------------------------------------------------------------------------------------------
--
-- File: BTracePlusTopTemplate.vhd
-- Author: National Instruments
-- Original Project: The Buffalo Trace Plus (based on Buffalo Trace / Macallan) FlexRIO Carrier
-- Date: 29 July 2020
--
------------------------------------------------------------------------------------------
-- (c) 2026 Copyright National Instruments Corporation
--
-- SPDX-License-Identifier: MIT
------------------------------------------------------------------------------------------
--
-- Purpose: This is the top level file for the 7994
------------------------------------------------------------------------------------------
--
-- githubvisible=true

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.PkgNiUtilities.all;
use work.PkgBuffaloTracePlus.all;
-- DMA engine Imports
use work.PkgBaRegPort.all;
use work.PkgCommunicationInterface.all;
use work.PkgDmaPortRecordFlattening.all;
use work.PkgDmaPortCommIfcArbiter.all;
use work.PkgNiDma.all;
use work.PkgNiDmaConfig.all;

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

-- HMB / Dram2DP
use work.PkgDram2DPConstants.all;

-----------------------------------------------------------------------------------------
-- Top-Level Clock/reset domain prefix guide.
-----------------------------------------------------------------------------------------

-- d      - DmaClk, coming from the DMA engine. Reset by a(d)BusReset for the most part.
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

entity BTracePlusTopTemplate is
  port (
    -------------------------------------------------------------------------------------
    -- Basics
    -------------------------------------------------------------------------------------
    -- Clock Inputs
    --Reliable Clk Input. Comes from an oscillator that is always on
    Osc100ClkIn               : in    std_logic;
    -------------------------------------------------------------------------------------
    -- Board Control
    -------------------------------------------------------------------------------------
    -- Monitoring SMBus
    bBaseSmbScl               : inout std_logic;
    bBaseSmbSda               : inout std_logic;
    -- Config I2C Bus
    bConfigI2cScl             : inout std_logic;
    bConfigI2cSda             : inout std_logic;
    -- Power supply PMBus
    bPwrSupplyPmbScl          : inout std_logic;
    bPwrSupplyPmbSda          : inout std_logic;
    aPwrSupplyPmbAlert_n      : in    std_logic; --vhook_nowarn aPwrSupplyPmbAlert_n
    -- Clock enables
    aIoRefClk100En            : out   std_logic;
    aIoRefClk10En             : out   std_logic;
    aIoRefSelClk100           : out   std_logic;
    -- Authentication
    aAuthSda                  : inout std_logic;
    -------------------------------------------------------------------------------------
    -- PXIe
    -------------------------------------------------------------------------------------
    -- PCIe
    aPcieRst_n                : in    std_logic;
    PcieRefClk_p              : in    std_logic;
    PcieRefClk_n              : in    std_logic;
    PcieRx_p                  : in    std_logic_vector (7 downto 0);
    PcieRx_n                  : in    std_logic_vector (7 downto 0);
    PcieTx_p                  : out   std_logic_vector (7 downto 0);
    PcieTx_n                  : out   std_logic_vector (7 downto 0);
    -- PXI trigger/control signals
    aPxiGa                    : in    std_logic_vector(4 downto 0);
    aPxiTrigData              : inout std_logic_vector(7 downto 0);
    aPxiStarData              : in    std_logic;
    -- BuffaloTracePlus does not output the aPxiTrigBufEn_n from FPGA. This signal
    -- is toggled using an IoExpander in the same way as Garrison.
    --aPxiTrigBufEn_n           : out   std_logic;
    aTrigPortExpReset_n       : out   std_logic;
    -- PXIe DStar
    aPxieDStarB_p             : in    std_logic;
    aPxieDStarB_n             : in    std_logic;
    aPxieDStarC_p             : out   std_logic;
    aPxieDStarC_n             : out   std_logic;
    -- PXIe Clk100 and Clk10
    PxieClk100_p              : in    std_logic;
    PxieClk100_n              : in    std_logic;
    pPxieSync100_p            : in    std_logic;
    pPxieSync100_n            : in    std_logic;
    pClk10GenD                : out   std_logic;
    -------------------------------------------------------------------------------------
    -- TDC
    -------------------------------------------------------------------------------------
    -- On Board TDC
    aTdcAllPeclEn             : out   std_logic;
    dvTdcAssertKu             : out   std_logic;
    -- BuffaloTracePlus does not prepare signal for dvTdcAssertKup
    --dvTdcAssertKup            : out   std_logic;
    sTdcDeassert              : out   std_logic;
    aTdcExpandedPulse_p       : in    std_logic;
    aTdcExpandedPulse_n       : in    std_logic;
    -------------------------------------------------------------------------------------
    -- FAM Configuration Plane
    -------------------------------------------------------------------------------------
    -- Single-Ended Config IO
    aSeGpio                   : inout std_logic_vector(29 downto 0);
    -- Module Detection
    aIoPresent_n              : in    std_logic;
    aIoReady                  : in    std_logic;
    -- ID
    aIoI2cScl                 : inout std_logic;
    aIoI2cSda                 : inout std_logic;
    -------------------------------------------------------------------------------------
    -- FAM Data Plane
    -------------------------------------------------------------------------------------
    -- Gpio
    aDiffGpio_p               : inout std_logic_vector(69 downto 0);
    aDiffGpio_n               : inout std_logic_vector(69 downto 0);
    -------------------------------------------------------------------------------------
    -- FAM Synchronization Plane
    -------------------------------------------------------------------------------------
    -- Main and Synchronization clocks
    SampleClk_p               : in    std_logic;
    SampleClk_n               : in    std_logic;
    DeviceClk_p               : in    std_logic;
    DeviceClk_n               : in    std_logic;
    -------------------------------------------------------------------------------------
    -- Reconfiguration CPLD
    -------------------------------------------------------------------------------------
    SidebandClk               : out   std_logic;
    sSidebandDataOut          : out   std_logic_vector(3 downto 0);
    aSidebandDataIn           : in    std_logic;
    aSidebandFifoFull         : in    std_logic;
    aFpgaStage2Done           : out   std_logic;
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
    aSysMonVtt0v6Sense_p      : in    std_logic;
    aSysMonVtt0v6Sense_n      : in    std_logic;
    aSysMon1v2MgtDivided_p    : in    std_logic;
    aSysMon1v2MgtDivided_n    : in    std_logic;
    aSysMonDdrVrefSense_p     : in    std_logic;
    aSysMonDdrVrefSense_n     : in    std_logic;
    aSysMon3v3ClkDivided_p    : in    std_logic;
    aSysMon3v3ClkDivided_n    : in    std_logic;
    aSysMonVppDivided_p       : in    std_logic;
    aSysMonVppDivided_n       : in    std_logic;
    aSysMon1v8MgtDivided_p    : in    std_logic;
    aSysMon1v8MgtDivided_n    : in    std_logic;
    aSysMon1v0MgtDivided_p    : in    std_logic;
    aSysMon1v0MgtDivided_n    : in    std_logic;
    aSysMon3v3CpldDivided_p   : in    std_logic;
    aSysMon3v3CpldDivided_n   : in    std_logic;
    aSysMon3v8IntDivided_p    : in    std_logic;
    aSysMon3v8IntDivided_n    : in    std_logic;

    -------------------------------------------------------------------------------------
    -- Base IO
    -------------------------------------------------------------------------------------

    -- Base board I2C bus
    aBaseI2cScl               : inout std_logic;
    aBaseI2cSda               : inout std_logic;
    -- Base board I2C reset
    aBaseConfigReset          : out   std_logic;

    -- Base board DIO
    aBaseDio                  : inout std_logic_vector(31 downto 0);
    aBaseExClk                : in    std_logic;

    -------------------------------------------------------------------------------------
    -- MGT Plane
    -------------------------------------------------------------------------------------
    -- RefClks
    MgtRefClk_p               : in    std_logic_vector(3 downto 0);
    MgtRefClk_n               : in    std_logic_vector(3 downto 0);

    -- MGTs for QSFP
    --@@BEGIN TOP_LEVEL_PORT
--
-- TheWindow.vhd is generated by LabVIEW FPGA.  We ship a stub to ensure that we can synthesize the design.  This
-- base design does not contain any MGT logic.  The MGT logic would be inside the CLIP in the LV Window for LV FPGA
-- generated designs.  For HDL customized FPGA targets, the MGT logic will be placed by the user in the top level entity.
-- Vivado will error when building a design that has MGT lines in the top level entity that are not connected
-- to anything.  So we comment out the MGT lines in the top level since this base design does not have any MGT logic.
--
-- If you are making a custom FPGA target, the MGT lines will be statically connected to your MGT logic.  If you are
-- using this FPGA target with a CLIP in LabVIEW FPGA, these MGT signals will be auto-generated by LV FPGA when it
-- processes the VHDL files.  The @ @ BEGIN / END around these signals is where LV FPGA generates the ports.
--
--    
--    MgtRxPortOneLane0_p       : in    std_logic;
--    MgtRxPortOneLane1_p       : in    std_logic;
--    MgtRxPortOneLane2_p       : in    std_logic;
--    MgtRxPortOneLane3_p       : in    std_logic;
--    MgtRxPortZeroLane0_p      : in    std_logic;
--    MgtRxPortZeroLane1_p      : in    std_logic;
--    MgtRxPortZeroLane2_p      : in    std_logic;
--    MgtRxPortZeroLane3_p      : in    std_logic;
--    MgtRxPortOneLane0_n       : in    std_logic;
--    MgtRxPortOneLane1_n       : in    std_logic;
--    MgtRxPortOneLane2_n       : in    std_logic;
--    MgtRxPortOneLane3_n       : in    std_logic;
--    MgtRxPortZeroLane0_n      : in    std_logic;
--    MgtRxPortZeroLane1_n      : in    std_logic;
--    MgtRxPortZeroLane2_n      : in    std_logic;
--    MgtRxPortZeroLane3_n      : in    std_logic;
--    MgtTxPortOneLane0_p       : out   std_logic;
--    MgtTxPortOneLane1_p       : out   std_logic;
--    MgtTxPortOneLane2_p       : out   std_logic;
--    MgtTxPortOneLane3_p       : out   std_logic;
--    MgtTxPortZeroLane0_p      : out   std_logic;
--    MgtTxPortZeroLane1_p      : out   std_logic;
--    MgtTxPortZeroLane2_p      : out   std_logic;
--    MgtTxPortZeroLane3_p      : out   std_logic;
--    MgtTxPortOneLane0_n       : out   std_logic;
--    MgtTxPortOneLane1_n       : out   std_logic;
--    MgtTxPortOneLane2_n       : out   std_logic;
--    MgtTxPortOneLane3_n       : out   std_logic;
--    MgtTxPortZeroLane0_n      : out   std_logic;
--    MgtTxPortZeroLane1_n      : out   std_logic;
--    MgtTxPortZeroLane2_n      : out   std_logic;
--    MgtTxPortZeroLane3_n      : out   std_logic;
    --@@END TOP_LEVEL_PORT
    --VSMake doesn't like prefix-less signals.
    --vhook_nodgv {.*Mgt(Port)?[TR]x_[pn]}

    -------------------------------------------------------------------------------------
    -- CPLD JTAG Field Update
    -------------------------------------------------------------------------------------
    aFldUpdJtagSel            : out   std_logic;
    bFldUpdJtagTck            : out   std_logic;
    bFldUpdJtagTdi            : out   std_logic;
    aFldUpdJtagTdo            : in    std_logic;
    bFldUpdJtagTms            : out   std_logic
    );

end entity BTracePlusTopTemplate;

architecture struct of BTracePlusTopTemplate is

  component PxieUsTimingEngine
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
      ReliableClk        : out std_logic;
      PxieClk100         : out std_logic;
      DlyRefClk          : out std_logic;
      PllClk40           : out std_logic;
      PllClk80           : out std_logic;
      MbClk              : out std_logic;
      aStage2Enabled     : in  boolean;
      pPxieSync100_p     : in  std_logic;
      pPxieSync100_n     : in  std_logic;
      pClk10GenD         : out std_logic;
      pIntSync100        : out std_logic;
      aIntClk10          : out std_logic;
      aEnableClk10       : in  boolean;
      aDramClocksValid   : in  boolean;
      aDramPllLocked     : in  boolean;
      aDramPonReset      : out boolean;
      aDramReady         : out std_logic;
      du0DramPhyInitDone : in  std_logic;
      du1DramPhyInitDone : in  std_logic;
      aPonReset          : out boolean;
      adlyReset          : out boolean);
  end component;

  --vhook_sigstart
  signal aAuthSdaIn: std_logic;
  signal aAuthSdaOut: std_logic;
  signal aBaseDioIn: std_logic_vector(kNumAuxIoData-1 downto 0);
  signal aBaseDioOut: std_logic_vector(kNumAuxIoData-1 downto 0);
  signal aBaseDioOutEn: std_logic_vector(kNumAuxIoData-1 downto 0);
  signal abBusReset: boolean;
  signal abDiagramReset: boolean;
  signal aDiagramReset: std_logic;
  signal aDramPonReset: boolean;
  signal aDramReady: std_logic;
  signal aEnableClk10: boolean;
  signal aGa: std_logic_vector(4 downto 0);
  signal aI2cSclIn: std_logic_vector(kNumI2cIfcs-1 downto 0);
  signal aI2cSclOut: std_logic_vector(kNumI2cIfcs-1 downto 0);
  signal aI2cSclTri: std_logic_vector(kNumI2cIfcs-1 downto 0);
  signal aI2cSdaIn: std_logic_vector(kNumI2cIfcs-1 downto 0);
  signal aI2cSdaOut: std_logic_vector(kNumI2cIfcs-1 downto 0);
  signal aI2cSdaTri: std_logic_vector(kNumI2cIfcs-1 downto 0);
  signal aIntClk10: std_logic;
  signal aPcieRst: std_logic;
  signal aPonReset: boolean;
  signal aPxieDStarB: std_logic;
  signal aPxieDStarC: std_logic;
  signal aPxiTrigDataIn: std_logic_vector(7 downto 0);
  signal aPxiTrigDataOut: std_logic_vector(7 downto 0);
  signal aPxiTrigDataTri: std_logic_vector(7 downto 0);
  signal aResetFromInchworm: boolean;
  signal aResetToInchworm_n: std_logic;
  signal aStage2Enabled: boolean;
  signal aSysMonVector_n: std_logic_vector(15 downto 0);
  signal aSysMonVector_p: std_logic_vector(15 downto 0);
  signal aTdcExpandedPulse: std_logic;
  signal bAxiStreamDataFromCtrl: AxiStreamData_t;
  signal bAxiStreamDataToCtrl: AxiStreamData_t;
  signal bAxiStreamReadyFromCtrl: boolean;
  signal bAxiStreamReadyToCtrl: boolean;
  signal bdClearIoRefClk100Enable: std_logic;
  signal bdClearIoRefClk10Enable: std_logic;
  signal bdClipAxi4LiteArAddr: std_logic_vector(31 downto 0);
  signal bdClipAxi4LiteArProt: std_logic_vector(2 downto 0);
  signal bdClipAxi4LiteArReady: std_logic;
  signal bdClipAxi4LiteArValid: std_logic;
  signal bdClipAxi4LiteAwAddr: std_logic_vector(31 downto 0);
  signal bdClipAxi4LiteAwProt: std_logic_vector(2 downto 0);
  signal bdClipAxi4LiteAwReady: std_logic;
  signal bdClipAxi4LiteAwValid: std_logic;
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
  signal bdIFifoRdData: IFifoReadData_t;
  signal bdIFifoRdDataValid: std_logic;
  signal bdIFifoRdIsError: std_logic;
  signal bdIFifoRdReadyForInput: std_logic;
  signal bdIFifoWrData: IFifoWriteData_t;
  signal bdIFifoWrDataValid: std_logic;
  signal bdIFifoWrReadyForOutput: std_logic;
  signal bdIoRefClk100Enabled: std_logic;
  signal bdIoRefClk10Enabled: std_logic;
  signal bdIoRefClkSwitch: std_logic;
  signal bDramClocksValid: std_logic;
  signal bdSelectIoRefClk10: std_logic;
  signal bdSelectIoRefClk100: std_logic;
  signal bdSetIoRefClk100Enable: std_logic;
  signal bdSetIoRefClk10Enable: std_logic;
  signal bFamOutputEnable: std_logic;
  signal bLvWindowRegPortTimeOut: boolean;
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
  signal dFlatHighSpeedSinkFromDma: FlatNiDmaHighSpeedSinkFromDma_t;
  signal dIrqFromFixedLogic: std_logic;
  signal DlyRefClk: std_logic;
  signal DmaClk: std_logic;
  signal Dram0ClkUser: std_logic;
  signal Dram1ClkUser: std_logic;
  signal DramClkLvFpga: std_logic;
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
  signal MbClk: std_logic;
  signal pIntSync100: std_logic;
  signal PxieClk100: std_logic;
  signal rBaseClksValid: std_logic;
  signal ReliableClk: std_logic;
  signal SampleClk: std_logic;
  signal stEnableIoRefClk10: std_logic;
  signal stEnableIoRefClk100: std_logic;
  signal stIoModuleSupportsFRAGLs: std_logic;
  signal xHostAxiStreamFromClipTData: AxiStreamTData_t;
  signal xHostAxiStreamFromClipTLast: std_logic;
  signal xHostAxiStreamFromClipTReady: std_logic;
  signal xHostAxiStreamFromClipTValid: std_logic;
  signal xHostAxiStreamToClipTData: AxiStreamTData_t;
  signal xHostAxiStreamToClipTLast: std_logic;
  signal xHostAxiStreamToClipTReady: std_logic;
  signal xHostAxiStreamToClipTValid: std_logic;
  --vhook_sigend
  -- Because we have the vhooks commented out on the window below, define this outside of vhook_sig*

  -- Inchworm Reset
  signal aBusReset : boolean := true;

  -- Signal not generated by vhook_sig due to commenting out vhook TheWindow. This will
  -- make sure that these signals will not vhook away when running make pxie-7994.
  signal aReservedFromClip: std_logic_vector(15 downto 0);
  signal aReservedToClip: std_logic_vector(15 downto 0);
  signal dtDevClkEn: std_logic;
  signal dtTdcAssert: std_logic;
  signal dvTdcAssert: std_logic;
  signal xDiagramAxiStreamFromClipTData: std_logic_vector(31 downto 0);
  signal xDiagramAxiStreamFromClipTLast: std_logic;
  signal xDiagramAxiStreamFromClipTReady: std_logic;
  signal xDiagramAxiStreamFromClipTValid: std_logic;
  signal xDiagramAxiStreamToClipTData: std_logic_vector(31 downto 0);
  signal xDiagramAxiStreamToClipTLast: std_logic;
  signal xDiagramAxiStreamToClipTReady: std_logic;
  signal xDiagramAxiStreamToClipTValid: std_logic;
  signal xIoOutputEnable: std_logic;
  signal xIoPresent: std_logic;
  signal xIoReady: std_logic;

  signal bAddressesDram2DP : boolean;
  signal bRegPortOutUserHdl: RegPortOut_t;

  -- Window-side stream interface signals (for UserHdl FIFO interception)
  signal dWinInputStreamInterfaceToFifo   : InputStreamInterfaceToFifoArray_t(Larger(kNumberOfDmaChannels,1)-1 downto 0);
  signal dWinInputStreamInterfaceFromFifo : InputStreamInterfaceFromFifoArray_t(Larger(kNumberOfDmaChannels,1)-1 downto 0);
  signal dWinOutputStreamInterfaceToFifo  : OutputStreamInterfaceToFifoArray_t(Larger(kNumberOfDmaChannels,1)-1 downto 0);
  signal dWinOutputStreamInterfaceFromFifo: OutputStreamInterfaceFromFifoArray_t(Larger(kNumberOfDmaChannels,1)-1 downto 0);

  signal bRegPortOutDram2DP : RegPortOut_t;
  signal bRegPortInDram2DP : RegPortIn_t;
  signal bRegPortShiftAddress : unsigned(kAlignedAddressWidth - 1 downto 0);
  -- Interface signals between Dram2DP and DMAPort
  signal dNiHmbInputArbGrant: NiDmaArbGrant_t;
  signal dNiHmbInputArbReq: NiDmaArbReq_t;
  signal dNiHmbInputDataFromDma: NiDmaInputDataFromDma_t;
  signal dNiHmbInputDataToDma: NiDmaInputDataToDma_t;
  signal dNiHmbInputRequestFromDma: NiDmaInputRequestFromDma_t;
  signal dNiHmbInputRequestToDma: NiDmaInputRequestToDma_t;
  signal dNiHmbInputStatusFromDma: NiDmaInputStatusFromDma_t;
  signal dNiHmbOutputArbGrant: NiDmaArbGrant_t;
  signal dNiHmbOutputArbReq: NiDmaArbReq_t;
  signal dNiHmbOutputDataFromDma: NiDmaOutputDataFromDma_t;
  signal dNiHmbOutputRequestFromDma: NiDmaOutputRequestFromDma_t;
  signal dNiHmbOutputRequestToDma: NiDmaOutputRequestToDma_t;

  signal dFixedLogicDmaIrq : IrqStatusArray_t(0 downto 0) := (others => kIrqStatusToInterfaceZero);

  -- Interface signals between Dram2DP and DRAM Interface in the Window
  signal dHmbDramAddrFifoAddr: std_logic_vector(31 downto 0);
  signal dHmbDramAddrFifoCmd: std_logic_vector(2 downto 0);
  signal dHmbDramAddrFifoFull: std_logic;
  signal dHmbDramAddrFifoWrEn: std_logic;
  signal dHmbDramRdDataValid: std_logic;
  signal dHmbDramRdFifoDataOut: std_logic_vector(1023 downto 0);
  signal dHmbDramWrFifoDataIn: std_logic_vector(1023 downto 0);
  signal dHmbDramWrFifoFull: std_logic;
  signal dHmbDramWrFifoMaskData: std_logic_vector(127 downto 0);
  signal dHmbDramWrFifoWrEn: std_logic;
  signal dHmbPhyInitDoneForLvfpga: std_logic;
  signal dLlbDramAddrFifoAddr: std_logic_vector(31 downto 0);
  signal dLlbDramAddrFifoCmd: std_logic_vector(2 downto 0);
  signal dLlbDramAddrFifoFull: std_logic;
  signal dLlbDramAddrFifoWrEn: std_logic;
  signal dLlbDramRdDataValid: std_logic;
  signal dLlbDramRdFifoDataOut: std_logic_vector(1023 downto 0);
  signal dLlbDramWrFifoDataIn: std_logic_vector(1023 downto 0);
  signal dLlbDramWrFifoFull: std_logic;
  signal dLlbDramWrFifoMaskData: std_logic_vector(127 downto 0);
  signal dLlbDramWrFifoWrEn: std_logic;
  signal dLlbPhyInitDoneForLvfpga: std_logic;

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

  -- This constant specifies the size of each memory buffer which (2^kSizeOfMemBuffers)
  -- In this case, it is 2^22= 4MB
  constant kSizeOfMemBuffers : integer := 22;
  -- This constant specifies the maximum number of memory buffers allowed to be used
  -- which (2^kMaxNumOfMemBuffers). In this case, 2^2 = 4 memory buffers.
  constant kMaxNumOfMemBuffers : integer := 2;

  -- Dram2DP Registers are all between 0x60000 and 0x60040 - LV Window shifts by 0x40000
  constant kDram2DPBaseAddress  : unsigned(kAlignedAddressWidth - 1 downto 0) := to_unsigned(work.PkgLvFpgaConst.kDram2DPBaseAddress / 4, kAlignedAddressWidth);
  constant kDram2DPAddressMask  : unsigned(kAlignedAddressWidth - 1 downto 0) := to_unsigned(16#1FC# / 4, kAlignedAddressWidth);

  -- ******************************************************************************************************************
  -- ********************** MODIFY THESE CONSTANTS IF NOT USING THE CLIP SOCKET INTERFACE  ****************************
  -- ******************************************************************************************************************
  --
  -- If you are using the CLIP socket interface, you should use the following constant for kExpectedTbIdConst
  -- because LabVIEW FPGA will generate the PkgLvFpgaConst.vhd that contains kExpectedTbId based on what CLIP
  -- is used in the LabVIEW FPGA project.  When the FPGA bitfile runs, it compares kExpectedTbIdConst to a
  -- value read from the EEPROM on the board to make sure that the CLIP used in LabVIEW FPGA is compatible with
  -- this board.  If the TbId does not match, the clocks to the board IO will not be enabled.
  --
  -- When using a CLIP node in LabVIEW FPGA, the user can configure which clock is enabled to the board IO logic.
  -- This becomes kEnableFamClockSync and kFamClockSrcSel which are also defined in PkgLvFpgaConst.vhd.
  --
  -- kFamClockSrcSel selects between the 10 MHz and 100 MHz clocks (0 = 10 Mhz, 1 = 100 MHz) and kEnableFamClockSync
  -- enables the clock to the board IO logic.
  --
  -- ***** COMMENT OUT THE FOLLOWING CONSTANTS AND SET YOUR OWN VALUES IF NOT USING THE CLIP SOCKET INTERFACE *****
  -- constant kExpectedTbIdConst : std_logic_vector(31 downto 0) := kExpectedTbId;
  -- constant kEnableFamClockSyncConst : std_logic := kEnableFamClockSync;
  -- constant kFamClockSrcSelConst : std_logic := kFamClockSrcSel;
  --
  -- If you are not using the CLIP socket interface because you are interfacing with the board IO directly from
  -- this HDL file, you must set kExpectedTbIdConst to match which IO frontend your module is using so that the
  -- TbId check matches.  
  -- 
  -- View the README for a table of IO Modules and their corresponding TbIds (IO Module ID):  
  --    https://github.com/ni/flexrio-custom/blob/main/README.md
  --  
  -- We set the clocking constants to enable the 100 MHz clock.
  --
  constant kExpectedTbIdConst : std_logic_vector(31 downto 0) := X"10937AA7";  -- Set this to match your IO frontend
  constant kEnableFamClockSyncConst : std_logic := '1';
  constant kFamClockSrcSelConst : std_logic := '1';

  -- Disable automatic io_buffer creation for FAM MGTs and signals that will instantiate
  -- their own.
  attribute io_buffer_type : string;
  attribute dont_touch     : boolean;

  -- BuffaloTracePlus have for MgtRefClk for 2 QSFP ports
  -- MgtRefClk[3:2] are connected to QSFP port 0
  -- MgtRefClk[1:0] are connected to QSFP port 1
  -- MGT RefClks
  attribute io_buffer_type of MgtRefClk_p     : signal is "none";
  attribute io_buffer_type of MgtRefClk_n     : signal is "none";
  -- MGTs
  --attribute io_buffer_type of MgtPortRx_p     : signal is "none";
  --attribute io_buffer_type of MgtPortRx_n     : signal is "none";
  --attribute io_buffer_type of MgtPortTx_p     : signal is "none";
  --attribute io_buffer_type of MgtPortTx_n     : signal is "none";

  --System Monitor
  attribute io_buffer_type of aSysMon1v8MgtDivided_p, aSysMon1v8MgtDivided_n   : signal is "none";
  attribute io_buffer_type of aSysMon3v3CpldDivided_p, aSysMon3v3CpldDivided_n : signal is "none";
  attribute io_buffer_type of aSysMonVppDivided_p, aSysMonVppDivided_n         : signal is "none";
  attribute io_buffer_type of aSysMon1v2MgtDivided_p, aSysMon1v2MgtDivided_n   : signal is "none";
  attribute io_buffer_type of aSysMon1v0MgtDivided_p, aSysMon1v0MgtDivided_n   : signal is "none";
  attribute io_buffer_type of aSysMon3v8IntDivided_p, aSysMon3v8IntDivided_n   : signal is "none";
  attribute io_buffer_type of aSysMon3v3ClkDivided_p, aSysMon3v3ClkDivided_n   : signal is "none";
  attribute io_buffer_type of aSysMonVtt0v6Sense_p, aSysMonVtt0v6Sense_n       : signal is "none";
  attribute io_buffer_type of aSysMonDdrVrefSense_p, aSysMonDdrVrefSense_n     : signal is "none";

  -- Tandem signals with explicit IOBUF instantiations
  -- This prevents inserting additional buffers which can mess up the stage 1 constraints.
  attribute io_buffer_type of aPcieRst_n     : signal is "none";
  attribute io_buffer_type of PxieClk100_p   : signal is "none";
  attribute io_buffer_type of PxieClk100_n   : signal is "none";
  attribute io_buffer_type of pPxieSync100_p : signal is "none";
  attribute io_buffer_type of pPxieSync100_n : signal is "none";
  attribute io_buffer_type of aPxiGa         : signal is "none";
  attribute io_buffer_type of Osc100ClkIn    : signal is "none";
  attribute io_buffer_type of aAuthSda       : signal is "none";

  -- Tandem IO Buffer block
  attribute dont_touch of MacallanIoBuffersStage1x : label is true;

begin  -- architecture struct

  -- Tags for software's autogeneration
  -- These are not used directly for BTracePlusTopTemplate, but it makes
  -- software's life easier
  --@@BEGIN LOCAL_SIGNAL_ASSIGNMENT
  --@@END LOCAL_SIGNAL_ASSIGNMENT

  ---------------------------------------------------------------------------------------
  -- Clock Generation and Resets
  ---------------------------------------------------------------------------------------

  --vhook   PxieUsTimingEngine TimingEnginex
  --vhook_a PllClk80            BusClk
  --vhook_a PllClk40            Clk40Mhz
  --vhook_# DRAM
  --vhook_a aDramClocksValid    to_Boolean(bDramClocksValid)
  --vhook_a aDramPllLocked      true
  --vhook_# Unused
  --vhook_h adlyReset           open
  --vhook_h bTePllLocked        open
  TimingEnginex: PxieUsTimingEngine
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
      ReliableClk        => ReliableClk,                   --out std_logic
      PxieClk100         => PxieClk100,                    --out std_logic
      DlyRefClk          => DlyRefClk,                     --out std_logic
      PllClk40           => Clk40Mhz,                      --out std_logic
      PllClk80           => BusClk,                        --out std_logic
      MbClk              => MbClk,                         --out std_logic
      aStage2Enabled     => aStage2Enabled,                --in  boolean
      pPxieSync100_p     => pPxieSync100_p,                --in  std_logic
      pPxieSync100_n     => pPxieSync100_n,                --in  std_logic
      pClk10GenD         => pClk10GenD,                    --out std_logic
      pIntSync100        => pIntSync100,                   --out std_logic
      aIntClk10          => aIntClk10,                     --out std_logic
      aEnableClk10       => aEnableClk10,                  --in  boolean
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

  --vhook_e G3UsHostInterface   HostInterfacex
  --vhook_# Use BusClk for AxiClk and ViClk
  --vhook_a AxiClk              BusClk
  --vhook_a {x(AxiStream.+)}    xHost$1
  --vhook_a ViClk               BusClk
  --vhook_a {v(IFifo.+)}        bd$1
  --vhook_# DmaClk wrap-back
  --vhook_a DmaClockSource      DmaClk
  --vhook_a bLvWindowRegPortIn  bRegPortIn
  --vhook_a bLvWindowRegPortOut bRegPortOut
  --vhook_g kHmbInUse true
  --vhook_g kDmaFifoConfArrayGeneric MergeDmaFifoConf(kDmaFifoConfArray, kUserHdlDmaFifoConf, kUserHdlDmaStartIndex)
  --vhook_g kForceChannelEnable GetForceChannelEnable(kUserHdlDmaFifoConf, kUserHdlDmaStartIndex)
  HostInterfacex: entity work.G3UsHostInterface (struct)
    generic map (
      kHmbInUse                => true,               --boolean:=false
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
      aGa                                      => aGa,                                       --in  std_logic_vector(4:0)
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
      dNiHmbInputRequestToDma                  => dNiHmbInputRequestToDma,                   --in  NiDmaInputRequestToDma_t:=kNiDmaInputRequestToDmaZero
      dNiHmbInputRequestFromDma                => dNiHmbInputRequestFromDma,                 --out NiDmaInputRequestFromDma_t
      dNiHmbInputDataToDma                     => dNiHmbInputDataToDma,                      --in  NiDmaInputDataToDma_t:=kNiDmaInputDataToDmaZero
      dNiHmbInputDataFromDma                   => dNiHmbInputDataFromDma,                    --out NiDmaInputDataFromDma_t
      dNiHmbInputStatusFromDma                 => dNiHmbInputStatusFromDma,                  --out NiDmaInputStatusFromDma_t
      dNiHmbOutputRequestToDma                 => dNiHmbOutputRequestToDma,                  --in  NiDmaOutputRequestToDma_t:=kNiDmaOutputRequestToDmaZero
      dNiHmbOutputRequestFromDma               => dNiHmbOutputRequestFromDma,                --out NiDmaOutputRequestFromDma_t
      dNiHmbOutputDataFromDma                  => dNiHmbOutputDataFromDma,                   --out NiDmaOutputDataFromDma_t
      dNiHmbInputArbReq                        => dNiHmbInputArbReq,                         --in  NiDmaArbReq_t:=kNiDmaArbReqZero
      dNiHmbInputArbGrant                      => dNiHmbInputArbGrant,                       --out NiDmaArbGrant_t
      dNiHmbOutputArbReq                       => dNiHmbOutputArbReq,                        --in  NiDmaArbReq_t:=kNiDmaArbReqZero
      dNiHmbOutputArbGrant                     => dNiHmbOutputArbGrant,                      --out NiDmaArbGrant_t
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
      dFlatHighSpeedSinkFromDma                => dFlatHighSpeedSinkFromDma,                 --out FlatNiDmaHighSpeedSinkFromDma_t
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
  --vhook_# I2c
  --vhook_a {^b(.*?)(Scl|Sda)(In|Out|Tri)}      aI2c$2$3(k$1Index)
  --vhook_# Unused Aux
  --vhook_h aAux*                               open            mode=out
  --vhook_a aAux3v3Fault_n                      '1'
  --vhook_a b*LvAuxDio                          (others => '0') mode=in
  --vhook_h b*LvAuxDio                          open            mode=out
  --vhook_# BTrace-specific naming
  --vhook_a aFamPowerGood                       aIoReady
  --vhook_a aModulePresent_n                    aIoPresent_n
  --vhook_# BTrace-specific unconnected
  --vhook_h bDigiPot*                           open             mode=out
  --vhook_a bDigiPotMiso                        '0'
  --vhook_g kExpectedTbIdGeneric kExpectedTbIdConst
  --vhook_g kAuxDioDefaultVoltageGeneric kAuxDioDefaultVoltage
  FixedLogicWrapperx: entity work.FixedLogicWrapper (struct)
    generic map (
      kExpectedTbIdGeneric         => kExpectedTbIdConst,     --std_logic_vector(31:0)
      kAuxDioDefaultVoltageGeneric => kAuxDioDefaultVoltage)  --natural
    port map (
      aPonReset                          => aPonReset,                           --in  boolean
      aBusReset                          => aBusReset,                           --in  boolean
      aDiagramReset                      => aDiagramReset,                       --in  std_logic
      DmaClk                             => DmaClk,                              --in  std_logic
      BusClk                             => BusClk,                              --in  std_logic
      MbClk                              => MbClk,                               --in  std_logic
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
      stEnableIoRefClk10                 => stEnableIoRefClk10,                  --in  std_logic
      stEnableIoRefClk100                => stEnableIoRefClk100,                 --in  std_logic
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
      bDigiPotMiso                       => '0',                                 --in  std_logic
      aTdcAllPeclEn                      => aTdcAllPeclEn,                       --out std_logic
      aTdcExpandedPulse                  => aTdcExpandedPulse,                   --in  std_logic
      bDramClocksValid                   => bDramClocksValid,                    --out std_logic
      aTrigPortExpReset_n                => aTrigPortExpReset_n,                 --out std_logic
      bdSetIoRefClk100Enable             => bdSetIoRefClk100Enable,              --out std_logic
      bdClearIoRefClk100Enable           => bdClearIoRefClk100Enable,            --out std_logic
      bdSetIoRefClk10Enable              => bdSetIoRefClk10Enable,               --out std_logic
      bdClearIoRefClk10Enable            => bdClearIoRefClk10Enable,             --out std_logic
      bdSelectIoRefClk100                => bdSelectIoRefClk100,                 --out std_logic
      bdSelectIoRefClk10                 => bdSelectIoRefClk10,                  --out std_logic
      bdIoRefClk100Enabled               => bdIoRefClk100Enabled,                --in  std_logic
      bdIoRefClk10Enabled                => bdIoRefClk10Enabled,                 --in  std_logic
      bdIoRefClkSwitch                   => bdIoRefClkSwitch,                    --in  std_logic
      aModulePresent_n                   => aIoPresent_n,                        --in  std_logic
      aFamPowerGood                      => aIoReady,                            --in  std_logic
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
      aAux3v3Fault_n                     => '1',                                 --in  std_logic
      abDiagramReset                     => abDiagramReset,                      --out boolean
      bdRequestaLvAuxDio                 => (others => '0'),                     --in  std_logic_vector(7:0)
      bdDirectionaLvAuxDio               => (others => '0'),                     --in  std_logic_vector(7:0)
      aSysMonVector_p                    => aSysMonVector_p,                     --in  std_logic_vector(15:0)
      aSysMonVector_n                    => aSysMonVector_n,                     --in  std_logic_vector(15:0)
      aFldUpdJtagSel                     => aFldUpdJtagSel,                      --out std_logic
      bFldUpdJtagTck                     => bFldUpdJtagTck,                      --out std_logic
      bFldUpdJtagTdi                     => bFldUpdJtagTdi,                      --out std_logic
      aFldUpdJtagTdo                     => aFldUpdJtagTdo,                      --in  std_logic
      bFldUpdJtagTms                     => bFldUpdJtagTms,                      --out std_logic
      dIrqFromFixedLogic                 => dIrqFromFixedLogic);                 --out std_logic

  aSysMonVector_p <= (kSysMon1v8MgtDivided  => aSysMon1v8MgtDivided_p,
                      kSysMon3v3CpldDivided => aSysMon3v3CpldDivided_p,
                      kSysMonVppDivided     => aSysMonVppDivided_p,
                      kSysMon1v2MgtDivided  => aSysMon1v2MgtDivided_p,
                      kSysMon1v0MgtDivided  => aSysMon1v0MgtDivided_p,
                      kSysMon3v8IntDivided  => aSysMon3v8IntDivided_p,
                      kSysMon3v3ClkDivided  => aSysMon3v3ClkDivided_p,
                      kSysMonVtt0v6Sense    => aSysMonVtt0v6Sense_p,
                      kSysMonDdrVrefSense   => aSysMonDdrVrefSense_p,
                      others                => '0');

  aSysMonVector_n <= (kSysMon1v8MgtDivided  => aSysMon1v8MgtDivided_n,
                      kSysMon3v3CpldDivided => aSysMon3v3CpldDivided_n,
                      kSysMonVppDivided     => aSysMonVppDivided_n,
                      kSysMon1v2MgtDivided  => aSysMon1v2MgtDivided_n,
                      kSysMon1v0MgtDivided  => aSysMon1v0MgtDivided_n,
                      kSysMon3v8IntDivided  => aSysMon3v8IntDivided_n,
                      kSysMon3v3ClkDivided  => aSysMon3v3ClkDivided_n,
                      kSysMonVtt0v6Sense    => aSysMonVtt0v6Sense_n,
                      kSysMonDdrVrefSense   => aSysMonDdrVrefSense_n,
                      others                => '0');

   --vhook_e IoRefClkSelect
   IoRefClkSelectx: entity work.IoRefClkSelect (rtl)
     generic map (
       kEnableFamClockSync => kEnableFamClockSyncConst,  --std_logic
       kFamClockSrcSel     => kFamClockSrcSelConst)      --std_logic
     port map (
       BusClk                   => BusClk,                    --in  std_logic
       abDiagramReset           => abDiagramReset,            --in  boolean
       bdSetIoRefClk100Enable   => bdSetIoRefClk100Enable,    --in  std_logic
       bdClearIoRefClk100Enable => bdClearIoRefClk100Enable,  --in  std_logic
       bdSetIoRefClk10Enable    => bdSetIoRefClk10Enable,     --in  std_logic
       bdClearIoRefClk10Enable  => bdClearIoRefClk10Enable,   --in  std_logic
       bdSelectIoRefClk100      => bdSelectIoRefClk100,       --in  std_logic
       bdSelectIoRefClk10       => bdSelectIoRefClk10,        --in  std_logic
       bdIoRefClk100Enabled     => bdIoRefClk100Enabled,      --out std_logic
       bdIoRefClk10Enabled      => bdIoRefClk10Enabled,       --out std_logic
       bdIoRefClkSwitch         => bdIoRefClkSwitch,          --out std_logic
       stEnableIoRefClk10       => stEnableIoRefClk10,        --out std_logic
       stEnableIoRefClk100      => stEnableIoRefClk100);      --out std_logic

  -- Outputs
  aIoRefClk100En  <= bdIoRefClk100Enabled;
  aIoRefClk10En   <= bdIoRefClk10Enabled;
  aIoRefSelClk100 <= bdIoRefClkSwitch;
  -- To TimingEngine
  aEnableClk10    <= to_Boolean(bdIoRefClk10Enabled);

  ---------------------------------------------------------------------------------------
  -- IO BUFFERs
  ---------------------------------------------------------------------------------------

  --vhook_e  MacallanIoBuffers
  --vhook_#  I2C Outputs
  --vhook_af {aI2c(Scl|Sda)$}(kIoSmbIndex)              {aIoI2c$1}            continue=true
  --vhook_af {aI2c(Scl|Sda)$}(kBaseSmbIndex)            {bBaseSmb$1}          continue=true
  --vhook_af {aI2c(Scl|Sda)$}(kConfigI2cIndex)          {bConfigI2c$1}        continue=true
  --vhook_af {aI2c(Scl|Sda)$}(kPwrSupplyPmbIndex)       {bPwrSupplyPmb$1}	    continue=true
  --vhook_af {aI2c(Scl|Sda)$}(kBaseBoardI2cIndex)       {aBaseI2c$1}
  --vhook_#  Loopback (unused)
  --vhook_a  aFpgaLoopback*                             '0'                   mode=in
  --vhook_h  aFpgaLoopback*                             open                  mode=out
  --vhook_#  Out Enables that are currently unused
  --vhook_a  aPxieDStarCEn_n                            '0'
  --vhook_#  AuxIo (used for DIO)
  --vhook_a  aAuxIoData                                 aBaseDio
  --vhook_a  aLvAuxDioInputData                         aBaseDioIn
  --vhook_a  aLvAuxDioOutputData                        aBaseDioOut
  --vhook_a  aLvAuxDioOutputEnable                      aBaseDioOutEn
  MacallanIoBuffersx: entity work.MacallanIoBuffers (struct)
    generic map (
      kNumI2cIfcs   => kNumI2cIfcs,    --natural:=5
      kNumAuxIoData => kNumAuxIoData)  --natural:=8
    port map (
      aI2cSclIn                   => aI2cSclIn,         --out std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSclOut                  => aI2cSclOut,        --in  std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSclTri                  => aI2cSclTri,        --in  std_logic_vector(kNumI2cIfcs-1:0)
      aI2cScl(kIoSmbIndex)        => aIoI2cScl,         --inout std_logic_vector(kNumI2cIfcs-1:0)
      aI2cScl(kBaseSmbIndex)      => bBaseSmbScl,       --inout std_logic_vector(kNumI2cIfcs-1:0)
      aI2cScl(kConfigI2cIndex)    => bConfigI2cScl,     --inout std_logic_vector(kNumI2cIfcs-1:0)
      aI2cScl(kPwrSupplyPmbIndex) => bPwrSupplyPmbScl,  --inout std_logic_vector(kNumI2cIfcs-1:0)
      aI2cScl(kBaseBoardI2cIndex) => aBaseI2cScl,       --inout std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSdaIn                   => aI2cSdaIn,         --out std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSdaOut                  => aI2cSdaOut,        --in  std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSdaTri                  => aI2cSdaTri,        --in  std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSda(kIoSmbIndex)        => aIoI2cSda,         --inout std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSda(kBaseSmbIndex)      => bBaseSmbSda,       --inout std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSda(kConfigI2cIndex)    => bConfigI2cSda,     --inout std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSda(kPwrSupplyPmbIndex) => bPwrSupplyPmbSda,  --inout std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSda(kBaseBoardI2cIndex) => aBaseI2cSda,       --inout std_logic_vector(kNumI2cIfcs-1:0)
      aPxiTrigDataIn              => aPxiTrigDataIn,    --out std_logic_vector(7:0)
      aPxiTrigDataOut             => aPxiTrigDataOut,   --in  std_logic_vector(7:0)
      aPxiTrigDataTri             => aPxiTrigDataTri,   --in  std_logic_vector(7:0)
      aPxiTrigData                => aPxiTrigData,      --inout std_logic_vector(7:0)
      aPxieDStarB                 => aPxieDStarB,       --out std_logic
      aPxieDStarB_p               => aPxieDStarB_p,     --in  std_logic
      aPxieDStarB_n               => aPxieDStarB_n,     --in  std_logic
      aPxieDStarC                 => aPxieDStarC,       --in  std_logic
      aPxieDStarCEn_n             => '0',               --in  std_logic
      aPxieDStarC_p               => aPxieDStarC_p,     --out std_logic
      aPxieDStarC_n               => aPxieDStarC_n,     --out std_logic
      aFpgaLoopbackOut            => '0',               --in  std_logic
      aFpgaLoopbackIn_p           => '0',               --in  std_logic
      aFpgaLoopbackIn_n           => '0',               --in  std_logic
      aAuxIoData                  => aBaseDio,          --inout std_logic_vector(kNumAuxIoData-1:0)
      aLvAuxDioOutputData         => aBaseDioOut,       --in  std_logic_vector(kNumAuxIoData-1:0)
      aLvAuxDioInputData          => aBaseDioIn,        --out std_logic_vector(kNumAuxIoData-1:0)
      aLvAuxDioOutputEnable       => aBaseDioOutEn);    --in  std_logic_vector(kNumAuxIoData-1:0)

  --vhook_e BTraceIoBuffersFam
  BTraceIoBuffersFamx: entity work.BTraceIoBuffersFam (struct)
    port map (
      aTdcExpandedPulse_p => aTdcExpandedPulse_p,  --in  std_logic
      aTdcExpandedPulse_n => aTdcExpandedPulse_n,  --in  std_logic
      aTdcExpandedPulse   => aTdcExpandedPulse,    --out std_logic
      DeviceClk           => DeviceClk,            --out std_logic
      DeviceClk_p         => DeviceClk_p,          --in  std_logic
      DeviceClk_n         => DeviceClk_n,          --in  std_logic
      SampleClk           => SampleClk,            --out std_logic
      SampleClk_p         => SampleClk_p,          --in  std_logic
      SampleClk_n         => SampleClk_n);         --in  std_logic

  --vhook_e MacallanIoBuffersStage1 hidegeneric=true
  MacallanIoBuffersStage1x: entity work.MacallanIoBuffersStage1 (struct)
    port map (
      aStage2Enabled  => aStage2Enabled,   --in  boolean
      aAuthSdaIn      => aAuthSdaIn,       --out std_logic
      aAuthSdaOut     => aAuthSdaOut,      --in  std_logic
      aAuthSda        => aAuthSda,         --inout std_logic
      aPxiGa          => aPxiGa,           --in  std_logic_vector(4:0)
      aGa             => aGa,              --out std_logic_vector(4:0)
      aPcieRst_n      => aPcieRst_n,       --in  std_logic
      aPcieRst        => aPcieRst,         --out std_logic
      aFpgaStage2Done => aFpgaStage2Done); --out std_logic

  ---------------------------------------------------------------------------------------
  -- DRAM Instantiation
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

  bRegPortOut.Data <= bLvWindowRegPortOut.Data or
                      bRegPortOutDram2DP.Data or
                      bRegPortOutUserHdl.Data;

  bRegPortOut.DataValid <= bLvWindowRegPortOut.DataValid or
                           bRegPortOutDram2DP.DataValid or
                           bRegPortOutUserHdl.DataValid;

  bRegPortOut.Ready <= bLvWindowRegPortOut.Ready and
                       bRegPortOutDram2DP.Ready and
                       bRegPortOutUserHdl.Ready;

  bAddressesDram2DP  <= (bRegportIn.Address >= kDram2DPBaseAddress) and
                        (bRegportIn.Address <= (kDram2DPBaseAddress + kDram2DPAddressMask));

  ---------------------------------------------------------------------------
  -- User HDL block (registers + FIFOs)
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
      aReservedToClip                 => aReservedToClip,
      aReservedFromClip               => aReservedFromClip,
      stIoModuleSupportsFRAGLs        => stIoModuleSupportsFRAGLs,
      xIoPresent                      => xIoPresent,
      xIoReady                        => xIoReady,
      xIoOutputEnable                 => xIoOutputEnable,
      dvTdcAssert                     => dvTdcAssert,
      dtTdcAssert                     => dtTdcAssert,
      dtDevClkEn                      => dtDevClkEn,
      -- Base IO
      aBaseI2cSclIn                   => aI2cSclIn(kBaseBoardI2cIndex),
      aBaseI2cSclOut                  => aI2cSclOut(kBaseBoardI2cIndex),
      aBaseI2cSclTri                  => aI2cSclTri(kBaseBoardI2cIndex),
      aBaseI2cSdaIn                   => aI2cSdaIn(kBaseBoardI2cIndex),
      aBaseI2cSdaOut                  => aI2cSdaOut(kBaseBoardI2cIndex),
      aBaseI2cSdaTri                  => aI2cSdaTri(kBaseBoardI2cIndex),
      aBaseConfigReset                => aBaseConfigReset,
      aBaseDioIn                      => aBaseDioIn,
      aBaseDioOut                     => aBaseDioOut,
      aBaseDioOutEn                   => aBaseDioOutEn,
      aBaseExClk                      => aBaseExClk,
      -- MGTs for QSFP ports (top-level MGT lanes are commented out on this
      -- base design; stub the data lanes and connect only the ref clocks).
      Qsfp0MgtRx_p                    => (others => '0'),
      Qsfp0MgtRx_n                    => (others => '0'),
      Qsfp0MgtTx_p                    => open,
      Qsfp0MgtTx_n                    => open,
      Qsfp0MgtRefClk_p                => MgtRefClk_p(3 downto 2),
      Qsfp0MgtRefClk_n                => MgtRefClk_n(3 downto 2),
      Qsfp1MgtRx_p                    => (others => '0'),
      Qsfp1MgtRx_n                    => (others => '0'),
      Qsfp1MgtTx_p                    => open,
      Qsfp1MgtTx_n                    => open,
      Qsfp1MgtRefClk_p                => MgtRefClk_p(1 downto 0),
      Qsfp1MgtRefClk_n                => MgtRefClk_n(1 downto 0),
      Qsfp0SocketClk80                => BusClk,
      Qsfp1SocketClk80                => BusClk,
      -- IoModule Socketed CLIP physical interface
      aSeGpio                         => aSeGpio,
      aDiffGpio_p                     => aDiffGpio_p,
      aDiffGpio_n                     => aDiffGpio_n,
      -- Clocking
      SampleClk                       => SampleClk,
      DeviceClk                       => DeviceClk
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

  MergeRegPortInDram2DP: process(bRegportIn, bAddressesDram2DP)
  begin
    bRegPortInDram2DP <= bRegportIn;
    bRegPortInDram2DP.Rd <= bAddressesDram2DP and bRegportIn.Rd;
    bRegPortInDram2DP.Wt <= bAddressesDram2DP and bRegportIn.Wt;
    bRegPortInDram2DP.Address <= bRegportIn.Address and kDram2DPAddressMask;
  end process;


  -- Dram2DP is used to translate write and read requests from DRAM Interface in the Window
  -- to DMAPort requests in the fixed logic DMAPort
  -- Use DMAPort channel 0x3B, the 5th reserved channel
  Dram2DPx: entity work.Dram2DP (rtl)
    generic map (
      kSizeOfMemBuffers   => kSizeOfMemBuffers,
      kMaxNumOfMemBuffers => kMaxNumOfMemBuffers,
      kDmaChannelNum      => "0111011",
      kHmbInUse           => work.PkgLvFpgaConst.kInsertHostMemoryBufferMig,  -- in  boolean := true
      kLlbInUse           => work.PkgLvFpgaConst.kInsertLowLatencyBufferMig,  -- in  boolean := true
      kDefaultBaggage     => SetField(0, 16#00#, kNiDmaBaggageWidth),
      kDramInterfaceDataWidth => 1024)
    port map (
      aBusReset                   => to_stdlogic(aBusReset),
      BusClk                      => BusClk,
      bRegPortIn                  => bRegPortInDram2DP,
      bRegPortOut                 => bRegPortOutDram2DP,
      dHighSpeedSinkFromDma       => UnFlatten(dFlatHighSpeedSinkFromDma),
      dDramAddrFifoAddr           => dHmbDramAddrFifoAddr,
      dDramAddrFifoCmd            => dHmbDramAddrFifoCmd,
      dDramAddrFifoFull           => dHmbDramAddrFifoFull,
      dDramAddrFifoWrEn           => dHmbDramAddrFifoWrEn,
      dDramRdDataValid            => dHmbDramRdDataValid,
      dDramRdFifoDataOut          => dHmbDramRdFifoDataOut,
      dDramWrFifoDataIn           => dHmbDramWrFifoDataIn,
      dDramWrFifoFull             => dHmbDramWrFifoFull,
      dDramWrFifoMaskData         => dHmbDramWrFifoMaskData,
      dDramWrFifoWrEn             => dHmbDramWrFifoWrEn,
      dPhyInitDoneForLvfpga       => dHmbPhyInitDoneForLvfpga,
      dLlbDramAddrFifoAddr        => dLlbDramAddrFifoAddr,
      dLlbDramAddrFifoCmd         => dLlbDramAddrFifoCmd,
      dLlbDramAddrFifoFull        => dLlbDramAddrFifoFull,
      dLlbDramAddrFifoWrEn        => dLlbDramAddrFifoWrEn,
      dLlbDramRdDataValid         => dLlbDramRdDataValid,
      dLlbDramRdFifoDataOut       => dLlbDramRdFifoDataOut,
      dLlbDramWrFifoDataIn        => dLlbDramWrFifoDataIn,
      dLlbDramWrFifoFull          => dLlbDramWrFifoFull,
      dLlbDramWrFifoMaskData      => dLlbDramWrFifoMaskData,
      dLlbDramWrFifoWrEn          => dLlbDramWrFifoWrEn,
      dLlbPhyInitDoneForLvfpga    => dLlbPhyInitDoneForLvfpga,
      DMAClk                      => DmaClk,
      dNiFpgaInputRequestToDma    => dNiHmbInputRequestToDma,
      dNiFpgaInputRequestFromDma  => dNiHmbInputRequestFromDma,
      dNiFpgaInputDataToDma       => dNiHmbInputDataToDma,
      dNiFpgaInputDataFromDma     => dNiHmbInputDataFromDma,
      dNiFpgaInputStatusFromDma   => dNiHmbInputStatusFromDma,
      dNiFpgaOutputRequestToDma   => dNiHmbOutputRequestToDma,
      dNiFpgaOutputRequestFromDma => dNiHmbOutputRequestFromDma,
      dNiFpgaOutputDataFromDma    => dNiHmbOutputDataFromDma,
      dNiFpgaInputArbReq          => dNiHmbInputArbReq,
      dNiFpgaInputArbGrant        => dNiHmbInputArbGrant,
      dNiFpgaOutputArbReq         => dNiHmbOutputArbReq,
      dNiFpgaOutputArbGrant       => dNiHmbOutputArbGrant);

  ---------------------------------------------------------------------------------------
  -- The Window (aka LVFPGA world)
  ---------------------------------------------------------------------------------------
  -- The BEGIN COMPONENT_SIGNAL_ASSIGNMENT and END COMPONENT_SIGNAL_ASSIGNMENT tags are
  -- around the MGT IO becaue TheWindow that's generated from LV FPGA will put the needed
  -- MGT IO in its port.  This file is called SasquatchTopTemplate because it is processed
  -- by LV FPGA to add the MGT signals.  This base file uses a stub TheWindow component
  -- that does not have MGT signals in its port.  Vivado needs MGT ports in the top-level
  -- entity to be connected to MGTs so that it can synthesize.  Since we have no MGTs in this
  -- base design, the MGT signals in the top-level entity are commented out.
  --
  -- If you are customizing this HDL file directly, then you will add whatever MGT signal ports
  -- you are using to the top-level entity and connect them to this TheWindow wrapper instance.
  --
  TheLvWindowWrapper: TheLvWindowFlatWrapper
    port map (
      -----------------------------------
      -- CUSTOM BOARD IO
      -----------------------------------

      -----------------------------------
      -- Communication interface ports
      -----------------------------------
      -- Reset ports
      aBusReset                           => to_stdlogic(aBusReset),                    --in std_logic

      -- Register Access/ PIO Ports
      bRegPortIn                          => bRegPortInFlat,                            --in std_logic_vector(kRegPortInSize-1 downto 0)
      bRegPortOut                         => bRegPortOutFlat,                           --out std_logic_vector(kRegPortOutSize-1 downto 0)
      bRegPortTimeout                     => to_stdlogic(bLvWindowRegPortTimeOut),      --in std_logic

      -- DMA Stream Ports
      dInputStreamInterfaceToFifo         => dInputStreamInterfaceToFifoFlat,           --in std_logic_vector( Larger(kNumberOfDmaChannels,1)*SizeOf(kInputStreamInterfaceToFifoZero)-1 downto 0)
      dInputStreamInterfaceFromFifo       => dInputStreamInterfaceFromFifoFlat,         --out std_logic_vector( Larger(kNumberOfDmaChannels,1)*SizeOf(kInputStreamInterfaceFromFifoZero)-1 downto 0)
      dOutputStreamInterfaceToFifo        => dOutputStreamInterfaceToFifoFlat,          --in std_logic_vector( Larger(kNumberOfDmaChannels,1)*SizeOf(kOutputStreamInterfaceToFifoZero)-1 downto 0)
      dOutputStreamInterfaceFromFifo      => dOutputStreamInterfaceFromFifoFlat,        --out std_logic_vector( Larger(kNumberOfDmaChannels,1)*SizeOf(kOutputStreamInterfaceFromFifoZero)-1 downto 0)

      -- IRQ Ports
      bIrqToInterface                     => bIrqToInterfaceFlat,                        --out std_logic_vector( Larger(kNumberOfIrqs,1)*kIrqToInterfaceSize*kIrqStatusToInterfaceSize-1 downto 0)

      -- MasterPort Ports
      dNiFpgaMasterWriteRequestFromMaster => dNiFpgaMasterWriteRequestFromMasterArrayFlat,  --out std_logic_vector( Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterWriteRequestFromMasterZero)-1 downto 0)
      dNiFpgaMasterWriteRequestToMaster   => dNiFpgaMasterWriteRequestToMasterArrayFlat,  --in std_logic_vector( Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterWriteRequestToMasterZero)-1 downto 0)
      dNiFpgaMasterWriteDataFromMaster    => dNiFpgaMasterWriteDataFromMasterArrayFlat,  --out std_logic_vector( Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterWriteDataFromMasterZero)-1 downto 0)
      dNiFpgaMasterWriteDataToMaster      => dNiFpgaMasterWriteDataToMasterArrayFlat,  --in std_logic_vector( Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterWriteDataToMasterZero)-1 downto 0)
      dNiFpgaMasterWriteStatusToMaster    => dNiFpgaMasterWriteStatusToMasterArrayFlat,  --in std_logic_vector( Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterWriteStatusToMasterZero)-1 downto 0)

      dNiFpgaMasterReadRequestFromMaster  => dNiFpgaMasterReadRequestFromMasterArrayFlat,  --out std_logic_vector( Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterReadRequestFromMasterZero)-1 downto 0)
      dNiFpgaMasterReadRequestToMaster    => dNiFpgaMasterReadRequestToMasterArrayFlat,  --in std_logic_vector( Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterReadRequestToMasterZero)-1 downto 0)
      dNiFpgaMasterReadDataToMaster       => dNiFpgaMasterReadDataToMasterArrayFlat,  --in std_logic_vector( Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterReadDataToMasterZero)-1 downto 0)

      -----------------------------------
      -- Clocks from TopLevel
      -----------------------------------
      DmaClk                              => DmaClk,                                    --in std_logic
      BusClk                              => BusClk,                                    --in std_logic
      ReliableClkIn                       => ReliableClk,                               --in std_logic
      PllClk80                            => BusClk,                                    --in std_logic
      DlyRefClk                           => DlyRefClk,                                 --in std_logic
      PxieClk100                          => PxieClk100,                                --in std_logic
      DramClkLvFpga                       => DramClkLvFpga,                             --in std_logic
      Dram0ClkSocket                      => Dram0ClkUser,                              --in std_logic
      Dram1ClkSocket                      => Dram1ClkUser,                              --in std_logic
      Dram0ClkUser                        => Dram0ClkUser,                              --in std_logic
      Dram1ClkUser                        => Dram1ClkUser,                              --in std_logic
      dHmbDmaClkSocket                    => DmaClk,                                    --in std_logic
      dLlbDmaClkSocket                    => DmaClk,                                    --in std_logic


      -----------------------------------
      -- Handshaking signals for derived
      -- clocks on external clocks
      -----------------------------------


      -----------------------------------
      -- Clock/Sync IO Node ports
      -----------------------------------
      pIntSync100                         => pIntSync100,                               --in std_logic
      aIntClk10                           => aIntClk10,                                 --in std_logic

      -----------------------------------
      -- Target Method and Properties ports
      -----------------------------------
      bdIFifoRdData                       => bdIFifoRdData,                             --out std_logic_vector(63 downto 0)
      bdIFifoRdDataValid                  => bdIFifoRdDataValid,                        --out std_logic
      bdIFifoRdReadyForInput              => bdIFifoRdReadyForInput,                    --in std_logic
      bdIFifoRdIsError                    => bdIFifoRdIsError,                          --out std_logic
      bdIFifoWrData                       => bdIFifoWrData,                             --in std_logic_vector(63 downto 0)
      bdIFifoWrDataValid                  => bdIFifoWrDataValid,                        --in std_logic
      bdIFifoWrReadyForOutput             => bdIFifoWrReadyForOutput,                   --out std_logic
      bdAxiStreamRdFromClipTData          => xDiagramAxiStreamFromClipTData,            --in std_logic_vector(31 downto 0)
      bdAxiStreamRdFromClipTLast          => xDiagramAxiStreamFromClipTLast,            --in std_logic
      bdAxiStreamRdFromClipTValid         => xDiagramAxiStreamFromClipTValid,           --in std_logic
      bdAxiStreamRdToClipTReady           => xDiagramAxiStreamToClipTReady,             --out std_logic
      bdAxiStreamWrToClipTData            => xDiagramAxiStreamToClipTData,              --out std_logic_vector(31 downto 0)
      bdAxiStreamWrToClipTLast            => xDiagramAxiStreamToClipTLast,              --out std_logic
      bdAxiStreamWrToClipTValid           => xDiagramAxiStreamToClipTValid,             --out std_logic
      bdAxiStreamWrFromClipTReady         => xDiagramAxiStreamFromClipTReady,           --in std_logic

      -----------------------------------
      -- Pass through LabVIEW FPGA ports
      -----------------------------------

      ----------------------------------------
      -- Trigger Routing Socketed CLIP
      ----------------------------------------
      PxieClk100Trigger                   => PxieClk100,                                --in std_logic
      pIntSync100Trigger                  => pIntSync100,                               --in std_logic
      dTdcAssert                          => dtTdcAssert,                               --out std_logic
      dDevClkEn                           => dtDevClkEn,                                --in std_logic
      sTdcDeassert                        => sTdcDeassert,                              --out std_logic
      aIntClk10Trigger                    => aIntClk10,                                 --in std_logic
      --ID Signals from Routing CLIP
      bRoutingClipPresent                 => bRoutingClipPresent,                       --out std_logic
      bRoutingClipNiCompatible            => bRoutingClipNiCompatible,                  --out std_logic

      BusClkTrigger                       => BusClk,                                    --in std_logic
      abBusResetTrigger                   => to_StdLogic(abBusReset),                   --in std_logic

      -- From PkgBaRegPort
      -- RegPortIn_t Size = Address 28 Data 64 WrStrobes 8 RdStrobes 8 = 108
      -- RegPortOut_t Size = Data 64 + Ack 1 = 65
      bTriggerRoutingBaRegPortInAddress   => bTriggerRoutingBaRegPortInAddress,         --in std_logic_vector(27 downto 0)
      bTriggerRoutingBaRegPortInData      => bTriggerRoutingBaRegPortInData,            --in std_logic_vector(63 downto 0)
      bTriggerRoutingBaRegPortInWtStrobe  => bTriggerRoutingBaRegPortInWtStrobe,        --in std_logic_vector(7 downto 0)
      bTriggerRoutingBaRegPortInRdStrobe  => bTriggerRoutingBaRegPortInRdStrobe,        --in std_logic_vector(7 downto 0)

      bTriggerRoutingBaRegPortOutData     => bTriggerRoutingBaRegPortOutData,           --out std_logic_vector(63 downto 0)
      bTriggerRoutingBaRegPortOutAck      => bTriggerRoutingBaRegPortOutAck,            --out std_logic

      aPxiTrigDataIn                      => aPxiTrigDataIn,                            --in std_logic_vector(7 downto 0)
      aPxiTrigDataOut                     => aPxiTrigDataOut,                           --out std_logic_vector(7 downto 0)
      aPxiTrigDataTri                     => aPxiTrigDataTri,                           --out std_logic_vector(7 downto 0)
      aPxiStarData                        => aPxiStarData,                              --in std_logic
      aPxieDstarB                         => aPxieDstarB,                               --in std_logic
      aPxieDstarC                         => aPxieDstarC,                               --out std_logic

      -----------------------------------
      -- TARGET IO AND CLIP PORTS NOT USED
      -----------------------------------

      -----------------------------------------------------------------------------
      --Dram Interface
      -----------------------------------------------------------------------------
      aDramReady                          => aDramReady,                                --in std_logic
      du0DramAddrFifoAddr                 => du0DramAddrFifoAddr,                       --out std_logic_vector(28 downto 0)
      du0DramAddrFifoCmd                  => du0DramAddrFifoCmd,                        --out std_logic_vector(2 downto 0)
      du0DramAddrFifoFull                 => du0DramAddrFifoFull,                       --in std_logic
      du0DramAddrFifoWrEn                 => du0DramAddrFifoWrEn,                       --out std_logic
      du0DramPhyInitDone                  => du0DramPhyInitDone,                        --in std_logic
      du0DramRdDataValid                  => du0DramRdDataValid,                        --in std_logic
      du0DramRdFifoDataOut                => du0DramRdFifoDataOut,                      --in std_logic_vector(255 downto 0)
      du0DramWrFifoDataIn                 => du0DramWrFifoDataIn,                       --out std_logic_vector(255 downto 0)
      du0DramWrFifoFull                   => du0DramWrFifoFull,                         --in std_logic
      du0DramWrFifoMaskData               => du0DramWrFifoMaskData,                     --out std_logic_vector(31 downto 0)
      du0DramWrFifoWrEn                   => du0DramWrFifoWrEn,                         --out std_logic
      du1DramAddrFifoAddr                 => du1DramAddrFifoAddr,                       --out std_logic_vector(28 downto 0)
      du1DramAddrFifoCmd                  => du1DramAddrFifoCmd,                        --out std_logic_vector(2 downto 0)
      du1DramAddrFifoFull                 => du1DramAddrFifoFull,                       --in std_logic
      du1DramAddrFifoWrEn                 => du1DramAddrFifoWrEn,                       --out std_logic
      du1DramPhyInitDone                  => du1DramPhyInitDone,                        --in std_logic
      du1DramRdDataValid                  => du1DramRdDataValid,                        --in std_logic
      du1DramRdFifoDataOut                => du1DramRdFifoDataOut,                      --in std_logic_vector(255 downto 0)
      du1DramWrFifoDataIn                 => du1DramWrFifoDataIn,                       --out std_logic_vector(255 downto 0)
      du1DramWrFifoFull                   => du1DramWrFifoFull,                         --in std_logic
      du1DramWrFifoMaskData               => du1DramWrFifoMaskData,                     --out std_logic_vector(31 downto 0)
      du1DramWrFifoWrEn                   => du1DramWrFifoWrEn,                         --out std_logic

      -----------------------------------------------------------------------------
      --HMB Interface
      -----------------------------------------------------------------------------
      dHmbDramAddrFifoAddr                => dHmbDramAddrFifoAddr,                      --out std_logic_vector(31 downto 0)
      dHmbDramAddrFifoCmd                 => dHmbDramAddrFifoCmd,                       --out std_logic_vector(2 downto 0)
      dHmbDramAddrFifoFull                => dHmbDramAddrFifoFull,                      --in std_logic
      dHmbDramAddrFifoWrEn                => dHmbDramAddrFifoWrEn,                      --out std_logic
      dHmbDramRdDataValid                 => dHmbDramRdDataValid,                       --in std_logic
      dHmbDramRdFifoDataOut               => dHmbDramRdFifoDataOut,                     --in std_logic_vector(1023 downto 0)
      dHmbDramWrFifoDataIn                => dHmbDramWrFifoDataIn,                      --out std_logic_vector(1023 downto 0)
      dHmbDramWrFifoFull                  => dHmbDramWrFifoFull,                        --in std_logic
      dHmbDramWrFifoMaskData              => dHmbDramWrFifoMaskData,                    --out std_logic_vector(127 downto 0)
      dHmbDramWrFifoWrEn                  => dHmbDramWrFifoWrEn,                        --out std_logic
      dHmbPhyInitDoneForLvfpga            => dHmbPhyInitDoneForLvfpga,                  --in std_logic
      dLlbDramAddrFifoAddr                => dLlbDramAddrFifoAddr,                      --out std_logic_vector(31 downto 0)
      dLlbDramAddrFifoCmd                 => dLlbDramAddrFifoCmd,                       --out std_logic_vector(2 downto 0)
      dLlbDramAddrFifoFull                => dLlbDramAddrFifoFull,                      --in std_logic
      dLlbDramAddrFifoWrEn                => dLlbDramAddrFifoWrEn,                      --out std_logic
      dLlbDramRdDataValid                 => dLlbDramRdDataValid,                       --in std_logic
      dLlbDramRdFifoDataOut               => dLlbDramRdFifoDataOut,                     --in std_logic_vector(1023 downto 0)
      dLlbDramWrFifoDataIn                => dLlbDramWrFifoDataIn,                      --out std_logic_vector(1023 downto 0)
      dLlbDramWrFifoFull                  => dLlbDramWrFifoFull,                        --in std_logic
      dLlbDramWrFifoMaskData              => dLlbDramWrFifoMaskData,                    --out std_logic_vector(127 downto 0)
      dLlbDramWrFifoWrEn                  => dLlbDramWrFifoWrEn,                        --out std_logic
      dLlbPhyInitDoneForLvfpga            => dLlbPhyInitDoneForLvfpga,                  --in std_logic

      -----------------------------------
      -- Clocks from TheWindow
      -----------------------------------
      TopLevelClkOut                      => open,  --out std_logic
      ReliableClkOut                      => open,  --out std_logic

      -----------------------------------
      -- Diagram/Reset/Clock status
      -----------------------------------
      rBaseClksValid                      => rBaseClksValid,                            --in std_logic := '1'
      tDiagramActive                      => open,  --out std_logic
      rDiagramReset                       => open,  --out std_logic
      aDiagramReset                       => aDiagramReset,                             --out std_logic
      rDerivedClockLostLockError          => open,  --out std_logic
      rGatedBaseClksValid                 => '1',                                      --in std_logic := '1'
      aSafeToEnableGatedClks              => open  --out std_logic
    );

  -----------------------------------
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

  xIoPresent <= not aIoPresent_n;
  xIoReady <= aIoReady;
  xIoOutputEnable <= bFamOutputEnable;

  ---------------------------------------------------------------------------------------
  -- Selecting between KU and KUP
  ---------------------------------------------------------------------------------------
  dvTdcAssertKu  <= dvTdcAssert;
  -- BuffaloTracePlus does not prepare signal for dvTdcAssertKup
  --dvTdcAssertKup <= 'Z';

  ---------------------------------------------------------------------------------------
  -- Unused or constant I/O
  ---------------------------------------------------------------------------------------
  -- This signal exists only to ensure that the triggers don't misbehave during FPGA
  -- reconfiguration. The reset has a pull-down, so it'll be asserted during FPGA
  -- configuration. After that, we'll tie it high (deasserted).

  -- This is now handled with a register write in fixed logic (same as Garrison)
  --aTrigPortExpReset_n <= '1';

  -- Unused top-level signals
  --vhook_nowarn aPoscEn
  --vhook_nowarn aIoSmbAlert_n

  -- Reserved CLIP Signals
  --vhook_nowarn aReservedFromClip
  aReservedToClip <= (others => '0');

end architecture struct;
