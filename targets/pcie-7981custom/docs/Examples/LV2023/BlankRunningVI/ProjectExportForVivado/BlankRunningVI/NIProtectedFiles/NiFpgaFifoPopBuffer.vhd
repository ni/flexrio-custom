-------------------------------------------------------------------------------
--
-- File: NiFpgaFifoPopBuffer.vhd
-- Author: Dustyn Blasig
-- Original Project: LabVIEW FPGA Fifos
-- Date: 29 November 2005
--
-------------------------------------------------------------------------------
-- (c) 2005 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--
--   this is the buffer added to the pop side of the block ram fifo so
--   we can mask the two cycle delay of the block ram fifo allowing the fpga
--   fifo to be used in a single cycle loop in an intuitive fashion.
--
--   one or more elements can be pushed or popped from the buffer during each
--   transaction based on the value of the kNumOfElements generic. the width of
--   the data buses is the width of one element multiplied by the number of
--   elements that are pushed or popped in each transaction.
--
--   The kNumOfElements generic must be always a positive, power of two value.
--     http://labview.natinst.com/docs/proposals/2013/FPGA/LabVIEW%20FPGA%20support%20for%20Gen2%20x8%20PCIe%20targets/index.html
--     http://labview.natinst.com/docs/proposals/2012/FPGA/Multi-Element%20FIFO%20Read%20Write%20in%20SCTL/index.html
--
--   the depth of the buffer is in terms of samples that are pushed or popped
--   during each transaction. for example, when kBufferDepth is 6 and
--   kNumOfElements is 4, the buffer can contain up to 24 individual elements,
--   but will push or pop 4 elements in each transaction.
--
-- vreview_group LutRamPopBuffer
-- vreview_closed http://review-board.natinst.com/r/230293/
-- vreview_reviewers rortega butler
-------------------------------------------------------------------------------

library ieee, work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.PkgNiUtilities.all;
use work.PkgNiFpgaFifo.all;
use work.PkgFpgaDeviceSpecs.all;

entity NiFpgaFifoPopBuffer is
  generic(
    kElementWidth         : positive;
    kNumOfElements        : positive := 1;
    kFifoDepth            : positive;
    kBufferDepth          : positive;
    kRamReadLatency       : positive range 1 to 2;
    kFifoAdditiveLatency  : natural range 0 to 1 := 1;
    kPopThreshold         : natural;
    kGenerateCounts       : boolean := false
    );
  port(
    Clk    : in std_logic;
    aReset : in boolean;
    cReset : in boolean;

    -- connections to adjoining fifo

    cPopToFifo         : out boolean;
    cDataFromFifo      : in  std_logic_vector;
    cFullCountFromFifo : in  unsigned;

    -- connections to user

    cPop        : in  boolean;
    cDisablePop : in  boolean;
    cDataOut    : out std_logic_vector;
    cEmpty      : out boolean;
    cFullCount  : out unsigned(Log2(kFifoDepth+kBufferDepth+1)-1 downto 0);
    cPopFlag    : out boolean := false
    );

end NiFpgaFifoPopBuffer;

architecture rtl of NiFpgaFifoPopBuffer is

  constant kDepth           : positive := kFifoDepth + kBufferDepth;
  constant kGeneratePopFlag : boolean  := kPopThreshold < kDepth;
  constant kFifoReadLatency : positive := kRamReadLatency + kFifoAdditiveLatency;

  subtype Count_t is unsigned(Log2(kDepth+1)-1 downto 0);

  -- The defined subtype is also used to size the counters that count the elements that
  -- pushed to the buffer. Because the read latencies correspond to a push and multiple
  -- elements can be pushed to the buffer during an operation, the size will be the
  -- product between the latencies and the number of elements.
  subtype PpCount_t is unsigned(Log2(kFifoReadLatency * kNumOfElements + 1)-1 downto 0);

  --vhook_sigstart
  signal cEmptyLoc: boolean;
  signal cFull: boolean;
  --vhook_sigend
  signal cBufferEmptyCount: unsigned(Log2(kBufferDepth+1)-1 downto 0);
  signal cBufferFullCount: unsigned(Log2(kBufferDepth+1)-1 downto 0);

  signal cBufferPush                   : boolean;
  signal cPopToFifoLoc, cDisablePopLoc : boolean;

  signal cFullCountLoc  : Count_t   := (others => '0');

  type PushArray_t is array (kFifoReadLatency-2 downto 0) of boolean;
  signal cPushes, cNxPushes : PushArray_t;

  -- kGenerateCounts isn't used in this module
  --vhook_nowarn kGenerateCounts

begin

  -----------------------------------------------------------------------------
  --
  -- Using the Flip Flop FIFO to buffer the data between the user
  -- and the block ram because of the two cycle latency. We constantly
  -- try to keep the FF FIFO full so that the user sees no delay when
  -- popping an element if it is not necessary.
  --
  --                                          NiFpgaFifoPopBuffer
  --                            -------------------------------------------
  --          Block Ram FIFO   |                           FF FIFO         |
  --          --------------   |                          ______________   |
  --         |     Data Out |>>|-cDataFromFifo---------->|DataIn DataOut|>-|--cDataOut
  --         |              |  |                         |              |  |
  --         |              |  |           -Delay-Delay->|Push       Pop|<-|--cPop
  --         |              |  |           |   |   |     |              |  |
  -- iPush-->|Push          |  |           |  -V---V-    |              |  |
  --         |           Pop|<<|cPopToFifo--<|  PP   |   |              |  |
  --         |              |  |             | LOGIC |<--|Full     Empty|>-|->cEmpty
  -- iFull--<|Full FullCount|>>|-EmpLoc----->|       |   |______________|  |
  --         |              |  |              -------                      |
  --          --------------    -------------------------------------------
  --
  -----------------------------------------------------------------------------

  cPopToFifoLoc <= not (cFullCountFromFifo<kNumOfElements or cDisablePop or cDisablePopLoc);

  -- delay elements -----------------------------------------------------------

  DelayBlk : block


  begin

    -- This code will fail when kRamReadLatency=1 and
    -- kFifoAdditiveLatency=0. But if that is the case, the pop buffer is unnecessary.
    assert kFifoReadLatency > 1
      report "If fifo read latency is less than 2, pop buffer is unncessary."
      severity failure;

    -- This code will fail when kRamReadLatency>3; The logic must be updated accordingly.
    assert kFifoReadLatency <= 3
      report "If fifo read latency is more than 3, pop buffer logic must be updated."
      severity failure;

    assert IsPowerOf2(kNumOfElements)
      report "kNumOfElements must be always a positive, power of two value"
      severity failure;

    GenNxPushes : for i in cNxPushes'range generate
      cNxPushes(i) <= cPopToFifoLoc when i = 0 else cPushes(larger(0, i-1));
    end generate GenNxPushes;

    DelayReg : process (Clk, aReset)
    begin
      if aReset then
        cPushes <= (others => false);
      elsif rising_edge(Clk) then
        if cReset then
          cPushes <= (others => false);
        else
          cPushes <= cNxPushes;
        end if;
      end if;
    end process DelayReg;

    cBufferPush <= cPushes(cPushes'left);

  end block DelayBlk;

  -- full count ---------------------------------------------------------------

  FullCountBlk: block

    -- read latencies correspond to push operations and multiple elements can be pushed
    -- to the buffer during a push operation
    constant kExtendedCountThreshold : positive
      := (kFifoReadLatency-1) * kNumOfElements;

    signal cPushQual, cPopQual : boolean := false;
    signal cNxBufferFullCount : unsigned(Log2(kBufferDepth+1)-1 downto 0) :=
      (others=>'0');
    signal cNxExtendedCountAvailable : std_logic;
    signal cExtendedCountAvailable : boolean := false;
    signal cBufferFullCountPlusPendingPushes : unsigned(Log2(kBufferDepth+1)-1 downto 0)
      := (others=>'0');

    signal cPendingPushes : PpCount_t := (others => '0');
    signal cNxPendingPushes : PpCount_t := (others => '0');

    signal cPendingElementsCount : PpCount_t := (others => '0');
    signal cNxPendingElementsCount : PpCount_t := (others => '0');

    signal cSamplesInFifoCount : Count_t := (others => '0');

    signal cNxBufferFullCountPlusPendingPushesAvailable : std_logic;
    signal cBufferFullCountPlusPendingPushesAvailable : boolean := false;
  begin

    -- Track the number of pending pushes that have been issued to the block RAM FIFO.
    cNxPendingPushes <= cPendingPushes + 1 when cPopToFifoLoc and not cBufferPush else
                        cPendingPushes - 1 when cBufferPush and not cPopToFifoLoc else
                        cPendingPushes;

    PendingPushesReg : process (aReset, Clk)
    begin
      if aReset then
        cPendingPushes <= (others => '0');
      elsif rising_edge(Clk) then
        if cReset then
          cPendingPushes <= (others => '0');
        else
          cPendingPushes <= cNxPendingPushes;
        end if;
      end if;
    end process PendingPushesReg;

    -- Ensure that the number of pending pushes never reaches the FIFO
    -- read latency.

    assert cPendingPushes < kFifoReadLatency
      report "Number of pending pushes reaches FIFO read latency."
      severity error;


    -- Compute pending pushes based on number of samples that will be transfered.
    -- The shift left is used to multiply the pending push operations with the number
    -- of elements that will be pushed to the buffer.
    cPendingElementsCount <= shift_left(cPendingPushes, Log2(kNumOfElements));

    cDisablePopLoc <= cPendingElementsCount >= cBufferEmptyCount;

    -- Combinatorially determine what the next buffer count will be. This can be done
    -- simply based on whether there is a push or pop to the buffer.

    cPushQual <= cBufferPush and not cFull;
    cPopQual  <= cPop and not cEmptyLoc;
    cNxBufferFullCount <= cBufferFullCount+kNumOfElements when cPushQual and not cPopQual else
                          cBufferFullCount-kNumOfElements when cPopQual and not cPushQual else
                          cBufferFullCount;

    -- The extended full count is defined as the buffer full count plus the block RAM
    -- FIFO full count plus any pending pushes.  This count should only be available
    -- to the user diagram when the pop buffer is in a state that would allow the user
    -- diagram to issue a pop every clock cycle and pop that many points without timing
    -- out.  The standard case when this is true is when the buffer count is greater than
    -- the read latency.  This can also be true, however, when buffer count plus the
    -- pending pushes is greater than the read latency, but only when the number of
    -- pending pushes is equal to (or greater than) the read latency.

    ExtendedCountReadLatencyOf2: if kFifoReadLatency = 2 generate
    begin
      cNxExtendedCountAvailable <= to_stdlogic(
           (cNxBufferFullCount > kExtendedCountThreshold)
        or (cNxBufferFullCount > 0 and cNxPendingPushes >= kFifoReadLatency-1));

      cNxBufferFullCountPlusPendingPushesAvailable <= '0';

    end generate;

    ExtendedCountReadLatencyOf3: if kFifoReadLatency = 3 generate
    begin

      -- Considerations:
      -- This logic is valid only for the case when kFifoReadLatency = 3
      -- In case the code is would be extended to kFifoReadLatency = 4 the implementation
      -- must be reconsidered.

      -- An example of more generic implementation would be:
      --   cNxExtendedCountAvailable <=
      --         cNxBufferFullCount + cNxPendingElementsCount >= kFifoReadLatency*kNumOfElements and
      --         cNxBufferFullCount > 0;
      --   cNxBufferFullCountPlusPendingPushesAvailable <=  ... a more complex logic

      -- The extended count can be exposed when the sum of internal buffer full counter
      -- and pending elements count is at least kFifoReadLatency. This ensures the user can
      -- continously read the content of the external FIFO and internal buffer.
      -- cNxPushes(1..0) represents the delayed version of the pop signal going to the external FIFO,
      -- and predicts the next writes to the internal buffer.
      -- From cNxPushes we can easily calculate pending elements number and schedule.
      cNxExtendedCountAvailable <= to_stdlogic(
            (cNxBufferFullCount > kExtendedCountThreshold)
         or (cNxBufferFullCount = 1*kNumOfElements and (cNxPushes(1) and cNxPushes(0)))
         or (cNxBufferFullCount = 2*kNumOfElements and (cNxPushes(1) or cNxPushes(0))));

      -- The pending element which will be writen to the internal buffer in the next cycle
      -- can be exposed too when there is at least one element in the internal buffer.
      cNxBufferFullCountPlusPendingPushesAvailable <= to_stdlogic(
                                                      (cNxBufferFullCount > 0 and cNxPushes(1)));

    end generate;

    ExtendedCountAvailableReg: process(Clk, aReset)
    begin
      if aReset then
        cExtendedCountAvailable <= false;
        cBufferFullCountPlusPendingPushesAvailable <= false;
      elsif rising_edge(Clk) then
        cExtendedCountAvailable <= to_boolean(cNxExtendedCountAvailable);
        cBufferFullCountPlusPendingPushesAvailable <=
          to_boolean(cNxBufferFullCountPlusPendingPushesAvailable);
      end if;
    end process ExtendedCountAvailableReg;

    -- Compute pending pushes based on number of samples that will be transfered.
    -- The shift left is used to multiply the pending push operations with the number
    -- of elements that will be pushed to the buffer.
    cNxPendingElementsCount <= shift_left(cNxPendingPushes, Log2(kNumOfElements));

    -- Register the buffer full count plus the pending pushes to reduce timing paths on
    -- the cFullCountLoc signal.

    BufferFullCountPlusPendingPushesReg: process(Clk, aReset)
    begin
      if aReset then
        cBufferFullCountPlusPendingPushes <= (others=>'0');
      elsif rising_edge(Clk) then
        cBufferFullCountPlusPendingPushes <= cNxPendingElementsCount + cNxBufferFullCount;
      end if;
    end process BufferFullCountPlusPendingPushesReg;

    -- Set the full count to either the buffer full count or the extended full
    -- count. note: we should investigate registering this by calculating a
    -- next count using additional logic and perhaps exposing the nx counts
    -- from the other modules if possible.

    SingleElementPerClockCycle: if kNumOfElements = 1 generate
    begin

      cFullCountLoc <=
        resize(cFullCountFromFifo, cFullCountLoc'length) +
            cBufferFullCountPlusPendingPushes when cExtendedCountAvailable else
        resize(cBufferFullCountPlusPendingPushes, cFullCountLoc'length)
          when cBufferFullCountPlusPendingPushesAvailable else
        resize(cBufferFullCount, cFullCountLoc'length);

    end generate SingleElementPerClockCycle;

    MultiElementsPerClockCycle: if kNumOfElements > 1 generate
    begin
      -- The samples from the block RAM FIFO that cannot be moved to the pop buffer
      -- should not be considered for the computation of the full count. The condition for
      -- this case is if there are less samples than kNumOfElemets in the block RAM FIFO.

      StrandedSamples: process(cFullCountFromFifo)
      begin
        cSamplesInFifoCount <= resize(cFullCountFromFifo, cSamplesInFifoCount'length);
        for i in Log2(kNumOfElements)-1 downto 0 loop
          cSamplesInFifoCount(i) <= '0';
        end loop;
      end process StrandedSamples;

      cFullCountLoc <= cSamplesInFifoCount + cBufferFullCountPlusPendingPushes
          when cExtendedCountAvailable else
        resize(cBufferFullCountPlusPendingPushes, cFullCountLoc'length)
          when cBufferFullCountPlusPendingPushesAvailable else
        resize(cBufferFullCount, cFullCountLoc'length);

    end generate MultiElementsPerClockCycle;

  end block FullCountBlk;

  -- output buffer ------------------------------------------------------------

  GenFlipFlopFifo: if not kUseLutRamPopBuffers generate

  --vhook_e NiFpgaFlipFlopFifo
  --vhook_g kWidth          kElementWidth
  --vhook_g kDepth          kBufferDepth
  --vhook_g kPushThreshold  kBufferDepth
  --vhook_g kPopThreshold   kBufferDepth
  --vhook_g kGenerateCounts true
  --vhook_p cDataIn         cDataFromFifo
  --vhook_p cPush           cBufferPush
  --vhook_p cFull           cFull
  --vhook_p cPushFlag       open
  --vhook_p cAlmostFull     open
  --vhook_p cEmptyCount     cBufferEmptyCount
  --vhook_p cEmpty          cEmptyLoc
  --vhook_p cPopFlag        open
  --vhook_p cFullCount      cBufferFullCount
  NiFpgaFlipFlopFifox: entity work.NiFpgaFlipFlopFifo (rtl)
    generic map (
      kWidth          => kElementWidth,   -- in  positive
      kNumOfElements  => kNumOfElements,  -- in  positive := 1
      kDepth          => kBufferDepth,    -- in  positive
      kPushThreshold  => kBufferDepth,    -- in  natural
      kPopThreshold   => kBufferDepth,    -- in  natural
      kGenerateCounts => true)            -- in  boolean := true
    port map (
      aReset      => aReset,             -- in  boolean
      Clk         => Clk,                -- in  std_logic
      cReset      => cReset,             -- in  boolean
      cDataIn     => cDataFromFifo,      -- in  std_logic_vector(kWidth*kNumOfElements-1 
      cPush       => cBufferPush,        -- in  boolean
      cFull       => cFull,              -- out boolean
      cEmptyCount => cBufferEmptyCount,  -- out unsigned(Log2(kDepth+1)-1 downto 0)
      cPushFlag   => open,               -- out boolean := false
      cAlmostFull => open,               -- out boolean
      cDataOut    => cDataOut,           -- out std_logic_vector(kWidth*kNumOfElements-1 
      cPop        => cPop,               -- in  boolean
      cEmpty      => cEmptyLoc,          -- out boolean
      cFullCount  => cBufferFullCount,   -- out unsigned(Log2(kDepth+1)-1 downto 0)
      cPopFlag    => open);              -- out boolean := false

  end generate GenFlipFlopFifo;

  GenLutRamFifo: if kUseLutRamPopBuffers generate

    --vhook_e NiFpgaLutRamFifo
    --vhook_g kWidth            kElementWidth
    --vhook_g kDepth            kBufferDepth
    --vhook_p cDataIn           cDataFromFifo
    --vhook_p cPush             cBufferPush
    --vhook_p cFull             cFull
    --vhook_p cEmptyCount       cBufferEmptyCount
    --vhook_p cEmpty            cEmptyLoc
    --vhook_p cFullCount        cBufferFullCount
    NiFpgaLutRamFifox: entity work.NiFpgaLutRamFifo (rtl)
      generic map (
        kWidth         => kElementWidth,   -- in  positive
        kDepth         => kBufferDepth,    -- in  positive
        kNumOfElements => kNumOfElements)  -- in  positive
      port map (
        aReset      => aReset,             -- in  boolean
        Clk         => Clk,                -- in  std_logic
        cReset      => cReset,             -- in  boolean
        cDataIn     => cDataFromFifo,      -- in  std_logic_vector(kWidth*kNumOfElements-
        cPush       => cBufferPush,        -- in  boolean
        cFull       => cFull,              -- out boolean
        cEmptyCount => cBufferEmptyCount,  -- out unsigned(Log2(kDepth+1)-1 downto 0)
        cDataOut    => cDataOut,           -- out std_logic_vector(kWidth*kNumOfElements-
        cPop        => cPop,               -- in  boolean
        cEmpty      => cEmptyLoc,          -- out boolean
        cFullCount  => cBufferFullCount);  -- out unsigned(Log2(kDepth+1)-1 downto 0)

  end generate GenLutRamFifo;

  -- output assignments -------------------------------------------------------

  cPopToFifo <= cPopToFifoLoc;
  cFullCount <= cFullCountLoc;
  cEmpty     <= cEmptyLoc;
  cPopFlag   <= (cFullCountLoc <= kPopThreshold) and kGeneratePopFlag;

end rtl;
