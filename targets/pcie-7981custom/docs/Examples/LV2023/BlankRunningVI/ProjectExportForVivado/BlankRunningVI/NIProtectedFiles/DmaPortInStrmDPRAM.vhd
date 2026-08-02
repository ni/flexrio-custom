-------------------------------------------------------------------------------
--
-- File: DmaPortInStrmDPRAM.vhd
-- Author: Florin Hurgoi
-- Original Project: LabVIEW FPGA support for Emerald Bay
-- Date: 20 March 2012
--
-------------------------------------------------------------------------------
-- (c) 2008 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--
--  This component implements the actual FIFO using inferred block RAM.
--
--  The user configures the width of the data to be written in the FIFO by setting
--  the sample size and the number of samples to be written in one clock cycle.
--  Theoretically there is no restriction about how wide the write data port can be.
--  The target configures the data bus width and the data read from the FIFO will
--  always need to be as wide as the data bus is. The data bus configurations we plan
--  to use in the near future are 32 bits, 64 bits and 128 bits but current design
--  should have no upper bound for the data bus width.
--
--  Having no restriction on how wide the write and read data ports could be we need to
--  consider two cases:
--  1. Wider Bus Case
--    This is the case when the data bus width (read data port width) is wider than
--    the write port width.  In this case the FIFO data width will match the data bus
--    width. For writting data to the FIFO we need to connect the data to be written
--    into the FIFO multiple times to the FIFO's write data port.  The inferred
--    block RAM needs to use byte enables to control which of the write word is written
--    to the FIFO.  On the read data port we always read a data bus width word (one FIFO
--    location) even if we only want to read just one sample. The DMA controller has
--    the byte lane and byte enable information that allows it know which data needs to
--    be further transferred.
--
--  2. Narrower Bus Case
--    This is the case when the data bus width (read data port width) is narrower than
--    the write port width.  In this case the FIFO data width will match the write data
--    port width and we always write an entire FIFO location.  On the read side
--    we need to multiplex data read from the FIFO to get the data to be sent over
--    the data bus.
--
--  The following two pictures shows the how the design looks like for the two cases
--  described above.
--
--              Wider Bus Case                            Narrower Bus Case
--
--                WrPortWidth                                WrPortWidth
--                    |                                          |
--               ____\|/____                                     |
--           ___|___|___|___|___                        ________\|/________
--          |    Byte Enable    |                      |                   |
--          |                   |                      |                   |
--          |                   |                      |                   |
--          |                   |                      |                   |
--          |                   |                      |                   |
--   VI     |       FIFO        |                      |        FIFO       |
-- ---------------------------------------------------------------------------------
--   BUS    |                   |                      |                   |
--          |                   |                      |                   |
--          |                   |                      |                   |
--          |  Data Bus Width   |                      |     WrPortWidth   |
--          |<----------------->|                      |<----------------->|
--          |___________________|                      |___________________|
--                    |                                          |      
--           ________\|/________                        ________\|/________
--          |     Register      |                      | BRAM Out Register |
--          |___________________|                      |___________________|
--                    |                                    |   |   |   |
--           ________\|/________                        __\|/_\|/_\|/_\|/__
--          |     Register      |                       \                 /
--          |___________________|                        \_______________/
--                                                               |
--                                                         _____\|/_____
--                                                        |   Data Out  |
--                                                        |__ Register__|
--                                                        <------------->
--                                                         Data Bus Width
--
--  The Narrower Bus Case requires two registers for making easier the timing closure:
--  one at the BRAM output and one after the data multiplexer. The register at the BRAM
--  output splits the combinatorial path for the case of deeper DMA FIFOs that require
--  data multiplexing for implementing the big BRAM structure.
--  The inferred block RAM component is configured to have a read latency of
--  two clock cycles for improving the block RAM maximum clock rates.
--  The total read latency of this component will be four clock cycles.
--  In the Wider Bus Case two registers are introduced to match the read
--  latency of four clock cycles imposed by the Narrower Bus Case.
--
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;
  use work.PkgDmaPortDataPackingFifo.all;
  use work.PkgNiDma.all;
  use work.PkgNiDmaConfig.all;

entity DmaPortInStrmDPRAM is
  generic (
    --kAddressWidth:  This constant represents the number of bits needed to address
    --                the FIFO content in data bus width words.
    kAddressWidth : natural := 8;
    --kSampleSize:  This represents the sample size rounded up to the closer
    --              standard data type.
    kSampleSize : natural := 8;
    --kNumOfSamplesPerWrite:  The number of samples that will be written to the FIFO
    --                        in one write cycle.
    kNumOfSamplesPerWrite : positive := 1;
    --kWrPortWidth:  This represents the data width written to the FIFO.
    kWrPortWidth : natural := 8;
    --kFifoCountWidth:  The number of bits needed to represent the number of samples
    --                  that fit in the FIFO.
    kFifoCountWidth : natural
  );
  port (
    --aReset: Serves as an asynchronous reset to this module.
    aReset : in boolean;

    -------------------------------------------------------------------------------------
    --INPUT PORT:
    -------------------------------------------------------------------------------------
    --IClk:  This is the input clock to this module. Write pointers
    --       as well as write enables increment synchronous to this clock.
    IClk : in std_logic;
    --iWrite:  This signal is used for pushing data into the BRAM.
    iWrite : in boolean;
    --iAddr:  This is the address that specifies the location to write to.
    iAddr : in unsigned(kFifoCountWidth-1 downto 0);
    --iDataIn:  This is the data written to the BRAM.
    iDataIn : in std_logic_vector(kWrPortWidth-1 downto 0);

    -------------------------------------------------------------------------------------
    --OUTPUT PORT:
    -------------------------------------------------------------------------------------
    --OClk:  This is the output port clock. All data read from BRAM and address
    --       pointers feeding the BRAM are synchronous to this clock.
    OClk : in std_logic;
    --oAddr:  This signal specifies the address of the BRAM location being read.
    oReset : in boolean;
    --oReset:   Synchronous reset for the output circuitry in this module.
    oAddr : in unsigned(kAddressWidth-1 downto 0);
    --oDataOut:  This signal is the data present in the BRAM at address specified by oAddr.
    oDataOut : out NiDmaData_t
  );
end DmaPortInStrmDPRAM;

architecture rtl of DmaPortInStrmDPRAM is

  --vhook_sigstart
  --vhook_sigend

  -- This constant represents the FIFO data port width in bits. This is a function of the
  -- data bus width and the data width on the VI side. The FIFO data port width is given
  -- by the largest data width between the data bus and the data on the VI side.
  constant kFifoDataWidth : natural := ActualFifoPortWidth (kWrPortWidth);

  -- This constant represents the number of write ports words we have in one fifo entry.
  constant kFifoWidthInWrPortWords : natural := kFifoDataWidth/kWrPortWidth;

  -- This constant represents the number of samples that fit in one FIFO location.
  constant kFifoWidthInSamples : natural := kFifoDataWidth/kSampleSize;

  -- This constant represents the number of data bus words we have in one fifo entry.
  constant kFifoWidthInDataBusWords : natural := kFifoDataWidth/kNiDmaDataWidth;

  constant kFifoAddressWidth : natural := kAddressWidth-Log2(kFifoWidthInDataBusWords);

  signal iWriteEnable : BooleanVector(kFifoDataWidth/8-1 downto 0);
  signal iAddrRam : unsigned(kFifoAddressWidth-1 downto 0);
  signal iDataInRam : std_logic_vector(kFifoDataWidth-1 downto 0);
  signal oAddrRam : unsigned (kFifoAddressWidth-1 downto 0);
  signal oDataOutRam, oDataOutRamReg : std_logic_vector(kFifoDataWidth-1 downto 0);
  signal oDataOutNx : NiDmaData_t;
  signal oDataSel2, oDataSel1, oDataSel0, oDataSelNx :
    unsigned (Log2(kFifoWidthInDataBusWords)-1 downto 0);
  signal oDataSelInt : natural;

begin

  -- Generate the signals that connect to the inferred block RAM for the case when
  -- the data bus port is wider than the data width written to the FIFO.
  WiderDataBusGenerate: if kNiDmaDataWidth >= kWrPortWidth generate
    -- In this case the FIFO's data width match the data bus width. 

    -- This signal controls which samples are pushed into the FIFO.
    iWriteEnable <= GetWriteEnables(
                    iAddr(Log2(kFifoWidthInSamples)-1 downto Log2(kNumOfSamplesPerWrite)),
                    kWrPortWidth) when iWrite else (others => false);

    -- Use the address bits that address the FIFO in data bus words.
    iAddrRam <= iAddr(iAddr'left downto Log2(kFifoWidthInSamples));

    -- The input data being narrower than the FIFO's data width is connected
    -- multiple times to the FIFO's input data and the iWriteEnable controls
    -- which of the kWrPortWidth slices is written to the FIFO.
    GenDataIn: for i in 0 to kFifoWidthInWrPortWords-1 generate
      iDataInRam((i+1)*kWrPortWidth-1 downto i*kWrPortWidth) <= iDataIn;
    end generate;

    oAddrRam <= oAddr;

    oDataOutNx <= oDataOutRamReg;

  end generate; --WiderDataBusGenerate


  -- Generate the signals that connect to the inferred block RAM for the case when
  -- the data bus port is narrower than the data width written to the FIFO.
  NarrowerDataBusGenerate: if kNiDmaDataWidth < kWrPortWidth generate
    -- In this case the FIFO's data width match the data width written to the FIFO.

    -- We always want to write to the FIFO the entire write data port.
    iWriteEnable <= (others => true) when iWrite else (others => false);

    -- Use the address bits that address the FIFO in data width written to the FIFO.
    iAddrRam <= iAddr(iAddr'left downto Log2(kNumOfSamplesPerWrite));

    iDataInRam <= iDataIn;

    oAddrRam <= oAddr(oAddr'left downto Log2(kFifoWidthInDataBusWords));

    oDataSelNx <= oAddr(Log2(kFifoWidthInDataBusWords)-1 downto 0);

    -- We need to delay the less semnificative bits of the read address that represents
    -- number of data bus words that fit in one FIFO entry. These bits will be used to
    -- multiplex the data read from the FIFO. The number of delay cycles needs to match
    -- the block RAM read latency.
    DataSelDelay: process (oClk, aReset)
    begin
      if aReset then
        oDataSel0 <= (others=>'0');
        oDataSel1 <= (others=>'0');
        oDataSel2 <= (others=>'0');
      elsif rising_edge(oClk) then
        if oReset then
          oDataSel0 <= (others=>'0');
          oDataSel1 <= (others=>'0');
          oDataSel2 <= (others=>'0');
        else
          oDataSel0 <= oDataSelNx;
          oDataSel1 <= oDataSel0;
          oDataSel2 <= oDataSel1;
        end if;
      end if;
    end process;

    oDataSelInt <= to_integer(oDataSel2);
    oDataOutNx <= oDataOutRamReg((oDataSelInt+1)*kNiDmaDataWidth-1 downto
      oDataSelInt*kNiDmaDataWidth);

  end generate; -- NarrowerDataBusGenerate

  -- The simple dual port RAM is inferred with a read latency of two clock cycles.
  -- This means that the optional output data register inside the BRAM is enabled and
  -- the BRAM's maximum working frequency is semnificatively improved.

  --vhook_e DmaPortCommIfcSimpleDualPortRAM_ByteEnable SimpleDualPortRAM_ByteEnable
  --vhook_a kAddrWidth kFifoAddressWidth
  --vhook_a kDataWidth kFifoDataWidth
  --vhook_a kReadDataLatency 2
  --vhook_a iWrite iWriteEnable
  --vhook_a iAddr iAddrRam
  --vhook_a iDataIn iDataInRam
  --vhook_a oReset false
  --vhook_a oAddr oAddrRam
  --vhook_a oDataOut oDataOutRam
  SimpleDualPortRAM_ByteEnable: entity work.DmaPortCommIfcSimpleDualPortRAM_ByteEnable (rtl)
    generic map (
      kAddrWidth       => kFifoAddressWidth,  -- in  integer := 10
      kDataWidth       => kFifoDataWidth,     -- in  integer := 64
      kReadDataLatency => 2)                  -- in  integer range 1 to 2 := 1
    port map (
      IClk     => IClk,          -- in  std_logic
      iWrite   => iWriteEnable,  -- in  BooleanVector(kDataWidth / 8-1 downto 0)
      iAddr    => iAddrRam,      -- in  unsigned(kAddrWidth-1 downto 0)
      iDataIn  => iDataInRam,    -- in  std_logic_vector(kDataWidth-1 downto 0)
      OClk     => OClk,          -- in  std_logic
      oReset   => false,         -- in  boolean
      oAddr    => oAddrRam,      -- in  unsigned(kAddrWidth-1 downto 0)
      oDataOut => oDataOutRam);  -- out std_logic_vector(kDataWidth-1 downto 0)

  -- This register help to close timing by splitting the combinatorial path between
  -- the BRAM output and the Output Data Register. Implementing Deeper DMA FIFOs
  -- require to multiplex the output data that comes from different BRAMs blocks.
  -- This register will separate the mux required to implement the deeper DMA FIFOs
  -- and the mux required to multiplex the FIFO's data read word to the data bus for
  -- narrower data bus case.
  RegisterRamOutputData: process(aReset, OClk)
  begin
    if aReset then
      oDataOutRamReg <= (others=>'0');
    elsif rising_edge(OClk) then
      oDataOutRamReg <= oDataOutRam;
    end if;
  end process;

  -- Register the output data.
  RegisterOutputData: process(aReset, OClk)
  begin
    if aReset then
      oDataOut <= (others=>'0');
    elsif rising_edge(OClk) then
      oDataOut <= oDataOutNx;
    end if;
  end process;


end rtl;
