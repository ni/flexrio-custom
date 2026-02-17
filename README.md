Pre-release custom FlexRIO code for use with LabVIEW FPGA HDL Tools

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
> cd C:\dev\github8\flexrio-custom\targets\pxie-7903custom

All command line operations are performed from within a target folder

## 3) Install the LabVIEW FPGA HDL Tools
> pip install -r requirements.txt

This will install the correct version of the tools that the checked out version of the repository is using

## 4) Run nihdl --help to see the list of available commands
> nihdl --help

## 5) Install dependencies
> nihdl install-deps

This will download the dependencies specified in the dependencies.toml file found here:
> C:\dev\github8\flexrio-custom\dependencies.toml

<b> That's it!  Your computer is setup to use the LabVIEW FPGA HDL Tools to make custom FlexRIO FPGA devices</b>

# Getting Started

## Read the LabVIEW FPGA HDL Tools README
https://github.com/ni/labview-fpga-hdl-tools/blob/main/README.md

## Build a bitfile for the custom PXIe-7903 project
### 1) Go to the custom target folder
> cd C:\dev\github8\flexrio-custom\targets\pxie-7903custom

### 2) Create a Vivado Project
> nihdl create-project

### 3) Launch Vivado
> nihdl launch-vivado

### 4) Build a bitfile
In Vivado, click "Generate Bitstream" in left-hand tools menu

## Customize your own PXIe-7903
### 1) Make a copy of the custom target folder
> C:\dev\github8\flexrio-custom\targets\pxie-7903custom-mycopy

### 2) Edit the projectsettings.ini file in pxie-7903-mycopy
Set `LVTargetName` to `PXIe-7903custom-mycopy`

Run 'nihdl get-guid' to generate a new GUID

Copy the new GUID into the 'LVTargetGUID' setting

### 3) Edit the top-level FPGA file
Open rtl-lvfpga/SasquatchTopTemplate

Find HdlSharedCommonHostRegs_inst and set kSigniature to 'x"7903FEED"'

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

Use the following register map for the common registers:

| Register | Offset | Access |
| --- | ---: | --- |
| kSignatureOffset | 0 | read-only |
| kVersionOffset | 4 | read-only |
| kOldestCompatibleVersionOffset` | 8 | read-only |
| kScratchOffset | 12 | read-write |

## Migrate a Socketed CLIP to use a custom LabVIEW FPGA target
The PXIe-7903Aurora example has the socketed CLIP node instantiated in the FPGA top-level entity to make a custom LabVIEW FPGA target with it.  Read the CLIP Migration Hands-On Guide that walks you through how this was done.
> C:\dev\github\flexrio-custom\targets\pxie-7903aurora\docs\CLIP Migration Hands-On Guide.pdf




# Repo Folder Hierarchy

* Root repo folder
    * `.github` - CI workflows and repo automation
    * `deps` - checked-out GitHub dependencies installed by `nihdl install-deps`
    * `docs` - documentation (`docs/public`)
    * `targets` - FPGA target projects
        * `pxie-7903custom` - example custom PXIe-7903 device (consider this to be the "Hello World" example)
            * `projectsettings.ini` - tool configuration
            * `requirements.txt` - target-specific Python dependency entrypoint
            * `lvFpgaTarget` - LabVIEW FPGA target plugin source files
            * `lvWindowNetlist` - extracted/generated LabVIEW window netlist content
            * `rtl-lvfpga` - target HDL sources
            * `xdc` - timing constraints
            * `VivadoProject` - Vivado project files
            * `objects` - generated outputs from HDL tools
            * `vivadoprojectsources.txt` - source list used for Vivado project generation
        * `pxie-7903aurora` - example of migrating the Aurora CLIP to make a custom Aurora PXIe-7903 device
    * `dependencies.toml` - dependency version specification for `nihdl install-deps`
    * `requirements.txt` - top-level Python dependencies (defines version dependency of LabVIEW FPGA HDL Tools)


