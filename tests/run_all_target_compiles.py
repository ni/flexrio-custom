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
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path


@dataclass
class CommandResult:
    """Result for one command execution."""

    command: str
    return_code: int | None
    duration_seconds: float
    error_text: str = ""
    skipped: bool = False

    @property
    def status(self) -> str:
        """Return a human-readable status for reporting."""
        if self.skipped:
            return "N/A"
        return "PASS" if self.return_code == 0 else "FAIL"


@dataclass
class TargetResult:
    """Aggregated results for one target."""

    target_name: str
    create_result: CommandResult
    compile_result: CommandResult

    @property
    def passed(self) -> bool:
        return self.create_result.return_code == 0 and self.compile_result.return_code == 0


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


def _print_summary(results: list[TargetResult], step_two_label: str) -> None:
    """Print final pass/fail summary."""
    print("\n" + "=" * 80)
    print("SUMMARY")
    print("=" * 80)

    passed_count = 0
    failed_count = 0

    for result in results:
        status = "PASS" if result.passed else "FAIL"
        if result.passed:
            passed_count += 1
        else:
            failed_count += 1

        create_status = result.create_result.status
        compile_status = result.compile_result.status

        print(
            f"{result.target_name:30} {status:4} "
            f"create= {create_status:4} "
            f"{step_two_label}= {compile_status:4}"
        )

        if result.create_result.error_text:
            print(f"  create error: {result.create_result.error_text}")
        if result.compile_result.error_text:
            print(f"  {step_two_label} error: {result.compile_result.error_text}")

    print("-" * 80)
    print(f"Total targets: {len(results)}")
    print(f"Passed: {passed_count}")
    print(f"Failed: {failed_count}")
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
        else:
            print(f"    Skipping {step_two_subcommand}: create-project failed")
            compile_result = CommandResult(
                command=" ".join(compile_cmd),
                return_code=None,
                duration_seconds=0.0,
                skipped=True,
            )

        results.append(
            TargetResult(
                target_name=target_name,
                create_result=create_result,
                compile_result=compile_result,
            )
        )

    _print_summary(results, step_two_label)

    return 0 if all(result.passed for result in results) else 1


if __name__ == "__main__":
    sys.exit(main())
