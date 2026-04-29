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

  -- Import types and constants from PkgCommIntConfiguration.
  use work.PkgCommIntConfiguration.all;

package PkgUserHdl is

  ---------------------------------------------------------------------------
  -- Simplified DMA FIFO configuration record
  ---------------------------------------------------------------------------
  -- Users specify only these four fields per FIFO channel. The remaining
  -- DmaChannelConfiguration_t fields are filled in with defaults by
  -- ToDmaChannelConfArray.
  type UserDmaFifoConf_t is record
    FifoDepth             : natural;
    FifoWidth             : natural;
    ElementsPerClockCycle : natural;
    Mode                  : DmaChannelMode_t;
    SignedData            : boolean;
    FxpType               : boolean;
  end record;

  type UserDmaFifoConfArray_t is array (natural range <>) of UserDmaFifoConf_t;

  ---------------------------------------------------------------------------
  -- DMA FIFO channel configuration
  ---------------------------------------------------------------------------

  -- Number of DMA channels used by UserHdl
  constant kNumUserHdlDmaChannels : natural := 2;

  -- Compute the DMA register base address for a given system channel index.
  -- Each channel occupies 0x40 bytes, starting from 0x3FFC0 at index 0.
  function DmaChannelBaseAddress(ChannelIndex : natural) return natural;

  -- Merge user FIFO configs into a base DmaChannelConfArray_t. The simplified
  -- UserConf entries are expanded to full DmaChannelConfiguration_t records
  -- and replace elements in BaseConf starting at StartIndex.
  function MergeDmaFifoConf(
    BaseConf   : DmaChannelConfArray_t;
    UserConf   : UserDmaFifoConfArray_t;
    StartIndex : natural
  ) return DmaChannelConfArray_t;

  -- Starting index where user HDL FIFOs are inserted into kDmaFifoConfArray.
--  constant kUserHdlDmaStartIndex : natural :=
--    kNumberOfDmaChannels - 1 - kNiFpgaFixedInputPorts - kNiFpgaFixedOutputPorts;

  -- *****************************************
  -- RIO driver loading .lvbitx XML requires DMA indexes to start at 0 and be contiguous... or test example
  -- uses two LV FPGA FIFOs at index 0 & 1 so this testing must start at index 3
  --
  -- WE WILL REMOVE THIS HACK ONCE WE DON'T HAVE TO USE .LVBITX TO LOAD THE RIO DRIVER FOR USER FIFOS
  -- *****************************************
  constant kUserHdlDmaStartIndex : natural := 3;

  -- Simplified user FIFO definitions.
  -- IMPORTANT: entries are ordered by descending DMA index so that the
  -- downward merge (conf(0) → StartIndex, conf(1) → StartIndex-1, …)
  -- produces the same Mode layout as kDmaFifoConfArray.
  --   conf(0) → index 3 = HostToTarget (Reader)
  --   conf(1) → index 2 = TargetToHost (Writer)
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

package body PkgUserHdl is

  function DmaChannelBaseAddress(ChannelIndex : natural) return natural is
  begin
    return 16#3FFC0# - ChannelIndex * 16#40#;
  end function;

  function MergeDmaFifoConf(
    BaseConf   : DmaChannelConfArray_t;
    UserConf   : UserDmaFifoConfArray_t;
    StartIndex : natural
  ) return DmaChannelConfArray_t is
    variable Result : DmaChannelConfArray_t(BaseConf'range);
  begin
    Result := BaseConf;
    for i in UserConf'range loop
      Result(StartIndex - i) := (
        FifoDepth              => UserConf(i).FifoDepth,
        FifoWidth              => UserConf(i).FifoWidth,
        ElementsPerClockCycle  => UserConf(i).ElementsPerClockCycle,
        Mode                   => UserConf(i).Mode,
        SignedData             => UserConf(i).SignedData,
        BaseAddress            => DmaChannelBaseAddress(StartIndex - i),
        SCL                    => false,
        CountSCL               => false,
        FxpType                => UserConf(i).FxpType,
        DisableOnFifoTimeout   => false,
        WriteWindowOffset      => 16#0#,
        DmaClkIsDefaultClk     => true,
        InterfaceIsHandshaking => false
      );
    end loop;
    return Result;
  end function;

end PkgUserHdl;
