# PXIe-7912 FIFO Test Target — Register Map

This document describes the host-accessible registers used by the FIFO
loopback test target. The source of truth is
[PkgUserHdl.vhd](../rtl-lvfpga/PkgUserHdl.vhd); regenerate this table if that
file changes.

## Overview

The `UserHdl` block instantiates **7 FIFO loopback pairs**
(`kNumLoopbackPairs = 7`). Each pair contains one **Reader** FIFO
(Host-to-Target) and one **Writer** FIFO (Target-to-Host) wired together in
hardware, so data the host streams into the Reader is automatically looped back
out through the Writer. No host-facing data-path registers are required —
only control/status registers.

Every register is 32 bits and occupies 4 bytes of address space.

## Register block summary

| Block | Base offset | # Registers | Notes |
|-------|-------------|-------------|-------|
| Common host registers | `0x00` | 4 | Signature, Version, OldestCompatibleVersion, Scratch |
| Demo register array | `0x10` | 4 | Loopback demo (out = in + 1) |
| FIFO registers | `0x3C` | 42 | 6 registers per pair × 7 pairs |

## Common host registers (`0x00`)

| Offset | Name | Access | Description |
|--------|------|--------|-------------|
| `0x00` | Signature | RO | Fixed signature (`0x7912BEEF`) |
| `0x04` | Version | RO | Interface version |
| `0x08` | OldestCompatibleVersion | RO | Oldest compatible interface version |
| `0x0C` | Scratch | R/W | General-purpose scratch register |

## Demo register array (`0x10`)

| Offset | Name | Access | Description |
|--------|------|--------|-------------|
| `0x10` | LoopbackInA | R/W | Input A |
| `0x14` | LoopbackInB | R/W | Input B |
| `0x18` | LoopbackOutA | RO | Output A (= InA + 1) |
| `0x1C` | LoopbackOutB | RO | Output B (= InB + 1) |

## FIFO registers (`0x3C`)

Each loopback pair exposes a fixed block of **6 registers**
(`kNumRegsPerFifoPair = 6`, 24-byte / `0x18` stride per pair):

| Per-pair offset | Name | Access | Description |
|-----------------|------|--------|-------------|
| `+0` | WriterStartStop | R/W | Writer (Target-to-Host) stream control. Bit 0 = start, bit 1 = stop (strobed) |
| `+1` | ReaderStartStop | R/W | Reader (Host-to-Target) stream control. Bit 0 = start, bit 1 = stop (strobed) |
| `+2` | WriterCount | RO | Writer (Target-to-Host) FIFO **empty/free** count (elements of room remaining). Idles at its maximum when drained. |
| `+3` | ReaderCount | RO | Reader (Host-to-Target) FIFO **occupancy** (elements waiting to be looped back) |
| `+4` | WriterState | RO | Writer stream state (2-bit `StreamStateValue_t`) |
| `+5` | ReaderState | RO | Reader stream state (2-bit `StreamStateValue_t`) |

### Per-pair data types

Within a pair, the Reader and Writer share `FifoWidth` and
`ElementsPerClockCycle`. All pairs use `ElementsPerClockCycle = 1`, Reader
depth = 1029, Writer depth = 1023.

The Reader (Host-to-Target) and Writer (Target-to-Host) FIFOs for each pair are
identified by two indices:

- **User conf index** — position within `kUserHdlDmaFifoConf` in `PkgUserHdl.vhd`
  (Reader = `2p`, Writer = `2p+1`).
- **DMA stream index** — position in the full 64-entry `kDmaFifoConfArray` used
  by the hardware and the host C API. Derived as
  `kUserHdlDmaStartIndex − user_conf_index` where
  `kUserHdlDmaStartIndex = kNumberOfDmaChannels(64) − 1 − kNiFpgaFixedInputPorts(3) − kNiFpgaFixedOutputPorts(2) = 58`.

| Pair | Width (bits) | Signed | FxpType | Host data type | H→T conf | H→T DMA | T→H conf | T→H DMA |
|------|--------------|--------|---------|----------------|----------|---------|----------|---------|
| 0 | 32 | yes | no  | I32                         |  0 | 58 |  1 | 57 |
| 1 | 16 | no  | no  | U16                         |  2 | 56 |  3 | 55 |
| 2 | 8  | yes | no  | I8                          |  4 | 54 |  5 | 53 |
| 3 | 8  | no  | no  | U8 (BOOLEAN in driver test) |  6 | 52 |  7 | 51 |
| 4 | 64 | no  | no  | U64                         |  8 | 50 |  9 | 49 |
| 5 | 64 | yes | no  | I64 (SGL in driver test)    | 10 | 48 | 11 | 47 |
| 6 | 64 | yes | yes | FXP (64-bit fixed-point signed) | 12 | 46 | 13 | 45 |

### Full address map

Pair `p` base address = `0x3C + p * 0x18`. Register byte address =
pair base + per-pair offset × 4.

| Pair | WriterStartStop | ReaderStartStop | WriterCount | ReaderCount | WriterState | ReaderState |
|------|-----------------|-----------------|-------------|-------------|-------------|-------------|
| 0 | `0x3C` | `0x40` | `0x44` | `0x48` | `0x4C` | `0x50` |
| 1 | `0x54` | `0x58` | `0x5C` | `0x60` | `0x64` | `0x68` |
| 2 | `0x6C` | `0x70` | `0x74` | `0x78` | `0x7C` | `0x80` |
| 3 | `0x84` | `0x88` | `0x8C` | `0x90` | `0x94` | `0x98` |
| 4 | `0x9C` | `0xA0` | `0xA4` | `0xA8` | `0xAC` | `0xB0` |
| 5 | `0xB4` | `0xB8` | `0xBC` | `0xC0` | `0xC4` | `0xC8` |
| 6 | `0xCC` | `0xD0` | `0xD4` | `0xD8` | `0xDC` | `0xE0` |
