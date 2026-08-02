-------------------------------------------------------------------------------
--
-- File: DmaPortCommIfcComponentStateTransitionEnableChain.vhd
-- Author: Matthew Koenn
-- Original Project: LvFPGA CHInCh Interface
-- Date: 16 October 2008
--
-------------------------------------------------------------------------------
-- (c) 2008 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--
--   This is a generic component that handles the diagram issuing a request
-- for a stream state transition, such as a Start, Stop, or Stop With Flush
-- request.  The standard LV FPGA enable chain is used to accomplish this.
-- The enable out will not go true until the desired state has been reached,
-- and no request strobe will be generated if the state is already in the
-- desired state when the enable in asserts.
--
--   The transition request strobe is output in the BusClk domain for use by
-- the DMA controller, as well as in the ViClk domain, since this signal is
-- sometimes used to change a copy of a stream state in this domain.
--
--   The strobe output in the BusClk domain goes through a safe reset
-- handshake and is not in any reset domain.
--
-------------------------------------------------------------------------------


library IEEE;
  use IEEE.std_logic_1164.all;
  use IEEE.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;
  use work.PkgDmaPortCommIfcStreamStates.all;

entity DmaPortCommIfcComponentStateTransitionEnableChain is
  port(

    aReset : in  boolean;

    -- ViClk : The clock from the VI diagram.
    ViClk   : in std_logic;

    -- BusClk : The clock that the communication interface bus is synchronous to.
    BusClk : in std_logic;


    -------------------------------------------------------------------------------------
    -- State Transition signals
    -------------------------------------------------------------------------------------

    -- bTransitionRequestStrobe : This is a one clock cycle strobe indicating when
    --                            a state transition has been requested.
    bTransitionRequestStrobe : out boolean;

    -- bTransitionTimeoutRequestStrobe : This is a one clock cycle strobe indicating when
    --                                   the original transition request has timed out.
    bTransitionTimeoutRequestStrobe : out boolean;

    -- vTransitionRequestStrobe : The transition request strobe in the ViClk domain.
    vTransitionRequestStrobe : out boolean;

    -- vTransitionTimeoutRequestStrobe : The timeout transition request strobe in the
    --                                   ViClk domain.
    vTransitionTimeoutRequestStrobe : out boolean;

    -- vTransitionComplete : This boolean indicates when the conditions for this
    --                       transition to complete successfully have been met.
    vTransitionComplete : in boolean;


    -------------------------------------------------------------------------------------
    -- VI Diagram Enable Chain signals
    -------------------------------------------------------------------------------------

    -- Enable chain signals
    vEnableIn    : in  std_logic;
    vEnableOut   : out std_logic;
    vEnableClear : in  std_logic;

    -- vTimedOut : Indicates to the diagram when a timeout occurs.  This bit is valid
    --             when the EnableOut signal is true.
    vTimedOut    : out std_logic;

    -- vTimeout  : The number of clock cycles to wait before issuing the timeout
    --             request strobe.  A negative value will wait forever.
    vTimeout     : in  signed(31 downto 0)

  );
end DmaPortCommIfcComponentStateTransitionEnableChain;

architecture rtl of DmaPortCommIfcComponentStateTransitionEnableChain  is

  --vhook_sigstart
  signal vHsModuleReady: boolean;
  signal vTimeoutHsModuleReady: boolean;
  --vhook_sigend

  -- Signals used to build a pulse for enable in.
  signal vEnableInDelay, vEnableInPulse : std_logic;

  -- Signals for the enable chain state machine
  type EnableChainState_t is (Idle, WaitForStrobeDeassertion, WaitForTransitionComplete);
  signal vEnableChainState, vEnableChainStateNx : EnableChainState_t;

  signal vSetEnableOut : boolean;
  signal vSetTimeout : boolean;
  signal vTransitionRequestStrobeLcl : boolean;
  signal vTransitionTimeoutRequestStrobeLcl : boolean;
  signal vLatchedTimeout, vLatchedTimeoutNx : signed(31 downto 0);

begin

  -- Create a pulse on the rising_edge of vEnableIn
  EnableInDelayer: process (aReset, ViClk)
  begin
    if aReset then
      vEnableInDelay <= '0';
    elsif rising_edge(ViClk) then
      vEnableInDelay <= vEnableIn;
    end if;
  end process EnableInDelayer;

  vEnableInPulse <= vEnableIn and not vEnableInDelay;
  vTransitionRequestStrobe <= vTransitionRequestStrobeLcl;
  vTransitionTimeoutRequestStrobe <= vTransitionTimeoutRequestStrobeLcl;


  -- Combinatorial logic for the enable chain state machine.
  NextEnableChainState: process (vEnableChainState, vEnableInPulse, vTransitionComplete,
                                 vHsModuleReady, vTimeoutHsModuleReady, vLatchedTimeout,
                                 vTimeout)
  begin

    vEnableChainStateNx <= vEnableChainState;
    vSetEnableOut <= false;
    vTransitionRequestStrobeLcl <= false;
    vTransitionTimeoutRequestStrobeLcl <= false;
    vLatchedTimeoutNx <= vLatchedTimeout;
    vSetTimeout <= false;

    case (vEnableChainState) is

      ---------------------------------------------------------------------------------
      -- Idle:
      --
      -- Wait for the enable in pulse and the transition request status in the BusClk
      -- domain to be false.  It's necessary to wait for the status to be false so
      -- that all transition request strobes are seen in the BusClk domain.
      -- Immediately assert enable out if the transition is already complete.
      ---------------------------------------------------------------------------------
      when Idle =>

        if (vEnableInPulse='1') then
          if vTransitionComplete then
            vSetEnableOut <= true;
          elsif not (vHsModuleReady and vTimeoutHsModuleReady) then
            vEnableChainStateNx <= WaitForStrobeDeassertion;
          else
            vEnableChainStateNx <= WaitForTransitionComplete;
            vTransitionRequestStrobeLcl <= true;
          end if;

          -- Latch the timeout value.
          vLatchedTimeoutNx <= vTimeout;

        end if;

      ---------------------------------------------------------------------------------
      -- WaitForStrobeDeassertion:
      --
      -- Wait for the status of the state transition strobe to go false so that the
      -- next strobe is guaranteed to be seen in the BusClk domain.
      ---------------------------------------------------------------------------------
      when WaitForStrobeDeassertion =>

        if vTransitionComplete then
          vEnableChainStateNx <= Idle;
          vSetEnableOut <= true;
        elsif vHsModuleReady and vTimeoutHsModuleReady then
          vEnableChainStateNx <= WaitForTransitionComplete;
          vTransitionRequestStrobeLcl <= true;
        end if;

      ---------------------------------------------------------------------------------
      -- WaitForTransitionComplete:
      --
      -- Wait until the requested state transition has occurred before strobing the
      -- enable out.
      ---------------------------------------------------------------------------------
      when WaitForTransitionComplete =>

        -- We don't move out of the WaitForTransitionComplete state until the desired
        -- state has been reached.
        if vTransitionComplete then
          vEnableChainStateNx <= Idle;
          vSetEnableOut <= true;

        -- Decrement the timeout counter while we haven't reached the desired state.
        -- Make sure not to use the timeout counter for negative values, since
        -- negative values mean wait forever.
        elsif vLatchedTimeout > 0 then
          vLatchedTimeoutNx <= vLatchedTimeout - 1;

        -- If this is a "Flush and Disable", we will try to flush for the specified
        -- timeout period.  When the timeout period has expired, we want to assert
        -- the disable request, which will be the bTransitionTimeoutRequestStrobe.
        -- We set this strobe when the timeout occurs, but we still hang in the
        -- WaitForTransitionComplete state until the stream is Disabled.  Timeout
        -- only applies for a "Flush and Disable" method.
        elsif vLatchedTimeout = 0 then
          vSetTimeout <= true;
          vTransitionTimeoutRequestStrobeLcl <= true;

        end if;

      when others =>

        vEnableChainStateNx <= Idle;

    end case;
  end process;

  StateMachineRegs: process(aReset, ViClk)
  begin

    if aReset then
      vEnableChainState <= Idle;
      vLatchedTimeout <= (others=>'0');
    elsif rising_edge(ViClk) then
      vEnableChainState <= vEnableChainStateNx;
      vLatchedTimeout <= vLatchedTimeoutNx;
    end if;

  end process StateMachineRegs;


  -- Logic for the enable out and timed out registers.
  OutputRegs: process (aReset, ViClk)
  begin

    if aReset then
      vEnableOut <= '0';
      vTimedOut <= '0';
    elsif rising_edge(ViClk) then

      -- Clear the enable out whenever the enable clear signal is strobed.
      if vEnableClear='1' then
        vEnableOut <= '0';

      -- Set the enable out whenever the state machine indicates that the desired state
      -- has been reached.
      elsif vSetEnableOut then
        vEnableOut <= '1';
      end if;

      -- Clear the time out whenever the enable clear signal is strobed.
      if vEnableClear = '1' then
        vTimedOut <= '0';

      -- Set the time out when the transition times out.
      elsif vSetTimeout then
        vTimedOut <= '1';
      end if;

    end if;

  end process OutputRegs;


  -- Generate the transition request strobes in the BusClk domain.

  -- This handshake requires the safe reset handshake because the request signal
  -- goes from the asynchronous diagram reset domain to the synchronous bus reset
  -- domain.

  --vhook_e HandshakeBaseResetCross HandshakeTransitionRequest
  --vhook_a kDataWidth 2
  --vhook_a aResetToDlyPush open
  --vhook_a aResetToIResetFast open
  --vhook_a aPushToggleDly open
  --vhook_a aIReset aReset
  --vhook_a IClk ViClk
  --vhook_a iPush vTransitionRequestStrobeLcl
  --vhook_a iData open
  --vhook_a iStoredData open
  --vhook_a iReady vHsModuleReady
  --vhook_a iOResetStatus open
  --vhook_a aOReset false
  --vhook_a OClk BusClk
  --vhook_a oDataValid bTransitionRequestStrobe
  --vhook_a oDataAck true
  --vhook_a oData open
  HandshakeTransitionRequest: entity work.HandshakeBaseResetCross (rtl)
    generic map (
      kDataWidth => 2)  -- in  integer := 1
    port map (
      aResetToDlyPush    => open,                         -- in  integer := 0
      aResetToIResetFast => open,                         -- in  integer := 0
      aPushToggleDly     => open,                         -- in  integer := 0
      aIReset            => aReset,                       -- in  boolean
      IClk               => ViClk,                        -- in  std_logic
      iPush              => vTransitionRequestStrobeLcl,  -- in  boolean
      iData              => open,                         -- in  std_logic_vector(kDataWi
      iStoredData        => open,                         -- out std_logic_vector(kDataWi
      iReady             => vHsModuleReady,               -- out boolean := false
      iOResetStatus      => open,                         -- out boolean := false
      aOReset            => false,                        -- in  boolean
      OClk               => BusClk,                       -- in  std_logic
      oDataValid         => bTransitionRequestStrobe,     -- out boolean := false
      oDataAck           => true,                         -- in  boolean := true
      oData              => open);                        -- out std_logic_vector(kDataWi


  -- This handshake requires the safe reset handshake because the request signal
  -- goes from the asynchronous diagram reset domain to the synchronous bus reset
  -- domain.

  --vhook_e HandshakeBaseResetCross HandshakeTransitionTimeoutRequest
  --vhook_a kDataWidth 2
  --vhook_a aResetToDlyPush open
  --vhook_a aResetToIResetFast open
  --vhook_a aPushToggleDly open
  --vhook_a aIReset aReset
  --vhook_a IClk ViClk
  --vhook_a iPush vTransitionTimeoutRequestStrobeLcl
  --vhook_a iData open
  --vhook_a iStoredData open
  --vhook_a iReady vTimeoutHsModuleReady
  --vhook_a iOResetStatus open
  --vhook_a aOReset false
  --vhook_a OClk BusClk
  --vhook_a oDataValid bTransitionTimeoutRequestStrobe
  --vhook_a oDataAck true
  --vhook_a oData open
  HandshakeTransitionTimeoutRequest: entity work.HandshakeBaseResetCross (rtl)
    generic map (
      kDataWidth => 2)  -- in  integer := 1
    port map (
      aResetToDlyPush    => open,                                -- in  integer := 0
      aResetToIResetFast => open,                                -- in  integer := 0
      aPushToggleDly     => open,                                -- in  integer := 0
      aIReset            => aReset,                              -- in  boolean
      IClk               => ViClk,                               -- in  std_logic
      iPush              => vTransitionTimeoutRequestStrobeLcl,  -- in  boolean
      iData              => open,                                -- in  std_logic_vector(
      iStoredData        => open,                                -- out std_logic_vector(
      iReady             => vTimeoutHsModuleReady,               -- out boolean := false
      iOResetStatus      => open,                                -- out boolean := false
      aOReset            => false,                               -- in  boolean
      OClk               => BusClk,                              -- in  std_logic
      oDataValid         => bTransitionTimeoutRequestStrobe,     -- out boolean := false
      oDataAck           => true,                                -- in  boolean := true
      oData              => open);                               -- out std_logic_vector(


end rtl;
