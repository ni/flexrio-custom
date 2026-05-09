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
    * DMA FIFOs (future - not yet supported)
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


# System Setup
Follow these steps to setup your machine to use the LabVIEW FPGA HDL Tools with this flexrio-custom GitHub repository

## Prerequisite Software
Use NI Package Manager to install the following software:
* LabVIEW 2023 (or newer)
* LabVIEW FPGA 2023 (or newer)
* LabVIEW FPGA Compilation tool for Vivado 2021.1
* FlexRIO 2025 (or newer)

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

<br>
<b> That's it!  Your computer is setup to use the LabVIEW FPGA HDL Tools to make custom FlexRIO FPGA devices</b>
<br><br><br>

# Getting Started

## Exercise 1 - Read the LabVIEW FPGA HDL Tools README
https://github.com/ni/labview-fpga-hdl-tools/blob/main/README.md

## Exercise 2 - Build a bitfile for the custom PXIe-7903 project
### 1) Go to the custom target folder
> cd C:\dev\github\flexrio-custom\targets\pxie-7903custom

### 2) Create a Vivado Project
> nihdl create-project

### 3) Launch Vivado
> nihdl launch-vivado

### 4) Build a bitfile
In Vivado, click "Generate Bitstream" in left-hand tools menu

## Exercise 3 - Customize your own PXIe-7903
### 1) Make a copy of the custom target folder
> C:\dev\github\flexrio-custom\targets\pxie-7903custom-mycopy

### 2) Edit the projectsettings.ini file in pxie-7903-mycopy
Set `LVTargetName` to `PXIe-7903custom-mycopy`

Run `nihdl get-guid` to generate a new GUID

Copy the new GUID into the `LVTargetGUID` setting

### 3) Edit the top-level FPGA file
Open rtl-lvfpga/SasquatchTopTemplate

Find `HdlSharedCommonHostRegs_inst` and set `kSigniature` to `x"7903FEED"`

### 4) Create a Vivado project
> nihdl create-project

### 5) Launch Vivado and generate a bitfile
> nihdl launch-vivado

In Vivado, click "Generate Bitstream" in left-hand tools menu

### 7) Generate and install the custom LabVIEW FPGA Target
> nihdl gen-target

> nihdl install-target

### 8) Test the target in LabVIEW 
Use the NI-RIO API to download and run the bitfile

Make sure to use the <b>Open Dynamic Bitfile Reference</b> (and not the normal Open FPGA VI Reference)

Use the read/write register subVI's from the hdl-shared repo to access the FPGA's registers
> C:\dev\github\flexrio-custom\deps\hdl-shared\host_interfaces\register\LabVIEW

Here is an example VI that demonstrates this:
> C:\dev\github\flexrio-custom\targets\pxie-7903custom\docs\Examples\Custom_FPGA_Target_Host_Example.vi

Use the following register map for the common registers:

| Register | Offset | Access |
| --- | ---: | --- |
| kSignatureOffset | 0 | read-only |
| kVersionOffset | 4 | read-only |
| kOldestCompatibleVersionOffset` | 8 | read-only |
| kScratchOffset | 12 | read-write |

## Exercise 4 - Migrate a Socketed CLIP to use a custom LabVIEW FPGA target
The PXIe-7903Aurora example has the socketed CLIP node instantiated in the FPGA top-level entity to make a custom LabVIEW FPGA target with it.  Read the CLIP Migration Hands-On Guide that walks you through how this was done.
> C:\dev\github\flexrio-custom\targets\pxie-7903aurora\docs\CLIP Migration Hands-On Guide.pdf


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

# Repo Folder Hierarchy

* Root repo folder
    * `.github` - CI workflows and repo automation
    * `deps` - checked-out GitHub dependencies installed by `nihdl install-deps`
    * `docs` - documentation (`docs/public`)
    * `targets` - FPGA target projects
        * `pxie-7903custom` - example custom PXIe-7903 device (consider this to be the "Hello World" example)
            * `projectsettings.ini` - tool configuration
            * `nisetup.bat` - runs the repo-root setup script to activate the Python environment
            * `lvFpgaTarget` - LabVIEW FPGA target plugin source files
            * `lvWindowNetlist` - extracted/generated LabVIEW window netlist content
            * `rtl-lvfpga` - target HDL sources
            * `xdc` - timing constraints
            * `VivadoProject` - Vivado project files
            * `objects` - generated outputs from HDL tools
            * `vivadoprojectsources.txt` - source list used for Vivado project generation
        * `pxie-7903aurora` - example of migrating the Aurora CLIP to make a custom Aurora PXIe-7903 device
    * `dependencies.toml` - dependency version specification for `nihdl install-deps` and Python tool versions
    * `nisetup.bat` - sets up a Python virtual environment and installs dependencies
    * `nisetup.py` - Python script that creates the venv and installs packages from `dependencies.toml`


