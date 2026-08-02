-------------------------------------------------------------------------------
--
-- File: DmaPortCommIfcComponentInputStateHolder.vhd
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
--   This component latches the stream state for an input stream.  It latches
-- it as flushing when the stream is enabled and receives a disable request
-- and unlatches it when the stream actually moves out of the enabled state.
-- This is done so that the diagram immediately sees the flushing state when
-- it begins a disable but before the actual state reports flushing.
--   
-------------------------------------------------------------------------------


library IEEE;
  use IEEE.std_logic_1164.all;
  use IEEE.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;
  use work.PkgDmaPortCommIfcStreamStates.all;

entity DmaPortCommIfcComponentInputStateHolder is
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
end DmaPortCommIfcComponentInputStateHolder;

architecture rtl of DmaPortCommIfcComponentInputStateHolder is

  signal vFlushingLatch, vFlushingLatchNx : boolean;

begin

  -- The flushing state should get latched whenever the stream is in the enabled state
  -- and there is a stop request and it should hold until the stream moves out of the
  -- enabled state.
  vFlushingLatchNx <= (vStopRequest and vStreamState = Enabled) or (vFlushingLatch 
    and vStreamState = Enabled);
  
  LatchFlushingState: process (aReset, ViClk)
  begin
    if aReset then
      vFlushingLatch <= false;
    elsif rising_edge(ViClk) then
      vFlushingLatch <= vFlushingLatchNx;
    end if;
  end process LatchFlushingState;
  
  vStreamStateOut <= Flushing when vFlushingLatch else vStreamState;


end rtl;
