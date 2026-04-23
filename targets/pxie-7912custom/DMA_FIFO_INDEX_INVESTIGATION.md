# DMA FIFO Channel Index Investigation

## Problem Statement

UserHdl DMA FIFOs **work at channel indices 2/3** but **fail at indices 4/5**.

The LV FPGA Window netlist (`TheWindowRunningFifos_2`) has compiled-in DMA FIFOs
at indices 0-3. Even though the DMA stream ports are fully disconnected between
TheWindow and the HostInterface for UserHdl channels, something about the
configuration allows indices 2/3 to work.

## Architecture Trace

### Host BAR Access Path

```
Host PCIe BAR0
  → InChWORM (PcieUsG3x8TandemInchwormNetlist.edf)
    → IwCompanionIsoPortN (per-project EDF netlist)
      ├── dDmaCommIfcRegPortIn  → DMA engine (DmaClk)
      ├── bLvWindowRegPortIn    → LV Window / TheWindow (BusClk)
      └── dFixedLogicBaRegPortIn → Fixed Logic (DmaClk)
```

### IwCompanion Address Routing — VERIFIED from source

The address routing is defined in `PkgPcieInchwormCompanionConfig.vhd`
(found at `hw-flexrio/common_source/iwcompanion/common/packages/`):

| BAR0 Address Range | RegPort Address Range | Target |
|---|---|---|
| `0x40000` – `0x6FFFC` | `0x00000` – `0x2FFFC` | LV Window (BusClk) |
| `0x70000` – `0x7FFFC` | `0x30000` – `0x3FFFC` | DMA Engine (DmaClk) |
| `0x10000` – `0x3FFFF` | `0x10000` – `0x3FFFF` | Fixed Logic (DmaClk) |

The DMA engine's RegPort window is **64KB** (`0x30000`–`0x3FFFC`), which covers
all 64 possible DMA channels (64 × 0x40 = 0x1000 bytes of registers each):

| Channel | BaseAddress | In DMA Window? |
|---------|-------------|----------------|
| 0 | `0x3FFC0` | Yes ✓ |
| 1 | `0x3FF80` | Yes ✓ |
| 2 | `0x3FF40` | Yes ✓ |
| 3 | `0x3FF00` | Yes ✓ |
| **4** | **`0x3FEC0`** | **Yes ✓** |
| **5** | **`0x3FE80`** | **Yes ✓** |

**Conclusion: IwCompanion address routing is NOT the issue.** All channel addresses
are within the DMA RegPort window.

The IwCompanion source (`IwCompanionIsoPortN.vhd`) performs address translation:
```vhdl
-- DMA RegPort translation
DmaRegPortTranslate: BaRegPortToLvFpgaRegPort
  generic map (kBaseAddress => 0x70000, kWindowSizeInBytes => 0x10000)

DmaRpAddressTranslation: process(dDmaCommIfcRegPortInL)
begin
  dDmaCommIfcRegPortIn.Address <= dDmaCommIfcRegPortInL.Address
                                  - (kLabViewRegPortBase / 4);  -- subtract 0x10000
end process;
```

This translates BAR0 address `0x7FEC0` → RegPort word address `0xFFB0` → byte
address `0x3FEC0`, correctly matching channel 4's BaseAddress.

### How I confirmed IwCompanion is per-project

File hash comparison between two VPE projects:

| File | Same? |
|------|-------|
| `IwCompanionIsoPortN.edf` | **DIFFERENT** |
| `PcieUsG3x8TandemInchwormNetlist.edf` | IDENTICAL |
| `DmaPortFixedDmaCommunicationInterface.vhd` | IDENTICAL |
| `PkgCommIntConfiguration.vhd` | IDENTICAL |

The IwCompanion EDF is generated per-project, but the address routing constants
(`PkgPcieInchwormCompanionConfig`) are **shared infrastructure** — the same values
are used regardless of project. The per-project differences are likely in the
IsoPort, reset sync, or other non-address-related logic.

### DMA Engine Per-Channel Registers

Inside `DmaPortFixedDmaCommunicationInterfaceCore`, a `for...generate` loop creates
per-channel blocks based on `kDmaFifoConfArray(i).Mode`:

- **TargetToHost** → `DmaPortCommIfcInputStream` (registers + input controller)
- **HostToTarget** → `DmaPortCommIfcOutputStream` (registers + output controller)
- **Disabled** → no register block, outputs tied to zero

Each active channel gets `DmaPortCommIfcRegisters` with
`kBaseOffset = kDmaFifoConfArray(i).BaseAddress`, responding to its own address range.

With channels 4/5 added as active in `kDmaFifoConfArray`, the DMA engine WILL
create register blocks and stream controllers for them. This is confirmed from
source code.

### Stream Interface Connectivity

For UserHdl channels, `MacallanTop` routes all 4 stream signals per channel to
`UserHdl` and drives TheWindow's inputs to zero:

```vhdl
-- UserHdl channels: all 4 signals connected to UserHdl via port map
UserHdlChannel: if i = kUserDmaWriterIdx or i = kUserDmaReaderIdx generate
  dWinInputStreamInterfaceToFifo(i)  <= kInputStreamInterfaceToFifoZero;
  dWinOutputStreamInterfaceToFifo(i) <= kOutputStreamInterfaceToFifoZero;
end generate;
```

The DMA engine's controllers talk directly to UserHdl's NiFifoWriter/NiFifoReader
via the stream interface. TheWindow is completely bypassed for UserHdl channels.

### LV Window's Interface.vhd

Interface.vhd does **NOT** contain DMA per-channel registers. Those live inside the
DMA engine (via `DmaPortFixedDmaCommunicationInterfaceCore`).

Interface.vhd contains:
1. **PIO block** — routes RegPort between communication interface and VI diagram
   (via bushold → controls/indicators, ViControl, ViSignature, DiagramReset)
2. **DMA block** — `DmaPortCommIfcFifos` instantiation (FIFO storage + diagram-side
   interface for channels 0-3)
3. **IRQ block** — interrupt routing
4. **MasterPort block** — master port connections

The RegPort flowing to/from Interface.vhd handles:
- ViSignature reads
- ViControl writes
- DiagramReset writes
- IRQ status/mask reads/writes
- Any VI diagram controls/indicators

It does **NOT** handle DMA FIFO registers (Control, Status, SATCR, FifoCount, etc.).

## Key Difference: Indices 2/3 vs 4/5

| Aspect | UserHdl at 2/3 | UserHdl at 4/5 |
|--------|----------------|----------------|
| `kDmaFifoConfArray` | **Unchanged** from original (4 active at 0-3) | **Modified** (6 active at 0-5) |
| DMA engine active channels | 4 (same as original) | 6 (2 more than original) |
| TheWindow FIFOs at UserHdl indices | **Active** (compiled in at 2/3) | **Disabled** (4/5 were disabled in original) |
| CodeGenerationResults.lvtxt | Uses **existing** entries (HdlTarget2Host/HdlHost2Target at 2/3) | **New** entries added (at 4/5) |
| DMA internal arbiter shape | Same as original (2 input + 2 output streams) | Changed (3 input + 3 output streams) |

The most significant difference is that **at indices 2/3, the entire DMA engine
configuration is identical to what the LV FPGA project was compiled with.** At
indices 4/5, the DMA engine has a different configuration than what the LV project
expected.

## ROOT CAUSE: NI-RIO Driver Requires Contiguous Channel Numbers

### Confirmed via `CompilationResults.cpp` (atomicrioddk)

The NI-RIO driver's bitfile parser (`CompilationResults.cpp`, line ~148) **requires
DMA channel numbers in the lvbitx to be a contiguous zero-based sequence `[0, 1, 2,
..., n-1]`**. Any gap in the sequence causes a `CorruptBitfile` error.

The critical code:

```cpp
// transfer from a map to a vector for more efficient access
size_t i = 0;
for (auto it = fifoMap.cbegin(), end = fifoMap.cend(); it != end; ++it, ++i)
{
   // the map shouldn't be sparsely filled, so we expect [0,n-1]
   if (it->first != i)
      NIRIO_THROW_1(StatusCode::CorruptBitfile,
                     "bitfile missing Channel with a certain Number", i);
   fifos.push_back(it->second);
}
```

**Source:** `ni-central/src/rio/riodriverd/atomicrioddk/source/atomicrioddk/user/CompilationResults.cpp`

### What happens with our channels at 4/5

Our `CodeGenerationResults.lvtxt` defines channels `{0, 1, 4, 5}`:
- Channel 0: Target2Host (LV Window)
- Channel 1: Host2Target (LV Window)
- Channel 4: HdlTarget2Host (UserHdl)
- Channel 5: HdlHost2Target (UserHdl)

The parser inserts them into a `std::map<uint32_t, NamedFifo>` sorted by Number,
then iterates expecting:
- `i=0` → finds `it->first=0` ✓
- `i=1` → finds `it->first=1` ✓
- `i=2` → finds `it->first=4` ✗ → **throws "bitfile missing Channel with a certain
  Number" with i=2**

### Why channels at 2/3 work

With channels `{0, 1, 2, 3}`, the sequence is contiguous:
- `i=0` → 0 ✓
- `i=1` → 1 ✓
- `i=2` → 2 ✓
- `i=3` → 3 ✓

### Verified via unit test

The `BitfileTest.cpp` test `SimplyParseAllBitfilesWithoutThrowingExceptions`
parses all `.lvbitx` files in the test directory. When our
`MacallanTopGH_FIFO_refactor_10.lvbitx` (with channels 0,1,4,5) is present, it
produces:

```
exception thrown when parsing bitfile:
  "source/test/unit/bitfiles/.\MacallanTopGH_FIFO_refactor_10.lvbitx"
{"reason":"bitfile missing Channel with a certain Number","values":{"i":2}}
```

## How I Analyzed the IwCompanion (EDF Netlist)

The `IwCompanionIsoPortN.edf` is encrypted and its internal logic cannot be directly
inspected. My analysis was based on:

1. **VHDL wrapper source** (`IwCompanionIsoPort.vhd` at
   `hw-flexrio/common_source/iwcompanion/iwcompanionisoport/rtl/`) — shows entity
   ports and flatten/unflatten wiring. The wrapper does NO address decode; all logic
   is in the netlist.

2. **Unencrypted source** (`IwCompanionIsoPortN.vhd` at the same location) — this is
   the VHDL source that gets compiled into the `.edf`. It shows the full architecture
   including:
   - `BaRegPortToLvFpgaRegPort` instances for LV Window and DMA engine RegPorts
   - Address gating for Fixed Logic RegPort
   - Address translation (subtracting `kLabViewRegPortBase/4` from word addresses)
   - The `BaRegPortClockCrossing` for LV Window (DmaClk → BusClk)

3. **Configuration package** (`PkgPcieInchwormCompanionConfig.vhd` at
   `hw-flexrio/common_source/iwcompanion/common/packages/`) — defines the address
   windows for each RegPort output.

4. **Hash comparison** — confirmed that `IwCompanionIsoPortN.edf` differs between VPE
   projects while `PcieUsG3x8TandemInchwormNetlist.edf` is identical, confirming the
   IwCompanion is compiled per-project.

## Recommendation

**Use channel indices 2/3 for UserHdl FIFOs.** This is the only viable option
without modifying the NI-RIO driver source code.

The constraint is fundamental: `CompilationResults.cpp` in `atomicrioddk` requires
dense `[0, n-1]` channel numbering. With LV Window FIFOs at 0/1, the UserHdl FIFOs
must be at 2/3 to maintain contiguity.

Placing them at 4/5 would require either:
- Adding dummy channels at 2/3 in the lvbitx (wasteful, and the FPGA hardware would
  need matching entries in `kDmaFifoConfArray`)
- Modifying `CompilationResults.cpp` to allow sparse channel numbering (requires
  driver rebuild and would affect all NI-RIO targets)
