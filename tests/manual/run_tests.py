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
import sys
from datetime import datetime

from tests_common import (
    NIHDL_TESTS,
    TEST_SEQUENCES,
    add_common_arguments,
    create_run_logger,
    print_test_summary,
    resolve_targets,
    run_test,
)


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
    _print_available_sequences()


def _print_available_sequences() -> None:
    """Print the predefined workflow sequences and the steps each one runs."""
    print("\nAvailable workflow sequences (run with --sequence <key>):\n")
    key_width = max(len(key) for key in TEST_SEQUENCES)
    print(f"  {'SEQUENCE':{key_width}}  STEPS / DESCRIPTION")
    for key, seq in TEST_SEQUENCES.items():
        steps = " -> ".join(seq.test_keys)
        mode = ""
        if seq.use_objects_lv_window:
            mode = "  [reads objects/ netlist]"
        elif seq.write_shipping_netlist:
            mode = "  [writes shipping netlist]"
        print(f"  {key:{key_width}}  {steps}{mode}")
        print(f"  {'':{key_width}}  {seq.description}")
        if seq.note:
            print(f"  {'':{key_width}}  note: {seq.note}")


def _prompt_for_sequence() -> list[str]:
    """Interactively prompt the user to choose a sequence of tests."""
    keys = list(NIHDL_TESTS)
    print("Select the tests to run, in order.\n")
    for index, key in enumerate(keys, start=1):
        print(f"  {index}. {key:14} {NIHDL_TESTS[key].description}")
    print(
        "\nEnter test numbers or names separated by spaces or commas "
        "(in the order to run).\n"
        "Examples: '1 2'  or  'gen-vivado compile-vivado'"
    )

    raw = input("Sequence: ").strip()
    if not raw:
        return []

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
        "  run them. Omit to choose interactively.\n"
        "  Each test runs 'nihdl <command>' in every discovered target.\n"
        "\n"
        "sequences:\n"
        "  --sequence <key> runs a predefined workflow (an ordered set of tests\n"
        "  with the right netlist mode already applied). Run 'python\n"
        "  run_tests.py --list' to see the available sequences and their steps.\n"
        "\n"
        "target selection:\n"
        "  Both the targets folder and the test-targets folder are scanned for\n"
        "  directories containing a nihdlsettings.py. Use --targets-dir /\n"
        "  --test-targets-dir to point at different folders. Use --target NAME\n"
        "  (repeatable) to run on just one target, e.g. --target pxie-7903custom,\n"
        "  which is handy for rerunning a sequence on a single failing target.\n"
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
        "  python run_tests.py --sequence setup-targets\n"
        "  python run_tests.py --sequence check-shipping-netlists\n"
        "  python run_tests.py --sequence test-netlists\n"
        "  python run_tests.py --sequence update-shipping-netlists\n"
        "  python run_tests.py --sequence check-shipping-netlists --target pxie-7903custom\n"
        "  python run_tests.py check-vivado\n"
        "  python run_tests.py gen-vivado compile-vivado\n"
        "  python run_tests.py gen-vivado --useobjectslvwindow\n"
        "  python run_tests.py gen-window --writeshippingnetlist\n"
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
            f"Choices: {', '.join(NIHDL_TESTS)}. "
            "Omit to choose interactively."
        ),
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help=(
            "List the available tests and workflow sequences (and the nihdl "
            "subcommand each test runs) and exit"
        ),
    )
    parser.add_argument(
        "--sequence",
        choices=list(TEST_SEQUENCES),
        metavar="SEQUENCE",
        help=(
            "Run a predefined workflow sequence instead of listing tests. "
            f"Choices: {', '.join(TEST_SEQUENCES)}. The sequence sets the "
            "netlist mode itself, so do not combine it with TEST keys or the "
            "--useobjectslvwindow / --writeshippingnetlist flags."
        ),
    )
    # --useobjectslvwindow (gen-vivado input netlist) and --writeshippingnetlist
    # (gen-window output netlist) map to generic nihdl ``--set`` overrides that the
    # shared wrapper reads from context.settings. They target different
    # subcommands and are mutually exclusive.
    window_netlist_group = parser.add_mutually_exclusive_group()
    window_netlist_group.add_argument(
        "--useobjectslvwindow",
        action="store_true",
        help=(
            "For tests that read the window netlist (e.g. gen-vivado), override "
            "the input window netlist folder (set_lv_window_netlist_folder) to "
            "the generated netlist under the target's objects/ folder (e.g. "
            "objects/testLvWindowNetlist). By default the lvWindowNetlist "
            "folder specified in each target's own nihdlsettings.py is used."
        ),
    )
    window_netlist_group.add_argument(
        "--writeshippingnetlist",
        action="store_true",
        help=(
            "For gen-window, write the generated netlist output "
            "(set_lv_window_netlist_output_folder) to the checked-in "
            "(\"shipping\") netlist folder at each target's root (e.g. "
            "blankLvWindowNetlist, fifoTestLvWindowNetlist) so it can be "
            "committed to GitHub. By default the output goes to the scratch "
            "objects/testLvWindowNetlist folder."
        ),
    )
    add_common_arguments(parser)
    args = parser.parse_args()

    if args.list:
        _print_available_tests()
        return 0

    # The netlist mode applied to the whole run. It comes from a --sequence
    # preset or from the manual --useobjectslvwindow / --writeshippingnetlist
    # flags.
    use_objects_lv_window = args.useobjectslvwindow
    write_shipping_netlist = args.writeshippingnetlist
    sequence_note = ""

    if args.sequence:
        if args.tests:
            print(
                "Do not combine TEST keys with --sequence; the sequence "
                "defines its own ordered steps."
            )
            return 2
        if args.useobjectslvwindow or args.writeshippingnetlist:
            print(
                "Do not combine --useobjectslvwindow / --writeshippingnetlist "
                "with --sequence; the sequence sets the netlist mode itself."
            )
            return 2
        seq = TEST_SEQUENCES[args.sequence]
        requested = list(seq.test_keys)
        use_objects_lv_window = seq.use_objects_lv_window
        write_shipping_netlist = seq.write_shipping_netlist
        sequence_note = seq.note
    else:
        requested = list(args.tests)

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

    # --useobjectslvwindow / --writeshippingnetlist map to generic nihdl ``--set``
    # overrides (forwarded to the wrapper as context.settings), so the choice is
    # explicit on each command line rather than carried through a side channel.
    targets = resolve_targets(args)
    if not targets:
        print("No targets with nihdlsettings.py found.")
        return 1

    print(f"Found {len(targets)} targets.")
    if args.sequence:
        print(f"Running sequence '{args.sequence}': {' -> '.join(requested)}")
    else:
        print(f"Running tests in order: {' -> '.join(requested)}")
    if use_objects_lv_window:
        print(
            "Input window netlist folder overridden to the generated netlist "
            "under each target's objects/ folder."
        )
    if write_shipping_netlist:
        print(
            "gen-window output overridden to the checked-in shipping netlist "
            "folder at each target's root."
        )
    if sequence_note:
        print(f"\nNote: {sequence_note}\n")

    # Open a per-run log file under objects/test_log/ and record the run
    # parameters. Every test and per-target result is appended (and flushed)
    # while the run is in progress, so the file can be tailed to watch progress
    # instead of waiting for the summary at the very end.
    logger = create_run_logger()
    print(f"Logging this run to: {logger.log_path}\n")
    logger.write("#" * 80)
    logger.write("RUN TESTS")
    logger.write("#" * 80)
    logger.write(f"Started: {datetime.now():%Y-%m-%d %H:%M:%S}")
    if args.sequence:
        logger.write(f"Sequence: {args.sequence}")
    logger.write(f"Tests: {' -> '.join(requested)}")
    logger.write(f"Targets ({len(targets)}):")
    for target in targets:
        logger.write(f"  - {target.display_name}")
    if use_objects_lv_window:
        logger.write("Netlist mode: input window netlist from objects/ folder")
    if write_shipping_netlist:
        logger.write("Netlist mode: gen-window writes the shipping netlist")
    if sequence_note:
        logger.write(f"Note: {sequence_note}")
    logger.write("#" * 80)

    overall: dict[str, bool] = {}
    try:
        for test_key in requested:
            test = NIHDL_TESTS[test_key]
            results = run_test(
                test,
                targets,
                nihdl_cmd=args.nihdl_cmd,
                use_objects_lv_window=use_objects_lv_window,
                write_shipping_netlist=write_shipping_netlist,
                use_xilinx_env=args.xilinx_from_env,
                use_modelsim_env=args.modelsim_from_env,
                logger=logger,
            )
            print_test_summary(test, results, logger=logger)
            overall[test_key] = all(result.passed for result in results)

        summary_lines = ["\n" + "#" * 80, "OVERALL SUMMARY", "#" * 80]
        for test_key in requested:
            status = "PASS" if overall[test_key] else "FAIL"
            summary_lines.append(f"  {test_key:16} {status}")
        summary_lines.append("#" * 80)
        summary_lines.append(f"Finished: {datetime.now():%Y-%m-%d %H:%M:%S}")

        for line in summary_lines:
            print(line)
            logger.write(line)
        print(f"\nFull run log: {logger.log_path}")
    finally:
        logger.close()

    return 0 if all(overall.values()) else 1


if __name__ == "__main__":
    sys.exit(main())
