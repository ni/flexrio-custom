# FlexRIO Custom Release Process

This document covers both the internal NI release pipelines and the GitHub repo steps required to release all repositories needed to use **flexrio-custom** to make custom FlexRIO FPGA targets.

## Overview

Releasing flexrio-custom is a multi-repo process. Source code is first published from NI's internal repo (hw-flexrio) to GitHub, then each GitHub repo is released in dependency order, and finally flexrio-custom is updated, tested, and released.

**Perform the releases in the order below. Each component must be released before the components that depend on it.**

| Step | What you release | Required? |
|------|------------------|-----------|
| 1 | Publish NI source code to GitHub (flexrio, flexrio-deps, flexrio-clips) | Required |
| 2 | PR and release the three FlexRIO GitHub repos | Required |
| 3 | Release hdl-shared | Only if co-developing hdl-shared |
| 4 | Release labview-fpga-hdl-tools | Only if co-developing the HDL tools |
| 5 | Update, test, and release flexrio-custom | Required |

### Release Versioning

These repos are **locked to NI product releases** and use calendar versioning (e.g. `26.3.0` for 2026 Q3):
- https://github.com/ni/flexrio
- https://github.com/ni/flexrio-deps
- https://github.com/ni/flexrio-clips

These repos are **decoupled from NI product releases** and use semantic versioning (e.g. `2.5.0`):
- https://github.com/ni/hdl-shared
- https://github.com/ni/labview-fpga-hdl-tools

---

## 1. Publish NI source code files to GitHub


### Step A) Run the hw-flexrio Global CI pipeline
Once we have finals of flexrio_baseboards for the FlexRIO driver, run the **hw-flexrio Global CI** pipeline on the main branch.  
You can set Publish to false - the nuget artifacts are not needed

This copies the filtered repo contents into the `githubstaging` branches.

We run the pipeline manually on `main` when we are ready to push to GitHub. Other runs of the pipeline on dev branches may overwrite the `githubstaging` branches, so we want to be sure they are freshly staged with the `main` branch contents before pushing.

When the pipeline has completed, inspect the staging branches to make sure they look right:
- `ni/githubstaging/flexrio`
- `ni/githubstaging/flexrio-deps-source`
- `ni/githubstaging/clips`

### Step B) Publish the githubstaging branches to GitHub

Clone the hw-flexrio repo:
```
git clone https://dev.azure.com/ni/DevCentral/_git/hw-flexrio
```

Go to the `publish_clip` folder:
```
C:\dev\git\hw-flexrio\github\publish_clip
```

On your dev machine, check out and pull the latest `main` branch of hw-flexrio:
```
git checkout main
git pull
```

Run `hwsetup`:
```
hwsetup
```

**First-time setup only:** install the VHDL encryption python module from the `hw-flexrio/targets` folder:
```
pip install encrypt_vhdl_vivado-26.0.0.9999+development-py3-none-any.whl
```

Run the `encryptdeps` build flow to encrypt the code in `ni/githubstaging/flexrio-deps-source` and produce the `ni/githubstaging/flexrio-deps` branch:
```
python build.py --flow=encryptdeps
```

This build leaves you on the `githubstaging` branch. Go back to `main`:
```
git checkout main
```

Before pushing to GitHub, inspect the `ni/githubstaging/flexrio-deps` branch to ensure that the HDL is encrypted and that it looks right.

Run the `pushgithub` build flow to push the staging branches to GitHub:
```
python build.py --flow=pushgithub
```

Go to the `publish_clip` folder in the hw-flexrio repo:
```
C:\dev\git\hw-flexrio\github\publish_clip
```

Run the `publishgithubclip` build flow to push the staging branch to GitHub:
```
python build.py --flow=pushgithubclip
```

This build leaves you on the `githubstaging` branch. Go back to `main`:
```
git checkout main
```

## 2. PR and Release FlexRIO GitHub Repos

### Perform these steps for each of these three GitHub repos:
- https://github.com/ni/flexrio
- https://github.com/ni/flexrio-deps
- https://github.com/ni/flexrio-clips

Create a Pull Request from the githubstaging branch to main

Create a release branch:
- Name: releases/26.3.0
- Source branch: main

Note: If you are doing a pre-release development release, you should skip making the release branch

Make the release:
- Name: 26.3.0
- Tag: 26.3.0
- Target: releases/26.3.0

Note: If you are doing a development release, name it 26.3.0.dev0 and set the "Pre-release" label


## 3. Optional - Release HDL Shared GitHub Repo

If you are co-developing code in the hdl-shared repo along with the flexrio-custom repo, you may want to do a release of hdl-shared at this time.  However, the hdl-shared repo is decopuled from the flexrio and flexrio-custom repo versioning so it may release independently when changes or fixes are added to it.

Release documentation is here:
https://github.com/ni/hdl-shared/blob/main/docs/TestAndReleaseProcess.md

## 4. Optional - Release LabVIEW FPGA HDL Tools GitHub Repo

If you are co-developing code in the labview-fpga-hdl-tools repo along with the flexrio-custom repo, you may want to do a release of labview-fpga-hdl-tools at this time.  However, the labview-fpga-hdl-tools repo is decopuled from the flexrio and flexrio-custom repo versioning so it may release independently when changes or fixes are added to it.

Release documentation is here:
https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/TestAndReleaseProcess.md

## 5. Test and Release FlexRIO Custom GitHub Repo

### Step 5A) Update dependencies.toml
Update the `dependencies.toml` file in flexrio-custom to use the latest flexrio, hdl-shared, and labview-fpga-hdl-tools dependencies.

Use the `~=` operator so users can uptake patches without having to change the `dependencies.toml` file:
```
"ni/flexrio~=26.3.0",
```

Check this updated `dependencies.toml` file into `main`.

### Step 5B) Testing
The testing process can take several hours so we recommend doing this on a test machine.

Test machine must have:
- LabVIEW 2023 or newer
- FlexRIO 2026 Q3 or newer

Before release, we run the testing sequence on the main branch.
```
git checkout main
git pull
```

Open a command prompt in a custom target folder:
```
C:\dev\github\flexrio-custom\targets\pxie-7912custom
```

Run `nisetup` to install the LabVIEW FPGA HDL Tools:
```
nisetup
```

Run `nihdl --help` to verify that the correct version of the tools is installed:
```
nihdl --help
```

The report from -- help should look like:
```
Usage: nihdl [OPTIONS] COMMAND [ARGS]...

  LabVIEW FPGA HDL Tools (v1.0.0)

Options:
  --help  Show this message and exit.


### NIHDL Commands ###
...
```

Run `install-deps`:
```
nihdl install-deps
```

Note: If you are testing a development release stack, run with the `--pre --latest` arguments to get the latest "dev" release versions.

Verify the right dependencies are installed.  The report should look like this:
```
Resolving version ~=26.3.0 for ni/flexrio...
    [INFO] Resolved to tag: 26.3.0
Cloning ni/flexrio at tag 26.3.0...
  [OK] Successfully cloned flexrio
Resolving version ~=26.3.0 for ni/flexrio-deps...
    [INFO] Resolved to tag: 26.3.0
Cloning ni/flexrio-deps at tag 26.3.0...
  [OK] Successfully cloned flexrio-deps
Resolving version ~=26.3.0 for ni/flexrio-clips...
    [INFO] Resolved to tag: 26.3.0
Cloning ni/flexrio-clips at tag 26.3.0...
  [OK] Successfully cloned flexrio-clips
Resolving version ~=1.0.0 for ni/hdl-shared...
    [INFO] Resolved to tag: 1.0.0
Cloning ni/hdl-shared at tag 1.0.0...
  [OK] Successfully cloned hdl-shared
```

Open a command prompt in the manual tests folder:
```
C:\dev\github\flexrio-custom\tests\manual
```

Run `nisetup` to install the LabVIEW FPGA HDL Tools into the virtual environment:
```
nisetup
```

#### Testing Stage 1 - Generate Vivado Project Export for BlankRunningVI projects
The first test sequence will generate and install all the custom LV FPGA target plugins in the flexrio-custom repo:
```
python run_tests.py --sequence gen-install-lv-targets
```

Note: Depending on your computer's IT settings, you may be asked to grant administrator privileges for each target plugin install.

For each custom target in the repo:
1. Open the BlankRunningVI LabVIEW project (path uses `pxie-7903custom` as an example):
   `C:\dev\github\flexrio-custom\targets\pxie-7903custom\docs\Examples\LV2023\BlankRunningVI`
2. Build the BlankRunningVI Vivado Project Export build specification in the LabVIEW project.

Note: There is an issue with LabVIEW 2023 related to file permissions for `constraint.xdc`. If you are testing with LabVIEW 2023, you must run LabVIEW as administrator and then open the projects from that instance.

#### Testing Stage 2A - Generate Netlists for BlankRunningVI Vivado Project Exports and Compile Bitfiles
Execute version A of this stage if you want to test re-generating netlists from Vivado Project Exports.  You should do this for final or near-final regression testing before release.

If you are only testing, run the following test script:
```
python run_tests.py --sequence compile-targets-gen-objects-window
```

This will regenerate the netlists for all targets (into the objects folder) and recompile the bitfiles.

If you are doing finalization for a new release, you may want to regenerate the netlists that ship in the flexrio-custom repo. You may skip this step if you are certain that there have been no changes to the code that might change the interfaces between the custom HDL and the LabVIEW FPGA VI window. To be on the safe side, you should regenerate the netlists.

Check out a dev branch:
```
git checkout -b users/ssantolu/netlistupdate
```

Run the test sequence that will overwrite the `blankLvWindowNetlist` folder in each custom target folder:
```
python run_tests.py --sequence compile-targets-gen-shipping-window
```

Once that is complete, push the updated netlist changes to flexrio-custom and submit a PR to get it into `main`. If you are testing in a version newer than LabVIEW 2023, be careful to **NOT** submit the example LabVIEW projects to GitHub because they will be saved in a newer version.

Note: The compilation tests will take several hours.

#### Testing Stage 2B - Compile Bitfiles Using Netlists From Repo
Execute version B of this stage if you want to test using the shipping netlists.  Do this when you are testing the after release to sanity check that it works out of the box.

Compile bitfiles using shipping netlists:
```
python run_tests.py --sequence compile-targets-use-shipping-window
```

#### Testing Stage 3 - Simulate Custom Target Testbenches
Run the test sequence that will generate modelsim projects and simulate for all targets
```
python run_tests.py --sequence simulate-targets
```

#### Testing Stage 4 - Manual Testing on Hardware

**On a machine with a PXIe-7912:**

##### 7912 Test 1 - Test custom target with LabVIEW FPGA generated bitfile

Go to the PXIe-7912fifotest folder:
```
C:\dev\github\flexrio-custom\test-targets\pxie-7912fifotest
```

Generate and install the LV target plugin:
```
nihdl gen-target
nihdl install-target
```

Open the DMA test LabVIEW project:
`C:\dev\github\flexrio-custom\test-targets\pxie-7912fifotest\docs\Examples\LV2023\DmaTest`

Generate the bitfile.

Run the `FIFO_AUTO_TEST.vi` with the LabVIEW FPGA generated bitfile.

##### 7912 Test 2 - Test custom target with HDL Tools Vivado generated bitfile

Go to the PXIe-7912fifotest folder:
```
C:\dev\github\flexrio-custom\test-targets\pxie-7912fifotest
```

Generate the Vivado project and compile the bitfile:
```
nihdl gen-vivado
nihdl compile-vivado
```

Run the `FIFO_AUTO_TEST.vi` with the HDL Tools Vivado generated bitfile (in `objects/bitfiles`).

**On a machine with a PXIe-7903:**

##### 7903 Test 1 - Test Aurora target with LabVIEW FPGA generated bitfile

Go to the PXIe-7903aurora folder:
```
C:\dev\github\flexrio-custom\targets\pxie-7903aurora
```

Generate and install the LV target plugin:
```
nihdl gen-target
nihdl install-target
```

Open the Aurora test LabVIEW project:
`C:\dev\github\flexrio-custom\targets\pxie-7903aurora\docs\Examples\LV2023\AuroraCustom`

Generate the bitfile.

Run the `PXIe-7903 Aurora Example Host.vi` with the LabVIEW FPGA generated bitfile.

##### 7903 Test 2 - Test custom target with HDL Tools Vivado generated bitfile

In the Aurora test LabVIEW project, build the Aurora 2-port Vivado Project Export.
- Note the location that the VPE will be written to.

Go to the PXIe-7903aurora folder:
```
C:\dev\github\flexrio-custom\test-targets\pxie-7903aurora
```

Modify the `nihdlsettings.py` file to ensure that the Generate Window Netlist tool is using the location that the Vivado Project Export went to:
```
config.set_lv_window_vivado_project_export_xpr(r"C:\temp\MyProjectVPE\MyProject.xpr")   # <-- MODIFY THIS PATH
```

Modify the `nihdlsettings.py` file to ensure that it is using the Window Netlist that was generated from the above step:
```
config.set_lv_window_netlist_output_folder("objects/TheLvWindowNetlist")
config.set_lv_window_netlist_folder("objects/TheLvWindowNetlist")
```

Generate the netlist for the LV Window:
```
nihdl gen-window
```

Generate the Vivado project and compile the bitfile:
```
nihdl gen-vivado
nihdl compile-vivado
```

Run the `PXIe-7903 Aurora Example Host.vi` with the HDL Tools Vivado generated bitfile (in `objects/bitfiles`).

### Step 5C) Release

Once you are satisfied with the testing results, make a release for flexrio-custom

Create a release branch:
- Name: releases/26.3.0
- Source branch: main

Note: If you are doing a pre-release development release, you should skip making the release branch

Make the release:
- Name: 26.3.0
- Tag: 26.3.0
- Target: releases/26.3.0

Note: If you are doing a development release, name it 26.3.0.dev0 and set the "Pre-release" label
