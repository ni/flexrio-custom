-------------------------------------------------------------------------------
--
-- File: PkgRegister.vhd
--
-------------------------------------------------------------------------------
--
-- Purpose:
--  This package contains all the information for registers that are part
--  of the register framework.
--
-- Top-level VI Controls and Indicators
-- Each control and indicator has 5 constants associated with it:
-- (1)           *: address offset
-- (2)      *Width: bit-width of the register
-- (3)    *Default: initial value of the register
-- (4)      *Index: Internal use only. The Index is used to select an address
--                  decode in the address decode vector that is handshaked to
--                  the clock domain containing this particular register
-- (5) *ShiftCount: Internal use only.  Number of bus accesses required to
--                  transfer the data in this register.
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;

package PkgRegister is

  -----------------------------------------------------------------------------
  -- Top-level VI Controls and Indicators
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Registers for Internal Use Only                                           
  -----------------------------------------------------------------------------

  constant kViControl : natural := 16#2FFF8#;
  constant kViControlWidth : natural := 32;
  constant kViControlDefault : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";
  constant kViControlIndex : natural := 49150;
  constant kViControlShiftCount : natural := 1;

  constant kDiagramReset : natural := 16#2FFFC#;
  constant kDiagramResetWidth : natural := 32;
  constant kDiagramResetDefault : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";
  constant kDiagramResetIndex : natural := 49151;
  constant kDiagramResetShiftCount : natural := 1;

  constant kViSignature : natural := 16#2FFF4#;
  constant kViSignatureWidth : natural := 128;
  constant kViSignatureDefault : std_logic_vector(127 downto 0) := "01100011101101000110111110111110111111010111000110000000010001100110100000101111110101011100010001100000110011110101101001001001";
  constant kViSignatureIndex : natural := 49149;
  constant kViSignatureShiftCount : natural := 4;

  -----------------------------------------------------------------------------
end PkgRegister;

package body PkgRegister is
end PkgRegister;
