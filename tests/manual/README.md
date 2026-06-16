# Manual target tests

This folder holds the manual test harness for the FlexRIO custom targets. It
runs `nihdl` subcommands across every target (and test-target) through a shared
wrapper so the runs use known-good, machine-independent paths instead of the
per-developer paths baked into each target's own `nihdlsettings.py`.

There is exactly one entry point: [`run_tests.py`](run_tests.py). The old
per-command `run_<command>.py` scripts are gone; everything is a "test" key or a
named "sequence" now.

## Prerequisites

- Python 3.11+
- `nihdl` on your `PATH` (or pass `--nihdl-cmd C:/path/to/nihdl.exe`). The
  version of `nihdl` must be recent enough to understand the generic
  `--set KEY=VALUE` option, since the wrapper relies on it. An older `nihdl`
  will reject `--set` and the tests will fail before doing any real work.
- Vivado / LabVIEW FPGA installed for the commands that need them.

## Quick start

```powershell
# See everything that's available (tests and sequences):
python run_tests.py --list

# Run a single test across all targets:
python run_tests.py check-vivado

# Run a couple of tests, in order:
python run_tests.py gen-vivado compile-vivado

# Run a predefined workflow:
python run_tests.py --sequence check-shipping-netlists

# Run interactively (you'll be prompted to pick the tests):
python run_tests.py
```

Tests run in the exact order you list them. The harness keeps going even if a
test fails, then prints a per-test summary and an overall summary at the end.

## Concepts

The harness has two layers you can drive from the command line:

- **Tests** — a thin label over a single `nihdl` subcommand, run once per
  target. Use these when you want fine-grained control.
- **Sequences** — a named, ordered bundle of tests with the correct *netlist
  mode* already applied. Use these when you want a whole workflow and don't want
  to remember which flags go with which step.

### Tests

Each test maps to one `nihdl` subcommand. Run `python run_tests.py --list` for
the authoritative list; at time of writing:

| Test             | nihdl command            | What it does                                      |
| ---------------- | ------------------------ | ------------------------------------------------- |
| `gen-vivado`     | `gen-vivado --overwrite` | Generate (overwrite) the Vivado project           |
| `compile-vivado` | `compile-vivado`         | Compile the Vivado project and generate the bitfile |
| `check-vivado`   | `check-vivado`           | Check RTL syntax/hierarchy via Vivado elaboration |
| `gen-window`     | `gen-window`             | Generate the LabVIEW window netlist               |
| `gen-target`     | `gen-target`             | Generate LabVIEW FPGA target support files        |
| `install-target` | `install-target`         | Install LabVIEW FPGA target support files         |

The options of each underlying `nihdl` subcommand are owned by `nihdl`, not by
this script. To discover them, ask `nihdl` directly, e.g. `nihdl gen-vivado
--help`.

### Sequences

Sequences are the recommended way to drive a real workflow. Run one with
`--sequence <key>`:

| Sequence                  | Steps                                       | Netlist mode               |
| ------------------------- | ------------------------------------------- | -------------------------- |
| `setup-targets`           | `gen-target` → `install-target`             | (none)                     |
| `check-shipping-netlists` | `gen-vivado` → `compile-vivado`             | uses checked-in netlists   |
| `test-netlists`           | `gen-window` → `gen-vivado` → `compile-vivado` | reads `objects/` netlist |
| `update-shipping-netlists`| `gen-window` → `gen-vivado` → `compile-vivado` | writes shipping netlist  |

A typical end-to-end flow:

1. `python run_tests.py --sequence setup-targets`
   Generates and installs the target support files. **Then manually open
   LabVIEW and generate the VPEs (Vivado project exports) for all projects** —
   the harness can't do that part for you.
2. `python run_tests.py --sequence check-shipping-netlists`
   Sanity-check that the netlists already committed to the repo still build and
   compile.
3. `python run_tests.py --sequence test-netlists`
   Regenerate netlists into the scratch `objects/` folder and build/compile from
   them. The checked-in shipping netlists are left untouched — this is your "try
   it before you commit it" pass.
4. `python run_tests.py --sequence update-shipping-netlists`
   Regenerate the checked-in shipping netlists, then build/compile from them.
   Run this when you're ready to refresh what gets committed to GitHub.

A sequence sets the netlist mode itself, so do **not** combine `--sequence` with
bare test keys or with the `--useobjectslvwindow` / `--writeshippingnetlist`
flags; the harness will reject those combinations.

## Netlist modes (the permutations)

There are two independent window-netlist folders, and the interesting
permutations come from which one each step touches:

- **Input** (`set_lv_window_netlist_folder`) — where `gen-vivado` *reads* the
  window netlist from.
- **Output** (`set_lv_window_netlist_output_folder`) — where `gen-window`
  *writes* the netlist to.

Two flags control them, mapped onto generic `nihdl` `--set` overrides:

| Flag                    | Affects             | Effect                                                                                          |
| ----------------------- | ------------------- | ----------------------------------------------------------------------------------------------- |
| `--useobjectslvwindow`  | `gen-vivado` input  | Read the input netlist from the target's `objects/testLvWindowNetlist` (the generated scratch one) instead of the target's configured folder. Maps to `--set lv_window_input=objects`. |
| `--writeshippingnetlist`| `gen-window` output | Write the generated netlist to the checked-in shipping folder at the target root (`blankLvWindowNetlist`, or `fifoTestLvWindowNetlist` for PXIe-7912fifotest) instead of the scratch `objects/` folder. Maps to `--set lv_window_output=shipping`. |

The two flags are mutually exclusive on the command line and target different
subcommands. Defaults if you pass neither:

- `gen-window` writes to the scratch `objects/testLvWindowNetlist` folder.
- `gen-vivado` reads the folder configured in the target's own
  `nihdlsettings.py` (i.e. the checked-in shipping netlist).

The four sequences are just convenient names for the useful combinations of
these modes, so most of the time you should reach for `--sequence` rather than
the raw flags.

## Target selection

By default every target is scanned out of the targets folder and the
test-targets folder (any directory containing a `nihdlsettings.py`). To narrow
the run:

- `--target NAME` — run on just the named target folder, e.g.
  `--target pxie-7903custom`. Repeatable to select several. Matching is
  case-insensitive against the target directory name and requires an exact name
  (so `--target 7903` matches nothing; `--target pxie-7903custom` matches one).
  Handy for rerunning a failing sequence on a single target.
- `--targets-dir PATH` / `--test-targets-dir PATH` — point at different folders.

If a `--target` name matches nothing, the harness warns and lists the targets it
actually found.

## Options reference

These belong to `run_tests.py` itself (not to the underlying `nihdl`
subcommands):

| Option                   | Description                                                                 |
| ------------------------ | --------------------------------------------------------------------------- |
| `tests` (positional)     | One or more test keys, in run order. Omit to choose interactively.          |
| `--sequence NAME`        | Run a predefined workflow. Cannot be combined with test keys or the netlist flags. |
| `--list`                 | List available tests and sequences, then exit.                              |
| `--useobjectslvwindow`   | `gen-vivado` reads the `objects/` netlist (see Netlist modes).              |
| `--writeshippingnetlist` | `gen-window` writes the checked-in shipping netlist (see Netlist modes).    |
| `--target NAME`          | Run on just the named target(s). Repeatable.                                |
| `--targets-dir PATH`     | Override the targets folder.                                                |
| `--test-targets-dir PATH`| Override the test-targets folder.                                           |
| `--nihdl-cmd CMD`        | Command name or full path for the `nihdl` executable (default: `nihdl`).    |

Run `python run_tests.py --help` for the full, always-current list.

## Examples

```powershell
# List tests and sequences
python run_tests.py --list

# Workflows
python run_tests.py --sequence setup-targets
python run_tests.py --sequence check-shipping-netlists
python run_tests.py --sequence test-netlists
python run_tests.py --sequence update-shipping-netlists

# Re-run a sequence on just the one target that misbehaved
python run_tests.py --sequence check-shipping-netlists --target pxie-7903custom

# Individual tests
python run_tests.py check-vivado
python run_tests.py gen-vivado compile-vivado

# Raw netlist-mode flags (advanced; sequences usually cover these)
python run_tests.py gen-vivado --useobjectslvwindow
python run_tests.py gen-window --writeshippingnetlist

# Use a specific nihdl build
python run_tests.py compile-vivado --nihdl-cmd C:/path/to/nihdl.exe
```

## How it works under the hood

`run_tests.py` invokes `nihdl <command> --config=<this folder>/nihdlsettings.py`
in each target directory. That shared
[`nihdlsettings.py`](nihdlsettings.py) wrapper loads the target's own settings,
then applies test overrides for machine-independent paths:

- The VPE project export (`.xpr`) path is always overridden to
  `c:\temp\testVPE\<TargetName>_VPE\VivadoProject\<xpr>`.
- The window-netlist input/output folders follow the netlist mode described
  above, driven entirely by `nihdl`'s generic `--set KEY=VALUE` overrides
  (`lv_window_input`, `lv_window_output`) — no per-variant wrapper files and no
  environment variables.

The recognized `--set` keys and the override logic live in `apply_test_overrides`
/ `pre_all` inside `nihdlsettings.py`.
