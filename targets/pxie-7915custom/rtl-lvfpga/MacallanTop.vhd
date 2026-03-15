------------------------------------------------------------------------------------------
--
-- File: MacallanTop.vhd
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
-- Purpose: This is the top level file for the 7915
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
use work.PkgCoprocessor.all;
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
use work.PkgDmaPortDmaFifosFlatTypes.all;
use work.PkgDmaPortCommIfcMasterPort.all;
use work.PkgDmaPortCommIfcMasterPortFlatTypes.all;
-- LvFpga printed by SW
use work.PkgLvFpgaConst.all;

-- The Window Component Instantiation
use work.PkgTheLvWindowFlatWrapper.all;

-- Instruction Fifo
use work.PkgInstructionFifo.all;

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

entity MacallanTop is
  port (
    -------------------------------------------------------------------------------------
    -- Basics
    -------------------------------------------------------------------------------------
    -- Clock Inputs
    --Reliable Clk Input. Comes from an oscillator that is always on
    Osc100ClkIn               : in    std_logic;
    -- POSC Enable
    aPoscEn                   : in    std_logic;
    -------------------------------------------------------------------------------------
    -- Board Control
    -------------------------------------------------------------------------------------
    -- Monitoring SMBus
    bBaseSmbScl               : inout std_logic;
    bBaseSmbSda               : inout std_logic;
    aBaseSmbAlert_n           : in    std_logic; --vhook_nowarn aBaseSmbAlert_n
    -- Control I2C Bus
    bConfigI2cScl             : inout std_logic;
    bConfigI2cSda             : inout std_logic;
    -- Power supply PMBus
    bPwrSupplyPmbScl          : inout std_logic;
    bPwrSupplyPmbSda          : inout std_logic;
    aPwrSupplyPmbAlert_n      : in    std_logic; --vhook_nowarn aPwrSupplyPmbAlert_n
    -- AuxIO Vcc Potentiometer SPI
    bDigiPotSclk              : out   std_logic;
    bDigiPotMosi              : out   std_logic;
    bDigiPotMiso              : in    std_logic;
    bDigiPotSync_n            : out   std_logic;
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
    dvTdcAssert               : out   std_logic;
    sTdcDeassert              : out   std_logic;
    --vhook_nowarn aTdcExpandedPulse*
    aTdcExpandedPulse_p       : in    std_logic;
    aTdcExpandedPulse_n       : in    std_logic;
    -- Loopback for FPGA TDC
    aFpgaLoopbackOut_p        : out   std_logic;
    aFpgaLoopbackOut_n        : out   std_logic;
    aFpgaLoopbackIn_p         : in    std_logic;
    aFpgaLoopbackIn_n         : in    std_logic;
    -------------------------------------------------------------------------------------
    -- Board Configuration
    -------------------------------------------------------------------------------------
    -- Cicada
    -- Buffer enables
    aCicada3v3BufEn_n         : out   std_logic;
    -- Reset
    aCicadaReset_n            : out   std_logic;
    -- JTAG
    aCicadaJtagReset_n        : out   std_logic;
    aCicadaBoundScanEn        : out   std_logic;
    -- Cicada Interface
    IsoPortTxClk              : out   std_logic;
    itIsoPortTxData           : out   std_logic_vector(3 downto 0);
    IsoPortRxClk              : in    std_logic;
    irIsoPortRxData           : in    std_logic_vector(3 downto 0);
    -- Reserved IO
    aFpgaToCicadaRsvd         : out   std_logic_vector(1 downto 0);
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
    --vhook_nodgv {.*Mgt(Port)?[TR]x_[pn]}
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
    -- I2C
    aSysMonI2cScl             : inout std_logic;
    aSysMonI2cSda             : inout std_logic;
    --vhook_nowarn aSysMonI2cS*
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
    bFldUpdJtagTms            : out   std_logic
    );

end entity MacallanTop;

architecture struct of MacallanTop is

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
  signal aDiagramReset: std_logic;
  signal aDramPonReset: boolean;
  signal aDramReady: std_logic;
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
  signal aPxieDstarB: std_logic;
  signal aPxieDstarC: std_logic;
  signal aPxiTrigDataIn: std_logic_vector(7 downto 0);
  signal aPxiTrigDataOut: std_logic_vector(7 downto 0);
  signal aPxiTrigDataTri: std_logic_vector(7 downto 0);
  signal aResetFromInchworm: boolean;
  signal aResetToInchworm_n: std_logic;
  signal aStage2Enabled: boolean;
  signal aSysMonVector_n: std_logic_vector(15 downto 0);
  signal aSysMonVector_p: std_logic_vector(15 downto 0);
  signal aTdcExpandedPulse: std_ulogic;
  signal bAxiStreamDataFromCtrl: AxiStreamData_t;
  signal bAxiStreamDataToCtrl: AxiStreamData_t;
  signal bAxiStreamReadyFromCtrl: boolean;
  signal bAxiStreamReadyToCtrl: boolean;
  signal bdIFifoRdData: std_logic_vector(63 downto 0);
  signal bdIFifoRdDataValid: std_logic;
  signal bdIFifoRdIsError: std_logic;
  signal bdIFifoRdReadyForInput: std_logic;
  signal bdIFifoWrData: std_logic_vector(63 downto 0);
  signal bdIFifoWrDataValid: std_logic;
  signal bdIFifoWrReadyForOutput: std_logic;
  signal bDramClocksValid: std_logic;
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
  signal dFixedLogicBaRegPortIn: BaRegPortIn_t;
  signal dFixedLogicBaRegPortOut: BaRegPortOut_t;
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
  --vhook_sigend

  -- Inchworm Reset
  signal aBusReset : boolean := true;

  signal dFlatHighSpeedSinkFromDma : FlatNiDmaHighSpeedSinkFromDma_t;

  -- Aux IO
  signal aLvAuxDioOutputData   : std_logic_vector(kNumAuxIoData-1 downto 0);
  signal aLvAuxDioInputData    : std_logic_vector(kNumAuxIoData-1 downto 0);
  signal aLvAuxDioOutputEnable : std_logic_vector(kNumAuxIoData-1 downto 0);
  signal bdRequestaLvAuxDio    : std_logic_vector(kNumAuxIoData-1 downto 0);
  signal bdDirectionaLvAuxDio  : std_logic_vector(kNumAuxIoData-1 downto 0);
  signal bdDoneaLvAuxDio       : std_logic_vector(kNumAuxIoData-1 downto 0);

  signal bAddressesDram2DP : boolean;
  signal bRegPortOutCommonRegs: RegPortOut_t;
  signal bRegPortOutSharedRegs: RegPortOut_t;

  signal bSharedHostRegFpgaHostWrite : BooleanVector(0 to 3);
  signal bSharedHostRegFpgaAck : BooleanVector(0 to 3) := (others => false);
  signal bSharedHostRegFpgaWrite : BooleanVector(0 to 3) := (others => false);
  signal bSharedHostRegFpgaDataIn : Slv32Ary_t(0 to 3) := (others => (others => '0'));
  signal bSharedHostRegFpgaDataOut : Slv32Ary_t(0 to 3);

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
  -- ********************** MODIFY THESE CONSTANTS IF NOT USING THE DIO FROM LV PROJECT *******************************
  -- ******************************************************************************************************************
  --
  -- The default voltage level for the AUX DIO lines is set in the LabVIEW FPGA project and gets generated into
  -- kAuxDioDefaultVoltage in PkgLvFpgaConst.vhd.  If you are controlling the AUX DIO from this HDL file instead of
  -- the LV project node, you can set kAuxDioDefaultVoltageConst to what you need.  This constant is the voltage level
  -- in milivolts.  The ONLY valid values are:
  --                          3300 (for 3.3V), 2500 (for 2.5v), 1800 (for 1.8V), and 1100 (for 1.1V).
  --
  -- By default, this template is set up to use the CLIP socket interface, so these constants get set to the values
  -- defined in PkgLvFpgaConst.vhd.
  constant kAuxDioDefaultVoltageConst : natural := kAuxDioDefaultVoltage;
  --
  -- If you are not using the DIO from the LabVIEW project because you are interfacing with the board IO directly from this
  -- HDL file, then you can comment out the line above and uncomment the line below and set the constant to the voltage
  -- level you need for the AUX DIO lines.
  -- constant kAuxDioDefaultVoltageConst : natural := 3300;

  -- Disable automatic io_buffer creation for FAM MGTs and signals that will instantiate
  -- their own.
  attribute io_buffer_type : string;
  attribute dont_touch     : boolean;

  -- MGT RefClks
  attribute io_buffer_type of AuxIoMgtRefClk_p : signal is "none";
  attribute io_buffer_type of AuxIoMgtRefClk_n : signal is "none";
  -- MGTs
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
  attribute io_buffer_type of pPxieSync100_p : signal is "none";
  attribute io_buffer_type of pPxieSync100_n : signal is "none";
  attribute io_buffer_type of aPxiGa         : signal is "none";
  attribute io_buffer_type of Osc100ClkIn    : signal is "none";
  attribute io_buffer_type of aAuthSda       : signal is "none";

  -- Tandem IO Buffer block
  attribute dont_touch of MacallanIoBuffersStage1x : label is true;

begin  -- architecture struct

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
  --vhook_a adlyReset           open
  --vhook_a bTePllLocked        open
  --vhook_a aEnableClk10        false
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
      bTePllLocked       => open,                          --out std_logic
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
      aEnableClk10       => false,                         --in  boolean
      aDramClocksValid   => to_Boolean(bDramClocksValid),  --in  boolean
      aDramPllLocked     => true,                          --in  boolean
      aDramPonReset      => aDramPonReset,                 --out boolean
      aDramReady         => aDramReady,                    --out std_logic
      du0DramPhyInitDone => du0DramPhyInitDone,            --in  std_logic
      du1DramPhyInitDone => du1DramPhyInitDone,            --in  std_logic
      aPonReset          => aPonReset,                     --out boolean
      adlyReset          => open);                         --out boolean

  ---------------------------------------------------------------------------------------
  -- Host Interface
  ---------------------------------------------------------------------------------------

  --VSMake doesn't like prefix-less signals.
  --vhook_nodgv {^Pcie[RT]x_[pn]}

  --vhook_e G3UsHostInterfaceIsoPort HostInterfacex
  --vhook_# Use BusClk for AxiClk and ViClk, even if some of the Axi Stream interfaces are not
  --vhook_# being used.
  --vhook_a AxiClk                      BusClk
  --vhook_a x*AxiStreamFromClipTData    (others => '0')
  --vhook_a x*AxiStreamFromClip*        '0'
  --vhook_a x*AxiStreamToClip*          open
  --vhook_a ViClk                       BusClk
  --vhook_a {v(IFifo.+)}                bd$1
  --vhook_# DmaClk wrap-back
  --vhook_a DmaClockSource              DmaClk
  --vhook_a bLvWindowRegPortIn  bRegPortIn
  --vhook_a bLvWindowRegPortOut bRegPortOut
  --vhook_g kHmbInUse true
  HostInterfacex: entity work.G3UsHostInterfaceIsoPort (struct)
    generic map (kHmbInUse => true)  --boolean:=false
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
      IsoPortTxClk                             => IsoPortTxClk,                              --out std_logic
      itIsoPortTxData                          => itIsoPortTxData,                           --out std_logic_vector(3:0)
      IsoPortRxClk                             => IsoPortRxClk,                              --in  std_logic
      irIsoPortRxData                          => irIsoPortRxData,                           --in  std_logic_vector(3:0)
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
      xAxiStreamFromClipTData                  => (others => '0'),                           --in  AxiStreamTData_t
      xAxiStreamFromClipTLast                  => '0',                                       --in  std_logic
      xAxiStreamToClipTReady                   => open,                                      --out std_logic
      xAxiStreamFromClipTValid                 => '0',                                       --in  std_logic
      xAxiStreamToClipTData                    => open,                                      --out AxiStreamTData_t
      xAxiStreamToClipTLast                    => open,                                      --out std_logic
      xAxiStreamToClipTValid                   => open,                                      --out std_logic
      xAxiStreamFromClipTReady                 => '0',                                       --in  std_logic
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

  -- These two signals should maintain static values at all times except for boundary-scan
  -- testing. Because Boundary-scan testing is only done without a bitfile loaded, for the
  -- purposes of this target they are static.
  aCicadaJtagReset_n <= '1';
  aCicadaBoundScanEn <= '0';

  --vhook_e FixedLogicWrapper
  --vhook_a FastTdcClk                          DlyRefClk
  --vhook_# I2c - Unused
  --vhook_a bIoSmb*                             open            mode=out
  --vhook_a bIoSmb*                             '0'             mode=in
  --vhook_# I2c - Used
  --vhook_a {^b(.*?)(Scl|Sda)(In|Out|Tri)}      aI2c$2$3(k$1Index)
  --vhook_# Unused AXI to Clip
  --vhook_a {bdClipAxi4.*}                      open            mode=out
  --vhook_a {bdClipAxi4.*(Ready|Valid)}         '0'             mode=in
  --vhook_a {bdClipAxi4.*}                      (others => '0') mode=in
  --vhook_# Unused FAM
  --vhook_a aFamPowerGood                       '0'
  --vhook_a aModulePresent_n                    '1'
  --vhook_a bFamOutputEnable                    open
  --vhook_a stIoModuleSupportsFRAGLs            '0'
  --vhook_# Unused TDC
  --vhook_a aTdcAllPeclEn                       open
  --vhook_# Unused RefClk
  --vhook_a stEnableIoRefClk*                   '0'
  --vhook_a {bd.*IoRefClk.*}                    open            mode=out
  --vhook_a {bd.*IoRefClk.*}                    '0'             mode=in
  --vhook_g kExpectedTbIdGeneric kExpectedTbId
  --vhook_g kAuxDioDefaultVoltageGeneric kAuxDioDefaultVoltageConst
  FixedLogicWrapperx: entity work.FixedLogicWrapper (struct)
    generic map (
      kExpectedTbIdGeneric         => kExpectedTbId,               --std_logic_vector(31:0)
      kAuxDioDefaultVoltageGeneric => kAuxDioDefaultVoltageConst)  --natural
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
      stEnableIoRefClk10                 => '0',                                 --in  std_logic
      stEnableIoRefClk100                => '0',                                 --in  std_logic
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
      bIoSmbSclIn                        => '0',                                 --in  std_logic
      bIoSmbSclOut                       => open,                                --out std_logic
      bIoSmbSclTri                       => open,                                --out std_logic
      bIoSmbSdaIn                        => '0',                                 --in  std_logic
      bIoSmbSdaOut                       => open,                                --out std_logic
      bIoSmbSdaTri                       => open,                                --out std_logic
      bDigiPotSclk                       => bDigiPotSclk,                        --out std_logic
      bDigiPotMosi                       => bDigiPotMosi,                        --out std_logic
      bDigiPotMiso                       => bDigiPotMiso,                        --in  std_logic
      bDigiPotSync_n                     => bDigiPotSync_n,                      --out std_logic
      aCicada3v3BufEn_n                  => aCicada3v3BufEn_n,                   --out std_logic
      aTdcAllPeclEn                      => open,                                --out std_logic
      aTdcExpandedPulse                  => aTdcExpandedPulse,                   --in  std_logic
      bDramClocksValid                   => bDramClocksValid,                    --out std_logic
      bdSetIoRefClk100Enable             => open,                                --out std_logic
      bdClearIoRefClk100Enable           => open,                                --out std_logic
      bdSetIoRefClk10Enable              => open,                                --out std_logic
      bdClearIoRefClk10Enable            => open,                                --out std_logic
      bdSelectIoRefClk100                => open,                                --out std_logic
      bdSelectIoRefClk10                 => open,                                --out std_logic
      bdIoRefClk100Enabled               => '0',                                 --in  std_logic
      bdIoRefClk10Enabled                => '0',                                 --in  std_logic
      bdIoRefClkSwitch                   => '0',                                 --in  std_logic
      aModulePresent_n                   => '1',                                 --in  std_logic
      aFamPowerGood                      => '0',                                 --in  std_logic
      bFamOutputEnable                   => open,                                --out std_logic
      stIoModuleSupportsFRAGLs           => '0',                                 --in  std_logic
      bdClipAxi4LiteArAddr               => (others => '0'),                     --in  std_logic_vector(31:0)
      bdClipAxi4LiteArProt               => (others => '0'),                     --in  std_logic_vector(2:0)
      bdClipAxi4LiteArReady              => open,                                --out std_logic
      bdClipAxi4LiteArValid              => '0',                                 --in  std_logic
      bdClipAxi4LiteAwAddr               => (others => '0'),                     --in  std_logic_vector(31:0)
      bdClipAxi4LiteAwProt               => (others => '0'),                     --in  std_logic_vector(2:0)
      bdClipAxi4LiteAwReady              => open,                                --out std_logic
      bdClipAxi4LiteAwValid              => '0',                                 --in  std_logic
      bdClipAxi4LiteBReady               => '0',                                 --in  std_logic
      bdClipAxi4LiteBResp                => open,                                --out std_logic_vector(1:0)
      bdClipAxi4LiteBValid               => open,                                --out std_logic
      bdClipAxi4LiteRData                => open,                                --out std_logic_vector(31:0)
      bdClipAxi4LiteRReady               => '0',                                 --in  std_logic
      bdClipAxi4LiteRResp                => open,                                --out std_logic_vector(1:0)
      bdClipAxi4LiteRValid               => open,                                --out std_logic
      bdClipAxi4LiteWData                => (others => '0'),                     --in  std_logic_vector(31:0)
      bdClipAxi4LiteWReady               => open,                                --out std_logic
      bdClipAxi4LiteWStrb                => (others => '0'),                     --in  std_logic_vector(3:0)
      bdClipAxi4LiteWValid               => '0',                                 --in  std_logic
      aCicadaReset_n                     => aCicadaReset_n,                      --out std_logic
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
      dIrqFromFixedLogic                 => dIrqFromFixedLogic);                 --out std_logic

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

  -- Vivado 2019.1 has a bug where if the TDC input is not connected, it throws a DRC
  -- error. To work around it, just connect the TDC pulse.
  --vhook_i IBUFDS      TdcExpandedPulseBuf           hidegeneric=true
  --vhook_a I           aTdcExpandedPulse_p
  --vhook_a IB          aTdcExpandedPulse_n
  --vhook_a O           aTdcExpandedPulse
  TdcExpandedPulseBuf: IBUFDS
    port map (
      O  => aTdcExpandedPulse,    --out std_ulogic
      I  => aTdcExpandedPulse_p,  --in  std_ulogic
      IB => aTdcExpandedPulse_n); --in  std_ulogic

  --vhook_e  MacallanIoBuffers
  --vhook_#  I2C Outputs
  --vhook_af {aI2c(Scl|Sda)$}(kBaseSmbIndex)            {bBaseSmb$1}          continue=true
  --vhook_af {aI2c(Scl|Sda)$}(kConfigI2cIndex)          {bConfigI2c$1}        continue=true
  --vhook_af {aI2c(Scl|Sda)$}(kPwrSupplyPmbIndex)       {bPwrSupplyPmb$1}
  --vhook_#  Loopback (unused)
  --vhook_a  aFpgaLoopbackOut                           '0'
  --vhook_a  aFpgaLoopbackIn                            open
  --vhook_#  Out Enables that are currently unused
  --vhook_a  aPxieDStarCEn_n                            '0'
  MacallanIoBuffersx: entity work.MacallanIoBuffers (struct)
    generic map (
      kNumI2cIfcs   => kNumI2cIfcs,    --natural:=5
      kNumAuxIoData => kNumAuxIoData)  --natural:=8
    port map (
      aI2cSclIn                   => aI2cSclIn,              --out std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSclOut                  => aI2cSclOut,             --in  std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSclTri                  => aI2cSclTri,             --in  std_logic_vector(kNumI2cIfcs-1:0)
      aI2cScl(kBaseSmbIndex)      => bBaseSmbScl,            --inout std_logic_vector(kNumI2cIfcs-1:0)
      aI2cScl(kConfigI2cIndex)    => bConfigI2cScl,          --inout std_logic_vector(kNumI2cIfcs-1:0)
      aI2cScl(kPwrSupplyPmbIndex) => bPwrSupplyPmbScl,       --inout std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSdaIn                   => aI2cSdaIn,              --out std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSdaOut                  => aI2cSdaOut,             --in  std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSdaTri                  => aI2cSdaTri,             --in  std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSda(kBaseSmbIndex)      => bBaseSmbSda,            --inout std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSda(kConfigI2cIndex)    => bConfigI2cSda,          --inout std_logic_vector(kNumI2cIfcs-1:0)
      aI2cSda(kPwrSupplyPmbIndex) => bPwrSupplyPmbSda,       --inout std_logic_vector(kNumI2cIfcs-1:0)
      aPxiTrigDataIn              => aPxiTrigDataIn,         --out std_logic_vector(7:0)
      aPxiTrigDataOut             => aPxiTrigDataOut,        --in  std_logic_vector(7:0)
      aPxiTrigDataTri             => aPxiTrigDataTri,        --in  std_logic_vector(7:0)
      aPxiTrigData                => aPxiTrigData,           --inout std_logic_vector(7:0)
      aPxieDStarB                 => aPxieDStarB,            --out std_logic
      aPxieDStarB_p               => aPxieDStarB_p,          --in  std_logic
      aPxieDStarB_n               => aPxieDStarB_n,          --in  std_logic
      aPxieDStarC                 => aPxieDStarC,            --in  std_logic
      aPxieDStarCEn_n             => '0',                    --in  std_logic
      aPxieDStarC_p               => aPxieDStarC_p,          --out std_logic
      aPxieDStarC_n               => aPxieDStarC_n,          --out std_logic
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
                      bRegPortOutCommonRegs.Data or
                      bRegPortOutSharedRegs.Data;

  bRegPortOut.DataValid <= bLvWindowRegPortOut.DataValid or
                           bRegPortOutDram2DP.DataValid or
                           bRegPortOutCommonRegs.DataValid or
                           bRegPortOutSharedRegs.DataValid;

  bRegPortOut.Ready <= bLvWindowRegPortOut.Ready and
                       bRegPortOutDram2DP.Ready and
                       bRegPortOutCommonRegs.Ready and
                       bRegPortOutSharedRegs.Ready;

  bAddressesDram2DP  <= (bRegportIn.Address >= kDram2DPBaseAddress) and
                        (bRegportIn.Address <= (kDram2DPBaseAddress + kDram2DPAddressMask));

  -- Common host registers are recommended for every design so software has a
  -- standard identification/version interface across targets.
  --
  -- They always start at byte offset 0 and use this fixed map:
  --   offset 0   : signature
  --   offset 4   : version
  --   offset 8   : oldest compatible version
  --   offset 12  : scratch register
  --
  -- Keeping this layout consistent across designs simplifies host-driver
  -- compatibility checks and basic bring-up/debug workflows.

  HdlSharedCommonHostRegs_inst : entity work.HdlSharedCommonHostRegs
    generic map(
      kSignature               => x"7915BEEF",
      kVersion                 => x"00000001",
      kOldestCompatibleVersion => x"00000001"
    )
    port map(
      BusClk      => BusClk,
      aReset      => aBusReset,
      bRegPortIn  => bRegPortIn,
      bRegPortOut => bRegPortOutCommonRegs
    );

  HdlSharedHostRegisterArray_inst : entity work.HdlSharedHostRegisterArray
    generic map(
      kNumRegisters => 4,
      kBaseAddress  => 16#10#,
      kDefault      => (x"00000000", x"00000000", x"00000000", x"00000000"),
      kReadOnly     => (false, false, true, true),
      kUseFpgaAck   => (false, false, false, false)
    )
    port map(
      BusClk         => BusClk,
      aReset         => aBusReset,
      bRegPortIn     => bRegPortIn,
      bRegPortOut    => bRegPortOutSharedRegs,
      bFpgaHostWrite => bSharedHostRegFpgaHostWrite,
      bFpgaAck       => bSharedHostRegFpgaAck,
      bFpgaWrite     => bSharedHostRegFpgaWrite,
      bFpgaDataIn    => bSharedHostRegFpgaDataIn,
      bFpgaDataOut   => bSharedHostRegFpgaDataOut
    );

  -- Demonstration loopback logic for HdlSharedHostRegisterArray usage.
  --
  -- This process is meant only as an example of how FPGA-side logic can interact with
  -- host-visible registers.
  --
  -- Register behavior used here:
  --   - Register 0: host read/write input register
  --   - Register 1: host read/write input register
  --   - Register 2: host read-only output register (derived from register 0)
  --   - Register 3: host read-only output register (derived from register 1)
  --
  -- Practical effect for software users:
  --   - Write a value to register 0, then read register 2 to observe value+1.
  --   - Write a value to register 1, then read register 3 to observe value+1.
  --
  -- This demonstrates host-to-FPGA eventing (bFpgaHostWrite), FPGA-side processing, and
  -- FPGA-to-host updates (bFpgaWrite/bFpgaDataIn) using the shared register interface.

  SharedHostRegisterLoopbackx: process(BusClk, aBusReset)
  begin
    if aBusReset then
      bSharedHostRegFpgaWrite <= (others => false);
      bSharedHostRegFpgaDataIn <= (others => (others => '0'));
    elsif rising_edge(BusClk) then
      -- Default behavior: loop back all register values.
      bSharedHostRegFpgaDataIn <= bSharedHostRegFpgaDataOut;
      bSharedHostRegFpgaWrite <= (others => false);

      -- Host writes to lower registers (0 an 1) update upper read-only registers (2 and 3)
      -- with incremented values.
      if bSharedHostRegFpgaHostWrite(0) then
        bSharedHostRegFpgaDataIn(2) <= std_logic_vector(unsigned(bSharedHostRegFpgaDataOut(0)) + 1);
        bSharedHostRegFpgaWrite(2) <= true;
      end if;

      if bSharedHostRegFpgaHostWrite(1) then
        bSharedHostRegFpgaDataIn(3) <= std_logic_vector(unsigned(bSharedHostRegFpgaDataOut(1)) + 1);
        bSharedHostRegFpgaWrite(3) <= true;
      end if;
    end if;
  end process SharedHostRegisterLoopbackx;
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
  TheLvWindowWrapper: TheLvWindowFlatWrapper
    port map (
      -----------------------------------
      -- CUSTOM BOARD IO
      -----------------------------------

      -----------------------------------
      -- Communication interface ports
      -----------------------------------
      -- Reset ports
      aBusReset                           => to_StdLogic(aBusReset),                        --in  std_logic

      -- Register Access/ PIO Ports
      bRegPortIn                          => bRegPortInFlat,                                --in  std_logic_vector(kRegPortInSize-1:0)
      bRegPortOut                         => bRegPortOutFlat,                               --out std_logic_vector(kRegPortOutSize-1:0)
      bRegPortTimeout                     => to_stdlogic(bLvWindowRegPortTimeout),          --in  std_logic

      -- DMA Stream Ports
      dInputStreamInterfaceToFifo         => dInputStreamInterfaceToFifoFlat,               --in  std_logic_vector( Larger(kNumberOfDmaChannels,1)*SizeOf(kInputStreamInterfaceToFifoZero)-1:0)
      dInputStreamInterfaceFromFifo       => dInputStreamInterfaceFromFifoFlat,             --out std_logic_vector( Larger(kNumberOfDmaChannels,1)*SizeOf(kInputStreamInterfaceFromFifoZero)-1:0)
      dOutputStreamInterfaceToFifo        => dOutputStreamInterfaceToFifoFlat,              --in  std_logic_vector( Larger(kNumberOfDmaChannels,1)*SizeOf(kOutputStreamInterfaceToFifoZero)-1:0)
      dOutputStreamInterfaceFromFifo      => dOutputStreamInterfaceFromFifoFlat,            --out std_logic_vector( Larger(kNumberOfDmaChannels,1)*SizeOf(kOutputStreamInterfaceFromFifoZero)-1:0)

      -- Memory Buffer DMA Stream Ports (if any)

      -- IRQ Ports
      bIrqToInterface                     => bIrqToInterfaceFlat,                           --out std_logic_vector( Larger(kNumberOfIrqs,1)*kIrqToInterfaceSize*kIrqStatusToInterfaceSize-1:0)

      -- MasterPort Ports
      dNiFpgaMasterWriteRequestFromMaster => dNiFpgaMasterWriteRequestFromMasterArrayFlat,  --out std_logic_vector( Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterWriteRequestFromMasterZero)-1:0)
      dNiFpgaMasterWriteRequestToMaster   => dNiFpgaMasterWriteRequestToMasterArrayFlat,    --in  std_logic_vector( Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterWriteRequestToMasterZero)-1:0)
      dNiFpgaMasterWriteDataFromMaster    => dNiFpgaMasterWriteDataFromMasterArrayFlat,     --out std_logic_vector( Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterWriteDataFromMasterZero)-1:0)
      dNiFpgaMasterWriteDataToMaster      => dNiFpgaMasterWriteDataToMasterArrayFlat,       --in  std_logic_vector( Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterWriteDataToMasterZero)-1:0)
      dNiFpgaMasterWriteStatusToMaster    => dNiFpgaMasterWriteStatusToMasterArrayFlat,     --in  std_logic_vector( Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterWriteStatusToMasterZero)-1:0)
      dNiFpgaMasterReadRequestFromMaster  => dNiFpgaMasterReadRequestFromMasterArrayFlat,   --out std_logic_vector( Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterReadRequestFromMasterZero)-1:0)
      dNiFpgaMasterReadRequestToMaster    => dNiFpgaMasterReadRequestToMasterArrayFlat,     --in  std_logic_vector( Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterReadRequestToMasterZero)-1:0)
      dNiFpgaMasterReadDataToMaster       => dNiFpgaMasterReadDataToMasterArrayFlat,        --in  std_logic_vector( Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterReadDataToMasterZero)-1:0)

      -----------------------------------
      -- Clocks from TopLevel
      -----------------------------------
      DmaClk                              => DmaClk,                                        --in  std_logic
      BusClk                              => BusClk,                                        --in  std_logic
      ReliableClkIn                       => ReliableClk,                                   --in  std_logic
      PllClk80                            => BusClk,                                        --in  std_logic
      DlyRefClk                           => DlyRefClk,                                     --in  std_logic
      PxieClk100                          => PxieClk100,                                    --in  std_logic
      DramClkLvFpga                       => DramClkLvFpga,                                 --in  std_logic
      Dram0ClkSocket                      => Dram0ClkUser,                                  --in  std_logic
      Dram1ClkSocket                      => Dram1ClkUser,                                  --in  std_logic
      Dram0ClkUser                        => Dram0ClkUser,                                  --in  std_logic
      Dram1ClkUser                        => Dram1ClkUser,                                  --in  std_logic
      dHmbDmaClkSocket                    => DmaClk,                                        --in  std_logic
      dLlbDmaClkSocket                    => DmaClk,                                        --in  std_logic

      -----------------------------------
      -- IO Node ports
      -----------------------------------
      ---------------------
      -- BEGIN DIO and CLIP SOCKET PORTS
      ---------------------     
      -- ***** NO DIO and CLIP SOCKET PORTS *****    
      ----------------------
      -- END DIO and CLIP SOCKET PORTS
      ----------------------      
      pIntSync100                         => pIntSync100,                                   --in  std_logic
      aIntClk10                           => aIntClk10,                                     --in  std_logic

      -----------------------------------
      -- Target Method and Properties ports
      -----------------------------------
      bdIFifoRdData                       => bdIFifoRdData,                                 --out std_logic_vector(63:0)
      bdIFifoRdDataValid                  => bdIFifoRdDataValid,                            --out std_logic
      bdIFifoRdReadyForInput              => bdIFifoRdReadyForInput,                        --in  std_logic
      bdIFifoRdIsError                    => bdIFifoRdIsError,                              --out std_logic
      bdIFifoWrData                       => bdIFifoWrData,                                 --in  std_logic_vector(63:0)
      bdIFifoWrDataValid                  => bdIFifoWrDataValid,                            --in  std_logic
      bdIFifoWrReadyForOutput             => bdIFifoWrReadyForOutput,                       --out std_logic
      bdAxiStreamRdFromClipTData          => (others => '0'),                               --in  std_logic_vector(31:0)
      bdAxiStreamRdFromClipTLast          => '0',                                           --in  std_logic
      bdAxiStreamRdFromClipTValid         => '0',                                           --in  std_logic
      bdAxiStreamRdToClipTReady           => open,                                          --out std_logic
      bdAxiStreamWrToClipTData            => open,                                          --out std_logic_vector(31:0)
      bdAxiStreamWrToClipTLast            => open,                                          --out std_logic
      bdAxiStreamWrToClipTValid           => open,                                          --out std_logic
      bdAxiStreamWrFromClipTReady         => '0',                                           --in  std_logic

      -----------------------------------
      -- Pass through LabVIEW FPGA ports
      -----------------------------------

      ----------------------------------------
      -- Trigger Routing Socketed CLIP
      ----------------------------------------
      PxieClk100Trigger                   => PxieClk100,                                    --in  std_logic
      pIntSync100Trigger                  => pIntSync100,                                   --in  std_logic
      dTdcAssert                          => open,                                          --out std_logic
      dDevClkEn                           => '1',                                           --in  std_logic
      sTdcDeassert                        => open,                                          --out std_logic
      aIntClk10Trigger                    => aIntClk10,                                     --in  std_logic
      bRoutingClipPresent                 => bRoutingClipPresent,                           --out std_logic
      bRoutingClipNiCompatible            => bRoutingClipNiCompatible,                      --out std_logic
      BusClkTrigger                       => BusClk,                                        --in  std_logic
      abBusResetTrigger                   => to_StdLogic(abBusReset),                       --in  std_logic
      bTriggerRoutingBaRegPortInAddress   => bTriggerRoutingBaRegPortInAddress,             --in  std_logic_vector(27:0)
      bTriggerRoutingBaRegPortInData      => bTriggerRoutingBaRegPortInData,                --in  std_logic_vector(63:0)
      bTriggerRoutingBaRegPortInWtStrobe  => bTriggerRoutingBaRegPortInWtStrobe,            --in  std_logic_vector(7:0)
      bTriggerRoutingBaRegPortInRdStrobe  => bTriggerRoutingBaRegPortInRdStrobe,            --in  std_logic_vector(7:0)
      bTriggerRoutingBaRegPortOutData     => bTriggerRoutingBaRegPortOutData,               --out std_logic_vector(63:0)
      bTriggerRoutingBaRegPortOutAck      => bTriggerRoutingBaRegPortOutAck,                --out std_logic
      aPxiTrigDataIn                      => aPxiTrigDataIn,                                --in  std_logic_vector(7:0)
      aPxiTrigDataOut                     => aPxiTrigDataOut,                               --out std_logic_vector(7:0)
      aPxiTrigDataTri                     => aPxiTrigDataTri,                               --out std_logic_vector(7:0)
      aPxiStarData                        => aPxiStarData,                                  --in  std_logic
      aPxieDstarB                         => aPxieDstarB,                                   --in  std_logic
      aPxieDstarC                         => aPxieDstarC,                                   --out std_logic

      -----------------------------------------------------------------------------
      --Dram Interface
      -----------------------------------------------------------------------------
      aDramReady                          => aDramReady,                                    --in  std_logic
      du0DramAddrFifoAddr                 => du0DramAddrFifoAddr,                           --out std_logic_vector(28:0)
      du0DramAddrFifoCmd                  => du0DramAddrFifoCmd,                            --out std_logic_vector(2:0)
      du0DramAddrFifoFull                 => du0DramAddrFifoFull,                           --in  std_logic
      du0DramAddrFifoWrEn                 => du0DramAddrFifoWrEn,                           --out std_logic
      du0DramPhyInitDone                  => du0DramPhyInitDone,                            --in  std_logic
      du0DramRdDataValid                  => du0DramRdDataValid,                            --in  std_logic
      du0DramRdFifoDataOut                => du0DramRdFifoDataOut,                          --in  std_logic_vector(255:0)
      du0DramWrFifoDataIn                 => du0DramWrFifoDataIn,                           --out std_logic_vector(255:0)
      du0DramWrFifoFull                   => du0DramWrFifoFull,                             --in  std_logic
      du0DramWrFifoMaskData               => du0DramWrFifoMaskData,                         --out std_logic_vector(31:0)
      du0DramWrFifoWrEn                   => du0DramWrFifoWrEn,                             --out std_logic
      du1DramAddrFifoAddr                 => du1DramAddrFifoAddr,                           --out std_logic_vector(28:0)
      du1DramAddrFifoCmd                  => du1DramAddrFifoCmd,                            --out std_logic_vector(2:0)
      du1DramAddrFifoFull                 => du1DramAddrFifoFull,                           --in  std_logic
      du1DramAddrFifoWrEn                 => du1DramAddrFifoWrEn,                           --out std_logic
      du1DramPhyInitDone                  => du1DramPhyInitDone,                            --in  std_logic
      du1DramRdDataValid                  => du1DramRdDataValid,                            --in  std_logic
      du1DramRdFifoDataOut                => du1DramRdFifoDataOut,                          --in  std_logic_vector(255:0)
      du1DramWrFifoDataIn                 => du1DramWrFifoDataIn,                           --out std_logic_vector(255:0)
      du1DramWrFifoFull                   => du1DramWrFifoFull,                             --in  std_logic
      du1DramWrFifoMaskData               => du1DramWrFifoMaskData,                         --out std_logic_vector(31:0)
      du1DramWrFifoWrEn                   => du1DramWrFifoWrEn,                             --out std_logic

      -----------------------------------------------------------------------------
      --HMB Interface
      -----------------------------------------------------------------------------
      dHmbDramAddrFifoAddr                => dHmbDramAddrFifoAddr,                          --out std_logic_vector(31:0)
      dHmbDramAddrFifoCmd                 => dHmbDramAddrFifoCmd,                           --out std_logic_vector(2:0)
      dHmbDramAddrFifoFull                => dHmbDramAddrFifoFull,                          --in  std_logic
      dHmbDramAddrFifoWrEn                => dHmbDramAddrFifoWrEn,                          --out std_logic
      dHmbDramRdDataValid                 => dHmbDramRdDataValid,                           --in  std_logic
      dHmbDramRdFifoDataOut               => dHmbDramRdFifoDataOut,                         --in  std_logic_vector(1023:0)
      dHmbDramWrFifoDataIn                => dHmbDramWrFifoDataIn,                          --out std_logic_vector(1023:0)
      dHmbDramWrFifoFull                  => dHmbDramWrFifoFull,                            --in  std_logic
      dHmbDramWrFifoMaskData              => dHmbDramWrFifoMaskData,                        --out std_logic_vector(127:0)
      dHmbDramWrFifoWrEn                  => dHmbDramWrFifoWrEn,                            --out std_logic
      dHmbPhyInitDoneForLvfpga            => dHmbPhyInitDoneForLvfpga,                      --in  std_logic
      dLlbDramAddrFifoAddr                => dLlbDramAddrFifoAddr,                          --out std_logic_vector(31:0)
      dLlbDramAddrFifoCmd                 => dLlbDramAddrFifoCmd,                           --out std_logic_vector(2:0)
      dLlbDramAddrFifoFull                => dLlbDramAddrFifoFull,                          --in  std_logic
      dLlbDramAddrFifoWrEn                => dLlbDramAddrFifoWrEn,                          --out std_logic
      dLlbDramRdDataValid                 => dLlbDramRdDataValid,                           --in  std_logic
      dLlbDramRdFifoDataOut               => dLlbDramRdFifoDataOut,                         --in  std_logic_vector(1023:0)
      dLlbDramWrFifoDataIn                => dLlbDramWrFifoDataIn,                          --out std_logic_vector(1023:0)
      dLlbDramWrFifoFull                  => dLlbDramWrFifoFull,                            --in  std_logic
      dLlbDramWrFifoMaskData              => dLlbDramWrFifoMaskData,                        --out std_logic_vector(127:0)
      dLlbDramWrFifoWrEn                  => dLlbDramWrFifoWrEn,                            --out std_logic
      dLlbPhyInitDoneForLvfpga            => dLlbPhyInitDoneForLvfpga,                      --in  std_logic

      -----------------------------------
      -- Clocks from TheWindow
      -----------------------------------
      TopLevelClkOut                      => open,                                          --out std_logic
      ReliableClkOut                      => open,                                          --out std_logic

      -----------------------------------
      -- Diagram/Reset/Clock status
      -----------------------------------
      rBaseClksValid                      => rBaseClksValid,                                --in  std_logic:='1'
      tDiagramActive                      => open,                                          --out std_logic
      rDiagramReset                       => open,                                          --out std_logic
      aDiagramReset                       => aDiagramReset,                                 --out std_logic
      rDerivedClockLostLockError          => open,                                          --out std_logic
      rGatedBaseClksValid                 => '1',                                           --in  std_logic:='1'
      aSafeToEnableGatedClks              => open);                                         --out std_logic


  -----------------------------------
  -- Convert record inputs to flat
  -----------------------------------
  bRegPortInFlat <= to_StdLogicVector(bRegPortIn);

  dInputStreamInterfaceToFifoFlat <= FlattenStreamInterface(dInputStreamInterfaceToFifo);
  dOutputStreamInterfaceToFifoFlat <= FlattenStreamInterface(dOutputStreamInterfaceToFifo);

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

  dInputStreamInterfaceFromFifo <= UnflattenStreamInterface(dInputStreamInterfaceFromFifoFlat);
  dOutputStreamInterfaceFromFifo <= UnflattenStreamInterface(dOutputStreamInterfaceFromFifoFlat);

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
  aFpgaToCicadaRsvd <= (others => '0');

  aTdcAllPeclEn <= '0';
  dvTdcAssert   <= '0';
  sTdcDeassert  <= '0';

  aIoRefClk100En  <= '0';
  aIoRefClk10En   <= '0';
  aIoRefSelClk100 <= '0';

  -- Unused top-level signals
  --vhook_nowarn aPoscEn
  --vhook_nowarn aIoSmbAlert_n

end architecture struct;

