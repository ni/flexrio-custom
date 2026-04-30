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
--   Types and utility functions live in PkgUserHdlFifos (do not edit).
--
------------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;
  use work.PkgCommIntConfiguration.all;
  use work.PkgUserHdlFifos.all;

package PkgUserHdl is

  ---------------------------------------------------------------------------
  -- DMA FIFO channel configuration
  ---------------------------------------------------------------------------

  -- Number of DMA channels used by UserHdl
  constant kNumUserHdlDmaChannels : natural := 2;


  constant kUserHdlDmaFifoConf : UserDmaFifoConfArray_t(0 to kNumUserHdlDmaChannels - 1) := (
    0 => (FifoDepth => 1029, FifoWidth => 32, ElementsPerClockCycle => 1, Mode => NiFpgaHostToTarget, SignedData => true, FxpType => false),
    1 => (FifoDepth => 1023, FifoWidth => 32, ElementsPerClockCycle => 1, Mode => NiFpgaTargetToHost, SignedData => true, FxpType => false)
  );

  ---------------------------------------------------------------------------
  -- Demo register array (4 registers starting at byte offset 0x10)
  ---------------------------------------------------------------------------
  constant kNumDemoRegs : natural := 4;

  constant kLoopbackInAIdx  : natural := 0;  -- offset 0x10: host R/W input A
  constant kLoopbackInBIdx  : natural := 1;  -- offset 0x14: host R/W input B
  constant kLoopbackOutAIdx : natural := 2;  -- offset 0x18: host RO output (A+1)
  constant kLoopbackOutBIdx : natural := 3;  -- offset 0x1C: host RO output (B+1)

  ---------------------------------------------------------------------------
  -- FIFO register array (9 registers starting at byte offset 60)
  ---------------------------------------------------------------------------
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
