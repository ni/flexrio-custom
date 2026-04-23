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
--   User-facing HDL block for the PXIe-7912 custom target.
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
use work.PkgUserHdl.all;

entity UserHdl is
  port(
    BusClk         : in  std_logic;
    DmaClk         : in  std_logic;
    aBusReset      : in  boolean;
    abDiagramReset : in  boolean;

    bRegPortIn  : in  RegPortIn_t;
    bRegPortOut : out RegPortOut_t;

    -- DMA stream interface for Writer FIFO (channel kUserDmaWriterIdx, FPGA-to-Host)
    -- Input direction: connected to NiFifoWriter
    dWriterInputStreamInterfaceToFifo    : in  InputStreamInterfaceToFifo_t;
    dWriterInputStreamInterfaceFromFifo   : out InputStreamInterfaceFromFifo_t;
    -- Output direction: unused for TargetToHost, driven to zero
    dWriterOutputStreamInterfaceToFifo   : in  OutputStreamInterfaceToFifo_t;
    dWriterOutputStreamInterfaceFromFifo  : out OutputStreamInterfaceFromFifo_t;

    -- DMA stream interface for Reader FIFO (channel kUserDmaReaderIdx, Host-to-FPGA)
    -- Input direction: unused for HostToTarget, driven to zero
    dReaderInputStreamInterfaceToFifo    : in  InputStreamInterfaceToFifo_t;
    dReaderInputStreamInterfaceFromFifo   : out InputStreamInterfaceFromFifo_t;
    -- Output direction: connected to NiFifoReader
    dReaderOutputStreamInterfaceToFifo   : in  OutputStreamInterfaceToFifo_t;
    dReaderOutputStreamInterfaceFromFifo  : out OutputStreamInterfaceFromFifo_t
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
  NiCommonHostRegs_inst : entity work.NiCommonHostRegs
    generic map(
      kSignature               => x"7912BEEF",
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
  NiDemoRegisterArray_inst : entity work.NiHostRegisterArray
    generic map(
      kNumRegisters => kNumDemoRegs,
      kBaseAddress  => 16#10#,
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
  -- Demonstration loopback logic for NiHostRegisterArray usage.
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
  NiFifoRegisterArray_inst : entity work.NiHostRegisterArray
    generic map(
      kNumRegisters => kNumFifoRegs,
      kBaseAddress  => 60,
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
  WriterFifo_inst : entity work.NiFifoWriter
    generic map(
      kFifoDepth            => kUserHdlDmaFifoConfArray(0).FifoDepth,
      kSampleWidth          => kUserHdlDmaFifoConfArray(0).FifoWidth,
      kNumOfSamplesPerWrite => kUserHdlDmaFifoConfArray(0).ElementsPerClockCycle,
      kSignExtend           => kUserHdlDmaFifoConfArray(0).SignedData,
      kFxpType              => kUserHdlDmaFifoConfArray(0).FxpType,
      kPeerToPeer           => false,
      kDisableOnFifoTimeout => kUserHdlDmaFifoConfArray(0).DisableOnFifoTimeout
    )
    port map(
      aDiagramReset                 => abDiagramReset,
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
  ReaderFifo_inst : entity work.NiFifoReader
    generic map(
      kFifoDepth            => kUserHdlDmaFifoConfArray(1).FifoDepth,
      kSampleWidth          => kUserHdlDmaFifoConfArray(1).FifoWidth,
      kNumOfSamplesPerRead  => kUserHdlDmaFifoConfArray(1).ElementsPerClockCycle,
      kFxpType              => kUserHdlDmaFifoConfArray(1).FxpType,
      kPeerToPeer           => false,
      kDisableOnFifoTimeout => kUserHdlDmaFifoConfArray(1).DisableOnFifoTimeout
    )
    port map(
      aDiagramReset                  => abDiagramReset,
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

end rtl;
