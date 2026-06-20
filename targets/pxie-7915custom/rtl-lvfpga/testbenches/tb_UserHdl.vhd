-------------------------------------------------------------------------------
--
-- File: tb_UserHdl.vhd
--
-------------------------------------------------------------------------------
-- (c) 2026 Copyright National Instruments Corporation
--
-- SPDX-License-Identifier: MIT
-------------------------------------------------------------------------------
--
-- Purpose:
--   Smoke/integration testbench for UserHdl.
--
--   Covers:
--   - Common host registers (signature/version/oldest/scratch)
--   - Demo loopback register array behavior
--   - FIFO endpoint host registers (start/stop, writer data, reader strobe)
--   - Read-only behavior for FIFO status/data registers
--
--   Board IO (AuxDio) ports are wired to the DUT but intentionally not
--   exercised or asserted on -- board IO behavior is out of scope for this
--   smoke test.
--
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;
  use work.PkgCommunicationInterface.all;
  use work.PkgDmaPortDmaFifos.all;
  use work.PkgUserHdl.all;

entity tb_UserHdl is
end entity tb_UserHdl;

architecture sim of tb_UserHdl is

  constant kBusClkPeriod : time := 10 ns;
  constant kDmaClkPeriod : time := 8 ns;
  constant kNumAuxIoData : natural := 8;

  constant kSignature : std_logic_vector(31 downto 0) := x"7915BEEF";
  constant kVersion : std_logic_vector(31 downto 0) := x"00000001";
  constant kOldestCompatible : std_logic_vector(31 downto 0) := x"00000001";

  signal BusClk : std_logic := '0';
  signal DmaClk : std_logic := '0';

  signal aBusReset : boolean := true;
  signal aDiagramReset : std_logic := '1';

  signal bRegPortIn : RegPortIn_t := kRegPortInZero;
  signal bRegPortOut : RegPortOut_t;

  signal dWriterInputStreamInterfaceToFifo : InputStreamInterfaceToFifo_t := kInputStreamInterfaceToFifoZero;
  signal dWriterInputStreamInterfaceFromFifo : InputStreamInterfaceFromFifo_t;
  signal dWriterOutputStreamInterfaceToFifo : OutputStreamInterfaceToFifo_t := kOutputStreamInterfaceToFifoZero;
  signal dWriterOutputStreamInterfaceFromFifo : OutputStreamInterfaceFromFifo_t;

  signal dReaderInputStreamInterfaceToFifo : InputStreamInterfaceToFifo_t := kInputStreamInterfaceToFifoZero;
  signal dReaderInputStreamInterfaceFromFifo : InputStreamInterfaceFromFifo_t;
  signal dReaderOutputStreamInterfaceToFifo : OutputStreamInterfaceToFifo_t := kOutputStreamInterfaceToFifoZero;
  signal dReaderOutputStreamInterfaceFromFifo : OutputStreamInterfaceFromFifo_t;

  signal aLvAuxDioInputData : std_logic_vector(kNumAuxIoData-1 downto 0) := (others => '0');
  signal bdDoneaLvAuxDio : std_logic_vector(kNumAuxIoData-1 downto 0) := (others => '0');
  signal aLvAuxDioOutputData : std_logic_vector(kNumAuxIoData-1 downto 0);
  signal aLvAuxDioOutputEnable : std_logic_vector(kNumAuxIoData-1 downto 0);
  signal bdDirectionaLvAuxDio : std_logic_vector(kNumAuxIoData-1 downto 0);
  signal bdRequestaLvAuxDio : std_logic_vector(kNumAuxIoData-1 downto 0);

  signal TestDone : boolean := false;

begin

  BusClk <= not BusClk after kBusClkPeriod / 2 when not TestDone else '0';
  DmaClk <= not DmaClk after kDmaClkPeriod / 2 when not TestDone else '0';

  DUT : entity work.UserHdl
    generic map(
      kNumAuxIoData => kNumAuxIoData
    )
    port map(
      BusClk => BusClk,
      DmaClk => DmaClk,
      aBusReset => aBusReset,
      aDiagramReset => aDiagramReset,

      bRegPortIn => bRegPortIn,
      bRegPortOut => bRegPortOut,

      dWriterInputStreamInterfaceToFifo => dWriterInputStreamInterfaceToFifo,
      dWriterInputStreamInterfaceFromFifo => dWriterInputStreamInterfaceFromFifo,
      dWriterOutputStreamInterfaceToFifo => dWriterOutputStreamInterfaceToFifo,
      dWriterOutputStreamInterfaceFromFifo => dWriterOutputStreamInterfaceFromFifo,

      dReaderInputStreamInterfaceToFifo => dReaderInputStreamInterfaceToFifo,
      dReaderInputStreamInterfaceFromFifo => dReaderInputStreamInterfaceFromFifo,
      dReaderOutputStreamInterfaceToFifo => dReaderOutputStreamInterfaceToFifo,
      dReaderOutputStreamInterfaceFromFifo => dReaderOutputStreamInterfaceFromFifo,

      aLvAuxDioInputData => aLvAuxDioInputData,
      bdDoneaLvAuxDio => bdDoneaLvAuxDio,
      aLvAuxDioOutputData => aLvAuxDioOutputData,
      aLvAuxDioOutputEnable => aLvAuxDioOutputEnable,
      bdDirectionaLvAuxDio => bdDirectionaLvAuxDio,
      bdRequestaLvAuxDio => bdRequestaLvAuxDio
    );

  Stimulus : process
    variable vReadData : std_logic_vector(31 downto 0);
    variable vBefore : std_logic_vector(31 downto 0);
    variable vAfter : std_logic_vector(31 downto 0);

    procedure BusClkWait(N : integer := 1) is
    begin
      for i in 1 to N loop
        wait until rising_edge(BusClk);
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

    -- Reset release
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

    report "=== tb_UserHdl: ALL TESTS PASSED ===" severity note;

    TestDone <= true;
    wait;
  end process;

end architecture sim;