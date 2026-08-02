-------------------------------------------------------------------------------
--
-- File: NiSharedFifoWriterCore.vhd
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
-- interface.  The module consists of an input FIFO, stream state management,
-- and some interconnect between them.
--
-- Enable chain logic has been removed; the signals formerly abstracted by
-- the enable chains (push/pop, reset, flush, stream state queries, and
-- state transition requests) are now exposed directly on the entity ports.
--
-- Bogdan Popa - 09/09/2013
-- Added support for the Handshaking interface.
--
-- Harmish - 08/04/2014 - Added support for Flush method.
-- * vFlush strobe drives the Flush logic in DmaPortInStrmFifo.
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


entity NiSharedFifoWriterCore is
    generic(

      -- kFifoDepth      : This is the size of the DMA FIFO in terms of bus data width
      --                   words.
      kFifoDepth         : natural  := 1024;

      -- kSampleWidth     : This is the width of one sample coming from the user VI.
      kSampleWidth        : positive := 32;

      -- kNumOfSamplesPerWrite : This the number of samples that are written in the FIFO
      --                    at one time;
      kNumOfSamplesPerWrite    : positive := 1;

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
      kDisableOnFifoTimeout     : boolean

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
      vFull          : out boolean;

      -- Write control 
      vWriteFifo       : in  boolean;

      -- Flush strobe
      vFlush             : in  boolean;

      -- vCtCount     : The current FIFO empty count in the ViClk domain.
      vCtCount        : out unsigned(31 downto 0);

      -- Handshaking signals
      vInputValid            : in  boolean;
      vReadyForInput         : out boolean;

      -------------------------------------------------------------------------
      -- User VI interface for stream state info and transitioning
      -------------------------------------------------------------------------

      -- Stream state in the VI clock domain.
      vStreamStateOut : out StreamStateValue_t;

      -- State transition request signals 
      vStartStreamRequest           : in  boolean;
      vStopRequestStrobe            : in  boolean;
      vFlushTimeoutRequest          : in  boolean;
      vStopWithFlushRequestStrobe   : in  boolean

    );
end NiSharedFifoWriterCore;


architecture structure of NiSharedFifoWriterCore is

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

  constant kTimeoutZero : std_logic_vector(31 downto 0) := (others => '0');

  -- The count width, which is the address width with the sample size taken into account.
  constant kFifoCountWidth : integer := FifoCountWidth(SampleSize => kSampleSize,
                                                       AddressWidth => kAddressWidth);


  signal vFullFromFifo: boolean;
  signal vEmptyCount, vEmptyCountLoc: unsigned(kFifoCountWidth-1 downto 0);
  signal bFifoFullCount: unsigned(kFifoCountWidth-1 downto 0);
  signal bStreamState : StreamStateValue_t;
  signal vFifoOverflow : std_logic;
  signal vFifoOverflowFlag : std_logic;
  signal bStateInViClkDomain : StreamStateValue_t;
  signal vWritesDisabled, vWritesDisabledForController : boolean;
  signal bWritesDisabled : boolean;
  signal bTransferEnd: boolean;
  signal bPop, bPopFifo: boolean;
  signal bByteEnableDirect: NiDmaByteEnable_t;
  signal bStartStreamRequest : boolean;

  signal vStopRequest : boolean;

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
  signal vOverflowStopRequest: boolean;
  signal vPush: boolean;
  signal vPushPop: boolean;
  signal vResetForFifo: boolean;
  signal vStateDisable: boolean;
  signal vStreamState: StreamState_t;
  signal vStreamStateFromController: StreamState_t;
  signal vStreamStateValueFromControllerEarly: std_logic_vector(bStreamState'length-1 downto 0) := to_StreamStateValue(Unlinked);
  --vhook_sigend
  
  signal vStreamStateValueFromController: std_logic_vector(bStreamState'length-1 downto 0);
  signal vStreamStateValueFromControllerDly: std_logic_vector(bStreamState'length-1 downto 0) := to_StreamStateValue(Unlinked);
  signal vDisableEarly : boolean;
  
  signal vAlmostFull        : boolean;
  signal vInputValidQual    : boolean;
  signal vReadyForInputBool : boolean;
  signal vReadyForInputReg  : boolean := true;
  
  
  signal bFlushReqFifo : std_logic;


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
  bInputStreamInterfaceFromFifo.FifoFullCount <= resize(bFifoFullCount, bInputStreamInterfaceFromFifo.FifoFullCount'length);
  bInputStreamInterfaceFromFifo.FifoOverflow <= bFifoOverflow;
  bInputStreamInterfaceFromFifo.StartStreamRequest <= bStartStreamRequest;
  bInputStreamInterfaceFromFifo.StopStreamRequest <= bStopStreamRequestFromDiagram or bFlushTimeoutRequest;
  bInputStreamInterfaceFromFifo.StopStreamWithFlushRequest <= bStopStreamWithFlushRequest or bOverflowStopRequest;
  bInputStreamInterfaceFromFifo.FlushRequest <= to_Boolean(bFlushReqFifo);
  bInputStreamInterfaceFromFifo.WritesDisabled <= bWritesDisabled;
  bInputStreamInterfaceFromFifo.WriteDetected <= bWriteDetected;

  -- Cross the ViClk-domain stream state back to BusClk via the
  -- HandshakeBaseResetCross (HandshakeStateToBusClkDomain).
  bInputStreamInterfaceFromFifo.StateInDefaultClkDomain <= bStateInViClkDomain;
  
  bPopFifo <= bPop and ((not bTransferEnd) or bByteEnableDirect(bByteEnableDirect'left));

  DmaPortCommIfcComponentEnableChainx: entity work.DmaPortCommIfcComponentEnableChain (rtl)
  generic map (
    kInput       => true,
    kSCL         => true,
    kDataWidth   => kWrPortWidth,
    kHandshaking => true)
  port map (
    aReset                     => aDiagramReset,
    PClk                       => ViClk,
    BusClk                     => BusClk,
    pEnableIn                  => vWriteFifo,
    pEnableOut                 => open,
    pEnableClear               => false,
    pHandshakingPushPopRequest => vInputValidQual,
    pPushPop                   => vPushPop,
    pDisable                   => vDisable,
    pResetForFifo              => vResetForFifo,
    bResetForFifo              => bResetForFifo,
    bResetBitFromRegister      => bDmaReset,
    bResetDone                 => bResetDone,
    pStateDisable              => vStateDisable,
    pTimeout                   => kTimeoutZero,
    pDataOut                   => open,
    pFlag                      => vFifoOverflowFlag,
    pDataOutFromFifo           => kDataZero,
    pFlagFromFifo              => to_StdLogic(vFullFromFifo));


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
      
  WritesDisabledDelayed:if kPeerToPeer generate        
    StreamStateFlop: process (aDiagramReset, ViClk)
    begin
      if aDiagramReset then
        vStreamStateValueFromControllerDly <= to_StreamStateValue(Unlinked);
      elsif rising_edge(ViClk) then
        vStreamStateValueFromControllerDly <= vStreamStateValueFromControllerEarly;
      end if;
    end process;
  end generate WritesDisabledDelayed;
      
  vStreamStateValueFromController <= vStreamStateValueFromControllerDly when kPeerToPeer else
                                    vStreamStateValueFromControllerEarly;
      

  -- Report the number of elements available for writing as zero if it is a peer-to-peer
  -- stream and the stream is not enabled.
  vEmptyCount <= vEmptyCountLoc when not vStateDisable else
                 (others=>'0');

  vCtCount <= resize(vEmptyCount, vCtCount'length);

  -- Do not allow a push to occur when the FIFO is full.  This will prevent
  -- any overflows from occuring.
  vPush <= vPushPop and not vFullFromFifo;

  -- The FIFO is full whenever the empty count is zero.
  vFullFromFifo <= vEmptyCount < kNumOfSamplesPerWrite;
  vFull <= to_boolean(vFifoOverflowFlag);

  -- In case of Handshaking report the overflow condition only when the vInputValid is asserted
  -- while the FIFO is full.
  vFifoOverflow <= to_stdlogic(to_boolean(vFifoOverflowFlag) and vInputValid);
  
  ---------------------------------------------------------------------------------------
  -- Handshaking interface 
  --------------------------------------------------------------------------------------  
  -- This flag asserts when only one write operation can be performed
  -- The number of empty slots must be greater or equal than the amount written 
  -- in one transaction, but smaller than two write transactions 
  vAlmostFull <= (vEmptyCount >= kNumOfSamplesPerWrite) and (vEmptyCount < (2*kNumOfSamplesPerWrite));
  
  -- This flag is qualified with registered Ready For Input, because the 4-wire
  -- protocol explicitly states that Input Valid can only assert if Ready For Input was 
  -- asserted in the previous cycle. This behavior must be ensured by the upstream component,
  -- but we are making sure that it's correct by qualifying Input Valid here, also.
  vInputValidQual <= vInputValid and vReadyForInputReg;
  
  -- Added vDisableEarly for the P2P case using Handshaking
  -- This disables vReadyForInputBool one cycle earlier, thus stopping the pushes as soon
  -- as Flushing or Disable state begins. In Flushing or Disable, the FIFO will not accept any data, so
  -- we must alert the user one cycle earlier, since iReadyForInput indicates the readiness of the FIFO on
  -- the next cycle.
  vReadyForInputBool <= not (vFullFromFifo or (vAlmostFull and vPushPop) or vDisable or vDisableEarly);
  
  vReadyForInput <= vReadyForInputBool;
  
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
  


  ---------------------------------------------------------------------------------------
  -- Stream State Components
  ---------------------------------------------------------------------------------------
  StreamStateBlock: block

    signal vStreamStateValue : StreamStateValue_t;
    signal vStreamState, vStreamStateFromController : StreamState_t;
    signal bPushStateToViClkDomain : boolean;

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
                      when kPeerToPeer else false;
                      
    -- For VI clock domain state reporting
    vStopRequest <= vStopWithFlushRequestStrobe or vStopRequestStrobe or vOverflowStopRequest;

    -- Handshake strobe signals from ViClk domain to BusClk domain.

    HandshakeStopStreamRequest: entity work.HandshakeBool (struct)
      port map (
        aReset => aDiagramReset,
        IClk   => ViClk,
        iSig   => vStopRequestStrobe,
        iReady => open,
        OClk   => BusClk,
        oSig   => bStopStreamRequestFromDiagram);

    HandshakeStopWithFlushRequest: entity work.HandshakeBool (struct)
      port map (
        aReset => aDiagramReset,
        IClk   => ViClk,
        iSig   => vStopWithFlushRequestStrobe,
        iReady => open,
        OClk   => BusClk,
        oSig   => bStopStreamWithFlushRequest);

    HandshakeStartStreamRequest: entity work.HandshakeBool (struct)
      port map (
        aReset => aDiagramReset,
        IClk   => ViClk,
        iSig   => vStartStreamRequest,
        iReady => open,
        OClk   => BusClk,
        oSig   => bStartStreamRequest);

    HandshakeFlushTimeoutRequest: entity work.HandshakeBool (struct)
      port map (
        aReset => aDiagramReset,
        IClk   => ViClk,
        iSig   => vFlushTimeoutRequest,
        iReady => open,
        OClk   => BusClk,
        oSig   => bFlushTimeoutRequest);


    -------------------------------------------------------------------------------------
    -- Stream State Outputs (enable chains removed, directly driven)
    -------------------------------------------------------------------------------------

    vStreamStateOut <= vStreamStateValue;


    -------------------------------------------------------------------------------------
    -- Handshake the Stream State
    -------------------------------------------------------------------------------------

    vStreamStateFromController <= to_StreamState(vStreamStateValueFromController);

    -- Handshake the stream state from the default clock domain back to the BusClk
    -- domain.  This handshake requires the safe reset handshake because the request
    -- signal goes from the asynchronous diagram reset domain to the asynchronous bus
    -- reset domain.

    --vhook_e HandshakeBaseResetCross HandshakeStateToBusClkDomain
    --vhook_a kDataWidth vStreamStateValueFromController'length
    --vhook_a aResetToDlyPush open
    --vhook_a aResetToIResetFast open
    --vhook_a aPushToggleDly open
    --vhook_a aIReset aDiagramReset
    --vhook_a IClk ViClk
    --vhook_a iPush dPushStateToBusClkDomain
    --vhook_a iData vStreamStateValueFromController
    --vhook_a iStoredData open
    --vhook_a iReady dPushStateToBusClkDomain
    --vhook_a iOResetStatus open
    --vhook_a aOReset aBusReset
    --vhook_a OClk BusClk
    --vhook_a oDataValid open
    --vhook_a oDataAck true
    --vhook_a oData bStateInViClkDomain
    HandshakeStateToBusClkDomain: entity work.HandshakeBaseResetCross (rtl)
      generic map (
        kDataWidth => vStreamStateValueFromController'length)  -- in  integer := 1
      port map (
        aResetToDlyPush    => open,                             -- in  integer := 0
        aResetToIResetFast => open,                             -- in  integer := 0
        aPushToggleDly     => open,                             -- in  integer := 0
        aIReset            => aDiagramReset,                    -- in  boolean
        IClk               => ViClk,                       -- in  std_logic
        iPush              => dPushStateToBusClkDomain,         -- in  boolean
        iData              => vStreamStateValueFromController,  -- in  std_logic_vector(k
        iStoredData        => open,                             -- out std_logic_vector(k
        iReady             => dPushStateToBusClkDomain,         -- out boolean := false
        iOResetStatus      => open,                             -- out boolean := false
        aOReset            => aBusReset,                        -- in  boolean
        OClk               => BusClk,                           -- in  std_logic
        oDataValid         => open,                             -- out boolean := false
        oDataAck           => true,                             -- in  boolean := true
        oData              => bStateInViClkDomain);        -- out std_logic_vector(k


    -------------------------------------------------------------------------------------
    -- Stream State Latching Components
    -------------------------------------------------------------------------------------


    -- Track the state to report to the ViClk domain and ViClk domain.
    -- This component is used so that the state is immediately reported as
    -- flushing after a stop request is made before the actual state is reported as
    -- flushing.

    --vhook_e DmaPortCommIfcComponentInputStateHolder StateHolderForViClkDomain
    --vhook_a aReset aDiagramReset
    --vhook_a ViClk ViClk
    --vhook_a vStreamStateOut vStreamState
    --vhook_a vStreamState vStreamStateFromController
    --vhook_a vStopRequest vStopRequest
    StateHolderForViClkDomain: entity work.DmaPortCommIfcComponentInputStateHolder (rtl)
      port map (
        aReset          => aDiagramReset,               -- in  boolean
        ViClk           => ViClk,                  -- in  std_logic
        vStreamStateOut => vStreamState,                -- out StreamState_t
        vStreamState    => vStreamStateFromController,  -- in  StreamState_t
        vStopRequest    => vStopRequest);               -- in  boolean


    vStreamStateValue <= to_StreamStateValue(vStreamState);


    -------------------------------------------------------------------------------------
    -- Disable on Overflow
    -------------------------------------------------------------------------------------


    -- Stop the stream from the ViClk domain if an overflow occurs and disable on
    -- overflow is enabled.
    vOverflowStopRequest <= kDisableOnFifoTimeout and vStreamState = Enabled and to_Boolean(vFifoOverflow);

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

    -- Create the FIFO overflow strobe based on the overflow signal.
    -- Qualify this with the HS ready signal so that a push is not
    -- sent while the HS module is in the middle of a previous HS.  This means that an
    -- overflow could be missed by the module, but this will only happen if the HS were
    -- already in the process of handshaking a previous overflow.  Since the overflow is
    -- setting an interrupt bit on the BusClk side, this is ok as long as the time
    -- between handshakes is less than the time for the host to receive and handle the
    -- interrupt.

    vFifoOverflowStrobe <= to_Boolean(vFifoOverflow) and vPushPop and vHsModuleReady;


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
