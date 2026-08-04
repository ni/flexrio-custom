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
--   Smoke/integration testbench for the PXIe-7990 custom target's UserHdl.
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
      kSignature => x"7994BEEF",
      kNumDioLines => 0
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
      aReservedToClip => (others => '0'),
      aReservedFromClip => open,
      stIoModuleSupportsFRAGLs => open,
      xIoPresent => '0',
      xIoReady => '0',
      xIoOutputEnable => '0',
      dvTdcAssert => open,
      dtTdcAssert => '0',
      dtDevClkEn => open,
      aSeGpio => open,
      aDiffGpio_p => open,
      aDiffGpio_n => open,
      SampleClk => '0',
      DeviceClk => '0'
    );

end architecture sim;
