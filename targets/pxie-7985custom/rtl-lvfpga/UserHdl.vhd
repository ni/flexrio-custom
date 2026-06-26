------------------------------------------------------------------------------------------
--
-- File: UserHdl.vhd
--
------------------------------------------------------------------------------------------
-- (c) 2026 Copyright National Instruments Corporation
--
-- SPDX-License-Identifier: MIT
------------------------------------------------------------------------------------------
--
-- Purpose:
--   User-facing HDL block for the PXIe-7985 custom target.
--
--   Instantiates:
--     - Common host registers (signature, version, oldest compatible, scratch)
--     - A four-element shared register array with loopback logic
--     - Writer FIFO (channel kUserDmaWriterIdx, FPGA-to-Host) with host push registers
--     - Reader FIFO (channel kUserDmaReaderIdx, Host-to-FPGA) with host pop registers
--     - FIFO start/stop, count, and state registers
--
--   The combined RegPortOut is presented as a single output so that the
--   parent top-level only needs one OR/AND merge point for this block.
--
------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.PkgNiUtilities.all;
use work.PkgCommunicationInterface.all;
use work.PkgDmaPortCommunicationInterface.all;
use work.PkgDmaPortDmaFifos.all;
use work.PkgDmaPortCommIfcStreamStates.all;
use work.PkgNiSharedFifo.all;
use work.PkgUserHdl.all;
use work.PkgNiHdlSettings.all;

entity UserHdl is
  port(
    BusClk         : in  std_logic;
    DmaClk         : in  std_logic;
    aBusReset      : in  boolean;
    aDiagramReset  : in  std_logic;

    bRegPortIn  : in  RegPortIn_t;
    bRegPortOut : out RegPortOut_t;

    -- DMA stream interface for Writer FIFO (channel kUserDmaWriterIdx, FPGA-to-Host)
    -- Input direction: connected to NiSharedFifoWriter
    dWriterInputStreamInterfaceToFifo    : in  InputStreamInterfaceToFifo_t;
    dWriterInputStreamInterfaceFromFifo   : out InputStreamInterfaceFromFifo_t;
    -- Output direction: unused for TargetToHost, driven to zero
    dWriterOutputStreamInterfaceToFifo   : in  OutputStreamInterfaceToFifo_t;
    dWriterOutputStreamInterfaceFromFifo  : out OutputStreamInterfaceFromFifo_t;

    -- DMA stream interface for Reader FIFO (channel kUserDmaReaderIdx, Host-to-FPGA)
    -- Input direction: unused for HostToTarget, driven to zero
    dReaderInputStreamInterfaceToFifo    : in  InputStreamInterfaceToFifo_t;
    dReaderInputStreamInterfaceFromFifo   : out InputStreamInterfaceFromFifo_t;
    -- Output direction: connected to NiSharedFifoReader
    dReaderOutputStreamInterfaceToFifo   : in  OutputStreamInterfaceToFifo_t;
    dReaderOutputStreamInterfaceFromFifo  : out OutputStreamInterfaceFromFifo_t;

    -- Board IO: the LV Window has board IO disabled on this custom target
    -- (set_include_board_io_on_lv_window(False)), so every board IO interface
    -- that would normally connect to the LV Window is brought into UserHdl
    -- instead. These ports EXACTLY match the include_board_io block of
    -- TheLvWindowFlatWrapper for this target.
    -----------------------------------
    -- IO Node ports
    -----------------------------------  
    aLvAuxDio0OutputData   : out std_logic;
    aLvAuxDio0InputData    : in  std_logic;
    aLvAuxDio0OutputEnable : out std_logic;
    oClkaLvAuxDio0         : in  std_logic;
    aoResetaLvAuxDio0      : in  std_logic;
    oDoneaLvAuxDio0        : in  std_logic;
    oDirectionaLvAuxDio0   : out std_logic;
    oRequestaLvAuxDio0     : out std_logic;
    aLvAuxDio1OutputData   : out std_logic;
    aLvAuxDio1InputData    : in  std_logic;
    aLvAuxDio1OutputEnable : out std_logic;
    oClkaLvAuxDio1         : in  std_logic;
    aoResetaLvAuxDio1      : in  std_logic;
    oDoneaLvAuxDio1        : in  std_logic;
    oDirectionaLvAuxDio1   : out std_logic;
    oRequestaLvAuxDio1     : out std_logic;
    aLvAuxDio2OutputData   : out std_logic;
    aLvAuxDio2InputData    : in  std_logic;
    aLvAuxDio2OutputEnable : out std_logic;
    oClkaLvAuxDio2         : in  std_logic;
    aoResetaLvAuxDio2      : in  std_logic;
    oDoneaLvAuxDio2        : in  std_logic;
    oDirectionaLvAuxDio2   : out std_logic;
    oRequestaLvAuxDio2     : out std_logic;
    aLvAuxDio3OutputData   : out std_logic;
    aLvAuxDio3InputData    : in  std_logic;
    aLvAuxDio3OutputEnable : out std_logic;
    oClkaLvAuxDio3         : in  std_logic;
    aoResetaLvAuxDio3      : in  std_logic;
    oDoneaLvAuxDio3        : in  std_logic;
    oDirectionaLvAuxDio3   : out std_logic;
    oRequestaLvAuxDio3     : out std_logic;
    aLvAuxDio4OutputData   : out std_logic;
    aLvAuxDio4InputData    : in  std_logic;
    aLvAuxDio4OutputEnable : out std_logic;
    oClkaLvAuxDio4         : in  std_logic;
    aoResetaLvAuxDio4      : in  std_logic;
    oDoneaLvAuxDio4        : in  std_logic;
    oDirectionaLvAuxDio4   : out std_logic;
    oRequestaLvAuxDio4     : out std_logic;
    aLvAuxDio5OutputData   : out std_logic;
    aLvAuxDio5InputData    : in  std_logic;
    aLvAuxDio5OutputEnable : out std_logic;
    oClkaLvAuxDio5         : in  std_logic;
    aoResetaLvAuxDio5      : in  std_logic;
    oDoneaLvAuxDio5        : in  std_logic;
    oDirectionaLvAuxDio5   : out std_logic;
    oRequestaLvAuxDio5     : out std_logic;
    aLvAuxDio6OutputData   : out std_logic;
    aLvAuxDio6InputData    : in  std_logic;
    aLvAuxDio6OutputEnable : out std_logic;
    oClkaLvAuxDio6         : in  std_logic;
    aoResetaLvAuxDio6      : in  std_logic;
    oDoneaLvAuxDio6        : in  std_logic;
    oDirectionaLvAuxDio6   : out std_logic;
    oRequestaLvAuxDio6     : out std_logic;
    aLvAuxDio7OutputData   : out std_logic;
    aLvAuxDio7InputData    : in  std_logic;
    aLvAuxDio7OutputEnable : out std_logic;
    oClkaLvAuxDio7         : in  std_logic;
    aoResetaLvAuxDio7      : in  std_logic;
    oDoneaLvAuxDio7        : in  std_logic;
    oDirectionaLvAuxDio7   : out std_logic;
    oRequestaLvAuxDio7     : out std_logic;
    
    -----------------------------------
    -- CLIP Socket ports
    -----------------------------------

    -- AxiClk is the same as BusCLk is the same as PllClk80
    AxiClk : in std_logic;

    xDiagramAxiStreamFromClipTData  : out std_logic_vector(31 downto 0);
    xDiagramAxiStreamFromClipTLast  : out std_logic;
    xDiagramAxiStreamFromClipTReady : out std_logic;
    xDiagramAxiStreamFromClipTValid : out std_logic;
    xDiagramAxiStreamToClipTData    : in  std_logic_vector(31 downto 0);
    xDiagramAxiStreamToClipTLast    : in  std_logic;
    xDiagramAxiStreamToClipTReady   : in  std_logic;
    xDiagramAxiStreamToClipTValid   : in  std_logic;

    xHostAxiStreamFromClipTData  : out std_logic_vector(31 downto 0);
    xHostAxiStreamFromClipTLast  : out std_logic;
    xHostAxiStreamFromClipTReady : out std_logic;
    xHostAxiStreamFromClipTValid : out std_logic;
    xHostAxiStreamToClipTData    : in  std_logic_vector(31 downto 0);
    xHostAxiStreamToClipTLast    : in  std_logic;
    xHostAxiStreamToClipTReady   : in  std_logic;
    xHostAxiStreamToClipTValid   : in  std_logic;


    -- Axi4Lite Interface from the CLIP to FixedLogic
    xClipAxi4LiteMasterARAddr  : out std_logic_vector(31 downto 0);
    xClipAxi4LiteMasterARProt  : out std_logic_vector(2 downto 0);
    xClipAxi4LiteMasterARReady : in  std_logic;
    xClipAxi4LiteMasterARValid : out std_logic;
    xClipAxi4LiteMasterAWAddr  : out std_logic_vector(31 downto 0);
    xClipAxi4LiteMasterAWProt  : out std_logic_vector(2 downto 0);
    xClipAxi4LiteMasterAWReady : in  std_logic;
    xClipAxi4LiteMasterAWValid : out std_logic;
    xClipAxi4LiteMasterBReady  : out std_logic;
    xClipAxi4LiteMasterBResp   : in  std_logic_vector(1 downto 0);
    xClipAxi4LiteMasterBValid  : in  std_logic;
    xClipAxi4LiteMasterRData   : in  std_logic_vector(31 downto 0);
    xClipAxi4LiteMasterRReady  : out std_logic;
    xClipAxi4LiteMasterRResp   : in  std_logic_vector(1 downto 0);
    xClipAxi4LiteMasterRValid  : in  std_logic;
    xClipAxi4LiteMasterWData   : out std_logic_vector(31 downto 0);
    xClipAxi4LiteMasterWReady  : in  std_logic;
    xClipAxi4LiteMasterWStrb   : out std_logic_vector(3 downto 0);
    xClipAxi4LiteMasterWValid  : out std_logic;
    xClipAxi4LiteInterrupt     : in  std_logic;

    --Configuration Interface
    -- Config Interface TX
    aConfigTxClkLvds          : out std_logic;
    aConfigTxClkSe            : out std_logic;
    aConfigTxDataSe           : out std_logic_vector(6 downto 0);

    -- Config Interface RX
    aConfigRxClkLvds          : in std_logic;
    aConfigRxClkSe            : in std_logic;
    aConfigRxDataSe           : in std_logic_vector(6 downto 0);

    -- Reserved GPIO
    aRsrvGpio_n              : inout std_logic_vector(4 downto 0);
    aRsrvGpio_p              : inout std_logic_vector(4 downto 0);

    --Reserved CLIP Signals
    aReservedToClip          : in std_logic_vector(15 downto 0);
    aReservedFromClip        : out std_logic_vector(15 downto 0);
    stIoModuleSupportsFRAGLs : out std_logic;

    --General purpose Synchronization Signals
    aGpoSync                 : out std_logic_vector(1 downto 0);
    aTriggerIn               : in  std_logic;
    aTriggerOut              : out std_logic;

    --Synchronization Signals
    DeviceClk            : in  std_logic;
    aJesd204SyncReqIn_n  : in  std_logic;
    aJesd204SyncReqOut_n : out std_logic;
    dvJesd204SysRef      : in  std_logic;
    dvTdcAssert          : out std_logic;
    dtTdcAssert          : in  std_logic;
    dtDevClkEn           : out std_logic;

    --IO MGT Ports
    MgtPortRx_n       : in  std_logic_vector(7 downto 0);
    MgtPortRx_p       : in  std_logic_vector(7 downto 0);
    MgtPortTx_n       : out std_logic_vector(7 downto 0);
    MgtPortTx_p       : out std_logic_vector(7 downto 0);
    MgtRefClk_p       : in  std_logic_vector(2 downto 0);
    MgtRefClk_n       : in  std_logic_vector(2 downto 0);
    ExportedMgtRefClk : out std_logic;

    --Nanopitch I/O
    DioMgtRefClk_p              : in  std_logic;
    DioMgtRefClk_n              : in  std_logic;
    DioMgtRefClkFromFam         : in  std_logic;
    DioMgtRX_n                  : in  std_logic_vector(3 downto 0);
    DioMgtRX_p                  : in  std_logic_vector(3 downto 0);
    DioMgtTX_n                  : out std_logic_vector(3 downto 0);
    DioMgtTX_p                  : out std_logic_vector(3 downto 0);
    SocketClk80                 : in  std_logic;
    --Synchronous to SocketClk80
    sDioMgtRefClkFromFamPresent : in  std_logic
  );
end entity UserHdl;

architecture rtl of UserHdl is

  -- Register RegPortOut signals
  signal bRegPortOutCommonRegs : RegPortOut_t;
  signal bRegPortOutDemoRegs : RegPortOut_t;
  signal bRegPortOutFifoRegs   : RegPortOut_t;

  -- Demo register array signals
  signal bDemoRegFpgaHostWrite : BooleanVector(0 to kNumDemoRegs-1);
  signal bDemoRegFpgaAck       : BooleanVector(0 to kNumDemoRegs-1) := (others => false);
  signal bDemoRegFpgaWrite     : BooleanVector(0 to kNumDemoRegs-1) := (others => false);
  signal bDemoRegFpgaDataIn    : Slv32Ary_t(0 to kNumDemoRegs-1) := (others => (others => '0'));
  signal bDemoRegFpgaDataOut   : Slv32Ary_t(0 to kNumDemoRegs-1);

  ---------------------------------------------------------------------------
  -- FIFO register array — 9 registers starting at byte offset 60
  ---------------------------------------------------------------------------
  signal bFifoRegFpgaHostWrite : BooleanVector(0 to kNumFifoRegs-1);
  signal bFifoRegFpgaAck       : BooleanVector(0 to kNumFifoRegs-1) := (others => false);
  signal bFifoRegFpgaWrite     : BooleanVector(0 to kNumFifoRegs-1);
  signal bFifoRegFpgaDataIn    : Slv32Ary_t(0 to kNumFifoRegs-1);
  signal bFifoRegFpgaDataOut   : Slv32Ary_t(0 to kNumFifoRegs-1);

  -- ReaderData dynamic FPGA-write signals (driven by clocked process)
  signal bReaderDataWrite : boolean := false;
  signal bReaderDataIn    : std_logic_vector(31 downto 0) := (others => '0');

  -- Writer FIFO (channel 2) user interface signals (BusClk domain)
  signal bWriterFifoWriteStrobe   : boolean := false;
  signal bWriterFifoDataIn        : std_logic_vector(31 downto 0) := (others => '0');
  signal bWriterFifoInputValid    : boolean := false;
  signal bWriterFifoReadyForInput : boolean;
  signal bWriterFifoFull          : boolean;
  signal bWriterFifoCtCount       : unsigned(31 downto 0);
  signal bWriterFifoStreamState   : StreamStateValue_t;

  -- Reader FIFO (channel 3) user interface signals (BusClk domain)
  signal bReaderFifoDataOut      : std_logic_vector(31 downto 0);
  signal bReaderFifoEmpty        : boolean;
  signal bReaderFifoReadStrobe   : boolean := false;
  signal bReaderFifoOutputValid  : boolean;
  signal bReaderFifoCtCount      : unsigned(31 downto 0);
  signal bReaderFifoStreamState  : StreamStateValue_t;

  -- FIFO start/stop control signals
  signal bWriterFifoStartReq : boolean := false;
  signal bWriterFifoStopReq  : boolean := false;
  signal bReaderFifoStartReq : boolean := false;
  signal bReaderFifoStopReq  : boolean := false;

begin

  ---------------------------------------------------------------------------
  -- Common host registers (signature / version / oldest compatible / scratch)
  ---------------------------------------------------------------------------
  NiSharedCommonHostRegs_inst : entity work.NiSharedCommonHostRegs
    generic map(
      kSignature               => x"7985BEEF",
      kVersion                 => x"00000001",
      kOldestCompatibleVersion => x"00000001",
      kMaxHdlRegOffset         => kMaxHdlRegOffset
    )
    port map(
      BusClk      => BusClk,
      aReset      => aBusReset,
      bRegPortIn  => bRegPortIn,
      bRegPortOut => bRegPortOutCommonRegs
    );

  ---------------------------------------------------------------------------
  -- Demonstration register array (4 registers starting at byte offset 0x10)
  ---------------------------------------------------------------------------
  NiDemoRegisterArray_inst : entity work.NiSharedHostRegisterArray
    generic map(
      kNumRegisters => kNumDemoRegs,
      kBaseAddress  => kDemoRegsBaseAddress,
      kDefault      => (0 to kNumDemoRegs-1 => x"00000000"),
      kReadOnly     => (kLoopbackInAIdx  => false,
                        kLoopbackInBIdx  => false,
                        kLoopbackOutAIdx => true,
                        kLoopbackOutBIdx => true),
      kUseFpgaAck   => (0 to kNumDemoRegs-1 => false),
      kMaxHdlRegOffset => kMaxHdlRegOffset
    )
    port map(
      BusClk         => BusClk,
      aReset         => aBusReset,
      bRegPortIn     => bRegPortIn,
      bRegPortOut    => bRegPortOutDemoRegs,
      bFpgaHostWrite => bDemoRegFpgaHostWrite,
      bFpgaAck       => bDemoRegFpgaAck,
      bFpgaWrite     => bDemoRegFpgaWrite,
      bFpgaDataIn    => bDemoRegFpgaDataIn,
      bFpgaDataOut   => bDemoRegFpgaDataOut
    );

  ---------------------------------------------------------------------------
  -- Demonstration loopback logic for NiSharedHostRegisterArray usage.
  --
  -- Write a value to LoopbackInA, read LoopbackOutA to see value+1.
  -- Write a value to LoopbackInB, read LoopbackOutB to see value+1.
  ---------------------------------------------------------------------------
  DemoHostRegisterLoopbackx: process(BusClk, aBusReset)
  begin
    if aBusReset then
      bDemoRegFpgaWrite <= (others => false);
      bDemoRegFpgaDataIn <= (others => (others => '0'));
    elsif rising_edge(BusClk) then
      bDemoRegFpgaDataIn <= bDemoRegFpgaDataOut;
      bDemoRegFpgaWrite <= (others => false);

      if bDemoRegFpgaHostWrite(kLoopbackInAIdx) then
        bDemoRegFpgaDataIn(kLoopbackOutAIdx) <= std_logic_vector(unsigned(bDemoRegFpgaDataOut(kLoopbackInAIdx)) + 1);
        bDemoRegFpgaWrite(kLoopbackOutAIdx) <= true;
      end if;

      if bDemoRegFpgaHostWrite(kLoopbackInBIdx) then
        bDemoRegFpgaDataIn(kLoopbackOutBIdx) <= std_logic_vector(unsigned(bDemoRegFpgaDataOut(kLoopbackInBIdx)) + 1);
        bDemoRegFpgaWrite(kLoopbackOutBIdx) <= true;
      end if;
    end if;
  end process DemoHostRegisterLoopbackx;

  ---------------------------------------------------------------------------
  -- FIFO registers (9 registers starting at byte offset 60)
  ---------------------------------------------------------------------------
  NiFifoRegisterArray_inst : entity work.NiSharedHostRegisterArray
    generic map(
      kNumRegisters => kNumFifoRegs,
      kBaseAddress  => kFifoRegsBaseAddress,
      kDefault      => (0 to kNumFifoRegs-1 => x"00000000"),
      kReadOnly     => (kWriterStartStopIdx => false,
                        kReaderStartStopIdx => false,
                        kWriterCountIdx     => true,
                        kReaderCountIdx     => true,
                        kWriterStateIdx     => true,
                        kReaderStateIdx     => true,
                        kWriterDataIdx      => false,
                        kReaderStrobeIdx    => false,
                        kReaderDataIdx      => true),
      kUseFpgaAck   => (0 to kNumFifoRegs-1 => false),
      kMaxHdlRegOffset => kMaxHdlRegOffset
    )
    port map(
      BusClk         => BusClk,
      aReset         => aBusReset,
      bRegPortIn     => bRegPortIn,
      bRegPortOut    => bRegPortOutFifoRegs,
      bFpgaHostWrite => bFifoRegFpgaHostWrite,
      bFpgaAck       => bFifoRegFpgaAck,
      bFpgaWrite     => bFifoRegFpgaWrite,
      bFpgaDataIn    => bFifoRegFpgaDataIn,
      bFpgaDataOut   => bFifoRegFpgaDataOut
    );

  -- Map FPGA-write signals into the FIFO register array
  FifoRegWriteMap : process(bWriterFifoCtCount, bReaderFifoCtCount,
                            bWriterFifoStreamState, bReaderFifoStreamState,
                            bReaderDataWrite, bReaderDataIn)
  begin
    bFifoRegFpgaWrite  <= (others => false);
    bFifoRegFpgaDataIn <= (others => (others => '0'));

    -- Continuously update count and state registers
    bFifoRegFpgaWrite(kWriterCountIdx)  <= true;
    bFifoRegFpgaDataIn(kWriterCountIdx) <= std_logic_vector(bWriterFifoCtCount);

    bFifoRegFpgaWrite(kReaderCountIdx)  <= true;
    bFifoRegFpgaDataIn(kReaderCountIdx) <= std_logic_vector(bReaderFifoCtCount);

    bFifoRegFpgaWrite(kWriterStateIdx)  <= true;
    bFifoRegFpgaDataIn(kWriterStateIdx) <= (31 downto 2 => '0') & bWriterFifoStreamState;

    bFifoRegFpgaWrite(kReaderStateIdx)  <= true;
    bFifoRegFpgaDataIn(kReaderStateIdx) <= (31 downto 2 => '0') & bReaderFifoStreamState;

    -- Dynamic write for ReaderData
    bFifoRegFpgaWrite(kReaderDataIdx)  <= bReaderDataWrite;
    bFifoRegFpgaDataIn(kReaderDataIdx) <= bReaderDataIn;
  end process FifoRegWriteMap;

  ---------------------------------------------------------------------------
  -- Writer FIFO (Channel 2, FPGA-to-Host)
  ---------------------------------------------------------------------------
  WriterFifo_inst : entity work.NiSharedFifoWriter
    generic map(
      kFifoDepth            => kUserHdlDmaFifoConf(1).FifoDepth,
      kSampleWidth          => FifoDataWidth(kUserHdlDmaFifoConf(1).DataType),
      kNumOfSamplesPerWrite => kUserHdlDmaFifoConf(1).ElementsPerClockCycle,
      kSignExtend           => FifoDataIsSigned(kUserHdlDmaFifoConf(1).DataType),
      kFxpType              => false,
      kPeerToPeer           => false,
      kDisableOnFifoTimeout => false
    )
    port map(
      aDiagramReset                 => to_Boolean(aDiagramReset),
      aBusReset                     => aBusReset,
      BusClk                        => DmaClk,
      bInputStreamInterfaceToFifo   => dWriterInputStreamInterfaceToFifo,
      bInputStreamInterfaceFromFifo => dWriterInputStreamInterfaceFromFifo,
      ViClk                         => BusClk,
      vDataIn                       => bWriterFifoDataIn,
      vFull                         => bWriterFifoFull,
      vWriteFifo                    => bWriterFifoWriteStrobe,
      vFlush                        => false,
      vCtCount                      => bWriterFifoCtCount,
      vInputValid                   => bWriterFifoInputValid,
      vReadyForInput                => bWriterFifoReadyForInput,
      vStreamStateOut               => bWriterFifoStreamState,
      vStartStreamRequest           => bWriterFifoStartReq,
      vStopRequestStrobe            => bWriterFifoStopReq,
      vFlushTimeoutRequest          => false,
      vStopWithFlushRequestStrobe   => false
    );

  ---------------------------------------------------------------------------
  -- Reader FIFO (Channel 3, Host-to-FPGA)
  ---------------------------------------------------------------------------
  ReaderFifo_inst : entity work.NiSharedFifoReader
    generic map(
      kFifoDepth            => kUserHdlDmaFifoConf(0).FifoDepth,
      kSampleWidth          => FifoDataWidth(kUserHdlDmaFifoConf(0).DataType),
      kNumOfSamplesPerRead  => kUserHdlDmaFifoConf(0).ElementsPerClockCycle,
      kFxpType              => false,
      kPeerToPeer           => false,
      kDisableOnFifoTimeout => false
    )
    port map(
      aDiagramReset                  => to_Boolean(aDiagramReset),
      aBusReset                      => aBusReset,
      BusClk                         => DmaClk,
      bOutputStreamInterfaceToFifo   => dReaderOutputStreamInterfaceToFifo,
      bOutputStreamInterfaceFromFifo => dReaderOutputStreamInterfaceFromFifo,
      ViClk                          => BusClk,
      vDataOut                       => bReaderFifoDataOut,
      vEmpty                         => bReaderFifoEmpty,
      vReadFifo                      => bReaderFifoReadStrobe,
      vCtCount                       => bReaderFifoCtCount,
      vOutputValid                   => bReaderFifoOutputValid,
      vReadyForOutput                => true,
      vStreamStateOut                => bReaderFifoStreamState,
      vStartStreamRequest            => bReaderFifoStartReq,
      vStopRequestStrobe             => bReaderFifoStopReq
    );

  ---------------------------------------------------------------------------
  -- Register / FIFO Glue Logic
  ---------------------------------------------------------------------------

  -- Writer FIFO push: host writes WriterData register -> push into Writer FIFO
  WriterFifoGlue : process(BusClk)
  begin
    if aBusReset then
      bWriterFifoWriteStrobe <= false;
      bWriterFifoInputValid  <= false;
      bWriterFifoDataIn      <= (others => '0');
    elsif rising_edge(BusClk) then
      bWriterFifoWriteStrobe <= false;
      bWriterFifoInputValid  <= false;
      if bFifoRegFpgaHostWrite(kWriterDataIdx) then
        bWriterFifoDataIn      <= bFifoRegFpgaDataOut(kWriterDataIdx);
        bWriterFifoInputValid  <= true;
        bWriterFifoWriteStrobe <= true;
      end if;
    end if;
  end process WriterFifoGlue;

  -- Reader FIFO pop: host writes ReaderStrobe register -> pop from Reader FIFO;
  -- when data arrives, latch it into ReaderData register.
  ReaderFifoGlue : process(BusClk)
  begin
    if aBusReset then
      bReaderFifoReadStrobe <= false;
      bReaderDataWrite      <= false;
      bReaderDataIn         <= (others => '0');
    elsif rising_edge(BusClk) then
      bReaderFifoReadStrobe <= false;
      bReaderDataWrite      <= false;

      -- Trigger a FIFO pop when the host writes to ReaderStrobe
      if bFifoRegFpgaHostWrite(kReaderStrobeIdx) then
        bReaderFifoReadStrobe <= true;
      end if;

      -- When the Reader FIFO produces valid data, write it into the ReaderData register
      if bReaderFifoOutputValid then
        bReaderDataIn    <= bReaderFifoDataOut;
        bReaderDataWrite <= true;
      end if;
    end if;
  end process ReaderFifoGlue;

  -- Start/Stop glue logic for Writer FIFO (channel 2)
  WriterFifoStartStopGlue : process(BusClk)
  begin
    if aBusReset then
      bWriterFifoStartReq <= false;
      bWriterFifoStopReq  <= false;
    elsif rising_edge(BusClk) then
      bWriterFifoStartReq <= false;
      bWriterFifoStopReq  <= false;
      if bFifoRegFpgaHostWrite(kWriterStartStopIdx) then
        if bFifoRegFpgaDataOut(kWriterStartStopIdx)(0) = '1' then
          bWriterFifoStartReq <= true;
        end if;
        if bFifoRegFpgaDataOut(kWriterStartStopIdx)(1) = '1' then
          bWriterFifoStopReq <= true;
        end if;
      end if;
    end if;
  end process WriterFifoStartStopGlue;

  -- Start/Stop glue logic for Reader FIFO (channel 3)
  ReaderFifoStartStopGlue : process(BusClk)
  begin
    if aBusReset then
      bReaderFifoStartReq <= false;
      bReaderFifoStopReq  <= false;
    elsif rising_edge(BusClk) then
      bReaderFifoStartReq <= false;
      bReaderFifoStopReq  <= false;
      if bFifoRegFpgaHostWrite(kReaderStartStopIdx) then
        if bFifoRegFpgaDataOut(kReaderStartStopIdx)(0) = '1' then
          bReaderFifoStartReq <= true;
        end if;
        if bFifoRegFpgaDataOut(kReaderStartStopIdx)(1) = '1' then
          bReaderFifoStopReq <= true;
        end if;
      end if;
    end if;
  end process ReaderFifoStartStopGlue;

  ---------------------------------------------------------------------------
  -- Merge register outputs (OR for Data/DataValid, AND for Ready)
  ---------------------------------------------------------------------------
  bRegPortOut.Data      <= bRegPortOutCommonRegs.Data or
                           bRegPortOutDemoRegs.Data or
                           bRegPortOutFifoRegs.Data;

  bRegPortOut.DataValid <= bRegPortOutCommonRegs.DataValid or
                           bRegPortOutDemoRegs.DataValid or
                           bRegPortOutFifoRegs.DataValid;

  bRegPortOut.Ready     <= bRegPortOutCommonRegs.Ready and
                           bRegPortOutDemoRegs.Ready and
                           bRegPortOutFifoRegs.Ready;

  ---------------------------------------------------------------------------
  -- Drive unused-direction FromFifo signals to zero
  -- (same pattern as DmaPortCommIfcFifos: Input channels zero the Output
  --  FromFifo, Output channels zero the Input FromFifo)
  ---------------------------------------------------------------------------
  dWriterOutputStreamInterfaceFromFifo <= kOutputStreamInterfaceFromFifoZero;
  dReaderInputStreamInterfaceFromFifo  <= kInputStreamInterfaceFromFifoZero;

  ---------------------------------------------------------------------------
  -- Board IO -- user-extendable placeholder
  ---------------------------------------------------------------------------
  -- Because the LV Window has board IO disabled on this custom target, every
  -- board IO interface that would normally connect to the LV Window is routed
  -- here instead. All outputs are driven to an inert default and the inout
  -- buses are released (high-Z); replace these assignments with custom logic
  -- to use the board IO.
  aLvAuxDio0OutputData            <= '0';
  aLvAuxDio0OutputEnable          <= '0';
  oDirectionaLvAuxDio0            <= '0';
  oRequestaLvAuxDio0              <= '0';
  aLvAuxDio1OutputData            <= '0';
  aLvAuxDio1OutputEnable          <= '0';
  oDirectionaLvAuxDio1            <= '0';
  oRequestaLvAuxDio1              <= '0';
  aLvAuxDio2OutputData            <= '0';
  aLvAuxDio2OutputEnable          <= '0';
  oDirectionaLvAuxDio2            <= '0';
  oRequestaLvAuxDio2              <= '0';
  aLvAuxDio3OutputData            <= '0';
  aLvAuxDio3OutputEnable          <= '0';
  oDirectionaLvAuxDio3            <= '0';
  oRequestaLvAuxDio3              <= '0';
  aLvAuxDio4OutputData            <= '0';
  aLvAuxDio4OutputEnable          <= '0';
  oDirectionaLvAuxDio4            <= '0';
  oRequestaLvAuxDio4              <= '0';
  aLvAuxDio5OutputData            <= '0';
  aLvAuxDio5OutputEnable          <= '0';
  oDirectionaLvAuxDio5            <= '0';
  oRequestaLvAuxDio5              <= '0';
  aLvAuxDio6OutputData            <= '0';
  aLvAuxDio6OutputEnable          <= '0';
  oDirectionaLvAuxDio6            <= '0';
  oRequestaLvAuxDio6              <= '0';
  aLvAuxDio7OutputData            <= '0';
  aLvAuxDio7OutputEnable          <= '0';
  oDirectionaLvAuxDio7            <= '0';
  oRequestaLvAuxDio7              <= '0';
  xDiagramAxiStreamFromClipTData  <= (others => '0');
  xDiagramAxiStreamFromClipTLast  <= '0';
  xDiagramAxiStreamFromClipTReady <= '0';
  xDiagramAxiStreamFromClipTValid <= '0';
  xHostAxiStreamFromClipTData     <= (others => '0');
  xHostAxiStreamFromClipTLast     <= '0';
  xHostAxiStreamFromClipTReady    <= '0';
  xHostAxiStreamFromClipTValid    <= '0';
  xClipAxi4LiteMasterARAddr       <= (others => '0');
  xClipAxi4LiteMasterARProt       <= (others => '0');
  xClipAxi4LiteMasterARValid      <= '0';
  xClipAxi4LiteMasterAWAddr       <= (others => '0');
  xClipAxi4LiteMasterAWProt       <= (others => '0');
  xClipAxi4LiteMasterAWValid      <= '0';
  xClipAxi4LiteMasterBReady       <= '0';
  xClipAxi4LiteMasterRReady       <= '0';
  xClipAxi4LiteMasterWData        <= (others => '0');
  xClipAxi4LiteMasterWStrb        <= (others => '0');
  xClipAxi4LiteMasterWValid       <= '0';
  aConfigTxClkLvds                <= '0';
  aConfigTxClkSe                  <= '0';
  aConfigTxDataSe                 <= (others => '0');
  aRsrvGpio_n                     <= (others => 'Z');
  aRsrvGpio_p                     <= (others => 'Z');
  aReservedFromClip               <= (others => '0');
  stIoModuleSupportsFRAGLs        <= '0';
  aGpoSync                        <= (others => '0');
  aTriggerOut                     <= '0';
  aJesd204SyncReqOut_n            <= '0';
  dvTdcAssert                     <= '0';
  dtDevClkEn                      <= '0';
  MgtPortTx_n                     <= (others => '0');
  MgtPortTx_p                     <= (others => '0');
  ExportedMgtRefClk               <= '0';
  DioMgtTX_n                      <= (others => '0');
  DioMgtTX_p                      <= (others => '0');

end rtl;
