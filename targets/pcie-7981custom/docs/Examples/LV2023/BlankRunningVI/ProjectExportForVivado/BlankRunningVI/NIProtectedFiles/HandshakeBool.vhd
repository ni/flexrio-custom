-------------------------------------------------------------------------------
--
-- File: HandshakeBool.vhd
-- Author: Craig Conway
-- Original Project: NICores
-- Date: 13 September 2002
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
--  IClk and OClk.
--      It captures the assertion of iSig and creates a pulse on
--  oSig.
--      iReady asserts when it is safe to assert iPush again.
--
--      Refer to HandshakeBase for more information.
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity HandshakeBool is
  port (
    aReset:     in  boolean;

    IClk:       in  std_logic;
    iSig:       in  boolean;
    iReady:     out boolean;

    OClk:       in  std_logic;
    oSig:       out boolean
  );
end HandshakeBool;

architecture struct of HandshakeBool is

begin

  --vhook_e HandshakeBase
  --vhook_a kDataWidth 2
  --vhook_a iPush iSig
  --vhook_a iData open
  --vhook_a iStoredData open
  --vhook_a oDataValid osig
  --vhook_a oDataAck true
  --vhook_a oData open
  HandshakeBasex: entity work.HandshakeBase (behavior)
    generic map (
      kDataWidth => 2)  -- in  integer := 32
    port map (
      aReset      => aReset,  -- in  boolean
      IClk        => IClk,    -- in  std_logic
      iPush       => iSig,    -- in  boolean
      iData       => open,    -- in  std_logic_vector(kDataWidth-1 downto 0) := ( others 
      iStoredData => open,    -- out std_logic_vector(kDataWidth-1 downto 0)
      iReady      => iReady,  -- out boolean
      OClk        => OClk,    -- in  std_logic
      oDataValid  => osig,    -- out boolean
      oDataAck    => true,    -- in  boolean := true
      oData       => open);   -- out std_logic_vector(kDataWidth-1 downto 0)

end struct;
