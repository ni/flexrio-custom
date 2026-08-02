-------------------------------------------------------------------------------
--
-- File: NiSharedFifoReaderCore.vhd
-- Author: Matthew Koenn
-- Original Project: LabVIEW FPGA
-- Date: 12 June 2008
--
-------------------------------------------------------------------------------
-- (c) 2008 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--
--   This block implements the FIFO and VI interface for an output stream.  It
-- is intended to interface to the DmaPortCommIfcOutputStream (DMA controller)
-- on the BusClk side of the FIFO.
--
-- Enable chain logic has been removed; the signals formerly abstracted by
-- the enable chains (pop/read, reset, stream state queries, and
-- state transition requests) are now exposed directly on the entity ports.
--
-- Bogdan Popa - 09/09/2013
-- Added support for the Handshaking interface.
--
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;

  -- This pkg contains the definitions for the LabVIEW FPGA register
  -- framework signals
  use work.PkgCommunicationInterface.all;
  use work.PkgDmaPortCommunicationInterface.all;

  -- This pkg contains information regarding FIFO address width
  use work.PkgDmaPortDataPackingFifo.all;

  -- The pkg containing the definitions for the FIFO interface signals.
  use work.PkgDmaPortDmaFifos.all;

  -- The pkg containing stream state definitions.
  use work.PkgDmaPortCommIfcStreamStates.all;

  -- This package contains the definitions for the interface between the NI DMA IP and
  -- the application specific logic.
  use work.PkgNiDma.all;


entity NiSharedFifoReaderCore is
    generic(

      -- kFifoDepth      : This is the size of the DMA FIFO in bus data width words.
      kFifoDepth         : natural  := 1024;

      -- kSampleWidth    : This is the sample size of the data going to the
      --                   user VI.  This is used to set the FIFO data width
      --                   and the data width of corresponding signals.
      kSampleWidth       : positive := 32;

      -- kNumOfSamplesPerRead : This the number of samples that are read from the FIFO
      --                        at one time.
      kNumOfSamplesPerRead   : positive := 1;

      -- kFxpType        : This boolean indicates whether the data type is a
      --                   FXP type.
      kFxpType           : boolean  := false;

      -- kPeerToPeer     : This boolean indicates whether the stream is a normal
      --                   host to target stream or a peer-to-peer sink stream.
      kPeerToPeer        : boolean  := false;

      -- kDisableOnFifoTimeout  : This sets whether or not the stream disables when an
      --                          underflow occurs.
      kDisableOnFifoTimeout     : boolean

    );
    port(

      -- The asynchronous reset for the stream circuit
      aDiagramReset : in boolean;

      aBusReset : in boolean;

      -------------------------------------------------------------------------
      -- Clocks
      -------------------------------------------------------------------------

      -- The IO Port 2 transmit clock
      BusClk : in std_logic;

      -------------------------------------------------------------------------
      -- Communication Interface interface
      -------------------------------------------------------------------------

      -- The signals going from the communication interface to the FIFO.
      bOutputStreamInterfaceToFifo : in OutputStreamInterfaceToFifo_t;

      -- The signals going from the FIFO to the communication interface.
      bOutputStreamInterfaceFromFifo : out OutputStreamInterfaceFromFifo_t;

      -------------------------------------------------------------------------
      -- User VI interface for reading
      -------------------------------------------------------------------------

      -- ViClk       : The user VI clock for reading
      ViClk          : in std_logic;

      -- vDataOut    : The data going to the user VI from the FIFO.
      vDataOut       : out std_logic_vector(kSampleWidth*kNumOfSamplesPerRead-1 downto 0);

      -- vEmpty      : This indicates to the user VI when the FIFO is empty.
      vEmpty         : out boolean;

      -- Read control strobe
      vReadFifo      : in  boolean;

      -- vCtCount    : The current FIFO full count in the ViClk domain.
      vCtCount       : out unsigned(31 downto 0);

      -- Handshaking signals
      vOutputValid     : out boolean;
      vReadyForOutput  : in  boolean;

      -------------------------------------------------------------------------
      -- User VI interface for stream state info and transitioning
      -------------------------------------------------------------------------

      -- Stream state in the VI clock domain.
      vStreamStateOut : out StreamStateValue_t;

      -- State transition request signals
      vStartStreamRequest         : in  boolean;
      vStopRequestStrobe          : in  boolean

    );
end NiSharedFifoReaderCore;


architecture structure of NiSharedFifoReaderCore is

  -- The constant represents the sample width rounded up to the closer standard data type.
  constant kSampleSize : integer := ActualSampleSize (SampleSizeInBits => kSampleWidth,
                                                      PeerToPeer => kPeerToPeer,
                                                      FxpType => kFxpType);

  -- This is the width of the data read from the FIFO on the VI side.
  constant kRdPortWidth : integer := kSampleSize*kNumOfSamplesPerRead;

  -- Get the actual data width of the FIFO.
  constant kFifoDataWidth : positive := ActualFifoPortWidth (kRdPortWidth);

  -- The address width of the FIFO based on the depth of the FIFO in read data port words.
  constant kAddressWidth : integer := Log2(kFifoDepth);

  -- The count width, which is the address width with the sample size taken into account.
  constant kFifoCountWidth : integer := FifoCountWidth(SampleSize => kSampleSize,
                                                       AddressWidth => kAddressWidth);

  -- The correlated data consists of the stream state and the latch disabled bit.
  constant kCorrelatedDataWidth : integer := StreamStateValue_t'length + 1;
  constant kCorrelatedDataResetValue : std_logic_vector(kCorrelatedDataWidth-1
    downto 0) := to_StreamStateValue(Unlinked) & '0';

  constant kFifoDepthInSamples : natural := 2**kFifoCountWidth-1;

  constant kFifoPopBufferDepth : positive := 6*kNumOfSamplesPerRead;
  constant kRamReadLatency : positive := 2;
  constant kFifoAdditiveLatency : natural := 1;
 
  constant kTimeoutZero : std_logic_vector(31 downto 0) := (others => '0');

  signal vFifoData : std_logic_vector(kRdPortWidth-1 downto 0);
  signal vFifoDataResized : std_logic_vector(vDataOut'range);
  signal vBufferData : std_logic_vector(vDataOut'range);
  signal vEmptyFromBuffer : boolean;
  signal vFullCountFromFifo : unsigned(kFifoCountWidth-1 downto 0);
  signal bEmptyCount : unsigned(kFifoCountWidth-1 downto 0);
  signal bReqWriteSamples : unsigned(kFifoCountWidth-1 downto 0);
  signal bStreamState : StreamState_t;
  signal bStreamStateValue : StreamStateValue_t;
  signal vPopBufferFullCountOut : unsigned(Log2(kFifoPopBufferDepth +
    kFifoDepthInSamples + 1) - 1 downto 0);
  signal vCtCountLoc : unsigned(Log2(kFifoPopBufferDepth + kFifoDepthInSamples + 1) - 1
    downto 0);
  signal vStreamStateValueFromFifo : StreamStateValue_t;
  signal bStopStreamRequest, bReportDisabledToDiagram, vReportDisabledToDiagram :
    boolean;
  signal bStateInDefaultClkDomain : StreamStateValue_t;

  signal bByteEnable: NiDmaByteEnable_t;
  signal bDmaReset: boolean;
  signal bFifoData: NiDmaData_t;
  signal bFifoUnderflow: boolean;
  signal bFifoWrite: boolean;
  signal bPopBufferFullCountOut: std_logic_vector(vPopBufferFullCountOut'length-1 downto 0);
  signal bResetDone: boolean;
  signal bResetForFifo: boolean;
  signal bRsrvdSpacesFilled: boolean;
  signal bRsrvWriteSpaces: boolean;
  signal bStartStreamRequest: boolean;
  signal bStopStreamRequestFromDiagram: boolean;
  signal bUnderflowStopRequest: boolean;
  signal bWriteLengthInBytes: NiDmaBusByteCount_t;
  signal iCorrelatedDataIn: std_logic_vector(kCorrelatedDataWidth-1 downto 0);
  signal oCorrelatedDataOut: std_logic_vector(kCorrelatedDataWidth-1 downto 0);
  signal vDisable: boolean;
  signal vPopBuffer: boolean;
  signal vPopToFifo: boolean;
  signal vPushPop: boolean;
  signal vReady: boolean;
  signal vResetForFifo: boolean;
  signal vStreamStateDelayed: StreamState_t;
  signal vUnderflowStopRequest: boolean;
  signal vFifoUnderflow: std_logic;
  signal vFifoUnderflowFlag: std_logic;

  -- Registered version of bStateInDefaultClkDomain that bypasses the
  -- HandshakeBaseResetCross.  The handshake can produce 'X' in simulation
  -- when both reset domains release simultaneously, and once 'X' enters
  -- the toggle synchronizer chain it never clears.
  -- Since BusClk = ViClk in our design, we can safely register the
  -- ViClk-domain correlated-data output directly onto BusClk.  This is
  -- functionally equivalent to the handshake round-trip but without the
  -- simulation 'X' bug.
  signal bStateInDefaultClkDomainClean : std_logic_vector(bStreamStateValue'length-1 downto 0) := to_StreamStateValue(Unlinked);

  constant kDataZero : std_logic_vector(vDataOut'range) := (others=>'0');

begin

  ---------------------------------------------------------------------------
  -- Interface record decomposition (BusClk domain)
  ---------------------------------------------------------------------------
  bDmaReset <= bOutputStreamInterfaceToFifo.DmaReset;
  bFifoWrite <= bOutputStreamInterfaceToFifo.FifoWrite;
  bWriteLengthInBytes <= bOutputStreamInterfaceToFifo.WriteLengthInBytes;
  bFifoData <= bOutputStreamInterfaceToFifo.FifoData;
  bByteEnable <= bOutputStreamInterfaceToFifo.ByteEnable;
  bRsrvWriteSpaces <= bOutputStreamInterfaceToFifo.RsrvWriteSpaces;
  bReqWriteSamples <= resize(bOutputStreamInterfaceToFifo.NumWriteSpaces,
    bReqWriteSamples'length);
  bStreamState <= to_StreamState(bOutputStreamInterfaceToFifo.StreamState);
  bReportDisabledToDiagram <= bOutputStreamInterfaceToFifo.ReportDisabledToDiagram;

  bOutputStreamInterfaceFromFifo.ResetDone <= bResetDone;
  bOutputStreamInterfaceFromFifo.EmptyCount <= resize(bEmptyCount,
    bOutputStreamInterfaceFromFifo.EmptyCount'length);
  bOutputStreamInterfaceFromFifo.RsrvdSpacesFilled <= bRsrvdSpacesFilled;
  bOutputStreamInterfaceFromFifo.FifoUnderflow <= bFifoUnderflow;
  bOutputStreamInterfaceFromFifo.StartStreamRequest <= bStartStreamRequest;
  bOutputStreamInterfaceFromFifo.StopStreamRequest <= bStopStreamRequest;
  bOutputStreamInterfaceFromFifo.HostReadableFullCount <=
    resize(unsigned(bPopBufferFullCountOut),
    bOutputStreamInterfaceFromFifo.HostReadableFullCount'length);

  -- Use the cleaned clock crossing state instead of the raw handshake output.
  bOutputStreamInterfaceFromFifo.StateInDefaultClkDomain <= bStateInDefaultClkDomainClean;

  -- Bypass the HandshakeBaseResetCross for the state feedback path.
  -- Register the ViClk-domain stream state (from correlated-data FIFO) directly
  -- onto BusClk.  This works because BusClk and ViClk are the same clock in this design.
  CleanCdcState: process(aBusReset, BusClk)
  begin
    if aBusReset then
      bStateInDefaultClkDomainClean <= to_StreamStateValue(Unlinked);
    elsif rising_edge(BusClk) then
      bStateInDefaultClkDomainClean <= vStreamStateValueFromFifo;
    end if;
  end process;

  vCtCount <= resize(vCtCountLoc, vCtCount'length);
  vCtCountLoc <= vPopBufferFullCountOut;


  ---------------------------------------------------------------------------
  -- Enable Chain component (drives reset, disable, push/pop logic)
  ---------------------------------------------------------------------------
  DmaPortCommIfcComponentEnableChainx: entity work.DmaPortCommIfcComponentEnableChain (rtl)
    generic map (
      kInput       => false,                     -- output FIFO
      kSCL         => true,                      -- SCL mode for strobe interface
      kDataWidth   => kSampleWidth*kNumOfSamplesPerRead,
      kHandshaking => true)                      -- handshaking mode
    port map (
      aReset                     => aDiagramReset,
      PClk                       => ViClk,
      BusClk                     => BusClk,
      pEnableIn                  => vReadFifo,
      pEnableOut                 => open,
      pEnableClear               => false,
      pHandshakingPushPopRequest => vReadyForOutput,
      pPushPop                   => vPushPop,
      pDisable                   => vDisable,
      pResetForFifo              => vResetForFifo,
      bResetForFifo              => bResetForFifo,
      bResetBitFromRegister      => bDmaReset,
      bResetDone                 => bResetDone,
      pStateDisable              => false,
      pTimeout                   => kTimeoutZero,
      pDataOut                   => vDataOut,
      pFlag                      => vFifoUnderflowFlag,
      pDataOutFromFifo           => vBufferData,
      pFlagFromFifo              => to_StdLogic(vEmptyFromBuffer));


  ---------------------------------------------------------------------------
  -- Pop buffer (ViClk domain read-side buffering)
  ---------------------------------------------------------------------------
  NiFpgaFifoPopBufferx: entity work.NiFpgaFifoPopBuffer (rtl)
    generic map (
      kElementWidth        => kSampleWidth,
      kNumOfElements       => kNumOfSamplesPerRead,
      kFifoDepth           => kFifoDepthInSamples,
      kBufferDepth         => kFifoPopBufferDepth,
      kRamReadLatency      => kRamReadLatency,
      kFifoAdditiveLatency => kFifoAdditiveLatency,
      kPopThreshold        => 1,
      kGenerateCounts      => true)
    port map (
      Clk                => ViClk,
      aReset             => aDiagramReset,
      cReset             => vResetForFifo,
      cPopToFifo         => vPopToFifo,
      cDataFromFifo      => vFifoDataResized,
      cFullCountFromFifo => vFullCountFromFifo,
      cPop               => vPopBuffer,
      cDisablePop        => vDisable,
      cDataOut           => vBufferData,
      cEmpty             => vEmptyFromBuffer,
      cFullCount         => vPopBufferFullCountOut,
      cPopFlag           => open);

  vPopBuffer <= vPushPop and not vEmptyFromBuffer;


  -- Resize the data from the FIFO to match the VI data size.
  -- Swap the samples order in a read data port for the multi element read case.
  DataReadResize: process (vFifoData)
  begin
    for i in 0 to kNumOfSamplesPerRead-1 loop
        vFifoDataResized((kNumOfSamplesPerRead-i)*kSampleWidth-1 downto
        (kNumOfSamplesPerRead-i-1)*kSampleWidth) <= std_logic_vector(resize(
            unsigned(vFifoData((i+1)*kSampleSize-1 downto i*kSampleSize)), kSampleWidth));
    end loop;
  end process;

  iCorrelatedDataIn <= bStreamStateValue & to_StdLogic(bReportDisabledToDiagram);
  vStreamStateValueFromFifo <= oCorrelatedDataOut(2 downto 1);
  vReportDisabledToDiagram <= to_Boolean(oCorrelatedDataOut(0));


  ---------------------------------------------------------------------------
  -- Output stream FIFO (BusClk write side, ViClk read side)
  ---------------------------------------------------------------------------
  DmaPortOutStrmFifox: entity work.DmaPortOutStrmFifo (rtl)
    generic map (
      kAddressWidth             => kAddressWidth,
      kSampleSize               => kSampleSize,
      kNumOfSamplesPerRead      => kNumOfSamplesPerRead,
      kRdPortWidth              => kRdPortWidth,
      kFifoCountWidth           => kFifoCountWidth,
      kCorrelatedDataWidth      => kCorrelatedDataWidth,
      kCorrelatedDataResetValue => kCorrelatedDataResetValue)
    port map (
      aReset              => aDiagramReset,
      IClk                => BusClk,
      iReset              => bResetForFifo,
      iWrite              => bFifoWrite,
      iWriteEnables       => bByteEnable,
      iWriteLengthInBytes => bWriteLengthInBytes,
      iDataIn             => bFifoData,
      iCorrelatedDataIn   => iCorrelatedDataIn,
      iEmptyCount         => bEmptyCount,
      iRsrvWriteSpaces    => bRsrvWriteSpaces,
      iReqWriteSpaces     => bReqWriteSamples,
      iRsrvdSpacesFilled  => bRsrvdSpacesFilled,
      OClk                => ViClk,
      oReset              => vResetForFifo,
      oRead               => vPopToFifo,
      oDataOut            => vFifoData,
      oCorrelatedDataOut  => oCorrelatedDataOut,
      oFullCount          => vFullCountFromFifo);


  ---------------------------------------------------------------------------
  -- Empty/underflow and handshaking (ViClk domain)
  ---------------------------------------------------------------------------
  vEmpty <= to_boolean(vFifoUnderflowFlag);

  -- In case of Handshaking report the underflow condition only when vReadyForOutput
  -- is asserted while the FIFO is empty.
  vFifoUnderflow <= to_stdlogic(to_boolean(vFifoUnderflowFlag) and vReadyForOutput);

  -- Output valid: data is valid when FIFO is not empty and a pop has been requested.
  vOutputValid <= not (to_boolean(vFifoUnderflowFlag)) and vPushPop;


  ---------------------------------------------------------------------------------------
  -- Stream State Components
  ---------------------------------------------------------------------------------------
  StreamStateBlock: block

    type StreamStateValueArray_t is array (natural range <>) of StreamStateValue_t;

    signal vStreamState : StreamState_t;
    signal vStreamStateValue, vStreamStateValueDelayed : StreamStateValue_t;
    signal vStreamStateValueDelays : StreamStateValueArray_t(kRamReadLatency-1 downto 0);
    signal vStopRequest : boolean;
    signal vStopRequestStrobeLocal : boolean;

  begin

    -------------------------------------------------------------------------------------
    -- Stream State from correlated data
    -------------------------------------------------------------------------------------

    bStreamStateValue <= to_StreamStateValue(bStreamState);


    -------------------------------------------------------------------------------------
    -- Handshake strobe signals from ViClk domain to BusClk domain
    -------------------------------------------------------------------------------------

    HandshakeStopStreamRequest: entity work.HandshakeBool (struct)
      port map (
        aReset => aDiagramReset,
        IClk   => ViClk,
        iSig   => vStopRequestStrobe,
        iReady => open,
        OClk   => BusClk,
        oSig   => bStopStreamRequestFromDiagram);

    HandshakeStartStreamRequest: entity work.HandshakeBool (struct)
      port map (
        aReset => aDiagramReset,
        IClk   => ViClk,
        iSig   => vStartStreamRequest,
        iReady => open,
        OClk   => BusClk,
        oSig   => bStartStreamRequest);


    -------------------------------------------------------------------------------------
    -- Stream State Outputs (enable chains removed, directly driven)
    -------------------------------------------------------------------------------------

    vStreamStateOut <= vStreamStateValue;


    -------------------------------------------------------------------------------------
    -- State Holder Component
    -------------------------------------------------------------------------------------

    -- Track the state to report to the ViClk domain.  This component
    -- is used so that the state is immediately reported as disabled after a stop
    -- request is made before the actual state is reported as disabled.
    ViClkStateHolder: entity work.DmaPortCommIfcComponentOutputStateHolder (rtl)
      port map (
        aReset          => aDiagramReset,
        ViClk           => ViClk,
        vStreamStateOut => vStreamState,
        vStreamState    => vStreamStateDelayed,
        vStopRequest    => vStopRequest);


    -- Latch the disabled state when there is a diagram stop request or when the state
    -- controller indicates that the host has issued a stop request.
    vStopRequest <= vStopRequestStrobeLocal or vReportDisabledToDiagram;

    -- The stop request strobe combines the user's vStopRequestStrobe port input
    -- and the underflow stop detection.
    vStopRequestStrobeLocal <= vStopRequestStrobe or vUnderflowStopRequest;


    -------------------------------------------------------------------------------------
    -- Request Strobes
    -------------------------------------------------------------------------------------

    -- Stop the stream from the ViClk domain if an underflow occurs and disable on
    -- underflow is enabled.
    vUnderflowStopRequest <= kDisableOnFifoTimeout and vFifoUnderflow='1' and
      vStreamState = Enabled;

    bStopStreamRequest <= bStopStreamRequestFromDiagram or bUnderflowStopRequest;

    -------------------------------------------------------------------------------------
    -- Handshake the underflow stop request to the BusClk domain.
    -------------------------------------------------------------------------------------

    HandshakeUnderflowStopRequest: entity work.HandshakeBaseResetCross (rtl)
      generic map (
        kDataWidth => 2)
      port map (
        aResetToDlyPush    => open,
        aResetToIResetFast => open,
        aPushToggleDly     => open,
        aIReset            => aDiagramReset,
        IClk               => ViClk,
        iPush              => vUnderflowStopRequest,
        iData              => open,
        iStoredData        => open,
        iReady             => open,
        iOResetStatus      => open,
        aOReset            => aBusReset,
        OClk               => BusClk,
        oDataValid         => bUnderflowStopRequest,
        oDataAck           => true,
        oData              => open);


    -------------------------------------------------------------------------------------
    -- Stream state delay pipeline
    --
    -- The stream state is transferred from the BusClk domain to the ViClk domain through
    -- the correlated data part of the FIFO.  This is done so that the stream state will
    -- never be visible to the user before the updated FIFO count.  This is important
    -- because otherwise the user could see the channel transition to the Disabled state
    -- while the FIFO count is zero, even though more data could still be in the FIFO
    -- that has not yet made it to the user's domain.  Then, the user could assume the
    -- channel stopped and all data had been received when it really hadn't.
    --
    -- In order to fully ensure that the state gets reflected in the user domain no
    -- sooner than the FIFO count, we have to account for the delay from the FIFO pop
    -- buffer.  Therefore, the stream state should be delayed by kRamReadLatency
    -- additional clock cycles.
    -------------------------------------------------------------------------------------

    DelayViClkStreamState: for i in kRamReadLatency-1 downto 0 generate
      process(aDiagramReset, ViClk)
      begin
        if aDiagramReset then
          vStreamStateValueDelays(i) <= to_StreamStateValue(Unlinked);
        elsif rising_edge(ViClk) then
          if vResetForFifo then
            vStreamStateValueDelays(i) <= to_StreamStateValue(Unlinked);
          else
            if i = 0 then
              vStreamStateValueDelays(i) <= vStreamStateValueFromFifo;
            else
              vStreamStateValueDelays(i) <= vStreamStateValueDelays(i-1);
            end if;
          end if;
        end if;
      end process;
    end generate DelayViClkStreamState;

    vStreamStateValueDelayed <= vStreamStateValueDelays(kRamReadLatency-1);
    vStreamStateDelayed <= to_StreamState(vStreamStateValueDelayed);

    vStreamStateValue <= to_StreamStateValue(vStreamState);


  end block StreamStateBlock;


  ---------------------------------------------------------------------------------------
  -- Underflow detector
  ---------------------------------------------------------------------------------------
  BlkUnderflow: block
    signal vFifoUnderflowStrobe, vHsModuleReady : boolean;
  begin

    -- Create the FIFO underflow strobe based on the underflow signal.
    -- Qualify this with the HS ready signal so that a push is not
    -- sent while the HS module is in the middle of a previous HS.  This means that an
    -- underflow could be missed by the module, but this will only happen if the HS were
    -- already in the process of handshaking a previous underflow.  Since the underflow
    -- is setting an interrupt bit on the BusClk side, this is ok as long as the time
    -- between handshakes is less than the time for the host to receive and handle the
    -- interrupt.

    vFifoUnderflowStrobe <= to_Boolean(vFifoUnderflow) and vPushPop and vHsModuleReady;

    HandshakeUnderflow: entity work.HandshakeBaseResetCross (rtl)
      generic map (
        kDataWidth => 2)
      port map (
        aResetToDlyPush    => open,
        aResetToIResetFast => open,
        aPushToggleDly     => open,
        aIReset            => aDiagramReset,
        IClk               => ViClk,
        iPush              => vFifoUnderflowStrobe,
        iData              => open,
        iStoredData        => open,
        iReady             => vHsModuleReady,
        iOResetStatus      => open,
        aOReset            => aBusReset,
        OClk               => BusClk,
        oDataValid         => bFifoUnderflow,
        oDataAck           => true,
        oData              => open);

  end block BlkUnderflow;


  ---------------------------------------------------------------------------
  -- Handshake the pop buffer full count to the BusClk domain
  ---------------------------------------------------------------------------

  -- The full count is used on the BusClk domain to allow the host to read the full
  -- count.  This can't be done with the empty count from the FIFO because the empty
  -- count doesn't take into account the elements in the pop buffer.

  HandshakeFullCount: entity work.HandshakeBaseResetCross (rtl)
    generic map (
      kDataWidth => vPopBufferFullCountOut'length)
    port map (
      aResetToDlyPush    => open,
      aResetToIResetFast => open,
      aPushToggleDly     => open,
      aIReset            => aDiagramReset,
      IClk               => ViClk,
      iPush              => vReady,
      iData              => std_logic_vector(vPopBufferFullCountOut),
      iStoredData        => open,
      iReady             => vReady,
      iOResetStatus      => open,
      aOReset            => aBusReset,
      OClk               => BusClk,
      oDataValid         => open,
      oDataAck           => true,
      oData              => bPopBufferFullCountOut);


end structure;
