-------------------------------------------------------------------------------
-- File: UserRTL_PXIe7903_Aurora64b66b_Framing_Crcx4_[lineRateStr]GHz.vhd
-- Author: National Instruments
-- Workspace: PXIe-7903 HSS
-- Date: 26 August 2022
-------------------------------------------------------------------------------
-- Copyright (c) 2025 National Instruments Corporation
-- 
-- All rights reserved.
-------------------------------------------------------------------------------
--
-- Purpose:
--   This CLIP instantiates an Aurora 64b66b core for the PXIe-7903. This core
-- is configured with the following settings:
--
-- [NumPort] Ports
-- 4 Lanes
-- Line rate: [lineRate]Gbps
-- Reference Clock: [refClk]MHz
-- Interface: Framing
-- CRC: True
-- Flow Control : Immediate NFC
-- Little Endian ： True
--
-------------------------------------------------------------------------------
--
-- githubvisible=true
--
-- vreview_group Ni7903AuroraStreamingVhdl
-- vreview_closed http://review-board.natinst.com/r/332238/
-- vreview_reviewers kygreen dhearn amoch
--
-------------------------------------------------------------------------------


library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgAXI4Lite_GTYE4_Control.all;

library unisim;
  use unisim.vcomponents.all;

entity UserRTL_PXIe7903_Aurora64b66b_Framing_Crcx4_[lineRateStr]GHz is
  port (
    -------------------------------------------------------------------------------------
    -- NI 7903 Required Signals
    -------------------------------------------------------------------------------------
    -------------------------------------------------------
    -- Reset
    -------------------------------------------------------
    -- Asynchronous reset signal from the LabVIEW FPGA environment.
    -- This signal *must* be present in the port interface for all IO Socket CLIPs.
    -- You should reset your CLIP logic whenever this signal is logic high.
    aResetSl                        : in  std_logic;

    -------------------------------------------------------
    -- REQUIRED Socket Signals
    -------------------------------------------------------
    -- Configuration
    aLmkI2cSda                      : inout std_logic;
    aLmkI2cScl                      : inout std_logic;
    aLmk1Pdn_n                      : out std_logic;
    aLmk2Pdn_n                      : out std_logic;
    aLmk1Gpio0                      : out std_logic;
    aLmk2Gpio0                      : out std_logic;
    aLmk1Status0                    : in std_logic;
    aLmk1Status1                    : in std_logic;
    aLmk2Status0                    : in std_logic;
    aLmk2Status1                    : in std_logic;
    aIPassPrsnt_n                   : in std_logic_vector(7 downto 0);
    aIPassIntr_n                    : in std_logic_vector(7 downto 0);
    aIPassSCL                       : inout std_logic_vector(11 downto 0);
    aIPassSDA                       : inout std_logic_vector(11 downto 0);
    aPortExpReset_n                 : out std_logic;
    aPortExpIntr_n                  : in std_logic;
    aPortExpSda                     : inout std_logic;
    aPortExpScl                     : inout std_logic;
    aIPassVccPowerFault_n           : in std_logic;

    -- Reserved Interfaces
    stIoModuleSupportsFRAGLs        : out std_logic;

    -------------------------------------------------------
    -- DIO Signals
    -------------------------------------------------------
    aDio                            : inout std_logic_vector(7 downto 0);

    -------------------------------------------------------
    -- AXI Communication Interfaces
    -------------------------------------------------------
    AxiClk                          : in  std_logic;
    xHostAxiStreamToClipTData       : in  std_logic_vector(31 downto 0);
    xHostAxiStreamToClipTLast       : in  std_logic;
    xHostAxiStreamFromClipTReady    : out std_logic;
    xHostAxiStreamToClipTValid      : in  std_logic;
    xHostAxiStreamFromClipTData     : out std_logic_vector(31 downto 0);
    xHostAxiStreamFromClipTLast     : out std_logic;
    xHostAxiStreamToClipTReady      : in  std_logic;
    xHostAxiStreamFromClipTValid    : out std_logic;
    xDiagramAxiStreamToClipTData    : in  std_logic_vector(31 downto 0);
    xDiagramAxiStreamToClipTLast    : in  std_logic;
    xDiagramAxiStreamFromClipTReady : out std_logic;
    xDiagramAxiStreamToClipTValid   : in  std_logic;
    xDiagramAxiStreamFromClipTData  : out std_logic_vector(31 downto 0);
    xDiagramAxiStreamFromClipTLast  : out std_logic;
    xDiagramAxiStreamToClipTReady   : in  std_logic;
    xDiagramAxiStreamFromClipTValid : out std_logic;

    -- AXI4 Lite interfaces
    xClipAxi4LiteMasterARAddr       : out std_logic_vector(31 downto 0);
    xClipAxi4LiteMasterARProt       : out std_logic_vector(2 downto 0);
    xClipAxi4LiteMasterARReady      : in  std_logic;
    xClipAxi4LiteMasterARValid      : out std_logic;
    xClipAxi4LiteMasterAWAddr       : out std_logic_vector(31 downto 0);
    xClipAxi4LiteMasterAWProt       : out std_logic_vector(2 downto 0);
    xClipAxi4LiteMasterAWReady      : in  std_logic;
    xClipAxi4LiteMasterAWValid      : out std_logic;
    xClipAxi4LiteMasterBReady       : out std_logic;
    xClipAxi4LiteMasterBResp        : in  std_logic_vector(1 downto 0);
    xClipAxi4LiteMasterBValid       : in  std_logic;
    xClipAxi4LiteMasterRData        : in  std_logic_vector(31 downto 0);
    xClipAxi4LiteMasterRReady       : out std_logic;
    xClipAxi4LiteMasterRResp        : in  std_logic_vector(1 downto 0);
    xClipAxi4LiteMasterRValid       : in  std_logic;
    xClipAxi4LiteMasterWData        : out std_logic_vector(31 downto 0);
    xClipAxi4LiteMasterWReady       : in  std_logic;
    xClipAxi4LiteMasterWStrb        : out std_logic_vector(3 downto 0);
    xClipAxi4LiteMasterWValid       : out std_logic;

    xClipAxi4LiteInterrupt          : in  std_logic;
    --vhook_nowarn xClipAxi4LiteInterrupt

    -------------------------------------------------------
    -- MGT Socket Interface
    -------------------------------------------------------
    -- These signals connect directly to the MGT pins, and should be connected to the
    -- user's IP.
    MgtRefClk_p                     : in  std_logic_vector(11 downto 0);
    MgtRefClk_n                     : in  std_logic_vector(11 downto 0);
    MgtPortRx_p                     : in  std_logic_vector(47 downto 0);
    MgtPortRx_n                     : in  std_logic_vector(47 downto 0);
    MgtPortTx_p                     : out std_logic_vector(47 downto 0);
    MgtPortTx_n                     : out std_logic_vector(47 downto 0);

    -------------------------------------------------------------------------------------
    -- Diagram facing signals
    -- This is the collection of signals that appears in LabVIEW FPGA.
    -- LabVIEW FPGA signals must use one of the following signal directions:  {in, out}
    -- LabVIEW FPGA signals must use one of the following data types:
    --          std_logic
    --          std_logic_vector(7 downto 0)
    --          std_logic_vector(15 downto 0)
    --          std_logic_vector(31 downto 0)
    --          std_logic_vector(63 downto 0)
    -------------------------------------------------------------------------------------

    -------------------------------------------------------
    -- REQUIRED Diagram Signals
    -------------------------------------------------------
    -- This is the exact same clock as AxiClk, but we need to bring it in so LVFPGA can enforce its use.
    --vhook_nowarn TopLevelClk80
    TopLevelClk80                   : in  std_logic;
    -- Status signals to the diagram
    xIoModuleReady                  : out std_logic;
    xIoModuleErrorCode              : out std_logic_vector(31 downto 0);
    -- DIO
    aDioOut                         : in  std_logic_vector(7 downto 0);
    aDioIn                          : out std_logic_vector(7 downto 0);

    -------------------------------------------------------------------------------------
    -- Aurora Signals
    -------------------------------------------------------------------------------------
    -------------------------------------------------------
    -- Aurora User Clock
    -------------------------------------------------------
    -- AXI Streaming User Clock Outputs (to LabVIEW FPGA diagram from I/O Socket)
    -- These clocks run at the line rate/64. By default, at 28.0Gbps, these
    -- clocks run at 437.5MHz.
    [StartDuplicatePort]
    UserClkPort[PortNum]                    : out std_logic;
    [EndDuplicatePort]

    -------------------------------------------------------
    -- Aurora Reset Interface
    -------------------------------------------------------
    -- Initialization reset signals to the Aurora cores
    -- pma_init : clock domain async
    --   The transceiver pma_init reset signal is connected to the top level
    --   through a debouncer. Systematically resets all Physical Coding Sublayer (PCS)
    --   and Physical Medium Attachment (PMA) subcomponents of the transceiver.
    [StartDuplicatePort]
    aPort[PortNum]PmaInit                   : in  std_logic;
    [EndDuplicatePort]

    -- reset_pb : clock domain async
    --   Push Button Reset. The top-level reset input at the example design level.
    [StartDuplicatePort]
    aPort[PortNum]ResetPb                   : in  std_logic;
    [EndDuplicatePort]

    -------------------------------------------------------
    -- Aurora AXI Tx Data Interface
    -------------------------------------------------------
    [StartDuplicatePort]
    -- The following signals are REQUIRED to be in the UserClkPort[PortNum] domain:
    uPort[PortNum]AxiTxTData0               : in  std_logic_vector(63 downto 0);
    uPort[PortNum]AxiTxTData1               : in  std_logic_vector(63 downto 0);
    uPort[PortNum]AxiTxTData2               : in  std_logic_vector(63 downto 0);
    uPort[PortNum]AxiTxTData3               : in  std_logic_vector(63 downto 0);
    uPort[PortNum]AxiTxTKeep                : in  std_logic_vector(31 downto 0);
    uPort[PortNum]AxiTxTLast                : in  std_logic;
    uPort[PortNum]AxiTxTValid               : in  std_logic;
    uPort[PortNum]AxiTxTReady               : out std_logic;

    [EndDuplicatePort]

    -------------------------------------------------------
    -- Aurora AXI Rx Data Interface
    -------------------------------------------------------
    [StartDuplicatePort]
    -- The following signals are REQUIRED to be in the UserClkPort[PortNum] domain:
    uPort[PortNum]AxiRxTData0               : out std_logic_vector(63 downto 0);
    uPort[PortNum]AxiRxTData1               : out std_logic_vector(63 downto 0);
    uPort[PortNum]AxiRxTData2               : out std_logic_vector(63 downto 0);
    uPort[PortNum]AxiRxTData3               : out std_logic_vector(63 downto 0);
    uPort[PortNum]AxiRxTKeep                : out std_logic_vector(31 downto 0);
    uPort[PortNum]AxiRxTLast                : out std_logic;
    uPort[PortNum]AxiRxTValid               : out std_logic;

    [EndDuplicatePort]

    -------------------------------------------------------
    -- Aurora AXI Native Flow Control Interface
    -------------------------------------------------------
    [StartDuplicatePort]
    -- The following signals are REQUIRED to be in the UserClkPort[PortNum] domain:
    uPort[PortNum]AxiNfcTValid              : in  std_logic;
    uPort[PortNum]AxiNfcTData               : in  std_logic_vector(31 downto 0);
    uPort[PortNum]AxiNfcTReady              : out std_logic;

    [EndDuplicatePort]

    -------------------------------------------------------
    -- Aurora Link Status Interface
    -------------------------------------------------------
    [StartDuplicatePort]
    -- The following signals are REQUIRED to be in the UserClkPort[PortNum] domain:
    uPort[PortNum]HardError                 : out std_logic;
    uPort[PortNum]SoftError                 : out std_logic;
    uPort[PortNum]LaneUp                    : out std_logic_vector(3 downto 0);
    uPort[PortNum]ChannelUp                 : out std_logic;
    uPort[PortNum]SysResetOut               : out std_logic;
    uPort[PortNum]MmcmNotLockOut            : out std_logic;
    uPort[PortNum]CrcPassFail_n             : out std_logic;
    uPort[PortNum]CrcValid                  : out std_logic;

    [EndDuplicatePort]

    -- The following signals are REQUIRED to be in the init_clk domain:
    [StartDuplicatePort]
    iPort[PortNum]LinkResetOut              : out std_logic;  -- Driven High if hot-plug count expires
    [EndDuplicatePort]

    -------------------------------------------------------------------------------------
    -- Aurora AXI4-Lite Ctrl/Drp Interface
    -------------------------------------------------------------------------------------
    [StartDuplicatePort]
    -------------------------------------------------------
    -- Aurora Port [PortNum] Ctrl Register Interface
    -------------------------------------------------------
    -- The following signals are REQUIRED to be in the SAClk domain:
    sGtwiz[PortNum]CtrlAxiAWAddr            : in  std_logic_vector(31 downto 0);
    sGtwiz[PortNum]CtrlAxiAWValid           : in  std_logic;
    sGtwiz[PortNum]CtrlAxiAWReady           : out std_logic;
    sGtwiz[PortNum]CtrlAxiWData             : in  std_logic_vector(31 downto 0);
    sGtwiz[PortNum]CtrlAxiWStrb             : in  std_logic_vector(3 downto 0);
    sGtwiz[PortNum]CtrlAxiWValid            : in  std_logic;
    sGtwiz[PortNum]CtrlAxiWReady            : out std_logic;
    sGtwiz[PortNum]CtrlAxiBResp             : out std_logic_vector(1 downto 0);
    sGtwiz[PortNum]CtrlAxiBValid            : out std_logic;
    sGtwiz[PortNum]CtrlAxiBReady            : in  std_logic;
    sGtwiz[PortNum]CtrlAxiARAddr            : in  std_logic_vector(31 downto 0);
    sGtwiz[PortNum]CtrlAxiARValid           : in  std_logic;
    sGtwiz[PortNum]CtrlAxiARReady           : out std_logic;
    sGtwiz[PortNum]CtrlAxiRData             : out std_logic_vector(31 downto 0);
    sGtwiz[PortNum]CtrlAxiRResp             : out std_logic_vector(1 downto 0);
    sGtwiz[PortNum]CtrlAxiRValid            : out std_logic;
    sGtwiz[PortNum]CtrlAxiRReady            : in  std_logic;

    -------------------------------------------------------
    -- Aurora Port [PortNum] Channel DRP Interface
    -------------------------------------------------------
    -- The following signals are REQUIRED to be in the SAClk domain:
    sGtwiz[PortNum]DrpChAxiAWAddr           : in  std_logic_vector(31 downto 0);
    sGtwiz[PortNum]DrpChAxiAWValid          : in  std_logic;
    sGtwiz[PortNum]DrpChAxiAWReady          : out std_logic;
    sGtwiz[PortNum]DrpChAxiWData            : in  std_logic_vector(31 downto 0);
    sGtwiz[PortNum]DrpChAxiWStrb            : in  std_logic_vector(3 downto 0);
    sGtwiz[PortNum]DrpChAxiWValid           : in  std_logic;
    sGtwiz[PortNum]DrpChAxiWReady           : out std_logic;
    sGtwiz[PortNum]DrpChAxiBResp            : out std_logic_vector(1 downto 0);
    sGtwiz[PortNum]DrpChAxiBValid           : out std_logic;
    sGtwiz[PortNum]DrpChAxiBReady           : in  std_logic;
    sGtwiz[PortNum]DrpChAxiARAddr           : in  std_logic_vector(31 downto 0);
    sGtwiz[PortNum]DrpChAxiARValid          : in  std_logic;
    sGtwiz[PortNum]DrpChAxiARReady          : out std_logic;
    sGtwiz[PortNum]DrpChAxiRData            : out std_logic_vector(31 downto 0);
    sGtwiz[PortNum]DrpChAxiRResp            : out std_logic_vector(1 downto 0);
    sGtwiz[PortNum]DrpChAxiRValid           : out std_logic;
    sGtwiz[PortNum]DrpChAxiRReady           : in  std_logic;

    [EndDuplicatePort]
    -------------------------------------------------------------------------------------
    -- Clocks
    -------------------------------------------------------------------------------------
    -- These signals may be modified to meet the requirements of the CLIP.
    -- If the ports are modified, the CLIP XML file must be updated to
    -- reflect the port map.
    -- InitClk required by Aurora IP core to register and debounce the pma_init signal.
    -- InitClk is also connected to the DRPCLK port of the GTHE3/GTYE3/GTHE4/GTYE4
    -- CHANNEL interface.
    InitClk                         : in  std_logic;
    -- SAClk is the main clock for AXI interface to access MGT registers and Channel DRP
    SAClk                           : in  std_logic
  );
end UserRTL_PXIe7903_Aurora64b66b_Framing_Crcx4_[lineRateStr]GHz;

architecture rtl of UserRTL_PXIe7903_Aurora64b66b_Framing_Crcx4_[lineRateStr]GHz is

  --vhook_sigstart
  signal aDioOutEn: std_logic_vector(7 downto 0);
  --vhook_sigend

  constant kNumLanes : integer := 4;  -- lanes per port
  constant kAddrSize : integer := 10; -- DRP address width
  constant kNumPorts : integer := [NumPort];  -- number of ports on front panel
  constant kCutOffFreqForExtraReg : real := 16.375; -- cut off frequency for extra pipeline register to improve timing, unit GHz

  --vhook_d AXI4Lite_GTYE4_Control_Regs4
  component AXI4Lite_GTYE4_Control_Regs4
    port (
      LiteClk                     : in  std_logic;
      aReset_n                    : in  std_logic;
      lAxiMasterWritePort         : in  Axi4LiteWritePortIn_t;
      lAxiSlaveWritePort          : out Axi4LiteWritePortOut_t;
      lAxiMasterReadPort          : in  Axi4LiteReadPortIn_t;
      lAxiSlaveReadPort           : out Axi4LiteReadPortOut_t;
      RxUsrClk2                   : in  std_logic_vector(4-1 downto 0);
      TxUsrClk2                   : in  std_logic_vector(4-1 downto 0);
      MgtRefClk                   : in  std_logic;
      aGtWiz_ResetAll_in          : out std_logic;
      aGtWiz_RxCdr_stable_out     : in  std_logic;
      aGtWiz_ResetTx_pll_data_in  : out std_logic;
      aGtWiz_ResetTx_data_in      : out std_logic;
      aGtWiz_ResetTx_Done_out     : in  std_logic;
      aGtWiz_UserClkTx_active_out : in  std_logic_vector(3 downto 0);
      aGtWiz_ResetRx_pll_data_in  : out std_logic;
      aGtWiz_ResetRx_data_in      : out std_logic;
      aGtWiz_ResetRx_Done_out     : in  std_logic;
      aGtWiz_UserClkRx_active_out : in  std_logic_vector(3 downto 0);
      rRxResetDone_out            : in  std_logic_vector(4-1 downto 0);
      aRxPmaResetDone_out         : in  std_logic_vector(4-1 downto 0);
      aRxPmaReset_in              : out std_logic_vector(4-1 downto 0);
      tTxResetDone_out            : in  std_logic_vector(4-1 downto 0);
      aTxPmaResetDone_out         : in  std_logic_vector(4-1 downto 0);
      aTxPmaReset_in              : out std_logic_vector(4-1 downto 0);
      aTxPcsReset_in              : out std_logic_vector(4-1 downto 0);
      aEyeScanReset_in            : out std_logic_vector(4-1 downto 0);
      aGtPowerGood_out            : in  std_logic_vector(4-1 downto 0);
      aCpllPD_in                  : out std_logic_vector(4-1 downto 0);
      aCpllReset_in               : out std_logic_vector(4-1 downto 0);
      aCpllRefClkSel_in           : out GTRefClkSelAry_t(4-1 downto 0);
      aCpllLock_out               : in  std_logic_vector(4-1 downto 0);
      aCpllRefClkLost_out         : in  std_logic_vector(4-1 downto 0);
      aQpll0PD_in                 : out std_logic;
      aQpll0Reset_in              : out std_logic;
      aQpll0RefClkSel_in          : out GTRefClkSel_t;
      aQpll0Lock_out              : in  std_logic;
      aQpll0RefClkLost_out        : in  std_logic;
      aQpll0SdmReset_in           : out std_logic;
      aQpll0SdmData_in            : out std_logic_vector(24 downto 0);
      aQpll0SdmWidth_in           : out std_logic_vector(1 downto 0);
      aQpll0SdmToggle_in          : out std_logic;
      aQpll0SdmFinalOut_out       : in  std_logic_vector(3 downto 0);
      aQpll1PD_in                 : out std_logic;
      aQpll1Reset_in              : out std_logic;
      aQpll1RefClkSel_in          : out GTRefClkSel_t;
      aQpll1Lock_out              : in  std_logic;
      aQpll1RefClkLost_out        : in  std_logic;
      aQpll1SdmReset_in           : out std_logic;
      aQpll1SdmData_in            : out std_logic_vector(24 downto 0);
      aQpll1SdmWidth_in           : out std_logic_vector(1 downto 0);
      aQpll1SdmToggle_in          : out std_logic;
      aQpll1SdmFinalOut_out       : in  std_logic_vector(3 downto 0);
      aTxSysClkSel_in             : out GTClkSelAry_t(4-1 downto 0);
      aRxSysClkSel_in             : out GTClkSelAry_t(4-1 downto 0);
      aTxPllClkSel_in             : out GTClkSelAry_t(4-1 downto 0);
      aRxPllClkSel_in             : out GTClkSelAry_t(4-1 downto 0);
      aTxOutClkSel_in             : out GTOutClkSelAry_t(4-1 downto 0);
      aRxOutClkSel_in             : out GTOutClkSelAry_t(4-1 downto 0);
      aRxCdrHold_in               : out std_logic_vector(4-1 downto 0);
      aRxCdrOvrdEn_in             : out std_logic_vector(4-1 downto 0);
      aRxCdrReset_in              : out std_logic_vector(4-1 downto 0);
      aRxCdrLock_out              : in  std_logic_vector(4-1 downto 0);
      tTxPiPpmEn_in               : out std_logic_vector(4-1 downto 0);
      tTxPiPpmOvrdEn_in           : out std_logic_vector(4-1 downto 0);
      aTxPiPpmPD_in               : out std_logic_vector(4-1 downto 0);
      tTxPiPpmSel_in              : out std_logic_vector(4-1 downto 0);
      tTxPiPpmStepSize_in         : out GTTxPiPpmStepSizeAry_t(4-1 downto 0);
      rRxDfeOSHold_in             : out std_logic_vector(4-1 downto 0);
      rRxDfeOSOvrdEn_in           : out std_logic_vector(4-1 downto 0);
      rRxDfeAgcHold_in            : out std_logic_vector(4-1 downto 0);
      rRxDfeAgcOvrdEn_in          : out std_logic_vector(4-1 downto 0);
      rRxDfeLFHold_in             : out std_logic_vector(4-1 downto 0);
      rRxDfeLFOvrdEn_in           : out std_logic_vector(4-1 downto 0);
      rRxDfeUTHold_in             : out std_logic_vector(4-1 downto 0);
      rRxDfeUTOvrdEn_in           : out std_logic_vector(4-1 downto 0);
      rRxDfeVPHold_in             : out std_logic_vector(4-1 downto 0);
      rRxDfeVPOvrdEn_in           : out std_logic_vector(4-1 downto 0);
      rRxDfeTap2Hold_in           : out std_logic_vector(4-1 downto 0);
      rRxDfeTap2OvrdEn_in         : out std_logic_vector(4-1 downto 0);
      rRxDfeTap3Hold_in           : out std_logic_vector(4-1 downto 0);
      rRxDfeTap3OvrdEn_in         : out std_logic_vector(4-1 downto 0);
      rRxDfeTap4Hold_in           : out std_logic_vector(4-1 downto 0);
      rRxDfeTap4OvrdEn_in         : out std_logic_vector(4-1 downto 0);
      rRxDfeTap5Hold_in           : out std_logic_vector(4-1 downto 0);
      rRxDfeTap5OvrdEn_in         : out std_logic_vector(4-1 downto 0);
      rRxDfeTap6Hold_in           : out std_logic_vector(4-1 downto 0);
      rRxDfeTap6OvrdEn_in         : out std_logic_vector(4-1 downto 0);
      rRxDfeTap7Hold_in           : out std_logic_vector(4-1 downto 0);
      rRxDfeTap7OvrdEn_in         : out std_logic_vector(4-1 downto 0);
      rRxDfeTap8Hold_in           : out std_logic_vector(4-1 downto 0);
      rRxDfeTap8OvrdEn_in         : out std_logic_vector(4-1 downto 0);
      rRxDfeTap9Hold_in           : out std_logic_vector(4-1 downto 0);
      rRxDfeTap9OvrdEn_in         : out std_logic_vector(4-1 downto 0);
      rRxDfeTap10Hold_in          : out std_logic_vector(4-1 downto 0);
      rRxDfeTap10OvrdEn_in        : out std_logic_vector(4-1 downto 0);
      rRxDfeTap11Hold_in          : out std_logic_vector(4-1 downto 0);
      rRxDfeTap11OvrdEn_in        : out std_logic_vector(4-1 downto 0);
      rRxDfeTap12Hold_in          : out std_logic_vector(4-1 downto 0);
      rRxDfeTap12OvrdEn_in        : out std_logic_vector(4-1 downto 0);
      rRxDfeTap13Hold_in          : out std_logic_vector(4-1 downto 0);
      rRxDfeTap13OvrdEn_in        : out std_logic_vector(4-1 downto 0);
      rRxDfeTap14Hold_in          : out std_logic_vector(4-1 downto 0);
      rRxDfeTap14OvrdEn_in        : out std_logic_vector(4-1 downto 0);
      rRxDfeTap15Hold_in          : out std_logic_vector(4-1 downto 0);
      rRxDfeTap15OvrdEn_in        : out std_logic_vector(4-1 downto 0);
      rRxLpmEn_in                 : out std_logic_vector(4-1 downto 0);
      rRxLpmOSHold_in             : out std_logic_vector(4-1 downto 0);
      rRxLpmOSOvrdEn_in           : out std_logic_vector(4-1 downto 0);
      rRxLpmGCHold_in             : out std_logic_vector(4-1 downto 0);
      rRxLpmGCOvrdEn_in           : out std_logic_vector(4-1 downto 0);
      rRxLpmHFHold_in             : out std_logic_vector(4-1 downto 0);
      rRxLpmHFOvrdEn_in           : out std_logic_vector(4-1 downto 0);
      rRxLpmLFHold_in             : out std_logic_vector(4-1 downto 0);
      rRxLpmLFOvrdEn_in           : out std_logic_vector(4-1 downto 0);
      DmonClk                     : in  std_logic_vector(4-1 downto 0);
      dDMonitorOut_out            : in  GTYE4DMonitorOutAry_t(4-1 downto 0);
      rRxRate_in                  : out GTRateSelAry_t(4-1 downto 0);
      rRxRateDone_out             : in  std_logic_vector(4-1 downto 0);
      tTxRate_in                  : out GTRateSelAry_t(4-1 downto 0);
      tTxRateDone_out             : in  std_logic_vector(4-1 downto 0);
      tTxDiffCtrl_in              : out GTYDiffCtrlAry_t(4-1 downto 0);
      aTxPreCursor_in             : out GTYCursorSelAry_t(4-1 downto 0);
      aTxPostCursor_in            : out GTYCursorSelAry_t(4-1 downto 0);
      rRxPrbsSel_in               : out GTPrbsSelAry_t(4-1 downto 0);
      rRxPrbsErr_out              : in  std_logic_vector(4-1 downto 0);
      rRxPrbsLocked_out           : in  std_logic_vector(4-1 downto 0);
      rRxPrbsCntReset_in          : out std_logic_vector(4-1 downto 0);
      rRxPolarity_in              : out std_logic_vector(4-1 downto 0);
      tTxPrbsSel_in               : out GTPrbsSelAry_t(4-1 downto 0);
      tTxPrbsForceErr_in          : out std_logic_vector(4-1 downto 0);
      tTxPolarity_in              : out std_logic_vector(4-1 downto 0);
      tTxDetectRx_in              : out std_logic_vector(4-1 downto 0);
      rPhyStatus_out              : in  std_logic_vector(4-1 downto 0);
      rRxStatus_out               : in  GTRxStatusAry_t(4-1 downto 0);
      tTxPd_in                    : out GTPdAry_t(4-1 downto 0);
      rRxPd_in                    : out GTPdAry_t(4-1 downto 0);
      aLoopback_in                : out GTLoopbackSelAry_t(4-1 downto 0));
  end component;

  --vhook_d aurora64b66b_framing_crcx4_[lineRateStr]GHz
  component aurora64b66b_framing_crcx4_[lineRateStr]GHz
    port (
      s_axi_tx_tdata              : in  STD_LOGIC_VECTOR(255 downto 0);
      s_axi_tx_tlast              : in  STD_LOGIC;
      s_axi_tx_tkeep              : in  STD_LOGIC_VECTOR(31 downto 0);
      s_axi_tx_tvalid             : in  STD_LOGIC;
      s_axi_tx_tready             : out STD_LOGIC;
      m_axi_rx_tdata              : out STD_LOGIC_VECTOR(255 downto 0);
      m_axi_rx_tlast              : out STD_LOGIC;
      m_axi_rx_tkeep              : out STD_LOGIC_VECTOR(31 downto 0);
      m_axi_rx_tvalid             : out STD_LOGIC;
      s_axi_nfc_tvalid            : in  STD_LOGIC;
      s_axi_nfc_tdata             : in  STD_LOGIC_VECTOR(15 downto 0);
      s_axi_nfc_tready            : out STD_LOGIC;
      rxp                         : in  STD_LOGIC_VECTOR(0 to 3);
      rxn                         : in  STD_LOGIC_VECTOR(0 to 3);
      txp                         : out STD_LOGIC_VECTOR(0 to 3);
      txn                         : out STD_LOGIC_VECTOR(0 to 3);
      refclk1_in                  : in  STD_LOGIC;
      hard_err                    : out STD_LOGIC;
      soft_err                    : out STD_LOGIC;
      channel_up                  : out STD_LOGIC;
      lane_up                     : out STD_LOGIC_VECTOR(0 to 3);
      crc_pass_fail_n             : out STD_LOGIC;
      crc_valid                   : out STD_LOGIC;
      user_clk_out                : out STD_LOGIC;
      mmcm_not_locked_out         : out STD_LOGIC;
      sync_clk_out                : out STD_LOGIC;
      reset_pb                    : in  STD_LOGIC;
      gt_rxcdrovrden_in           : in  STD_LOGIC;
      power_down                  : in  STD_LOGIC;
      loopback                    : in  STD_LOGIC_VECTOR(2 downto 0);
      pma_init                    : in  STD_LOGIC;
      gt_pll_lock                 : out STD_LOGIC;
      gt0_drpaddr                 : in  STD_LOGIC_VECTOR(9 downto 0);
      gt0_drpdi                   : in  STD_LOGIC_VECTOR(15 downto 0);
      gt0_drpdo                   : out STD_LOGIC_VECTOR(15 downto 0);
      gt0_drprdy                  : out STD_LOGIC;
      gt0_drpen                   : in  STD_LOGIC;
      gt0_drpwe                   : in  STD_LOGIC;
      gt1_drpaddr                 : in  STD_LOGIC_VECTOR(9 downto 0);
      gt1_drpdi                   : in  STD_LOGIC_VECTOR(15 downto 0);
      gt1_drpdo                   : out STD_LOGIC_VECTOR(15 downto 0);
      gt1_drprdy                  : out STD_LOGIC;
      gt1_drpen                   : in  STD_LOGIC;
      gt1_drpwe                   : in  STD_LOGIC;
      gt2_drpaddr                 : in  STD_LOGIC_VECTOR(9 downto 0);
      gt2_drpdi                   : in  STD_LOGIC_VECTOR(15 downto 0);
      gt2_drpdo                   : out STD_LOGIC_VECTOR(15 downto 0);
      gt2_drprdy                  : out STD_LOGIC;
      gt2_drpen                   : in  STD_LOGIC;
      gt2_drpwe                   : in  STD_LOGIC;
      gt3_drpaddr                 : in  STD_LOGIC_VECTOR(9 downto 0);
      gt3_drpdi                   : in  STD_LOGIC_VECTOR(15 downto 0);
      gt3_drpdo                   : out STD_LOGIC_VECTOR(15 downto 0);
      gt3_drprdy                  : out STD_LOGIC;
      gt3_drpen                   : in  STD_LOGIC;
      gt3_drpwe                   : in  STD_LOGIC;
      init_clk                    : in  STD_LOGIC;
      link_reset_out              : out STD_LOGIC;
      gt_rxusrclk_out             : out STD_LOGIC;
      gt_eyescandataerror         : out STD_LOGIC_VECTOR(3 downto 0);
      gt_eyescanreset             : in  STD_LOGIC_VECTOR(3 downto 0);
      gt_eyescantrigger           : in  STD_LOGIC_VECTOR(3 downto 0);
      gt_rxcdrhold                : in  STD_LOGIC_VECTOR(3 downto 0);
      gt_rxdfelpmreset            : in  STD_LOGIC_VECTOR(3 downto 0);
      gt_rxlpmen                  : in  STD_LOGIC_VECTOR(3 downto 0);
      gt_rxpmareset               : in  STD_LOGIC_VECTOR(3 downto 0);
      gt_rxpcsreset               : in  STD_LOGIC_VECTOR(3 downto 0);
      gt_rxrate                   : in  STD_LOGIC_VECTOR(11 downto 0);
      gt_rxbufreset               : in  STD_LOGIC_VECTOR(3 downto 0);
      gt_rxpmaresetdone           : out STD_LOGIC_VECTOR(3 downto 0);
      gt_rxprbssel                : in  STD_LOGIC_VECTOR(15 downto 0);
      gt_rxprbserr                : out STD_LOGIC_VECTOR(3 downto 0);
      gt_rxprbscntreset           : in  STD_LOGIC_VECTOR(3 downto 0);
      gt_rxresetdone              : out STD_LOGIC_VECTOR(3 downto 0);
      gt_rxbufstatus              : out STD_LOGIC_VECTOR(11 downto 0);
      gt_txpostcursor             : in  STD_LOGIC_VECTOR(19 downto 0);
      gt_txdiffctrl               : in  STD_LOGIC_VECTOR(19 downto 0);
      gt_txprecursor              : in  STD_LOGIC_VECTOR(19 downto 0);
      gt_txpolarity               : in  STD_LOGIC_VECTOR(3 downto 0);
      gt_txinhibit                : in  STD_LOGIC_VECTOR(3 downto 0);
      gt_txpmareset               : in  STD_LOGIC_VECTOR(3 downto 0);
      gt_txpcsreset               : in  STD_LOGIC_VECTOR(3 downto 0);
      gt_txprbssel                : in  STD_LOGIC_VECTOR(15 downto 0);
      gt_txprbsforceerr           : in  STD_LOGIC_VECTOR(3 downto 0);
      gt_txbufstatus              : out STD_LOGIC_VECTOR(7 downto 0);
      gt_txresetdone              : out STD_LOGIC_VECTOR(3 downto 0);
      gt_pcsrsvdin                : in  STD_LOGIC_VECTOR(63 downto 0);
      gt_dmonitorout              : out STD_LOGIC_VECTOR(63 downto 0);
      gt_cplllock                 : out STD_LOGIC_VECTOR(3 downto 0);
      gt_qplllock                 : out STD_LOGIC;
      gt_powergood                : out STD_LOGIC_VECTOR(3 downto 0);
      gt_qpllclk_quad1_out        : out STD_LOGIC;
      gt_qpllrefclk_quad1_out     : out STD_LOGIC;
      gt_qplllock_quad1_out       : out STD_LOGIC;
      gt_qpllrefclklost_quad1_out : out STD_LOGIC;
      sys_reset_out               : out STD_LOGIC;
      gt_reset_out                : out STD_LOGIC;
      tx_out_clk                  : out STD_LOGIC);
  end component;

  --vhook_d SasquatchClipFixedLogic
  component SasquatchClipFixedLogic
    port (
      AxiClk                          : in  std_logic;
      aDiagramReset                   : in  std_logic;
      aLmkI2cSda                      : inout std_logic;
      aLmkI2cScl                      : inout std_logic;
      aLmk1Pdn_n                      : out std_logic;
      aLmk2Pdn_n                      : out std_logic;
      aLmk1Gpio0                      : out std_logic;
      aLmk2Gpio0                      : out std_logic;
      aLmk1Status0                    : in  std_logic;
      aLmk1Status1                    : in  std_logic;
      aLmk2Status0                    : in  std_logic;
      aLmk2Status1                    : in  std_logic;
      aIPassPrsnt_n                   : in  std_logic_vector(7 downto 0);
      aIPassIntr_n                    : in  std_logic_vector(7 downto 0);
      aIPassSCL                       : inout std_logic_vector(11 downto 0);
      aIPassSDA                       : inout std_logic_vector(11 downto 0);
      aPortExpReset_n                 : out std_logic;
      aPortExpIntr_n                  : in  std_logic;
      aPortExpSda                     : inout std_logic;
      aPortExpScl                     : inout std_logic;
      stIoModuleSupportsFRAGLs        : out std_logic;
      xIoModuleReady                  : out std_logic;
      xIoModuleErrorCode              : out std_logic_vector(31 downto 0);
      xMgtRefClkEnabled               : out std_logic_vector(11 downto 0);
      aDioOutEn                       : out std_logic_vector(7 downto 0);
      xHostAxiStreamToClipTData       : in  std_logic_vector(31 downto 0);
      xHostAxiStreamToClipTLast       : in  std_logic;
      xHostAxiStreamFromClipTReady    : out std_logic;
      xHostAxiStreamToClipTValid      : in  std_logic;
      xHostAxiStreamFromClipTData     : out std_logic_vector(31 downto 0);
      xHostAxiStreamFromClipTLast     : out std_logic;
      xHostAxiStreamToClipTReady      : in  std_logic;
      xHostAxiStreamFromClipTValid    : out std_logic;
      xDiagramAxiStreamToClipTData    : in  std_logic_vector(31 downto 0);
      xDiagramAxiStreamToClipTLast    : in  std_logic;
      xDiagramAxiStreamFromClipTReady : out std_logic;
      xDiagramAxiStreamToClipTValid   : in  std_logic;
      xDiagramAxiStreamFromClipTData  : out std_logic_vector(31 downto 0);
      xDiagramAxiStreamFromClipTLast  : out std_logic;
      xDiagramAxiStreamToClipTReady   : in  std_logic;
      xDiagramAxiStreamFromClipTValid : out std_logic;
      xClipAxi4LiteMasterARAddr       : out std_logic_vector(31 downto 0);
      xClipAxi4LiteMasterARProt       : out std_logic_vector(2 downto 0);
      xClipAxi4LiteMasterARReady      : in  std_logic;
      xClipAxi4LiteMasterARValid      : out std_logic;
      xClipAxi4LiteMasterAWAddr       : out std_logic_vector(31 downto 0);
      xClipAxi4LiteMasterAWProt       : out std_logic_vector(2 downto 0);
      xClipAxi4LiteMasterAWReady      : in  std_logic;
      xClipAxi4LiteMasterAWValid      : out std_logic;
      xClipAxi4LiteMasterBReady       : out std_logic;
      xClipAxi4LiteMasterBResp        : in  std_logic_vector(1 downto 0);
      xClipAxi4LiteMasterBValid       : in  std_logic;
      xClipAxi4LiteMasterRData        : in  std_logic_vector(31 downto 0);
      xClipAxi4LiteMasterRReady       : out std_logic;
      xClipAxi4LiteMasterRResp        : in  std_logic_vector(1 downto 0);
      xClipAxi4LiteMasterRValid       : in  std_logic;
      xClipAxi4LiteMasterWData        : out std_logic_vector(31 downto 0);
      xClipAxi4LiteMasterWReady       : in  std_logic;
      xClipAxi4LiteMasterWStrb        : out std_logic_vector(3 downto 0);
      xClipAxi4LiteMasterWValid       : out std_logic);
  end component;

  --vhook_d AxiLiteToMgtDrp
  component AxiLiteToMgtDrp
    generic (
      kNumLanes : integer := 4;
      kAddrSize : integer := 10);
    port (
      aResetSl        : in  std_logic;
      SAxiAClk        : in  std_logic;
      sAxiAWaddr      : in  std_logic_vector(31 downto 0);
      sAxiAWValid     : in  std_logic;
      sAxiAWReady     : out std_logic;
      sAxiWData       : in  std_logic_vector(31 downto 0);
      sAxiWStrb       : in  std_logic_vector(3 downto 0);
      sAxiWValid      : in  std_logic;
      sAxiWReady      : out std_logic;
      sAxiBResp       : out std_logic_vector(1 downto 0);
      sAxiBValid      : out std_logic;
      sAxiBReady      : in  std_logic;
      sAxiARAddr      : in  std_logic_vector(31 downto 0);
      sAxiARValid     : in  std_logic;
      sAxiARReady     : out std_logic;
      sAxiRData       : out std_logic_vector(31 downto 0);
      sAxiRResp       : out std_logic_vector(1 downto 0);
      sAxiRValid      : out std_logic;
      sAxiRReady      : in  std_logic;
      InitClk         : in  std_logic;
      iGtwizDrpClk    : out std_logic_vector(kNumLanes-1 downto 0);
      iGtwizDrpAddrIn : out std_logic_vector(kNumLanes*kAddrSize-1 downto 0);
      iGtwizDrpDiIn   : out std_logic_vector(kNumLanes*16-1 downto 0);
      iGtwizDrpDoOut  : in  std_logic_vector(kNumLanes*16-1 downto 0);
      iGtwizDrpEnIn   : out std_logic_vector(kNumLanes-1 downto 0);
      iGtwizDrpWeIn   : out std_logic_vector(kNumLanes-1 downto 0);
      iGtwizDrpRdyOut : in  std_logic_vector(kNumLanes-1 downto 0));
  end component;

  --vhook_d AxiFramingRegx4
  component AxiFramingRegx4
    port (
      aclk : in std_logic;
      aresetn : in std_logic;
      s_axis_tvalid : in std_logic;
      s_axis_tready : out std_logic;
      s_axis_tdata : in std_logic_vector(255 downto 0);
      s_axis_tkeep : in std_logic_vector(31 downto 0);
      s_axis_tlast : in std_logic;
      m_axis_tvalid : out std_logic;
      m_axis_tready : in std_logic;
      m_axis_tdata : out std_logic_vector(255 downto 0);
      m_axis_tkeep : out std_logic_vector(31 downto 0);
      m_axis_tlast : out std_logic
    );
  end component;

  -------------------------------------------------------------
  -- CLIP signals                                            --
  -------------------------------------------------------------
  signal MgtRefClk            : std_logic_vector(11 downto 0);
  signal xMgtRefClkEnabled    : std_logic_vector(11 downto 0);
  signal aReset_n             : std_logic;

  -------------------------------------------------------------
  -- Vectorized signals to connect to GT Wizard Verilog core --
  -------------------------------------------------------------
  signal iGtwizDrpAddrIn      : std_logic_vector(kNumPorts*kNumLanes*kAddrSize-1 downto 0);
  signal iGtwizDrpDiIn        : std_logic_vector(kNumPorts*kNumLanes*16-1 downto 0);
  signal iGtwizDrpDoOut       : std_logic_vector(kNumPorts*kNumLanes*16-1 downto 0);
  signal iGtwizDrpRdyOut      : std_logic_vector(kNumPorts*kNumLanes-1 downto 0);
  signal iGtwizDrpEnIn        : std_logic_vector(kNumPorts*kNumLanes-1 downto 0);
  signal iGtwizDrpWeIn        : std_logic_vector(kNumPorts*kNumLanes-1 downto 0);

  signal aGtwizDMonitorOut    : std_logic_vector(kNumPorts*kNumLanes*17-1 downto 0);
  signal rGtwizRxRateIn       : std_logic_vector(kNumPorts*kNumLanes*3-1  downto 0);

  signal tGtwizTxDiffCtrlIn   : std_logic_vector(kNumPorts*kNumLanes*5-1  downto 0);
  signal aGtwizTxPreCursorIn  : std_logic_vector(kNumPorts*kNumLanes*5-1  downto 0);
  signal aGtwizTxPostCursorIn : std_logic_vector(kNumPorts*kNumLanes*5-1  downto 0);
  signal rGtwizRxPrbsSelIn    : std_logic_vector(kNumPorts*kNumLanes*4-1  downto 0);
  signal tGtwizTxPrbsSelIn    : std_logic_vector(kNumPorts*kNumLanes*4-1  downto 0);

  -------------------------------------------------------------
  -- Signals to connect to AXI4-Lite Register Set            --
  -------------------------------------------------------------
  type Axi4LiteReadPortInAry_t   is array(natural range <>) of Axi4LiteReadPortIn_t;
  type Axi4LiteWritePortInAry_t  is array(natural range <>) of Axi4LiteWritePortIn_t;
  type Axi4LiteReadPortOutAry_t  is array(natural range <>) of Axi4LiteReadPortOut_t;
  type Axi4LiteWritePortOutAry_t is array(natural range <>) of Axi4LiteWritePortOut_t;
  signal sAxiMasterReadPort   : Axi4LiteReadPortInAry_t  (kNumPorts-1 downto 0);
  signal sAxiMasterWritePort  : Axi4LiteWritePortInAry_t (kNumPorts-1 downto 0);
  signal sAxiSlaveReadPort    : Axi4LiteReadPortOutAry_t (kNumPorts-1 downto 0);
  signal sAxiSlaveWritePort   : Axi4LiteWritePortOutAry_t(kNumPorts-1 downto 0);

  signal RxUsrClk2, TxUsrClk2 : std_logic_vector(kNumPorts*kNumLanes-1 downto 0);

  signal rRxResetDoneOut      : std_logic_vector(kNumPorts*kNumLanes-1 downto 0);
  signal aRxPmaResetIn        : std_logic_vector(kNumPorts*kNumLanes-1 downto 0);
  signal aGtRxPmaResetDone    : std_logic_vector(kNumPorts*kNumLanes-1 downto 0);
  signal tTxResetDoneOut      : std_logic_vector(kNumPorts*kNumLanes-1 downto 0);
  signal aTxPmaResetIn        : std_logic_vector(kNumPorts*kNumLanes-1 downto 0);

  signal aTxPcsResetIn        : std_logic_vector(kNumPorts*kNumLanes-1 downto 0);
  signal aEyeScanResetIn      : std_logic_vector(kNumPorts*kNumLanes-1 downto 0);
  signal aGtPowerGoodOut      : std_logic_vector(kNumPorts*kNumLanes-1 downto 0);

  signal aCpllLockOut         : std_logic_vector(kNumPorts*kNumLanes-1 downto 0);

  signal aQpll0LockOut        : std_logic_vector(kNumPorts-1 downto 0);
  signal aQpll0RefClkLostOut  : std_logic_vector(kNumPorts-1 downto 0);

  signal aRxCdrHoldIn         : std_logic_vector(kNumPorts*kNumLanes-1 downto 0);
  signal aRxCdrOvrdEnIn       : std_logic_vector(kNumPorts*kNumLanes-1 downto 0);

  signal rRxLpmEnIn           : std_logic_vector(kNumPorts*kNumLanes-1 downto 0);

  signal SGtwizSlvDmonclk     : std_logic_vector(kNumPorts*kNumLanes-1 downto 0);
  signal aDMonitorOut         : GTYE4DMonitorOutAry_t(kNumPorts*kNumLanes-1 downto 0);

  signal rRxRateIn            : GTRateSelAry_t  (kNumPorts*kNumLanes-1 downto 0);

  signal tTxDiffCtrlIn        : GTYDiffCtrlAry_t (kNumPorts*kNumLanes-1 downto 0);
  signal aTxPreCursorIn       : GTYCursorSelAry_t(kNumPorts*kNumLanes-1 downto 0);
  signal aTxPostCursorIn      : GTYCursorSelAry_t(kNumPorts*kNumLanes-1 downto 0);

  signal rRxPrbsSelIn         : GTPrbsSelAry_t  (kNumPorts*kNumLanes-1 downto 0);
  signal rRxPrbsErrOut        : std_logic_vector(kNumPorts*kNumLanes-1 downto 0);
  signal rRxPrbsCntResetIn    : std_logic_vector(kNumPorts*kNumLanes-1 downto 0);
  signal tTxPrbsSelIn         : GTPrbsSelAry_t  (kNumPorts*kNumLanes-1 downto 0);
  signal tTxPrbsForceErrIn    : std_logic_vector(kNumPorts*kNumLanes-1 downto 0);
  signal tTxPolarityIn        : std_logic_vector(kNumPorts*kNumLanes-1 downto 0);

  signal aLoopbackIn          : GTLoopbackSelAry_t(kNumPorts*kNumLanes-1 downto 0);

  -------------------------------------------------------------
  -- Vectorized signals to connect to Aurora core            --
  -------------------------------------------------------------
  signal PortRx_p : std_logic_vector(0 to [NumLane-1]);
  signal PortRx_n : std_logic_vector(0 to [NumLane-1]);
  signal PortTx_p : std_logic_vector(0 to [NumLane-1]);
  signal PortTx_n : std_logic_vector(0 to [NumLane-1]);

  -- SLVs for the single lane port signals on the cores.
  signal uPortHardErr, uPortSoftErr, uPortChannelUp : std_logic_vector(kNumPorts-1 downto 0);
  signal uPortCrcPassFail_n, uPortCrcValid, uPortAxiNfcTValid, uPortAxiNfcTReady : std_logic_vector(kNumPorts-1 downto 0);

  subtype AuroraLaneUp_t is std_logic_vector(kNumLanes-1 downto 0);
  type AuroraLaneUpAry_t is array(natural range <>) of AuroraLaneUp_t;
  signal uPortLaneUp, uPortLaneUpRev : AuroraLaneUpAry_t(kNumPorts-1 downto 0);

  subtype AxiData2_t is std_logic_vector(1 downto 0);
  type AxiData2Ary_t is array(natural range <>) of AxiData2_t;
  signal sGtwizDrpChAxiBResp  : AxiData2Ary_t(kNumPorts-1 downto 0);
  signal sGtwizDrpChAxiRResp  : AxiData2Ary_t(kNumPorts-1 downto 0);

  subtype AxiData4_t is std_logic_vector(3 downto 0);
  type AxiData4Ary_t is array(natural range <>) of AxiData4_t;
  signal sGtwizDrpChAxiWStrb  : AxiData4Ary_t(kNumPorts-1 downto 0);

  subtype AxiData32_t is std_logic_vector(31 downto 0);
  type AxiData32Ary_t is array(natural range <>) of AxiData32_t;
  signal uPortAxiNfcTData : AxiData32Ary_t(kNumPorts-1 downto 0);
  signal sGtwizDrpChAxiAWAddr : AxiData32Ary_t(kNumPorts-1 downto 0);
  signal sGtwizDrpChAxiWData  : AxiData32Ary_t(kNumPorts-1 downto 0);
  signal sGtwizDrpChAxiARAddr : AxiData32Ary_t(kNumPorts-1 downto 0);
  signal sGtwizDrpChAxiRData  : AxiData32Ary_t(kNumPorts-1 downto 0);

  subtype AxiData64_t is std_logic_vector(63 downto 0);
  type AxiData64Ary_t is array(natural range <>) of AxiData64_t;
  signal uPortAxiTxTData0, uPortAxiTxTData1, uPortAxiTxTData2, uPortAxiTxTData3 : AxiData64Ary_t(kNumPorts-1 downto 0);
  signal uPortAxiRxTData0, uPortAxiRxTData1, uPortAxiRxTData2, uPortAxiRxTData3 : AxiData64Ary_t(kNumPorts-1 downto 0);

  subtype AxiData256_t is std_logic_vector(255 downto 0);
  type AxiData256Ary_t is array(natural range <>) of AxiData256_t;
  signal uPortAxiTxTData : AxiData256Ary_t(kNumPorts-1 downto 0);
  signal uPortAxiRegTxTData : AxiData256Ary_t(kNumPorts-1 downto 0);
  signal uPortAxiRxTData : AxiData256Ary_t(kNumPorts-1 downto 0);

  subtype AxiKeep_t is std_logic_vector(31 downto 0);
  type AxiKeepAry_t is array(natural range <>) of AxiKeep_t;
  signal uPortAxiTxTKeep, uPortAxiRxTKeep : AxiKeepAry_t(kNumPorts-1 downto 0);
  signal uPortAxiRegTxTKeep : AxiKeepAry_t(kNumPorts-1 downto 0);

  signal sGtwizDrpChAxiAWValid : std_logic_vector(kNumPorts-1 downto 0);
  signal sGtwizDrpChAxiAWReady : std_logic_vector(kNumPorts-1 downto 0);
  signal sGtwizDrpChAxiWValid  : std_logic_vector(kNumPorts-1 downto 0);
  signal sGtwizDrpChAxiWReady  : std_logic_vector(kNumPorts-1 downto 0);
  signal sGtwizDrpChAxiBValid  : std_logic_vector(kNumPorts-1 downto 0);
  signal sGtwizDrpChAxiBReady  : std_logic_vector(kNumPorts-1 downto 0);
  signal sGtwizDrpChAxiARValid : std_logic_vector(kNumPorts-1 downto 0);
  signal sGtwizDrpChAxiARReady : std_logic_vector(kNumPorts-1 downto 0);
  signal sGtwizDrpChAxiRValid  : std_logic_vector(kNumPorts-1 downto 0);
  signal sGtwizDrpChAxiRReady  : std_logic_vector(kNumPorts-1 downto 0);

  signal uPortAxiTxTLast, uPortAxiTxTValid, uPortAxiTxTReady : std_logic_vector(kNumPorts-1 downto 0);
  signal uPortAxiRegTxTLast, uPortAxiRegTxTValid, uPortAxiRegTxTReady : std_logic_vector(kNumPorts-1 downto 0);
  signal uPortAxiRxTLast, uPortAxiRxTValid : std_logic_vector(kNumPorts-1 downto 0);

  signal UserClkPort, RxUserClk2Port, SyncClkPort, aPortResetPb : std_logic_vector(kNumPorts-1 downto 0);
  signal uPortMmcmNotLocked, uPortSysResetOut, iPortLinkResetOut, aPortPmaInit : std_logic_vector(kNumPorts-1 downto 0);


  -------------------------------------------------------------
  -- Utility Functions                                       --
  -------------------------------------------------------------
  function to_StdLogic(b : boolean) return std_logic is
  begin
    if b then
      return '1';
    else
      return '0';
    end if;
  end to_StdLogic;

  function reversi (arg : std_logic_vector) return std_logic_vector is
    variable RetVal : std_logic_vector(arg'reverse_range) := (others => '0');
  begin  -- reversi
    for index in arg'range loop
      RetVal(index) := arg(index);
    end loop;  -- index
    return RetVal;
  end reversi;

begin

  ---------------------------------------------------------------------------------------
  -- 7903 Required Logic
  ---------------------------------------------------------------------------------------
  -- !!! WARNING !!!
  -- Do not change this logic. Doing so may cause the CLIP to stop functioning.

  -- Configuration Netlist --
  --vhook SasquatchClipFixedLogic
  --vhook_a aDiagramReset  aResetSl
  SasquatchClipFixedLogicx: SasquatchClipFixedLogic
    port map (
      AxiClk                          => AxiClk,                           --in  std_logic
      aDiagramReset                   => aResetSl,                         --in  std_logic
      aLmkI2cSda                      => aLmkI2cSda,                       --inout std_logic
      aLmkI2cScl                      => aLmkI2cScl,                       --inout std_logic
      aLmk1Pdn_n                      => aLmk1Pdn_n,                       --out std_logic
      aLmk2Pdn_n                      => aLmk2Pdn_n,                       --out std_logic
      aLmk1Gpio0                      => aLmk1Gpio0,                       --out std_logic
      aLmk2Gpio0                      => aLmk2Gpio0,                       --out std_logic
      aLmk1Status0                    => aLmk1Status0,                     --in  std_logic
      aLmk1Status1                    => aLmk1Status1,                     --in  std_logic
      aLmk2Status0                    => aLmk2Status0,                     --in  std_logic
      aLmk2Status1                    => aLmk2Status1,                     --in  std_logic
      aIPassPrsnt_n                   => aIPassPrsnt_n,                    --in  std_logic_vector(7:0)
      aIPassIntr_n                    => aIPassIntr_n,                     --in  std_logic_vector(7:0)
      aIPassSCL                       => aIPassSCL,                        --inout std_logic_vector(11:0)
      aIPassSDA                       => aIPassSDA,                        --inout std_logic_vector(11:0)
      aPortExpReset_n                 => aPortExpReset_n,                  --out std_logic
      aPortExpIntr_n                  => aPortExpIntr_n,                   --in  std_logic
      aPortExpSda                     => aPortExpSda,                      --inout std_logic
      aPortExpScl                     => aPortExpScl,                      --inout std_logic
      stIoModuleSupportsFRAGLs        => stIoModuleSupportsFRAGLs,         --out std_logic
      xIoModuleReady                  => xIoModuleReady,                   --out std_logic
      xIoModuleErrorCode              => xIoModuleErrorCode,               --out std_logic_vector(31:0)
      xMgtRefClkEnabled               => xMgtRefClkEnabled,                --out std_logic_vector(11:0)
      aDioOutEn                       => aDioOutEn,                        --out std_logic_vector(7:0)
      xHostAxiStreamToClipTData       => xHostAxiStreamToClipTData,        --in  std_logic_vector(31:0)
      xHostAxiStreamToClipTLast       => xHostAxiStreamToClipTLast,        --in  std_logic
      xHostAxiStreamFromClipTReady    => xHostAxiStreamFromClipTReady,     --out std_logic
      xHostAxiStreamToClipTValid      => xHostAxiStreamToClipTValid,       --in  std_logic
      xHostAxiStreamFromClipTData     => xHostAxiStreamFromClipTData,      --out std_logic_vector(31:0)
      xHostAxiStreamFromClipTLast     => xHostAxiStreamFromClipTLast,      --out std_logic
      xHostAxiStreamToClipTReady      => xHostAxiStreamToClipTReady,       --in  std_logic
      xHostAxiStreamFromClipTValid    => xHostAxiStreamFromClipTValid,     --out std_logic
      xDiagramAxiStreamToClipTData    => xDiagramAxiStreamToClipTData,     --in  std_logic_vector(31:0)
      xDiagramAxiStreamToClipTLast    => xDiagramAxiStreamToClipTLast,     --in  std_logic
      xDiagramAxiStreamFromClipTReady => xDiagramAxiStreamFromClipTReady,  --out std_logic
      xDiagramAxiStreamToClipTValid   => xDiagramAxiStreamToClipTValid,    --in  std_logic
      xDiagramAxiStreamFromClipTData  => xDiagramAxiStreamFromClipTData,   --out std_logic_vector(31:0)
      xDiagramAxiStreamFromClipTLast  => xDiagramAxiStreamFromClipTLast,   --out std_logic
      xDiagramAxiStreamToClipTReady   => xDiagramAxiStreamToClipTReady,    --in  std_logic
      xDiagramAxiStreamFromClipTValid => xDiagramAxiStreamFromClipTValid,  --out std_logic
      xClipAxi4LiteMasterARAddr       => xClipAxi4LiteMasterARAddr,        --out std_logic_vector(31:0)
      xClipAxi4LiteMasterARProt       => xClipAxi4LiteMasterARProt,        --out std_logic_vector(2:0)
      xClipAxi4LiteMasterARReady      => xClipAxi4LiteMasterARReady,       --in  std_logic
      xClipAxi4LiteMasterARValid      => xClipAxi4LiteMasterARValid,       --out std_logic
      xClipAxi4LiteMasterAWAddr       => xClipAxi4LiteMasterAWAddr,        --out std_logic_vector(31:0)
      xClipAxi4LiteMasterAWProt       => xClipAxi4LiteMasterAWProt,        --out std_logic_vector(2:0)
      xClipAxi4LiteMasterAWReady      => xClipAxi4LiteMasterAWReady,       --in  std_logic
      xClipAxi4LiteMasterAWValid      => xClipAxi4LiteMasterAWValid,       --out std_logic
      xClipAxi4LiteMasterBReady       => xClipAxi4LiteMasterBReady,        --out std_logic
      xClipAxi4LiteMasterBResp        => xClipAxi4LiteMasterBResp,         --in  std_logic_vector(1:0)
      xClipAxi4LiteMasterBValid       => xClipAxi4LiteMasterBValid,        --in  std_logic
      xClipAxi4LiteMasterRData        => xClipAxi4LiteMasterRData,         --in  std_logic_vector(31:0)
      xClipAxi4LiteMasterRReady       => xClipAxi4LiteMasterRReady,        --out std_logic
      xClipAxi4LiteMasterRResp        => xClipAxi4LiteMasterRResp,         --in  std_logic_vector(1:0)
      xClipAxi4LiteMasterRValid       => xClipAxi4LiteMasterRValid,        --in  std_logic
      xClipAxi4LiteMasterWData        => xClipAxi4LiteMasterWData,         --out std_logic_vector(31:0)
      xClipAxi4LiteMasterWReady       => xClipAxi4LiteMasterWReady,        --in  std_logic
      xClipAxi4LiteMasterWStrb        => xClipAxi4LiteMasterWStrb,         --out std_logic_vector(3:0)
      xClipAxi4LiteMasterWValid       => xClipAxi4LiteMasterWValid);       --out std_logic

  -- Drive active low reset.
  aReset_n <= not aResetSl;

  GenDioBuffers: for i in aDio'range generate
    aDio(i) <= aDioOut(i) when aDioOutEn(i) = '1' else 'Z';
  end generate GenDioBuffers;
  aDioIn <= aDio;

  ---------------------------------------------------------------------------------------
  -- MGT Reference Clocks
  ---------------------------------------------------------------------------------------
  -- Instantiate IBUFDS_GTE4 buffers on the reference clock pins.
  -- Depending on the application, the IP may already instantiate a buffer, so
  -- these buffers may be removed in this case.

  IbufdsGen: for i in MgtRefClk_p'range generate

    --vhook_i IBUFDS_GTE4 IBUFDS_GTE4_inst hidegeneric=true
    --vhook_a I      MgtRefClk_p(i)
    --vhook_a IB     MgtRefClk_n(i)
    --vhook_a CEB    '0'
    --vhook_a O      MgtRefClk(i)
    --vhook_a ODIV2  open
    IBUFDS_GTE4_inst: IBUFDS_GTE4
      port map (
        O     => MgtRefClk(i),    --out std_ulogic
        ODIV2 => open,            --out std_ulogic
        CEB   => '0',             --in  std_ulogic
        I     => MgtRefClk_p(i),  --in  std_ulogic
        IB    => MgtRefClk_n(i)); --in  std_ulogic

  end generate;

  ---------------------------------------------------------------------------------------
  -- Aurora Core
  ---------------------------------------------------------------------------------------
  ---------------------------------------------------------
  -- Sample Status Signals
  ---------------------------------------------------------
  [StartDuplicatePort]
  -- Sample Port[PortNum] Status Signals
  process(aResetSl, UserClkPort([PortNum]))
  begin
    if aResetSl = '1' then
      uPort[PortNum]HardError      <= '0';
      uPort[PortNum]SoftError      <= '0';
      uPort[PortNum]ChannelUp      <= '0';
      uPort[PortNum]SysResetOut    <= '1';
      uPort[PortNum]MmcmNotLockOut <= '1';
      uPort[PortNum]LaneUp         <= (others => '0');
    elsif rising_edge(UserClkPort([PortNum])) then
      uPort[PortNum]HardError      <= uPortHardErr    ([PortNum]);
      uPort[PortNum]SoftError      <= uPortSoftErr    ([PortNum]);
      uPort[PortNum]ChannelUp      <= uPortChannelUp  ([PortNum]);
      uPort[PortNum]SysResetOut    <= uPortSysResetOut([PortNum]);
      uPort[PortNum]MmcmNotLockOut <= uPortMmcmNotLocked([PortNum]);
      uPort[PortNum]LaneUp         <= uPortLaneUp([PortNum]);
    end if;
  end process;

  [EndDuplicatePort]

  ---------------------------------------------------------
  -- Linke Reset Out
  ---------------------------------------------------------
  process(aResetSl, InitClk)
  begin
    if aResetSl = '1' then
      [StartDuplicatePort]
      iPort[PortNum]LinkResetOut <= '1';
      [EndDuplicatePort]
    elsif rising_edge(InitClk) then
      [StartDuplicatePort]
      iPort[PortNum]LinkResetOut <= iPortLinkResetOut ([PortNum]);
      [EndDuplicatePort]
    end if;
  end process;

  ---------------------------------------------------------
  -- Aurora AXI4-Lite to Channel DRP Interface
  ---------------------------------------------------------
  AxiToDrpBlock : block
  begin

    [StartDuplicatePort]
    -- Connect Port[PortNum] AXI-Lite
    sGtwizDrpChAxiAWaddr([PortNum]) <= sGtwiz[PortNum]DrpChAxiAWAddr;
    sGtwizDrpChAxiAWValid([PortNum]) <= sGtwiz[PortNum]DrpChAxiAWValid;
    sGtwiz[PortNum]DrpChAxiAWReady <= sGtwizDrpChAxiAWReady([PortNum]);
    sGtwizDrpChAxiWData([PortNum]) <= sGtwiz[PortNum]DrpChAxiWData;
    sGtwizDrpChAxiWStrb([PortNum]) <= sGtwiz[PortNum]DrpChAxiWStrb;
    sGtwizDrpChAxiWValid([PortNum]) <= sGtwiz[PortNum]DrpChAxiWValid;
    sGtwiz[PortNum]DrpChAxiWReady <= sGtwizDrpChAxiWReady([PortNum]);
    sGtwiz[PortNum]DrpChAxiBResp <= sGtwizDrpChAxiBResp([PortNum]);
    sGtwiz[PortNum]DrpChAxiBValid <= sGtwizDrpChAxiBValid([PortNum]);
    sGtwizDrpChAxiBReady([PortNum]) <= sGtwiz[PortNum]DrpChAxiBReady;
    sGtwizDrpChAxiARAddr([PortNum]) <= sGtwiz[PortNum]DrpChAxiARAddr;
    sGtwizDrpChAxiARValid([PortNum]) <= sGtwiz[PortNum]DrpChAxiARValid;
    sGtwiz[PortNum]DrpChAxiARReady <= sGtwizDrpChAxiARReady([PortNum]);
    sGtwiz[PortNum]DrpChAxiRData <= sGtwizDrpChAxiRData([PortNum]);
    sGtwiz[PortNum]DrpChAxiRResp <= sGtwizDrpChAxiRResp([PortNum]);
    sGtwiz[PortNum]DrpChAxiRValid <= sGtwizDrpChAxiRValid([PortNum]);
    sGtwizDrpChAxiRReady([PortNum]) <= sGtwiz[PortNum]DrpChAxiRReady;

    [EndDuplicatePort]


    GenAxiToDrp : for i in 0 to kNumPorts-1 generate
      --vhook AxiLiteToMgtDrp AxiLiteToMgtDrpPortN
      --vhook_a {sAxi(.*)} sGtwizDrpChAxi$1(i)
      --vhook_a {sAxi(.*)} sGtwizDrpChAxi$1(i)
      --vhook_a SAxiAClk SAClk
      --vhook_a iGtwizDrpClk     open
      --vhook_a iGtwizDrpAddrIn  iGtwizDrpAddrIn((i+1)*kNumLanes*kAddrSize-1 downto i*kNumLanes*kAddrSize)
      --vhook_a iGtwizDrpDiIn    iGtwizDrpDiIn  ((i+1)*kNumLanes*16-1 downto i*kNumLanes*16)
      --vhook_a iGtwizDrpDoOut   iGtwizDrpDoOut ((i+1)*kNumLanes*16-1 downto i*kNumLanes*16)
      --vhook_a iGtwizDrpEnIn    iGtwizDrpEnIn  ((i+1)*kNumLanes-1    downto i*kNumLanes)
      --vhook_a iGtwizDrpWeIn    iGtwizDrpWeIn  ((i+1)*kNumLanes-1    downto i*kNumLanes)
      --vhook_a iGtwizDrpRdyOut  iGtwizDrpRdyOut((i+1)*kNumLanes-1    downto i*kNumLanes)
      AxiLiteToMgtDrpPortN: AxiLiteToMgtDrp
        generic map (
          kNumLanes => kNumLanes,  --integer:=4
          kAddrSize => kAddrSize)  --integer:=10
        port map (
          aResetSl        => aResetSl,                                                                   --in  std_logic
          SAxiAClk        => SAClk,                                                                      --in  std_logic
          sAxiAWaddr      => sGtwizDrpChAxiAWaddr(i),                                                    --in  std_logic_vector(31:0)
          sAxiAWValid     => sGtwizDrpChAxiAWValid(i),                                                   --in  std_logic
          sAxiAWReady     => sGtwizDrpChAxiAWReady(i),                                                   --out std_logic
          sAxiWData       => sGtwizDrpChAxiWData(i),                                                     --in  std_logic_vector(31:0)
          sAxiWStrb       => sGtwizDrpChAxiWStrb(i),                                                     --in  std_logic_vector(3:0)
          sAxiWValid      => sGtwizDrpChAxiWValid(i),                                                    --in  std_logic
          sAxiWReady      => sGtwizDrpChAxiWReady(i),                                                    --out std_logic
          sAxiBResp       => sGtwizDrpChAxiBResp(i),                                                     --out std_logic_vector(1:0)
          sAxiBValid      => sGtwizDrpChAxiBValid(i),                                                    --out std_logic
          sAxiBReady      => sGtwizDrpChAxiBReady(i),                                                    --in  std_logic
          sAxiARAddr      => sGtwizDrpChAxiARAddr(i),                                                    --in  std_logic_vector(31:0)
          sAxiARValid     => sGtwizDrpChAxiARValid(i),                                                   --in  std_logic
          sAxiARReady     => sGtwizDrpChAxiARReady(i),                                                   --out std_logic
          sAxiRData       => sGtwizDrpChAxiRData(i),                                                     --out std_logic_vector(31:0)
          sAxiRResp       => sGtwizDrpChAxiRResp(i),                                                     --out std_logic_vector(1:0)
          sAxiRValid      => sGtwizDrpChAxiRValid(i),                                                    --out std_logic
          sAxiRReady      => sGtwizDrpChAxiRReady(i),                                                    --in  std_logic
          InitClk         => InitClk,                                                                    --in  std_logic
          iGtwizDrpClk    => open,                                                                       --out std_logic_vector(kNumLanes-1:0)
          iGtwizDrpAddrIn => iGtwizDrpAddrIn((i+1)*kNumLanes*kAddrSize-1 downto i*kNumLanes*kAddrSize),  --out std_logic_vector(kNumLanes*kAddrSize-1:0)
          iGtwizDrpDiIn   => iGtwizDrpDiIn ((i+1)*kNumLanes*16-1 downto i*kNumLanes*16),                 --out std_logic_vector(kNumLanes*16-1:0)
          iGtwizDrpDoOut  => iGtwizDrpDoOut ((i+1)*kNumLanes*16-1 downto i*kNumLanes*16),                --in  std_logic_vector(kNumLanes*16-1:0)
          iGtwizDrpEnIn   => iGtwizDrpEnIn ((i+1)*kNumLanes-1 downto i*kNumLanes),                       --out std_logic_vector(kNumLanes-1:0)
          iGtwizDrpWeIn   => iGtwizDrpWeIn ((i+1)*kNumLanes-1 downto i*kNumLanes),                       --out std_logic_vector(kNumLanes-1:0)
          iGtwizDrpRdyOut => iGtwizDrpRdyOut((i+1)*kNumLanes-1 downto i*kNumLanes));                     --in  std_logic_vector(kNumLanes-1:0)

    end generate;
  end block AxiToDrpBlock;

  ---------------------------------------------------------
  -- Aurora AXI4-Lite to Ctrl Register Interface
  ---------------------------------------------------------
  [StartDuplicatePort]
  -- Fill in AXI Port[PortNum] records with top level signals.
  sAxiMasterWritePort([PortNum]).Address   <= unsigned(sGtwiz[PortNum]CtrlAxiAWAddr);
  sAxiMasterWritePort([PortNum]).AddrValid <= sGtwiz[PortNum]CtrlAxiAWValid = '1';
  sAxiMasterWritePort([PortNum]).Data      <= sGtwiz[PortNum]CtrlAxiWData;
  sAxiMasterWritePort([PortNum]).DataStrb  <= sGtwiz[PortNum]CtrlAxiWStrb;
  sAxiMasterWritePort([PortNum]).DataValid <= sGtwiz[PortNum]CtrlAxiWValid = '1';
  sAxiMasterWritePort([PortNum]).Ready     <= sGtwiz[PortNum]CtrlAxiBReady = '1';

  sGtwiz[PortNum]CtrlAxiAWReady <= to_StdLogic(sAxiSlaveWritePort([PortNum]).AddrReady);
  sGtwiz[PortNum]CtrlAxiWReady  <= to_StdLogic(sAxiSlaveWritePort([PortNum]).DataReady);
  sGtwiz[PortNum]CtrlAxiBResp   <= sAxiSlaveWritePort([PortNum]).Response;
  sGtwiz[PortNum]CtrlAxiBValid  <= to_StdLogic(sAxiSlaveWritePort([PortNum]).RespValid);

  sAxiMasterReadPort([PortNum]).Address   <= unsigned(sGtwiz[PortNum]CtrlAxiARAddr);
  sAxiMasterReadPort([PortNum]).AddrValid <= sGtwiz[PortNum]CtrlAxiARValid = '1';
  sAxiMasterReadPort([PortNum]).Ready     <= sGtwiz[PortNum]CtrlAxiRReady = '1';

  sGtwiz[PortNum]CtrlAxiARReady <= to_StdLogic(sAxiSlaveReadPort([PortNum]).AddrReady);
  sGtwiz[PortNum]CtrlAxiRData   <= sAxiSlaveReadPort([PortNum]).Data;
  sGtwiz[PortNum]CtrlAxiRResp   <= sAxiSlaveReadPort([PortNum]).Response;
  sGtwiz[PortNum]CtrlAxiRValid  <= to_StdLogic(sAxiSlaveReadPort([PortNum]).DataValid);

  [EndDuplicatePort]

  ---------------------------------------------------------
  -- MGT Connection
  ---------------------------------------------------------
  -- Sasquatch lane 0/1 swapped of each port
  GenMgtRoute:
  for i in 0 to [NumPort]-1 generate
    PortRx_p   (4*i to 4*(i+1)-1)     <= reversi(MgtPortRx_p(4*(i+1)-1 downto 4*i));
    PortRx_n   (4*i to 4*(i+1)-1)     <= reversi(MgtPortRx_n(4*(i+1)-1 downto 4*i));
    MgtPortTx_p(4*(i+1)-1 downto 4*i) <= reversi(PortTx_p   (4*i to 4*(i+1)-1));
    MgtPortTx_n(4*(i+1)-1 downto 4*i) <= reversi(PortTx_n   (4*i to 4*(i+1)-1));
  end generate;

  ---------------------------------------------------------
  -- User Clock
  ---------------------------------------------------------
  [StartDuplicatePort]
  UserClkPort[PortNum] <= UserClkPort([PortNum]);
  [EndDuplicatePort]

  ---------------------------------------------------------
  -- PmaInit
  ---------------------------------------------------------
  [StartDuplicatePort]
  aPortPmaInit([PortNum]) <= aPort[PortNum]PmaInit or aResetSl;
  [EndDuplicatePort]

  ---------------------------------------------------------
  -- ResetPb
  ---------------------------------------------------------
  [StartDuplicatePort]
  aPortResetPb([PortNum]) <= aPort[PortNum]ResetPb;
  [EndDuplicatePort]

  ---------------------------------------------------------
  -- CrcPassFail / CrcValid
  ---------------------------------------------------------
  [StartDuplicatePort]
  -- If line rate is greater than the cut off line rate, adding extra
  -- pipeline register to improve the timing
  GeneratePort[PortNum]CrcResultWithRegister :
  if [lineRate] > kCutOffFreqForExtraReg generate
    process(aResetSl, UserClkPort([PortNum]))
    begin
      if aResetSl = '1' then
        uPort[PortNum]CrcPassFail_n <= '1';
        uPort[PortNum]CrcValid      <= '0';
      elsif rising_edge(UserClkPort([PortNum])) then
        uPort[PortNum]CrcPassFail_n <= uPortCrcPassFail_n([PortNum]);
        uPort[PortNum]CrcValid      <= uPortCrcValid([PortNum]);
      end if;
    end process;
  end generate;

  GeneratePort[PortNum]CrcResultWithoutRegister :
  if [lineRate] <= kCutOffFreqForExtraReg generate
    uPort[PortNum]CrcPassFail_n <= uPortCrcPassFail_n([PortNum]);
    uPort[PortNum]CrcValid      <= uPortCrcValid([PortNum]);
  end generate;

  [EndDuplicatePort]

  ---------------------------------------------------------
  -- AXI Tx Data Interface
  ---------------------------------------------------------
  [StartDuplicatePort]
  -- AXI TX Data Interface Port[PortNum]
  uPortAxiTxTData0([PortNum])  <= uPort[PortNum]AxiTxTData0;
  uPortAxiTxTData1([PortNum])  <= uPort[PortNum]AxiTxTData1;
  uPortAxiTxTData2([PortNum])  <= uPort[PortNum]AxiTxTData2;
  uPortAxiTxTData3([PortNum])  <= uPort[PortNum]AxiTxTData3;
  uPortAxiTxTKeep([PortNum])   <= uPort[PortNum]AxiTxTKeep;
  uPortAxiTxTLast([PortNum])   <= uPort[PortNum]AxiTxTLast;
  uPortAxiTxTValid([PortNum])  <= uPort[PortNum]AxiTxTValid;
  uPort[PortNum]AxiTxTReady    <= uPortAxiTxTReady([PortNum]);

  [EndDuplicatePort]

  ---------------------------------------------------------
  -- AXI Rx Data Interface
  ---------------------------------------------------------
  [StartDuplicatePort]
  -- AXI RX Data Interface Port[PortNum]
  -- If line rate is greater than the cut off line rate, adding extra
  -- pipeline register to improve the timing
  GeneratePort[PortNum]AxiRxWithRegister :
  if [lineRate] > kCutOffFreqForExtraReg generate
    process(aResetSl, UserClkPort([PortNum]))
    begin
      if aResetSl = '1' then
        uPort[PortNum]AxiRxTData0  <= (others => '0');
        uPort[PortNum]AxiRxTData1  <= (others => '0');
        uPort[PortNum]AxiRxTData2  <= (others => '0');
        uPort[PortNum]AxiRxTData3  <= (others => '0');
        uPort[PortNum]AxiRxTKeep   <= (others => '0');
        uPort[PortNum]AxiRxTLast   <= '0';
        uPort[PortNum]AxiRxTValid  <= '0';
      elsif rising_edge(UserClkPort([PortNum])) then
        uPort[PortNum]AxiRxTData0  <= uPortAxiRxTData0([PortNum]);
        uPort[PortNum]AxiRxTData1  <= uPortAxiRxTData1([PortNum]);
        uPort[PortNum]AxiRxTData2  <= uPortAxiRxTData2([PortNum]);
        uPort[PortNum]AxiRxTData3  <= uPortAxiRxTData3([PortNum]);
        uPort[PortNum]AxiRxTKeep   <= uPortAxiRxTKeep([PortNum]);
        uPort[PortNum]AxiRxTLast   <= uPortAxiRxTLast([PortNum]);
        uPort[PortNum]AxiRxTValid  <= uPortAxiRxTValid([PortNum]);
      end if;
    end process;
  end generate;

  GeneratePort[PortNum]AxiRxWithoutRegister :
  if [lineRate] <= kCutOffFreqForExtraReg generate
    uPort[PortNum]AxiRxTData0  <= uPortAxiRxTData0([PortNum]);
    uPort[PortNum]AxiRxTData1  <= uPortAxiRxTData1([PortNum]);
    uPort[PortNum]AxiRxTData2  <= uPortAxiRxTData2([PortNum]);
    uPort[PortNum]AxiRxTData3  <= uPortAxiRxTData3([PortNum]);
    uPort[PortNum]AxiRxTKeep   <= uPortAxiRxTKeep([PortNum]);
    uPort[PortNum]AxiRxTLast   <= uPortAxiRxTLast([PortNum]);
    uPort[PortNum]AxiRxTValid  <= uPortAxiRxTValid([PortNum]);
  end generate;

  [EndDuplicatePort]

  ---------------------------------------------------------
  -- AXI Native Flow Control Interface
  ---------------------------------------------------------
  [StartDuplicatePort]
  -- AXI Nfc Interface Port[PortNum]
  uPortAxiNfcTData([PortNum])  <= uPort[PortNum]AxiNfcTData;
  uPortAxiNfcTValid([PortNum]) <= uPort[PortNum]AxiNfcTValid;
  uPort[PortNum]AxiNfcTReady   <= uPortAxiNfcTReady([PortNum]);

  [EndDuplicatePort]

  GenSigAssignment : for i in 0 to kNumPorts*kNumLanes-1 generate
    rGtwizRxRateIn      ((i+1)*3-1 downto i*3) <= rRxRateIn      (i);
    tGtwizTxDiffCtrlIn  ((i+1)*5-1 downto i*5) <= tTxDiffCtrlIn  (i);
    aGtwizTxPreCursorIn ((i+1)*5-1 downto i*5) <= aTxPreCursorIn (i);
    aGtwizTxPostCursorIn((i+1)*5-1 downto i*5) <= aTxPostCursorIn(i);
    rGtwizRxPrbsSelIn   ((i+1)*4-1 downto i*4) <= rRxPrbsSelIn   (i);
    tGtwizTxPrbsSelIn   ((i+1)*4-1 downto i*4) <= tTxPrbsSelIn   (i);
  end generate;

  SGtwizSlvDmonclk <= (others => SAClk);

  GenGtwizDMonClk : for i in 0 to kNumPorts*kNumLanes-1 generate
    aDMonitorOut(i) <= aGtwizDMonitorOut((i+1)*16-1 downto i*16);

  end generate;

  AuroraBlock : block
  begin
    GenAurora : for i in 0 to kNumPorts-1 generate
      RxUsrClk2(i*4+0) <= RxUserClk2Port(i);
      RxUsrClk2(i*4+1) <= RxUserClk2Port(i);
      RxUsrClk2(i*4+2) <= RxUserClk2Port(i);
      RxUsrClk2(i*4+3) <= RxUserClk2Port(i);
      TxUsrClk2(i*4+0) <= UserClkPort(i);
      TxUsrClk2(i*4+1) <= UserClkPort(i);
      TxUsrClk2(i*4+2) <= UserClkPort(i);
      TxUsrClk2(i*4+3) <= UserClkPort(i);

      --vhook AXI4Lite_GTYE4_Control_Regs4 AXI4Lite_GTYE4_Control_Regs4_inst
      --vhook_a LiteClk              SAClk
      --vhook_a lAxiMasterWritePort  sAxiMasterWritePort(i)
      --vhook_a lAxiSlaveWritePort   sAxiSlaveWritePort (i)
      --vhook_a lAxiMasterReadPort   sAxiMasterReadPort (i)
      --vhook_a lAxiSlaveReadPort    sAxiSlaveReadPort  (i)
      --vhook_a RxUsrClk2            RxUsrClk2((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a TxUsrClk2            TxUsrClk2((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a MgtRefClk            MgtRefClk(i)
      --vhook_a aGtWiz_ResetAll_in           open
      --vhook_a aGtWiz_RxCdr_stable_out      '1'
      --vhook_a aGtWiz_ResetTx_pll_data_in   open
      --vhook_a aGtWiz_ResetTx_data_in       open
      --vhook_a aGtWiz_ResetTx_Done_out      '1'
      --vhook_a aGtWiz_UserClkTx_active_out  (others => '1')
      --vhook_a aGtWiz_ResetRx_pll_data_in   open
      --vhook_a aGtWiz_ResetRx_data_in       open
      --vhook_a aGtWiz_ResetRx_Done_out      '1'
      --vhook_a aGtWiz_UserClkRx_active_out  (others => '1')
      --vhook_a rRxResetDone_out      rRxResetDoneOut((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a aRxPmaResetDone_out   aGtRxPmaResetDone((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a aRxPmaReset_in        aRxPmaResetIn  ((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a tTxResetDone_out      tTxResetDoneOut((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a aTxPmaResetDone_out   (others => '1')
      --vhook_a aTxPmaReset_in        aTxPmaResetIn  ((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a aTxPcsReset_in        aTxPcsResetIn  ((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a aEyeScanReset_in      aEyeScanResetIn((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a aGtPowerGood_out      aGtPowerGoodOut((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a aCpllPD_in            open
      --vhook_a aCpllReset_in         open
      --vhook_a aCpllRefClkSel_in     open
      --vhook_a aCpllLock_out         aCpllLockOut((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a aCpllRefClkLost_out   (others => '0')
      --vhook_a aQpll0PD_in           open
      --vhook_a aQpll0Reset_in        open
      --vhook_a aQpll0RefClkSel_in    open
      --vhook_a aQpll0Lock_out        aQpll0LockOut(i)
      --vhook_a aQpll0RefClkLost_out  aQpll0RefClkLostOut(i)
      --vhook_a aQpll0SdmReset_in     open
      --vhook_a aQpll0SdmData_in      open
      --vhook_a aQpll0SdmWidth_in     open
      --vhook_a aQpll0SdmToggle_in    open
      --vhook_a aQpll0SdmFinalOut_out (others => '0')
      --vhook_a aQpll1PD_in           open
      --vhook_a aQpll1Reset_in        open
      --vhook_a aQpll1RefClkSel_in    open
      --vhook_a aQpll1Lock_out        '0'
      --vhook_a aQpll1RefClkLost_out  '0'
      --vhook_a aQpll1SdmReset_in     open
      --vhook_a aQpll1SdmData_in      open
      --vhook_a aQpll1SdmWidth_in     open
      --vhook_a aQpll1SdmToggle_in    open
      --vhook_a aQpll1SdmFinalOut_out (others => '0')
      --vhook_a aTxSysClkSel_in       open
      --vhook_a aRxSysClkSel_in       open
      --vhook_a aTxPllClkSel_in       open
      --vhook_a aRxPllClkSel_in       open
      --vhook_a aTxOutClkSel_in       open
      --vhook_a aRxOutClkSel_in       open
      --vhook_a aRxCdrHold_in         aRxCdrHoldIn  ((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a aRxCdrOvrdEn_in       aRxCdrOvrdEnIn((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a aRxCdrReset_in        open
      --vhook_a aRxCdrLock_out        (others => '0')
      --vhook_a tTxPiPpmEn_in         open
      --vhook_a tTxPiPpmOvrdEn_in     open
      --vhook_a aTxPiPpmPD_in         open
      --vhook_a tTxPiPpmSel_in        open
      --vhook_a tTxPiPpmStepSize_in   open
      --vhook_a rRxDfeOsHold_in       open
      --vhook_a rRxDfeOsOvrdEn_in     open
      --vhook_a rRxDfeAgcHold_in      open
      --vhook_a rRxDfeAgcOvrdEn_in    open
      --vhook_a rRxDfeLfHold_in       open
      --vhook_a rRxDfeLfOvrdEn_in     open
      --vhook_a rRxDfeUtHold_in       open
      --vhook_a rRxDfeUtOvrdEn_in     open
      --vhook_a rRxDfeVpHold_in       open
      --vhook_a rRxDfeVpOvrdEn_in     open
      --vhook_a rRxDfeTap2Hold_in     open
      --vhook_a rRxDfeTap2OvrdEn_in   open
      --vhook_a rRxDfeTap3Hold_in     open
      --vhook_a rRxDfeTap3OvrdEn_in   open
      --vhook_a rRxDfeTap4Hold_in     open
      --vhook_a rRxDfeTap4OvrdEn_in   open
      --vhook_a rRxDfeTap5Hold_in     open
      --vhook_a rRxDfeTap5OvrdEn_in   open
      --vhook_a rRxDfeTap6Hold_in     open
      --vhook_a rRxDfeTap6OvrdEn_in   open
      --vhook_a rRxDfeTap7Hold_in     open
      --vhook_a rRxDfeTap7OvrdEn_in   open
      --vhook_a rRxDfeTap8Hold_in     open
      --vhook_a rRxDfeTap8OvrdEn_in   open
      --vhook_a rRxDfeTap9Hold_in     open
      --vhook_a rRxDfeTap9OvrdEn_in   open
      --vhook_a rRxDfeTap10Hold_in    open
      --vhook_a rRxDfeTap10OvrdEn_in  open
      --vhook_a rRxDfeTap11Hold_in    open
      --vhook_a rRxDfeTap11OvrdEn_in  open
      --vhook_a rRxDfeTap12Hold_in    open
      --vhook_a rRxDfeTap12OvrdEn_in  open
      --vhook_a rRxDfeTap13Hold_in    open
      --vhook_a rRxDfeTap13OvrdEn_in  open
      --vhook_a rRxDfeTap14Hold_in    open
      --vhook_a rRxDfeTap14OvrdEn_in  open
      --vhook_a rRxDfeTap15Hold_in    open
      --vhook_a rRxDfeTap15OvrdEn_in  open
      --vhook_a rRxLpmEn_in           rRxLpmEnIn((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a rRxLpmOSHold_in       open
      --vhook_a rRxLpmOSOvrdEn_in     open
      --vhook_a rRxLpmGCHold_in       open
      --vhook_a rRxLpmGCOvrdEn_in     open
      --vhook_a rRxLpmHFHold_in       open
      --vhook_a rRxLpmHFOvrdEn_in     open
      --vhook_a rRxLpmLFHold_in       open
      --vhook_a rRxLpmLFOvrdEn_in     open
      --vhook_a DmonClk               SGtwizSlvDmonclk((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a dDMonitorOut_out      aDMonitorOut((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a rRxRate_in            rRxRateIn((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a rRxRateDone_out       (others => '1')
      --vhook_a tTxRate_in            open
      --vhook_a tTxRateDone_out       (others => '1')
      --vhook_a tTxDiffCtrl_in        tTxDiffCtrlIn  ((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a aTxPreCursor_in       aTxPreCursorIn ((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a aTxPostCursor_in      aTxPostCursorIn((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a rRxPrbsSel_in         rRxPrbsSelIn ((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a rRxPrbsErr_out        rRxPrbsErrOut((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a rRxPrbsLocked_out     (others => '1')
      --vhook_a rRxPrbsCntReset_in    rRxPrbsCntResetIn((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a rRxPolarity_in        open
      --vhook_a tTxPrbsSel_in         tTxPrbsSelIn     ((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a tTxPrbsForceErr_in    tTxPrbsForceErrIn((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a tTxPolarity_in        tTxPolarityIn    ((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a tTxDetectRx_in        open
      --vhook_a rPhyStatus_out        (others => '1')
      --vhook_a rRxStatus_out         (others => (others => '1'))
      --vhook_a tTxPd_in              open
      --vhook_a rRxPd_in              open
      --vhook_a aLoopback_in          aLoopbackIn((i+1)*kNumLanes-1 downto i*kNumLanes)
      AXI4Lite_GTYE4_Control_Regs4_inst: AXI4Lite_GTYE4_Control_Regs4
        port map (
          LiteClk                     => SAClk,                                                    --in  std_logic
          aReset_n                    => aReset_n,                                                 --in  std_logic
          lAxiMasterWritePort         => sAxiMasterWritePort(i),                                   --in  Axi4LiteWritePortIn_t
          lAxiSlaveWritePort          => sAxiSlaveWritePort (i),                                   --out Axi4LiteWritePortOut_t
          lAxiMasterReadPort          => sAxiMasterReadPort (i),                                   --in  Axi4LiteReadPortIn_t
          lAxiSlaveReadPort           => sAxiSlaveReadPort (i),                                    --out Axi4LiteReadPortOut_t
          RxUsrClk2                   => RxUsrClk2((i+1)*kNumLanes-1 downto i*kNumLanes),          --in  std_logic_vector(4-1:0)
          TxUsrClk2                   => TxUsrClk2((i+1)*kNumLanes-1 downto i*kNumLanes),          --in  std_logic_vector(4-1:0)
          MgtRefClk                   => MgtRefClk(i),                                             --in  std_logic
          aGtWiz_ResetAll_in          => open,                                                     --out std_logic
          aGtWiz_RxCdr_stable_out     => '1',                                                      --in  std_logic
          aGtWiz_ResetTx_pll_data_in  => open,                                                     --out std_logic
          aGtWiz_ResetTx_data_in      => open,                                                     --out std_logic
          aGtWiz_ResetTx_Done_out     => '1',                                                      --in  std_logic
          aGtWiz_UserClkTx_active_out => (others => '1'),                                          --in  std_logic_vector(3:0)
          aGtWiz_ResetRx_pll_data_in  => open,                                                     --out std_logic
          aGtWiz_ResetRx_data_in      => open,                                                     --out std_logic
          aGtWiz_ResetRx_Done_out     => '1',                                                      --in  std_logic
          aGtWiz_UserClkRx_active_out => (others => '1'),                                          --in  std_logic_vector(3:0)
          rRxResetDone_out            => rRxResetDoneOut((i+1)*kNumLanes-1 downto i*kNumLanes),    --in  std_logic_vector(4-1:0)
          aRxPmaResetDone_out         => aGtRxPmaResetDone((i+1)*kNumLanes-1 downto i*kNumLanes),  --in  std_logic_vector(4-1:0)
          aRxPmaReset_in              => aRxPmaResetIn ((i+1)*kNumLanes-1 downto i*kNumLanes),     --out std_logic_vector(4-1:0)
          tTxResetDone_out            => tTxResetDoneOut((i+1)*kNumLanes-1 downto i*kNumLanes),    --in  std_logic_vector(4-1:0)
          aTxPmaResetDone_out         => (others => '1'),                                          --in  std_logic_vector(4-1:0)
          aTxPmaReset_in              => aTxPmaResetIn ((i+1)*kNumLanes-1 downto i*kNumLanes),     --out std_logic_vector(4-1:0)
          aTxPcsReset_in              => aTxPcsResetIn ((i+1)*kNumLanes-1 downto i*kNumLanes),     --out std_logic_vector(4-1:0)
          aEyeScanReset_in            => aEyeScanResetIn((i+1)*kNumLanes-1 downto i*kNumLanes),    --out std_logic_vector(4-1:0)
          aGtPowerGood_out            => aGtPowerGoodOut((i+1)*kNumLanes-1 downto i*kNumLanes),    --in  std_logic_vector(4-1:0)
          aCpllPD_in                  => open,                                                     --out std_logic_vector(4-1:0)
          aCpllReset_in               => open,                                                     --out std_logic_vector(4-1:0)
          aCpllRefClkSel_in           => open,                                                     --out GTRefClkSelAry_t(4-1:0)
          aCpllLock_out               => aCpllLockOut((i+1)*kNumLanes-1 downto i*kNumLanes),       --in  std_logic_vector(4-1:0)
          aCpllRefClkLost_out         => (others => '0'),                                          --in  std_logic_vector(4-1:0)
          aQpll0PD_in                 => open,                                                     --out std_logic
          aQpll0Reset_in              => open,                                                     --out std_logic
          aQpll0RefClkSel_in          => open,                                                     --out GTRefClkSel_t
          aQpll0Lock_out              => aQpll0LockOut(i),                                         --in  std_logic
          aQpll0RefClkLost_out        => aQpll0RefClkLostOut(i),                                   --in  std_logic
          aQpll0SdmReset_in           => open,                                                     --out std_logic
          aQpll0SdmData_in            => open,                                                     --out std_logic_vector(24:0)
          aQpll0SdmWidth_in           => open,                                                     --out std_logic_vector(1:0)
          aQpll0SdmToggle_in          => open,                                                     --out std_logic
          aQpll0SdmFinalOut_out       => (others => '0'),                                          --in  std_logic_vector(3:0)
          aQpll1PD_in                 => open,                                                     --out std_logic
          aQpll1Reset_in              => open,                                                     --out std_logic
          aQpll1RefClkSel_in          => open,                                                     --out GTRefClkSel_t
          aQpll1Lock_out              => '0',                                                      --in  std_logic
          aQpll1RefClkLost_out        => '0',                                                      --in  std_logic
          aQpll1SdmReset_in           => open,                                                     --out std_logic
          aQpll1SdmData_in            => open,                                                     --out std_logic_vector(24:0)
          aQpll1SdmWidth_in           => open,                                                     --out std_logic_vector(1:0)
          aQpll1SdmToggle_in          => open,                                                     --out std_logic
          aQpll1SdmFinalOut_out       => (others => '0'),                                          --in  std_logic_vector(3:0)
          aTxSysClkSel_in             => open,                                                     --out GTClkSelAry_t(4-1:0)
          aRxSysClkSel_in             => open,                                                     --out GTClkSelAry_t(4-1:0)
          aTxPllClkSel_in             => open,                                                     --out GTClkSelAry_t(4-1:0)
          aRxPllClkSel_in             => open,                                                     --out GTClkSelAry_t(4-1:0)
          aTxOutClkSel_in             => open,                                                     --out GTOutClkSelAry_t(4-1:0)
          aRxOutClkSel_in             => open,                                                     --out GTOutClkSelAry_t(4-1:0)
          aRxCdrHold_in               => aRxCdrHoldIn ((i+1)*kNumLanes-1 downto i*kNumLanes),      --out std_logic_vector(4-1:0)
          aRxCdrOvrdEn_in             => aRxCdrOvrdEnIn((i+1)*kNumLanes-1 downto i*kNumLanes),     --out std_logic_vector(4-1:0)
          aRxCdrReset_in              => open,                                                     --out std_logic_vector(4-1:0)
          aRxCdrLock_out              => (others => '0'),                                          --in  std_logic_vector(4-1:0)
          tTxPiPpmEn_in               => open,                                                     --out std_logic_vector(4-1:0)
          tTxPiPpmOvrdEn_in           => open,                                                     --out std_logic_vector(4-1:0)
          aTxPiPpmPD_in               => open,                                                     --out std_logic_vector(4-1:0)
          tTxPiPpmSel_in              => open,                                                     --out std_logic_vector(4-1:0)
          tTxPiPpmStepSize_in         => open,                                                     --out GTTxPiPpmStepSizeAry_t(4-1:0)
          rRxDfeOSHold_in             => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeOSOvrdEn_in           => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeAgcHold_in            => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeAgcOvrdEn_in          => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeLFHold_in             => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeLFOvrdEn_in           => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeUTHold_in             => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeUTOvrdEn_in           => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeVPHold_in             => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeVPOvrdEn_in           => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap2Hold_in           => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap2OvrdEn_in         => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap3Hold_in           => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap3OvrdEn_in         => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap4Hold_in           => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap4OvrdEn_in         => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap5Hold_in           => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap5OvrdEn_in         => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap6Hold_in           => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap6OvrdEn_in         => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap7Hold_in           => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap7OvrdEn_in         => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap8Hold_in           => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap8OvrdEn_in         => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap9Hold_in           => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap9OvrdEn_in         => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap10Hold_in          => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap10OvrdEn_in        => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap11Hold_in          => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap11OvrdEn_in        => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap12Hold_in          => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap12OvrdEn_in        => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap13Hold_in          => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap13OvrdEn_in        => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap14Hold_in          => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap14OvrdEn_in        => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap15Hold_in          => open,                                                     --out std_logic_vector(4-1:0)
          rRxDfeTap15OvrdEn_in        => open,                                                     --out std_logic_vector(4-1:0)
          rRxLpmEn_in                 => rRxLpmEnIn((i+1)*kNumLanes-1 downto i*kNumLanes),         --out std_logic_vector(4-1:0)
          rRxLpmOSHold_in             => open,                                                     --out std_logic_vector(4-1:0)
          rRxLpmOSOvrdEn_in           => open,                                                     --out std_logic_vector(4-1:0)
          rRxLpmGCHold_in             => open,                                                     --out std_logic_vector(4-1:0)
          rRxLpmGCOvrdEn_in           => open,                                                     --out std_logic_vector(4-1:0)
          rRxLpmHFHold_in             => open,                                                     --out std_logic_vector(4-1:0)
          rRxLpmHFOvrdEn_in           => open,                                                     --out std_logic_vector(4-1:0)
          rRxLpmLFHold_in             => open,                                                     --out std_logic_vector(4-1:0)
          rRxLpmLFOvrdEn_in           => open,                                                     --out std_logic_vector(4-1:0)
          DmonClk                     => SGtwizSlvDmonclk((i+1)*kNumLanes-1 downto i*kNumLanes),   --in  std_logic_vector(4-1:0)
          dDMonitorOut_out            => aDMonitorOut((i+1)*kNumLanes-1 downto i*kNumLanes),       --in  GTYE4DMonitorOutAry_t(4-1:0)
          rRxRate_in                  => rRxRateIn((i+1)*kNumLanes-1 downto i*kNumLanes),          --out GTRateSelAry_t(4-1:0)
          rRxRateDone_out             => (others => '1'),                                          --in  std_logic_vector(4-1:0)
          tTxRate_in                  => open,                                                     --out GTRateSelAry_t(4-1:0)
          tTxRateDone_out             => (others => '1'),                                          --in  std_logic_vector(4-1:0)
          tTxDiffCtrl_in              => tTxDiffCtrlIn ((i+1)*kNumLanes-1 downto i*kNumLanes),     --out GTYDiffCtrlAry_t(4-1:0)
          aTxPreCursor_in             => aTxPreCursorIn ((i+1)*kNumLanes-1 downto i*kNumLanes),    --out GTYCursorSelAry_t(4-1:0)
          aTxPostCursor_in            => aTxPostCursorIn((i+1)*kNumLanes-1 downto i*kNumLanes),    --out GTYCursorSelAry_t(4-1:0)
          rRxPrbsSel_in               => rRxPrbsSelIn ((i+1)*kNumLanes-1 downto i*kNumLanes),      --out GTPrbsSelAry_t(4-1:0)
          rRxPrbsErr_out              => rRxPrbsErrOut((i+1)*kNumLanes-1 downto i*kNumLanes),      --in  std_logic_vector(4-1:0)
          rRxPrbsLocked_out           => (others => '1'),                                          --in  std_logic_vector(4-1:0)
          rRxPrbsCntReset_in          => rRxPrbsCntResetIn((i+1)*kNumLanes-1 downto i*kNumLanes),  --out std_logic_vector(4-1:0)
          rRxPolarity_in              => open,                                                     --out std_logic_vector(4-1:0)
          tTxPrbsSel_in               => tTxPrbsSelIn ((i+1)*kNumLanes-1 downto i*kNumLanes),      --out GTPrbsSelAry_t(4-1:0)
          tTxPrbsForceErr_in          => tTxPrbsForceErrIn((i+1)*kNumLanes-1 downto i*kNumLanes),  --out std_logic_vector(4-1:0)
          tTxPolarity_in              => tTxPolarityIn ((i+1)*kNumLanes-1 downto i*kNumLanes),     --out std_logic_vector(4-1:0)
          tTxDetectRx_in              => open,                                                     --out std_logic_vector(4-1:0)
          rPhyStatus_out              => (others => '1'),                                          --in  std_logic_vector(4-1:0)
          rRxStatus_out               => (others => (others => '1')),                              --in  GTRxStatusAry_t(4-1:0)
          tTxPd_in                    => open,                                                     --out GTPdAry_t(4-1:0)
          rRxPd_in                    => open,                                                     --out GTPdAry_t(4-1:0)
          aLoopback_in                => aLoopbackIn((i+1)*kNumLanes-1 downto i*kNumLanes));       --out GTLoopbackSelAry_t(4-1:0)

      uPortAxiTxTData(i)  <= uPortAxiTxTData3(i) & uPortAxiTxTData2(i) & uPortAxiTxTData1(i) & uPortAxiTxTData0(i);
      uPortAxiRxTData0(i) <= uPortAxiRxTData(i)(0*64+63 downto 0*64);
      uPortAxiRxTData1(i) <= uPortAxiRxTData(i)(1*64+63 downto 1*64);
      uPortAxiRxTData2(i) <= uPortAxiRxTData(i)(2*64+63 downto 2*64);
      uPortAxiRxTData3(i) <= uPortAxiRxTData(i)(3*64+63 downto 3*64);

      uPortLaneUp(i) <= reversi(uPortLaneUpRev(i));

      -- If line rate is greater than the cut off line rate, adding extra
      -- pipeline register to improve the timing
      GenerateAxiTxWithRegister :
      if [lineRate] > kCutOffFreqForExtraReg generate
        --vhook AxiFramingRegx4 AxiFramingRegx4Tx
        --vhook_a aclk           UserClkPort(i)
        --vhook_a aresetn        aReset_n
        --vhook_a s_axis_tvalid  uPortAxiTxTValid(i)
        --vhook_a s_axis_tready  uPortAxiTxTReady(i)
        --vhook_a s_axis_tdata   uPortAxiTxTData (i)
        --vhook_a s_axis_tkeep   uPortAxiTxTKeep (i)
        --vhook_a s_axis_tlast   uPortAxiTxTLast (i)
        --vhook_a m_axis_tvalid  uPortAxiRegTxTValid(i)
        --vhook_a m_axis_tready  uPortAxiRegTxTReady(i)
        --vhook_a m_axis_tdata   uPortAxiRegTxTData (i)
        --vhook_a m_axis_tkeep   uPortAxiRegTxTKeep (i)
        --vhook_a m_axis_tlast   uPortAxiRegTxTLast (i)
        AxiFramingRegx4Tx: AxiFramingRegx4
          port map (
            aclk          => UserClkPort(i),          --in  STD_LOGIC
            aresetn       => aReset_n,                --in  STD_LOGIC
            s_axis_tvalid => uPortAxiTxTValid(i),     --in  STD_LOGIC
            s_axis_tready => uPortAxiTxTReady(i),     --out STD_LOGIC
            s_axis_tdata  => uPortAxiTxTData (i),     --in  STD_LOGIC_VECTOR(255:0)
            s_axis_tkeep  => uPortAxiTxTKeep (i),     --in  STD_LOGIC_VECTOR(31:0)
            s_axis_tlast  => uPortAxiTxTLast (i),     --in  STD_LOGIC
            m_axis_tvalid => uPortAxiRegTxTValid(i),  --out STD_LOGIC
            m_axis_tready => uPortAxiRegTxTReady(i),  --in  STD_LOGIC
            m_axis_tdata  => uPortAxiRegTxTData (i),  --out STD_LOGIC_VECTOR(255:0)
            m_axis_tkeep  => uPortAxiRegTxTKeep (i),  --out STD_LOGIC_VECTOR(31:0)
            m_axis_tlast  => uPortAxiRegTxTLast (i)); --out STD_LOGIC
      end generate;

      GenerateAxiTxWithoutRegister :
      if [lineRate] <= kCutOffFreqForExtraReg generate
        uPortAxiRegTxTData (i) <= uPortAxiTxTData (i);
        uPortAxiRegTxTLast (i) <= uPortAxiTxTLast (i);
        uPortAxiRegTxTKeep (i) <= uPortAxiTxTKeep (i);
        uPortAxiRegTxTValid(i) <= uPortAxiTxTValid(i);
        uPortAxiTxTReady(i) <= uPortAxiRegTxTReady(i);
      end generate;

      --vhook aurora64b66b_framing_crcx4_[lineRateStr]GHz Aurora_PortN
      --vhook_a s_axi_tx_tdata   uPortAxiRegTxTData (i)
      --vhook_a s_axi_tx_tlast   uPortAxiRegTxTLast (i)
      --vhook_a s_axi_tx_tkeep   uPortAxiRegTxTKeep (i)
      --vhook_a s_axi_tx_tvalid  uPortAxiRegTxTValid(i)
      --vhook_a s_axi_tx_tready  uPortAxiRegTxTReady(i)
      --vhook_a m_axi_rx_tdata   uPortAxiRxTData (i)
      --vhook_a m_axi_rx_tlast   uPortAxiRxTLast (i)
      --vhook_a m_axi_rx_tkeep   uPortAxiRxTKeep (i)
      --vhook_a m_axi_rx_tvalid  uPortAxiRxTValid(i)
      --vhook_a s_axi_nfc_tvalid uPortAxiNfcTValid(i)
      --vhook_a s_axi_nfc_tdata  uPortAxiNfcTData (i)(15 downto 0)
      --vhook_a s_axi_nfc_tready uPortAxiNfcTReady(i)
      --vhook_a rxp  PortRx_p(i*4 to i*4+3)
      --vhook_a rxn  PortRx_n(i*4 to i*4+3)
      --vhook_a txp  PortTx_p(i*4 to i*4+3)
      --vhook_a txn  PortTx_n(i*4 to i*4+3)
      --vhook_a refclk1_in  MgtRefClk(i)
      --vhook_a hard_err         uPortHardErr  (i)
      --vhook_a soft_err         uPortSoftErr  (i)
      --vhook_a lane_up          uPortLaneUpRev(i)
      --vhook_a channel_up       uPortChannelUp(i)
      --vhook_a crc_pass_fail_n  uPortCrcPassFail_n(i)
      --vhook_a crc_valid        uPortCrcValid(i)
      --vhook_a init_clk         InitClk
      --vhook_a user_clk_out     UserClkPort(i)
      --vhook_a sync_clk_out     SyncClkPort(i)
      --vhook_a mmcm_not_locked_out  uPortMmcmNotLocked(i)
      --vhook_a pma_init         aPortPmaInit(i)
      --vhook_a reset_pb         aPortResetPb(i)
      --vhook_a power_down       '0'
      --vhook_a loopback         aLoopbackIn(i*kNumLanes)
      --vhook_a gt_pll_lock      open
      --vhook_a link_reset_out   iPortLinkResetOut(i)
      --vhook_a sys_reset_out    uPortSysResetOut (i)
      --vhook_a gt_reset_out     open
      --vhook_a gt_rxusrclk_out  RxUserClk2Port(i)
      --vhook_a tx_out_clk       open
      --vhook_a gt_qpllclk_quad1_out         open
      --vhook_a gt_qpllrefclk_quad1_out      open
      --vhook_a gt_qplllock_quad1_out        aQpll0LockOut(i)
      --vhook_a gt_qpllrefclklost_quad1_out  aQpll0RefClkLostOut(i)
      --vhook_a gt0_drpaddr  iGtwizDrpAddrIn((i*4+1)*kAddrSize-1 downto (i*4+0)*kAddrSize)
      --vhook_a gt0_drpdi    iGtwizDrpDiIn  ((i*4+1)*16-1 downto (i*4+0)*16)
      --vhook_a gt0_drpdo    iGtwizDrpDoOut ((i*4+1)*16-1 downto (i*4+0)*16)
      --vhook_a gt0_drprdy   iGtwizDrpRdyOut (i*4+0)
      --vhook_a gt0_drpen    iGtwizDrpEnIn   (i*4+0)
      --vhook_a gt0_drpwe    iGtwizDrpWeIn   (i*4+0)
      --vhook_a gt1_drpaddr  iGtwizDrpAddrIn((i*4+2)*kAddrSize-1 downto (i*4+1)*kAddrSize)
      --vhook_a gt1_drpdi    iGtwizDrpDiIn  ((i*4+2)*16-1 downto (i*4+1)*16)
      --vhook_a gt1_drpdo    iGtwizDrpDoOut ((i*4+2)*16-1 downto (i*4+1)*16)
      --vhook_a gt1_drprdy   iGtwizDrpRdyOut (i*4+1)
      --vhook_a gt1_drpen    iGtwizDrpEnIn   (i*4+1)
      --vhook_a gt1_drpwe    iGtwizDrpWeIn   (i*4+1)
      --vhook_a gt2_drpaddr  iGtwizDrpAddrIn((i*4+3)*kAddrSize-1 downto (i*4+2)*kAddrSize)
      --vhook_a gt2_drpdi    iGtwizDrpDiIn  ((i*4+3)*16-1 downto (i*4+2)*16)
      --vhook_a gt2_drpdo    iGtwizDrpDoOut ((i*4+3)*16-1 downto (i*4+2)*16)
      --vhook_a gt2_drprdy   iGtwizDrpRdyOut (i*4+2)
      --vhook_a gt2_drpen    iGtwizDrpEnIn   (i*4+2)
      --vhook_a gt2_drpwe    iGtwizDrpWeIn   (i*4+2)
      --vhook_a gt3_drpaddr  iGtwizDrpAddrIn((i*4+4)*kAddrSize-1 downto (i*4+3)*kAddrSize)
      --vhook_a gt3_drpdi    iGtwizDrpDiIn  ((i*4+4)*16-1 downto (i*4+3)*16)
      --vhook_a gt3_drpdo    iGtwizDrpDoOut ((i*4+4)*16-1 downto (i*4+3)*16)
      --vhook_a gt3_drprdy   iGtwizDrpRdyOut (i*4+3)
      --vhook_a gt3_drpen    iGtwizDrpEnIn   (i*4+3)
      --vhook_a gt3_drpwe    iGtwizDrpWeIn   (i*4+3)
      --vhook_a gt_rxcdrovrden_in    aRxCdrOvrdEnIn (i*kNumLanes)
      --vhook_a gt_eyescandataerror  open
      --vhook_a gt_eyescanreset      aEyeScanResetIn((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a gt_eyescantrigger    (others => '0')
      --vhook_a gt_rxcdrhold         aRxCdrHoldIn   ((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a gt_rxdfelpmreset     (others => '0')
      --vhook_a gt_rxlpmen           rRxLpmEnIn     ((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a gt_rxpmareset        aRxPmaResetIn  ((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a gt_rxpcsreset        (others => '0')
      --vhook_a gt_rxrate            rGtwizRxRateIn((i+1)*kNumLanes*3-1 downto i*kNumLanes*3)
      --vhook_a gt_rxbufreset        (others => '0')
      --vhook_a gt_rxpmaresetdone    aGtRxPmaResetDone((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a gt_rxprbssel         rGtwizRxPrbsSelIn((i+1)*kNumLanes*4-1 downto i*kNumLanes*4)
      --vhook_a gt_rxprbserr         rRxPrbsErrOut     ((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a gt_rxprbscntreset    rRxPrbsCntResetIn ((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a gt_rxresetdone       rRxResetDoneOut   ((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a gt_rxbufstatus       open
      --vhook_a gt_txdiffctrl        tGtwizTxDiffCtrlIn  ((i+1)*kNumLanes*5-1 downto i*kNumLanes*5)
      --vhook_a gt_txprecursor       aGtwizTxPreCursorIn ((i+1)*kNumLanes*5-1 downto i*kNumLanes*5)
      --vhook_a gt_txpostcursor      aGtwizTxPostCursorIn((i+1)*kNumLanes*5-1 downto i*kNumLanes*5)
      --vhook_a gt_txpolarity        tTxPolarityIn((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a gt_txinhibit         (others => '0')
      --vhook_a gt_txpmareset        aTxPmaResetIn((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a gt_txpcsreset        aTxPcsResetIn((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a gt_txprbssel         tGtwizTxPrbsSelIn((i+1)*kNumLanes*4-1 downto i*kNumLanes*4)
      --vhook_a gt_txprbsforceerr    tTxPrbsForceErrIn ((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a gt_txbufstatus       open
      --vhook_a gt_txresetdone       tTxResetDoneOut   ((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a gt_pcsrsvdin         (others => '0')
      --vhook_a gt_powergood         aGtPowerGoodOut((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a gt_dmonitorout       aGtwizDMonitorOut((i+1)*kNumLanes*16-1 downto i*kNumLanes*16)
      --vhook_a gt_cplllock          aCpllLockOut ((i+1)*kNumLanes-1 downto i*kNumLanes)
      --vhook_a gt_qplllock          open
      Aurora_PortN: aurora64b66b_framing_crcx4_[lineRateStr]GHz
        port map (
          s_axi_tx_tdata              => uPortAxiRegTxTData (i),                                          --in  STD_LOGIC_VECTOR(255:0)
          s_axi_tx_tlast              => uPortAxiRegTxTLast (i),                                          --in  STD_LOGIC
          s_axi_tx_tkeep              => uPortAxiRegTxTKeep (i),                                          --in  STD_LOGIC_VECTOR(31:0)
          s_axi_tx_tvalid             => uPortAxiRegTxTValid(i),                                          --in  STD_LOGIC
          s_axi_tx_tready             => uPortAxiRegTxTReady(i),                                          --out STD_LOGIC
          m_axi_rx_tdata              => uPortAxiRxTData (i),                                             --out STD_LOGIC_VECTOR(255:0)
          m_axi_rx_tlast              => uPortAxiRxTLast (i),                                             --out STD_LOGIC
          m_axi_rx_tkeep              => uPortAxiRxTKeep (i),                                             --out STD_LOGIC_VECTOR(31:0)
          m_axi_rx_tvalid             => uPortAxiRxTValid(i),                                             --out STD_LOGIC
          s_axi_nfc_tvalid            => uPortAxiNfcTValid(i),                                            --in  STD_LOGIC
          s_axi_nfc_tdata             => uPortAxiNfcTData (i)(15 downto 0),                               --in  STD_LOGIC_VECTOR(15:0)
          s_axi_nfc_tready            => uPortAxiNfcTReady(i),                                            --out STD_LOGIC
          rxp                         => PortRx_p(i*4 to i*4+3),                                          --in  STD_LOGIC_VECTOR(0:3)
          rxn                         => PortRx_n(i*4 to i*4+3),                                          --in  STD_LOGIC_VECTOR(0:3)
          txp                         => PortTx_p(i*4 to i*4+3),                                          --out STD_LOGIC_VECTOR(0:3)
          txn                         => PortTx_n(i*4 to i*4+3),                                          --out STD_LOGIC_VECTOR(0:3)
          refclk1_in                  => MgtRefClk(i),                                                    --in  STD_LOGIC
          hard_err                    => uPortHardErr (i),                                                --out STD_LOGIC
          soft_err                    => uPortSoftErr (i),                                                --out STD_LOGIC
          channel_up                  => uPortChannelUp(i),                                               --out STD_LOGIC
          lane_up                     => uPortLaneUpRev(i),                                               --out STD_LOGIC_VECTOR(0:3)
          crc_pass_fail_n             => uPortCrcPassFail_n(i),                                           --out STD_LOGIC
          crc_valid                   => uPortCrcValid(i),                                                --out STD_LOGIC
          user_clk_out                => UserClkPort(i),                                                  --out STD_LOGIC
          mmcm_not_locked_out         => uPortMmcmNotLocked(i),                                           --out STD_LOGIC
          sync_clk_out                => SyncClkPort(i),                                                  --out STD_LOGIC
          reset_pb                    => aPortResetPb(i),                                                 --in  STD_LOGIC
          gt_rxcdrovrden_in           => aRxCdrOvrdEnIn (i*kNumLanes),                                    --in  STD_LOGIC
          power_down                  => '0',                                                             --in  STD_LOGIC
          loopback                    => aLoopbackIn(i*kNumLanes),                                        --in  STD_LOGIC_VECTOR(2:0)
          pma_init                    => aPortPmaInit(i),                                                 --in  STD_LOGIC
          gt_pll_lock                 => open,                                                            --out STD_LOGIC
          gt0_drpaddr                 => iGtwizDrpAddrIn((i*4+1)*kAddrSize-1 downto (i*4+0)*kAddrSize),   --in  STD_LOGIC_VECTOR(9:0)
          gt0_drpdi                   => iGtwizDrpDiIn ((i*4+1)*16-1 downto (i*4+0)*16),                  --in  STD_LOGIC_VECTOR(15:0)
          gt0_drpdo                   => iGtwizDrpDoOut ((i*4+1)*16-1 downto (i*4+0)*16),                 --out STD_LOGIC_VECTOR(15:0)
          gt0_drprdy                  => iGtwizDrpRdyOut (i*4+0),                                         --out STD_LOGIC
          gt0_drpen                   => iGtwizDrpEnIn (i*4+0),                                           --in  STD_LOGIC
          gt0_drpwe                   => iGtwizDrpWeIn (i*4+0),                                           --in  STD_LOGIC
          gt1_drpaddr                 => iGtwizDrpAddrIn((i*4+2)*kAddrSize-1 downto (i*4+1)*kAddrSize),   --in  STD_LOGIC_VECTOR(9:0)
          gt1_drpdi                   => iGtwizDrpDiIn ((i*4+2)*16-1 downto (i*4+1)*16),                  --in  STD_LOGIC_VECTOR(15:0)
          gt1_drpdo                   => iGtwizDrpDoOut ((i*4+2)*16-1 downto (i*4+1)*16),                 --out STD_LOGIC_VECTOR(15:0)
          gt1_drprdy                  => iGtwizDrpRdyOut (i*4+1),                                         --out STD_LOGIC
          gt1_drpen                   => iGtwizDrpEnIn (i*4+1),                                           --in  STD_LOGIC
          gt1_drpwe                   => iGtwizDrpWeIn (i*4+1),                                           --in  STD_LOGIC
          gt2_drpaddr                 => iGtwizDrpAddrIn((i*4+3)*kAddrSize-1 downto (i*4+2)*kAddrSize),   --in  STD_LOGIC_VECTOR(9:0)
          gt2_drpdi                   => iGtwizDrpDiIn ((i*4+3)*16-1 downto (i*4+2)*16),                  --in  STD_LOGIC_VECTOR(15:0)
          gt2_drpdo                   => iGtwizDrpDoOut ((i*4+3)*16-1 downto (i*4+2)*16),                 --out STD_LOGIC_VECTOR(15:0)
          gt2_drprdy                  => iGtwizDrpRdyOut (i*4+2),                                         --out STD_LOGIC
          gt2_drpen                   => iGtwizDrpEnIn (i*4+2),                                           --in  STD_LOGIC
          gt2_drpwe                   => iGtwizDrpWeIn (i*4+2),                                           --in  STD_LOGIC
          gt3_drpaddr                 => iGtwizDrpAddrIn((i*4+4)*kAddrSize-1 downto (i*4+3)*kAddrSize),   --in  STD_LOGIC_VECTOR(9:0)
          gt3_drpdi                   => iGtwizDrpDiIn ((i*4+4)*16-1 downto (i*4+3)*16),                  --in  STD_LOGIC_VECTOR(15:0)
          gt3_drpdo                   => iGtwizDrpDoOut ((i*4+4)*16-1 downto (i*4+3)*16),                 --out STD_LOGIC_VECTOR(15:0)
          gt3_drprdy                  => iGtwizDrpRdyOut (i*4+3),                                         --out STD_LOGIC
          gt3_drpen                   => iGtwizDrpEnIn (i*4+3),                                           --in  STD_LOGIC
          gt3_drpwe                   => iGtwizDrpWeIn (i*4+3),                                           --in  STD_LOGIC
          init_clk                    => InitClk,                                                         --in  STD_LOGIC
          link_reset_out              => iPortLinkResetOut(i),                                            --out STD_LOGIC
          gt_rxusrclk_out             => RxUserClk2Port(i),                                               --out STD_LOGIC
          gt_eyescandataerror         => open,                                                            --out STD_LOGIC_VECTOR(3:0)
          gt_eyescanreset             => aEyeScanResetIn((i+1)*kNumLanes-1 downto i*kNumLanes),           --in  STD_LOGIC_VECTOR(3:0)
          gt_eyescantrigger           => (others => '0'),                                                 --in  STD_LOGIC_VECTOR(3:0)
          gt_rxcdrhold                => aRxCdrHoldIn ((i+1)*kNumLanes-1 downto i*kNumLanes),             --in  STD_LOGIC_VECTOR(3:0)
          gt_rxdfelpmreset            => (others => '0'),                                                 --in  STD_LOGIC_VECTOR(3:0)
          gt_rxlpmen                  => rRxLpmEnIn ((i+1)*kNumLanes-1 downto i*kNumLanes),               --in  STD_LOGIC_VECTOR(3:0)
          gt_rxpmareset               => aRxPmaResetIn ((i+1)*kNumLanes-1 downto i*kNumLanes),            --in  STD_LOGIC_VECTOR(3:0)
          gt_rxpcsreset               => (others => '0'),                                                 --in  STD_LOGIC_VECTOR(3:0)
          gt_rxrate                   => rGtwizRxRateIn((i+1)*kNumLanes*3-1 downto i*kNumLanes*3),        --in  STD_LOGIC_VECTOR(11:0)
          gt_rxbufreset               => (others => '0'),                                                 --in  STD_LOGIC_VECTOR(3:0)
          gt_rxpmaresetdone           => aGtRxPmaResetDone((i+1)*kNumLanes-1 downto i*kNumLanes),         --out STD_LOGIC_VECTOR(3:0)
          gt_rxprbssel                => rGtwizRxPrbsSelIn((i+1)*kNumLanes*4-1 downto i*kNumLanes*4),     --in  STD_LOGIC_VECTOR(15:0)
          gt_rxprbserr                => rRxPrbsErrOut ((i+1)*kNumLanes-1 downto i*kNumLanes),            --out STD_LOGIC_VECTOR(3:0)
          gt_rxprbscntreset           => rRxPrbsCntResetIn ((i+1)*kNumLanes-1 downto i*kNumLanes),        --in  STD_LOGIC_VECTOR(3:0)
          gt_rxresetdone              => rRxResetDoneOut ((i+1)*kNumLanes-1 downto i*kNumLanes),          --out STD_LOGIC_VECTOR(3:0)
          gt_rxbufstatus              => open,                                                            --out STD_LOGIC_VECTOR(11:0)
          gt_txpostcursor             => aGtwizTxPostCursorIn((i+1)*kNumLanes*5-1 downto i*kNumLanes*5),  --in  STD_LOGIC_VECTOR(19:0)
          gt_txdiffctrl               => tGtwizTxDiffCtrlIn ((i+1)*kNumLanes*5-1 downto i*kNumLanes*5),   --in  STD_LOGIC_VECTOR(19:0)
          gt_txprecursor              => aGtwizTxPreCursorIn ((i+1)*kNumLanes*5-1 downto i*kNumLanes*5),  --in  STD_LOGIC_VECTOR(19:0)
          gt_txpolarity               => tTxPolarityIn((i+1)*kNumLanes-1 downto i*kNumLanes),             --in  STD_LOGIC_VECTOR(3:0)
          gt_txinhibit                => (others => '0'),                                                 --in  STD_LOGIC_VECTOR(3:0)
          gt_txpmareset               => aTxPmaResetIn((i+1)*kNumLanes-1 downto i*kNumLanes),             --in  STD_LOGIC_VECTOR(3:0)
          gt_txpcsreset               => aTxPcsResetIn((i+1)*kNumLanes-1 downto i*kNumLanes),             --in  STD_LOGIC_VECTOR(3:0)
          gt_txprbssel                => tGtwizTxPrbsSelIn((i+1)*kNumLanes*4-1 downto i*kNumLanes*4),     --in  STD_LOGIC_VECTOR(15:0)
          gt_txprbsforceerr           => tTxPrbsForceErrIn ((i+1)*kNumLanes-1 downto i*kNumLanes),        --in  STD_LOGIC_VECTOR(3:0)
          gt_txbufstatus              => open,                                                            --out STD_LOGIC_VECTOR(7:0)
          gt_txresetdone              => tTxResetDoneOut ((i+1)*kNumLanes-1 downto i*kNumLanes),          --out STD_LOGIC_VECTOR(3:0)
          gt_pcsrsvdin                => (others => '0'),                                                 --in  STD_LOGIC_VECTOR(63:0)
          gt_dmonitorout              => aGtwizDMonitorOut((i+1)*kNumLanes*16-1 downto i*kNumLanes*16),   --out STD_LOGIC_VECTOR(63:0)
          gt_cplllock                 => aCpllLockOut ((i+1)*kNumLanes-1 downto i*kNumLanes),             --out STD_LOGIC_VECTOR(3:0)
          gt_qplllock                 => open,                                                            --out STD_LOGIC
          gt_powergood                => aGtPowerGoodOut((i+1)*kNumLanes-1 downto i*kNumLanes),           --out STD_LOGIC_VECTOR(3:0)
          gt_qpllclk_quad1_out        => open,                                                            --out STD_LOGIC
          gt_qpllrefclk_quad1_out     => open,                                                            --out STD_LOGIC
          gt_qplllock_quad1_out       => aQpll0LockOut(i),                                                --out STD_LOGIC
          gt_qpllrefclklost_quad1_out => aQpll0RefClkLostOut(i),                                          --out STD_LOGIC
          sys_reset_out               => uPortSysResetOut (i),                                            --out STD_LOGIC
          gt_reset_out                => open,                                                            --out STD_LOGIC
          tx_out_clk                  => open);                                                           --out STD_LOGIC
    end generate;
  end block AuroraBlock;
end rtl;
