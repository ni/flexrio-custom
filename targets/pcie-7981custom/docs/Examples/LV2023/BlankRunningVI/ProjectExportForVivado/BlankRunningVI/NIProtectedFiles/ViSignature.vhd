-- (c) 2005 National Instruments Corporation.

library IEEE;
  use IEEE.std_logic_1164.all;

library work;
  use work.PkgRegister.all;

entity ViSignature is
  generic (
    kHostReadWidthIn : POSITIVE := 2;
    kHostReadWidthOut : POSITIVE := 129
  );

  port (
   Clk : in std_logic ;
   reset : in std_logic ;
   clkHostReadFromReshold : in std_logic_vector(kHostReadWidthIn-1 downto 0);
   clkHostReadToReshold : out std_logic_vector(kHostReadWidthOut-1 downto 0)
  );

end entity;

architecture rtl of ViSignature is

begin

  -- Output the data for one clock cycle when a read is made, 0 otherwise
  clkHostReadToReshold(kHostReadWidthOut - 1 downto 1) <= std_logic_vector(kViSignatureDefault) when clkHostReadFromReshold(0) = '1'
                                                     else (others=>'0');
  -- the DataValidPulse is just the read pulse wrapped back
  clkHostReadToReshold(0) <= clkHostReadFromReshold(0);
    
end rtl;

