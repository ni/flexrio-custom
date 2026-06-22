-------------------------------------------------------------------------------
--
-- File: PkgUserHdlTest.vhd
--
-------------------------------------------------------------------------------
-- (c) 2026 Copyright National Instruments Corporation
--
-- SPDX-License-Identifier: MIT
-------------------------------------------------------------------------------
--
-- Purpose:
--   Single source of truth for the UserHdl smoke/integration stimulus.
--
--   The complete test sequence (host register-port driver, demo loopback
--   checks, FIFO endpoint register checks and the Writer/Reader FIFO data-path
--   exercises) lives here as one procedure, RunUserHdlTest. The board-agnostic
--   core entity (UserHdlTestCore) only generates the clocks and calls this
--   procedure, so the stimulus is never duplicated.
--
--   Covers:
--   - Common host registers (signature/version/oldest/scratch)
--   - Demo loopback register array behavior
--   - FIFO endpoint host registers (start/stop, writer data, reader strobe)
--   - Read-only behavior for FIFO status/data registers
--   - Writer FIFO data path: host push (user end) observed at the DMA end
--   - Reader FIFO data path: DMA write end observed/popped at the host end
--
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;
  use work.PkgCommunicationInterface.all;
  use work.PkgDmaPortDmaFifos.all;
  use work.PkgDmaPortCommIfcStreamStates.all;
  use work.PkgUserHdl.all;

package PkgUserHdlTest is

  -- Runs the full UserHdl smoke test. Drives the register port and the DMA
  -- stream ends, checks results, and finally raises TestDone to stop the
  -- clocks. The clock-generation, signal declarations and DUT instantiation
  -- are supplied by the calling core entity.
  procedure RunUserHdlTest(
    constant kSignature : in std_logic_vector(31 downto 0);
    signal BusClk : in std_logic;
    signal DmaClk : in std_logic;
    signal aBusReset : out boolean;
    signal aDiagramReset : out std_logic;
    signal bRegPortIn : out RegPortIn_t;
    signal bRegPortOut : in RegPortOut_t;
    signal dWriterInputStreamInterfaceToFifo : out InputStreamInterfaceToFifo_t;
    signal dWriterInputStreamInterfaceFromFifo : in InputStreamInterfaceFromFifo_t;
    signal dReaderOutputStreamInterfaceToFifo : out OutputStreamInterfaceToFifo_t;
    signal dReaderOutputStreamInterfaceFromFifo : in OutputStreamInterfaceFromFifo_t;
    signal TestDone : out boolean
  );

end package PkgUserHdlTest;

package body PkgUserHdlTest is

  constant kVersion : std_logic_vector(31 downto 0) := x"00000001";
  constant kOldestCompatible : std_logic_vector(31 downto 0) := x"00000001";

  -- Known value pushed through the Reader FIFO for the end-to-end data check.
  constant kReaderTestValue : std_logic_vector(31 downto 0) := x"5A5A1234";

  procedure RunUserHdlTest(
    constant kSignature : in std_logic_vector(31 downto 0);
    signal BusClk : in std_logic;
    signal DmaClk : in std_logic;
    signal aBusReset : out boolean;
    signal aDiagramReset : out std_logic;
    signal bRegPortIn : out RegPortIn_t;
    signal bRegPortOut : in RegPortOut_t;
    signal dWriterInputStreamInterfaceToFifo : out InputStreamInterfaceToFifo_t;
    signal dWriterInputStreamInterfaceFromFifo : in InputStreamInterfaceFromFifo_t;
    signal dReaderOutputStreamInterfaceToFifo : out OutputStreamInterfaceToFifo_t;
    signal dReaderOutputStreamInterfaceFromFifo : in OutputStreamInterfaceFromFifo_t;
    signal TestDone : out boolean
  ) is
    variable vReadData : std_logic_vector(31 downto 0);
    variable vBefore : std_logic_vector(31 downto 0);
    variable vAfter : std_logic_vector(31 downto 0);
    variable DmaResetWaitCount : natural := 0;
    variable FifoWaitCount : natural := 0;

    procedure BusClkWait(N : integer := 1) is
    begin
      for i in 1 to N loop
        wait until rising_edge(BusClk);
      end loop;
    end procedure;

    procedure DmaClkWait(N : integer := 1) is
    begin
      for i in 1 to N loop
        wait until rising_edge(DmaClk);
      end loop;
    end procedure;

    procedure HostWrite(
      constant Addr : in natural;
      constant Data : in std_logic_vector(31 downto 0)
    ) is
      variable WaitCount : natural := 0;
    begin
      while not bRegPortOut.Ready loop
        BusClkWait(1);
        WaitCount := WaitCount + 1;
        assert WaitCount < 200 report "HostWrite timeout waiting for Ready" severity failure;
      end loop;

      bRegPortIn.Address <= to_unsigned(Addr / 4, bRegPortIn.Address'length);
      bRegPortIn.Data <= Data;
      bRegPortIn.Wt <= true;
      bRegPortIn.Rd <= false;
      BusClkWait(1);

      bRegPortIn.Wt <= false;
      bRegPortIn.Data <= (others => '0');
      BusClkWait(1);
    end procedure;

    procedure HostRead(
      constant Addr : in natural;
      variable Data : out std_logic_vector(31 downto 0)
    ) is
      variable WaitCount : natural := 0;
    begin
      while not bRegPortOut.Ready loop
        BusClkWait(1);
        WaitCount := WaitCount + 1;
        assert WaitCount < 200 report "HostRead timeout waiting for Ready" severity failure;
      end loop;

      bRegPortIn.Address <= to_unsigned(Addr / 4, bRegPortIn.Address'length);
      bRegPortIn.Rd <= true;
      bRegPortIn.Wt <= false;
      BusClkWait(1);
      bRegPortIn.Rd <= false;

      WaitCount := 0;
      while not bRegPortOut.DataValid loop
        BusClkWait(1);
        WaitCount := WaitCount + 1;
        assert WaitCount < 200 report "HostRead timeout waiting for DataValid" severity failure;
      end loop;

      Data := bRegPortOut.Data;
      BusClkWait(1);
    end procedure;

  begin

    report "=== tb_UserHdl: start ===" severity note;

    -- Drive all controlled signals to a known initial state.
    bRegPortIn <= kRegPortInZero;
    dWriterInputStreamInterfaceToFifo <= kInputStreamInterfaceToFifoZero;
    dReaderOutputStreamInterfaceToFifo <= kOutputStreamInterfaceToFifoZero;
    TestDone <= false;

    -- Reset release
    aBusReset <= true;
    aDiagramReset <= '1';
    BusClkWait(8);
    aBusReset <= false;
    BusClkWait(4);
    aDiagramReset <= '0';
    BusClkWait(10);

    -------------------------------------------------------------------------
    -- SECTION 1: Common host registers
    -------------------------------------------------------------------------
    report "SECTION 1: common host registers" severity note;

    HostRead(16#00#, vReadData);
    assert vReadData = kSignature report "Common Signature mismatch" severity error;

    HostRead(16#04#, vReadData);
    assert vReadData = kVersion report "Common Version mismatch" severity error;

    HostRead(16#08#, vReadData);
    assert vReadData = kOldestCompatible report "Common OldestCompatible mismatch" severity error;

    HostRead(16#0C#, vReadData);
    assert vReadData = x"00000000" report "Scratch default mismatch" severity error;

    HostWrite(16#0C#, x"CAFEBABE");
    HostRead(16#0C#, vReadData);
    assert vReadData = x"CAFEBABE" report "Scratch R/W failed" severity error;

    HostWrite(16#00#, x"FFFFFFFF");
    HostRead(16#00#, vReadData);
    assert vReadData = kSignature report "Signature should remain read-only" severity error;

    -------------------------------------------------------------------------
    -- SECTION 2: Demo register loopback
    -------------------------------------------------------------------------
    report "SECTION 2: demo loopback registers" severity note;

    HostWrite(kDemoRegsBaseAddress + 0, x"00000011");
    BusClkWait(3);
    HostRead(kDemoRegsBaseAddress + 8, vReadData);
    assert vReadData = x"00000012" report "LoopbackOutA != LoopbackInA + 1" severity error;

    HostWrite(kDemoRegsBaseAddress + 4, x"000000FE");
    BusClkWait(3);
    HostRead(kDemoRegsBaseAddress + 12, vReadData);
    assert vReadData = x"000000FF" report "LoopbackOutB != LoopbackInB + 1" severity error;

    -------------------------------------------------------------------------
    -- SECTION 3: FIFO endpoint host registers
    -------------------------------------------------------------------------
    report "SECTION 3: FIFO endpoint host registers" severity note;

    -- Writable control/data endpoint registers
    HostWrite(kFifoRegsBaseAddress + 4 * kWriterStartStopIdx, x"00000001");
    HostRead(kFifoRegsBaseAddress + 4 * kWriterStartStopIdx, vReadData);
    assert vReadData = x"00000001" report "WriterStartStop R/W failed" severity error;

    HostWrite(kFifoRegsBaseAddress + 4 * kReaderStartStopIdx, x"00000002");
    HostRead(kFifoRegsBaseAddress + 4 * kReaderStartStopIdx, vReadData);
    assert vReadData = x"00000002" report "ReaderStartStop R/W failed" severity error;

    HostWrite(kFifoRegsBaseAddress + 4 * kWriterDataIdx, x"1234ABCD");
    HostRead(kFifoRegsBaseAddress + 4 * kWriterDataIdx, vReadData);
    assert vReadData = x"1234ABCD" report "WriterData R/W failed" severity error;

    HostWrite(kFifoRegsBaseAddress + 4 * kReaderStrobeIdx, x"00000001");
    HostRead(kFifoRegsBaseAddress + 4 * kReaderStrobeIdx, vReadData);
    assert vReadData = x"00000001" report "ReaderStrobe R/W failed" severity error;

    -- Read-only status/data registers should be readable and reject host writes.
    HostRead(kFifoRegsBaseAddress + 4 * kWriterCountIdx, vBefore);
    HostWrite(kFifoRegsBaseAddress + 4 * kWriterCountIdx, x"DEADBEEF");
    HostRead(kFifoRegsBaseAddress + 4 * kWriterCountIdx, vAfter);
    assert vAfter = vBefore report "WriterCount should be read-only" severity error;

    HostRead(kFifoRegsBaseAddress + 4 * kReaderCountIdx, vBefore);
    HostWrite(kFifoRegsBaseAddress + 4 * kReaderCountIdx, x"A5A5A5A5");
    HostRead(kFifoRegsBaseAddress + 4 * kReaderCountIdx, vAfter);
    assert vAfter = vBefore report "ReaderCount should be read-only" severity error;

    HostRead(kFifoRegsBaseAddress + 4 * kWriterStateIdx, vBefore);
    HostWrite(kFifoRegsBaseAddress + 4 * kWriterStateIdx, x"11111111");
    HostRead(kFifoRegsBaseAddress + 4 * kWriterStateIdx, vAfter);
    assert vAfter = vBefore report "WriterState should be read-only" severity error;

    HostRead(kFifoRegsBaseAddress + 4 * kReaderStateIdx, vBefore);
    HostWrite(kFifoRegsBaseAddress + 4 * kReaderStateIdx, x"22222222");
    HostRead(kFifoRegsBaseAddress + 4 * kReaderStateIdx, vAfter);
    assert vAfter = vBefore report "ReaderState should be read-only" severity error;

    HostRead(kFifoRegsBaseAddress + 4 * kReaderDataIdx, vBefore);
    HostWrite(kFifoRegsBaseAddress + 4 * kReaderDataIdx, x"33333333");
    HostRead(kFifoRegsBaseAddress + 4 * kReaderDataIdx, vAfter);
    assert vAfter = vBefore report "ReaderData should be read-only" severity error;

    -------------------------------------------------------------------------
    -- SECTION 4: Writer FIFO data path (host push end -> DMA end)
    --
    -- The host pushes one full bus word of samples through the WriterData
    -- register (user end); we then observe them arrive on the DMA stream end
    -- and pop them back out, exercising both ends of the Writer FIFO.
    -------------------------------------------------------------------------
    report "SECTION 4: Writer FIFO data path" severity note;

    -- Mark the DMA side enabled and reset the FIFO to a known-empty state.
    dWriterInputStreamInterfaceToFifo.StreamState <= kStreamStateEnabled;
    dWriterInputStreamInterfaceToFifo.DmaReset <= true;
    DmaResetWaitCount := 0;
    while not dWriterInputStreamInterfaceFromFifo.ResetDone loop
      DmaClkWait(1);
      DmaResetWaitCount := DmaResetWaitCount + 1;
      assert DmaResetWaitCount < 500
        report "Writer DMA reset: ResetDone timeout" severity failure;
    end loop;
    dWriterInputStreamInterfaceToFifo.DmaReset <= false;
    DmaClkWait(2);

    -- Enable the writer stream from the user side.
    HostWrite(kFifoRegsBaseAddress + 4 * kWriterStartStopIdx, x"00000001");

    -- Push one full 256-bit bus word worth of samples (8 x 32-bit) from the host.
    for i in 0 to 7 loop
      HostWrite(kFifoRegsBaseAddress + 4 * kWriterDataIdx,
                std_logic_vector(to_unsigned(16#A0# + i, 32)));
      BusClkWait(2);
    end loop;

    -- The pushed samples must cross into the DMA (DmaClk) domain.
    FifoWaitCount := 0;
    while dWriterInputStreamInterfaceFromFifo.FifoFullCount < 8 loop
      DmaClkWait(1);
      FifoWaitCount := FifoWaitCount + 1;
      assert FifoWaitCount < 1000
        report "Writer FIFO fill timeout (DMA end never saw the pushed samples)"
        severity failure;
    end loop;
    report "Writer FIFO: DMA end observed the host-pushed samples" severity note;

    -- Exercise the DMA read end: the head bus word is presented on the DMA-side
    -- FifoDataOut output. The first host-pushed sample (0xA0) lands in sample
    -- lane 0, i.e. the low 32 bits of the 256-bit bus word. This confirms the
    -- data crossed end-to-end from the user push end to the DMA read port.
    vReadData := dWriterInputStreamInterfaceFromFifo.FifoDataOut(31 downto 0);
    assert vReadData = std_logic_vector(to_unsigned(16#A0#, 32))
      report "Writer FIFO: DMA-side FifoDataOut did not match the pushed sample"
      severity error;
    report "Writer FIFO: DMA read port presents the host-pushed data" severity note;

    -------------------------------------------------------------------------
    -- SECTION 5: Reader FIFO data path (DMA write end -> host pop end)
    --
    -- The DMA stream end writes one known sample; we then observe it become
    -- available to the user and pop it back through the host registers,
    -- exercising both ends of the Reader FIFO with an end-to-end data check.
    -------------------------------------------------------------------------
    report "SECTION 5: Reader FIFO data path" severity note;

    -- Mark the DMA side enabled and reset the FIFO to a known-empty state.
    dReaderOutputStreamInterfaceToFifo.StreamState <= kStreamStateEnabled;
    dReaderOutputStreamInterfaceToFifo.DmaReset <= true;
    DmaResetWaitCount := 0;
    while not dReaderOutputStreamInterfaceFromFifo.ResetDone loop
      DmaClkWait(1);
      DmaResetWaitCount := DmaResetWaitCount + 1;
      assert DmaResetWaitCount < 500
        report "Reader DMA reset: ResetDone timeout" severity failure;
    end loop;
    dReaderOutputStreamInterfaceToFifo.DmaReset <= false;
    DmaClkWait(2);

    -- Enable the reader stream from the user side.
    HostWrite(kFifoRegsBaseAddress + 4 * kReaderStartStopIdx, x"00000001");

    -- DMA end writes one known 32-bit sample (4 bytes, low lane) into the FIFO.
    wait until falling_edge(DmaClk);
    dReaderOutputStreamInterfaceToFifo.FifoData <=
      std_logic_vector(resize(unsigned(kReaderTestValue),
                              dReaderOutputStreamInterfaceToFifo.FifoData'length));
    dReaderOutputStreamInterfaceToFifo.ByteEnable <=
      (0 => true, 1 => true, 2 => true, 3 => true, others => false);
    dReaderOutputStreamInterfaceToFifo.WriteLengthInBytes <=
      to_unsigned(4, dReaderOutputStreamInterfaceToFifo.WriteLengthInBytes'length);
    dReaderOutputStreamInterfaceToFifo.FifoWrite <= true;
    DmaClkWait(1);
    dReaderOutputStreamInterfaceToFifo.FifoWrite <= false;
    dReaderOutputStreamInterfaceToFifo.FifoData <= (others => '0');
    dReaderOutputStreamInterfaceToFifo.ByteEnable <= (others => false);
    dReaderOutputStreamInterfaceToFifo.WriteLengthInBytes <= (others => '0');

    -- The sample must cross into the user (BusClk) domain; wait until the
    -- host-visible reader count reports data is available.
    FifoWaitCount := 0;
    loop
      HostRead(kFifoRegsBaseAddress + 4 * kReaderCountIdx, vReadData);
      exit when vReadData /= x"00000000";
      FifoWaitCount := FifoWaitCount + 1;
      assert FifoWaitCount < 500
        report "Reader FIFO fill timeout (user end never saw the DMA-written sample)"
        severity failure;
    end loop;
    report "Reader FIFO: user end observed the DMA-written sample" severity note;

    -- Pop the sample from the user side and verify the data end-to-end.
    HostWrite(kFifoRegsBaseAddress + 4 * kReaderStrobeIdx, x"00000001");
    BusClkWait(5);

    FifoWaitCount := 0;
    loop
      HostRead(kFifoRegsBaseAddress + 4 * kReaderDataIdx, vReadData);
      exit when vReadData = kReaderTestValue;
      FifoWaitCount := FifoWaitCount + 1;
      assert FifoWaitCount < 200
        report "Reader FIFO: popped data not ready / mismatch" severity failure;
      BusClkWait(2);
    end loop;
    assert vReadData = kReaderTestValue
      report "Reader FIFO data integrity check failed" severity error;
    report "Reader FIFO: end-to-end data integrity verified" severity note;


    TestDone <= true;
    wait;
  end procedure RunUserHdlTest;

end package body PkgUserHdlTest;
