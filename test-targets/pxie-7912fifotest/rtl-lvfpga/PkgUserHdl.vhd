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

package PkgUserHdl is

  ---------------------------------------------------------------------------
  -- DMA FIFO channel configuration
  ---------------------------------------------------------------------------
  -- The UserHdl block instantiates kNumLoopbackPairs FifoLoopbackPair blocks.
  -- Each pair uses two DMA channels (config indices), laid out as:
  --   config(2*p)   = Reader (Host-to-Target) for pair p
  --   config(2*p+1) = Writer (Target-to-Host) for pair p
  -- Within a pair the Reader and Writer must share FifoWidth and
  -- ElementsPerClockCycle so popped Reader data can be pushed into the Writer.
  constant kNumLoopbackPairs      : natural := 7;
  constant kNumUserHdlDmaChannels : natural := kNumLoopbackPairs * 2;

  -- FifoWidth             : 1..64 (host types: Boolean, U/I[8,16,32,64], FXP, SGL-64)
  -- ElementsPerClockCycle : 1, 2, 4, 8, 16, 32, or 64
  -- Mode                  : NiFpgaHostToTarget or NiFpgaTargetToHost
  -- SignedData            : true if host data type is signed
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

  constant kUserHdlDmaFifoConf : UserDmaFifoConfArray_t(0 to kNumUserHdlDmaChannels - 1) := (
    -- Pair 0: 32-bit signed
    0  => (FifoDepth => 1029, FifoWidth => 32, ElementsPerClockCycle => 1, Mode => NiFpgaHostToTarget, SignedData => true),
    1  => (FifoDepth => 1023, FifoWidth => 32, ElementsPerClockCycle => 1, Mode => NiFpgaTargetToHost, SignedData => true),
    -- Pair 1: 16-bit unsigned
    2  => (FifoDepth => 1029, FifoWidth => 16, ElementsPerClockCycle => 1, Mode => NiFpgaHostToTarget, SignedData => false),
    3  => (FifoDepth => 1023, FifoWidth => 16, ElementsPerClockCycle => 1, Mode => NiFpgaTargetToHost, SignedData => false),
    -- Pair 2: 8-bit signed
    4  => (FifoDepth => 1029, FifoWidth => 8,  ElementsPerClockCycle => 1, Mode => NiFpgaHostToTarget, SignedData => true),
    5  => (FifoDepth => 1023, FifoWidth => 8,  ElementsPerClockCycle => 1, Mode => NiFpgaTargetToHost, SignedData => true),
    -- Pair 3: 8-bit unsigned (maps to BOOLEAN in driver test)
    6  => (FifoDepth => 1029, FifoWidth => 8,  ElementsPerClockCycle => 1, Mode => NiFpgaHostToTarget, SignedData => false),
    7  => (FifoDepth => 1023, FifoWidth => 8,  ElementsPerClockCycle => 1, Mode => NiFpgaTargetToHost, SignedData => false),
    -- Pair 4: 64-bit unsigned
    8  => (FifoDepth => 1029, FifoWidth => 64, ElementsPerClockCycle => 1, Mode => NiFpgaHostToTarget, SignedData => false),
    9  => (FifoDepth => 1023, FifoWidth => 64, ElementsPerClockCycle => 1, Mode => NiFpgaTargetToHost, SignedData => false),
    -- Pair 5: 64-bit signed (maps to SGL in driver test)
    10 => (FifoDepth => 1029, FifoWidth => 64, ElementsPerClockCycle => 1, Mode => NiFpgaHostToTarget, SignedData => true),
    11 => (FifoDepth => 1023, FifoWidth => 64, ElementsPerClockCycle => 1, Mode => NiFpgaTargetToHost, SignedData => true),
    12 => (FifoDepth => 1029, FifoWidth => 64, ElementsPerClockCycle => 1, Mode => NiFpgaHostToTarget, SignedData => true),
    13 => (FifoDepth => 1023, FifoWidth => 64, ElementsPerClockCycle => 1, Mode => NiFpgaTargetToHost, SignedData => true)
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
