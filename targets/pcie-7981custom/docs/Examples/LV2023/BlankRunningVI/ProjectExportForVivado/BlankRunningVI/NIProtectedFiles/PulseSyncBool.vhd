-------------------------------------------------------------------------------
--
-- File: PulseSyncBool.vhd
-- Author: Craig Conway
-- Original Project: DSF Input/Output Engine for DFC
-- Date: 24 January 2000
--
-------------------------------------------------------------------------------
-- (c) 2002 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--      This module handshakes boolean data from one clock domain
--  to another independent of the relative clock frequencies or phases of
--  IClk and OClk.  It ensures that oSig will remain asserted as long
--  as iSig remains asserted.
--      Refer to PulseSyncBase for more information.
--
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity PulseSyncBool is
  port (
    aReset:  in  boolean;

    IClk:    in  std_logic;
    iSig:    in  boolean;

    OClk:    in  std_logic;
    oSig:    out boolean
  );
end PulseSyncBool;

architecture behavior of PulseSyncBool is

  signal iSigSL: std_logic;
  signal oSigSL: std_logic;

begin

  -- Convert iSig to std_logic
  iSigSL <= '1' when iSig else '0';

  --vhook_e PulseSyncBase
  --vhook_a iClkEn true
  --vhook_a iSig iSigSL
  --vhook_a iStatusOfoSig open
  --vhook_a oClkEn true
  --vhook_a oSigCE oSigSL
  --vhook_a oSig open
  --vhook_a oSigReturn oSigSL
  PulseSyncBasex: entity work.PulseSyncBase (behavior)
    port map (
      aReset        => aReset,  -- in  boolean
      IClk          => IClk,    -- in  std_logic
      iClkEn        => true,    -- in  boolean
      iSig          => iSigSL,  -- in  std_logic
      iStatusOfoSig => open,    -- out std_logic
      OClk          => OClk,    -- in  std_logic
      oClkEn        => true,    -- in  boolean
      oSigCE        => oSigSL,  -- out std_logic
      oSig          => open,    -- out std_logic
      oSigReturn    => oSigSL); -- in  std_logic

  -- Convert oSigSL back to boolean
  oSig <= oSigSL='1';

end behavior;

-- The following comment is a checksum VScan uses to determine whether this
-- file has been modified.  Please don't try to get around it.  It's there
-- for a reason.
--VScan_CS 5071919
