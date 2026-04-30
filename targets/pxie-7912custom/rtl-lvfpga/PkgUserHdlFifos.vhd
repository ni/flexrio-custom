------------------------------------------------------------------------------------------
--
-- File: PkgUserHdlFifos.vhd
--
------------------------------------------------------------------------------------------
-- (c) 2026 Copyright National Instruments Corporation
--
-- SPDX-License-Identifier: MIT
------------------------------------------------------------------------------------------
--
-- Purpose:
--   Types and utility functions for UserHdl DMA FIFO configuration.
--
--   This package defines the simplified UserDmaFifoConf_t record type and the
--   MergeDmaFifoConf function that expands user FIFO definitions into full
--   DmaChannelConfiguration_t entries. Users should NOT need to edit this file.
--   Edit PkgUserHdl.vhd to change FIFO configuration constants.
--
------------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;
  use work.PkgCommIntConfiguration.all;

package PkgUserHdlFifos is


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
  
  ---------------------------------------------------------------------------
  -- Simplified DMA FIFO configuration record
  ---------------------------------------------------------------------------
  -- Users specify only these fields per FIFO channel. The remaining
  -- DmaChannelConfiguration_t fields are filled in with defaults by
  -- MergeDmaFifoConf.
  type UserDmaFifoConf_t is record
    FifoDepth             : natural;
    FifoWidth             : natural;
    ElementsPerClockCycle : natural;
    Mode                  : DmaChannelMode_t;
    SignedData            : boolean;
    FxpType               : boolean;
  end record;

  type UserDmaFifoConfArray_t is array (natural range <>) of UserDmaFifoConf_t;

  -- Compute the DMA register base address for a given system channel index.
  -- Each channel occupies 0x40 bytes, starting from 0x3FFC0 at index 0.
  function DmaChannelBaseAddress(ChannelIndex : natural) return natural;

  -- Merge user FIFO configs into a base DmaChannelConfArray_t. The simplified
  -- UserConf entries are expanded to full DmaChannelConfiguration_t records
  -- and replace elements in BaseConf starting at StartIndex, growing downward:
  --   UserConf(0) → Result(StartIndex)
  --   UserConf(1) → Result(StartIndex - 1)
  --   …
  function MergeDmaFifoConf(
    BaseConf   : DmaChannelConfArray_t;
    UserConf   : UserDmaFifoConfArray_t;
    StartIndex : natural
  ) return DmaChannelConfArray_t;

end PkgUserHdlFifos;

package body PkgUserHdlFifos is

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

end PkgUserHdlFifos;
