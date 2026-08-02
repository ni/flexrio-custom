-------------------------------------------------------------------------------
--
-- File: SafeBusCrossing.vhd
-- Author: Asrar Rangwala
-- Original Project: Safeguarding the Diagram Reset and VIControl registers
-- Date: 22 January 2008
--
-------------------------------------------------------------------------------
-- (c) 2009 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--   This component can be used to provide protection to registers against
--   spurious bus writes. Such invalid accesses could be generated on the PCI
--   bus especially during host warm-reboot. Essentially, this component
--   provides safe data handshaking from BusClk to ReliableClk domain by using
--   NiCore safe reset HS component, along with BusWrite strobe to gate off any
--   invalid bus write access.
--
--   The bus may carry bad traffic during, or even before aBusReset asserts.
--   However, we can rely on the bus write strobe to be glitch-free.
--   To assuage the situation, we use the write strobe to enable the push
--   register before driving it to the NiCore safe reset HS component.
--
-- Timing:
--   Below is the turn-around time (along with breakdown) for rDataValid, and
--   bReady-
--   After bPush asserts, it takes 2 BusClk + 3-4 ReliableClk for rDataValid
--   to be asserted:
--     * 1 BusClk by PushRegister process
--     * 1 BusClk + 3-4 ReliableClk by NiCore safe reset HS component
--
--   After rDataValid asserts, it takes 4-5 BusClk + 1 ReliableClk for bReady
--   to be asserted:
--     * 3-4 BusClk + 1 ReliableClk by NiCore safe reset HS component
--     * 1 BusClk by ReadyRegister process
--
-- Constraints:
--   To guarantee correct operation, constraints must be placed on this
--   component. Refer to "!CONSTRAINT!" in the code for more info.
--
-- Generics:
--   kDataWidth:   This defines the HS data width.
--
-- Ports:
--   aBusReset:    This is the asynchronous bus reset.
--
--   BusClk :      This is the bus clock.
--
--   bPush :       This is the HS Push signal. It should be a single cycle
--                 pulse.
--
--   bPushEn :     For correct operation, it should be asserted one clock cycle
--                 before bPush asserts. Also, it may be asserted for any
--                 arbitrary no. of clock cycles. Ideally, it should be
--                 connected directly to the Bus Write strobe (from an I/O pin,
--                 or a Flip Flop).
--
--   bData :       This is the data HS from BusClk to the ReliableClk domain.
--                 It is captured when bPush is asserted. Width of this port is
--                 defined by kDataWidth.
--
--   bReady :      This indicates when the HS component is ready to transfer
--                 data. It is de-asserted one clock cycle after bPush asserts.
--                 Refer to "Timing" for turn-around time. This output is
--                 registered.
--
--   ReliableClk : This is a raw clock generated straight from an on-board
--                 oscillator. It is considered glitch-free.
--
--   rData :       This is the data HS from BusClk to the ReliableClk domain.
--                 Width of this port is defined by kDataWidth. It is reset
--                 synchronously with aBusReset. This output is registered.
--
--   rDataValid :  It stays asserted for one clock cycle to indicate that rData
--                 is valid. Refer to "Timing" for turn-around time. It is
--                 reset synchronously with aBusReset. This output is
--                 registered.
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;

entity SafeBusCrossing is
  generic (
    kDataWidth : positive := 32
  );
  port (
    aBusReset : in boolean;

    BusClk : in std_logic;
    bPush : in boolean;
    bPushEn : in boolean;
    bData : in std_logic_vector(kDataWidth-1 downto 0) := (others => '0');
    bReady : out boolean;

    ReliableClk : in std_logic;
    rData : out std_logic_vector(kDataWidth-1 downto 0);
    rDataValid : out boolean
  );

  -- These attributes are specific to XST. Without this, constrained
  -- registers can be combined with other registers and be lost,
  -- invalidating the constraint.
  attribute equivalent_register_removal : string;
  attribute equivalent_register_removal of SafeBusCrossing : entity is "no";

end entity SafeBusCrossing;

architecture rtl of SafeBusCrossing is

  --vhook_sigstart
  signal rDataValidLoc: boolean;
  --vhook_sigend

  -----------------------------------------------------------------------------
  -- These signals are shared between blocks
  -----------------------------------------------------------------------------
  signal bPushDly : boolean := false;
  signal bReadyLoc : boolean := false;
  signal bPushEnDly : boolean := false;

begin

  -- ClockDomainCrossing: -----------------------------------------------------
  -- This block performs HS of data from the BusClk to the ReliableClk
  -- domain. It uses BusWrite (bPushEn) signal to gate off any invalid bus
  -- write access.
  -----------------------------------------------------------------------------
  ClockDomainCrossing : block

    signal bDataDly : std_logic_vector(kDataWidth-1 downto 0) := Zeros(kDataWidth);
    signal bHsReady : boolean;

    -- PushEn state type
    type PushEnState_t is (

    -- Idle:    Wait for the host write strobe to assert. bPushEnDly is asserted
    --          on transition to Assert1.
    Idle,
    --
    -- Assert1: Transition to Assert2 and keep bPushEnDly asserted.
    Assert1,
    --
    -- Assert2: Keep bPushEnDly asserted until host write strobe de-asserts.
    --          bPushEnDly is de-asserted on transition to Idle.
    Assert2
    );
    -- PushEn state signals
    signal bPushEnState, bPushEnStateNx : PushEnState_t := Idle;
    signal bPushEnDlyNx : boolean := false;

  begin

    -- PushEnStateRegister: ---------------------------------------------------
    -- This is the next state process for the PushEn state machine.
    ---------------------------------------------------------------------------
    PushEnStateRegister : process(BusClk, aBusReset)
    begin
      if aBusReset then
        bPushEnState <= Idle;
        bPushEnDly <= false;
      elsif rising_edge(BusClk) then
        bPushEnState <= bPushEnStateNx;
        bPushEnDly <= bPushEnDlyNx;
      end if;
    end process PushEnStateRegister;

    -- PushEnNxStatePrc: ------------------------------------------------------
    -- This FSM generates bPushEnDly signal. It is asserted one clock cycle
    -- after bPushEn asserts and remains asserted for atleast 2 clock cycles or
    -- as long as bPushEn remains asserted. Essentially, Bus write strobe is
    -- used as bPushEn to gate off any invalid bus write access.
    --
    -- !STATE MACHINE STARTUP! This state machine cannot start immediately as
    -- bPushEn can only assert a few clock cycles after bitstream download or
    -- after aBusReset is de-asserted. Thus, the FSM is safe.
    ---------------------------------------------------------------------------
    PushEnNxStateProc : process(bPushEnState, bPushEn)
    begin
      bPushEnStateNx <= bPushEnState;
      bPushEnDlyNx <= false;

      case bPushEnState is
        when Idle =>

          bPushEnDlyNx <= false;

          if bPushEn then
            bPushEnStateNx <= Assert1;
            bPushEnDlyNx <= true;
          end if;

        when Assert1 =>

          bPushEnStateNx <= Assert2;
          bPushEnDlyNx <= true;

        when Assert2 =>

          bPushEnDlyNx <= true;

          if not bPushEn then
            bPushEnStateNx <= Idle;
            bPushEnDlyNx <= false;
          end if;

        when others =>

          bPushEnStateNx <= Idle;

      end case;
    end process PushEnNxStateProc;

    -- PushRegister: ----------------------------------------------------------
    -- This process registers the HS push signal. BusWrite signal is used as FF
    -- enable. This is being done so that a valid bus write access could be
    -- further qualified with BusWrite strobe. This provides another layer of
    -- protection from the unreliable bus behavior during host warm-reboot.
    ---------------------------------------------------------------------------
    PushRegister : process (BusClk, aBusReset)
    begin
      if aBusReset then
        bPushDly <= false;
      elsif rising_edge(BusClk) then
        if bPushEnDly then
          bPushDly <= bPush;
        end if;
      end if;
    end process PushRegister;

    -- DataDelay: -------------------------------------------------------------
    -- This process delays bData by one clock cycle to match a clock cycle
    -- delay introduced in bPush by the PushRegister process.
    ---------------------------------------------------------------------------
    DataDelay : process (BusClk, aBusReset)
    begin
      if aBusReset then
        bDataDly <= Zeros(kDataWidth);
      elsif rising_edge(BusClk) then
        bDataDly <= bData;
     end if;
    end process DataDelay;

    -- BusClkToReliableClkHS: -------------------------------------------------
    -- !CLOCK BOUNDARY CROSSING! This component HS data from the BusClk to the
    -- ReliableClk domain.
    --
    -- Intentionally using oDataValid as oDataAck. This increases the turn
    -- around time from rDataValid to bReady by 1 ReliableClk cycle. This is
    -- required to preclude any race conditions for DiagramReset, and ViControl
    -- registers. Refer to these registers for more information.
    --
    -- !CONSTRAINTS! Constraints should be set on this component. Refer to the
    -- components source code for more information.
    ---------------------------------------------------------------------------
    --vhook_e HandshakeBaseResetCross BusClkToReliableClkHS
    --vhook_a aIReset aBusReset
    --vhook_a aResetToDlyPush open
    --vhook_a aResetToIResetFast open
    --vhook_a aPushToggleDly open
    --vhook_a IClk BusClk
    --vhook_a iPush bPushDly
    --vhook_a iData bDataDly
    --vhook_a iStoredData open
    --vhook_a iReady bHsReady
    --vhook_a iOResetStatus open
    --vhook_a aOReset false
    --vhook_a OClk ReliableClk
    --vhook_a oDataValid rDataValidLoc
    --vhook_a oDataAck rDataValidLoc
    --vhook_a oData rData
    BusClkToReliableClkHS: entity work.HandshakeBaseResetCross (rtl)
      generic map (
        kDataWidth => kDataWidth)
      port map (
        aResetToDlyPush    => open,
        aResetToIResetFast => open,
        aPushToggleDly     => open,
        aIReset            => aBusReset,
        IClk               => BusClk,
        iPush              => bPushDly,
        iData              => bDataDly,
        iStoredData        => open,
        iReady             => bHsReady,
        iOResetStatus      => open,
        aOReset            => false,
        OClk               => ReliableClk,
        oDataValid         => rDataValidLoc,
        oDataAck           => rDataValidLoc,
        oData              => rData);

    -- ReadyProc: -------------------------------------------------------------
    -- Making sure that bReady is de-asserted at the same clock edge as bPush
    -- is observed. Also, bHsReady asserts only when aBusReset de-asserts
    -- synchonously (aReset is Dbl synch. in the HS component). So it is
    -- guaranteed that bReady cannot become metastable after aBusReset
    -- de-asserts.
    ---------------------------------------------------------------------------
    ReadyRegister : process (BusClk, aBusReset)
    begin
      if aBusReset then
        bReadyLoc <= false;
      elsif rising_edge(BusClk) then
        if (bPushEnDly and (bPush or bPushDly)) then
          bReadyLoc <= false;
        elsif not bHsReady then
          bReadyLoc <= false;
        else
          bReadyLoc <= true;
        end if;
      end if;
    end process ReadyRegister;

    bReady <= bReadyLoc;
    rDataValid <= rDataValidLoc;

  end block ClockDomainCrossing;

  --synopsys translate_off
  -- ErrorBlk: ----------------------------------------------------------------
  -- This block contains error detection circuitry.  It checks:
  -- 1). If the user has asserted bPush while bReady is not asserted.
  -- 2). If the user has bPush asserted for more than one clock cycle.
  -----------------------------------------------------------------------------
  ErrorBlk: block
  begin

    assert not ((bPush and not bPushDly) and (not bReadyLoc) and rising_edge(BusClk))
      report "Entity: SafeBusCrossing, Block: ErrorBlk" & LF &
             "bPush asserted while SafeBusCrossing module was not ready."
      severity failure;

    PushCheck: process
    begin
      wait until rising_edge(BusClk);
      if not aBusReset then
        if bPushEn then
          if bPush then
            wait until falling_edge(BusClk);
            wait until falling_edge(BusClk);
            assert (not bPushDly)
              report "Entity: SafeBusCrossing, Process: PushCheck" & LF &
                     "Either bPush did not de-assert after one clock cycle or" & LF &
                     "bPushEn did not stay asserted for at least one clock cycle" &
                     LF & "after bPush de-asserted."
              severity failure;
          end if;
        end if;
      end if;
    end process PushCheck;

  end block ErrorBlk;
  --synopsys translate_on

end architecture rtl;
