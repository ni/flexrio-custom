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
  constant kNumUserHdlDmaChannels : natural := 2;

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

  constant kUserHdlDmaFifoConf : UserDmaFifoConfArray_t(0 to kNumUserHdlDmaChannels - 1) := (
    0 => (FifoDepth => 1029, FifoWidth => 32, ElementsPerClockCycle => 1, Mode => NiFpgaHostToTarget, SignedData => true),
    1 => (FifoDepth => 1023, FifoWidth => 32, ElementsPerClockCycle => 1, Mode => NiFpgaTargetToHost, SignedData => true)
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
  -- FIFO register array (9 registers starting at byte offset 60)
  ---------------------------------------------------------------------------
  constant kFifoRegsBaseAddress : natural := 16#3C#;
  constant kNumFifoRegs : natural := 9;

  constant kWriterStartStopIdx : natural := 0;  -- offset 60
  constant kReaderStartStopIdx : natural := 1;  -- offset 64
  constant kWriterCountIdx     : natural := 2;  -- offset 68
  constant kReaderCountIdx     : natural := 3;  -- offset 72
  constant kWriterStateIdx     : natural := 4;  -- offset 76
  constant kReaderStateIdx     : natural := 5;  -- offset 80
  constant kWriterDataIdx      : natural := 6;  -- offset 84
  constant kReaderStrobeIdx    : natural := 7;  -- offset 88
  constant kReaderDataIdx      : natural := 8;  -- offset 92

end PkgUserHdl;
