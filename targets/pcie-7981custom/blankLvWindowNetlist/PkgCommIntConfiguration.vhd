-- © 2012 National Instruments Corporation.
-------------------------------------------------------------------------------
--
-- File: PkgComIntConfiguration.vhd
-- Author: Claudiu Chirap, Florin Hurgoi, Daria Tioc-Deac
-- Original Project: DmaPort Communication Interface
-- Date: 2 February 2012
--
-------------------------------------------------------------------------------
--
-- Purpose:
--
--   This package is only intended to configure the package
--   PkgCommunicationInterface. It is dynamically generated from G code based
--   on configuration of the plug-in used.
--
-------------------------------------------------------------------------------

library ieee, work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.PkgNiUtilities.all;

package PkgCommIntConfiguration is

  -- CONSTANTS AND TYPES----------------------------------------------------------------

  -- Constants that configure the communication interface
    constant kAddressWidth          : positive := 19;
  constant kNumberOfDmaChannels   : natural  := 64;
  constant kNumberOfIrqs          : natural  := 1;
  constant kNumberOfMasterPorts   : natural  := 64;
  constant kNiFpgaFixedInputPorts : natural := 3;
  constant kNiFpgaFixedOutputPorts : natural := 2;
  constant kIrqBaseOffset         : natural  := 16#2FFE4#;
  constant kCommunicationTimeout  : natural  := 512;
  constant kFifoWriteWindow       : natural  := 4096;
  constant kFifoReadLatency       : natural  := 4;
  constant kAutoRun               : boolean  := false;
  constant kDmaDataWidth          : positive := 256;
  constant kDmaAddressWidth       : positive := 64;
  constant kBusBaggageWidth       : natural  := 6;
  constant kInputMaxTransfer      : natural  := 1024;
  constant kOutputMaxTransfer     : natural  := 1024;

  -- The two constants below define the address range allocated for writing
  -- HighSpeedSink FIFOs.  kDmaHighSpeedSinkSize needs to be a power-of-two
  -- and kDmaHighSpeedSinkBase needs to be naturally aligned to a boundary of
  -- kDmaHighSpeedSinkSize.
  -- If kDmaHighSpeedSinkBase is 0 and kDmaHighSpeedSinkSize is 1, then P2P
  -- is not supported on the respective target.
  constant kDmaHighSpeedSinkBase     : natural  :=  16#80000#;
  constant kDmaHighSpeedSinkSize     : positive  :=  16#40000#;

  -- Constants that configure the InChWORM
    constant kInputMaxRequests      : natural := 2;
  constant kOutputMaxRequests     : natural := 2;
  constant kInputDataBuffer       : natural := 2;

  constant kDmaRegBase              : natural := 16#1000#;
  constant kDmaRegSize              : positive := 16#1000#;

  constant kEnableByteSwapper       : boolean := false;
  constant kEnableLatchingTtc       : boolean := false;
  constant kTtcWidth                : natural := 1;
  constant kEnableFullScatterGather : boolean := false;
  constant kMaxChunkyLinkSize       : natural := 32;
  constant kLinkFetchMaxRequests    : natural := 1;

  constant kMaxMuxWidth             : natural := 8;

  constant kAxiMasterMaxBurstLength : integer := 2;
  constant kAxiSlaveBaseAddress : natural := 16#2#;
  constant kAxiSlaveIdWidth : integer := 1;
  constant kAxiMasterIdWidth : integer := 1;

  type MasterPortMode_t is (
    Disabled, -- MasterPort is disabled
    NiFpgaMasterPortWrite, -- MasterPort is only writer
    NiFpgaMasterPortRead, -- MasterPort is only reader
    NiFpgaMasterPortWriteRead -- MasterPort is both writer and reader
    );

  type MasterPortConfiguration_t is record
    Mode : MasterPortMode_t;
  end record;

  type MasterPortConfArray_t is array (natural range <>)
    of MasterPortConfiguration_t;

  constant kMasterPortConfArray : MasterPortConfArray_t(0 to kNumberOfMasterPorts - 1) := (
(Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
, (Mode => Disabled)
);


  type DmaChannelMode_t is (
    Disabled,               -- channel is disabled (no hardware generated).
    NiFpgaTargetToHost,     -- input mode using modified mite read interface
    NiFpgaHostToTarget,     -- output mode using modified mite write interface
    NiCoreTargetToHost,     -- input mode using standard nicore mite read interface
    NiCoreHostToTarget,     -- output mode using standard nicore mite write interface
    NiFpgaPeerToPeerWriter, -- peer to peer input channel
    NiFpgaPeerToPeerReader  -- peer to peer output channel
    );
  
  type DmaChannelConfiguration_t is record
    Mode                  : DmaChannelMode_t;
    FifoDepth             : natural;
    FifoWidth             : natural;
    ElementsPerClockCycle : natural;
    SignedData            : boolean;
    BaseAddress           : natural;
    SCL                   : boolean;
    CountSCL              : boolean;
    FxpType               : boolean;
    DisableOnFifoTimeout  : boolean;
    WriteWindowOffset     : natural;
    DmaClkIsDefaultClk    : boolean;
    InterfaceIsHandshaking: boolean;
  end record;

  type DmaChannelConfArray_t is array (natural range <>)
    of DmaChannelConfiguration_t;

  constant kDmaChannelConfigurationZero : DmaChannelConfiguration_t :=
    (FifoDepth              => 0,
     FifoWidth              => 0,
     ElementsPerClockCycle  => 0,
     SignedData             => false,
     BaseAddress            => 0,
     Mode                   => Disabled,
     SCL                    => false,
     CountSCL               => false,
     FxpType                => false,
     DisableOnFifoTimeout   => false,
     WriteWindowOffset      => 0,
     DmaClkIsDefaultClk     => false,
     InterfaceIsHandshaking => false);

    constant kDmaFifoConfArray : DmaChannelConfArray_t(0 to kNumberOfDmaChannels-1) :=
(    (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
,     (FifoDepth => 0, 
    FifoWidth => 0,
    SignedData => false, 
    BaseAddress =>16#0#,
    SCL => false,
    CountSCL => false,
    FxpType => false,
    DisableOnFifoTimeout => false,
    WriteWindowOffset => 16#0#,
    DmaClkIsDefaultClk => false,
    Mode => Disabled,
    ElementsPerClockCycle => 0,
    InterfaceIsHandshaking => false)
);


  -- FUNCTIONS ----------------------------------------------------------------

  -- Function to return the depths of the DMA FIFOs in samples.
  function GetFifoDepthsInSamples(ChannelConfig: DmaChannelConfArray_t)
    return DmaChannelConfArray_t;
  
  function DmaMaxWidth(unused : boolean) return natural;
  function DmaMaxDepth(unused : boolean) return positive;
 
  -- Functions to return the number of DMA input, output and sink channels.  
  function NumOfInStrms(Arg : DmaChannelConfArray_t) return natural;
  function NumOfOutStrms(Arg : DmaChannelConfArray_t) return natural;
  function NumOfSinkStrms(Arg : DmaChannelConfArray_t) return natural;

  --Functions to return the numbert of Write and Read Master Ports.
  function NumOfWriteMasterPorts(Arg : MasterPortConfArray_t) return natural;
  function NumOfReadMasterPorts(Arg : MasterPortConfArray_t) return natural;
  
end PkgCommIntConfiguration;

-------------------------------------------------------------------------------
-- PKGCOMMINTCONFIGURATION BODY
-------------------------------------------------------------------------------

package body PkgCommIntConfiguration is

  -- This function returns an array of the FIFO depths in samples.
  -- The values passed in should come directly from PkgCommIntConfiguration.
  function GetFifoDepthsInSamples(ChannelConfig: DmaChannelConfArray_t)
    return DmaChannelConfArray_t is

    variable ReturnVal : DmaChannelConfArray_t(ChannelConfig'range);

  begin
    -- Set the configuration output equal to the configuration input.
    ReturnVal := ChannelConfig;

    -- Find the depth for each channel.  
    for i in ChannelConfig'range loop
      -- An output channel needs to subtract the size of the pop buffer.
      if ChannelConfig(i).Mode = NiFpgaTargetToHost or
         ChannelConfig(i).Mode = NiFpgaPeerToPeerWriter then
        ReturnVal(i).FifoDepth := ChannelConfig(i).FifoDepth;
      else
        ReturnVal(i).FifoDepth := ChannelConfig(i).FifoDepth -
					              ChannelConfig(i).ElementsPerClockCycle * 6;
      end if;
    end loop;
    return ReturnVal;
  end GetFifoDepthsInSamples;

  function DmaMaxWidth(unused : boolean) return natural is
    variable maxWidth : natural := 1;
  begin
    for i in 0 to kNumberOfDmaChannels-1 loop
      maxWidth := Larger(maxWidth,
                    kDmaFifoConfArray(i).FifoWidth*kDmaFifoConfArray(i).ElementsPerClockCycle);
    end loop;
    return maxWidth;
  end DmaMaxWidth;

  function DmaMaxDepth(unused : boolean) return positive is
    variable maxDepth : positive := 1;
  begin
    for i in 0 to kNumberOfDmaChannels-1 loop
      maxDepth := Larger(maxDepth, kDmaFifoConfArray(i).FifoDepth);
    end loop;
    return maxDepth;
  end DmaMaxDepth;

  -- This function returns the number of used DMA input channels.  
  function NumOfInStrms(Arg : DmaChannelConfArray_t) 
  return natural is
    variable ReturnVal : natural;
  begin
    ReturnVal := 0;
    for i in arg'range loop
      if Arg(i).Mode = NiFpgaTargetToHost or Arg(i).Mode = NiFpgaPeerToPeerWriter then
        ReturnVal := ReturnVal + 1;
      end if;
    end loop;
    return ReturnVal;
  end NumOfInStrms;
  
  -- This function returns the number of used DMA output channels.  This includes
  -- peer-to-peer sink streams.
  function NumOfOutStrms(Arg : DmaChannelConfArray_t) 
  return natural is
    variable ReturnVal : natural;
  begin
    ReturnVal := 0;
    for i in arg'range loop
      if Arg(i).Mode = NiFpgaHostToTarget then
        ReturnVal := ReturnVal + 1;
      end if;
    end loop;
    return ReturnVal;
  end NumOfOutStrms;

  -- This function returns the number of used DMA sink channels.  
  function NumOfSinkStrms(Arg : DmaChannelConfArray_t) 
  return natural is
    variable ReturnVal : natural;
  begin
    ReturnVal := 0;
    for i in arg'range loop
      if Arg(i).Mode = NiFpgaPeerToPeerReader then
        ReturnVal := ReturnVal + 1;
      end if;
    end loop;
    return ReturnVal;
  end NumOfSinkStrms;

  -- This function returns the number of used Write Master Ports.  
  function NumOfWriteMasterPorts(Arg : MasterPortConfArray_t) 
  return natural is
    variable ReturnVal : natural;
  begin
    ReturnVal := 0;
    for i in arg'range loop
      if Arg(i).Mode = NiFpgaMasterPortWriteRead or Arg(i).Mode = NiFpgaMasterPortWrite then
        ReturnVal := ReturnVal + 1;
      end if;
    end loop;
    return ReturnVal;
  end NumOfWriteMasterPorts;
  
  -- This function returns the number of used DMA output channels.  This includes
  -- peer-to-peer sink streams.
  function NumOfReadMasterPorts(Arg : MasterPortConfArray_t) 
  return natural is
    variable ReturnVal : natural;
  begin
    ReturnVal := 0;
    for i in arg'range loop
      if Arg(i).Mode = NiFpgaMasterPortWriteRead or Arg(i).Mode = NiFpgaMasterPortRead then
        ReturnVal := ReturnVal + 1;
      end if;
    end loop;
    return ReturnVal;
  end NumOfReadMasterPorts;
  
end PkgCommIntConfiguration;
