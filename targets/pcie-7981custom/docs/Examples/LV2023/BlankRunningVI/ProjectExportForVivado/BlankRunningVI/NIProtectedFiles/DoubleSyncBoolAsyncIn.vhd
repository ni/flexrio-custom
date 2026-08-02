-------------------------------------------------------------------------------
--
-- File: DoubleSyncBoolAsyncIn.vhd
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
--    This is a simple double synchronizer for an asynchronous
--  boolean input.
--    This module does not automatically cause VScan to suppress
--  clock crossing warnings, although if aSig is driven from
--  a glitch-free source (such as a top-level glitch-free input
--  or a flip-flop), VScan may not require an explanation.
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;

entity DoubleSyncBoolAsyncIn is
  generic (
    kResetVal : boolean := false
  );
  port (
    aSig:   in  boolean;     -- must be a glitch-free input

    aOReset: in boolean;     -- can drive this with false if needed
    OClk:   in  std_logic;
    oSig:   out boolean := kResetVal
  );
end DoubleSyncBoolAsyncIn;

architecture rtl of DoubleSyncBoolAsyncIn is

  function To_StdLogic ( x : boolean) return std_logic is
  begin
    if x then return '1'; else return '0'; end if;
  end function To_StdLogic;

  signal aSigSL, oSigSL : std_logic;

begin

  aSigSL <= To_StdLogic(aSig);

  --vhook_e DoubleSyncSlAsyncIn
  --vhook_a kResetVal To_StdLogic(kResetVal)
  --vhook_a aSig aSigSL
  --vhook_a oSig oSigSL
  DoubleSyncSlAsyncInx: entity work.DoubleSyncSlAsyncIn (rtl)
    generic map (
      kResetVal => To_StdLogic(kResetVal))  -- in  std_logic := '0'
    port map (
      aSig    => aSigSL,   -- in  std_logic
      aOReset => aOReset,  -- in  boolean
      OClk    => OClk,     -- in  std_logic
      oSig    => oSigSL);  -- out std_logic := kResetVal

  oSig <= oSigSL='1';

end rtl;
