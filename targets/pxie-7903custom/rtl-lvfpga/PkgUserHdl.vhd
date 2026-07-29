------------------------------------------------------------------------------------------
--
-- File: PkgUserHdl.vhd
--
------------------------------------------------------------------------------------------
-- (c) 2026 Copyright National Instruments Corporation
--
-- SPDX-License-Identifier: MIT
------------------------------------------------------------------------------------------
--
-- Purpose:
--   User-editable configuration constants for the UserHdl block:
--   DMA FIFO channel definitions, demo register layout, and FIFO register
--   layout.
--
--
------------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;
  use work.PkgCommIntConfiguration.all;
  use work.PkgNiSharedFifo.all;
  use work.PkgNiHdlSettings.all;

package PkgUserHdl is

  ---------------------------------------------------------------------------
  -- DMA FIFO channel configuration
  ---------------------------------------------------------------------------
  -- The number of channels (kNumHdlFifos) is the single source of truth from
  -- nihdlsettings.py (set_num_hdl_fifos), pushed into the HDL via the generated
  -- PkgNiHdlSettings package. If the kUserHdlDmaFifoConf aggregate below does
  -- not have exactly kNumHdlFifos elements, this package will fail to analyze
  -- (range/aggregate mismatch).

  -- DataType              : host data type for the FIFO. The element width and
  --                         signedness are derived automatically. Valid values:
  --                           kBoolean                 (Boolean, maps to U8)
  --                           kUnsigned8  / kInteger8  (U8  / I8)
  --                           kUnsigned16 / kInteger16 (U16 / I16)
  --                           kUnsigned32 / kInteger32 (U32 / I32)
  --                           kUnsigned64 / kInteger64 (U64 / I64)
  --                           kSingle                  (SGL, single-precision float)
  -- ElementsPerClockCycle : 1, 2, 4, 8, 16, 32, or 64
  -- Mode                  : NiFpgaHostToTarget or NiFpgaTargetToHost
  --
  -- FifoDepth (TargetToHost / PeerToPeer Writer):
  --   2^N - 1, minimum 63, maximum 1048575 (2^20 -1)
  --
  -- FifoDepth (HostToTarget / PeerToPeer Reader):
  -- *** NOTE: For HostToTarget FIFOs, add 6*ElementsPerClockCycle to the desired size of the FIFO to account for
  -- *** the additional buffering required for the NI DMA engine to achieve maximum throughput.
  --   (2^N + 6*(ElementsPerClockCycle)) -1

  -- for boolean data types, the max fifo width is 2097151 (2^21 - 1)
  -- for 16-bit data types, the max fifo width is 1048575 (2^20 - 1)
  -- for 32-bit data types, the max fifo width is 524287 (2^19 - 1)
  -- for 64-bit data types, the max fifo width is 262143 (2^18 - 1)

  constant kUserHdlDmaFifoConf : UserDmaFifoConfArray_t(0 to kNumHdlFifos - 1) := (
    0 => (FifoDepth => 1029, DataType => kInteger32, ElementsPerClockCycle => 1, Mode => NiFpgaHostToTarget),
    1 => (FifoDepth => 1023, DataType => kInteger32, ElementsPerClockCycle => 1, Mode => NiFpgaTargetToHost)
  );

  -- DERIVED - do not edit. Starting DMA channel index where the user HDL FIFOs
  -- are inserted, growing downward (UserConf(0) -> kUserHdlDmaStartIndex,
  -- UserConf(1) -> kUserHdlDmaStartIndex - 1, ...). The user HDL FIFOs occupy the
  -- DMA channels just below the fixed-logic streams. Both inputs come from the
  -- per-target generated packages:
  --   kNumberOfDmaChannels     - LV window config (PkgCommIntConfiguration)
  --   kNumFixedLogicDmaStreams - HDL settings      (PkgNiHdlSettings)
  constant kUserHdlDmaStartIndex : natural :=
    kNumberOfDmaChannels - 1 - kNumFixedLogicDmaStreams;

  ---------------------------------------------------------------------------
  -- Common host registers (4 registers starting at byte offset 0x00)
  ---------------------------------------------------------------------------
  -- 0x00: Signature              (host RO)
  -- 0x04: Version                (host RO)
  -- 0x08: OldestCompatibleVersion (host RO)
  -- 0x0C: Scratch                (host R/W)

  ---------------------------------------------------------------------------
  -- Demo register array (4 registers starting at byte offset 0x10)
  ---------------------------------------------------------------------------
  constant kDemoRegsBaseAddress : natural := 16#10#;
  constant kNumDemoRegs : natural := 4;

  constant kLoopbackInAIdx  : natural := 0;  -- offset 0x10: host R/W input A
  constant kLoopbackInBIdx  : natural := 1;  -- offset 0x14: host R/W input B
  constant kLoopbackOutAIdx : natural := 2;  -- offset 0x18: host RO output (A+1)
  constant kLoopbackOutBIdx : natural := 3;  -- offset 0x1C: host RO output (B+1)

  ---------------------------------------------------------------------------
  -- FIFO register array (9 registers starting at byte offset 60)
  ---------------------------------------------------------------------------
  constant kFifoRegsBaseAddress : natural := 16#3C#;
  constant kNumFifoRegs : natural := 9;

  constant kWriterStartStopIdx : natural := 0;  -- offset 60
  constant kReaderStartStopIdx : natural := 1;  -- offset 64
  constant kWriterCountIdx     : natural := 2;  -- offset 68
  constant kReaderCountIdx     : natural := 3;  -- offset 72
  constant kWriterStateIdx     : natural := 4;  -- offset 76
  constant kReaderStateIdx     : natural := 5;  -- offset 80
  constant kWriterDataIdx      : natural := 6;  -- offset 84
  constant kReaderStrobeIdx    : natural := 7;  -- offset 88
  constant kReaderDataIdx      : natural := 8;  -- offset 92

  ---------------------------------------------------------------------------
  -- Digital IO (base-board DIO) register array (3 registers starting at 0x20)
  ---------------------------------------------------------------------------
  -- The base-board DIO bus (aDio, kNumDioLines = 8 lines) is exposed to the
  -- host as three registers. This target has NO external direction handshake
  -- (aDio is a direct bidirectional FPGA pin bus), so the FPGA tristates the
  -- bus itself:
  --   0x20 Direction  (host R/W) bit N: 1 = output, 0 = input
  --   0x24 OutputData (host R/W) bit N: value driven on line N when it is an
  --                                     output
  --   0x28 Status     (host RO)  [7:0]  live input sample per line
  -- Placed in the address gap between the demo array (ends 0x1C) and the FIFO
  -- array (starts 0x3C), so it does not extend kMaxHdlRegOffset.
  constant kDioRegsBaseAddress : natural := 16#20#;
  constant kNumDioRegs  : natural := 3;
  constant kNumDioLines : natural := 8;

  constant kDioDirectionIdx  : natural := 0;  -- offset 0x20: host R/W direction
  constant kDioOutputDataIdx : natural := 1;  -- offset 0x24: host R/W output data
  constant kDioStatusIdx     : natural := 2;  -- offset 0x28: host RO input

end PkgUserHdl;
