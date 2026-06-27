#!/usr/bin/env python3
"""Shared helpers for running nihdl commands across all targets.

This module is imported by the test shell ``run_tests.py``, which runs one or
more nihdl-command tests across every discovered target.

Each test runs a single nihdl subcommand in every target directory (under
``../targets`` and ``../test-targets``), keeps going on failures, and reports
a pass/fail summary.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import time
from dataclasses import dataclass, field
from pathlib import Path


# ---------------------------------------------------------------------------
# Result data classes
# ---------------------------------------------------------------------------


@dataclass
class CommandResult:
    """Result for one command execution."""

    command: str
    return_code: int | None
    duration_seconds: float
    error_text: str = ""
    skipped: bool = False
    log_verdict: str = ""  # "PASS", "FAIL", "WARN", or "" (not checked)
    log_verdict_message: str = ""

    @property
    def status(self) -> str:
        """Return a human-readable status for reporting."""
        if self.skipped:
            return "N/A"
        if self.log_verdict:
            return self.log_verdict
        return "PASS" if self.return_code == 0 else "FAIL"

    @property
    def failed(self) -> bool:
        return self.status in ("FAIL", "WARN")


@dataclass
class TimingResult:
    """Result of post-routing timing analysis."""

    status: str  # "PASS", "FAIL", "WARN", or "N/A"
    slack_values: dict[str, float] = field(default_factory=dict)
    message: str = ""


@dataclass
class DiscoveredTarget:
    """A target directory discovered under a targets folder."""

    path: Path
    display_name: str


@dataclass
class TargetResult:
    """Aggregated result of running one command in one target."""

    target_name: str
    command_result: CommandResult
    timing_result: TimingResult = field(
        default_factory=lambda: TimingResult(status="N/A")
    )

    @property
    def passed(self) -> bool:
        return (
            not self.command_result.failed
            and self.timing_result.status in ("PASS", "N/A")
        )


# ---------------------------------------------------------------------------
# nihdl command/test definitions
# ---------------------------------------------------------------------------


@dataclass
class NihdlTest:
    """Definition of a single nihdl-command test run across all targets."""

    key: str  # CLI-friendly identifier, e.g. "gen-vivado"
    label: str  # short column label for the summary, e.g. "gen-viv"
    subcommand: list[str]  # nihdl args, e.g. ["gen-vivado", "--overwrite"]
    description: str = ""
    log_verdict_key: str = ""  # key into _LOG_VERDICTS, or "" to skip
    check_timing: bool = False


# Registry of all available nihdl-command tests. The test shell (run_tests.py)
# and the individual test scripts both look tests up here so behaviour stays
# consistent.
NIHDL_TESTS: dict[str, NihdlTest] = {
    "gen-vivado": NihdlTest(
        key="gen-vivado",
        label="gen-viv",
        subcommand=["gen-vivado", "--overwrite"],
        description="Generate (overwrite) the Vivado project for each target",
    ),
    "compile-vivado": NihdlTest(
        key="compile-vivado",
        label="compile",
        subcommand=["compile-vivado"],
        description="Compile the Vivado project and generate the bitfile",
        log_verdict_key="compile",
        check_timing=True,
    ),
    "check-vivado": NihdlTest(
        key="check-vivado",
        label="syntax",
        subcommand=["check-vivado"],
        description="Check RTL syntax/hierarchy via Vivado elaboration",
        log_verdict_key="syntax",
    ),
    "gen-window": NihdlTest(
        key="gen-window",
        label="gen-win",
        subcommand=["gen-window"],
        description="Generate the LabVIEW window netlist for each target",
    ),
    "gen-target": NihdlTest(
        key="gen-target",
        label="gen-tgt",
        subcommand=["gen-target"],
        description="Generate LabVIEW FPGA target support files",
    ),
    "install-target": NihdlTest(
        key="install-target",
        label="inst-tgt",
        subcommand=["install-target"],
        description="Install LabVIEW FPGA target support files",
    ),
    "gen-modelsim": NihdlTest(
        key="gen-modelsim",
        label="gen-sim",
        subcommand=["gen-modelsim", "--overwrite"],
        description="Generate (overwrite) the ModelSim simulation project",
    ),
    "sim-modelsim": NihdlTest(
        key="sim-modelsim",
        label="sim",
        subcommand=["sim-modelsim"],
        description="Run the ModelSim testbench simulation",
    ),
}


# ---------------------------------------------------------------------------
# Predefined test sequences (workflows)
# ---------------------------------------------------------------------------


@dataclass
class TestSequence:
    """A named workflow: an ordered list of tests plus the netlist mode.

    A sequence bundles a few NIHDL_TESTS keys with the window-netlist override
    that applies to the whole run. The override only affects the gen-window /
    gen-vivado netlist folders; it is a no-op for the other commands, so a
    single mode can safely apply to every step in the sequence.
    """

    key: str  # CLI-friendly identifier, e.g. "test-netlists"
    description: str  # one-line summary for --list and --help
    test_keys: list[str]  # NIHDL_TESTS keys to run, in order
    use_objects_lv_window: bool = False  # gen-vivado reads objects/ netlist
    write_shipping_netlist: bool = False  # gen-window writes the shipping netlist
    note: str = ""  # extra guidance printed before the run (e.g. a manual step)


# Registry of predefined workflows. Run one with:
#     python run_tests.py --sequence <key>
TEST_SEQUENCES: dict[str, TestSequence] = {
    "gen-install-lv-targets": TestSequence(
        key="gen-install-lv-targets",
        description="Generate and install LabVIEW FPGA target support files",
        test_keys=["gen-target", "install-target"],
        note=(
            "Next, manually open LabVIEW and generate the VPEs (Vivado project "
            "exports) for all projects before running the netlist sequences."
        ),
    ),
    "compile-targets-use-shipping-window": TestSequence(
        key="compile-targets-use-shipping-window",
        description="Build and compile using the checked-in shipping netlists",
        test_keys=["gen-vivado", "compile-vivado"],
    ),
    "compile-targets-gen-objects-window": TestSequence(
        key="compile-targets-gen-objects-window",
        description=(
            "Generate fresh netlists into objects/ and build/compile from them; "
            "the checked-in shipping netlists are left untouched"
        ),
        test_keys=["gen-window", "gen-vivado", "compile-vivado"],
        use_objects_lv_window=True,
    ),
    "compile-targets-gen-shipping-window": TestSequence(
        key="compile-targets-gen-shipping-window",
        description=(
            "Regenerate the checked-in shipping netlists, then build/compile "
            "from them"
        ),
        test_keys=["gen-window", "gen-vivado", "compile-vivado"],
        write_shipping_netlist=True,
    ),
    "simulate-targets": TestSequence(
        key="simulate-targets",
        description=(
            "Generate the ModelSim project and run the testbench simulation "
            "for each target"
        ),
        test_keys=["gen-modelsim", "sim-modelsim"],
    ),
}


# ---------------------------------------------------------------------------
# Vivado log parsing
# ---------------------------------------------------------------------------

# Regex for the Vivado post-routing timing summary line.
# Example: INFO: [Route 35-20] Post Routing Timing Summary | WNS=0.236  | TNS=0.000  | WHS=0.010  | THS=0.000  |
_POST_ROUTE_TIMING_RE = re.compile(
    r"\[Route 35-20\] Post Routing Timing Summary"
    r"\s*\|\s*WNS=(?P<WNS>\S+)"
    r"\s*\|\s*TNS=(?P<TNS>\S+)"
    r"\s*\|\s*WHS=(?P<WHS>\S+)"
    r"\s*\|\s*THS=(?P<THS>\S+)"
)

_TIMING_METRICS = ("WNS", "TNS", "WHS", "THS")

# Log verdict patterns written by the nihdl Tcl scripts.
_LOG_VERDICTS = {
    "compile": {
        "log_file": "VivadoProject/compile_project.log",
        "pass_token": "NIHDL_COMPILE_PROJECT=PASSED",
        "fail_token": "NIHDL_COMPILE_PROJECT=FAILED",
    },
    "syntax": {
        "log_file": "VivadoProject/check_syntax.log",
        "pass_token": "NIHDL_CHECK_SYNTAX=PASSED",
        "fail_token": "NIHDL_CHECK_SYNTAX=FAILED",
    },
}


def check_log_verdict(target_dir: Path, log_verdict_key: str) -> tuple[str, str]:
    """Check the Vivado log for the nihdl pass/fail verdict token.

    Returns (verdict, message) where verdict is:
      - "PASS" if the pass token is found
      - "FAIL" if the fail token is found
      - "WARN" if the log is missing, unreadable, or the verdict can't be
        determined (avoids silent false passes)
    """
    info = _LOG_VERDICTS.get(log_verdict_key)
    if info is None:
        return ("", "")

    log_path = target_dir / info["log_file"]
    if not log_path.is_file():
        return ("WARN", f"Log not found: {log_path}")

    try:
        log_text = log_path.read_text(errors="replace")
    except OSError as exc:
        return ("WARN", f"Cannot read log: {exc}")

    # Search non-comment lines for the verdict tokens.
    found_pass = False
    found_fail = False
    for line in log_text.splitlines():
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        if info["pass_token"] in stripped:
            found_pass = True
        if info["fail_token"] in stripped:
            found_fail = True

    if found_fail:
        return ("FAIL", f"Log contains {info['fail_token']}")
    if found_pass:
        return ("PASS", "")

    # Neither token found — format may have changed.
    return ("WARN", f"Neither PASSED nor FAILED token found in {log_path.name}")


def check_timing(target_dir: Path) -> TimingResult:
    """Parse VivadoProject/compile_project.log for post-routing timing.

    Returns PASS if all slack values are non-negative, FAIL if any are
    negative, or WARN if the log is missing or the summary line cannot
    be found/parsed.
    """
    log_path = target_dir / "VivadoProject" / "compile_project.log"
    if not log_path.is_file():
        return TimingResult(
            status="WARN",
            message=f"compile_project.log not found: {log_path}",
        )

    try:
        log_text = log_path.read_text(errors="replace")
    except OSError as exc:
        return TimingResult(status="WARN", message=f"Cannot read log: {exc}")

    match = None
    for line in log_text.splitlines():
        m = _POST_ROUTE_TIMING_RE.search(line)
        if m:
            match = m  # keep the last match (the final post-routing summary)

    if match is None:
        return TimingResult(
            status="WARN",
            message="Post Routing Timing Summary (Route 35-20) not found in log",
        )

    slack_values: dict[str, float] = {}
    for metric in _TIMING_METRICS:
        raw = match.group(metric)
        try:
            slack_values[metric] = float(raw)
        except (ValueError, TypeError):
            return TimingResult(
                status="WARN",
                slack_values=slack_values,
                message=f"Cannot parse {metric} value: {raw!r}",
            )

    violations = {k: v for k, v in slack_values.items() if v < 0}
    if violations:
        detail = ", ".join(f"{k}={v:+.3f}" for k, v in violations.items())
        return TimingResult(
            status="FAIL",
            slack_values=slack_values,
            message=f"Timing violated: {detail}",
        )

    return TimingResult(status="PASS", slack_values=slack_values)


# ---------------------------------------------------------------------------
# Target discovery and command execution
# ---------------------------------------------------------------------------


# Repository root, relative to this file (tests/manual/tests_common.py).
# parents[0] = tests/manual, parents[1] = tests, parents[2] = repo root.
REPO_ROOT = Path(__file__).resolve().parents[2]


def default_targets_dir() -> Path:
    """Return the default <repo>/targets folder."""
    return REPO_ROOT / "targets"


def default_test_targets_dir() -> Path:
    """Return the default <repo>/test-targets folder."""
    return REPO_ROOT / "test-targets"


# Shared wrapper nihdlsettings.py passed to every nihdl command via --config.
# It loads each target's own settings and applies machine-independent test
# overrides (window netlist folders and the Vivado project export .xpr path).
# Behavior is tuned per run via generic ``--set KEY=VALUE`` overrides that nihdl
# forwards to the wrapper as ``context.settings`` (see run_test).
WRAPPER_SETTINGS = Path(__file__).resolve().parent / "nihdlsettings.py"


def discover_targets(targets_dirs: list[Path]) -> list[DiscoveredTarget]:
    """Return target directories (containing nihdlsettings.py) across folders.

    Targets are returned in the order the folders are given, sorted by name
    within each folder. The display name is prefixed with the parent folder
    name (e.g. ``targets/pxie-7903custom``) so targets and test-targets are
    distinguishable in the summary.
    """
    found: list[DiscoveredTarget] = []
    for targets_dir in targets_dirs:
        if not targets_dir.exists() or not targets_dir.is_dir():
            print(f"Warning: targets folder not found, skipping: {targets_dir}")
            continue
        for child in sorted(targets_dir.iterdir(), key=lambda p: p.name.lower()):
            if child.is_dir() and (child / "nihdlsettings.py").is_file():
                found.append(
                    DiscoveredTarget(
                        path=child,
                        display_name=f"{targets_dir.name}/{child.name}",
                    )
                )
    return found


def run_command(command: list[str], cwd: Path) -> CommandResult:
    """Run a command in cwd and return status without raising."""
    command_text = " ".join(command)
    print(f"    Running: {command_text}")

    start = time.perf_counter()
    try:
        completed = subprocess.run(command, cwd=str(cwd), check=False)
        return_code = completed.returncode
        error_text = ""
    except FileNotFoundError as exc:
        return_code = 127
        error_text = str(exc)
        print(f"    ERROR: {error_text}")

    duration_seconds = time.perf_counter() - start
    print(f"    Exit code: {return_code} ({duration_seconds:.1f}s)")

    return CommandResult(
        command=command_text,
        return_code=return_code,
        duration_seconds=duration_seconds,
        error_text=error_text,
    )


# ---------------------------------------------------------------------------
# Running a single nihdl-command test across all targets
# ---------------------------------------------------------------------------


def run_test(
    test: NihdlTest,
    targets: list[DiscoveredTarget],
    nihdl_cmd: str = "nihdl",
    use_objects_lv_window: bool = False,
    write_shipping_netlist: bool = False,
    use_xilinx_env: bool = False,
) -> list[TargetResult]:
    """Run one nihdl-command test in every target directory.

    Keeps going on failures and returns a list of per-target results.
    """
    print("\n" + "=" * 80)
    print(f"TEST: {test.key} \u2014 {test.description}")
    print("=" * 80)

    # Tune the shared wrapper's behavior via generic --set overrides that nihdl
    # forwards to the wrapper's hooks as context.settings (no variant files, no
    # environment variables).
    set_overrides: list[str] = []
    if use_objects_lv_window:
        set_overrides += ["--set", "lv_window_input=objects"]
    if write_shipping_netlist:
        set_overrides += ["--set", "lv_window_output=shipping"]
    if use_xilinx_env:
        set_overrides += ["--set", "use_xilinx_env=1"]

    results: list[TargetResult] = []
    for target in targets:
        print("\n" + "-" * 80)
        print(f"Target: {target.display_name}")
        print(f"Directory: {target.path}")

        # Run every nihdl command through the shared test wrapper settings so
        # the tests use machine-independent paths instead of the per-developer
        # paths in each target's own nihdlsettings.py.
        command = [
            nihdl_cmd,
            *test.subcommand,
            f"--config={WRAPPER_SETTINGS}",
            *set_overrides,
        ]
        command_result = run_command(command, target.path)

        if test.log_verdict_key and command_result.return_code == 0:
            verdict, verdict_msg = check_log_verdict(
                target.path, test.log_verdict_key
            )
            command_result.log_verdict = verdict
            command_result.log_verdict_message = verdict_msg
            if verdict_msg:
                print(f"    Log verdict: {verdict} - {verdict_msg}")

        timing_result = TimingResult(status="N/A")
        if test.check_timing and command_result.return_code == 0:
            print("    Checking post-routing timing ...")
            timing_result = check_timing(target.path)
            print(f"    Timing: {timing_result.status}")
            if timing_result.message:
                print(f"      {timing_result.message}")

        results.append(
            TargetResult(
                target_name=target.display_name,
                command_result=command_result,
                timing_result=timing_result,
            )
        )

    return results


def print_test_summary(test: NihdlTest, results: list[TargetResult]) -> None:
    """Print a pass/fail summary for a single test."""
    print("\n" + "=" * 80)
    print(f"SUMMARY: {test.key}")
    print("=" * 80)

    passed_count = 0
    failed_count = 0
    timing_warn_count = 0

    for result in results:
        status = "PASS" if result.passed else "FAIL"
        if result.passed:
            passed_count += 1
        else:
            failed_count += 1

        command_status = result.command_result.status
        line = (
            f"{result.target_name:34} {status:4} "
            f"{test.label}= {command_status:4}"
        )

        if test.check_timing:
            timing_status = result.timing_result.status
            line += f"  timing= {timing_status:4}"
            if timing_status == "WARN":
                timing_warn_count += 1

        print(line)

        if result.command_result.error_text:
            print(f"  error: {result.command_result.error_text}")
        if result.command_result.log_verdict_message:
            print(f"  log: {result.command_result.log_verdict_message}")
        if test.check_timing and result.timing_result.message:
            print(f"  timing: {result.timing_result.message}")
            if result.timing_result.slack_values:
                vals = "  ".join(
                    f"{k}={v:+.3f}"
                    for k, v in result.timing_result.slack_values.items()
                )
                print(f"  timing values: {vals}")

    print("-" * 80)
    print(f"Total targets: {len(results)}")
    print(f"Passed: {passed_count}")
    print(f"Failed: {failed_count}")
    if test.check_timing and timing_warn_count:
        print(f"Timing warnings (could not determine pass/fail): {timing_warn_count}")
    print("=" * 80)


# ---------------------------------------------------------------------------
# Shared CLI plumbing
# ---------------------------------------------------------------------------


def add_common_arguments(parser: argparse.ArgumentParser) -> None:
    """Add the target-selection and nihdl options common to every test."""
    parser.add_argument(
        "--targets-dir",
        type=Path,
        default=default_targets_dir(),
        help=f"Path to targets folder (default: {default_targets_dir()})",
    )
    parser.add_argument(
        "--test-targets-dir",
        type=Path,
        default=default_test_targets_dir(),
        help=f"Path to test-targets folder (default: {default_test_targets_dir()})",
    )
    parser.add_argument(
        "--nihdl-cmd",
        default="nihdl",
        help="Command name or full path for nihdl executable (default: nihdl)",
    )
    parser.add_argument(
        "--xilinx-from-env",
        action="store_true",
        help=(
            "Override the Vivado tools folder from the XILINX environment "
            "variable (set_vivado_tools_folder). Intended for CI/pipeline runs "
            "where XILINX selects the Vivado install. No-op if XILINX is unset."
        ),
    )
    parser.add_argument(
        "--target",
        action="append",
        metavar="NAME",
        help=(
            "Only run on the named target folder, e.g. --target pxie-7903custom. "
            "Repeatable to select several. Matched case-insensitively against "
            "the target directory name. Defaults to every discovered target -- "
            "handy for rerunning a sequence on the one target that misbehaved."
        ),
    )


def resolve_targets(args: argparse.Namespace) -> list[DiscoveredTarget]:
    """Discover targets based on the common CLI arguments.

    When --target is supplied, the discovered list is filtered down to the
    requested target folder name(s). Any name that matches nothing produces a
    warning listing the targets that are actually available.
    """
    discovered = discover_targets([args.targets_dir, args.test_targets_dir])

    requested = getattr(args, "target", None)
    if not requested:
        return discovered

    wanted = [name.strip().lower() for name in requested]
    selected: list[DiscoveredTarget] = []
    matched: set[str] = set()
    for target in discovered:
        folder = target.path.name.lower()
        display = target.display_name.lower()
        for name in wanted:
            if name == folder or name == display or display.endswith("/" + name):
                selected.append(target)
                matched.add(name)
                break

    unmatched = [orig for orig, low in zip(requested, wanted) if low not in matched]
    if unmatched:
        available = ", ".join(t.path.name for t in discovered) or "(none)"
        print(f"Warning: --target not found: {', '.join(unmatched)}")
        print(f"Available targets: {available}")
    return selected
