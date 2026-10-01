# Customizing a FlexRIO Board

The high-level map of *what you are actually customizing* and the **two ways** to do it, plus
the per-device **IO Module IDs**. New here? Start at the
[flexrio-custom README](../README.md) and the [Getting Started exercises](GettingStarted.md);
read this when you want the concepts behind them.

> **Creating a brand-new baseboard target?** To stand up a new `<device>custom` example from a
> released base target (file-by-file), see
> [Creating a FlexRIO Baseboard Custom Target](CreatingABaseboardCustomTarget.md).

> **Where your HDL goes: [`rtl-lvfpga/UserHdl.vhd`](../targets/pxie-7903custom/rtl-lvfpga/UserHdl.vhd).** In every target, `UserHdl.vhd` is the entity you extend with your custom logic. Its ports expose the host registers and DMA FIFOs (and the board IO), so it is where you implement your design and connect it to the host. The rest of a target — the top-level wrapper, the LabVIEW FPGA window, the register/FIFO plumbing, and the build and target-generation files — is scaffolding that supports it. A natively supported FlexRIO target can only be extended in a LabVIEW FPGA VI; a custom target gives you this HDL entity to own directly.

## Background: integrated IO and the socketed CLIP (the pre-HDL-workflow model)

A FlexRIO device with **integrated IO** is a **baseboard + an IO module** built into one product. To make that device do anything, it needs HDL that knows how to run the integrated IO module (the high-speed serial link, the digital IO, etc.).

Before the HDL workflow, that HDL was delivered as a **socketed CLIP** — a block of VHDL you dropped into a **CLIP socket** in a LabVIEW FPGA project. So:

* **baseboard + IO module = integrated IO FlexRIO device**
* **integrated IO device + socketed CLIP VHDL = working design**

On top of the CLIP you wrote a **LabVIEW FPGA VI** that talked to the CLIP node, plus a **host VI** that talked to the FPGA. NI's *Getting Started FlexRIO Integrated IO* example generator produced exactly this vertical stack (socketed CLIP + FPGA VI + host VI) for each supported IO-module permutation.

With that model you had two ways to change the behavior:

* **Modify the CLIP VHDL** directly. This was rarely done and never fully documented — you had to read the CLIP source and its comments and rely on being an expert in the underlying bus.
* **Leave the CLIP as-is and extend it in LabVIEW FPGA.** Most people did this: they took the example FPGA VI, studied its comments, and adapted the LabVIEW logic to their application.

## What this repo gives you instead

The new HDL workflow (`flexrio-custom` + [`labview-fpga-hdl-tools`](https://github.com/ni/labview-fpga-hdl-tools)) ships the pieces, not a pre-wired vertical example for every permutation:

* **The baseboard top-level FPGA (HDL) file**, with a blank **`UserHdl`** entity where your custom HDL goes.
* **The CLIPs as-is** — the same VHDL used by the socketed LabVIEW FPGA CLIP, delivered through [`flexrio-clips`](https://github.com/ni/flexrio-clips).
* **One worked example** — [`pxie-7903aurora`](../targets/pxie-7903aurora) — that instantiates the socketed Aurora CLIP directly in the top-level HDL, but still wires its LabVIEW-facing signals up to a LabVIEW FPGA VI *as if the CLIP were still in the socket*.

## If you are starting a new project, without an existing socketed CLIP

This is the **greenfield HDL workflow**: you own the design from scratch. The baseboard
custom target hands you a blank
[`UserHdl.vhd`](../targets/pxie-7903custom/rtl-lvfpga/UserHdl.vhd) entity — you write your
logic there and build out its interfaces yourself. There is no CLIP to migrate and no
LabVIEW FPGA VI is required.

`UserHdl` exposes two kinds of interface; you decide which to use.

### Talk to the host directly — registers and DMA FIFOs

This is the primary path: communicate with the NI-RIO driver on the host PC over **host
registers** and **DMA FIFOs**, entirely from HDL. You instantiate the building blocks from
[`hdl-shared`](https://github.com/ni/hdl-shared) inside `UserHdl`:

- **Registers** (control/status). Use `NiSharedCommonHostRegs` — a fixed Signature / Version /
  Oldest-Compatible-Version / Scratch identity block the host reads at bring-up — plus one or
  more `NiSharedHostRegisterArray` banks for your own control/status registers. The register
  space you may use is bounded by `set_max_hdl_reg_offset` (a register placed outside it fails
  elaboration instead of silently colliding with LabVIEW FPGA's register space). See the
  [register instantiation guide](https://github.com/ni/hdl-shared/blob/main/host_interfaces/register/docs/instantiation-guide.md).
- **DMA FIFOs** (high-throughput streaming to/from host memory). Declare each channel — depth,
  data type, direction — in `PkgUserHdl` and reserve the channel count with
  `set_num_hdl_fifos`, then instantiate `NiSharedFifoWriter` (FPGA → host) and
  `NiSharedFifoReader` (host → FPGA). See the
  [DMA-FIFO instantiation guide](https://github.com/ni/hdl-shared/blob/main/host_interfaces/fifo/docs/instantiation-guide.md).

You compile the bitfile in Vivado and open the resulting `.lvbitx` from the host with the
NI-RIO API (or a thin LabVIEW FPGA host VI) — see
[Talk to the bitfile from a host VI](HostVIsAndBitfiles.md). No LabVIEW FPGA VI runs on the
FPGA in this path.

### Drive the board's physical I/O

Your logic also drives the board's real I/O (DIO, and on some boards MGT / high-speed serial).
Because a custom target disables board I/O on the LabVIEW window
(`set_include_board_io_on_lv_window(False)`), those interfaces are routed straight into
`UserHdl`'s ports for you to drive from HDL. See [Digital IO](DigitalIO.md) for the per-target
interface styles.

### (Optional) Expose signals to a LabVIEW FPGA window

If you also want part of the design reachable from a **LabVIEW FPGA VI** (a hybrid design), you
can surface custom signals on the LabVIEW FPGA window instead of — or alongside — the direct
register/FIFO path. Declare them in the target's
[`LVTargetBoardIO.csv`](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/LVTargetCustomIO-Reference.md):
each row becomes a port on the generated `TheWindow` component and an I/O node in the LabVIEW
FPGA project. You wire those window ports to your `UserHdl` logic in the top-level HDL, and a
LabVIEW FPGA VI can then read and write them from the block diagram. Leave the CSV header-only
if you don't need this.

**Use this when** you are designing new IP in HDL and want to own the host interface (and,
optionally, a LabVIEW FPGA window) yourself.

**Worked examples:** the plain `<device>custom` targets — e.g.
[`pxie-7912custom`](../targets/pxie-7912custom) — ship a `UserHdl` that already demonstrates
the identity + control/status registers, register loopbacks, DMA-FIFO loopbacks, and DIO. Copy
one and replace the example logic with your own. To stand up a brand-new baseboard target from
a released base target, see
[Creating a FlexRIO Baseboard Custom Target](CreatingABaseboardCustomTarget.md).

## If you are starting from an existing socketed CLIP, there are two ways to integrate that HDL into the custom FlexRIO target

Socketed CLIPs only had signal ports between the HDL and the LabVIEW FPGA VI IO Nodes.  All communication to between the socketed CLIP and the Host had to go through those IO Node ports and then through LabVIEW FPGA host interfaces.  If you are reusing existing socketed CLIP IP, you can choose to keep the same LabVIEW interfaces or rework the CLIP HDL to talk directly to the host.

### Option 1 — Migrate a socketed CLIP, keep the same LabVIEW interface

Take an existing socketed CLIP and instantiate it in your top-level `UserHdl`, then reconnect its **LabVIEW-facing** ports so the design still exposes the same interface to a LabVIEW FPGA VI. The CLIP HDL moves out of the LabVIEW window and into the top-level HDL, but *the HDL-to-LabVIEW interface you had before is unchanged* — you keep writing your application in a LabVIEW FPGA VI.

**A complete worked example of this ships in this repo:**
[`pxie-7903aurora`](../targets/pxie-7903aurora) migrates the socketed Aurora CLIP into the
PXIe-7903's top-level HDL while keeping its original LabVIEW interface. The
[CLIP Migration Hands-On Guide](CLIPMigrationHandsOnGuide.md) walks through exactly how it was
built (also walked through as Exercise 4 in [Getting Started](GettingStarted.md)).

**Use this when** you want the new HDL packaging/build flow but still want to do your application logic in LabVIEW FPGA.

### Option 2 — Move your logic into HDL and talk to the host directly (the HDL-only workflow)

Start from the same socketed CLIP HDL, but instead of re-exposing its LabVIEW ports, **build onto those ports inside `UserHdl` yourself**. Do in VHDL whatever you would previously have done in a LabVIEW FPGA VI, and communicate with the host using the HDL workflow's **host registers and DMA FIFOs** (from [`hdl-shared`](https://github.com/ni/hdl-shared) — see its [register](https://github.com/ni/hdl-shared/blob/main/host_interfaces/register/docs/instantiation-guide.md) and [DMA-FIFO](https://github.com/ni/hdl-shared/blob/main/host_interfaces/fifo/docs/instantiation-guide.md) instantiation guides). No LabVIEW FPGA VI is required at all — you compile the bitfile in Vivado and talk to it from the NI-RIO driver on the host.

This is the **primary use case** of `flexrio-custom`: customers who want the integrated IO business logic packaged so they can extend it **in VHDL**, not in LabVIEW. There is **no bespoke example of this yet** — it is the piece a domain/subject-matter expert fills in for a given IO module — but the CLIP source, the blank `UserHdl`, and the host register/FIFO interfaces are all here to build it on.

**Use this when** you want an HDL-only design with no LabVIEW FPGA VI in the stack.

> **How do I know what's inside the CLIP?** The CLIP VHDL is not formally documented — its behavior is described by the comments in the CLIP source itself, and interpreting it assumes familiarity with the underlying high-speed bus. See [Dependencies and File Management](DependenciesAndFileManagement.md) for where the CLIP source lives and how it is pulled into a target, and [Digital IO](DigitalIO.md) for the board IO interfaces routed into `UserHdl`.

## Customizing IO Module Devices

Modules with integrated IO use an IO Module ID (also called Terminal Block ID or TbId in the VHDL) to ensure that the LabVIEW FPGA CLIP node is compatible with the device.  When customizing the device in VHDL, use this IO Module ID to ensure that the integrated IO is enabled.

### IO Module IDs

| Device | IO Module ID |
| --- | --- |
| PXIe-7903 | 0x10937AEC |
| PXIe-7903-DDR1280 | 0x10937AEC |
| PXIe-7911 | none |
| PXIe-7912 | none |
| PXIe-7915 | none |
| PXIe-6593 KU40 | 0x109379F9 |
| PXIe-6593 KU60 | 0x109379F9 |
| PXIe-6594 | 0x109379FC |
| PXIe-7890 | 0x10937AA7 |
| PXIe-7891 | 0x10937AA8 |
