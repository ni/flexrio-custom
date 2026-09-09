------------------------------------------------------------------------------------------
--
-- File: GarrisonTop.vhd
-- Author: National Instruments
-- Original Project: The Macallan FlexRIO Carrier
-- Date: 02 February 2015
--
------------------------------------------------------------------------------------------
-- (c) 2026 Copyright National Instruments Corporation
--
-- SPDX-License-Identifier: MIT
------------------------------------------------------------------------------------------
--
-- Purpose: This is the top level file for the PCIe-7985
------------------------------------------------------------------------------------------
--
-- githubvisible=true

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.PkgNiUtilities.all;
use work.PkgMacallan.all;
-- InChWORM Imports
use work.PkgBaRegPort.all;
use work.PkgCommunicationInterface.all;
use work.PkgDmaPortRecordFlattening.all;

-- LVFPGA
use work.PkgDmaPortCommunicationInterface.all;
use work.PkgCommIntConfiguration.all;
use work.PkgDmaPortDmaFifos.all;
-- User HDL
use work.PkgNiSharedFifo.all;
use work.PkgUserHdl.all;
use work.PkgNiHdlSettings.all;
use work.PkgDmaPortDmaFifosFlatTypes.all;
use work.PkgDmaPortCommIfcMasterPort.all;
use work.PkgDmaPortCommIfcMasterPortFlatTypes.all;
-- LvFpga printed by SW
use work.PkgLvFpgaConst.all;

-- The Window Component Instantiation
use work.PkgTheLvWindowFlatWrapper.all;

-- Instruction Fifo
use work.PkgInstructionFifo.all;

-- This package is not used in this file, but it is being included to be seen as a
-- dependency and included as an export.
use work.PkgFlexRioTargetConfig.all;

-- Axi Stream
use work.PkgFlexRioAxiStream.all;

-- Sysmon
use work.PkgSysMonConfig.all;

-----------------------------------------------------------------------------------------
-- Top-Level Clock/reset domain prefix guide.
-----------------------------------------------------------------------------------------

-- d      - DmaClk, coming from the Inchworm. Reset by a(d)BusReset for the most part.
-- dr[01] - Physical (fast) Dram?Clk for each of the banks.
-- du[01] - Divided down DramUserClk for each of the banks.
-- b      - BusClk, reset by either a(b)BusReset or aPonReset.
-- bd     - BusClk, reset by aDiagramReset. Only exists for signals that use BusClk but
--          connect to The Window.
-- x      - AxiClk on The Window, so also on aDiagramReset. Because we tie AxiClk to
--          BusClk at The Window, in effect x = bd.
-- dt     - DataClk from the FAM Clip
-- dv     - DeviceClk going into the FAM Clip
-- p or s - PxieClk100
-- st     - Static. These signals should be tied to static pins or constants.
-- r      - ReliableClk, as seen by The Window. Not subject to aDiagramReset.
-- it     - IsoTxClk (IsoPort)
-- ir     - IsoRxClk (IsoPort)
-- s      - SidebandClk

entity GarrisonTop is
  port (
    -------------------------------------------------------------------------------------
    -- Basics
    -------------------------------------------------------------------------------------
    -- Clock Inputs
    --Reliable Clk Input. Comes from an oscillator that is always on
    Osc100ClkIn          : in    std_logic;
    -- POSC Enable
    aPoscEn              : in    std_logic;
    -------------------------------------------------------------------------------------
    -- Board Control
    -------------------------------------------------------------------------------------
    -- Monitoring SMBus
    bBaseSmbScl          : inout std_logic;
    bBaseSmbSda          : inout std_logic;
    aBaseSmbAlert_n      : in    std_logic;  --vhook_nowarn aBaseSmbAlert_n
    -- Control I2C Bus
    bConfigI2cScl        : inout std_logic;
    bConfigI2cSda        : inout std_logic;
    -- Power supply PMBus
    bPwrSupplyPmbScl     : inout std_logic;
    bPwrSupplyPmbSda     : inout std_logic;
    aPwrSupplyPmbAlert_n : in    std_logic;  --vhook_nowarn aPwrSupplyPmbAlert_n
    -- AuxIO Vcc Potentiometer SPI
    bDigiPotSclk         : out   std_logic;
    bDigiPotMosi         : out   std_logic;
    bDigiPotMiso         : in    std_logic;
    bDigiPotSync_n       : out   std_logic;
    -- Authentication
    aAuthSda             : inout std_logic;
    -------------------------------------------------------------------------------------
    -- PXIe
    -------------------------------------------------------------------------------------
    -- PCIe
    aPcieRst_n           : in    std_logic;
    PcieRefClk_p         : in    std_logic;
    PcieRefClk_n         : in    std_logic;
    PcieRx_p             : in    std_logic_vector (7 downto 0);
    PcieRx_n             : in    std_logic_vector (7 downto 0);
    PcieTx_p             : out   std_logic_vector (7 downto 0);
    PcieTx_n             : out   std_logic_vector (7 downto 0);
    -- PXI trigger/control signals
    aPxiTrigData         : inout std_logic_vector(7 downto 0);
    -- PXIe Clk100 and Clk10
    PxieClk100_p         : in    std_logic;
    PxieClk100_n         : in    std_logic;
    pPxieClk10_p         : in    std_logic;
    pPxieClk10_n         : in    std_logic;
    -------------------------------------------------------------------------------------
    -- TDC
    -------------------------------------------------------------------------------------
    -- On Board TDC
    aTdcAllPeclEn        : out   std_logic;
    dvTdcAssert          : out   std_logic;
    sTdcDeassert         : out   std_logic;
    aTdcExpandedPulse_p  : in    std_logic;
    aTdcExpandedPulse_n  : in    std_logic;
    -- Loopback for FPGA TDC
    aFpgaLoopbackOut_p   : out   std_logic;
    aFpgaLoopbackOut_n   : out   std_logic;
    aFpgaLoopbackIn_p    : in    std_logic;
    aFpgaLoopbackIn_n    : in    std_logic;
    -------------------------------------------------------------------------------------
    -- FAM Configuration Plane
    -------------------------------------------------------------------------------------
    -- Config Interface TX
    aConfigTxClkLvds_p   : out   std_logic;
    aConfigTxClkLvds_n   : out   std_logic;
    aConfigTxClkSe       : out   std_logic;
    aConfigTxDataSe      : out   std_logic_vector(6 downto 0);

    -- Config Interface RX
    aConfigRxClkLvds_p : in std_logic;
    aConfigRxClkLvds_n : in std_logic;
    aConfigRxClkSe     : in std_logic;
    aConfigRxDataSe    : in std_logic_vector(6 downto 0);

    -- Module Detection
    aModulePresent_n          : in    std_logic;
    -- RASM
    bIoSmbScl                 : inout std_logic;
    bIoSmbSda                 : inout std_logic;
    aIoSmbAlert_n             : in    std_logic;
    aFamPowerGood             : in    std_logic;
    -------------------------------------------------------------------------------------
    -- FAM MGT Plane
    -------------------------------------------------------------------------------------
    -- RefClks
    MgtRefClk_p               : in    std_logic_vector (2 downto 0);
    MgtRefClk_n               : in    std_logic_vector (2 downto 0);
    -- MGTs
    MgtPortRx_p               : in    std_logic_vector (7 downto 0);
    MgtPortRx_n               : in    std_logic_vector (7 downto 0);
    MgtPortTx_p               : out   std_logic_vector (7 downto 0);
    MgtPortTx_n               : out   std_logic_vector (7 downto 0);
    --VSMake doesn't like prefix-less signals.
    --vhook_nodgv {.*Mgt(Port)?[TR]x_[pn]}
    -------------------------------------------------------------------------------------
    -- FAM Synchronization Plane
    -------------------------------------------------------------------------------------
    -- TimeBase Clock
    DeviceClk_p               : in    std_logic;
    DeviceClk_n               : in    std_logic;
    -- SubClass 1 Synchronization
    dvJesd204SysRef_p         : in    std_logic;
    dvJesd204SysRef_n         : in    std_logic;
    aJesd204SyncReqOut_n      : out   std_logic;
    aJesd204SyncReqIn_n       : in    std_logic;
    -- Sync Pulses
    aGpoSync                  : out   std_logic_vector(1 downto 0);
    -- Triggers
    aTriggerIn_p              : in    std_logic;
    aTriggerIn_n              : in    std_logic;
    aTriggerOut_p             : out   std_logic;
    aTriggerOut_n             : out   std_logic;
    -------------------------------------------------------------------------------------
    -- FAM Gpio
    -------------------------------------------------------------------------------------
    aRsrvGpio_p               : inout std_logic_vector (4 downto 0);
    aRsrvGpio_n               : inout std_logic_vector (4 downto 0);
    -------------------------------------------------------------------------------------
    -- Board Configuration
    -------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------
    -- Reconfiguration CPLD
    -------------------------------------------------------------------------------------
    SidebandClk               : out   std_logic;
    sSidebandDataOut          : out   std_logic_vector(3 downto 0);
    aSidebandDataIn           : in    std_logic;
    aSidebandFifoFull         : in    std_logic;
    aFpgaStage2Done           : out   std_logic;
    -------------------------------------------------------------------------------------
    -- Aux Connector
    -------------------------------------------------------------------------------------
    -- Data and direction
    aAuxIoData                : inout std_logic_vector(7 downto 0);
    aAuxIoOutputEn            : out   std_logic_vector (7 downto 0);
    aAuxIoEnable_n            : out   std_logic;
    -- Power Supplies control and monitoring
    aAuxVccAEnable            : out   std_logic;
    aAux5vEnable              : out   std_logic;
    aAux3v3Enable             : out   std_logic;
    aAux3v3Fault_n            : in    std_logic;
    -- MGTs
    AuxIoMgtRx_p              : in    std_logic_vector(3 downto 0);
    AuxIoMgtRx_n              : in    std_logic_vector(3 downto 0);
    AuxIoMgtTx_p              : out   std_logic_vector(3 downto 0);
    AuxIoMgtTx_n              : out   std_logic_vector(3 downto 0);
    AuxIoMgtRefClk_p          : in    std_logic;
    AuxIoMgtRefClk_n          : in    std_logic;
    -------------------------------------------------------------------------------------
    -- DRAM signals
    -------------------------------------------------------------------------------------
    -- External oscillators for DRAM controllers
    Dram0RefClk_p             : in    std_logic;
    Dram0RefClk_n             : in    std_logic;
    Dram1RefClk_p             : in    std_logic;
    Dram1RefClk_n             : in    std_logic;
    -------------------------------------------------------------------------------------
    -- Bank 0
    -------------------------------------------------------------------------------------
    -- Outgoing clock
    Dram0Clk_p                : out   std_logic;
    Dram0Clk_n                : out   std_logic;
    -- Data
    dr0DramDq                 : inout std_logic_vector(31 downto 0);
    dr0DramDmDbi_n            : inout std_logic_vector(3 downto 0);
    dr0DramDqs_p              : inout std_logic_vector(3 downto 0);
    dr0DramDqs_n              : inout std_logic_vector(3 downto 0);
    -- Address/Command
    dr0DramCs_n               : out   std_logic;
    dr0DramAddr               : out   std_logic_vector(16 downto 0);
    dr0DramBankAddr           : out   std_logic_vector(1 downto 0);
    dr0DramBg                 : out   std_logic_vector(0 downto 0);
    dr0DramAct_n              : out   std_logic;
    -- Control/Clocking
    dr0DramClkEn              : out   std_logic;
    dr0DramOdt                : out   std_logic;
    dr0DramReset_n            : out   std_logic;
    -- Test Pin
    dr0DramTestMode           : out   std_logic;
    -------------------------------------------------------------------------------------
    -- Bank 1
    -------------------------------------------------------------------------------------
    -- Outgoing clock
    Dram1Clk_p                : out   std_logic;
    Dram1Clk_n                : out   std_logic;
    -- Data
    dr1DramDq                 : inout std_logic_vector(31 downto 0);
    dr1DramDmDbi_n            : inout std_logic_vector(3 downto 0);
    dr1DramDqs_p              : inout std_logic_vector(3 downto 0);
    dr1DramDqs_n              : inout std_logic_vector(3 downto 0);
    -- Address/Command
    dr1DramCs_n               : out   std_logic;
    dr1DramAddr               : out   std_logic_vector(16 downto 0);
    dr1DramBankAddr           : out   std_logic_vector(1 downto 0);
    dr1DramBg                 : out   std_logic_vector(0 downto 0);
    dr1DramAct_n              : out   std_logic;
    -- Control/Clocking
    dr1DramClkEn              : out   std_logic;
    dr1DramOdt                : out   std_logic;
    dr1DramReset_n            : out   std_logic;
    dr1DramTestMode           : out   std_logic;
    -------------------------------------------------------------------------------------
    -- System Monitor
    -------------------------------------------------------------------------------------
    -- Voltage Monitors
    aSysMon1v8MgtDivided_p    : in    std_logic;
    aSysMon1v8MgtDivided_n    : in    std_logic;
    aSysMonVccAuxADivided_p   : in    std_logic;
    aSysMonVccAuxADivided_n   : in    std_logic;
    aSysMon1v8SwDivided_p     : in    std_logic;
    aSysMon1v8SwDivided_n     : in    std_logic;
    aSysMon3v3CpldDivided_p   : in    std_logic;
    aSysMon3v3CpldDivided_n   : in    std_logic;
    aSysMon3v3IoDivided_p     : in    std_logic;
    aSysMon3v3IoDivided_n     : in    std_logic;
    aSysMonVppDivided_p       : in    std_logic;
    aSysMonVppDivided_n       : in    std_logic;
    aSysMon3v3AuxDivided_p    : in    std_logic;
    aSysMon3v3AuxDivided_n    : in    std_logic;
    aSysMon1v2MgtDivided_p    : in    std_logic;
    aSysMon1v2MgtDivided_n    : in    std_logic;
    aSysMon1v0MgtDivided_p    : in    std_logic;
    aSysMon1v0MgtDivided_n    : in    std_logic;
    aSysMon3v8IntDivided_p    : in    std_logic;
    aSysMon3v8IntDivided_n    : in    std_logic;
    aSysMon3v3ClkDivided_p    : in    std_logic;
    aSysMon3v3ClkDivided_n    : in    std_logic;
    aSysMon1v2ADivided_p      : in    std_logic;
    aSysMon1v2ADivided_n      : in    std_logic;
    aSysMonVtt0v6Sense_p      : in    std_logic;
    aSysMonVtt0v6Sense_n      : in    std_logic;
    aSysMon5vAuxDivided_p     : in    std_logic;
    aSysMon5vAuxDivided_n     : in    std_logic;
    aSysMon1v2CicadaDivided_p : in    std_logic;
    aSysMon1v2CicadaDivided_n : in    std_logic;
    aSysMonDdrVrefSense_p     : in    std_logic;
    aSysMonDdrVrefSense_n     : in    std_logic;
    -------------------------------------------------------------------------------------
    -- CPLD JTAG Field Update
    -------------------------------------------------------------------------------------
    aFldUpdJtagSel            : out   std_logic;
    bFldUpdJtagTck            : out   std_logic;
    bFldUpdJtagTdi            : out   std_logic;
    aFldUpdJtagTdo            : in    std_logic;
    bFldUpdJtagTms            : out   std_logic;

    -------------------------------------------------------------------------------------
    -- New Garrison Signals
    -------------------------------------------------------------------------------------
    aClockMiso                : in    std_logic;
    aClockMosi                : out   std_logic;
    aClockSck                 : out   std_logic;
    aLmkCs_n                  : out   std_logic;
    aPhaseDacCs_n             : out   std_logic;
    aDirectVcxo               : out   std_logic;
    aEnRefIn                  : out   std_logic;
    aLmkStatus                : in    std_logic;
    aFpgaSyncClockOutEn       : out   std_logic;

    aExpansionGpio            : inout std_logic_vector(7 downto 0);
    aExpansionPrst_n          : in    std_logic;
    aExpansionMiso            : in    std_logic;
    aExpansionMosi            : out   std_logic;
    aExpansionSck             : out   std_logic;
    aExpansionCs_n            : out   std_logic;

    aFan0Pwm                  : out   std_logic;
    aFan1Pwm                  : out   std_logic;
    aFan0Tach                 : in    std_logic;
    aFan1Tach                 : in    std_logic;
    aFanPwrGood_n             : in    std_logic;
    aFanPwrEn                 : out   std_logic;

    aTrigPortExpReset_n       : out   std_logic
    );

end entity GarrisonTop;

architecture struct of GarrisonTop is

  component PcieUsTimingEngine
    port (
      aPcieRst           : in  std_logic;
      aResetToInchworm_n : out std_logic;
      aResetFromInchworm : in  boolean;
      aBusReset          : out boolean;
      abBusReset         : out boolean;
      PxieClk100_p       : in  std_logic;
      PxieClk100_n       : in  std_logic;
      Osc100ClkIn        : in  std_logic;
      rBaseClksValid     : out std_logic;
      BusClk             : in  std_logic;
      bTePllLocked       : out std_logic;
      aLmkConfigured     : in  boolean;
      ReliableClk        : out std_logic;
      PxieClk100         : out std_logic;
      DlyRefClk          : out std_logic;
      PllClk40           : out std_logic;
      PllClk80           : out std_logic;
      MbClk              : out std_logic;
      aStage2Enabled     : in  boolean;
      pPxieClk10_p       : in  std_logic;
      pPxieClk10_n       : in  std_logic;
      pIntSync100        : out std_logic;
      aIntClk10          : out std_logic;
      aDramClocksValid   : in  boolean;
      aDramPllLocked     : in  boolean;
      aDramPonReset      : out boolean;
      aDramReady         : out std_logic;
      du0DramPhyInitDone : in  std_logic;
      du1DramPhyInitDone : in  std_logic;
      aPonReset          : out boolean;
      adlyReset          : out boolean);
  end component;

  -- Board IO ref-clock enables. Driven from HDL, not from the LV-generated kEnableFamClockSync /
  -- kFamClockSrcSel (a custom target's PkgLvFpgaConst does not define them): enable the 100 MHz clock.
  constant kEnableIoRefClk10  : std_logic := '0';
  constant kEnableIoRefClk100 : std_logic := '1';

  -- Internal signals for flattened types to connect to TheLvWindowFlatWrapper
  signal bRegPortInFlat : std_logic_vector(kRegPortInSize-1 downto 0);
  signal bRegPortOutFlat : std_logic_vector(kRegPortOutSize-1 downto 0);

  signal dInputStreamInterfaceToFifoFlat : std_logic_vector(
    Larger(kNumberOfDmaChannels,1)*SizeOf(kInputStreamInterfaceToFifoZero)-1 downto 0);
  signal dInputStreamInterfaceFromFifoFlat : std_logic_vector(
    Larger(kNumberOfDmaChannels,1)*SizeOf(kInputStreamInterfaceFromFifoZero)-1 downto 0);
  signal dOutputStreamInterfaceToFifoFlat : std_logic_vector(
    Larger(kNumberOfDmaChannels,1)*SizeOf(kOutputStreamInterfaceToFifoZero)-1 downto 0);
  signal dOutputStreamInterfaceFromFifoFlat : std_logic_vector(
    Larger(kNumberOfDmaChannels,1)*SizeOf(kOutputStreamInterfaceFromFifoZero)-1 downto 0);

  signal bIrqToInterfaceFlat : std_logic_vector(
    Larger(kNumberOfIrqs,1)*kIrqToInterfaceSize*kIrqStatusToInterfaceSize-1 downto 0);

  signal dNiFpgaMasterWriteRequestFromMasterArrayFlat : std_logic_vector(
    Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterWriteRequestFromMasterZero)-1 downto 0);
  signal dNiFpgaMasterWriteRequestToMasterArrayFlat : std_logic_vector(
    Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterWriteRequestToMasterZero)-1 downto 0);
  signal dNiFpgaMasterWriteDataFromMasterArrayFlat : std_logic_vector(
    Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterWriteDataFromMasterZero)-1 downto 0);
  signal dNiFpgaMasterWriteDataToMasterArrayFlat : std_logic_vector(
    Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterWriteDataToMasterZero)-1 downto 0);
  signal dNiFpgaMasterWriteStatusToMasterArrayFlat : std_logic_vector(
    Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterWriteStatusToMasterZero)-1 downto 0);

  signal dNiFpgaMasterReadRequestFromMasterArrayFlat : std_logic_vector(
    Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterReadRequestFromMasterZero)-1 downto 0);
  signal dNiFpgaMasterReadRequestToMasterArrayFlat : std_logic_vector(
    Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterReadRequestToMasterZero)-1 downto 0);
  signal dNiFpgaMasterReadDataToMasterArrayFlat : std_logic_vector(
    Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterReadDataToMasterZero)-1 downto 0);

  -- Regport interface between Shim and DmaPortCommInt/TheWindow
  signal bRegPortOut: RegPortOut_t;
  signal bRegPortIn: RegPortIn_t;

  signal bLvWindowRegPortOut: RegPortOut_t;

  signal dInputStreamInterfaceFromFifo: InputStreamInterfaceFromFifoArray_t(Larger(kNumberOfDmaChannels,1)-1 downto 0);
  signal dInputStreamInterfaceToFifo: InputStreamInterfaceToFifoArray_t(Larger(kNumberOfDmaChannels,1)-1 downto 0);

  signal bIrqToInterface: IrqToInterfaceArray_t(Larger(kNumberOfIrqs,1)-1 downto 0);

  signal dNiFpgaMasterReadDataToMasterArray: NiFpgaMasterReadDataToMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);
  signal dNiFpgaMasterReadRequestFromMasterArray: NiFpgaMasterReadRequestFromMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);
  signal dNiFpgaMasterReadRequestToMasterArray: NiFpgaMasterReadRequestToMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);
  signal dNiFpgaMasterWriteDataFromMasterArray: NiFpgaMasterWriteDataFromMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);
  signal dNiFpgaMasterWriteDataToMasterArray: NiFpgaMasterWriteDataToMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);
  signal dNiFpgaMasterWriteRequestFromMasterArray: NiFpgaMasterWriteRequestFromMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);
  signal dNiFpgaMasterWriteRequestToMasterArray: NiFpgaMasterWriteRequestToMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);
  signal dNiFpgaMasterWriteStatusToMasterArray: NiFpgaMasterWriteStatusToMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);
  signal dOutputStreamInterfaceFromFifo: OutputStreamInterfaceFromFifoArray_t(Larger(kNumberOfDmaChannels,1)-1 downto 0);
  signal dOutputStreamInterfaceToFifo: OutputStreamInterfaceToFifoArray_t(Larger(kNumberOfDmaChannels,1)-1 downto 0);

  --vhook_sigstart
  signal aAuthSdaIn: std_logic;
  signal aAuthSdaOut: std_logic;
  signal abBusReset: boolean;
  signal abDiagramReset: boolean;
  signal aConfigRxClkLvds: std_logic;
  signal aConfigRxClkSeBuf: std_logic;
  signal aConfigRxDataSeBuf: std_logic_vector(6 downto 0);
  signal aConfigTxClkLvds: std_logic;
  signal aConfigTxClkSeBuf: std_logic;
  signal aConfigTxDataSeBuf: std_logic_vector(6 downto 0);
  signal aDiagramReset: std_logic;
  signal aDramPonReset: boolean;
  signal aDramReady: std_logic;
  signal aI2cSclIn: std_logic_vector(kNumI2cIfcs-1 downto 0);
  signal aI2cSclOut: std_logic_vector(kNumI2cIfcs-1 downto 0);
  signal aI2cSclTri: std_logic_vector(kNumI2cIfcs-1 downto 0);
  signal aI2cSdaIn: std_logic_vector(kNumI2cIfcs-1 downto 0);
  signal aI2cSdaOut: std_logic_vector(kNumI2cIfcs-1 downto 0);
  signal aI2cSdaTri: std_logic_vector(kNumI2cIfcs-1 downto 0);
  signal aIntClk10: std_logic;
  signal aLmkConfigured: boolean;
  signal aPcieRst: std_logic;
  signal aPonReset: boolean;
  signal aPxiTrigDataIn: std_logic_vector(7 downto 0);
  signal aPxiTrigDataOut: std_logic_vector(7 downto 0);
  signal aPxiTrigDataTri: std_logic_vector(7 downto 0);
  signal aReservedFromClip: std_logic_vector(15 downto 0);
  signal aReservedToClip: std_logic_vector(15 downto 0);
  signal aResetFromInchworm: boolean;
  signal aResetToInchworm_n: std_logic;
  signal aStage2Enabled: boolean;
  signal aSysMonVector_n: std_logic_vector(15 downto 0);
  signal aSysMonVector_p: std_logic_vector(15 downto 0);
  signal aTdcExpandedPulse: std_logic;
  signal aTriggerIn: std_logic;
  signal aTriggerOut: std_logic;
  signal bAxiStreamDataFromCtrl: AxiStreamData_t;
  signal bAxiStreamDataToCtrl: AxiStreamData_t;
  signal bAxiStreamReadyFromCtrl: boolean;
  signal bAxiStreamReadyToCtrl: boolean;
  signal bdClipAxi4LiteARAddr: std_logic_vector(31 downto 0);
  signal bdClipAxi4LiteARProt: std_logic_vector(2 downto 0);
  signal bdClipAxi4LiteARReady: std_logic;
  signal bdClipAxi4LiteARValid: std_logic;
  signal bdClipAxi4LiteAWAddr: std_logic_vector(31 downto 0);
  signal bdClipAxi4LiteAWProt: std_logic_vector(2 downto 0);
  signal bdClipAxi4LiteAWReady: std_logic;
  signal bdClipAxi4LiteAWValid: std_logic;
  signal bdClipAxi4LiteBReady: std_logic;
  signal bdClipAxi4LiteBResp: std_logic_vector(1 downto 0);
  signal bdClipAxi4LiteBValid: std_logic;
  signal bdClipAxi4LiteRData: std_logic_vector(31 downto 0);
  signal bdClipAxi4LiteRReady: std_logic;
  signal bdClipAxi4LiteRResp: std_logic_vector(1 downto 0);
  signal bdClipAxi4LiteRValid: std_logic;
  signal bdClipAxi4LiteWData: std_logic_vector(31 downto 0);
  signal bdClipAxi4LiteWReady: std_logic;
  signal bdClipAxi4LiteWStrb: std_logic_vector(3 downto 0);
  signal bdClipAxi4LiteWValid: std_logic;
  signal bdIFifoRdData: std_logic_vector(63 downto 0);
  signal bdIFifoRdDataValid: std_logic;
  signal bdIFifoRdIsError: std_logic;
  signal bdIFifoRdReadyForInput: std_logic;
  signal bdIFifoWrData: std_logic_vector(63 downto 0);
  signal bdIFifoWrDataValid: std_logic;
  signal bdIFifoWrReadyForOutput: std_logic;
  signal bDramClocksValid: std_logic;
  signal bFamOutputEnable: std_logic;
  signal bLvWindowRegPortIn: RegPortIn_t;
  signal bLvWindowRegPortTimeout: boolean;
  signal bRoutingClipNiCompatible: std_logic;
  signal bRoutingClipPresent: std_logic;
  signal bTriggerRoutingBaRegPortInAddress: std_logic_vector(BaRegPortAddress_t'range);
  signal bTriggerRoutingBaRegPortInData: std_logic_vector(BaRegPortData_t'range);
  signal bTriggerRoutingBaRegPortInRdStrobe: std_logic_vector(BaRegPortStrobe_t'range);
  signal bTriggerRoutingBaRegPortInWtStrobe: std_logic_vector(BaRegPortStrobe_t'range);
  signal bTriggerRoutingBaRegPortOutAck: std_logic;
  signal bTriggerRoutingBaRegPortOutData: std_logic_vector(BaRegPortData_t'range);
  signal BusClk: std_logic;
  signal Clk40MHz: std_logic;
  signal DeviceClk: std_logic;
  signal dFixedLogicBaRegPortIn: BaRegPortIn_t;
  signal dFixedLogicBaRegPortOut: BaRegPortOut_t;
  signal dIrqFromFixedLogic: std_logic;
  signal DlyRefClk: std_logic;
  signal DmaClk: std_logic;
  signal Dram0ClkUser: std_logic;
  signal Dram1ClkUser: std_logic;
  signal DramClkLvFpga: std_logic;
  signal dtDevClkEn: std_logic;
  signal dtTdcAssert: std_logic;
  signal du0DramAddrFifoAddr: std_logic_vector(28 downto 0);
  signal du0DramAddrFifoCmd: std_logic_vector(2 downto 0);
  signal du0DramAddrFifoFull: std_logic;
  signal du0DramAddrFifoWrEn: std_logic;
  signal du0DramPhyInitDone: std_logic;
  signal du0DramRdDataValid: std_logic;
  signal du0DramRdFifoDataOut: std_logic_vector(255 downto 0);
  signal du0DramWrFifoDataIn: std_logic_vector(255 downto 0);
  signal du0DramWrFifoFull: std_logic;
  signal du0DramWrFifoMaskData: std_logic_vector(31 downto 0);
  signal du0DramWrFifoWrEn: std_logic;
  signal du1DramAddrFifoAddr: std_logic_vector(28 downto 0);
  signal du1DramAddrFifoCmd: std_logic_vector(2 downto 0);
  signal du1DramAddrFifoFull: std_logic;
  signal du1DramAddrFifoWrEn: std_logic;
  signal du1DramPhyInitDone: std_logic;
  signal du1DramRdDataValid: std_logic;
  signal du1DramRdFifoDataOut: std_logic_vector(255 downto 0);
  signal du1DramWrFifoDataIn: std_logic_vector(255 downto 0);
  signal du1DramWrFifoFull: std_logic;
  signal du1DramWrFifoMaskData: std_logic_vector(31 downto 0);
  signal du1DramWrFifoWrEn: std_logic;
  signal dvJesd204SysRef: std_logic;
  signal ExportedMgtRefClk: std_logic;
  signal MbClk: std_logic;
  signal pIntSync100: std_logic;
  signal PxieClk100: std_logic;
  signal rBaseClksValid: std_logic;
  signal ReliableClk: std_logic;
  signal stIoModuleSupportsFRAGLs: std_logic;
  signal xDiagramAxiStreamFromClipTData: std_logic_vector(31 downto 0);
  signal xDiagramAxiStreamFromClipTLast: std_logic;
  signal xDiagramAxiStreamFromClipTReady: std_logic;
  signal xDiagramAxiStreamFromClipTValid: std_logic;
  signal xDiagramAxiStreamToClipTData: std_logic_vector(31 downto 0);
  signal xDiagramAxiStreamToClipTLast: std_logic;
  signal xDiagramAxiStreamToClipTReady: std_logic;
  signal xDiagramAxiStreamToClipTValid: std_logic;
  signal xHostAxiStreamFromClipTData: std_logic_vector(31 downto 0);
  signal xHostAxiStreamFromClipTLast: std_logic;
  signal xHostAxiStreamFromClipTReady: std_logic;
  signal xHostAxiStreamFromClipTValid: std_logic;
  signal xHostAxiStreamToClipTData: std_logic_vector(31 downto 0);
  signal xHostAxiStreamToClipTLast: std_logic;
  signal xHostAxiStreamToClipTReady: std_logic;
  signal xHostAxiStreamToClipTValid: std_logic;
  --vhook_sigend

  -- Global Reset.
  signal aBusReset : boolean := true;

  -- Aux IO
  signal aLvAuxDioOutputData   : std_logic_vector(kNumAuxIoData-1 downto 0);
  signal aLvAuxDioInputData    : std_logic_vector(kNumAuxIoData-1 downto 0);
  signal aLvAuxDioOutputEnable : std_logic_vector(kNumAuxIoData-1 downto 0);
  signal bdRequestaLvAuxDio    : std_logic_vector(kNumAuxIoData-1 downto 0);
  signal bdDirectionaLvAuxDio  : std_logic_vector(kNumAuxIoData-1 downto 0);
  signal bdDoneaLvAuxDio       : std_logic_vector(kNumAuxIoData-1 downto 0);

  -- UserHdl register-port output (board-agnostic)
  signal bRegPortOutUserHdl: RegPortOut_t;

  -- Window-side stream interface signals (for UserHdl FIFO interception)
  signal dWinInputStreamInterfaceToFifo   : InputStreamInterfaceToFifoArray_t(Larger(kNumberOfDmaChannels,1)-1 downto 0);
  signal dWinInputStreamInterfaceFromFifo : InputStreamInterfaceFromFifoArray_t(Larger(kNumberOfDmaChannels,1)-1 downto 0);
  signal dWinOutputStreamInterfaceToFifo  : OutputStreamInterfaceToFifoArray_t(Larger(kNumberOfDmaChannels,1)-1 downto 0);
  signal dWinOutputStreamInterfaceFromFifo: OutputStreamInterfaceFromFifoArray_t(Larger(kNumberOfDmaChannels,1)-1 downto 0);


  -- Disable automatic io_buffer creation for FAM MGTs and signals that will instantiate
  -- their own.
  attribute io_buffer_type : string;
  attribute dont_touch     : boolean;

  -- MGT RefClks
  attribute io_buffer_type of MgtRefClk_p      : signal is "none";
  attribute io_buffer_type of MgtRefClk_n      : signal is "none";
  attribute io_buffer_type of AuxIoMgtRefClk_p : signal is "none";
  attribute io_buffer_type of AuxIoMgtRefClk_n : signal is "none";
  -- MGTs
  attribute io_buffer_type of MgtPortRx_p      : signal is "none";
  attribute io_buffer_type of MgtPortRx_n      : signal is "none";
  attribute io_buffer_type of MgtPortTx_p      : signal is "none";
  attribute io_buffer_type of MgtPortTx_n      : signal is "none";
  attribute io_buffer_type of AuxIoMgtRx_p     : signal is "none";
  attribute io_buffer_type of AuxIoMgtRx_n     : signal is "none";
  attribute io_buffer_type of AuxIoMgtTx_p     : signal is "none";
  attribute io_buffer_type of AuxIoMgtTx_n     : signal is "none";

  --System Monitor
  attribute io_buffer_type of aSysMon1v8MgtDivided_p    : signal is "none";
  attribute io_buffer_type of aSysMonVccAuxADivided_p   : signal is "none";
  attribute io_buffer_type of aSysMon1v8SwDivided_p     : signal is "none";
  attribute io_buffer_type of aSysMon3v3CpldDivided_p   : signal is "none";
  attribute io_buffer_type of aSysMon3v3IoDivided_p     : signal is "none";
  attribute io_buffer_type of aSysMonVppDivided_p       : signal is "none";
  attribute io_buffer_type of aSysMon3v3AuxDivided_p    : signal is "none";
  attribute io_buffer_type of aSysMon1v2MgtDivided_p    : signal is "none";
  attribute io_buffer_type of aSysMon1v0MgtDivided_p    : signal is "none";
  attribute io_buffer_type of aSysMon3v8IntDivided_p    : signal is "none";
  attribute io_buffer_type of aSysMon3v3ClkDivided_p    : signal is "none";
  attribute io_buffer_type of aSysMon1v2ADivided_p      : signal is "none";
  attribute io_buffer_type of aSysMonVtt0v6Sense_p      : signal is "none";
  attribute io_buffer_type of aSysMon5vAuxDivided_p     : signal is "none";
  attribute io_buffer_type of aSysMon1v2CicadaDivided_p : signal is "none";
  attribute io_buffer_type of aSysMonDdrVrefSense_p     : signal is "none";

  attribute io_buffer_type of aSysMon1v8MgtDivided_n    : signal is "none";
  attribute io_buffer_type of aSysMonVccAuxADivided_n   : signal is "none";
  attribute io_buffer_type of aSysMon1v8SwDivided_n     : signal is "none";
  attribute io_buffer_type of aSysMon3v3CpldDivided_n   : signal is "none";
  attribute io_buffer_type of aSysMon3v3IoDivided_n     : signal is "none";
  attribute io_buffer_type of aSysMonVppDivided_n       : signal is "none";
  attribute io_buffer_type of aSysMon3v3AuxDivided_n    : signal is "none";
  attribute io_buffer_type of aSysMon1v2MgtDivided_n    : signal is "none";
  attribute io_buffer_type of aSysMon1v0MgtDivided_n    : signal is "none";
  attribute io_buffer_type of aSysMon3v8IntDivided_n    : signal is "none";
  attribute io_buffer_type of aSysMon3v3ClkDivided_n    : signal is "none";
  attribute io_buffer_type of aSysMon1v2ADivided_n      : signal is "none";
  attribute io_buffer_type of aSysMonVtt0v6Sense_n      : signal is "none";
  attribute io_buffer_type of aSysMon5vAuxDivided_n     : signal is "none";
  attribute io_buffer_type of aSysMon1v2CicadaDivided_n : signal is "none";
  attribute io_buffer_type of aSysMonDdrVrefSense_n     : signal is "none";

  -- Tandem signals with explicit IOBUF instantiations
  -- This prevents inserting additional buffers which can mess up the stage 1 constraints.
  attribute io_buffer_type of aPcieRst_n     : signal is "none";
  attribute io_buffer_type of PxieClk100_p   : signal is "none";
  attribute io_buffer_type of PxieClk100_n   : signal is "none";
  attribute io_buffer_type of pPxieClk10_p   : signal is "none";
  attribute io_buffer_type of pPxieClk10_n   : signal is "none";
  attribute io_buffer_type of Osc100ClkIn    : signal is "none";
  attribute io_buffer_type of aAuthSda       : signal is "none";

  -- Tandem IO Buffer block
  attribute dont_touch of MacallanIoBuffersStage1x : label is true;

begin  -- architecture struct

  ---------------------------------------------------------------------------------------
  -- Clock Generation and Resets
  ---------------------------------------------------------------------------------------

  --vhook   PcieUsTimingEngine TimingEnginex
  --vhook_a PllClk80            BusClk
  --vhook_a PllClk40            Clk40Mhz
  --vhook_# DRAM
  --vhook_a aDramClocksValid    to_Boolean(bDramClocksValid)
  --vhook_a aDramPllLocked      true
  --vhook_# Unused
  --vhook_h adlyReset           open
  --vhook_h bTePllLocked        open
  TimingEnginex: PcieUsTimingEngine
    port map (
      aPcieRst           => aPcieRst,                      --in  std_logic
      aResetToInchworm_n => aResetToInchworm_n,            --out std_logic
      aResetFromInchworm => aResetFromInchworm,            --in  boolean
      aBusReset          => aBusReset,                     --out boolean
      abBusReset         => abBusReset,                    --out boolean
      PxieClk100_p       => PxieClk100_p,                  --in  std_logic
      PxieClk100_n       => PxieClk100_n,                  --in  std_logic
      Osc100ClkIn        => Osc100ClkIn,                   --in  std_logic
      rBaseClksValid     => rBaseClksValid,                --out std_logic
      BusClk             => BusClk,                        --in  std_logic
      aLmkConfigured     => aLmkConfigured,                --in  boolean
      ReliableClk        => ReliableClk,                   --out std_logic
      PxieClk100         => PxieClk100,                    --out std_logic
      DlyRefClk          => DlyRefClk,                     --out std_logic
      PllClk40           => Clk40Mhz,                      --out std_logic
      PllClk80           => BusClk,                        --out std_logic
      MbClk              => MbClk,                         --out std_logic
      aStage2Enabled     => aStage2Enabled,                --in  boolean
      pPxieClk10_p       => pPxieClk10_p,                  --in  std_logic
      pPxieClk10_n       => pPxieClk10_n,                  --in  std_logic
      pIntSync100        => pIntSync100,                   --out std_logic
      aIntClk10          => aIntClk10,                     --out std_logic
      aDramClocksValid   => to_Boolean(bDramClocksValid),  --in  boolean
      aDramPllLocked     => true,                          --in  boolean
      aDramPonReset      => aDramPonReset,                 --out boolean
      aDramReady         => aDramReady,                    --out std_logic
      du0DramPhyInitDone => du0DramPhyInitDone,            --in  std_logic
      du1DramPhyInitDone => du1DramPhyInitDone,            --in  std_logic
      aPonReset          => aPonReset);                    --out boolean

  ---------------------------------------------------------------------------------------
  -- Host Interface
  ---------------------------------------------------------------------------------------

  --VSMake doesn't like prefix-less signals.
  --vhook_nodgv {^Pcie[RT]x_[pn]}
  --Suppress warnings about unused signals.
  --vhook_nowarn dNiHmb*

  --vhook_e G3UsHostInterface   HostInterfacex
  --vhook_# Use BusClk for AxiClk and ViClk
  --vhook_a AxiClk              BusClk
  --vhook_a {x(AxiStream.+)}    xHost$1
  --vhook_a ViClk               BusClk
  --vhook_a {v(IFifo.+)}        bd$1
  --vhook_a aGa                 (others => '0')
  --vhook_# DmaClk wrap-back
  --vhook_a DmaClockSource      DmaClk
  --vhook_g kHmbInUse false
  --vhook_g kDmaFifoConfArrayGeneric MergeDmaFifoConf(kDmaFifoConfArray, kUserHdlDmaFifoConf, kUserHdlDmaStartIndex)
  --vhook_h {dNiHmb.*}
  --vhook_h dFlatHighSpeedSinkFromDma
  --vhook_g kForceChannelEnable GetForceChannelEnable(kUserHdlDmaFifoConf, kUserHdlDmaStartIndex)
  HostInterfacex: entity work.G3UsHostInterface (struct)
    generic map (
      kHmbInUse                => false,                                                     --boolean:=false
      kDmaFifoConfArrayGeneric => MergeDmaFifoConf(kDmaFifoConfArray, kUserHdlDmaFifoConf,
                                                   kUserHdlDmaStartIndex),                    --DmaChannelConfArray_t
      kForceChannelEnable      => GetForceChannelEnable(kUserHdlDmaFifoConf,
                                                        kUserHdlDmaStartIndex))               --NiDmaDmaChannelOneHot_t
    port map (
      PcieRefClk_p                             => PcieRefClk_p,                              --in  std_logic
      PcieRefClk_n                             => PcieRefClk_n,                              --in  std_logic
      PcieRx_p                                 => PcieRx_p,                                  --in  std_logic_vector(7:0)
      PcieRx_n                                 => PcieRx_n,                                  --in  std_logic_vector(7:0)
      PcieTx_p                                 => PcieTx_p,                                  --out std_logic_vector(7:0)
      PcieTx_n                                 => PcieTx_n,                                  --out std_logic_vector(7:0)
      aGa                                      => (others => '0'),                           --in  std_logic_vector(4:0)
      DmaClockSource                           => DmaClk,                                    --out std_logic
      DmaClk                                   => DmaClk,                                    --in  std_logic
      BusClk                                   => BusClk,                                    --in  std_logic
      aPonReset                                => aPonReset,                                 --in  boolean
      aBusReset                                => aBusReset,                                 --in  boolean
      aResetToInchworm_n                       => aResetToInchworm_n,                        --in  std_logic
      aResetFromInchworm                       => aResetFromInchworm,                        --out boolean
      Clk40MHz                                 => Clk40MHz,                                  --in  std_logic
      aAuthSdaIn                               => aAuthSdaIn,                                --in  std_logic
      aAuthSdaOut                              => aAuthSdaOut,                               --out std_logic
      aDiagramReset                            => aDiagramReset,                             --in  std_logic
      bLvWindowRegPortIn                       => bRegPortIn,                                --out RegPortIn_t
      bLvWindowRegPortOut                      => bRegPortOut,                               --in  RegPortOut_t
      bLvWindowRegPortTimeOut                  => bLvWindowRegPortTimeOut,                   --out boolean
      bIrqToInterface                          => bIrqToInterface,                           --in  IrqToInterfaceArray_t
      dInputStreamInterfaceFromFifo            => dInputStreamInterfaceFromFifo,             --in  InputStreamInterfaceFromFifoArray_t
      dInputStreamInterfaceToFifo              => dInputStreamInterfaceToFifo,               --out InputStreamInterfaceToFifoArray_t
      dOutputStreamInterfaceFromFifo           => dOutputStreamInterfaceFromFifo,            --in  OutputStreamInterfaceFromFifoArray_t
      dOutputStreamInterfaceToFifo             => dOutputStreamInterfaceToFifo,              --out OutputStreamInterfaceToFifoArray_t
      dNiFpgaMasterWriteRequestFromMasterArray => dNiFpgaMasterWriteRequestFromMasterArray,  --in  NiFpgaMasterWriteRequestFromMasterArray_t
      dNiFpgaMasterWriteRequestToMasterArray   => dNiFpgaMasterWriteRequestToMasterArray,    --out NiFpgaMasterWriteRequestToMasterArray_t
      dNiFpgaMasterWriteDataFromMasterArray    => dNiFpgaMasterWriteDataFromMasterArray,     --in  NiFpgaMasterWriteDataFromMasterArray_t
      dNiFpgaMasterWriteDataToMasterArray      => dNiFpgaMasterWriteDataToMasterArray,       --out NiFpgaMasterWriteDataToMasterArray_t
      dNiFpgaMasterWriteStatusToMasterArray    => dNiFpgaMasterWriteStatusToMasterArray,     --out NiFpgaMasterWriteStatusToMasterArray_t
      dNiFpgaMasterReadRequestFromMasterArray  => dNiFpgaMasterReadRequestFromMasterArray,   --in  NiFpgaMasterReadRequestFromMasterArray_t
      dNiFpgaMasterReadRequestToMasterArray    => dNiFpgaMasterReadRequestToMasterArray,     --out NiFpgaMasterReadRequestToMasterArray_t
      dNiFpgaMasterReadDataToMasterArray       => dNiFpgaMasterReadDataToMasterArray,        --out NiFpgaMasterreadDataToMasterArray_t
      AxiClk                                   => BusClk,                                    --in  std_logic
      xAxiStreamFromClipTData                  => xHostAxiStreamFromClipTData,               --in  AxiStreamTData_t
      xAxiStreamFromClipTLast                  => xHostAxiStreamFromClipTLast,               --in  std_logic
      xAxiStreamToClipTReady                   => xHostAxiStreamToClipTReady,                --out std_logic
      xAxiStreamFromClipTValid                 => xHostAxiStreamFromClipTValid,              --in  std_logic
      xAxiStreamToClipTData                    => xHostAxiStreamToClipTData,                 --out AxiStreamTData_t
      xAxiStreamToClipTLast                    => xHostAxiStreamToClipTLast,                 --out std_logic
      xAxiStreamToClipTValid                   => xHostAxiStreamToClipTValid,                --out std_logic
      xAxiStreamFromClipTReady                 => xHostAxiStreamFromClipTReady,              --in  std_logic
      ViClk                                    => BusClk,                                    --in  std_logic
      vIFifoWrData                             => bdIFifoWrData,                             --out IFifoWriteData_t
      vIFifoWrDataValid                        => bdIFifoWrDataValid,                        --out std_logic
      vIFifoWrReadyForOutput                   => bdIFifoWrReadyForOutput,                   --in  std_logic
      vIFifoRdData                             => bdIFifoRdData,                             --in  IFifoReadData_t
      vIFifoRdIsError                          => bdIFifoRdIsError,                          --in  std_logic
      vIFifoRdDataValid                        => bdIFifoRdDataValid,                        --in  std_logic
      vIFifoRdReadyForInput                    => bdIFifoRdReadyForInput,                    --out std_logic
      dFixedLogicBaRegPortIn                   => dFixedLogicBaRegPortIn,                    --out BaRegPortIn_t
      dFixedLogicBaRegPortOut                  => dFixedLogicBaRegPortOut,                   --in  BaRegPortOut_t
      bAxiStreamDataToCtrl                     => bAxiStreamDataToCtrl,                      --out AxiStreamData_t
      bAxiStreamReadyFromCtrl                  => bAxiStreamReadyFromCtrl,                   --in  boolean
      bAxiStreamDataFromCtrl                   => bAxiStreamDataFromCtrl,                    --in  AxiStreamData_t
      bAxiStreamReadyToCtrl                    => bAxiStreamReadyToCtrl,                     --out boolean
      dIrqFromFixedLogic                       => dIrqFromFixedLogic,                        --in  std_logic
      aStage2Enabled                           => aStage2Enabled);                           --out boolean

  ---------------------------------------------------------------------------------------
  -- Fixed Logic
  ---------------------------------------------------------------------------------------

  --vhook_e FixedLogicWrapper
  --vhook_a FastTdcClk                          DlyRefClk
  --vhook_a Clk300                              DlyRefClk
  --vhook_# I2c
  --vhook_a {^b(.*?)(Scl|Sda)(In|Out|Tri)}      aI2c$2$3(k$1Index)
  --vhook_a stEnableIoRefClk10                  kEnableIoRefClk10
  --vhook_a stEnableIoRefClk100                 kEnableIoRefClk100
  FixedLogicWrapperx: entity work.FixedLogicWrapper (struct)
    port map (
      aPonReset                          => aPonReset,                           --in  boolean
      aBusReset                          => aBusReset,                           --in  boolean
      aDiagramReset                      => aDiagramReset,                       --in  std_logic
      DmaClk                             => DmaClk,                              --in  std_logic
      BusClk                             => BusClk,                              --in  std_logic
      MbClk                              => MbClk,                               --in  std_logic
      Clk300                             => DlyRefClk,                           --in  std_logic
      FastTdcClk                         => DlyRefClk,                           --in  std_logic
      dFixedLogicBaRegPortIn             => dFixedLogicBaRegPortIn,              --in  BaRegPortIn_t
      dFixedLogicBaRegPortOut            => dFixedLogicBaRegPortOut,             --out BaRegPortOut_t
      bTriggerRoutingBaRegPortInAddress  => bTriggerRoutingBaRegPortInAddress,   --out std_logic_vector(BaRegPortAddress_t'range)
      bTriggerRoutingBaRegPortInData     => bTriggerRoutingBaRegPortInData,      --out std_logic_vector(BaRegPortData_t'range)
      bTriggerRoutingBaRegPortInWtStrobe => bTriggerRoutingBaRegPortInWtStrobe,  --out std_logic_vector(BaRegPortStrobe_t'range)
      bTriggerRoutingBaRegPortInRdStrobe => bTriggerRoutingBaRegPortInRdStrobe,  --out std_logic_vector(BaRegPortStrobe_t'range)
      bTriggerRoutingBaRegPortOutData    => bTriggerRoutingBaRegPortOutData,     --in  std_logic_vector(BaRegPortData_t'range)
      bTriggerRoutingBaRegPortOutAck     => bTriggerRoutingBaRegPortOutAck,      --in  std_logic
      bRoutingClipPresent                => bRoutingClipPresent,                 --in  std_logic
      bRoutingClipNiCompatible           => bRoutingClipNiCompatible,            --in  std_logic
      stEnableIoRefClk10                 => kEnableIoRefClk10,                   --in  std_logic
      stEnableIoRefClk100                => kEnableIoRefClk100,                  --in  std_logic
      bAxiStreamDataToCtrl               => bAxiStreamDataToCtrl,                --in  AxiStreamData_t
      bAxiStreamReadyFromCtrl            => bAxiStreamReadyFromCtrl,             --out boolean
      bAxiStreamDataFromCtrl             => bAxiStreamDataFromCtrl,              --out AxiStreamData_t
      bAxiStreamReadyToCtrl              => bAxiStreamReadyToCtrl,               --in  boolean
      bBaseSmbSclOut                     => aI2cSclOut(kBaseSmbIndex),           --out std_logic
      bBaseSmbSclIn                      => aI2cSclIn(kBaseSmbIndex),            --in  std_logic
      bBaseSmbSclTri                     => aI2cSclTri(kBaseSmbIndex),           --out std_logic
      bBaseSmbSdaIn                      => aI2cSdaIn(kBaseSmbIndex),            --in  std_logic
      bBaseSmbSdaOut                     => aI2cSdaOut(kBaseSmbIndex),           --out std_logic
      bBaseSmbSdaTri                     => aI2cSdaTri(kBaseSmbIndex),           --out std_logic
      bConfigI2cSclIn                    => aI2cSclIn(kConfigI2cIndex),          --in  std_logic
      bConfigI2cSclOut                   => aI2cSclOut(kConfigI2cIndex),         --out std_logic
      bConfigI2cSclTri                   => aI2cSclTri(kConfigI2cIndex),         --out std_logic
      bConfigI2cSdaIn                    => aI2cSdaIn(kConfigI2cIndex),          --in  std_logic
      bConfigI2cSdaOut                   => aI2cSdaOut(kConfigI2cIndex),         --out std_logic
      bConfigI2cSdaTri                   => aI2cSdaTri(kConfigI2cIndex),         --out std_logic
      bPwrSupplyPmbSclIn                 => aI2cSclIn(kPwrSupplyPmbIndex),       --in  std_logic
      bPwrSupplyPmbSclOut                => aI2cSclOut(kPwrSupplyPmbIndex),      --out std_logic
      bPwrSupplyPmbSclTri                => aI2cSclTri(kPwrSupplyPmbIndex),      --out std_logic
      bPwrSupplyPmbSdaIn                 => aI2cSdaIn(kPwrSupplyPmbIndex),       --in  std_logic
      bPwrSupplyPmbSdaOut                => aI2cSdaOut(kPwrSupplyPmbIndex),      --out std_logic
      bPwrSupplyPmbSdaTri                => aI2cSdaTri(kPwrSupplyPmbIndex),      --out std_logic
      bIoSmbSclIn                        => aI2cSclIn(kIoSmbIndex),              --in  std_logic
      bIoSmbSclOut                       => aI2cSclOut(kIoSmbIndex),             --out std_logic
      bIoSmbSclTri                       => aI2cSclTri(kIoSmbIndex),             --out std_logic
      bIoSmbSdaIn                        => aI2cSdaIn(kIoSmbIndex),              --in  std_logic
      bIoSmbSdaOut                       => aI2cSdaOut(kIoSmbIndex),             --out std_logic
      bIoSmbSdaTri                       => aI2cSdaTri(kIoSmbIndex),             --out std_logic
      bDigiPotSclk                       => bDigiPotSclk,                        --out std_logic
      bDigiPotMosi                       => bDigiPotMosi,                        --out std_logic
      bDigiPotMiso                       => bDigiPotMiso,                        --in  std_logic
      bDigiPotSync_n                     => bDigiPotSync_n,                      --out std_logic
      aTdcAllPeclEn                      => aTdcAllPeclEn,                       --out std_logic
      aTdcExpandedPulse                  => aTdcExpandedPulse,                   --in  std_logic
      bDramClocksValid                   => bDramClocksValid,                    --out std_logic
      aModulePresent_n                   => aModulePresent_n,                    --in  std_logic
      aFamPowerGood                      => aFamPowerGood,                       --in  std_logic
      bFamOutputEnable                   => bFamOutputEnable,                    --out std_logic
      stIoModuleSupportsFRAGLs           => stIoModuleSupportsFRAGLs,            --in  std_logic
      bdClipAxi4LiteArAddr               => bdClipAxi4LiteArAddr,                --in  std_logic_vector(31:0)
      bdClipAxi4LiteArProt               => bdClipAxi4LiteArProt,                --in  std_logic_vector(2:0)
      bdClipAxi4LiteArReady              => bdClipAxi4LiteArReady,               --out std_logic
      bdClipAxi4LiteArValid              => bdClipAxi4LiteArValid,               --in  std_logic
      bdClipAxi4LiteAwAddr               => bdClipAxi4LiteAwAddr,                --in  std_logic_vector(31:0)
      bdClipAxi4LiteAwProt               => bdClipAxi4LiteAwProt,                --in  std_logic_vector(2:0)
      bdClipAxi4LiteAwReady              => bdClipAxi4LiteAwReady,               --out std_logic
      bdClipAxi4LiteAwValid              => bdClipAxi4LiteAwValid,               --in  std_logic
      bdClipAxi4LiteBReady               => bdClipAxi4LiteBReady,                --in  std_logic
      bdClipAxi4LiteBResp                => bdClipAxi4LiteBResp,                 --out std_logic_vector(1:0)
      bdClipAxi4LiteBValid               => bdClipAxi4LiteBValid,                --out std_logic
      bdClipAxi4LiteRData                => bdClipAxi4LiteRData,                 --out std_logic_vector(31:0)
      bdClipAxi4LiteRReady               => bdClipAxi4LiteRReady,                --in  std_logic
      bdClipAxi4LiteRResp                => bdClipAxi4LiteRResp,                 --out std_logic_vector(1:0)
      bdClipAxi4LiteRValid               => bdClipAxi4LiteRValid,                --out std_logic
      bdClipAxi4LiteWData                => bdClipAxi4LiteWData,                 --in  std_logic_vector(31:0)
      bdClipAxi4LiteWReady               => bdClipAxi4LiteWReady,                --out std_logic
      bdClipAxi4LiteWStrb                => bdClipAxi4LiteWStrb,                 --in  std_logic_vector(3:0)
      bdClipAxi4LiteWValid               => bdClipAxi4LiteWValid,                --in  std_logic
      SidebandClk                        => SidebandClk,                         --out std_logic
      sSidebandDataOut                   => sSidebandDataOut,                    --out std_logic_vector(3:0)
      aSidebandDataIn                    => aSidebandDataIn,                     --in  std_logic
      aSidebandFifoFull                  => aSidebandFifoFull,                   --in  std_logic
      aAuxIoEnable_n                     => aAuxIoEnable_n,                      --out std_logic
      aAuxVccAEnable                     => aAuxVccAEnable,                      --out std_logic
      aAux5vEnable                       => aAux5vEnable,                        --out std_logic
      aAux3v3Enable                      => aAux3v3Enable,                       --out std_logic
      aAux3v3Fault_n                     => aAux3v3Fault_n,                      --in  std_logic
      abDiagramReset                     => abDiagramReset,                      --out boolean
      bdRequestaLvAuxDio                 => bdRequestaLvAuxDio,                  --in  std_logic_vector(7:0)
      bdDirectionaLvAuxDio               => bdDirectionaLvAuxDio,                --in  std_logic_vector(7:0)
      bdDoneaLvAuxDio                    => bdDoneaLvAuxDio,                     --out std_logic_vector(7:0)
      aAuxIoOutputEn                     => aAuxIoOutputEn,                      --out std_logic_vector(7:0)
      aSysMonVector_p                    => aSysMonVector_p,                     --in  std_logic_vector(15:0)
      aSysMonVector_n                    => aSysMonVector_n,                     --in  std_logic_vector(15:0)
      aFldUpdJtagSel                     => aFldUpdJtagSel,                      --out std_logic
      bFldUpdJtagTck                     => bFldUpdJtagTck,                      --out std_logic
      bFldUpdJtagTdi                     => bFldUpdJtagTdi,                      --out std_logic
      aFldUpdJtagTdo                     => aFldUpdJtagTdo,                      --in  std_logic
      bFldUpdJtagTms                     => bFldUpdJtagTms,                      --out std_logic
      dIrqFromFixedLogic                 => dIrqFromFixedLogic,                  --out std_logic
      aClockMiso                         => aClockMiso,                          --in  std_logic
      aClockMosi                         => aClockMosi,                          --out std_logic
      aClockSck                          => aClockSck,                           --out std_logic
      aLmkCs_n                           => aLmkCs_n,                            --out std_logic
      aPhaseDacCs_n                      => aPhaseDacCs_n,                       --out std_logic
      aDirectVcxo                        => aDirectVcxo,                         --out std_logic
      aEnRefIn                           => aEnRefIn,                            --out std_logic
      aLmkStatus                         => aLmkStatus,                          --in  std_logic
      aFpgaSyncClockOutEn                => aFpgaSyncClockOutEn,                 --out std_logic
      aLmkConfigured                     => aLmkConfigured,                      --out boolean
      aFan0Pwm                           => aFan0Pwm,                            --out std_logic
      aFan1Pwm                           => aFan1Pwm,                            --out std_logic
      aFan0Tach                          => aFan0Tach,                           --in  std_logic
      aFan1Tach                          => aFan1Tach,                           --in  std_logic
      aFanPwrGood_n                      => aFanPwrGood_n,                       --in  std_logic
      aFanPwrEn                          => aFanPwrEn,                           --out std_logic
      aTrigPortExpReset_n                => aTrigPortExpReset_n);                --out std_logic

  aSysMonVector_p <= (kSysMonDdrVrefSense     => aSysMonDdrVrefSense_p,
                      kSysMon1v2CicadaDivided => aSysMon1v2CicadaDivided_p,
                      kSysMon1v2MgtDivided    => aSysMon1v2MgtDivided_p,
                      kSysMon1v8MgtDivided    => aSysMon1v8MgtDivided_p,
                      kSysMonVccAuxADivided   => aSysMonVccAuxADivided_p,
                      kSysMon3v3AuxDivided    => aSysMon3v3AuxDivided_p,
                      kSysMon3v3ClkDivided    => aSysMon3v3ClkDivided_p,
                      kSysMon5vAuxDivided     => aSysMon5vAuxDivided_p,
                      kSysMon1v0MgtDivided    => aSysMon1v0MgtDivided_p,
                      kSysMon1v2ADivided      => aSysMon1v2ADivided_p,
                      kSysMon1v8SwDivided     => aSysMon1v8SwDivided_p,
                      kSysMonVppDivided       => aSysMonVppDivided_p,
                      kSysMon3v3CpldDivided   => aSysMon3v3CpldDivided_p,
                      kSysMon3v3IoDivided     => aSysMon3v3IoDivided_p,
                      kSysMon3v8IntDivided    => aSysMon3v8IntDivided_p,
                      kSysMonVtt0v6Sense      => aSysMonVtt0v6Sense_p,
                      others                  => '0');

  aSysMonVector_n <= (kSysMonDdrVrefSense     => aSysMonDdrVrefSense_n,
                      kSysMon1v2CicadaDivided => aSysMon1v2CicadaDivided_n,
                      kSysMon1v2MgtDivided    => aSysMon1v2MgtDivided_n,
                      kSysMon1v8MgtDivided    => aSysMon1v8MgtDivided_n,
                      kSysMonVccAuxADivided   => aSysMonVccAuxADivided_n,
                      kSysMon3v3AuxDivided    => aSysMon3v3AuxDivided_n,
                      kSysMon3v3ClkDivided    => aSysMon3v3ClkDivided_n,
                      kSysMon5vAuxDivided     => aSysMon5vAuxDivided_n,
                      kSysMon1v0MgtDivided    => aSysMon1v0MgtDivided_n,
                      kSysMon1v2ADivided      => aSysMon1v2ADivided_n,
                      kSysMon1v8SwDivided     => aSysMon1v8SwDivided_n,
                      kSysMonVppDivided       => aSysMonVppDivided_n,
                      kSysMon3v3CpldDivided   => aSysMon3v3CpldDivided_n,
                      kSysMon3v3IoDivided     => aSysMon3v3IoDivided_n,
                      kSysMon3v8IntDivided    => aSysMon3v8IntDivided_n,
                      kSysMonVtt0v6Sense      => aSysMonVtt0v6Sense_n,
                      others                  => '0');


  ---------------------------------------------------------------------------------------
  -- IO BUFFERs
  ---------------------------------------------------------------------------------------

  --vhook_e  MacallanIoBuffers
  --vhook_#  I2C Outputs
  --vhook_af {aI2c(Scl|Sda)$}(kIoSmbIndex)              {bIoSmb$1}            continue=true
  --vhook_af {aI2c(Scl|Sda)$}(kBaseSmbIndex)            {bBaseSmb$1}          continue=true
  --vhook_af {aI2c(Scl|Sda)$}(kConfigI2cIndex)          {bConfigI2c$1}        continue=true
  --vhook_af {aI2c(Scl|Sda)$}(kPwrSupplyPmbIndex)       {bPwrSupplyPmb$1}
  --vhook_#  Loopback (unused)
  --vhook_a  aFpgaLoopbackOut                           '0'
  --vhook_a  aFpgaLoopbackIn                            open
  --vhook_#  Out Enables that are currently unused
  --vhook_a  aPxieDStarCEn_n                            '0'
  --vhook_a  aPxieDStar*                                '0'                   mode=in
  --vhook_a  aPxieDStar*                                open                  mode=out
  MacallanIoBuffersx: entity work.MacallanIoBuffers (struct)
    generic map (
      kNumI2cIfcs   => kNumI2cIfcs,    --natural:=5
      kNumAuxIoData => kNumAuxIoData)  --natural:=8
    port map (
      aI2cSclIn                   => aI2cSclIn,              --out std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSclOut                  => aI2cSclOut,             --in  std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSclTri                  => aI2cSclTri,             --in  std_logic_vector(kNumI2cIfcs-1:0)
      aI2cScl(kIoSmbIndex)        => bIoSmbScl,              --inout std_logic_vector(kNumI2cIfcs-1:0)
      aI2cScl(kBaseSmbIndex)      => bBaseSmbScl,            --inout std_logic_vector(kNumI2cIfcs-1:0)
      aI2cScl(kConfigI2cIndex)    => bConfigI2cScl,          --inout std_logic_vector(kNumI2cIfcs-1:0)
      aI2cScl(kPwrSupplyPmbIndex) => bPwrSupplyPmbScl,       --inout std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSdaIn                   => aI2cSdaIn,              --out std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSdaOut                  => aI2cSdaOut,             --in  std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSdaTri                  => aI2cSdaTri,             --in  std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSda(kIoSmbIndex)        => bIoSmbSda,              --inout std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSda(kBaseSmbIndex)      => bBaseSmbSda,            --inout std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSda(kConfigI2cIndex)    => bConfigI2cSda,          --inout std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSda(kPwrSupplyPmbIndex) => bPwrSupplyPmbSda,       --inout std_logic_vector(kNumI2cIfcs-1:0)
      aPxiTrigDataIn              => aPxiTrigDataIn,         --out std_logic_vector(7:0)
      aPxiTrigDataOut             => aPxiTrigDataOut,        --in  std_logic_vector(7:0)
      aPxiTrigDataTri             => aPxiTrigDataTri,        --in  std_logic_vector(7:0)
      aPxiTrigData                => aPxiTrigData,           --inout std_logic_vector(7:0)
      aPxieDStarB                 => open,                   --out std_logic
      aPxieDStarB_p               => '0',                    --in  std_logic
      aPxieDStarB_n               => '0',                    --in  std_logic
      aPxieDStarC                 => '0',                    --in  std_logic
      aPxieDStarCEn_n             => '0',                    --in  std_logic
      aPxieDStarC_p               => open,                   --out std_logic
      aPxieDStarC_n               => open,                   --out std_logic
      aFpgaLoopbackOut            => '0',                    --in  std_logic
      aFpgaLoopbackOut_p          => aFpgaLoopbackOut_p,     --out std_logic
      aFpgaLoopbackOut_n          => aFpgaLoopbackOut_n,     --out std_logic
      aFpgaLoopbackIn             => open,                   --out std_logic
      aFpgaLoopbackIn_p           => aFpgaLoopbackIn_p,      --in  std_logic
      aFpgaLoopbackIn_n           => aFpgaLoopbackIn_n,      --in  std_logic
      aAuxIoData                  => aAuxIoData,             --inout std_logic_vector(kNumAuxIoData-1:0)
      aLvAuxDioOutputData         => aLvAuxDioOutputData,    --in  std_logic_vector(kNumAuxIoData-1:0)
      aLvAuxDioInputData          => aLvAuxDioInputData,     --out std_logic_vector(kNumAuxIoData-1:0)
      aLvAuxDioOutputEnable       => aLvAuxDioOutputEnable); --in  std_logic_vector(kNumAuxIoData-1:0)

  --vhook_e MacallanIoBuffersFam
  --vhook_a aFamOutputEnable            bFamOutputEnable
  MacallanIoBuffersFamx: entity work.MacallanIoBuffersFam (struct)
    port map (
      dvJesd204SysRef     => dvJesd204SysRef,      --out std_logic
      dvJesd204SysRef_p   => dvJesd204SysRef_p,    --in  std_logic
      dvJesd204SysRef_n   => dvJesd204SysRef_n,    --in  std_logic
      aFamOutputEnable    => bFamOutputEnable,     --in  std_logic
      aTriggerOut         => aTriggerOut,          --in  std_logic
      aTriggerOut_p       => aTriggerOut_p,        --out std_logic
      aTriggerOut_n       => aTriggerOut_n,        --out std_logic
      aTriggerIn          => aTriggerIn,           --out std_logic
      aTriggerIn_p        => aTriggerIn_p,         --in  std_logic
      aTriggerIn_n        => aTriggerIn_n,         --in  std_logic
      aTdcExpandedPulse_p => aTdcExpandedPulse_p,  --in  std_logic
      aTdcExpandedPulse_n => aTdcExpandedPulse_n,  --in  std_logic
      aTdcExpandedPulse   => aTdcExpandedPulse,    --out std_logic
      aConfigTxClkLvds_p  => aConfigTxClkLvds_p,   --out std_logic
      aConfigTxClkLvds_n  => aConfigTxClkLvds_n,   --out std_logic
      aConfigTxClkSe      => aConfigTxClkSe,       --out std_logic
      aConfigTxDataSe     => aConfigTxDataSe,      --out std_logic_vector(6:0)
      aConfigRxClkLvds_p  => aConfigRxClkLvds_p,   --in  std_logic
      aConfigRxClkLvds_n  => aConfigRxClkLvds_n,   --in  std_logic
      aConfigRxClkSe      => aConfigRxClkSe,       --in  std_logic
      aConfigRxDataSe     => aConfigRxDataSe,      --in  std_logic_vector(6:0)
      aConfigTxClkLvds    => aConfigTxClkLvds,     --in  std_logic
      aConfigTxClkSeBuf   => aConfigTxClkSeBuf,    --in  std_logic
      aConfigTxDataSeBuf  => aConfigTxDataSeBuf,   --in  std_logic_vector(6:0)
      aConfigRxClkLvds    => aConfigRxClkLvds,     --out std_logic
      aConfigRxClkSeBuf   => aConfigRxClkSeBuf,    --out std_logic
      aConfigRxDataSeBuf  => aConfigRxDataSeBuf,   --out std_logic_vector(6:0)
      DeviceClk           => DeviceClk,            --out std_logic
      DeviceClk_p         => DeviceClk_p,          --in  std_logic
      DeviceClk_n         => DeviceClk_n);         --in  std_logic

  --vhook_e MacallanIoBuffersStage1
  --vhook_g kInstantiatePxiGaBuf false
  --vhook_a aPxiGa (others => '0')
  --vhook_a aGa open
  MacallanIoBuffersStage1x: entity work.MacallanIoBuffersStage1 (struct)
    generic map (kInstantiatePxiGaBuf => false)  --boolean:=true
    port map (
      aStage2Enabled  => aStage2Enabled,   --in  boolean
      aAuthSdaIn      => aAuthSdaIn,       --out std_logic
      aAuthSdaOut     => aAuthSdaOut,      --in  std_logic
      aAuthSda        => aAuthSda,         --inout std_logic
      aPxiGa          => (others => '0'),  --in  std_logic_vector(4:0)
      aGa             => open,             --out std_logic_vector(4:0)
      aPcieRst_n      => aPcieRst_n,       --in  std_logic
      aPcieRst        => aPcieRst,         --out std_logic
      aFpgaStage2Done => aFpgaStage2Done); --out std_logic

  -- Register-port response merge (Garrison/PCIe: no Dram2DP term — the window and UserHdl are the
  -- only register-port responders).
  bRegPortOut.Data <= bLvWindowRegPortOut.Data or
                      bRegPortOutUserHdl.Data;

  bRegPortOut.DataValid <= bLvWindowRegPortOut.DataValid or
                           bRegPortOutUserHdl.DataValid;

  bRegPortOut.Ready <= bLvWindowRegPortOut.Ready and
                       bRegPortOutUserHdl.Ready;

  ---------------------------------------------------------------------------
  -- User HDL block (registers + FIFOs)
  -- Board I/O is disabled on the LV Window for this custom target
  -- (set_include_board_io_on_lv_window(False)). Every port inside "% if include_board_io" in THIS
  -- board's base-target TheWindow.vhd.mako is therefore routed here into UserHdl instead of the
  -- window/flat wrapper. The exact set is board-specific and mirrors this board's own base-target
  -- board I/O (do not copy it from another board).
  ---------------------------------------------------------------------------
  UserHdl_inst : entity work.UserHdl
    port map(
      BusClk         => BusClk,
      DmaClk         => DmaClk,
      aBusReset      => aBusReset,
      aDiagramReset  => aDiagramReset,
      bRegPortIn     => bRegPortIn,
      bRegPortOut    => bRegPortOutUserHdl,
      -- Writer channel: conf(1) = TargetToHost at DMA index kUserHdlDmaStartIndex - 1
      dWriterInputStreamInterfaceToFifo    => dInputStreamInterfaceToFifo(kUserHdlDmaStartIndex - 1),
      dWriterInputStreamInterfaceFromFifo  => dInputStreamInterfaceFromFifo(kUserHdlDmaStartIndex - 1),
      dWriterOutputStreamInterfaceToFifo   => dOutputStreamInterfaceToFifo(kUserHdlDmaStartIndex - 1),
      dWriterOutputStreamInterfaceFromFifo => dOutputStreamInterfaceFromFifo(kUserHdlDmaStartIndex - 1),
      -- Reader channel: conf(0) = HostToTarget at DMA index kUserHdlDmaStartIndex
      dReaderInputStreamInterfaceToFifo    => dInputStreamInterfaceToFifo(kUserHdlDmaStartIndex),
      dReaderInputStreamInterfaceFromFifo  => dInputStreamInterfaceFromFifo(kUserHdlDmaStartIndex),
      dReaderOutputStreamInterfaceToFifo   => dOutputStreamInterfaceToFifo(kUserHdlDmaStartIndex),
      dReaderOutputStreamInterfaceFromFifo => dOutputStreamInterfaceFromFifo(kUserHdlDmaStartIndex),
      -- Board IO: board IO is disabled on the LV Window for this target
      -- (set_include_board_io_on_lv_window(False)), so every board IO interface
      -- that would normally connect to the LV Window is brought into UserHdl.
      -- The actuals mirror this target's reference non-custom TheWindow port map.
      -- DIO IO Node ports
      aLvAuxDio0OutputData   => aLvAuxDioOutputData(0),
      aLvAuxDio0InputData    => aLvAuxDioInputData(0),
      aLvAuxDio0OutputEnable => aLvAuxDioOutputEnable(0),
      oClkaLvAuxDio0         => BusClk,
      aoResetaLvAuxDio0      => to_StdLogic(abDiagramReset),
      oDoneaLvAuxDio0        => bdDoneaLvAuxDio(0),
      oDirectionaLvAuxDio0   => bdDirectionaLvAuxDio(0),
      oRequestaLvAuxDio0     => bdRequestaLvAuxDio(0),
      aLvAuxDio1OutputData   => aLvAuxDioOutputData(1),
      aLvAuxDio1InputData    => aLvAuxDioInputData(1),
      aLvAuxDio1OutputEnable => aLvAuxDioOutputEnable(1),
      oClkaLvAuxDio1         => BusClk,
      aoResetaLvAuxDio1      => to_StdLogic(abDiagramReset),
      oDoneaLvAuxDio1        => bdDoneaLvAuxDio(1),
      oDirectionaLvAuxDio1   => bdDirectionaLvAuxDio(1),
      oRequestaLvAuxDio1     => bdRequestaLvAuxDio(1),
      aLvAuxDio2OutputData   => aLvAuxDioOutputData(2),
      aLvAuxDio2InputData    => aLvAuxDioInputData(2),
      aLvAuxDio2OutputEnable => aLvAuxDioOutputEnable(2),
      oClkaLvAuxDio2         => BusClk,
      aoResetaLvAuxDio2      => to_StdLogic(abDiagramReset),
      oDoneaLvAuxDio2        => bdDoneaLvAuxDio(2),
      oDirectionaLvAuxDio2   => bdDirectionaLvAuxDio(2),
      oRequestaLvAuxDio2     => bdRequestaLvAuxDio(2),
      aLvAuxDio3OutputData   => aLvAuxDioOutputData(3),
      aLvAuxDio3InputData    => aLvAuxDioInputData(3),
      aLvAuxDio3OutputEnable => aLvAuxDioOutputEnable(3),
      oClkaLvAuxDio3         => BusClk,
      aoResetaLvAuxDio3      => to_StdLogic(abDiagramReset),
      oDoneaLvAuxDio3        => bdDoneaLvAuxDio(3),
      oDirectionaLvAuxDio3   => bdDirectionaLvAuxDio(3),
      oRequestaLvAuxDio3     => bdRequestaLvAuxDio(3),
      aLvAuxDio4OutputData   => aLvAuxDioOutputData(4),
      aLvAuxDio4InputData    => aLvAuxDioInputData(4),
      aLvAuxDio4OutputEnable => aLvAuxDioOutputEnable(4),
      oClkaLvAuxDio4         => BusClk,
      aoResetaLvAuxDio4      => to_StdLogic(abDiagramReset),
      oDoneaLvAuxDio4        => bdDoneaLvAuxDio(4),
      oDirectionaLvAuxDio4   => bdDirectionaLvAuxDio(4),
      oRequestaLvAuxDio4     => bdRequestaLvAuxDio(4),
      aLvAuxDio5OutputData   => aLvAuxDioOutputData(5),
      aLvAuxDio5InputData    => aLvAuxDioInputData(5),
      aLvAuxDio5OutputEnable => aLvAuxDioOutputEnable(5),
      oClkaLvAuxDio5         => BusClk,
      aoResetaLvAuxDio5      => to_StdLogic(abDiagramReset),
      oDoneaLvAuxDio5        => bdDoneaLvAuxDio(5),
      oDirectionaLvAuxDio5   => bdDirectionaLvAuxDio(5),
      oRequestaLvAuxDio5     => bdRequestaLvAuxDio(5),
      aLvAuxDio6OutputData   => aLvAuxDioOutputData(6),
      aLvAuxDio6InputData    => aLvAuxDioInputData(6),
      aLvAuxDio6OutputEnable => aLvAuxDioOutputEnable(6),
      oClkaLvAuxDio6         => BusClk,
      aoResetaLvAuxDio6      => to_StdLogic(abDiagramReset),
      oDoneaLvAuxDio6        => bdDoneaLvAuxDio(6),
      oDirectionaLvAuxDio6   => bdDirectionaLvAuxDio(6),
      oRequestaLvAuxDio6     => bdRequestaLvAuxDio(6),
      aLvAuxDio7OutputData   => aLvAuxDioOutputData(7),
      aLvAuxDio7InputData    => aLvAuxDioInputData(7),
      aLvAuxDio7OutputEnable => aLvAuxDioOutputEnable(7),
      oClkaLvAuxDio7         => BusClk,
      aoResetaLvAuxDio7      => to_StdLogic(abDiagramReset),
      oDoneaLvAuxDio7        => bdDoneaLvAuxDio(7),
      oDirectionaLvAuxDio7   => bdDirectionaLvAuxDio(7),
      oRequestaLvAuxDio7     => bdRequestaLvAuxDio(7),
      -- CLIP Socket
      AxiClk                          => BusClk,
      xDiagramAxiStreamFromClipTData  => xDiagramAxiStreamFromClipTData,
      xDiagramAxiStreamFromClipTLast  => xDiagramAxiStreamFromClipTLast,
      xDiagramAxiStreamFromClipTReady => xDiagramAxiStreamFromClipTReady,
      xDiagramAxiStreamFromClipTValid => xDiagramAxiStreamFromClipTValid,
      xDiagramAxiStreamToClipTData    => xDiagramAxiStreamToClipTData,
      xDiagramAxiStreamToClipTLast    => xDiagramAxiStreamToClipTLast,
      xDiagramAxiStreamToClipTReady   => xDiagramAxiStreamToClipTReady,
      xDiagramAxiStreamToClipTValid   => xDiagramAxiStreamToClipTValid,
      xHostAxiStreamFromClipTData     => xHostAxiStreamFromClipTData,
      xHostAxiStreamFromClipTLast     => xHostAxiStreamFromClipTLast,
      xHostAxiStreamFromClipTReady    => xHostAxiStreamFromClipTReady,
      xHostAxiStreamFromClipTValid    => xHostAxiStreamFromClipTValid,
      xHostAxiStreamToClipTData       => xHostAxiStreamToClipTData,
      xHostAxiStreamToClipTLast       => xHostAxiStreamToClipTLast,
      xHostAxiStreamToClipTReady      => xHostAxiStreamToClipTReady,
      xHostAxiStreamToClipTValid      => xHostAxiStreamToClipTValid,
      xClipAxi4LiteMasterARAddr       => bdClipAxi4LiteARAddr,
      xClipAxi4LiteMasterARProt       => bdClipAxi4LiteARProt,
      xClipAxi4LiteMasterARReady      => bdClipAxi4LiteARReady,
      xClipAxi4LiteMasterARValid      => bdClipAxi4LiteARValid,
      xClipAxi4LiteMasterAWAddr       => bdClipAxi4LiteAWAddr,
      xClipAxi4LiteMasterAWProt       => bdClipAxi4LiteAWProt,
      xClipAxi4LiteMasterAWReady      => bdClipAxi4LiteAWReady,
      xClipAxi4LiteMasterAWValid      => bdClipAxi4LiteAWValid,
      xClipAxi4LiteMasterBReady       => bdClipAxi4LiteBReady,
      xClipAxi4LiteMasterBResp        => bdClipAxi4LiteBResp,
      xClipAxi4LiteMasterBValid       => bdClipAxi4LiteBValid,
      xClipAxi4LiteMasterRData        => bdClipAxi4LiteRData,
      xClipAxi4LiteMasterRReady       => bdClipAxi4LiteRReady,
      xClipAxi4LiteMasterRResp        => bdClipAxi4LiteRResp,
      xClipAxi4LiteMasterRValid       => bdClipAxi4LiteRValid,
      xClipAxi4LiteMasterWData        => bdClipAxi4LiteWData,
      xClipAxi4LiteMasterWReady       => bdClipAxi4LiteWReady,
      xClipAxi4LiteMasterWStrb        => bdClipAxi4LiteWStrb,
      xClipAxi4LiteMasterWValid       => bdClipAxi4LiteWValid,
      xClipAxi4LiteInterrupt          => '0',
      -- Configuration Interface
      aConfigTxClkLvds                => aConfigTxClkLvds,
      aConfigTxClkSe                  => aConfigTxClkSeBuf,
      aConfigTxDataSe                 => aConfigTxDataSeBuf,
      aConfigRxClkLvds                => aConfigRxClkLvds,
      aConfigRxClkSe                  => aConfigRxClkSeBuf,
      aConfigRxDataSe                 => aConfigRxDataSeBuf,
      -- Reserved GPIO
      aRsrvGpio_n                     => aRsrvGpio_n,
      aRsrvGpio_p                     => aRsrvGpio_p,
      -- Reserved CLIP
      aReservedToClip                 => aReservedToClip,
      aReservedFromClip               => aReservedFromClip,
      stIoModuleSupportsFRAGLs        => stIoModuleSupportsFRAGLs,
      -- General purpose Synchronization
      aGpoSync                        => aGpoSync,
      aTriggerIn                      => aTriggerIn,
      aTriggerOut                     => aTriggerOut,
      -- Synchronization
      DeviceClk                       => DeviceClk,
      aJesd204SyncReqIn_n             => aJesd204SyncReqIn_n,
      aJesd204SyncReqOut_n            => aJesd204SyncReqOut_n,
      dvJesd204SysRef                 => dvJesd204SysRef,
      dvTdcAssert                     => dvTdcAssert,
      dtTdcAssert                     => dtTdcAssert,
      dtDevClkEn                      => dtDevClkEn,
      -- IO MGT Ports
      MgtPortRx_n                     => MgtPortRx_n,
      MgtPortRx_p                     => MgtPortRx_p,
      MgtPortTx_n                     => MgtPortTx_n,
      MgtPortTx_p                     => MgtPortTx_p,
      MgtRefClk_p                     => MgtRefClk_p,
      MgtRefClk_n                     => MgtRefClk_n,
      ExportedMgtRefClk               => ExportedMgtRefClk,
      -- Aux DIO MGT (this board's include_board_io exposes it; routed to UserHdl)
      DioMgtRefClk_p                  => AuxIoMgtRefClk_p,
      DioMgtRefClk_n                  => AuxIoMgtRefClk_n,
      DioMgtRefClkFromFam             => ExportedMgtRefClk,
      DioMgtRX_n                      => AuxIoMgtRX_n,
      DioMgtRX_p                      => AuxIoMgtRX_p,
      DioMgtTX_n                      => AuxIoMgtTX_n,
      DioMgtTX_p                      => AuxIoMgtTX_p,
      SocketClk80                     => BusClk,
      sDioMgtRefClkFromFamPresent     => '1'
    );

  ---------------------------------------------------------------------------
  -- Stream Interface Routing
  ---------------------------------------------------------------------------
  -- For each of the 64 DMA channels, four stream arrays connect the DMA
  -- engine (HostInterface) to TheWindow.
  --
  -- LV DMA channels start at index 0 and grow upward.
  -- UserHdl channels start at kUserHdlDmaStartIndex and grow downward:
  --   conf(0) -> index kUserHdlDmaStartIndex
  --   conf(1) -> index kUserHdlDmaStartIndex - 1
  --   ...
  --   conf(N-1) -> index kUserHdlDmaStartIndex - (N-1)
  -- All UserHdl channel signals are owned by UserHdl (connected in port
  -- map above). Window-side ToFifo inputs are driven to zero defaults.

  StreamRouting : for i in dInputStreamInterfaceToFifo'range generate

    -- Normal channels: bidirectional pass-through to TheWindow
    NormalChannel : if i > kUserHdlDmaStartIndex or i < kUserHdlDmaStartIndex - kNumHdlFifos + 1 generate
      dWinInputStreamInterfaceToFifo(i)  <= dInputStreamInterfaceToFifo(i);
      dInputStreamInterfaceFromFifo(i)   <= dWinInputStreamInterfaceFromFifo(i);
      dWinOutputStreamInterfaceToFifo(i) <= dOutputStreamInterfaceToFifo(i);
      dOutputStreamInterfaceFromFifo(i)  <= dWinOutputStreamInterfaceFromFifo(i);
    end generate NormalChannel;

    -- UserHdl channels: all 4 signals connected to UserHdl via port map.
    -- Disconnect Window side by driving ToFifo inputs to zero.
    UserHdlChannel : if i <= kUserHdlDmaStartIndex and i >= kUserHdlDmaStartIndex - kNumHdlFifos + 1 generate
      dWinInputStreamInterfaceToFifo(i)  <= kInputStreamInterfaceToFifoZero;
      dWinOutputStreamInterfaceToFifo(i) <= kOutputStreamInterfaceToFifoZero;
    end generate UserHdlChannel;

  end generate StreamRouting;

  ---------------------------------------------------------------------------------------
  -- DRAM Instantiation (Garrison/PCIe native — direct DRAM controller, no Dram2DP/HMB)
  ---------------------------------------------------------------------------------------
  --vhook_e MacallanDram
  MacallanDramx: entity work.MacallanDram (struct)
    port map (
      aDramPonReset         => aDramPonReset,          --in  boolean
      Dram0RefClk_p         => Dram0RefClk_p,          --in  std_logic
      Dram0RefClk_n         => Dram0RefClk_n,          --in  std_logic
      Dram1RefClk_p         => Dram1RefClk_p,          --in  std_logic
      Dram1RefClk_n         => Dram1RefClk_n,          --in  std_logic
      DramClkLvFpga         => DramClkLvFpga,          --out std_logic
      Dram0Clk_p            => Dram0Clk_p,             --out std_logic
      Dram0Clk_n            => Dram0Clk_n,             --out std_logic
      dr0DramCs_n           => dr0DramCs_n,            --out std_logic
      dr0DramAct_n          => dr0DramAct_n,           --out std_logic
      dr0DramAddr           => dr0DramAddr,            --out std_logic_vector(16:0)
      dr0DramBankAddr       => dr0DramBankAddr,        --out std_logic_vector(1:0)
      dr0DramBg             => dr0DramBg,              --out std_logic_vector(0:0)
      dr0DramClkEn          => dr0DramClkEn,           --out std_logic
      dr0DramOdt            => dr0DramOdt,             --out std_logic
      dr0DramReset_n        => dr0DramReset_n,         --out std_logic
      dr0DramDmDbi_n        => dr0DramDmDbi_n,         --inout std_logic_vector(3:0)
      dr0DramDq             => dr0DramDq,              --inout std_logic_vector(31:0)
      dr0DramDqs_p          => dr0DramDqs_p,           --inout std_logic_vector(3:0)
      dr0DramDqs_n          => dr0DramDqs_n,           --inout std_logic_vector(3:0)
      dr0DramTestMode       => dr0DramTestMode,        --out std_logic
      Dram0ClkUser          => Dram0ClkUser,           --out std_logic
      du0DramPhyInitDone    => du0DramPhyInitDone,     --out std_logic
      du0DramAddrFifoFull   => du0DramAddrFifoFull,    --out std_logic
      du0DramAddrFifoAddr   => du0DramAddrFifoAddr,    --in  std_logic_vector(28:0)
      du0DramAddrFifoCmd    => du0DramAddrFifoCmd,     --in  std_logic_vector(2:0)
      du0DramAddrFifoWrEn   => du0DramAddrFifoWrEn,    --in  std_logic
      du0DramWrFifoFull     => du0DramWrFifoFull,      --out std_logic
      du0DramWrFifoWrEn     => du0DramWrFifoWrEn,      --in  std_logic
      du0DramWrFifoDataIn   => du0DramWrFifoDataIn,    --in  std_logic_vector(255:0)
      du0DramWrFifoMaskData => du0DramWrFifoMaskData,  --in  std_logic_vector(31:0)
      du0DramRdDataValid    => du0DramRdDataValid,     --out std_logic
      du0DramRdFifoDataOut  => du0DramRdFifoDataOut,   --out std_logic_vector(255:0)
      Dram1Clk_p            => Dram1Clk_p,             --out std_logic
      Dram1Clk_n            => Dram1Clk_n,             --out std_logic
      dr1DramCs_n           => dr1DramCs_n,            --out std_logic
      dr1DramAct_n          => dr1DramAct_n,           --out std_logic
      dr1DramAddr           => dr1DramAddr,            --out std_logic_vector(16:0)
      dr1DramBankAddr       => dr1DramBankAddr,        --out std_logic_vector(1:0)
      dr1DramBg             => dr1DramBg,              --out std_logic_vector(0:0)
      dr1DramClkEn          => dr1DramClkEn,           --out std_logic
      dr1DramOdt            => dr1DramOdt,             --out std_logic
      dr1DramReset_n        => dr1DramReset_n,         --out std_logic
      dr1DramDmDbi_n        => dr1DramDmDbi_n,         --inout std_logic_vector(3:0)
      dr1DramDq             => dr1DramDq,              --inout std_logic_vector(31:0)
      dr1DramDqs_p          => dr1DramDqs_p,           --inout std_logic_vector(3:0)
      dr1DramDqs_n          => dr1DramDqs_n,           --inout std_logic_vector(3:0)
      dr1DramTestMode       => dr1DramTestMode,        --out std_logic
      Dram1ClkUser          => Dram1ClkUser,           --out std_logic
      du1DramPhyInitDone    => du1DramPhyInitDone,     --out std_logic
      du1DramAddrFifoFull   => du1DramAddrFifoFull,    --out std_logic
      du1DramAddrFifoAddr   => du1DramAddrFifoAddr,    --in  std_logic_vector(28:0)
      du1DramAddrFifoCmd    => du1DramAddrFifoCmd,     --in  std_logic_vector(2:0)
      du1DramAddrFifoWrEn   => du1DramAddrFifoWrEn,    --in  std_logic
      du1DramWrFifoFull     => du1DramWrFifoFull,      --out std_logic
      du1DramWrFifoWrEn     => du1DramWrFifoWrEn,      --in  std_logic
      du1DramWrFifoDataIn   => du1DramWrFifoDataIn,    --in  std_logic_vector(255:0)
      du1DramWrFifoMaskData => du1DramWrFifoMaskData,  --in  std_logic_vector(31:0)
      du1DramRdDataValid    => du1DramRdDataValid,     --out std_logic
      du1DramRdFifoDataOut  => du1DramRdFifoDataOut);  --out std_logic_vector(255:0)

  ---------------------------------------------------------------------------------------
  -- The Window (aka LVFPGA world)
  ---------------------------------------------------------------------------------------
  --vhook_i TheLvWindowFlatWrapper        TheLvWindowWrapper
  --vhook_# Clocking
  --vhook_a aBusReset                   to_StdLogic(aBusReset)
  --vhook_a ReliableClkIn               ReliableClk
  --vhook_a PllClk80                    BusClk
  --vhook_a {^d(Input|Output)StreamInterface(To|From)Fifo$} d$1StreamInterface$2FifoFlat
  --vhook_a {Dram([01])ClkSocket}       Dram$1ClkUser
  --vhook_a rGatedBaseClksValid         '1'
  --vhook_# Renaming DmaComms and RegPort Signals
  --vhook_a {^(dNiFpgaMaster.*)}        $1ArrayFlat
  --vhook_a bRegPortTimeout             to_stdlogic(bLvWindowRegPortTimeout)
  --vhook_a bRegPort(In|Out)            bRegPort$1Flat
  --vhook_a bIrqToInterface             bIrqToInterfaceFlat
  --vhook_# Unused Window signals
  --vhook_a TopLevelClkOut              open
  --vhook_a ReliableClkOut              open
  --vhook_a tDiagramActive              open
  --vhook_a rDiagramReset               open
  --vhook_a aSafeToEnableGatedClks      open
  --vhook_a rDerivedClockLostLockError  open
  --vhook_a aPxiStarData                '0'
  --vhook_# AuxDIO
  --vhook_a {^aLvAuxDio(.)(.+)}         aLvAuxDio$2($1)
  --vhook_a {oClkaLvAuxDio(.)}          BusClk
  --vhook_a {aoResetaLvAuxDio(.)}       to_StdLogic(abDiagramReset)
  --vhook_a {^o(.+LvAuxDio)(.)}         bd$1($2)
  --vhook_# AuxDIO MGT
  --vhook_a {DioMgt(.*)}                AuxIoMgt$1
  --vhook_a DioMgtRefClkFromFam         ExportedMgtRefClk
  --vhook_a sDioMgtRefClkFromFamPresent '1'
  --vhook_a SocketClk80                 BusClk
  --vhook_# ------------------------------------
  --vhook_# CLIP Signals
  --vhook_# ------------------------------------
  --vhook_# CLIP AxiStream
  --vhook_a AxiClk                      BusClk
  --vhook_a xClipAxi4LiteInterrupt      '0'
  --vhook_# Clip-FixedLogic Axi4Lite
  --vhook_a {x(ClipAxi4Lite)Master(.*)} bd$1$2
  --vhook_# FAM Config
  --vhook_a {aConfig(.)x(Clk|Data)Se}   aConfig$1x$2SeBuf
  --vhook_# Diagram to CLIP AxiStream
  --vhook_a {bdAxiStream(Rd|Wr)(.*)}    xDiagramAxiStream$2
  --vhook_# Trigger Socket
  --vhook_a BusClkTrigger               BusClk
  --vhook_a abBusResetTrigger           to_StdLogic(abBusReset)
  --vhook_a PxieClk100Trigger           PxieClk100
  --vhook_a pIntSync100Trigger          pIntSync100
  --vhook_a aIntClk10Trigger            aIntClk10
  --vhook_a dTdcAssert                  dtTdcAssert
  --vhook_a dDevClkEn                   dtDevClkEn
  TheLvWindowWrapper: TheLvWindowFlatWrapper
    port map (
      aBusReset                           => to_StdLogic(aBusReset),                                 --in  boolean
      bRegPortIn                          => bRegPortInFlat,                        --in  RegPortIn_t
      bRegPortOut                         => bRegPortOutFlat,                       --out RegPortOut_t
      bRegPortTimeout                     => to_stdlogic(bLvWindowRegPortTimeout),                   --in  boolean
      dInputStreamInterfaceToFifo         => dInputStreamInterfaceToFifoFlat,               --in  InputStreamInterfaceToFifoArray_t(Larger(kNumberOfDmaChannels, 1)-1:0)
      dInputStreamInterfaceFromFifo       => dInputStreamInterfaceFromFifoFlat,             --out InputStreamInterfaceFromFifoArray_t(Larger(kNumberOfDmaChannels, 1)-1:0)
      dOutputStreamInterfaceToFifo        => dOutputStreamInterfaceToFifoFlat,              --in  OutputStreamInterfaceToFifoArray_t(Larger(kNumberOfDmaChannels, 1)-1:0)
      dOutputStreamInterfaceFromFifo      => dOutputStreamInterfaceFromFifoFlat,            --out OutputStreamInterfaceFromFifoArray_t(Larger(kNumberOfDmaChannels, 1)-1:0)
      bIrqToInterface                     => bIrqToInterfaceFlat,                           --out IrqToInterfaceArray_t(Larger(kNumberOfIrqs, 1)-1:0)
      dNiFpgaMasterWriteRequestFromMaster => dNiFpgaMasterWriteRequestFromMasterArrayFlat,  --out NiFpgaMasterWriteRequestFromMasterArray_t(Larger(kNumberOfMasterPorts, 1)-1:0)
      dNiFpgaMasterWriteRequestToMaster   => dNiFpgaMasterWriteRequestToMasterArrayFlat,    --in  NiFpgaMasterWriteRequestToMasterArray_t(Larger(kNumberOfMasterPorts, 1)-1:0)
      dNiFpgaMasterWriteDataFromMaster    => dNiFpgaMasterWriteDataFromMasterArrayFlat,     --out NiFpgaMasterWriteDataFromMasterArray_t(Larger(kNumberOfMasterPorts, 1)-1:0)
      dNiFpgaMasterWriteDataToMaster      => dNiFpgaMasterWriteDataToMasterArrayFlat,       --in  NiFpgaMasterWriteDataToMasterArray_t(Larger(kNumberOfMasterPorts, 1)-1:0)
      dNiFpgaMasterWriteStatusToMaster    => dNiFpgaMasterWriteStatusToMasterArrayFlat,     --in  NiFpgaMasterWriteStatusToMasterArray_t(Larger(kNumberOfMasterPorts, 1)-1:0)
      dNiFpgaMasterReadRequestFromMaster  => dNiFpgaMasterReadRequestFromMasterArrayFlat,   --out NiFpgaMasterReadRequestFromMasterArray_t(Larger(kNumberOfMasterPorts, 1)-1:0)
      dNiFpgaMasterReadRequestToMaster    => dNiFpgaMasterReadRequestToMasterArrayFlat,     --in  NiFpgaMasterReadRequestToMasterArray_t(Larger(kNumberOfMasterPorts, 1)-1:0)
      dNiFpgaMasterReadDataToMaster       => dNiFpgaMasterReadDataToMasterArrayFlat,        --in  NiFpgaMasterReadDataToMasterArray_t(Larger(kNumberOfMasterPorts, 1)-1:0)
      DmaClk                              => DmaClk,                                    --in  std_logic
      BusClk                              => BusClk,                                    --in  std_logic
      ReliableClkIn                       => ReliableClk,                               --in  std_logic
      PllClk80                            => BusClk,                                    --in  std_logic
      DlyRefClk                           => DlyRefClk,                                 --in  std_logic
      PxieClk100                          => PxieClk100,                                --in  std_logic
      DramClkLvFpga                       => DramClkLvFpga,                             --in  std_logic
      Dram0ClkSocket                      => Dram0ClkUser,                              --in  std_logic
      Dram1ClkSocket                      => Dram1ClkUser,                              --in  std_logic
      Dram0ClkUser                        => Dram0ClkUser,                              --in  std_logic
      Dram1ClkUser                        => Dram1ClkUser,                              --in  std_logic
      pIntSync100                         => pIntSync100,                               --in  std_logic
      aIntClk10                           => aIntClk10,                                 --in  std_logic
      bdIFifoRdData                       => bdIFifoRdData,                             --out std_logic_vector(63:0)
      bdIFifoRdDataValid                  => bdIFifoRdDataValid,                        --out std_logic
      bdIFifoRdReadyForInput              => bdIFifoRdReadyForInput,                    --in  std_logic
      bdIFifoRdIsError                    => bdIFifoRdIsError,                          --out std_logic
      bdIFifoWrData                       => bdIFifoWrData,                             --in  std_logic_vector(63:0)
      bdIFifoWrDataValid                  => bdIFifoWrDataValid,                        --in  std_logic
      bdIFifoWrReadyForOutput             => bdIFifoWrReadyForOutput,                   --out std_logic
      bdAxiStreamRdFromClipTData          => xDiagramAxiStreamFromClipTData,            --in  std_logic_vector(31:0)
      bdAxiStreamRdFromClipTLast          => xDiagramAxiStreamFromClipTLast,            --in  std_logic
      bdAxiStreamRdFromClipTValid         => xDiagramAxiStreamFromClipTValid,           --in  std_logic
      bdAxiStreamRdToClipTReady           => xDiagramAxiStreamToClipTReady,             --out std_logic
      bdAxiStreamWrToClipTData            => xDiagramAxiStreamToClipTData,              --out std_logic_vector(31:0)
      bdAxiStreamWrToClipTLast            => xDiagramAxiStreamToClipTLast,              --out std_logic
      bdAxiStreamWrToClipTValid           => xDiagramAxiStreamToClipTValid,             --out std_logic
      bdAxiStreamWrFromClipTReady         => xDiagramAxiStreamFromClipTReady,           --in  std_logic
      PxieClk100Trigger                   => PxieClk100,                                --in  std_logic
      pIntSync100Trigger                  => pIntSync100,                               --in  std_logic
      dTdcAssert                          => dtTdcAssert,                               --out std_logic
      dDevClkEn                           => dtDevClkEn,                                --in  std_logic
      sTdcDeassert                        => sTdcDeassert,                              --out std_logic
      aIntClk10Trigger                    => aIntClk10,                                 --in  std_logic
      bRoutingClipPresent                 => bRoutingClipPresent,                       --out std_logic
      bRoutingClipNiCompatible            => bRoutingClipNiCompatible,                  --out std_logic
      BusClkTrigger                       => BusClk,                                    --in  std_logic
      abBusResetTrigger                   => to_StdLogic(abBusReset),                   --in  std_logic
      bTriggerRoutingBaRegPortInAddress   => bTriggerRoutingBaRegPortInAddress,         --in  std_logic_vector(27:0)
      bTriggerRoutingBaRegPortInData      => bTriggerRoutingBaRegPortInData,            --in  std_logic_vector(63:0)
      bTriggerRoutingBaRegPortInWtStrobe  => bTriggerRoutingBaRegPortInWtStrobe,        --in  std_logic_vector(7:0)
      bTriggerRoutingBaRegPortInRdStrobe  => bTriggerRoutingBaRegPortInRdStrobe,        --in  std_logic_vector(7:0)
      bTriggerRoutingBaRegPortOutData     => bTriggerRoutingBaRegPortOutData,           --out std_logic_vector(63:0)
      bTriggerRoutingBaRegPortOutAck      => bTriggerRoutingBaRegPortOutAck,            --out std_logic
      aPxiTrigDataIn                      => aPxiTrigDataIn,                            --in  std_logic_vector(7:0)
      aPxiTrigDataOut                     => aPxiTrigDataOut,                           --out std_logic_vector(7:0)
      aPxiTrigDataTri                     => aPxiTrigDataTri,                           --out std_logic_vector(7:0)
      aPxiStarData                        => '0',                                       --in  std_logic
      aDramReady                          => aDramReady,                                --in  std_logic
      du0DramAddrFifoAddr                 => du0DramAddrFifoAddr,                       --out std_logic_vector(28:0)
      du0DramAddrFifoCmd                  => du0DramAddrFifoCmd,                        --out std_logic_vector(2:0)
      du0DramAddrFifoFull                 => du0DramAddrFifoFull,                       --in  std_logic
      du0DramAddrFifoWrEn                 => du0DramAddrFifoWrEn,                       --out std_logic
      du0DramPhyInitDone                  => du0DramPhyInitDone,                        --in  std_logic
      du0DramRdDataValid                  => du0DramRdDataValid,                        --in  std_logic
      du0DramRdFifoDataOut                => du0DramRdFifoDataOut,                      --in  std_logic_vector(255:0)
      du0DramWrFifoDataIn                 => du0DramWrFifoDataIn,                       --out std_logic_vector(255:0)
      du0DramWrFifoFull                   => du0DramWrFifoFull,                         --in  std_logic
      du0DramWrFifoMaskData               => du0DramWrFifoMaskData,                     --out std_logic_vector(31:0)
      du0DramWrFifoWrEn                   => du0DramWrFifoWrEn,                         --out std_logic
      du1DramAddrFifoAddr                 => du1DramAddrFifoAddr,                       --out std_logic_vector(28:0)
      du1DramAddrFifoCmd                  => du1DramAddrFifoCmd,                        --out std_logic_vector(2:0)
      du1DramAddrFifoFull                 => du1DramAddrFifoFull,                       --in  std_logic
      du1DramAddrFifoWrEn                 => du1DramAddrFifoWrEn,                       --out std_logic
      du1DramPhyInitDone                  => du1DramPhyInitDone,                        --in  std_logic
      du1DramRdDataValid                  => du1DramRdDataValid,                        --in  std_logic
      du1DramRdFifoDataOut                => du1DramRdFifoDataOut,                      --in  std_logic_vector(255:0)
      du1DramWrFifoDataIn                 => du1DramWrFifoDataIn,                       --out std_logic_vector(255:0)
      du1DramWrFifoFull                   => du1DramWrFifoFull,                         --in  std_logic
      du1DramWrFifoMaskData               => du1DramWrFifoMaskData,                     --out std_logic_vector(31:0)
      du1DramWrFifoWrEn                   => du1DramWrFifoWrEn,                         --out std_logic
      TopLevelClkOut                      => open,                                      --out std_logic
      ReliableClkOut                      => open,                                      --out std_logic
      rBaseClksValid                      => rBaseClksValid,                            --in  std_logic:='1'
      tDiagramActive                      => open,                                      --out std_logic
      rDiagramReset                       => open,                                      --out std_logic
      aDiagramReset                       => aDiagramReset,                             --out std_logic
      rDerivedClockLostLockError          => open,                                      --out std_logic
      rGatedBaseClksValid                 => '1',                                       --in  std_logic:='1'
      aSafeToEnableGatedClks              => open);                                     --out std_logic

  -- Convert record inputs to flat
  -----------------------------------
  bRegPortInFlat <= to_StdLogicVector(bRegPortIn);

  dInputStreamInterfaceToFifoFlat <= FlattenStreamInterface(dWinInputStreamInterfaceToFifo);
  dOutputStreamInterfaceToFifoFlat <= FlattenStreamInterface(dWinOutputStreamInterfaceToFifo);

  -- Convert Master Port record inputs to flat
  gen_master_inputs_flat: for i in 0 to Larger(kNumberOfMasterPorts,1)-1 generate
    dNiFpgaMasterWriteRequestToMasterArrayFlat(
      (i+1)*SizeOf(kNiFpgaMasterWriteRequestToMasterZero)-1 downto
      i*SizeOf(kNiFpgaMasterWriteRequestToMasterZero)) <=
        std_logic_vector(FlattenMasterPortInterface(dNiFpgaMasterWriteRequestToMasterArray(i)));

    dNiFpgaMasterWriteDataToMasterArrayFlat(
      (i+1)*SizeOf(kNiFpgaMasterWriteDataToMasterZero)-1 downto
      i*SizeOf(kNiFpgaMasterWriteDataToMasterZero)) <=
        std_logic_vector(FlattenMasterPortInterface(dNiFpgaMasterWriteDataToMasterArray(i)));

    dNiFpgaMasterWriteStatusToMasterArrayFlat(
      (i+1)*SizeOf(kNiFpgaMasterWriteStatusToMasterZero)-1 downto
      i*SizeOf(kNiFpgaMasterWriteStatusToMasterZero)) <=
        std_logic_vector(FlattenMasterPortInterface(dNiFpgaMasterWriteStatusToMasterArray(i)));

    dNiFpgaMasterReadRequestToMasterArrayFlat(
      (i+1)*SizeOf(kNiFpgaMasterReadRequestToMasterZero)-1 downto
      i*SizeOf(kNiFpgaMasterReadRequestToMasterZero)) <=
        std_logic_vector(FlattenMasterPortInterface(dNiFpgaMasterReadRequestToMasterArray(i)));

    dNiFpgaMasterReadDataToMasterArrayFlat(
      (i+1)*SizeOf(kNiFpgaMasterReadDataToMasterZero)-1 downto
      i*SizeOf(kNiFpgaMasterReadDataToMasterZero)) <=
        std_logic_vector(FlattenMasterPortInterface(dNiFpgaMasterReadDataToMasterArray(i)));
  end generate;

  -----------------------------------
  -- Convert flat outputs back to records
  -----------------------------------
  bLvWindowRegPortOut <= BuildRegPortOut(bRegPortOutFlat);

  dWinInputStreamInterfaceFromFifo <= UnflattenStreamInterface(dInputStreamInterfaceFromFifoFlat);
  dWinOutputStreamInterfaceFromFifo <= UnflattenStreamInterface(dOutputStreamInterfaceFromFifoFlat);

  bIrqToInterface <= BuildIrqToInterfaceArray(bIrqToInterfaceFlat);

  -- Convert flat Master Port outputs back to records
  gen_master_outputs_unflatten: for i in 0 to Larger(kNumberOfMasterPorts,1)-1 generate
    dNiFpgaMasterWriteRequestFromMasterArray(i) <=
      UnflattenMasterPortInterface(
        NiFpgaMasterWriteRequestFromMasterFlat_t(
          dNiFpgaMasterWriteRequestFromMasterArrayFlat(
            (i+1)*SizeOf(kNiFpgaMasterWriteRequestFromMasterZero)-1 downto
            i*SizeOf(kNiFpgaMasterWriteRequestFromMasterZero))));

    dNiFpgaMasterWriteDataFromMasterArray(i) <=
      UnflattenMasterPortInterface(
        NiFpgaMasterWriteDataFromMasterFlat_t(
          dNiFpgaMasterWriteDataFromMasterArrayFlat(
            (i+1)*SizeOf(kNiFpgaMasterWriteDataFromMasterZero)-1 downto
            i*SizeOf(kNiFpgaMasterWriteDataFromMasterZero))));

    dNiFpgaMasterReadRequestFromMasterArray(i) <=
      UnflattenMasterPortInterface(
        NiFpgaMasterReadRequestFromMasterFlat_t(
          dNiFpgaMasterReadRequestFromMasterArrayFlat(
            (i+1)*SizeOf(kNiFpgaMasterReadRequestFromMasterZero)-1 downto
            i*SizeOf(kNiFpgaMasterReadRequestFromMasterZero))));
  end generate;

  ---------------------------------------------------------------------------------------
  -- Unused or constant I/O
  ---------------------------------------------------------------------------------------

  -- Unused top-level signals
  --vhook_nowarn aPoscEn
  --vhook_nowarn aIoSmbAlert_n

  -- Reserved CLIP Signals
  --vhook_nowarn aReservedFromClip
  aReservedToClip(0)           <= bFamOutputEnable;
  aReservedToClip(1)           <= not aModulePresent_n;
  aReservedToClip(2)           <= aFamPowerGood;
  aReservedToClip(15 downto 3) <= (others => '0');

  -- Yet unused triggering and CLIP signals
  --vhook_nowarn xDiagramAxiStream*

  aExpansionGpio <= (others => '0');
  aExpansionMosi <= '0';
  aExpansionSck  <= '0';
  aExpansionCs_n <= '0';
  --vhook_nowarn aExpansion*

end architecture struct;
