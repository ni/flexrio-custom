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
      dHmbDmaClkSocket : in std_logic;
      dLlbDmaClkSocket : in std_logic;

      -----------------------------------
      -- IO Node ports
      -----------------------------------
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
  end component;

end package PkgTheLvWindowFlatWrapper;