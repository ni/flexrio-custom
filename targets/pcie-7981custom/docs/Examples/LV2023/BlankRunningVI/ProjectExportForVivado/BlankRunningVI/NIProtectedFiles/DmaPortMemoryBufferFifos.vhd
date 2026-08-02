-------------------------------------------------------------------------------
--
-- File: DmaPortMemoryBufferFifos.vhd
-- Author: Newton Petersen
-- Original Project: LabVIEW FPGA Sleipnir FIFOs
-- Date: 29 August 2023
--
-------------------------------------------------------------------------------
-- (c) 2023 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--
-- This file is very similar to DmaPortCommIfcFifos.vhd. Its main difference
-- is different types on the ports that encode possibly different widths of
-- signals than 'normal/pre-existing' dma. With some additional work I think
-- the two files could be merged if made more generic. The different types
-- are a bit of a rabbit hole that would take a while to sort out. I did take 
-- small steps to make some of this a tad more generic aligned with this
-- longer term goal.
-------------------------------------------------------------------------------

--StaticVHDL Component

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;

  -- The pkg that specifies several signals used by the user VI and register
  -- framework.
  use work.PkgCommunicationInterface.all;
  use work.PkgDmaPortCommunicationInterface.all;

  -- The pkg containing some configuration info on the communication interface,
  -- such as the number of DMA channels and size of the DMA FIFO's.
  use work.PkgCommIntConfiguration.all;

  -- The pkg containing the definitions for the FIFO interface signals.
  use work.PkgDmaPortDmaFifos.all;

  -- The pkg containing definitions for DMA stream states.
  use work.PkgDmaPortCommIfcStreamStates.all;

  use work.PkgNiDma.all;
  
entity DmaPortMemoryBufferFifos is
  generic(
    kNumChannels : natural;
    kConfig : DmaChannelConfArray_t
  );
  port(

    aDiagramReset : in boolean;

    aBusReset : in boolean;

    BusClk : in std_logic;

    -- Assign this to a default value of '0' for now because there is no hook up
    -- for this clock in LV FPGA yet.
    DefaultClk : in std_logic := '0';

    ---------------------------------------------------------------------------
    -- DMA Interface to the VI
    ---------------------------------------------------------------------------

    -- DmaClkArray : The individual clocks for read/write access for each
    --               DMA channel.
    DmaClkArray       : in  MemoryBufferDmaClkArray_t;

    -- DmaFlagArray : The flags indicating when the channels are full or empty,
    --                depending on the direction.
    DmaFlagArray        : out MemoryBufferDmaFlagArray_t;

    -- DmaDataInArray : The input data for a DMA input channel.
    DmaDataInArray      : in  MemoryBufferDmaDataArray_t;

    -- DmaDataOutArray : The output data for a DMA output channel.
    DmaDataOutArray     : out MemoryBufferDmaDataArray_t;

    -- DmaTimeoutArray : The number of clock cycles to wait for a timeout for
    --                   each DMA channel.
    DmaTimeoutArray     : in  MemoryBufferDmaTimeoutArray_t;

    -- The enable chain for performing reads/writes.
    DmaEnableInArray    : in  MemoryBufferDmaEnableArray_t;
    DmaEnableClearArray : in  MemoryBufferDmaEnableArray_t;
    DmaEnableOutArray   : out MemoryBufferDmaEnableArray_t;
    
    -- The handshaking signals, used for FIFO methods with the Handshaking interface
    -- Depending on the FIFO type, these signals are:
    --    T2H (Input)  FIFO - In = Input Valid, Out = Ready For Input
    --    H2T (Output) FIFO - In = Ready For Output, Out = Output Valid
    DmaHandshakingInArray  : in  MemoryBufferDmaHandshakingArray_t;
    DmaHandshakingOutArray : out MemoryBufferDmaHandshakingArray_t;

    -- Enable chain for the flush method
    DmaFlushEnableInArray    : in MemoryBufferDmaEnableArray_t;  
    DmaFlushEnableClearArray : in MemoryBufferDmaEnableArray_t;
    DmaFlushEnableOutArray   : out MemoryBufferDmaEnableArray_t;       
            
    -- The DMA FIFO count values.
    DmaCtCountArray     : out MemoryBufferDmaCountArray_t;

    -- The enable chain associated with the FIFO count.
    DmaCtEnableInArray       : in  MemoryBufferDmaEnableArray_t;
    DmaCtEnableOutClearArray : in  MemoryBufferDmaEnableArray_t;
    DmaCtEnableOutArray      : out MemoryBufferDmaEnableArray_t;

    -- The enable chain for stream state in the DMA clock domain.
    DmaStreamStateEnableInArray : in MemoryBufferDmaEnableArray_t := (others=>'0');
    DmaStreamStateEnableOutArray : out MemoryBufferDmaEnableArray_t;
    DmaStreamStateEnableClearArray : in MemoryBufferDmaEnableArray_t := (others=>'0');
    DmaStreamStateOutArray : out
      StreamStateValueArray_t(kNumChannels-1 downto 0);

    -- The enable chain for stream state in the default clock domain.
    dStreamStateEnableInArray : in MemoryBufferDmaEnableArray_t := (others=>'0');
    dStreamStateEnableOutArray : out MemoryBufferDmaEnableArray_t;
    dStreamStateEnableClearArray : in MemoryBufferDmaEnableArray_t := (others=>'0');
    dStreamStateOutArray : out StreamStateValueArray_t(kNumChannels-1 downto 0);

    -- The current stream state value, used to access the stream state from the
    -- Get Stream State resholder in a single cycle timed loop.
    dCurrentStreamStateArray : out StreamStateValueArray_t
      (kNumChannels-1 downto 0);

    -- The enable chain for start, stop, and stop with flush requests.
    dStartRequestEnableInArray : in MemoryBufferDmaEnableArray_t := (others=>'0');
    dStartRequestEnableOutArray : out MemoryBufferDmaEnableArray_t;
    dStartRequestEnableClearArray : in MemoryBufferDmaEnableArray_t := (others=>'0');

    dStopRequestEnableInArray : in MemoryBufferDmaEnableArray_t := (others=>'0');
    dStopRequestEnableOutArray : out MemoryBufferDmaEnableArray_t;
    dStopRequestEnableClearArray : in MemoryBufferDmaEnableArray_t := (others=>'0');

    dStopWithFlushRequestEnableInArray : in MemoryBufferDmaEnableArray_t := (others=>'0');
    dStopWithFlushRequestEnableOutArray : out MemoryBufferDmaEnableArray_t;
    dStopWithFlushRequestEnableClearArray : in MemoryBufferDmaEnableArray_t := (others=>'0');
    dStopWithFlushRequestTimeoutArray : in MemoryBufferDmaTimeoutArray_t := (others=>(others=>'0'));
    dStopWithFlushRequestTimedOutArray : out MemoryBufferDmaFlagArray_t;


    ---------------------------------------------------------------------------
    -- DMA Input Communication Interface Signals
    ---------------------------------------------------------------------------

    -- bInputStreamInterfaceToFifo : This signal is used for the control lines
    --   going from the top level communication interface to the FIFOs within
    --   TheWindow.
    bInputStreamInterfaceToFifo : in InputStreamInterfaceToFifoArray_t(
      kNumChannels - 1 downto 0);

    -- bInputStreamInterfaceFromFifo : This signal is used for the control
    --   lines going from the FIFOs within TheWindow to the top level
    --   communication interface.
    bInputStreamInterfaceFromFifo : out InputStreamInterfaceFromFifoArray_t(
      kNumChannels - 1 downto 0);

    ---------------------------------------------------------------------------
    -- DMA Output Communication Interface Signals
    ---------------------------------------------------------------------------

    -- bOutputStreamInterfaceToFifo : This signal is used for the control lines
    --   going from the top level communication interface to the FIFOs within
    --   TheWindow.
    bOutputStreamInterfaceToFifo : in OutputStreamInterfaceToFifoArray_t(
      kNumChannels - 1 downto 0);

    -- bOutputStreamInterfaceFromFifo : This signal is used for the control
    --   lines going from the FIFOs within TheWindow to the top level
    --   communication interface.
    bOutputStreamInterfaceFromFifo : out OutputStreamInterfaceFromFifoArray_t(
      kNumChannels - 1 downto 0)

  );
end DmaPortMemoryBufferFifos;

architecture struct of DmaPortMemoryBufferFifos is
  
  type CountUnsignedArray_t is array(kNumChannels-1 downto 0) of
    unsigned(31 downto 0);
  signal DmaCountUnsignedArray : CountUnsignedArray_t;

  -- Obtain the FIFO depths in Data Bus width words from the FIFO depths in samples.
  constant kFifoDepthInDataBusWidthWords : DmaChannelConfArray_t(kConfig'range)
  := GetFifoDepths(kConfig);

  -- This is an array of constants that define the FIFOs' data width as it is defined
  -- by the user.
  constant kFifoDataWidthArray : FifoDataWidthArray_t :=
    GetFifoDataWidth(kConfig);

begin

  DmaBlk:block

  begin

    DmaComponents: for i in 0 to kConfig'length - 1 generate

      DmaInput: if kConfig(i).Mode = NiFpgaMemoryBufferWriter generate

        -- Make sure the FIFO size from the configuration array is 2^n-1 for an
        -- input stream.
        assert Log2(kConfig(i).FifoDepth+2) >
               Log2(kConfig(i).FifoDepth+1)
          report "kFifoDepth should be 2**N-1 where N is an integer."
          severity failure;

        assert kConfig(i).FifoDepth+1 > kNiDmaDataWidthInBytes
          report "kFifoDepth should be at least the number of samples that fit in two data bus words."
          severity failure;

        assert kConfig(i).FifoDepth+1 > kConfig(i).ElementsPerClockCycle
          report "kFifoDepth should be at least the number of elements per write."
          severity failure;

        --vhook_e DmaPortCommIfcInputFifoInterface
        --vhook_a kFifoDepth kFifoDepthInDataBusWidthWords(i).FifoDepth
        --vhook_a kSampleWidth kConfig(i).FifoWidth
        --vhook_a kNumOfSamplesPerWrite kConfig(i).ElementsPerClockCycle
        --vhook_a kScl kConfig(i).SCL
        --vhook_a kCountScl kConfig(i).CountSCL
        --vhook_a kSignExtend kConfig(i).SignedData
        --vhook_a kPeerToPeer (kConfig(i).Mode = NiFpgaPeerToPeerWriter)
        --vhook_a kFxpType kConfig(i).FxpType
        --vhook_a kDisableOnFifoTimeout kConfig(i).DisableOnFifoTimeout
        --vhook_a kViClkIsDefaultClk kConfig(i).DmaClkIsDefaultClk
        --vhook_a kWriteUsingHandshaking kConfig(i).InterfaceIsHandshaking
        --vhook_a ViClk DmaClkArray(i)
        --vhook_a bInputStreamInterfaceToFifo bInputStreamInterfaceToFifo(i)
        --vhook_a bInputStreamInterfaceFromFifo bInputStreamInterfaceFromFifo(i)
        --vhook_a vDataIn DmaDataInArray(i)(kFifoDataWidthArray(i)-1 downto 0)
        --vhook_a vFull DmaFlagArray(i)
        --vhook_a vCtCount DmaCountUnsignedArray(i)
        --vhook_a vCtEnableIn DmaCtEnableInArray(i)
        --vhook_a vCtEnableOutClear DmaCtEnableOutClearArray(i)
        --vhook_a vCtEnableOut DmaCtEnableOutArray(i)
        --vhook_a vTimeout DmaTimeoutArray(i)
        --vhook_a vEnableIn DmaEnableInArray(i)
        --vhook_a vEnableOut DmaEnableOutArray(i)
        --vhook_a vEnableClear DmaEnableClearArray(i)
        --vhook_a vFlushEnableIn DmaFlushEnableInArray(i)
        --vhook_a vFlushEnableOut DmaFlushEnableOutArray(i)
        --vhook_a vFlushEnableClear DmaFlushEnableClearArray(i)  
        --vhook_a vInputValid DmaHandshakingInArray(i)
        --vhook_a vReadyForInput DmaHandshakingOutArray(i)
        --vhook_a vStreamStateEnableIn DmaStreamStateEnableInArray(i)
        --vhook_a vStreamStateEnableOut DmaStreamStateEnableOutArray(i)
        --vhook_a vStreamStateEnableClear DmaStreamStateEnableClearArray(i)
        --vhook_a vStreamStateOut DmaStreamStateOutArray(i)
        --vhook_a dStreamStateEnableIn dStreamStateEnableInArray(i)
        --vhook_a dStreamStateEnableOut dStreamStateEnableOutArray(i)
        --vhook_a dStreamStateEnableClear dStreamStateEnableClearArray(i)
        --vhook_a dStreamStateOut dStreamStateOutArray(i)
        --vhook_a dCurrentStreamState dCurrentStreamStateArray(i)
        --vhook_a dStartRequestEnableIn dStartRequestEnableInArray(i)
        --vhook_a dStartRequestEnableOut dStartRequestEnableOutArray(i)
        --vhook_a dStartRequestEnableClear dStartRequestEnableClearArray(i)
        --vhook_a dStopRequestEnableIn dStopRequestEnableInArray(i)
        --vhook_a dStopRequestEnableOut dStopRequestEnableOutArray(i)
        --vhook_a dStopRequestEnableClear dStopRequestEnableClearArray(i)
        --vhook_a dStopWithFlushRequestEnableIn dStopWithFlushRequestEnableInArray(i)
        --vhook_a dStopWithFlushRequestEnableOut dStopWithFlushRequestEnableOutArray(i)
        --vhook_a dStopWithFlushRequestEnableClear dStopWithFlushRequestEnableClearArray(i)
        --vhook_a dStopWithFlushRequestTimeout signed(dStopWithFlushRequestTimeoutArray(i))
        --vhook_a dStopWithFlushRequestTimedOut dStopWithFlushRequestTimedOutArray(i)
        DmaPortCommIfcInputFifoInterfacex: entity work.DmaPortCommIfcInputFifoInterface (structure)
          generic map (
            kFifoDepth             => kFifoDepthInDataBusWidthWords(i).FifoDepth,        
            kSampleWidth           => kConfig(i).FifoWidth,                    
            kNumOfSamplesPerWrite  => kConfig(i).ElementsPerClockCycle,        
            kScl                   => kConfig(i).SCL,                          
            kCountScl              => kConfig(i).CountSCL,                     
            kSignExtend            => kConfig(i).SignedData,                   
            kFxpType               => kConfig(i).FxpType,                      
            kPeerToPeer            => false,
            kDisableOnFifoTimeout  => kConfig(i).DisableOnFifoTimeout,         
            kViClkIsDefaultClk     => kConfig(i).DmaClkIsDefaultClk,           
            kWriteUsingHandshaking => kConfig(i).InterfaceIsHandshaking)       
          port map (
            aDiagramReset                    => aDiagramReset,                           
            aBusReset                        => aBusReset,                               
            BusClk                           => BusClk,                                  
            bInputStreamInterfaceToFifo      => bInputStreamInterfaceToFifo(i),          
            bInputStreamInterfaceFromFifo    => bInputStreamInterfaceFromFifo(i),        
            ViClk                            => DmaClkArray(i),                          
            vDataIn                          => DmaDataInArray(i)(kFifoDataWidthArray(i)-1 downto 0),
            vFull                            => DmaFlagArray(i),                         
            vTimeout                         => DmaTimeoutArray(i),                      
            vEnableIn                        => DmaEnableInArray(i),                     
            vEnableOut                       => DmaEnableOutArray(i),                    
            vEnableClear                     => DmaEnableClearArray(i),                  
            vFlushEnableIn                   => DmaFlushEnableInArray(i),                
            vFlushEnableOut                  => DmaFlushEnableOutArray(i),               
            vFlushEnableClear                => DmaFlushEnableClearArray(i),             
            vCtCount                         => DmaCountUnsignedArray(i),                
            vCtEnableIn                      => DmaCtEnableInArray(i),                   
            vCtEnableOut                     => DmaCtEnableOutArray(i),                  
            vCtEnableOutClear                => DmaCtEnableOutClearArray(i),             
            vInputValid                      => DmaHandshakingInArray(i),                
            vReadyForInput                   => DmaHandshakingOutArray(i),               
            DefaultClk                       => DefaultClk,                              
            vStreamStateEnableIn             => DmaStreamStateEnableInArray(i),          
            vStreamStateEnableOut            => DmaStreamStateEnableOutArray(i),         
            vStreamStateEnableClear          => DmaStreamStateEnableClearArray(i),       
            vStreamStateOut                  => DmaStreamStateOutArray(i),               
            dStreamStateEnableIn             => dStreamStateEnableInArray(i),            
            dStreamStateEnableOut            => dStreamStateEnableOutArray(i),           
            dStreamStateEnableClear          => dStreamStateEnableClearArray(i),         
            dStreamStateOut                  => dStreamStateOutArray(i),                 
            dCurrentStreamState              => dCurrentStreamStateArray(i),             
            dStartRequestEnableIn            => dStartRequestEnableInArray(i),           
            dStartRequestEnableOut           => dStartRequestEnableOutArray(i),          
            dStartRequestEnableClear         => dStartRequestEnableClearArray(i),        
            dStopRequestEnableIn             => dStopRequestEnableInArray(i),            
            dStopRequestEnableOut            => dStopRequestEnableOutArray(i),           
            dStopRequestEnableClear          => dStopRequestEnableClearArray(i),         
            dStopWithFlushRequestEnableIn    => dStopWithFlushRequestEnableInArray(i),
            dStopWithFlushRequestEnableOut   => dStopWithFlushRequestEnableOutArray(i),
            dStopWithFlushRequestEnableClear => dStopWithFlushRequestEnableClearArray(i),
            dStopWithFlushRequestTimeout     => signed(dStopWithFlushRequestTimeoutArray(i)),
            dStopWithFlushRequestTimedOut    => dStopWithFlushRequestTimedOutArray(i));


        DmaCtCountArray(i) <= std_logic_vector(
          resize(DmaCountUnsignedArray(i),DmaCtCountArray(i)'length));

        bOutputStreamInterfaceFromFifo(i) <= kOutputStreamInterfaceFromFifoZero;

        DmaDataOutArray(i) <= (others=>'0');

      end generate; --DmaInput

      DmaOutput: if kConfig(i).Mode = NiFpgaMemoryBufferReader generate

        -- Make sure the FIFO size from the configuration array is computed with formula:
        -- 2^n+6*ElementsPerClockCycle-1 for an output stream.  The actual FIFO is 2^n-1 
        -- and the flip flop pop buffer is 6*ElementsPerClockCycle.
        assert 
          Log2(kConfig(i).FifoDepth-6*kConfig(i).ElementsPerClockCycle+2) > 
          Log2(kConfig(i).FifoDepth-6*kConfig(i).ElementsPerClockCycle+1)
          report "kFifoDepth should be 2**N+6*ElementsPerClockCycle-1 where N is an integer."
          severity failure;

        assert kConfig(i).FifoDepth-6*kConfig(i).ElementsPerClockCycle+1 >
        kNiDmaDataWidthInBytes
          report "kFifoDepth should be at least the number of samples that fit in two data bus words."
          severity failure;

        assert kConfig(i).FifoDepth-6*kConfig(i).ElementsPerClockCycle+1 >
        kConfig(i).ElementsPerClockCycle
          report "kFifoDepth should be at least the number of elements per read."
          severity failure;

        --vhook_e DmaPortCommIfcOutputFifoInterface
        --vhook_a kFifoDepth kFifoDepthInDataBusWidthWords(i).FifoDepth
        --vhook_a kSampleWidth kConfig(i).FifoWidth
        --vhook_a kNumOfSamplesPerRead kConfig(i).ElementsPerClockCycle
        --vhook_a kScl kConfig(i).SCL
        --vhook_a kCountScl kConfig(i).CountSCL
        --vhook_a kFxpType kConfig(i).FxpType
        --vhook_a kPeerToPeer (kConfig(i).Mode = NiFpgaPeerToPeerReader)
        --vhook_a kDisableOnFifoTimeout kConfig(i).DisableOnFifoTimeout
        --vhook_a kViClkIsDefaultClk kConfig(i).DmaClkIsDefaultClk
        --vhook_a kReadUsingHandshaking kConfig(i).InterfaceIsHandshaking
        --vhook_a ViClk DmaClkArray(i)
        --vhook_a bOutputStreamInterfaceToFifo bOutputStreamInterfaceToFifo(i)
        --vhook_a bOutputStreamInterfaceFromFifo bOutputStreamInterfaceFromFifo(i)
        --vhook_a vDataOut DmaDataOutArray(i)(kFifoDataWidthArray(i)-1 downto 0)
        --vhook_a vEmpty DmaFlagArray(i)
        --vhook_a vCtCount DmaCountUnsignedArray(i)
        --vhook_a vCtEnableIn DmaCtEnableInArray(i)
        --vhook_a vCtEnableOutClear DmaCtEnableOutClearArray(i)
        --vhook_a vCtEnableOut DmaCtEnableOutArray(i)
        --vhook_a vTimeout DmaTimeoutArray(i)
        --vhook_a vEnableIn DmaEnableInArray(i)
        --vhook_a vEnableOut DmaEnableOutArray(i)
        --vhook_a vEnableClear DmaEnableClearArray(i)
        --vhook_a vOutputValid DmaHandshakingOutArray(i)
        --vhook_a vReadyForOutput DmaHandshakingInArray(i)
        --vhook_a vStreamStateEnableIn DmaStreamStateEnableInArray(i)
        --vhook_a vStreamStateEnableOut DmaStreamStateEnableOutArray(i)
        --vhook_a vStreamStateEnableClear DmaStreamStateEnableClearArray(i)
        --vhook_a vStreamStateOut DmaStreamStateOutArray(i)
        --vhook_a dStreamStateEnableIn dStreamStateEnableInArray(i)
        --vhook_a dStreamStateEnableOut dStreamStateEnableOutArray(i)
        --vhook_a dStreamStateEnableClear dStreamStateEnableClearArray(i)
        --vhook_a dStreamStateOut dStreamStateOutArray(i)
        --vhook_a dCurrentStreamState dCurrentStreamStateArray(i)
        --vhook_a dStartRequestEnableIn dStartRequestEnableInArray(i)
        --vhook_a dStartRequestEnableOut dStartRequestEnableOutArray(i)
        --vhook_a dStartRequestEnableClear dStartRequestEnableClearArray(i)
        --vhook_a dStopRequestEnableIn dStopRequestEnableInArray(i)
        --vhook_a dStopRequestEnableOut dStopRequestEnableOutArray(i)
        --vhook_a dStopRequestEnableClear dStopRequestEnableClearArray(i)
        DmaPortCommIfcOutputFifoInterfacex: entity work.DmaPortCommIfcOutputFifoInterface (structure)
          generic map (
            kFifoDepth            => kFifoDepthInDataBusWidthWords(i).FifoDepth,         
            kSampleWidth          => kConfig(i).FifoWidth,                     
            kNumOfSamplesPerRead  => kConfig(i).ElementsPerClockCycle,         
            kFxpType              => kConfig(i).FxpType,                       
            kScl                  => kConfig(i).SCL,                           
            kCountScl             => kConfig(i).CountSCL,                      
            kPeerToPeer           => false,
            kDisableOnFifoTimeout => kConfig(i).DisableOnFifoTimeout,          
            kViClkIsDefaultClk    => kConfig(i).DmaClkIsDefaultClk,            
            kReadUsingHandshaking => kConfig(i).InterfaceIsHandshaking)        
          port map (
            aDiagramReset                  => aDiagramReset,                             
            aBusReset                      => aBusReset,                                 
            BusClk                         => BusClk,                                    
            ViClk                          => DmaClkArray(i),                            
            bOutputStreamInterfaceToFifo   => bOutputStreamInterfaceToFifo(i),           
            bOutputStreamInterfaceFromFifo => bOutputStreamInterfaceFromFifo(i),         
            vDataOut                       => DmaDataOutArray(i)(kFifoDataWidthArray(i)-1 downto 0),
            vEmpty                         => DmaFlagArray(i),                           
            vTimeout                       => DmaTimeoutArray(i),                        
            vEnableIn                      => DmaEnableInArray(i),                       
            vEnableOut                     => DmaEnableOutArray(i),                      
            vEnableClear                   => DmaEnableClearArray(i),                    
            vCtCount                       => DmaCountUnsignedArray(i),                  
            vCtEnableIn                    => DmaCtEnableInArray(i),                     
            vCtEnableOut                   => DmaCtEnableOutArray(i),                    
            vCtEnableOutClear              => DmaCtEnableOutClearArray(i),               
            vOutputValid                   => DmaHandshakingOutArray(i),                 
            vReadyForOutput                => DmaHandshakingInArray(i),                  
            DefaultClk                     => DefaultClk,                                
            vStreamStateEnableIn           => DmaStreamStateEnableInArray(i),            
            vStreamStateEnableOut          => DmaStreamStateEnableOutArray(i),           
            vStreamStateEnableClear        => DmaStreamStateEnableClearArray(i),         
            vStreamStateOut                => DmaStreamStateOutArray(i),                 
            dStreamStateEnableIn           => dStreamStateEnableInArray(i),              
            dStreamStateEnableOut          => dStreamStateEnableOutArray(i),             
            dStreamStateEnableClear        => dStreamStateEnableClearArray(i),           
            dStreamStateOut                => dStreamStateOutArray(i),                   
            dCurrentStreamState            => dCurrentStreamStateArray(i),               
            dStartRequestEnableIn          => dStartRequestEnableInArray(i),             
            dStartRequestEnableOut         => dStartRequestEnableOutArray(i),            
            dStartRequestEnableClear       => dStartRequestEnableClearArray(i),          
            dStopRequestEnableIn           => dStopRequestEnableInArray(i),              
            dStopRequestEnableOut          => dStopRequestEnableOutArray(i),             
            dStopRequestEnableClear        => dStopRequestEnableClearArray(i));          



        DmaCtCountArray(i) <= std_logic_vector(
          resize(DmaCountUnsignedArray(i),DmaCtCountArray(i)'length));

        Padding: if kFifoDataWidthArray(i) /= DmaDataOutArray(i)'length generate

          DmaDataOutArray(i)(DmaDataOutArray(i)'length-1 downto kFifoDataWidthArray(i)) <=
            (others => '0');

        end generate Padding;

        dStopWithFlushRequestEnableOutArray(i) <= '0';
        dStopWithFlushRequestTimedOutArray(i) <= '0';
        bInputStreamInterfaceFromFifo(i) <= kInputStreamInterfaceFromFifoZero;

      end generate; --DmaOutput

      DmaUnused: if kConfig(i).Mode = Disabled generate

        bInputStreamInterfaceFromFifo(i) <= kInputStreamInterfaceFromFifoZero;
        bOutputStreamInterfaceFromFifo(i) <= kOutputStreamInterfaceFromFifoZero;
        DmaDataOutArray(i) <= (others=>'0');
        DmaFlagArray(i) <= '0';
        DmaHandshakingOutArray(i) <= '0';
        DmaCtCountArray(i) <= (others=>'0');
        DmaEnableOutArray(i) <= '0';
        DmaStreamStateEnableOutArray(i) <= '0';
        DmaCtEnableOutArray(i) <= '0';
        DmaStreamStateOutArray(i) <= (others=>'0');
        dStreamStateOutArray(i) <= (others=>'0');
        dStreamStateEnableOutArray(i) <= '0';
        dCurrentStreamStateArray(i) <= (others=>'0');
        dStartRequestEnableOutArray(i) <= '0';
        dStopRequestEnableOutArray(i) <= '0';
        dStopWithFlushRequestEnableOutArray(i) <= '0';
        dStopWithFlushRequestTimedOutArray(i) <= '0';

      end generate; --DmaUnused

    end generate; --DmaComponents

  end block DmaBlk;

end struct;
