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
* LabVIEW 2023 (or newer)
* LabVIEW FPGA 2023 (or newer)
* LabVIEW FPGA Compilation tool for Vivado 2021.1
* FlexRIO 2026 Q3 (or newer)

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


