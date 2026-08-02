-------------------------------------------------------------------------------
--
-- File: DmaPortCommIfcComponentStreamStateEnableChain.vhd
-- Author: Matthew Koenn
-- Original Project: LvFPGA CHInCh Interface
-- Date: 16 October 2008
--
-------------------------------------------------------------------------------
-- (c) 2008 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
-- 
-- Purpose:
--   
--   This is a component used to report the stream state to the VI diagram
-- in the ViClk domain.  This simply takes in the stream state and latches it
-- for output to the diagram when the enable in signal is strobed.
--   
-------------------------------------------------------------------------------


library IEEE;
  use IEEE.std_logic_1164.all;
  use IEEE.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;
  use work.PkgDmaPortCommIfcStreamStates.all;

entity DmaPortCommIfcComponentStreamStateEnableChain is
  generic(
  
    -- kSCL : Indicates whether this enable chain component is in a single cycle loop.
    kSCL : boolean := false
    
  );
  port(
    
    aReset : in  boolean;
    
    -- ViClk : The clock from the VI diagram.
    ViClk   : in std_logic; 
    
    -- vStreamState : The current state of the stream in the ViClk domain.
    vStreamState : in StreamStateValue_t;
    
    -- The enable chain for the stream state.
    vEnableIn : in std_logic;
    vEnableOut : out std_logic;
    vEnableClear : in std_logic;
    
    -- vStreamStateOut : The actual stream state output, qualified by 
    --                   vStreamStateEnableOut.
    vStreamStateOut : out StreamStateValue_t
    
  );
end DmaPortCommIfcComponentStreamStateEnableChain;

architecture rtl of DmaPortCommIfcComponentStreamStateEnableChain  is

  signal vEnableInDelay : std_logic;
  signal vEnableInPulse : std_logic;

begin

  ---------------------------------------------------------------------------------------
  -- SCL
  ---------------------------------------------------------------------------------------
  -- In the SCL case, no signal is registered
  SCL : if kSCL generate
    vEnableOut <= vEnableIn;
    vStreamStateOut <= vStreamState;
  end generate SCL;

  
  ---------------------------------------------------------------------------------------
  -- No SCL
  ---------------------------------------------------------------------------------------
  NoSCL : if not kSCL generate
  
    -- Create a pulse on the rising_edge of vEnableIn
    EnableInDelayer: process (aReset, ViClk)
    begin
      if aReset then
        vEnableInDelay <= '0';
      elsif rising_edge(ViClk) then
        vEnableInDelay <= vEnableIn;
      end if;
    end process EnableInDelayer;
  
    vEnableInPulse <= vEnableIn and not vEnableInDelay;


    -- Reset the enable out when the block is reset asynchronously.  Set the enable
    -- out and latch the stream state whenever the enable in is pulsed.
    EnableChainHandler: process (aReset, ViClk)
    begin
  
      if aReset then
      
        vEnableOut <= '0';
        vStreamStateOut <= to_StreamStateValue(Unlinked);
      
      elsif rising_edge(ViClk) then
      
        if vEnableClear = '1' then
          vEnableOut <= '0';
        elsif vEnableInPulse = '1' then
          vEnableOut <= '1';
          vStreamStateOut <= vStreamState;
        end if;
        
      end if;
  
    end process EnableChainHandler;
  
  end generate NoSCL;

end rtl;
