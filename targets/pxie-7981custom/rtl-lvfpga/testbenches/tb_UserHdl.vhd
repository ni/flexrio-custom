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

  -- Aux DIO board model signals (8 lines).
  signal bAuxDioOutData   : std_logic_vector(7 downto 0);
  signal bAuxDioInData    : std_logic_vector(7 downto 0);
  signal bAuxDioOutEnable : std_logic_vector(7 downto 0);
  signal bAuxDioDone      : std_logic_vector(7 downto 0) := (others => '0');
  signal bAuxDioDirection : std_logic_vector(7 downto 0);
  signal bAuxDioRequest   : std_logic_vector(7 downto 0);

begin

  TestCore : entity work.UserHdlTestCore
    generic map(
      kSignature => x"7981BEEF",
      kNumDioLines => 8
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
      -- Aux DIO: exercised in simulation via the board model below.
      aLvAuxDio0OutputData => bAuxDioOutData(0),
      aLvAuxDio0InputData => bAuxDioInData(0),
      aLvAuxDio0OutputEnable => bAuxDioOutEnable(0),
      oClkaLvAuxDio0 => BusClk,
      aoResetaLvAuxDio0 => aDiagramReset,
      oDoneaLvAuxDio0 => bAuxDioDone(0),
      oDirectionaLvAuxDio0 => bAuxDioDirection(0),
      oRequestaLvAuxDio0 => bAuxDioRequest(0),
      aLvAuxDio1OutputData => bAuxDioOutData(1),
      aLvAuxDio1InputData => bAuxDioInData(1),
      aLvAuxDio1OutputEnable => bAuxDioOutEnable(1),
      oClkaLvAuxDio1 => BusClk,
      aoResetaLvAuxDio1 => aDiagramReset,
      oDoneaLvAuxDio1 => bAuxDioDone(1),
      oDirectionaLvAuxDio1 => bAuxDioDirection(1),
      oRequestaLvAuxDio1 => bAuxDioRequest(1),
      aLvAuxDio2OutputData => bAuxDioOutData(2),
      aLvAuxDio2InputData => bAuxDioInData(2),
      aLvAuxDio2OutputEnable => bAuxDioOutEnable(2),
      oClkaLvAuxDio2 => BusClk,
      aoResetaLvAuxDio2 => aDiagramReset,
      oDoneaLvAuxDio2 => bAuxDioDone(2),
      oDirectionaLvAuxDio2 => bAuxDioDirection(2),
      oRequestaLvAuxDio2 => bAuxDioRequest(2),
      aLvAuxDio3OutputData => bAuxDioOutData(3),
      aLvAuxDio3InputData => bAuxDioInData(3),
      aLvAuxDio3OutputEnable => bAuxDioOutEnable(3),
      oClkaLvAuxDio3 => BusClk,
      aoResetaLvAuxDio3 => aDiagramReset,
      oDoneaLvAuxDio3 => bAuxDioDone(3),
      oDirectionaLvAuxDio3 => bAuxDioDirection(3),
      oRequestaLvAuxDio3 => bAuxDioRequest(3),
      aLvAuxDio4OutputData => bAuxDioOutData(4),
      aLvAuxDio4InputData => bAuxDioInData(4),
      aLvAuxDio4OutputEnable => bAuxDioOutEnable(4),
      oClkaLvAuxDio4 => BusClk,
      aoResetaLvAuxDio4 => aDiagramReset,
      oDoneaLvAuxDio4 => bAuxDioDone(4),
      oDirectionaLvAuxDio4 => bAuxDioDirection(4),
      oRequestaLvAuxDio4 => bAuxDioRequest(4),
      aLvAuxDio5OutputData => bAuxDioOutData(5),
      aLvAuxDio5InputData => bAuxDioInData(5),
      aLvAuxDio5OutputEnable => bAuxDioOutEnable(5),
      oClkaLvAuxDio5 => BusClk,
      aoResetaLvAuxDio5 => aDiagramReset,
      oDoneaLvAuxDio5 => bAuxDioDone(5),
      oDirectionaLvAuxDio5 => bAuxDioDirection(5),
      oRequestaLvAuxDio5 => bAuxDioRequest(5),
      aLvAuxDio6OutputData => bAuxDioOutData(6),
      aLvAuxDio6InputData => bAuxDioInData(6),
      aLvAuxDio6OutputEnable => bAuxDioOutEnable(6),
      oClkaLvAuxDio6 => BusClk,
      aoResetaLvAuxDio6 => aDiagramReset,
      oDoneaLvAuxDio6 => bAuxDioDone(6),
      oDirectionaLvAuxDio6 => bAuxDioDirection(6),
      oRequestaLvAuxDio6 => bAuxDioRequest(6),
      aLvAuxDio7OutputData => bAuxDioOutData(7),
      aLvAuxDio7InputData => bAuxDioInData(7),
      aLvAuxDio7OutputEnable => bAuxDioOutEnable(7),
      oClkaLvAuxDio7 => BusClk,
      aoResetaLvAuxDio7 => aDiagramReset,
      oDoneaLvAuxDio7 => bAuxDioDone(7),
      oDirectionaLvAuxDio7 => bAuxDioDirection(7),
      oRequestaLvAuxDio7 => bAuxDioRequest(7),
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

  ---------------------------------------------------------------------------
  -- Aux DIO board model
  --   * Pin loopback (MacallanIoBuffers behaviour): the input reflects the
  --     driven output whenever the FPGA output enable is asserted.
  --   * Direction handshake (carrier FixedLogic AuxIoDirectionCtrl behaviour):
  --     Done asserts a couple of BusClk cycles after Request is held high (the
  --     Aux DIO bank is assumed enabled). Done is what gates the FPGA output
  --     enable inside UserHdl, so without this model an output never drives.
  ---------------------------------------------------------------------------
  GenAuxDioModel : for i in 0 to 7 generate
    -- Pin loopback
    bAuxDioInData(i) <= bAuxDioOutData(i) when bAuxDioOutEnable(i) = '1' else '0';

    -- Direction handshake (Done) model
    DoneModel : process(BusClk)
      variable vCount : natural := 0;
    begin
      if rising_edge(BusClk) then
        if bAuxDioRequest(i) = '1' then
          if vCount >= 2 then
            bAuxDioDone(i) <= '1';
          else
            vCount := vCount + 1;
          end if;
        else
          vCount := 0;
          bAuxDioDone(i) <= '0';
        end if;
      end if;
    end process DoneModel;
  end generate GenAuxDioModel;

end architecture sim;