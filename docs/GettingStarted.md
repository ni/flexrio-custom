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

**What you'll achieve:** build a FlexRIO bitfile, customize your own target, and talk to the
bitfile from the host. There are **two ways** to get a bitfile — they are alternatives, so
pick the one you need. Both end with a `.lvbitx`:

- **HDL-only (Exercise 1)** — customize in HDL and build the bitfile in Vivado. No LabVIEW
  FPGA VI in the stack.
- **Custom LabVIEW FPGA target (Exercise 2)** — package your HDL as a custom target and
  compile the bitfile in Vivado or LabVIEW FPGA (requires LabVIEW 2026+).

**Exercise 3** tests the bitfile from either path: open it from a LabVIEW host VI with the
NI-RIO API and read/write its registers and DMA FIFOs.

**Exercise 4** migrates an existing socketed CLIP into the top-level HDL — for when you're
starting from a CLIP you already have.

**Exercise 5 (optional)** simulates the target's testbench in ModelSim — **only** if you
already have a licensed ModelSim install. ModelSim is **not** part of LabVIEW FPGA.

See the [Theory of Operation](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/TheoryOfOperation.md) for the difference between the two compile flows.

> **End-to-end walkthroughs.** For a page that pulls together the commands and
> settings for each flow, see
> [Vivado Compile Flow](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/VivadoCompileFlow.md),
> [LabVIEW FPGA Target and Compile Flow](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/LabVIEWFpgaTargetFlow.md),
> and [ModelSim Simulation Flow](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/ModelSimSimulationFlow.md).
>
> **Simulation (ModelSim) is optional** — it only verifies a testbench and requires a
> licensed ModelSim install, which is **not** included with LabVIEW FPGA. If you don't have
> ModelSim, skip [Exercise 5](#exercise-5-optional---simulate-the-testbench-in-modelsim).

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
In Vivado, click **Generate Bitstream** in the left-hand tools menu. *(You can also run
`nihdl compile-vivado` instead of launching Vivado interactively.)*

When the bitstream finishes, a post-bitstream step automatically runs `nihdl gen-lvbitx` to
package it as a LabVIEW FPGA bitfile:

> targets\pxie-7903custom\objects\bitfiles\SasquatchTopTemplate.lvbitx

That `.lvbitx` is the result of this exercise. Next, test it from a host VI in
[Exercise 3](#exercise-3---test-the-bitfile-from-a-host-vi-ni-rio-api).

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
(`gen-lvbitx`) writes the bitfile to `objects\bitfiles\SasquatchTopTemplate.lvbitx` in your
target folder. *(You can also run `nihdl compile-vivado` instead of launching Vivado
interactively.)*

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

Either Step 5 or Step 7 leaves you with a `.lvbitx` — the result of this exercise. Next, test
it from a host VI in [Exercise 3](#exercise-3---test-the-bitfile-from-a-host-vi-ni-rio-api).

## Exercise 3 - Test the bitfile from a host VI (NI-RIO API)
Download the bitfile from Exercise 1 or 2 to your FlexRIO device and talk to its registers
and DMA FIFOs from a LabVIEW host VI through the NI-RIO driver.

**You need:**
- The `.lvbitx` from [Exercise 1](#exercise-1---build-a-bitfile-hdl-only-flow) or
  [Exercise 2](#exercise-2---create-a-custom-labview-fpga-target).
- The FlexRIO device installed in the host system, with the NI-RIO driver installed.
- LabVIEW 2023 or newer (the shipped example is saved in LabVIEW 2023).
- `nihdl install-deps` already run for the target — the example's helper VIs come from
  the installed dependencies.

### 1) Find your bitfile
- **Vivado build** (Exercise 1, or Exercise 2 Step 5):
  `objects\bitfiles\SasquatchTopTemplate.lvbitx` in the target folder.
- **LabVIEW FPGA build** (Exercise 2 Step 7): the output folder of the FPGA build
  specification.

### 2) Find the device's RIO resource name
Open **NI MAX**, expand **Devices and Interfaces**, and select your FlexRIO device. Note its
resource name (for example `RIO0`) — that's the device address the host VI opens.

### 3) Open the shipped host example
> flexrio-custom\targets\pxie-7903custom\docs\Examples\LV2023\HostExample\HostExampleWithDio.vi

If LabVIEW can't find a helper VI such as `NiFPGA_HdlFifo_ReadI32.vi`, point it at the copy
under the target's `deps/` folder, or add that folder to **Tools → Options → Paths → VI
Search Path**.

### 4) Point the example at your bitfile and device
On the block diagram, find the **Open Dynamic Bitfile Reference** node and wire:
- **bitfile path** → your `.lvbitx` from Step 1.
- **device address** → the RIO resource from Step 2.

> **Use _Open Dynamic Bitfile Reference_, not _Open FPGA VI Reference_.** The standard
> **Open FPGA VI Reference** node does **not** work with custom targets. If LabVIEW asks you
> to locate `niLvFpga_Open_<target>.vi`, or you get **Error 7** at run time, the wrong node is
> being used.

### 5) Import the refnum interface from your bitfile (required)
The **FPGA Interface Dynamic Refnum** constant wired to the node's **type** input must match
your bitfile's registers and FIFOs:

1. Right-click the refnum constant → **Configure FPGA VI Reference Interface…**.
2. Click **Import from bitfile…** and select your `.lvbitx`.
3. Click **OK**.

Repeat this whenever you change the registers or FIFOs in `UserHdl` and rebuild. This is the
most commonly missed step.

### 6) Run the VI and check the registers
Run the host VI and confirm the bitfile responds:

| Register | Offset | Access | Expected |
| --- | ---: | --- | --- |
| Signature | `0x00` | read-only | `0x7903BEEF` (`0x7903FEED` if you made the Exercise 2 Step 3 change) |
| Version | `0x04` | read-only | `0x00000001` |
| OldestCompatibleVersion | `0x08` | read-only | `0x00000001` |
| Scratch | `0x0C` | read-write | Reads back whatever you write |

Then try the demo loopback: write a value to `LoopbackInA` (`0x10`) and read
`LoopbackOutA` (`0x18`) — it returns your value + 1.

### 7) (Optional) Exercise the DMA FIFOs
- **Writer FIFO (target-to-host, DMA stream 58):** write `0x1` to `WriterStartStop`
  (`0x3C`), write samples to `WriterData` (`0x54`), then read them back over DMA.
- **Reader FIFO (host-to-target, DMA stream 59):** write `0x1` to `ReaderStartStop`
  (`0x40`), write samples over DMA, then write anything to `ReaderStrobe` (`0x58`) to pop one
  and read it from `ReaderData` (`0x5C`).

When you're done, close the reference with **Close FPGA VI Reference**.

The full register and FIFO map is in the target's
[HostInterfaces.md](../targets/pxie-7903custom/docs/HostInterfaces.md). For more detail and
fixes for common errors, see [Talk to the bitfile from a host VI](HostVIsAndBitfiles.md).

## Exercise 4 - Migrate a socketed CLIP into the top-level HDL
When you're customizing in HDL and starting from an existing socketed CLIP, you instantiate
the CLIP directly in the top-level HDL instead of dropping it into a LabVIEW FPGA CLIP socket.
The [CLIP Migration Hands-On Guide](CLIPMigrationHandsOnGuide.md) walks through how this was
done for the PXIe-7903Aurora example. *(That worked example goes on to expose the result as a
custom LabVIEW FPGA target, but the migration technique itself is what brings your existing
CLIP into the HDL flow.)*

## Exercise 5 (optional) - Simulate the testbench in ModelSim

> **Only do this exercise if you already have ModelSim installed and licensed.** ModelSim is
> a third-party (Siemens EDA) simulator — it is **not** included with LabVIEW FPGA or the
> FPGA compile tools, and `nihdl` cannot install or license it for you. Nothing else in this
> guide depends on simulation: if you don't have ModelSim, skip this exercise.

This runs the target's `tb_UserHdl` testbench
([`rtl-lvfpga/testbenches/tb_UserHdl.vhd`](../targets/pxie-7903custom/rtl-lvfpga/testbenches/tb_UserHdl.vhd)),
which exercises `UserHdl`'s common registers, demo registers, and DMA FIFO paths — a quick
functional check before a long Vivado compile.

### 1) Go to the custom target folder and activate the environment
> cd C:\dev\github\flexrio-custom\targets\pxie-7903custom

> nisetup

### 2) Point the target at your ModelSim install
In `nihdlsettings.py`, set `set_modelsim_tools_folder(...)` to your ModelSim install root
(the folder containing `vsim`, `vcom`, and `vlib`). The default is
`C:/modeltech_pe_2020.4`.

### 3) Create the ModelSim project
> nihdl gen-modelsim --overwrite

The **first** run also builds the Xilinx simulation libraries (`unisim`) using Vivado, so it
takes several minutes and needs `set_vivado_tools_folder(...)` to point at a valid Vivado
install. Later runs reuse the libraries and skip that step.

### 4) Run the simulation
> nihdl sim-modelsim

This runs the testbench headlessly and prints a **Simulation Summary**. Look for
`Result:   PASSED`; any testbench error or fatal reports `FAILED` and a nonzero exit code.

### 5) (Optional) Open the simulation in the ModelSim GUI
> nihdl launch-modelsim

Use this to add waveforms and step through the design interactively.

For every setting and option, see
[ModelSim Simulation Flow](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/ModelSimSimulationFlow.md).
If the simulation won't start, see [Troubleshooting](Troubleshooting.md#simulation-modelsim).
