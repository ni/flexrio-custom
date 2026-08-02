-------------------------------------------------------------------------------
--
-- File: PeleDmaOutputFifoInterface.vhd
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
-- is intended to interface to the Chinch communication interface on the
-- BusClk side of the FIFO.
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

  use work.PkgNiDma.all;
  use work.PkgNiDmaConfig.all;

entity DmaPortCommIfcOutputFifoInterface is
    generic(

      -- kFifoDepth      : This is the size of the DMA FIFO in bus data width words.
      kFifoDepth         : natural  := 1024;

      -- kSampleWidth    : This is the sample size of the data going to the
      --                   user VI.  This is used to set the FIFO data width
      --                   and the data width of corresponding signals.
      kSampleWidth       : positive := 32;

      --kNumOfSamplesPerRead : This the number of samples that are read from the FIFO
      --                       at one time;
      kNumOfSamplesPerRead   : positive := 1;

      -- kFxpType        : This boolean indicates whether the data type is a
      --                   FXP type.
      kFxpType           : boolean  := false;

      -- kScl            : This boolean controls whether or not the DMA channel
      --                   is located in a single cycle loop.  This is used to
      --                   control how the enable chain with the user VI
      --                   operates.
      kScl               : boolean  := false;

      -- kCountScl       : This boolean controls whether or not the query FIFO
      --                   count method is in a single cycle loop.
      kCountScl          : boolean  := false;

      -- kPeerToPeer     : This boolean indicates whether the stream is a normal
      --                   target to host stream or a peer-to-peer source stream.
      kPeerToPeer        : boolean  := false;

      -- kDisableOnFifoTimeout  : This sets whether or not the stream disables when an
      --                          overflow/underflow occurs.
      kDisableOnFifoTimeout     : boolean;

      -- kViClkIsDefaultClk     : This bit is set when the DMA clock (or VI clock) is
      --                          the same clock as the default clock.
      kViClkIsDefaultClk        : boolean;
      
      -- kReadUsingHandshaking  : This boolean indicates the interface of the FIFO,
      --                          Timeout or Handshaking.
      kReadUsingHandshaking     : boolean := false

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

      -- The user VI clock
      ViClk  : in std_logic;

      -------------------------------------------------------------------------
      -- Communication Interface interface
      -------------------------------------------------------------------------

      -- The signals going from the communication interface to the FIFO.
      bOutputStreamInterfaceToFifo : in OutputStreamInterfaceToFifo_t;

      -- The signals going from the FIFO to the communication interface.
      bOutputStreamInterfaceFromFifo : out OutputStreamInterfaceFromFifo_t;

      -------------------------------------------------------------------------
      -- User VI interface
      -------------------------------------------------------------------------

      -- vDataOut    : The data going to the user VI.
      vDataOut       : out std_logic_vector(kSampleWidth*kNumOfSamplesPerRead-1 downto 0);

      -- vEmpty          : This indicates to the user VI when the FIFO is
      --                   empty.
      vEmpty             : out std_logic;

      -- vTimeout        : This is the number of ViClk cycles to wait to
      --                   pop data from the FIFO in the case that the
      --                   FIFO is empty.  If the timeout is reached before
      --                   there is data available in the FIFO, the user
      --                   VI receives the EnableOut signal, but the data
      --                   has not been popped.
      vTimeout           : in  std_logic_vector(31 downto 0);

      -- vEnableIn       : This is the signal from the user VI indicating
      --                   that he wishes to perform a pop.
      vEnableIn          : in  std_logic;

      -- vEnableOut      : This is the signal to the user VI indicating
      --                   that the pop has occurred or timeout has
      --                   occurred.  This stays asserted until the VI
      --                   asserts EnableClear.
      vEnableOut         : out std_logic;

      -- vEnableClear    : This is the signal from the user VI to clear the
      --                   EnableOut signal and indicate that EnableIn
      --                   should be re-processed.
      vEnableClear       : in  std_logic;

      -- vCtCount        : The current FIFO full count in the ViClk domain.
      vCtCount           : out unsigned(31 downto 0);

      -- Enable chain for the full count.
      vCtEnableIn        : in  std_logic;
      vCtEnableOut       : out std_logic;
      vCtEnableOutClear  : in  std_logic;
      
      -- Handshaking signals
      vOutputValid       : out std_logic;
      vReadyForOutput    : in  std_logic;

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
      dStopRequestEnableClear : in std_logic

    );
end DmaPortCommIfcOutputFifoInterface;


architecture structure of DmaPortCommIfcOutputFifoInterface is

  -- The constant represents the sample width rounded up to the closer standard data type.
  constant kSampleSize : integer := ActualSampleSize (SampleSizeInBits => kSampleWidth,
                                                      PeerToPeer => kPeerToPeer,
                                                      FxpType => kFxpType);

  -- This is the width of the data read from the FIFO on the VI side;
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
  signal bStateInDefaultClkDomain, dStreamStateValue : StreamStateValue_t;
  signal vFifoUnderflow: std_logic;

  --vhook_sigstart
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
  signal dPushStateToBusClkDomain: boolean;
  signal dStopRequestStrobe: boolean;
  signal iCorrelatedDataIn: std_logic_vector(kCorrelatedDataWidth-1 downto 0);
  signal oCorrelatedDataOut: std_logic_vector(kCorrelatedDataWidth-1 downto 0);
  signal vCtEnableOutBool: boolean;
  signal vDisable: boolean;
  signal vEnableOutLoc: boolean;
  signal vFifoUnderflowFlag: std_logic;
  signal vPopBuffer: boolean;
  signal vPopToFifo: boolean;
  signal vPushPop: boolean;
  signal vReady: boolean;
  signal vResetForFifo: boolean;
  signal vStopRequestStrobeFromDiagram: boolean;
  signal vStreamStateDelayed: StreamState_t;
  signal vUnderflowStopRequest: boolean;
  --vhook_sigend

  constant kSampleShift : natural := Log2(kFifoDataWidth)-3;
  

begin

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
  bOutputStreamInterfaceFromFifo.StateInDefaultClkDomain <= bStateInDefaultClkDomain;

  vCtCount <= resize(vCtCountLoc, vCtCount'length);


  --vhook_e DmaPortCommIfcComponentEnableChain
  --vhook_a kInput false
  --vhook_a kDataWidth kSampleWidth*kNumOfSamplesPerRead
  --vhook_a kHandshaking kReadUsingHandshaking
  --vhook_a aReset aDiagramReset
  --vhook_a PClk ViClk
  --vhook_a BusClk BusClk
  --vhook_a pEnableIn to_boolean(vEnableIn)
  --vhook_a pEnableOut vEnableOutLoc
  --vhook_a pEnableClear to_Boolean(vEnableClear)
  --vhook_a pHandshakingPushPopRequest to_boolean(vReadyForOutput)
  --vhook_a pPushPop vPushPop
  --vhook_a pDisable vDisable
  --vhook_a pResetForFifo vResetForFifo
  --vhook_a bResetForFifo bResetForFifo
  --vhook_a bResetBitFromRegister bDmaReset
  --vhook_a bResetDone bResetDone
  --vhook_a pStateDisable false
  --vhook_a pTimeout vTimeout
  --vhook_a pDataOut vDataOut
  --vhook_a pFlag vFifoUnderflowFlag
  --vhook_a pDataOutFromFifo vBufferData
  --vhook_a pFlagFromFifo to_StdLogic(vEmptyFromBuffer)
  DmaPortCommIfcComponentEnableChainx: entity work.DmaPortCommIfcComponentEnableChain (rtl)
    generic map (
      kInput       => false,
      kSCL         => kSCL,
      kDataWidth   => kSampleWidth*kNumOfSamplesPerRead,
      kHandshaking => kReadUsingHandshaking)
    port map (
      aReset                     => aDiagramReset,
      PClk                       => ViClk,
      BusClk                     => BusClk,
      pEnableIn                  => to_boolean(vEnableIn),
      pEnableOut                 => vEnableOutLoc,
      pEnableClear               => to_Boolean(vEnableClear),
      pHandshakingPushPopRequest => to_boolean(vReadyForOutput),
      pPushPop                   => vPushPop,
      pDisable                   => vDisable,
      pResetForFifo              => vResetForFifo,
      bResetForFifo              => bResetForFifo,
      bResetBitFromRegister      => bDmaReset,
      bResetDone                 => bResetDone,
      pStateDisable              => false,
      pTimeout                   => vTimeout,
      pDataOut                   => vDataOut,
      pFlag                      => vFifoUnderflowFlag,
      pDataOutFromFifo           => vBufferData,
      pFlagFromFifo              => to_StdLogic(vEmptyFromBuffer));


  vEnableOut <= to_StdLogic(vEnableOutLoc);


  --vhook_e NiFpgaFifoPopBuffer
  --vhook_a kElementWidth kSampleWidth
  --vhook_a kNumOfElements kNumOfSamplesPerRead
  --vhook_a kFifoDepth kFifoDepthInSamples
  --vhook_a kBufferDepth kFifoPopBufferDepth
  --vhook_a kPopThreshold 1
  --vhook_a kGenerateCounts true
  --vhook_a aReset aDiagramReset
  --vhook_a Clk ViClk
  --vhook_a cReset vResetForFifo
  --vhook_a cDataFromFifo vFifoDataResized
  --vhook_a cFullCountFromFifo vFullCountFromFifo
  --vhook_a cPopToFifo vPopToFifo
  --vhook_a cDisablePop vDisable
  --vhook_a cPop vPopBuffer
  --vhook_a cDataOut vBufferData
  --vhook_a cEmpty vEmptyFromBuffer
  --vhook_a cFullCount vPopBufferFullCountOut
  --vhook_a cPopFlag open
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

  --vhook_e DmaPortOutStrmFifo
  --vhook_a aReset aDiagramReset
  --vhook_a IClk BusClk
  --vhook_a iWrite bFifoWrite
  --vhook_a iWriteEnables bByteEnable
  --vhook_a iWriteLengthInBytes bWriteLengthInBytes
  --vhook_a iReset bResetForFifo
  --vhook_a iDataIn bFifoData
  --vhook_a iRsrvWriteSpaces bRsrvWriteSpaces
  --vhook_a iReqWriteSpaces bReqWriteSamples
  --vhook_a iRsrvdSpacesFilled bRsrvdSpacesFilled
  --vhook_a iEmptyCount bEmptyCount
  --vhook_a OClk ViClk
  --vhook_a oRead vPopToFifo
  --vhook_a oReset vResetForFifo
  --vhook_a oDataOut vFifoData
  --vhook_a oFullCount vFullCountFromFifo
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

  --vhook_e NiFpgaFifoCountControl
  --vhook_a kWidth vPopBufferFullCountOut'length
  --vhook_a kInSCL kCountScl
  --vhook_a aReset aDiagramReset
  --vhook_a Clk ViClk
  --vhook_a cReset vResetForFifo
  --vhook_a cEnableIn to_boolean(vCtEnableIn)
  --vhook_a cEnableOutClear to_boolean(vCtEnableOutClear)
  --vhook_a cEnableOut vCtEnableOutBool
  --vhook_a cCountIn vPopBufferFullCountOut
  --vhook_a cCountOut vCtCountLoc
  NiFpgaFifoCountControlx: entity work.NiFpgaFifoCountControl (rtl)
    generic map (
      kWidth => vPopBufferFullCountOut'length,
      kInSCL => kCountScl)
    port map (
      aReset          => aDiagramReset,
      Clk             => ViClk,
      cReset          => vResetForFifo,
      cEnableIn       => to_boolean(vCtEnableIn),
      cEnableOutClear => to_boolean(vCtEnableOutClear),
      cEnableOut      => vCtEnableOutBool,
      cCountIn        => vPopBufferFullCountOut,
      cCountOut       => vCtCountLoc);

  vCtEnableOut <= to_StdLogic(vCtEnableOutBool);
  vEmpty <= vFifoUnderflowFlag;
  -- In case of Handshaking report the underflow condition only when vReadyForOutput is asserted 
  -- together with vEnableIn while the FIFO is empty.
  -- In case of timeout mechanism the underflow condition occurs 
  -- when vEnableIn is asserted while the FIFO is empty, so we can use just vFifoUnderflowFlag.  
  vFifoUnderflow <= to_stdlogic(to_boolean(vFifoUnderflowFlag) and to_boolean(vReadyForOutput)) 
              when kReadUsingHandshaking else vFifoUnderflowFlag;

  ---------------------------------------------------------------------------------------
  -- Handshaking interface 
  ---------------------------------------------------------------------------------------
  GenReadHS : if kReadUsingHandshaking generate
    
    vOutputValid <= to_stdlogic(not (to_boolean(vFifoUnderflowFlag)) and vPushPop);
    
  end generate GenReadHS;
  
  -------------------------------------------------------------------------------------
  -- Stream State Enable Chain Components
  -------------------------------------------------------------------------------------  
  StreamStateBlock: block

    type StreamStateValueArray_t is array (natural range <>) of StreamStateValue_t;

    signal vStreamState : StreamState_t;
    signal vStreamStateValue, vStreamStateValueDelayed : StreamStateValue_t;
    signal dStreamState : StreamState_t;
    signal dStartTransitionComplete, dStopTransitionComplete : boolean;
    signal bPushStateToDefaultClkDomain : boolean;
    signal vStreamStateValueDelays : StreamStateValueArray_t(kRamReadLatency-1 downto 0);
    signal vStopRequest, vStopRequestStrobe : boolean;

  begin

    vStreamStateValue <= to_StreamStateValue(vStreamState);

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
        kSCL => kScl)
      port map (
        aReset          => aDiagramReset,
        ViClk           => ViClk,
        vStreamState    => vStreamStateValue,
        vEnableIn       => vStreamStateEnableIn,
        vEnableOut      => vStreamStateEnableOut,
        vEnableClear    => vStreamStateEnableClear,
        vStreamStateOut => vStreamStateOut);


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
        kSCL => false)
      port map (
        aReset          => aDiagramReset,
        ViClk           => DefaultClk,
        vStreamState    => dStreamStateValue,
        vEnableIn       => dStreamStateEnableIn,
        vEnableOut      => dStreamStateEnableOut,
        vEnableClear    => dStreamStateEnableClear,
        vStreamStateOut => dStreamStateOut);



    -------------------------------------------------------------------------------------
    -- Enable Chain Components for State Transitioning
    -------------------------------------------------------------------------------------


    dStartTransitionComplete <= dStreamState = Enabled;
    dStopTransitionComplete <= dStreamState = Disabled or dStreamState = Unlinked;

    --vhook_e DmaPortCommIfcComponentStateTransitionEnableChain StartEnableChain
    --vhook_a aReset aDiagramReset
    --vhook_a ViClk DefaultClk
    --vhook_a bTransitionRequestStrobe bStartStreamRequest
    --vhook_a vTransitionRequestStrobe open
    --vhook_a vTransitionComplete dStartTransitionComplete
    --vhook_a vEnableIn dStartRequestEnableIn
    --vhook_a vEnableOut dStartRequestEnableOut
    --vhook_a vEnableClear dStartRequestEnableClear
    --vhook_a bTransitionTimeoutRequestStrobe open
    --vhook_a vTransitionTimeoutRequestStrobe open
    --vhook_a vTimedOut open
    --vhook_a vTimeout (others=>'0')
    StartEnableChain: entity work.DmaPortCommIfcComponentStateTransitionEnableChain (rtl)
      port map (
        aReset                          => aDiagramReset,
        ViClk                           => DefaultClk,
        BusClk                          => BusClk,
        bTransitionRequestStrobe        => bStartStreamRequest,
        bTransitionTimeoutRequestStrobe => open,
        vTransitionRequestStrobe        => open,
        vTransitionTimeoutRequestStrobe => open,
        vTransitionComplete             => dStartTransitionComplete,
        vEnableIn                       => dStartRequestEnableIn,
        vEnableOut                      => dStartRequestEnableOut,
        vEnableClear                    => dStartRequestEnableClear,
        vTimedOut                       => open,
        vTimeout                        => (others=>'0'));


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
        aReset                          => aDiagramReset,
        ViClk                           => DefaultClk,
        BusClk                          => BusClk,
        bTransitionRequestStrobe        => bStopStreamRequestFromDiagram,
        bTransitionTimeoutRequestStrobe => open,
        vTransitionRequestStrobe        => dStopRequestStrobe,
        vTransitionTimeoutRequestStrobe => open,
        vTransitionComplete             => dStopTransitionComplete,
        vEnableIn                       => dStopRequestEnableIn,
        vEnableOut                      => dStopRequestEnableOut,
        vEnableClear                    => dStopRequestEnableClear,
        vTimedOut                       => open,
        vTimeout                        => (others=>'0'));



    -------------------------------------------------------------------------------------
    -- Handshake the Stream State
    -------------------------------------------------------------------------------------


    bStreamStateValue <= to_StreamStateValue(bStreamState);

    -- Handshake the stream state to the DefaultClk domain.


    -- If the ViClk is different from the DefaultClk, then the stream state for the
    -- two clock domains will never be coherent, so generate a second handshake.
    GenDefaultStateCrossing: if not kViClkIsDefaultClk generate

      --vhook_e HandshakeSLV HandshakeStateToDefaultClkDomain
      --vhook_a aReset aDiagramReset
      --vhook_a kDataWidth bStreamStateValue'length
      --vhook_a IClk BusClk
      --vhook_a iPush bPushStateToDefaultClkDomain
      --vhook_a iData bStreamStateValue
      --vhook_a iReady bPushStateToDefaultClkDomain
      --vhook_a OClk DefaultClk
      --vhook_a oDataValid open
      --vhook_a oData dStreamStateValue
      HandshakeStateToDefaultClkDomain: entity work.HandshakeSLV (struct)
        generic map (
          kDataWidth => bStreamStateValue'length)
        port map (
          aReset     => aDiagramReset,
          IClk       => BusClk,
          iPush      => bPushStateToDefaultClkDomain,
          iData      => bStreamStateValue,
          iReady     => bPushStateToDefaultClkDomain,
          OClk       => DefaultClk,
          oDataValid => open,
          oData      => dStreamStateValue);

    end generate GenDefaultStateCrossing;

    -- If the ViClk is the same as the DefaultClk, then the stream state for the
    -- two clock domains needs to be coherent.  We cannot use a separate handshake
    -- for this stream state, since the handshake would make the states incoherent.
    -- Therefore, just assign the state in the DefaultClk domain to the one from
    -- the ViClk domain.
    NoDefaultStateCrossing: if kViClkIsDefaultClk generate

      --vscan Begin Exception OutputStreamStateClockCrossing
      --vscan # This assignment is safe because it is only done when the ViClk is the
      --vscan # same clock as the DefaultClk, so there is no clock crossing.
      --vscan Source Clock: DmaClkArray
      --vscan Destination Clock: DefaultClk
      --vscan Path: *[ChinchDmaOutputFifoInterface]dStreamStateValue*
      --vscan End Exception

      dStreamStateValue <= vStreamStateValueDelayed;

    end generate NoDefaultStateCrossing;


    dStreamState <= to_StreamState(dStreamStateValue);
    dCurrentStreamState <= dStreamStateValue;
    vStreamStateDelayed <= to_StreamState(vStreamStateValueDelayed);


    -- Handshake the stream state from the default clock domain back to the BusClk
    -- domain.  This handshake requires the safe reset handshake because the request
    -- signal goes from the asynchronous diagram reset domain to the asynchronous bus
    -- reset domain.

    --vhook_e HandshakeBaseResetCross HandshakeStateToBusClkDomain
    --vhook_a kDataWidth dStreamStateValue'length
    --vhook_a aResetToDlyPush open
    --vhook_a aResetToIResetFast open
    --vhook_a aPushToggleDly open
    --vhook_a aIReset aDiagramReset
    --vhook_a IClk DefaultClk
    --vhook_a iPush dPushStateToBusClkDomain
    --vhook_a iData dStreamStateValue
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
        kDataWidth => dStreamStateValue'length)
      port map (
        aResetToDlyPush    => open,
        aResetToIResetFast => open,
        aPushToggleDly     => open,
        aIReset            => aDiagramReset,
        IClk               => DefaultClk,
        iPush              => dPushStateToBusClkDomain,
        iData              => dStreamStateValue,
        iStoredData        => open,
        iReady             => dPushStateToBusClkDomain,
        iOResetStatus      => open,
        aOReset            => aBusReset,
        OClk               => BusClk,
        oDataValid         => open,
        oDataAck           => true,
        oData              => bStateInDefaultClkDomain);


    -------------------------------------------------------------------------------------
    -- State Holder Components
    -------------------------------------------------------------------------------------


    -- Track the state to report to the ViClk domain.  This component
    -- is used so that the state is immediately reported as disabled after a stop
    -- request is made before the actual state is reported as disabled.

    --vhook_e DmaPortCommIfcComponentOutputStateHolder ViClkStateHolder
    --vhook_a aReset aDiagramReset
    --vhook_a ViClk ViClk
    --vhook_a vStreamStateOut vStreamState
    --vhook_a vStreamState vStreamStateDelayed
    ViClkStateHolder: entity work.DmaPortCommIfcComponentOutputStateHolder (rtl)
      port map (
        aReset          => aDiagramReset,
        ViClk           => ViClk,
        vStreamStateOut => vStreamState,
        vStreamState    => vStreamStateDelayed,
        vStopRequest    => vStopRequest);


    -- Latch the disabled state when there is a diagram stop request or when the state
    -- controller indicates that the host has issued a stop request.
    vStopRequest <= vStopRequestStrobe or vReportDisabledToDiagram;


    -------------------------------------------------------------------------------------
    -- Request Strobes
    -------------------------------------------------------------------------------------


    -- Sync the stop request strobe to the ViClk domain.

    --vhook_e PulseSyncBool SyncStopRequestStrobeToViClk
    --vhook_a aReset aDiagramReset
    --vhook_a IClk DefaultClk
    --vhook_a iSig dStopRequestStrobe
    --vhook_a OClk ViClk
    --vhook_a oSig vStopRequestStrobeFromDiagram
    SyncStopRequestStrobeToViClk: entity work.PulseSyncBool (behavior)
      port map (
        aReset => aDiagramReset,
        IClk   => DefaultClk,
        iSig   => dStopRequestStrobe,
        OClk   => ViClk,
        oSig   => vStopRequestStrobeFromDiagram);

    vStopRequestStrobe <= vStopRequestStrobeFromDiagram or vUnderflowStopRequest;


    -- Stop the stream from the ViClk domain if an underflow occurs and disable on
    -- underflow is enabled.
    vUnderflowStopRequest <= kDisableOnFifoTimeout and vFifoUnderflow='1' and
      vStreamState = Enabled;

    bStopStreamRequest <= bStopStreamRequestFromDiagram or bUnderflowStopRequest;

    -------------------------------------------------------------------------------------
    -- Handshake the underflow stop request to the BusClk domain.
    --
    -- This handshake requires the safe reset handshake because the request signal
    -- goes from the asynchronous diagram reset domain to the asynchronous bus reset
    -- domain.
    --
    --
    -- !ASSUMPTION!
    -- The iReady signal is ignored, which means that if a stream disables due to
    -- underflow and then re-enables before the handshake is ready, an underflow could
    -- potentially ignored.  I am making the assumption that this will not happen because
    -- the host is required to enable a stream, and this should be much slower than the
    -- time required to handshake the underflow stop request.
    -------------------------------------------------------------------------------------

    --vhook_e HandshakeBaseResetCross HandshakeUnderflowStopRequest
    --vhook_a kDataWidth 2
    --vhook_a aResetToDlyPush open
    --vhook_a aResetToIResetFast open
    --vhook_a aPushToggleDly open
    --vhook_a aIReset aDiagramReset
    --vhook_a IClk ViClk
    --vhook_a iPush vUnderflowStopRequest
    --vhook_a iData open
    --vhook_a iStoredData open
    --vhook_a iReady open
    --vhook_a iOResetStatus open
    --vhook_a aOReset aBusReset
    --vhook_a OClk BusClk
    --vhook_a oDataValid bUnderflowStopRequest
    --vhook_a oDataAck true
    --vhook_a oData open
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
    -- buffer.  Since the FIFO has a read latency of 1, it can take up to 1 clock cycle
    -- between the updated FIFO count being available to the FIFO pop buffer and that
    -- count making it to the user.  Therefore, the stream state should be delayed
    -- 1 additional clock cycle.
    -------------------------------------------------------------------------------------

    -- Implement the additional delays for the stream state based on the FIFO read
    -- latency.  Shift the stream state from the FIFO into vStreamStateValueDelays(0).
    -- vStreamStateValueDelays(kRamReadLatency-1) is the value to provide the user.
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

  end block StreamStateBlock;


  ---------------------------------------------------------------------------------------
  -- Underflow detector
  ---------------------------------------------------------------------------------------
  BlkUnderflow: block
    signal vFifoUnderflowStrobe, vHsModuleReady : boolean;
  begin

    -- Create the FIFO underflow strobe based on the underflow signal from
    -- the enable chain.  Qualify this with the HS ready signal so that a push is not
    -- sent while the HS module is in the middle of a previous HS.  This means that an
    -- underflow could be missed by the module, but this will only happen if the HS were
    -- already in the process of handshaking a previous underflow.  Since the underflow
    -- is setting an interrupt bit on the BusClk side, this is ok as long as the time
    -- between handshakes is less than the time for the host to receive and handle the
    -- interrupt.

    vFifoUnderflowStrobe <= to_Boolean(vFifoUnderflow) and vEnableOutLoc and
      vHsModuleReady;


    -- This handshake requires the safe reset handshake because the bFifoUnderflow signal
    -- goes from the asynchronous diagram reset domain to the asynchronous bus reset
    -- domain.  Even though the bFifoUnderflow signal is quiesced during diagram reset,
    -- the handshake module is still unsafe since the data valid signal is an xor of
    -- two flip flops, which could be reset at different times and produce metastability
    -- on the data valid signal.  Using the safe handshake prevents any metastability
    -- from propagating to the asynchronous bus reset domain.

    -- Set this handshake up like the HandshakeBool so that the overflow flag
    -- strobes for one clock cycle in the BusClk domain.

    --vhook_e HandshakeBaseResetCross HandshakeUnderflow
    --vhook_a kDataWidth 2
    --vhook_a aResetToDlyPush open
    --vhook_a aResetToIResetFast open
    --vhook_a aPushToggleDly open
    --vhook_a aIReset aDiagramReset
    --vhook_a IClk ViClk
    --vhook_a iPush vFifoUnderflowStrobe
    --vhook_a iData open
    --vhook_a iStoredData open
    --vhook_a iReady vHsModuleReady
    --vhook_a iOResetStatus open
    --vhook_a aOReset aBusReset
    --vhook_a OClk BusClk
    --vhook_a oDataValid bFifoUnderflow
    --vhook_a oDataAck true
    --vhook_a oData open
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


  -- Handshake the pop buffer full count to the BusClk domain with safe reset crossing.
  -- The full count is used on the BusClk domain to allow the host to read the full
  -- count.  This can't be done with the empty count from the FIFO because the empty
  -- count doesn't take into account the elements in the pop buffer.

  --vhook_e HandshakeBaseResetCross HandshakeFullCount
  --vhook_a kDataWidth vPopBufferFullCountOut'length
  --vhook_a aResetToDlyPush open
  --vhook_a aResetToIResetFast open
  --vhook_a aPushToggleDly open
  --vhook_a aIReset aDiagramReset
  --vhook_a IClk ViClk
  --vhook_a iPush vReady
  --vhook_a iData std_logic_vector(vPopBufferFullCountOut)
  --vhook_a iStoredData open
  --vhook_a iReady vReady
  --vhook_a iOResetStatus open
  --vhook_a aOReset aBusReset
  --vhook_a OClk BusClk
  --vhook_a oDataValid open
  --vhook_a oDataAck true
  --vhook_a oData bPopBufferFullCountOut
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
