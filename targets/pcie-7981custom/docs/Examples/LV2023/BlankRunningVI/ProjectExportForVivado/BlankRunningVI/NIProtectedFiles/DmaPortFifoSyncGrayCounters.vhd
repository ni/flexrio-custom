-------------------------------------------------------------------------------
--
-- File: DmaPortFifoSyncGrayCounters.vhd
-- Author: Bogdan Popa
-- Original Project: LvFpga Communication Interface
-- Date: 25 March 2016
--
-------------------------------------------------------------------------------
-- (c) 2016 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--
--    This module implements a synchronization mechanism for Gray counters.
-- Since Gray counters are guaranteed to only change one bit between any 
-- consecutive values, it is safe to only use double synchronizers for each
-- bit in the counters, without running into coherency issues.
--
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgGray.all;
  use work.PkgNiUtilities.all;
  
entity DmaPortFifoSyncGrayCounters is
  generic(
    -- kWidth: Gray pointers width
    kWidth : positive;
    kPtrWidth : positive;
    kNumOfSamplesPerWrite : positive
  );
  port(
    -- OClk: Output port clock.
    OClk            : in  std_logic;
    -- oReset: Synchronous reset for the output clock domain.
    oReset          : in  boolean;
    -- iInputPtrGray: Gray pointer that will be synchronized to the 
    --                output clock.
    iInputPtrGray   : in Gray(kWidth-1 downto 0);
    -- iDisablePtr: Boolean indicating that the writes have been disabled,
    --              that will be transferred to the output clock domain.
    iDisablePtr     : in  boolean;
    -- oOutputPtrUns: Unsigned pointer synchronized to the output clock.
    oOutputPtrUns  : out unsigned(kPtrWidth-1 downto 0);
    -- oDisablePtr: Boolean indicating that writes have been disabled,
    --              synchronized to the output clock domain. This flag 
    --              should have the delays match those of the Gray count
    --              making sure that the count is valid.
    oDisablePtr     : out boolean
  );
end DmaPortFifoSyncGrayCounters;

architecture rtl of DmaPortFifoSyncGrayCounters is

  constant kGrayResetVal : Gray(kWidth-1 downto 0) := (others => '0');
  
  -- These signals do not require a default value, because they are outputs
  -- from components and the default output values are specified inside.
  signal oPtrGray_ms, oPtrGray: Gray(kWidth-1 downto 0);
  signal oDisablePtr_ms, oDisablePtrFromDoubleSync: boolean;
  signal oOutputPtrUnsLoc : unsigned(kPtrWidth-1 downto 0) := (others => '0');
  -- These signals are initialized to true because the writes are disabled
  -- when the channel is reset, as it starts in the Unlinked state. 
  signal oDisablePtrFromDoubleSyncDly, oDisablePtrLoc : boolean := true;

begin

  GrayPtrClockCrossing: block is
  begin    
    
    --vhook_e DFlopGray OutputGrayReg_ms
    --vhook_a kAsyncReg "true"      
    --vhook_a kResetVal kGrayResetVal
    --vhook_a aReset false
    --vhook_a cEn true
    --vhook_a Clk OClk
    --vhook_a cD iInputPtrGray
    --vhook_a cQ oPtrGray_ms
    OutputGrayReg_ms: entity work.DFlopGray (rtl)
      generic map (
        kResetVal => kGrayResetVal,  -- in  Gray
        kAsyncReg => "true")         -- in  string := "false"
      port map (
        aReset => false,          -- in  boolean
        cEn    => true,           -- in  boolean
        Clk    => OClk,           -- in  std_logic
        cD     => iInputPtrGray,  -- in  Gray(kResetVal'length-1 downto 0)
        cQ     => oPtrGray_ms);   -- out Gray(kResetVal'length-1 downto 0) := kResetVal
    
    
    --vhook_e DFlopGray OutputGrayReg
    --vhook_a kAsyncReg "true"      
    --vhook_a kResetVal kGrayResetVal
    --vhook_a aReset false
    --vhook_a cEn true
    --vhook_a Clk OClk
    --vhook_a cD oPtrGray_ms
    --vhook_a cQ oPtrGray
    OutputGrayReg: entity work.DFlopGray (rtl)
      generic map (
        kResetVal => kGrayResetVal,  -- in  Gray
        kAsyncReg => "true")         -- in  string := "false"
      port map (
        aReset => false,        -- in  boolean
        cEn    => true,         -- in  boolean
        Clk    => OClk,         -- in  std_logic
        cD     => oPtrGray_ms,  -- in  Gray(kResetVal'length-1 downto 0)
        cQ     => oPtrGray);    -- out Gray(kResetVal'length-1 downto 0) := kResetVal
    
    -- Having only a synchronous reset that cannot be used with DFlopGray instances,
    -- I'm resetting only the registers placed after the synchronization has happened
    -- and are safely in the OClk domain.
    OutputPtrReg: process(OClk)
    begin
      if rising_edge(OClk) then
        if oReset then
          oOutputPtrUnsLoc <= (others => '0');
        else
          oOutputPtrUnsLoc <= To_Unsigned(oPtrGray) & unsigned(Zeros(Log2(kNumOfSamplesPerWrite)));
        end if;
      end if;
    end process;
    
    oOutputPtrUns <= oOutputPtrUnsLoc;
    
  end block GrayPtrClockCrossing;
  
  DisableSignalClockCrossing: block is
  begin
    
    --vhook_e DflopBool SyncToOClk_ms
    --vhook_a kResetVal true
    --vhook_a kAsyncReg "true"
    --vhook_a aReset false
    --vhook_a cEn true
    --vhook_a Clk OClk
    --vhook_a cD iDisablePtr
    --vhook_a cQ oDisablePtr_ms
    SyncToOClk_ms: entity work.DFlopBool (rtl)
      generic map (
        kResetVal => true,    -- in  boolean := false
        kAsyncReg => "true")  -- in  string := "false"
      port map (
        aReset => false,           -- in  boolean
        cEn    => true,            -- in  boolean
        Clk    => OClk,            -- in  std_logic
        cD     => iDisablePtr,     -- in  boolean
        cQ     => oDisablePtr_ms); -- out boolean := kResetVal
		
    --vhook_e DflopBool SyncToOClk
    --vhook_a kResetVal true
    --vhook_a kAsyncReg "true"
    --vhook_a aReset false
    --vhook_a cEn true
    --vhook_a Clk OClk
    --vhook_a cD oDisablePtr_ms
    --vhook_a cQ oDisablePtrFromDoubleSync
    SyncToOClk: entity work.DFlopBool (rtl)
      generic map (
        kResetVal => true,    -- in  boolean := false
        kAsyncReg => "true")  -- in  string := "false"
      port map (
        aReset => false,                      -- in  boolean
        cEn    => true,                       -- in  boolean
        Clk    => OClk,                       -- in  std_logic
        cD     => oDisablePtr_ms,             -- in  boolean
        cQ     => oDisablePtrFromDoubleSync); -- out boolean := kResetVal
    
    -- The writes disabled signals must reset to true since the channel resets to the
    -- Unlinked state, where writes are disabled.
    -- Delay the writes disabled signal so that the delay matches the delay
    -- to the full count.  Add an extra delay here since there is a clock
    -- crossing from the iClk to oClk domain, and the write pointer may
    -- actually get clocked in to the oClk domain one cycle later than the
    -- writes disabled signal.
    -- Having only a synchronous reset that cannot be used with the DflopBool,
    -- I'm resetting only the registers placed after the synchronization has happened
    -- and are safely in the OClk domain.
    OutputDisableRegs: process(OClk)
    begin
      if rising_edge(OClk) then
        if oReset then
          oDisablePtrFromDoubleSyncDly <= true;
          oDisablePtrLoc <= true;
        else
          oDisablePtrFromDoubleSyncDly <= oDisablePtrFromDoubleSync;
          oDisablePtrLoc <= oDisablePtrFromDoubleSyncDly;
        end if;
      end if;
    end process;
    
    oDisablePtr <= oDisablePtrLoc;
    
  end block DisableSignalClockCrossing;

end architecture rtl;
