"""Set up Python environment and install packages from dependencies.toml.

Usage:
    python nisetup.py              # Create/reuse .venv and install packages
    python nisetup.py --no-venv    # Install packages into current Python (for pipelines)
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:
    try:
        import tomli as tomllib
    except ModuleNotFoundError:
        tomllib = None  # Fall back to _load_string_arrays on Python < 3.11 without tomli.


def _load_string_arrays(toml_path, keys):
    """Minimal reader for top-level ``key = ["a", "b"]`` string arrays.

    Used only when neither tomllib (3.11+) nor tomli is available, so nisetup can
    still bootstrap on older Pythons. Not a general TOML parser: it handles only
    string arrays and strips ``#`` comments.
    """
    lines = []
    for line in Path(toml_path).read_text(encoding="utf-8").splitlines():
        hash_index = line.find("#")
        if hash_index != -1:
            line = line[:hash_index]
        lines.append(line)
    text = "\n".join(lines)
    result = {}
    for key in keys:
        match = re.search(rf"{re.escape(key)}\s*=\s*\[(.*?)\]", text, re.DOTALL)
        result[key] = re.findall(r'"([^"]*)"', match.group(1)) if match else []
    return result


def _read_config(toml_path):
    """Read python dependencies and supported interpreter versions from dependencies.toml."""
    if tomllib is not None:
        with open(toml_path, "rb") as f:
            data = tomllib.load(f)
    else:
        data = _load_string_arrays(toml_path, ("python_dependencies", "python_supported"))
    return {
        "packages": data.get("python_dependencies", []),
        "supported": data.get("python_supported", []),
    }


def _minor(version):
    """Return the 'X.Y' prefix of a version string (e.g. '3.11.8' -> '3.11')."""
    return ".".join(version.split(".")[:2])


def _pyenv_root():
    """Return the pyenv-win root directory from the environment, or the default location."""
    for var in ("PYENV_ROOT", "PYENV", "PYENV_HOME"):
        value = os.environ.get(var)
        if value:
            return Path(value)
    return Path.home() / ".pyenv" / "pyenv-win"


def _pyenv_installed_versions():
    """Return (version_name, interpreter_path) for every pyenv-installed version.

    Reads the pyenv ``versions`` directory directly instead of invoking ``pyenv``.
    On Windows ``pyenv`` is a ``.bat`` shim that ``subprocess`` cannot launch
    (CreateProcess does not resolve PATHEXT), so shelling out silently finds
    nothing.
    """
    versions_dir = _pyenv_root() / "versions"
    if not versions_dir.exists():
        return []
    found = []
    for entry in versions_dir.iterdir():
        exe = entry / "python.exe"
        if not exe.exists():
            exe = entry / "bin" / "python"
        if exe.exists():
            found.append((entry.name, str(exe)))
    return found


def _py_launcher_versions():
    """Return (version, interpreter_path) for pythons known to the Windows 'py' launcher.

    This finds regular python.org installs on machines that do not use pyenv.
    """
    py = shutil.which("py")
    if not py:
        return []
    try:
        result = subprocess.run([py, "-0p"], capture_output=True, text=True)
    except OSError:
        return []
    found = []
    for line in result.stdout.splitlines():
        version = re.search(r"-V:(\d+\.\d+)", line)
        path = re.search(r"[A-Za-z]:\\.*python\.exe", line, re.IGNORECASE)
        if version and path:
            found.append((version.group(1), path.group(0)))
    return found


def _installed_supported():
    """Return (version_name, interpreter_path) for interpreters pyenv or the py launcher know about."""
    return _pyenv_installed_versions() + _py_launcher_versions()


def _resolve_interpreter(supported):
    """Return (interpreter_path, version) for a supported Python, or exit with instructions.

    Order of preference: the active interpreter (if supported), then the newest
    supported version found via pyenv or the Windows 'py' launcher. pyenv is NOT
    required — a plain python.org install is discovered through the 'py' launcher.
    """
    current = ".".join(map(str, sys.version_info[:3]))
    if _minor(current) in supported:
        return sys.executable, current
    best = None
    for name, exe in _installed_supported():
        if _minor(name) not in supported:
            continue
        key = tuple(int(part) for part in name.split(".") if part.isdigit())
        if best is None or key > best[0]:
            best = (key, exe, name)
    if best:
        return best[1], best[2]
    _exit_no_supported_python(supported)


def _exit_no_supported_python(supported):
    """Print beginner-friendly install instructions and exit."""
    versions = ", ".join(supported)
    example = f"{supported[-2] if len(supported) >= 2 else supported[-1]}.0"
    print(
        f"\nERROR: nisetup could not find a Python version this repo supports.\n"
        f"       Supported versions: {versions}\n\n"
        f"       Do EITHER option below, then run  nisetup  again:\n\n"
        f"       Option 1 - regular Python (simplest, no pyenv needed):\n"
        f"         1. Download Python {example} from https://www.python.org/downloads/\n"
        f"         2. Run the installer and CHECK the box\n"
        f'            "Add python.exe to PATH" on the first screen.\n\n'
        f"       Option 2 - pyenv (if your machine uses it):\n"
        f"         1. pyenv install {example}\n"
        f"         2. pyenv global {example}     <-- REQUIRED: this step selects the version\n"
        f"         3. pyenv rehash\n"
        f"         4. Confirm with:  python --version   (should show {example})\n"
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
        existing = _venv_version(venv_dir)
        if not existing or _minor(existing) not in supported:
            print(
                f"Existing .venv (Python {existing or 'unknown'}) is not a supported version "
                f"({', '.join(supported)}); recreating ..."
            )
            shutil.rmtree(venv_dir, ignore_errors=True)
        else:
            print(f"Reusing existing .venv (Python {existing}).")

    if not _venv_python(venv_dir).exists():
        if supported:
            interpreter, chosen_version = _resolve_interpreter(supported)
        else:
            interpreter = sys.executable
            chosen_version = ".".join(map(str, sys.version_info[:3]))
        print(f"\nCreating virtual environment in .venv using Python {chosen_version} ...")
        prompt_name = repo_root.resolve().name
        subprocess.run(
            [str(interpreter), "-m", "venv", str(venv_dir), "--prompt", prompt_name],
            check=True,
        )

    venv_pip = _venv_pip(venv_dir)
    _install_packages([str(venv_pip)], packages, venv_pip.parent)
    print(f"\nEnvironment ready: Python {_venv_version(venv_dir) or 'unknown'} in .venv")


if __name__ == "__main__":
    main()
