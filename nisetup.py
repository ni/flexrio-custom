"""Set up Python environment and install packages from dependencies.toml.

Usage:
    python nisetup.py              # Create/reuse .venv and install packages
    python nisetup.py --no-venv    # Install packages into current Python (for pipelines)
"""

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib


def _read_config(toml_path):
    """Read python dependencies and supported interpreter versions from dependencies.toml."""
    with open(toml_path, "rb") as f:
        data = tomllib.load(f)
    return {
        "packages": data.get("python_dependencies", []),
        "supported": data.get("python_supported", []),
    }


def _minor(version):
    """Return the 'X.Y' prefix of a version string (e.g. '3.11.8' -> '3.11')."""
    return ".".join(version.split(".")[:2])


def _pyenv_installed_versions():
    """Return (version_name, interpreter_path) for every pyenv-installed version."""
    try:
        root = subprocess.run(["pyenv", "root"], capture_output=True, text=True).stdout.strip()
    except OSError:
        return []
    versions_dir = Path(root) / "versions" if root else None
    if not versions_dir or not versions_dir.exists():
        return []
    found = []
    for entry in versions_dir.iterdir():
        exe = entry / "python.exe"
        if not exe.exists():
            exe = entry / "bin" / "python"
        if exe.exists():
            found.append((entry.name, str(exe)))
    return found


def _resolve_interpreter(supported):
    """Return an interpreter whose minor version is supported, or exit with instructions."""
    current = ".".join(map(str, sys.version_info[:3]))
    if _minor(current) in supported:
        return sys.executable
    # Prefer the newest pyenv-installed version whose minor is supported.
    best = None
    for name, exe in _pyenv_installed_versions():
        if _minor(name) not in supported:
            continue
        key = tuple(int(part) for part in name.split(".") if part.isdigit())
        if best is None or key > best[0]:
            best = (key, exe)
    if best:
        return best[1]
    print(
        f"\nERROR: No supported Python is installed. This repo supports "
        f"{', '.join(supported)}.\n"
        f"       Install one of those versions (e.g. `pyenv install {supported[-1]}.x`) "
        f"and re-run nisetup.\n"
    )
    sys.exit(1)


def _venv_python(venv_dir):
    """Return the interpreter path inside a venv for the current platform."""
    if os.name == "nt":
        return venv_dir / "Scripts" / "python.exe"
    return venv_dir / "bin" / "python"


def _venv_pip(venv_dir):
    """Return the pip path inside a venv for the current platform."""
    pip = venv_dir / "Scripts" / "pip.exe"
    if not pip.exists():
        pip = venv_dir / "bin" / "pip"
    return pip


def _venv_version(venv_dir):
    """Return the 'X.Y.Z' Python version recorded in the venv's pyvenv.cfg, or None."""
    cfg = venv_dir / "pyvenv.cfg"
    if not cfg.exists():
        return None
    for line in cfg.read_text().splitlines():
        if line.strip().startswith("version"):
            return line.split("=", 1)[1].strip()
    return None


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

    config = _read_config(deps_file)
    packages = config["packages"]
    if not packages:
        print("ERROR: No python_dependencies found in dependencies.toml.")
        sys.exit(1)
    supported = config["supported"]

    if args.no_venv:
        # Pipeline mode: install directly into the current Python (CI selects the version).
        current = ".".join(map(str, sys.version_info[:3]))
        if supported and _minor(current) not in supported:
            print(f"ERROR: current Python {current} is not supported ({', '.join(supported)}).")
            sys.exit(1)
        print(f"Using: Python {current}")
        _install_packages([sys.executable, "-m", "pip"], packages, Path(sys.executable).parent)
        return

    # Local dev mode: create/reuse a venv built from a supported interpreter.
    venv_dir = repo_root / ".venv"

    # Recreate the venv if it is built from an unsupported Python version.
    if venv_dir.exists() and supported:
        current = _venv_version(venv_dir)
        if not current or _minor(current) not in supported:
            print(
                f"Existing .venv (Python {current or 'unknown'}) is not a supported version "
                f"({', '.join(supported)}); recreating ..."
            )
            shutil.rmtree(venv_dir, ignore_errors=True)

    if not _venv_python(venv_dir).exists():
        interpreter = _resolve_interpreter(supported) if supported else sys.executable
        print("\nCreating virtual environment in .venv ...")
        prompt_name = repo_root.resolve().name
        subprocess.run(
            [str(interpreter), "-m", "venv", str(venv_dir), "--prompt", prompt_name],
            check=True,
        )

    venv_pip = _venv_pip(venv_dir)
    _install_packages([str(venv_pip)], packages, venv_pip.parent)


if __name__ == "__main__":
    main()
