------------------------------------------------------------------------------------------
--
-- File: PkgNiSharedFifo.vhd
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
  use work.PkgNiDma.all;

package PkgNiSharedFifo is

  ---------------------------------------------------------------------------
  -- Supported host API data types for DMA FIFOs
  ---------------------------------------------------------------------------
  -- These are the ONLY data types the host (RIO) API supports for DMA FIFOs.
  -- Selecting one of these in a UserDmaFifoConf_t entry automatically sets the
  -- correct FifoWidth and SignedData when MergeDmaFifoConf expands it, so the
  -- user never specifies width or signedness directly.
  --
  --   Constant      Host type   Width  Signed
  --   -----------   ---------   -----  ------
  --   kBoolean      Boolean       8    no     (Boolean maps to U8 on the host)
  --   kUnsigned8    U8            8    no
  --   kInteger8     I8            8    yes
  --   kUnsigned16   U16          16    no
  --   kInteger16    I16          16    yes
  --   kUnsigned32   U32          32    no
  --   kInteger32    I32          32    yes
  --   kUnsigned64   U64          64    no
  --   kInteger64    I64          64    yes
  --   kSingle       SGL          64    no     (single-precision floating point)
  type FifoDataType_t is (
    kBoolean,
    kUnsigned8,  kInteger8,
    kUnsigned16, kInteger16,
    kUnsigned32, kInteger32,
    kUnsigned64, kInteger64,
    kSingle
  );

  -- Return the DMA FIFO element width (in bits) for a host data type.
  function FifoDataWidth(DataType : FifoDataType_t) return natural;

  -- Return true if the host data type is signed (enables sign extension).
  function FifoDataIsSigned(DataType : FifoDataType_t) return boolean;

  ---------------------------------------------------------------------------
  -- Simplified DMA FIFO configuration record
  ---------------------------------------------------------------------------
  -- Users specify only these fields per FIFO channel. Width and signedness are
  -- derived from DataType, and the remaining DmaChannelConfiguration_t fields
  -- are filled in with defaults by MergeDmaFifoConf.
  type UserDmaFifoConf_t is record
    FifoDepth             : natural;
    DataType              : FifoDataType_t;
    ElementsPerClockCycle : natural;
    Mode                  : DmaChannelMode_t;
  end record;

  type UserDmaFifoConfArray_t is array (natural range <>) of UserDmaFifoConf_t;

  -- Compute the DMA register base address for a given user FIFO config index.
  -- Each FIFO occupies 0x40 bytes, starting from 0x37FFC at config index 0 and
  -- stepping downward by 0x40 for each subsequent config index.
  function DmaChannelBaseAddress(ConfigIndex : natural) return natural;

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

  -- Build a kForceChannelEnable vector that marks every DMA channel occupied
  -- by a user HDL FIFO. Channel mapping mirrors MergeDmaFifoConf:
  --   UserConf(0) → channel StartIndex
  --   UserConf(1) → channel StartIndex - 1
  --   …
  function GetForceChannelEnable(
    UserConf   : UserDmaFifoConfArray_t;
    StartIndex : natural
  ) return NiDmaDmaChannelOneHot_t;

end PkgNiSharedFifo;

package body PkgNiSharedFifo is

  function FifoDataWidth(DataType : FifoDataType_t) return natural is
  begin
    case DataType is
      when kBoolean                  => return 8;   -- Boolean maps to U8
      when kUnsigned8  | kInteger8   => return 8;
      when kUnsigned16 | kInteger16  => return 16;
      when kUnsigned32 | kInteger32  => return 32;
      when kUnsigned64 | kInteger64  => return 64;
      when kSingle                   => return 64;  -- SGL: 64-bit element
    end case;
  end function;

  function FifoDataIsSigned(DataType : FifoDataType_t) return boolean is
  begin
    case DataType is
      when kInteger8  | kInteger16 |
           kInteger32 | kInteger64 => return true;
      when others                  => return false;
    end case;
  end function;

  function DmaChannelBaseAddress(ConfigIndex : natural) return natural is
  begin
    -- This is hard-coded to the lower half of the DMA register space for FlexRIO devices, which is where user HDL FIFOs are located. 
    -- The user HDL FIFO register space is 0x37FFC down to 0x30000, with each FIFO occupying 0x40 bytes. 
    -- The upper half of the DMA register space (0x3FFFC down to 0x38000) is reserved for LV FPGA FIFOs.
    --
    -- Addressing is driven by the user FIFO config index (kUserHdlDmaFifoConf index), NOT the system
    -- DMA channel index.  Config index 0 maps to 0x37FFC and each subsequent config index steps down
    -- by 0x40, independent of which physical DMA channel the FIFO is assigned to.
    --
    -- This will likely need to be updated to consider different target types that have different FIFO address ranges
    --
    -- Perhaps in the future this should be in the PkgLvFpgaConst or other package file generated from LV FPGA since it should be sourced
    -- from the target resource XML.  But then we have a dependency between this file and generated LV packages which is also not ideal.
    return 16#37FFC# - ConfigIndex * 16#40#;
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
        FifoWidth              => FifoDataWidth(UserConf(i).DataType),
        ElementsPerClockCycle  => UserConf(i).ElementsPerClockCycle,
        Mode                   => UserConf(i).Mode,
        SignedData             => FifoDataIsSigned(UserConf(i).DataType),
        BaseAddress            => DmaChannelBaseAddress(i),
        SCL                    => false,
        CountSCL               => false,
        FxpType                => false,
        DisableOnFifoTimeout   => false,
        WriteWindowOffset      => 16#0#,
        DmaClkIsDefaultClk     => true,
        InterfaceIsHandshaking => false
      );
    end loop;
    return Result;
  end function;

  function GetForceChannelEnable(
    UserConf   : UserDmaFifoConfArray_t;
    StartIndex : natural
  ) return NiDmaDmaChannelOneHot_t is
    variable Result : NiDmaDmaChannelOneHot_t := (others => false);
  begin
    for i in UserConf'range loop
      Result(StartIndex - i) := true;
    end loop;
    return Result;
  end function;

end PkgNiSharedFifo;
