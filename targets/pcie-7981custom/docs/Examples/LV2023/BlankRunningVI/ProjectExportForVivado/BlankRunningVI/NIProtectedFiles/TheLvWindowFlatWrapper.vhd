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
    DmaClk :  in std_logic;
    BusClk :  in std_logic;
    ReliableClkIn :  in std_logic;
    PllClk80 :  in std_logic;
    DlyRefClk :  in std_logic;
    PxieClk100 :  in std_logic;
    DramClkLvFpga :  in std_logic;
    Dram0ClkSocket :  in std_logic;
    Dram1ClkSocket :  in std_logic;
    Dram0ClkUser :  in std_logic;
    Dram1ClkUser :  in std_logic;


    -----------------------------------
    -- Handshaking signals for derived
    -- clocks on external clocks
    -----------------------------------

    -----------------------------------
    -- Clock/Sync IO Node ports
    -----------------------------------
    pIntSync100 : in std_logic;
    aIntClk10 : in std_logic;


    -----------------------------------
    -- Target Method and Properties ports
    -----------------------------------
    bdIFifoRdData : out  std_logic_vector(63 downto 0);
    bdIFifoRdDataValid : out std_logic;
    bdIFifoRdReadyForInput : in std_logic;
    bdIFifoRdIsError : out std_logic;
    bdIFifoWrData : in  std_logic_vector(63 downto 0);
    bdIFifoWrDataValid : in std_logic;
    bdIFifoWrReadyForOutput : out std_logic;
    bdAxiStreamRdFromClipTData : in  std_logic_vector(31 downto 0);
    bdAxiStreamRdFromClipTLast : in std_logic;
    bdAxiStreamRdFromClipTValid : in std_logic;
    bdAxiStreamRdToClipTReady : out std_logic;
    bdAxiStreamWrToClipTData : out  std_logic_vector(31 downto 0);
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
    --ID Signals from Routing CLIP
    bRoutingClipPresent : out std_logic;
    bRoutingClipNiCompatible : out std_logic;

    BusClkTrigger : in std_logic;
    abBusResetTrigger : in std_logic;

    -- From PkgBaRegPort
    -- RegPortIn_t Size = Address 28 Data 64 WrStrobes 8 RdStrobes 8 = 108
    -- RegPortOut_t Size = Data 64 + Ack 1 = 65
    bTriggerRoutingBaRegPortInAddress : in std_logic_vector(27 downto 0);
    bTriggerRoutingBaRegPortInData : in std_logic_vector(63 downto 0);
    bTriggerRoutingBaRegPortInWtStrobe : in std_logic_vector(7 downto 0);
    bTriggerRoutingBaRegPortInRdStrobe : in std_logic_vector(7 downto 0);

    bTriggerRoutingBaRegPortOutData : out std_logic_vector(63 downto 0);
    bTriggerRoutingBaRegPortOutAck : out std_logic;

    aPxiTrigDataIn : in  std_logic_vector(7 downto 0);
    aPxiTrigDataOut : out std_logic_vector(7 downto 0);
    aPxiTrigDataTri : out std_logic_vector(7 downto 0);
    aPxiStarData : in std_logic;


    -----------------------------------------------------------------------------
    --Dram Interface
    -----------------------------------------------------------------------------
    aDramReady               : in    std_logic;
    du0DramAddrFifoAddr      : out   std_logic_vector(28 downto 0);
    du0DramAddrFifoCmd       : out   std_logic_vector(2 downto 0);
    du0DramAddrFifoFull      : in    std_logic;
    du0DramAddrFifoWrEn      : out   std_logic;
    du0DramPhyInitDone       : in    std_logic;
    du0DramRdDataValid       : in    std_logic;
    du0DramRdFifoDataOut     : in    std_logic_vector(255 downto 0);
    du0DramWrFifoDataIn      : out   std_logic_vector(255 downto 0);
    du0DramWrFifoFull        : in    std_logic;
    du0DramWrFifoMaskData    : out   std_logic_vector(31 downto 0);
    du0DramWrFifoWrEn        : out   std_logic;
    du1DramAddrFifoAddr      : out   std_logic_vector(28 downto 0);
    du1DramAddrFifoCmd       : out   std_logic_vector(2 downto 0);
    du1DramAddrFifoFull      : in    std_logic;
    du1DramAddrFifoWrEn      : out   std_logic;
    du1DramPhyInitDone       : in    std_logic;
    du1DramRdDataValid       : in    std_logic;
    du1DramRdFifoDataOut     : in    std_logic_vector(255 downto 0);
    du1DramWrFifoDataIn      : out   std_logic_vector(255 downto 0);
    du1DramWrFifoFull        : in    std_logic;
    du1DramWrFifoMaskData    : out   std_logic_vector(31 downto 0);
    du1DramWrFifoWrEn        : out   std_logic;

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

  -- Std logic to boolean
  signal aBusResetBool : boolean;
  signal bRegPortTimeoutBool : boolean;

  -- Internal signals for record types
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

  ----------------------------------
  -- Convert std_logic to boolean
  ----------------------------------
  aBusResetBool <= aBusReset = '1';
  bRegPortTimeoutBool <= bRegPortTimeout = '1';

  -----------------------------------
  -- Convert flat inputs to records
  -----------------------------------
  bRegPortInInternal <= BuildRegPortIn(bRegPortIn);

  dInputStreamInterfaceToFifoInternal <= UnflattenStreamInterface(dInputStreamInterfaceToFifo);
  dOutputStreamInterfaceToFifoInternal <= UnflattenStreamInterface(dOutputStreamInterfaceToFifo);

  -- Convert flat Master Port inputs
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


  -----------------------------------
  -- Convert record outputs to flat
  -----------------------------------
  bRegPortOut <= to_StdLogicVector(bRegPortOutInternal);

  dInputStreamInterfaceFromFifo <= FlattenStreamInterface(dInputStreamInterfaceFromFifoInternal);
  dOutputStreamInterfaceFromFifo <= FlattenStreamInterface(dOutputStreamInterfaceFromFifoInternal);

  bIrqToInterface <= to_StdLogicVector(bIrqToInterfaceInternal);

  -- Convert flat Master Port outputs
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

  -----------------------------------
  -- Instantiate TheWindow
  -----------------------------------
  TheLvWindow : entity work.TheWindow (behavioral)
    port map(
     -----------------------------------
    -- CUSTOM BOARD IO
    -----------------------------------
      -----------------------------------
      -- Communication interface ports
      -----------------------------------
      -- Reset ports
      aBusReset => aBusResetBool,

      -- Register Access/ PIO Ports
      bRegPortIn => bRegPortInInternal,
      bRegPortOut => bRegPortOutInternal,
      bRegPortTimeout => bRegPortTimeoutBool,

      -- DMA Stream Ports
      dInputStreamInterfaceToFifo => dInputStreamInterfaceToFifoInternal,
      dInputStreamInterfaceFromFifo => dInputStreamInterfaceFromFifoInternal,
      dOutputStreamInterfaceToFifo => dOutputStreamInterfaceToFifoInternal,
      dOutputStreamInterfaceFromFifo => dOutputStreamInterfaceFromFifoInternal,

      -- IRQ Ports
      bIrqToInterface => bIrqToInterfaceInternal,

      -- MasterPort Ports
      dNiFpgaMasterWriteRequestFromMaster => dNiFpgaMasterWriteRequestFromMasterInternal,
      dNiFpgaMasterWriteRequestToMaster => dNiFpgaMasterWriteRequestToMasterInternal,
      dNiFpgaMasterWriteDataFromMaster => dNiFpgaMasterWriteDataFromMasterInternal,
      dNiFpgaMasterWriteDataToMaster => dNiFpgaMasterWriteDataToMasterInternal,
      dNiFpgaMasterWriteStatusToMaster => dNiFpgaMasterWriteStatusToMasterInternal,

      dNiFpgaMasterReadRequestFromMaster => dNiFpgaMasterReadRequestFromMasterInternal,
      dNiFpgaMasterReadRequestToMaster => dNiFpgaMasterReadRequestToMasterInternal,
      dNiFpgaMasterReadDataToMaster => dNiFpgaMasterReadDataToMasterInternal,

      -----------------------------------
      -- Clocks from TopLevel
      -----------------------------------
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


      -----------------------------------
      -- Handshaking signals for derived
      -- clocks on external clocks
      -----------------------------------

      -----------------------------------
      -- Clock/Sync IO Node ports
      -----------------------------------
      pIntSync100 => pIntSync100,
      aIntClk10 => aIntClk10,


      -----------------------------------
      -- Target Method and Properties ports
      -----------------------------------
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

      -----------------------------------
      -- Pass through LabVIEW FPGA ports
      -----------------------------------

      ----------------------------------------
      -- Trigger Routing Socketed CLIP
      ----------------------------------------
      PxieClk100Trigger => PxieClk100Trigger,
      pIntSync100Trigger => pIntSync100Trigger,
      dTdcAssert => dTdcAssert,
      dDevClkEn => dDevClkEn,
      sTdcDeassert => sTdcDeassert,
      aIntClk10Trigger => aIntClk10Trigger,
      --ID Signals from Routing CLIP
      bRoutingClipPresent => bRoutingClipPresent,
      bRoutingClipNiCompatible => bRoutingClipNiCompatible,

      BusClkTrigger => BusClkTrigger,
      abBusResetTrigger => abBusResetTrigger,

      -- From PkgBaRegPort
      -- RegPortIn_t Size = Address 28 Data 64 WrStrobes 8 RdStrobes 8 = 108
      -- RegPortOut_t Size = Data 64 + Ack 1 = 65
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


      -----------------------------------------------------------------------------
      --Dram Interface
      -----------------------------------------------------------------------------
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

      -----------------------------------
      -- Clocks from TheWindow
      -----------------------------------
      TopLevelClkOut => TopLevelClkOut,
      ReliableClkOut => ReliableClkOut,

      -----------------------------------
      -- Diagram/Reset/Clock status
      -----------------------------------
      rBaseClksValid => rBaseClksValid,
      tDiagramActive => tDiagramActive,
      rDiagramReset => rDiagramReset,
      aDiagramReset => aDiagramReset,
      rDerivedClockLostLockError => rDerivedClockLostLockError,
      rGatedBaseClksValid => rGatedBaseClksValid,
      aSafeToEnableGatedClks => aSafeToEnableGatedClks
    );

end architecture behavioral;
