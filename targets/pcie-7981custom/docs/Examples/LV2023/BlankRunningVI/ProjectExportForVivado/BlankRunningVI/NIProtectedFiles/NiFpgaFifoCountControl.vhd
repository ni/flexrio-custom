-------------------------------------------------------------------------------
--
-- File: NiFpgaFifoCountControl.vhd
-- Author: Dustyn Blasig
-- Original Project: LabVIEW FPGA Fifos
-- Date: 20 October 2008
--
-------------------------------------------------------------------------------
-- (c) 2005 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--
--   the following entity handles the enable chain for the count ports going
--   from the fifo resource to the diagram. the fifo count ports are slightly
--   more complex than other resholder ports because the read and write ports
--   can affect the output of the count so we need to ensure we only allow
--   refresh our count when enable in is asserted and hold that value until
--   we're told we can return a new value. because we have to return the count
--   on the cycle it's requested we have to allow the incoming count to
--   passthrough on the first cycle of enable in but then maintain its value
--   until enable in pulses again.
--
--   another way to solve the timing issue would be to pull the next count
--   values from the fifo components to the top-level so we could register them
--   here. however, the ni core fifo component doesn't currently export those
--   values and it seems like it isn't worth doing that work at the moment to
--   remove one register.
--
-------------------------------------------------------------------------------

library ieee, work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.PkgNiUtilities.all;

entity NiFpgaFifoCountControl is
  generic (
    kWidth : positive;
    kInSCL : boolean
    );
  port (
    aReset          : in  boolean;
    Clk             : in  std_logic;
    cReset          : in  boolean;
    cEnableIn       : in  boolean;
    cEnableOutClear : in  boolean;
    cEnableOut      : out boolean;
    cCountIn        : in  unsigned(kWidth-1 downto 0);
    cCountOut       : out unsigned(kWidth-1 downto 0)
    );
end NiFpgaFifoCountControl;

architecture rtl of NiFpgaFifoCountControl is
  
  signal cEnableInPulse : boolean;

  signal cCountInQual, cCountInQualReg, cCountOutLoc
    : unsigned(cCountIn'range);

begin

  -----------------------------------------------------------------------------
  -- Enable Pulse Generation
  -----------------------------------------------------------------------------

  -- for standard operation we want to pulse the enable to the count register
  -- for one cycle. however, if we're in a single-cycle timed loop the enable
  -- in becomes a pulse by definition so each cycle it's high we need to
  -- re-register the values. 
  
  GenTimedLoop : if kInSCL generate
    cEnableInPulse <= cEnableIn;
  end generate GenTimedLoop;

  GenOthers : if not kInSCL generate
    signal cEnableInReg : boolean;
  begin
    EnableInReg : process (aReset, Clk)
    begin
      if aReset then
        cEnableInReg <= false;
      elsif rising_edge(Clk) then
        cEnableInReg <= cEnableIn;
      end if;
    end process EnableInReg;
    cEnableInPulse <= cEnableIn and not cEnableInReg;
  end generate GenOthers;

  -----------------------------------------------------------------------------
  -- Count Register and Assignment
  -----------------------------------------------------------------------------

  -- to ensure we always output a stable count even if the count coming from
  -- the fifo is fluctuating during a synchronous reset we zero out the count.
  -- this might seem a bit strange in some cases but its better than us
  -- throwing some garbage value out.

  cCountInQual <= cCountIn when not cReset else (others => '0');

  CountReg : process (aReset, Clk)
  -- the count value is latched to ensure the output count won't change
  -- between enable cycles even if the input count is changing due to reads
  -- and writes.
  begin
    if aReset then
      cCountInQualReg <= (others => '0');
    elsif rising_edge(Clk) then
      if cEnableInPulse then
        cCountInQualReg <= cCountInQual;
      end if;
    end if;
  end process CountReg;

  cCountOutLoc <= cCountInQual when cEnableInPulse else
                  cCountInQualReg;

  -----------------------------------------------------------------------------
  -- Output Assignments
  -----------------------------------------------------------------------------
  
  cEnableOut <= cEnableIn and not cEnableOutClear;
  cCountOut  <= cCountOutLoc;
  
end rtl;
