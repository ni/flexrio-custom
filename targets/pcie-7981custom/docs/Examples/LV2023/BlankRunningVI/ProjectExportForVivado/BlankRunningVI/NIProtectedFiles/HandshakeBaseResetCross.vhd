-------------------------------------------------------------------------------
--
-- File: HandshakeBaseResetCross.vhd
-- Author: Jeff Bergeron/Craig Conway
-- Original Project: NICores
-- Date: 5 September 2008
--
-------------------------------------------------------------------------------
-- (c) 2008 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--      This module handshakes std_logic_vector data from one clock domain
--  to another independent of the relative clock frequencies or phases of
--  IClk and OClk.
--      Worst case turnaround time is 5 IClk cycles and 4 OClk cycles.  If
--  IClk and OClk were the same clock, this means you would be able to assert
--  iPush once every 9 clock cycles.
--      The module also crosses from one reset domain to another,
--  without a known relationship between the resets.  For more details on
--  the reset crossing, see additional documentation here:
--  //ComputerBasedInstruments/scopesHW/VHDL/Misc/
--    NiCoreUpdates/Doc/HandshakeBase with Reset Crossing.pptx
--
--  Note that some of the flip-flops in this file are instantiated "DFlop"
--  components rather than simple processes.  There are two reasons for this:
--
--   Reason 1) I have not found a reliable way to use synthesis directives to
--             ensure that the flip-flops created will be enabled flip-flops.
--             By using components and telling synthesis not to optimize across
--             the DFlop* boundary, we ensure that we get enabled flops.
--
--   Reason 2) These instances also make it easy to find the signals for timing
--             constraints.  For example, the path from iLclStoredData to the
--             oLclData flip-flop is the path from iStoredDatax|cQ to oDataFlop|cQ.
--             These names should be relatively immune to synthesis renaming.
--             Without these components, iStoredData may be renamed to whatever
--             actual connects to it, making general purpose constraints difficult
--             to write.
--
-- --------------------
--  Timing Constraints
-- --------------------
--
--  Here are some example TimeQuest timing constraints used for SMC4 to constrain the
-- handshake module:
--
-- set_false_path -from [get_registers *iPushTogglex|cQ*] \
--                -to [get_registers *oPushToggle0_msx|cQ*]
-- set_false_path -from [get_registers *oPushToggleToReadyx|cQ*] \
--                -to [get_registers *iRdyPushToggle_msx|cQ*]
-- # The datapath clock crossings must be less than 2X the period of the destination
-- # clock.  Since our fastest clock is 266 MHz, we can set this to 7.5 ns and work
-- # for all clocks in the design.
-- set_max_delay -from [get_registers *iStoredDatax|cQ*] \
--               -to [get_registers *_ODataFlop|cQ*] 7.5
-- set_min_delay -from [get_registers *iStoredDatax|cQ*] \
--               -to [get_registers *_ODataFlop|cQ*] 0.0
--
--  Note that for TimeQuest, the set_max/min_delay constraints still take clock
-- insertion delay into account.  If IClk and OClk have the same or similar
-- insertion delays, then this constraint basically acts like a node-node constraint.
-- But if IClk and OClk have different insertion delays, the constraint value may
-- need to be adjusted to compensate.
--
--  It may be sufficient to simply constrain all paths from IClk to OClk to be
-- less than 2X OClk's period.  One interesting side effect of unrelated
-- clock-crossing timing analysis is that a pessimistic analysis will always fail
-- on the paths that cross the clock domain.  So if you only constrain the
-- clock crossings you know about, then timing analysis will find the other
-- clock crossings you might not know about, because they'll fail timing.  So
-- I recommend the above rather than a more blanket statement such as:
--
-- set_max_delay -from [get_clocks IClk] -to [get_clocks OClk] 7.5  # BAD
--
-- Because of the reset crossing, additional timing constraints need to be
-- written.
--
-- NET "IClk" TNM_NET = IClk;
-- TIMESPEC TS_IClk = PERIOD "IClk" x ns HIGH 50%;
-- NET "OClk" TNM_NET = OClk;
-- TIMESPEC TS_OClk = PERIOD "OClk" y ns HIGH 50%;
--
-- # Constrain the maximum reset skew to be less than it's corresponding
-- # clock period.  A similar constraint is not currently available for
-- # Altera targets, so reset skew will have to be analyzed post P&R
-- NET "aIReset" MAXSKEW = x/2 ns;
-- NET "aOReset" MAXSKEW = y/2 ns;
--
-- # Group the FFs used in from-to constraints
-- INST "*BlkOut.SyncIReset/c1ResetFastLclx/cQ_0" TNM = iIRestFast;
-- INST "*BlkOut.SyncIReset/c2ResetFe_msx/cQ_0" TNM = oIReset_ms;
-- INST "*BlkIn.iPushTogglex/cQ_0" TNM = iPushToggle;
-- INST "*BlkOut.oPushToggle0_msx/cQ_0" TNM = oPushToggle_ms;
--
-- # Constrain the path from iIResetFast to oIReset_ms to ensure oIReset
-- # will not arrive too late to clear bad toggles.
-- TIMESPEC TS_iPushToggle_to_oPushToggle_ms = FROM "iPushToggle" TO "oPushToggle_ms" TS_OClk;
--
-- # Set the maximum delay on the iIResetFast net to be less than 2 IClk periods.
-- # Since the path we are trying to constrain is from Q of iIResetFast to the async reset
-- # pin of iPushToggle we must use the MAXDELAY constraint instead of a from-to.
-- NET "iIResetFast" MAXDELAY = 2*x ns;
--
-- !Implementation Detail! - LVFGPA relies on certain naming to script the
-- correct timing constraints for this module.  If you change the names, or add
-- additional circuitry, please check compatibility with them.
--
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity HandshakeBaseResetCross is
  generic (
    kDataWidth: integer := 1
  );
  port (
    aResetToDlyPush,                  -- These are non-synthesis values used in a
    aResetToIResetFast,               -- testbench to control the reset skew and
    aPushToggleDly                    -- path delays.
                   : in integer := 0;

    --vhook_nowarn aResetToDlyPush
    --vhook_nowarn aResetToIResetFast
    --vhook_nowarn aPushToggleDly
    aIReset:       in  boolean;
    IClk:          in  std_logic;
    iPush:         in  boolean;
    iData:         in  std_logic_vector(kDataWidth-1 downto 0) := (others => '0');
    iStoredData:   out std_logic_vector(kDataWidth-1 downto 0) := (others => '0');
    iReady:        out boolean := false;
    iOResetStatus: out boolean := false;

    aOReset:     in  boolean;
    OClk:        in  std_logic;
    oDataValid:  out boolean := false;
    oDataAck:    in  boolean := true;
    oData:       out std_logic_vector(kDataWidth-1 downto 0) := (others => '0')
  );
end HandshakeBaseResetCross;

architecture rtl of HandshakeBaseResetCross is
  
  -- Workaround --  
  -- Created a local version of iPush so we can apply 'keep' attribute to it. 
  -- This is not possible for input signals in Vivado 2013.4
  signal iPushLcl : boolean;

  attribute keep : string;
  attribute keep of iPushLcl : signal is "true";


  constant kResetVal : std_logic_vector(kDataWidth-1 downto 0) := (others => '0');

  signal iDlyPush : boolean := false;
  attribute keep of iDlyPush : signal is "true";
  signal iLclReady : boolean := false;
  attribute keep of iLclReady : signal is "true";
  signal iPushToggle : boolean := false;
  signal oPushToggleToReady : boolean := false;
  
  signal iLclStoredData : std_logic_vector(iData'range) := (others => '0');
  signal iIReset, iIResetFast, iOReset : boolean := false;
  
begin
  
  ---------------------------------------------------------------------------
  -- Workaround --  
  -- Created a local version of iPush so we can apply 'keep' attribute to it. 
  -- This is not possible for input signals in Vivado 2013.4
  iPushLcl <= iPush;
  ---------------------------------------------------------------------------

  ---------------------------------------------------------------------------
  -- This block contains a process that captures the iPush signal and creates
  -- a pulse from it.  That pulse causes the iPushToggle signal to change and
  -- causes iData to be stored.
  ---------------------------------------------------------------------------
  BlkIn: block
    signal iPushPulse, iNxPushToggle : boolean := false;
    signal iToggleEnable : boolean := false;
  begin

    process (aIReset, IClk)
    begin
      if aIReset then
        iDlyPush <= false;
      elsif rising_edge(IClk) then
        iDlyPush <= iPushLcl;
      end if;
    end process;

    ---------------------------------------------------------------------------
    -- Use a single LUT to create iPushPulse.
    ---------------------------------------------------------------------------
    -- !Implementation Detail!  We are using iLclReady to protect against
    -- possible glitches on iPushPulse due to aIReset skew.  Skew on the
    -- arrival of aIReset to iDlyPush and the FF(s) creating iPush external to
    -- this component could result in a glitch on the output of a simple 2
    -- input AND implemenentaion for the edge detector.  For this reason, we
    -- add a third input (iLclReady), and try to force this 3 input AND into a
    -- single LUT through synthesis directives.
    -- There are 2 cases to consider:
    --   1) aIReset asserts shortly (an IClk or two) after iPush - In this
    --   case, iLclReady should have changed to false one clock after iPush
    --   asserted, and will mask off glitches on iPushPulse.  Futhermore,
    --   iLclReady is reset to false by aIReset, so it will not be change in
    --   the middle of a handshake transaction when aIReset asserts.
    --   2) aIReset asserts at the same time as (or long after) iPush - In this
    --   case, iLclReady will be true so a glitch could occur on iPushPulse.
    --   However, aIReset should intercept the toggle on its way to the OClk
    --   domain (in the form of oIReset) and prevent data from becoming
    --   valid in OClk.
    ---------------------------------------------------------------------------
    iPushPulse <= (iPushLcl and not iDlyPush and iLclReady);
    iToggleEnable <= iPushPulse or iOReset;
    iNxPushToggle <= (not iPushToggle) and (not iOReset);

    --vscan Begin Add ResetWarningSuppression
    --vscan Destination Reset: *[HandshakeBaseResetCross]/iIResetFast
    --vscan NewQ: {\[HandshakeBaseResetCross\]BlkIn/iPushTogglex/\[DFlopBool\]DFlopx/\[DFlop\](cQ|cLclQ)$}
    --vscan End Add ResetWarningSuppression

    -- Instantiate DFlop for iPushToggle for Reason 2 (see purpose statement)

    --vhook_e DFlopBool iPushTogglex
    --vhook_a kAsyncReg "false"      
    --vhook_a kResetVal false
    --vhook_a aReset iIResetFast
    --vhook_a Clk IClk
    --vhook_a cEn iToggleEnable
    --vhook_a cD iNxPushToggle
    --vhook_a cQ iPushToggle
    iPushTogglex: entity work.DFlopBool (rtl)
      generic map (
        kResetVal => false,    -- in  boolean := false
        kAsyncReg => "false")  -- in  string := "false"
      port map (
        aReset => iIResetFast,    -- in  boolean
        cEn    => iToggleEnable,  -- in  boolean
        Clk    => IClk,           -- in  std_logic
        cD     => iNxPushToggle,  -- in  boolean
        cQ     => iPushToggle);   -- out boolean := kResetVal

    ---------------------------------------------------------------------------
    -- !Implementation Detail! The iLclStoredData registers can not be reset by
    -- aIReset.  This prevents an assertion of aIReset during a push causing
    -- the oData registers to go metastable.  As a result, there is a reset crossing
    -- on the data from aIReset to no reset.  This crossing is okay since
    -- precautions are taken to prevent us from forwarding on potentially bad
    -- data when aIReset asserts close to iPush.  oIReset will prevent the
    -- push from making it to the OClk domain, so the oData registers should
    -- not be enabled to accept new data in this case.  When aIReset clears,
    -- as long as the driver of iPush does not push before iReady sets, there
    -- should be a few clocks for iData to stabilize.
    ---------------------------------------------------------------------------

    --vscan Begin Add ResetWarningSuppression
    --vscan NewQ: {\[HandshakeBaseResetCross\]BlkIn/iStoredDatax/\[DFlopSlvResetVal\]GenFlops/DFlopx/\[DFlop\](cQ|cLclQ)$}
    --vscan End Add ResetWarningSuppression

    -- Instantiate DFlop for iPushToggle for Reason 2 (see purpose statement)

    --vhook_e DFlopSlvResetVal iStoredDatax
    --vhook_a kWidth kDataWidth
    --vhook_a aReset false
    --vhook_a Clk IClk
    --vhook_a cEn iPushPulse
    --vhook_a cD iData
    --vhook_a cQ iLclStoredData
    iStoredDatax: entity work.DFlopSlvResetVal (rtl)
      generic map (
        kWidth    => kDataWidth,  -- in  integer
        kResetVal => kResetVal)   -- in  std_logic_vector
      port map (
        aReset => false,           -- in  boolean
        cEn    => iPushPulse,      -- in  boolean
        Clk    => IClk,            -- in  std_logic
        cD     => iData,           -- in  std_logic_vector(kWidth-1 downto 0)
        cQ     => iLclStoredData); -- out std_logic_vector(kWidth-1 downto 0) := kResetVa

    iStoredData <= iLclStoredData;

  end block BlkIn;

  ---------------------------------------------------------------------------
  -- The process in this block resynchronizes iPushToggle to OClk and creates
  -- a pulse on oDataValid.  It also resynchronizes iStoredData to OClk.
  -- Note that it's not really necessary to have the iStoredData variable at
  -- all. If the data is stable, we could simply have a concurrent signal
  -- assignment as follows: oData <= iData.  The advantage to having
  -- flip-flops at the input and output of this module is that the clock
  -- boundary crossing is totally contained within this module.  You
  -- will be able to prove correctness easily and won't have to worry
  -- about whether iData hangs around long enough to be seen in the
  -- other clock domain.
  ---------------------------------------------------------------------------
  BlkOut: block
    signal oPushToggle0_ms,
           oPushToggle1,
           oNxPushToggle2,
           oPushToggle2,
           oNxPushToggleToReady,
           oPushToggleChanged : boolean := false;
    
    signal oIReset, oOReset, oEitherReset : boolean := false;
    signal oDataAckClkEnable : boolean := false;
	
    attribute keep of oDataAckClkEnable : signal is "true";

  begin

    ---------------------------------------------------------------------------
    -- The ResetSync module will give us oIReset less than 2 OClks after
    -- aIReset asserts.
    ---------------------------------------------------------------------------
    --vhook_e ResetSync SyncIReset
    --vhook_a kEnableOutputs true
    --vhook_a kSpeedUpWithFallingEdgeFlops true
    --vhook_a aReset1 aIReset
    --vhook_a Clk1 IClk
    --vhook_a aReset2 aOReset
    --vhook_a Clk2 OClk
    --vhook_a c1ResetFast iIResetFast
    --vhook_a c1Reset iIReset
    --vhook_a c2Reset oIReset
    SyncIReset: entity work.ResetSync (rtl)
      generic map (
        kEnableOutputs               => true,  -- in  boolean := true
        kSpeedUpWithFallingEdgeFlops => true)  -- in  boolean := true
      port map (
        aReset1     => aIReset,      -- in  boolean
        Clk1        => IClk,         -- in  std_logic
        aReset2     => aOReset,      -- in  boolean
        Clk2        => OClk,         -- in  std_logic
        c1ResetFast => iIResetFast,  -- out boolean := false
        c1Reset     => iIReset,      -- out boolean := false
        c2Reset     => oIReset);     -- out boolean := false

    -- Instantiate DFlop for oPushToggle0_ms for Reason 2 (see purpose statement)

    --vhook_e DFlopBool oPushToggle0_msx  
    --vhook_a kAsyncReg "true"      
    --vhook_a kResetVal false
    --vhook_a aReset aOReset
    --vhook_a Clk OClk
    --vhook_a cEn true
    --vhook_a cD iPushToggle
    --vhook_a cQ oPushToggle0_ms
    oPushToggle0_msx: entity work.DFlopBool (rtl)
      generic map (
        kResetVal => false,   -- in  boolean := false
        kAsyncReg => "true")  -- in  string := "false"
      port map (
        aReset => aOReset,          -- in  boolean
        cEn    => true,             -- in  boolean
        Clk    => OClk,             -- in  std_logic
        cD     => iPushToggle,      -- in  boolean
        cQ     => oPushToggle0_ms); -- out boolean := kResetVal
        
    --vhook_e DFlopBool oPushToggle1x  
    --vhook_a kAsyncReg "true"      
    --vhook_a kResetVal false
    --vhook_a aReset aOReset
    --vhook_a Clk OClk
    --vhook_a cEn true
    --vhook_a cD oPushToggle0_ms
    --vhook_a cQ oPushToggle1
    oPushToggle1x: entity work.DFlopBool (rtl)
      generic map (
        kResetVal => false,   -- in  boolean := false
        kAsyncReg => "true")  -- in  string := "false"
      port map (
        aReset => aOReset,          -- in  boolean
        cEn    => true,             -- in  boolean
        Clk    => OClk,             -- in  std_logic
        cD     => oPushToggle0_ms,  -- in  boolean
        cQ     => oPushToggle1);    -- out boolean := kResetVal

    oEitherReset <= oIReset or oOReset;
    oNxPushToggle2 <= oPushToggle1 and not oEitherReset;

    process (aOReset, OClk)
    begin
      if aOReset then
        oPushToggle2 <= false;
      elsif rising_edge(OClk) then
        oPushToggle2 <= oNxPushToggle2;
      end if;
    end process;

    ---------------------------------------------------------------------------
    -- Use a ResetSync module to create various versions of aOReset in the OClk
    -- and IClk domains.  Note, it is possible to for pushes to be lost in this
    -- component when aOReset sets, so aOReset's status is passed out
    -- synchronous to IClk as iOResetStatus.  This signal enables drivers of iPush
    -- to monitor if data might have been lost due to iPush setting close to an
    -- occurrence of aOReset.
    ---------------------------------------------------------------------------
    --vhook_e ResetSync SyncOReset
    --vhook_a kEnableOutputs true
    --vhook_a kSpeedUpWithFallingEdgeFlops false
    --vhook_a aReset1 aOReset
    --vhook_a Clk1 OClk
    --vhook_a aReset2 aIReset
    --vhook_a Clk2 IClk
    --vhook_a c1ResetFast open
    --vhook_a c1Reset oOReset
    --vhook_a c2Reset iOReset
    SyncOReset: entity work.ResetSync (rtl)
      generic map (
        kEnableOutputs               => true,   -- in  boolean := true
        kSpeedUpWithFallingEdgeFlops => false)  -- in  boolean := true
      port map (
        aReset1     => aOReset,  -- in  boolean
        Clk1        => OClk,     -- in  std_logic
        aReset2     => aIReset,  -- in  boolean
        Clk2        => IClk,     -- in  std_logic
        c1ResetFast => open,     -- out boolean := false
        c1Reset     => oOReset,  -- out boolean := false
        c2Reset     => iOReset); -- out boolean := false

    iOResetStatus <= iOReset;
    oNxPushToggleToReady <= oPushToggle2 and not oEitherReset;
    oPushToggleChanged <= (oNxPushToggleToReady /= oNxPushToggle2);

    process (aOReset, OClk) is
    begin
      if aOReset then
        oDataValid <= false;
      elsif rising_edge(OClk) then
        oDataValid <= oPushToggleChanged;
      end if;
    end process;

    -- Instantiate DFlop for oLclData for Reasons 1 and 2 (see purpose statement)

    ---------------------------------------------------------------------------
    -- !ASSUMPTION! Note that this is the only flop where a clock enable is actually
    -- required.  We're crossing a clock boundary here from iLclStoredData to oLclData
    -- and need to be sure that the D input of this flip-flop is stable when
    -- oPushToggleChanged asserts.  The major assumption here is that the routing
    -- from iLclStoredData to the D input of oLclData will be less than the
    -- time it takes for iPushToggle to propagate to oPushToggleChanged.  A constraint
    -- must be written to ensure that the path from iLclStoredDatax|cQ to its
    -- destination is less than 2 oClk cycles.
    ---------------------------------------------------------------------------

    --vhook_e DFlopSlvResetVal oDataFlopx
    --vhook_a kWidth kDataWidth
    --vhook_a aReset aOReset
    --vhook_a Clk OClk
    --vhook_a cEn oPushToggleChanged
    --vhook_a cD iLclStoredData
    --vhook_a cQ oData
    oDataFlopx: entity work.DFlopSlvResetVal (rtl)
      generic map (
        kWidth    => kDataWidth,  -- in  integer
        kResetVal => kResetVal)   -- in  std_logic_vector
      port map (
        aReset => aOReset,             -- in  boolean
        cEn    => oPushToggleChanged,  -- in  boolean
        Clk    => OClk,                -- in  std_logic
        cD     => iLclStoredData,      -- in  std_logic_vector(kWidth-1 downto 0)
        cQ     => oData);              -- out std_logic_vector(kWidth-1 downto 0) := kRes

    ---------------------------------------------------------------------------
    -- oIReset is OR'd in to cover the case where the toggle chain gets
    -- synchronously reset due to aIReset setting.  This will allow the
    -- new cleared value of oNxPushToggleToReady to be passed through so the
    -- module can become ready when aIReset releases.
    ---------------------------------------------------------------------------
    oDataAckClkEnable <= oIReset
                         or oDataAck;

    -- Instantiate DFlop for oPushToggleToReady for Reason 2 (see purpose statement)

    --vhook_e DFlopBool oPushToggleToReadyx
    --vhook_a kAsyncReg "false"      
    --vhook_a kResetVal false
    --vhook_a aReset aOReset
    --vhook_a Clk OClk
    --vhook_a cEn oDataAckClkEnable
    --vhook_a cD oNxPushToggleToReady
    --vhook_a cQ oPushToggleToReady
    oPushToggleToReadyx: entity work.DFlopBool (rtl)
      generic map (
        kResetVal => false,    -- in  boolean := false
        kAsyncReg => "false")  -- in  string := "false"
      port map (
        aReset => aOReset,               -- in  boolean
        cEn    => oDataAckClkEnable,     -- in  boolean
        Clk    => OClk,                  -- in  std_logic
        cD     => oNxPushToggleToReady,  -- in  boolean
        cQ     => oPushToggleToReady);   -- out boolean := kResetVal

  end block BlkOut;

  ---------------------------------------------------------------------------
  -- The rdyproc process in this block creates the iReady signal.  This signal
  -- is false once iPush asserts and becomes true once the push signal makes
  -- it back around from the OClk domain.
  ---------------------------------------------------------------------------
  BlkRdy: block
    signal iRdyPushToggle_ms, iRdyPushToggle : boolean := false;
   
  begin

    -- Instantiate DFlop for iRdyPushToggle_ms for Reason 2 (see purpose statement)

    --vhook_e DFlopBool iRdyPushToggle_msx
    --vhook_a kAsyncReg "true"      
    --vhook_a kResetVal false
    --vhook_a aReset aIReset
    --vhook_a Clk IClk
    --vhook_a cEn true
    --vhook_a cD oPushToggleToReady
    --vhook_a cQ iRdyPushToggle_ms
    iRdyPushToggle_msx: entity work.DFlopBool (rtl)
      generic map (
        kResetVal => false,   -- in  boolean := false
        kAsyncReg => "true")  -- in  string := "false"
      port map (
        aReset => aIReset,             -- in  boolean
        cEn    => true,                -- in  boolean
        Clk    => IClk,                -- in  std_logic
        cD     => oPushToggleToReady,  -- in  boolean
        cQ     => iRdyPushToggle_ms);  -- out boolean := kResetVal
        
    --vhook_e DFlopBool iRdyPushTogglex
    --vhook_a kAsyncReg "true"      
    --vhook_a kResetVal false
    --vhook_a aReset aIReset
    --vhook_a Clk IClk
    --vhook_a cEn true
    --vhook_a cD iRdyPushToggle_ms
    --vhook_a cQ iRdyPushToggle
    iRdyPushTogglex: entity work.DFlopBool (rtl)
      generic map (
        kResetVal => false,   -- in  boolean := false
        kAsyncReg => "true")  -- in  string := "false"
      port map (
        aReset => aIReset,            -- in  boolean
        cEn    => true,               -- in  boolean
        Clk    => IClk,               -- in  std_logic
        cD     => iRdyPushToggle_ms,  -- in  boolean
        cQ     => iRdyPushToggle);    -- out boolean := kResetVal

    process (aIReset, IClk)
    begin
      if aIReset then
        iLclReady <= false;
      elsif rising_edge(IClk) then
        iLclReady <= (not iPushLcl)
                     and (iPushToggle = iRdyPushToggle)
                     and (not iIReset)
                     and (not iOReset);
      end if;
    end process;

    iReady <= iLclReady;

  end block BlkRdy;

  ---------------------------------------------------------------------------
  -- This block contains error detection circuitry.  It checks to see if
  -- the user has asserted iPush while iReady is not asserted and checks
  -- to see if the user has iPush asserted when aReset deasserts
  ---------------------------------------------------------------------------
  --synthesis translate_off
  BlkErr: block
  begin

    assert not (    (not aIReset)
                and (iPush and not iDlyPush)
                and (not iLclReady)
                and rising_edge(iClk))
      report "iPush asserted while handshake module not ready."
      severity failure;

    process (aIReset)
    begin
      if not aIReset then
        assert not iPush report "iPush asserted when aIReset deasserted" severity failure;
      end if;
    end process;

    process (iOReset) is
    begin
      if not iOReset then
        assert not iLclReady report "iReady should be false when iOReset clears" severity failure;
      end if;
    end process;

  end block BlkErr;
  --synthesis translate_on

end rtl;

-- The following comment is a checksum VScan uses to determine whether this
-- file has been modified.  Please don't try to get around it.  It's there
-- for a reason.
--VScan_CS 29849120
