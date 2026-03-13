------------------------------------------------------------------------------
--
-- File: TheLvWindowFlatWrapper.vhd
-- Author: Auto-generated wrapper
-- Original Project: FlexRIO
-- Date: 2 January 2026
--
------------------------------------------------------------------------------
-- (c) 2026 Copyright National Instruments Corporation
--
-- SPDX-License-Identifier: MIT
------------------------------------------------------------------------------
--
-- Purpose: This wrapper flattens all record-type ports of TheWindow to
--          std_logic_vector ports for compatibility.
--
------------------------------------------------------------------------------
-- githubvisible=true

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

Library work;
  use work.PkgNiUtilities.all;
  use work.PkgCommIntConfiguration.all;
  use work.PkgCommunicationInterface.all;
  use work.PkgDmaPortCommunicationInterface.all;
  use work.PkgDmaPortDmaFifos.all;
  use work.PkgDmaPortDmaFifosFlatTypes.all;
  use work.PkgDmaPortCommIfcMasterPort.all;
  use work.PkgDmaPortCommIfcMasterPortFlatTypes.all;

entity TheLvWindowFlatWrapper is
   port(
     -----------------------------------
    -- CUSTOM BOARD IO
    -----------------------------------
% if include_custom_io:
% for signal in custom_signals:
    ${signal['name']} : ${signal['direction']} ${signal['type']}; -- ${signal['name']}
% endfor
% endif

    -----------------------------------
    -- Communication interface ports
    -----------------------------------
    -- Reset ports
    aBusReset : in std_logic;

    -- Register Access/ PIO Ports
    bRegPortIn : in std_logic_vector(kRegPortInSize-1 downto 0);
    bRegPortOut : out std_logic_vector(kRegPortOutSize-1 downto 0);
    bRegPortTimeout : in std_logic;

    -- DMA Stream Ports
    dInputStreamInterfaceToFifo : in std_logic_vector(
      Larger(kNumberOfDmaChannels,1)*SizeOf(kInputStreamInterfaceToFifoZero)-1 downto 0);
    dInputStreamInterfaceFromFifo : out std_logic_vector(
      Larger(kNumberOfDmaChannels,1)*SizeOf(kInputStreamInterfaceFromFifoZero)-1 downto 0);
    dOutputStreamInterfaceToFifo : in std_logic_vector(
      Larger(kNumberOfDmaChannels,1)*SizeOf(kOutputStreamInterfaceToFifoZero)-1 downto 0);
    dOutputStreamInterfaceFromFifo : out std_logic_vector(
      Larger(kNumberOfDmaChannels,1)*SizeOf(kOutputStreamInterfaceFromFifoZero)-1 downto 0);

    -- IRQ Ports
    bIrqToInterface : out std_logic_vector(
      Larger(kNumberOfIrqs,1)*kIrqToInterfaceSize*kIrqStatusToInterfaceSize-1 downto 0);

    -- MasterPort Ports
    dNiFpgaMasterWriteRequestFromMaster : out std_logic_vector(
      Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterWriteRequestFromMasterZero)-1 downto 0);
    dNiFpgaMasterWriteRequestToMaster : in std_logic_vector(
      Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterWriteRequestToMasterZero)-1 downto 0);
    dNiFpgaMasterWriteDataFromMaster : out std_logic_vector(
      Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterWriteDataFromMasterZero)-1 downto 0);
    dNiFpgaMasterWriteDataToMaster : in std_logic_vector(
      Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterWriteDataToMasterZero)-1 downto 0);
    dNiFpgaMasterWriteStatusToMaster : in std_logic_vector(
      Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterWriteStatusToMasterZero)-1 downto 0);

    dNiFpgaMasterReadRequestFromMaster : out std_logic_vector(
      Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterReadRequestFromMasterZero)-1 downto 0);
    dNiFpgaMasterReadRequestToMaster : in std_logic_vector(
      Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterReadRequestToMasterZero)-1 downto 0);
    dNiFpgaMasterReadDataToMaster : in std_logic_vector(
      Larger(kNumberOfMasterPorts,1)*SizeOf(kNiFpgaMasterReadDataToMasterZero)-1 downto 0);

    -----------------------------------
    -- Clocks from TopLevel
    -----------------------------------
    DmaClk : in std_logic;
    BusClk : in std_logic;
    ReliableClkIn : in std_logic;
    PllClk80 : in std_logic;
    DlyRefClk : in std_logic;
    PxieClk100 : in std_logic;
    DramClkLvFpga : in std_logic;
    Dram0ClkSocket : in std_logic;
    Dram1ClkSocket : in std_logic;
    Dram0ClkUser : in std_logic;
    Dram1ClkUser : in std_logic;
    dHmbDmaClkSocket : in std_logic;
    dLlbDmaClkSocket : in std_logic;

    -----------------------------------
    -- Handshaking signals for derived
    -- clocks on external clocks
    -----------------------------------

    -----------------------------------
    -- IO Node ports
    -----------------------------------
    aLvAuxDio0OutputData : out std_logic;
    aLvAuxDio0InputData : in std_logic;
    aLvAuxDio0OutputEnable : out std_logic;
    oClkaLvAuxDio0 : in std_logic;
    aoResetaLvAuxDio0 : in std_logic;
    oDoneaLvAuxDio0 : in std_logic;
    oDirectionaLvAuxDio0 : out std_logic := '0';
    oRequestaLvAuxDio0 : out std_logic := '1';
    aLvAuxDio1OutputData : out std_logic;
    aLvAuxDio1InputData : in std_logic;
    aLvAuxDio1OutputEnable : out std_logic;
    oClkaLvAuxDio1 : in std_logic;
    aoResetaLvAuxDio1 : in std_logic;
    oDoneaLvAuxDio1 : in std_logic;
    oDirectionaLvAuxDio1 : out std_logic := '0';
    oRequestaLvAuxDio1 : out std_logic := '1';
    aLvAuxDio2OutputData : out std_logic;
    aLvAuxDio2InputData : in std_logic;
    aLvAuxDio2OutputEnable : out std_logic;
    oClkaLvAuxDio2 : in std_logic;
    aoResetaLvAuxDio2 : in std_logic;
    oDoneaLvAuxDio2 : in std_logic;
    oDirectionaLvAuxDio2 : out std_logic := '0';
    oRequestaLvAuxDio2 : out std_logic := '1';
    aLvAuxDio3OutputData : out std_logic;
    aLvAuxDio3InputData : in std_logic;
    aLvAuxDio3OutputEnable : out std_logic;
    oClkaLvAuxDio3 : in std_logic;
    aoResetaLvAuxDio3 : in std_logic;
    oDoneaLvAuxDio3 : in std_logic;
    oDirectionaLvAuxDio3 : out std_logic := '0';
    oRequestaLvAuxDio3 : out std_logic := '1';
    aLvAuxDio4OutputData : out std_logic;
    aLvAuxDio4InputData : in std_logic;
    aLvAuxDio4OutputEnable : out std_logic;
    oClkaLvAuxDio4 : in std_logic;
    aoResetaLvAuxDio4 : in std_logic;
    oDoneaLvAuxDio4 : in std_logic;
    oDirectionaLvAuxDio4 : out std_logic := '0';
    oRequestaLvAuxDio4 : out std_logic := '1';
    aLvAuxDio5OutputData : out std_logic;
    aLvAuxDio5InputData : in std_logic;
    aLvAuxDio5OutputEnable : out std_logic;
    oClkaLvAuxDio5 : in std_logic;
    aoResetaLvAuxDio5 : in std_logic;
    oDoneaLvAuxDio5 : in std_logic;
    oDirectionaLvAuxDio5 : out std_logic := '0';
    oRequestaLvAuxDio5 : out std_logic := '1';
    aLvAuxDio6OutputData : out std_logic;
    aLvAuxDio6InputData : in std_logic;
    aLvAuxDio6OutputEnable : out std_logic;
    oClkaLvAuxDio6 : in std_logic;
    aoResetaLvAuxDio6 : in std_logic;
    oDoneaLvAuxDio6 : in std_logic;
    oDirectionaLvAuxDio6 : out std_logic := '0';
    oRequestaLvAuxDio6 : out std_logic := '1';
    aLvAuxDio7OutputData : out std_logic;
    aLvAuxDio7InputData : in std_logic;
    aLvAuxDio7OutputEnable : out std_logic;
    oClkaLvAuxDio7 : in std_logic;
    aoResetaLvAuxDio7 : in std_logic;
    oDoneaLvAuxDio7 : in std_logic;
    oDirectionaLvAuxDio7 : out std_logic := '0';
    oRequestaLvAuxDio7 : out std_logic := '1';
    pIntSync100 : in std_logic;
    aIntClk10 : in std_logic;

    -----------------------------------
    -- Target Method and Properties ports
    -----------------------------------
    bdIFifoRdData : out std_logic_vector(63 downto 0);
    bdIFifoRdDataValid : out std_logic;
    bdIFifoRdReadyForInput : in std_logic;
    bdIFifoRdIsError : out std_logic;
    bdIFifoWrData : in std_logic_vector(63 downto 0);
    bdIFifoWrDataValid : in std_logic;
    bdIFifoWrReadyForOutput : out std_logic;
    bdAxiStreamRdFromClipTData : in std_logic_vector(31 downto 0);
    bdAxiStreamRdFromClipTLast : in std_logic;
    bdAxiStreamRdFromClipTValid : in std_logic;
    bdAxiStreamRdToClipTReady : out std_logic;
    bdAxiStreamWrToClipTData : out std_logic_vector(31 downto 0);
    bdAxiStreamWrToClipTLast : out std_logic;
    bdAxiStreamWrToClipTValid : out std_logic;
    bdAxiStreamWrFromClipTReady : in std_logic;

    -----------------------------------
    -- Pass through LabVIEW FPGA ports
    -----------------------------------

    ----------------------------------------
    -- Trigger Routing Socketed CLIP
    ----------------------------------------
    PxieClk100Trigger : in std_logic;
    pIntSync100Trigger : in std_logic;
    dTdcAssert : out std_logic;
    dDevClkEn : in std_logic;
    sTdcDeassert : out std_logic;
    aIntClk10Trigger : in std_logic;
    bRoutingClipPresent : out std_logic;
    bRoutingClipNiCompatible : out std_logic;
    BusClkTrigger : in std_logic;
    abBusResetTrigger : in std_logic;
    bTriggerRoutingBaRegPortInAddress : in std_logic_vector(27 downto 0);
    bTriggerRoutingBaRegPortInData : in std_logic_vector(63 downto 0);
    bTriggerRoutingBaRegPortInWtStrobe : in std_logic_vector(7 downto 0);
    bTriggerRoutingBaRegPortInRdStrobe : in std_logic_vector(7 downto 0);
    bTriggerRoutingBaRegPortOutData : out std_logic_vector(63 downto 0);
    bTriggerRoutingBaRegPortOutAck : out std_logic;
    aPxiTrigDataIn : in std_logic_vector(7 downto 0);
    aPxiTrigDataOut : out std_logic_vector(7 downto 0);
    aPxiTrigDataTri : out std_logic_vector(7 downto 0);
    aPxiStarData : in std_logic;
    aPxieDstarB : in std_logic;
    aPxieDstarC : out std_logic;

    -----------------------------------
    -- CLIP Socket ports
    -----------------------------------

    --Nanopitch I/O
    DioMgtRefClk_p : in std_logic;
    DioMgtRefClk_n : in std_logic;
    DioMgtRefClkFromFam : in std_logic;
    DioMgtRX_n : in std_logic_vector(3 downto 0);
    DioMgtRX_p : in std_logic_vector(3 downto 0);
    DioMgtTX_n : out std_logic_vector(3 downto 0);
    DioMgtTX_p : out std_logic_vector(3 downto 0);
    SocketClk80 : in std_logic;
    --Synchronous to SocketClk80
    sDioMgtRefClkFromFamPresent : in std_logic;

    -----------------------------------------------------------------------------
    --Dram Interface
    -----------------------------------------------------------------------------
    aDramReady : in std_logic;
    du0DramAddrFifoAddr : out std_logic_vector(28 downto 0);
    du0DramAddrFifoCmd : out std_logic_vector(2 downto 0);
    du0DramAddrFifoFull : in std_logic;
    du0DramAddrFifoWrEn : out std_logic;
    du0DramPhyInitDone : in std_logic;
    du0DramRdDataValid : in std_logic;
    du0DramRdFifoDataOut : in std_logic_vector(255 downto 0);
    du0DramWrFifoDataIn : out std_logic_vector(255 downto 0);
    du0DramWrFifoFull : in std_logic;
    du0DramWrFifoMaskData : out std_logic_vector(31 downto 0);
    du0DramWrFifoWrEn : out std_logic;
    du1DramAddrFifoAddr : out std_logic_vector(28 downto 0);
    du1DramAddrFifoCmd : out std_logic_vector(2 downto 0);
    du1DramAddrFifoFull : in std_logic;
    du1DramAddrFifoWrEn : out std_logic;
    du1DramPhyInitDone : in std_logic;
    du1DramRdDataValid : in std_logic;
    du1DramRdFifoDataOut : in std_logic_vector(255 downto 0);
    du1DramWrFifoDataIn : out std_logic_vector(255 downto 0);
    du1DramWrFifoFull : in std_logic;
    du1DramWrFifoMaskData : out std_logic_vector(31 downto 0);
    du1DramWrFifoWrEn : out std_logic;

    -----------------------------------------------------------------------------
    --HMB Interface
    -----------------------------------------------------------------------------
    dHmbDramAddrFifoAddr : out std_logic_vector(31 downto 0);
    dHmbDramAddrFifoCmd : out std_logic_vector(2 downto 0);
    dHmbDramAddrFifoFull : in std_logic;
    dHmbDramAddrFifoWrEn : out std_logic;
    dHmbDramRdDataValid : in std_logic;
    dHmbDramRdFifoDataOut : in std_logic_vector(1023 downto 0);
    dHmbDramWrFifoDataIn : out std_logic_vector(1023 downto 0);
    dHmbDramWrFifoFull : in std_logic;
    dHmbDramWrFifoMaskData : out std_logic_vector(127 downto 0);
    dHmbDramWrFifoWrEn : out std_logic;
    dHmbPhyInitDoneForLvfpga : in std_logic;
    dLlbDramAddrFifoAddr : out std_logic_vector(31 downto 0);
    dLlbDramAddrFifoCmd : out std_logic_vector(2 downto 0);
    dLlbDramAddrFifoFull : in std_logic;
    dLlbDramAddrFifoWrEn : out std_logic;
    dLlbDramRdDataValid : in std_logic;
    dLlbDramRdFifoDataOut : in std_logic_vector(1023 downto 0);
    dLlbDramWrFifoDataIn : out std_logic_vector(1023 downto 0);
    dLlbDramWrFifoFull : in std_logic;
    dLlbDramWrFifoMaskData : out std_logic_vector(127 downto 0);
    dLlbDramWrFifoWrEn : out std_logic;
    dLlbPhyInitDoneForLvfpga : in std_logic;

    -----------------------------------
    -- Clocks from TheWindow
    -----------------------------------
    TopLevelClkOut : out std_logic;
    ReliableClkOut : out std_logic;

    -----------------------------------
    -- Diagram/Reset/Clock status
    -----------------------------------
    rBaseClksValid : in std_logic := '1';
    tDiagramActive : out std_logic;
    rDiagramReset : out std_logic;
    aDiagramReset : out std_logic;
    rDerivedClockLostLockError : out std_logic;
    rGatedBaseClksValid : in std_logic := '1';
    aSafeToEnableGatedClks : out std_logic
  );
end entity TheLvWindowFlatWrapper;

architecture behavioral of TheLvWindowFlatWrapper is

  signal aBusResetBool : boolean;
  signal bRegPortTimeoutBool : boolean;

  signal bRegPortInInternal : RegPortIn_t;
  signal bRegPortOutInternal : RegPortOut_t;

  signal dInputStreamInterfaceToFifoInternal : InputStreamInterfaceToFifoArray_t(
    Larger(kNumberOfDmaChannels,1)-1 downto 0);
  signal dInputStreamInterfaceFromFifoInternal : InputStreamInterfaceFromFifoArray_t(
    Larger(kNumberOfDmaChannels,1)-1 downto 0);
  signal dOutputStreamInterfaceToFifoInternal : OutputStreamInterfaceToFifoArray_t(
    Larger(kNumberOfDmaChannels,1)-1 downto 0);
  signal dOutputStreamInterfaceFromFifoInternal : OutputStreamInterfaceFromFifoArray_t(
    Larger(kNumberOfDmaChannels,1)-1 downto 0);

  signal bIrqToInterfaceInternal : IrqToInterfaceArray_t(
    Larger(kNumberOfIrqs,1)-1 downto 0);

  signal dNiFpgaMasterWriteRequestFromMasterInternal :
    NiFpgaMasterWriteRequestFromMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);
  signal dNiFpgaMasterWriteRequestToMasterInternal :
    NiFpgaMasterWriteRequestToMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);
  signal dNiFpgaMasterWriteDataFromMasterInternal :
    NiFpgaMasterWriteDataFromMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);
  signal dNiFpgaMasterWriteDataToMasterInternal :
    NiFpgaMasterWriteDataToMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);
  signal dNiFpgaMasterWriteStatusToMasterInternal :
    NiFpgaMasterWriteStatusToMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);

  signal dNiFpgaMasterReadRequestFromMasterInternal :
    NiFpgaMasterReadRequestFromMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);
  signal dNiFpgaMasterReadRequestToMasterInternal :
    NiFpgaMasterReadRequestToMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);
  signal dNiFpgaMasterReadDataToMasterInternal :
    NiFpgaMasterReadDataToMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);

begin

  aBusResetBool <= aBusReset = '1';
  bRegPortTimeoutBool <= bRegPortTimeout = '1';

  bRegPortInInternal <= BuildRegPortIn(bRegPortIn);

  dInputStreamInterfaceToFifoInternal <= UnflattenStreamInterface(dInputStreamInterfaceToFifo);
  dOutputStreamInterfaceToFifoInternal <= UnflattenStreamInterface(dOutputStreamInterfaceToFifo);

  gen_master_inputs: for i in 0 to Larger(kNumberOfMasterPorts,1)-1 generate
    dNiFpgaMasterWriteRequestToMasterInternal(i) <=
      UnflattenMasterPortInterface(
        NiFpgaMasterWriteRequestToMasterFlat_t(
          dNiFpgaMasterWriteRequestToMaster(
            (i+1)*SizeOf(kNiFpgaMasterWriteRequestToMasterZero)-1 downto
            i*SizeOf(kNiFpgaMasterWriteRequestToMasterZero))));

    dNiFpgaMasterWriteDataToMasterInternal(i) <=
      UnflattenMasterPortInterface(
        NiFpgaMasterWriteDataToMasterFlat_t(
          dNiFpgaMasterWriteDataToMaster(
            (i+1)*SizeOf(kNiFpgaMasterWriteDataToMasterZero)-1 downto
            i*SizeOf(kNiFpgaMasterWriteDataToMasterZero))));

    dNiFpgaMasterWriteStatusToMasterInternal(i) <=
      UnflattenMasterPortInterface(
        NiFpgaMasterWriteStatusToMasterFlat_t(
          dNiFpgaMasterWriteStatusToMaster(
            (i+1)*SizeOf(kNiFpgaMasterWriteStatusToMasterZero)-1 downto
            i*SizeOf(kNiFpgaMasterWriteStatusToMasterZero))));

    dNiFpgaMasterReadRequestToMasterInternal(i) <=
      UnflattenMasterPortInterface(
        NiFpgaMasterReadRequestToMasterFlat_t(
          dNiFpgaMasterReadRequestToMaster(
            (i+1)*SizeOf(kNiFpgaMasterReadRequestToMasterZero)-1 downto
            i*SizeOf(kNiFpgaMasterReadRequestToMasterZero))));

    dNiFpgaMasterReadDataToMasterInternal(i) <=
      UnflattenMasterPortInterface(
        NiFpgaMasterReadDataToMasterFlat_t(
          dNiFpgaMasterReadDataToMaster(
            (i+1)*SizeOf(kNiFpgaMasterReadDataToMasterZero)-1 downto
            i*SizeOf(kNiFpgaMasterReadDataToMasterZero))));
  end generate;

  bRegPortOut <= to_StdLogicVector(bRegPortOutInternal);

  dInputStreamInterfaceFromFifo <= FlattenStreamInterface(dInputStreamInterfaceFromFifoInternal);
  dOutputStreamInterfaceFromFifo <= FlattenStreamInterface(dOutputStreamInterfaceFromFifoInternal);

  bIrqToInterface <= to_StdLogicVector(bIrqToInterfaceInternal);

  gen_master_outputs: for i in 0 to Larger(kNumberOfMasterPorts,1)-1 generate
    dNiFpgaMasterWriteRequestFromMaster(
      (i+1)*SizeOf(kNiFpgaMasterWriteRequestFromMasterZero)-1 downto
      i*SizeOf(kNiFpgaMasterWriteRequestFromMasterZero)) <=
        std_logic_vector(FlattenMasterPortInterface(dNiFpgaMasterWriteRequestFromMasterInternal(i)));

    dNiFpgaMasterWriteDataFromMaster(
      (i+1)*SizeOf(kNiFpgaMasterWriteDataFromMasterZero)-1 downto
      i*SizeOf(kNiFpgaMasterWriteDataFromMasterZero)) <=
        std_logic_vector(FlattenMasterPortInterface(dNiFpgaMasterWriteDataFromMasterInternal(i)));

    dNiFpgaMasterReadRequestFromMaster(
      (i+1)*SizeOf(kNiFpgaMasterReadRequestFromMasterZero)-1 downto
      i*SizeOf(kNiFpgaMasterReadRequestFromMasterZero)) <=
        std_logic_vector(FlattenMasterPortInterface(dNiFpgaMasterReadRequestFromMasterInternal(i)));
  end generate;

  TheLvWindow : entity work.TheWindow (behavioral)
    port map(
% if include_custom_io:
% for signal in custom_signals:
      ${signal['name']} => ${signal['name']},
% endfor
% endif
      aBusReset => aBusResetBool,
      bRegPortIn => bRegPortInInternal,
      bRegPortOut => bRegPortOutInternal,
      bRegPortTimeout => bRegPortTimeoutBool,
      dInputStreamInterfaceToFifo => dInputStreamInterfaceToFifoInternal,
      dInputStreamInterfaceFromFifo => dInputStreamInterfaceFromFifoInternal,
      dOutputStreamInterfaceToFifo => dOutputStreamInterfaceToFifoInternal,
      dOutputStreamInterfaceFromFifo => dOutputStreamInterfaceFromFifoInternal,
      bIrqToInterface => bIrqToInterfaceInternal,
      dNiFpgaMasterWriteRequestFromMaster => dNiFpgaMasterWriteRequestFromMasterInternal,
      dNiFpgaMasterWriteRequestToMaster => dNiFpgaMasterWriteRequestToMasterInternal,
      dNiFpgaMasterWriteDataFromMaster => dNiFpgaMasterWriteDataFromMasterInternal,
      dNiFpgaMasterWriteDataToMaster => dNiFpgaMasterWriteDataToMasterInternal,
      dNiFpgaMasterWriteStatusToMaster => dNiFpgaMasterWriteStatusToMasterInternal,
      dNiFpgaMasterReadRequestFromMaster => dNiFpgaMasterReadRequestFromMasterInternal,
      dNiFpgaMasterReadRequestToMaster => dNiFpgaMasterReadRequestToMasterInternal,
      dNiFpgaMasterReadDataToMaster => dNiFpgaMasterReadDataToMasterInternal,
      DmaClk => DmaClk,
      BusClk => BusClk,
      ReliableClkIn => ReliableClkIn,
      PllClk80 => PllClk80,
      DlyRefClk => DlyRefClk,
      PxieClk100 => PxieClk100,
      DramClkLvFpga => DramClkLvFpga,
      Dram0ClkSocket => Dram0ClkSocket,
      Dram1ClkSocket => Dram1ClkSocket,
      Dram0ClkUser => Dram0ClkUser,
      Dram1ClkUser => Dram1ClkUser,
      dHmbDmaClkSocket => dHmbDmaClkSocket,
      dLlbDmaClkSocket => dLlbDmaClkSocket,
      aLvAuxDio0OutputData => aLvAuxDio0OutputData,
      aLvAuxDio0InputData => aLvAuxDio0InputData,
      aLvAuxDio0OutputEnable => aLvAuxDio0OutputEnable,
      oClkaLvAuxDio0 => oClkaLvAuxDio0,
      aoResetaLvAuxDio0 => aoResetaLvAuxDio0,
      oDoneaLvAuxDio0 => oDoneaLvAuxDio0,
      oDirectionaLvAuxDio0 => oDirectionaLvAuxDio0,
      oRequestaLvAuxDio0 => oRequestaLvAuxDio0,
      aLvAuxDio1OutputData => aLvAuxDio1OutputData,
      aLvAuxDio1InputData => aLvAuxDio1InputData,
      aLvAuxDio1OutputEnable => aLvAuxDio1OutputEnable,
      oClkaLvAuxDio1 => oClkaLvAuxDio1,
      aoResetaLvAuxDio1 => aoResetaLvAuxDio1,
      oDoneaLvAuxDio1 => oDoneaLvAuxDio1,
      oDirectionaLvAuxDio1 => oDirectionaLvAuxDio1,
      oRequestaLvAuxDio1 => oRequestaLvAuxDio1,
      aLvAuxDio2OutputData => aLvAuxDio2OutputData,
      aLvAuxDio2InputData => aLvAuxDio2InputData,
      aLvAuxDio2OutputEnable => aLvAuxDio2OutputEnable,
      oClkaLvAuxDio2 => oClkaLvAuxDio2,
      aoResetaLvAuxDio2 => aoResetaLvAuxDio2,
      oDoneaLvAuxDio2 => oDoneaLvAuxDio2,
      oDirectionaLvAuxDio2 => oDirectionaLvAuxDio2,
      oRequestaLvAuxDio2 => oRequestaLvAuxDio2,
      aLvAuxDio3OutputData => aLvAuxDio3OutputData,
      aLvAuxDio3InputData => aLvAuxDio3InputData,
      aLvAuxDio3OutputEnable => aLvAuxDio3OutputEnable,
      oClkaLvAuxDio3 => oClkaLvAuxDio3,
      aoResetaLvAuxDio3 => aoResetaLvAuxDio3,
      oDoneaLvAuxDio3 => oDoneaLvAuxDio3,
      oDirectionaLvAuxDio3 => oDirectionaLvAuxDio3,
      oRequestaLvAuxDio3 => oRequestaLvAuxDio3,
      aLvAuxDio4OutputData => aLvAuxDio4OutputData,
      aLvAuxDio4InputData => aLvAuxDio4InputData,
      aLvAuxDio4OutputEnable => aLvAuxDio4OutputEnable,
      oClkaLvAuxDio4 => oClkaLvAuxDio4,
      aoResetaLvAuxDio4 => aoResetaLvAuxDio4,
      oDoneaLvAuxDio4 => oDoneaLvAuxDio4,
      oDirectionaLvAuxDio4 => oDirectionaLvAuxDio4,
      oRequestaLvAuxDio4 => oRequestaLvAuxDio4,
      aLvAuxDio5OutputData => aLvAuxDio5OutputData,
      aLvAuxDio5InputData => aLvAuxDio5InputData,
      aLvAuxDio5OutputEnable => aLvAuxDio5OutputEnable,
      oClkaLvAuxDio5 => oClkaLvAuxDio5,
      aoResetaLvAuxDio5 => aoResetaLvAuxDio5,
      oDoneaLvAuxDio5 => oDoneaLvAuxDio5,
      oDirectionaLvAuxDio5 => oDirectionaLvAuxDio5,
      oRequestaLvAuxDio5 => oRequestaLvAuxDio5,
      aLvAuxDio6OutputData => aLvAuxDio6OutputData,
      aLvAuxDio6InputData => aLvAuxDio6InputData,
      aLvAuxDio6OutputEnable => aLvAuxDio6OutputEnable,
      oClkaLvAuxDio6 => oClkaLvAuxDio6,
      aoResetaLvAuxDio6 => aoResetaLvAuxDio6,
      oDoneaLvAuxDio6 => oDoneaLvAuxDio6,
      oDirectionaLvAuxDio6 => oDirectionaLvAuxDio6,
      oRequestaLvAuxDio6 => oRequestaLvAuxDio6,
      aLvAuxDio7OutputData => aLvAuxDio7OutputData,
      aLvAuxDio7InputData => aLvAuxDio7InputData,
      aLvAuxDio7OutputEnable => aLvAuxDio7OutputEnable,
      oClkaLvAuxDio7 => oClkaLvAuxDio7,
      aoResetaLvAuxDio7 => aoResetaLvAuxDio7,
      oDoneaLvAuxDio7 => oDoneaLvAuxDio7,
      oDirectionaLvAuxDio7 => oDirectionaLvAuxDio7,
      oRequestaLvAuxDio7 => oRequestaLvAuxDio7,
      pIntSync100 => pIntSync100,
      aIntClk10 => aIntClk10,
      bdIFifoRdData => bdIFifoRdData,
      bdIFifoRdDataValid => bdIFifoRdDataValid,
      bdIFifoRdReadyForInput => bdIFifoRdReadyForInput,
      bdIFifoRdIsError => bdIFifoRdIsError,
      bdIFifoWrData => bdIFifoWrData,
      bdIFifoWrDataValid => bdIFifoWrDataValid,
      bdIFifoWrReadyForOutput => bdIFifoWrReadyForOutput,
      bdAxiStreamRdFromClipTData => bdAxiStreamRdFromClipTData,
      bdAxiStreamRdFromClipTLast => bdAxiStreamRdFromClipTLast,
      bdAxiStreamRdFromClipTValid => bdAxiStreamRdFromClipTValid,
      bdAxiStreamRdToClipTReady => bdAxiStreamRdToClipTReady,
      bdAxiStreamWrToClipTData => bdAxiStreamWrToClipTData,
      bdAxiStreamWrToClipTLast => bdAxiStreamWrToClipTLast,
      bdAxiStreamWrToClipTValid => bdAxiStreamWrToClipTValid,
      bdAxiStreamWrFromClipTReady => bdAxiStreamWrFromClipTReady,
      PxieClk100Trigger => PxieClk100Trigger,
      pIntSync100Trigger => pIntSync100Trigger,
      dTdcAssert => dTdcAssert,
      dDevClkEn => dDevClkEn,
      sTdcDeassert => sTdcDeassert,
      aIntClk10Trigger => aIntClk10Trigger,
      bRoutingClipPresent => bRoutingClipPresent,
      bRoutingClipNiCompatible => bRoutingClipNiCompatible,
      BusClkTrigger => BusClkTrigger,
      abBusResetTrigger => abBusResetTrigger,
      bTriggerRoutingBaRegPortInAddress => bTriggerRoutingBaRegPortInAddress,
      bTriggerRoutingBaRegPortInData => bTriggerRoutingBaRegPortInData,
      bTriggerRoutingBaRegPortInWtStrobe => bTriggerRoutingBaRegPortInWtStrobe,
      bTriggerRoutingBaRegPortInRdStrobe => bTriggerRoutingBaRegPortInRdStrobe,
      bTriggerRoutingBaRegPortOutData => bTriggerRoutingBaRegPortOutData,
      bTriggerRoutingBaRegPortOutAck => bTriggerRoutingBaRegPortOutAck,
      aPxiTrigDataIn => aPxiTrigDataIn,
      aPxiTrigDataOut => aPxiTrigDataOut,
      aPxiTrigDataTri => aPxiTrigDataTri,
      aPxiStarData => aPxiStarData,
      aPxieDstarB => aPxieDstarB,
      aPxieDstarC => aPxieDstarC,
      DioMgtRefClk_p => DioMgtRefClk_p,
      DioMgtRefClk_n => DioMgtRefClk_n,
      DioMgtRefClkFromFam => DioMgtRefClkFromFam,
      DioMgtRX_n => DioMgtRX_n,
      DioMgtRX_p => DioMgtRX_p,
      DioMgtTX_n => DioMgtTX_n,
      DioMgtTX_p => DioMgtTX_p,
      SocketClk80 => SocketClk80,
      sDioMgtRefClkFromFamPresent => sDioMgtRefClkFromFamPresent,
      aDramReady => aDramReady,
      du0DramAddrFifoAddr => du0DramAddrFifoAddr,
      du0DramAddrFifoCmd => du0DramAddrFifoCmd,
      du0DramAddrFifoFull => du0DramAddrFifoFull,
      du0DramAddrFifoWrEn => du0DramAddrFifoWrEn,
      du0DramPhyInitDone => du0DramPhyInitDone,
      du0DramRdDataValid => du0DramRdDataValid,
      du0DramRdFifoDataOut => du0DramRdFifoDataOut,
      du0DramWrFifoDataIn => du0DramWrFifoDataIn,
      du0DramWrFifoFull => du0DramWrFifoFull,
      du0DramWrFifoMaskData => du0DramWrFifoMaskData,
      du0DramWrFifoWrEn => du0DramWrFifoWrEn,
      du1DramAddrFifoAddr => du1DramAddrFifoAddr,
      du1DramAddrFifoCmd => du1DramAddrFifoCmd,
      du1DramAddrFifoFull => du1DramAddrFifoFull,
      du1DramAddrFifoWrEn => du1DramAddrFifoWrEn,
      du1DramPhyInitDone => du1DramPhyInitDone,
      du1DramRdDataValid => du1DramRdDataValid,
      du1DramRdFifoDataOut => du1DramRdFifoDataOut,
      du1DramWrFifoDataIn => du1DramWrFifoDataIn,
      du1DramWrFifoFull => du1DramWrFifoFull,
      du1DramWrFifoMaskData => du1DramWrFifoMaskData,
      du1DramWrFifoWrEn => du1DramWrFifoWrEn,
      dHmbDramAddrFifoAddr => dHmbDramAddrFifoAddr,
      dHmbDramAddrFifoCmd => dHmbDramAddrFifoCmd,
      dHmbDramAddrFifoFull => dHmbDramAddrFifoFull,
      dHmbDramAddrFifoWrEn => dHmbDramAddrFifoWrEn,
      dHmbDramRdDataValid => dHmbDramRdDataValid,
      dHmbDramRdFifoDataOut => dHmbDramRdFifoDataOut,
      dHmbDramWrFifoDataIn => dHmbDramWrFifoDataIn,
      dHmbDramWrFifoFull => dHmbDramWrFifoFull,
      dHmbDramWrFifoMaskData => dHmbDramWrFifoMaskData,
      dHmbDramWrFifoWrEn => dHmbDramWrFifoWrEn,
      dHmbPhyInitDoneForLvfpga => dHmbPhyInitDoneForLvfpga,
      dLlbDramAddrFifoAddr => dLlbDramAddrFifoAddr,
      dLlbDramAddrFifoCmd => dLlbDramAddrFifoCmd,
      dLlbDramAddrFifoFull => dLlbDramAddrFifoFull,
      dLlbDramAddrFifoWrEn => dLlbDramAddrFifoWrEn,
      dLlbDramRdDataValid => dLlbDramRdDataValid,
      dLlbDramRdFifoDataOut => dLlbDramRdFifoDataOut,
      dLlbDramWrFifoDataIn => dLlbDramWrFifoDataIn,
      dLlbDramWrFifoFull => dLlbDramWrFifoFull,
      dLlbDramWrFifoMaskData => dLlbDramWrFifoMaskData,
      dLlbDramWrFifoWrEn => dLlbDramWrFifoWrEn,
      dLlbPhyInitDoneForLvfpga => dLlbPhyInitDoneForLvfpga,
      TopLevelClkOut => TopLevelClkOut,
      ReliableClkOut => ReliableClkOut,
      rBaseClksValid => rBaseClksValid,
      tDiagramActive => tDiagramActive,
      rDiagramReset => rDiagramReset,
      aDiagramReset => aDiagramReset,
      rDerivedClockLostLockError => rDerivedClockLostLockError,
      rGatedBaseClksValid => rGatedBaseClksValid,
      aSafeToEnableGatedClks => aSafeToEnableGatedClks
    );

end architecture behavioral;
