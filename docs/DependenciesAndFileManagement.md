# Dependencies and File Management

This document explains how a `flexrio-custom` target is assembled from the base
FlexRIO target and its dependencies: which repositories are pulled in, which
files you **copy and modify** versus **reference in place**, and what each of
the file-list files (`vivadoprojectsources.txt`, `vivadoprojectdeps.txt`,
`lvtargetexcludefiles.txt`) is for.

If you are new to the repo, read the [README](../README.md) and the
[LabVIEW FPGA HDL Tools Theory of Operation](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/TheoryOfOperation.md)
first, then come back here when you want to understand *where the files come
from* and *how to customize them*.

## The two repositories

| Repository | Role |
| --- | --- |
| **flexrio-custom** (this repo) | Examples of **customized** FlexRIO targets. Use a target here as the starting point for your own application. |
| **flexrio** (base target) | The source code for the **base** FlexRIO target that each custom target builds on. The custom targets depend on it. |

The key idea: a custom target **copies only the top-level HDL file** from the
base target and modifies it. Everything else is **referenced in place** from the
base target and the other dependency repos, so you inherit the base target's
sources without duplicating them.

- Only the top-level VHDL file (for example, `MacallanTop.vhd` for the
  PXIe-7912) is copied into the custom target's `rtl-lvfpga/` folder and
  modified.
- All the other base-target files stay in the `deps/` folders and are pulled
  into the build by path references in `nihdlsettings.py`.
- You add your **own** custom VHDL and constraints files to the custom target
  alongside the copied top file.

> **Copy vs. reference:** Most of the time you only need to modify the top-level
> VHDL file. You *can* copy other base-target files into your custom target to
> modify them, but by default leave them referenced from the base target so you
> automatically pick up base-target updates.

## Dependency repositories

`nihdl install-deps` clones four dependency repositories into this repo's
`deps/` folder. The versions are controlled by
[`dependencies.toml`](../dependencies.toml) at the repo root.

| Dependency repo | What it provides |
| --- | --- |
| **flexrio** | The base FlexRIO target support (the target you customize on top of). |
| **flexrio-deps** | Additional base target support; these files are **encrypted**. |
| **hdl-shared** | Shared HDL such as host interfaces (registers, DMA FIFOs). Optional, but recommended. |
| **flexrio-clips** | The existing **socketed CLIP** VHDL normally used with FlexRIO boards in LabVIEW FPGA. You can instantiate this CLIP IP directly in the top-level `UserHdl.vhd` of your custom target to replicate a traditional socketed-CLIP LabVIEW FPGA target. |

Install (or refresh) all four with:

```bash
nihdl install-deps
```

This reads `dependencies.toml` and clones each repo into `deps/`. See the
[Command Reference](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/CommandReference.md)
for `install-deps` options.

### Version management

Which versions are synced is controlled in
[`dependencies.toml`](../dependencies.toml). For dependencies that use NI's
quarterly release versioning (for example, 2026 Q4 is version `2026.4.0`), NI
recommends keeping them all on the **same quarterly version**.

```toml
github_dependencies = [
    "ni/flexrio~=26.4.0.dev0",
    "ni/flexrio-deps~=26.4.0.dev0",
    "ni/flexrio-clips~=26.3.0",
    "ni/hdl-shared~=1.1.0.dev0",
]
```

## The file-list files

Each custom target's `nihdlsettings.py` builds the design from a few plain-text
file lists. Understanding what each one contains — and **which repo owns it** —
makes it clear what to change when you customize.

### `vivadoprojectsources.txt` (in the custom target)

The list of the **custom target's own** source files needed to build it in
Vivado — most importantly the **modified top-level VHDL file**. Because you use
the modified top file in this repo (not the one from the base target), the
custom target references its own `vivadoprojectsources.txt` instead of the base
target's source list. This is also where you add your own custom VHDL and any
shared HDL you pull in (for example, the `hdl-shared` host interface files).

### `vivadoprojectdeps.txt` (in the base FlexRIO target)

Lists all the files in the `flexrio-deps` folder used to compile the target.
Different targets use different sets of `flexrio-deps` files, so this list is
**specific to each base target**. The custom target's `nihdlsettings.py`
references this file from the base target so the custom build uses the **same
deps as the base target**.

### `lvtargetexcludefiles.txt` (in the base FlexRIO target)

Only relevant when building a **custom LabVIEW FPGA target plugin** (the
LabVIEW FPGA compile flow). It indicates which files from the GitHub source
repos should **not** be included in the custom LabVIEW FPGA target plugin.
LabVIEW FPGA provides some files during its code-generation step, so including
duplicates of those files in the custom target plugin causes errors. This file
excludes those to avoid the collision.

## How it fits together in `nihdlsettings.py`

The file lists are wired up with `add_hdl_file_list(...)` and
`add_lv_target_exclude_files(...)`. A typical PXIe-7912 custom target looks like
this (paths are relative to the target folder):

```python
base_deps = "../../deps/flexrio/targets/pxie-7912"   # base target in the flexrio repo

# HDL sources for the Vivado / LabVIEW FPGA compile flows
config.add_hdl_file_list(f"{base_deps}/vivadoprojectdeps.txt")   # base-target deps (flexrio-deps files)
config.add_hdl_file_list("vivadoprojectsources.txt")             # THIS target's sources (modified top file, custom HDL)
config.add_hdl_file_list("../../deps/flexrio-deps/hdl_shared_deps_list/hdlsharedvivadoprojectdeps.txt")

# Files to exclude from the custom LabVIEW FPGA target plugin
config.add_lv_target_exclude_files(f"{base_deps}/lvtargetexcludefiles.txt")
config.add_lv_target_exclude_files("../../deps/flexrio-deps/hdl_shared_deps_list/hdlsharedlvtargetexcludefiles.txt")
```

Notes:

- `base_deps` points into `deps/flexrio/...` — the **base target** cloned by
  `install-deps`.
- `vivadoprojectsources.txt` is a **local** path (no `deps/` prefix) — it is the
  custom target's own list, headed by the modified top-level VHDL file.
- The `hdl_shared_deps_list` files under `deps/flexrio-deps/` carry the shared
  HDL deps and their corresponding LabVIEW FPGA target exclusions.

If a dependency file collides by name with a target-specific copy, use
`add_exclude_hdl_file_list(...)` to drop the unwanted copy (see the
[Settings Reference](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/SettingsReference.md)).

## Generated VHDL

Not every source file in the build is authored by hand. The `nihdl` tools
**generate** some of the target's VHDL — the window instantiation and its
flatten/unflatten wrappers (from the custom-I/O CSV) and `PkgNiHdlSettings.vhd`
(HDL constants from `nihdlsettings.py`). These are registered with
`add_generated_vhdl_template(...)`, rendered into `objects/GeneratedHDL/` (a build
artifact that is **not** checked in), and then listed in
`vivadoprojectsources.txt` / `modelsimprojectsources.txt` like any other source.

They are generated — not hand-written — so the HDL and the LabVIEW FPGA target
plugin are driven from a **single source** (`nihdlsettings.py` and the custom-I/O
CSV) and cannot drift. For what is generated and why, see
[Generated VHDL](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/GeneratedVHDL.md).
Edit the source (`nihdlsettings.py` or the CSV), never the generated `.vhd`.

## Related documentation

- [README — Core Concepts and System Setup](../README.md)
- [Getting Started exercises](GettingStarted.md)
- [LabVIEW FPGA HDL Tools — Theory of Operation](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/TheoryOfOperation.md)
- [LabVIEW FPGA HDL Tools — Generated VHDL](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/GeneratedVHDL.md)
- [LabVIEW FPGA HDL Tools — Settings Reference](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/SettingsReference.md)
- [LabVIEW FPGA HDL Tools — Command Reference](https://github.com/ni/labview-fpga-hdl-tools/blob/main/docs/CommandReference.md)
</content>
</invoke>
