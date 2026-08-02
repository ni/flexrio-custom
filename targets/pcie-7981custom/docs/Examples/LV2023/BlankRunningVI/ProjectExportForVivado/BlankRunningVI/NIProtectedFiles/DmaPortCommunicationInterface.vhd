-------------------------------------------------------------------------------
--
-- File: DmaPortCommunicationInterface.vhd
-- Author: Florin Hurgoi
-- Original Project: LabVIEW FPGA
-- Date: 16 June 2011
--
-------------------------------------------------------------------------------
-- (c) 2007 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--
--   This is the top level file for the DmaPort communication interface for LabVIEW FPGA.
--   It connects directly the NI DMA IP and the interface to TheWindow.
--
--  This is a simple wrapper for DmaPortFixedDmaCommunicationInterface, 
--  which hides the DMA Port interfaces that are intended for targets 
--  that need DMA or MasterPort channels in the fixed logic. The unused 
--  DmaPort interfaces are tied to default values. Targets that do not 
--  need any DMA channels in the fixed logic could simply instantiate 
--  DmaPortFixedDmaCommunicationInterface directly. This component is 
--  provided for simplicity, but more importantly for backward 
--  compatibility. Targets that existed prior to the creation of the 
--  fixed-DMA version of the communication interface are designed to 
--  instantiate DmaPortCommunicationInterface.
-------------------------------------------------------------------------------

--StaticVHDL Component

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;

  use work.PkgDmaPortCommIfcArbiter.all;

  -- The pkg that specifies several signals used by the user VI and register
  -- framework.
  use work.PkgCommunicationInterface.all;
  use work.PkgDmaPortCommunicationInterface.all;

  -- The pkg containing some configuration info on the communication interface,
  -- such as the number of DMA channels and size of the DMA FIFO's.
  use work.PkgCommIntConfiguration.all;

  -- The pkg containing information on the DmaPort configuration.
   use work.PkgNiDmaConfig.all;

  -- The pkg containing the definitions for the FIFO interface signals.
  use work.PkgDmaPortDmaFifos.all;
  use work.PkgDmaPortDmaFifosFlatTypes.all;

  -- This package contains the definitions for the interface between the NI DMA IP and
  -- the application specific logic
  use work.PkgNiDma.all;

  -- The package contain data types definitions needed to define Master Port interfaces.
  use work.PkgDmaPortCommIfcMasterPort.all;
  use work.PkgDmaPortCommIfcMasterPortFlatTypes.all;

entity DmaPortCommunicationInterface is
  port(

    -- This is the asynchronous reset for the interface.
    aReset : in boolean;

    -- This is a synchronous reset for the interface.
    dReset : in boolean;

    -- PCIe slot.
    DmaClk : in std_logic;
    -- The clock on which the interrupts coming from the LvFpga VI are synchronized.
    IrqClk : in std_logic;

    ---------------------------------------------------------------------------
    -- NI DMA IP signals
    ---------------------------------------------------------------------------

    dNiDmaInputRequestToDma : out NiDmaInputRequestToDma_t;
    dNiDmaInputRequestFromDma : in NiDmaInputRequestFromDma_t;
    dNiDmaInputDataToDma : out NiDmaInputDataToDma_t;
    dNiDmaInputDataFromDma : in NiDmaInputDataFromDma_t;
    dNiDmaInputStatusFromDma : in NiDmaInputStatusFromDma_t;

    dNiDmaOutputRequestToDma : out NiDmaOutputRequestToDma_t;
    dNiDmaOutputRequestFromDma : in NiDmaOutputRequestFromDma_t;
    dNiDmaOutputDataFromDma : in NiDmaOutputDataFromDma_t;

    dNiDmaHighSpeedSinkFromDma : in NiDmaHighSpeedSinkFromDma_t;

    ---------------------------------------------------------------------------
    -- DMA FIFO signals
    ---------------------------------------------------------------------------

    -- These are the DMA ports used by LV FPGA.
    dInputStreamInterfaceFromFifo : in
      InputStreamInterfaceFromFifoArray_t(Larger(kNumberOfDmaChannels,1)-1 downto 0);
    dInputStreamInterfaceToFifo : out
      InputStreamInterfaceToFifoArray_t(Larger(kNumberOfDmaChannels,1)-1 downto 0);
    dOutputStreamInterfaceFromFifo : in
      OutputStreamInterfaceFromFifoArray_t(Larger(kNumberOfDmaChannels,1)-1 downto 0);
    dOutputStreamInterfaceToFifo : out
      OutputStreamInterfaceToFifoArray_t(Larger(kNumberOfDmaChannels,1)-1 downto 0);

    ---------------------------------------------------------------------------
    -- Master Port signals
    ---------------------------------------------------------------------------

    dNiFpgaMasterWriteRequestFromMasterArray : in
      NiFpgaMasterWriteRequestFromMasterArray_t (Larger(kNumberOfMasterPorts,1)-1 downto 0);
    dNiFpgaMasterWriteRequestToMasterArray : out
      NiFpgaMasterWriteRequestToMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);
    dNiFpgaMasterWriteDataFromMasterArray : in
      NiFpgaMasterWriteDataFromMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);
    dNiFpgaMasterWriteDataToMasterArray : out
      NiFpgaMasterWriteDataToMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);
    dNiFpgaMasterWriteStatusToMasterArray : out
      NiFpgaMasterWriteStatusToMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);

    dNiFpgaMasterReadRequestFromMasterArray : in
      NiFpgaMasterReadRequestFromMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);
    dNiFpgaMasterReadRequestToMasterArray : out
      NiFpgaMasterReadRequestToMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);
    dNiFpgaMasterReadDataToMasterArray : out
      NiFpgaMasterreadDataToMasterArray_t(Larger(kNumberOfMasterPorts,1)-1 downto 0);

    ---------------------------------------------------------------------------
    -- IRQ signals
    ---------------------------------------------------------------------------

    -- The signals coming from the LvFpga VI.
    iLvFpgaIrq : in IrqToInterfaceArray_t(Larger(kNumberOfIrqs,1)-1 downto 0);

    -- The level interrupt line(s)
    dIrq : out std_logic_vector(kNumberOfIrqs-1 downto 0);


    ---------------------------------------------------------------------------
    -- Register Port signals
    ---------------------------------------------------------------------------

    -- The signals from the register access component advertising reads and
    -- writes.
    dRegPortIn   : in RegPortIn_t;

    -- The signals going to the register access component to indicate read
    -- responses and readiness.
    dRegPortOut  : out  RegPortOut_t

  );
end DmaPortCommunicationInterface;

architecture struct of DmaPortCommunicationInterface is

  --vhook_sigstart
  signal dNiFpgaInputArbReq: NiDmaArbReqArray_t(kNiFpgaFixedInputPorts-1 downto 0);
  signal dNiFpgaInputDataToDmaArray: NiDmaInputDataToDmaArray_t(kNiFpgaFixedInputPorts-1 downto 0);
  signal dNiFpgaInputRequestToDmaArray: NiDmaInputRequestToDmaArray_t(kNiFpgaFixedInputPorts-1 downto 0);
  signal dNiFpgaOutputArbReq: NiDmaArbReqArray_t(kNiFpgaFixedOutputPorts-1 downto 0);
  signal dNiFpgaOutputRequestToDmaArray: NiDmaOutputRequestToDmaArray_t(kNiFpgaFixedOutputPorts-1 downto 0);
  --vhook_sigend

  -- A null array has no entries. Since this component connects no 
  -- fixed-logic DMA channels, this array needs no entries.
  signal dFixedLogicDmaIrq : IrqStatusArray_t (-1 downto 0);

begin

  --vhook_e DmaPortFixedDmaCommunicationInterface
  --vhook_a dNiFpgaOutputRequestFromDmaArray open
  --vhook_a dNiFpgaOutputDataFromDmaArray open
  --vhook_a dNiFpgaInputArbGrant open
  --vhook_a dNiFpgaInputRequestFromDmaArray open
  --vhook_a dNiFpgaInputStatusFromDmaArray open
  --vhook_a dNiFpgaOutputArbGrant open
  --vhook_a dNiFpgaInputDataFromDmaArray open
  DmaPortFixedDmaCommunicationInterfacex: entity work.DmaPortFixedDmaCommunicationInterface (struct)
    port map (
      aReset                                   => aReset,                                
      dReset                                   => dReset,                                
      DmaClk                                   => DmaClk,                                
      IrqClk                                   => IrqClk,                                
      dNiDmaInputRequestToDma                  => dNiDmaInputRequestToDma,               
      dNiDmaInputRequestFromDma                => dNiDmaInputRequestFromDma,             
      dNiDmaInputDataToDma                     => dNiDmaInputDataToDma,                  
      dNiDmaInputDataFromDma                   => dNiDmaInputDataFromDma,                
      dNiDmaInputStatusFromDma                 => dNiDmaInputStatusFromDma,              
      dNiDmaOutputRequestToDma                 => dNiDmaOutputRequestToDma,              
      dNiDmaOutputRequestFromDma               => dNiDmaOutputRequestFromDma,            
      dNiDmaOutputDataFromDma                  => dNiDmaOutputDataFromDma,               
      dNiDmaHighSpeedSinkFromDma               => dNiDmaHighSpeedSinkFromDma,            
      dInputStreamInterfaceFromFifo            => dInputStreamInterfaceFromFifo,         
      dInputStreamInterfaceToFifo              => dInputStreamInterfaceToFifo,           
      dOutputStreamInterfaceFromFifo           => dOutputStreamInterfaceFromFifo,        
      dOutputStreamInterfaceToFifo             => dOutputStreamInterfaceToFifo,          
      dNiFpgaMasterWriteRequestFromMasterArray => dNiFpgaMasterWriteRequestFromMasterArray,
      dNiFpgaMasterWriteRequestToMasterArray   => dNiFpgaMasterWriteRequestToMasterArray,
      dNiFpgaMasterWriteDataFromMasterArray    => dNiFpgaMasterWriteDataFromMasterArray,
      dNiFpgaMasterWriteDataToMasterArray      => dNiFpgaMasterWriteDataToMasterArray,
      dNiFpgaMasterWriteStatusToMasterArray    => dNiFpgaMasterWriteStatusToMasterArray,
      dNiFpgaMasterReadRequestFromMasterArray  => dNiFpgaMasterReadRequestFromMasterArray,
      dNiFpgaMasterReadRequestToMasterArray    => dNiFpgaMasterReadRequestToMasterArray,
      dNiFpgaMasterReadDataToMasterArray       => dNiFpgaMasterReadDataToMasterArray,    
      dNiFpgaInputRequestToDmaArray            => dNiFpgaInputRequestToDmaArray,         
      dNiFpgaInputRequestFromDmaArray          => open,                                  
      dNiFpgaInputDataToDmaArray               => dNiFpgaInputDataToDmaArray,            
      dNiFpgaInputDataFromDmaArray             => open,                                  
      dNiFpgaInputStatusFromDmaArray           => open,                                  
      dNiFpgaOutputRequestToDmaArray           => dNiFpgaOutputRequestToDmaArray,        
      dNiFpgaOutputRequestFromDmaArray         => open,                                  
      dNiFpgaOutputDataFromDmaArray            => open,                                  
      dNiFpgaInputArbReq                       => dNiFpgaInputArbReq,                    
      dNiFpgaInputArbGrant                     => open,                                  
      dNiFpgaOutputArbReq                      => dNiFpgaOutputArbReq,                   
      dNiFpgaOutputArbGrant                    => open,                                  
      iLvFpgaIrq                               => iLvFpgaIrq,                            
      dFixedLogicDmaIrq                        => dFixedLogicDmaIrq,                     
      dIrq                                     => dIrq,                                  
      dRegPortIn                               => dRegPortIn,                            
      dRegPortOut                              => dRegPortOut);                          


 dNiFpgaInputRequestToDmaArray <= (others => kNiDmaInputRequestToDmaZero);
 dNiFpgaOutputArbReq <= (others => kNiDmaArbReqZero);
 dNiFpgaInputDataToDmaArray <= (others => kNiDmaInputDataToDmaZero);
 dNiFpgaOutputRequestToDmaArray <= (others => kNiDmaOutputRequestToDmaZero);
 dNiFpgaInputArbReq <= (others => kNiDmaArbReqZero);
 dFixedLogicDmaIrq <= (others => kIrqStatusToInterfaceZero);

end struct;
