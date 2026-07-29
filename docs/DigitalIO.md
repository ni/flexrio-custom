# FlexRIO Custom Targets — Digital IO

This document describes the **Digital IO (DIO)** capability shared across the
FlexRIO custom targets: the actual board DIO hardware interfaces that are routed
into `UserHdl`, how to use them, and — kept deliberately separate — the small
**register interface we ship as a demonstration only**.

> **Read this first:** The register interface (Direction / OutputData / Status)
> described in Part 2 and in each target's
> `docs/HostInterfaces.md` is **only a demonstration** that the DIO works from
> the host. It is **not** the intended use case. The real use case is to write
> your own HDL inside `UserHdl` that drives the hardware interfaces described in
> Part 1.

On every custom target the LabVIEW Window has board IO disabled
(`set_include_board_io_on_lv_window(False)`), so the board's DIO interfaces are
routed into `UserHdl` instead of the LabVIEW diagram. That is what makes the DIO
available to your custom HDL.

## DIO interface types by target

The FlexRIO custom family exposes DIO to `UserHdl` in three different ways.
Each target uses exactly one style:

| Target(s) | Interface type | Lines | Direction handshake |
|-----------|----------------|-------|---------------------|
| pxie-7912custom, pxie-7915custom, pxie-7981custom, pxie-7982custom, pxie-7985custom, pxie-7986custom | **Type A** — Aux DIO IO-Node | 8 | Yes |
| pxie-7903custom, pxie-7903-ddr1280custom | **Type B** — Direct bidirectional bus (`aDio`) | 8 | No |
| pxie-7994custom | **Type C** — Separated in/out/output-enable vectors (`aBaseDio`) | 32 | No |
| pxie-7911custom | None (no DIO routed into UserHdl) | — | — |
| pxie-7903aurora | n/a — this target has no `UserHdl` register/FIFO block | — | — |

---

# Part 1 — DIO hardware interfaces (the real interface)

## Type A — Aux DIO IO-Node with direction handshake

Targets: **7912, 7915, 7981, 7982, 7985, 7986**.

Each of the 8 Aux DIO lines is a LabVIEW-FPGA "IO Node" interface. Per line
`N` (0..7) `UserHdl` sees:

| Port | Dir | Meaning |
|------|-----|---------|
| `aLvAuxDioNOutputData` | out | Value to drive on the pin |
| `aLvAuxDioNInputData` | in | Value currently on the pin (asynchronous) |
| `aLvAuxDioNOutputEnable` | out | FPGA IOBUF tri-state: `1` drives, `0` releases (high-Z = input) |
| `oClkaLvAuxDioN` | in | Clock for the IO-Node logic (tied to `BusClk`) |
| `aoResetaLvAuxDioN` | in | Async reset (diagram reset) |
| `oDoneaLvAuxDioN` | in | Direction handshake: asserted by the carrier once the requested direction is applied |
| `oDirectionaLvAuxDioN` | out | Requested direction: `1` = drive OUT, `0` = input |
| `oRequestaLvAuxDioN` | out | Hold high to apply the requested direction |

### Two buffers must agree

Each line has **two** buffers, and both must point the same way:

1. **FPGA pin buffer** (`MacallanIoBuffers`) — controlled directly by
   `aLvAuxDioNOutputEnable`:
   ```
   pin              <= aLvAuxDioNOutputData when aLvAuxDioNOutputEnable = '1' else 'Z';
   aLvAuxDioNInputData <= pin;
   ```
2. **External level translator** on the Aux connector — its direction is owned
   by the carrier FixedLogic (`AuxIoDirectionCtrl`), negotiated over the
   `oRequest` / `oDirection` / `oDone` handshake.

### The direction handshake (`AuxIoDirectionCtrl`)

The carrier FixedLogic implements this behavior (`kClocksBeforeDone = 2`):

- **`oRequest`** — hold high. While high, the external buffer takes the
  requested direction; dropping it forces the external buffer back to input and
  clears `oDone`.
- **`oDirection`** — `1` requests the external buffer to drive **out**, `0`
  requests input.
- **`oDone`** — asserts ~2 `BusClk` cycles after `oRequest`, **but only once the
  Aux DIO bank has been enabled by the board firmware**. Until firmware enables
  the bank, `oDone` never asserts.

### How to use a line

Drive line N as an output:
1. Hold `oRequestaLvAuxDioN = '1'` and set `oDirectionaLvAuxDioN = '1'`.
2. Wait for `oDoneaLvAuxDioN = '1'` (external buffer switched and bank enabled).
3. Drive `aLvAuxDioNOutputData` and set `aLvAuxDioNOutputEnable = '1'`.

Read line N as an input:
1. `aLvAuxDioNOutputEnable <= '0'` (release the FPGA IOBUF).
2. Request the input direction (`oDirection = '0'`, `oRequest = '1'`) and wait
   for `oDoneaLvAuxDioN`.
3. Sample `aLvAuxDioNInputData` (synchronize it into your clock domain first —
   it is asynchronous).

To avoid the FPGA fighting the external buffer while it is still switching, gate
your FPGA output enable on `oDone` (drive the pin only once `oDone` is
asserted).

## Type B — Direct bidirectional bus (`aDio`)

Targets: **7903, 7903-ddr1280**.

The base-board DIO is a single, direct bidirectional bus that `UserHdl` owns:

```
aDio : inout std_logic_vector(7 downto 0);
```

There is **no** external buffer/direction handshake — the FPGA tri-states the
bus itself. Per line:

```
aDio(i)   <= <your output value> when <output> else 'Z';   -- drive or release
<your input> := aDio(i);                                    -- read (synchronize first)
```

Drive a line by assigning it; read a line by releasing it (`'Z'`) and sampling
`aDio(i)`.

## Type C — Separated in/out/output-enable vectors (`aBaseDio`)

Target: **7994**.

The 32-line base-board DIO bus is presented to `UserHdl` already split into
three vectors (the carrier does the tri-state buffering):

| Port | Dir | Meaning |
|------|-----|---------|
| `aBaseDioIn` | in | Value on each pin (asynchronous) |
| `aBaseDioOut` | out | Value to drive when the line is an output |
| `aBaseDioOutEn` | out | Per-line output enable: `1` = drive, `0` = input |

There is **no** direction handshake. Per line:

```
aBaseDioOut(i)   <= <your output value>;
aBaseDioOutEn(i) <= <output? '1' : '0'>;
<your input>     := aBaseDioIn(i);   -- read (synchronize first)
```

## Targets without DIO

- **pxie-7911custom** — no DIO is routed into `UserHdl`.
- **pxie-7903aurora** — has no `UserHdl` register/FIFO block at all; it is a
  different kind of target and is out of scope for this document.

---

# Part 2 — The example register interface (demonstration only)

To make it easy to see the DIO working from a host program **without writing any
custom HDL**, `UserHdl` on every DIO-capable target adds a tiny three-register
interface. **This is a demonstrator, not the intended use case.** In a real
design you would delete it and drive the Part 1 hardware interfaces directly
from your own HDL.

The three registers (byte offsets `0x20` / `0x24` / `0x28`) are:

| Offset | Name | Access | Meaning |
|--------|------|--------|---------|
| `0x20` | Direction | R/W | Bit N: `1` = output, `0` = input |
| `0x24` | OutputData | R/W | Bit N: value driven when line N is an output |
| `0x28` | Status | RO | Live input per line (plus Done on Type A) |

How `UserHdl` maps these to the hardware differs by interface type:

- **Type A (handshake):** `oRequest` is held high, `oDirection` = the Direction
  bit, and the FPGA output enable is gated on `oDone`. `Status[7:0]` is the live
  input, `Status[15:8]` is the per-line `Done`.
- **Type B (`aDio`):** `aDio(i)` is driven when the Direction bit is set, else
  released; `Status[7:0]` is the live input. (No Done — no handshake exists.)
- **Type C (`aBaseDio`):** `aBaseDioOut`/`aBaseDioOutEn` are driven from the
  OutputData/Direction registers; `Status[31:0]` is the live input. (No Done.)

The exact register map, bit fields and line counts for each target are in that
target's [`docs/HostInterfaces.md`](../targets/). Line counts: 8 for Type A and
Type B, 32 for Type C.

The register interface is placed in the address gap between the demo register
array (ends `0x1C`) and the FIFO registers (`0x3C`), so it does not change the
rest of the register map.
