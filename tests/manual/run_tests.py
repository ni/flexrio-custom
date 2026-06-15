#!/usr/bin/env python3
"""Test shell: run a chosen sequence of nihdl-command tests across all targets.

This is the single entry point for all of the per-command tests. Each "test"
runs one nihdl subcommand in every target and test-target directory, through
the shared wrapper nihdlsettings.py (tests/manual/nihdlsettings.py) so the runs
use machine-independent paths.

Pick the sequence of tests to run, for example generate the Vivado projects
and then compile them:

    python run_tests.py gen-vivado compile-vivado

Run a single test (this replaces the old run_<command>.py scripts):

    python run_tests.py check-vivado

Run every test, in registry order:

    python run_tests.py all

List the available tests and the nihdl subcommand each one runs:

    python run_tests.py --list

Run interactively (you'll be prompted to pick a sequence) when no tests are
given on the command line:

    python run_tests.py

Tests run in the exact order you list them. The shell keeps going if a test
fails and prints a per-test summary plus an overall summary at the end.

See "python run_tests.py --help" for the full list of options.
"""

from __future__ import annotations

import argparse
import os
import sys

from tests_common import (
    NIHDL_TESTS,
    add_common_arguments,
    print_test_summary,
    resolve_targets,
    run_test,
)

# Environment variable used to tell the wrapper nihdlsettings.py whether to also
# point the *input* window netlist folder at the test netlist folder. The
# wrapper runs in a separate nihdl process and can't see our argv, so the flag
# is communicated through the environment.
USE_TEST_LV_WINDOW_ENV = "FLEXRIO_TEST_USE_TEST_LV_WINDOW"


def _print_available_tests() -> None:
    """Print the registered tests, the nihdl subcommand, and descriptions."""
    print("Available nihdl-command tests:\n")
    key_width = max(len(key) for key in NIHDL_TESTS)
    cmd_width = max(len(" ".join(t.subcommand)) for t in NIHDL_TESTS.values())
    print(f"  {'TEST':{key_width}}  {'NIHDL COMMAND':{cmd_width}}  DESCRIPTION")
    for key, test in NIHDL_TESTS.items():
        nihdl_cmd = " ".join(test.subcommand)
        print(f"  {key:{key_width}}  {nihdl_cmd:{cmd_width}}  {test.description}")
    print(
        "\nEach test runs 'nihdl <command>' in every target. To see the options "
        "for a\nspecific nihdl subcommand, ask nihdl directly, e.g.:\n"
        "    nihdl gen-vivado --help\n"
        "    nihdl compile-vivado --help"
    )


def _prompt_for_sequence() -> list[str]:
    """Interactively prompt the user to choose a sequence of tests."""
    keys = list(NIHDL_TESTS)
    print("Select the tests to run, in order.\n")
    for index, key in enumerate(keys, start=1):
        print(f"  {index}. {key:14} {NIHDL_TESTS[key].description}")
    print(
        "\nEnter test numbers or names separated by spaces or commas "
        "(in the order to run).\n"
        "Examples: '1 2'  or  'gen-vivado compile-vivado'  or  'all'"
    )

    raw = input("Sequence: ").strip()
    if not raw:
        return []
    if raw.lower() == "all":
        return keys

    tokens = raw.replace(",", " ").split()
    selected: list[str] = []
    for token in tokens:
        if token.isdigit():
            number = int(token)
            if 1 <= number <= len(keys):
                selected.append(keys[number - 1])
            else:
                print(f"Ignoring out-of-range selection: {token}")
        elif token in NIHDL_TESTS:
            selected.append(token)
        else:
            print(f"Ignoring unknown test: {token}")
    return selected


def main() -> int:
    epilog = (
        "tests:\n"
        "  Give one or more test keys (see the choices above) in the order to\n"
        "  run them. Use 'all' to run every test. Omit to choose interactively.\n"
        "  Each test runs 'nihdl <command>' in every discovered target.\n"
        "\n"
        "target selection:\n"
        "  By default both the targets folder and the test-targets folder are\n"
        "  scanned for directories containing a nihdlsettings.py. Use\n"
        "  --no-test-targets / --only-test-targets to restrict the set, or\n"
        "  --targets-dir / --test-targets-dir to point at different folders.\n"
        "\n"
        "nihdl subcommand options:\n"
        "  The --xxx options below belong to THIS script. The options of each\n"
        "  underlying nihdl subcommand (the ones run inside every target) are\n"
        "  owned by nihdl itself. To discover them, ask nihdl directly:\n"
        "      nihdl gen-vivado --help\n"
        "      nihdl compile-vivado --help\n"
        "      nihdl check-vivado --help\n"
        "  Run 'python run_tests.py --list' to see which nihdl command each\n"
        "  test maps to.\n"
        "\n"
        "examples:\n"
        "  python run_tests.py --list\n"
        "  python run_tests.py check-vivado\n"
        "  python run_tests.py gen-vivado compile-vivado\n"
        "  python run_tests.py all --no-test-targets\n"
        "  python run_tests.py gen-vivado --usetestlvwindow\n"
        "  python run_tests.py check-vivado --only-test-targets\n"
        "  python run_tests.py compile-vivado --nihdl-cmd C:/path/to/nihdl.exe\n"
    )
    parser = argparse.ArgumentParser(
        prog="run_tests.py",
        description=(
            "Run one or more nihdl-command tests across all targets and "
            "test-targets. This is the single entry point that replaces the "
            "old per-command run_<command>.py scripts."
        ),
        epilog=epilog,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "tests",
        nargs="*",
        metavar="TEST",
        help=(
            "Sequence of tests to run, in order. "
            f"Choices: {', '.join(NIHDL_TESTS)}, all. "
            "Use 'all' to run every test. Omit to choose interactively."
        ),
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help=(
            "List the available tests (and the nihdl subcommand each one runs) "
            "and exit"
        ),
    )
    parser.add_argument(
        "--usetestlvwindow",
        action="store_true",
        help=(
            "For tests that read the window netlist (e.g. gen-vivado), also "
            "override the input window netlist folder "
            "(set_lv_window_netlist_folder) to objects/testLvWindowNetlist. By "
            "default each target's own netlist folder is used."
        ),
    )
    add_common_arguments(parser)
    args = parser.parse_args()

    if args.list:
        _print_available_tests()
        return 0

    requested = list(args.tests)
    if requested == ["all"]:
        requested = list(NIHDL_TESTS)
    elif "all" in requested:
        # Expand 'all' in place while preserving any explicit ordering around it.
        expanded: list[str] = []
        for key in requested:
            expanded.extend(NIHDL_TESTS if key == "all" else [key])
        requested = expanded

    if not requested:
        requested = _prompt_for_sequence()

    if not requested:
        print("No tests selected.")
        return 1

    unknown = [key for key in requested if key not in NIHDL_TESTS]
    if unknown:
        print(f"Unknown test(s): {', '.join(unknown)}")
        print(f"Valid tests: {', '.join(NIHDL_TESTS)}")
        return 2

    # The wrapper nihdlsettings.py is loaded by nihdl (a separate process) and
    # can't see our args, so communicate --usetestlvwindow via the environment.
    os.environ[USE_TEST_LV_WINDOW_ENV] = "1" if args.usetestlvwindow else "0"

    targets = resolve_targets(args)
    if not targets:
        print("No targets with nihdlsettings.py found.")
        return 1

    print(f"Found {len(targets)} targets.")
    print(f"Running tests in order: {' -> '.join(requested)}")
    if args.usetestlvwindow:
        print(
            "Input window netlist folder overridden to objects/testLvWindowNetlist."
        )

    overall: dict[str, bool] = {}
    for test_key in requested:
        test = NIHDL_TESTS[test_key]
        results = run_test(test, targets, nihdl_cmd=args.nihdl_cmd)
        print_test_summary(test, results)
        overall[test_key] = all(result.passed for result in results)

    print("\n" + "#" * 80)
    print("OVERALL SUMMARY")
    print("#" * 80)
    for test_key in requested:
        status = "PASS" if overall[test_key] else "FAIL"
        print(f"  {test_key:16} {status}")
    print("#" * 80)

    return 0 if all(overall.values()) else 1


if __name__ == "__main__":
    sys.exit(main())
