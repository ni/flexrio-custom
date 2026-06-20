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
--   User-facing HDL block for the PXIe-7903 custom target.
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

entity UserHdl is
  generic(
    -- Number of auxiliary board DIO lines routed to UserHdl (the LV Window has
    -- board IO disabled on this custom target).
    kNumAuxIoData : natural := 8
  );
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

    -- Board IO (Base DIO): the LV Window has board IO disabled on this custom
    -- target (set_include_board_io_on_lv_window(False)), so the carrier's
    -- base DIO lines (aDio) are brought into UserHdl via inferred tristate
    -- buffers in the top. aLvAuxDioInputData reads the pin state;
    -- aLvAuxDioOutputData/OutputEnable drive the pins. This target's DIO node
    -- has no request/direction/done handshake, so only these three lines are
    -- routed.
    aLvAuxDioInputData    : in  std_logic_vector(kNumAuxIoData-1 downto 0);
    aLvAuxDioOutputData   : out std_logic_vector(kNumAuxIoData-1 downto 0);
    aLvAuxDioOutputEnable : out std_logic_vector(kNumAuxIoData-1 downto 0)
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
      kSignature               => x"7903BEEF",
      kVersion                 => x"00000001",
      kOldestCompatibleVersion => x"00000001"
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
      kUseFpgaAck   => (0 to kNumDemoRegs-1 => false)
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
      kUseFpgaAck   => (0 to kNumFifoRegs-1 => false)
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
      kSampleWidth          => kUserHdlDmaFifoConf(1).FifoWidth,
      kNumOfSamplesPerWrite => kUserHdlDmaFifoConf(1).ElementsPerClockCycle,
      kSignExtend           => kUserHdlDmaFifoConf(1).SignedData,
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
      kSampleWidth          => kUserHdlDmaFifoConf(0).FifoWidth,
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
  -- Board IO (AuxDio) -- user-extendable placeholder
  ---------------------------------------------------------------------------
  -- Because the LV Window has board IO disabled on this custom target, the
  -- carrier's kNumAuxIoData auxiliary DIO lines are routed here instead of to
  -- the LabVIEW diagram. In SasquatchTopTemplate these lines connect to the
  -- base DIO pins (aDio) through inferred tristate buffers:
  --   * aLvAuxDioOutputData  -> aDio drive value
  --   * aLvAuxDioOutputEnable -> aDio tristate enable (per bit)
  --   * aLvAuxDioInputData   <- aDio pin read-back
  --
  -- All outputs are driven to 0 by default:
  --   * aLvAuxDioOutputEnable = 0 keeps every line tristated (high-Z), which is
  --     the safe default -- UserHdl does not drive the physical pins.
  --   * aLvAuxDioOutputData = 0 is an inert default.
  --
  -- To use the DIO lines, replace these constant assignments with your own
  -- custom logic: drive aLvAuxDioOutputData/OutputEnable to control the pins
  -- and read aLvAuxDioInputData for the pin state.
  aLvAuxDioOutputData   <= (others => '0');
  aLvAuxDioOutputEnable <= (others => '0');

end rtl;
