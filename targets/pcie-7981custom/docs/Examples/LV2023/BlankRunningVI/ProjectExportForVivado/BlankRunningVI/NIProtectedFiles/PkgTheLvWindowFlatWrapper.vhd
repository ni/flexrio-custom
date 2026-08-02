------------------------------------------------------------------------------
--
-- File: PkgTheLvWindowFlatWrapper.vhd
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

package PkgTheLvWindowFlatWrapper is

  component TheLvWindowFlatWrapper is
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
  end component;

end package PkgTheLvWindowFlatWrapper;
