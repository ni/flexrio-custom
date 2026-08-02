-------------------------------------------------------------------------------
--
-- File: DmaPortInStrmFifoFlags.vhd
-- Author: Haider Khan
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
--   This module is responsible for controlling the input stream data packing
-- FIFO and generating the read/write signals and full/empty counts.
--
-- Harmish - 08/04/2014
-- Added support for the flsuh method.
-- This module implements the logic to handle the flush request.
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

entity DmaPortInStrmFifoFlags is
  generic(
    --kAddressWidth : This is the width of the address bits feeding the BRAM.
    --                Each FIFO location representing one data bus width word.
    kAddressWidth : natural := 8;
    --kSampleSize : This represents the sample size rounded up to the closer
    --                     standard data type.
    kSampleSize : natural := 8;
    --kNumOfSamplesPerWrite : The number of samples that will be written in the FIFO in one
    --                       write cycle;
    kNumOfSamplesPerWrite : positive := 1;
    --kWrPortWidth : This represents the data width that is written to the FIFO.
    kWrPortWidth : natural := 8;
    --kFifoCountWidth : The number of bits needed to represent the number of samples
    --                    that fit in the FIFO.
    kFifoCountWidth : natural;
    --kCorrelatedDataWidth : This is the width of any correlated data that is to be
    --                       transferred from the OClk domain to the IClk domain to
    --                       ensure that the data matches the delay for the empty count.
    kCorrelatedDataWidth : integer := 0;
    --kCorrelatedDataResetValue : The value that the correlated data should reset to.
    kCorrelatedDataResetValue : std_logic_vector
  );
  port(
    --aReset:   Serves as an asynchronous reset to this module.
    aReset : in boolean;

    -------------------------------------------------------------------------------------
    --INPUT PORT:
    -------------------------------------------------------------------------------------
    --The input port is the port that is exposed to the user and is configureable
    --to support data packing.

    --IClk:  This is the input clock to this module. Write pointers
    --       as well as write enables increment synchronous to this clock.
    IClk : in std_logic;
    --iReset:  Synchronous reset for the input circuitry.
    iReset : in boolean;
    --iWrite: This signal is used for pushing data into the BRAM. The signal
    --         is used in this module to increment the write enables and the
    --         write address pointer.
    iWrite : in boolean;
    --iAddr: This is the address that is fed to the BRAM to specify the location to
    --        write to. This address increments with every valid iWrite strobe.
    iFlush : in boolean; 
    iAddr : out unsigned(kFifoCountWidth-1 downto 0);
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
    --data back to the host. This side of the port is configurable to 32-bits, 64-bits
    --or 128-bits.

    --OClk:  This is the output port clock. All data read from BRAM and address
    --       pointers feeding the BRAM are synchronous to this clock.
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
    --oByteLanePtr:  This signal points to the location of the read pointer
    --               within a single FIFO entry. This is useful for cases where the
    --               input and output ports are not symmetric. So for any sample size
    --               other than data bus width, this becomes useful as it represents
    --               the true location of the read pointer.
    oByteLanePtr : out NiDmaByteLane_t;
    --oNumReadSamples:  This signal represents the number of samples for which
    --                  a data request was sent; This is used to update the full count.
    oNumReadSamples : in unsigned(kFifoCountWidth-1 downto 0);
    --oRsrvReadSpaces:  This signal is true for one clock cycle to
    --                  update the FifoFullCount. The amount to update
    --                  the FifoFullCount is specified in bNumReadSamples.
    oRsrvReadSpaces : in boolean;
    --oAddr:  This signal is fed to the BRAM to address the appropriate BRAM
    --        location. The signal is incremented with every pop asserted from
    --        DMA controller engine.
    oAddr : out unsigned(kAddressWidth-1 downto 0);
    --oWritesDisabled:  This value indicates that writes have been disabled on the
    --                  iClk side and that oFullCount will therefore not change as the
    --                  result of an iWrite strobe.
    oWritesDisabled : out boolean;
    --oWriteDetected:  Indicates a write to the FIFO.
    oWriteDetected : out boolean;
    --oCorrelatedDataIn:  The correlated data in.  It is clocked from the OClk to IClk
    --                    domain at the same rate as the FIFO count.
    oCorrelatedDataIn : in std_logic_vector(kCorrelatedDataWidth-1 downto 0);
  
    oFlushReq : out std_logic; 

    -------------------------------------------------------------------------------------
    --FIFO COUNTS:
    -------------------------------------------------------------------------------------
    --The count signals represent the amount of space available in the FIFO and
    --should be used to make decisions about when to push or pop data into or out
    --of the FIFO.

    --iEmptyCount:  The empty count represents the number of empty spaces available
    --              in the FIFO.
    iEmptyCount : out unsigned(kFifoCountWidth-1 downto 0);
    --oFullCount:  The full count represents the number of spaces that have been
    --             already filled in the FIFO.
    oFullCount : out unsigned(kFifoCountWidth-1 downto 0)

  );
end DmaPortInStrmFifoFlags;


architecture rtl of DmaPortInStrmFifoFlags is

  constant kWrPortWidthInBytes : natural := kWrPortWidth/8;
  constant kSampleSizeInBits : natural := kSampleSize;
  constant kSampleSizeInBytes : natural := kSampleSizeInBits/8;
  constant kNiDmaDataWidthInSamples : natural := kNiDmaDataWidth/kSampleSizeInBits;
  constant kPtrWidth : natural := kFifoCountWidth;
  constant kGrayClockCrossingWritePtrWidth : natural :=
    kPtrWidth-Log2(kNumOfSamplesPerWrite);
  constant kOutputResetValue : unsigned(kPtrWidth-1 downto 0) := (others => '0');

  signal oReadSamplePtrUns: unsigned(kPtrWidth-1 downto 0) := (others => '0');
  signal oWriteSamplePtrUns : unsigned(kPtrWidth-1 downto 0);
  signal oWriteSamplePtrUnsDly : unsigned(kPtrWidth-1 downto 0) := (others => '0');
  signal oReadAddUns, oReadAddUnsNx :
    unsigned(kAddressWidth-1 downto 0) := (others => '0');
  signal oReqSamplePtrUns: unsigned(kPtrWidth-1 downto 0) := (others => '0');
  signal oByteLanePtrLoc, oByteLane : NiDmaByteLane_t := (others => '0');
  signal oPush, oPush_ms : boolean;

  signal iReadSamplePtrUns: unsigned(kPtrWidth-1 downto 0) := (others => '0');
  signal iWriteSamplePtrUns: unsigned(kPtrWidth-1 downto 0) := (others => '0');
  signal iWriteSamplePtrUnsGray: Gray(kGrayClockCrossingWritePtrWidth-1 downto 0) :=
    (others => '0');

  signal iWritesDisabledSampPtrUns, iWritesDisabledSampPtrUnsGray : boolean := true;
  signal oWritesDisabledLoc : boolean;

  -- Harmish: 06/08/2014: Signals to support flush feature ---------------
  signal iFlushDly : boolean;

  signal iFlushPending : boolean := false;
  signal iWritePtrHSPush : boolean := false;
  signal iWritePtrHSReady : boolean := false;
  signal iWriteSamplePtrUnsLatched: unsigned(kPtrWidth-1 downto 0) := (others => '0');
  signal oWriteSamplePtrUnsLcl :std_logic_vector(kPtrWidth-1 downto 0) := (others => '0');
  signal oWriteSamplePtrUnsLatched :unsigned(kPtrWidth-1 downto 0) := (others => '0');
  signal oWritePtrHSValid : boolean := false;
  signal oFlushReqLoc : std_logic;
  -------------------------------------------------------------------------
  
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of oPush_ms,oPush: signal is "true";

  --vhook_sigstart
  --vhook_sigend

begin

  ---------------------------------------------------------------------------------------
  ---------------------------------------------------------------------------------------

  RequestByteLanePointer:
  -- The request byte lane pointer is used in the stream controller to be send with
  -- the following request. The pointer is updated based on the number of bytes requested
  -- in the previous request.
  process(aReset, OClk)
  begin
    if aReset then
      oByteLanePtrLoc <= (others => '0');
    elsif rising_edge(OClk) then
      if oReset then
        oByteLanePtrLoc <= (others => '0');
      elsif oRsrvReadSpaces then
        oByteLanePtrLoc <= shift_left(resize(oNumReadSamples, oByteLanePtrLoc'length),
        log2(kSampleSizeInBytes)) + oByteLanePtrLoc;
      end if;
    end if;
  end process;

  oByteLanePtr <= oByteLanePtrLoc;


  ByteLanePointer:
  --Since the BRAM can be wider than the sample size, it is important to know where the
  --read pointer truly points within a BRAM read address. The bytelane pointer provides
  --the extra resolution to point to a certain sample within a single BRAM element for
  --the case where the write port is smaller than data bus size. The byte lane pointer
  --always points to zero when the write port is larger than the data bus size.
  --Since the byte lane pointer is used as part of the read pointer, it is important to
  --reset the value to zero when the synchronous reset (oReset) happens.
  process(aReset, OClk)
  begin
    if aReset then
      oByteLane <= (others => '0');
    elsif rising_edge(OClk) then
      if oReset then
        oByteLane <= (others => '0');
      elsif oPop then
        oByteLane <= oByteLane + resize(oByteCount, oByteLane'length);
      end if;
    end if;
  end process;

  ReadAddressCounter:
  --The read address is incremented based on the oRead signal.
  --It is the responsibility of the DMA controller engine to make sure that the oRead
  --signal is asserted appropriately. An inappropriate use of the oRead signal would be
  --when the sample size is 1 byte and the ByteLanePtr is pointing to the first byte in
  --a particular FIFO element and the DMA controller engine assert oRead when it is
  --going to read less than 8 bytes.
  process(oReset, oReadAddUns, oRead)
  begin
    if oReset then
      oReadAddUnsNx <= (others => '0');
    elsif oRead then
      oReadAddUnsNx <= oReadAddUns + 1;
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

  oAddr <= oReadAddUns;

  ReqReadAddressCounter:
  process(aReset, OClk)
  begin
    if aReset then
      oReqSamplePtrUns <= (others => '0');
    elsif rising_edge(OClk) then
      if oReset then
        oReqSamplePtrUns <= (others => '0');
      elsif oRsrvReadSpaces then
        oReqSamplePtrUns <= oReqSamplePtrUns + oNumReadSamples;
      end if;
    end if;
  end process;


  NarrowerSampleSize: if kSampleSizeInBits <= kNiDmaDataWidth generate
    -- In this case the read sample address pointer is computed by concatenating
    -- to the FIFO location pointer the number of samples poped during each read cycle.

    oReadSamplePtrUns <= oReadAddUns & oByteLane(oByteLane'left downto
                         (Log2(kNiDmaDataWidthInBytes)-Log2(kNiDmaDataWidthInSamples)));
  end generate;

  WiderSampleSize: if kSampleSizeInBits > kNiDmaDataWidth generate
    -- For the case when the sample size is wider than the data bus width one sample
    -- will be pop during many clock cycles.
    oReadSamplePtrUns <= oReadAddUns(oReadAddUns'left downto
                         Log2(kSampleSizeInBits/kNiDmaDataWidth));
  end generate;


  OClkToIClkCrossing: block is
    constant kClockCrossingWidth : natural := kPtrWidth + kCorrelatedDataWidth;
    constant kClockCrossingResetValue : unsigned(kClockCrossingWidth-1 downto 0) :=
      unsigned(kCorrelatedDataResetValue) & kOutputResetValue;
    signal oClockCrossingDataIn : unsigned(kClockCrossingWidth-1 downto 0);
    signal iClockCrossingDataOut : unsigned(kClockCrossingWidth-1 downto 0);
  begin

    --The module is used to push the read pointer accross to the write clock domain side.
    --The module uses a handshake mechanism to move the pointer to the other side. Gray
    --could not be used here because the least significant bits of the pointer made of
    --the oByteLanePtr can change in random fashion and not in a known good pattern.

    --vhook_e DmaPortFifoPtrClockCrossing SyncToIClk
    --vhook_a kPtrWidth kClockCrossingWidth
    --vhook_a kOutputResetValue kClockCrossingResetValue
    --vhook_a iPush oPush
    --vhook_a IClk OClk
    --vhook_a iData oClockCrossingDataIn
    --vhook_a OClk IClk
    --vhook_a oData iClockCrossingDataOut
    SyncToIClk: entity work.DmaPortFifoPtrClockCrossing (rtl)
      generic map (
        kPtrWidth         => kClockCrossingWidth,       -- in  integer := 32
        kOutputResetValue => kClockCrossingResetValue)  -- in  unsigned
      port map (
        aReset => aReset,                 -- in  boolean
        IClk   => OClk,                   -- in  std_logic
        iPush  => oPush,                  -- in  boolean
        iData  => oClockCrossingDataIn,   -- in  unsigned(kPtrWidth-1 downto 0) := ( othe
        OClk   => IClk,                   -- in  std_logic
        oData  => iClockCrossingDataOut); -- out unsigned(kPtrWidth-1 downto 0)

    -- The input to the clock crossing module is the write pointer plus any correlated
    -- data.
    oClockCrossingDataIn(kPtrWidth-1 downto 0) <= oReadSamplePtrUns;
    oClockCrossingDataIn(kCorrelatedDataWidth+kPtrWidth-1 downto kPtrWidth) <=
      unsigned(oCorrelatedDataIn);

    -- Retrieve the pointer and correlated data from the clock crossing output.
    iReadSamplePtrUns <= iClockCrossingDataOut(kPtrWidth-1 downto 0);
    iCorrelatedDataOut <= std_logic_vector(iClockCrossingDataOut(kCorrelatedDataWidth+
      kPtrWidth-1 downto kPtrWidth));

  end block OClkToIClkCrossing;

  -- The push signal should always be true so that we continually push the read
  -- pointer, but this is unsafe immediately following reset since push resets to
  -- false.  Therefore, we double sync the push to true following reset.
  DoubleSyncPush:
  process(aReset, OClk)
  begin
    if aReset then
      oPush_ms <= false;
      oPush <= false;
    elsif rising_edge(OClk) then
      oPush_ms <= true;
      oPush <= oPush_ms;
    end if;
  end process;


  --The empty count is zero when the read pointer is one addr behind the write pointer.
  iEmptyCount <= iReadSamplePtrUns - iWriteSamplePtrUns - 1;

  ---------------------------------------------------------------------------------------
  ---------------------------------------------------------------------------------------

  WriteAddressCounter:
  --The write pointer is used to generate the write enables as well the address for the
  --BRAM.
  process(aReset, IClk)
  begin
    if aReset then

      iWriteSamplePtrUns <= (others => '0');
      iWriteSamplePtrUnsGray <= (others => '0');

      -- The writes disabled signals must reset to true since the channel resets to the
      -- Unlinked state, where writes are disabled.
      iWritesDisabledSampPtrUns <= true;
      iWritesDisabledSampPtrUnsGray <= true;

    elsif rising_edge(IClk) then

      if iReset then
        iWriteSamplePtrUns <= (others => '0');
      elsif iWrite then
        iWriteSamplePtrUns <= iWriteSamplePtrUns + kNumOfSamplesPerWrite;
      end if;

      if iReset then
        iWriteSamplePtrUnsGray <= (others => '0');
      else
        iWriteSamplePtrUnsGray <= To_Gray(
          iWriteSamplePtrUns(iWriteSamplePtrUns'left downto Log2(kNumOfSamplesPerWrite)));
      end if;

      -- The writes disabled signal should follow the write pointer data path so that
      -- it matches the delay.
      if iReset then
        iWritesDisabledSampPtrUns <= true;
        iWritesDisabledSampPtrUnsGray <= true;
      else
        iWritesDisabledSampPtrUns <= iWritesDisabled;
        iWritesDisabledSampPtrUnsGray <= iWritesDisabledSampPtrUns;
      end if;

    end if;
  end process;

  ---------------------------------------------------------------------------------------
  -- Transfer the FIFO write pointer to the read clock domain.
  --
  -- There is no asynchronous reset for these count values since this count is being
  -- passed from the asynchronous diagram reset domain to the synchronous bus reset
  -- domain.  When asynchronous diagram reset asserts, the reset may reach some flip
  -- flops before others cause glitchiness in logic that is fed from both flip flops.
  -- In order to ensure that this glitchiness does not translate into metastability
  -- and reach the synchronous bus reset domain, the double synchronizer here is used.
  -- Since it is not reset with asynchronous diagram reset, there is no possibility that
  -- diagram reset reaches one flip flop right before a clock edge and not the next
  -- flip flop, so any metastability should be settled out.
  --
  -- It's ok not to reset this count because the driver can reset it synchronously.
  -- The driver is required to reset the DMA channel prior to issuing a diagram reset.
  --
  -- For synchronizing the pointers, a multi-bit double-synchronizer is built by
  -- directly instantiating DFlopGray components.
  ---------------------------------------------------------------------------------------

  --vhook_e DmaPortFifoSyncGrayCounters SyncToOClk
  --vhook_a kWidth kGrayClockCrossingWritePtrWidth
  --vhook_a kPtrWidth kPtrWidth
  --vhook_a kNumOfSamplesPerWrite kNumOfSamplesPerWrite
  --vhook_a OClk OClk
  --vhook_a oReset oReset
  --vhook_a iInputPtrGray iWriteSamplePtrUnsGray
  --vhook_a iDisablePtr iWritesDisabledSampPtrUnsGray
  --vhook_a oOutputPtrUns oWriteSamplePtrUns
  --vhook_a oDisablePtr oWritesDisabledLoc
  SyncToOClk: entity work.DmaPortFifoSyncGrayCounters (rtl)
    generic map (
      kWidth                => kGrayClockCrossingWritePtrWidth,  -- in  positive
      kPtrWidth             => kPtrWidth,                        -- in  positive
      kNumOfSamplesPerWrite => kNumOfSamplesPerWrite)            -- in  positive
    port map (
      OClk          => OClk,                           -- in  std_logic
      oReset        => oReset,                         -- in  boolean
      iInputPtrGray => iWriteSamplePtrUnsGray,         -- in  Gray(kWidth-1 downto 0)
      iDisablePtr   => iWritesDisabledSampPtrUnsGray,  -- in  boolean
      oOutputPtrUns => oWriteSamplePtrUns,             -- out unsigned(kPtrWidth-1 downto
      oDisablePtr   => oWritesDisabledLoc);            -- out boolean
  
  oFullCount <= oWriteSamplePtrUns - oReqSamplePtrUns;
  oWritesDisabled <= oWritesDisabledLoc;

  -- Delay the FIFO write pointer so that we can track when the FIFO pointer
  -- gets incremented.
  DelayWriteSamplePtr: process (aReset, OClk)
  begin
    if aReset then
      oWriteSamplePtrUnsDly <= (others => '0');
    elsif rising_edge(Oclk) then
      if oReset then
        oWriteSamplePtrUnsDly <= (others => '0');
      else
        oWriteSamplePtrUnsDly <= oWriteSamplePtrUns;
      end if;
    end if;
  end process DelayWriteSamplePtr;

  -- The oWriteDetected is registered so that we can more easily meet the timing closure.
  WriteDetectReg: process (aReset, OClk)
  begin
    if aReset then
      oWriteDetected <= false;
    elsif rising_edge(Oclk) then
      if oReset then
        oWriteDetected <= false;
      elsif oWriteSamplePtrUns = oWriteSamplePtrUnsDly then
        oWriteDetected <= false;
      else
        oWriteDetected <= true;
      end if;
    end if;
  end process WriteDetectReg;

  -- The address fed to the BRAM represents the number of FIFO locations
  -- in terms of samples.
  iAddr <= iWriteSamplePtrUns;

  -----------------------------------------------------------------------------
  ------------------- Logic for the Flush feature -----------------------------
  -----------------------------------------------------------------------------
  
  -- If FlushStrobe comes in then go to flush_pending state.
  -- Clear the flush_pending state when the latched write pointer has been pushed into the Handshake component.
  	process(aReset, IClk)
	begin
	 if aReset then
		iFlushPending <= false;
	 elsif rising_edge(IClk) then
		if(iReset) then
			iFlushPending <= false;
		elsif (iFlushDly) then
			iFlushPending <= true;
		elsif (iFlushPending and iWritePtrHSReady) then
			iFlushPending <= false;
		end if;
	end if;
	end process;
	
	-- If we are in Flush_pendind state and if we can push the strobe in the oClk domain then push it.
	iWritePtrHSPush <= iFlushPending and iWritePtrHSReady;
	 
	-- + Handshake component for the latched write pointer clock crossing
	-- + Constraints for this handshake component are generated dynamically through
	--   \\lvfpga\fpga\main\trunk\8.0\source\LabVIEW\resource\RVI\CommunicationInterface\PlugIns\DmaPortModGen.llb\Utilities\niFpgaPrintDmaPortInputFifoConstraints.vi
	WritePointerHandshake: entity work.HandshakeBaseResetCross (rtl)
      generic map (
        kDataWidth => kPtrWidth) 
      port map (
        aResetToDlyPush    => open,                 
        aResetToIResetFast => open,                 
        aPushToggleDly     => open,                 
        aIReset            => iReset,        
        IClk               => IClk,                 
        iPush              => iWritePtrHSPush,  
        iData              => std_logic_vector(iWriteSamplePtrUnsLatched),                  
        iStoredData        => open,                  
        iReady             => iWritePtrHSReady,                 
        iOResetStatus      => open,                  
        aOReset            => oReset,            
        OClk               => OClk,                
        oDataValid         => oWritePtrHSValid,  
        oDataAck           => true,                 
        oData              => oWriteSamplePtrUnsLcl);                
	
	-- * Delay the iFlush request by one clock cycle --> This is necessary because 
	--   writePointer is updated one clock cycle after the Write Strobe. If Flush 
	--   and Write comes into the same cycle then we want to latch the updated write pointer.
	
	process(aReset, IClk)
	begin
	if aReset then
		iFlushDly <= false;
	elsif rising_edge(IClk) then
		if(iReset) then
			iFlushDly <= false;
		else
			iFlushDly <= iFlush;
		end if;
	end if;
	end process;
	
	-- Latch the Write pointer on delayed iFlush strobe(iFlushDly)
	process(aReset, IClk)
	begin
	if aReset then
		iWriteSamplePtrUnsLatched <= (others => '0');
	elsif rising_edge(IClk) then
		if iReset then
			iWriteSamplePtrUnsLatched <= (others => '0');
		elsif(iFlushDly) then
			iWriteSamplePtrUnsLatched <= iWriteSamplePtrUns;
		else
			iWriteSamplePtrUnsLatched <= iWriteSamplePtrUnsLatched;
		end if;
	end if;
	end process;
	  
	-- Latch the Write pointer when write pointer has crossed the clock domain and is valid in oClk
	process(aReset, OClk)
	begin
    if aReset then
      oWriteSamplePtrUnsLatched <= (others => '0');
    elsif rising_edge(OClk) then
      if oReset then
        oWriteSamplePtrUnsLatched <= (others => '0');
	  elsif(oWritePtrHSValid) then
		oWriteSamplePtrUnsLatched <= unsigned(oWriteSamplePtrUnsLcl);
	  else
		oWriteSamplePtrUnsLatched <= oWriteSamplePtrUnsLatched;
	  end if;
    end if;

	end process;  
	
	-- * When latched_write pointer is valid in oClk domain then set the flush pending(oFlushReq) in oClk.
	-- * If read and latched write pointer equals then clear flush pending state in oClk. Read pointer(rather than request pointer) 
	--   always increments by one so it is always guaranteed that at some point flush_pending state will be cleared.
	-- * Don't compare Write pointer and Request_read pointer(oReqSamplePtrUns) because request_read pointer can increment in discrete steps and
	--   this can cause request pointer going past the latched write pointer without equalling it.
	--   e.g. Write(Cycle-0), Flush(Cycle-1), Write(Cycle-2)... in this case request_read pointer will jump from 0 to 2, whereas
	--   latched write pointer will be 1. but read pointer increments in steps of 1 i.e. 0->1->2 and it will match write pointer.
	-- * If request to set and clear the flush pending state comes in the same cycle then 
	--   setting flush_pending state has higher priority than clearing flush_pending state. To 
	--   ensure this priority maintain the order of if-else ladder below.
	process(aReset, OClk)
	begin
	if aReset then
      oFlushReqLoc <= '0';
    elsif rising_edge(OClk) then
		if(oReset) then
			oFlushReqLoc <= '0';
		elsif (oWritePtrHSValid) then                                   -- higher priority
			oFlushReqLoc <= '1';
		elsif (oWriteSamplePtrUnsLatched = oReadSamplePtrUns) then       -- lower priority
			oFlushReqLoc <= '0';
		else
			oFlushReqLoc <= oFlushReqLoc;
		end if;
	end if;
	end process;
	oFlushReq <= oFlushReqLoc;
end rtl;
