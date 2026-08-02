library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.PkgNiUtilities.all;

entity NiFpgaAG_00000000_WhileLoop is
		port (
			reset : in std_logic;
			enable_in : in std_logic;
			enable_out : out std_logic;
			enable_clr : in std_logic;
			iteration : in std_logic_vector(31 downto 0);
			cont : out std_logic_vector(0 downto 0)
		);
end NiFpgaAG_00000000_WhileLoop;

architecture vhdl_labview of NiFpgaAG_00000000_WhileLoop is

	constant c_0 : std_logic_vector(0 downto 0) := "0";
	signal s_constant_86 : std_logic_vector(0 downto 0) := "0"; -- B

begin
	enable_out <= enable_in;
	cont <= s_constant_86;

end vhdl_labview;

