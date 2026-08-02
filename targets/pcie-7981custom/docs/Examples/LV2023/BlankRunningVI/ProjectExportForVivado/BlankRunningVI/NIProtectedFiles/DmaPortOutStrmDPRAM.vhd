-------------------------------------------------------------------------------
--
-- File: DmaPortOutStrmDPRAM.vhd
-- Author: Florin Hurgoi
-- Original Project: LabVIEW FPGA support for Emerald Bay
-- Date: 13 February 2012
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
--  The user configures the width of the data to be read in the FIFO by setting
--  the sample size and the number of samples to be read in one clock cycle.
--  Theoretically there is no restriction about how wide the data port width can be.
--  The target configures the data bus width and the data written to the FIFO will
--  always need to be as wide as the data bus is. The data bus configurations we plan
--  to use in the near future are 32 bits, 64 bits and 128 bits but the current design
--  should have no upper bound for the data bus width.
--
--  Having no restriction on how wide the write and read data ports could be we need to
--  consider two cases:
--  1. Wider Bus Case
--    This is the case when the data bus width is wider than the read port width.
--    In this case the FIFO data width will match the data bus width. For writting data
--    to the FIFO we connect the data bus to the FIFO's write port and we use the
--    byte enables that comes together with the data to be able to write only valid data
--    to the FIFO.  On the read side we always read a data bus width word (one FIFO
--    location) even if we only need to read just one sample. The data read from the FIFO
--    is then multiplexed to the user's read data width.
--
--  2. Narrower Bus Case
--    This is the case when the data bus width is narrower than the read port width.
--    In this case the FIFO data width will match the read data port width.  On the write
--    side we need to connect the data bus multiple times to the write data port and
--    to use write enables to select which data bus slice is written.  For writing
--    an entire FIFO location many write cycles are required.  On the read side
--    we always read an entire FIFO location that represents the user's read data.
--
--  The following two pictures shows the how the design looks like for the two cases
--  described above.
--
--              Wider Bus Case                            Narrower Bus Case
--
--                RdPortWidth
--                   /|\
--              ______|______
--             | Pop Buffer* |
--             |_____________|                              RdPortWidth
--                   /|\                                        /|\
--             _______|_______                          _________|_________
--            /               \                        |     Pop Buffer*   |
--           /_________________\                       |___________________|
--             /|\ /|\ /|\ /|\                                  /|\
--           ___|___|___|___|___                        _________|_________
--          |  RAM Out Register |                      |  RAM Out Register |
--          |___________________|                      |___________________|
--                   /|\                                        /|\
--           _________|_________                        _________|_________
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
--          |  Data Bus Width   |                      |     RdPortWidth   |
--          |<----------------->|                      |<----------------->|
--          |___________________|                      |___________________|
--                   /|\                                  /|\ /|\ /|\ /|\
--                    |                                    |___|___|___|
--                Data Bus                                             |
--                                                                 Data Bus
--
--  *Please note that the Pop Buffer is not included in this component.
--
--  The Wider Bus Case requires one register between the FIFO's output and the data
--  multiplexer for making easier the timing closure.
--  The inferred block RAM component is configured to have a read latency of two clock
--  cycles for improving the block RAM maximum clock rates.  The total read latency
--  of this component will be three clock cycles.
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
  use work.PkgByteArray.all;

entity DmaPortOutStrmDPRAM is
  generic (
    --kAddressWidth:  This is the width of the address bits feeding the FIFO.
    --                Each FIFO location representing one data bus width word.
    kAddressWidth : natural := 6;
    --kSampleSize :  This represents the sample width rounded up to the closer
    --               standard data type.
    kSampleSize : natural := 8;
    --kNumOfSamplesPerRead:  This is the number of samples read from the FIFO
    --                       on the VI side;
    kNumOfSamplesPerRead : natural := 1;
    --kRdPortWidth:  The read port width specifies the data width read from the FIFO
    --               on the user side. This take in consideration the standard
    --               sample size and the number of samples poped in one read cycle.
    kRdPortWidth : natural := 8;
    --kFifoCountWidth:  The number of bits needed to represent the number of samples
    --                  that fit in the FIFO.
    kFifoCountWidth : natural
  );
  port (

    aReset : in boolean;

    -------------------------------------------------------------------------------------
    --INPUT PORT:
    -------------------------------------------------------------------------------------
    --IClk:     This is the input clock to this module. Write pointers
    --          as well as write enables increment synchronous to this clock.
    IClk : in std_logic;
    --iWriteEnables:  Write enables are used to store data to speficic locations
    --                within a BRAM location.
    iWriteEnables : in NiDmaByteEnable_t;
    --iAddr:    This is the address that specifies the location to write to.
    --          This address increments with every valid iWrite strobe.
    iAddr : in unsigned(kAddressWidth-1 downto 0);
    --iDataIn:  This is the data that is written to the BRAM.
    iDataIn : in NiDmaData_t;

    -------------------------------------------------------------------------------------
    --OUTPUT PORT:
    -------------------------------------------------------------------------------------
    --OClk:     This is the output port clock. All data read from BRAM and address
    --          pointers feeding the BRAM are synchronous to this clock.
    OClk : in std_logic;
    --oReset:   Synchronous reset for the output circuitry in this module.
    oReset : in boolean;
    --oAddr:    This signal specifies the address of the BRAM location being read.
    --          This signal is registered within this component, so there is an extra
    --          cycle of latency between setting oAddr and receiving the value.
    oAddr : in unsigned(kFifoCountWidth-1 downto 0);
    --oDataOut: This signal is the data present in the BRAM at address specified by
    --          oAddr.
    oDataOut : out std_logic_vector(kRdPortWidth-1 downto 0)
  );
end DmaPortOutStrmDPRAM;

architecture rtl of DmaPortOutStrmDPRAM is

  -- This constant represents the FIFO data port width in bits. This is a function of the
  -- data bus width and the data width on the VI side. The FIFO data port width is given
  -- by the largest data width between the data bus and the data on the VI side.
  constant kFifoDataWidth : natural := ActualFifoPortWidth (kRdPortWidth);

  -- This constant represents the number of read data words that fit in one FIFO location.
  constant kFifoWidthInRdPortWords : natural := kFifoDataWidth/kRdPortWidth;

  -- This constant represents the number of samples that fit in one FIFO location.
  constant kFifoWidthInSamples : natural := kFifoDataWidth/kSampleSize;

  -- This constant represents the number of data bus words we have in one fifo location.
  constant kFifoWidthInDataBusWords : natural := kFifoDataWidth/kNiDmaDataWidth;

  constant kFifoAddressWidth : natural := kAddressWidth-Log2(kFifoWidthInDataBusWords);

  constant kDataSelWidth : natural := Log2(kFifoWidthInSamples)-Log2(kNumOfSamplesPerRead);

  signal iWriteEnable : BooleanVector(kFifoDataWidth/8-1 downto 0);
  signal iAddrRam : unsigned(kFifoAddressWidth-1 downto 0);
  signal iDataInRam : std_logic_vector(kFifoDataWidth-1 downto 0);
  signal iDataSelInt : natural;
  signal oAddrRam : unsigned (kFifoAddressWidth-1 downto 0);
  signal oDataOutRam, oDataOutRamReg : std_logic_vector(kFifoDataWidth-1 downto 0);
  signal oDataSel0, oDataSel1, oDataSel2, oDataSelNx :
    unsigned (Larger(kDataSelWidth, 1)-1 downto 0);
  signal oDataSelInt : natural;

  --vhook_sigstart
  --vhook_sigend

begin

  -- Generate the signals that connect to the inferred block RAM for the case when
  -- the data bus port is wider than the data width read from the FIFO.
  WiderDataBusGenerate: if kNiDmaDataWidth >= kRdPortWidth generate
    -- In this case the FIFO's data width match the data bus width. 

    -- This signal controls which samples are pushed into the FIFO. iWriteEnables
    -- is provided by the DMA controller and is guaranteed to be all false during
    -- any state in which Push is not asserted.
    iWriteEnable <= iWriteEnables;

    iAddrRam <= iAddr;

    iDataInRam <= iDataIn;

    oAddrRam <= oAddr(oAddr'left downto Log2(kFifoWidthInSamples));

    oDataSelNx <= (others => '0') when kNiDmaDataWidth = kRdPortWidth else
      oAddr(Log2(kFifoWidthInSamples)-1 downto Log2(kNumOfSamplesPerRead));

    -- We need to delay the read address bits that represents the number of
    -- read data words that fit in one FIFO entry. These bits will be used to
    -- multiplex the data read from the FIFO. The number of delay cycles need to match
    -- the block RAM read latency.
    DataSelDelay: process (oClk, aReset)
    begin
      if aReset then
        oDataSel0 <= (others=>'0');
        oDataSel1 <= (others=>'0');
        oDataSel2 <= (others => '0');
      elsif rising_edge(oClk) then
        if oReset then
          oDataSel0 <= (others=>'0');
          oDataSel1 <= (others => '0');
          oDataSel2 <= (others => '0');
        else
          oDataSel0 <= oDataSelNx;
          oDataSel1 <= oDataSel0;
          oDataSel2 <= oDataSel1;
        end if;
      end if;
    end process;

    oDataSelInt <= to_integer(oDataSel2);
    oDataOut <= oDataOutRamReg((oDataSelInt+1)*kRdPortWidth-1 downto
      oDataSelInt*kRdPortWidth);

  end generate; --WiderDataBusGenerate


  -- Generate the signals that connect to the inferred block RAM for the case when
  -- the data bus port is narrower than the data width read from the FIFO.
  NarrowerDataBusGenerate: if kNiDmaDataWidth < kRdPortWidth generate
    -- In this case the FIFO's data width match the data width written to the FIFO.

    -- The Log2(kFifoWidthInDataBusWords) less semnificative bits of write address
    -- represents the position of a data bus word in a FIFO data word.
    -- iDataSelInt is used to enable the write enable vector just for the
    -- corresponding data bus word within the FIFO's data width word.
    iDataSelInt <= to_integer(iAddr(Log2(kFifoWidthInDataBusWords)-1 downto 0));

    -- We connect iWriteEnables signal generated by the DMA controller just to the
    -- data bus word that need to be written to the FIFO.
    GenerateByteEnables: for i in 0 to kFifoWidthInDataBusWords-1 generate

        iWriteEnable ((i+1)*kNiDmaDataWidthInBytes-1 downto i*kNiDmaDataWidthInBytes) <=
          iWriteEnables when (i = iDataSelInt) else (others => false);

    end generate;


    iAddrRam <= iAddr(iAddr'left downto Log2(kFifoWidthInDataBusWords));

    -- The input data being narrower than the FIFO's data width is connected
    -- multiple times to the FIFO's input data and the iWriteEnable controls
    -- which of the data bus words slices is written to the FIFO.
    GenDataIn: for i in 0 to kFifoWidthInDataBusWords-1 generate
      iDataInRam((i+1)*kNiDmaDataWidth-1 downto i*kNiDmaDataWidth) <= iDataIn;
    end generate;

    oAddrRam <= oAddr(oAddr'left downto Log2(kFifoWidthInSamples));

    oDataOut <= oDataOutRamReg;

  end generate; -- NarrowerDataBusGenerate


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
  -- the BRAM output and the Pop Buffer. Implementing Deeper DMA FIFOs
  -- require a multiplexer to connect the data that comes from different BRAMs blocks
  -- to the FIFO's data read port. This register will separate the mux required to implement
  -- the deeper DMA FIFOs and the mux required to multiplex the FIFO's data read word
  -- to the data bus for wider data bus case.
  RegisterRamOutputData: process(aReset, OClk)
  begin
    if aReset then
      oDataOutRamReg <= (others=>'0');
    elsif rising_edge(OClk) then
      oDataOutRamReg <= oDataOutRam;
    end if;
  end process;

end rtl;
