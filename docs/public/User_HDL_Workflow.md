# User Workflow

This is a basic "Hello World" workflow to ensure that your system is properly setup.  Refer to the HDL Workflow CLIP Migration Guide to learn about using the full workflow.

## Prerequisites
1.	Install latest version Git  – https://git-scm.com/downloads
2.	Install Python (version 3.11.8 officially tested) –  https://www.python.org/downloads/
3.	Install LabVIEW FPGA Compilation tool for Vivado 2021.1 – https://www.ni.com/en/support/downloads/software-products/download.package-manager.html

## Phase 1 – Clone the FlexRIO GitHub repo
1.	Go to the FlexRIO repo on GitHub (e.g. https://github.com/ni/flexrio)
2.	Copy the repo HTTPS URL to clipboard
3.	Open a command prompt in your computer's GitHub repo folder (e.g. C:\dev\github)
4.	Clone the FlexRIO GitHub repo:
    > git clone <b>[FlexRIO GitHub repo URL]</b>

## Phase 2 – Install LabVIEW FPGA HDL Tools
1.  Open a command prompt in your target folder (e.g. C:\dev\github\flexrio\pxie-7903)
    * Note: the PXIe-7xxx folder is the working directory where you will run all commands
2.  Run this command to pip install the tools and their dependencies
    > pip install -r requirements.txt

## Phase 3 - Install FlexRIO repo depenencies
1.  Go to the latest releases of the FlexRIO repo on GitHub
2.  Download the dependencies.zip artifact into the dependencies folder on your computer (e.g. C:\dev\github\flexrio\dependencies)
3.  Run the extract dependencies command
    > nihdl extract-deps

## Phase 4 – Create and Build the Vivado Project
1.	Create the Vivado project:
    > nihdl create-project
2.	Launch Vivado:
    > nihdl launch-vivado
3.	In the Vivado IDE, click <b>Synthesize</b>


