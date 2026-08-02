-------------------------------------------------------------------------------
--
-- File: NiFpgaFifoPortReset.vhd
-- Author: Gregory Voirin
-- Original Project: Original Project Name Here
-- Date: 1 Janvier 2007
--
-------------------------------------------------------------------------------
-- (c) 2007 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
-- This component is used in the FifoTypeSelector entity of the LabVIEW FPGA
-- FIFOs, to handle the synchronous reset of the Fifo Read port or the Fifo
-- Write port when there is a clock domain crossing.
-- This component communicates with the Clear FSM in the fsmClk Clock domain
-- and with the Fifo Read (or Write) port in the portClk Clock Domain.
--
-- Requirements: 
-- When a 1 fsmClk cycle pulse is sent on fReset, pReset needs to assert for 
-- at least 1 port cycle pulse.
-- After portResert deassert, a rising_edge must be seen on fDone.
--
-------------------------------------------------------------------------------

library ieee, work;
use ieee.std_logic_1164.all;
use work.PkgNiUtilities.all;

entity NiFpgaFifoPortReset is
  generic(
    kClearPushClockCrossing : boolean := false;
    kClearPopClockCrossing  : boolean := false;
    kPushPopClockCrossing   : boolean := false
    );
  port(
    aReset : in boolean;

    CClk           : in  std_logic;     -- clock of the Clear port
    cClear         : in  boolean;
    cPushClearDone : out boolean;
    cPopClearDone  : out boolean;

    IClk   : in  std_logic;             -- clock of the Push port
    iReset : out boolean;

    OClk   : in  std_logic;             -- clock of the Pop port
    oReset : out boolean
    );
end entity;

architecture rtl of NiFpgaFifoPortReset is

  constant kGenerateClockCrossingComponents : boolean :=
    kClearPopClockCrossing or
    kClearPushClockCrossing or
    kPushPopClockCrossing or
    true;
  -- ||
  -- || remove "true" and uncomment the generate statement at the
  -- \\ bottom of the file when the FifoFlags component is optimized for
  --    non-clock-crossing case

  --vhook_sigstart
  signal iResetFromPop: boolean;
  signal iResetLoc: std_logic;
  signal iSigCE: std_logic;
  signal oResetFromPush: boolean;
  signal oResetLoc: std_logic;
  signal oSigCE: std_logic;
  --vhook_sigend

  signal cPopClearDoneLoc, cPushClearDoneLoc       : std_logic;
  signal cPopClearDoneLocDly, cPushClearDoneLocDly : boolean;

  signal oPopClearDone  : boolean;
  signal iPushClearDone : boolean;

  signal oResetDly, iResetDly                    : boolean;
  signal iResetFromPopDly, iResetFromPopDlyDly   : boolean;
  signal oResetFromPushDly, oResetFromPushDlyDly : boolean;

  type State_t is (Idle, Driving);
  signal iPushDoneState, iNxPushDoneState : State_t := Idle;
  signal oPopDoneState, oNxPopDoneState   : State_t := Idle;
  
begin

  Crossing : if kGenerateClockCrossingComponents generate

    ---------------------------------------------------------------------------
    -- CLEAR TO POP
    ---------------------------------------------------------------------------
    
    process (aReset, CClk)
    begin
      if aReset then
        cPopClearDoneLocDly <= false;
      elsif rising_edge(CClk) then
        cPopClearDoneLocDly <= to_Boolean(cPopClearDoneLoc);
      end if;
    end process;
    cPopClearDone <= cPopClearDoneLocDly and not to_Boolean(cPopClearDoneLoc);
    oReset        <= to_Boolean(oResetLoc);

    --vhook_e NiFpgaPulseSyncBaseWrapper ClearToPop
    --vhook_a IClk          CClk
    --vhook_a iClkEn        true
    --vhook_a iSig          to_StdLogic(cClear)
    --vhook_a iStatusOfoSig cPopClearDoneLoc 
    --vhook_a OClk          OClk
    --vhook_a oClkEn        true
    --vhook_a oSigCE        oSigCE
    --vhook_a oSig          oResetLoc
    --vhook_a oSigAck       oPopClearDone
    ClearToPop: entity work.NiFpgaPulseSyncBaseWrapper (rtl)
      port map (
        aReset        => aReset,
        IClk          => CClk,
        iClkEn        => true,
        iSig          => to_StdLogic(cClear),
        iStatusOfoSig => cPopClearDoneLoc,
        OClk          => OClk,
        oClkEn        => true,
        oSigAck       => oPopClearDone,
        oSigCE        => oSigCE,
        oSig          => oResetLoc);

    ---------------------------------------------------------------------------

    -- Adding a flip-flop between the 2 PulseSync components

    process (aReset, OClk)
    begin
      if aReset then
        oResetDly <= false;
      elsif rising_edge(OClk) then
        oResetDly <= to_Boolean(oResetLoc);
      end if;
    end process;

    ---------------------------------------------------------------------------
    -- POP TO PUSH
    ---------------------------------------------------------------------------

    --vhook_e PulseSyncBool PopToPush
    --vhook_a IClk OClk
    --vhook_a iSig oResetDly
    --vhook_a OClk IClk
    --vhook_a oSig iResetFromPop
    PopToPush: entity work.PulseSyncBool (behavior)
      port map (
        aReset => aReset,
        IClk   => OClk,
        iSig   => oResetDly,
        OClk   => IClk,
        oSig   => iResetFromPop);

    ---------------------------------------------------------------------------

    -- Adding 2 flip-flops in front of the state machine (accounts for the
    -- From-To timing constraints set in FifoFlags)

    process (aReset, IClk)
    begin
      if aReset then
        iResetFromPopDly    <= false;
        iResetFromPopDlyDly <= false;
      elsif rising_edge(IClk) then
        iResetFromPopDly    <= iResetFromPop;
        iResetFromPopDlyDly <= iResetFromPop and not iResetFromPopDly;
      end if;
    end process;

    ---------------------------------------------------------------------------

    -- Adding the state machine to handle the feedback. See comment in 
    -- PulseSyncBase about keeping oSigReturn asserted until oSigCE unasserts
    -- ASSUMPTION: oResetFromPushDlyDly will always assert after oSigCE. This is
    -- a valid assumption because both signals have the same root "source" (the
    -- cClear pulse) but 2 different paths:
    --   Path 1 (oSigCe): the clear pulse goes through a CClk to OClk pulse sync
    --   Path2 (oResetFromPushDelay):  the clear pulse goes through a CClk to 
    --    IClk pulse sync AND a IClk to OClk pulse sync AND some flipflops
    -- Path2 is always longer than Path1, regardless of the clock frequencies.

    process (oPopDoneState, oResetFromPushDlyDly, oSigCE)
    begin
      oNxPopDoneState <= oPopDoneState;
      case (oPopDoneState) is
        when Idle =>
          if oResetFromPushDlyDly then
            oNxPopDoneState <= Driving;
          end if;
          
        when Driving =>
          if oSigCE = '0' then
            oNxPopDoneState <= Idle;
          end if;

      end case;
    end process;

    --Clocked process to assign iPushDoneState (Note that this flip-flop is 
    -- accounted for: see design documents)

    process (aReset, OClk)
    begin
      if aReset then
        oPopDoneState <= Idle;
      elsif rising_edge(OClk) then
        oPopDoneState <= oNxPopDoneState;
      end if;
    end process;

    -- Output of the state machine

    oPopClearDone <= (oPopDoneState = Driving);

    ---------------------------------------------------------------------------
    -- CLEAR TO PUSH
    ---------------------------------------------------------------------------

    process (aReset, CClk)
    begin
      if aReset then
        cPushClearDoneLocDly <= false;
      elsif rising_edge(CClk) then
        cPushClearDoneLocDly <= to_Boolean(cPushClearDoneLoc);
      end if;
    end process;
    cPushClearDone <= cPushClearDoneLocDly and not to_Boolean(cPushClearDoneLoc);
    iReset         <= to_Boolean(iResetLoc);

    --vhook_e NiFpgaPulseSyncBaseWrapper ClearToPush
    --vhook_a IClk          CClk
    --vhook_a iClkEn        true
    --vhook_a iSig          to_StdLogic(cClear)
    --vhook_a iStatusOfoSig cPushClearDoneLoc 
    --vhook_a OClk          IClk
    --vhook_a oClkEn        true
    --vhook_a oSigCE        iSigCE
    --vhook_a oSig          iResetLoc
    --vhook_a oSigAck       iPushClearDone
    ClearToPush: entity work.NiFpgaPulseSyncBaseWrapper (rtl)
      port map (
        aReset        => aReset,
        IClk          => CClk,
        iClkEn        => true,
        iSig          => to_StdLogic(cClear),
        iStatusOfoSig => cPushClearDoneLoc,
        OClk          => IClk,
        oClkEn        => true,
        oSigAck       => iPushClearDone,
        oSigCE        => iSigCE,
        oSig          => iResetLoc);

    ---------------------------------------------------------------------------

    -- Adding a flip-flop between the 2 PulseSync components

    process (aReset, IClk)
    begin
      if aReset then
        iResetDly <= false;
      elsif rising_edge(IClk) then
        iResetDly <= to_Boolean(iResetLoc);
      end if;
    end process;

    ---------------------------------------------------------------------------

    -- Adding the state machine to handle the feedback. See comment in 
    -- PulseSyncBase about keeping iSigReturn asserted until iSigCE unasserts
    -- ASSUMPTION: iResetFromPopDlyDly will always assert after iSigCE. This is
    -- a valid assumption because both signals have the same root "source" (the
    -- cClear pulse) but 2 different paths:
    --   Path 1 (iSigCe): the clear pulse goes through a CClk to IClk pulse sync
    --   Path2 (iResetFromPopDelay):  the clear pulse goes through a CClk to 
    --    OClk pulse sync AND a OClk to IClk pulse sync AND some flipflops
    -- Path2 is always longer than Path1, regardless of the clock frequencies.

    process (iPushDoneState, iResetFromPopDlyDly, iSigCE)
    begin
      iNxPushDoneState <= iPushDoneState;
      case (iPushDoneState) is
        when Idle =>
          if iResetFromPopDlyDly then
            iNxPushDoneState <= Driving;
          end if;
          
        when Driving =>
          if iSigCE = '0' then
            iNxPushDoneState <= Idle;
          end if;
      end case;
      
    end process;

    --Clocked process to assign iPushDoneState (Note that this flip-flop is 
    -- accounted for: see design documents)

    process (aReset, IClk)
    begin
      if aReset then
        iPushDoneState <= Idle;
      elsif rising_edge(IClk) then
        iPushDoneState <= iNxPushDoneState;
      end if;
    end process;

    -- Output of the state machine

    iPushClearDone <= (iPushDoneState = Driving);

    ---------------------------------------------------------------------------
    -- PUSH TO POP
    ---------------------------------------------------------------------------

    --vhook_e PulseSyncBool PushToPop
    --vhook_a IClk IClk
    --vhook_a iSig iResetDly
    --vhook_a OClk OClk
    --vhook_a oSig oResetFromPush
    PushToPop: entity work.PulseSyncBool (behavior)
      port map (
        aReset => aReset,
        IClk   => IClk,
        iSig   => iResetDly,
        OClk   => OClk,
        oSig   => oResetFromPush);

    ---------------------------------------------------------------------------

    -- Adding 2 flip-flops in front of the state machine (accounts for the
    -- From-To timing constraints set in FifoFlags)

    process (aReset, OClk)
    begin
      if aReset then
        oResetFromPushDly    <= false;
        oResetFromPushDlyDly <= false;
      elsif rising_edge(OClk) then
        oResetFromPushDly    <= oResetFromPush;
        oResetFromPushDlyDly <= oResetFromPush and not oResetFromPushDly;
      end if;
    end process;
    
  end generate Crossing;

  -----------------------------------------------------------------------------
  -- NO CLOCK CROSSINGS
  -----------------------------------------------------------------------------

  --? NoCrossing : if not kGenerateClockCrossingComponents generate
  --? 
  --?   iReset <= cClear;
  --?   oReset <= cClear;
  --?   -- Adding a flip-flop so it takes at least one clock cycle to send the
  --?   -- ClearDone pulse (which is a requirement due to the State Machine of
  --?   -- the FifoControl component).
  --?   process (aReset, CClk)
  --?   begin
  --?     if aReset then
  --?       cPushClearDone <= false;
  --?       cPopClearDone  <= false;
  --?     elsif rising_Edge(CClk) then
  --?       cPushClearDone <= cClear;
  --?       cPopClearDone  <= cClear;
  --?     end if;
  --?   end process;
  --? 
  --? end generate NoCrossing;
  
end rtl;
