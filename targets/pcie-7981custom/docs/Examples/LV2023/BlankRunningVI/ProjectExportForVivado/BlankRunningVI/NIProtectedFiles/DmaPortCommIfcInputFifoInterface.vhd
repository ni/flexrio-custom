-------------------------------------------------------------------------------
--
-- File: DmaPortCommIfcInputFifoInterface.vhd
-- Author: Matthew Koenn
-- Original Project: LabVIEW FPGA
-- Date: 11 June 2008
--
-------------------------------------------------------------------------------
-- (c) 2008 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--
-- This file implements the input DMA FIFO that connects to the Chinch LvFpga
-- interface.  The module simply consists of an input FIFO, the LV FPGA
-- enable chain component, and some interconnect between them.
--
-- Bogdan Popa - 09/09/2013
-- Added support for the Handshaking interface.
--
-- Harmish - 08/04/2014 - Added support for Flush method.
-- * vFlushIn/Out/Clear signals acts as the input to ViClkFlushEnableChain
--   and outputs the strobe(iFlush) for the Flush logic in DmaPortInStrmFifo.
-- * New field "FlushRequest" is added to the bInputStreamInterfaceFromFifo record(PkgDmaPortDmaFifos.vhd)
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;

  -- The pkg that specifies several signals used by the user VI and register
  -- framework.
  use work.PkgCommunicationInterface.all;
  use work.PkgDmaPortCommunicationInterface.all;

  -- The pkg containing the definitions for the FIFO interface signals.
  use work.PkgDmaPortDmaFifos.all;

  -- Contains functions for determining depths of data packing FIFOs.
  use work.PkgDmaPortDataPackingFifo.all;

  -- Contains stream state definitions.
  use work.PkgDmaPortCommIfcStreamStates.all;

  -- This package contains the definitions for the interface between the NI DMA IP and
  -- the application specific logic.
  use work.PkgNiDma.all;


entity DmaPortCommIfcInputFifoInterface is
    generic(

      -- kFifoDepth      : This is the size of the DMA FIFO in terms of bus data width
      --                   words.
      kFifoDepth         : natural  := 1024;

      -- kSampleWidth     : This is the width of one sample coming from the user VI.
      kSampleWidth        : positive := 32;

      -- kNumOfSamplesPerWrite : This the number of samples that are written in the FIFO
      --                    at one time;
      kNumOfSamplesPerWrite    : positive := 1;

      -- kScl            : This boolean controls whether or not the DMA channel
      --                   is located in a single cycle loop.  This is used to
      --                   control how the enable chain with the user VI
      --                   operates.
      kScl               : boolean  := false;

      -- kCountScl       : This boolean controls whether or not the query FIFO
      --                   count method is in a single cycle loop.
      kCountScl          : boolean  := false;

      -- kSignExtend     : This boolean controls whether or not to sign extend
      --                   the data before it is sent to the host.  This is
      --                   used if the data type is a fixed-point number, and
      --                   the generic is set dynamically by LabVIEW.
      kSignExtend        : boolean  := false;

      -- kFxpType        : This boolean indicates whether the data type is a
      --                   FXP type.
      kFxpType           : boolean  := false;

      -- kPeerToPeer     : This boolean indicates whether the stream is a normal
      --                   target to host stream or a peer-to-peer source stream.
      kPeerToPeer        : boolean  := false;

      -- kDisableOnFifoTimeout  : This sets whether or not the stream disables when an
      --                          overflow/underflow occurs.
      kDisableOnFifoTimeout     : boolean;

      -- kViClkIsDefaultClk     : This bit is set when the DMA clock (or VI clock) is
      --                          the same clock as the default clock.
      kViClkIsDefaultClk        : boolean;
      
      -- kWriteUsingHandshaking : This boolean indicates the interface of the FIFO,
      --                          Timeout or Handshaking.
      kWriteUsingHandshaking    : boolean := false

    );
    port(

      -- The asynchronous reset for the stream circuit
      aDiagramReset : in boolean;

      aBusReset : in boolean;

      -- The IO Port 2 transmit clock
      BusClk : in std_logic;

      -------------------------------------------------------------------------
      -- Communication Interface interface
      -------------------------------------------------------------------------

      -- The signals going from the top level communication interface to the
      -- FIFO.
      bInputStreamInterfaceToFifo : in InputStreamInterfaceToFifo_t;

      -- The signals going from the FIFO to the top level communication
      -- interface.
      bInputStreamInterfaceFromFifo : out InputStreamInterfaceFromFifo_t;
      -------------------------------------------------------------------------
      -- User VI interface for writing
      -------------------------------------------------------------------------

      -- ViClk       : The user VI clock for writing
      ViClk          : in std_logic;

      -- vDataIn     : The data coming from the user VI to push into the FIFO.
      vDataIn        : in std_logic_vector(kSampleWidth*kNumOfSamplesPerWrite-1 downto 0);

      -- vFull       : This indicates to the user VI when the FIFO is full.
      vFull          : out std_logic;

      -- vTimeout    : This is the number of ViClk cycles to wait to push data
      --               into the FIFO in the case that the FIFO is full.
      --               If the timeout is reached before there is space available
      --               in the FIFO, the user VI receives the EnableOut signal,
      --               but the data has not been pushed.
      vTimeout       : in  std_logic_vector(31 downto 0);

      -- vEnableIn   : This is the signal from the user VI indicating that he wishes
      --               to perform a push.
      vEnableIn      : in  std_logic;

      -- vEnableOut  : This is the signal to the user VI indicating that the push
      --               has occurred or timeout has occurred.  This stays asserted
      --               until the VI asserts EnableClear.
      vEnableOut     : out std_logic;

      -- vEnableClear : This is the signal from the user VI to clear the EnableOut signal
      --                and indicate that EnableIn should be re-processed.
      vEnableClear    : in  std_logic;
	  
	  -- Signals for Flush enable chain
	  vFlushEnableIn    : in std_logic;                  
      vFlushEnableOut   : out std_logic;                  
      vFlushEnableClear : in std_logic;     

      -- vCtCount     : The current FIFO empty count in the ViClk domain.
      vCtCount        : out unsigned(31 downto 0);

      -- Enable chain for the empty count.
      vCtEnableIn            : in  std_logic;
      vCtEnableOut           : out std_logic;
      vCtEnableOutClear      : in  std_logic;
      
      -- Handshaking signals
      vInputValid            : in  std_logic;
      vReadyForInput         : out std_logic;


      -------------------------------------------------------------------------
      -- User VI interface for stream state info and transitioning
      -------------------------------------------------------------------------

      -- DefaultClk : The top level clock to which the state transitions and
      --              stream state info is synchronous to.
      DefaultClk : in std_logic;

      -- The enable chain for the stream state in the VI clock domain.
      vStreamStateEnableIn : in std_logic;
      vStreamStateEnableOut : out std_logic;
      vStreamStateEnableClear : in std_logic;
      vStreamStateOut : out StreamStateValue_t;

      -- The enable chain for the stream state in the default clock domain.
      dStreamStateEnableIn : in std_logic;
      dStreamStateEnableOut : out std_logic;
      dStreamStateEnableClear : in std_logic;
      dStreamStateOut : out StreamStateValue_t;

      -- The current value of the stream state used by the get stream state resholder
      -- if it is in a SCTL in the DefaultClk domain.
      dCurrentStreamState : out StreamStateValue_t;

      -- The enable chain for the start request.
      dStartRequestEnableIn : in std_logic;
      dStartRequestEnableOut : out std_logic;
      dStartRequestEnableClear : in std_logic;

      -- The enable chain for the stop request.
      dStopRequestEnableIn : in std_logic;
      dStopRequestEnableOut : out std_logic;
      dStopRequestEnableClear : in std_logic;

      -- The enable chain for the stop with flush request.
      dStopWithFlushRequestEnableIn : in std_logic;
      dStopWithFlushRequestEnableOut : out std_logic;
      dStopWithFlushRequestEnableClear : in std_logic;
      dStopWithFlushRequestTimeout : in signed(31 downto 0);
      dStopWithFlushRequestTimedOut : out std_logic

    );
end DmaPortCommIfcInputFifoInterface;


architecture structure of DmaPortCommIfcInputFifoInterface is

  -- The constant represents the sample width rounded up to the closer standard data type.
  constant kSampleSize : integer := ActualSampleSize (SampleSizeInBits => kSampleWidth,
                                                      PeerToPeer => kPeerToPeer,
                                                      FxpType => kFxpType);

  -- The address width represents the number of bits nedeed to represent the FIFO's depth
  -- in terms of data bus width words.
  constant kAddressWidth : integer := Log2(kFifoDepth);

  -- This is the width of the data written in the FIFO on the VI side;
  constant kWrPortWidth : integer := kSampleSize*kNumOfSamplesPerWrite;

  constant kDataZero : std_logic_vector(kWrPortWidth-1 downto 0) := (others=>'0');

  -- The count width, which is the address width with the sample size taken into account.
  constant kFifoCountWidth : integer := FifoCountWidth(SampleSize => kSampleSize,
                                                       AddressWidth => kAddressWidth);


  signal vFullFromFifo: boolean;
  signal vEmptyCount, vEmptyCountLoc: unsigned(kFifoCountWidth-1 downto 0);
  signal bFifoFullCount: unsigned(kFifoCountWidth-1 downto 0);
  signal bStreamState : StreamStateValue_t;
  signal vFifoOverflow : std_logic;
  signal vFifoOverflowFlag : std_logic;
  signal bStartStreamRequest : boolean;
  signal bStateInDefaultClkDomain : StreamStateValue_t;
  signal vWritesDisabled, vWritesDisabledForController : boolean;
  signal bWritesDisabled : boolean;
  signal bTransferEnd: boolean;
  signal bPop, bPopFifo: boolean;
  signal bByteEnableDirect: NiDmaByteEnable_t;

  --vhook_sigstart
  signal bByteCount: NiDmaBusByteCount_t;
  signal bByteLanePtr: NiDmaByteLane_t;
  signal bDmaReset: boolean;
  signal bFifoDataOut: NiDmaData_t;
  signal bFifoOverflow: boolean;
  signal bFlushTimeoutRequest: boolean;
  signal bNumReadSamples: unsigned(kFifoCountWidth-1 downto 0);
  signal bOverflowStopRequest: boolean;
  signal bResetDone: boolean;
  signal bResetForFifo: boolean;
  signal bRsrvReadSpaces: boolean;
  signal bStopStreamRequestFromDiagram: boolean;
  signal bStopStreamWithFlushRequest: boolean;
  signal bWriteDetected: boolean;
  signal dPushStateToBusClkDomain: boolean;
  signal dStopRequest: boolean;
  signal dStopRequestStrobe: boolean;
  signal dStopWithFlushRequestStrobe: boolean;
  signal vCtCountLoc: unsigned(vEmptyCount'length-1 downto 0);
  signal vCtEnableOutBool: boolean;
  signal vDisable: boolean;
  signal vEnableOutLoc: boolean;
  signal vFifoDataIn: std_logic_vector(kWrPortWidth-1 downto 0);
  signal vFlush: boolean;
  signal vOverflowStopRequest: boolean;
  signal vPush: boolean;
  signal vPushPop: boolean;
  signal vResetForFifo: boolean;
  signal vStateDisable: boolean;
  signal vStreamState: StreamState_t;
  signal vStreamStateFromController: StreamState_t;
  signal vStreamStateValueFromControllerEarly: std_logic_vector(bStreamState'length-1 downto 0);
  --vhook_sigend
  
  signal vStreamStateValueFromController: std_logic_vector(bStreamState'length-1 downto 0);
  signal vStreamStateValueFromControllerDly: std_logic_vector(bStreamState'length-1 downto 0) := to_StreamStateValue(Unlinked);
  signal vDisableEarly : boolean;
  
  signal vAlmostFull        : boolean;
  signal vInputValidQual    : boolean;
  signal vReadyForInputBool : boolean;
  signal vReadyForInputReg  : boolean := true;
  
  
  signal bFlushReqFifo : std_logic;
  signal vFlushEnableInDelay : std_logic;


begin

  bDmaReset <= bInputStreamInterfaceToFifo.DmaReset;
  bPop <= bInputStreamInterfaceToFifo.Pop;
  bTransferEnd <= bInputStreamInterfaceToFifo.TransferEnd;
  bByteEnableDirect <= bInputStreamInterfaceToFifo.ByteEnable;
  bNumReadSamples <= resize(bInputStreamInterfaceToFifo.NumReadSamples,
                     bNumReadSamples'length);
  bRsrvReadSpaces <= bInputStreamInterfaceToFifo.RsrvReadSpaces;
  bStreamState <= bInputStreamInterfaceToFifo.StreamState;
  bByteCount <= bInputStreamInterfaceToFifo.ByteCount;

  bInputStreamInterfaceFromFifo.ByteLanePtr <= bByteLanePtr;
  bInputStreamInterfaceFromFifo.ResetDone <= bResetDone;
  bInputStreamInterfaceFromFifo.FifoDataOut <= bFifoDataOut;
  bInputStreamInterfaceFromFifo.FifoFullCount <= resize(bFifoFullCount,
    bInputStreamInterfaceFromFifo.FifoFullCount'length);
  bInputStreamInterfaceFromFifo.FifoOverflow <= bFifoOverflow;
  bInputStreamInterfaceFromFifo.StartStreamRequest <= bStartStreamRequest;
  bInputStreamInterfaceFromFifo.StopStreamRequest <= bStopStreamRequestFromDiagram or
    bFlushTimeoutRequest;
  bInputStreamInterfaceFromFifo.StopStreamWithFlushRequest <=
    bStopStreamWithFlushRequest or bOverflowStopRequest;
  bInputStreamInterfaceFromFifo.FlushRequest <= to_Boolean(bFlushReqFifo);
  bInputStreamInterfaceFromFifo.WritesDisabled <= bWritesDisabled;
  bInputStreamInterfaceFromFifo.WriteDetected <= bWriteDetected;
  bInputStreamInterfaceFromFifo.StateInDefaultClkDomain <= bStateInDefaultClkDomain;
  
  bPopFifo <= bPop and ((not bTransferEnd) or bByteEnableDirect(bByteEnableDirect'left));

  --vhook_e DmaPortCommIfcComponentEnableChain
  --vhook_a kInput true
  --vhook_a kDataWidth kWrPortWidth
  --vhook_a kHandshaking kWriteUsingHandshaking
  --vhook_a aReset aDiagramReset
  --vhook_a PClk ViClk
  --vhook_a BusClk BusClk
  --vhook_a pEnableIn to_boolean(vEnableIn)
  --vhook_a pEnableOut vEnableOutLoc
  --vhook_a pEnableClear to_Boolean(vEnableClear)
  --vhook_a pHandshakingPushPopRequest vInputValidQual
  --vhook_a pPushPop vPushPop
  --vhook_a pDisable vDisable
  --vhook_a pResetForFifo vResetForFifo
  --vhook_a bResetForFifo bResetForFifo
  --vhook_a bResetBitFromRegister bDmaReset
  --vhook_a bResetDone bResetDone
  --vhook_a pStateDisable vStateDisable
  --vhook_a pTimeout vTimeout
  --vhook_a pDataOut open
  --vhook_a pFlag vFifoOverflowFlag
  --vhook_a pDataOutFromFifo kDataZero
  --vhook_a pFlagFromFifo to_StdLogic(vFullFromFifo)
  DmaPortCommIfcComponentEnableChainx: entity work.DmaPortCommIfcComponentEnableChain (rtl)
    generic map (
      kInput       => true,                    -- in  boolean := true
      kSCL         => kSCL,                    -- in  boolean := false
      kDataWidth   => kWrPortWidth,            -- in  natural := 32
      kHandshaking => kWriteUsingHandshaking)  -- in  boolean := false
    port map (
      aReset                     => aDiagramReset,               -- in  boolean
      PClk                       => ViClk,                       -- in  std_logic
      BusClk                     => BusClk,                      -- in  std_logic
      pEnableIn                  => to_boolean(vEnableIn),       -- in  boolean
      pEnableOut                 => vEnableOutLoc,               -- out boolean
      pEnableClear               => to_Boolean(vEnableClear),    -- in  boolean
      pHandshakingPushPopRequest => vInputValidQual,             -- in  boolean
      pPushPop                   => vPushPop,                    -- out boolean
      pDisable                   => vDisable,                    -- out boolean
      pResetForFifo              => vResetForFifo,               -- out boolean
      bResetForFifo              => bResetForFifo,               -- out boolean
      bResetBitFromRegister      => bDmaReset,                   -- in  boolean
      bResetDone                 => bResetDone,                  -- out boolean
      pStateDisable              => vStateDisable,               -- in  boolean
      pTimeout                   => vTimeout,                    -- in  std_logic_vector(
      pDataOut                   => open,                        -- out std_logic_vector(
      pFlag                      => vFifoOverflowFlag,           -- out std_logic
      pDataOutFromFifo           => kDataZero,                   -- in  std_logic_vector(
      pFlagFromFifo              => to_StdLogic(vFullFromFifo)); -- in  std_logic



  vEnableOut <= to_StdLogic(vEnableOutLoc);

  -- Each sample in the vDataIn needs to be resized to actual sample size.
  -- Swap the samples order in a write data port for the multi element write case.
  DataInResize: process (vDataIn)
  begin
    for i in 0 to kNumOfSamplesPerWrite-1 loop
      if kSignExtend then
        vFifoDataIn((kNumOfSamplesPerWrite-i)*kSampleSize-1 downto
        (kNumOfSamplesPerWrite-i-1)*kSampleSize) <= std_logic_vector(resize(
            signed(vDataIn((i+1)*kSampleWidth-1 downto i*kSampleWidth)), kSampleSize));
      else
        vFifoDataIn((kNumOfSamplesPerWrite-i)*kSampleSize-1 downto
        (kNumOfSamplesPerWrite-i-1)*kSampleSize) <= std_logic_vector(resize(
            unsigned(vDataIn((i+1)*kSampleWidth-1 downto i*kSampleWidth)), kSampleSize));
      end if;
    end loop;
  end process;
  
    --vhook_e DmaPortCommIfcComponentStreamStateEnableChain ViClkFlushEnableChain
    --vhook_a kSCL kScl
    --vhook_a aReset aDiagramReset
    --vhook_a ViClk ViClk
    --vhook_c vStreamState to_StreamStateValue(Unlinked)
    --vhook_a vEnableIn vFlushEnableIn
    --vhook_a vEnableOut vFlushEnableOut
    --vhook_a vEnableClear vFlushEnableClear
    --vhook_a vStreamStateOut open
    ViClkFlushEnableChain: entity work.DmaPortCommIfcComponentStreamStateEnableChain (rtl)
      generic map (
        kSCL => kScl)  -- in  boolean := false
      port map (
        aReset          => aDiagramReset,                  -- in  boolean
        ViClk           => ViClk,                          -- in  std_logic
        vStreamState    => to_StreamStateValue(Unlinked),  -- in  StreamStateValue_t
        vEnableIn       => vFlushEnableIn,                 -- in  std_logic
        vEnableOut      => vFlushEnableOut,                -- out std_logic
        vEnableClear    => vFlushEnableClear,              -- in  std_logic
        vStreamStateOut => open);                          -- out StreamStateValue_t

   
	process (aDiagramReset, ViClk)
    begin
      if aDiagramReset then
        vFlushEnableInDelay <= '0';
      elsif rising_edge(ViClk) then
        vFlushEnableInDelay <= vFlushEnableIn;
      end if;
    end process;
	SCL : if kSCL generate
		vFlush <= to_boolean(vFlushEnableIn);
	end generate SCL;
	NOSCL : if not kSCL generate
		vFlush <= to_boolean(vFlushEnableIn and not vFlushEnableInDelay);
	end generate NOSCL;
  
  --vhook_e DmaPortInStrmFifo
  --vhook_a kDataTypeIsSigned kSignExtend
  --vhook_a kCorrelatedDataWidth bStreamState'length
  --vhook_a kCorrelatedDataResetValue to_StreamStateValue(Unlinked)
  --vhook_a aReset aDiagramReset
  --vhook_a IClk ViClk
  --vhook_a iReset vResetForFifo
  --vhook_a iWrite vPush
  --vhook_a iFlush vFlush
  --vhook_a iDataIn vFifoDataIn
  --vhook_a iEmptyCount vEmptyCountLoc
  --vhook_a iWritesDisabled vWritesDisabledForController
  --vhook_a iCorrelatedDataOut vStreamStateValueFromControllerEarly
  --vhook_a OClk BusClk
  --vhook_a oReset bResetForFifo
  --vhook_a oRead bPopFifo
  --vhook_a oPop bPop
  --vhook_a oByteCount bByteCount
  --vhook_a oByteLanePtr bByteLanePtr
  --vhook_a oNumReadSamples bNumReadSamples
  --vhook_a oRsrvReadSpaces bRsrvReadSpaces
  --vhook_a oDataOut bFifoDataOut
  --vhook_a oFullCount bFifoFullCount
  --vhook_a oWritesDisabled bWritesDisabled
  --vhook_a oWriteDetected bWriteDetected
  --vhook_a oFlushreqFifo bFlushReqFifo
  --vhook_a oCorrelatedDataIn bStreamState
  DmaPortInStrmFifox: entity work.DmaPortInStrmFifo (rtl)
    generic map (
      kAddressWidth             => kAddressWidth,                  -- in  natural := 8
      kSampleSize               => kSampleSize,                    -- in  natural := 8
      kWrPortWidth              => kWrPortWidth,                   -- in  natural := 8
      kNumOfSamplesPerWrite     => kNumOfSamplesPerWrite,          -- in  positive := 1
      kFifoCountWidth           => kFifoCountWidth,                -- in  natural
      kDataTypeIsSigned         => kSignExtend,                    -- in  boolean := fals
      kCorrelatedDataWidth      => bStreamState'length,            -- in  integer := 0
      kCorrelatedDataResetValue => to_StreamStateValue(Unlinked))  -- in  std_logic_vecto
    port map (
      aReset             => aDiagramReset,                         -- in  boolean
      IClk               => ViClk,                                 -- in  std_logic
      iReset             => vResetForFifo,                         -- in  boolean
      iWrite             => vPush,                                 -- in  boolean
      iFlush             => vFlush,                                -- in  boolean
      iDataIn            => vFifoDataIn,                           -- in  std_logic_vecto
      iEmptyCount        => vEmptyCountLoc,                        -- out unsigned(kFifoC
      iWritesDisabled    => vWritesDisabledForController,          -- in  boolean
      iCorrelatedDataOut => vStreamStateValueFromControllerEarly,  -- out std_logic_vecto
      OClk               => BusClk,                                -- in  std_logic
      oReset             => bResetForFifo,                         -- in  boolean
      oRead              => bPopFifo,                              -- in  boolean
      oPop               => bPop,                                  -- in  boolean
      oByteCount         => bByteCount,                            -- in  NiDmaBusByteCou
      oByteLanePtr       => bByteLanePtr,                          -- out NiDmaByteLane_t
      oNumReadSamples    => bNumReadSamples,                       -- in  unsigned(kFifoC
      oRsrvReadSpaces    => bRsrvReadSpaces,                       -- in  boolean
      oDataOut           => bFifoDataOut,                          -- out NiDmaData_t
      oFullCount         => bFifoFullCount,                        -- out unsigned(kFifoC
      oWritesDisabled    => bWritesDisabled,                       -- out boolean
      oWriteDetected     => bWriteDetected,                        -- out boolean
      oFlushReqFifo      => bFlushReqFifo,                         -- out std_logic
      oCorrelatedDataIn  => bStreamState);                         -- in  std_logic_vecto
      
  WritesDisabledDelayed:if (kWriteUsingHandshaking and kPeerToPeer) generate        
    StreamStateFlop: process (aDiagramReset, ViClk)
    begin
      if aDiagramReset then
        vStreamStateValueFromControllerDly <= to_StreamStateValue(Unlinked);
      elsif rising_edge(ViClk) then
        vStreamStateValueFromControllerDly <= vStreamStateValueFromControllerEarly;
      end if;
    end process;
  end generate WritesDisabledDelayed;
      
  vStreamStateValueFromController <= vStreamStateValueFromControllerDly when (kPeerToPeer and kWriteUsingHandshaking) else
                                    vStreamStateValueFromControllerEarly;
      

  --vhook_e NiFpgaFifoCountControl
  --vhook_a kWidth vEmptyCount'length
  --vhook_a kInSCL kCountScl
  --vhook_a aReset aDiagramReset
  --vhook_a Clk ViClk
  --vhook_a cReset vResetForFifo
  --vhook_a cEnableIn to_boolean(vCtEnableIn)
  --vhook_a cEnableOutClear to_boolean(vCtEnableOutClear)
  --vhook_a cEnableOut vCtEnableOutBool
  --vhook_a cCountIn vEmptyCount
  --vhook_a cCountOut vCtCountLoc
  NiFpgaFifoCountControlx: entity work.NiFpgaFifoCountControl (rtl)
    generic map (
      kWidth => vEmptyCount'length,  -- in  positive
      kInSCL => kCountScl)           -- in  boolean
    port map (
      aReset          => aDiagramReset,                  -- in  boolean
      Clk             => ViClk,                          -- in  std_logic
      cReset          => vResetForFifo,                  -- in  boolean
      cEnableIn       => to_boolean(vCtEnableIn),        -- in  boolean
      cEnableOutClear => to_boolean(vCtEnableOutClear),  -- in  boolean
      cEnableOut      => vCtEnableOutBool,               -- out boolean
      cCountIn        => vEmptyCount,                    -- in  unsigned(kWidth-1 downto 
      cCountOut       => vCtCountLoc);                   -- out unsigned(kWidth-1 downto 

  vCtEnableOut <= to_StdLogic(vCtEnableOutBool);

  -- Report the number of elements available for writing as zero if it is a peer-to-peer
  -- stream and the stream is not enabled.
  vEmptyCount <= vEmptyCountLoc when not vStateDisable else
                 (others=>'0');

  vCtCount <= resize(vCtCountLoc, vCtCount'length);

  -- Do not allow a push to occur when the FIFO is full.  This will prevent
  -- any overflows from occuring.
  vPush <= vPushPop and not vFullFromFifo;

  -- The FIFO is full whenever the empty count is zero.
  vFullFromFifo <= vEmptyCount < kNumOfSamplesPerWrite;
  vFull <= vFifoOverflowFlag;

  -- In case of Handshaking report the overflow condition only when the vInputValid is asserted 
  -- together with pEnableIn while the FIFO is full.
  -- In case of timeout mechanism the overflow condition occurs 
  -- when pEnableIn is asserted while the FIFO is full.  
  vFifoOverflow <= to_stdlogic(to_boolean(vFifoOverflowFlag) and to_boolean(vInputValid)) 
              when kWriteUsingHandshaking else vFifoOverflowFlag;
  
  ---------------------------------------------------------------------------------------
  -- Handshaking interface 
  ---------------------------------------------------------------------------------------
  GenWriteHS : if kWriteUsingHandshaking generate
  
    -- This flag asserts when only one write operation can be performed
    -- The number of empty slots must be greater or equal than the amount written 
    -- in one transaction, but smaller than two write transactions 
    vAlmostFull <= (vEmptyCount >= kNumOfSamplesPerWrite) and (vEmptyCount < (2*kNumOfSamplesPerWrite));
    
    -- This flag is qualified with registered Ready For Input, because the 4-wire
    -- protocol explicitly states that Input Valid can only assert if Ready For Input was 
    -- asserted in the previous cycle. This behavior must be ensured by the upstream component,
    -- but we are making sure that it's correct by qualifying Input Valid here, also.
    vInputValidQual <= to_boolean(vInputValid) and vReadyForInputReg;
    
    -- Added vDisableEarly for the P2P case using Handshaking
    -- This disables vReadyForInputBool one cycle earlier, thus stopping the pushes as soon
    -- as Flushing or Disable state begins. In Flushing or Disable, the FIFO will not accept any data, so
    -- we must alert the user one cycle earlier, since iReadyForInput indicates the readiness of the FIFO on
    -- the next cycle.
    vReadyForInputBool <= not (vFullFromFifo or (vAlmostFull and vPushPop) or vDisable or vDisableEarly);
    
    vReadyForInput <= to_stdLogic(vReadyForInputBool);
    
    -- By setting the register to true, pushed data will be accepted
    -- on the first cycle, if iInputValid is true. This was done to
    -- benefit designs where the enable chain is removed from the SCTL.
    ReadyForInputFlop : process (ViClk, aDiagramReset)
    begin
      if aDiagramReset then
        vReadyForInputReg <= true;
      elsif rising_edge (ViClk) then
        vReadyForInputReg <= vReadyForInputBool;
      end if;
    end process ReadyForInputFlop;
    
  end generate GenWriteHS;

  ---------------------------------------------------------------------------------------
  -- Stream State Enable Chain Components
  ---------------------------------------------------------------------------------------
  StreamStateBlock: block

    signal vStreamStateValue : StreamStateValue_t;
    signal dStreamStateValue, dStreamStateValueFromController : StreamStateValue_t;
    signal dStartTransitionComplete, dStopTransitionComplete,
      dStopWithFlushTransitionComplete : boolean;
    signal dStreamState, dStreamStateFromController : StreamState_t;
    signal bPushStateToDefaultClkDomain : boolean;

  begin

    -- Always allow pushes for a non-peer-to-peer stream.  For a P2P source stream,
    -- pushing to the FIFO is only enabled when the stream is in the Enabled state.
    -- The WritesDisabled signal to be sent back to the BusClk domain is based on the
    -- unlatched stream state, since this value must be guaranteed to eventually settle
    -- to false while the stream state from the controller is Enabled.  Otherwise,
    -- handshaking for the ChinchDmaSourceStreamStateController would not be
    -- possible.
    
    vWritesDisabled <= not (vStreamStateValue = to_StreamStateValue(Enabled));
    vWritesDisabledForController <= not (vStreamStateFromController = Enabled);
    vStateDisable <= vWritesDisabled when kPeerToPeer else false;
    
    vDisableEarly <= not (to_StreamState(vStreamStateValueFromControllerEarly) = Enabled) 
                      when (kPeerToPeer and kWriteUsingHandshaking) else false;
                      
    dStopRequest <= dStopWithFlushRequestStrobe or dStopRequestStrobe;


    -------------------------------------------------------------------------------------
    -- Enable Chain Components for Querying Stream State
    -------------------------------------------------------------------------------------


    --vhook_e DmaPortCommIfcComponentStreamStateEnableChain ViClkStreamStateEnableChain
    --vhook_a kSCL kScl
    --vhook_a aReset aDiagramReset
    --vhook_a ViClk ViClk
    --vhook_a vStreamState vStreamStateValue
    --vhook_a vEnableIn vStreamStateEnableIn
    --vhook_a vEnableOut vStreamStateEnableOut
    --vhook_a vEnableClear vStreamStateEnableClear
    --vhook_a vStreamStateOut vStreamStateOut
    ViClkStreamStateEnableChain: entity work.DmaPortCommIfcComponentStreamStateEnableChain (rtl)
      generic map (
        kSCL => kScl)  -- in  boolean := false
      port map (
        aReset          => aDiagramReset,            -- in  boolean
        ViClk           => ViClk,                    -- in  std_logic
        vStreamState    => vStreamStateValue,        -- in  StreamStateValue_t
        vEnableIn       => vStreamStateEnableIn,     -- in  std_logic
        vEnableOut      => vStreamStateEnableOut,    -- out std_logic
        vEnableClear    => vStreamStateEnableClear,  -- in  std_logic
        vStreamStateOut => vStreamStateOut);         -- out StreamStateValue_t
		
	


    --vhook_e DmaPortCommIfcComponentStreamStateEnableChain DefaultClkStreamStateEnableChain
    --vhook_a kSCL false
    --vhook_a aReset aDiagramReset
    --vhook_a ViClk DefaultClk
    --vhook_a vStreamState dStreamStateValue
    --vhook_a vEnableIn dStreamStateEnableIn
    --vhook_a vEnableOut dStreamStateEnableOut
    --vhook_a vEnableClear dStreamStateEnableClear
    --vhook_a vStreamStateOut dStreamStateOut
    DefaultClkStreamStateEnableChain: entity work.DmaPortCommIfcComponentStreamStateEnableChain (rtl)
      generic map (
        kSCL => false)  -- in  boolean := false
      port map (
        aReset          => aDiagramReset,            -- in  boolean
        ViClk           => DefaultClk,               -- in  std_logic
        vStreamState    => dStreamStateValue,        -- in  StreamStateValue_t
        vEnableIn       => dStreamStateEnableIn,     -- in  std_logic
        vEnableOut      => dStreamStateEnableOut,    -- out std_logic
        vEnableClear    => dStreamStateEnableClear,  -- in  std_logic
        vStreamStateOut => dStreamStateOut);         -- out StreamStateValue_t


    dCurrentStreamState <= dStreamStateValue;


    -------------------------------------------------------------------------------------
    -- Enable Chain Components for State Transitioning
    -------------------------------------------------------------------------------------

    dStartTransitionComplete <= dStreamState = Enabled or dStreamState = Flushing;
    dStopTransitionComplete <= dStreamState = Unlinked or dStreamState = Disabled;
    dStopWithFlushTransitionComplete <= dStreamState = Unlinked or
      dStreamState = Disabled;

    --vhook_e DmaPortCommIfcComponentStateTransitionEnableChain StartEnableChain
    --vhook_a ViClk DefaultClk
    --vhook_a aReset aDiagramReset
    --vhook_a bTransitionRequestStrobe bStartStreamRequest
    --vhook_a bTransitionTimeoutRequestStrobe open
    --vhook_a vTransitionRequestStrobe open
    --vhook_a vTransitionTimeoutRequestStrobe open
    --vhook_a vTransitionComplete dStartTransitionComplete
    --vhook_a vEnableIn dStartRequestEnableIn
    --vhook_a vEnableOut dStartRequestEnableOut
    --vhook_a vEnableClear dStartRequestEnableClear
    --vhook_a vTimedOut open
    --vhook_a vTimeout (others=>'0')
    StartEnableChain: entity work.DmaPortCommIfcComponentStateTransitionEnableChain (rtl)
      port map (
        aReset                          => aDiagramReset,             -- in  boolean
        ViClk                           => DefaultClk,                -- in  std_logic
        BusClk                          => BusClk,                    -- in  std_logic
        bTransitionRequestStrobe        => bStartStreamRequest,       -- out boolean
        bTransitionTimeoutRequestStrobe => open,                      -- out boolean
        vTransitionRequestStrobe        => open,                      -- out boolean
        vTransitionTimeoutRequestStrobe => open,                      -- out boolean
        vTransitionComplete             => dStartTransitionComplete,  -- in  boolean
        vEnableIn                       => dStartRequestEnableIn,     -- in  std_logic
        vEnableOut                      => dStartRequestEnableOut,    -- out std_logic
        vEnableClear                    => dStartRequestEnableClear,  -- in  std_logic
        vTimedOut                       => open,                      -- out std_logic
        vTimeout                        => (others=>'0'));            -- in  signed(31 do



    --vhook_e DmaPortCommIfcComponentStateTransitionEnableChain StopEnableChain
    --vhook_a aReset aDiagramReset
    --vhook_a ViClk DefaultClk
    --vhook_a bTransitionRequestStrobe bStopStreamRequestFromDiagram
    --vhook_a vTransitionRequestStrobe dStopRequestStrobe
    --vhook_a vTransitionComplete dStopTransitionComplete
    --vhook_a vEnableIn dStopRequestEnableIn
    --vhook_a vEnableOut dStopRequestEnableOut
    --vhook_a vEnableClear dStopRequestEnableClear
    --vhook_a bTransitionTimeoutRequestStrobe open
    --vhook_a vTransitionTimeoutRequestStrobe open
    --vhook_a vTimedOut open
    --vhook_a vTimeout (others=>'0')
    StopEnableChain: entity work.DmaPortCommIfcComponentStateTransitionEnableChain (rtl)
      port map (
        aReset                          => aDiagramReset,                  -- in  boolean
        ViClk                           => DefaultClk,                     -- in  std_log
        BusClk                          => BusClk,                         -- in  std_log
        bTransitionRequestStrobe        => bStopStreamRequestFromDiagram,  -- out boolean
        bTransitionTimeoutRequestStrobe => open,                           -- out boolean
        vTransitionRequestStrobe        => dStopRequestStrobe,             -- out boolean
        vTransitionTimeoutRequestStrobe => open,                           -- out boolean
        vTransitionComplete             => dStopTransitionComplete,        -- in  boolean
        vEnableIn                       => dStopRequestEnableIn,           -- in  std_log
        vEnableOut                      => dStopRequestEnableOut,          -- out std_log
        vEnableClear                    => dStopRequestEnableClear,        -- in  std_log
        vTimedOut                       => open,                           -- out std_log
        vTimeout                        => (others=>'0'));                 -- in  signed(



    --vhook_e DmaPortCommIfcComponentStateTransitionEnableChain StopWithFlushEnableChain
    --vhook_a aReset aDiagramReset
    --vhook_a ViClk DefaultClk
    --vhook_a bTransitionRequestStrobe bStopStreamWithFlushRequest
    --vhook_a vTransitionRequestStrobe dStopWithFlushRequestStrobe
    --vhook_a vTransitionComplete dStopWithFlushTransitionComplete
    --vhook_a vEnableIn dStopWithFlushRequestEnableIn
    --vhook_a vEnableOut dStopWithFlushRequestEnableOut
    --vhook_a vEnableClear dStopWithFlushRequestEnableClear
    --vhook_a bTransitionTimeoutRequestStrobe bFlushTimeoutRequest
    --vhook_a vTransitionTimeoutRequestStrobe open
    --vhook_a vTimedOut dStopWithFlushRequestTimedOut
    --vhook_a vTimeout dStopWithFlushRequestTimeout
    StopWithFlushEnableChain: entity work.DmaPortCommIfcComponentStateTransitionEnableChain (rtl)
      port map (
        aReset                          => aDiagramReset,                     -- in  bool
        ViClk                           => DefaultClk,                        -- in  std_
        BusClk                          => BusClk,                            -- in  std_
        bTransitionRequestStrobe        => bStopStreamWithFlushRequest,       -- out bool
        bTransitionTimeoutRequestStrobe => bFlushTimeoutRequest,              -- out bool
        vTransitionRequestStrobe        => dStopWithFlushRequestStrobe,       -- out bool
        vTransitionTimeoutRequestStrobe => open,                              -- out bool
        vTransitionComplete             => dStopWithFlushTransitionComplete,  -- in  bool
        vEnableIn                       => dStopWithFlushRequestEnableIn,     -- in  std_
        vEnableOut                      => dStopWithFlushRequestEnableOut,    -- out std_
        vEnableClear                    => dStopWithFlushRequestEnableClear,  -- in  std_
        vTimedOut                       => dStopWithFlushRequestTimedOut,     -- out std_
        vTimeout                        => dStopWithFlushRequestTimeout);     -- in  sign



    -------------------------------------------------------------------------------------
    -- Handshake the Stream State
    -------------------------------------------------------------------------------------

    -- Handshake the stream state to the DefaultClk domain.

    -- If the ViClk is different from the DefaultClk, then the stream state for the
    -- two clock domains will never be coherent, so generate a second handshake.
    GenDefaultStateCrossing: if not kViClkIsDefaultClk generate

      --vhook_e HandshakeSLV HandshakeStateToDefaultClkDomain
      --vhook_a aReset aDiagramReset
      --vhook_a kDataWidth bStreamState'length
      --vhook_a IClk BusClk
      --vhook_a iPush bPushStateToDefaultClkDomain
      --vhook_a iData bStreamState
      --vhook_a iReady bPushStateToDefaultClkDomain
      --vhook_a OClk DefaultClk
      --vhook_a oDataValid open
      --vhook_a oData dStreamStateValueFromController
      HandshakeStateToDefaultClkDomain: entity work.HandshakeSLV (struct)
        generic map (
          kDataWidth => bStreamState'length)  -- in  integer := 32
        port map (
          aReset     => aDiagramReset,                    -- in  boolean
          IClk       => BusClk,                           -- in  std_logic
          iPush      => bPushStateToDefaultClkDomain,     -- in  boolean
          iData      => bStreamState,                     -- in  std_logic_vector(kDataWi
          iReady     => bPushStateToDefaultClkDomain,     -- out boolean
          OClk       => DefaultClk,                       -- in  std_logic
          oDataValid => open,                             -- out boolean
          oData      => dStreamStateValueFromController); -- out std_logic_vector(kDataWi

    end generate GenDefaultStateCrossing;

    -- If the ViClk is the same as the DefaultClk, then the stream state for the
    -- two clock domains needs to be coherent.  We cannot use a separate handshake
    -- for this stream state, since the handshake would make the states incoherent.
    -- Therefore, just assign the state in the DefaultClk domain to the one from
    -- the ViClk domain.
    NoDefaultStateCrossing: if kViClkIsDefaultClk generate

      --vscan Begin Exception InputStreamStateClockCrossing
      --vscan # This assignment is safe because it is only done when the ViClk is the
      --vscan # same clock as the DefaultClk, so there is no clock crossing.
      --vscan Source Clock: DmaClkArray
      --vscan Destination Clock: DefaultClk
      --vscan Path: *[ChinchDmaInputFifoInterface]vStreamStateValueFromController*
      --vscan End Exception

      dStreamStateValueFromController <= vStreamStateValueFromController;

    end generate NoDefaultStateCrossing;

    dStreamStateFromController <= to_StreamState(dStreamStateValueFromController);

    -- Handshake the stream state from the default clock domain back to the BusClk
    -- domain.  This handshake requires the safe reset handshake because the request
    -- signal goes from the asynchronous diagram reset domain to the asynchronous bus
    -- reset domain.

    --vhook_e HandshakeBaseResetCross HandshakeStateToBusClkDomain
    --vhook_a kDataWidth dStreamStateValueFromController'length
    --vhook_a aResetToDlyPush open
    --vhook_a aResetToIResetFast open
    --vhook_a aPushToggleDly open
    --vhook_a aIReset aDiagramReset
    --vhook_a IClk DefaultClk
    --vhook_a iPush dPushStateToBusClkDomain
    --vhook_a iData dStreamStateValueFromController
    --vhook_a iStoredData open
    --vhook_a iReady dPushStateToBusClkDomain
    --vhook_a iOResetStatus open
    --vhook_a aOReset aBusReset
    --vhook_a OClk BusClk
    --vhook_a oDataValid open
    --vhook_a oDataAck true
    --vhook_a oData bStateInDefaultClkDomain
    HandshakeStateToBusClkDomain: entity work.HandshakeBaseResetCross (rtl)
      generic map (
        kDataWidth => dStreamStateValueFromController'length)  -- in  integer := 1
      port map (
        aResetToDlyPush    => open,                             -- in  integer := 0
        aResetToIResetFast => open,                             -- in  integer := 0
        aPushToggleDly     => open,                             -- in  integer := 0
        aIReset            => aDiagramReset,                    -- in  boolean
        IClk               => DefaultClk,                       -- in  std_logic
        iPush              => dPushStateToBusClkDomain,         -- in  boolean
        iData              => dStreamStateValueFromController,  -- in  std_logic_vector(k
        iStoredData        => open,                             -- out std_logic_vector(k
        iReady             => dPushStateToBusClkDomain,         -- out boolean := false
        iOResetStatus      => open,                             -- out boolean := false
        aOReset            => aBusReset,                        -- in  boolean
        OClk               => BusClk,                           -- in  std_logic
        oDataValid         => open,                             -- out boolean := false
        oDataAck           => true,                             -- in  boolean := true
        oData              => bStateInDefaultClkDomain);        -- out std_logic_vector(k


    -------------------------------------------------------------------------------------
    -- Stream State Latching Components
    -------------------------------------------------------------------------------------


    -- Track the state to report to the DefaultClk domain and ViClk domain.
    -- This component is used so that the state is immediately reported as
    -- flushing after a stop request is made before the actual state is reported as
    -- flushing.

    --vhook_e DmaPortCommIfcComponentInputStateHolder StateHolderForDefaultClkDomain
    --vhook_a aReset aDiagramReset
    --vhook_a ViClk DefaultClk
    --vhook_a vStreamStateOut dStreamState
    --vhook_a vStreamState dStreamStateFromController
    --vhook_a vStopRequest dStopRequest
    StateHolderForDefaultClkDomain: entity work.DmaPortCommIfcComponentInputStateHolder (rtl)
      port map (
        aReset          => aDiagramReset,               -- in  boolean
        ViClk           => DefaultClk,                  -- in  std_logic
        vStreamStateOut => dStreamState,                -- out StreamState_t
        vStreamState    => dStreamStateFromController,  -- in  StreamState_t
        vStopRequest    => dStopRequest);               -- in  boolean


    --vhook_e DmaPortCommIfcComponentInputStateHolder StateHolderForViClkDomain
    --vhook_a aReset aDiagramReset
    --vhook_a ViClk ViClk
    --vhook_a vStreamStateOut vStreamState
    --vhook_a vStreamState vStreamStateFromController
    --vhook_a vStopRequest vOverflowStopRequest
    StateHolderForViClkDomain: entity work.DmaPortCommIfcComponentInputStateHolder (rtl)
      port map (
        aReset          => aDiagramReset,               -- in  boolean
        ViClk           => ViClk,                       -- in  std_logic
        vStreamStateOut => vStreamState,                -- out StreamState_t
        vStreamState    => vStreamStateFromController,  -- in  StreamState_t
        vStopRequest    => vOverflowStopRequest);       -- in  boolean


    vStreamStateFromController <= to_StreamState(vStreamStateValueFromController);
    dStreamStateValue <= to_StreamStateValue(dStreamState);
    vStreamStateValue <= to_StreamStateValue(vStreamState);


    -------------------------------------------------------------------------------------
    -- Disable on Overflow
    -------------------------------------------------------------------------------------


    -- Stop the stream from the ViClk domain if an overflow occurs and disable on
    -- overflow is enabled.
    vOverflowStopRequest <= kDisableOnFifoTimeout and vStreamState = Enabled and
      to_Boolean(vFifoOverflow);

    -------------------------------------------------------------------------------------
    -- Handshake the overflow stop request to the BusClk domain.
    --
    -- This handshake requires the safe reset handshake because the request signal
    -- goes from the asynchronous diagram reset domain to the asynchronous bus reset
    -- domain.
    --
    --
    -- !ASSUMPTION!
    -- The iReady signal is ignored, which means that if a stream disables due to
    -- overflow and then re-enables before the handshake is ready, an overflow could
    -- potentially ignored.  I am making the assumption that this will not happen because
    -- the host is required to enable a stream, and this should be much slower than the
    -- time required to handshake the overflow stop request.
    -------------------------------------------------------------------------------------

    --vhook_e HandshakeBaseResetCross HandshakeOverflowStopRequest
    --vhook_a kDataWidth 2
    --vhook_a aResetToDlyPush open
    --vhook_a aResetToIResetFast open
    --vhook_a aPushToggleDly open
    --vhook_a aIReset aDiagramReset
    --vhook_a IClk ViClk
    --vhook_a iPush vOverflowStopRequest
    --vhook_a iData open
    --vhook_a iStoredData open
    --vhook_a iReady open
    --vhook_a iOResetStatus open
    --vhook_a aOReset aBusReset
    --vhook_a OClk BusClk
    --vhook_a oDataValid bOverflowStopRequest
    --vhook_a oDataAck true
    --vhook_a oData open
    HandshakeOverflowStopRequest: entity work.HandshakeBaseResetCross (rtl)
      generic map (
        kDataWidth => 2)  -- in  integer := 1
      port map (
        aResetToDlyPush    => open,                  -- in  integer := 0
        aResetToIResetFast => open,                  -- in  integer := 0
        aPushToggleDly     => open,                  -- in  integer := 0
        aIReset            => aDiagramReset,         -- in  boolean
        IClk               => ViClk,                 -- in  std_logic
        iPush              => vOverflowStopRequest,  -- in  boolean
        iData              => open,                  -- in  std_logic_vector(kDataWidth-1
        iStoredData        => open,                  -- out std_logic_vector(kDataWidth-1
        iReady             => open,                  -- out boolean := false
        iOResetStatus      => open,                  -- out boolean := false
        aOReset            => aBusReset,             -- in  boolean
        OClk               => BusClk,                -- in  std_logic
        oDataValid         => bOverflowStopRequest,  -- out boolean := false
        oDataAck           => true,                  -- in  boolean := true
        oData              => open);                 -- out std_logic_vector(kDataWidth-1

  end block StreamStateBlock;


  ---------------------------------------------------------------------------------------
  -- Overflow detector
  ---------------------------------------------------------------------------------------
  BlkOverflow: block
    signal vFifoOverflowStrobe, vHsModuleReady : boolean;
  begin

    -- Create the FIFO overflow strobe based on the overflow signal from
    -- the enable chain.  Qualify this with the HS ready signal so that a push is not
    -- sent while the HS module is in the middle of a previous HS.  This means that an
    -- overflow could be missed by the module, but this will only happen if the HS were
    -- already in the process of handshaking a previous overflow.  Since the overflow is
    -- setting an interrupt bit on the BusClk side, this is ok as long as the time
    -- between handshakes is less than the time for the host to receive and handle the
    -- interrupt.

    vFifoOverflowStrobe <= to_Boolean(vFifoOverflow) and vEnableOutLoc and
      vHsModuleReady;


    -- This handshake requires the safe reset handshake because the bFifoOverflow signal
    -- goes from the asynchronous diagram reset domain to the asynchronous bus reset
    -- domain. Even though the bFifoOverflow signal is quiesced during diagram reset,
    -- the handshake module is still unsafe since the data valid signal is an xor of
    -- two flip flops, which could be reset at different times and produce metastability
    -- on the data valid signal. Using the safe handshake prevents any metastability
    -- from propagating to the asynchronous bus reset domain.

    -- Set up the reset safe handshake equivalent to the HandshakeBool so that the
    -- true pulse is only seen for one clock cycle in the BusClk domain.

    --vhook_e HandshakeBaseResetCross HandshakeOverflow
    --vhook_a kDataWidth 2
    --vhook_a aResetToDlyPush open
    --vhook_a aResetToIResetFast open
    --vhook_a aPushToggleDly open
    --vhook_a aIReset aDiagramReset
    --vhook_a IClk ViClk
    --vhook_a iPush vFifoOverflowStrobe
    --vhook_a iData open
    --vhook_a iStoredData open
    --vhook_a iReady vHsModuleReady
    --vhook_a iOResetStatus open
    --vhook_a aOReset aBusReset
    --vhook_a OClk BusClk
    --vhook_a oDataValid bFifoOverflow
    --vhook_a oDataAck true
    --vhook_a oData open
    HandshakeOverflow: entity work.HandshakeBaseResetCross (rtl)
      generic map (
        kDataWidth => 2)  -- in  integer := 1
      port map (
        aResetToDlyPush    => open,                 -- in  integer := 0
        aResetToIResetFast => open,                 -- in  integer := 0
        aPushToggleDly     => open,                 -- in  integer := 0
        aIReset            => aDiagramReset,        -- in  boolean
        IClk               => ViClk,                -- in  std_logic
        iPush              => vFifoOverflowStrobe,  -- in  boolean
        iData              => open,                 -- in  std_logic_vector(kDataWidth-1 
        iStoredData        => open,                 -- out std_logic_vector(kDataWidth-1 
        iReady             => vHsModuleReady,       -- out boolean := false
        iOResetStatus      => open,                 -- out boolean := false
        aOReset            => aBusReset,            -- in  boolean
        OClk               => BusClk,               -- in  std_logic
        oDataValid         => bFifoOverflow,        -- out boolean := false
        oDataAck           => true,                 -- in  boolean := true
        oData              => open);                -- out std_logic_vector(kDataWidth-1 



  end block BlkOverflow;


end structure;
