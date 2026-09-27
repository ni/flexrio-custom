# Troubleshooting / FAQ

Workflow-level issues hit while building and running custom FlexRIO targets. For the tool's
own command/setting details, see the
[LabVIEW FPGA HDL Tools](https://github.com/ni/labview-fpga-hdl-tools) reference.

---

## Setup & environment

**`nihdl` isn't found / the environment isn't active.**
Run `nisetup` in the target folder first. It works in both **Command Prompt** and
**PowerShell** (PowerShell is VS Code's default terminal). You'll see `(flexrio-custom)` in
the prompt when active, and you must re-run `nisetup` in every new terminal.

**Which NI Package Manager modules do I install?**
LabVIEW, **LabVIEW FPGA Module**, **LabVIEW FPGA Compilation Tool for Vivado** (2021.1), and
**FlexRIO** (2026 Q3+). "LabVIEW FPGA" is not a Package Manager entry by that exact name —
it's the **LabVIEW FPGA Module**. See [System Setup](../README.md#system-setup).

**Do I need to clone `flexrio`, `flexrio-deps`, `flexrio-clips`, `hdl-shared`?**
No. `nihdl install-deps` clones them into `deps/` for you.

---

## Building the bitfile (Vivado flow)

**`nihdl gen-vivado` errors on a folder I copied from another exercise.**
A copied target folder can already contain a generated Vivado project. Re-run with
**`nihdl gen-vivado --overwrite`** to regenerate it (this also re-runs `gen-hdl`/`gen-xdc`).
Use `--update` to refresh an existing project in place.

**`nihdl gen-vivado --overwrite` fails and `vivado.log` is empty.**
An empty `vivado.log` usually means Vivado never launched. Check that:
- `nisetup` is active and `nihdl` runs (`nihdl --help`).
- `nihdl install-deps` completed for this target (missing deps break project generation).
- Vivado is installed and the tools path is configured for the target.
Then re-run with `-v` (`nihdl -v gen-vivado --overwrite`) to see inline step detail. If it
still fails, capture the verbose output for a bug report.

**`launch-vivado` / `check-vivado` / `compile-vivado` can't find the project.**
Run `nihdl gen-vivado --overwrite` first — these require an existing `.xpr`.

---

## Running the host VI

**LabVIEW prompts for a missing `niLvFpga_Open_<target>.vi`, or I get Error 7 at run time.**
You opened the bitfile with **Open FPGA VI Reference**, which custom targets don't support.
Use **Open Dynamic Bitfile Reference** instead, and configure the Refnum via **Import from
bitfile**. Full steps: [Talk to the bitfile from a host VI](HostVIsAndBitfiles.md).

**The host example can't locate `NiFPGA_HdlFifo_*.vi` (or other helper VIs).**
Those helper VIs come from the installed dependencies under `deps/`. Run
`nihdl install-deps`, then point LabVIEW at the helper under the target's `deps/` folder or
add it to your VI search path. See
[Talk to the bitfile from a host VI → helper VIs](HostVIsAndBitfiles.md#if-the-example-cant-find-its-helper-vis).

---

## LabVIEW FPGA target flow

**Which LabVIEW version do I need to compile in LabVIEW FPGA?**
The LabVIEW FPGA target flow (build the bitfile *in LabVIEW FPGA*) needs **LabVIEW 2026 or
newer**. The HDL-only Vivado flow works with LabVIEW 2023+.

**After `install-target`, LabVIEW doesn't show the custom target.**
LabVIEW only scans for target plugins **at startup**. Close all LabVIEW instances before
`nihdl install-target`, then (re)start LabVIEW.

---

## Simulation (ModelSim)

**ModelSim simulation doesn't run.**
The ModelSim flow requires **ModelSim to be installed** — `nihdl` cannot install it. If you
don't have ModelSim, skip the simulation exercise; every other exercise works without it.

---

## Still stuck?

Use the repo's [Issues](https://github.com/ni/flexrio-custom/issues) and
[Discussions](https://github.com/ni/flexrio-custom/discussions). Include the failing command
run with `-v`, your OS/LabVIEW/Vivado versions, and the target folder you ran from.
