-------------------------------------------------------------------------------
--
-- File: DFlopBoolFallingEdge.vhd
-- Author: Craig Conway
-- Original Project: SMC4
-- Date: 28 November 2006
--
-------------------------------------------------------------------------------
-- (c) 2006 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--    This creates a falling edge flip-flop with a "hard" 
--  syn_hier attribute so that hopefully the enable logic
--  won't get merged with the D logic.
--
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;

library work;
  use work.PkgNiUtilities.all;

entity DFlopBoolFallingEdge is
  generic (kResetVal : boolean := false;
           kAsyncReg : string := "false");
  port (
    aReset, cEn  : in boolean;
    Clk : in std_logic;
    cD   : in boolean;
    cQ   : out boolean := kResetVal
  );

end DFlopBoolFallingEdge;

architecture rtl of DFlopBoolFallingEdge is

  --vhook_sigstart
  signal cQ_SL: std_logic;
  --vhook_sigend

begin

  --vhook_e DFlopFallingEdge
  --vhook_a kResetVal To_StdLogic(kResetVal)
  --vhook_a cD To_StdLogic(cD)
  --vhook_a cQ cQ_SL
  DFlopFallingEdgex: entity work.DFlopFallingEdge (rtl)
    generic map (
      kResetVal => To_StdLogic(kResetVal),  -- in  std_logic := '0'
      kAsyncReg => kAsyncReg)               -- in  string := "false"
    port map (
      aReset => aReset,           -- in  boolean
      cEn    => cEn,              -- in  boolean
      Clk    => Clk,              -- in  std_logic
      cD     => To_StdLogic(cD),  -- in  std_logic
      cQ     => cQ_SL);           -- out std_logic := kResetVal

  cQ <= to_Boolean(cQ_SL);

end rtl;

-- The following comment is a checksum VScan uses to determine whether this
-- file has been modified.  Please don't try to get around it.  It's there
-- for a reason.
--VScan_CS 4932421
