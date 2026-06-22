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
--   Smoke/integration testbench for this target's UserHdl.
--
--   Instantiates work.UserHdl directly (the DUT) and the board-agnostic
--   work.UserHdlTestCore, which generates the clocks and drives the register
--   and DMA FIFO stream ends. This target's board IO is brought out of UserHdl
--   but is not exercised in simulation, so every board IO port is tied off
--   here (inputs to a constant, outputs / inouts left open).
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

  signal BusClk : std_logic;
  signal DmaClk : std_logic;
  signal aBusReset : boolean;
  signal aDiagramReset : std_logic;

  signal bRegPortIn : RegPortIn_t;
  signal bRegPortOut : RegPortOut_t;

  signal dWriterInputStreamInterfaceToFifo : InputStreamInterfaceToFifo_t;
  signal dWriterInputStreamInterfaceFromFifo : InputStreamInterfaceFromFifo_t;
  signal dWriterOutputStreamInterfaceToFifo : OutputStreamInterfaceToFifo_t := kOutputStreamInterfaceToFifoZero;
  signal dWriterOutputStreamInterfaceFromFifo : OutputStreamInterfaceFromFifo_t;

  signal dReaderInputStreamInterfaceToFifo : InputStreamInterfaceToFifo_t := kInputStreamInterfaceToFifoZero;
  signal dReaderInputStreamInterfaceFromFifo : InputStreamInterfaceFromFifo_t;
  signal dReaderOutputStreamInterfaceToFifo : OutputStreamInterfaceToFifo_t;
  signal dReaderOutputStreamInterfaceFromFifo : OutputStreamInterfaceFromFifo_t;

begin

  TestCore : entity work.UserHdlTestCore
    generic map(
      kSignature => x"7981BEEF"
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
      dReaderOutputStreamInterfaceToFifo => dReaderOutputStreamInterfaceToFifo,
      dReaderOutputStreamInterfaceFromFifo => dReaderOutputStreamInterfaceFromFifo
    );

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

      -- Board IO: not exercised in simulation; inputs tied off, outputs/inouts open.
      aLvAuxDio0OutputData => open,
      aLvAuxDio0InputData => '0',
      aLvAuxDio0OutputEnable => open,
      oClkaLvAuxDio0 => '0',
      aoResetaLvAuxDio0 => '0',
      oDoneaLvAuxDio0 => '0',
      oDirectionaLvAuxDio0 => open,
      oRequestaLvAuxDio0 => open,
      aLvAuxDio1OutputData => open,
      aLvAuxDio1InputData => '0',
      aLvAuxDio1OutputEnable => open,
      oClkaLvAuxDio1 => '0',
      aoResetaLvAuxDio1 => '0',
      oDoneaLvAuxDio1 => '0',
      oDirectionaLvAuxDio1 => open,
      oRequestaLvAuxDio1 => open,
      aLvAuxDio2OutputData => open,
      aLvAuxDio2InputData => '0',
      aLvAuxDio2OutputEnable => open,
      oClkaLvAuxDio2 => '0',
      aoResetaLvAuxDio2 => '0',
      oDoneaLvAuxDio2 => '0',
      oDirectionaLvAuxDio2 => open,
      oRequestaLvAuxDio2 => open,
      aLvAuxDio3OutputData => open,
      aLvAuxDio3InputData => '0',
      aLvAuxDio3OutputEnable => open,
      oClkaLvAuxDio3 => '0',
      aoResetaLvAuxDio3 => '0',
      oDoneaLvAuxDio3 => '0',
      oDirectionaLvAuxDio3 => open,
      oRequestaLvAuxDio3 => open,
      aLvAuxDio4OutputData => open,
      aLvAuxDio4InputData => '0',
      aLvAuxDio4OutputEnable => open,
      oClkaLvAuxDio4 => '0',
      aoResetaLvAuxDio4 => '0',
      oDoneaLvAuxDio4 => '0',
      oDirectionaLvAuxDio4 => open,
      oRequestaLvAuxDio4 => open,
      aLvAuxDio5OutputData => open,
      aLvAuxDio5InputData => '0',
      aLvAuxDio5OutputEnable => open,
      oClkaLvAuxDio5 => '0',
      aoResetaLvAuxDio5 => '0',
      oDoneaLvAuxDio5 => '0',
      oDirectionaLvAuxDio5 => open,
      oRequestaLvAuxDio5 => open,
      aLvAuxDio6OutputData => open,
      aLvAuxDio6InputData => '0',
      aLvAuxDio6OutputEnable => open,
      oClkaLvAuxDio6 => '0',
      aoResetaLvAuxDio6 => '0',
      oDoneaLvAuxDio6 => '0',
      oDirectionaLvAuxDio6 => open,
      oRequestaLvAuxDio6 => open,
      aLvAuxDio7OutputData => open,
      aLvAuxDio7InputData => '0',
      aLvAuxDio7OutputEnable => open,
      oClkaLvAuxDio7 => '0',
      aoResetaLvAuxDio7 => '0',
      oDoneaLvAuxDio7 => '0',
      oDirectionaLvAuxDio7 => open,
      oRequestaLvAuxDio7 => open,
      AxiClk => '0',
      xDiagramAxiStreamFromClipTData => open,
      xDiagramAxiStreamFromClipTLast => open,
      xDiagramAxiStreamFromClipTReady => open,
      xDiagramAxiStreamFromClipTValid => open,
      xDiagramAxiStreamToClipTData => (others => '0'),
      xDiagramAxiStreamToClipTLast => '0',
      xDiagramAxiStreamToClipTReady => '0',
      xDiagramAxiStreamToClipTValid => '0',
      xHostAxiStreamFromClipTData => open,
      xHostAxiStreamFromClipTLast => open,
      xHostAxiStreamFromClipTReady => open,
      xHostAxiStreamFromClipTValid => open,
      xHostAxiStreamToClipTData => (others => '0'),
      xHostAxiStreamToClipTLast => '0',
      xHostAxiStreamToClipTReady => '0',
      xHostAxiStreamToClipTValid => '0',
      xClipAxi4LiteMasterARAddr => open,
      xClipAxi4LiteMasterARProt => open,
      xClipAxi4LiteMasterARReady => '0',
      xClipAxi4LiteMasterARValid => open,
      xClipAxi4LiteMasterAWAddr => open,
      xClipAxi4LiteMasterAWProt => open,
      xClipAxi4LiteMasterAWReady => '0',
      xClipAxi4LiteMasterAWValid => open,
      xClipAxi4LiteMasterBReady => open,
      xClipAxi4LiteMasterBResp => (others => '0'),
      xClipAxi4LiteMasterBValid => '0',
      xClipAxi4LiteMasterRData => (others => '0'),
      xClipAxi4LiteMasterRReady => open,
      xClipAxi4LiteMasterRResp => (others => '0'),
      xClipAxi4LiteMasterRValid => '0',
      xClipAxi4LiteMasterWData => open,
      xClipAxi4LiteMasterWReady => '0',
      xClipAxi4LiteMasterWStrb => open,
      xClipAxi4LiteMasterWValid => open,
      xClipAxi4LiteInterrupt => '0',
      aConfigTxClkLvds => open,
      aConfigTxClkSe => open,
      aConfigTxDataSe => open,
      aConfigRxClkLvds => '0',
      aConfigRxClkSe => '0',
      aConfigRxDataSe => (others => '0'),
      aRsrvGpio_n => open,
      aRsrvGpio_p => open,
      aReservedToClip => (others => '0'),
      aReservedFromClip => open,
      stIoModuleSupportsFRAGLs => open,
      aGpoSync => open,
      aTriggerIn => '0',
      aTriggerOut => open,
      DeviceClk => '0',
      aJesd204SyncReqIn_n => '0',
      aJesd204SyncReqOut_n => open,
      dvJesd204SysRef => '0',
      dvTdcAssert => open,
      dtTdcAssert => '0',
      dtDevClkEn => open,
      MgtPortRx_n => (others => '0'),
      MgtPortRx_p => (others => '0'),
      MgtPortTx_n => open,
      MgtPortTx_p => open,
      MgtRefClk_p => (others => '0'),
      MgtRefClk_n => (others => '0'),
      ExportedMgtRefClk => open
    );

end architecture sim;