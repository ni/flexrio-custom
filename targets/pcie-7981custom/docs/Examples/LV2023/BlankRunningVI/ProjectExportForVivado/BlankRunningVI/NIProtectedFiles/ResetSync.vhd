-------------------------------------------------------------------------------
--
-- File: ResetSync.vhd
-- Author: Jeff Bergeron
-- Original Project: NICores
-- Date: 4 September 2008
--
-------------------------------------------------------------------------------
-- (c) 2008 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--
-- Summary:
--   Capture the assertion of aReset1 and immediately assert c1ResetFast and c1Reset
--   Synchronize this to Clk2 and assert c2Reset then syncrhonize back to Clk1
--   for feedback to allow the loop to clear.
--
-------------------------------------------------------------------------------
--   When aReset1 asserts it will
--   (1) Immediately asynchronously set c1ResetFast and c1Reset. c1ResetFromClk2
--       is also immediately cleared, but in steady state would have
--       normally been cleared anyway. 
--   (2) c1ResetFast is synchronized to Clk2 where it sets c2Reset.  There
--       are two delay options.
--          kSpeedUpWithFallingEdgeFlop = 1 -> 0.5 to 1.5 Clk2's
--          kSpeedUpWithFallingEdgeFlop = 0 => 1 to 2 Clk2's
--   (3) c2Reset is synchronized back to Clk1 where it sets c1ResetFromClk2.
--       c1Reset was already asserted, but this will hold off the removal of
--       c1ResetFast and c1Reset.
--       This synchronization will take 1 to 2 Clk1's.
--
-------------------------------------------------------------------------------
--   When aReset1 removes the clearing process takes the same path.
--        (1) After aReset1 stops asserting the c1ResetFast signal deasserts on
--        the next Clk1 edge. c1Reset does not deassert immediately.
--        (2) c1ResetFast is synchronized to Clk2 and deasserts c2Reset
--        (3) c2Reset is synchronized to Clk1 and deasserts c1Reset
--
-------------------------------------------------------------------------------
--   When aReset2 is asserted it will immediately set c2Reset to false.  This
--  would block the propagation of c1ResetFast were it also set.  This
--  effectively holds off the assertion of c2Reset and c1Reset until aReset2 is
--  removed.
--
--  Notes:
--     aReset1 only resets flops clocked by Clk1.
--     aReset2 only resets flops clocked by Clk2.
--     c1ResetFast is set, all other flops are cleared.
--     aReset1 and aReset2 serve different purposes.
--     !!This module does not have any generic usefulness outside of it's
--       application in handshake base!!
--
--  Usage:
--     This block is used to control the assertion of reset to various flops in
--     the HandshakeBaseResetCross module.  This module is designed to
--     allow asynchronous assertion of reset in either clock domain without
--     spurious DataValid assertions or incorrect Ready assertions.  To
--     accomplish this it is necessary to be able to propagate the reset chain
--     faster then the data toggle chain in the handshake module.  Depending on
--     the timing analysis you apply it may be helpful to use
--     kSpeedUpWithFallingEdgeFlop.  See the following power point for more details.
--      //ASIC/nicores/CoreComponents/ClockCrossing/trunk/1.2/ClockCrossing/Handshake/Doc/HandshakeBase with Reset Crossing.pptx
--  Options:
--     kEnableOutputs - Can be used to force the c1Reset and c2Reset outputs
--                      permanently false. I speculate this could be useful in
--                      disabling the module.
--     kSpeedUpWithFallingEdgeFlops - Choose option for the delay between
--                      c1ResetFast and c2Reset.
--                      When true  the delay is 0.5 to 1.5 Clk2 Clks
--                          (Used when IClk=Clk1 and OClk=Clk2)
--                      When false the delay is   1 to 2   Clk2 Clks
--                          (Used when IClk=Clk2 and OClk=Clk1)
--                          *IClk and OClk are clocks in the HandshakeBase file
--                           where this module is used.
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;

entity ResetSync is
  generic (
    kEnableOutputs:               boolean := true;
    kSpeedUpWithFallingEdgeFlops: boolean := true);
  port (
    aReset1:     in  boolean;
    Clk1:        in  std_logic;
    aReset2:     in  boolean;
    Clk2:        in  std_logic;
    c1ResetFast: out boolean := false;
    c1Reset:     out boolean := false;
    c2Reset:     out boolean := false
  );

  -- These attributes are specific to XST. Without this, constrained
  -- registers can be combined with other registers and be lost,
  -- invalidating the constraint.
  --attribute equivalent_register_removal : string;
  --attribute equivalent_register_removal of ResetSync : entity is "no";
  
  -- Vivado:
  -- The above attribute was inherited from ISE. For details on why we needed
  -- this attribute, please look at CAR#465983.
  -- For Vivado, the equivalent_register_removal attribute is not supported.
  
end ResetSync;

architecture rtl of ResetSync is

  --vhook_sigstart
  --vhook_sigend

  signal c1NxResetFastLcl: boolean := false;
  signal c1ResetFastLcl: boolean := false;
  signal c2ResetFe_ms, c2ResetRe_ms, c2ResetLcl : boolean := false;
  signal c1ResetFromClk2_ms, c1ResetFromClk2 : boolean := false;
  
  
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of c1ResetFromClk2_ms,c1ResetFromClk2 : signal is "true";           

  -- This 'keep' attribute attempts to ensure that the first flop will not
  -- be merged with any others that happen to have the same connections.
  -- Previous versions of this file used an 'equivalent_register_removal'
  -- attribute, but that only works for ISE.
  attribute keep : string;
  attribute keep of c1NxResetFastLcl : signal is "true";

begin

  -- This term provides the deassertion of c1ResetFast after it has had time to
  -- propagate the entire loop and aReset1 has been removed.
  c1NxResetFastLcl <= not c1ResetFromClk2 and c1ResetFastLcl;

  -- SET the reset.  Note that this is the only flop in the loop that SETS on reset.
  
  --vhook_e DFlopBool c1ResetFastLclx
  --vhook_a kAsyncReg "false"      
  --vhook_a kResetVal true
  --vhook_a aReset aReset1
  --vhook_a cEn true
  --vhook_a Clk Clk1
  --vhook_a cD c1NxResetFastLcl
  --vhook_a cQ c1ResetFastLcl
  c1ResetFastLclx: entity work.DFlopBool (rtl)
    generic map (
      kResetVal => true,     -- in  boolean := false
      kAsyncReg => "false")  -- in  string := "false"
    port map (
      aReset => aReset1,           -- in  boolean
      cEn    => true,              -- in  boolean
      Clk    => Clk1,              -- in  std_logic
      cD     => c1NxResetFastLcl,  -- in  boolean
      cQ     => c1ResetFastLcl);   -- out boolean := kResetVal

  c1ResetFast <= c1ResetfastLcl and kEnableOutputs;

  --vhook_e DFlopBoolFallingEdge c2ResetFe_msx
  --vhook_a kAsyncReg "true"
  --vhook_a kResetVal false
  --vhook_a aReset aReset2
  --vhook_a cEn true
  --vhook_a Clk Clk2
  --vhook_a cD c1ResetfastLcl
  --vhook_a cQ c2ResetFe_ms
  c2ResetFe_msx: entity work.DFlopBoolFallingEdge (rtl)
    generic map (
      kResetVal => false,   -- in  boolean := false
      kAsyncReg => "true")  -- in  string := "false"
    port map (
      aReset => aReset2,         -- in  boolean
      cEn    => true,            -- in  boolean
      Clk    => Clk2,            -- in  std_logic
      cD     => c1ResetfastLcl,  -- in  boolean
      cQ     => c2ResetFe_ms);   -- out boolean := kResetVal
      
  --vhook_e DFlopBool c2ResetRe_msx
  --vhook_a kAsyncReg "true"
  --vhook_a kResetVal false
  --vhook_a aReset aReset2
  --vhook_a cEn true
  --vhook_a Clk Clk2
  --vhook_a cD c1ResetfastLcl
  --vhook_a cQ c2ResetRe_ms    
  c2ResetRe_msx: entity work.DFlopBool (rtl)
    generic map (
      kResetVal => false,   -- in  boolean := false
      kAsyncReg => "true")  -- in  string := "false"
    port map (
      aReset => aReset2,         -- in  boolean
      cEn    => true,            -- in  boolean
      Clk    => Clk2,            -- in  std_logic
      cD     => c1ResetfastLcl,  -- in  boolean
      cQ     => c2ResetRe_ms);   -- out boolean := kResetVal
  
  SpeedUpWithFeFlopGen : if kSpeedUpWithFallingEdgeFlops generate
    --vhook_e DFlopBool SyncToClk2REfromFE
    --vhook_a kAsyncReg "true"
    --vhook_a kResetVal false
    --vhook_a aReset aReset2
    --vhook_a cEn true
    --vhook_a Clk Clk2
    --vhook_a cD c2ResetFe_ms
    --vhook_a cQ c2ResetLcl   
    SyncToClk2REfromFE: entity work.DFlopBool (rtl)
      generic map (
        kResetVal => false,   -- in  boolean := false
        kAsyncReg => "true")  -- in  string := "false"
      port map (
        aReset => aReset2,       -- in  boolean
        cEn    => true,          -- in  boolean
        Clk    => Clk2,          -- in  std_logic
        cD     => c2ResetFe_ms,  -- in  boolean
        cQ     => c2ResetLcl);   -- out boolean := kResetVal
    
  end generate SpeedUpWithFeFlopGen;
  
  DontSpeedUpWithFeFlopGen : if not kSpeedUpWithFallingEdgeFlops generate
    --vhook_e DFlopBool SyncToClk2REfromRE
    --vhook_a kAsyncReg "true"
    --vhook_a kResetVal false
    --vhook_a aReset aReset2
    --vhook_a cEn true
    --vhook_a Clk Clk2
    --vhook_a cD c2ResetRe_ms
    --vhook_a cQ c2ResetLcl   
    SyncToClk2REfromRE: entity work.DFlopBool (rtl)
      generic map (
        kResetVal => false,   -- in  boolean := false
        kAsyncReg => "true")  -- in  string := "false"
      port map (
        aReset => aReset2,       -- in  boolean
        cEn    => true,          -- in  boolean
        Clk    => Clk2,          -- in  std_logic
        cD     => c2ResetRe_ms,  -- in  boolean
        cQ     => c2ResetLcl);   -- out boolean := kResetVal
    
  end generate DontSpeedUpWithFeFlopGen;

  c2Reset <= c2ResetLcl and kEnableOutputs;

  -- We apply the ASYNC_REG attribute in Vivado that ensures that the flops of the
  -- 'SyncBackToClk1' double-synchronizer are placed into the same slice. This can
  -- only happen if both flops of the double-synchronizer have the exact same control
  -- set. 
  SyncBackToClk1: process (Clk1, aReset1) is
  begin
    if aReset1 then
      c1ResetFromClk2_ms <= false;
      c1ResetFromClk2 <= false;
    elsif rising_edge(Clk1) then
      c1ResetFromClk2 <= c1ResetFromClk2_ms;
      c1ResetFromClk2_ms <= c2ResetLcl;
    end if;
  end process SyncBackToClk1;

  c1Reset <= (c1ResetfastLcl or c1ResetFromClk2) and kEnableOutputs;

end rtl;

-- The following comment is a checksum VScan uses to determine whether this
-- file has been modified.  Please don't try to get around it.  It's there
-- for a reason.
--VScan_CS 2850854
