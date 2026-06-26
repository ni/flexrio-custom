------------------------------------------------------------------------------------------
--
-- File: PkgUserHdl.vhd
--
------------------------------------------------------------------------------------------
-- (c) 2026 Copyright National Instruments Corporation
--
-- SPDX-License-Identifier: MIT
------------------------------------------------------------------------------------------
--
-- Purpose:
--   User-editable configuration constants for the UserHdl block:
--   DMA FIFO channel definitions, demo register layout, and FIFO register
--   layout.
--
--
------------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;
  use work.PkgCommIntConfiguration.all;
  use work.PkgNiSharedFifo.all;
  use work.PkgNiHdlSettings.all;

package PkgUserHdl is

  ---------------------------------------------------------------------------
  -- DMA FIFO channel configuration
  ---------------------------------------------------------------------------
  -- The UserHdl block instantiates kNumLoopbackPairs FifoLoopbackPair blocks.
  -- Each pair uses two DMA channels (config indices), laid out as:
  --   config(2*p)   = Reader (Host-to-Target) for pair p
  --   config(2*p+1) = Writer (Target-to-Host) for pair p
  -- Within a pair the Reader and Writer must share DataType and
  -- ElementsPerClockCycle so popped Reader data can be pushed into the Writer.
  --
  -- kNumHdlFifos is the single source of truth from nihdlsettings.py
  -- (set_num_hdl_fifos), pushed into the HDL via the generated PkgNiHdlSettings
  -- package. Each loopback pair consumes two DMA channels, so the number of
  -- pairs is half the FIFO count. UserHdl asserts (kNumHdlFifos mod 2 = 0) and
  -- that the kUserHdlDmaFifoConf aggregate below has exactly kNumHdlFifos
  -- elements (range/aggregate mismatch otherwise fails analysis).
  constant kNumLoopbackPairs      : natural := kNumHdlFifos / 2;

  -- DataType              : host data type for the FIFO. The element width and
  --                         signedness are derived automatically. Valid values:
  --                           kBoolean                 (Boolean, maps to U8)
  --                           kUnsigned8  / kInteger8  (U8  / I8)
  --                           kUnsigned16 / kInteger16 (U16 / I16)
  --                           kUnsigned32 / kInteger32 (U32 / I32)
  --                           kUnsigned64 / kInteger64 (U64 / I64)
  --                           kSingle                  (SGL, single-precision float)
  -- ElementsPerClockCycle : 1, 2, 4, 8, 16, 32, or 64
  -- Mode                  : NiFpgaHostToTarget or NiFpgaTargetToHost
  --
  -- FifoDepth (TargetToHost / PeerToPeer Writer):
  --   2^N - 1, minimum 63, maximum 1048575 (2^20 -1)
  --
  -- FifoDepth (HostToTarget / PeerToPeer Reader):
  -- *** NOTE: For HostToTarget FIFOs, add 6*ElementsPerClockCycle to the desired size of the FIFO to account for
  -- *** the additional buffering required for the NI DMA engine to achieve maximum throughput.
  --   (2^N + 6*(ElementsPerClockCycle)) -1

  -- for boolean data types, the max fifo width is 2097151 (2^21 - 1)
  -- for 16-bit data types, the max fifo width is 1048575 (2^20 - 1)
  -- for 32-bit data types, the max fifo width is 524287 (2^19 - 1)
  -- for 64-bit data types, the max fifo width is 262143 (2^18 - 1)
  --
  -- All pairs use a nominal 1024-element FIFO: Reader depth = 1024 + 6*1 - 1 = 1029,
  -- Writer depth = 1024 - 1 = 1023 (ElementsPerClockCycle = 1).

  constant kUserHdlDmaFifoConf : UserDmaFifoConfArray_t(0 to kNumHdlFifos - 1) := (
    -- Pair 0: I32 (32-bit signed)
    0  => (FifoDepth => 1029, DataType => kInteger32, ElementsPerClockCycle => 1, Mode => NiFpgaHostToTarget),
    1  => (FifoDepth => 1023, DataType => kInteger32, ElementsPerClockCycle => 1, Mode => NiFpgaTargetToHost),
    -- Pair 1: U16 (16-bit unsigned)
    2  => (FifoDepth => 1029, DataType => kUnsigned16, ElementsPerClockCycle => 1, Mode => NiFpgaHostToTarget),
    3  => (FifoDepth => 1023, DataType => kUnsigned16, ElementsPerClockCycle => 1, Mode => NiFpgaTargetToHost),
    -- Pair 2: I8 (8-bit signed)
    4  => (FifoDepth => 1029, DataType => kInteger8,   ElementsPerClockCycle => 1, Mode => NiFpgaHostToTarget),
    5  => (FifoDepth => 1023, DataType => kInteger8,   ElementsPerClockCycle => 1, Mode => NiFpgaTargetToHost),
    -- Pair 3: Boolean (maps to U8)
    6  => (FifoDepth => 1029, DataType => kBoolean,    ElementsPerClockCycle => 1, Mode => NiFpgaHostToTarget),
    7  => (FifoDepth => 1023, DataType => kBoolean,    ElementsPerClockCycle => 1, Mode => NiFpgaTargetToHost),
    -- Pair 4: U64 (64-bit unsigned)
    8  => (FifoDepth => 1029, DataType => kUnsigned64, ElementsPerClockCycle => 1, Mode => NiFpgaHostToTarget),
    9  => (FifoDepth => 1023, DataType => kUnsigned64, ElementsPerClockCycle => 1, Mode => NiFpgaTargetToHost),
    -- Pair 5: SGL (single-precision float, 64-bit element)
    10 => (FifoDepth => 1029, DataType => kSingle,     ElementsPerClockCycle => 1, Mode => NiFpgaHostToTarget),
    11 => (FifoDepth => 1023, DataType => kSingle,     ElementsPerClockCycle => 1, Mode => NiFpgaTargetToHost),
    -- Pair 6: I64 (64-bit signed)
    12 => (FifoDepth => 1029, DataType => kInteger64,  ElementsPerClockCycle => 1, Mode => NiFpgaHostToTarget),
    13 => (FifoDepth => 1023, DataType => kInteger64,  ElementsPerClockCycle => 1, Mode => NiFpgaTargetToHost)
  );

  ---------------------------------------------------------------------------
  -- Common host registers (4 registers starting at byte offset 0x00)
  ---------------------------------------------------------------------------
  -- 0x00: Signature              (host RO)
  -- 0x04: Version                (host RO)
  -- 0x08: OldestCompatibleVersion (host RO)
  -- 0x0C: Scratch                (host R/W)

  ---------------------------------------------------------------------------
  -- Demo register array (4 registers starting at byte offset 0x10)
  ---------------------------------------------------------------------------
  constant kDemoRegsBaseAddress : natural := 16#10#;
  constant kNumDemoRegs : natural := 4;

  constant kLoopbackInAIdx  : natural := 0;  -- offset 0x10: host R/W input A
  constant kLoopbackInBIdx  : natural := 1;  -- offset 0x14: host R/W input B
  constant kLoopbackOutAIdx : natural := 2;  -- offset 0x18: host RO output (A+1)
  constant kLoopbackOutBIdx : natural := 3;  -- offset 0x1C: host RO output (B+1)

  ---------------------------------------------------------------------------
  -- FIFO register array (starting at byte offset 60)
  --
  -- The Reader and Writer FIFOs in each pair are wired together in hardware
  -- (loopback), so no host-facing data-path registers are required. Each pair
  -- exposes a fixed block of kNumRegsPerFifoPair control/status registers:
  --   +0 WriterStartStop (R/W)   +3 ReaderCount (RO)
  --   +1 ReaderStartStop (R/W)   +4 WriterState (RO)
  --   +2 WriterCount     (RO)    +5 ReaderState (RO)
  -- Pair p occupies register indices [p*kNumRegsPerFifoPair .. +5].
  ---------------------------------------------------------------------------
  constant kFifoRegsBaseAddress : natural := 16#3C#;
  constant kNumRegsPerFifoPair  : natural := 6;
  constant kNumFifoRegs         : natural := kNumLoopbackPairs * kNumRegsPerFifoPair;

  -- Per-pair register offsets
  constant kWriterStartStopOffset : natural := 0;
  constant kReaderStartStopOffset : natural := 1;
  constant kWriterCountOffset     : natural := 2;
  constant kReaderCountOffset     : natural := 3;
  constant kWriterStateOffset     : natural := 4;
  constant kReaderStateOffset     : natural := 5;

  -- Build the kReadOnly vector for the FIFO register array. Per pair the
  -- StartStop registers are writable; Count and State registers are read-only.
  function FifoRegReadOnly return BooleanVector;

end PkgUserHdl;

package body PkgUserHdl is

  function FifoRegReadOnly return BooleanVector is
    variable Result : BooleanVector(0 to kNumFifoRegs - 1);
  begin
    for p in 0 to kNumLoopbackPairs - 1 loop
      Result(p * kNumRegsPerFifoPair + kWriterStartStopOffset) := false;
      Result(p * kNumRegsPerFifoPair + kReaderStartStopOffset) := false;
      Result(p * kNumRegsPerFifoPair + kWriterCountOffset)     := true;
      Result(p * kNumRegsPerFifoPair + kReaderCountOffset)     := true;
      Result(p * kNumRegsPerFifoPair + kWriterStateOffset)     := true;
      Result(p * kNumRegsPerFifoPair + kReaderStateOffset)     := true;
    end loop;
    return Result;
  end function;

end PkgUserHdl;
