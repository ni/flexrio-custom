# FlexRIO Custom Release Process

This document covers both the internal NI release pipelines and the GitHub repo steps required to release all repositories needed to use **flexrio-custom** to make custom FlexRIO FPGA targets.

Perform the releases in the order below. Each component must be released before the components that depend on it.

## Repo Release Versioning

These repos are locked to NI product releaes and use calendar versioning (e.g. 26.3.0 for 2026 Q3):
- https://github.com/ni/flexrio
- https://github.com/ni/flexrio-deps
- https://github.com/ni/flexrio-clips

These repos are decoupled from NI product releases and use semantic versioning (e.g. 2.5.0):
- https://github.com/ni/hdl-shared
- https://github.com/ni/labview-fpga-hdl-tools


## 1. Publish NI source code files to GitHub


### Step A) Run the hw-flexrio Global CI pipeline
Once we have finals of flexrio_baseboards for the FlexRIO driver, run the **hw-flexrio Global CI** pipeline on the main branch.  
You can set Publish to false - the nuget artifacts are not needed

This will get the filtered repo contents into the githubstaging branches

We manually run the pipeline on main branch when we are ready to push to GitHub because other runs of the pieline on dev branches may overwrite the githubstaging branches so we want to be sure that they are freshly staged with the main branch contents before pushing to GitHub.

When the pipeline has completed, inspect the staging branches to make sure they look right:
- ni/githubstaging/flexrio
- ni/githubstaging/flexrio-deps-source
- ni/githubstaging/clips

### Step B) Publish the githubstaging branches to GitHub
Clone the hw-flexrio repo:
> git clone https://dev.azure.com/ni/DevCentral/_git/hw-flexrio

Go to the hw-flexrio/targets folder:
> C:\dev\git\hw-flexrio\github\publish_clip

On your dev machine, checkout and pull the latest main branch of hw-flexrio
> git checkout main

> git pull

Run hwsetup
> hwsetup

If this is your first time running the release process, you must install the VHDL encryption python module that is in the hw-flexrio/targets folder:
> pip install encrypt_vhdl_vivado-26.0.0.9999+development-py3-none-any.whl

Run the encryptdeps build flow to encrypt the code in ni/githubstaging/flexrio-deps-source and produce the ni/githubstaging/flexrio-deps branch
> python build.py --flow=encryptdeps

This build will leave you on the githubstaging branch, go back to the main brainch
> git checkout main

Before pushing to GitHub, inspect the ni/githubstaging/flexrio-deps branch to ensure that the HDL is encrypted and that it looks right

Run the pushgithub bulid flow to push the staging branches to GitHub
> python build.py --flow=pushgithub

Go to the publish_clip folder in the hw-flexrio repo
> C:\dev\git\hw-flexrio\github\publish_clip

Run the publishgithubclip build flow to push the staging branch to GitHub
> python build.py --flow=pushgithubclip


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

## 5. Release FlexRIO Custom GitHub Repo

### Step A) Update dependencies.toml
Update the `dependencies.toml` file in flexrio-custom to use the latest flexrio, hdl-shared, and labview-fpga-hdl-tools dependencies

Use the `~=` operator to enable the user to uptake patches without having to change the dependencies.toml file
> "ni/flexrio~=26.3.0",

Check this updated dependencies.toml file into main

### Step B) Testing
The testing process can take several hours so we recommend doing this on a test machine.

Test machine must have:
- LabVIEW 2023
- FlexRIO 2026 Q3 or newer

Before release, we run the testing sequence on the main branch.
```
git checkout main
git pull
```




### Step C) Release

1. Update `dependencies.toml`
2. Update `requirements.txt`
3. Open a PR to run the smoke tests
4. Run the AzDO test GitHub pipeline on the dev branch
5. Close the PR
6. Create a `releases/26.2.0` branch
7. Create a release off of that branch


## 6. Manual and Autoamted Release Testing