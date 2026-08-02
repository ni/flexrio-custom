-------------------------------------------------------------------------------
--
-- File: PkgCommunicationInterface.vhd
-- Author: Gregory Voirin, Dustyn Blasig
-- Original Project: LV FPGA Communication Interface
-- Date: 12 February 2005
--
-------------------------------------------------------------------------------
-- (c) 2010 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--
-- This package provides type definitions and functions used by the components
-- of the LabVIEW FPGA communication interface. It affects the register access
-- part, as well as the DMA and IRQ management.
--
-- RegPortxx: This types define a 'standard' port for register access. Every interface
-- plugin should export this type of port to connect to the frameworks.
--
-- DmaInputxx: Ports used to connect to a resholder on the diagram in the BoardToHost
-- case of a DMA transfer.
--
-- Irqxx: Ports used to connect to a resholder on the diagram in the Interrupt
-- generation process.
--
-- Arrays: these are defined for convenient use of array functions defined in
-- the package PkgNiUtilities.
--
-- SelectPort: this function prints one hot mux
--
-- NumOfBits: this function is used to get the number of bits needed to encode
-- the index of an array. It based on the Log2 function but returns 1 for an input
-- equal to one and allows an input of zero without erroring.  All other functions
-- are conversion functions from and to std_logic_vector.
--
-------------------------------------------------------------------------------
--*****************************************************************************
-- Some DMA files in this repo have been forked/duplicated into the hw-nicores AzDo git repository.
--
-- Before changing this file or any of its upstream/downstream dependencies, read the following:
--
--      CommInterfaces/DmaPort/README_DMA_FILES_FORK.md
--
--*****************************************************************************


library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;
  use work.PkgCommIntConfiguration.all;

package PkgCommunicationInterface is

  -- Currently, the data passed to/from the interface components is always 32
  -- bits, even if we're compiling for a 16 bit board. This helps simplify our
  -- life in many situations since the interfaces don't change widths.

  subtype InterfaceData_t is std_logic_vector(31 downto 0);
  type InterfaceDataArray_t is array (natural range<>) of InterfaceData_t;

  -- The whole communication interface is 32bits by design. Therefore
  -- we are removing bits 0 and 1 of the address to obtain 32bits
  -- aligned address.

  constant kAlignedAddressWidth : positive := kAddressWidth - 2;

  -- RegPortIn contains the address plus 32 bits of data, a read
  -- signal and a write signal (32 + 1 + 1 = 34)

  constant kRegPortInSize  : positive := kAlignedAddressWidth + 34;

  -- RegPortOut contains 32 bits of data, a DataValid signal and
  -- a Ready signal (32 + 1 + 1 = 34)

  constant kRegPortOutSize : positive := 34;

  -- Currently, we always transfer data through dma using chunk sizes of
  -- multiples of 32 bits. This makes transfers on 16 bit boards less efficient
  -- for 16 and 48 bit numbers, but it makes life easier on the driver.

  constant kDmaTransferStride : positive := 32;
  
  -- This is the total number of virtual interrupts available to the user VI.
  -- This constant is applicable if virtual interrupts are supported on the
  -- target, i.e. kNumberOfIrqs >= 1.
  constant kNumVirtualInterrupts : natural := 32;

  -----------------------------------------------------------------------------
  -- Type Definitions
  -----------------------------------------------------------------------------

  -- The type of the signal used to communicate from the Interface
  -- component to the frameworks
  type RegPortIn_t is record
    Address : unsigned(kAlignedAddressWidth - 1 downto 0);
    Data    : InterfaceData_t;
    Rd      : boolean;                  -- Must be a one clock cycle pulse
    Wt      : boolean;                  -- Must be a one clock cycle pulse
  end record;

  -- The type of the signal used to communicate to the Interface
  -- component from the frameworks
  -- Ready is just the Ready signal from the Handshake component.
  -- Address in RegPortIn_t should be valid in the cycle where Data, DataValid,
  -- or Ready are being sampled by the bus communication interface.
  type RegPortOut_t is record
    Data      : InterfaceData_t;
    DataValid : boolean;                -- Must be a one clock cycle pulse
    Ready     : boolean;                -- Must be valid one clock after Wt assertion
  end record;

  -- The type of the signal used to communicate from the Interface
  -- component to the resHolders
  type IrqIn_t is record
    EnableOut : std_logic;
  end record;

  -- The type of the signal used to communicate to the Interface
  -- component from the resHolders
  type IrqOut_t is record
    EnableIn    : std_logic;
    EnableClear : std_logic;
    IrqNum      : std_logic_vector(Log2(kNumVirtualInterrupts)-1 downto 0);
  end record;

  -- The type of the signal used to communicate from the Interface
  -- component to the resHolders
  type IrqStatusIn_t is record
    Status    : std_logic_vector(kNumVirtualInterrupts-1 downto 0);
    EnableOut : std_logic;
  end record;

  -- The type of the signal used to communicate to the Interface
  -- component from the resHolders
  type IrqStatusOut_t is record
    EnableIn    : std_logic;
    EnableClear : std_logic;
  end record;

  -- The array containing all the signals from all the frameworks
  type RegPortOutArray_t is array (natural range<>) of RegPortOut_t;

  -- The dma type definitions. Since dma supports arbitrary data widths from
  -- the diagram, there are two types of data arrays. One is the data array
  -- coming to and from the diagram which is the actual width of the data. The
  -- second is the interface data array which is always the width of the data
  -- to and from the interface.

  subtype DmaVec_t is std_logic_vector(kNumberOfDmaChannels-1 downto 0);
  subtype DmaClkArray_t is std_logic_vector(0 to kNumberOfDmaChannels-1);
  subtype DmaFlagArray_t is std_logic_vector(0 to kNumberOfDmaChannels-1);
  subtype DmaHandshakingArray_t is std_logic_vector(0 to kNumberOfDmaChannels-1);
  subtype DmaEnableArray_t is std_logic_vector(0 to kNumberOfDmaChannels-1);
  subtype DmaData_t is std_logic_vector(DmaMaxWidth(false)-1 downto 0);
  subtype DmaCount_t is std_logic_vector(Log2(DmaMaxDepth(false)+1)-1 downto 0);
  subtype DmaTimeout_t is std_logic_vector(31 downto 0);
  subtype DmaInterfaceDataArray_t is InterfaceDataArray_t(0 to kNumberOfDmaChannels-1);
  type DmaDataArray_t is array (0 to kNumberOfDmaChannels-1) of DmaData_t;
  type DmaCountArray_t is array (0 to kNumberOfDmaChannels-1) of DmaCount_t;
  type DmaTimeoutArray_t is array (0 to kNumberOfDmaChannels-1) of DmaTimeout_t;

  -- Memory Buffer DMA channels are very similar to above
  subtype MemoryBufferDmaVec_t is std_logic_vector(kNumberOfMemoryBufferDmaChannels-1 downto 0);
  subtype MemoryBufferDmaClkArray_t is std_logic_vector(0 to kNumberOfMemoryBufferDmaChannels-1);
  subtype MemoryBufferDmaFlagArray_t is std_logic_vector(0 to kNumberOfMemoryBufferDmaChannels-1);
  subtype MemoryBufferDmaHandshakingArray_t is std_logic_vector(0 to kNumberOfMemoryBufferDmaChannels-1);
  subtype MemoryBufferDmaEnableArray_t is std_logic_vector(0 to kNumberOfMemoryBufferDmaChannels-1);
  subtype MemoryBufferDmaData_t is std_logic_vector(MemoryBufferDmaMaxWidth(false)-1 downto 0);
  subtype MemoryBufferDmaCount_t is std_logic_vector(Log2(MemoryBufferDmaMaxDepth(false)+1)-1 downto 0);
  subtype MemoryBufferDmaInterfaceDataArray_t is InterfaceDataArray_t(0 to kNumberOfMemoryBufferDmaChannels-1);
  type MemoryBufferDmaDataArray_t is array (0 to kNumberOfMemoryBufferDmaChannels-1) of MemoryBufferDmaData_t;
  type MemoryBufferDmaCountArray_t is array (0 to kNumberOfMemoryBufferDmaChannels-1) of MemoryBufferDmaCount_t;
  type MemoryBufferDmaTimeoutArray_t is array (0 to kNumberOfMemoryBufferDmaChannels-1) of DmaTimeout_t;

  subtype IrqVec_t is std_logic_vector(kNumberOfIrqs-1 downto 0);
  subtype IrqClkArray_t is std_logic_vector(0 to kNumberOfIrqs-1);
  subtype IrqEnableArray_t is std_logic_vector(0 to kNumberOfIrqs-1);
  subtype IrqData_t is std_logic_vector(31 downto 0);
  subtype IrqDataArray_t is InterfaceDataArray_t(0 to kNumberOfIrqs-1);
  type IrqInArray_t is array (0 to kNumberOfIrqs-1) of IrqIn_t;
  type IrqOutArray_t is array (0 to kNumberOfIrqs-1) of IrqOut_t;
  type IrqStatusInArray_t is array (0 to kNumberOfIrqs-1) of IrqStatusIn_t;
  type IrqStatusOutArray_t is array (0 to kNumberOfIrqs-1) of IrqStatusOut_t;
  type IrqIntStatusArray_t is array (0 to kNumberOfIrqs-1)
    of std_logic_vector(31 downto 0);

  function SelectPort(arg : RegPortOutArray_t) return RegPortOut_t;

  function BuildRegPortIn(
    arg  : std_logic_vector(kRegPortInSize-1 downto 0))
    return RegPortIn_t;
  
  function BuildRegPortOut(
    arg : std_logic_vector(kRegPortOutSize-1 downto 0))
    return RegPortOut_t;

  function to_StdLogicVector(arg : RegPortIn_t) return std_logic_vector;
  function to_StdLogicVector(arg : RegPortOut_t) return std_logic_vector;

  function OrInterfaceDataArray(arg : InterfaceDataArray_t) return InterfaceData_t;

  function NumOfBits(Arg : natural) return natural;
  
  -- Constants for the RegPort
  constant kRegPortInZero : RegPortIn_t := (
    Address => to_unsigned(0,kAlignedAddressWidth),
    Data => (others => '0'),
    Rd => false,
    Wt => false);
    
  constant kRegPortOutZero : RegPortOut_t := (
    Data => (others=>'0'),
    DataValid => false,
    Ready => true);

end PkgCommunicationInterface;

package body PkgCommunicationInterface is

  -- This function prints one hot mux
  function SelectPort(arg : RegPortOutArray_t) return RegPortOut_t is

    type Array_t is array (arg'range) of InterfaceData_t;

    variable ReturnVal     : RegPortOut_t;
    -- ArrayToBeOred may seem a weird name as it is first used in the AND stage
    -- of the OneHot Mux, but it gets ORed ultimately :-)
    variable ArrayToBeOred : Array_t;
    variable Selector      : natural;

  begin

    -- Zero out input vector based on the DataValid
    for i in arg'range loop
      if arg(i).DataValid then
        ArrayToBeOred(i) := arg(i).Data;
      else
        ArrayToBeOred(i) := (others => '0');
      end if;
    end loop;

    -- Init values
    ReturnVal.Data      := (others => '0');
    ReturnVal.DataValid := false;
    ReturnVal.Ready     := true;

    for i in ArrayToBeOred'range loop
      ReturnVal.Data      := ReturnVal.Data or ArrayToBeOred(i);
      ReturnVal.DataValid := ReturnVal.DataValid or arg(i).DataValid;
      ReturnVal.Ready     := ReturnVal.Ready and arg(i).Ready;
    end loop;
    
    return ReturnVal;
    
  end SelectPort;

  function BuildRegPortOut(arg : std_logic_vector(kRegPortOutSize - 1 downto 0))
      return RegPortOut_t is
    variable ReturnVal : RegPortOut_t;
  begin
    ReturnVal.Data      := arg(31 downto 0);
    ReturnVal.DataValid := to_Boolean(arg(32));
    ReturnVal.Ready     := to_Boolean(arg(33));
    return ReturnVal;
  end BuildRegPortOut;

  function BuildRegPortIn(arg : std_logic_vector(kRegPortInSize - 1 downto 0))
      return RegPortIn_t is
    variable ReturnVal : RegPortIn_t;
  begin
    ReturnVal.Data    := arg(31 downto 0);
    ReturnVal.Address := unsigned(arg(kRegPortInSize - 3 downto 32));
    ReturnVal.Wt      := to_Boolean(arg(kRegPortInSize - 2));
    ReturnVal.Rd      := to_Boolean(arg(kRegPortInSize - 1));
    return ReturnVal;
  end BuildRegPortIn;

  function to_StdLogicVector(arg : RegPortOut_t) return std_logic_vector is
    variable ReturnVal : std_logic_vector(kRegPortOutSize - 1 downto 0);
  begin
    ReturnVal := to_StdLogic(arg.Ready) & to_StdLogic(arg.DataValid) & arg.Data;
    return ReturnVal;
  end to_StdLogicVector;

  function to_StdLogicVector(arg : RegPortIn_t) return std_logic_vector is
    variable ReturnVal : std_logic_vector(kRegPortInSize - 1 downto 0);
  begin
    ReturnVal := to_StdLogic(arg.Rd) &
                 to_StdLogic(arg.Wt) &
                 std_logic_vector(arg.Address) &
                 arg.Data;
    return ReturnVal;

  end to_StdLogicVector;

  -- This function could be described based on Log2 with special cases
  -- for 0 and 1. Can be changed later.
  function NumOfBits(Arg : natural) return natural is
    variable ReturnVal  : natural;
    variable ShiftedArg : natural;
  begin
    if Arg > 0 then
      ReturnVal  := 1;
      ShiftedArg := Arg-1;
      while ShiftedArg > 0 loop
        ShiftedArg := ShiftedArg / 2;
        ReturnVal  := ReturnVal + 1;
      end loop;
    else
      ReturnVal := 0;
    end if;
    return ReturnVal;
  end NumOfBits;

  function OrInterfaceDataArray (arg : InterfaceDataArray_t) return InterfaceData_t is
    variable ReturnVal : InterfaceData_t;
  begin
    ReturnVal := (others => '0');
    for i in arg'range loop
      ReturnVal := ReturnVal or arg(i);
    end loop;
    return ReturnVal;
  end OrInterfaceDataArray;

end PkgCommunicationInterface;
