-------------------------------------------------------------------------------
--
-- File: TimeoutManager.vhd
-- Author: Dustyn Blasig
-- Original Project: LabVIEW FPGA Fifos
-- Date: 18 February 2005
--
-------------------------------------------------------------------------------
-- (c) 2005 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--
--  generic timeout manager created for the fpga fifos but can be used by any
--  modules requring a simple timeout scheme. 
--
--  a negative timeout value implies an infinite timeout if the limit is 0 or
--  positive, we count down by one each clock cycle. cTimeout becomes valid the
--  clock cycle after the assertion of cStart. once asserted, cTimeout will
--  remain asserted until cStart is asserted again. if cLimit is 0 or 1
--  cTimeout will not deassert as the following cycle is the timed out cycle.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.PkgNiUtilities.all;

entity TimeoutManager is
  generic (
    kWidth : positive := 32
    );
  port (
    aReset   : in  boolean;
    Clk      : in  std_logic;
    cStart   : in  std_logic;
    cLimit   : in  std_logic_vector(kWidth-1 downto 0);
    cTimeout : out std_logic
    );
end TimeoutManager;

architecture rtl of TimeoutManager is

  signal cCounter    : unsigned(kWidth-1 downto 0);
  signal cTimeoutLoc : std_logic;
  
begin

  -- create a simple down counter. xilinx optimized this
  -- to a fast counter automatically. the default value on
  -- reset doesn't really matter so we just picked zero.

  CountDownProc : process(aReset, Clk)
  begin
    if aReset then
      cCounter <= to_unsigned(0, kWidth);  -- Doesn't matter what we store
    elsif rising_edge(Clk) then
      if cStart = '1' or cLimit(cLimit'left)='1' then
        cCounter <= unsigned(cLimit);
      elsif cTimeoutLoc = '1' then
        cCounter <= cCounter;
      else
        cCounter <= cCounter - 1;
      end if;
    end if;
  end process CountDownProc;

  -- We signal a timeout when the counter gets to either
  -- one or zero. Therefore, we can just wait until the
  -- top kWidth-1 bits of the signal become all zeros.

  cTimeoutLoc <= to_stdlogic(cCounter(cCounter'left downto 1) = 0);
  cTimeout    <= cTimeoutLoc;

end rtl;
