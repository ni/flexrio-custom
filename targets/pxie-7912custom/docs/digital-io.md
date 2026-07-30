# PXIe-7912 Custom Target — Digital IO (Aux DIO)

This document describes the host-accessible **Digital IO (Aux DIO)** interface
in the `UserHdl` block, and the theory of operation behind it. The source of
truth is [UserHdl.vhd](../rtl-lvfpga/UserHdl.vhd) and
[PkgUserHdl.vhd](../rtl-lvfpga/PkgUserHdl.vhd); regenerate this document if
those files change.

## Overview

The carrier exposes **8 Aux DIO lines** (`kNumDioLines = 8`) on the front
Aux connector. On this custom target the LabVIEW Window has board IO disabled
(`set_include_board_io_on_lv_window(False)`), so the 8 Aux DIO IO-Node
interfaces are routed into `UserHdl` and driven by a small register interface.

The host controls all 8 lines through **three 32-bit registers**:

| Offset | Name | Access | Purpose |
|--------|------|--------|---------|
| `0x20` | Direction  | R/W | Per-line direction: `1` = output, `0` = input |
| `0x24` | OutputData | R/W | Per-line output value (used when the line is an output) |
| `0x28` | Status     | RO  | Per-line live input value + Done/ready status |

All three registers are bit-per-line: **bit N corresponds to Aux DIO line N**
(`N = 0..7`). Bits above the used range read as `0`.

## Register details

### `0x20` — Direction (R/W)

| Bits | Field | Description |
|------|-------|-------------|
| `[7:0]` | Direction | Bit N: `1` = drive line N as an **output**, `0` = **input** (default) |
| `[31:8]` | Reserved | Reads `0` |

Reset default is `0x0000_0000` (all lines input).

### `0x24` — OutputData (R/W)

| Bits | Field | Description |
|------|-------|-------------|
| `[7:0]` | OutputData | Bit N: logic value driven on line N while it is configured as an output |
| `[31:8]` | Reserved | Reads `0` |

Writing this register while a line is an input has no effect on the pin; the
value is applied the moment the line becomes an output.

### `0x28` — Status (RO)

| Bits | Field | Description |
|------|-------|-------------|
| `[7:0]`  | InputData | Bit N: live logic value sampled on line N (valid for both input and output lines) |
| `[15:8]` | Done | Bit N: `1` once line N's requested direction has been applied by the carrier FixedLogic **and** the Aux DIO bank is enabled by firmware |
| `[31:16]` | Reserved | Reads `0` |

`InputData` is double-synchronized into the register clock domain before being
published, so it is safe to read at any time.

## Theory of operation

Each Aux DIO line has **two independent buffers** that must agree, and this is
the key to understanding the interface.

### Plane 1 — FPGA pin buffer (`UserHdl` controls directly)

Inside [MacallanIoBuffers.vhd](../../common/rtl-lvfpga/MacallanIoBuffers.vhd)
each line is a simple tri-state IOBUF:

```
aAuxIoData(i)         <= aLvAuxDioOutputData(i) when aLvAuxDioOutputEnable(i) = '1' else 'Z';
aLvAuxDioInputData(i) <= aAuxIoData(i);
```

- `OutputData` register bit → `aLvAuxDioOutputData`.
- `Direction` register bit (gated by Done, see below) → `aLvAuxDioOutputEnable`
  (`'1'` drives the pin, `'0'` tri-states it = input).
- Pin value → `aLvAuxDioInputData` → `Status[7:0]`.

### Plane 2 — External level translator (carrier FixedLogic controls)

The Aux connector also has an *external* bidirectional level translator whose
direction is owned by the carrier FixedLogic, negotiated over the LabVIEW
IO-Node handshake. The FSM is
[AuxIoDirectionCtrl.vhd](../../../../../../git/hw-flexrio/fixedlogic/design/us-usp/common/rtl/AuxIoDirectionCtrl.vhd)
and behaves exactly as:

- `oRequest` — held high by `UserHdl`, so the requested direction is always
  applied.
- `oDirection` — the `Direction` register bit: `1` requests the external buffer
  to drive **out**, `0` requests input. (`aAuxIoOutputEn <= oDirection`.)
- `oDone` — asserted 2 `BusClk` cycles after `oRequest`, **but only once the
  Aux DIO bank has been enabled by the board firmware** (`bAuxIoEnable`). This
  is surfaced to the host as `Status[15:8]`.

Dropping `oRequest` forces the external buffer back to input and clears `Done`;
`UserHdl` therefore keeps `oRequest` high at all times.

### How `UserHdl` combines the two planes

To avoid the FPGA fighting the external buffer while it is still switching (or
while the bank is disabled), `UserHdl` only enables the FPGA IOBUF once the
line's `Done` is asserted:

```
bDioOutEnable(i) <= bDioDirection(i) and bDioDoneSync(i);
```

So a line only actively drives its pin when **both** the host has set its
Direction bit to output **and** the carrier reports Done for that line.

## Host usage

### Drive a line as an output

1. Set the line's bit in **OutputData** (`0x24`) to the desired value.
2. Set the line's bit in **Direction** (`0x20`) to `1`.
3. Poll **Status** (`0x28`) bit `[8+N]` until Done = `1` (external buffer has
   switched and the bank is enabled). The pin now drives your value.

You may update **OutputData** at any time to change the driven value.

### Read a line as an input

1. Clear the line's bit in **Direction** (`0x20`) to `0` (the default).
2. Read **Status** (`0x28`) bit `[N]` for the live pin value.

`Status[7:0]` reflects the actual pin for every line, so you can also read back
the level of a line you are driving.

### Notes

- Direction and OutputData are independent per line — you can mix inputs and
  outputs across the 8 lines freely.
- If `Done` never asserts, the Aux DIO bank has not been enabled by the board
  firmware (or its Vcc has not been configured). No line will drive until the
  bank is enabled.
- The latency in the FPGA fabric is only 2 `BusClk` cycles; the meaningful wait
  is the firmware bank-enable reflected by `Done`.

## Address summary

| Offset | Register | Access |
|--------|----------|--------|
| `0x20` | Direction | R/W |
| `0x24` | OutputData | R/W |
| `0x28` | Status | RO |
