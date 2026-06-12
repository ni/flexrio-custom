------------------------------------------------------------------------------------------
--
-- File: FifoLoopbackPair.vhd
--
------------------------------------------------------------------------------------------
-- (c) 2026 Copyright National Instruments Corporation
--
-- SPDX-License-Identifier: MIT
------------------------------------------------------------------------------------------
--
-- Purpose:
--   A self-contained DMA FIFO loopback pair for the FIFO test suite.
--
--   Instantiates one NiSharedFifoReader (Host-to-Target) and one
--   NiSharedFifoWriter (Target-to-Host) and wires them together in hardware:
--   data the host streams into the Reader FIFO is automatically moved into
--   the Writer FIFO and streamed back out to the host.
--
--   The block is parameterized by sample width, elements per clock, and FIFO
--   depth so that multiple instances with different data types can be
--   instantiated to exercise more FIFO scenarios. The Reader and Writer share
--   the same total data width (kSampleWidth * kElementsPerClockCycle) so the
--   popped element can be pushed directly into the Writer.
--
--   Stream start/stop control is exposed as request strobes; element counts
--   and stream states are exposed as status outputs so the parent can map
--   them to host registers.
--
------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.PkgNiUtilities.all;
use work.PkgCommunicationInterface.all;
use work.PkgDmaPortCommunicationInterface.all;
use work.PkgDmaPortDmaFifos.all;
use work.PkgDmaPortCommIfcStreamStates.all;
use work.PkgNiSharedFifo.all;

entity FifoLoopbackPair is
  generic(
    -- Host-to-Target (Reader) FIFO depth: (2^N + 6*ElementsPerClockCycle) - 1
    kReaderFifoDepth       : natural := 1029;
    -- Target-to-Host (Writer) FIFO depth: 2^N - 1
    kWriterFifoDepth       : natural := 1023;
    -- Bit width of a single element (shared by Reader and Writer)
    kSampleWidth           : natural := 32;
    -- Elements transferred per clock cycle (1, 2, 4, 8, 16, 32, 64)
    kElementsPerClockCycle : natural := 1;
    -- true if the host data type is signed (enables Writer sign extension)
    kSignedData            : boolean := true;
    -- true if the host data type is fixed point
    kFxpType               : boolean := false
  );
  port(
    BusClk         : in  std_logic;
    DmaClk         : in  std_logic;
    aBusReset      : in  boolean;
    abDiagramReset : in  boolean;

    -- Writer FIFO (Target-to-Host) DMA stream interface
    -- Input direction active; Output direction driven to zero internally
    dWriterInputStreamInterfaceToFifo    : in  InputStreamInterfaceToFifo_t;
    dWriterInputStreamInterfaceFromFifo  : out InputStreamInterfaceFromFifo_t;
    dWriterOutputStreamInterfaceToFifo   : in  OutputStreamInterfaceToFifo_t;
    dWriterOutputStreamInterfaceFromFifo : out OutputStreamInterfaceFromFifo_t;

    -- Reader FIFO (Host-to-Target) DMA stream interface
    -- Output direction active; Input direction driven to zero internally
    dReaderInputStreamInterfaceToFifo    : in  InputStreamInterfaceToFifo_t;
    dReaderInputStreamInterfaceFromFifo  : out InputStreamInterfaceFromFifo_t;
    dReaderOutputStreamInterfaceToFifo   : in  OutputStreamInterfaceToFifo_t;
    dReaderOutputStreamInterfaceFromFifo : out OutputStreamInterfaceFromFifo_t;

    -- Stream start/stop control (one-cycle request strobes, BusClk domain)
    bWriterStartReq : in  boolean;
    bWriterStopReq  : in  boolean;
    bReaderStartReq : in  boolean;
    bReaderStopReq  : in  boolean;

    -- Status outputs (BusClk domain)
    bWriterCtCount     : out unsigned(31 downto 0);
    bReaderCtCount     : out unsigned(31 downto 0);
    bWriterStreamState : out StreamStateValue_t;
    bReaderStreamState : out StreamStateValue_t
  );
end entity FifoLoopbackPair;

architecture rtl of FifoLoopbackPair is

  -- Total data width shared by the Reader and Writer FIFOs
  constant kTotalWidth : natural := kSampleWidth * kElementsPerClockCycle;

  -- FIFO-to-FIFO loopback state: true while a Reader pop is in flight
  signal bLoopbackReadPending : boolean := false;

  -- Writer FIFO user interface signals (BusClk domain)
  signal bWriterFifoWriteStrobe   : boolean := false;
  signal bWriterFifoDataIn        : std_logic_vector(kTotalWidth-1 downto 0) := (others => '0');
  signal bWriterFifoInputValid    : boolean := false;
  signal bWriterFifoReadyForInput : boolean;
  signal bWriterFifoFull          : boolean;
  signal bWriterFifoCtCount       : unsigned(31 downto 0);
  signal bWriterFifoStreamState   : StreamStateValue_t;

  -- Reader FIFO user interface signals (BusClk domain)
  signal bReaderFifoDataOut      : std_logic_vector(kTotalWidth-1 downto 0);
  signal bReaderFifoEmpty        : boolean;
  signal bReaderFifoReadStrobe   : boolean := false;
  signal bReaderFifoOutputValid  : boolean;
  signal bReaderFifoCtCount      : unsigned(31 downto 0);
  signal bReaderFifoStreamState  : StreamStateValue_t;

begin

  ---------------------------------------------------------------------------
  -- Writer FIFO (Target-to-Host)
  ---------------------------------------------------------------------------
  WriterFifo_inst : entity work.NiSharedFifoWriter
    generic map(
      kFifoDepth            => kWriterFifoDepth,
      kSampleWidth          => kSampleWidth,
      kNumOfSamplesPerWrite => kElementsPerClockCycle,
      kSignExtend           => kSignedData,
      kFxpType              => kFxpType,
      kPeerToPeer           => false,
      kDisableOnFifoTimeout => false
    )
    port map(
      aDiagramReset                 => abDiagramReset,
      aBusReset                     => aBusReset,
      BusClk                        => DmaClk,
      bInputStreamInterfaceToFifo   => dWriterInputStreamInterfaceToFifo,
      bInputStreamInterfaceFromFifo => dWriterInputStreamInterfaceFromFifo,
      ViClk                         => BusClk,
      vDataIn                       => bWriterFifoDataIn,
      vFull                         => bWriterFifoFull,
      vWriteFifo                    => bWriterFifoWriteStrobe,
      vFlush                        => false,
      vCtCount                      => bWriterFifoCtCount,
      vInputValid                   => bWriterFifoInputValid,
      vReadyForInput                => bWriterFifoReadyForInput,
      vStreamStateOut               => bWriterFifoStreamState,
      vStartStreamRequest           => bWriterStartReq,
      vStopRequestStrobe            => bWriterStopReq,
      vFlushTimeoutRequest          => false,
      vStopWithFlushRequestStrobe   => false
    );

  ---------------------------------------------------------------------------
  -- Reader FIFO (Host-to-Target)
  ---------------------------------------------------------------------------
  ReaderFifo_inst : entity work.NiSharedFifoReader
    generic map(
      kFifoDepth            => kReaderFifoDepth,
      kSampleWidth          => kSampleWidth,
      kNumOfSamplesPerRead  => kElementsPerClockCycle,
      kFxpType              => kFxpType,
      kPeerToPeer           => false,
      kDisableOnFifoTimeout => false
    )
    port map(
      aDiagramReset                  => abDiagramReset,
      aBusReset                      => aBusReset,
      BusClk                         => DmaClk,
      bOutputStreamInterfaceToFifo   => dReaderOutputStreamInterfaceToFifo,
      bOutputStreamInterfaceFromFifo => dReaderOutputStreamInterfaceFromFifo,
      ViClk                          => BusClk,
      vDataOut                       => bReaderFifoDataOut,
      vEmpty                         => bReaderFifoEmpty,
      vReadFifo                      => bReaderFifoReadStrobe,
      vCtCount                       => bReaderFifoCtCount,
      vOutputValid                   => bReaderFifoOutputValid,
      vReadyForOutput                => true,
      vStreamStateOut                => bReaderFifoStreamState,
      vStartStreamRequest            => bReaderStartReq,
      vStopRequestStrobe             => bReaderStopReq
    );

  ---------------------------------------------------------------------------
  -- FIFO-to-FIFO loopback
  --
  -- Data the host streams into the Reader FIFO (Host-to-Target) is
  -- automatically popped and pushed into the Writer FIFO (Target-to-Host),
  -- where the host streams it back out. One element is moved at a time:
  -- a pop is only issued when the Reader has data and the Writer has room,
  -- and the popped element is written once the Reader presents valid data.
  ---------------------------------------------------------------------------
  FifoLoopback : process(BusClk)
  begin
    if aBusReset then
      bReaderFifoReadStrobe  <= false;
      bWriterFifoWriteStrobe <= false;
      bWriterFifoInputValid  <= false;
      bWriterFifoDataIn      <= (others => '0');
      bLoopbackReadPending   <= false;
    elsif rising_edge(BusClk) then
      bReaderFifoReadStrobe  <= false;
      bWriterFifoWriteStrobe <= false;
      bWriterFifoInputValid  <= false;

      -- Push popped Reader data into the Writer FIFO once it becomes valid
      if bReaderFifoOutputValid then
        bWriterFifoDataIn      <= bReaderFifoDataOut;
        bWriterFifoInputValid  <= true;
        bWriterFifoWriteStrobe <= true;
        bLoopbackReadPending   <= false;
      end if;

      -- Issue a new Reader pop only when both streams are enabled, the Reader
      -- has data, the Writer has room, and no pop is already in flight.
      --
      -- Gate the pop on the element COUNT (bReaderFifoCtCount > 0), not on the
      -- empty flag. vEmpty is derived from the FIFO underflow flag and can lag
      -- the count by a cycle as the FIFO drains to empty. Using vEmpty here let
      -- the engine issue one extra pop right at the drain-to-empty boundary;
      -- that read-while-empty never returns vOutputValid, so bLoopbackReadPending
      -- latched true forever and the loopback wedged after the first batch. The
      -- count is the authoritative number of elements present, so popping only
      -- when it is non-zero guarantees every pop returns vOutputValid.
      if not bLoopbackReadPending and bReaderFifoCtCount > 0 and not bWriterFifoFull
         and bReaderFifoStreamState = kStreamStateEnabled
         and bWriterFifoStreamState = kStreamStateEnabled then
        bReaderFifoReadStrobe <= true;
        bLoopbackReadPending  <= true;
      end if;
    end if;
  end process FifoLoopback;

  ---------------------------------------------------------------------------
  -- Status outputs
  ---------------------------------------------------------------------------
  bWriterCtCount     <= bWriterFifoCtCount;
  bReaderCtCount     <= bReaderFifoCtCount;
  bWriterStreamState <= bWriterFifoStreamState;
  bReaderStreamState <= bReaderFifoStreamState;

  ---------------------------------------------------------------------------
  -- Drive unused-direction FromFifo signals to zero
  -- (same pattern as DmaPortCommIfcFifos: Input channels zero the Output
  --  FromFifo, Output channels zero the Input FromFifo)
  ---------------------------------------------------------------------------
  dWriterOutputStreamInterfaceFromFifo <= kOutputStreamInterfaceFromFifoZero;
  dReaderInputStreamInterfaceFromFifo  <= kInputStreamInterfaceFromFifoZero;

end rtl;
