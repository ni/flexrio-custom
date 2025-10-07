-------------------------------------------------------------------------------
--
-- File: PXIe7903_100GbE.vhd
-- Author: National Instruments
-- Original Project: PXIe-7903 HSS
-- Date: 02 June 2022
--
-------------------------------------------------------------------------------
-- Copyright (c) 2025 National Instruments Corporation
-- 
-- All rights reserved.
-------------------------------------------------------------------------------
--
-- Purpose:
--   This CLIP implements 6 100Gb Ethernet cores for the 7903.
--
--   While there are 12 ports on the 7903, only 6 have the CMAC hard IP easily
-- accessable. These are ports 0, 2, 3, 8, 10, and 11 on the front panel.
--
-------------------------------------------------------------------------------
--
-- githubvisible=true
--

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgFlexRioTargetConfig.all;

library unisim;
  use unisim.vcomponents.all;

entity PXIe7903_100GbE is
  port (
    ------------------------------
    -- Reset                    --
    ------------------------------
    -- Asynchronous reset signal from the LabVIEW FPGA environment.
    -- This signal *must* be present in the port interface for all IO Socket CLIPs.
    -- You should reset your CLIP logic whenever this signal is logic high.
    aResetSl : in  std_logic;

    ------------------------------
    -- REQUIRED Socket Signals --
    ------------------------------
    -- Configuration
    aLmkI2cSda          : inout std_logic;
    aLmkI2cScl          : inout std_logic;
    aLmk1Pdn_n          : out std_logic;
    aLmk2Pdn_n          : out std_logic;
    aLmk1Gpio0          : out std_logic;
    aLmk2Gpio0          : out std_logic;
    aLmk1Status0        : in std_logic;
    aLmk1Status1        : in std_logic;
    aLmk2Status0        : in std_logic;
    aLmk2Status1        : in std_logic;
    aIPassPrsnt_n       : in std_logic_vector(7 downto 0);
    aIPassIntr_n        : in std_logic_vector(7 downto 0);
    aIPassSCL           : inout std_logic_vector(11 downto 0);
    aIPassSDA           : inout std_logic_vector(11 downto 0);
    aPortExpReset_n     : out std_logic;
    aPortExpIntr_n      : in std_logic;
    aPortExpSda         : inout std_logic;
    aPortExpScl         : inout std_logic;
    aIPassVccPowerFault_n : in std_logic; --vhook_nowarn aIPassVccPowerFault_n

    -- Reserved Interfaces
    stIoModuleSupportsFRAGLs : out std_logic;

    ------------------------------
    -- DIO Signals              --
    ------------------------------
    aDio : inout std_logic_vector(7 downto 0);

    ----------------------------------
    -- AXI Communication Interfaces --
    ----------------------------------
    AxiClk : in  std_logic;
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

    ------------------------------
    -- MGT Socket Interface     --
    ------------------------------
    -- These signals connect directly to the MGT pins, and should be connected to the
    -- user's IP.
    MgtRefClk_p : in  std_logic_vector(11 downto 0);
    MgtRefClk_n : in  std_logic_vector(11 downto 0);
    MgtPortRx_p : in  std_logic_vector(47 downto 0);
    MgtPortRx_n : in  std_logic_vector(47 downto 0);
    MgtPortTx_p : out std_logic_vector(47 downto 0);
    MgtPortTx_n : out std_logic_vector(47 downto 0);
    --vhook_nodgv MgtPort*

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

    ------------------------------
    -- REQUIRED Diagram Signals --
    ------------------------------
    -- This is the exact same clock as AxiClk, but we need to bring it in so LVFPGA can enforce its use.
    --vhook_nowarn TopLevelClk80
    TopLevelClk80      : in  std_logic;
    -- Status signals to the diagram
    xIoModuleReady     : out std_logic;
    xIoModuleErrorCode : out std_logic_vector(31 downto 0);
    -- DIO
    aDioOut : in  std_logic_vector(7 downto 0);
    aDioIn  : out std_logic_vector(7 downto 0);

    ----------------------------------------------------------------------------
    -- LVFPGA signals
    ----------------------------------------------------------------------------
    -- This is the collection of signals that appear in LabVIEW FPGA.
    --
    -- These signals are used to allow the user to interface with the CLIP
    -- from a high level perspective through LabVIEW as well as allowing the user
    -- to monitor the values associated with some of the internal signals
    --
    -- LabVIEW FPGA signals must use one of the following signal directions:
    -- {in, out}
    -- LabVIEW FPGA signals must use one of the following data types:
    -- (std_logic, std_logic_vector)
    ----------------------------------------------------------------------------

    --------------------------------- Status -----------------------------------
    xPort0CoreReady  : out std_logic;
    xPort2CoreReady  : out std_logic;
    xPort3CoreReady  : out std_logic;
    xPort8CoreReady  : out std_logic;
    xPort10CoreReady : out std_logic;
    xPort11CoreReady : out std_logic;

    --------------------------------- Clocks -----------------------------------
    -- 80MHz Clock
    SysClk        : in  std_logic;
    -- 322.26666 Mhz clock generated by 100G Phy from RefClock
    UserClkPort0  : out std_logic;
    UserClkPort2  : out std_logic;
    UserClkPort3  : out std_logic;
    UserClkPort8  : out std_logic;
    UserClkPort10 : out std_logic;
    UserClkPort11 : out std_logic;

    -------------------------------------------------------------------------
    -- DRP AXI
    -------------------------------------------------------------------------
    xDrpAxiAwaddr   : in  std_logic_vector(31 downto 0);
    xDrpAxiAwvalid  : in  std_logic;
    xDrpAxiAwready  : out std_logic;
    xDrpAxiWdata    : in  std_logic_vector(31 downto 0);
    xDrpAxiWstrb    : in  std_logic_vector(3 downto 0);
    xDrpAxiWvalid   : in  std_logic;
    xDrpAxiWready   : out std_logic;
    xDrpAxiBresp    : out std_logic_vector(1 downto 0);
    xDrpAxiBvalid   : out std_logic;
    xDrpAxiBready   : in  std_logic;
    xDrpAxiAraddr   : in  std_logic_vector(31 downto 0);
    xDrpAxiArvalid  : in  std_logic;
    xDrpAxiArready  : out std_logic;
    xDrpAxiRdata    : out std_logic_vector(31 downto 0);
    xDrpAxiRresp    : out std_logic_vector(1 downto 0);
    xDrpAxiRvalid   : out std_logic;
    xDrpAxiRready   : in  std_logic;


    -------------------------------------------------------------------------
    -- Port 0
    -------------------------------------------------------------------------

    ------------------------ AXI Stream TX Interface ------------------------
    -- The following signals are REQUIRED to be in the UserClk domain:
    uPort0TxTData0     : in  std_logic_vector(63 downto 0);
    uPort0TxTData1     : in  std_logic_vector(63 downto 0);
    uPort0TxTData2     : in  std_logic_vector(63 downto 0);
    uPort0TxTData3     : in  std_logic_vector(63 downto 0);
    uPort0TxTData4     : in  std_logic_vector(63 downto 0);
    uPort0TxTData5     : in  std_logic_vector(63 downto 0);
    uPort0TxTData6     : in  std_logic_vector(63 downto 0);
    uPort0TxTData7     : in  std_logic_vector(63 downto 0);
    uPort0TxTKeep      : in  std_logic_vector(63 downto 0);
    uPort0TxTLast      : in  std_logic;
    uPort0TxTUser      : in  std_logic;
    uPort0TxTValid     : in  std_logic;
    uPort0TxTReady     : out std_logic;

    ------------------------ AXI Stream RX Interface ------------------------
    -- The following signals are REQUIRED to be in the UserClk domain:
    uPort0RxTData0     : out std_logic_vector(63 downto 0);
    uPort0RxTData1     : out std_logic_vector(63 downto 0);
    uPort0RxTData2     : out std_logic_vector(63 downto 0);
    uPort0RxTData3     : out std_logic_vector(63 downto 0);
    uPort0RxTData4     : out std_logic_vector(63 downto 0);
    uPort0RxTData5     : out std_logic_vector(63 downto 0);
    uPort0RxTData6     : out std_logic_vector(63 downto 0);
    uPort0RxTData7     : out std_logic_vector(63 downto 0);
    uPort0RxTKeep      : out std_logic_vector(63 downto 0);
    uPort0RxTUser      : out std_logic; -- 1 indicates a bad packet
    uPort0RxTLast      : out std_logic;
    uPort0RxTValid     : out std_logic;
    -- There is no RxTReady signal support by the Ethernet100G IP. Received data has to
    -- be read immediately or it is lost.

    ----------------------------- Flow Control ------------------------------
    uPort0CtlRxPauseEnable        : in  std_logic_vector(8 downto 0);
    uPort0CtlRxEnableGcp          : in  std_logic;
    uPort0CtlRxCheckMcastGcp      : in  std_logic;
    uPort0CtlRxCheckUcastGcp      : in  std_logic;
    uPort0CtlRxCheckSaGcp         : in  std_logic;
    uPort0CtlRxCheckEtypeGcp      : in  std_logic;
    uPort0CtlRxCheckOpcodeGcp     : in  std_logic;
    uPort0CtlRxEnablePcp          : in  std_logic;
    uPort0CtlRxCheckMcastPcp      : in  std_logic;
    uPort0CtlRxCheckUcastPcp      : in  std_logic;
    uPort0CtlRxCheckSaPcp         : in  std_logic;
    uPort0CtlRxCheckEtypePcp      : in  std_logic;
    uPort0CtlRxCheckOpcodePcp     : in  std_logic;
    uPort0CtlRxEnableGpp          : in  std_logic;
    uPort0CtlRxCheckMcastGpp      : in  std_logic;
    uPort0CtlRxCheckUcastGpp      : in  std_logic;
    uPort0CtlRxCheckSaGpp         : in  std_logic;
    uPort0CtlRxCheckEtypeGpp      : in  std_logic;
    uPort0CtlRxCheckOpcodeGpp     : in  std_logic;
    uPort0CtlRxEnablePpp          : in  std_logic;
    uPort0CtlRxCheckMcastPpp      : in  std_logic;
    uPort0CtlRxCheckUcastPpp      : in  std_logic;
    uPort0CtlRxCheckSaPpp         : in  std_logic;
    uPort0CtlRxCheckEtypePpp      : in  std_logic;
    uPort0CtlRxCheckOpcodePpp     : in  std_logic;
    uPort0StatRxPauseReq          : out std_logic_vector(8 downto 0);
    uPort0CtlRxPauseAck           : in  std_logic_vector(8 downto 0);
    uPort0StatRxPauseValid        : out std_logic_vector(8 downto 0);
    uPort0StatRxPauseQanta0       : out std_logic_vector(15 downto 0);
    uPort0StatRxPauseQanta1       : out std_logic_vector(15 downto 0);
    uPort0StatRxPauseQanta2       : out std_logic_vector(15 downto 0);
    uPort0StatRxPauseQanta3       : out std_logic_vector(15 downto 0);
    uPort0StatRxPauseQanta4       : out std_logic_vector(15 downto 0);
    uPort0StatRxPauseQanta5       : out std_logic_vector(15 downto 0);
    uPort0StatRxPauseQanta6       : out std_logic_vector(15 downto 0);
    uPort0StatRxPauseQanta7       : out std_logic_vector(15 downto 0);
    uPort0StatRxPauseQanta8       : out std_logic_vector(15 downto 0);

    uPort0CtlTxPauseEnable        : in  std_logic_vector(8 downto 0);
    uPort0CtlTxPauseReq           : in  std_logic_vector(8 downto 0);
    uPort0CtlTxPauseQuanta0       : in  std_logic_vector(15 downto 0);
    uPort0CtlTxPauseQuanta1       : in  std_logic_vector(15 downto 0);
    uPort0CtlTxPauseQuanta2       : in  std_logic_vector(15 downto 0);
    uPort0CtlTxPauseQuanta3       : in  std_logic_vector(15 downto 0);
    uPort0CtlTxPauseQuanta4       : in  std_logic_vector(15 downto 0);
    uPort0CtlTxPauseQuanta5       : in  std_logic_vector(15 downto 0);
    uPort0CtlTxPauseQuanta6       : in  std_logic_vector(15 downto 0);
    uPort0CtlTxPauseQuanta7       : in  std_logic_vector(15 downto 0);
    uPort0CtlTxPauseQuanta8       : in  std_logic_vector(15 downto 0);
    uPort0CtlTxPauseRefreshTimer0 : in  std_logic_vector(15 downto 0);
    uPort0CtlTxPauseRefreshTimer1 : in  std_logic_vector(15 downto 0);
    uPort0CtlTxPauseRefreshTimer2 : in  std_logic_vector(15 downto 0);
    uPort0CtlTxPauseRefreshTimer3 : in  std_logic_vector(15 downto 0);
    uPort0CtlTxPauseRefreshTimer4 : in  std_logic_vector(15 downto 0);
    uPort0CtlTxPauseRefreshTimer5 : in  std_logic_vector(15 downto 0);
    uPort0CtlTxPauseRefreshTimer6 : in  std_logic_vector(15 downto 0);
    uPort0CtlTxPauseRefreshTimer7 : in  std_logic_vector(15 downto 0);
    uPort0CtlTxPauseRefreshTimer8 : in  std_logic_vector(15 downto 0);
    uPort0CtlTxResendPause        : in  std_logic;
    uPort0StatTxPauseValid        : out std_logic_vector(8 downto 0);

    ------------------------------- IEEE 1588 -------------------------------
    uPort0CtlRxSystemtimerinHigh         : in  std_logic_vector(15 downto 0);
    uPort0CtlRxSystemtimerinLow          : in  std_logic_vector(63 downto 0);
    uPort0CtlTxSystemtimerinHigh         : in  std_logic_vector(15 downto 0);
    uPort0CtlTxSystemtimerinLow          : in  std_logic_vector(63 downto 0);
    uPort0RxLaneAlignerFill0             : out std_logic_vector(6 downto 0);
    uPort0RxLaneAlignerFill1             : out std_logic_vector(6 downto 0);
    uPort0RxLaneAlignerFill10            : out std_logic_vector(6 downto 0);
    uPort0RxLaneAlignerFill11            : out std_logic_vector(6 downto 0);
    uPort0RxLaneAlignerFill12            : out std_logic_vector(6 downto 0);
    uPort0RxLaneAlignerFill13            : out std_logic_vector(6 downto 0);
    uPort0RxLaneAlignerFill14            : out std_logic_vector(6 downto 0);
    uPort0RxLaneAlignerFill15            : out std_logic_vector(6 downto 0);
    uPort0RxLaneAlignerFill16            : out std_logic_vector(6 downto 0);
    uPort0RxLaneAlignerFill17            : out std_logic_vector(6 downto 0);
    uPort0RxLaneAlignerFill18            : out std_logic_vector(6 downto 0);
    uPort0RxLaneAlignerFill19            : out std_logic_vector(6 downto 0);
    uPort0RxLaneAlignerFill2             : out std_logic_vector(6 downto 0);
    uPort0RxLaneAlignerFill3             : out std_logic_vector(6 downto 0);
    uPort0RxLaneAlignerFill4             : out std_logic_vector(6 downto 0);
    uPort0RxLaneAlignerFill5             : out std_logic_vector(6 downto 0);
    uPort0RxLaneAlignerFill6             : out std_logic_vector(6 downto 0);
    uPort0RxLaneAlignerFill7             : out std_logic_vector(6 downto 0);
    uPort0RxLaneAlignerFill8             : out std_logic_vector(6 downto 0);
    uPort0RxLaneAlignerFill9             : out std_logic_vector(6 downto 0);
    uPort0RxPtpPcslaneOut                : out std_logic_vector(4 downto 0);
    uPort0RxPtpTstampOutHigh             : out std_logic_vector(15 downto 0);
    uPort0RxPtpTstampOutLow              : out std_logic_vector(63 downto 0);
    uPort0StatTxPtpFifoReadError         : out std_logic;
    uPort0StatTxPtpFifoWriteError        : out std_logic;
    uPort0TxPtp1588opIn                  : in  std_logic_vector(1 downto 0);
    uPort0TxPtpPcslaneOut                : out std_logic_vector(4 downto 0);
    uPort0TxPtpTagFieldIn                : in  std_logic_vector(15 downto 0);
    uPort0TxPtpTstampOutHigh             : out std_logic_vector(15 downto 0);
    uPort0TxPtpTstampOutLow              : out std_logic_vector(63 downto 0);
    uPort0TxPtpTstampTagOut              : out std_logic_vector(15 downto 0);
    uPort0TxPtpTstampValidOut            : out std_logic;

    -------------------------------- Status ---------------------------------
    uPort0StatRxRsfecAmLock0             : out std_logic;
    uPort0StatRxRsfecAmLock1             : out std_logic;
    uPort0StatRxRsfecAmLock2             : out std_logic;
    uPort0StatRxRsfecAmLock3             : out std_logic;
    uPort0StatRxRsfecCorrectedCwInc      : out std_logic;
    uPort0StatRxRsfecCwInc               : out std_logic;
    uPort0StatRxRsfecErrCount0Inc        : out std_logic_vector(2 downto 0);
    uPort0StatRxRsfecErrCount1Inc        : out std_logic_vector(2 downto 0);
    uPort0StatRxRsfecErrCount2Inc        : out std_logic_vector(2 downto 0);
    uPort0StatRxRsfecErrCount3Inc        : out std_logic_vector(2 downto 0);
    uPort0StatRxRsfecHiSer               : out std_logic;
    uPort0StatRxRsfecLaneAlignmentStatus : out std_logic;
    uPort0StatRxRsfecLaneFill0           : out std_logic_vector(13 downto 0);
    uPort0StatRxRsfecLaneFill1           : out std_logic_vector(13 downto 0);
    uPort0StatRxRsfecLaneFill2           : out std_logic_vector(13 downto 0);
    uPort0StatRxRsfecLaneFill3           : out std_logic_vector(13 downto 0);
    uPort0StatRxRsfecLaneMapping         : out std_logic_vector(7 downto 0);
    uPort0StatRxRsfecUncorrectedCwInc    : out std_logic;

    ---------------------------- Core Reset Status -----------------------------
    -- The following signal is REQUIRED to be in the UserClk domain:
    uPort0UserClkResetOut  : out std_logic;

    -------------------------------------------------------------------------
    -- Port2
    -------------------------------------------------------------------------

    ------------------------ AXI Stream TX Interface ------------------------
    -- The following signals are REQUIRED to be in the UserClk domain:
    uPort2TxTData0     : in  std_logic_vector(63 downto 0);
    uPort2TxTData1     : in  std_logic_vector(63 downto 0);
    uPort2TxTData2     : in  std_logic_vector(63 downto 0);
    uPort2TxTData3     : in  std_logic_vector(63 downto 0);
    uPort2TxTData4     : in  std_logic_vector(63 downto 0);
    uPort2TxTData5     : in  std_logic_vector(63 downto 0);
    uPort2TxTData6     : in  std_logic_vector(63 downto 0);
    uPort2TxTData7     : in  std_logic_vector(63 downto 0);
    uPort2TxTKeep      : in  std_logic_vector(63 downto 0);
    uPort2TxTLast      : in  std_logic;
    uPort2TxTUser      : in  std_logic;
    uPort2TxTValid     : in  std_logic;
    uPort2TxTReady     : out std_logic;

    ------------------------ AXI Stream RX Interface ------------------------
    -- The following signals are REQUIRED to be in the UserClk domain:
    uPort2RxTData0     : out std_logic_vector(63 downto 0);
    uPort2RxTData1     : out std_logic_vector(63 downto 0);
    uPort2RxTData2     : out std_logic_vector(63 downto 0);
    uPort2RxTData3     : out std_logic_vector(63 downto 0);
    uPort2RxTData4     : out std_logic_vector(63 downto 0);
    uPort2RxTData5     : out std_logic_vector(63 downto 0);
    uPort2RxTData6     : out std_logic_vector(63 downto 0);
    uPort2RxTData7     : out std_logic_vector(63 downto 0);
    uPort2RxTKeep      : out std_logic_vector(63 downto 0);
    uPort2RxTUser      : out std_logic; -- 1 indicates a bad packet
    uPort2RxTLast      : out std_logic;
    uPort2RxTValid     : out std_logic;
    -- There is no RxTReady signal support by the Ethernet100G IP. Received data has to
    -- be read immediately or it is lost.

    ----------------------------- Flow Control ------------------------------
    uPort2CtlRxPauseEnable        : in  std_logic_vector(8 downto 0);
    uPort2CtlRxEnableGcp          : in  std_logic;
    uPort2CtlRxCheckMcastGcp      : in  std_logic;
    uPort2CtlRxCheckUcastGcp      : in  std_logic;
    uPort2CtlRxCheckSaGcp         : in  std_logic;
    uPort2CtlRxCheckEtypeGcp      : in  std_logic;
    uPort2CtlRxCheckOpcodeGcp     : in  std_logic;
    uPort2CtlRxEnablePcp          : in  std_logic;
    uPort2CtlRxCheckMcastPcp      : in  std_logic;
    uPort2CtlRxCheckUcastPcp      : in  std_logic;
    uPort2CtlRxCheckSaPcp         : in  std_logic;
    uPort2CtlRxCheckEtypePcp      : in  std_logic;
    uPort2CtlRxCheckOpcodePcp     : in  std_logic;
    uPort2CtlRxEnableGpp          : in  std_logic;
    uPort2CtlRxCheckMcastGpp      : in  std_logic;
    uPort2CtlRxCheckUcastGpp      : in  std_logic;
    uPort2CtlRxCheckSaGpp         : in  std_logic;
    uPort2CtlRxCheckEtypeGpp      : in  std_logic;
    uPort2CtlRxCheckOpcodeGpp     : in  std_logic;
    uPort2CtlRxEnablePpp          : in  std_logic;
    uPort2CtlRxCheckMcastPpp      : in  std_logic;
    uPort2CtlRxCheckUcastPpp      : in  std_logic;
    uPort2CtlRxCheckSaPpp         : in  std_logic;
    uPort2CtlRxCheckEtypePpp      : in  std_logic;
    uPort2CtlRxCheckOpcodePpp     : in  std_logic;
    uPort2StatRxPauseReq          : out std_logic_vector(8 downto 0);
    uPort2CtlRxPauseAck           : in  std_logic_vector(8 downto 0);
    uPort2StatRxPauseValid        : out std_logic_vector(8 downto 0);
    uPort2StatRxPauseQanta0       : out std_logic_vector(15 downto 0);
    uPort2StatRxPauseQanta1       : out std_logic_vector(15 downto 0);
    uPort2StatRxPauseQanta2       : out std_logic_vector(15 downto 0);
    uPort2StatRxPauseQanta3       : out std_logic_vector(15 downto 0);
    uPort2StatRxPauseQanta4       : out std_logic_vector(15 downto 0);
    uPort2StatRxPauseQanta5       : out std_logic_vector(15 downto 0);
    uPort2StatRxPauseQanta6       : out std_logic_vector(15 downto 0);
    uPort2StatRxPauseQanta7       : out std_logic_vector(15 downto 0);
    uPort2StatRxPauseQanta8       : out std_logic_vector(15 downto 0);

    uPort2CtlTxPauseEnable        : in  std_logic_vector(8 downto 0);
    uPort2CtlTxPauseReq           : in  std_logic_vector(8 downto 0);
    uPort2CtlTxPauseQuanta0       : in  std_logic_vector(15 downto 0);
    uPort2CtlTxPauseQuanta1       : in  std_logic_vector(15 downto 0);
    uPort2CtlTxPauseQuanta2       : in  std_logic_vector(15 downto 0);
    uPort2CtlTxPauseQuanta3       : in  std_logic_vector(15 downto 0);
    uPort2CtlTxPauseQuanta4       : in  std_logic_vector(15 downto 0);
    uPort2CtlTxPauseQuanta5       : in  std_logic_vector(15 downto 0);
    uPort2CtlTxPauseQuanta6       : in  std_logic_vector(15 downto 0);
    uPort2CtlTxPauseQuanta7       : in  std_logic_vector(15 downto 0);
    uPort2CtlTxPauseQuanta8       : in  std_logic_vector(15 downto 0);
    uPort2CtlTxPauseRefreshTimer0 : in  std_logic_vector(15 downto 0);
    uPort2CtlTxPauseRefreshTimer1 : in  std_logic_vector(15 downto 0);
    uPort2CtlTxPauseRefreshTimer2 : in  std_logic_vector(15 downto 0);
    uPort2CtlTxPauseRefreshTimer3 : in  std_logic_vector(15 downto 0);
    uPort2CtlTxPauseRefreshTimer4 : in  std_logic_vector(15 downto 0);
    uPort2CtlTxPauseRefreshTimer5 : in  std_logic_vector(15 downto 0);
    uPort2CtlTxPauseRefreshTimer6 : in  std_logic_vector(15 downto 0);
    uPort2CtlTxPauseRefreshTimer7 : in  std_logic_vector(15 downto 0);
    uPort2CtlTxPauseRefreshTimer8 : in  std_logic_vector(15 downto 0);
    uPort2CtlTxResendPause        : in  std_logic;
    uPort2StatTxPauseValid        : out std_logic_vector(8 downto 0);

    ------------------------------- IEEE 1588 -------------------------------
    uPort2CtlRxSystemtimerinHigh         : in  std_logic_vector(15 downto 0);
    uPort2CtlRxSystemtimerinLow          : in  std_logic_vector(63 downto 0);
    uPort2CtlTxSystemtimerinHigh         : in  std_logic_vector(15 downto 0);
    uPort2CtlTxSystemtimerinLow          : in  std_logic_vector(63 downto 0);
    uPort2RxLaneAlignerFill0             : out std_logic_vector(6 downto 0);
    uPort2RxLaneAlignerFill1             : out std_logic_vector(6 downto 0);
    uPort2RxLaneAlignerFill10            : out std_logic_vector(6 downto 0);
    uPort2RxLaneAlignerFill11            : out std_logic_vector(6 downto 0);
    uPort2RxLaneAlignerFill12            : out std_logic_vector(6 downto 0);
    uPort2RxLaneAlignerFill13            : out std_logic_vector(6 downto 0);
    uPort2RxLaneAlignerFill14            : out std_logic_vector(6 downto 0);
    uPort2RxLaneAlignerFill15            : out std_logic_vector(6 downto 0);
    uPort2RxLaneAlignerFill16            : out std_logic_vector(6 downto 0);
    uPort2RxLaneAlignerFill17            : out std_logic_vector(6 downto 0);
    uPort2RxLaneAlignerFill18            : out std_logic_vector(6 downto 0);
    uPort2RxLaneAlignerFill19            : out std_logic_vector(6 downto 0);
    uPort2RxLaneAlignerFill2             : out std_logic_vector(6 downto 0);
    uPort2RxLaneAlignerFill3             : out std_logic_vector(6 downto 0);
    uPort2RxLaneAlignerFill4             : out std_logic_vector(6 downto 0);
    uPort2RxLaneAlignerFill5             : out std_logic_vector(6 downto 0);
    uPort2RxLaneAlignerFill6             : out std_logic_vector(6 downto 0);
    uPort2RxLaneAlignerFill7             : out std_logic_vector(6 downto 0);
    uPort2RxLaneAlignerFill8             : out std_logic_vector(6 downto 0);
    uPort2RxLaneAlignerFill9             : out std_logic_vector(6 downto 0);
    uPort2RxPtpPcslaneOut                : out std_logic_vector(4 downto 0);
    uPort2RxPtpTstampOutHigh             : out std_logic_vector(15 downto 0);
    uPort2RxPtpTstampOutLow              : out std_logic_vector(63 downto 0);
    uPort2StatTxPtpFifoReadError         : out std_logic;
    uPort2StatTxPtpFifoWriteError        : out std_logic;
    uPort2TxPtp1588opIn                  : in  std_logic_vector(1 downto 0);
    uPort2TxPtpPcslaneOut                : out std_logic_vector(4 downto 0);
    uPort2TxPtpTagFieldIn                : in  std_logic_vector(15 downto 0);
    uPort2TxPtpTstampOutHigh             : out std_logic_vector(15 downto 0);
    uPort2TxPtpTstampOutLow              : out std_logic_vector(63 downto 0);
    uPort2TxPtpTstampTagOut              : out std_logic_vector(15 downto 0);
    uPort2TxPtpTstampValidOut            : out std_logic;

    -------------------------------- Status ---------------------------------
    uPort2StatRxRsfecAmLock0             : out std_logic;
    uPort2StatRxRsfecAmLock1             : out std_logic;
    uPort2StatRxRsfecAmLock2             : out std_logic;
    uPort2StatRxRsfecAmLock3             : out std_logic;
    uPort2StatRxRsfecCorrectedCwInc      : out std_logic;
    uPort2StatRxRsfecCwInc               : out std_logic;
    uPort2StatRxRsfecErrCount0Inc        : out std_logic_vector(2 downto 0);
    uPort2StatRxRsfecErrCount1Inc        : out std_logic_vector(2 downto 0);
    uPort2StatRxRsfecErrCount2Inc        : out std_logic_vector(2 downto 0);
    uPort2StatRxRsfecErrCount3Inc        : out std_logic_vector(2 downto 0);
    uPort2StatRxRsfecHiSer               : out std_logic;
    uPort2StatRxRsfecLaneAlignmentStatus : out std_logic;
    uPort2StatRxRsfecLaneFill0           : out std_logic_vector(13 downto 0);
    uPort2StatRxRsfecLaneFill1           : out std_logic_vector(13 downto 0);
    uPort2StatRxRsfecLaneFill2           : out std_logic_vector(13 downto 0);
    uPort2StatRxRsfecLaneFill3           : out std_logic_vector(13 downto 0);
    uPort2StatRxRsfecLaneMapping         : out std_logic_vector(7 downto 0);
    uPort2StatRxRsfecUncorrectedCwInc    : out std_logic;

    ---------------------------- Core Reset Status -----------------------------
    -- The following signal is REQUIRED to be in the UserClk domain:
    uPort2UserClkResetOut  : out std_logic;

    -------------------------------------------------------------------------
    -- Port3
    -------------------------------------------------------------------------

    ------------------------ AXI Stream TX Interface ------------------------
    -- The following signals are REQUIRED to be in the UserClk domain:
    uPort3TxTData0     : in  std_logic_vector(63 downto 0);
    uPort3TxTData1     : in  std_logic_vector(63 downto 0);
    uPort3TxTData2     : in  std_logic_vector(63 downto 0);
    uPort3TxTData3     : in  std_logic_vector(63 downto 0);
    uPort3TxTData4     : in  std_logic_vector(63 downto 0);
    uPort3TxTData5     : in  std_logic_vector(63 downto 0);
    uPort3TxTData6     : in  std_logic_vector(63 downto 0);
    uPort3TxTData7     : in  std_logic_vector(63 downto 0);
    uPort3TxTKeep      : in  std_logic_vector(63 downto 0);
    uPort3TxTLast      : in  std_logic;
    uPort3TxTUser      : in  std_logic;
    uPort3TxTValid     : in  std_logic;
    uPort3TxTReady     : out std_logic;

    ------------------------ AXI Stream RX Interface ------------------------
    -- The following signals are REQUIRED to be in the UserClk domain:
    uPort3RxTData0     : out std_logic_vector(63 downto 0);
    uPort3RxTData1     : out std_logic_vector(63 downto 0);
    uPort3RxTData2     : out std_logic_vector(63 downto 0);
    uPort3RxTData3     : out std_logic_vector(63 downto 0);
    uPort3RxTData4     : out std_logic_vector(63 downto 0);
    uPort3RxTData5     : out std_logic_vector(63 downto 0);
    uPort3RxTData6     : out std_logic_vector(63 downto 0);
    uPort3RxTData7     : out std_logic_vector(63 downto 0);
    uPort3RxTKeep      : out std_logic_vector(63 downto 0);
    uPort3RxTUser      : out std_logic; -- 1 indicates a bad packet
    uPort3RxTLast      : out std_logic;
    uPort3RxTValid     : out std_logic;
    -- There is no RxTReady signal support by the Ethernet100G IP. Received data has to
    -- be read immediately or it is lost.

    ----------------------------- Flow Control ------------------------------
    uPort3CtlRxPauseEnable        : in  std_logic_vector(8 downto 0);
    uPort3CtlRxEnableGcp          : in  std_logic;
    uPort3CtlRxCheckMcastGcp      : in  std_logic;
    uPort3CtlRxCheckUcastGcp      : in  std_logic;
    uPort3CtlRxCheckSaGcp         : in  std_logic;
    uPort3CtlRxCheckEtypeGcp      : in  std_logic;
    uPort3CtlRxCheckOpcodeGcp     : in  std_logic;
    uPort3CtlRxEnablePcp          : in  std_logic;
    uPort3CtlRxCheckMcastPcp      : in  std_logic;
    uPort3CtlRxCheckUcastPcp      : in  std_logic;
    uPort3CtlRxCheckSaPcp         : in  std_logic;
    uPort3CtlRxCheckEtypePcp      : in  std_logic;
    uPort3CtlRxCheckOpcodePcp     : in  std_logic;
    uPort3CtlRxEnableGpp          : in  std_logic;
    uPort3CtlRxCheckMcastGpp      : in  std_logic;
    uPort3CtlRxCheckUcastGpp      : in  std_logic;
    uPort3CtlRxCheckSaGpp         : in  std_logic;
    uPort3CtlRxCheckEtypeGpp      : in  std_logic;
    uPort3CtlRxCheckOpcodeGpp     : in  std_logic;
    uPort3CtlRxEnablePpp          : in  std_logic;
    uPort3CtlRxCheckMcastPpp      : in  std_logic;
    uPort3CtlRxCheckUcastPpp      : in  std_logic;
    uPort3CtlRxCheckSaPpp         : in  std_logic;
    uPort3CtlRxCheckEtypePpp      : in  std_logic;
    uPort3CtlRxCheckOpcodePpp     : in  std_logic;
    uPort3StatRxPauseReq          : out std_logic_vector(8 downto 0);
    uPort3CtlRxPauseAck           : in  std_logic_vector(8 downto 0);
    uPort3StatRxPauseValid        : out std_logic_vector(8 downto 0);
    uPort3StatRxPauseQanta0       : out std_logic_vector(15 downto 0);
    uPort3StatRxPauseQanta1       : out std_logic_vector(15 downto 0);
    uPort3StatRxPauseQanta2       : out std_logic_vector(15 downto 0);
    uPort3StatRxPauseQanta3       : out std_logic_vector(15 downto 0);
    uPort3StatRxPauseQanta4       : out std_logic_vector(15 downto 0);
    uPort3StatRxPauseQanta5       : out std_logic_vector(15 downto 0);
    uPort3StatRxPauseQanta6       : out std_logic_vector(15 downto 0);
    uPort3StatRxPauseQanta7       : out std_logic_vector(15 downto 0);
    uPort3StatRxPauseQanta8       : out std_logic_vector(15 downto 0);

    uPort3CtlTxPauseEnable        : in  std_logic_vector(8 downto 0);
    uPort3CtlTxPauseReq           : in  std_logic_vector(8 downto 0);
    uPort3CtlTxPauseQuanta0       : in  std_logic_vector(15 downto 0);
    uPort3CtlTxPauseQuanta1       : in  std_logic_vector(15 downto 0);
    uPort3CtlTxPauseQuanta2       : in  std_logic_vector(15 downto 0);
    uPort3CtlTxPauseQuanta3       : in  std_logic_vector(15 downto 0);
    uPort3CtlTxPauseQuanta4       : in  std_logic_vector(15 downto 0);
    uPort3CtlTxPauseQuanta5       : in  std_logic_vector(15 downto 0);
    uPort3CtlTxPauseQuanta6       : in  std_logic_vector(15 downto 0);
    uPort3CtlTxPauseQuanta7       : in  std_logic_vector(15 downto 0);
    uPort3CtlTxPauseQuanta8       : in  std_logic_vector(15 downto 0);
    uPort3CtlTxPauseRefreshTimer0 : in  std_logic_vector(15 downto 0);
    uPort3CtlTxPauseRefreshTimer1 : in  std_logic_vector(15 downto 0);
    uPort3CtlTxPauseRefreshTimer2 : in  std_logic_vector(15 downto 0);
    uPort3CtlTxPauseRefreshTimer3 : in  std_logic_vector(15 downto 0);
    uPort3CtlTxPauseRefreshTimer4 : in  std_logic_vector(15 downto 0);
    uPort3CtlTxPauseRefreshTimer5 : in  std_logic_vector(15 downto 0);
    uPort3CtlTxPauseRefreshTimer6 : in  std_logic_vector(15 downto 0);
    uPort3CtlTxPauseRefreshTimer7 : in  std_logic_vector(15 downto 0);
    uPort3CtlTxPauseRefreshTimer8 : in  std_logic_vector(15 downto 0);
    uPort3CtlTxResendPause        : in  std_logic;
    uPort3StatTxPauseValid        : out std_logic_vector(8 downto 0);

    ------------------------------- IEEE 1588 -------------------------------
    uPort3CtlRxSystemtimerinHigh         : in  std_logic_vector(15 downto 0);
    uPort3CtlRxSystemtimerinLow          : in  std_logic_vector(63 downto 0);
    uPort3CtlTxSystemtimerinHigh         : in  std_logic_vector(15 downto 0);
    uPort3CtlTxSystemtimerinLow          : in  std_logic_vector(63 downto 0);
    uPort3RxLaneAlignerFill0             : out std_logic_vector(6 downto 0);
    uPort3RxLaneAlignerFill1             : out std_logic_vector(6 downto 0);
    uPort3RxLaneAlignerFill10            : out std_logic_vector(6 downto 0);
    uPort3RxLaneAlignerFill11            : out std_logic_vector(6 downto 0);
    uPort3RxLaneAlignerFill12            : out std_logic_vector(6 downto 0);
    uPort3RxLaneAlignerFill13            : out std_logic_vector(6 downto 0);
    uPort3RxLaneAlignerFill14            : out std_logic_vector(6 downto 0);
    uPort3RxLaneAlignerFill15            : out std_logic_vector(6 downto 0);
    uPort3RxLaneAlignerFill16            : out std_logic_vector(6 downto 0);
    uPort3RxLaneAlignerFill17            : out std_logic_vector(6 downto 0);
    uPort3RxLaneAlignerFill18            : out std_logic_vector(6 downto 0);
    uPort3RxLaneAlignerFill19            : out std_logic_vector(6 downto 0);
    uPort3RxLaneAlignerFill2             : out std_logic_vector(6 downto 0);
    uPort3RxLaneAlignerFill3             : out std_logic_vector(6 downto 0);
    uPort3RxLaneAlignerFill4             : out std_logic_vector(6 downto 0);
    uPort3RxLaneAlignerFill5             : out std_logic_vector(6 downto 0);
    uPort3RxLaneAlignerFill6             : out std_logic_vector(6 downto 0);
    uPort3RxLaneAlignerFill7             : out std_logic_vector(6 downto 0);
    uPort3RxLaneAlignerFill8             : out std_logic_vector(6 downto 0);
    uPort3RxLaneAlignerFill9             : out std_logic_vector(6 downto 0);
    uPort3RxPtpPcslaneOut                : out std_logic_vector(4 downto 0);
    uPort3RxPtpTstampOutHigh             : out std_logic_vector(15 downto 0);
    uPort3RxPtpTstampOutLow              : out std_logic_vector(63 downto 0);
    uPort3StatTxPtpFifoReadError         : out std_logic;
    uPort3StatTxPtpFifoWriteError        : out std_logic;
    uPort3TxPtp1588opIn                  : in  std_logic_vector(1 downto 0);
    uPort3TxPtpPcslaneOut                : out std_logic_vector(4 downto 0);
    uPort3TxPtpTagFieldIn                : in  std_logic_vector(15 downto 0);
    uPort3TxPtpTstampOutHigh             : out std_logic_vector(15 downto 0);
    uPort3TxPtpTstampOutLow              : out std_logic_vector(63 downto 0);
    uPort3TxPtpTstampTagOut              : out std_logic_vector(15 downto 0);
    uPort3TxPtpTstampValidOut            : out std_logic;

    -------------------------------- Status ---------------------------------
    uPort3StatRxRsfecAmLock0             : out std_logic;
    uPort3StatRxRsfecAmLock1             : out std_logic;
    uPort3StatRxRsfecAmLock2             : out std_logic;
    uPort3StatRxRsfecAmLock3             : out std_logic;
    uPort3StatRxRsfecCorrectedCwInc      : out std_logic;
    uPort3StatRxRsfecCwInc               : out std_logic;
    uPort3StatRxRsfecErrCount0Inc        : out std_logic_vector(2 downto 0);
    uPort3StatRxRsfecErrCount1Inc        : out std_logic_vector(2 downto 0);
    uPort3StatRxRsfecErrCount2Inc        : out std_logic_vector(2 downto 0);
    uPort3StatRxRsfecErrCount3Inc        : out std_logic_vector(2 downto 0);
    uPort3StatRxRsfecHiSer               : out std_logic;
    uPort3StatRxRsfecLaneAlignmentStatus : out std_logic;
    uPort3StatRxRsfecLaneFill0           : out std_logic_vector(13 downto 0);
    uPort3StatRxRsfecLaneFill1           : out std_logic_vector(13 downto 0);
    uPort3StatRxRsfecLaneFill2           : out std_logic_vector(13 downto 0);
    uPort3StatRxRsfecLaneFill3           : out std_logic_vector(13 downto 0);
    uPort3StatRxRsfecLaneMapping         : out std_logic_vector(7 downto 0);
    uPort3StatRxRsfecUncorrectedCwInc    : out std_logic;

    ---------------------------- Core Reset Status -----------------------------
    -- The following signal is REQUIRED to be in the UserClk domain:
    uPort3UserClkResetOut  : out std_logic;

    -------------------------------------------------------------------------
    -- Port8
    -------------------------------------------------------------------------

    ------------------------ AXI Stream TX Interface ------------------------
    -- The following signals are REQUIRED to be in the UserClk domain:
    uPort8TxTData0     : in  std_logic_vector(63 downto 0);
    uPort8TxTData1     : in  std_logic_vector(63 downto 0);
    uPort8TxTData2     : in  std_logic_vector(63 downto 0);
    uPort8TxTData3     : in  std_logic_vector(63 downto 0);
    uPort8TxTData4     : in  std_logic_vector(63 downto 0);
    uPort8TxTData5     : in  std_logic_vector(63 downto 0);
    uPort8TxTData6     : in  std_logic_vector(63 downto 0);
    uPort8TxTData7     : in  std_logic_vector(63 downto 0);
    uPort8TxTKeep      : in  std_logic_vector(63 downto 0);
    uPort8TxTLast      : in  std_logic;
    uPort8TxTUser      : in  std_logic;
    uPort8TxTValid     : in  std_logic;
    uPort8TxTReady     : out std_logic;

    ------------------------ AXI Stream RX Interface ------------------------
    -- The following signals are REQUIRED to be in the UserClk domain:
    uPort8RxTData0     : out std_logic_vector(63 downto 0);
    uPort8RxTData1     : out std_logic_vector(63 downto 0);
    uPort8RxTData2     : out std_logic_vector(63 downto 0);
    uPort8RxTData3     : out std_logic_vector(63 downto 0);
    uPort8RxTData4     : out std_logic_vector(63 downto 0);
    uPort8RxTData5     : out std_logic_vector(63 downto 0);
    uPort8RxTData6     : out std_logic_vector(63 downto 0);
    uPort8RxTData7     : out std_logic_vector(63 downto 0);
    uPort8RxTKeep      : out std_logic_vector(63 downto 0);
    uPort8RxTUser      : out std_logic; -- 1 indicates a bad packet
    uPort8RxTLast      : out std_logic;
    uPort8RxTValid     : out std_logic;
    -- There is no RxTReady signal support by the Ethernet100G IP. Received data has to
    -- be read immediately or it is lost.

    ----------------------------- Flow Control ------------------------------
    uPort8CtlRxPauseEnable        : in  std_logic_vector(8 downto 0);
    uPort8CtlRxEnableGcp          : in  std_logic;
    uPort8CtlRxCheckMcastGcp      : in  std_logic;
    uPort8CtlRxCheckUcastGcp      : in  std_logic;
    uPort8CtlRxCheckSaGcp         : in  std_logic;
    uPort8CtlRxCheckEtypeGcp      : in  std_logic;
    uPort8CtlRxCheckOpcodeGcp     : in  std_logic;
    uPort8CtlRxEnablePcp          : in  std_logic;
    uPort8CtlRxCheckMcastPcp      : in  std_logic;
    uPort8CtlRxCheckUcastPcp      : in  std_logic;
    uPort8CtlRxCheckSaPcp         : in  std_logic;
    uPort8CtlRxCheckEtypePcp      : in  std_logic;
    uPort8CtlRxCheckOpcodePcp     : in  std_logic;
    uPort8CtlRxEnableGpp          : in  std_logic;
    uPort8CtlRxCheckMcastGpp      : in  std_logic;
    uPort8CtlRxCheckUcastGpp      : in  std_logic;
    uPort8CtlRxCheckSaGpp         : in  std_logic;
    uPort8CtlRxCheckEtypeGpp      : in  std_logic;
    uPort8CtlRxCheckOpcodeGpp     : in  std_logic;
    uPort8CtlRxEnablePpp          : in  std_logic;
    uPort8CtlRxCheckMcastPpp      : in  std_logic;
    uPort8CtlRxCheckUcastPpp      : in  std_logic;
    uPort8CtlRxCheckSaPpp         : in  std_logic;
    uPort8CtlRxCheckEtypePpp      : in  std_logic;
    uPort8CtlRxCheckOpcodePpp     : in  std_logic;
    uPort8StatRxPauseReq          : out std_logic_vector(8 downto 0);
    uPort8CtlRxPauseAck           : in  std_logic_vector(8 downto 0);
    uPort8StatRxPauseValid        : out std_logic_vector(8 downto 0);
    uPort8StatRxPauseQanta0       : out std_logic_vector(15 downto 0);
    uPort8StatRxPauseQanta1       : out std_logic_vector(15 downto 0);
    uPort8StatRxPauseQanta2       : out std_logic_vector(15 downto 0);
    uPort8StatRxPauseQanta3       : out std_logic_vector(15 downto 0);
    uPort8StatRxPauseQanta4       : out std_logic_vector(15 downto 0);
    uPort8StatRxPauseQanta5       : out std_logic_vector(15 downto 0);
    uPort8StatRxPauseQanta6       : out std_logic_vector(15 downto 0);
    uPort8StatRxPauseQanta7       : out std_logic_vector(15 downto 0);
    uPort8StatRxPauseQanta8       : out std_logic_vector(15 downto 0);

    uPort8CtlTxPauseEnable        : in  std_logic_vector(8 downto 0);
    uPort8CtlTxPauseReq           : in  std_logic_vector(8 downto 0);
    uPort8CtlTxPauseQuanta0       : in  std_logic_vector(15 downto 0);
    uPort8CtlTxPauseQuanta1       : in  std_logic_vector(15 downto 0);
    uPort8CtlTxPauseQuanta2       : in  std_logic_vector(15 downto 0);
    uPort8CtlTxPauseQuanta3       : in  std_logic_vector(15 downto 0);
    uPort8CtlTxPauseQuanta4       : in  std_logic_vector(15 downto 0);
    uPort8CtlTxPauseQuanta5       : in  std_logic_vector(15 downto 0);
    uPort8CtlTxPauseQuanta6       : in  std_logic_vector(15 downto 0);
    uPort8CtlTxPauseQuanta7       : in  std_logic_vector(15 downto 0);
    uPort8CtlTxPauseQuanta8       : in  std_logic_vector(15 downto 0);
    uPort8CtlTxPauseRefreshTimer0 : in  std_logic_vector(15 downto 0);
    uPort8CtlTxPauseRefreshTimer1 : in  std_logic_vector(15 downto 0);
    uPort8CtlTxPauseRefreshTimer2 : in  std_logic_vector(15 downto 0);
    uPort8CtlTxPauseRefreshTimer3 : in  std_logic_vector(15 downto 0);
    uPort8CtlTxPauseRefreshTimer4 : in  std_logic_vector(15 downto 0);
    uPort8CtlTxPauseRefreshTimer5 : in  std_logic_vector(15 downto 0);
    uPort8CtlTxPauseRefreshTimer6 : in  std_logic_vector(15 downto 0);
    uPort8CtlTxPauseRefreshTimer7 : in  std_logic_vector(15 downto 0);
    uPort8CtlTxPauseRefreshTimer8 : in  std_logic_vector(15 downto 0);
    uPort8CtlTxResendPause        : in  std_logic;
    uPort8StatTxPauseValid        : out std_logic_vector(8 downto 0);

    ------------------------------- IEEE 1588 -------------------------------
    uPort8CtlRxSystemtimerinHigh         : in  std_logic_vector(15 downto 0);
    uPort8CtlRxSystemtimerinLow          : in  std_logic_vector(63 downto 0);
    uPort8CtlTxSystemtimerinHigh         : in  std_logic_vector(15 downto 0);
    uPort8CtlTxSystemtimerinLow          : in  std_logic_vector(63 downto 0);
    uPort8RxLaneAlignerFill0             : out std_logic_vector(6 downto 0);
    uPort8RxLaneAlignerFill1             : out std_logic_vector(6 downto 0);
    uPort8RxLaneAlignerFill10            : out std_logic_vector(6 downto 0);
    uPort8RxLaneAlignerFill11            : out std_logic_vector(6 downto 0);
    uPort8RxLaneAlignerFill12            : out std_logic_vector(6 downto 0);
    uPort8RxLaneAlignerFill13            : out std_logic_vector(6 downto 0);
    uPort8RxLaneAlignerFill14            : out std_logic_vector(6 downto 0);
    uPort8RxLaneAlignerFill15            : out std_logic_vector(6 downto 0);
    uPort8RxLaneAlignerFill16            : out std_logic_vector(6 downto 0);
    uPort8RxLaneAlignerFill17            : out std_logic_vector(6 downto 0);
    uPort8RxLaneAlignerFill18            : out std_logic_vector(6 downto 0);
    uPort8RxLaneAlignerFill19            : out std_logic_vector(6 downto 0);
    uPort8RxLaneAlignerFill2             : out std_logic_vector(6 downto 0);
    uPort8RxLaneAlignerFill3             : out std_logic_vector(6 downto 0);
    uPort8RxLaneAlignerFill4             : out std_logic_vector(6 downto 0);
    uPort8RxLaneAlignerFill5             : out std_logic_vector(6 downto 0);
    uPort8RxLaneAlignerFill6             : out std_logic_vector(6 downto 0);
    uPort8RxLaneAlignerFill7             : out std_logic_vector(6 downto 0);
    uPort8RxLaneAlignerFill8             : out std_logic_vector(6 downto 0);
    uPort8RxLaneAlignerFill9             : out std_logic_vector(6 downto 0);
    uPort8RxPtpPcslaneOut                : out std_logic_vector(4 downto 0);
    uPort8RxPtpTstampOutHigh             : out std_logic_vector(15 downto 0);
    uPort8RxPtpTstampOutLow              : out std_logic_vector(63 downto 0);
    uPort8StatTxPtpFifoReadError         : out std_logic;
    uPort8StatTxPtpFifoWriteError        : out std_logic;
    uPort8TxPtp1588opIn                  : in  std_logic_vector(1 downto 0);
    uPort8TxPtpPcslaneOut                : out std_logic_vector(4 downto 0);
    uPort8TxPtpTagFieldIn                : in  std_logic_vector(15 downto 0);
    uPort8TxPtpTstampOutHigh             : out std_logic_vector(15 downto 0);
    uPort8TxPtpTstampOutLow              : out std_logic_vector(63 downto 0);
    uPort8TxPtpTstampTagOut              : out std_logic_vector(15 downto 0);
    uPort8TxPtpTstampValidOut            : out std_logic;

    -------------------------------- Status ---------------------------------
    uPort8StatRxRsfecAmLock0             : out std_logic;
    uPort8StatRxRsfecAmLock1             : out std_logic;
    uPort8StatRxRsfecAmLock2             : out std_logic;
    uPort8StatRxRsfecAmLock3             : out std_logic;
    uPort8StatRxRsfecCorrectedCwInc      : out std_logic;
    uPort8StatRxRsfecCwInc               : out std_logic;
    uPort8StatRxRsfecErrCount0Inc        : out std_logic_vector(2 downto 0);
    uPort8StatRxRsfecErrCount1Inc        : out std_logic_vector(2 downto 0);
    uPort8StatRxRsfecErrCount2Inc        : out std_logic_vector(2 downto 0);
    uPort8StatRxRsfecErrCount3Inc        : out std_logic_vector(2 downto 0);
    uPort8StatRxRsfecHiSer               : out std_logic;
    uPort8StatRxRsfecLaneAlignmentStatus : out std_logic;
    uPort8StatRxRsfecLaneFill0           : out std_logic_vector(13 downto 0);
    uPort8StatRxRsfecLaneFill1           : out std_logic_vector(13 downto 0);
    uPort8StatRxRsfecLaneFill2           : out std_logic_vector(13 downto 0);
    uPort8StatRxRsfecLaneFill3           : out std_logic_vector(13 downto 0);
    uPort8StatRxRsfecLaneMapping         : out std_logic_vector(7 downto 0);
    uPort8StatRxRsfecUncorrectedCwInc    : out std_logic;

    ---------------------------- Core Reset Status -----------------------------
    -- The following signal is REQUIRED to be in the UserClk domain:
    uPort8UserClkResetOut  : out std_logic;

    -------------------------------------------------------------------------
    -- Port10
    -------------------------------------------------------------------------

    ------------------------ AXI Stream TX Interface ------------------------
    -- The following signals are REQUIRED to be in the UserClk domain:
    uPort10TxTData0     : in  std_logic_vector(63 downto 0);
    uPort10TxTData1     : in  std_logic_vector(63 downto 0);
    uPort10TxTData2     : in  std_logic_vector(63 downto 0);
    uPort10TxTData3     : in  std_logic_vector(63 downto 0);
    uPort10TxTData4     : in  std_logic_vector(63 downto 0);
    uPort10TxTData5     : in  std_logic_vector(63 downto 0);
    uPort10TxTData6     : in  std_logic_vector(63 downto 0);
    uPort10TxTData7     : in  std_logic_vector(63 downto 0);
    uPort10TxTKeep      : in  std_logic_vector(63 downto 0);
    uPort10TxTLast      : in  std_logic;
    uPort10TxTUser      : in  std_logic;
    uPort10TxTValid     : in  std_logic;
    uPort10TxTReady     : out std_logic;

    ------------------------ AXI Stream RX Interface ------------------------
    -- The following signals are REQUIRED to be in the UserClk domain:
    uPort10RxTData0     : out std_logic_vector(63 downto 0);
    uPort10RxTData1     : out std_logic_vector(63 downto 0);
    uPort10RxTData2     : out std_logic_vector(63 downto 0);
    uPort10RxTData3     : out std_logic_vector(63 downto 0);
    uPort10RxTData4     : out std_logic_vector(63 downto 0);
    uPort10RxTData5     : out std_logic_vector(63 downto 0);
    uPort10RxTData6     : out std_logic_vector(63 downto 0);
    uPort10RxTData7     : out std_logic_vector(63 downto 0);
    uPort10RxTKeep      : out std_logic_vector(63 downto 0);
    uPort10RxTUser      : out std_logic; -- 1 indicates a bad packet
    uPort10RxTLast      : out std_logic;
    uPort10RxTValid     : out std_logic;
    -- There is no RxTReady signal support by the Ethernet100G IP. Received data has to
    -- be read immediately or it is lost.

    ----------------------------- Flow Control ------------------------------
    uPort10CtlRxPauseEnable        : in  std_logic_vector(8 downto 0);
    uPort10CtlRxEnableGcp          : in  std_logic;
    uPort10CtlRxCheckMcastGcp      : in  std_logic;
    uPort10CtlRxCheckUcastGcp      : in  std_logic;
    uPort10CtlRxCheckSaGcp         : in  std_logic;
    uPort10CtlRxCheckEtypeGcp      : in  std_logic;
    uPort10CtlRxCheckOpcodeGcp     : in  std_logic;
    uPort10CtlRxEnablePcp          : in  std_logic;
    uPort10CtlRxCheckMcastPcp      : in  std_logic;
    uPort10CtlRxCheckUcastPcp      : in  std_logic;
    uPort10CtlRxCheckSaPcp         : in  std_logic;
    uPort10CtlRxCheckEtypePcp      : in  std_logic;
    uPort10CtlRxCheckOpcodePcp     : in  std_logic;
    uPort10CtlRxEnableGpp          : in  std_logic;
    uPort10CtlRxCheckMcastGpp      : in  std_logic;
    uPort10CtlRxCheckUcastGpp      : in  std_logic;
    uPort10CtlRxCheckSaGpp         : in  std_logic;
    uPort10CtlRxCheckEtypeGpp      : in  std_logic;
    uPort10CtlRxCheckOpcodeGpp     : in  std_logic;
    uPort10CtlRxEnablePpp          : in  std_logic;
    uPort10CtlRxCheckMcastPpp      : in  std_logic;
    uPort10CtlRxCheckUcastPpp      : in  std_logic;
    uPort10CtlRxCheckSaPpp         : in  std_logic;
    uPort10CtlRxCheckEtypePpp      : in  std_logic;
    uPort10CtlRxCheckOpcodePpp     : in  std_logic;
    uPort10StatRxPauseReq          : out std_logic_vector(8 downto 0);
    uPort10CtlRxPauseAck           : in  std_logic_vector(8 downto 0);
    uPort10StatRxPauseValid        : out std_logic_vector(8 downto 0);
    uPort10StatRxPauseQanta0       : out std_logic_vector(15 downto 0);
    uPort10StatRxPauseQanta1       : out std_logic_vector(15 downto 0);
    uPort10StatRxPauseQanta2       : out std_logic_vector(15 downto 0);
    uPort10StatRxPauseQanta3       : out std_logic_vector(15 downto 0);
    uPort10StatRxPauseQanta4       : out std_logic_vector(15 downto 0);
    uPort10StatRxPauseQanta5       : out std_logic_vector(15 downto 0);
    uPort10StatRxPauseQanta6       : out std_logic_vector(15 downto 0);
    uPort10StatRxPauseQanta7       : out std_logic_vector(15 downto 0);
    uPort10StatRxPauseQanta8       : out std_logic_vector(15 downto 0);

    uPort10CtlTxPauseEnable        : in  std_logic_vector(8 downto 0);
    uPort10CtlTxPauseReq           : in  std_logic_vector(8 downto 0);
    uPort10CtlTxPauseQuanta0       : in  std_logic_vector(15 downto 0);
    uPort10CtlTxPauseQuanta1       : in  std_logic_vector(15 downto 0);
    uPort10CtlTxPauseQuanta2       : in  std_logic_vector(15 downto 0);
    uPort10CtlTxPauseQuanta3       : in  std_logic_vector(15 downto 0);
    uPort10CtlTxPauseQuanta4       : in  std_logic_vector(15 downto 0);
    uPort10CtlTxPauseQuanta5       : in  std_logic_vector(15 downto 0);
    uPort10CtlTxPauseQuanta6       : in  std_logic_vector(15 downto 0);
    uPort10CtlTxPauseQuanta7       : in  std_logic_vector(15 downto 0);
    uPort10CtlTxPauseQuanta8       : in  std_logic_vector(15 downto 0);
    uPort10CtlTxPauseRefreshTimer0 : in  std_logic_vector(15 downto 0);
    uPort10CtlTxPauseRefreshTimer1 : in  std_logic_vector(15 downto 0);
    uPort10CtlTxPauseRefreshTimer2 : in  std_logic_vector(15 downto 0);
    uPort10CtlTxPauseRefreshTimer3 : in  std_logic_vector(15 downto 0);
    uPort10CtlTxPauseRefreshTimer4 : in  std_logic_vector(15 downto 0);
    uPort10CtlTxPauseRefreshTimer5 : in  std_logic_vector(15 downto 0);
    uPort10CtlTxPauseRefreshTimer6 : in  std_logic_vector(15 downto 0);
    uPort10CtlTxPauseRefreshTimer7 : in  std_logic_vector(15 downto 0);
    uPort10CtlTxPauseRefreshTimer8 : in  std_logic_vector(15 downto 0);
    uPort10CtlTxResendPause        : in  std_logic;
    uPort10StatTxPauseValid        : out std_logic_vector(8 downto 0);

    ------------------------------- IEEE 1588 -------------------------------
    uPort10CtlRxSystemtimerinHigh         : in  std_logic_vector(15 downto 0);
    uPort10CtlRxSystemtimerinLow          : in  std_logic_vector(63 downto 0);
    uPort10CtlTxSystemtimerinHigh         : in  std_logic_vector(15 downto 0);
    uPort10CtlTxSystemtimerinLow          : in  std_logic_vector(63 downto 0);
    uPort10RxLaneAlignerFill0             : out std_logic_vector(6 downto 0);
    uPort10RxLaneAlignerFill1             : out std_logic_vector(6 downto 0);
    uPort10RxLaneAlignerFill10            : out std_logic_vector(6 downto 0);
    uPort10RxLaneAlignerFill11            : out std_logic_vector(6 downto 0);
    uPort10RxLaneAlignerFill12            : out std_logic_vector(6 downto 0);
    uPort10RxLaneAlignerFill13            : out std_logic_vector(6 downto 0);
    uPort10RxLaneAlignerFill14            : out std_logic_vector(6 downto 0);
    uPort10RxLaneAlignerFill15            : out std_logic_vector(6 downto 0);
    uPort10RxLaneAlignerFill16            : out std_logic_vector(6 downto 0);
    uPort10RxLaneAlignerFill17            : out std_logic_vector(6 downto 0);
    uPort10RxLaneAlignerFill18            : out std_logic_vector(6 downto 0);
    uPort10RxLaneAlignerFill19            : out std_logic_vector(6 downto 0);
    uPort10RxLaneAlignerFill2             : out std_logic_vector(6 downto 0);
    uPort10RxLaneAlignerFill3             : out std_logic_vector(6 downto 0);
    uPort10RxLaneAlignerFill4             : out std_logic_vector(6 downto 0);
    uPort10RxLaneAlignerFill5             : out std_logic_vector(6 downto 0);
    uPort10RxLaneAlignerFill6             : out std_logic_vector(6 downto 0);
    uPort10RxLaneAlignerFill7             : out std_logic_vector(6 downto 0);
    uPort10RxLaneAlignerFill8             : out std_logic_vector(6 downto 0);
    uPort10RxLaneAlignerFill9             : out std_logic_vector(6 downto 0);
    uPort10RxPtpPcslaneOut                : out std_logic_vector(4 downto 0);
    uPort10RxPtpTstampOutHigh             : out std_logic_vector(15 downto 0);
    uPort10RxPtpTstampOutLow              : out std_logic_vector(63 downto 0);
    uPort10StatTxPtpFifoReadError         : out std_logic;
    uPort10StatTxPtpFifoWriteError        : out std_logic;
    uPort10TxPtp1588opIn                  : in  std_logic_vector(1 downto 0);
    uPort10TxPtpPcslaneOut                : out std_logic_vector(4 downto 0);
    uPort10TxPtpTagFieldIn                : in  std_logic_vector(15 downto 0);
    uPort10TxPtpTstampOutHigh             : out std_logic_vector(15 downto 0);
    uPort10TxPtpTstampOutLow              : out std_logic_vector(63 downto 0);
    uPort10TxPtpTstampTagOut              : out std_logic_vector(15 downto 0);
    uPort10TxPtpTstampValidOut            : out std_logic;

    -------------------------------- Status ---------------------------------
    uPort10StatRxRsfecAmLock0             : out std_logic;
    uPort10StatRxRsfecAmLock1             : out std_logic;
    uPort10StatRxRsfecAmLock2             : out std_logic;
    uPort10StatRxRsfecAmLock3             : out std_logic;
    uPort10StatRxRsfecCorrectedCwInc      : out std_logic;
    uPort10StatRxRsfecCwInc               : out std_logic;
    uPort10StatRxRsfecErrCount0Inc        : out std_logic_vector(2 downto 0);
    uPort10StatRxRsfecErrCount1Inc        : out std_logic_vector(2 downto 0);
    uPort10StatRxRsfecErrCount2Inc        : out std_logic_vector(2 downto 0);
    uPort10StatRxRsfecErrCount3Inc        : out std_logic_vector(2 downto 0);
    uPort10StatRxRsfecHiSer               : out std_logic;
    uPort10StatRxRsfecLaneAlignmentStatus : out std_logic;
    uPort10StatRxRsfecLaneFill0           : out std_logic_vector(13 downto 0);
    uPort10StatRxRsfecLaneFill1           : out std_logic_vector(13 downto 0);
    uPort10StatRxRsfecLaneFill2           : out std_logic_vector(13 downto 0);
    uPort10StatRxRsfecLaneFill3           : out std_logic_vector(13 downto 0);
    uPort10StatRxRsfecLaneMapping         : out std_logic_vector(7 downto 0);
    uPort10StatRxRsfecUncorrectedCwInc    : out std_logic;

    ---------------------------- Core Reset Status -----------------------------
    -- The following signal is REQUIRED to be in the UserClk domain:
    uPort10UserClkResetOut  : out std_logic;

    -------------------------------------------------------------------------
    -- Port11
    -------------------------------------------------------------------------

    ------------------------ AXI Stream TX Interface ------------------------
    -- The following signals are REQUIRED to be in the UserClk domain:
    uPort11TxTData0     : in  std_logic_vector(63 downto 0);
    uPort11TxTData1     : in  std_logic_vector(63 downto 0);
    uPort11TxTData2     : in  std_logic_vector(63 downto 0);
    uPort11TxTData3     : in  std_logic_vector(63 downto 0);
    uPort11TxTData4     : in  std_logic_vector(63 downto 0);
    uPort11TxTData5     : in  std_logic_vector(63 downto 0);
    uPort11TxTData6     : in  std_logic_vector(63 downto 0);
    uPort11TxTData7     : in  std_logic_vector(63 downto 0);
    uPort11TxTKeep      : in  std_logic_vector(63 downto 0);
    uPort11TxTLast      : in  std_logic;
    uPort11TxTUser      : in  std_logic;
    uPort11TxTValid     : in  std_logic;
    uPort11TxTReady     : out std_logic;

    ------------------------ AXI Stream RX Interface ------------------------
    -- The following signals are REQUIRED to be in the UserClk domain:
    uPort11RxTData0     : out std_logic_vector(63 downto 0);
    uPort11RxTData1     : out std_logic_vector(63 downto 0);
    uPort11RxTData2     : out std_logic_vector(63 downto 0);
    uPort11RxTData3     : out std_logic_vector(63 downto 0);
    uPort11RxTData4     : out std_logic_vector(63 downto 0);
    uPort11RxTData5     : out std_logic_vector(63 downto 0);
    uPort11RxTData6     : out std_logic_vector(63 downto 0);
    uPort11RxTData7     : out std_logic_vector(63 downto 0);
    uPort11RxTKeep      : out std_logic_vector(63 downto 0);
    uPort11RxTUser      : out std_logic; -- 1 indicates a bad packet
    uPort11RxTLast      : out std_logic;
    uPort11RxTValid     : out std_logic;
    -- There is no RxTReady signal support by the Ethernet100G IP. Received data has to
    -- be read immediately or it is lost.

    ----------------------------- Flow Control ------------------------------
    uPort11CtlRxPauseEnable        : in  std_logic_vector(8 downto 0);
    uPort11CtlRxEnableGcp          : in  std_logic;
    uPort11CtlRxCheckMcastGcp      : in  std_logic;
    uPort11CtlRxCheckUcastGcp      : in  std_logic;
    uPort11CtlRxCheckSaGcp         : in  std_logic;
    uPort11CtlRxCheckEtypeGcp      : in  std_logic;
    uPort11CtlRxCheckOpcodeGcp     : in  std_logic;
    uPort11CtlRxEnablePcp          : in  std_logic;
    uPort11CtlRxCheckMcastPcp      : in  std_logic;
    uPort11CtlRxCheckUcastPcp      : in  std_logic;
    uPort11CtlRxCheckSaPcp         : in  std_logic;
    uPort11CtlRxCheckEtypePcp      : in  std_logic;
    uPort11CtlRxCheckOpcodePcp     : in  std_logic;
    uPort11CtlRxEnableGpp          : in  std_logic;
    uPort11CtlRxCheckMcastGpp      : in  std_logic;
    uPort11CtlRxCheckUcastGpp      : in  std_logic;
    uPort11CtlRxCheckSaGpp         : in  std_logic;
    uPort11CtlRxCheckEtypeGpp      : in  std_logic;
    uPort11CtlRxCheckOpcodeGpp     : in  std_logic;
    uPort11CtlRxEnablePpp          : in  std_logic;
    uPort11CtlRxCheckMcastPpp      : in  std_logic;
    uPort11CtlRxCheckUcastPpp      : in  std_logic;
    uPort11CtlRxCheckSaPpp         : in  std_logic;
    uPort11CtlRxCheckEtypePpp      : in  std_logic;
    uPort11CtlRxCheckOpcodePpp     : in  std_logic;
    uPort11StatRxPauseReq          : out std_logic_vector(8 downto 0);
    uPort11CtlRxPauseAck           : in  std_logic_vector(8 downto 0);
    uPort11StatRxPauseValid        : out std_logic_vector(8 downto 0);
    uPort11StatRxPauseQanta0       : out std_logic_vector(15 downto 0);
    uPort11StatRxPauseQanta1       : out std_logic_vector(15 downto 0);
    uPort11StatRxPauseQanta2       : out std_logic_vector(15 downto 0);
    uPort11StatRxPauseQanta3       : out std_logic_vector(15 downto 0);
    uPort11StatRxPauseQanta4       : out std_logic_vector(15 downto 0);
    uPort11StatRxPauseQanta5       : out std_logic_vector(15 downto 0);
    uPort11StatRxPauseQanta6       : out std_logic_vector(15 downto 0);
    uPort11StatRxPauseQanta7       : out std_logic_vector(15 downto 0);
    uPort11StatRxPauseQanta8       : out std_logic_vector(15 downto 0);

    uPort11CtlTxPauseEnable        : in  std_logic_vector(8 downto 0);
    uPort11CtlTxPauseReq           : in  std_logic_vector(8 downto 0);
    uPort11CtlTxPauseQuanta0       : in  std_logic_vector(15 downto 0);
    uPort11CtlTxPauseQuanta1       : in  std_logic_vector(15 downto 0);
    uPort11CtlTxPauseQuanta2       : in  std_logic_vector(15 downto 0);
    uPort11CtlTxPauseQuanta3       : in  std_logic_vector(15 downto 0);
    uPort11CtlTxPauseQuanta4       : in  std_logic_vector(15 downto 0);
    uPort11CtlTxPauseQuanta5       : in  std_logic_vector(15 downto 0);
    uPort11CtlTxPauseQuanta6       : in  std_logic_vector(15 downto 0);
    uPort11CtlTxPauseQuanta7       : in  std_logic_vector(15 downto 0);
    uPort11CtlTxPauseQuanta8       : in  std_logic_vector(15 downto 0);
    uPort11CtlTxPauseRefreshTimer0 : in  std_logic_vector(15 downto 0);
    uPort11CtlTxPauseRefreshTimer1 : in  std_logic_vector(15 downto 0);
    uPort11CtlTxPauseRefreshTimer2 : in  std_logic_vector(15 downto 0);
    uPort11CtlTxPauseRefreshTimer3 : in  std_logic_vector(15 downto 0);
    uPort11CtlTxPauseRefreshTimer4 : in  std_logic_vector(15 downto 0);
    uPort11CtlTxPauseRefreshTimer5 : in  std_logic_vector(15 downto 0);
    uPort11CtlTxPauseRefreshTimer6 : in  std_logic_vector(15 downto 0);
    uPort11CtlTxPauseRefreshTimer7 : in  std_logic_vector(15 downto 0);
    uPort11CtlTxPauseRefreshTimer8 : in  std_logic_vector(15 downto 0);
    uPort11CtlTxResendPause        : in  std_logic;
    uPort11StatTxPauseValid        : out std_logic_vector(8 downto 0);

    ------------------------------- IEEE 1588 -------------------------------
    uPort11CtlRxSystemtimerinHigh         : in  std_logic_vector(15 downto 0);
    uPort11CtlRxSystemtimerinLow          : in  std_logic_vector(63 downto 0);
    uPort11CtlTxSystemtimerinHigh         : in  std_logic_vector(15 downto 0);
    uPort11CtlTxSystemtimerinLow          : in  std_logic_vector(63 downto 0);
    uPort11RxLaneAlignerFill0             : out std_logic_vector(6 downto 0);
    uPort11RxLaneAlignerFill1             : out std_logic_vector(6 downto 0);
    uPort11RxLaneAlignerFill10            : out std_logic_vector(6 downto 0);
    uPort11RxLaneAlignerFill11            : out std_logic_vector(6 downto 0);
    uPort11RxLaneAlignerFill12            : out std_logic_vector(6 downto 0);
    uPort11RxLaneAlignerFill13            : out std_logic_vector(6 downto 0);
    uPort11RxLaneAlignerFill14            : out std_logic_vector(6 downto 0);
    uPort11RxLaneAlignerFill15            : out std_logic_vector(6 downto 0);
    uPort11RxLaneAlignerFill16            : out std_logic_vector(6 downto 0);
    uPort11RxLaneAlignerFill17            : out std_logic_vector(6 downto 0);
    uPort11RxLaneAlignerFill18            : out std_logic_vector(6 downto 0);
    uPort11RxLaneAlignerFill19            : out std_logic_vector(6 downto 0);
    uPort11RxLaneAlignerFill2             : out std_logic_vector(6 downto 0);
    uPort11RxLaneAlignerFill3             : out std_logic_vector(6 downto 0);
    uPort11RxLaneAlignerFill4             : out std_logic_vector(6 downto 0);
    uPort11RxLaneAlignerFill5             : out std_logic_vector(6 downto 0);
    uPort11RxLaneAlignerFill6             : out std_logic_vector(6 downto 0);
    uPort11RxLaneAlignerFill7             : out std_logic_vector(6 downto 0);
    uPort11RxLaneAlignerFill8             : out std_logic_vector(6 downto 0);
    uPort11RxLaneAlignerFill9             : out std_logic_vector(6 downto 0);
    uPort11RxPtpPcslaneOut                : out std_logic_vector(4 downto 0);
    uPort11RxPtpTstampOutHigh             : out std_logic_vector(15 downto 0);
    uPort11RxPtpTstampOutLow              : out std_logic_vector(63 downto 0);
    uPort11StatTxPtpFifoReadError         : out std_logic;
    uPort11StatTxPtpFifoWriteError        : out std_logic;
    uPort11TxPtp1588opIn                  : in  std_logic_vector(1 downto 0);
    uPort11TxPtpPcslaneOut                : out std_logic_vector(4 downto 0);
    uPort11TxPtpTagFieldIn                : in  std_logic_vector(15 downto 0);
    uPort11TxPtpTstampOutHigh             : out std_logic_vector(15 downto 0);
    uPort11TxPtpTstampOutLow              : out std_logic_vector(63 downto 0);
    uPort11TxPtpTstampTagOut              : out std_logic_vector(15 downto 0);
    uPort11TxPtpTstampValidOut            : out std_logic;

    -------------------------------- Status ---------------------------------
    uPort11StatRxRsfecAmLock0             : out std_logic;
    uPort11StatRxRsfecAmLock1             : out std_logic;
    uPort11StatRxRsfecAmLock2             : out std_logic;
    uPort11StatRxRsfecAmLock3             : out std_logic;
    uPort11StatRxRsfecCorrectedCwInc      : out std_logic;
    uPort11StatRxRsfecCwInc               : out std_logic;
    uPort11StatRxRsfecErrCount0Inc        : out std_logic_vector(2 downto 0);
    uPort11StatRxRsfecErrCount1Inc        : out std_logic_vector(2 downto 0);
    uPort11StatRxRsfecErrCount2Inc        : out std_logic_vector(2 downto 0);
    uPort11StatRxRsfecErrCount3Inc        : out std_logic_vector(2 downto 0);
    uPort11StatRxRsfecHiSer               : out std_logic;
    uPort11StatRxRsfecLaneAlignmentStatus : out std_logic;
    uPort11StatRxRsfecLaneFill0           : out std_logic_vector(13 downto 0);
    uPort11StatRxRsfecLaneFill1           : out std_logic_vector(13 downto 0);
    uPort11StatRxRsfecLaneFill2           : out std_logic_vector(13 downto 0);
    uPort11StatRxRsfecLaneFill3           : out std_logic_vector(13 downto 0);
    uPort11StatRxRsfecLaneMapping         : out std_logic_vector(7 downto 0);
    uPort11StatRxRsfecUncorrectedCwInc    : out std_logic;

    ---------------------------- Core Reset Status -----------------------------
    -- The following signal is REQUIRED to be in the UserClk domain:
    uPort11UserClkResetOut  : out std_logic
  );
end PXIe7903_100GbE;

architecture rtl of PXIe7903_100GbE is

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

  -------------------------------------------------------------
  -- REQUIRED CLIP signals                                   --
  -------------------------------------------------------------
  signal xIoModuleReadyLcl : std_logic;
  signal xMgtRefClkEnabled : std_logic_vector(11 downto 0);
  signal aDioOutEn         : std_logic_vector(7 downto 0);

  -------------------------------------------------------------
  -- USER CLIP signals                                       --
  -------------------------------------------------------------
  signal aPort0Reset  : std_logic;
  signal aPort2Reset  : std_logic;
  signal aPort3Reset  : std_logic;
  signal aPort8Reset  : std_logic;
  signal aPort10Reset : std_logic;
  signal aPort11Reset : std_logic;

  -- DRP Signals
  constant kNumIPs : integer := 6;
  constant kDrpAddrSize : integer := 10; -- DRP address width
  constant kDrpDataSize : integer := 16; -- DRP address width

  signal dDrpAddr : std_logic_vector(kNumIPs*kDrpAddrSize-1 downto 0);
  signal dDrpDi   : std_logic_vector(kNumIPs*kDrpDataSize-1 downto 0);
  signal dDrpDo   : std_logic_vector(kNumIPs*kDrpDataSize-1 downto 0);
  signal dDrpRdy  : std_logic_vector(kNumIPs-1 downto 0);
  signal dDrpEn   : std_logic_vector(kNumIPs-1 downto 0);
  signal dDrpWe   : std_logic_vector(kNumIPs-1 downto 0);

begin
  -----------------------------
  -- 7903 Required Logic--
  -----------------------------
  -- !!! WARNING !!!
  -- Do not change this logic. Doing so may cause the CLIP to stop functioning.

  -- Configuration Netlist --
  --vhook SasquatchClipFixedLogic
  --vhook_a xIoModuleReady xIoModuleReadyLcl
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
      xIoModuleReady                  => xIoModuleReadyLcl,                --out std_logic
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

  xIoModuleReady <= xIoModuleReadyLcl;

  GenDioBuffers: for i in aDio'range generate
    aDio(i) <= aDioOut(i) when aDioOutEn(i) = '1' else 'Z';
  end generate GenDioBuffers;
  aDioIn <= aDio;

  -----------------------------------------------------------------------------
  -- AXI to DRP
  -----------------------------------------------------------------------------
  --vhook_e MgtTest_DRP_bridge
  --vhook_a kNUM_LANES kNumIPs
  --vhook_a kADDR_SIZE kDrpAddrSize
  --vhook_a gtwiz_drpclk      open
  --vhook_a gtwiz_drpaddr_in  dDrpAddr
  --vhook_a gtwiz_drpdi_in    dDrpDi
  --vhook_a gtwiz_drpdo_out   dDrpDo
  --vhook_a gtwiz_drpen_in    dDrpEn
  --vhook_a gtwiz_drpwe_in    dDrpWe
  --vhook_a gtwiz_drprdy_out  dDrpRdy
  --vhook_a s_aclk            AxiClk
  --vhook_a drp_s_axi_awaddr  xDrpAxiAwaddr
  --vhook_a drp_s_axi_awvalid xDrpAxiAwvalid
  --vhook_a drp_s_axi_awready xDrpAxiAwready
  --vhook_a drp_s_axi_wdata   xDrpAxiWdata
  --vhook_a drp_s_axi_wstrb   xDrpAxiWstrb
  --vhook_a drp_s_axi_wvalid  xDrpAxiWvalid
  --vhook_a drp_s_axi_wready  xDrpAxiWready
  --vhook_a drp_s_axi_bresp   xDrpAxiBresp
  --vhook_a drp_s_axi_bvalid  xDrpAxiBvalid
  --vhook_a drp_s_axi_bready  xDrpAxiBready
  --vhook_a drp_s_axi_araddr  xDrpAxiAraddr
  --vhook_a drp_s_axi_arvalid xDrpAxiArvalid
  --vhook_a drp_s_axi_arready xDrpAxiArready
  --vhook_a drp_s_axi_rdata   xDrpAxiRdata
  --vhook_a drp_s_axi_rresp   xDrpAxiRresp
  --vhook_a drp_s_axi_rvalid  xDrpAxiRvalid
  --vhook_a drp_s_axi_rready  xDrpAxiRready
  MgtTest_DRP_bridgex: entity work.MgtTest_DRP_bridge (rtl)
    generic map (
      kNUM_LANES => kNumIPs,       --integer:=4
      kADDR_SIZE => kDrpAddrSize)  --integer:=9
    port map (
      aResetSl          => aResetSl,        --in  std_logic
      gtwiz_drpclk      => open,            --out std_logic_vector(kNUM_LANES-1:0)
      gtwiz_drpaddr_in  => dDrpAddr,        --out std_logic_vector(kNUM_LANES*kADDR_SIZE-1:0)
      gtwiz_drpdi_in    => dDrpDi,          --out std_logic_vector(kNUM_LANES*16-1:0)
      gtwiz_drpdo_out   => dDrpDo,          --in  std_logic_vector(kNUM_LANES*16-1:0)
      gtwiz_drpen_in    => dDrpEn,          --out std_logic_vector(kNUM_LANES-1:0)
      gtwiz_drpwe_in    => dDrpWe,          --out std_logic_vector(kNUM_LANES-1:0)
      gtwiz_drprdy_out  => dDrpRdy,         --in  std_logic_vector(kNUM_LANES-1:0)
      s_aclk            => AxiClk,          --in  std_logic
      drp_s_axi_awaddr  => xDrpAxiAwaddr,   --in  std_logic_vector(31:0)
      drp_s_axi_awvalid => xDrpAxiAwvalid,  --in  std_logic
      drp_s_axi_awready => xDrpAxiAwready,  --out std_logic
      drp_s_axi_wdata   => xDrpAxiWdata,    --in  std_logic_vector(31:0)
      drp_s_axi_wstrb   => xDrpAxiWstrb,    --in  std_logic_vector(3:0)
      drp_s_axi_wvalid  => xDrpAxiWvalid,   --in  std_logic
      drp_s_axi_wready  => xDrpAxiWready,   --out std_logic
      drp_s_axi_bresp   => xDrpAxiBresp,    --out std_logic_vector(1:0)
      drp_s_axi_bvalid  => xDrpAxiBvalid,   --out std_logic
      drp_s_axi_bready  => xDrpAxiBready,   --in  std_logic
      drp_s_axi_araddr  => xDrpAxiAraddr,   --in  std_logic_vector(31:0)
      drp_s_axi_arvalid => xDrpAxiArvalid,  --in  std_logic
      drp_s_axi_arready => xDrpAxiArready,  --out std_logic
      drp_s_axi_rdata   => xDrpAxiRdata,    --out std_logic_vector(31:0)
      drp_s_axi_rresp   => xDrpAxiRresp,    --out std_logic_vector(1:0)
      drp_s_axi_rvalid  => xDrpAxiRvalid,   --out std_logic
      drp_s_axi_rready  => xDrpAxiRready);  --in  std_logic


  -----------------------------------------------------------------------------
  -- Port 0
  -----------------------------------------------------------------------------
  aPort0Reset  <= aResetSl or not xMgtRefClkEnabled(0);

  --vhook_e CmacCore CmacCore0
  --vhook_a aResetSl       aPort0Reset
  --vhook_a MgtRefClk_p    MgtRefClk_p(0)
  --vhook_a MgtRefClk_n    MgtRefClk_n(0)
  --vhook_a MgtPortRx_p    MgtPortRx_p(3 downto 0)
  --vhook_a MgtPortRx_n    MgtPortRx_n(3 downto 0)
  --vhook_a MgtPortTx_p    MgtPortTx_p(3 downto 0)
  --vhook_a MgtPortTx_n    MgtPortTx_n(3 downto 0)
  --vhook_a UserClk        UserClkPort0
  --vhook_a xCoreReady     xPort0CoreReady
  --vhook_a aRxPolarity    kRxIoModRxMgtPolarity(3 downto 0)
  --vhook_a aTxPolarity    kTxIoModTxMgtPolarity(3 downto 0)
  --vhook_a DrpClk         AxiClk
  --vhook_a dDrpAddr       dDrpAddr(kDrpAddrSize-1 downto 0)
  --vhook_a dDrpDi         dDrpDi(kDrpDataSize-1 downto 0)
  --vhook_a dDrpDo         dDrpDo(kDrpDataSize-1 downto 0)
  --vhook_a dDrpEn         dDrpEn(0)
  --vhook_a dDrpRdy        dDrpRdy(0)
  --vhook_a dDrpWe         dDrpWe(0)
  --vhook_af {u(.*)}       {uPort0$1}
  CmacCore0: entity work.CmacCore (rtl)
    port map (
      aResetSl                        => aPort0Reset,                           --in  std_logic
      MgtRefClk_p                     => MgtRefClk_p(0),                        --in  std_logic
      MgtRefClk_n                     => MgtRefClk_n(0),                        --in  std_logic
      MgtPortRx_p                     => MgtPortRx_p(3 downto 0),               --in  std_logic_vector(3:0)
      MgtPortRx_n                     => MgtPortRx_n(3 downto 0),               --in  std_logic_vector(3:0)
      MgtPortTx_p                     => MgtPortTx_p(3 downto 0),               --out std_logic_vector(3:0)
      MgtPortTx_n                     => MgtPortTx_n(3 downto 0),               --out std_logic_vector(3:0)
      AxiClk                          => AxiClk,                                --in  std_logic
      SysClk                          => SysClk,                                --in  std_logic
      UserClk                         => UserClkPort0,                          --out std_logic
      xCoreReady                      => xPort0CoreReady,                       --out std_logic
      uTxTData0                       => uPort0TxTData0,                        --in  std_logic_vector(63:0)
      uTxTData1                       => uPort0TxTData1,                        --in  std_logic_vector(63:0)
      uTxTData2                       => uPort0TxTData2,                        --in  std_logic_vector(63:0)
      uTxTData3                       => uPort0TxTData3,                        --in  std_logic_vector(63:0)
      uTxTData4                       => uPort0TxTData4,                        --in  std_logic_vector(63:0)
      uTxTData5                       => uPort0TxTData5,                        --in  std_logic_vector(63:0)
      uTxTData6                       => uPort0TxTData6,                        --in  std_logic_vector(63:0)
      uTxTData7                       => uPort0TxTData7,                        --in  std_logic_vector(63:0)
      uTxTKeep                        => uPort0TxTKeep,                         --in  std_logic_vector(63:0)
      uTxTLast                        => uPort0TxTLast,                         --in  std_logic
      uTxTUser                        => uPort0TxTUser,                         --in  std_logic
      uTxTValid                       => uPort0TxTValid,                        --in  std_logic
      uTxTReady                       => uPort0TxTReady,                        --out std_logic
      uRxTData0                       => uPort0RxTData0,                        --out std_logic_vector(63:0)
      uRxTData1                       => uPort0RxTData1,                        --out std_logic_vector(63:0)
      uRxTData2                       => uPort0RxTData2,                        --out std_logic_vector(63:0)
      uRxTData3                       => uPort0RxTData3,                        --out std_logic_vector(63:0)
      uRxTData4                       => uPort0RxTData4,                        --out std_logic_vector(63:0)
      uRxTData5                       => uPort0RxTData5,                        --out std_logic_vector(63:0)
      uRxTData6                       => uPort0RxTData6,                        --out std_logic_vector(63:0)
      uRxTData7                       => uPort0RxTData7,                        --out std_logic_vector(63:0)
      uRxTKeep                        => uPort0RxTKeep,                         --out std_logic_vector(63:0)
      uRxTUser                        => uPort0RxTUser,                         --out std_logic
      uRxTLast                        => uPort0RxTLast,                         --out std_logic
      uRxTValid                       => uPort0RxTValid,                        --out std_logic
      aRxPolarity                     => kRxIoModRxMgtPolarity(3 downto 0),     --in  std_logic_vector(3:0)
      aTxPolarity                     => kTxIoModTxMgtPolarity(3 downto 0),     --in  std_logic_vector(3:0)
      uCtlRxSystemtimerinHigh         => uPort0CtlRxSystemtimerinHigh,          --in  std_logic_vector(15:0)
      uCtlRxSystemtimerinLow          => uPort0CtlRxSystemtimerinLow,           --in  std_logic_vector(63:0)
      uCtlTxSystemtimerinHigh         => uPort0CtlTxSystemtimerinHigh,          --in  std_logic_vector(15:0)
      uCtlTxSystemtimerinLow          => uPort0CtlTxSystemtimerinLow,           --in  std_logic_vector(63:0)
      uRxLaneAlignerFill0             => uPort0RxLaneAlignerFill0,              --out std_logic_vector(6:0)
      uRxLaneAlignerFill1             => uPort0RxLaneAlignerFill1,              --out std_logic_vector(6:0)
      uRxLaneAlignerFill10            => uPort0RxLaneAlignerFill10,             --out std_logic_vector(6:0)
      uRxLaneAlignerFill11            => uPort0RxLaneAlignerFill11,             --out std_logic_vector(6:0)
      uRxLaneAlignerFill12            => uPort0RxLaneAlignerFill12,             --out std_logic_vector(6:0)
      uRxLaneAlignerFill13            => uPort0RxLaneAlignerFill13,             --out std_logic_vector(6:0)
      uRxLaneAlignerFill14            => uPort0RxLaneAlignerFill14,             --out std_logic_vector(6:0)
      uRxLaneAlignerFill15            => uPort0RxLaneAlignerFill15,             --out std_logic_vector(6:0)
      uRxLaneAlignerFill16            => uPort0RxLaneAlignerFill16,             --out std_logic_vector(6:0)
      uRxLaneAlignerFill17            => uPort0RxLaneAlignerFill17,             --out std_logic_vector(6:0)
      uRxLaneAlignerFill18            => uPort0RxLaneAlignerFill18,             --out std_logic_vector(6:0)
      uRxLaneAlignerFill19            => uPort0RxLaneAlignerFill19,             --out std_logic_vector(6:0)
      uRxLaneAlignerFill2             => uPort0RxLaneAlignerFill2,              --out std_logic_vector(6:0)
      uRxLaneAlignerFill3             => uPort0RxLaneAlignerFill3,              --out std_logic_vector(6:0)
      uRxLaneAlignerFill4             => uPort0RxLaneAlignerFill4,              --out std_logic_vector(6:0)
      uRxLaneAlignerFill5             => uPort0RxLaneAlignerFill5,              --out std_logic_vector(6:0)
      uRxLaneAlignerFill6             => uPort0RxLaneAlignerFill6,              --out std_logic_vector(6:0)
      uRxLaneAlignerFill7             => uPort0RxLaneAlignerFill7,              --out std_logic_vector(6:0)
      uRxLaneAlignerFill8             => uPort0RxLaneAlignerFill8,              --out std_logic_vector(6:0)
      uRxLaneAlignerFill9             => uPort0RxLaneAlignerFill9,              --out std_logic_vector(6:0)
      uRxPtpPcslaneOut                => uPort0RxPtpPcslaneOut,                 --out std_logic_vector(4:0)
      uRxPtpTstampOutHigh             => uPort0RxPtpTstampOutHigh,              --out std_logic_vector(15:0)
      uRxPtpTstampOutLow              => uPort0RxPtpTstampOutLow,               --out std_logic_vector(63:0)
      uStatTxPtpFifoReadError         => uPort0StatTxPtpFifoReadError,          --out std_logic
      uStatTxPtpFifoWriteError        => uPort0StatTxPtpFifoWriteError,         --out std_logic
      uTxPtp1588opIn                  => uPort0TxPtp1588opIn,                   --in  std_logic_vector(1:0)
      uTxPtpPcslaneOut                => uPort0TxPtpPcslaneOut,                 --out std_logic_vector(4:0)
      uTxPtpTagFieldIn                => uPort0TxPtpTagFieldIn,                 --in  std_logic_vector(15:0)
      uTxPtpTstampOutHigh             => uPort0TxPtpTstampOutHigh,              --out std_logic_vector(15:0)
      uTxPtpTstampOutLow              => uPort0TxPtpTstampOutLow,               --out std_logic_vector(63:0)
      uTxPtpTstampTagOut              => uPort0TxPtpTstampTagOut,               --out std_logic_vector(15:0)
      uTxPtpTstampValidOut            => uPort0TxPtpTstampValidOut,             --out std_logic
      uStatRxRsfecAmLock0             => uPort0StatRxRsfecAmLock0,              --out std_logic
      uStatRxRsfecAmLock1             => uPort0StatRxRsfecAmLock1,              --out std_logic
      uStatRxRsfecAmLock2             => uPort0StatRxRsfecAmLock2,              --out std_logic
      uStatRxRsfecAmLock3             => uPort0StatRxRsfecAmLock3,              --out std_logic
      uStatRxRsfecCorrectedCwInc      => uPort0StatRxRsfecCorrectedCwInc,       --out std_logic
      uStatRxRsfecCwInc               => uPort0StatRxRsfecCwInc,                --out std_logic
      uStatRxRsfecErrCount0Inc        => uPort0StatRxRsfecErrCount0Inc,         --out std_logic_vector(2:0)
      uStatRxRsfecErrCount1Inc        => uPort0StatRxRsfecErrCount1Inc,         --out std_logic_vector(2:0)
      uStatRxRsfecErrCount2Inc        => uPort0StatRxRsfecErrCount2Inc,         --out std_logic_vector(2:0)
      uStatRxRsfecErrCount3Inc        => uPort0StatRxRsfecErrCount3Inc,         --out std_logic_vector(2:0)
      uStatRxRsfecHiSer               => uPort0StatRxRsfecHiSer,                --out std_logic
      uStatRxRsfecLaneAlignmentStatus => uPort0StatRxRsfecLaneAlignmentStatus,  --out std_logic
      uStatRxRsfecLaneFill0           => uPort0StatRxRsfecLaneFill0,            --out std_logic_vector(13:0)
      uStatRxRsfecLaneFill1           => uPort0StatRxRsfecLaneFill1,            --out std_logic_vector(13:0)
      uStatRxRsfecLaneFill2           => uPort0StatRxRsfecLaneFill2,            --out std_logic_vector(13:0)
      uStatRxRsfecLaneFill3           => uPort0StatRxRsfecLaneFill3,            --out std_logic_vector(13:0)
      uStatRxRsfecLaneMapping         => uPort0StatRxRsfecLaneMapping,          --out std_logic_vector(7:0)
      uStatRxRsfecUncorrectedCwInc    => uPort0StatRxRsfecUncorrectedCwInc,     --out std_logic
      uCtlRxPauseEnable               => uPort0CtlRxPauseEnable,                --in  std_logic_vector(8:0)
      uCtlRxEnableGcp                 => uPort0CtlRxEnableGcp,                  --in  std_logic
      uCtlRxCheckMcastGcp             => uPort0CtlRxCheckMcastGcp,              --in  std_logic
      uCtlRxCheckUcastGcp             => uPort0CtlRxCheckUcastGcp,              --in  std_logic
      uCtlRxCheckSaGcp                => uPort0CtlRxCheckSaGcp,                 --in  std_logic
      uCtlRxCheckEtypeGcp             => uPort0CtlRxCheckEtypeGcp,              --in  std_logic
      uCtlRxCheckOpcodeGcp            => uPort0CtlRxCheckOpcodeGcp,             --in  std_logic
      uCtlRxEnablePcp                 => uPort0CtlRxEnablePcp,                  --in  std_logic
      uCtlRxCheckMcastPcp             => uPort0CtlRxCheckMcastPcp,              --in  std_logic
      uCtlRxCheckUcastPcp             => uPort0CtlRxCheckUcastPcp,              --in  std_logic
      uCtlRxCheckSaPcp                => uPort0CtlRxCheckSaPcp,                 --in  std_logic
      uCtlRxCheckEtypePcp             => uPort0CtlRxCheckEtypePcp,              --in  std_logic
      uCtlRxCheckOpcodePcp            => uPort0CtlRxCheckOpcodePcp,             --in  std_logic
      uCtlRxEnableGpp                 => uPort0CtlRxEnableGpp,                  --in  std_logic
      uCtlRxCheckMcastGpp             => uPort0CtlRxCheckMcastGpp,              --in  std_logic
      uCtlRxCheckUcastGpp             => uPort0CtlRxCheckUcastGpp,              --in  std_logic
      uCtlRxCheckSaGpp                => uPort0CtlRxCheckSaGpp,                 --in  std_logic
      uCtlRxCheckEtypeGpp             => uPort0CtlRxCheckEtypeGpp,              --in  std_logic
      uCtlRxCheckOpcodeGpp            => uPort0CtlRxCheckOpcodeGpp,             --in  std_logic
      uCtlRxEnablePpp                 => uPort0CtlRxEnablePpp,                  --in  std_logic
      uCtlRxCheckMcastPpp             => uPort0CtlRxCheckMcastPpp,              --in  std_logic
      uCtlRxCheckUcastPpp             => uPort0CtlRxCheckUcastPpp,              --in  std_logic
      uCtlRxCheckSaPpp                => uPort0CtlRxCheckSaPpp,                 --in  std_logic
      uCtlRxCheckEtypePpp             => uPort0CtlRxCheckEtypePpp,              --in  std_logic
      uCtlRxCheckOpcodePpp            => uPort0CtlRxCheckOpcodePpp,             --in  std_logic
      uStatRxPauseReq                 => uPort0StatRxPauseReq,                  --out std_logic_vector(8:0)
      uCtlRxPauseAck                  => uPort0CtlRxPauseAck,                   --in  std_logic_vector(8:0)
      uStatRxPauseValid               => uPort0StatRxPauseValid,                --out std_logic_vector(8:0)
      uStatRxPauseQanta0              => uPort0StatRxPauseQanta0,               --out std_logic_vector(15:0)
      uStatRxPauseQanta1              => uPort0StatRxPauseQanta1,               --out std_logic_vector(15:0)
      uStatRxPauseQanta2              => uPort0StatRxPauseQanta2,               --out std_logic_vector(15:0)
      uStatRxPauseQanta3              => uPort0StatRxPauseQanta3,               --out std_logic_vector(15:0)
      uStatRxPauseQanta4              => uPort0StatRxPauseQanta4,               --out std_logic_vector(15:0)
      uStatRxPauseQanta5              => uPort0StatRxPauseQanta5,               --out std_logic_vector(15:0)
      uStatRxPauseQanta6              => uPort0StatRxPauseQanta6,               --out std_logic_vector(15:0)
      uStatRxPauseQanta7              => uPort0StatRxPauseQanta7,               --out std_logic_vector(15:0)
      uStatRxPauseQanta8              => uPort0StatRxPauseQanta8,               --out std_logic_vector(15:0)
      uCtlTxPauseEnable               => uPort0CtlTxPauseEnable,                --in  std_logic_vector(8:0)
      uCtlTxPauseReq                  => uPort0CtlTxPauseReq,                   --in  std_logic_vector(8:0)
      uCtlTxPauseQuanta0              => uPort0CtlTxPauseQuanta0,               --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta1              => uPort0CtlTxPauseQuanta1,               --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta2              => uPort0CtlTxPauseQuanta2,               --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta3              => uPort0CtlTxPauseQuanta3,               --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta4              => uPort0CtlTxPauseQuanta4,               --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta5              => uPort0CtlTxPauseQuanta5,               --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta6              => uPort0CtlTxPauseQuanta6,               --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta7              => uPort0CtlTxPauseQuanta7,               --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta8              => uPort0CtlTxPauseQuanta8,               --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer0        => uPort0CtlTxPauseRefreshTimer0,         --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer1        => uPort0CtlTxPauseRefreshTimer1,         --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer2        => uPort0CtlTxPauseRefreshTimer2,         --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer3        => uPort0CtlTxPauseRefreshTimer3,         --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer4        => uPort0CtlTxPauseRefreshTimer4,         --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer5        => uPort0CtlTxPauseRefreshTimer5,         --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer6        => uPort0CtlTxPauseRefreshTimer6,         --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer7        => uPort0CtlTxPauseRefreshTimer7,         --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer8        => uPort0CtlTxPauseRefreshTimer8,         --in  std_logic_vector(15:0)
      uCtlTxResendPause               => uPort0CtlTxResendPause,                --in  std_logic
      uStatTxPauseValid               => uPort0StatTxPauseValid,                --out std_logic_vector(8:0)
      DrpClk                          => AxiClk,                                --in  std_logic
      dDrpAddr                        => dDrpAddr(kDrpAddrSize-1 downto 0),     --in  std_logic_vector(9:0)
      dDrpDi                          => dDrpDi(kDrpDataSize-1 downto 0),       --in  std_logic_vector(15:0)
      dDrpEn                          => dDrpEn(0),                             --in  std_logic
      dDrpDo                          => dDrpDo(kDrpDataSize-1 downto 0),       --out std_logic_vector(15:0)
      dDrpRdy                         => dDrpRdy(0),                            --out std_logic
      dDrpWe                          => dDrpWe(0),                             --in  std_logic
      uUserClkResetOut                => uPort0UserClkResetOut);                --out std_logic

  -----------------------------------------------------------------------------
  -- Port 2
  -----------------------------------------------------------------------------
  aPort2Reset  <= aResetSl or not xMgtRefClkEnabled(2);

  --vhook_e CmacCore CmacCore2
  --vhook_a aResetSl       aPort2Reset
  --vhook_a MgtRefClk_p    MgtRefClk_p(2)
  --vhook_a MgtRefClk_n    MgtRefClk_n(2)
  --vhook_a MgtPortRx_p    MgtPortRx_p(11 downto 8)
  --vhook_a MgtPortRx_n    MgtPortRx_n(11 downto 8)
  --vhook_a MgtPortTx_p    MgtPortTx_p(11 downto 8)
  --vhook_a MgtPortTx_n    MgtPortTx_n(11 downto 8)
  --vhook_a UserClk        UserClkPort2
  --vhook_a xCoreReady     xPort2CoreReady
  --vhook_a aRxPolarity    kRxIoModRxMgtPolarity(11 downto 8)
  --vhook_a aTxPolarity    kTxIoModTxMgtPolarity(11 downto 8)
  --vhook_a DrpClk         AxiClk
  --vhook_a dDrpAddr       dDrpAddr(2*kDrpAddrSize-1 downto kDrpAddrSize)
  --vhook_a dDrpDi         dDrpDi(2*kDrpDataSize-1 downto kDrpDataSize)
  --vhook_a dDrpDo         dDrpDo(2*kDrpDataSize-1 downto kDrpDataSize)
  --vhook_a dDrpEn         dDrpEn(1)
  --vhook_a dDrpRdy        dDrpRdy(1)
  --vhook_a dDrpWe         dDrpWe(1)
  --vhook_af {u(.*)}       {uPort2$1}
  CmacCore2: entity work.CmacCore (rtl)
    port map (
      aResetSl                        => aPort2Reset,                                     --in  std_logic
      MgtRefClk_p                     => MgtRefClk_p(2),                                  --in  std_logic
      MgtRefClk_n                     => MgtRefClk_n(2),                                  --in  std_logic
      MgtPortRx_p                     => MgtPortRx_p(11 downto 8),                        --in  std_logic_vector(3:0)
      MgtPortRx_n                     => MgtPortRx_n(11 downto 8),                        --in  std_logic_vector(3:0)
      MgtPortTx_p                     => MgtPortTx_p(11 downto 8),                        --out std_logic_vector(3:0)
      MgtPortTx_n                     => MgtPortTx_n(11 downto 8),                        --out std_logic_vector(3:0)
      AxiClk                          => AxiClk,                                          --in  std_logic
      SysClk                          => SysClk,                                          --in  std_logic
      UserClk                         => UserClkPort2,                                    --out std_logic
      xCoreReady                      => xPort2CoreReady,                                 --out std_logic
      uTxTData0                       => uPort2TxTData0,                                  --in  std_logic_vector(63:0)
      uTxTData1                       => uPort2TxTData1,                                  --in  std_logic_vector(63:0)
      uTxTData2                       => uPort2TxTData2,                                  --in  std_logic_vector(63:0)
      uTxTData3                       => uPort2TxTData3,                                  --in  std_logic_vector(63:0)
      uTxTData4                       => uPort2TxTData4,                                  --in  std_logic_vector(63:0)
      uTxTData5                       => uPort2TxTData5,                                  --in  std_logic_vector(63:0)
      uTxTData6                       => uPort2TxTData6,                                  --in  std_logic_vector(63:0)
      uTxTData7                       => uPort2TxTData7,                                  --in  std_logic_vector(63:0)
      uTxTKeep                        => uPort2TxTKeep,                                   --in  std_logic_vector(63:0)
      uTxTLast                        => uPort2TxTLast,                                   --in  std_logic
      uTxTUser                        => uPort2TxTUser,                                   --in  std_logic
      uTxTValid                       => uPort2TxTValid,                                  --in  std_logic
      uTxTReady                       => uPort2TxTReady,                                  --out std_logic
      uRxTData0                       => uPort2RxTData0,                                  --out std_logic_vector(63:0)
      uRxTData1                       => uPort2RxTData1,                                  --out std_logic_vector(63:0)
      uRxTData2                       => uPort2RxTData2,                                  --out std_logic_vector(63:0)
      uRxTData3                       => uPort2RxTData3,                                  --out std_logic_vector(63:0)
      uRxTData4                       => uPort2RxTData4,                                  --out std_logic_vector(63:0)
      uRxTData5                       => uPort2RxTData5,                                  --out std_logic_vector(63:0)
      uRxTData6                       => uPort2RxTData6,                                  --out std_logic_vector(63:0)
      uRxTData7                       => uPort2RxTData7,                                  --out std_logic_vector(63:0)
      uRxTKeep                        => uPort2RxTKeep,                                   --out std_logic_vector(63:0)
      uRxTUser                        => uPort2RxTUser,                                   --out std_logic
      uRxTLast                        => uPort2RxTLast,                                   --out std_logic
      uRxTValid                       => uPort2RxTValid,                                  --out std_logic
      aRxPolarity                     => kRxIoModRxMgtPolarity(11 downto 8),              --in  std_logic_vector(3:0)
      aTxPolarity                     => kTxIoModTxMgtPolarity(11 downto 8),              --in  std_logic_vector(3:0)
      uCtlRxSystemtimerinHigh         => uPort2CtlRxSystemtimerinHigh,                    --in  std_logic_vector(15:0)
      uCtlRxSystemtimerinLow          => uPort2CtlRxSystemtimerinLow,                     --in  std_logic_vector(63:0)
      uCtlTxSystemtimerinHigh         => uPort2CtlTxSystemtimerinHigh,                    --in  std_logic_vector(15:0)
      uCtlTxSystemtimerinLow          => uPort2CtlTxSystemtimerinLow,                     --in  std_logic_vector(63:0)
      uRxLaneAlignerFill0             => uPort2RxLaneAlignerFill0,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill1             => uPort2RxLaneAlignerFill1,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill10            => uPort2RxLaneAlignerFill10,                       --out std_logic_vector(6:0)
      uRxLaneAlignerFill11            => uPort2RxLaneAlignerFill11,                       --out std_logic_vector(6:0)
      uRxLaneAlignerFill12            => uPort2RxLaneAlignerFill12,                       --out std_logic_vector(6:0)
      uRxLaneAlignerFill13            => uPort2RxLaneAlignerFill13,                       --out std_logic_vector(6:0)
      uRxLaneAlignerFill14            => uPort2RxLaneAlignerFill14,                       --out std_logic_vector(6:0)
      uRxLaneAlignerFill15            => uPort2RxLaneAlignerFill15,                       --out std_logic_vector(6:0)
      uRxLaneAlignerFill16            => uPort2RxLaneAlignerFill16,                       --out std_logic_vector(6:0)
      uRxLaneAlignerFill17            => uPort2RxLaneAlignerFill17,                       --out std_logic_vector(6:0)
      uRxLaneAlignerFill18            => uPort2RxLaneAlignerFill18,                       --out std_logic_vector(6:0)
      uRxLaneAlignerFill19            => uPort2RxLaneAlignerFill19,                       --out std_logic_vector(6:0)
      uRxLaneAlignerFill2             => uPort2RxLaneAlignerFill2,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill3             => uPort2RxLaneAlignerFill3,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill4             => uPort2RxLaneAlignerFill4,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill5             => uPort2RxLaneAlignerFill5,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill6             => uPort2RxLaneAlignerFill6,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill7             => uPort2RxLaneAlignerFill7,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill8             => uPort2RxLaneAlignerFill8,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill9             => uPort2RxLaneAlignerFill9,                        --out std_logic_vector(6:0)
      uRxPtpPcslaneOut                => uPort2RxPtpPcslaneOut,                           --out std_logic_vector(4:0)
      uRxPtpTstampOutHigh             => uPort2RxPtpTstampOutHigh,                        --out std_logic_vector(15:0)
      uRxPtpTstampOutLow              => uPort2RxPtpTstampOutLow,                         --out std_logic_vector(63:0)
      uStatTxPtpFifoReadError         => uPort2StatTxPtpFifoReadError,                    --out std_logic
      uStatTxPtpFifoWriteError        => uPort2StatTxPtpFifoWriteError,                   --out std_logic
      uTxPtp1588opIn                  => uPort2TxPtp1588opIn,                             --in  std_logic_vector(1:0)
      uTxPtpPcslaneOut                => uPort2TxPtpPcslaneOut,                           --out std_logic_vector(4:0)
      uTxPtpTagFieldIn                => uPort2TxPtpTagFieldIn,                           --in  std_logic_vector(15:0)
      uTxPtpTstampOutHigh             => uPort2TxPtpTstampOutHigh,                        --out std_logic_vector(15:0)
      uTxPtpTstampOutLow              => uPort2TxPtpTstampOutLow,                         --out std_logic_vector(63:0)
      uTxPtpTstampTagOut              => uPort2TxPtpTstampTagOut,                         --out std_logic_vector(15:0)
      uTxPtpTstampValidOut            => uPort2TxPtpTstampValidOut,                       --out std_logic
      uStatRxRsfecAmLock0             => uPort2StatRxRsfecAmLock0,                        --out std_logic
      uStatRxRsfecAmLock1             => uPort2StatRxRsfecAmLock1,                        --out std_logic
      uStatRxRsfecAmLock2             => uPort2StatRxRsfecAmLock2,                        --out std_logic
      uStatRxRsfecAmLock3             => uPort2StatRxRsfecAmLock3,                        --out std_logic
      uStatRxRsfecCorrectedCwInc      => uPort2StatRxRsfecCorrectedCwInc,                 --out std_logic
      uStatRxRsfecCwInc               => uPort2StatRxRsfecCwInc,                          --out std_logic
      uStatRxRsfecErrCount0Inc        => uPort2StatRxRsfecErrCount0Inc,                   --out std_logic_vector(2:0)
      uStatRxRsfecErrCount1Inc        => uPort2StatRxRsfecErrCount1Inc,                   --out std_logic_vector(2:0)
      uStatRxRsfecErrCount2Inc        => uPort2StatRxRsfecErrCount2Inc,                   --out std_logic_vector(2:0)
      uStatRxRsfecErrCount3Inc        => uPort2StatRxRsfecErrCount3Inc,                   --out std_logic_vector(2:0)
      uStatRxRsfecHiSer               => uPort2StatRxRsfecHiSer,                          --out std_logic
      uStatRxRsfecLaneAlignmentStatus => uPort2StatRxRsfecLaneAlignmentStatus,            --out std_logic
      uStatRxRsfecLaneFill0           => uPort2StatRxRsfecLaneFill0,                      --out std_logic_vector(13:0)
      uStatRxRsfecLaneFill1           => uPort2StatRxRsfecLaneFill1,                      --out std_logic_vector(13:0)
      uStatRxRsfecLaneFill2           => uPort2StatRxRsfecLaneFill2,                      --out std_logic_vector(13:0)
      uStatRxRsfecLaneFill3           => uPort2StatRxRsfecLaneFill3,                      --out std_logic_vector(13:0)
      uStatRxRsfecLaneMapping         => uPort2StatRxRsfecLaneMapping,                    --out std_logic_vector(7:0)
      uStatRxRsfecUncorrectedCwInc    => uPort2StatRxRsfecUncorrectedCwInc,               --out std_logic
      uCtlRxPauseEnable               => uPort2CtlRxPauseEnable,                          --in  std_logic_vector(8:0)
      uCtlRxEnableGcp                 => uPort2CtlRxEnableGcp,                            --in  std_logic
      uCtlRxCheckMcastGcp             => uPort2CtlRxCheckMcastGcp,                        --in  std_logic
      uCtlRxCheckUcastGcp             => uPort2CtlRxCheckUcastGcp,                        --in  std_logic
      uCtlRxCheckSaGcp                => uPort2CtlRxCheckSaGcp,                           --in  std_logic
      uCtlRxCheckEtypeGcp             => uPort2CtlRxCheckEtypeGcp,                        --in  std_logic
      uCtlRxCheckOpcodeGcp            => uPort2CtlRxCheckOpcodeGcp,                       --in  std_logic
      uCtlRxEnablePcp                 => uPort2CtlRxEnablePcp,                            --in  std_logic
      uCtlRxCheckMcastPcp             => uPort2CtlRxCheckMcastPcp,                        --in  std_logic
      uCtlRxCheckUcastPcp             => uPort2CtlRxCheckUcastPcp,                        --in  std_logic
      uCtlRxCheckSaPcp                => uPort2CtlRxCheckSaPcp,                           --in  std_logic
      uCtlRxCheckEtypePcp             => uPort2CtlRxCheckEtypePcp,                        --in  std_logic
      uCtlRxCheckOpcodePcp            => uPort2CtlRxCheckOpcodePcp,                       --in  std_logic
      uCtlRxEnableGpp                 => uPort2CtlRxEnableGpp,                            --in  std_logic
      uCtlRxCheckMcastGpp             => uPort2CtlRxCheckMcastGpp,                        --in  std_logic
      uCtlRxCheckUcastGpp             => uPort2CtlRxCheckUcastGpp,                        --in  std_logic
      uCtlRxCheckSaGpp                => uPort2CtlRxCheckSaGpp,                           --in  std_logic
      uCtlRxCheckEtypeGpp             => uPort2CtlRxCheckEtypeGpp,                        --in  std_logic
      uCtlRxCheckOpcodeGpp            => uPort2CtlRxCheckOpcodeGpp,                       --in  std_logic
      uCtlRxEnablePpp                 => uPort2CtlRxEnablePpp,                            --in  std_logic
      uCtlRxCheckMcastPpp             => uPort2CtlRxCheckMcastPpp,                        --in  std_logic
      uCtlRxCheckUcastPpp             => uPort2CtlRxCheckUcastPpp,                        --in  std_logic
      uCtlRxCheckSaPpp                => uPort2CtlRxCheckSaPpp,                           --in  std_logic
      uCtlRxCheckEtypePpp             => uPort2CtlRxCheckEtypePpp,                        --in  std_logic
      uCtlRxCheckOpcodePpp            => uPort2CtlRxCheckOpcodePpp,                       --in  std_logic
      uStatRxPauseReq                 => uPort2StatRxPauseReq,                            --out std_logic_vector(8:0)
      uCtlRxPauseAck                  => uPort2CtlRxPauseAck,                             --in  std_logic_vector(8:0)
      uStatRxPauseValid               => uPort2StatRxPauseValid,                          --out std_logic_vector(8:0)
      uStatRxPauseQanta0              => uPort2StatRxPauseQanta0,                         --out std_logic_vector(15:0)
      uStatRxPauseQanta1              => uPort2StatRxPauseQanta1,                         --out std_logic_vector(15:0)
      uStatRxPauseQanta2              => uPort2StatRxPauseQanta2,                         --out std_logic_vector(15:0)
      uStatRxPauseQanta3              => uPort2StatRxPauseQanta3,                         --out std_logic_vector(15:0)
      uStatRxPauseQanta4              => uPort2StatRxPauseQanta4,                         --out std_logic_vector(15:0)
      uStatRxPauseQanta5              => uPort2StatRxPauseQanta5,                         --out std_logic_vector(15:0)
      uStatRxPauseQanta6              => uPort2StatRxPauseQanta6,                         --out std_logic_vector(15:0)
      uStatRxPauseQanta7              => uPort2StatRxPauseQanta7,                         --out std_logic_vector(15:0)
      uStatRxPauseQanta8              => uPort2StatRxPauseQanta8,                         --out std_logic_vector(15:0)
      uCtlTxPauseEnable               => uPort2CtlTxPauseEnable,                          --in  std_logic_vector(8:0)
      uCtlTxPauseReq                  => uPort2CtlTxPauseReq,                             --in  std_logic_vector(8:0)
      uCtlTxPauseQuanta0              => uPort2CtlTxPauseQuanta0,                         --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta1              => uPort2CtlTxPauseQuanta1,                         --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta2              => uPort2CtlTxPauseQuanta2,                         --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta3              => uPort2CtlTxPauseQuanta3,                         --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta4              => uPort2CtlTxPauseQuanta4,                         --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta5              => uPort2CtlTxPauseQuanta5,                         --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta6              => uPort2CtlTxPauseQuanta6,                         --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta7              => uPort2CtlTxPauseQuanta7,                         --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta8              => uPort2CtlTxPauseQuanta8,                         --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer0        => uPort2CtlTxPauseRefreshTimer0,                   --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer1        => uPort2CtlTxPauseRefreshTimer1,                   --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer2        => uPort2CtlTxPauseRefreshTimer2,                   --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer3        => uPort2CtlTxPauseRefreshTimer3,                   --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer4        => uPort2CtlTxPauseRefreshTimer4,                   --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer5        => uPort2CtlTxPauseRefreshTimer5,                   --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer6        => uPort2CtlTxPauseRefreshTimer6,                   --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer7        => uPort2CtlTxPauseRefreshTimer7,                   --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer8        => uPort2CtlTxPauseRefreshTimer8,                   --in  std_logic_vector(15:0)
      uCtlTxResendPause               => uPort2CtlTxResendPause,                          --in  std_logic
      uStatTxPauseValid               => uPort2StatTxPauseValid,                          --out std_logic_vector(8:0)
      DrpClk                          => AxiClk,                                          --in  std_logic
      dDrpAddr                        => dDrpAddr(2*kDrpAddrSize-1 downto kDrpAddrSize),  --in  std_logic_vector(9:0)
      dDrpDi                          => dDrpDi(2*kDrpDataSize-1 downto kDrpDataSize),    --in  std_logic_vector(15:0)
      dDrpEn                          => dDrpEn(1),                                       --in  std_logic
      dDrpDo                          => dDrpDo(2*kDrpDataSize-1 downto kDrpDataSize),    --out std_logic_vector(15:0)
      dDrpRdy                         => dDrpRdy(1),                                      --out std_logic
      dDrpWe                          => dDrpWe(1),                                       --in  std_logic
      uUserClkResetOut                => uPort2UserClkResetOut);                          --out std_logic


  -----------------------------------------------------------------------------
  -- Port 3
  -----------------------------------------------------------------------------
  aPort3Reset  <= aResetSl or not xMgtRefClkEnabled(3);

  --vhook_e CmacCore CmacCore3
  --vhook_a aResetSl       aPort3Reset
  --vhook_a MgtRefClk_p    MgtRefClk_p(3)
  --vhook_a MgtRefClk_n    MgtRefClk_n(3)
  --vhook_a MgtPortRx_p    MgtPortRx_p(15 downto 12)
  --vhook_a MgtPortRx_n    MgtPortRx_n(15 downto 12)
  --vhook_a MgtPortTx_p    MgtPortTx_p(15 downto 12)
  --vhook_a MgtPortTx_n    MgtPortTx_n(15 downto 12)
  --vhook_a UserClk        UserClkPort3
  --vhook_a xCoreReady     xPort3CoreReady
  --vhook_a aRxPolarity    kRxIoModRxMgtPolarity(15 downto 12)
  --vhook_a aTxPolarity    kTxIoModTxMgtPolarity(15 downto 12)
  --vhook_a DrpClk         AxiClk
  --vhook_a dDrpAddr       dDrpAddr(3*kDrpAddrSize-1 downto 2*kDrpAddrSize)
  --vhook_a dDrpDi         dDrpDi(3*kDrpDataSize-1 downto 2*kDrpDataSize)
  --vhook_a dDrpDo         dDrpDo(3*kDrpDataSize-1 downto 2*kDrpDataSize)
  --vhook_a dDrpEn         dDrpEn(2)
  --vhook_a dDrpRdy        dDrpRdy(2)
  --vhook_a dDrpWe         dDrpWe(2)
  --vhook_af {u(.*)}       {uPort3$1}
  CmacCore3: entity work.CmacCore (rtl)
    port map (
      aResetSl                        => aPort3Reset,                                       --in  std_logic
      MgtRefClk_p                     => MgtRefClk_p(3),                                    --in  std_logic
      MgtRefClk_n                     => MgtRefClk_n(3),                                    --in  std_logic
      MgtPortRx_p                     => MgtPortRx_p(15 downto 12),                         --in  std_logic_vector(3:0)
      MgtPortRx_n                     => MgtPortRx_n(15 downto 12),                         --in  std_logic_vector(3:0)
      MgtPortTx_p                     => MgtPortTx_p(15 downto 12),                         --out std_logic_vector(3:0)
      MgtPortTx_n                     => MgtPortTx_n(15 downto 12),                         --out std_logic_vector(3:0)
      AxiClk                          => AxiClk,                                            --in  std_logic
      SysClk                          => SysClk,                                            --in  std_logic
      UserClk                         => UserClkPort3,                                      --out std_logic
      xCoreReady                      => xPort3CoreReady,                                   --out std_logic
      uTxTData0                       => uPort3TxTData0,                                    --in  std_logic_vector(63:0)
      uTxTData1                       => uPort3TxTData1,                                    --in  std_logic_vector(63:0)
      uTxTData2                       => uPort3TxTData2,                                    --in  std_logic_vector(63:0)
      uTxTData3                       => uPort3TxTData3,                                    --in  std_logic_vector(63:0)
      uTxTData4                       => uPort3TxTData4,                                    --in  std_logic_vector(63:0)
      uTxTData5                       => uPort3TxTData5,                                    --in  std_logic_vector(63:0)
      uTxTData6                       => uPort3TxTData6,                                    --in  std_logic_vector(63:0)
      uTxTData7                       => uPort3TxTData7,                                    --in  std_logic_vector(63:0)
      uTxTKeep                        => uPort3TxTKeep,                                     --in  std_logic_vector(63:0)
      uTxTLast                        => uPort3TxTLast,                                     --in  std_logic
      uTxTUser                        => uPort3TxTUser,                                     --in  std_logic
      uTxTValid                       => uPort3TxTValid,                                    --in  std_logic
      uTxTReady                       => uPort3TxTReady,                                    --out std_logic
      uRxTData0                       => uPort3RxTData0,                                    --out std_logic_vector(63:0)
      uRxTData1                       => uPort3RxTData1,                                    --out std_logic_vector(63:0)
      uRxTData2                       => uPort3RxTData2,                                    --out std_logic_vector(63:0)
      uRxTData3                       => uPort3RxTData3,                                    --out std_logic_vector(63:0)
      uRxTData4                       => uPort3RxTData4,                                    --out std_logic_vector(63:0)
      uRxTData5                       => uPort3RxTData5,                                    --out std_logic_vector(63:0)
      uRxTData6                       => uPort3RxTData6,                                    --out std_logic_vector(63:0)
      uRxTData7                       => uPort3RxTData7,                                    --out std_logic_vector(63:0)
      uRxTKeep                        => uPort3RxTKeep,                                     --out std_logic_vector(63:0)
      uRxTUser                        => uPort3RxTUser,                                     --out std_logic
      uRxTLast                        => uPort3RxTLast,                                     --out std_logic
      uRxTValid                       => uPort3RxTValid,                                    --out std_logic
      aRxPolarity                     => kRxIoModRxMgtPolarity(15 downto 12),               --in  std_logic_vector(3:0)
      aTxPolarity                     => kTxIoModTxMgtPolarity(15 downto 12),               --in  std_logic_vector(3:0)
      uCtlRxSystemtimerinHigh         => uPort3CtlRxSystemtimerinHigh,                      --in  std_logic_vector(15:0)
      uCtlRxSystemtimerinLow          => uPort3CtlRxSystemtimerinLow,                       --in  std_logic_vector(63:0)
      uCtlTxSystemtimerinHigh         => uPort3CtlTxSystemtimerinHigh,                      --in  std_logic_vector(15:0)
      uCtlTxSystemtimerinLow          => uPort3CtlTxSystemtimerinLow,                       --in  std_logic_vector(63:0)
      uRxLaneAlignerFill0             => uPort3RxLaneAlignerFill0,                          --out std_logic_vector(6:0)
      uRxLaneAlignerFill1             => uPort3RxLaneAlignerFill1,                          --out std_logic_vector(6:0)
      uRxLaneAlignerFill10            => uPort3RxLaneAlignerFill10,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill11            => uPort3RxLaneAlignerFill11,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill12            => uPort3RxLaneAlignerFill12,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill13            => uPort3RxLaneAlignerFill13,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill14            => uPort3RxLaneAlignerFill14,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill15            => uPort3RxLaneAlignerFill15,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill16            => uPort3RxLaneAlignerFill16,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill17            => uPort3RxLaneAlignerFill17,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill18            => uPort3RxLaneAlignerFill18,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill19            => uPort3RxLaneAlignerFill19,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill2             => uPort3RxLaneAlignerFill2,                          --out std_logic_vector(6:0)
      uRxLaneAlignerFill3             => uPort3RxLaneAlignerFill3,                          --out std_logic_vector(6:0)
      uRxLaneAlignerFill4             => uPort3RxLaneAlignerFill4,                          --out std_logic_vector(6:0)
      uRxLaneAlignerFill5             => uPort3RxLaneAlignerFill5,                          --out std_logic_vector(6:0)
      uRxLaneAlignerFill6             => uPort3RxLaneAlignerFill6,                          --out std_logic_vector(6:0)
      uRxLaneAlignerFill7             => uPort3RxLaneAlignerFill7,                          --out std_logic_vector(6:0)
      uRxLaneAlignerFill8             => uPort3RxLaneAlignerFill8,                          --out std_logic_vector(6:0)
      uRxLaneAlignerFill9             => uPort3RxLaneAlignerFill9,                          --out std_logic_vector(6:0)
      uRxPtpPcslaneOut                => uPort3RxPtpPcslaneOut,                             --out std_logic_vector(4:0)
      uRxPtpTstampOutHigh             => uPort3RxPtpTstampOutHigh,                          --out std_logic_vector(15:0)
      uRxPtpTstampOutLow              => uPort3RxPtpTstampOutLow,                           --out std_logic_vector(63:0)
      uStatTxPtpFifoReadError         => uPort3StatTxPtpFifoReadError,                      --out std_logic
      uStatTxPtpFifoWriteError        => uPort3StatTxPtpFifoWriteError,                     --out std_logic
      uTxPtp1588opIn                  => uPort3TxPtp1588opIn,                               --in  std_logic_vector(1:0)
      uTxPtpPcslaneOut                => uPort3TxPtpPcslaneOut,                             --out std_logic_vector(4:0)
      uTxPtpTagFieldIn                => uPort3TxPtpTagFieldIn,                             --in  std_logic_vector(15:0)
      uTxPtpTstampOutHigh             => uPort3TxPtpTstampOutHigh,                          --out std_logic_vector(15:0)
      uTxPtpTstampOutLow              => uPort3TxPtpTstampOutLow,                           --out std_logic_vector(63:0)
      uTxPtpTstampTagOut              => uPort3TxPtpTstampTagOut,                           --out std_logic_vector(15:0)
      uTxPtpTstampValidOut            => uPort3TxPtpTstampValidOut,                         --out std_logic
      uStatRxRsfecAmLock0             => uPort3StatRxRsfecAmLock0,                          --out std_logic
      uStatRxRsfecAmLock1             => uPort3StatRxRsfecAmLock1,                          --out std_logic
      uStatRxRsfecAmLock2             => uPort3StatRxRsfecAmLock2,                          --out std_logic
      uStatRxRsfecAmLock3             => uPort3StatRxRsfecAmLock3,                          --out std_logic
      uStatRxRsfecCorrectedCwInc      => uPort3StatRxRsfecCorrectedCwInc,                   --out std_logic
      uStatRxRsfecCwInc               => uPort3StatRxRsfecCwInc,                            --out std_logic
      uStatRxRsfecErrCount0Inc        => uPort3StatRxRsfecErrCount0Inc,                     --out std_logic_vector(2:0)
      uStatRxRsfecErrCount1Inc        => uPort3StatRxRsfecErrCount1Inc,                     --out std_logic_vector(2:0)
      uStatRxRsfecErrCount2Inc        => uPort3StatRxRsfecErrCount2Inc,                     --out std_logic_vector(2:0)
      uStatRxRsfecErrCount3Inc        => uPort3StatRxRsfecErrCount3Inc,                     --out std_logic_vector(2:0)
      uStatRxRsfecHiSer               => uPort3StatRxRsfecHiSer,                            --out std_logic
      uStatRxRsfecLaneAlignmentStatus => uPort3StatRxRsfecLaneAlignmentStatus,              --out std_logic
      uStatRxRsfecLaneFill0           => uPort3StatRxRsfecLaneFill0,                        --out std_logic_vector(13:0)
      uStatRxRsfecLaneFill1           => uPort3StatRxRsfecLaneFill1,                        --out std_logic_vector(13:0)
      uStatRxRsfecLaneFill2           => uPort3StatRxRsfecLaneFill2,                        --out std_logic_vector(13:0)
      uStatRxRsfecLaneFill3           => uPort3StatRxRsfecLaneFill3,                        --out std_logic_vector(13:0)
      uStatRxRsfecLaneMapping         => uPort3StatRxRsfecLaneMapping,                      --out std_logic_vector(7:0)
      uStatRxRsfecUncorrectedCwInc    => uPort3StatRxRsfecUncorrectedCwInc,                 --out std_logic
      uCtlRxPauseEnable               => uPort3CtlRxPauseEnable,                            --in  std_logic_vector(8:0)
      uCtlRxEnableGcp                 => uPort3CtlRxEnableGcp,                              --in  std_logic
      uCtlRxCheckMcastGcp             => uPort3CtlRxCheckMcastGcp,                          --in  std_logic
      uCtlRxCheckUcastGcp             => uPort3CtlRxCheckUcastGcp,                          --in  std_logic
      uCtlRxCheckSaGcp                => uPort3CtlRxCheckSaGcp,                             --in  std_logic
      uCtlRxCheckEtypeGcp             => uPort3CtlRxCheckEtypeGcp,                          --in  std_logic
      uCtlRxCheckOpcodeGcp            => uPort3CtlRxCheckOpcodeGcp,                         --in  std_logic
      uCtlRxEnablePcp                 => uPort3CtlRxEnablePcp,                              --in  std_logic
      uCtlRxCheckMcastPcp             => uPort3CtlRxCheckMcastPcp,                          --in  std_logic
      uCtlRxCheckUcastPcp             => uPort3CtlRxCheckUcastPcp,                          --in  std_logic
      uCtlRxCheckSaPcp                => uPort3CtlRxCheckSaPcp,                             --in  std_logic
      uCtlRxCheckEtypePcp             => uPort3CtlRxCheckEtypePcp,                          --in  std_logic
      uCtlRxCheckOpcodePcp            => uPort3CtlRxCheckOpcodePcp,                         --in  std_logic
      uCtlRxEnableGpp                 => uPort3CtlRxEnableGpp,                              --in  std_logic
      uCtlRxCheckMcastGpp             => uPort3CtlRxCheckMcastGpp,                          --in  std_logic
      uCtlRxCheckUcastGpp             => uPort3CtlRxCheckUcastGpp,                          --in  std_logic
      uCtlRxCheckSaGpp                => uPort3CtlRxCheckSaGpp,                             --in  std_logic
      uCtlRxCheckEtypeGpp             => uPort3CtlRxCheckEtypeGpp,                          --in  std_logic
      uCtlRxCheckOpcodeGpp            => uPort3CtlRxCheckOpcodeGpp,                         --in  std_logic
      uCtlRxEnablePpp                 => uPort3CtlRxEnablePpp,                              --in  std_logic
      uCtlRxCheckMcastPpp             => uPort3CtlRxCheckMcastPpp,                          --in  std_logic
      uCtlRxCheckUcastPpp             => uPort3CtlRxCheckUcastPpp,                          --in  std_logic
      uCtlRxCheckSaPpp                => uPort3CtlRxCheckSaPpp,                             --in  std_logic
      uCtlRxCheckEtypePpp             => uPort3CtlRxCheckEtypePpp,                          --in  std_logic
      uCtlRxCheckOpcodePpp            => uPort3CtlRxCheckOpcodePpp,                         --in  std_logic
      uStatRxPauseReq                 => uPort3StatRxPauseReq,                              --out std_logic_vector(8:0)
      uCtlRxPauseAck                  => uPort3CtlRxPauseAck,                               --in  std_logic_vector(8:0)
      uStatRxPauseValid               => uPort3StatRxPauseValid,                            --out std_logic_vector(8:0)
      uStatRxPauseQanta0              => uPort3StatRxPauseQanta0,                           --out std_logic_vector(15:0)
      uStatRxPauseQanta1              => uPort3StatRxPauseQanta1,                           --out std_logic_vector(15:0)
      uStatRxPauseQanta2              => uPort3StatRxPauseQanta2,                           --out std_logic_vector(15:0)
      uStatRxPauseQanta3              => uPort3StatRxPauseQanta3,                           --out std_logic_vector(15:0)
      uStatRxPauseQanta4              => uPort3StatRxPauseQanta4,                           --out std_logic_vector(15:0)
      uStatRxPauseQanta5              => uPort3StatRxPauseQanta5,                           --out std_logic_vector(15:0)
      uStatRxPauseQanta6              => uPort3StatRxPauseQanta6,                           --out std_logic_vector(15:0)
      uStatRxPauseQanta7              => uPort3StatRxPauseQanta7,                           --out std_logic_vector(15:0)
      uStatRxPauseQanta8              => uPort3StatRxPauseQanta8,                           --out std_logic_vector(15:0)
      uCtlTxPauseEnable               => uPort3CtlTxPauseEnable,                            --in  std_logic_vector(8:0)
      uCtlTxPauseReq                  => uPort3CtlTxPauseReq,                               --in  std_logic_vector(8:0)
      uCtlTxPauseQuanta0              => uPort3CtlTxPauseQuanta0,                           --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta1              => uPort3CtlTxPauseQuanta1,                           --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta2              => uPort3CtlTxPauseQuanta2,                           --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta3              => uPort3CtlTxPauseQuanta3,                           --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta4              => uPort3CtlTxPauseQuanta4,                           --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta5              => uPort3CtlTxPauseQuanta5,                           --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta6              => uPort3CtlTxPauseQuanta6,                           --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta7              => uPort3CtlTxPauseQuanta7,                           --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta8              => uPort3CtlTxPauseQuanta8,                           --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer0        => uPort3CtlTxPauseRefreshTimer0,                     --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer1        => uPort3CtlTxPauseRefreshTimer1,                     --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer2        => uPort3CtlTxPauseRefreshTimer2,                     --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer3        => uPort3CtlTxPauseRefreshTimer3,                     --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer4        => uPort3CtlTxPauseRefreshTimer4,                     --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer5        => uPort3CtlTxPauseRefreshTimer5,                     --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer6        => uPort3CtlTxPauseRefreshTimer6,                     --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer7        => uPort3CtlTxPauseRefreshTimer7,                     --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer8        => uPort3CtlTxPauseRefreshTimer8,                     --in  std_logic_vector(15:0)
      uCtlTxResendPause               => uPort3CtlTxResendPause,                            --in  std_logic
      uStatTxPauseValid               => uPort3StatTxPauseValid,                            --out std_logic_vector(8:0)
      DrpClk                          => AxiClk,                                            --in  std_logic
      dDrpAddr                        => dDrpAddr(3*kDrpAddrSize-1 downto 2*kDrpAddrSize),  --in  std_logic_vector(9:0)
      dDrpDi                          => dDrpDi(3*kDrpDataSize-1 downto 2*kDrpDataSize),    --in  std_logic_vector(15:0)
      dDrpEn                          => dDrpEn(2),                                         --in  std_logic
      dDrpDo                          => dDrpDo(3*kDrpDataSize-1 downto 2*kDrpDataSize),    --out std_logic_vector(15:0)
      dDrpRdy                         => dDrpRdy(2),                                        --out std_logic
      dDrpWe                          => dDrpWe(2),                                         --in  std_logic
      uUserClkResetOut                => uPort3UserClkResetOut);                            --out std_logic


  -----------------------------------------------------------------------------
  -- Port 8
  -----------------------------------------------------------------------------
  aPort8Reset  <= aResetSl or not xMgtRefClkEnabled(8);

  --vhook_e CmacCore CmacCore8
  --vhook_a aResetSl       aPort8Reset
  --vhook_a MgtRefClk_p    MgtRefClk_p(8)
  --vhook_a MgtRefClk_n    MgtRefClk_n(8)
  --vhook_a MgtPortRx_p    MgtPortRx_p(35 downto 32)
  --vhook_a MgtPortRx_n    MgtPortRx_n(35 downto 32)
  --vhook_a MgtPortTx_p    MgtPortTx_p(35 downto 32)
  --vhook_a MgtPortTx_n    MgtPortTx_n(35 downto 32)
  --vhook_a UserClk        UserClkPort8
  --vhook_a xCoreReady     xPort8CoreReady
  --vhook_a aRxPolarity    kRxIoModRxMgtPolarity(35 downto 32)
  --vhook_a aTxPolarity    kTxIoModTxMgtPolarity(35 downto 32)
  --vhook_a DrpClk         AxiClk
  --vhook_a dDrpAddr       dDrpAddr(4*kDrpAddrSize-1 downto 3*kDrpAddrSize)
  --vhook_a dDrpDi         dDrpDi(4*kDrpDataSize-1 downto 3*kDrpDataSize)
  --vhook_a dDrpDo         dDrpDo(4*kDrpDataSize-1 downto 3*kDrpDataSize)
  --vhook_a dDrpEn         dDrpEn(3)
  --vhook_a dDrpRdy        dDrpRdy(3)
  --vhook_a dDrpWe         dDrpWe(3)
  --vhook_af {u(.*)}       {uPort8$1}
  CmacCore8: entity work.CmacCore (rtl)
    port map (
      aResetSl                        => aPort8Reset,                                       --in  std_logic
      MgtRefClk_p                     => MgtRefClk_p(8),                                    --in  std_logic
      MgtRefClk_n                     => MgtRefClk_n(8),                                    --in  std_logic
      MgtPortRx_p                     => MgtPortRx_p(35 downto 32),                         --in  std_logic_vector(3:0)
      MgtPortRx_n                     => MgtPortRx_n(35 downto 32),                         --in  std_logic_vector(3:0)
      MgtPortTx_p                     => MgtPortTx_p(35 downto 32),                         --out std_logic_vector(3:0)
      MgtPortTx_n                     => MgtPortTx_n(35 downto 32),                         --out std_logic_vector(3:0)
      AxiClk                          => AxiClk,                                            --in  std_logic
      SysClk                          => SysClk,                                            --in  std_logic
      UserClk                         => UserClkPort8,                                      --out std_logic
      xCoreReady                      => xPort8CoreReady,                                   --out std_logic
      uTxTData0                       => uPort8TxTData0,                                    --in  std_logic_vector(63:0)
      uTxTData1                       => uPort8TxTData1,                                    --in  std_logic_vector(63:0)
      uTxTData2                       => uPort8TxTData2,                                    --in  std_logic_vector(63:0)
      uTxTData3                       => uPort8TxTData3,                                    --in  std_logic_vector(63:0)
      uTxTData4                       => uPort8TxTData4,                                    --in  std_logic_vector(63:0)
      uTxTData5                       => uPort8TxTData5,                                    --in  std_logic_vector(63:0)
      uTxTData6                       => uPort8TxTData6,                                    --in  std_logic_vector(63:0)
      uTxTData7                       => uPort8TxTData7,                                    --in  std_logic_vector(63:0)
      uTxTKeep                        => uPort8TxTKeep,                                     --in  std_logic_vector(63:0)
      uTxTLast                        => uPort8TxTLast,                                     --in  std_logic
      uTxTUser                        => uPort8TxTUser,                                     --in  std_logic
      uTxTValid                       => uPort8TxTValid,                                    --in  std_logic
      uTxTReady                       => uPort8TxTReady,                                    --out std_logic
      uRxTData0                       => uPort8RxTData0,                                    --out std_logic_vector(63:0)
      uRxTData1                       => uPort8RxTData1,                                    --out std_logic_vector(63:0)
      uRxTData2                       => uPort8RxTData2,                                    --out std_logic_vector(63:0)
      uRxTData3                       => uPort8RxTData3,                                    --out std_logic_vector(63:0)
      uRxTData4                       => uPort8RxTData4,                                    --out std_logic_vector(63:0)
      uRxTData5                       => uPort8RxTData5,                                    --out std_logic_vector(63:0)
      uRxTData6                       => uPort8RxTData6,                                    --out std_logic_vector(63:0)
      uRxTData7                       => uPort8RxTData7,                                    --out std_logic_vector(63:0)
      uRxTKeep                        => uPort8RxTKeep,                                     --out std_logic_vector(63:0)
      uRxTUser                        => uPort8RxTUser,                                     --out std_logic
      uRxTLast                        => uPort8RxTLast,                                     --out std_logic
      uRxTValid                       => uPort8RxTValid,                                    --out std_logic
      aRxPolarity                     => kRxIoModRxMgtPolarity(35 downto 32),               --in  std_logic_vector(3:0)
      aTxPolarity                     => kTxIoModTxMgtPolarity(35 downto 32),               --in  std_logic_vector(3:0)
      uCtlRxSystemtimerinHigh         => uPort8CtlRxSystemtimerinHigh,                      --in  std_logic_vector(15:0)
      uCtlRxSystemtimerinLow          => uPort8CtlRxSystemtimerinLow,                       --in  std_logic_vector(63:0)
      uCtlTxSystemtimerinHigh         => uPort8CtlTxSystemtimerinHigh,                      --in  std_logic_vector(15:0)
      uCtlTxSystemtimerinLow          => uPort8CtlTxSystemtimerinLow,                       --in  std_logic_vector(63:0)
      uRxLaneAlignerFill0             => uPort8RxLaneAlignerFill0,                          --out std_logic_vector(6:0)
      uRxLaneAlignerFill1             => uPort8RxLaneAlignerFill1,                          --out std_logic_vector(6:0)
      uRxLaneAlignerFill10            => uPort8RxLaneAlignerFill10,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill11            => uPort8RxLaneAlignerFill11,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill12            => uPort8RxLaneAlignerFill12,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill13            => uPort8RxLaneAlignerFill13,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill14            => uPort8RxLaneAlignerFill14,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill15            => uPort8RxLaneAlignerFill15,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill16            => uPort8RxLaneAlignerFill16,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill17            => uPort8RxLaneAlignerFill17,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill18            => uPort8RxLaneAlignerFill18,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill19            => uPort8RxLaneAlignerFill19,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill2             => uPort8RxLaneAlignerFill2,                          --out std_logic_vector(6:0)
      uRxLaneAlignerFill3             => uPort8RxLaneAlignerFill3,                          --out std_logic_vector(6:0)
      uRxLaneAlignerFill4             => uPort8RxLaneAlignerFill4,                          --out std_logic_vector(6:0)
      uRxLaneAlignerFill5             => uPort8RxLaneAlignerFill5,                          --out std_logic_vector(6:0)
      uRxLaneAlignerFill6             => uPort8RxLaneAlignerFill6,                          --out std_logic_vector(6:0)
      uRxLaneAlignerFill7             => uPort8RxLaneAlignerFill7,                          --out std_logic_vector(6:0)
      uRxLaneAlignerFill8             => uPort8RxLaneAlignerFill8,                          --out std_logic_vector(6:0)
      uRxLaneAlignerFill9             => uPort8RxLaneAlignerFill9,                          --out std_logic_vector(6:0)
      uRxPtpPcslaneOut                => uPort8RxPtpPcslaneOut,                             --out std_logic_vector(4:0)
      uRxPtpTstampOutHigh             => uPort8RxPtpTstampOutHigh,                          --out std_logic_vector(15:0)
      uRxPtpTstampOutLow              => uPort8RxPtpTstampOutLow,                           --out std_logic_vector(63:0)
      uStatTxPtpFifoReadError         => uPort8StatTxPtpFifoReadError,                      --out std_logic
      uStatTxPtpFifoWriteError        => uPort8StatTxPtpFifoWriteError,                     --out std_logic
      uTxPtp1588opIn                  => uPort8TxPtp1588opIn,                               --in  std_logic_vector(1:0)
      uTxPtpPcslaneOut                => uPort8TxPtpPcslaneOut,                             --out std_logic_vector(4:0)
      uTxPtpTagFieldIn                => uPort8TxPtpTagFieldIn,                             --in  std_logic_vector(15:0)
      uTxPtpTstampOutHigh             => uPort8TxPtpTstampOutHigh,                          --out std_logic_vector(15:0)
      uTxPtpTstampOutLow              => uPort8TxPtpTstampOutLow,                           --out std_logic_vector(63:0)
      uTxPtpTstampTagOut              => uPort8TxPtpTstampTagOut,                           --out std_logic_vector(15:0)
      uTxPtpTstampValidOut            => uPort8TxPtpTstampValidOut,                         --out std_logic
      uStatRxRsfecAmLock0             => uPort8StatRxRsfecAmLock0,                          --out std_logic
      uStatRxRsfecAmLock1             => uPort8StatRxRsfecAmLock1,                          --out std_logic
      uStatRxRsfecAmLock2             => uPort8StatRxRsfecAmLock2,                          --out std_logic
      uStatRxRsfecAmLock3             => uPort8StatRxRsfecAmLock3,                          --out std_logic
      uStatRxRsfecCorrectedCwInc      => uPort8StatRxRsfecCorrectedCwInc,                   --out std_logic
      uStatRxRsfecCwInc               => uPort8StatRxRsfecCwInc,                            --out std_logic
      uStatRxRsfecErrCount0Inc        => uPort8StatRxRsfecErrCount0Inc,                     --out std_logic_vector(2:0)
      uStatRxRsfecErrCount1Inc        => uPort8StatRxRsfecErrCount1Inc,                     --out std_logic_vector(2:0)
      uStatRxRsfecErrCount2Inc        => uPort8StatRxRsfecErrCount2Inc,                     --out std_logic_vector(2:0)
      uStatRxRsfecErrCount3Inc        => uPort8StatRxRsfecErrCount3Inc,                     --out std_logic_vector(2:0)
      uStatRxRsfecHiSer               => uPort8StatRxRsfecHiSer,                            --out std_logic
      uStatRxRsfecLaneAlignmentStatus => uPort8StatRxRsfecLaneAlignmentStatus,              --out std_logic
      uStatRxRsfecLaneFill0           => uPort8StatRxRsfecLaneFill0,                        --out std_logic_vector(13:0)
      uStatRxRsfecLaneFill1           => uPort8StatRxRsfecLaneFill1,                        --out std_logic_vector(13:0)
      uStatRxRsfecLaneFill2           => uPort8StatRxRsfecLaneFill2,                        --out std_logic_vector(13:0)
      uStatRxRsfecLaneFill3           => uPort8StatRxRsfecLaneFill3,                        --out std_logic_vector(13:0)
      uStatRxRsfecLaneMapping         => uPort8StatRxRsfecLaneMapping,                      --out std_logic_vector(7:0)
      uStatRxRsfecUncorrectedCwInc    => uPort8StatRxRsfecUncorrectedCwInc,                 --out std_logic
      uCtlRxPauseEnable               => uPort8CtlRxPauseEnable,                            --in  std_logic_vector(8:0)
      uCtlRxEnableGcp                 => uPort8CtlRxEnableGcp,                              --in  std_logic
      uCtlRxCheckMcastGcp             => uPort8CtlRxCheckMcastGcp,                          --in  std_logic
      uCtlRxCheckUcastGcp             => uPort8CtlRxCheckUcastGcp,                          --in  std_logic
      uCtlRxCheckSaGcp                => uPort8CtlRxCheckSaGcp,                             --in  std_logic
      uCtlRxCheckEtypeGcp             => uPort8CtlRxCheckEtypeGcp,                          --in  std_logic
      uCtlRxCheckOpcodeGcp            => uPort8CtlRxCheckOpcodeGcp,                         --in  std_logic
      uCtlRxEnablePcp                 => uPort8CtlRxEnablePcp,                              --in  std_logic
      uCtlRxCheckMcastPcp             => uPort8CtlRxCheckMcastPcp,                          --in  std_logic
      uCtlRxCheckUcastPcp             => uPort8CtlRxCheckUcastPcp,                          --in  std_logic
      uCtlRxCheckSaPcp                => uPort8CtlRxCheckSaPcp,                             --in  std_logic
      uCtlRxCheckEtypePcp             => uPort8CtlRxCheckEtypePcp,                          --in  std_logic
      uCtlRxCheckOpcodePcp            => uPort8CtlRxCheckOpcodePcp,                         --in  std_logic
      uCtlRxEnableGpp                 => uPort8CtlRxEnableGpp,                              --in  std_logic
      uCtlRxCheckMcastGpp             => uPort8CtlRxCheckMcastGpp,                          --in  std_logic
      uCtlRxCheckUcastGpp             => uPort8CtlRxCheckUcastGpp,                          --in  std_logic
      uCtlRxCheckSaGpp                => uPort8CtlRxCheckSaGpp,                             --in  std_logic
      uCtlRxCheckEtypeGpp             => uPort8CtlRxCheckEtypeGpp,                          --in  std_logic
      uCtlRxCheckOpcodeGpp            => uPort8CtlRxCheckOpcodeGpp,                         --in  std_logic
      uCtlRxEnablePpp                 => uPort8CtlRxEnablePpp,                              --in  std_logic
      uCtlRxCheckMcastPpp             => uPort8CtlRxCheckMcastPpp,                          --in  std_logic
      uCtlRxCheckUcastPpp             => uPort8CtlRxCheckUcastPpp,                          --in  std_logic
      uCtlRxCheckSaPpp                => uPort8CtlRxCheckSaPpp,                             --in  std_logic
      uCtlRxCheckEtypePpp             => uPort8CtlRxCheckEtypePpp,                          --in  std_logic
      uCtlRxCheckOpcodePpp            => uPort8CtlRxCheckOpcodePpp,                         --in  std_logic
      uStatRxPauseReq                 => uPort8StatRxPauseReq,                              --out std_logic_vector(8:0)
      uCtlRxPauseAck                  => uPort8CtlRxPauseAck,                               --in  std_logic_vector(8:0)
      uStatRxPauseValid               => uPort8StatRxPauseValid,                            --out std_logic_vector(8:0)
      uStatRxPauseQanta0              => uPort8StatRxPauseQanta0,                           --out std_logic_vector(15:0)
      uStatRxPauseQanta1              => uPort8StatRxPauseQanta1,                           --out std_logic_vector(15:0)
      uStatRxPauseQanta2              => uPort8StatRxPauseQanta2,                           --out std_logic_vector(15:0)
      uStatRxPauseQanta3              => uPort8StatRxPauseQanta3,                           --out std_logic_vector(15:0)
      uStatRxPauseQanta4              => uPort8StatRxPauseQanta4,                           --out std_logic_vector(15:0)
      uStatRxPauseQanta5              => uPort8StatRxPauseQanta5,                           --out std_logic_vector(15:0)
      uStatRxPauseQanta6              => uPort8StatRxPauseQanta6,                           --out std_logic_vector(15:0)
      uStatRxPauseQanta7              => uPort8StatRxPauseQanta7,                           --out std_logic_vector(15:0)
      uStatRxPauseQanta8              => uPort8StatRxPauseQanta8,                           --out std_logic_vector(15:0)
      uCtlTxPauseEnable               => uPort8CtlTxPauseEnable,                            --in  std_logic_vector(8:0)
      uCtlTxPauseReq                  => uPort8CtlTxPauseReq,                               --in  std_logic_vector(8:0)
      uCtlTxPauseQuanta0              => uPort8CtlTxPauseQuanta0,                           --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta1              => uPort8CtlTxPauseQuanta1,                           --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta2              => uPort8CtlTxPauseQuanta2,                           --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta3              => uPort8CtlTxPauseQuanta3,                           --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta4              => uPort8CtlTxPauseQuanta4,                           --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta5              => uPort8CtlTxPauseQuanta5,                           --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta6              => uPort8CtlTxPauseQuanta6,                           --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta7              => uPort8CtlTxPauseQuanta7,                           --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta8              => uPort8CtlTxPauseQuanta8,                           --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer0        => uPort8CtlTxPauseRefreshTimer0,                     --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer1        => uPort8CtlTxPauseRefreshTimer1,                     --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer2        => uPort8CtlTxPauseRefreshTimer2,                     --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer3        => uPort8CtlTxPauseRefreshTimer3,                     --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer4        => uPort8CtlTxPauseRefreshTimer4,                     --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer5        => uPort8CtlTxPauseRefreshTimer5,                     --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer6        => uPort8CtlTxPauseRefreshTimer6,                     --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer7        => uPort8CtlTxPauseRefreshTimer7,                     --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer8        => uPort8CtlTxPauseRefreshTimer8,                     --in  std_logic_vector(15:0)
      uCtlTxResendPause               => uPort8CtlTxResendPause,                            --in  std_logic
      uStatTxPauseValid               => uPort8StatTxPauseValid,                            --out std_logic_vector(8:0)
      DrpClk                          => AxiClk,                                            --in  std_logic
      dDrpAddr                        => dDrpAddr(4*kDrpAddrSize-1 downto 3*kDrpAddrSize),  --in  std_logic_vector(9:0)
      dDrpDi                          => dDrpDi(4*kDrpDataSize-1 downto 3*kDrpDataSize),    --in  std_logic_vector(15:0)
      dDrpEn                          => dDrpEn(3),                                         --in  std_logic
      dDrpDo                          => dDrpDo(4*kDrpDataSize-1 downto 3*kDrpDataSize),    --out std_logic_vector(15:0)
      dDrpRdy                         => dDrpRdy(3),                                        --out std_logic
      dDrpWe                          => dDrpWe(3),                                         --in  std_logic
      uUserClkResetOut                => uPort8UserClkResetOut);                            --out std_logic


  -----------------------------------------------------------------------------
  -- Port 10
  -----------------------------------------------------------------------------
  aPort10Reset <= aResetSl or not xMgtRefClkEnabled(10);

  --vhook_e CmacCore CmacCore10
  --vhook_a aResetSl       aPort10Reset
  --vhook_a MgtRefClk_p    MgtRefClk_p(10)
  --vhook_a MgtRefClk_n    MgtRefClk_n(10)
  --vhook_a MgtPortRx_p    MgtPortRx_p(43 downto 40)
  --vhook_a MgtPortRx_n    MgtPortRx_n(43 downto 40)
  --vhook_a MgtPortTx_p    MgtPortTx_p(43 downto 40)
  --vhook_a MgtPortTx_n    MgtPortTx_n(43 downto 40)
  --vhook_a UserClk        UserClkPort10
  --vhook_a xCoreReady     xPort10CoreReady
  --vhook_a aRxPolarity    kRxIoModRxMgtPolarity(43 downto 40)
  --vhook_a aTxPolarity    kTxIoModTxMgtPolarity(43 downto 40)
  --vhook_a DrpClk         AxiClk
  --vhook_a dDrpAddr       dDrpAddr(5*kDrpAddrSize-1 downto 4*kDrpAddrSize)
  --vhook_a dDrpDi         dDrpDi(5*kDrpDataSize-1 downto 4*kDrpDataSize)
  --vhook_a dDrpDo         dDrpDo(5*kDrpDataSize-1 downto 4*kDrpDataSize)
  --vhook_a dDrpEn         dDrpEn(4)
  --vhook_a dDrpRdy        dDrpRdy(4)
  --vhook_a dDrpWe         dDrpWe(4)
  --vhook_af {u(.*)}       {uPort10$1}
  CmacCore10: entity work.CmacCore (rtl)
    port map (
      aResetSl                        => aPort10Reset,                                      --in  std_logic
      MgtRefClk_p                     => MgtRefClk_p(10),                                   --in  std_logic
      MgtRefClk_n                     => MgtRefClk_n(10),                                   --in  std_logic
      MgtPortRx_p                     => MgtPortRx_p(43 downto 40),                         --in  std_logic_vector(3:0)
      MgtPortRx_n                     => MgtPortRx_n(43 downto 40),                         --in  std_logic_vector(3:0)
      MgtPortTx_p                     => MgtPortTx_p(43 downto 40),                         --out std_logic_vector(3:0)
      MgtPortTx_n                     => MgtPortTx_n(43 downto 40),                         --out std_logic_vector(3:0)
      AxiClk                          => AxiClk,                                            --in  std_logic
      SysClk                          => SysClk,                                            --in  std_logic
      UserClk                         => UserClkPort10,                                     --out std_logic
      xCoreReady                      => xPort10CoreReady,                                  --out std_logic
      uTxTData0                       => uPort10TxTData0,                                   --in  std_logic_vector(63:0)
      uTxTData1                       => uPort10TxTData1,                                   --in  std_logic_vector(63:0)
      uTxTData2                       => uPort10TxTData2,                                   --in  std_logic_vector(63:0)
      uTxTData3                       => uPort10TxTData3,                                   --in  std_logic_vector(63:0)
      uTxTData4                       => uPort10TxTData4,                                   --in  std_logic_vector(63:0)
      uTxTData5                       => uPort10TxTData5,                                   --in  std_logic_vector(63:0)
      uTxTData6                       => uPort10TxTData6,                                   --in  std_logic_vector(63:0)
      uTxTData7                       => uPort10TxTData7,                                   --in  std_logic_vector(63:0)
      uTxTKeep                        => uPort10TxTKeep,                                    --in  std_logic_vector(63:0)
      uTxTLast                        => uPort10TxTLast,                                    --in  std_logic
      uTxTUser                        => uPort10TxTUser,                                    --in  std_logic
      uTxTValid                       => uPort10TxTValid,                                   --in  std_logic
      uTxTReady                       => uPort10TxTReady,                                   --out std_logic
      uRxTData0                       => uPort10RxTData0,                                   --out std_logic_vector(63:0)
      uRxTData1                       => uPort10RxTData1,                                   --out std_logic_vector(63:0)
      uRxTData2                       => uPort10RxTData2,                                   --out std_logic_vector(63:0)
      uRxTData3                       => uPort10RxTData3,                                   --out std_logic_vector(63:0)
      uRxTData4                       => uPort10RxTData4,                                   --out std_logic_vector(63:0)
      uRxTData5                       => uPort10RxTData5,                                   --out std_logic_vector(63:0)
      uRxTData6                       => uPort10RxTData6,                                   --out std_logic_vector(63:0)
      uRxTData7                       => uPort10RxTData7,                                   --out std_logic_vector(63:0)
      uRxTKeep                        => uPort10RxTKeep,                                    --out std_logic_vector(63:0)
      uRxTUser                        => uPort10RxTUser,                                    --out std_logic
      uRxTLast                        => uPort10RxTLast,                                    --out std_logic
      uRxTValid                       => uPort10RxTValid,                                   --out std_logic
      aRxPolarity                     => kRxIoModRxMgtPolarity(43 downto 40),               --in  std_logic_vector(3:0)
      aTxPolarity                     => kTxIoModTxMgtPolarity(43 downto 40),               --in  std_logic_vector(3:0)
      uCtlRxSystemtimerinHigh         => uPort10CtlRxSystemtimerinHigh,                     --in  std_logic_vector(15:0)
      uCtlRxSystemtimerinLow          => uPort10CtlRxSystemtimerinLow,                      --in  std_logic_vector(63:0)
      uCtlTxSystemtimerinHigh         => uPort10CtlTxSystemtimerinHigh,                     --in  std_logic_vector(15:0)
      uCtlTxSystemtimerinLow          => uPort10CtlTxSystemtimerinLow,                      --in  std_logic_vector(63:0)
      uRxLaneAlignerFill0             => uPort10RxLaneAlignerFill0,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill1             => uPort10RxLaneAlignerFill1,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill10            => uPort10RxLaneAlignerFill10,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill11            => uPort10RxLaneAlignerFill11,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill12            => uPort10RxLaneAlignerFill12,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill13            => uPort10RxLaneAlignerFill13,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill14            => uPort10RxLaneAlignerFill14,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill15            => uPort10RxLaneAlignerFill15,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill16            => uPort10RxLaneAlignerFill16,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill17            => uPort10RxLaneAlignerFill17,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill18            => uPort10RxLaneAlignerFill18,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill19            => uPort10RxLaneAlignerFill19,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill2             => uPort10RxLaneAlignerFill2,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill3             => uPort10RxLaneAlignerFill3,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill4             => uPort10RxLaneAlignerFill4,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill5             => uPort10RxLaneAlignerFill5,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill6             => uPort10RxLaneAlignerFill6,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill7             => uPort10RxLaneAlignerFill7,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill8             => uPort10RxLaneAlignerFill8,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill9             => uPort10RxLaneAlignerFill9,                         --out std_logic_vector(6:0)
      uRxPtpPcslaneOut                => uPort10RxPtpPcslaneOut,                            --out std_logic_vector(4:0)
      uRxPtpTstampOutHigh             => uPort10RxPtpTstampOutHigh,                         --out std_logic_vector(15:0)
      uRxPtpTstampOutLow              => uPort10RxPtpTstampOutLow,                          --out std_logic_vector(63:0)
      uStatTxPtpFifoReadError         => uPort10StatTxPtpFifoReadError,                     --out std_logic
      uStatTxPtpFifoWriteError        => uPort10StatTxPtpFifoWriteError,                    --out std_logic
      uTxPtp1588opIn                  => uPort10TxPtp1588opIn,                              --in  std_logic_vector(1:0)
      uTxPtpPcslaneOut                => uPort10TxPtpPcslaneOut,                            --out std_logic_vector(4:0)
      uTxPtpTagFieldIn                => uPort10TxPtpTagFieldIn,                            --in  std_logic_vector(15:0)
      uTxPtpTstampOutHigh             => uPort10TxPtpTstampOutHigh,                         --out std_logic_vector(15:0)
      uTxPtpTstampOutLow              => uPort10TxPtpTstampOutLow,                          --out std_logic_vector(63:0)
      uTxPtpTstampTagOut              => uPort10TxPtpTstampTagOut,                          --out std_logic_vector(15:0)
      uTxPtpTstampValidOut            => uPort10TxPtpTstampValidOut,                        --out std_logic
      uStatRxRsfecAmLock0             => uPort10StatRxRsfecAmLock0,                         --out std_logic
      uStatRxRsfecAmLock1             => uPort10StatRxRsfecAmLock1,                         --out std_logic
      uStatRxRsfecAmLock2             => uPort10StatRxRsfecAmLock2,                         --out std_logic
      uStatRxRsfecAmLock3             => uPort10StatRxRsfecAmLock3,                         --out std_logic
      uStatRxRsfecCorrectedCwInc      => uPort10StatRxRsfecCorrectedCwInc,                  --out std_logic
      uStatRxRsfecCwInc               => uPort10StatRxRsfecCwInc,                           --out std_logic
      uStatRxRsfecErrCount0Inc        => uPort10StatRxRsfecErrCount0Inc,                    --out std_logic_vector(2:0)
      uStatRxRsfecErrCount1Inc        => uPort10StatRxRsfecErrCount1Inc,                    --out std_logic_vector(2:0)
      uStatRxRsfecErrCount2Inc        => uPort10StatRxRsfecErrCount2Inc,                    --out std_logic_vector(2:0)
      uStatRxRsfecErrCount3Inc        => uPort10StatRxRsfecErrCount3Inc,                    --out std_logic_vector(2:0)
      uStatRxRsfecHiSer               => uPort10StatRxRsfecHiSer,                           --out std_logic
      uStatRxRsfecLaneAlignmentStatus => uPort10StatRxRsfecLaneAlignmentStatus,             --out std_logic
      uStatRxRsfecLaneFill0           => uPort10StatRxRsfecLaneFill0,                       --out std_logic_vector(13:0)
      uStatRxRsfecLaneFill1           => uPort10StatRxRsfecLaneFill1,                       --out std_logic_vector(13:0)
      uStatRxRsfecLaneFill2           => uPort10StatRxRsfecLaneFill2,                       --out std_logic_vector(13:0)
      uStatRxRsfecLaneFill3           => uPort10StatRxRsfecLaneFill3,                       --out std_logic_vector(13:0)
      uStatRxRsfecLaneMapping         => uPort10StatRxRsfecLaneMapping,                     --out std_logic_vector(7:0)
      uStatRxRsfecUncorrectedCwInc    => uPort10StatRxRsfecUncorrectedCwInc,                --out std_logic
      uCtlRxPauseEnable               => uPort10CtlRxPauseEnable,                           --in  std_logic_vector(8:0)
      uCtlRxEnableGcp                 => uPort10CtlRxEnableGcp,                             --in  std_logic
      uCtlRxCheckMcastGcp             => uPort10CtlRxCheckMcastGcp,                         --in  std_logic
      uCtlRxCheckUcastGcp             => uPort10CtlRxCheckUcastGcp,                         --in  std_logic
      uCtlRxCheckSaGcp                => uPort10CtlRxCheckSaGcp,                            --in  std_logic
      uCtlRxCheckEtypeGcp             => uPort10CtlRxCheckEtypeGcp,                         --in  std_logic
      uCtlRxCheckOpcodeGcp            => uPort10CtlRxCheckOpcodeGcp,                        --in  std_logic
      uCtlRxEnablePcp                 => uPort10CtlRxEnablePcp,                             --in  std_logic
      uCtlRxCheckMcastPcp             => uPort10CtlRxCheckMcastPcp,                         --in  std_logic
      uCtlRxCheckUcastPcp             => uPort10CtlRxCheckUcastPcp,                         --in  std_logic
      uCtlRxCheckSaPcp                => uPort10CtlRxCheckSaPcp,                            --in  std_logic
      uCtlRxCheckEtypePcp             => uPort10CtlRxCheckEtypePcp,                         --in  std_logic
      uCtlRxCheckOpcodePcp            => uPort10CtlRxCheckOpcodePcp,                        --in  std_logic
      uCtlRxEnableGpp                 => uPort10CtlRxEnableGpp,                             --in  std_logic
      uCtlRxCheckMcastGpp             => uPort10CtlRxCheckMcastGpp,                         --in  std_logic
      uCtlRxCheckUcastGpp             => uPort10CtlRxCheckUcastGpp,                         --in  std_logic
      uCtlRxCheckSaGpp                => uPort10CtlRxCheckSaGpp,                            --in  std_logic
      uCtlRxCheckEtypeGpp             => uPort10CtlRxCheckEtypeGpp,                         --in  std_logic
      uCtlRxCheckOpcodeGpp            => uPort10CtlRxCheckOpcodeGpp,                        --in  std_logic
      uCtlRxEnablePpp                 => uPort10CtlRxEnablePpp,                             --in  std_logic
      uCtlRxCheckMcastPpp             => uPort10CtlRxCheckMcastPpp,                         --in  std_logic
      uCtlRxCheckUcastPpp             => uPort10CtlRxCheckUcastPpp,                         --in  std_logic
      uCtlRxCheckSaPpp                => uPort10CtlRxCheckSaPpp,                            --in  std_logic
      uCtlRxCheckEtypePpp             => uPort10CtlRxCheckEtypePpp,                         --in  std_logic
      uCtlRxCheckOpcodePpp            => uPort10CtlRxCheckOpcodePpp,                        --in  std_logic
      uStatRxPauseReq                 => uPort10StatRxPauseReq,                             --out std_logic_vector(8:0)
      uCtlRxPauseAck                  => uPort10CtlRxPauseAck,                              --in  std_logic_vector(8:0)
      uStatRxPauseValid               => uPort10StatRxPauseValid,                           --out std_logic_vector(8:0)
      uStatRxPauseQanta0              => uPort10StatRxPauseQanta0,                          --out std_logic_vector(15:0)
      uStatRxPauseQanta1              => uPort10StatRxPauseQanta1,                          --out std_logic_vector(15:0)
      uStatRxPauseQanta2              => uPort10StatRxPauseQanta2,                          --out std_logic_vector(15:0)
      uStatRxPauseQanta3              => uPort10StatRxPauseQanta3,                          --out std_logic_vector(15:0)
      uStatRxPauseQanta4              => uPort10StatRxPauseQanta4,                          --out std_logic_vector(15:0)
      uStatRxPauseQanta5              => uPort10StatRxPauseQanta5,                          --out std_logic_vector(15:0)
      uStatRxPauseQanta6              => uPort10StatRxPauseQanta6,                          --out std_logic_vector(15:0)
      uStatRxPauseQanta7              => uPort10StatRxPauseQanta7,                          --out std_logic_vector(15:0)
      uStatRxPauseQanta8              => uPort10StatRxPauseQanta8,                          --out std_logic_vector(15:0)
      uCtlTxPauseEnable               => uPort10CtlTxPauseEnable,                           --in  std_logic_vector(8:0)
      uCtlTxPauseReq                  => uPort10CtlTxPauseReq,                              --in  std_logic_vector(8:0)
      uCtlTxPauseQuanta0              => uPort10CtlTxPauseQuanta0,                          --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta1              => uPort10CtlTxPauseQuanta1,                          --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta2              => uPort10CtlTxPauseQuanta2,                          --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta3              => uPort10CtlTxPauseQuanta3,                          --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta4              => uPort10CtlTxPauseQuanta4,                          --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta5              => uPort10CtlTxPauseQuanta5,                          --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta6              => uPort10CtlTxPauseQuanta6,                          --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta7              => uPort10CtlTxPauseQuanta7,                          --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta8              => uPort10CtlTxPauseQuanta8,                          --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer0        => uPort10CtlTxPauseRefreshTimer0,                    --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer1        => uPort10CtlTxPauseRefreshTimer1,                    --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer2        => uPort10CtlTxPauseRefreshTimer2,                    --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer3        => uPort10CtlTxPauseRefreshTimer3,                    --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer4        => uPort10CtlTxPauseRefreshTimer4,                    --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer5        => uPort10CtlTxPauseRefreshTimer5,                    --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer6        => uPort10CtlTxPauseRefreshTimer6,                    --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer7        => uPort10CtlTxPauseRefreshTimer7,                    --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer8        => uPort10CtlTxPauseRefreshTimer8,                    --in  std_logic_vector(15:0)
      uCtlTxResendPause               => uPort10CtlTxResendPause,                           --in  std_logic
      uStatTxPauseValid               => uPort10StatTxPauseValid,                           --out std_logic_vector(8:0)
      DrpClk                          => AxiClk,                                            --in  std_logic
      dDrpAddr                        => dDrpAddr(5*kDrpAddrSize-1 downto 4*kDrpAddrSize),  --in  std_logic_vector(9:0)
      dDrpDi                          => dDrpDi(5*kDrpDataSize-1 downto 4*kDrpDataSize),    --in  std_logic_vector(15:0)
      dDrpEn                          => dDrpEn(4),                                         --in  std_logic
      dDrpDo                          => dDrpDo(5*kDrpDataSize-1 downto 4*kDrpDataSize),    --out std_logic_vector(15:0)
      dDrpRdy                         => dDrpRdy(4),                                        --out std_logic
      dDrpWe                          => dDrpWe(4),                                         --in  std_logic
      uUserClkResetOut                => uPort10UserClkResetOut);                           --out std_logic


  -----------------------------------------------------------------------------
  -- Port 11
  -----------------------------------------------------------------------------
  aPort11Reset <= aResetSl or not xMgtRefClkEnabled(11);

  --vhook_e CmacCore CmacCore11
  --vhook_a aResetSl       aPort11Reset
  --vhook_a MgtRefClk_p    MgtRefClk_p(11)
  --vhook_a MgtRefClk_n    MgtRefClk_n(11)
  --vhook_a MgtPortRx_p    MgtPortRx_p(47 downto 44)
  --vhook_a MgtPortRx_n    MgtPortRx_n(47 downto 44)
  --vhook_a MgtPortTx_p    MgtPortTx_p(47 downto 44)
  --vhook_a MgtPortTx_n    MgtPortTx_n(47 downto 44)
  --vhook_a UserClk        UserClkPort11
  --vhook_a xCoreReady     xPort11CoreReady
  --vhook_a aRxPolarity    kRxIoModRxMgtPolarity(47 downto 44)
  --vhook_a aTxPolarity    kTxIoModTxMgtPolarity(47 downto 44)
  --vhook_a DrpClk         AxiClk
  --vhook_a dDrpAddr       dDrpAddr(6*kDrpAddrSize-1 downto 5*kDrpAddrSize)
  --vhook_a dDrpDi         dDrpDi(6*kDrpDataSize-1 downto 5*kDrpDataSize)
  --vhook_a dDrpDo         dDrpDo(6*kDrpDataSize-1 downto 5*kDrpDataSize)
  --vhook_a dDrpEn         dDrpEn(5)
  --vhook_a dDrpRdy        dDrpRdy(5)
  --vhook_a dDrpWe         dDrpWe(5)
  --vhook_af {u(.*)}       {uPort11$1}
  CmacCore11: entity work.CmacCore (rtl)
    port map (
      aResetSl                        => aPort11Reset,                                      --in  std_logic
      MgtRefClk_p                     => MgtRefClk_p(11),                                   --in  std_logic
      MgtRefClk_n                     => MgtRefClk_n(11),                                   --in  std_logic
      MgtPortRx_p                     => MgtPortRx_p(47 downto 44),                         --in  std_logic_vector(3:0)
      MgtPortRx_n                     => MgtPortRx_n(47 downto 44),                         --in  std_logic_vector(3:0)
      MgtPortTx_p                     => MgtPortTx_p(47 downto 44),                         --out std_logic_vector(3:0)
      MgtPortTx_n                     => MgtPortTx_n(47 downto 44),                         --out std_logic_vector(3:0)
      AxiClk                          => AxiClk,                                            --in  std_logic
      SysClk                          => SysClk,                                            --in  std_logic
      UserClk                         => UserClkPort11,                                     --out std_logic
      xCoreReady                      => xPort11CoreReady,                                  --out std_logic
      uTxTData0                       => uPort11TxTData0,                                   --in  std_logic_vector(63:0)
      uTxTData1                       => uPort11TxTData1,                                   --in  std_logic_vector(63:0)
      uTxTData2                       => uPort11TxTData2,                                   --in  std_logic_vector(63:0)
      uTxTData3                       => uPort11TxTData3,                                   --in  std_logic_vector(63:0)
      uTxTData4                       => uPort11TxTData4,                                   --in  std_logic_vector(63:0)
      uTxTData5                       => uPort11TxTData5,                                   --in  std_logic_vector(63:0)
      uTxTData6                       => uPort11TxTData6,                                   --in  std_logic_vector(63:0)
      uTxTData7                       => uPort11TxTData7,                                   --in  std_logic_vector(63:0)
      uTxTKeep                        => uPort11TxTKeep,                                    --in  std_logic_vector(63:0)
      uTxTLast                        => uPort11TxTLast,                                    --in  std_logic
      uTxTUser                        => uPort11TxTUser,                                    --in  std_logic
      uTxTValid                       => uPort11TxTValid,                                   --in  std_logic
      uTxTReady                       => uPort11TxTReady,                                   --out std_logic
      uRxTData0                       => uPort11RxTData0,                                   --out std_logic_vector(63:0)
      uRxTData1                       => uPort11RxTData1,                                   --out std_logic_vector(63:0)
      uRxTData2                       => uPort11RxTData2,                                   --out std_logic_vector(63:0)
      uRxTData3                       => uPort11RxTData3,                                   --out std_logic_vector(63:0)
      uRxTData4                       => uPort11RxTData4,                                   --out std_logic_vector(63:0)
      uRxTData5                       => uPort11RxTData5,                                   --out std_logic_vector(63:0)
      uRxTData6                       => uPort11RxTData6,                                   --out std_logic_vector(63:0)
      uRxTData7                       => uPort11RxTData7,                                   --out std_logic_vector(63:0)
      uRxTKeep                        => uPort11RxTKeep,                                    --out std_logic_vector(63:0)
      uRxTUser                        => uPort11RxTUser,                                    --out std_logic
      uRxTLast                        => uPort11RxTLast,                                    --out std_logic
      uRxTValid                       => uPort11RxTValid,                                   --out std_logic
      aRxPolarity                     => kRxIoModRxMgtPolarity(47 downto 44),               --in  std_logic_vector(3:0)
      aTxPolarity                     => kTxIoModTxMgtPolarity(47 downto 44),               --in  std_logic_vector(3:0)
      uCtlRxSystemtimerinHigh         => uPort11CtlRxSystemtimerinHigh,                     --in  std_logic_vector(15:0)
      uCtlRxSystemtimerinLow          => uPort11CtlRxSystemtimerinLow,                      --in  std_logic_vector(63:0)
      uCtlTxSystemtimerinHigh         => uPort11CtlTxSystemtimerinHigh,                     --in  std_logic_vector(15:0)
      uCtlTxSystemtimerinLow          => uPort11CtlTxSystemtimerinLow,                      --in  std_logic_vector(63:0)
      uRxLaneAlignerFill0             => uPort11RxLaneAlignerFill0,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill1             => uPort11RxLaneAlignerFill1,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill10            => uPort11RxLaneAlignerFill10,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill11            => uPort11RxLaneAlignerFill11,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill12            => uPort11RxLaneAlignerFill12,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill13            => uPort11RxLaneAlignerFill13,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill14            => uPort11RxLaneAlignerFill14,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill15            => uPort11RxLaneAlignerFill15,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill16            => uPort11RxLaneAlignerFill16,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill17            => uPort11RxLaneAlignerFill17,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill18            => uPort11RxLaneAlignerFill18,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill19            => uPort11RxLaneAlignerFill19,                        --out std_logic_vector(6:0)
      uRxLaneAlignerFill2             => uPort11RxLaneAlignerFill2,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill3             => uPort11RxLaneAlignerFill3,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill4             => uPort11RxLaneAlignerFill4,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill5             => uPort11RxLaneAlignerFill5,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill6             => uPort11RxLaneAlignerFill6,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill7             => uPort11RxLaneAlignerFill7,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill8             => uPort11RxLaneAlignerFill8,                         --out std_logic_vector(6:0)
      uRxLaneAlignerFill9             => uPort11RxLaneAlignerFill9,                         --out std_logic_vector(6:0)
      uRxPtpPcslaneOut                => uPort11RxPtpPcslaneOut,                            --out std_logic_vector(4:0)
      uRxPtpTstampOutHigh             => uPort11RxPtpTstampOutHigh,                         --out std_logic_vector(15:0)
      uRxPtpTstampOutLow              => uPort11RxPtpTstampOutLow,                          --out std_logic_vector(63:0)
      uStatTxPtpFifoReadError         => uPort11StatTxPtpFifoReadError,                     --out std_logic
      uStatTxPtpFifoWriteError        => uPort11StatTxPtpFifoWriteError,                    --out std_logic
      uTxPtp1588opIn                  => uPort11TxPtp1588opIn,                              --in  std_logic_vector(1:0)
      uTxPtpPcslaneOut                => uPort11TxPtpPcslaneOut,                            --out std_logic_vector(4:0)
      uTxPtpTagFieldIn                => uPort11TxPtpTagFieldIn,                            --in  std_logic_vector(15:0)
      uTxPtpTstampOutHigh             => uPort11TxPtpTstampOutHigh,                         --out std_logic_vector(15:0)
      uTxPtpTstampOutLow              => uPort11TxPtpTstampOutLow,                          --out std_logic_vector(63:0)
      uTxPtpTstampTagOut              => uPort11TxPtpTstampTagOut,                          --out std_logic_vector(15:0)
      uTxPtpTstampValidOut            => uPort11TxPtpTstampValidOut,                        --out std_logic
      uStatRxRsfecAmLock0             => uPort11StatRxRsfecAmLock0,                         --out std_logic
      uStatRxRsfecAmLock1             => uPort11StatRxRsfecAmLock1,                         --out std_logic
      uStatRxRsfecAmLock2             => uPort11StatRxRsfecAmLock2,                         --out std_logic
      uStatRxRsfecAmLock3             => uPort11StatRxRsfecAmLock3,                         --out std_logic
      uStatRxRsfecCorrectedCwInc      => uPort11StatRxRsfecCorrectedCwInc,                  --out std_logic
      uStatRxRsfecCwInc               => uPort11StatRxRsfecCwInc,                           --out std_logic
      uStatRxRsfecErrCount0Inc        => uPort11StatRxRsfecErrCount0Inc,                    --out std_logic_vector(2:0)
      uStatRxRsfecErrCount1Inc        => uPort11StatRxRsfecErrCount1Inc,                    --out std_logic_vector(2:0)
      uStatRxRsfecErrCount2Inc        => uPort11StatRxRsfecErrCount2Inc,                    --out std_logic_vector(2:0)
      uStatRxRsfecErrCount3Inc        => uPort11StatRxRsfecErrCount3Inc,                    --out std_logic_vector(2:0)
      uStatRxRsfecHiSer               => uPort11StatRxRsfecHiSer,                           --out std_logic
      uStatRxRsfecLaneAlignmentStatus => uPort11StatRxRsfecLaneAlignmentStatus,             --out std_logic
      uStatRxRsfecLaneFill0           => uPort11StatRxRsfecLaneFill0,                       --out std_logic_vector(13:0)
      uStatRxRsfecLaneFill1           => uPort11StatRxRsfecLaneFill1,                       --out std_logic_vector(13:0)
      uStatRxRsfecLaneFill2           => uPort11StatRxRsfecLaneFill2,                       --out std_logic_vector(13:0)
      uStatRxRsfecLaneFill3           => uPort11StatRxRsfecLaneFill3,                       --out std_logic_vector(13:0)
      uStatRxRsfecLaneMapping         => uPort11StatRxRsfecLaneMapping,                     --out std_logic_vector(7:0)
      uStatRxRsfecUncorrectedCwInc    => uPort11StatRxRsfecUncorrectedCwInc,                --out std_logic
      uCtlRxPauseEnable               => uPort11CtlRxPauseEnable,                           --in  std_logic_vector(8:0)
      uCtlRxEnableGcp                 => uPort11CtlRxEnableGcp,                             --in  std_logic
      uCtlRxCheckMcastGcp             => uPort11CtlRxCheckMcastGcp,                         --in  std_logic
      uCtlRxCheckUcastGcp             => uPort11CtlRxCheckUcastGcp,                         --in  std_logic
      uCtlRxCheckSaGcp                => uPort11CtlRxCheckSaGcp,                            --in  std_logic
      uCtlRxCheckEtypeGcp             => uPort11CtlRxCheckEtypeGcp,                         --in  std_logic
      uCtlRxCheckOpcodeGcp            => uPort11CtlRxCheckOpcodeGcp,                        --in  std_logic
      uCtlRxEnablePcp                 => uPort11CtlRxEnablePcp,                             --in  std_logic
      uCtlRxCheckMcastPcp             => uPort11CtlRxCheckMcastPcp,                         --in  std_logic
      uCtlRxCheckUcastPcp             => uPort11CtlRxCheckUcastPcp,                         --in  std_logic
      uCtlRxCheckSaPcp                => uPort11CtlRxCheckSaPcp,                            --in  std_logic
      uCtlRxCheckEtypePcp             => uPort11CtlRxCheckEtypePcp,                         --in  std_logic
      uCtlRxCheckOpcodePcp            => uPort11CtlRxCheckOpcodePcp,                        --in  std_logic
      uCtlRxEnableGpp                 => uPort11CtlRxEnableGpp,                             --in  std_logic
      uCtlRxCheckMcastGpp             => uPort11CtlRxCheckMcastGpp,                         --in  std_logic
      uCtlRxCheckUcastGpp             => uPort11CtlRxCheckUcastGpp,                         --in  std_logic
      uCtlRxCheckSaGpp                => uPort11CtlRxCheckSaGpp,                            --in  std_logic
      uCtlRxCheckEtypeGpp             => uPort11CtlRxCheckEtypeGpp,                         --in  std_logic
      uCtlRxCheckOpcodeGpp            => uPort11CtlRxCheckOpcodeGpp,                        --in  std_logic
      uCtlRxEnablePpp                 => uPort11CtlRxEnablePpp,                             --in  std_logic
      uCtlRxCheckMcastPpp             => uPort11CtlRxCheckMcastPpp,                         --in  std_logic
      uCtlRxCheckUcastPpp             => uPort11CtlRxCheckUcastPpp,                         --in  std_logic
      uCtlRxCheckSaPpp                => uPort11CtlRxCheckSaPpp,                            --in  std_logic
      uCtlRxCheckEtypePpp             => uPort11CtlRxCheckEtypePpp,                         --in  std_logic
      uCtlRxCheckOpcodePpp            => uPort11CtlRxCheckOpcodePpp,                        --in  std_logic
      uStatRxPauseReq                 => uPort11StatRxPauseReq,                             --out std_logic_vector(8:0)
      uCtlRxPauseAck                  => uPort11CtlRxPauseAck,                              --in  std_logic_vector(8:0)
      uStatRxPauseValid               => uPort11StatRxPauseValid,                           --out std_logic_vector(8:0)
      uStatRxPauseQanta0              => uPort11StatRxPauseQanta0,                          --out std_logic_vector(15:0)
      uStatRxPauseQanta1              => uPort11StatRxPauseQanta1,                          --out std_logic_vector(15:0)
      uStatRxPauseQanta2              => uPort11StatRxPauseQanta2,                          --out std_logic_vector(15:0)
      uStatRxPauseQanta3              => uPort11StatRxPauseQanta3,                          --out std_logic_vector(15:0)
      uStatRxPauseQanta4              => uPort11StatRxPauseQanta4,                          --out std_logic_vector(15:0)
      uStatRxPauseQanta5              => uPort11StatRxPauseQanta5,                          --out std_logic_vector(15:0)
      uStatRxPauseQanta6              => uPort11StatRxPauseQanta6,                          --out std_logic_vector(15:0)
      uStatRxPauseQanta7              => uPort11StatRxPauseQanta7,                          --out std_logic_vector(15:0)
      uStatRxPauseQanta8              => uPort11StatRxPauseQanta8,                          --out std_logic_vector(15:0)
      uCtlTxPauseEnable               => uPort11CtlTxPauseEnable,                           --in  std_logic_vector(8:0)
      uCtlTxPauseReq                  => uPort11CtlTxPauseReq,                              --in  std_logic_vector(8:0)
      uCtlTxPauseQuanta0              => uPort11CtlTxPauseQuanta0,                          --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta1              => uPort11CtlTxPauseQuanta1,                          --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta2              => uPort11CtlTxPauseQuanta2,                          --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta3              => uPort11CtlTxPauseQuanta3,                          --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta4              => uPort11CtlTxPauseQuanta4,                          --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta5              => uPort11CtlTxPauseQuanta5,                          --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta6              => uPort11CtlTxPauseQuanta6,                          --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta7              => uPort11CtlTxPauseQuanta7,                          --in  std_logic_vector(15:0)
      uCtlTxPauseQuanta8              => uPort11CtlTxPauseQuanta8,                          --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer0        => uPort11CtlTxPauseRefreshTimer0,                    --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer1        => uPort11CtlTxPauseRefreshTimer1,                    --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer2        => uPort11CtlTxPauseRefreshTimer2,                    --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer3        => uPort11CtlTxPauseRefreshTimer3,                    --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer4        => uPort11CtlTxPauseRefreshTimer4,                    --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer5        => uPort11CtlTxPauseRefreshTimer5,                    --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer6        => uPort11CtlTxPauseRefreshTimer6,                    --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer7        => uPort11CtlTxPauseRefreshTimer7,                    --in  std_logic_vector(15:0)
      uCtlTxPauseRefreshTimer8        => uPort11CtlTxPauseRefreshTimer8,                    --in  std_logic_vector(15:0)
      uCtlTxResendPause               => uPort11CtlTxResendPause,                           --in  std_logic
      uStatTxPauseValid               => uPort11StatTxPauseValid,                           --out std_logic_vector(8:0)
      DrpClk                          => AxiClk,                                            --in  std_logic
      dDrpAddr                        => dDrpAddr(6*kDrpAddrSize-1 downto 5*kDrpAddrSize),  --in  std_logic_vector(9:0)
      dDrpDi                          => dDrpDi(6*kDrpDataSize-1 downto 5*kDrpDataSize),    --in  std_logic_vector(15:0)
      dDrpEn                          => dDrpEn(5),                                         --in  std_logic
      dDrpDo                          => dDrpDo(6*kDrpDataSize-1 downto 5*kDrpDataSize),    --out std_logic_vector(15:0)
      dDrpRdy                         => dDrpRdy(5),                                        --out std_logic
      dDrpWe                          => dDrpWe(5),                                         --in  std_logic
      uUserClkResetOut                => uPort11UserClkResetOut);                           --out std_logic

end rtl;
