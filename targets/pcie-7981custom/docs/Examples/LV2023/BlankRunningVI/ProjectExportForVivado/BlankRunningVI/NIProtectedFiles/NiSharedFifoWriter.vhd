-------------------------------------------------------------------------------
--
-- File: NiSharedFifoWriter.vhd
--
-------------------------------------------------------------------------------
-- (c) Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--
--   User-facing DMA input (target-to-host) FIFO entity.
--
--   This is the top-level entity that users instantiate to write data from
--   FPGA logic into a DMA FIFO for transfer to the host.  Internally it
--   wraps NiSharedFifoWriterCore.
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

entity NiSharedFifoWriter is
    generic(

      -- kFifoDepth      : This is the size of the DMA FIFO in terms of bus
      --                   data width words.
      kFifoDepth         : natural  := 1024;

      -- kSampleWidth    : This is the width of one sample coming from the
      --                   user VI.
      kSampleWidth       : positive := 32;

      -- kNumOfSamplesPerWrite : Number of samples written to the FIFO at one
      --                        time.
      kNumOfSamplesPerWrite : positive := 1;

      -- kSignExtend     : This boolean controls whether or not to sign extend
      --                   the data before it is sent to the host.
      kSignExtend        : boolean := false;

      -- kFxpType        : This boolean indicates whether the data type is a
      --                   FXP type.
      kFxpType           : boolean  := false;

      -- kPeerToPeer     : This boolean indicates whether the stream is a
      --                   normal target to host stream or a peer-to-peer
      --                   source stream.
      kPeerToPeer        : boolean := false;

      -- kDisableOnFifoTimeout : This sets whether or not the stream disables
      --                         when an overflow/underflow occurs.
      kDisableOnFifoTimeout : boolean

    );
    port(

      -- The asynchronous reset for the stream circuit
      aDiagramReset : in boolean;

      aBusReset : in boolean;

      -- The IO Port 2 transmit clock
      BusClk : in std_logic;

      -------------------------------------------------------------------------
      -- Communication Interface interface
      -------------------------------------------------------------------------

      bInputStreamInterfaceToFifo   : in  InputStreamInterfaceToFifo_t;
      bInputStreamInterfaceFromFifo : out InputStreamInterfaceFromFifo_t;

      -------------------------------------------------------------------------
      -- User VI interface for writing (all signals in ViClk domain)
      -------------------------------------------------------------------------

      -- User logic clock for all v-prefixed signals below
      ViClk          : in std_logic;

      -- Data to write. Must be stable on the cycle vWriteFifo is asserted.
      vDataIn        : in  std_logic_vector(kSampleWidth*kNumOfSamplesPerWrite-1 downto 0);

      -- FIFO full status. Check before writing. Do not assert vWriteFifo when true.
      vFull          : out boolean;

      -- Write strobe. Assert for exactly one ViClk cycle to push vDataIn into the FIFO.
      vWriteFifo     : in  boolean;

      -- Flush strobe. Assert to flush partial data to host. Tie false if unused.
      vFlush         : in  boolean;

      -- Current number of elements in the FIFO. Valid every ViClk cycle.
      vCtCount       : out unsigned(31 downto 0);

      -- Handshaking: assert true when vDataIn is valid and ready to be written.
      vInputValid    : in  boolean;

      -- Handshaking: FIFO is ready to accept data. Check before writing in handshake mode.
      vReadyForInput : out boolean;

      -------------------------------------------------------------------------
      -- User VI interface for stream state info and transitioning (ViClk domain)
      -------------------------------------------------------------------------

      -- Current stream state. Only write data when this equals kStreamStateEnabled ("10").
      vStreamStateOut             : out StreamStateValue_t;

      -- Strobe: assert for one ViClk cycle to request Disabled -> Enabled transition.
      vStartStreamRequest         : in  boolean;

      -- Strobe: assert for one ViClk cycle to request immediate stop (Enabled -> Disabled).
      vStopRequestStrobe          : in  boolean;

      -- Strobe: assert to trigger flush timeout. Tie false if unused.
      vFlushTimeoutRequest        : in  boolean;

      -- Strobe: assert for one ViClk cycle to flush all data then stop.
      vStopWithFlushRequestStrobe : in  boolean

    );
end NiSharedFifoWriter;


architecture structure of NiSharedFifoWriter is
begin

  NiSharedFifoWriterCorex: entity work.NiSharedFifoWriterCore (structure)
    generic map (
      kFifoDepth            => kFifoDepth,
      kSampleWidth          => kSampleWidth,
      kNumOfSamplesPerWrite => kNumOfSamplesPerWrite,
      kSignExtend           => kSignExtend,
      kFxpType              => kFxpType,
      kPeerToPeer           => kPeerToPeer,
      kDisableOnFifoTimeout => kDisableOnFifoTimeout)
    port map (
      aDiagramReset                 => aDiagramReset,
      aBusReset                     => aBusReset,
      BusClk                        => BusClk,
      bInputStreamInterfaceToFifo   => bInputStreamInterfaceToFifo,
      bInputStreamInterfaceFromFifo => bInputStreamInterfaceFromFifo,
      ViClk                         => ViClk,
      vDataIn                       => vDataIn,
      vFull                         => vFull,
      vWriteFifo                    => vWriteFifo,
      vFlush                        => vFlush,
      vCtCount                      => vCtCount,
      vInputValid                   => vInputValid,
      vReadyForInput                => vReadyForInput,
      vStreamStateOut               => vStreamStateOut,
      vStartStreamRequest           => vStartStreamRequest,
      vStopRequestStrobe            => vStopRequestStrobe,
      vFlushTimeoutRequest          => vFlushTimeoutRequest,
      vStopWithFlushRequestStrobe   => vStopWithFlushRequestStrobe);

  -- synthesis translate_off
  -- Simulation-only protocol monitor. Continuously asserts that the user logic
  -- hooked up to this Writer honors the FIFO write contract (no write while
  -- full, known data on write cycles, one stream request per cycle). It is
  -- passive (reads the user-side ports only) and is fenced out of synthesis, so
  -- every consumer that instantiates NiSharedFifoWriter gets the check for free
  -- in simulation at zero hardware cost.
  WriterProtocolCheck : entity work.NiSharedFifoWriterChecker
    generic map (
      kName        => "NiSharedFifoWriter",
      kSampleWidth => kSampleWidth*kNumOfSamplesPerWrite
    )
    port map (
      ViClk                       => ViClk,
      aReset                      => aDiagramReset or aBusReset,
      vFull                       => vFull,
      vWriteFifo                  => vWriteFifo,
      vInputValid                 => vInputValid,
      vDataIn                     => vDataIn,
      vStreamStateOut             => vStreamStateOut,
      vStartStreamRequest         => vStartStreamRequest,
      vStopRequestStrobe          => vStopRequestStrobe,
      vStopWithFlushRequestStrobe => vStopWithFlushRequestStrobe,
      ViolationCount              => open
    );
  -- synthesis translate_on

end structure;
