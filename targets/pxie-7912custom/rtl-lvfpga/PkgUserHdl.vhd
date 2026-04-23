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
--   Constants for the UserHdl block: DMA FIFO channel configurations,
--   demo register layout, and FIFO register layout.
--
------------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;

  -- Import only type definitions from PkgCommIntConfiguration (not constants).
  use work.PkgCommIntConfiguration.DmaChannelConfArray_t;
  use work.PkgCommIntConfiguration.DmaChannelConfiguration_t;
  use work.PkgCommIntConfiguration.DmaChannelMode_t;

package PkgUserHdl is

  ---------------------------------------------------------------------------
  -- DMA FIFO channel configuration
  ---------------------------------------------------------------------------

  -- Number of DMA channels used by UserHdl
  constant kNumUserHdlDmaChannels : natural := 2;

  -- DMA channel indices for the UserHdl FIFOs.
  -- These must match the channel numbers in CodeGenerationResults.lvtxt.
  constant kUserDmaWriterIdx : natural := 2;  -- Writer (FPGA-to-Host, TargetToHost)
  constant kUserDmaReaderIdx : natural := 3;  -- Reader (Host-to-FPGA, HostToTarget)

  -- Compute the DMA register base address for a given system channel index.
  -- Each channel occupies 0x40 bytes, starting from 0x3FFC0 at index 0.
  function DmaChannelBaseAddress(ChannelIndex : natural) return natural;


  -- DMA FIFO configurations for the UserHdl channels
  constant kUserHdlDmaFifoConfArray : DmaChannelConfArray_t(0 to kNumUserHdlDmaChannels - 1) := (
    0 => (  -- Writer FIFO (channel kUserDmaWriterIdx, FPGA-to-Host)
      FifoDepth              => 1023,
      FifoWidth              => 32,
      ElementsPerClockCycle  => 1,
      SignedData             => true,
      BaseAddress            => DmaChannelBaseAddress(kUserDmaWriterIdx),
      Mode                   => NiFpgaTargetToHost,
      SCL                    => false,
      CountSCL               => false,
      FxpType                => false,
      DisableOnFifoTimeout   => false,
      WriteWindowOffset      => 16#0#,
      DmaClkIsDefaultClk     => true,
      InterfaceIsHandshaking => false
    ),
    1 => (  -- Reader FIFO (channel kUserDmaReaderIdx, Host-to-FPGA)
      FifoDepth              => 1029,
      FifoWidth              => 32,
      ElementsPerClockCycle  => 1,
      SignedData             => true,
      BaseAddress            => DmaChannelBaseAddress(kUserDmaReaderIdx),
      Mode                   => NiFpgaHostToTarget,
      SCL                    => false,
      CountSCL               => false,
      FxpType                => false,
      DisableOnFifoTimeout   => false,
      WriteWindowOffset      => 16#0#,
      DmaClkIsDefaultClk     => true,
      InterfaceIsHandshaking => false
    )
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

package body PkgUserHdl is

  function DmaChannelBaseAddress(ChannelIndex : natural) return natural is
  begin
    return 16#3FFC0# - ChannelIndex * 16#40#;
  end function;

end PkgUserHdl;
