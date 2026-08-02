-------------------------------------------------------------------------------
--
-- File: HandshakeBase.vhd
-- Author: Craig Conway
-- Original Project: NICores
-- Date: 23 October 2002
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
--  IClk and OClk. It also uses clock enables.
--      Worst case turnaround time is 5 IClk cycles and 4 OClk cycles.  If
--  IClk and OClk were the same clock, this means you would be able to assert
--  iPush once every 9 clock cycles.
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity HandshakeBase is
  generic (
    kDataWidth : integer := 32
  );
  port (
    aReset:      in  boolean;

    IClk:        in  std_logic;
    iPush:       in  boolean;
    iData:       in  std_logic_vector(kDataWidth-1 downto 0) := (others => '0');
    iStoredData: out std_logic_vector(kDataWidth-1 downto 0);
    iReady:      out boolean;

    OClk:        in  std_logic;
    oDataValid:  out boolean;
    oDataAck:    in  boolean := true;
    oData:       out std_logic_vector(kDataWidth-1 downto 0)
  );
end HandshakeBase;

architecture behavior of HandshakeBase is

  --vhook_sigstart
  --vhook_sigend

  constant kResetVal : std_logic_vector(kDataWidth-1 downto 0) := (others => '0');

  signal iDlyPush, iPushToggle , oPushToggleToReady : boolean;
  signal iLclReady : boolean;
  signal iLclStoredData : std_logic_vector(iData'range);

begin

  ---------------------------------------------------------------------------
  -- This block contains a process that captures the iPush signal and creates
  -- a pulse from it.  That pulse causes the iPushToggle signal to change and
  -- causes iData to be stored.
  ---------------------------------------------------------------------------
  BlkIn: block
    signal iPushPulse : boolean;
  begin

    process (aReset, IClk)
    begin
      if aReset then
        iDlyPush <= false;
      elsif rising_edge(IClk) then
        iDlyPush <= iPush;
      end if;
    end process;

    iPushPulse <= iPush and not iDlyPush;

    process (aReset, IClk)
    begin
      if aReset then
        iPushToggle <= false;
        iLclStoredData <= (others => '0');
      elsif rising_edge(IClk) then
        if iPushPulse then
          iPushToggle <= not iPushToggle;
          iLclStoredData <= iData;
        end if;
      end if;
    end process;

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
           oPushToggle2,
           oPushToggleChanged : boolean := false;
    signal oLclData :  std_logic_vector(kDataWidth-1 downto 0) := (others => '0');
    
    attribute ASYNC_REG : string;
    attribute ASYNC_REG of oPushToggle0_ms,oPushToggle1 : signal is "true";

  begin

    process (aReset, OClk)
    begin
      if aReset then
        oPushToggle0_ms <= false;
        oPushToggle1 <= false;
        oPushToggle2 <= false;
      elsif rising_edge(OClk) then
        oPushToggle0_ms <= iPushToggle;
        oPushToggle1 <= oPushToggle0_ms;
        oPushToggle2 <= oPushToggle1;
      end if;
    end process;

    oPushToggleChanged <= oPushToggle2 /= oPushToggle1;

    process (aReset, OClk)
    begin
      if aReset then
        oDataValid <= false;
        oPushToggleToReady <= false;
      elsif rising_edge(OClk) then
        oDataValid <= oPushToggleChanged;
        if oDataAck then
          oPushToggleToReady <= oPushToggle2;
        end if;
      end if;
    end process;

    ---------------------------------------------------------------------------
    --!ASSUMPTION! I am driving oData directly from iStoredData
    --because oDataValid won't assert until iStoredData is set
    --up.  The major assumption here is that the routing from
    --iStoredData to the D input of oData will be less than the
    --time it takes for iPush to propagate to oPush.  If the
    --frequency of oClk is high (say 200 MHz?), this assumption
    --may no longer be valid and a constraint must be written
    --to specify that the delay from iClk to oClk must be less
    --than 2 oClk cycles.
    ---------------------------------------------------------------------------

    --vhook_e DFlopSlvResetVal ODataFlop
    --vhook_a kWidth kDataWidth
    --vhook_a Clk OClk
    --vhook_a cEn oPushToggleChanged
    --vhook_a cD iLclStoredData
    --vhook_a cQ oLclData
    ODataFlop: entity work.DFlopSlvResetVal (rtl)
      generic map (
        kWidth    => kDataWidth,  -- in  integer
        kResetVal => kResetVal)   -- in  std_logic_vector
      port map (
        aReset => aReset,              -- in  boolean
        cEn    => oPushToggleChanged,  -- in  boolean
        Clk    => OClk,                -- in  std_logic
        cD     => iLclStoredData,      -- in  std_logic_vector(kWidth-1 downto 0)
        cQ     => oLclData);           -- out std_logic_vector(kWidth-1 downto 0) := kRes

    oData <= oLclData;


  end block BlkOut;

  ---------------------------------------------------------------------------
  -- The rdyproc process in this block creates the iReady signal.  This signal
  -- is false once iPush asserts and becomes true once the push signal makes
  -- it back around from the OClk domain.
  ---------------------------------------------------------------------------
  BlkRdy: block
    signal iReset_ms, iReset : boolean := true;
    signal iRdyPushToggle_ms, iRdyPushToggle : boolean;
    
    attribute ASYNC_REG : string;
    attribute ASYNC_REG of iReset_ms,iReset: signal is "true";
    attribute ASYNC_REG of iRdyPushToggle_ms,iRdyPushToggle: signal is "true";

  begin

    -- Create a synchronous version of reset so we can keep iReady from
    -- asserting when the asynchronous reset asserts
    rstproc: process (aReset, IClk)
    begin
      if aReset then
        iReset_ms <= true;
        iReset <= true;
      elsif rising_edge(IClk) then
        iReset_ms <= false;
        iReset <= iReset_ms;
      end if;
    end process;

    process (aReset, IClk)
    begin
      if aReset then
        iRdyPushToggle_ms <= false;
        iRdyPushToggle <= false;
        iLclReady <= false;
      elsif rising_edge(IClk) then
        iRdyPushToggle_ms <= oPushToggleToReady;
        iRdyPushToggle <= iRdyPushToggle_ms;
        iLclReady <= (not iPush) and (iPushToggle = iRdyPushToggle) and not iReset;
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

    assert not ((iPush and not iDlyPush)
                and (not iLclReady) and (not aReset) and rising_edge(iClk))
      report "iPush asserted while handhake module not ready."
      severity failure;

    process (aReset)
    begin
      if not aReset then
        assert not iPush report "iPush asserted when aReset deasserts" severity failure;
      end if;
    end process;

  end block BlkErr;
  --synthesis translate_on

end behavior;

-- The following comment is a checksum VScan uses to determine whether this
-- file has been modified.  Please don't try to get around it.  It's there
-- for a reason.
--VScan_CS 54226122
