-------------------------------------------------------------------------------
--
-- File: PulseSyncBase.vhd
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
--   Handshakes between two clock domains to ensure a signal makes it across
-- as long it is synchronous to the input clock, no matter what the frequency
-- of the output clock is.  This is different from the handshake modules in
-- two ways:
--   First, the output remains asserted as long as the input remains asserted.
--   Second, instead of iReady, we have iStatusOfoSig.  This is basically a
-- double synchronized version of oSig in the IClk domain.  It allows you to
-- tell if the change in iSig made it to oSig.  This signal can be used as
-- a "ready" indicator for both polarities.  If you only care about rising
-- edges, then make sure you don't assert iSig while iStatusOfoSig is asserted.
-- If you also care about falling edges, then make sure you don't deassert
-- iSig while iStatusOfoSig is deasserted.
--
-- The cycle follows the pattern below:
-- Assert iSig for 1 IClk cycle
-- oSig asserts 1 IClk + 1 to 2 OClks later
-- iStatusOfoSig asserts 1 to 2 IClks after that
-- oSig deasserts 1 IClk + 1 to 2 OClks later
-- iStatusOfoSig deasserts after 1 to 2 IClks
--
--  So total cycle time is 5 to 7 IClks + 2 to 4 OClks
--
--  Note that there are three outputs, oSig, oSigCE, and iStatusOfoSig.
-- iStatusOfoSig lets you know that your signal made it to the OClk
-- domain.
--
--  If you use the base module, you have the option of breaking the
-- feedback from oSigCE to oSigReturn.  This allows you to process or
-- delay the return signal.  Note that once you assert oSigReturn,
-- you must keep it asserted until oSigCE deasserts. oSigReturn is directly
-- sampled in the IClk domain, so it MUST be driven into PulseSyncBase as
-- the output of a single FF clocked by OClk.
--
--
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity PulseSyncBase is
  port (
    aReset:        in  boolean;
    IClk:          in  std_logic;
    iClkEn:        in  boolean;
    iSig:          in  std_logic;
    iStatusOfoSig: out std_logic;

    OClk:          in  std_logic;
    oClkEn:        in  boolean;
    oSigCE:        out std_logic;
    oSig:          out std_logic;
    oSigReturn:    in  std_logic

  );
end PulseSyncBase;

architecture behavior of PulseSyncBase is

  --vhook_sigstart
  signal iNxHoldSigIn: std_logic;
  --vhook_sigend

  signal iSigOut_ms,
         iSigOut,
         iHoldSigIn,
         oHoldSigIn_ms,
         oLocalSigOut,
         oLocalSigOutCE : std_logic;
  attribute keep : string;
  attribute keep of iSigOut_ms: signal is "true";
  attribute keep of oHoldSigIn_ms: signal is "true";

begin

  -- ****** Start Here ******
  -- 1) Capture the input signal and hold it asserted
  -- as long as the input signal remains asserted.
  -- 6) Deassert iSigIn if the input signal has
  -- deasserted and the output signal iSigOut has
  -- asserted.
  iNxHoldSigIn <= iSig or (iHoldSigIn and not iSigOut);

  --vhook_e DFlop iHoldSigInx
  --vhook_a kAsyncReg "false"      
  --vhook_a kResetVal '0'
  --vhook_a Clk IClk
  --vhook_a cEn iClkEn
  --vhook_a cD iNxHoldSigIn
  --vhook_a cQ iHoldSigIn
  iHoldSigInx: entity work.DFlop (rtl)
    generic map (
      kResetVal => '0',      -- in  std_logic := '0'
      kAsyncReg => "false")  -- in  string := "false"
    port map (
      aReset => aReset,        -- in  boolean
      cEn    => iClkEn,        -- in  boolean
      Clk    => IClk,          -- in  std_logic
      cD     => iNxHoldSigIn,  -- in  std_logic
      cQ     => iHoldSigIn);   -- out std_logic := kResetVal

  -- 2) Now translate the captured signal to the OClk domain

  --vhook_e DFlop oHoldSigIn_msx
  --vhook_a kAsyncReg "true"      
  --vhook_a kResetVal '0'
  --vhook_a Clk OClk
  --vhook_a cEn true
  --vhook_a cD iHoldSigIn
  --vhook_a cQ oHoldSigIn_ms
  oHoldSigIn_msx: entity work.DFlop (rtl)
    generic map (
      kResetVal => '0',     -- in  std_logic := '0'
      kAsyncReg => "true")  -- in  string := "false"
    port map (
      aReset => aReset,         -- in  boolean
      cEn    => true,           -- in  boolean
      Clk    => OClk,           -- in  std_logic
      cD     => iHoldSigIn,     -- in  std_logic
      cQ     => oHoldSigIn_ms); -- out std_logic := kResetVal

  --vhook_e DFlop oLocalSigOutx
  --vhook_a kAsyncReg "true"      
  --vhook_a kResetVal '0'
  --vhook_a Clk OClk
  --vhook_a cEn true
  --vhook_a cD oHoldSigIn_ms
  --vhook_a cQ oLocalSigOut
  oLocalSigOutx: entity work.DFlop (rtl)
    generic map (
      kResetVal => '0',     -- in  std_logic := '0'
      kAsyncReg => "true")  -- in  string := "false"
    port map (
      aReset => aReset,         -- in  boolean
      cEn    => true,           -- in  boolean
      Clk    => OClk,           -- in  std_logic
      cD     => oHoldSigIn_ms,  -- in  std_logic
      cQ     => oLocalSigOut);  -- out std_logic := kResetVal

  -- 3) remove metastability -- this will create the output
  -- signal and will get synchronized back to IClk to
  -- clear iHoldSigIn

  --vhook_e DFlop oLocalSigOutCEx
  --vhook_a kAsyncReg "true"      
  --vhook_a kResetVal '0'
  --vhook_a Clk OClk
  --vhook_a cEn oClkEn
  --vhook_a cD oHoldSigIn_ms
  --vhook_a cQ oLocalSigOutCE
  oLocalSigOutCEx: entity work.DFlop (rtl)
    generic map (
      kResetVal => '0',      -- in  std_logic := '0'
      kAsyncReg => "true")   -- in  string := "true"
    port map (
      aReset => aReset,          -- in  boolean
      cEn    => oClkEn,          -- in  boolean
      Clk    => OClk,            -- in  std_logic
      cD     => oHoldSigIn_ms,   -- in  std_logic
      cQ     => oLocalSigOutCE); -- out std_logic := kResetVal

  -- 4b) translate output signal back to IClk domain

  --vhook_e DFlop iSigOut_msx
  --vhook_a kAsyncReg "true"      
  --vhook_a kResetVal '0'
  --vhook_a Clk IClk
  --vhook_a cEn true
  --vhook_a cD oSigReturn
  --vhook_a cQ iSigOut_ms
  iSigOut_msx: entity work.DFlop (rtl)
    generic map (
      kResetVal => '0',     -- in  std_logic := '0'
      kAsyncReg => "true")  -- in  string := "false"
    port map (
      aReset => aReset,      -- in  boolean
      cEn    => true,        -- in  boolean
      Clk    => IClk,        -- in  std_logic
      cD     => oSigReturn,  -- in  std_logic
      cQ     => iSigOut_ms); -- out std_logic := kResetVal

  -- 5) remove metastability

  --vhook_e DFlop iSigOutx
  --vhook_a kAsyncReg "true"      
  --vhook_a kResetVal '0'
  --vhook_a Clk IClk
  --vhook_a cEn iClkEn
  --vhook_a cD iSigOut_ms
  --vhook_a cQ iSigOut
  iSigOutx: entity work.DFlop (rtl)
    generic map (
      kResetVal => '0',     -- in  std_logic := '0'
      kAsyncReg => "true")  -- in  string := "false"
    port map (
      aReset => aReset,      -- in  boolean
      cEn    => iClkEn,      -- in  boolean
      Clk    => IClk,        -- in  std_logic
      cD     => iSigOut_ms,  -- in  std_logic
      cQ     => iSigOut);    -- out std_logic := kResetVal

  iStatusOfoSig <= iSigOut;

  -- 7) Drive the output
  oSig <= oLocalSigOut;
  oSigCE <= oLocalSigOutCE;

  ---------------------------------------------------------------------------
  -- This block contains error detection circuitry.  It checks to see if
  -- the user has reasserted iSig before the module is ready to generate
  -- another pulse.
  ---------------------------------------------------------------------------
  --synthesis translate_off
  BlkErr: block
  begin
--    process(IClk)
--    begin
--     if rising_edge(IClk) then
--      assert not (iSig='1' and iSigOut='1')
--        report "iSig reasserted while PulseSync module not ready"
--        severity failure;
--      end if;
--     end process;

    process
    begin
      wait until falling_edge(oSigReturn);
      assert oLocalSigOutCE='0'
        report "oSigReturn not allowed to deassert while oSigOut still asserted"
        severity warning;
    end process;

  end block BlkErr;
  --synthesis translate_on

end behavior;

-- The following comment is a checksum VScan uses to determine whether this
-- file has been modified.  Please don't try to get around it.  It's there
-- for a reason.
--VScan_CS 4066438
