Pre-release custom FlexRIO code for use with LabVIEW FPGA HDL Tools

# What is this? - Core Concepts
* This repository contains examples of customized FlexRIO FPGA devices
* These examples use the LabVIEW FPGA HDL Tools to manage dependencies, create Vivado projects and integrate custom HDL with LabVIEW
    * https://github.com/ni/labview-fpga-hdl-tools
    * https://pypi.org/project/labview-fpga-hdl-tools
* These examples depends on a number of other repositorires that contain FlexRIO and shared HDL source code.  These dependencies are installed (cloned) by the LabVIEW FPGA HDL Tools.
    * https://github.com/ni/flexrio
    * https://github.com/ni/flexrio-deps
    * https://github.com/ni/flexrio-clips
    * https://github.com/ni/hdl-shared
* You can perform workflows for customizing LabVIEW FPGA targets with HDL
    * Use HDL-only and Vivado to build a bitfile and communicate with it from the NI-RIO driver on a host PC
    * Use HDL to make a custom LabVIEW FPGA target that can be extended in LabVIEW FPGA and use the standard LabVIEW FPGA bitfile generation workflow
    * Use LabVIEW FPGA to make a top-level VI that is exported as a netlist and brought into your custom HDL to build in Vivado
* You can communicate between the NI-RIO driver on a host PC and custom HDL directly using
    * Registers
    * DMA FIFOs
* All of this is pre-release and not supported by NI
    * Use the [Issues](https://github.com/ni/flexrio-custom/issues) and [Discussions](https://github.com/ni/flexrio-custom/discussions) sections in this repository to collaborate with the developers and other lead users
<br><br><br>

# Supported Devices

This is the support matrix for the custom HDL workflow, organized the same way FlexRIO
modules are grouped in the LabVIEW **new FPGA target** dialog. For each device it shows
how far the new workflow has come — from a complete worked example, to "you can build it
yourself today," to "not available in the new workflow yet."

**Status definitions**

| Status | Meaning |
| --- | --- |
| ✅ **Supported** | A customizable custom target ships in this repo (for IO-module devices, a complete worked example) — clone it and build. |
| 🟨 **Buildable (no example yet)** | The baseboard custom target **and** the IO-module CLIP are both available, but no bespoke example wires them together. Build it yourself by starting from the baseboard's custom target and following the [CLIP Migration Hands-On Guide](docs/CLIPMigrationHandsOnGuide.md). |
| ⬜ **Not yet supported** | The custom target and/or CLIP is not yet available in the custom HDL workflow. |

## FlexRIO Coprocessor Modules

Coprocessor modules have no integrated IO module, so they need no IO-module CLIP. Each
ships as a customizable custom target — start from its target folder. The **PXIe-7903**
can additionally drive a digital frontend using the **Aurora** or **100 GbE** CLIPs.

| Device | Status |
| --- | --- |
| PXIe-7903 | ✅ Supported — customizable target (Aurora frontend example `pxie-7903aurora`; 100 GbE CLIP available) |
| PXIe-7903-DDR1280 | ✅ Supported — customizable target |
| PXIe-7911 | ✅ Supported — customizable target |
| PXIe-7912 | ✅ Supported — customizable target |
| PXIe-7915 | ✅ Supported — customizable target |

## FlexRIO FPGA Modules

FPGA modules are baseboards with no integrated IO — you add your own IO in `UserHdl`.
Each one now ships as a customizable custom target — start from its target folder. The
**PCIe-798x** rows are the PCIe form-factor (Garrison) equivalents of the Macallan modules;
the **PXIe-799x** rows are the BTrace family (PXIe-7993 is the Blackadder baseboard).

| Device | Status |
| --- | --- |
| PXIe-7981 | ✅ Supported — customizable target |
| PXIe-7982 | ✅ Supported — customizable target |
| PXIe-7985 | ✅ Supported — customizable target |
| PXIe-7986 | ✅ Supported — customizable target |
| PXIe-7990 | ✅ Supported — customizable target |
| PXIe-7991 | ✅ Supported — customizable target |
| PXIe-7992 | ✅ Supported — customizable target |
| PXIe-7993 | ✅ Supported — customizable target |
| PXIe-7994 | ✅ Supported — customizable target |
| PCIe-7981 | ✅ Supported — customizable target |
| PCIe-7982 | ✅ Supported — customizable target |
| PCIe-7985 | ✅ Supported — customizable target |

## FlexRIO Digital Modules

| Device | Baseboard | Status |
| --- | --- | --- |
| PXIe-6569 | PXIe-7991 / PXIe-7992 | 🟨 Buildable — CLIP available, no example yet |

## FlexRIO High-Speed Serial Modules

| Device | Baseboard | Status |
| --- | --- | --- |
| PXIe-6593 (KU40) | PXIe-7982 | 🟨 Buildable — CLIP available, no example yet |
| PXIe-6593 (KU60) | PXIe-7985 | 🟨 Buildable — CLIP available, no example yet |
| PXIe-6594 | PXIe-7986 | 🟨 Buildable — CLIP available, no example yet |

## FlexRIO Multifunction IO Modules

| Device | Baseboard | Status |
| --- | --- | --- |
| PXIe-7890 | PXIe-7994 | 🟨 Buildable — CLIP available, no example yet |
| PXIe-7891 | PXIe-7994 | 🟨 Buildable — CLIP available, no example yet |

## FlexRIO FPD-Link Interface Modules

| Device | Baseboard | Status |
| --- | --- | --- |
| PXIe-1486 / PXIe-1487 | PXIe-7993 | 🟨 Buildable — CLIP available, no example yet |
| PXIe-1488 / PXIe-1489 | PXIe-7993 | 🟨 Buildable — CLIP available, no example yet |

## FlexRIO Digitizer and Transceiver Modules

These analog instrument modules run on the Macallan FPGA modules (PXIe-7981 / 7982 / 7985)
and are customized through their socketed CLIP, just like the other IO modules.

| Device | Baseboard | Status |
| --- | --- | --- |
| PXIe-5763 / PXIe-5764 | PXIe-7981 / 7982 / 7985 | 🟨 Buildable — CLIP available, no example yet |
| PXIe-5785 / PXIe-5775 / PXIe-5745 | PXIe-7981 / 7982 / 7985 | 🟨 Buildable — CLIP available, no example yet |
| PXIe-5774 | PXIe-7982 / 7985 | 🟨 Buildable — CLIP available, no example yet |

<br><br>

# How You Customize a FlexRIO Board

This section is the high-level map of *what you are actually customizing* and the **two ways** to do it. The step-by-step exercises live in [Getting Started](docs/GettingStarted.md) and the [CLIP Migration Hands-On Guide](docs/CLIPMigrationHandsOnGuide.md); read this first to decide which path you want.

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
* **One worked example** — [`pxie-7903aurora`](targets/pxie-7903aurora) — that instantiates the socketed Aurora CLIP directly in the top-level HDL, but still wires its LabVIEW-facing signals up to a LabVIEW FPGA VI *as if the CLIP were still in the socket*.

## The two ways to customize

### Option 1 — Migrate a socketed CLIP, keep the same LabVIEW interface

Take an existing socketed CLIP and instantiate it in your top-level `UserHdl`, then reconnect its **LabVIEW-facing** ports so the design still exposes the same interface to a LabVIEW FPGA VI. The CLIP HDL moves out of the LabVIEW window and into the top-level HDL, but *the HDL-to-LabVIEW interface you had before is unchanged* — you keep writing your application in a LabVIEW FPGA VI.

This is exactly what the Aurora example does. Follow the [CLIP Migration Hands-On Guide](docs/CLIPMigrationHandsOnGuide.md) (also walked through as Exercise 4 in [Getting Started](docs/GettingStarted.md)).

**Use this when** you want the new HDL packaging/build flow but still want to do your application logic in LabVIEW FPGA.

### Option 2 — Move your logic into HDL and talk to the host directly (the HDL-only workflow)

Start from the same socketed CLIP HDL, but instead of re-exposing its LabVIEW ports, **build onto those ports inside `UserHdl` yourself**. Do in VHDL whatever you would previously have done in a LabVIEW FPGA VI, and communicate with the host using the HDL workflow's **host registers and DMA FIFOs** (from [`hdl-shared`](https://github.com/ni/hdl-shared)). No LabVIEW FPGA VI is required at all — you compile the bitfile in Vivado and talk to it from the NI-RIO driver on the host.

This is the **primary use case** of `flexrio-custom`: customers who want the integrated IO business logic packaged so they can extend it **in VHDL**, not in LabVIEW. There is **no bespoke example of this yet** — it is the piece a domain/subject-matter expert fills in for a given IO module — but the CLIP source, the blank `UserHdl`, and the host register/FIFO interfaces are all here to build it on.

**Use this when** you want an HDL-only design with no LabVIEW FPGA VI in the stack.

> **How do I know what's inside the CLIP?** The CLIP VHDL is not formally documented — its behavior is described by the comments in the CLIP source itself, and interpreting it assumes familiarity with the underlying high-speed bus. See [Dependencies and File Management](docs/DependenciesAndFileManagement.md) for where the CLIP source lives and how it is pulled into a target, and [Digital IO](docs/DigitalIO.md) for the board IO interfaces routed into `UserHdl`.

# Customizing IO Module Devices

Modules with integrated IO use an IO Module ID (also called Terminal Block ID or TbId in the VHDL) to ensure that the LabVIEW FPGA CLIP node is compatible with the device.  When customizing the device in VHDL, use this IO Module ID to ensure that the integrated IO is enabled.

## IO Module IDs

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

# System Setup
Follow these steps to setup your machine to use the LabVIEW FPGA HDL Tools with this flexrio-custom GitHub repository

## Prerequisite Software
Use NI Package Manager to install the following software:
* LabVIEW 2023 (or newer)
* LabVIEW FPGA 2023 (or newer)
* LabVIEW FPGA Compilation tool for Vivado 2021.1
* FlexRIO 2026 Q3 (or newer)

Install the following 3rd party software:
* Install latest version Git  – https://git-scm.com/downloads
* Install Python 3.10 or newer (tested with 3.10–3.14) –  https://www.python.org/downloads/

## 1) Clone this repo
In a dev folder (e.g. c:\dev\github) clone the repo:
> git clone https://github.com/ni/flexrio-custom

List tags for all the releases:
> git tag

Checkout the repo at a specific tag/version:
> git checkout tags/26.x.y 

(main branch may be unstable; we recommend checking out the latest version that does not have "dev" in the name)

## 2) Go to the custom target folder
> cd C:\dev\github\flexrio-custom\targets\pxie-7903custom

All command line operations are performed from within a target folder

## 3) Set up the Python environment
> nisetup

This creates a virtual environment, installs the correct version of the LabVIEW FPGA HDL Tools, and activates the environment.

**Important:** You must run `nisetup` every time you open a new command prompt.  The virtual environment is only active for the current terminal session.  You will see `(flexrio-custom)` in your command prompt when the environment is active.

## 4) Run nihdl --help to see the list of available commands
> nihdl --help

## 5) Install dependencies
> nihdl install-deps

This will download the dependencies specified in the dependencies.toml file found here:
> C:\dev\github\flexrio-custom\dependencies.toml

<br>
<b> That's it!  Your computer is setup to use the LabVIEW FPGA HDL Tools to make custom FlexRIO FPGA devices</b>
<br><br><br>

# Getting Started

Step-by-step exercises for building bitfiles, customizing a target, and migrating a socketed CLIP have moved to [docs/GettingStarted.md](docs/GettingStarted.md).


# Repo Folder Hierarchy

* Root repo folder
    * `.github` - CI workflows and repo automation
    * `deps` - checked-out GitHub dependencies installed by `nihdl install-deps`
    * `docs` - repository documentation
    * `targets` - FPGA target projects (one folder per supported device)
        * `common` - shared files used across the target projects
        * `pxie-7903custom` - example custom PXIe-7903 device (consider this to be the "Hello World" example)
            * `nihdlsettings.py` - tool configuration (Python-based target settings)
            * `nisetup.bat` - runs the repo-root setup script to activate the Python environment
            * `lvFpgaTarget` - LabVIEW FPGA target plugin source files
            * `blankLvWindowNetlist` - placeholder LabVIEW window netlist content
            * `rtl-lvfpga` - target HDL sources
            * `xdc` - timing constraints
            * `VivadoProject` - Vivado project files (ignored in .gitignore)
            * `ModelSimProject` - ModelSim simulation project files (ignored in .gitignore)
            * `objects` - generated outputs from HDL tools (ignored in .gitignore)
            * `docs` - target-specific documentation and examples
            * `vivadoprojectsources.txt` - source list used for Vivado project generation
            * `vivadoprojectexclude.txt` - files excluded from the generated Vivado project
            * `modelsimprojectsources.txt` - source list used for ModelSim project generation
        * `pxie-7903aurora` - example of migrating the Aurora CLIP to make a custom Aurora PXIe-7903 device
        * `pxie-7xxxCustom` - additional custom device examples
    * `tests` / `test-targets` - automated tests and test targets
    * `dependencies.toml` - dependency version specification for `nihdl install-deps` and Python tool versions
    * `nisetup.bat` - sets up a Python virtual environment and installs dependencies
    * `nisetup.py` - Python script that creates the venv and installs packages from `dependencies.toml`
    * `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE` - project meta files


