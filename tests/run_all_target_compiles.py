#!/usr/bin/env python3
"""Run nihdl project creation and compile/syntax-check for every target folder.

This script iterates targets under ../targets that contain a projectsettings.ini file,
runs the following commands in each target directory, and keeps going on failures:

1. nihdl create-project --overwrite
2. nihdl compile-project (default) or nihdl check-syntax (--syntax-only)

At the end, it prints a pass/fail summary for each target and overall totals.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path


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


def _check_log_verdict(
    target_dir: Path, step_label: str
) -> tuple[str, str]:
    """Check the Vivado log for the nihdl pass/fail verdict token.

    Returns (verdict, message) where verdict is:
      - "PASS" if the pass token is found
      - "FAIL" if the fail token is found
      - "WARN" if the log is missing, unreadable, or the verdict can't be
        determined (avoids silent false passes)
    """
    info = _LOG_VERDICTS.get(step_label)
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


def _check_timing(target_dir: Path) -> TimingResult:
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


@dataclass
class TargetResult:
    """Aggregated results for one target."""

    target_name: str
    create_result: CommandResult
    compile_result: CommandResult
    timing_result: TimingResult = field(
        default_factory=lambda: TimingResult(status="N/A")
    )

    @property
    def passed(self) -> bool:
        return (
            self.create_result.return_code == 0
            and not self.compile_result.failed
            and self.timing_result.status in ("PASS", "N/A")
        )


def _discover_targets(targets_dir: Path) -> list[Path]:
    """Return target directories that contain projectsettings.ini."""
    if not targets_dir.exists() or not targets_dir.is_dir():
        raise FileNotFoundError(f"Targets folder not found: {targets_dir}")

    target_dirs = []
    for child in sorted(targets_dir.iterdir(), key=lambda p: p.name.lower()):
        if child.is_dir() and (child / "projectsettings.ini").is_file():
            target_dirs.append(child)
    return target_dirs


def _run_command(command: list[str], cwd: Path) -> CommandResult:
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


def _print_summary(
    results: list[TargetResult], step_two_label: str, check_timing: bool
) -> None:
    """Print final pass/fail summary."""
    print("\n" + "=" * 80)
    print("SUMMARY")
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

        create_status = result.create_result.status
        compile_status = result.compile_result.status

        line = (
            f"{result.target_name:30} {status:4} "
            f"create= {create_status:4} "
            f"{step_two_label}= {compile_status:4}"
        )

        if check_timing:
            timing_status = result.timing_result.status
            line += f"  timing= {timing_status:4}"
            if timing_status == "WARN":
                timing_warn_count += 1

        print(line)

        if result.create_result.error_text:
            print(f"  create error: {result.create_result.error_text}")
        if result.compile_result.error_text:
            print(f"  {step_two_label} error: {result.compile_result.error_text}")
        if result.compile_result.log_verdict_message:
            print(
                f"  {step_two_label} log: {result.compile_result.log_verdict_message}"
            )
        if check_timing and result.timing_result.message:
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
    if check_timing and timing_warn_count:
        print(f"Timing warnings (could not determine pass/fail): {timing_warn_count}")
    print("=" * 80)


def main() -> int:
    """CLI entrypoint."""
    script_dir = Path(__file__).resolve().parent
    default_targets_dir = script_dir.parent / "targets"

    parser = argparse.ArgumentParser(
        description=(
            "Run nihdl create-project and then compile-project or check-syntax "
            "for all targets."
        )
    )
    parser.add_argument(
        "--targets-dir",
        type=Path,
        default=default_targets_dir,
        help=f"Path to targets folder (default: {default_targets_dir})",
    )
    parser.add_argument(
        "--nihdl-cmd",
        default="nihdl",
        help="Command name or full path for nihdl executable (default: nihdl)",
    )
    parser.add_argument(
        "--syntax-only",
        action="store_true",
        help="Run nihdl check-syntax instead of nihdl compile-project",
    )
    args = parser.parse_args()

    try:
        targets = _discover_targets(args.targets_dir)
    except Exception as exc:
        print(f"Error: {exc}")
        return 1

    if not targets:
        print(f"No targets with projectsettings.ini found in: {args.targets_dir}")
        return 1

    print(f"Found {len(targets)} targets in: {args.targets_dir}")

    step_two_subcommand = "check-syntax" if args.syntax_only else "compile-project"
    step_two_label = "syntax" if args.syntax_only else "compile"

    results: list[TargetResult] = []
    for target_dir in targets:
        target_name = target_dir.name
        print("\n" + "-" * 80)
        print(f"Target: {target_name}")
        print(f"Directory: {target_dir}")

        create_cmd = [args.nihdl_cmd, "create-project", "--overwrite"]
        compile_cmd = [args.nihdl_cmd, step_two_subcommand]

        create_result = _run_command(create_cmd, target_dir)
        if create_result.return_code == 0:
            compile_result = _run_command(compile_cmd, target_dir)
            verdict, verdict_msg = _check_log_verdict(
                target_dir, step_two_label
            )
            compile_result.log_verdict = verdict
            compile_result.log_verdict_message = verdict_msg
            if verdict_msg:
                print(f"    Log verdict: {verdict} - {verdict_msg}")
        else:
            print(f"    Skipping {step_two_subcommand}: create-project failed")
            compile_result = CommandResult(
                command=" ".join(compile_cmd),
                return_code=None,
                duration_seconds=0.0,
                skipped=True,
            )

        timing_result = TimingResult(status="N/A")
        if not args.syntax_only and compile_result.return_code == 0:
            print("    Checking post-routing timing ...")
            timing_result = _check_timing(target_dir)
            print(f"    Timing: {timing_result.status}")
            if timing_result.message:
                print(f"      {timing_result.message}")

        results.append(
            TargetResult(
                target_name=target_name,
                create_result=create_result,
                compile_result=compile_result,
                timing_result=timing_result,
            )
        )

    _print_summary(results, step_two_label, check_timing=not args.syntax_only)

    return 0 if all(result.passed for result in results) else 1


if __name__ == "__main__":
    sys.exit(main())
