# Getting Started

These exercises walk through both **compile flows**. Exercise 2 builds a bitfile with the **Vivado compile flow** (you compile in Vivado). Exercise 3 also builds and installs a **custom LabVIEW FPGA target** — the **LabVIEW FPGA compile flow** — so you can extend the design with a VI in LabVIEW FPGA. See the [Theory of Operation](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/TheoryOfOperation.md) for the difference between the two flows.

## Exercise 1 - Read the LabVIEW FPGA HDL Tools README and Theory of Operation
https://github.com/ni/labview-fpga-hdl-tools/blob/main/README.md

https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/TheoryOfOperation.md

## Exercise 2 - Build a bitfile with the Vivado compile flow
### 1) Go to the custom target folder
> cd C:\dev\github\flexrio-custom\targets\pxie-7903custom

### 2) Create a Vivado Project
> nihdl gen-vivado

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
Open rtl-lvfpga/UserHdl

Find `HdlSharedCommonHostRegs_inst` and set `kSigniature` to `x"7903FEED"`

### 4) Create a Vivado project
> nihdl gen-vivado

### 5) Launch Vivado and generate a bitfile
> nihdl launch-vivado

In Vivado, click "Generate Bitstream" in left-hand tools menu

### 7) Generate and install the custom LabVIEW FPGA Target (LabVIEW FPGA compile flow)
> nihdl gen-target

> nihdl install-target

### 8) Test the target in LabVIEW 
Use the NI-RIO API to download and run the bitfile

Open the HostExample VI:
> flexrio-custom\targets\pxie-7903custom\docs\Examples\LV2023\HostExample


Use the following register map for the common registers:

| Register | Offset | Access |
| --- | ---: | --- |
| kSignatureOffset | 0 | read-only |
| kVersionOffset | 4 | read-only |
| kOldestCompatibleVersionOffset` | 8 | read-only |
| kScratchOffset | 12 | read-write |

## Exercise 4 - Migrate a Socketed CLIP to use a custom LabVIEW FPGA target
The PXIe-7903Aurora example has the socketed CLIP node instantiated in the FPGA top-level entity to make a custom LabVIEW FPGA target with it.  Read the [CLIP Migration Hands-On Guide](CLIPMigrationHandsOnGuide.md) that walks you through how this was done.
