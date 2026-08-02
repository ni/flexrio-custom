-------------------------------------------------------------------------------
--
-- File: HandshakeSLV.vhd
-- Author: Craig Conway
-- Original Project: NICores
-- Date: 19 September 2002
--
-------------------------------------------------------------------------------
-- (c) 2002 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--      This module handshakes std_logic_vector data from one clock domain
--  to another independent of the relative clock frequencies or phases of
--  IClk and OClk.
--      It captures the data when iPush asserts and creates a pulse on
--  oDataValid when oData is valid.
--      iReady asserts when it is safe to assert iPush again.
--
--      Refer to HandshakeBase for more information.
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity HandshakeSLV is
  generic (
    kDataWidth : integer := 32
  );
  port (
    aReset:     in  boolean;

    IClk:       in  std_logic;
    iPush:      in  boolean;
    iData:      in  std_logic_vector(kDataWidth-1 downto 0) := (others => '0');
    iReady:     out boolean;

    OClk:       in  std_logic;
    oDataValid: out boolean;
    oData:      out std_logic_vector(kDataWidth-1 downto 0)
  );
end HandshakeSLV;

architecture struct of HandshakeSLV is

begin

  --vhook_e HandshakeBase HBx
  --vhook_a iStoredData open
  --vhook_a oDataAck true
  HBx: entity work.HandshakeBase (behavior)
    generic map (
      kDataWidth => kDataWidth)  -- in  integer := 32
    port map (
      aReset      => aReset,      -- in  boolean
      IClk        => IClk,        -- in  std_logic
      iPush       => iPush,       -- in  boolean
      iData       => iData,       -- in  std_logic_vector(kDataWidth-1 downto 0) := ( oth
      iStoredData => open,        -- out std_logic_vector(kDataWidth-1 downto 0)
      iReady      => iReady,      -- out boolean
      OClk        => OClk,        -- in  std_logic
      oDataValid  => oDataValid,  -- out boolean
      oDataAck    => true,        -- in  boolean := true
      oData       => oData);      -- out std_logic_vector(kDataWidth-1 downto 0)

end struct;
