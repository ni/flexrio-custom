-------------------------------------------------------------------------------
--
-- File: DmaPortCommIfcComponentOutputStateHolder.vhd
-- Author: Matthew Koenn
-- Original Project: LvFPGA CHInCh Interface
-- Date: 21 October 2008
--
-------------------------------------------------------------------------------
-- (c) 2008 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
-- 
-- Purpose:
--   
--   The output state holder is used to hold a copy of the stream state in the
-- ViClk domain.  This is generally just the value of the stream state 
-- transferred from the BusClk domain, except that an output stream will
-- latch the Disabled state to report to the diagram when a stream stop
-- request is received from the diagram.
--   
-------------------------------------------------------------------------------


library IEEE;
  use IEEE.std_logic_1164.all;
  use IEEE.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;
  use work.PkgDmaPortCommIfcStreamStates.all;

entity DmaPortCommIfcComponentOutputStateHolder is
  port(
    
    aReset : in  boolean;
    
    -- ViClk : The clock from the VI diagram.
    ViClk   : in std_logic; 
        
    
    -------------------------------------------------------------------------------------
    -- State Transition signals
    -------------------------------------------------------------------------------------
    
    -- vStreamStateOut : The state of the stream to report to the VI diagram.
    vStreamStateOut : out StreamState_t;
    
    -- vStreamState : The actual current state of the stream.
    vStreamState : in StreamState_t;
    
    -- vStopRequest : A strobe bit indicating when a stream stop is requested.
    vStopRequest : in boolean
    
  );
end DmaPortCommIfcComponentOutputStateHolder;

architecture rtl of DmaPortCommIfcComponentOutputStateHolder is

  signal vDisabledLatch, vDisabledLatchNx : boolean;

begin

  -- The flushing state should get latched whenever the stream is in the enabled state
  -- and there is a stop request and it should hold until the stream moves out of the
  -- enabled state.
  vDisabledLatchNx <= (vStopRequest and vStreamState = Enabled) or (vDisabledLatch 
    and vStreamState = Enabled);
  
  LatchDisabledState: process (aReset, ViClk)
  begin
    if aReset then
      vDisabledLatch <= false;
    elsif rising_edge(ViClk) then
      vDisabledLatch <= vDisabledLatchNx;
    end if;
  end process LatchDisabledState;
  
  vStreamStateOut <= Disabled when vDisabledLatch else vStreamState;


end rtl;
