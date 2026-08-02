-------------------------------------------------------------------------------
--
-- File: DoubleSyncSlAsyncIn.vhd
-- Author: Craig Conway
-- Original Project: NICores
-- Date: 8 January 2009
--
-------------------------------------------------------------------------------
-- (c) 2009 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
-- Purpose:
--    This is a simple double synchronizer for an asynchronous
--  std_logic input.
--    This module does not automatically cause VScan to suppress
--  clock crossing warnings, although if aSig is driven from
--  a glitch-free source (such as a top-level glitch-free input
--  or a flip-flop), VScan may not require an explanation.
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;

entity DoubleSyncSlAsyncIn is
  generic (
    kResetVal : std_logic := '0'
  );
  port (
    aSig:   in  std_logic;     -- must be a glitch-free input

    aOReset: in boolean;     -- can drive this with false if needed
    OClk:   in  std_logic;
    oSig:   out std_logic := kResetVal
  );
end DoubleSyncSlAsyncIn;

architecture rtl of DoubleSyncSlAsyncIn is

begin

  --vhook_e DoubleSyncAsyncInBase
  --vhook_a oClkEn true
  DoubleSyncAsyncInBasex: entity work.DoubleSyncAsyncInBase (rtl)
    generic map (
      kResetVal => kResetVal)  -- in  std_logic := '0'
    port map (
      aSig    => aSig,     -- in  std_logic
      aOReset => aOReset,  -- in  boolean
      OClk    => OClk,     -- in  std_logic
      oClkEn  => true,     -- in  boolean := true
      oSig    => oSig);    -- out std_logic := kResetVal

end rtl;
