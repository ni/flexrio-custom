# Repo Folder Hierarchy

* Root repo folder
    * baseboards - common HDL source used across multiple targets
    * dependencies - dependencies of targets delivered via zip file from the repo's release artifact
    * docs - documentation
    * fixedlogic - common HDL source used across multiple targets
    * ipcores - common HDL source used across multiple targets
    * targets - FPGA targets
        * common - common HDL source used across multiple targets
        * pxie-7xxx - Specific model number FPGA target
            * lvFpgaTarget - non-HDL files used to create custom LabVIEW FPGA target plugins
            * objects - generated file outputs from the HDL tools
                * gathereddeps - flat folder of dependencies copied from the root dependencies folder
                * LVTargetPlugin - custom LabVIEW FPGA target plugin files
                * rtl-lvfpga - ouptut of pxie-7xxx\rtl-lvfpga file that were processed
                * TCL - output of pxie-7xxx\TCL files that were processed
                * xdc - output of pxie-7xxx\xdc files that were processed
            * rtl-lvfpga - HDL files specific to the PXIe-7xxx
                * lvgen - HDL files that are normally provided by LabVIEW FPGA code generation
            * TCL - scripts used by Vivado
            * xdc - timing constraints
        * lvfpgaexcludefiles.py - list of regular expressions to define files that should not be included in custom LabVIEW FPGA target plugin generation
        * requirements.txt - Python modules and dependencies installed by pip


