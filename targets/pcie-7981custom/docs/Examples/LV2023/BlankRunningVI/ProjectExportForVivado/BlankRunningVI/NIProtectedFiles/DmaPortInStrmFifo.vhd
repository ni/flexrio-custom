-------------------------------------------------------------------------------
--
-- File: DmaPortInStrmFifo.vhd
-- Author: Siddharth Sethi
-- Original Project: CHInCh Interface
-- Date: 30 July 2008
--
-------------------------------------------------------------------------------
-- (c) 2008 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose: Data packing FIFO for IN streams.
--

-- Harmish- 08/04/2014 - Added support for the flush method.
-- + iFlush input indicates the flush request and it's passed to the DmaPortInStrmFifoFlags logic.
-- + DmaPortInStrmFifoFlags component implements the logic to handle the request and 
--   drives out the request(oFlushReqFlags) to the input stream controller(DmaPortCommIfcInputController.vhd)
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;
  use work.PkgDmaPortDataPackingFifo.all;
  use work.PkgNiDma.all;

entity DmaPortInStrmFifo is
  generic (
    --kAddressWidth:  This is the width of the address bits feeding the FIFO.
    --                Each FIFO location representing one data bus width word.
    kAddressWidth : natural := 8;
    --kSampleSize :  This represents the sample size rounded up to the closer standard
    --               data type.
    kSampleSize : natural := 8;
    --kWrPortWidth:  This represents the data width that is written to the FIFO.
    kWrPortWidth : natural := 8;
    --kNumOfSamplesPerWrite:  The number of samples that will be written in the FIFO
    --                        in one write cycle;
    kNumOfSamplesPerWrite : positive := 1;
    --kFifoCountWidth: The number of bits needed to represent the number of samples
    --                 that fit in the FIFO.
    kFifoCountWidth : natural;
    --kDataTypeIsSigned:  This determines the sign of the data extension for non
    --                    8,16,32, or 64-bit aligned data.
    kDataTypeIsSigned : boolean := false;
    --kCorrelatedDataWidth:  This is the width of any correlated data that is to be
    --                       transferred from the OClk domain to the IClk domain to
    --                       ensure that the data matches the delay for the empty count.
    kCorrelatedDataWidth : integer := 0;
    --kCorrelatedDataResetValue:  The value that the correlated data should reset to.
    kCorrelatedDataResetValue : std_logic_vector
  );
  port (
    --aReset:   Serves as an asynchronous reset to this module.
    aReset : in boolean;

    -------------------------------------------------------------------------------------
    --INPUT PORT:
    -------------------------------------------------------------------------------------
    --The input port is the port that is exposed to the user and is configurable
    --to support data packing.

    --IClk:  This is the input clock to this module.
    IClk : in std_logic;
    --iReset:  Synchronous reset for the input circuitry.
    iReset : in boolean;
    --iWrite:  This signal is used for pushing data into the FIFO.
    iWrite : in boolean;
    --iDataIn:  Data that needs to be written to the FIFO.
	iFlush : in boolean; 
    iDataIn : in std_logic_vector(kWrPortWidth-1 downto 0);
    --iEmptyCount:  The empty count represents the number of empty spaces available
    --              in the FIFO.
    iEmptyCount : out unsigned(kFifoCountWidth-1 downto 0);
    --iWritesDisabled:  A boolean value indicating that writes have been disabled.  This
    --                  is only used so that it can be transfered to the oClk domain
    --                  and have the delays match the delay of the write pointers so
    --                  that the full count is valid.
    iWritesDisabled : in boolean;
    --iCorrelatedDataOut:  The data that will is correlated with the FIFO count.  It is
    --                     clocked from the OClk to IClk domain at the same rate as the
    --                     FIFO count.
    iCorrelatedDataOut : out std_logic_vector(kCorrelatedDataWidth-1 downto 0);

    -------------------------------------------------------------------------------------
    --OUTPUT PORT:
    -------------------------------------------------------------------------------------
    --The output port is the port that is exposed to the DMA control logic moving
    --data back to the host. This side of the port is configurable to 64-bit or 128-bit.

    --OClk:  This is the output port clock.
    OClk : in std_logic;
    --oReset:  Synchronous reset for the output circuitry in this module.
    oReset : in boolean;
    --oRead:  This signal is used for incrementing the read pointers. oRead will only
    --        update the read address pointer when we need to point to a new FIFO
    --        location.
    oRead : in boolean;
    --oPop:  This signal is used to update the address pointer when less than one
    --       FIFO location is accessed.
    oPop : in boolean;
    --oByteCount:  This signal is driven by the DMA controller and it is used to compute
    --             the read addres pointer.
    oByteCount : in NiDmaBusByteCount_t;
    --oByteLanePtr:   This signal points to the location of the read pointer
    --                within a single FIFO entry. This is useful for cases where the
    --                input and output ports are not symmetric. So for any data size
    --                other than 64-bits, this becomes useful as it represents
    --                the true location of the read pointer.
    oByteLanePtr : out NiDmaByteLane_t;
    --oNumReadSamples:  This signal represents the number of samples for which
    --                  a data request was sent;
    oNumReadSamples : in unsigned(kFifoCountWidth-1 downto 0);
    --oRsrvReadSpaces:  This signal is true for one clock cycle to update
    --                  the FIFO's FifoFullCount. The amount to update
    --                  the FifoFullCount is specified in bNumReadSamples.
    oRsrvReadSpaces : in boolean;
    --oDataOut:  Data read from the FIFO.
    oDataOut : out NiDmaData_t;
    --oFullCount:  The full count represents the number of spaces that have been
    --             already filled in the FIFO.
    oFullCount : out unsigned(kFifoCountWidth-1 downto 0);
    --oWritesDisabled:  This value indicates that writes have been disabled on the
    --                  iClk side and that oFullCount will therefore not change as the
    --                  result of an iWrite strobe.
    oWritesDisabled : out boolean;
    -- oWriteDetected:  Indicates a write to the FIFO.
    oWriteDetected : out boolean;
    --oCorrelatedDataIn:  The correlated data in.  It is clocked from the OClk to IClk
    --                     domain at the same rate as the FIFO count.
    oFlushReqFifo : out std_logic;
	oCorrelatedDataIn : in std_logic_vector(kCorrelatedDataWidth-1 downto 0)

	
  );
end DmaPortInStrmFifo;

architecture rtl of DmaPortInStrmFifo is

  --vhook_sigstart
  signal iAddr: unsigned(kFifoCountWidth-1 downto 0);
  signal oAddr: unsigned(kAddressWidth-1 downto 0);
  signal oFlushReqFlags: std_logic;
  --vhook_sigend
  

begin

	oFlushReqFifo <= oFlushReqFlags;

  -----------------------------------------------------------------------------
  -- Instantiate the Fifo Control module.
  -----------------------------------------------------------------------------

  --vhook_e DmaPortInStrmFifoFlags
  --vhook_a oFlushReq oFlushReqFlags
  DmaPortInStrmFifoFlagsx: entity work.DmaPortInStrmFifoFlags (rtl)
    generic map (
      kAddressWidth             => kAddressWidth,              -- in  natural := 8
      kSampleSize               => kSampleSize,                -- in  natural := 8
      kNumOfSamplesPerWrite     => kNumOfSamplesPerWrite,      -- in  positive := 1
      kWrPortWidth              => kWrPortWidth,               -- in  natural := 8
      kFifoCountWidth           => kFifoCountWidth,            -- in  natural
      kCorrelatedDataWidth      => kCorrelatedDataWidth,       -- in  integer := 0
      kCorrelatedDataResetValue => kCorrelatedDataResetValue)  -- in  std_logic_vector
    port map (
      aReset             => aReset,              -- in  boolean
      IClk               => IClk,                -- in  std_logic
      iReset             => iReset,              -- in  boolean
      iWrite             => iWrite,              -- in  boolean
      iFlush             => iFlush,              -- in  boolean
      iAddr              => iAddr,               -- out unsigned(kFifoCountWidth-1 downto
      iWritesDisabled    => iWritesDisabled,     -- in  boolean
      iCorrelatedDataOut => iCorrelatedDataOut,  -- out std_logic_vector(kCorrelatedDataW
      OClk               => OClk,                -- in  std_logic
      oReset             => oReset,              -- in  boolean
      oRead              => oRead,               -- in  boolean
      oPop               => oPop,                -- in  boolean
      oByteCount         => oByteCount,          -- in  NiDmaBusByteCount_t
      oByteLanePtr       => oByteLanePtr,        -- out NiDmaByteLane_t
      oNumReadSamples    => oNumReadSamples,     -- in  unsigned(kFifoCountWidth-1 downto
      oRsrvReadSpaces    => oRsrvReadSpaces,     -- in  boolean
      oAddr              => oAddr,               -- out unsigned(kAddressWidth-1 downto 0
      oWritesDisabled    => oWritesDisabled,     -- out boolean
      oWriteDetected     => oWriteDetected,      -- out boolean
      oCorrelatedDataIn  => oCorrelatedDataIn,   -- in  std_logic_vector(kCorrelatedDataW
      oFlushReq          => oFlushReqFlags,      -- out std_logic
      iEmptyCount        => iEmptyCount,         -- out unsigned(kFifoCountWidth-1 downto
      oFullCount         => oFullCount);         -- out unsigned(kFifoCountWidth-1 downto


  -----------------------------------------------------------------------------
  -- Instantiate the dual port RAM
  -----------------------------------------------------------------------------

  --vhook_e DmaPortInStrmDPRAM DmaPortInStrmDPRAM_inferred
  DmaPortInStrmDPRAM_inferred: entity work.DmaPortInStrmDPRAM (rtl)
    generic map (
      kAddressWidth         => kAddressWidth,          -- in  natural := 8
      kSampleSize           => kSampleSize,            -- in  natural := 8
      kNumOfSamplesPerWrite => kNumOfSamplesPerWrite,  -- in  positive := 1
      kWrPortWidth          => kWrPortWidth,           -- in  natural := 8
      kFifoCountWidth       => kFifoCountWidth)        -- in  natural
    port map (
      aReset   => aReset,    -- in  boolean
      IClk     => IClk,      -- in  std_logic
      iWrite   => iWrite,    -- in  boolean
      iAddr    => iAddr,     -- in  unsigned(kFifoCountWidth-1 downto 0)
      iDataIn  => iDataIn,   -- in  std_logic_vector(kWrPortWidth-1 downto 0)
      OClk     => OClk,      -- in  std_logic
      oReset   => oReset,    -- in  boolean
      oAddr    => oAddr,     -- in  unsigned(kAddressWidth-1 downto 0)
      oDataOut => oDataOut); -- out NiDmaData_t

end rtl;
