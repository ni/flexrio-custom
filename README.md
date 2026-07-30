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
    * See [Dependencies and File Management](docs/DependenciesAndFileManagement.md) for how a custom target is assembled from the base target and these dependencies, and what each file list is for
* There are two **compile flows** for turning custom HDL into a bitfile (see the [LabVIEW FPGA HDL Tools Theory of Operation](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/TheoryOfOperation.md) for the full story):
    * **Vivado compile flow** – extend the design in HDL and compile the bitfile directly in Vivado, then communicate with it from the NI-RIO driver on a host PC (no LabVIEW required)
    * **LabVIEW FPGA compile flow** – use HDL to make a custom LabVIEW FPGA target, then write a VI in LabVIEW FPGA and let it compile the bitfile using the standard LabVIEW FPGA bitfile-generation experience (LabVIEW FPGA runs Vivado under the hood)
    * You can also author a top-level VI in LabVIEW FPGA, export it as a netlist, and bring it into the Vivado compile flow
    * In short: in the **Vivado flow** you drive Vivado; in the **LabVIEW FPGA flow** LabVIEW FPGA drives Vivado for you
* You can communicate between the NI-RIO driver on a host PC and custom HDL directly using
    * Registers
    * DMA FIFOs
* All of this is pre-release and not supported by NI
    * Use the [Issues](https://github.com/ni/flexrio-custom/issues) and [Discussions](https://github.com/ni/flexrio-custom/discussions) sections in this repository to collaborate with the developers and other lead users
<br><br><br>

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
<br><br><br>

# Supported Devices

## FlexRIO Co-Processor Modules

| Device |
| --- |
| PXIe-7903 |
| PXIe-7903-DDR1280 |
| PXIe-7911 |
| PXIe-7912 |
| PXIe-7915 |

## FlexRIO High-Speed Serial Modules

| Device | Baseboard |
| --- | --- |
| PXIe-6593 KU35 | PXIe-7981 |
| PXIe-6593 KU40 | PXIe-7982 |
| PXIe-6593 KU60 | PXIe-7985 |
| PXIe-6594 | PXIe-7986 |

## FlexRIO Multifunction IO Modules

| Device | Baseboard |
| --- | --- |
| PXIe-7890 | PXIe-7994 |
| PXIe-7891 | PXIe-7994 |

For the High-Speed Serial and Multifunction IO Modules, start with the Custom folder for the baseboard module.

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
| PXIe-6593 KU35 | 0x109379F9 |
| PXIe-6593 KU40 | 0x109379F9 |
| PXIe-6593 KU60 | 0x109379F9 |
| PXIe-6594 | 0x109379FC |
| PXIe-7890 | 0x10937AA7 |
| PXIe-7891 | 0x10937AA8 |

# System Setup
Follow these steps to setup your machine to use the LabVIEW FPGA HDL Tools with this flexrio-custom GitHub repository

## Prerequisite Software
Use NI Package Manager to install the following software:
* LabVIEW 2023 (or newer) — see the LabVIEW version note below
* LabVIEW FPGA 2023 (or newer)
* LabVIEW FPGA Compilation tool for Vivado 2021.1
* FlexRIO 2026 Q3 (or newer)

**LabVIEW version depends on which compile flow you use.** LabVIEW **2023 or newer** is enough for the **Vivado compile flow** — author a VI, export a LabVIEW window netlist with `gen-window`, and compile in Vivado. The **LabVIEW FPGA compile flow** (build a custom LabVIEW FPGA target and compile the bitfile in LabVIEW FPGA) requires **LabVIEW 2026 or newer**. See [Window Netlist and Constraints → LabVIEW version support](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/WindowNetlistAndConstraints.md#labview-version-support-2023-vs-2026) for the details.

Install the following 3rd party software:
* Install latest version Git  – https://git-scm.com/downloads
* Install Python (version 3.11.8 officially tested) –  https://www.python.org/downloads/

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

See [Dependencies and File Management](docs/DependenciesAndFileManagement.md) for what each dependency repo provides and how versions are managed.

<br>
<b> That's it!  Your computer is setup to use the LabVIEW FPGA HDL Tools to make custom FlexRIO FPGA devices</b>
<br><br><br>

# Managing Dependency Versions

`nihdl install-deps` clones the dependency repositories listed in [`dependencies.toml`](dependencies.toml) at the repo root. Understanding how those repos are versioned — and what to do when you move to a newer version — keeps your custom target building across upgrades.

## Versioning schemes

The dependencies use two different versioning schemes:

**Locked to NI product releases — calendar versioning** (e.g. `26.3.0` = 2026 Q3). Keep these three on the **same quarterly version**:
- `ni/flexrio` — the base FlexRIO target support your custom target builds on
- `ni/flexrio-deps` — the encrypted base-target dependencies
- `ni/flexrio-clips` — the socketed CLIP HDL

**Decoupled from NI product releases — semantic versioning** (e.g. `2.5.0`). These release independently whenever they change:
- `ni/hdl-shared` — reusable host interfaces (registers, DMA FIFOs)
- `ni/labview-fpga-hdl-tools` — the `nihdl` tools themselves (also pinned as a Python package)

The flexrio-custom repo itself is calendar-versioned and tracks the FlexRIO quarterly release.

## Specifying versions in `dependencies.toml`

Use the `~=` ("compatible release") operator so you can pick up patch fixes without editing the file:

```toml
github_dependencies = [
    "ni/flexrio~=26.3.0",
    "ni/flexrio-deps~=26.3.0",
    "ni/flexrio-clips~=26.3.0",
    "ni/hdl-shared~=1.0.0",
]
```

NI recommends keeping `flexrio`, `flexrio-deps`, and `flexrio-clips` on the **same** quarterly version — mixing quarters can produce interface mismatches between the base target and its deps.

A checked-out release tag (or `main`) already pins a coherent stack in `dependencies.toml`, so **`nihdl install-deps` alone installs the right versions — no extra flags needed.** A `.dev0` pin (e.g. `ni/flexrio~=26.3.0.dev0`) automatically resolves to the latest matching pre-release (`.dev1`, `.dev2`, …), so a development stack installs the same way. `install-deps --pre --latest` is only a convenience for pulling the newest pre-releases of *every* dependency regardless of the pins, when you are iterating on a development branch — you should not need it for a released version or `main`.

See [Dependencies and File Management](docs/DependenciesAndFileManagement.md) for what each repo provides and how the file lists tie them together.

## Match the installed FlexRIO driver version

Choose the **quarterly version** of `flexrio` / `flexrio-deps` (and therefore of flexrio-custom) to **match the FlexRIO driver installed on your machine**. For example, with FlexRIO 2026 Q3 installed, pin the deps to `~=26.3.0`.

This matters because a custom target relies on pieces that ship with the **FlexRIO driver**, not with this repo:

- **Common target-plugin files.** A custom LabVIEW FPGA target plugin depends on **common target-plugin files that the FlexRIO driver installs** — these are *not* provided by the GitHub custom device target plugin. So the version of the flexrio base-target support must match the installed FlexRIO driver version.
- **Host driver API for FIFOs and registers.** flexrio-custom exposes **DMA FIFO** and **register** host APIs on the custom FPGA device. The host-side driver for those APIs is installed with the FlexRIO driver, so the versions must match to avoid incompatibility.

Keeping flexrio-custom, its `flexrio` / `flexrio-deps` dependencies, and the installed FlexRIO driver all on the **same quarterly version** avoids these mismatches.

## Upgrading to a newer base-target version

When you bump `flexrio` / `flexrio-deps` in `dependencies.toml` and re-run `nihdl install-deps`:

- **Referenced files update automatically.** A custom target references almost everything **in place** from the base target, so those files come along with the new version with no action from you.
- **Forked files do NOT update automatically.** A custom target **copies and modifies** the base target's **top-level HDL file** — for example `SasquatchTopTemplate.vhd` (Sasquatch / Aurora) or `MacallanTop.vhd` (Macallan). Your copy keeps the old interface, so if NI changed the base top-level file, your fork can break. (See [Dependencies and File Management](docs/DependenciesAndFileManagement.md) for which files are forked vs. referenced.)

### Reconciling a forked file after an upgrade

**How you'll know something broke.** After `install-deps`, the target fails to build (`nihdl gen-vivado`, `gen-target`, `gen-modelsim`, or a compile) with errors on the forked top-level file — commonly missing or extra **generics** or **ports** on instantiations of the fixed logic, the window wrapper, `IoRefClkSelect`, or clock/reset constants.

**How to find what changed — diff the OLD base against the NEW base.** Your fork has usually drifted far from the base target (you added your `UserHdl`, FIFOs, custom I/O, and so on), so:

- **Do NOT** diff your **customized** file against the **new base** file — that diff is dominated by *your* customizations and it's hard to see NI's changes.
- **DO** diff the **old base** version against the **new base** version of the *same* file. That isolates exactly what NI changed between the two releases — usually a small, focused diff.

Two ways to get the two base versions:

- **On GitHub (easiest):** compare the two tags on `ni/flexrio` and open the top-level file, e.g. `https://github.com/ni/flexrio/compare/26.1.0...26.2.0` (or view one version directly: `https://github.com/ni/flexrio/blob/26.1.0/targets/<base-target>/rtl-lvfpga/<Top>.vhd`).
- **Locally:** before upgrading, save a copy of `deps/flexrio/targets/<base-target>/rtl-lvfpga/<Top>.vhd`, run `install-deps` on the new version, and diff the two copies with any diff tool.

**Reconcile.** For each change in the old → new base diff, decide whether it affects the interface your fork depends on (generics, ports, constants, signal declarations, instantiations). If it does, apply the equivalent edit to your forked top-level file while **preserving your customizations**, then rebuild to confirm.

> Today only the **top-level HDL file** is forked. If you fork additional base-target files, apply the same old → new base diff to each of them on every version bump.
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
            * `nihdlsettings.py` - tool configuration (Python-based target settings; see [Dependencies and File Management](docs/DependenciesAndFileManagement.md))
            * `nisetup.bat` - runs the repo-root setup script to activate the Python environment
            * `lvFpgaTarget` - LabVIEW FPGA target plugin source files
            * `blankLvWindowNetlist` - placeholder LabVIEW window netlist content
            * `rtl-lvfpga` - target HDL sources
            * `xdc` - timing constraints
            * `VivadoProject` - Vivado project files (ignored in .gitignore)
            * `ModelSimProject` - ModelSim simulation project files (ignored in .gitignore)
            * `objects` - generated outputs from HDL tools (ignored in .gitignore)
            * `docs` - target-specific documentation and examples
            * `vivadoprojectsources.txt` - source list used for Vivado project generation (the custom target's own sources, headed by the modified top-level VHDL file — see [Dependencies and File Management](docs/DependenciesAndFileManagement.md))
            * `modelsimprojectsources.txt` - source list used for ModelSim project generation
        * `pxie-7903aurora` - example of migrating the Aurora CLIP to make a custom Aurora PXIe-7903 device
        * `pxie-7xxxCustom` - additional custom device examples
    * `tests` / `test-targets` - automated tests and test targets
    * `dependencies.toml` - dependency version specification for `nihdl install-deps` and Python tool versions
    * `nisetup.bat` - sets up a Python virtual environment and installs dependencies
    * `nisetup.py` - Python script that creates the venv and installs packages from `dependencies.toml`
    * `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE` - project meta files


