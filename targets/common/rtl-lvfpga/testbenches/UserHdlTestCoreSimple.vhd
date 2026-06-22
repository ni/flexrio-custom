-------------------------------------------------------------------------------
--
-- File: UserHdlTestCoreSimple.vhd
--
-------------------------------------------------------------------------------
-- (c) 2026 Copyright National Instruments Corporation
--
-- SPDX-License-Identifier: MIT
-------------------------------------------------------------------------------
--
-- Purpose:
--   DUT wrapper for targets whose UserHdl exposes the plain aux-DIO interface
--   (input / output / output-enable only, no bidirectional handshake). It
--   declares the testbench signals, generates the clocks, instantiates
--   work.UserHdl and runs the single-sourced stimulus from work.PkgUserHdlTest.
--   The companion UserHdlTestCoreBidir covers targets with the bidirectional
--   aux handshake.
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

entity UserHdlTestCoreSimple is
  generic (
    -- Board signature reported by the common Signature register.
    kSignature : std_logic_vector(31 downto 0);
    -- Number of auxiliary DIO lines on the target.
    kNumAuxIoData : natural := 8
  );
end entity UserHdlTestCoreSimple;

architecture sim of UserHdlTestCoreSimple is

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

  signal aLvAuxDioInputData : std_logic_vector(kNumAuxIoData-1 downto 0) := (others => '0');
  signal aLvAuxDioOutputData : std_logic_vector(kNumAuxIoData-1 downto 0);
  signal aLvAuxDioOutputEnable : std_logic_vector(kNumAuxIoData-1 downto 0);

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
      aLvAuxDioOutputData => aLvAuxDioOutputData,
      aLvAuxDioOutputEnable => aLvAuxDioOutputEnable
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
