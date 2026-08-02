-------------------------------------------------------------------------------
--
-- File: PkgNiDmaConfig.vhd
-- Author: Glen Sescila
-- Original Project: NI DMA IP
-- Date: 27 May 2010
--
-------------------------------------------------------------------------------
-- (c) 2010 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
-- Configures the NI DMA IP.  Each design will modify this package based on the
-- bus technology and application requirements.
--
-- !!! THIS FILE WAS ADDED TO THE SIMULATION MODELS FOLDER TO MAKE SURE
-- IT IS EXCLUDED FROM THE DEPENDENCY LIST OF THE STATIC VHDL FILE
-- DMAPORTCOMMUNICATIONINTERFACE.VHD. NORMALLY THIS FILE IS PROVIDED BY THE 
-- CLIENT GROUP. THERE IS A PACKAGE WITH THIS EXACT NAME IN THE InChWORM
-- SIMULATION MODELS FOLDER. MODIFY THE REMOVAL EXPRESSIONS IN THE 
-- VSMAKESETTINGS FILE TO CHOOSE WHICH OF THE TWO PACKAGES YOU WANT
-- TO EXCLUDE FROM COMPILATION TO AVOID A DUPLICATE FILE NAME ERROR.
--
-- ADD *DmaPort*SimulationModels/PkgNiDmaConfig.vhd TO THE REMOVAL
-- EXPRESSIONS IF YOU WANT TO EXCLUDE THE DMAPORT VERSION OF THE PACKAGE,
-- ADD *InChWORM*SimulationModels/PkgNiDmaConfig.vhd TO EXCLUDE
-- THE INCHWORM VERSION OF THE PACKAGE.
-------------------------------------------------------------------------------
--*****************************************************************************
-- Some DMA files in this repo have been forked/duplicated into the hw-nicores AzDo git repository.
--
-- Before changing this file or any of its upstream/downstream dependencies, read the following:
--
--      CommInterfaces/DmaPort/README_DMA_FILES_FORK.md
--
--*****************************************************************************


library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  
library work;
  use work.PkgNiutilities.all;
  use work.PkgCommIntConfiguration.all;
  use work.PkgCommunicationInterface.all;

package PkgNiDmaConfig is

  -------------------------- Data Path Configuration --------------------------

  -- Width of the bus address.  Note that this can be configured based on the
  -- total address space that needs to be accessible, not necessarily the width
  -- of address that the bus protocol supports.  For example, an application
  -- might set this based on the amount of memory actually installed in the
  -- system.  Care should be taken to consider peer-to-peer use cases since
  -- that may require accessing address ranges at higher locations than the
  -- memory.
  constant kNiDmaAddressWidth : natural := kDmaAddressWidth;

  -- Width of the bus data.  This must be a power-of-two mutliple of 8.
  constant kNiDmaDataWidth : natural := kDmaDataWidth;

  -- Baggage is used for any bus-specific purpose.  PCIe example uses would be
  -- Traffic Classes and TLP Steering Tags.  On AXI the Baggage could be used
  -- to select which master interface the transaction should route to (SAM or
  -- ACP for example).  Each DMA channel or Direct Master can provide a
  -- programmable Baggage value but to the NI DMA IP and application hardware
  -- it serves no purpose.  The design of bus-specific logic determines how the
  -- Baggage value should be used.
  constant kNiDmaBaggageWidth : natural := kBusBaggageWidth;

  -- The maximum transfer size in bytes for Input and Output transactions.
  -- These must each be a power-of-two multiple of (kNiDmaDataWidth / 8).  The
  -- multiple must be four or greater.
  constant kNiDmaInputMaxTransfer : natural := kInputMaxTransfer;
  constant kNiDmaOutputMaxTransfer : natural := kOutputMaxTransfer;

  -- The number of Input and Output transactions that can be pending at once in
  -- the NI DMA IP.  Multiple transactions must be issued simultaneously in
  -- order to overcome pipeline and processing delays and sustain high
  -- streaming throughput.  For Output the number of simultaneous transactions
  -- needs to be set high enough to overcome the entire system round-trip
  -- latency.  If system round-trip latency is 5 us, then the design needs to
  -- simultaneously issue at least the number of transactions required to
  -- transfer 5 us worth of data at the desired bandwidth.  For Input the
  -- number of transactions necessary depends on characteristics of the bus
  -- technology.  If the NI DMA IP must wait to receive a response from the
  -- final destination of write transactions then the situation is no different
  -- than Output.  In this case Input needs to be configured for the number of
  -- simultaneous transactions required for the entire system round-trip
  -- latency.  If the bus technology posts writes and has appropriate ordering
  -- guarantees then Input can be configured for fewer simultaneous
  -- transactions.  In this case you only need enough transactions to overcome
  -- the latency through the NI DMA IP itself because transfers will be
  -- considered complete as soon as they post to the bus-speciifc logic.
  constant kNiDmaInputMaxRequests : natural := kInputMaxRequests;
  constant kNiDmaOutputMaxRequests : natural := kOutputMaxRequests;

  -- The number of max transfer data payloads that can be stored in the NI DMA
  -- IP Input data path at once.  The NI DMA IP has been designed to provide
  -- maximum bus streaming throughput even with very little data buffering in
  -- the NI DMA IP itself.  The key to this concept is that the NI DMA IP is in
  -- control over when data transfers from the application hardware so there is
  -- no need for deep buffering in the NI DMA IP.  The minimum allowed value
  -- for this field is 2 and it shouldn't be necessary to increase it.  This is
  -- just being made configurable in case testing determines that more data
  -- buffering is necessary.  No buffering is required in the Output data path
  -- since the NI DMA IP can transfer received data to application-specic logic
  -- at will.
  constant kNiDmaInputDataBuffer : natural := kInputDataBuffer;

  -- The number of DMA channels implemented.
  constant kNiDmaDmaChannels : natural := kNumberOfDmaChannels;

  -- The number of Direct Masters that needs to be supported.
  constant kNiDmaDirectMasters : natural := kNumberOfDmaChannels + kNumberOfMasterPorts;
  
  -- This constant specifies the latency between Pop and data on the Input Data
  -- Interface.  The minimum value is 1 which means data is valid the state
  -- after Pop.
  constant kNiDmaInputDataReadLatency : natural := kFifoReadLatency + 1;

  -------------------------- RegPort Configuration ----------------------------

  -- Width of the RegPort address.  The RegPort address only needs to be wide
  -- enough to access all register space within the endpoint.
  constant kNiDmaRegPortAddressWidth : natural := kAddressWidth;

  -- Width of the RegPort data.  This must be a power-of-two mutliple of 8.
  constant kNiDmaRegPortDataWidth : natural := InterfaceData_t'length;

  --   The two constants below specify the address range allocated for the DMA
  -- context memory on RegPort.  InChWORM will respond to this entire range on
  -- RegPort even if there is more address space than necessary for the number
  -- of DMA channels implemented.  The unused space will return 0s on reads.
  -- This allows a fixed address range to be mapped to InChWORM without concern
  -- that software accesses to unused space in the range will hang or timeout.
  --   kNiDmaDmaRegBase must be naturally aligned to a boundary of
  -- kNiDmaDmaRegSize.  The total space should be a power-of-two that is at
  -- least 256 bytes * (kNiDmaDmaChannels rounded up to the next power-of-two).
  -- For example, with 5 DMA channels the total address space needed by NI DMA
  -- IP is 256 * 8 = 2048 bytes even though the register set for 5 channels
  -- fits in 256 * 5 = 1280 bytes.
  constant kNiDmaDmaRegBase : natural := kDmaRegBase;
  constant kNiDmaDmaRegSize : positive := kDmaRegSize;  -- 16K supports up to 64 chans

  ---------------------- High Speed Sink Configuration ------------------------

  -- For LvFPGA the high speed sink address width should be the same as the
  -- RegPort address width + 1. This is a requirement from CHInCh 2. However,
  -- this requirement may change for a future interface ASIC/IP. In order
  -- for this package file to support other interfaces in the future, log2
  -- of the max address of Sink Stream's write window could be used to define
  -- this constant. Doing so will also maintain backwards compatibility with
  -- the requirement from CHInCh 2.
  constant kNiDmaHighSpeedSinkAddressWidth : positive := kAddressWidth + 1;

  -- The two constants below define the address range allocated for writing
  -- HighSpeedSink FIFOs.  kNiDmaHighSpeedSinkSize needs to be a power-of-two
  -- and kNiDmaHighSpeedSinkBase needs to be naturally aligned to a boundary of
  -- kNiDmaHighSpeedSinkSize. However, these constants need to reference
  -- similar constants located in PkgCommIntConfiguration.vhd.
  constant kNiDmaHighSpeedSinkBase : natural := kDmaHighSpeedSinkBase;
  constant kNiDmaHighSpeedSinkSize : positive := kDmaHighSpeedSinkSize;

  -------------------------- Feature Configuration ----------------------------

  constant kNiDmaEnableInput : boolean := 
    (NumOfInStrms(kDmaFifoConfArray) + NumOfWriteMasterPorts(kMasterPortConfArray)) > 0;
  constant kNiDmaEnableOutput : boolean := 
    (NumOfOutStrms(kDmaFifoConfArray) + NumOfReadMasterPorts(kMasterPortConfArray)) > 0;

  constant kNiDmaEnableByteSwapper : boolean := kEnableByteSwapper;

  constant kNiDmaTtcWidth : natural := kTtcWidth;
  constant kNiDmaEnableLatchingTtc : boolean := kEnableLatchingTtc;

  constant kNiDmaEnableFullScatterGather : boolean := kEnableFullScatterGather;

  -- These constants are only used when kNiDmaEnableFullScatterGather = true.
  constant kNiDmaMaxChunkyLinkSize : natural := kMaxChunkyLinkSize;
  constant kNiDmaLinkFetchMaxRequests : natural := kLinkFetchMaxRequests;

  -------------------------- Optimization Settings ----------------------------

  -- The NI DMA IP needs to do a lot of alignment work on its data paths.  The
  -- byte lanes on which the user wants data are unrelated to the byte lanes
  -- where the host bus needs the data.  So the NI DMA IP needs the capability
  -- to mux every byte lane from the user to every byte lane of the host bus.
  -- Without pipelining this mux would get slower the wider the bus gets.  The
  -- kNiDmaMaxMuxWidth constant specifies the maximum width allowed for a
  -- combinatorial mux in the NI DMA IP.  The design adds pipeline stages such
  -- that we never have muxes wider than kNiDmaMaxMuxWidth-to-1.  Of course,
  -- wider buses will have more states of latency.  But that is because there
  -- is more processing to do and we want the NI DMA IP to support high clock
  -- rates.
  --
  -- The value of this constant must be a power-of-two.  8-to-1 muxes seem to
  -- be a sweet spot between speed and area in today's FPGAs.  Any wider would
  -- significantly reduce speed because the mux would not fit within a single
  -- SLICE.  Muxes narrower than 8-to-1 would not take full advantage of the
  -- resources available in a SLICE.  For Xilinx families Spartan-6, Virtex-5,
  -- and later; an 8-to-1 mux can be implemented using two 6-input LUTs and an
  -- FMUX.  This is one level of LUTs plus the FMUX all within a SLICE.
  constant kNiDmaMaxMuxWidth : natural := kMaxMuxWidth;
  
  -- The two constants below control the selection between LutRAM and BlockRAM.
  -- These specify thresholds for LutRAM address and data width.  Any RAM
  -- instance in NiDmaIp will use LutRAM when the address and data width are
  -- less than or equal to the maximums specified below.  Otherwise the RAM
  -- instance will use BlockRAM.
  constant kNiDmaMaxLutRamAddressWidth : natural := 8;
  constant kNiDmaMaxLutRamDataWidth : natural := 512;

end PkgNiDmaConfig;

package body PkgNiDmaConfig is
  
end package body PkgNiDmaConfig;
