"""Set up Python environment and install packages from dependencies.toml.

Usage:
    python nisetup.py              # Create/reuse .venv and install packages
    python nisetup.py --no-venv    # Install packages into current Python (for pipelines)
"""

import argparse
import subprocess
import sys
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib


def _read_python_dependencies(toml_path):
    """Read python_dependencies list from dependencies.toml."""
    with open(toml_path, "rb") as f:
        data = tomllib.load(f)
    return data.get("python_dependencies", [])


def main():
    parser = argparse.ArgumentParser(description="Set up Python environment for this workspace.")
    parser.add_argument("repo_root", nargs="?", default=None, help="Path to repo root")
    parser.add_argument("--no-venv", action="store_true", help="Install into current Python (skip venv)")
    args = parser.parse_args()

    repo_root = Path(args.repo_root) if args.repo_root else Path(__file__).parent
    deps_file = repo_root / "dependencies.toml"

    if not deps_file.exists():
        print(f"ERROR: {deps_file} not found.")
        sys.exit(1)

    packages = _read_python_dependencies(deps_file)
    if not packages:
        print("ERROR: No python_dependencies found in dependencies.toml.")
        sys.exit(1)

    print(f"Using: Python {sys.version.split()[0]}")

    if args.no_venv:
        # Pipeline mode: install directly into current Python
        print(f"\nInstalling Python packages: {', '.join(packages)}")
        subprocess.run(
            [sys.executable, "-m", "pip", "install", *packages, "--quiet"],
            check=True,
        )
        return

    # Local dev mode: create/reuse venv
    venv_dir = repo_root / ".venv"
    venv_pip = venv_dir / "Scripts" / "pip.exe"
    if not venv_pip.exists():
        venv_pip = venv_dir / "bin" / "pip"

    if not venv_pip.exists():
        print("\nCreating virtual environment in .venv ...")
        prompt_name = repo_root.resolve().name
        subprocess.run([sys.executable, "-m", "venv", str(venv_dir), "--prompt", prompt_name], check=True)
        print("Virtual environment created.")
        # Re-resolve after creation
        venv_pip = venv_dir / "Scripts" / "pip.exe"
        if not venv_pip.exists():
            venv_pip = venv_dir / "bin" / "pip"
    else:
        print("Virtual environment already exists.")

    print("\nInstalling Python packages from dependencies.toml ...")
    subprocess.run(
        [str(venv_pip), "install", *packages, "--quiet"],
        check=True,
    )


if __name__ == "__main__":
    main()
