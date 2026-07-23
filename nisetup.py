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


def _report_nihdl_version(scripts_dir):
    """Run `nihdl --version` from the given scripts directory and print the result."""
    nihdl = scripts_dir / "nihdl.exe"
    if not nihdl.exists():
        nihdl = scripts_dir / "nihdl"
    if not nihdl.exists():
        print("WARNING: nihdl was not found after installation; skipping version report.")
        return
    result = subprocess.run([str(nihdl), "--version"], capture_output=True, text=True)
    version = (result.stdout or result.stderr).strip()
    if result.returncode != 0 or not version:
        print("WARNING: could not determine nihdl version.")
        return
    print(f"\nLoaded HDL tools: {version}")


def _install_packages(pip_command, packages, scripts_dir):
    """Install packages with the given pip command and report the nihdl version."""
    print(f"\nInstalling Python packages: {', '.join(packages)}")
    subprocess.run(
        [*pip_command, "install", *packages, "--quiet", "--disable-pip-version-check"],
        check=True,
    )
    _report_nihdl_version(scripts_dir)


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
        _install_packages([sys.executable, "-m", "pip"], packages, Path(sys.executable).parent)
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

    _install_packages([str(venv_pip)], packages, venv_pip.parent)


if __name__ == "__main__":
    main()
