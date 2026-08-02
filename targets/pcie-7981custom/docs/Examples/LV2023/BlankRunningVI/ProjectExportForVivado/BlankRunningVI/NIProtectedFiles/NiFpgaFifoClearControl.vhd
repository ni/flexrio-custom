-------------------------------------------------------------------------------
--
-- File: NiFpgaFifoClearControl.vhd
-- Author: Gregory Voirin
-- Original Project: LabVIEW FPGA FIFO Clear
-- Date: 14 November 2006
-- Modified by Lei Song on 2 Nov 2009
-- Add the built-in FIFO support
-------------------------------------------------------------------------------
-- (c) 2006 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--
--   This entity handles the disabling of the push and the pop port before sending
--   the clear request to the resource. It is meant to prevent any push or pop
--   request during the clear phase of the underlying FIFO.
--
--   Note:
--   The use of the states Wait4ResetDone, Wait4PushResetDone,  and
--   Wait4PopResetDone comes from the lack of control on the arrival time of the
--   ack signals(cPushClearDone, cPopClearDone). In case the Push and Pop ports are in different clock
--   domains, it's likely that these signals will arrive at different times, so
--   the logic here is robust enough to tackle same-time arrival, faster Push ack or faster Pop ack.
--
--   Since built-in FIFO doesn't have a synchronous reset, we need to use an extra
--   state "Wait4Empty" to pop all the elements in the FIFO.
--
--   For cores with *RstBusy signals, the reset phase takes longer than one cycle,
--   which means that the core must not be read/written when these signals are asserted.
--   Two states (Wait4EnterResetState, Wait4FinishResetState) were added to cover this use-case.
--
-- Ports:
--   aReset
--     Asynchronous reset input.  Pretty much resets everything.
--
--   IClk, OClk, CClk
--     IClk is the clock for the write side of the FIFO. OClk is the read side clock. CClk is the clk of clear method.
--
--    cEnableIn,  cEnableClr,  cEnableOut
--      Enabel chain of clear method
--
--    iDisablePush, iPushDisabled, oDisablePop, oPopDisabled
--      Disable request and acknowledge signals for push and pop control entity
--
--    oReset, iReset
--      Reset signals for read count and write count.
--
--    oPopFromClear
--      Pop signal for the FIFO core. Pop from clear or from pop entity will both pop the FIFO.
--
--    oEmpty
--      Indicate that the FIFO is empty and clear operation finished.
--
--    iEmpty
--      Indicate if the iEmptyCount = kDepth
-------------------------------------------------------------------------------

library ieee, work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.PkgNiUtilities.all;

entity NiFpgaFifoClearControl is
  generic(
    kSingleCycleLoop        : boolean := false;
    kClearPushClockCrossing : boolean := false;
    kClearPopClockCrossing  : boolean := false;
    kPushPopClockCrossing   : boolean := false;
    kBuiltin                : boolean := false;
    kUsesRstBusySignals     : boolean := false
    );
  port(
    aReset : in boolean;

    -- Push port

    IClk          : in  std_logic;
    iReset        : out boolean;
    iDisablePush  : out boolean;
    iPushDisabled : in  boolean;
    iWrRstBusy    : in  boolean := false;

    -- Pop port

    OClk         : in  std_logic;
    oReset       : out boolean;
    oDisablePop  : out boolean;
    oPopDisabled : in  boolean;
    --vhook_nowarn oRdRstBusy
    oRdRstBusy   : in  boolean := false;

    -- Clear Port
    oPopFromClear: out boolean;
    oEmpty       : in  boolean := true;
    iEmpty       : in  boolean := true;

    CClk       : in  std_logic;
    cEnableIn  : in  boolean;
    cEnableClr : in  boolean;
    cEnableOut : out boolean
    );
end entity NiFpgaFifoClearControl;

architecture rtl of NiFpgaFifoClearControl is

  type ControlState_t is (
    Idle,
    Wait4DisableDone,
    Wait4ResetDone,
    Wait4PushResetDone,
    Wait4PopResetDone,
    Wait4ReEnable,
    Wait4Empty,
    Wait4EnterResetState,
    Wait4FinishResetState
    );

  -- The main control logic is in the Clear Port clock domain(CClk)
  signal cDisablerState, cDisablerNxState : ControlState_t := Idle;

  -- Clear Request
  signal cClearReq : boolean;

  -- Local signals
  signal cEnableOutLoc                 : boolean := false;
  signal cClear                        : boolean;
  signal cDisable                      : boolean := false;
  signal cPushDisabled, cPopDisabled   : boolean;
  signal cPushClearDone, cPopClearDone : boolean;
  signal cPopFromClear                 : boolean := false;
  signal cEmpty                        : boolean := true;
  signal cEmptyICount                  : boolean := true;
  --vhook_sigstart
  signal cFifoInResetState: boolean;
  --vhook_sigend

begin

  -- For the moment, this component supports only single-clock functionality
  -- when using *RstBusy signals. Multi-clock functionality is not required
  -- for UltraRAM FIFOs, the only one exposing *RstBusy.
  assert not (kUsesRstBusySignals and kPushPopClockCrossing)
    report "When utilizing *RstBusy signals, the FIFO must be single-clock."
    severity failure;

  -----------------------------------------------------------------------------
  -- Building the cClear Request signal
  -----------------------------------------------------------------------------
  ClearRequestSCL : if kSingleCycleLoop generate
    cClearReq <= cEnableIn;
  end generate;  -- ClearRequestSCL

  ClearRequestNoSCL : if not kSingleCycleLoop generate
    signal cDelayedEnableIn : boolean := false;
  begin

    process (aReset, CClk)
    begin
      if aReset then
        cDelayedEnableIn <= false;
      elsif rising_edge(CClk) then
        cDelayedEnableIn <= cEnableIn;
      end if;
    end process;
    cClearReq <= cEnableIn and not cDelayedEnableIn;

  end generate;  -- ClearRequestNoSCL
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- DISABLER STATE MACHINE
  -----------------------------------------------------------------------------
  -- !STATE MACHINE STARTUP! This state machine cannot start
  -- immediately after aReset deasserts because cClearReq won't be
  -- asserted; thus, the asynchronous reset is safe.
  -- Asynchronous process
  Disabler : process (cDisablerState, cPushDisabled, cPopDisabled, cFifoInResetState,
                      cClearReq, cPushClearDone, cPopClearDone, cEmpty, cEmptyICount)
  begin

    -- Default assignement
    cDisablerNxState <= cDisablerState;
    cClear           <= false;
    cPopFromClear    <= false;

    case cDisablerState is
      when Idle =>
        -- When a new clear request comes from the resholser(s)
        if cClearReq then
          cDisablerNxState <= Wait4DisableDone;  -- wait for ack
        end if;

      when Wait4DisableDone =>
        -- When both ports are disabled
        if cPushDisabled and cPopDisabled then
          cClear           <= true;  -- send the clear to the resource (pulse)
          if kUsesRstBusySignals then
            cDisablerNxState <= Wait4EnterResetState;
          else
            cDisablerNxState <= Wait4ResetDone;  -- wait for done
          end if;
        end if;

      when Wait4EnterResetState =>
        cClear <= false;
        if cFifoInResetState then
          cDisablerNxState <= Wait4FinishResetState;
        end if;

      when Wait4FinishResetState =>
        if not cFifoInResetState then
          cDisablerNxState <= Wait4ReEnable;
        end if;

      when Wait4ResetDone =>
        -- Stop requesting the clear
        cClear <= false;
        -- Wait for clear done from resource
        if cPushClearDone then
          if cPopClearDone then
            cDisablerNxState <= Wait4Empty;
          else
            -- wait 4 the other clear done
            cDisablerNxState <= Wait4PopResetDone;
          end if;
        elsif cPopClearDone then
          -- wait 4 the other clear done
          cDisablerNxState <= Wait4PushResetDone;
        end if;

      when Wait4PopResetDone =>
        if cPopClearDone then
          cDisablerNxState <= Wait4Empty;
        end if;

      when Wait4PushResetDone =>
        if cPushClearDone then
          cDisablerNxState <= Wait4Empty;
        end if;

      when Wait4Empty =>
        if not kBuiltin then
          cDisablerNxState <= Wait4ReEnable;
        else
          cPopFromClear  <= true;
          if cEmpty and cEmptyICount then
            -- re-enable the ports as both clears are done
            cDisablerNxState <= Wait4ReEnable;
          end if;
        end if;

      when Wait4ReEnable =>
        -- We are not done until we get the ack of re-enabling the ports
        if not cPushDisabled and not cPopDisabled then
          cDisablerNxState <= Idle;
        end if;

      when others =>
        cDisablerNxState <= Idle;
    end case;
  end process Disabler;

  -- This register was added to ensure the outputs (iPushDisable and oPopDisable)
  -- are registered especially if the upper level component wants to wrap back a
  -- Disable output to a Disabled input
  process (aReset, CClk)
  begin
    if aReset then
      cDisable <= false;
    elsif rising_edge(CClk) then
      cDisable <= cDisablerNxState = Wait4DisableDone
                  or cDisablerNxState = Wait4ResetDone
                  or cDisablerNxState = Wait4PushResetDone
                  or cDisablerNxState = Wait4PopResetDone
                  or cDisablerNxState = Wait4Empty
                  or cDisablerNxState = Wait4EnterResetState
                  or cDisablerNxState = Wait4FinishResetState;
    end if;
  end process;

  -- Clocked state assignement
  process (aReset, CClk)
  begin
    if aReset then
      cDisablerState <= Idle;
    elsif rising_edge(CClk) then
      cDisablerState <= cDisablerNxState;
    end if;
  end process;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  --Synchronization to the push port
  -----------------------------------------------------------------------------
  PushSynchNeeded : if kClearPushClockCrossing generate

  begin

    -- Double Synchronize the Disable request TO the port

    --vhook_e DoubleSyncBool ToPushDblSync
    --vhook_a IClk CClk
    --vhook_a iSig cDisable
    --vhook_a OClk IClk
    --vhook_a oSig iDisablePush
    ToPushDblSync: entity work.DoubleSyncBool (behavior)
      port map (
        aReset => aReset,        -- in  boolean
        IClk   => CClk,          -- in  std_logic
        iSig   => cDisable,      -- in  boolean
        OClk   => IClk,          -- in  std_logic
        oSig   => iDisablePush); -- out boolean

    -- Double Synchronize the Disable ack FROM the port

    --vhook_e DoubleSyncBool FromPushDblSync
    --vhook_a IClk IClk
    --vhook_a iSig iPushDisabled
    --vhook_a OClk CClk
    --vhook_a oSig cPushDisabled
    FromPushDblSync: entity work.DoubleSyncBool (behavior)
      port map (
        aReset => aReset,         -- in  boolean
        IClk   => IClk,           -- in  std_logic
        iSig   => iPushDisabled,  -- in  boolean
        OClk   => CClk,           -- in  std_logic
        oSig   => cPushDisabled); -- out boolean

    DoubleSyncICLKForBuiltin: if kBuiltin generate
    begin
      --vhook_e DoubleSyncBool FromPushDblSyncEmptyICount
      --vhook_a IClk IClk
      --vhook_a iSig iEmpty
      --vhook_a OClk CClk
      --vhook_a oSig cEmptyICount
      FromPushDblSyncEmptyICount: entity work.DoubleSyncBool (behavior)
        port map (
          aReset => aReset,        -- in  boolean
          IClk   => IClk,          -- in  std_logic
          iSig   => iEmpty,        -- in  boolean
          OClk   => CClk,          -- in  std_logic
          oSig   => cEmptyICount); -- out boolean
    end generate DoubleSyncICLKForBuiltin;

    PulseSyncFifoInResetStateForUltraRam: if kUsesRstBusySignals generate
    begin
      -- We are purposefully ignoring the oRdRstBusy signal here and
      -- synchronizing only iWrRstBusy, because they are one and the
      -- same in the case of single-clock FIFOs. If this component is
      -- used for a multi-clock FIFO with *RstBusy signals, an assert
      -- from the very beginning of this architecture block will fail.

      --vhook_e PulseSyncBool SyncFifoInResetStateFromUltraRamFifo
      --vhook_a IClk IClk
      --vhook_a iSig iWrRstBusy
      --vhook_a OClk CClk
      --vhook_a oSig cFifoInResetState
      SyncFifoInResetStateFromUltraRamFifo: entity work.PulseSyncBool (behavior)
        port map (
          aReset => aReset,             -- in  boolean
          IClk   => IClk,               -- in  std_logic
          iSig   => iWrRstBusy,         -- in  boolean
          OClk   => CClk,               -- in  std_logic
          oSig   => cFifoInResetState); -- out boolean
    end generate PulseSyncFifoInResetStateForUltraRam;

  end generate PushSynchNeeded;

  NoPushSynch : if not kClearPushClockCrossing generate

    -- intermediate signals are required for vscan to pick up the assignments
    -- happening within this block. if you add any additional signals using the
    -- Loc suffix make sure you updated the exception below.

    signal iDisablePushLoc, cPushDisabledLoc, cEmptyICountLoc : boolean;

  begin

    iDisablePushLoc <= cDisable;
    iDisablePush    <= iDisablePushLoc;

    cPushDisabledLoc <= iPushDisabled;
    cPushDisabled    <= cPushDisabledLoc;

    cEmptyICountLoc <= iEmpty;
    cEmptyICount    <= cEmptyICountLoc;

    NoPulseSyncFifoInResetStateForUltraRam: if kUsesRstBusySignals generate
    begin

      cFifoInResetState <= iWrRstBusy;

    end generate NoPulseSyncFifoInResetStateForUltraRam;

    --vscan Begin Exception NiFpgaClearControlClearPushCrossingFakeout
    --vscan # the instantiator should guarantee that the CClk and IClk ports
    --vscan # are driven by the same signal if the kClearPushClockCrossing generic
    --vscan # is set to false. given that assumption, this is not really a clock
    --vscan # crossing.
    --vscan Source Clock: *
    --vscan Destination Clock: *
    --vscan Path: {\[NiFpgaFifoClearControl\]NoPushSynch/.*Loc}
    --vscan End

  end generate NoPushSynch;

  -----------------------------------------------------------------------------
  --Synchronization to the pop port
  -----------------------------------------------------------------------------

  PopSynchNeeded : if kClearPopClockCrossing generate

  begin

    -- Double Synchronize the Disable request TO the port
    --vhook_e DoubleSyncBool ToPopDblSync
    --vhook_a IClk CClk
    --vhook_a iSig cDisable
    --vhook_a OClk OClk
    --vhook_a oSig oDisablePop
    ToPopDblSync: entity work.DoubleSyncBool (behavior)
      port map (
        aReset => aReset,       -- in  boolean
        IClk   => CClk,         -- in  std_logic
        iSig   => cDisable,     -- in  boolean
        OClk   => OClk,         -- in  std_logic
        oSig   => oDisablePop); -- out boolean

    -- Double Synchronize the Disable ack FROM the port
    --vhook_e DoubleSyncBool FromPopDblSync
    --vhook_a IClk OClk
    --vhook_a iSig oPopDisabled
    --vhook_a OClk CClk
    --vhook_a oSig cPopDisabled
    FromPopDblSync: entity work.DoubleSyncBool (behavior)
      port map (
        aReset => aReset,        -- in  boolean
        IClk   => OClk,          -- in  std_logic
        iSig   => oPopDisabled,  -- in  boolean
        OClk   => CClk,          -- in  std_logic
        oSig   => cPopDisabled); -- out boolean
    DoubleSyncOCLKForBuiltin: if kBuiltin generate
    begin
      -- Double Synchronize the PopFromClear request TO the port
      --vhook_e DoubleSyncBool ToPopDblSyncPopFromClear
      --vhook_a IClk CClk
      --vhook_a iSig cPopFromClear
      --vhook_a OClk OClk
      --vhook_a oSig oPopFromClear
      ToPopDblSyncPopFromClear: entity work.DoubleSyncBool (behavior)
        port map (
          aReset => aReset,         -- in  boolean
          IClk   => CClk,           -- in  std_logic
          iSig   => cPopFromClear,  -- in  boolean
          OClk   => OClk,           -- in  std_logic
          oSig   => oPopFromClear); -- out boolean

      -- Double Synchronize the Empty FROM the port
      --vhook_e DoubleSyncBool FromPopDblSyncEmpty
      --vhook_a IClk OClk
      --vhook_a iSig oEmpty
      --vhook_a OClk CClk
      --vhook_a oSig cEmpty
      FromPopDblSyncEmpty: entity work.DoubleSyncBool (behavior)
        port map (
          aReset => aReset,  -- in  boolean
          IClk   => OClk,    -- in  std_logic
          iSig   => oEmpty,  -- in  boolean
          OClk   => CClk,    -- in  std_logic
          oSig   => cEmpty); -- out boolean
      end generate DoubleSyncOCLKForBuiltin;
  end generate PopSynchNeeded;

  NoPopSynch : if not kClearPopClockCrossing generate

    -- intermediate signals are required for vscan to pick up the assignments
    -- happening within this block. if you add any additional signals using the
    -- Loc suffix make sure you updated the exception below.
    signal oDisablePopLoc, cPopDisabledLoc, oPopFromClearLoc, cEmptyLoc : boolean;
  begin

    oDisablePopLoc  <= cDisable;
    oDisablePop     <= oDisablePopLoc;
    cPopDisabledLoc <= oPopDisabled;
    cPopDisabled    <= cPopDisabledLoc;
    cEmptyLoc       <= oEmpty;
    cEmpty          <= cEmptyLoc;
    oPopFromClearLoc<= cPopFromClear;
    -- we add this register to ensure there is no asynchronous loop from oPop to the empty flag.
    process (OCLK, aReset)
    begin
      if aReset then
        oPopFromClear <= false;
      elsif rising_edge(OCLK) then
        oPopFromClear <= oPopFromClearLoc;
      end if;
    end process;
    --vscan Begin Exception NiFpgaClearControlClearPopCrossingFakeout
    --vscan # the instantiator should guarantee that the CClk and OClk ports
    --vscan # are driven by the same signal if the kClearPopClockCrossing generic
    --vscan # is set to false. given that assumption, this is not really a clock
    --vscan # crossing.
    --vscan Source Clock: *
    --vscan Destination Clock: *
    --vscan Path: {\[NiFpgaFifoClearControl\]NoPopSynch/.*Loc}
    --vscan End

  end generate NoPopSynch;

  -----------------------------------------------------------------------------
  -- Enable Chain for the clear port
  -----------------------------------------------------------------------------

  EnableChainScl : if kSingleCycleLoop generate
    cEnableOutLoc <= cEnableIn;
  end generate EnableChainScl;

  EnableChainNoScl : if not kSingleCycleLoop generate
    process (aReset, CClk)
    begin
      if aReset then
        cEnableOutLoc <= false;
      elsif rising_edge(CClk) then
        if cEnableClr then
          cEnableOutLoc <= false;
        elsif cEnableIn and cDisablerNxState = Idle then
          cEnableOutLoc <= true;
        else
          cEnableOutLoc <= cEnableOutLoc;
        end if;
      end if;
    end process;
  end generate EnableChainNoScl;

  -----------------------------------------------------------------------------

  -- Outputs from the local signals

  cEnableOut <= cEnableOutLoc;

  --vhook_e NiFpgaFifoPortReset
  NiFpgaFifoPortResetx: entity work.NiFpgaFifoPortReset (rtl)
    generic map (
      kClearPushClockCrossing => kClearPushClockCrossing,  -- in  boolean := false
      kClearPopClockCrossing  => kClearPopClockCrossing,   -- in  boolean := false
      kPushPopClockCrossing   => kPushPopClockCrossing)    -- in  boolean := false
    port map (
      aReset         => aReset,          -- in  boolean
      CClk           => CClk,            -- in  std_logic
      cClear         => cClear,          -- in  boolean
      cPushClearDone => cPushClearDone,  -- out boolean
      cPopClearDone  => cPopClearDone,   -- out boolean
      IClk           => IClk,            -- in  std_logic
      iReset         => iReset,          -- out boolean
      OClk           => OClk,            -- in  std_logic
      oReset         => oReset);         -- out boolean 

  -----------------------------------------------------------------------------
  -- ASSERT statements
  -----------------------------------------------------------------------------

  assert not kSingleCycleLoop
    report "Fifo Clear is called from a SCL although it is not yet supported"
    severity failure;

end rtl;
