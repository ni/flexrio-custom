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
--     - kNumLoopbackPairs FifoLoopbackPair blocks (each a Reader + Writer FIFO
--       wired together) covering a range of data widths/types
--     - Per-pair FIFO start/stop, count, and state registers
--
--   Each FifoLoopbackPair wires its Reader (Host-to-Target) and Writer
--   (Target-to-Host) FIFOs together in hardware: data the host streams into
--   the Reader FIFO is automatically moved into the Writer FIFO and streamed
--   back to the host, providing a DMA FIFO loopback for the test suite.
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
  port(
    BusClk         : in  std_logic;
    DmaClk         : in  std_logic;
    aBusReset      : in  boolean;
    abDiagramReset : in  boolean;

    bRegPortIn  : in  RegPortIn_t;
    bRegPortOut : out RegPortOut_t;

    -- DMA stream interfaces for all UserHdl FIFO channels, indexed by config
    -- index (0 to kNumUserHdlDmaChannels-1). For pair p:
    --   config(2*p)   = Reader (Host-to-Target)
    --   config(2*p+1) = Writer (Target-to-Host)
    dUserInputStreamInterfaceToFifo    : in  InputStreamInterfaceToFifoArray_t(0 to kNumUserHdlDmaChannels-1);
    dUserInputStreamInterfaceFromFifo  : out InputStreamInterfaceFromFifoArray_t(0 to kNumUserHdlDmaChannels-1);
    dUserOutputStreamInterfaceToFifo   : in  OutputStreamInterfaceToFifoArray_t(0 to kNumUserHdlDmaChannels-1);
    dUserOutputStreamInterfaceFromFifo : out OutputStreamInterfaceFromFifoArray_t(0 to kNumUserHdlDmaChannels-1)
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
  -- FIFO register array — kNumRegsPerFifoPair registers per pair, starting at
  -- byte offset 60
  ---------------------------------------------------------------------------
  signal bFifoRegFpgaHostWrite : BooleanVector(0 to kNumFifoRegs-1);
  signal bFifoRegFpgaAck       : BooleanVector(0 to kNumFifoRegs-1) := (others => false);
  signal bFifoRegFpgaWrite     : BooleanVector(0 to kNumFifoRegs-1);
  signal bFifoRegFpgaDataIn    : Slv32Ary_t(0 to kNumFifoRegs-1);
  signal bFifoRegFpgaDataOut   : Slv32Ary_t(0 to kNumFifoRegs-1);

  -- Per-pair status / control arrays (BusClk domain)
  type Unsigned32Array_t  is array (natural range <>) of unsigned(31 downto 0);
  type StreamStateArray_t is array (natural range <>) of StreamStateValue_t;

  signal bWriterFifoCtCount     : Unsigned32Array_t(0 to kNumLoopbackPairs-1);
  signal bReaderFifoCtCount     : Unsigned32Array_t(0 to kNumLoopbackPairs-1);
  signal bWriterFifoStreamState : StreamStateArray_t(0 to kNumLoopbackPairs-1);
  signal bReaderFifoStreamState : StreamStateArray_t(0 to kNumLoopbackPairs-1);

  signal bWriterFifoStartReq : BooleanVector(0 to kNumLoopbackPairs-1) := (others => false);
  signal bWriterFifoStopReq  : BooleanVector(0 to kNumLoopbackPairs-1) := (others => false);
  signal bReaderFifoStartReq : BooleanVector(0 to kNumLoopbackPairs-1) := (others => false);
  signal bReaderFifoStopReq  : BooleanVector(0 to kNumLoopbackPairs-1) := (others => false);

begin

  ---------------------------------------------------------------------------
  -- Common host registers (signature / version / oldest compatible / scratch)
  ---------------------------------------------------------------------------
  NiSharedCommonHostRegs_inst : entity work.NiSharedCommonHostRegs
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
  -- FIFO registers (kNumRegsPerFifoPair registers per pair, from byte offset 60)
  ---------------------------------------------------------------------------
  NiFifoRegisterArray_inst : entity work.NiSharedHostRegisterArray
    generic map(
      kNumRegisters => kNumFifoRegs,
      kBaseAddress  => kFifoRegsBaseAddress,
      kDefault      => (0 to kNumFifoRegs-1 => x"00000000"),
      kReadOnly     => FifoRegReadOnly,
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

  -- Map per-pair count/state status into the FIFO register array
  FifoRegWriteMap : process(bWriterFifoCtCount, bReaderFifoCtCount,
                            bWriterFifoStreamState, bReaderFifoStreamState)
  begin
    bFifoRegFpgaWrite  <= (others => false);
    bFifoRegFpgaDataIn <= (others => (others => '0'));

    for p in 0 to kNumLoopbackPairs-1 loop
      -- Continuously update count and state registers for each pair
      bFifoRegFpgaWrite(p*kNumRegsPerFifoPair + kWriterCountOffset)  <= true;
      bFifoRegFpgaDataIn(p*kNumRegsPerFifoPair + kWriterCountOffset) <= std_logic_vector(bWriterFifoCtCount(p));

      bFifoRegFpgaWrite(p*kNumRegsPerFifoPair + kReaderCountOffset)  <= true;
      bFifoRegFpgaDataIn(p*kNumRegsPerFifoPair + kReaderCountOffset) <= std_logic_vector(bReaderFifoCtCount(p));

      bFifoRegFpgaWrite(p*kNumRegsPerFifoPair + kWriterStateOffset)  <= true;
      bFifoRegFpgaDataIn(p*kNumRegsPerFifoPair + kWriterStateOffset) <= (31 downto 2 => '0') & bWriterFifoStreamState(p);

      bFifoRegFpgaWrite(p*kNumRegsPerFifoPair + kReaderStateOffset)  <= true;
      bFifoRegFpgaDataIn(p*kNumRegsPerFifoPair + kReaderStateOffset) <= (31 downto 2 => '0') & bReaderFifoStreamState(p);
    end loop;
  end process FifoRegWriteMap;

  ---------------------------------------------------------------------------
  -- FIFO loopback pairs (Reader + Writer FIFOs wired together in hardware)
  --
  -- For pair p:
  --   config(2*p)   = Reader (Host-to-Target)
  --   config(2*p+1) = Writer (Target-to-Host)
  ---------------------------------------------------------------------------
  GenLoopbackPairs : for p in 0 to kNumLoopbackPairs-1 generate
    FifoLoopbackPair_inst : entity work.FifoLoopbackPair
      generic map(
        kReaderFifoDepth       => kUserHdlDmaFifoConf(2*p).FifoDepth,
        kWriterFifoDepth       => kUserHdlDmaFifoConf(2*p+1).FifoDepth,
        kSampleWidth           => kUserHdlDmaFifoConf(2*p).FifoWidth,
        kElementsPerClockCycle => kUserHdlDmaFifoConf(2*p).ElementsPerClockCycle,
        kSignedData            => kUserHdlDmaFifoConf(2*p+1).SignedData,
        kFxpType               => false
      )
      port map(
        BusClk         => BusClk,
        DmaClk         => DmaClk,
        aBusReset      => aBusReset,
        abDiagramReset => abDiagramReset,

        -- Writer FIFO = config index 2*p+1
        dWriterInputStreamInterfaceToFifo    => dUserInputStreamInterfaceToFifo(2*p+1),
        dWriterInputStreamInterfaceFromFifo  => dUserInputStreamInterfaceFromFifo(2*p+1),
        dWriterOutputStreamInterfaceToFifo   => dUserOutputStreamInterfaceToFifo(2*p+1),
        dWriterOutputStreamInterfaceFromFifo => dUserOutputStreamInterfaceFromFifo(2*p+1),

        -- Reader FIFO = config index 2*p
        dReaderInputStreamInterfaceToFifo    => dUserInputStreamInterfaceToFifo(2*p),
        dReaderInputStreamInterfaceFromFifo  => dUserInputStreamInterfaceFromFifo(2*p),
        dReaderOutputStreamInterfaceToFifo   => dUserOutputStreamInterfaceToFifo(2*p),
        dReaderOutputStreamInterfaceFromFifo => dUserOutputStreamInterfaceFromFifo(2*p),

        bWriterStartReq    => bWriterFifoStartReq(p),
        bWriterStopReq     => bWriterFifoStopReq(p),
        bReaderStartReq    => bReaderFifoStartReq(p),
        bReaderStopReq     => bReaderFifoStopReq(p),

        bWriterCtCount     => bWriterFifoCtCount(p),
        bReaderCtCount     => bReaderFifoCtCount(p),
        bWriterStreamState => bWriterFifoStreamState(p),
        bReaderStreamState => bReaderFifoStreamState(p)
      );
  end generate GenLoopbackPairs;

  -- Start/Stop glue logic for all pairs.
  -- Host writes bit 0 = start request, bit 1 = stop request to the
  -- Writer/Reader StartStop register of each pair.
  FifoStartStopGlue : process(BusClk)
  begin
    if aBusReset then
      bWriterFifoStartReq <= (others => false);
      bWriterFifoStopReq  <= (others => false);
      bReaderFifoStartReq <= (others => false);
      bReaderFifoStopReq  <= (others => false);
    elsif rising_edge(BusClk) then
      bWriterFifoStartReq <= (others => false);
      bWriterFifoStopReq  <= (others => false);
      bReaderFifoStartReq <= (others => false);
      bReaderFifoStopReq  <= (others => false);

      for p in 0 to kNumLoopbackPairs-1 loop
        if bFifoRegFpgaHostWrite(p*kNumRegsPerFifoPair + kWriterStartStopOffset) then
          if bFifoRegFpgaDataOut(p*kNumRegsPerFifoPair + kWriterStartStopOffset)(0) = '1' then
            bWriterFifoStartReq(p) <= true;
          end if;
          if bFifoRegFpgaDataOut(p*kNumRegsPerFifoPair + kWriterStartStopOffset)(1) = '1' then
            bWriterFifoStopReq(p) <= true;
          end if;
        end if;

        if bFifoRegFpgaHostWrite(p*kNumRegsPerFifoPair + kReaderStartStopOffset) then
          if bFifoRegFpgaDataOut(p*kNumRegsPerFifoPair + kReaderStartStopOffset)(0) = '1' then
            bReaderFifoStartReq(p) <= true;
          end if;
          if bFifoRegFpgaDataOut(p*kNumRegsPerFifoPair + kReaderStartStopOffset)(1) = '1' then
            bReaderFifoStopReq(p) <= true;
          end if;
        end if;
      end loop;
    end if;
  end process FifoStartStopGlue;

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

end rtl;
