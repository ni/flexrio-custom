-------------------------------------------------------------------------------
--
-- File: UserHdlTestCoreNoAux.vhd
--
-------------------------------------------------------------------------------
-- (c) 2026 Copyright National Instruments Corporation
--
-- SPDX-License-Identifier: MIT
-------------------------------------------------------------------------------
--
-- Purpose:
--   DUT wrapper for targets whose UserHdl exposes no auxiliary DIO interface
--   at all (no aux ports, no kNumAuxIoData generic). It declares the testbench
--   signals, generates the clocks, instantiates work.UserHdl and runs the
--   single-sourced stimulus from work.PkgUserHdlTest. Local zeroed aux-output
--   signals are passed to the shared procedure so the board-IO default check
--   (SECTION 6) is a vacuous pass for this variant. The companion
--   UserHdlTestCoreBidir / UserHdlTestCoreSimple cover the aux variants.
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

entity UserHdlTestCoreNoAux is
  generic (
    -- Board signature reported by the common Signature register.
    kSignature : std_logic_vector(31 downto 0)
  );
end entity UserHdlTestCoreNoAux;

architecture sim of UserHdlTestCoreNoAux is

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

  -- This target has no aux DIO; provide zeroed stand-ins so the shared
  -- stimulus procedure's board-IO default check is a vacuous pass.
  signal aLvAuxDioOutputData : std_logic_vector(0 downto 0) := (others => '0');
  signal aLvAuxDioOutputEnable : std_logic_vector(0 downto 0) := (others => '0');

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
      dReaderOutputStreamInterfaceFromFifo => dReaderOutputStreamInterfaceFromFifo
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
