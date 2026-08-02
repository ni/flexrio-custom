------------------------------------------------------------------------------
--
-- File: InvisibleResholder.vhd
-- Date: 20 April 2010
--
------------------------------------------------------------------------------
-- (c) 2010 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
------------------------------------------------------------------------------
--
-- Purpose: This component gets generated only to request certain resources
--          which don't have any requesters on the diagram.
--
------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;

entity InvisibleResholder is
  -------------------------------------------
  -- Dynamically generated generics and ports
  -- BEGIN
  -------------------------------------------
    generic (
    kbusholddummyWidthOut : NATURAL := 2;
    kbusholddummyWidthIn : NATURAL := 1
  );

  port (
   Clk : in std_logic ;
   reset : in std_logic ;
   ToResbusholddummy : out std_logic_vector(kbusholddummyWidthOut-1 downto 0);
   FromResbusholddummy : in std_logic_vector(kbusholddummyWidthIn-1 downto 0)
  );

  -------------------------------------------
  -- Dynamically generated generics and ports
  -- END
  -------------------------------------------
end entity InvisibleResholder;

architecture rtl of InvisibleResholder is
  signal toggler : std_logic;
begin

 -- Hello World I'm Invisible. Don't peek!
 -- Just test code below
  MainPrc : process(reset, Clk)
  begin
    if reset = '1' then
      toggler <= '0';
    elsif rising_edge(Clk) then
      toggler <= not toggler;
    end if;
  end process MainPrc;

end architecture rtl;
