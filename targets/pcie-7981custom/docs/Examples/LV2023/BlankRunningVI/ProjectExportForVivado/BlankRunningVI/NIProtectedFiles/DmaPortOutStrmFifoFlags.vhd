-------------------------------------------------------------------------------
--
-- File: DmaPortOutStrmFifoFlags.vhd
-- Author: Haider Khan, Matthew Koenn
-- Original Project: CHInCh Interface
-- Date: 11 January 2008
--
-------------------------------------------------------------------------------
-- (c) 2008 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--
--   This module implements the FIFO flags for an output stream DMA FIFO
-- that implements data packing.  It is similar to the normal FIFO flags
-- module with the added features of being able to reserve space in the FIFO
-- when read requests are made from the DMA controller.
--
--   Since the DMA controller uses the empty count to determine how much data
-- can be requested from Dma Port, the empty count needs to account for data
-- that has already been requested but has not yet been received by the FIFO.
-- Therefore, the empty count is based on a reserved pointer, which is
-- incremented by the DMA controller whenever the controller makes read
-- requests.
--
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;
  use work.PkgGray.all;
  use work.PkgDmaPortDataPackingFifo.all;
  use work.PkgNiDma.all;
  use work.PkgNiDmaConfig.all;

entity DmaPortOutStrmFifoFlags is
  generic(
    --kAddressWidth    : This is the width of the address bits feeding the FIFO.
    --                   Each FIFO location representing one data bus width word.
    kAddressWidth : natural := 6;
    --kSampleSize : This represents the sample size rounded up to the closer
    --              standard data type.
    kSampleSize : natural := 8;
    --kNumOfSamplesPerRead:  This is the number of samples read from the FIFO
    --                       in one read operation.
    kNumOfSamplesPerRead : natural := 1;
    --kRdPortWidth:  The read port width specifies the data width read from the FIFO
    --               on the user side. This take in consideration the standard
    --               sample size and the number of samples poped in one read cycle.
    kRdPortWidth : natural := 8;
    --kFifoCountWidth  : The number of bits needed to represent the number of samples
    --                   that fit in the FIFO.
    kFifoCountWidth : natural;
    --kCorrelatedDataWidth:  This is the width of any correlated data that is to be
    --                       transferred from the IClk domain to the OClk domain to
    --                       ensure that the data matches the delay for the full count.
    kCorrelatedDataWidth : integer := 0;
    --kCorrelatedDataResetValue:  The value that the correlated data should reset to.
    kCorrelatedDataResetValue : std_logic_vector
  );
  port(
    --aReset:   Serves as an asynchronous reset to this module.
    aReset : in boolean;

    -------------------------------------------------------------------------------------
    --INPUT PORT:
    -------------------------------------------------------------------------------------
    --The input port is the port that is exposed to the DMA controller and is used to
    --store data incoming from the host.

    --IClk:     This is the input clock to this module. Write pointers
    --          as well as write enables increment synchronous to this clock.
    IClk : in std_logic;
    --iReset:   Synchronous reset for the input circuitry.
    iReset : in boolean;
    --iWrite:   This signal is used for pushing data into the BRAM. The signal
    --          is used in this module to increment the write address pointer.
    iWrite : in boolean;
    --iAddr:    This is the address that is fed to the BRAM to specify the location to
    --          write to. This address increments with every valid iWrite strobe.
    iAddr : out unsigned(kAddressWidth-1 downto 0);
    --iCorrelatedDataIn:  The data that will be correlated with the FIFO count.  It is
    --                    clocked from the IClk to OClk domain at the same rate as the
    --                    FIFO count.
    iCorrelatedDataIn : in std_logic_vector(kCorrelatedDataWidth-1 downto 0);
    --iWriteLengthInBytes:  This is the number of bytes being written into the FIFO
    --                      when the iWrite signal is strobed.  The number of bytes
    --                      written should always be between 1 and kNiDmaDataWidth/8.
    iWriteLengthInBytes : in NiDmaBusByteCount_t;
    --iRsrvWriteSpaces: This signal is used to strobe in the ReqWriteSamples signal,
    --                  incrementing the FIFO spaces that have been reserved by read
    --                  request packets.
    iRsrvWriteSpaces : in boolean;
    --iReqWriteSamples: This is the number of samples reserved when the RsrvWriteSpaces
    --                  signal is strobed.  Spaces should be reserved whenever read
    --                  read request packets are issued.
    iReqWriteSamples : in unsigned(kFifoCountWidth-1 downto 0);
    --iRsrvdSpacesFilled: This signal indicates whether all the requested data has been
    --                    received by the FIFO.
    iRsrvdSpacesFilled : out boolean;

    -------------------------------------------------------------------------------------
    --OUTPUT PORT:
    -------------------------------------------------------------------------------------
    --The output port is the port that is exposed to the LabVIEW FPGA VI.  It is used
    --to pop data coming from the host, and the width is configurable based on the
    --data size chosen by the user.

    --OClk:     This is the output port clock. All data read from BRAM and address
    --          pointers feeding the BRAM are synchronous to this clock.
    OClk : in std_logic;
    --oReset:   Synchronous reset for the output circuitry in this module.
    oReset : in boolean;
    --oRead:    This signal is used for reading data from the BRAM and incrementing
    --          the read pointers. This will always pop kNumOfSamplesPerRead.
    oRead : in boolean;
    --oAddr:    This signal is fed to the BRAM to address the appropriate BRAM
    --          location. The signal is incremented with every oRead asserted from
    --          NiFpgaPopBuffer. This is not a registered output.
    oAddr : out unsigned(kFifoCountWidth-1 downto 0);
    --oCorrelatedDataOut:  The correlated data out.  It is clocked from the IClk to OClk
    --                     domain at the same rate as the FIFO count.
    oCorrelatedDataOut : out std_logic_vector(kCorrelatedDataWidth-1 downto 0);

    -------------------------------------------------------------------------------------
    --FIFO COUNTS:
    -------------------------------------------------------------------------------------
    --The count signals represent the amount of space available in the FIFO and
    --should be used to make decisions about when to push or pop data into or out
    --of the FIFO.

    --iEmptyCount:    The empty count represents the number of empty spaces available
    --                in the FIFO.
    iEmptyCount : out unsigned(kFifoCountWidth-1 downto 0);
    --oFullCount:     The full count represents the number of spaces that have been
    --                already filled in the FIFO.
    oFullCount : out unsigned(kFifoCountWidth-1 downto 0)

  );
end DmaPortOutStrmFifoFlags;


architecture rtl of DmaPortOutStrmFifoFlags is

  constant kSampleSizeInBits : natural := kSampleSize;
  constant kSampleSizeInBytes : natural := kSampleSizeInBits/8;
  constant kNiDmaDataWidthInSamples : natural := kNiDmaDataWidth/kSampleSizeInBits;
  constant kRdPortWidthInBytes : natural := kRdPortWidth/8;
  constant kPtrWidth : natural := kFifoCountWidth;
  constant kGrayClockCrossingReadPtrWidth : natural :=
    kPtrWidth - Log2(kNumOfSamplesPerRead);
  constant kBytePtrWidth : natural := kAddressWidth + Log2(kNiDmaDataWidthInBytes);
  constant kOutputResetValue : unsigned(kPtrWidth-1 downto 0) := (others => '0');

  signal oReadSamplePtrUns: unsigned(kPtrWidth-1 downto 0) := (others => '0');
  signal oReadSamplePtrUnsGray: Gray(kGrayClockCrossingReadPtrWidth-1 downto 0) :=
    (others => '0');
  signal oWriteSamplePtrUns: unsigned(kPtrWidth-1 downto 0) := (others => '0');
  signal oReadAddUns, oReadAddUnsNx : unsigned(kPtrWidth-1 downto 0) := (others => '0');

  signal iReqSamplePtrUns : unsigned(kPtrWidth-1 downto 0) := (others => '0');

  signal iReadSamplePtrUns : unsigned(kPtrWidth-1 downto 0) := (others => '0');
  signal iWriteSamplePtrUns : unsigned(kPtrWidth-1 downto 0) := (others => '0');
  signal iWriteSamplePtrUnsBytes :  unsigned(kBytePtrWidth-1 downto 0) :=
    (others => '0');
  signal iReadSamplePtrUnsGray_ms,
    iReadSamplePtrUnsGray : Gray(kGrayClockCrossingReadPtrWidth-1 downto 0)
    := (others => '0');

  signal oLclFullCount : unsigned(kPtrWidth-1 downto 0) := (others => '0');

  signal iPush, iPush_ms : boolean := false;

  attribute ASYNC_REG : string;
  attribute ASYNC_REG of iReadSamplePtrUnsGray_ms,
                         iReadSamplePtrUnsGray : signal is "true";
  attribute ASYNC_REG of iPush_ms,iPush : signal is "true";

  --vhook_sigstart
  --vhook_sigend

begin

  ---------------------------------------------------------------------------------------
  ---------------------------------------------------------------------------------------

  ReadAddressCounter:
  --The read address is incremented based on the oRead signal.
  --It is the responsibility of the Pop Buffer to make sure that the oRead
  --signal is asserted appropriately.
  process(oReset, oRead, oReadAddUns)
  begin
    if oReset then
      oReadAddUnsNx <= (others => '0');
    elsif oRead then
      oReadAddUnsNx <= oReadAddUns + kNumOfSamplesPerRead;
    else
      oReadAddUnsNx <= oReadAddUns;
    end if;
  end process;

  process(aReset, OClk)
  begin
    if aReset then
      oReadAddUns <= (others => '0');
    elsif rising_edge(OClk) then
      oReadAddUns <= oReadAddUnsNx;
    end if;
  end process;


  oReadSamplePtrUns <= oReadAddUns;

  -- Read address for BRAM.
  oAddr <= oReadAddUnsNx;

  -- Convert the read sample pointer to gray encoding.
  GrayEncodeReadPtr:
  process (aReset, OClk)
  begin
    if aReset then
      oReadSamplePtrUnsGray <= (others => '0');
    elsif rising_edge(OClk) then
      if oReset then
        oReadSamplePtrUnsGray <= (others => '0');
      else
        oReadSamplePtrUnsGray <= To_Gray(oReadSamplePtrUns(oReadSamplePtrUns'left downto
          Log2(kNumOfSamplesPerRead)));
      end if;
    end if;
  end process;

  -- Transfer the FIFO read pointer to the write clock domain.  This is also crossing
  -- the reset domain from asynchronous diagram reset to synchronous bus reset.  The
  -- value of the read sample pointer should be zero when diagram reset asserts, but
  -- there can be glitchiness due to the arrival time of diagram reset.  Double
  -- synchronizing the signal without a reset should prevent any glitchiness from
  -- propagating as metastability to the bus reset domain.
  SyncToIClk:
  process (IClk)
  begin
    -- The iReadSamplePtrUns's are not reset since reseting would cause the
    -- synchronous reset to be implemented as combinatorial logic on the clock crossing
    -- path.
    if rising_edge(IClk) then
      iReadSamplePtrUnsGray_ms <= oReadSamplePtrUnsGray;
      iReadSamplePtrUnsGray <= iReadSamplePtrUnsGray_ms;
      iReadSamplePtrUns <= To_Unsigned(iReadSamplePtrUnsGray) &
        unsigned(Zeros(Log2(kNumOfSamplesPerRead)));
    end if;
  end process;


  ---------------------------------------------------------------------------------------
  ---------------------------------------------------------------------------------------


  --The empty count is zero when the read pointer is one addr behind the write pointer.
  iEmptyCount <= iReadSamplePtrUns - iReqSamplePtrUns - 1;


  WriteAddressCounter:
  --The write pointer is used to generate the address for the BRAM.
  process(aReset, IClk)
  begin
    if aReset then
      iWriteSamplePtrUnsBytes <= (others => '0');
    elsif rising_edge(IClk) then
      if iReset then
        iWriteSamplePtrUnsBytes <= (others => '0');
      elsif iWrite then
        iWriteSamplePtrUnsBytes <= iWriteSamplePtrUnsBytes + iWriteLengthInBytes;
      end if;
    end if;
  end process;


  NarrowerSampleSize: if kSampleSizeInBits <= kNiDmaDataWidth generate

    iWriteSamplePtrUns <= iWriteSamplePtrUnsBytes(iWriteSamplePtrUnsBytes'left downto
                          (Log2(kNiDmaDataWidthInBytes)-Log2(kNiDmaDataWidthInSamples)));

    iAddr <= iWriteSamplePtrUns(iWriteSamplePtrUns'left downto
                                iWriteSamplePtrUns'left - iAddr'left);

  end generate;


  WiderSampleSize: if kSampleSizeInBits > kNiDmaDataWidth generate

    iWriteSamplePtrUns <= iWriteSamplePtrUnsBytes(iWriteSamplePtrUnsBytes'left downto
                  (Log2(kNiDmaDataWidthInBytes)+Log2(kSampleSizeInBits/kNiDmaDataWidth)));

    iAddr <= iWriteSamplePtrUnsBytes(iWriteSamplePtrUnsBytes'left downto
              Log2(kNiDmaDataWidthInBytes));

  end generate;


  ReqWriteAddressCounter:
  process(aReset, IClk)
  begin
    if aReset then
      iReqSamplePtrUns <= (others => '0');
    elsif rising_edge(IClk) then
      if iReset then
        iReqSamplePtrUns <= (others => '0');
      elsif iRsrvWriteSpaces then
        iReqSamplePtrUns <= iReqSamplePtrUns + iReqWriteSamples;
      end if;
    end if;
  end process;

  iRsrvdSpacesFilled <= (iWriteSamplePtrUns = iReqSamplePtrUns);


  IClkToOClkCrossing: block is
    constant kClockCrossingWidth : natural := kPtrWidth + kCorrelatedDataWidth;
    constant kClockCrossingResetValue : unsigned(kClockCrossingWidth-1 downto 0) :=
      unsigned(kCorrelatedDataResetValue) & kOutputResetValue;
    signal iClockCrossingDataIn : unsigned(kClockCrossingWidth-1 downto 0);
    signal oClockCrossingDataOut : unsigned(kClockCrossingWidth-1 downto 0);
  begin

    -- The module is used to push the write pointer across to the read clock domain side.
    -- The module uses a handshake mechanism to move the pointer to the other side. Gray
    -- could not be used here because the least significant bits of the pointer can
    -- change in random fashion and not in a known good pattern.

    --vhook_e DmaPortFifoPtrClockCrossing SyncToOClk
    --vhook_a kPtrWidth kClockCrossingWidth
    --vhook_a kOutputResetValue kClockCrossingResetValue
    --vhook_a IClk IClk
    --vhook_a iPush iPush
    --vhook_a iData iClockCrossingDataIn
    --vhook_a OClk OClk
    --vhook_a oData oClockCrossingDataOut
    SyncToOClk: entity work.DmaPortFifoPtrClockCrossing (rtl)
      generic map (
        kPtrWidth         => kClockCrossingWidth,       -- in  integer := 32
        kOutputResetValue => kClockCrossingResetValue)  -- in  unsigned
      port map (
        aReset => aReset,                 -- in  boolean
        IClk   => IClk,                   -- in  std_logic
        iPush  => iPush,                  -- in  boolean
        iData  => iClockCrossingDataIn,   -- in  unsigned(kPtrWidth-1 downto 0) := ( othe
        OClk   => OClk,                   -- in  std_logic
        oData  => oClockCrossingDataOut); -- out unsigned(kPtrWidth-1 downto 0)

    -- The input to the clock crossing module is the write pointer plus any correlated
    -- data.
    iClockCrossingDataIn(kPtrWidth-1 downto 0) <= iWriteSamplePtrUns;
    iClockCrossingDataIn(kCorrelatedDataWidth+kPtrWidth-1 downto kPtrWidth) <=
      unsigned(iCorrelatedDataIn);

    -- Retrieve the pointer and correlated data from the clock crossing output.
    oWriteSamplePtrUns <= oClockCrossingDataOut(kPtrWidth-1 downto 0);
    oCorrelatedDataOut <= std_logic_vector(oClockCrossingDataOut(kCorrelatedDataWidth+
      kPtrWidth-1 downto kPtrWidth));

  end block IClkToOClkCrossing;


  -- The push signal should always be true so that we continually push the read
  -- pointer, but this is unsafe immediately following reset since push resets to
  -- false.  Therefore, we double sync the push to true following reset.
  DoubleSyncPush:
  process(aReset, IClk)
  begin
    if aReset then
      iPush_ms <= false;
      iPush <= false;
    elsif rising_edge(IClk) then
      iPush_ms <= true;
      iPush <= iPush_ms;
    end if;
  end process;

  oLclFullCount <= oWriteSamplePtrUns - oReadSamplePtrUns;
  oFullCount <= oLclFullCount;


end rtl;
