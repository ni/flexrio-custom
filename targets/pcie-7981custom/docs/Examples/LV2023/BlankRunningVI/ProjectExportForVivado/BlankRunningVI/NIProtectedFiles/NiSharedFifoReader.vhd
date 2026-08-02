-------------------------------------------------------------------------------
--
-- File: NiSharedFifoReader.vhd
--
-------------------------------------------------------------------------------
-- (c) Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--
--   User-facing DMA output (host-to-target) FIFO entity.
--
--   This is the top-level entity that users instantiate to read data from
--   a DMA FIFO sent by the host.  Internally it wraps NiSharedFifoReaderCore.
--
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;
  use work.PkgCommunicationInterface.all;
  use work.PkgDmaPortCommunicationInterface.all;
  use work.PkgDmaPortDataPackingFifo.all;
  use work.PkgDmaPortDmaFifos.all;
  use work.PkgDmaPortCommIfcStreamStates.all;
  use work.PkgNiDma.all;

entity NiSharedFifoReader is
    generic(

      -- kFifoDepth      : This is the size of the DMA FIFO in bus data width
      --                   words.
      kFifoDepth         : natural  := 1024;

      -- kSampleWidth    : This is the sample size of the data going to the
      --                   user VI.
      kSampleWidth       : positive := 32;

      -- kNumOfSamplesPerRead : Number of samples read from the FIFO at one
      --                        time.
      kNumOfSamplesPerRead : positive := 1;

      -- kFxpType        : This boolean indicates whether the data type is a
      --                   FXP type.
      kFxpType           : boolean  := false;

      -- kPeerToPeer     : This boolean indicates whether the stream is a
      --                   normal host to target stream or a peer-to-peer sink
      --                   stream.
      kPeerToPeer        : boolean := false;

      -- kDisableOnFifoTimeout : This sets whether or not the stream disables
      --                         when an underflow occurs.
      kDisableOnFifoTimeout : boolean

    );
    port(

      -- The asynchronous reset for the stream circuit
      aDiagramReset : in boolean;

      aBusReset : in boolean;

      -------------------------------------------------------------------------
      -- Clocks
      -------------------------------------------------------------------------

      BusClk : in std_logic;

      -------------------------------------------------------------------------
      -- Communication Interface interface
      -------------------------------------------------------------------------

      bOutputStreamInterfaceToFifo   : in  OutputStreamInterfaceToFifo_t;
      bOutputStreamInterfaceFromFifo : out OutputStreamInterfaceFromFifo_t;

      -------------------------------------------------------------------------
      -- User VI interface for reading (all signals in ViClk domain)
      -------------------------------------------------------------------------

      -- User logic clock for all v-prefixed signals below
      ViClk          : in std_logic;

      -- Data output. Only valid when vOutputValid is true. Capture on that cycle.
      vDataOut       : out std_logic_vector(kSampleWidth*kNumOfSamplesPerRead-1 downto 0);

      -- FIFO empty status. Check before reading. Do not assert vReadFifo when true.
      vEmpty         : out boolean;

      -- Read strobe. Assert for exactly one ViClk cycle to pop data from the FIFO.
      vReadFifo      : in  boolean;

      -- Current number of elements in the FIFO. Valid every ViClk cycle.
      vCtCount       : out unsigned(31 downto 0);

      -- Data valid flag. When true, vDataOut holds valid data — capture it this cycle.
      vOutputValid     : out boolean;

      -- Handshaking: assert true when ready to accept data. Tie true if always ready.
      -- When false, the FIFO holds vDataOut stable until this is asserted.
      vReadyForOutput  : in  boolean;

      -------------------------------------------------------------------------
      -- User VI interface for stream state info and transitioning (ViClk domain)
      -------------------------------------------------------------------------

      -- Current stream state. Only read data when this equals kStreamStateEnabled ("10").
      vStreamStateOut             : out StreamStateValue_t;

      -- Strobe: assert for one ViClk cycle to request Disabled -> Enabled transition.
      vStartStreamRequest         : in  boolean;

      -- Strobe: assert for one ViClk cycle to request immediate stop (Enabled -> Disabled).
      vStopRequestStrobe          : in  boolean

    );
end NiSharedFifoReader;


architecture structure of NiSharedFifoReader is
begin

  NiSharedFifoReaderCorex: entity work.NiSharedFifoReaderCore (structure)
    generic map (
      kFifoDepth            => kFifoDepth,
      kSampleWidth          => kSampleWidth,
      kNumOfSamplesPerRead  => kNumOfSamplesPerRead,
      kFxpType              => kFxpType,
      kPeerToPeer           => kPeerToPeer,
      kDisableOnFifoTimeout => kDisableOnFifoTimeout)
    port map (
      aDiagramReset                  => aDiagramReset,
      aBusReset                      => aBusReset,
      BusClk                         => BusClk,
      bOutputStreamInterfaceToFifo   => bOutputStreamInterfaceToFifo,
      bOutputStreamInterfaceFromFifo => bOutputStreamInterfaceFromFifo,
      ViClk                          => ViClk,
      vDataOut                       => vDataOut,
      vEmpty                         => vEmpty,
      vReadFifo                      => vReadFifo,
      vCtCount                       => vCtCount,
      vOutputValid                   => vOutputValid,
      vReadyForOutput                => vReadyForOutput,
      vStreamStateOut                => vStreamStateOut,
      vStartStreamRequest            => vStartStreamRequest,
      vStopRequestStrobe             => vStopRequestStrobe);

  -- synthesis translate_off
  -- Simulation-only protocol monitor. Continuously asserts that the user logic
  -- hooked up to this Reader honors the FIFO read contract (data only emerges
  -- while Enabled, known data on valid cycles, one stream request per cycle). It
  -- is passive (reads the user-side ports only) and is fenced out of synthesis,
  -- so every consumer that instantiates NiSharedFifoReader gets the check for
  -- free in simulation at zero hardware cost.
  ReaderProtocolCheck : entity work.NiSharedFifoReaderChecker
    generic map (
      kName        => "NiSharedFifoReader",
      kSampleWidth => kSampleWidth*kNumOfSamplesPerRead
    )
    port map (
      ViClk               => ViClk,
      aReset              => aDiagramReset or aBusReset,
      vEmpty              => vEmpty,
      vReadFifo           => vReadFifo,
      vOutputValid        => vOutputValid,
      vReadyForOutput     => vReadyForOutput,
      vDataOut            => vDataOut,
      vStreamStateOut     => vStreamStateOut,
      vStartStreamRequest => vStartStreamRequest,
      vStopRequestStrobe  => vStopRequestStrobe,
      ViolationCount      => open
    );
  -- synthesis translate_on

end structure;
