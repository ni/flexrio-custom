# Overview

The PXIe-7903 is a high-performance FlexRIO co-processor.  It includes a Xilinx Virtex UltraScale+ FPGA to implement various high-speed serial protocols using multigigabit transcievers to deliver 48 TX and RX serial lanes.

# Architecture Diagram

![7903 Architecture](PXIe-7903_Architecture.png)

* **Timing Engine** - 
* **Host Interface** - 
* **Fixed Logic** - 
* **IO Reference Clock Select** - 
* **IO Buffers** - 
* **DRAM** - 
* **DRAM 2DP** - 
* **The Window** - 
* **The VI** - 
* **The CLIPs** - 

# User Signals

These signals are connected to the CLIP socket on the LabVIEW window.  If you wish to customize the PXIe-7903 top-level HDL file, you may disconnect these signals from TheWindow and instantiate your own custom HDL to operate them.

