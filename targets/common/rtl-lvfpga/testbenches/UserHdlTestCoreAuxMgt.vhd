-------------------------------------------------------------------------------
--
-- File: UserHdlTestCoreAuxMgt.vhd
--
-------------------------------------------------------------------------------
-- (c) 2026 Copyright National Instruments Corporation
--
-- SPDX-License-Identifier: MIT
-------------------------------------------------------------------------------
--
-- Purpose:
--   DUT wrapper for targets whose UserHdl exposes the full board IO interface
--   relocated from the LV Window: eight aux-DIO IO nodes (per-index
--   OutputData / InputData / OutputEnable plus the oClk / aoReset / oDone /
--   oDirection / oRequest handshake) and the MGT CLIP socket. It declares the
--   testbench signals, generates the clocks, instantiates work.UserHdl and runs
--   the single-sourced stimulus from work.PkgUserHdlTest. The per-index scalar
--   OutputData / OutputEnable ports are aggregated into vectors so the shared
--   SECTION 6 board-IO default check can inspect them.
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
  use work.PkgUserHdlTest.all;

entity UserHdlTestCoreAuxMgt is
  generic (
    -- Board signature reported by the common Signature register.
    kSignature : std_logic_vector(31 downto 0);
    -- Number of auxiliary DIO lines on the target.
    kNumAuxIoData : natural := 8
  );
end entity UserHdlTestCoreAuxMgt;

architecture sim of UserHdlTestCoreAuxMgt is

  constant kBusClkPeriod : time := 10 ns;
  constant kDmaClkPeriod : time := 8 ns;

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

  -- Aggregated board-IO outputs from UserHdl (per-index scalar ports collected
  -- into vectors for the shared SECTION 6 default-drive check).
  signal aLvAuxDioOutputData : std_logic_vector(kNumAuxIoData-1 downto 0);
  signal aLvAuxDioOutputEnable : std_logic_vector(kNumAuxIoData-1 downto 0);

  signal TestDone : boolean := false;

begin

  BusClk <= not BusClk after kBusClkPeriod / 2 when not TestDone else '0';
  DmaClk <= not DmaClk after kDmaClkPeriod / 2 when not TestDone else '0';

  DUT : entity work.UserHdl
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

      aLvAuxDio0OutputData => aLvAuxDioOutputData(0),
      aLvAuxDio0InputData => '0',
      aLvAuxDio0OutputEnable => aLvAuxDioOutputEnable(0),
      oClkaLvAuxDio0 => BusClk,
      aoResetaLvAuxDio0 => '0',
      oDoneaLvAuxDio0 => '0',
      oDirectionaLvAuxDio0 => open,
      oRequestaLvAuxDio0 => open,
      aLvAuxDio1OutputData => aLvAuxDioOutputData(1),
      aLvAuxDio1InputData => '0',
      aLvAuxDio1OutputEnable => aLvAuxDioOutputEnable(1),
      oClkaLvAuxDio1 => BusClk,
      aoResetaLvAuxDio1 => '0',
      oDoneaLvAuxDio1 => '0',
      oDirectionaLvAuxDio1 => open,
      oRequestaLvAuxDio1 => open,
      aLvAuxDio2OutputData => aLvAuxDioOutputData(2),
      aLvAuxDio2InputData => '0',
      aLvAuxDio2OutputEnable => aLvAuxDioOutputEnable(2),
      oClkaLvAuxDio2 => BusClk,
      aoResetaLvAuxDio2 => '0',
      oDoneaLvAuxDio2 => '0',
      oDirectionaLvAuxDio2 => open,
      oRequestaLvAuxDio2 => open,
      aLvAuxDio3OutputData => aLvAuxDioOutputData(3),
      aLvAuxDio3InputData => '0',
      aLvAuxDio3OutputEnable => aLvAuxDioOutputEnable(3),
      oClkaLvAuxDio3 => BusClk,
      aoResetaLvAuxDio3 => '0',
      oDoneaLvAuxDio3 => '0',
      oDirectionaLvAuxDio3 => open,
      oRequestaLvAuxDio3 => open,
      aLvAuxDio4OutputData => aLvAuxDioOutputData(4),
      aLvAuxDio4InputData => '0',
      aLvAuxDio4OutputEnable => aLvAuxDioOutputEnable(4),
      oClkaLvAuxDio4 => BusClk,
      aoResetaLvAuxDio4 => '0',
      oDoneaLvAuxDio4 => '0',
      oDirectionaLvAuxDio4 => open,
      oRequestaLvAuxDio4 => open,
      aLvAuxDio5OutputData => aLvAuxDioOutputData(5),
      aLvAuxDio5InputData => '0',
      aLvAuxDio5OutputEnable => aLvAuxDioOutputEnable(5),
      oClkaLvAuxDio5 => BusClk,
      aoResetaLvAuxDio5 => '0',
      oDoneaLvAuxDio5 => '0',
      oDirectionaLvAuxDio5 => open,
      oRequestaLvAuxDio5 => open,
      aLvAuxDio6OutputData => aLvAuxDioOutputData(6),
      aLvAuxDio6InputData => '0',
      aLvAuxDio6OutputEnable => aLvAuxDioOutputEnable(6),
      oClkaLvAuxDio6 => BusClk,
      aoResetaLvAuxDio6 => '0',
      oDoneaLvAuxDio6 => '0',
      oDirectionaLvAuxDio6 => open,
      oRequestaLvAuxDio6 => open,
      aLvAuxDio7OutputData => aLvAuxDioOutputData(7),
      aLvAuxDio7InputData => '0',
      aLvAuxDio7OutputEnable => aLvAuxDioOutputEnable(7),
      oClkaLvAuxDio7 => BusClk,
      aoResetaLvAuxDio7 => '0',
      oDoneaLvAuxDio7 => '0',
      oDirectionaLvAuxDio7 => open,
      oRequestaLvAuxDio7 => open,

      DioMgtRefClk_p => '0',
      DioMgtRefClk_n => '0',
      DioMgtRefClkFromFam => '0',
      DioMgtRX_n => "0000",
      DioMgtRX_p => "0000",
      DioMgtTX_n => open,
      DioMgtTX_p => open,
      SocketClk80 => BusClk,
      sDioMgtRefClkFromFamPresent => '0'
    );

  Stimulus : process
  begin
    RunUserHdlTest(
      kSignature => kSignature,
      BusClk => BusClk,
      DmaClk => DmaClk,
      aBusReset => aBusReset,
      aDiagramReset => aDiagramReset,
      bRegPortIn => bRegPortIn,
      bRegPortOut => bRegPortOut,
      dWriterInputStreamInterfaceToFifo => dWriterInputStreamInterfaceToFifo,
      dWriterInputStreamInterfaceFromFifo => dWriterInputStreamInterfaceFromFifo,
      dReaderOutputStreamInterfaceToFifo => dReaderOutputStreamInterfaceToFifo,
      dReaderOutputStreamInterfaceFromFifo => dReaderOutputStreamInterfaceFromFifo,
      aLvAuxDioOutputData => aLvAuxDioOutputData,
      aLvAuxDioOutputEnable => aLvAuxDioOutputEnable,
      TestDone => TestDone
    );
    wait;
  end process;

end architecture sim;
