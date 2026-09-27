# Getting Started

> **← Haven't set up yet?** Do the one-time [System Setup](../README.md#system-setup) first
> — clone the repo and run `nihdl install-deps`. Then, **every time you open a new terminal**,
> run `nisetup` from the target folder to activate the environment and put `nihdl` on the
> command-line path (you'll see `(flexrio-custom)` in the prompt). The exercises below repeat
> this `nisetup` reminder where you need it.

## Recommended reading first

Before the exercises, skim these to understand *why* the tools work the way they do:

- [LabVIEW FPGA HDL Tools — Theory of Operation](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/TheoryOfOperation.md) — the architecture and the two compile flows.
- [LabVIEW FPGA HDL Tools — README](https://github.com/ni/labview-fpga-hdl-tools/blob/main/README.md) — orientation for the `nihdl` toolchain. **Treat its Quickstart as reference only** — the canonical commands for this repo are the exercises below, so you don't need to run the tool README's quickstart separately.
- [Dependencies and File Management](DependenciesAndFileManagement.md) — how a custom target is assembled from the base FlexRIO target and its dependencies: which files you copy and modify versus reference in place, and what each file list (`vivadoprojectsources.txt`, `vivadoprojectdeps.txt`, `lvtargetexcludefiles.txt`) is for.

**What you'll achieve:** build a FlexRIO bitfile and customize your own target. There are
**two ways** to customize — they are alternatives, so pick the one you need:

- **HDL-only (Exercise 1)** — customize in HDL and build the bitfile in Vivado; talk to the
  host over registers/DMA FIFOs. No LabVIEW FPGA VI in the stack.
- **Custom LabVIEW FPGA target (Exercise 2)** — package your HDL as a custom target and
  compile the bitfile in LabVIEW FPGA (requires LabVIEW 2026+).

**Exercise 3** migrates an existing socketed CLIP into the top-level HDL — for when you're
starting from a CLIP you already have.

See the [Theory of Operation](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/TheoryOfOperation.md) for the difference between the two compile flows.

> **End-to-end walkthroughs.** For a page that pulls together the commands and
> settings for each flow, see
> [Vivado Compile Flow](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/VivadoCompileFlow.md),
> [LabVIEW FPGA Target and Compile Flow](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/LabVIEWFpgaTargetFlow.md),
> and [ModelSim Simulation Flow](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/ModelSimSimulationFlow.md).
>
> **Simulation (ModelSim) is optional** — it only verifies a testbench and requires ModelSim
> to be installed. If you don't have ModelSim, skip it.

## Where you add your HDL: `rtl-lvfpga/UserHdl.vhd`

[`rtl-lvfpga/UserHdl.vhd`](../targets/pxie-7903custom/rtl-lvfpga/UserHdl.vhd) is the entity you extend with your custom HDL. Add your logic in its architecture body (between `begin` and `end architecture rtl`), and communicate with the host PC through the **register** and **DMA FIFO** ports on its entity. The rest of the target connects `UserHdl` to the host and to LabVIEW FPGA. The exercises below cover building and installing the target.

The register and DMA-FIFO blocks you wire up in `UserHdl` come from
**[hdl-shared](https://github.com/ni/hdl-shared)** — see its
[register](https://github.com/ni/hdl-shared/blob/main/host_interfaces/register/docs/instantiation-guide.md)
and [DMA-FIFO](https://github.com/ni/hdl-shared/blob/main/host_interfaces/fifo/docs/instantiation-guide.md)
instantiation guides.

## Exercise 1 - Build a bitfile (HDL-only flow)

> **Before you start:** complete the one-time [System Setup](../README.md#system-setup)
> (clone the repo and run `nihdl install-deps`) if you haven't yet.

### 1) Go to the custom target folder
> cd C:\dev\github\flexrio-custom\targets\pxie-7903custom

### 2) Activate the environment (run this in every new terminal)
> nisetup

This activates the Python environment and puts `nihdl` on the command-line path for this
session — you'll see `(flexrio-custom)` in the prompt. It is **not** a one-time step: run
`nisetup` again every time you open a new terminal.

### 3) Create a Vivado Project
> nihdl gen-vivado

### 4) Launch Vivado
> nihdl launch-vivado

### 5) Build a bitfile
In Vivado, click **Generate Bitstream** in the left-hand tools menu.

## Exercise 2 - Create a custom LabVIEW FPGA target
### 1) Make a copy of the custom target folder
Copy `targets/pxie-7903custom` to a new folder, for example:
> C:\dev\github\flexrio-custom\targets\pxie-7903custom-mycopy

Then `cd` into the copy and run `nisetup` (every new terminal) so `nihdl` is on the path:
> cd C:\dev\github\flexrio-custom\targets\pxie-7903custom-mycopy

> nisetup

### 2) Edit the nihdlsettings.py file in pxie-7903custom-mycopy
Set `set_lv_target_name(...)` to `PXIe-7903custom-mycopy`

Run `nihdl gen-guid` to generate a new GUID

Copy the new GUID into the `set_lv_target_guid(...)` call

### 3) Add your HDL in `rtl-lvfpga/UserHdl.vhd`
[`rtl-lvfpga/UserHdl.vhd`](../targets/pxie-7903custom/rtl-lvfpga/UserHdl.vhd) is the entity you extend with your custom HDL. Add your logic in its architecture body (between `begin` and `end architecture rtl`); its entity exposes the host **register** and **DMA FIFO** ports for communicating with the host PC. Those register and FIFO blocks (for example `NiSharedCommonHostRegs`) come from **[hdl-shared](https://github.com/ni/hdl-shared)** — see its [register](https://github.com/ni/hdl-shared/blob/main/host_interfaces/register/docs/instantiation-guide.md) and [DMA-FIFO](https://github.com/ni/hdl-shared/blob/main/host_interfaces/fifo/docs/instantiation-guide.md) instantiation guides.

As a first change to confirm your build loaded, open `rtl-lvfpga/UserHdl.vhd`, find `NiSharedCommonHostRegs_inst`, and set `kSignature` to `x"7903FEED"`.

### 4) Create a Vivado project
> nihdl gen-vivado --overwrite

Use `--overwrite` here: you copied `pxie-7903custom`, which may already contain a generated
Vivado project, and a plain `nihdl gen-vivado` will stop and ask for `--overwrite` (or
`--update`). See [Troubleshooting](Troubleshooting.md#building-the-bitfile-vivado-flow).

### 5) Build a bitfile with the Vivado flow
> nihdl launch-vivado

In Vivado, click **Generate Bitstream**. When it finishes, the packaging step
(`gen-lvbitx`) produces a `.lvbitx` you can use from a host VI (Step 8). *(You can also run
`nihdl compile-vivado` instead of launching Vivado interactively.)*

### 6) Generate and install the custom LabVIEW FPGA target
> nihdl gen-target

Close **all** LabVIEW instances before installing:

> nihdl install-target

After installing, (re)start LabVIEW so it picks up the new target — LabVIEW only scans for
target plugins at startup.

### 7) (LabVIEW FPGA compile flow) Build a bitfile in LabVIEW FPGA
This is the alternative to Step 5: instead of compiling in Vivado yourself, let **LabVIEW
FPGA** compile the bitfile (it drives Vivado under the hood). Requires **LabVIEW 2026 or
newer**.

1. In LabVIEW, create a new **FPGA project** and add your installed custom target (it
   appears under the FlexRIO devices in the **new FPGA target** dialog).
2. Add your VI, plus the custom I/O and host interfaces, under the target.
3. Under the target's **Build Specifications**, create or select the FPGA build, then
   right-click → **Build**. LabVIEW FPGA runs the compile and writes a `.lvbitx` to the
   build-specification output.

For the full walkthrough and settings, see
[LabVIEW FPGA Target and Compile Flow](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/LabVIEWFpgaTargetFlow.md).

### 8) Test the target from a host VI
Download and run the bitfile from a LabVIEW FPGA host VI using the NI-RIO API. Open the
shipped example:

> flexrio-custom\targets\pxie-7903custom\docs\Examples\LV2023\HostExample

> **Open the bitfile with _Open Dynamic Bitfile Reference_ and configure its Refnum via
> _Import from bitfile_.** The standard **Open FPGA VI Reference** node does **not** work
> with custom targets. Full steps — including fixes for the "missing `niLvFpga_Open_<target>.vi`"
> / Error 7 symptoms and for linking the example's helper VIs — are in
> **[Talk to the bitfile from a host VI](HostVIsAndBitfiles.md)**.

Use the following register map for the common registers:

| Register | Offset | Access |
| --- | ---: | --- |
| kSignatureOffset | 0 | read-only |
| kVersionOffset | 4 | read-only |
| kOldestCompatibleVersionOffset | 8 | read-only |
| kScratchOffset | 12 | read-write |

## Exercise 3 - Migrate a socketed CLIP into the top-level HDL
When you're customizing in HDL and starting from an existing socketed CLIP, you instantiate
the CLIP directly in the top-level HDL instead of dropping it into a LabVIEW FPGA CLIP socket.
The [CLIP Migration Hands-On Guide](CLIPMigrationHandsOnGuide.md) walks through how this was
done for the PXIe-7903Aurora example. *(That worked example goes on to expose the result as a
custom LabVIEW FPGA target, but the migration technique itself is what brings your existing
CLIP into the HDL flow.)*
