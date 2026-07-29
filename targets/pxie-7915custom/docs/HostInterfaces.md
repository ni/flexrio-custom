# PXIe-7915 Custom Target — Host Interfaces (Register & FIFO API)

Host-facing API reference for the PXIe-7915 **custom** target: every
host-accessible register and both DMA FIFOs exposed by the `UserHdl` block. The
source of truth is [PkgUserHdl.vhd](../rtl-lvfpga/PkgUserHdl.vhd) and
[UserHdl.vhd](../rtl-lvfpga/UserHdl.vhd); regenerate this document if those
files change.

This register layout is common to the FlexRIO custom targets; only the board
signature and the Digital IO section differ per target (see the common
[FlexRIO Digital IO](../../../docs/DigitalIO.md) document).

Every register is 32 bits and occupies 4 bytes of address space. Register
offsets are byte offsets into the UserHdl register space.

## Register block summary

| Block | Base offset | # Registers | Notes |
|-------|-------------|-------------|-------|
| Common host registers | `0x00` | 4  | Signature, Version, OldestCompatibleVersion, Scratch |
| Demo register array   | `0x10` | 4  | Loopback demo (out = in + 1) |
| Digital IO (Aux DIO)  | `0x20` | 3  | Direction / OutputData / Status — see [FlexRIO Digital IO](../../../docs/DigitalIO.md) |
| FIFO registers        | `0x3C` | 9  | Control/status + register bridges for the two DMA FIFOs |

## Common host registers (`0x00`)

| Offset | Name | Access | Description |
|--------|------|--------|-------------|
| `0x00` | Signature | RO | Fixed signature (`0x7915BEEF`) |
| `0x04` | Version | RO | Interface version (`0x00000001`) |
| `0x08` | OldestCompatibleVersion | RO | Oldest compatible interface version (`0x00000001`) |
| `0x0C` | Scratch | R/W | General-purpose scratch register |

## Demo register array (`0x10`)

| Offset | Name | Access | Description |
|--------|------|--------|-------------|
| `0x10` | LoopbackInA | R/W | Input A |
| `0x14` | LoopbackInB | R/W | Input B |
| `0x18` | LoopbackOutA | RO | Output A (= InA + 1) |
| `0x1C` | LoopbackOutB | RO | Output B (= InB + 1) |

Write a value to `LoopbackInA`, then read `LoopbackOutA` to see value + 1
(likewise for B). This demonstrates the FPGA-driven register array pattern.

## Digital IO registers (`0x20`)

Bit-per-line control of the **8** Aux DIO lines (bit N ↔ line N). This target
uses the **Aux DIO IO-Node** interface with a carrier direction handshake — see
the common [FlexRIO Digital IO](../../../docs/DigitalIO.md) document for the
hardware theory of operation.

| Offset | Name | Access | Description |
|--------|------|--------|-------------|
| `0x20` | Direction  | R/W | Bit N: `1` = output, `0` = input |
| `0x24` | OutputData | R/W | Bit N: value driven when line N is an output |
| `0x28` | Status     | RO  | `[7:0]` live input per line, `[15:8]` Done/ready per line |

> These three registers are a **demonstration** of the DIO capability, not the
> intended use case — the real interface is the Aux DIO IO-Node in your custom
> HDL. See Part 2 of the common [FlexRIO Digital IO](../../../docs/DigitalIO.md)
> document.

## FIFO registers (`0x3C`)

This target instantiates **one Reader FIFO** (Host-to-Target) and **one Writer
FIFO** (Target-to-Host). The FIFO registers provide stream control, status, and
register bridges that let the host exercise both DMA directions.

| Offset | Name | Access | Description |
|--------|------|--------|-------------|
| `0x3C` | WriterStartStop | R/W | Writer (Target-to-Host) stream control. Bit 0 = start, bit 1 = stop (strobed) |
| `0x40` | ReaderStartStop | R/W | Reader (Host-to-Target) stream control. Bit 0 = start, bit 1 = stop (strobed) |
| `0x44` | WriterCount | RO | Writer (Target-to-Host) FIFO free/empty count (room remaining) |
| `0x48` | ReaderCount | RO | Reader (Host-to-Target) FIFO occupancy (elements waiting) |
| `0x4C` | WriterState | RO | Writer stream state (2-bit `StreamStateValue_t`) |
| `0x50` | ReaderState | RO | Reader stream state (2-bit `StreamStateValue_t`) |
| `0x54` | WriterData | R/W | Write a 32-bit sample here to **push** it into the Writer (Target-to-Host) FIFO |
| `0x58` | ReaderStrobe | R/W | Any write **pops** one element from the Reader (Host-to-Target) FIFO |
| `0x5C` | ReaderData | RO | Latches the most recent element popped from the Reader FIFO |

## DMA FIFO host API

Both FIFOs carry a 32-bit signed (`I32`) element, one element per clock cycle.

| FIFO | Direction | Host data type | Depth | User conf index | DMA stream number |
|------|-----------|----------------|-------|-----------------|-------------------|
| Reader | Host-to-Target (`NiFpgaHostToTarget`) | I32 | 1029 | 0 | 59 |
| Writer | Target-to-Host (`NiFpgaTargetToHost`) | I32 | 1023 | 1 | 58 |

**DMA stream number derivation.** The user FIFOs occupy the DMA channels just
below the fixed-logic streams, growing downward from `kUserHdlDmaStartIndex`:

```
kUserHdlDmaStartIndex = kNumberOfDmaChannels − 1 − kNumFixedLogicDmaStreams
                      = 64 − 1 − 4 = 59
```

- User conf 0 (Reader, H→T) → DMA stream `59`
- User conf 1 (Writer, T→H) → DMA stream `58`

(`kNumberOfDmaChannels` comes from `PkgCommIntConfiguration`;
`kNumFixedLogicDmaStreams` from the generated `PkgNiHdlSettings` — `4` for
FlexRIO targets.)

### Using the Writer FIFO (Target-to-Host, DMA 58)

1. Start the stream: write `0x1` to `WriterStartStop` (`0x3C`).
2. Enqueue samples: write each 32-bit value to `WriterData` (`0x54`). Each write
   pushes one element into the Writer FIFO.
3. Read the samples back over DMA from stream **58** (e.g. `NiFpga_ReadFifoI32`).
4. Observe `WriterCount` (`0x44`) for free space and `WriterState` (`0x4C`).
5. Stop the stream: write `0x2` to `WriterStartStop`.

### Using the Reader FIFO (Host-to-Target, DMA 59)

1. Start the stream: write `0x1` to `ReaderStartStop` (`0x40`).
2. Write samples over DMA to stream **59** (e.g. `NiFpga_WriteFifoI32`).
3. Pop an element: write any value to `ReaderStrobe` (`0x58`).
4. Read the popped element from `ReaderData` (`0x5C`).
5. Observe `ReaderCount` (`0x48`) and `ReaderState` (`0x50`).
6. Stop the stream: write `0x2` to `ReaderStartStop`.

### Stream state encoding

`WriterState` / `ReaderState` return a 2-bit `StreamStateValue_t` in bits
`[1:0]` (upper bits read `0`).

## Full address map

| Offset | Register | Block | Access |
|--------|----------|-------|--------|
| `0x00` | Signature | Common | RO |
| `0x04` | Version | Common | RO |
| `0x08` | OldestCompatibleVersion | Common | RO |
| `0x0C` | Scratch | Common | R/W |
| `0x10` | LoopbackInA | Demo | R/W |
| `0x14` | LoopbackInB | Demo | R/W |
| `0x18` | LoopbackOutA | Demo | RO |
| `0x1C` | LoopbackOutB | Demo | RO |
| `0x20` | Direction | Digital IO | R/W |
| `0x24` | OutputData | Digital IO | R/W |
| `0x28` | Status | Digital IO | RO |
| `0x3C` | WriterStartStop | FIFO | R/W |
| `0x40` | ReaderStartStop | FIFO | R/W |
| `0x44` | WriterCount | FIFO | RO |
| `0x48` | ReaderCount | FIFO | RO |
| `0x4C` | WriterState | FIFO | RO |
| `0x50` | ReaderState | FIFO | RO |
| `0x54` | WriterData | FIFO | R/W |
| `0x58` | ReaderStrobe | FIFO | R/W |
| `0x5C` | ReaderData | FIFO | RO |
