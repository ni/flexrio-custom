-------------------------------------------------------------------------------
--
-- File: DiagramReset.vhd
-- Author: Asrar Rangwala
-- Original Project: Improving FPGA Diagram Reset Scheme
-- Date: 7 March 2008
--
-------------------------------------------------------------------------------
-- (c) 2008 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--   This component houses the Diagram reset regsiter, and logic for the
--   diagram reset state machine. Asserting diagram reset starts the
--   diagram reset state machine which makes sure that all the FPGA base clocks
--   and derived clocks are valid. The state machine also guarantees minimum
--   reset assertion duration for components that have such requirements. For
--   detailed theory of operation, refer to the state machine comments.
--
--   It also uses the SafeBusCrossing component to protect the diagram reset
--   register from unreliable bus behavior during host warm-reboot.
--
--   To preclude asynchronous reset crossings to/from this component over the
--   BusClk ports: Drive the aBusReset port only if the BusClk port accessor
--   (RegisterAccess component in the CommunicationInterface) is also using
--   the same reset.
--
-- Registers:
--   Diagram Reset : (Bit: 0 R/W) Setting this register resets the FPGA VI. It
--                   can be asserted by the host. It is also asserted by the
--                   FPGA only after bitstream download. It can only be
--                   de-asserted by the FPGA.
-- Timing:
--   The following analysis will prove that after a host write access, host
--   reads fetch the hardware value, thus getting rid of any race conditions on
--   reads after writes.
--
--   Path 1: After DataValid(SafeBusCrossing) asserts, it takes 5-6 BusClk
--   + 1 ReliableClk cycles for IoReady(RegisterAccess) to be asserted:
--     * 4-5 BusClk + 1 ReliableClk by SafeBusCrossing Component
--     * 1 BusClk by RegisterAccess Component.
--
--   Path 2: After DataValid(SafeBusCrossing) asserts, it takes 2-3 BusClk
--   + 1 ReliableClk cycles for bDiagramResetForHost to be updated:
--     * 1 ReliableClk by the DiagramReset state machine.
--     * 2-3 BusClks by the DiagRstForHostInBusClk process.
--
--   Fastest path 1: 5BusClk+1ReliableClk
--   Slowest path 2: 3BusClk+1ReliableClk
--
--   Difference: 2BusClk cycles. Some FFs may have positive hold
--   times, and so being more conservative, we are left with a wiggle room of
--   1BusClk cycle on the host read path (path 2). This is set as a
--   constraint on the Dbl Synch on the host read path, thus making path 1, and
--   2 equal in the worst case. Q.E.D. (Latin for "Hence Proved" :)
--
-- Constraints:
--   To guarantee correct operation, constraints must be placed on this
--   component. Refer to "!CONSTRAINT!" in the code for more info.
--
-- Generics:
--   kDiagramResetMaxFanout :    This indicates the maximum fanout no. for the
--                               rDiagramReset signal, and it's target specific.
--
--   kDiagRstAssertionDuration : This is the minimum duration (specified as the
--                               no. of ReliableClk cycles) for which the
--                               rDiagramReset signal should remain asserted
--                               once all the clocks are valid and free-running.
--                               Its value is determined dynamically during code
--                               generation by considering the maximum reset
--                               assertion time requested by all the components.
--                               A value of '0' indicates that reset assertion
--                               duration was not requested.
--
--   kDiagRstDeAsrtPropDlyWait : This is the worst case propagation delay for
--                               diagram reset deassertion (specified as the
--                               no. of ReliableClk cycles). Its value was
--                               chosen to be large enough to meet the needs of
--                               all the current, and possible future FPGA
--                               devices. It's set to be equivalent to 1us.
--
--   kAllowEnableRemoval :  This boolean indicates whether enable chain removal
--                          optimization was selected in the build specification or not. 
--
-- Ports:
--   aBusReset :             This is the asynchronous bus reset.
--
--   BusClk :                This is the bus clock.
--
--   bIoWtToEnSafeBusCrossing:This is the Io Write strobe from the Bus. Ideally
--                           it should be connected directly to the I/O pin or
--                           an IOB register. It is imp that it is asserted one
--                           clock cycle before bHostWriteIn(0) asserts. Also,
--                           this signal may be asserted for any arbitrary
--                           no. of clock cycles. This signal is only used to
--                           enable the safebuscrossing component.
--
--   bHostReadIn :           Bit 0 - This is a single cycle pulse indicating
--                           host read access to the diagram reset register.
--                           Bit 1 - Unused.
--
--   bHostReadOut :          Bit 0 - This is a single cycle pulse indicating
--                           data valid for host read access.
--                           Bit 1 to 32 - This is the Diagram Reset register.
--                           This output is NOT registered.
--
--   bHostWriteIn :          Bit 0 - This is a single cycle pulse indicating
--                           host write access to the diagram reset register.
--                           Bit 1 - Unused.
--                           Bit 2 to 33 - This is the Diagram reset Register.
--
--   bHostWriteOut :         Bit 0 - This is the Ready signal. It is de-
--                           asserted a clock cycle after bHostWriteIn(0)
--                           asserts. It is asserted back at the completion of
--                           host write access. This output is registered.
--
--   ReliableClk :           This is a raw clock generated straight from an
--                           on-board oscillator. It is considered glitch-free.
--
--   rDiagramReset :         This is the diagram reset signal that resets the
--                           diagram components. This signal is initilized to '1'
--                           on device startup. This signal should only be used 
--                           to reset components synchronously wrt the 
--                           ReliableClk domain, otherwise that could lead to 
--                           timing failures on Spartan/Virtex 6 and later devices.
--                           Instead, aDiagramReset should be used to reset components
--                           asynchronously. This output is registered.
--
--   aDiagramReset :         Identical to rDiagramReset. This signal should be used
--                           as an asynchronous reset only even though it is being 
--                           produced in the ReliableClk domain. This is because a 
--                           TIG constraint is placed on this reset net and the 
--                           tools can no longer treat it synchronous to the 
--                           ReliableClk domain. This was required to pre-empt 
--                           Xilinx tools from analyzing timing on the asynchronous 
--                           reset net on Spartan/Virtex6 and later devices.
--
--   rDiagramResetStatus :   This indicates the status of diagram reset signal.
--                           It asserts  in the same cycle as rDiagramReset.
--                           It de-asserts kDiagRstDeAsrtPropDlyWait cycles
--                           after rDiagramReset de-asserts. This output is
--                           registered.
--
--   rDerivedClksValid :     This should be asserted to indicate that all the
--                           FPGA derived clocks are valid, and good for use.
--                           This port will be sampled one ReliableClk cycle after
--                           rDcmPllSourceClksValid asserts. Ideally, it should be
--                           driven by the logical AND of Locked output from
--                           all the internal DCM/PLLs that run off the FPGA
--                           base clocks. Locked output from the Xilinx DCM/PLL
--                           are known to be un-reliable a few CC after DCM/PLL
--                           reset/ configuration , and so it is imperative for
--                           this port to be driven from a valid source. Also,
--                           it is assumed that this port will be asserted
--                           within 10ms of rDcmPllSourceClksValid asserting,
--                           otherwise the software will timeout. It is
--                           assumed that this signal is not reset asynchronously.
--
--   rBaseClksValid :        This should be asserted to indicate that all the
--                           FPGA base clocks are valid, and good for use. Its
--                           functionality may also be overloaded to indicate
--                           that all the external circuitry is ready which is
--                           important before the FPGA VI could begin execution.
--                           This port will be sampled two ReliableClk cycles
--                           after rDiagramReset asserts. Also, it is assumed
--                           that this port will be asserted within 10ms of
--                           rDiagramReset asserting, otherwise the software
--                           will timeout. It is assumed that this signal is
--                           not reset asynchronously.
--
--   rGatedBaseClksValid :   This signal should be asserted to indicate that 
--                           the gated FPGA base clocks are valid.
--
--   rSafeToEnableGatedClks : 
--                           This signal should be asserted to indicate that it
--                           is safe to enable gated clocks.
--
--   rDcmPllSourceClksValid :
--                           This stays de-asserted until the base clocks are
--                           valid. Internal DCM/PLL should start the locking
--                           process on assertion of this signal. This
--                           output is registered.
--
--   rInternalClksValid :    This signal should be asserted to indicate that all
--                           base and derived clocks (excluding external clocks)
--                           are running. It is checked by the ViControl EnableIn FSM
--                           before asserting the enable in for the VI.
--
--   rEnableClksForViRun :   This signal should be asserted to request the gated
--                           base and derived clocks to start running. It is controlled
--                           from the ViControl.
--                           Note: this signal is used only when 'kAllowEnableRemoval' is true.
--
--   rAssumeExternalClkInvalid : The assertion of this signal indicates that external clocks
--                               should be considered as invalid. This signal is used by the derived
--                               clock control logic to turn off derived clocks from external clocks
--                               when it is asserted. 
--                               The signal is asserted after the user calls the Reset method, but before
--                               asserting the diagram reset. When diagram reset asserts, the FAM power cycles,
--                               so we need to make sure derived clocks are turned off by that time.
--
--   rDerivedFromExternalValid : This signal indicates whether derived clocks from external clocks are valid
--                               or not. If the signal is deasserted, it indicates that derived clocks are shut down.
--                               This signal should be checked before asserting diagram reset - it's not safe
--                               to assert diagram reset while derived clocks from external clocks are running.
--
--   rDiagramResetAssertionErr : 
--                           This signal indicates an error if Diagram Reset was 
--                           requested by host when the VI was built with enable removal 
--                           optimization allowed - in this case Diagram Reset assertion
--                           is not supported.
-------------------------------------------------------------------------------

--StaticVHDL Component

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library UNISIM;
  use UNISIM.vcomponents.all;

library work;
  use work.PkgNiUtilities.all;
  use work.PkgFpgaDeviceSpecs.all;

entity DiagramReset is
  generic (
    kDiagramResetMaxFanout : integer := 100000000;
    kDiagRstAssertionDuration : natural := 0;
    kDiagRstDeAsrtPropDlyWait : natural := 40;
    kAllowEnableRemoval : boolean := false;
    kHostReadWidthIn : positive range 2 to 2 := 2;
    kHostReadWidthOut : positive range 9 to 33 := 33;
    kHostWriteWidthIn : positive range 10 to 34 := 34;
    kHostWriteWidthOut : positive range 1 to 1 := 1
  );
  port (
    aBusReset : in boolean;

    BusClk : in std_logic;
    bIoWtToEnSafeBusCrossing : in boolean;
    bHostReadIn : in std_logic_vector(kHostReadWidthIn-1 downto 0);
    bHostReadOut : out std_logic_vector(kHostReadWidthOut-1 downto 0);
    bHostWriteIn : in std_logic_vector(kHostWriteWidthIn-1 downto 0);
    bHostWriteOut : out std_logic_vector(kHostWriteWidthOut-1 downto 0);

    ReliableClk : in std_logic;
    rDerivedClksValid : in boolean;
    rBaseClksValid : in boolean;
    rGatedBaseClksValid : in boolean;
    rEnableClksForViRun : in boolean;
    rDiagramReset : out std_logic;
    aDiagramReset : out std_logic;
    rDiagramResetStatus : out std_logic;
    rSafeToEnableGatedClks : out std_logic;
    rDcmPllSourceClksValid : out std_logic;
    rInternalClksValid : out std_logic;
    rAssumeExternalClkInvalid : out std_logic;
    rDerivedFromExternalValid : in boolean;
    rDiagramResetAssertionErr : out std_logic
  );

  -- These attributes are specific to XST. Without this, constrained
  -- registers can be combined with other registers and be lost,
  -- invalidating the constraint.
  --attribute equivalent_register_removal : string;
  --attribute equivalent_register_removal of DiagramReset : entity is "no";

  -- Vivado:
  -- The above attribute was inherited from ISE. For details on why we needed
  -- this attribute, please look at CAR#465983.
  -- For Vivado, the equivalent_register_removal attribute is not supported.

end entity DiagramReset;

architecture rtl of DiagramReset is

  --vhook_sigstart
  signal bPush: boolean;
  signal bReady: boolean;
  --vhook_sigend

  -----------------------------------------------------------------------------
  -- These signals are shared between blocks.
  -----------------------------------------------------------------------------
  signal rDiagramResetNx : std_logic;
  signal rDiagramResetForHostAssert, rDiagramResetForHostDeAssert : boolean;
  signal rStartFsmByHostPulse1 : boolean;
  signal bHostWritePulse, bHostReadPulse : boolean;
  signal bHostWriteData : std_logic;
  signal bHostReadData : std_logic_vector(31 downto 0);

  -- Diagram reset signals for host access. These signals are initialized to
  -- '1' so that if the host performs a read right after download, it is
  -- observed as asserted. Otherwise it may take upto 3ReliableClk + 2BusClk
  -- cycles for bDiagramResetForHost to be asserted after download.
  signal bDiagramResetForHost, bDiagramResetForHost_ms,
         rDiagramResetForHost : std_logic := '1';
  -- !CONSTRAINT! -------------------------------------------------------------
  -- There are FROM TO constraints placed on nets driven by these flops.
  -- Using keep to make sure the net name is immune to synthesis re-naming.
  -----------------------------------------------------------------------------
    attribute keep : string;
    attribute keep of rDiagramResetForHost : signal is "true"; 
    attribute keep of rDiagramResetAssertionErr : signal is "true";

    attribute ASYNC_REG : string;
    attribute ASYNC_REG of bDiagramResetForHost_ms,bDiagramResetForHost: signal is "true";

  -----------------------------------------------------------------------------
  -- Location of DiagramReset bit in the DiagramReset register
  -----------------------------------------------------------------------------
  constant kDiagramResetBit : integer := 0;

  -- LargestTimerCount: -------------------------------------------------------
  -- This function returns the largest timer count from all the timer duration
  -- generics.
  -----------------------------------------------------------------------------
  function LargestTimerCount return integer is
  begin
    return Larger(kDiagRstDeAsrtPropDlyWait, kDiagRstAssertionDuration);
  end LargestTimerCount;

begin

  -- HostWtAccessBlk: ---------------------------------------------------------
  -- This Block contains logic for host wt access to the DiagramReset register.
  -- Host Access to this  Register is controlled through the bushold,
  -- and the RegisterAccess components.
  -----------------------------------------------------------------------------
  HostWtAccessBlk : block
  begin

    ---------------------------------------------------------------------------
    -- Flatten/Unflatten the Host Write port
    ---------------------------------------------------------------------------
    -- The host write access issued from the Bushold is a single cycle pulse.
    -- This is asserted at the same clock edge as bPushEn for the
    -- SafeBusCrossing component.
    bHostWritePulse <= to_Boolean(bHostWriteIn(0));
    -- Bits 2 to 33 is DiagramReset register data.
    bHostWriteData <= bHostWriteIn (kDiagramResetBit + 2);

    -- Host can only assert the DiagramReset register.
    bPush <= bHostWritePulse when bHostWriteData = '1' else false;

  -- BusClkToReliableClkHS: -------------------------------------------------
  -- !CLOCK BOUNDARY CROSSING! This component provides safe data HS from
  -- busClk to ReliableClk. Since, only diagram reset assertion requests
  -- from the host are entertained, we are using data valid signal as the
  -- only qualifier, which starts the diagram reset state machine.
  --
  -- !CONSTRAINTS! Constraints should be set on this component. Refer to the
  -- component for more information.
  ---------------------------------------------------------------------------
  --vhook_e SafeBusCrossing BusClkToReliableClkHS
  --vhook_a kDataWidth 1
  --vhook_a bPushEn bIoWtToEnSafeBusCrossing
  --vhook_a bData open
  --vhook_a rData open
  --vhook_a rDataValid rStartFsmByHostPulse1
  BusClkToReliableClkHS: entity work.SafeBusCrossing (rtl)
    generic map (
      kDataWidth => 1)
    port map (
      aBusReset   => aBusReset,
      BusClk      => BusClk,
      bPush       => bPush,
      bPushEn     => bIoWtToEnSafeBusCrossing,
      bData       => open,
      bReady      => bReady,
      ReliableClk => ReliableClk,
      rData       => open,
      rDataValid  => rStartFsmByHostPulse1);

    -- Wire Ready from SafeBusCrossing component back to the Bushold.
    bHostWriteOut(0) <= to_StdLogic(bReady);

  end block HostWtAccessBlk;

  -- DiagramResetFSM:----------------------------------------------------------
  -- This block contains logic for the diagram reset state machine, and
  -- registers for some outputs of the state machine.
  -----------------------------------------------------------------------------
  DiagramResetFSM : block

    type DiagramResetState_t is (

    -- Idle:                        Wait for the state machine to start 
    --                              automatically a couple of cycles after 
    --                              configuration. On transition to the next 
    --                              state, DiagramReset (read by host and FPGA),
    --                              and internal DCM PLL reset signals are
    --                              asserted.
    --                              This state is identical to 
    --                              WaitForHostToAssertDiagRst state, except, 
    --                              rDiagramResetNx is kept asserted in this 
    --                              state and it is kept de-asserted in the other
    --                              state.
    Idle,
    --
    -- WaitForExternalCircuitToInit:Wait for all the externally placed (in the
    --                              toplevel) circuitry (PLL, etc.) to initialize
    --                              by waiting one clock cycle after the assertion
    --                              of diagram reset, and then transition to
    --                              WaitForBaseClksToBecomeValid.
    WaitForExternalCircuitToInit,
    --
    -- WaitForBaseClksToBecomeValid:Wait for an assertion on the rBaseClksValid
    --                              port. All the non-gated FPGA base clocks are
    --                              stable before moving to the next state.
    WaitForBaseClksToBecomeValid,
    --
    -- WaitForClkEnableRequest : Wait until ViControl requests the gated clocks to be
    --                           enabled. 
    -- 
    WaitForClkEnableRequest,
    --
    -- WaitForGatedBaseClksToBecomeValid:Wait for assertion of the rGatedBaseClksValid
    --                               port. All the gated FPGA base clocks are enabled
    --                               and stable before moving to the next state.
    --                               On transition to the next state, reset for
    --                              internal DCM/PLL is de-asserted.
    WaitForGatedBaseClksToBecomeValid,
    --
    -- WaitForDervClksToBecomeValid:Wait for an assertion on the
    --                              rDerivedClksValid port. All the derived
    --                              clocks are stable before moving to the next
    --                              state.
    WaitForDervClksToBecomeValid,
    --
    -- WaitForResetAssertionDuration:Wait until the minimum reset assertion
    --                              duration has expired. On transition to the
    --                              next state, diagram reset signal
    --                              is de-asserted.
    WaitForResetAssertionDuration,
    --
    -- WaitForDiagRstDeAsrtPropDly: Wait for diagram reset de-assertion prop
    --                              delay. On transition to 
    --                              WaitForHostToAssertDiagRst, diagram reset
    --                              (read by the host) signal is de-asserted.
    WaitForDiagRstDeAsrtPropDly,
    --
    -- WaitForHostToAssertDiagRst: Wait for the host to assert diagram reset.
    --                             This state is identical to Idle state,
    --                             except, rDiagramResetNx is kept de-asserted 
    --                             in this state whereas it is kept asserted
    --                             in Idle.
    --                             If host requests diagram reset and enable removal
    --                             optimization is allowed, go to DiagRstAssertionNotSupportedErr.
    --                             If enable removal optimization is not allowed then
    --                             go to the WaitUntilDerivedFromExternalShutDown state.
    WaitForHostToAssertDiagRst,
    --
    -- WaitUntilDerivedFromExternalShutDown: 
    --                            Wait until derived clocks from external clocks
    --                            are turned off. 'rDiagramResetNx' is kept deasserted until
    --                            derived clocks are turned off. This is required because the FAM
    --                            power cycles when reset is asserted and the external clock
    --                            immediately goes away.
    WaitUntilDerivedFromExternalShutDown,
    --
    -- DiagRstAssertionNotSupportedErr : This is an error state.
    --                                   Assert 'DiagramResetAssertionErr' output.
    DiagRstAssertionNotSupportedErr
    );

    -- Diagram reset state signals
    signal rDiagramResetState, rDiagramResetStateNx : DiagramResetState_t := Idle;

    -- Diagram Reset FSM start on download signals
    signal rStartFsmOnDld, rStartFsmOnDldDly, rStartFsmOnDldPulse1,
           rStartFsmOnDld_ms : boolean := false;

    -- Timer signals
    signal rTimerSet, rTimerExpired : boolean;
    signal rTimerSetCount : natural range 0 to LargestTimerCount;
    signal rTimerCount : natural range 0 to LargestTimerCount := 0;

    -- Internal DCM/PLL Source clock signals
    signal rDcmPllSourceClksValidAssert, rDcmPllSourceClksValidDeAssert : boolean;
    -- This signal is initialized to false on device startup.
    signal rDcmPllSourceClksValidLoc : std_logic := '0';
    -- 
    signal rSafeToEnableGatedClksAssert, rSafeToEnableGatedClksDeAssert : boolean;
    --
    signal rSafeToEnableGatedClksLoc : std_logic := to_stdlogic(not(kAllowEnableRemoval));

    signal rInternalClksValidAssert, rInternalClksValidDeassert : boolean;
    signal rInternalClksValidLoc : boolean := false;

    signal rDiagramResetAssertionErrNx : boolean := false;
    signal rDiagramResetAssertionErrLoc : boolean := false;

    signal rAssumeExternalClkInvalidNx : boolean := false; 
    signal rAssumeExternalClkInvalidLoc : boolean := false; 

    -- The keep and async_reg attributes prevent the Vivado tools from inferring SRLs
    -- on the following signals. We don't want SRLs to be inferred because GSR may
    -- corrupt the initial value of an SRL.
    -- For details, please check: //labview/docs/web/docs/proposals/2014/
    --  FPGA/XilinxVivadoSupport_HW/V&V/SRL/initial-value-problem-with-xilinx-srls.pdf
    attribute keep : string;
    attribute keep of rStartFsmOnDldDly : signal is "true";
    attribute ASYNC_REG of rStartFsmOnDld_ms,rStartFsmOnDld: signal is "true";

    attribute keep of rSafeToEnableGatedClksLoc : signal is "true";

  begin

    -- StartFsmOnDownloadPrc: -------------------------------------------------
    -- This process double Sync. "true" to ReliableClk domain to remove
    -- any metastability after bitstream download. The doubleSync signal is
    -- used to create a pulse to start the diagram reset FSM.
    ---------------------------------------------------------------------------
    StartFsmOnDownloadPrc : process (ReliableClk)
    begin
      if rising_edge(ReliableClk) then
        rStartFsmOnDld_ms <= true;
        rStartFsmOnDld <= rStartFsmOnDld_ms;
        rStartFsmOnDldDly <= rStartFsmOnDld;
      end if;
    end process StartFsmOnDownloadPrc;

    -- This creates a single cycle pulse on download to start the state machine
    rStartFsmOnDldPulse1 <= rStartFsmOnDld and not rStartFsmOnDldDly;

    -- DiagramResetStateReg: --------------------------------------------------
    -- This process registers the next state signal for the diagram reset
    -- state machine.
    ---------------------------------------------------------------------------
    DiagramResetStateReg : process (ReliableClk)
    begin
      if rising_edge(ReliableClk) then
        rDiagramResetState <= rDiagramResetStateNx;
      end if;
    end process DiagramResetStateReg;

    -- DiagramResetNxStatePrc: ------------------------------------------------
    -- This is the next state process for the diagram reset state machine.
    -- For FSM theory of operation, refer to the state signal declaration.
    --
    -- !STATE MACHINE STARTUP! This state machine cannot start immediately
    -- after download. rStartFsmOnDldPulse1 is asserted 2 clock cycles
    -- after download. rStartFsmByHostPulse1 can only assert after the first
    -- diagram reset cycle. Thus, the FSM is safe.
    ---------------------------------------------------------------------------
    DiagramResetNxStatePrc : process (rDiagramResetState, rStartFsmOnDldPulse1,
                                      rStartFsmByHostPulse1, rTimerExpired,
                                      rBaseClksValid, rDerivedClksValid, rGatedBaseClksValid, 
                                      rEnableClksForViRun, rDerivedFromExternalValid)
    begin
      -- Default signal assign. This ensures that a latch isn't inferred on any
      -- signal.
      rDiagramResetStateNx <= rDiagramResetState;
      rTimerSet <= false;
      rTimerSetCount <= 0;
      rDiagramResetNx <= '1';
      rDcmPllSourceClksValidAssert <= false;
      rDcmPllSourceClksValidDeAssert <= false;
      rDiagramResetForHostAssert <= false;
      rDiagramResetForHostDeAssert <= false;
      rSafeToEnableGatedClksAssert <= false;
      rSafeToEnableGatedClksDeAssert <= false;
      rInternalClksValidAssert <= false;
      rInternalClksValidDeassert <= false;
      rDiagramResetAssertionErrNx <= false;
      rAssumeExternalClkInvalidNx <= false;

      case rDiagramResetState is
        when Idle =>

          if rStartFsmOnDldPulse1 then
            -- State Change
            rDiagramResetStateNx <= WaitForExternalCircuitToInit;
            -- Output Signals
            rDiagramResetForHostAssert <= true;
            rDcmPllSourceClksValidDeAssert <= true;
          end if;

        when WaitForExternalCircuitToInit =>

          -- State Change
          rDiagramResetStateNx <= WaitForBaseClksToBecomeValid;

        when WaitForBaseClksToBecomeValid =>

          if rBaseClksValid then
            --State Change
            if kAllowEnableRemoval then
              rDiagramResetStateNx <= WaitForResetAssertionDuration;
              -- Output Signals
              rTimerSet <= true;
              rTimerSetCount <= kDiagRstAssertionDuration;
            else
              rDiagramResetStateNx <= WaitForGatedBaseClksToBecomeValid;    
            end if;
          end if;

        when WaitForDervClksToBecomeValid =>

          -- If enable removal build-spec option is set, diagram reset
          -- is already deasserted in this state.
          if kAllowEnableRemoval then
            rDiagramResetNx <= '0';
          else
            rDiagramResetNx <= '1';
          end if;

          if rDerivedClksValid then
            if kAllowEnableRemoval then
              -- State Change
              rDiagramResetStateNx <= WaitForHostToAssertDiagRst;
              -- Output Signals
              rDiagramResetForHostDeAssert <= true;
              rInternalClksValidAssert <= true;
            else
              -- State Change
              rDiagramResetStateNx <= WaitForResetAssertionDuration;
              -- Output Signals
              rTimerSet <= true;
              rTimerSetCount <= kDiagRstAssertionDuration;
            end if;
          end if;

        when WaitForResetAssertionDuration =>

          if rTimerExpired then
            -- State Change
            rDiagramResetStateNx <= WaitForDiagRstDeAsrtPropDly;
            -- Output Signals
            rDiagramResetNx <= '0';
            rTimerSet <= true;
            rTimerSetCount <= kDiagRstDeAsrtPropDlyWait;
          end if;

        when WaitForDiagRstDeAsrtPropDly =>

          rDiagramResetNx <= '0';
          if rTimerExpired then     
            -- State Change          
            if kAllowEnableRemoval then
              rDiagramResetStateNx <= WaitForClkEnableRequest;
            else
              rDiagramResetStateNx <= WaitForHostToAssertDiagRst;
            end if;
            -- Output Signals
            rDiagramResetForHostDeAssert <= true;
          end if;

        when WaitForClkEnableRequest =>

          rDiagramResetNx <= '0';
          if rEnableClksForViRun then
            rDiagramResetStateNx <= WaitForGatedBaseClksToBecomeValid;
            -- Output Signals
            rSafeToEnableGatedClksAssert <= true;
          end if;

        when WaitForGatedBaseClksToBecomeValid =>

          if kAllowEnableRemoval then
            rDiagramResetNx <= '0';
          else
            rDiagramResetNx <= '1';
          end if;
          if rGatedBaseClksValid then
            rDiagramResetStateNx <= WaitForDervClksToBecomeValid;
            --Output Signals
            rDcmPllSourceClksValidAssert <= true;
          end if;

        when WaitForHostToAssertDiagRst =>

          rDiagramResetNx <= '0';
          if rStartFsmByHostPulse1 then
            -- State Change & Output signals
            if kAllowEnableRemoval then
              rDiagramResetStateNx <= DiagRstAssertionNotSupportedErr;
              rDiagramResetAssertionErrNx <= true;
            else
              rDiagramResetStateNx <= WaitUntilDerivedFromExternalShutDown;
              rAssumeExternalClkInvalidNx <= true;
            end if;
            rDiagramResetForHostAssert <= true;
          end if;

        when WaitUntilDerivedFromExternalShutDown =>
          rDiagramResetNx <= '0';
          rAssumeExternalClkInvalidNx <= true;
          if not rDerivedFromExternalValid then
            rDiagramResetStateNx <= WaitForExternalCircuitToInit;
            rDiagramResetNx <= '1';
            rDcmPllSourceClksValidDeAssert <= true;
          end if;

        when DiagRstAssertionNotSupportedErr =>
          rDiagramResetAssertionErrNx <= true;

        when others =>
          rDiagramResetStateNx <= Idle;
      end case;
    end process DiagramResetNxStatePrc;

    -- Timerprc: --------------------------------------------------------------
    -- This process instantiates the timer used in the diagram reset cycle.
    --
    -- !COUNTER STARTUP! The counter cannot transition right after bitstream
    -- download, as it starts operating only when the FSM is out of the
    -- "Idle" state which takes place 3 ReliableClk cycles after download.
    ---------------------------------------------------------------------------
    Timerprc : process (ReliableClk)
    begin
      if rising_edge(ReliableClk) then
        if rTimerSet then
          rTimerCount <= rTimerSetCount;
        elsif (rTimerCount /= 0) then
          rTimerCount <= rTimerCount - 1;
        end if;
      end if;
    end process TimerPrc;

    -- This indicates if the timer has expired.
    rTimerExpired <= true when rTimerCount = 0 else false;

    -- DcmPllSourceClksValidReg: ----------------------------------------------
    -- This process registers the rDcmPllSourceClksValid signal.
    ---------------------------------------------------------------------------
    DcmPllSourceClksValidReg : process (ReliableClk)
    begin
      if rising_edge(ReliableClk) then
        if rDcmPllSourceClksValidAssert then
          rDcmPllSourceClksValidLoc <= '1';
        elsif rDcmPllSourceClksValidDeAssert then
          rDcmPllSourceClksValidLoc <= '0';
        end if;
      end if;
    end process DcmPllSourceClksValidReg;

    rDcmPllSourceClksValid <= rDcmPllSourceClksValidLoc;

    -- AssumeExternalClkInvalidReg: ----------------------------------------------
    -- This process registers the rAssumeExternalClkInvalid signal.
    ---------------------------------------------------------------------------
    AssumeExternalClkInvalidReg : process (ReliableClk)
    begin
      if rising_edge(ReliableClk) then
        rAssumeExternalClkInvalidLoc <= rAssumeExternalClkInvalidNx;
      end if;
    end process AssumeExternalClkInvalidReg;
    rAssumeExternalClkInvalid <= to_StdLogic(rAssumeExternalClkInvalidLoc);

    -- SafeToEnableGatedClksReg: ----------------------------------------------
    -- This process registers the rSafeToEnableGatedClksAssert signal.
    ---------------------------------------------------------------------------
    SafeToEnableGatedClksReg : process (ReliableClk)
    begin
      if rising_edge(ReliableClk) then
        if rSafeToEnableGatedClksAssert then
          rSafeToEnableGatedClksLoc <= '1';
        elsif rSafeToEnableGatedClksDeAssert then
          rSafeToEnableGatedClksLoc <= '0';
        end if;
      end if;
    end process SafeToEnableGatedClksReg;
    rSafeToEnableGatedClks <= rSafeToEnableGatedClksLoc;

    -- InternalClksValidPrc: ----------------------------------------------------
    -- This process registers the rInternalClksValid signal.
    --------------------------------------------------------------------------
    InternalClksValidPrc : process (ReliableClk)
    begin
      if rising_edge(ReliableClk) then
        if rInternalClksValidAssert then
          rInternalClksValidLoc <= true;
        elsif rInternalClksValidDeassert then
          rInternalClksValidLoc <= false;
        end if;
      end if;
    end process InternalClksValidPrc;
    rInternalClksValid <= to_stdlogic(rInternalClksValidLoc);

    -- DiagramResetAssertionErr: -------------------------------------------------
    -- This process registers the rDiagramResetAssertionErr signal
    ------------------------------------------------------------------------------
    DiagramResetAssertionErr : process (ReliableClk)
    begin
      if rising_edge(ReliableClk) then
        rDiagramResetAssertionErrLoc <= rDiagramResetAssertionErrNx;
      end if;
    end process DiagramResetAssertionErr;
    rDiagramResetAssertionErr <= to_stdlogic(rDiagramResetAssertionErrLoc);

  end block DiagramResetFSM;

  -- DiagramResetRegisterBlk: -------------------------------------------------
  -- This block contains the diagram reset registers.
  -----------------------------------------------------------------------------
  DiagramResetRegisterBlk : block

    -- Diagram reset signal for fpga access. This signal is initialized to '1'
    -- on device startup.
    signal rDiagramResetLoc, aDiagramResetLoc : std_logic;

    -- !CONSTRAINT! -------------------------------------------------------------
    -- dont_touch is important for the following reasons:
    -- 1. Prevent the two identical registers on DiagramReset from getting
    -- merged.
    -- 2. Prevent synthesis renaming of these nets since there is set_false_path
    -- constraint on aDiagramResetLoc signal.
    --
    -- Xilinx prefers using 'dont_touch' over the 'keep' attribute since 'dont_touch'
    -- is forward-annotated to the place-and-route tools to prevent logic 
    -- optimizations.
    -- The downside of using 'dont_touch' is that opt_design throws an error if 
    -- the signal having the attribute applied becomes unconnected.
    --
    -- In conclusion, we can use 'dont_touch' on aDiagramResetLoc because 
    -- this signal should always have a load and should not be optimized.   
    -- We have to use 'keep' on rDiagramResetLoc because this signal might be
    -- unconnected and using 'dont_touch' would throw a Vivado error.
    -----------------------------------------------------------------------------
    attribute dont_touch : string;
    attribute dont_touch of aDiagramResetLoc : signal is "true";

    attribute keep : string;    
    attribute keep of rDiagramResetLoc : signal is "true";

  begin

    -- DiagRstForHostInReliableClk: -------------------------------------------
    -- This process registers the diagram reset signal that's read by the Host.
    -- This signal is different from the one read by the FPGA in that, it is
    -- de-asserted after the reset de-assertion prop delay(as opposed to the one
    -- read by the FPGA, which is de-asserted before the prop delay). This is
    -- done in order to lock the host from performing any other FPGA operations
    -- before the FPGA is completely out of the reset/un-reset cycle.
    ---------------------------------------------------------------------------
    DiagRstForHostInReliableClk : process (ReliableClk)
    begin
      if rising_edge(ReliableClk) then
        if rDiagramResetForHostAssert then
          rDiagramResetForHost <= '1';
        elsif rDiagramResetForHostDeAssert then
          rDiagramResetForHost <= '0';
        end if;
      end if;
    end process DiagRstForHostInReliableClk;

    rDiagramResetStatus <= rDiagramResetForHost;

    -- DiagRstForHostInBusClk: ------------------------------------------------
    -- !CLOCK BOUNDARY CROSSING! This process double synchronizes
    -- rDiagramResetForHost for host read.
    --
    -- !CONSTRAINT! From rDiagramResetForHost To bDiagramResetForHost_ms -
    -- 1 BusClk cycle. This is necessary to prove correctness
    -- of the design. Refer to the header for more information.
    ---------------------------------------------------------------------------
    DiagRstForHostInBusClk : process (BusClk)
    begin
      if rising_edge(BusClk) then
        bDiagramResetForHost_ms <= rDiagramResetForHost;
        bDiagramResetForHost <= bDiagramResetForHost_ms;
      end if;
    end process DiagRstForHostInBusClk;

    ---------------------------------------------------------------------------
    -- The following two instances register the DiagramReset signal.
    -- One version of this registered signal is meant to be used as a 
    -- synchronous reset signal, and the other version is meant to be used as
    -- an asynchronous reset signal.
    -- Using DFlop component to make sure that the two identical flops do not
    -- get merged.
    ---------------------------------------------------------------------------
    --vhook_e DFlop SyncDiagramRst
    --vhook_a kResetVal '1'
    --vhook_a kAsyncReg "false"
    --vhook_a aReset false
    --vhook_a Clk ReliableClk
    --vhook_a cEn true
    --vhook_a cD rDiagramResetNx
    --vhook_a cQ rDiagramResetLoc
    SyncDiagramRst: entity work.DFlop (rtl)
      generic map (
        kResetVal => '1',
        kAsyncReg => "false")
      port map (
        aReset => false,
        cEn    => true,
        Clk    => ReliableClk,
        cD     => rDiagramResetNx,
        cQ     => rDiagramResetLoc);

    --vhook_e DFlop AsyncDiagramRst
    --vhook_a kResetVal '1'
    --vhook_a kAsyncReg "false"
    --vhook_a aReset false
    --vhook_a Clk ReliableClk
    --vhook_a cEn true
    --vhook_a cD rDiagramResetNx
    --vhook_a cQ aDiagramResetLoc
    AsyncDiagramRst: entity work.DFlop (rtl)
      generic map (
        kResetVal => '1',
        kAsyncReg => "false")
      port map (
        aReset => false,
        cEn    => true,
        Clk    => ReliableClk,
        cD     => rDiagramResetNx,
        cQ     => aDiagramResetLoc);

    rDiagramReset <= rDiagramResetLoc;

    DiagramResetDriver: block is
      constant kInsertBufg : boolean := 
            kDeviceFamily=kintex7 
         or kDeviceFamily=virtex7 
         or kDeviceFamily=artix7
         or kDeviceFamily=KintexU
         or kDeviceFamily=KintexUp
         or kDeviceFamily=VirtexUp 
         or kDeviceFamily=zynquplus;
         -- Its worth revisiting this but leaving out versal based on this error gotten from Kumaran + Xilinx's research:
         -- ERROR: [Place 30-1161] Could not place all instances for rule! 
         -- Clock Rule: rule_bufg_in_shadow_regions_driven_by_fabric 
         -- Rule Description: Only one connection is available for BUFGCE/BUFGCTRL driven by a non IO/Clock element in shadow clock regions.
      begin
      InsertBufg : if kInsertBufg generate
        BUFG_inst : BUFG
        port map (
          O => aDiagramReset, 
          I => aDiagramResetLoc  
        );
      end generate InsertBufg;

      NoInsertBufg : if not kInsertBufg generate
        aDiagramReset <= aDiagramResetLoc;
      end generate NoInsertBufg;
    end block DiagramResetDriver;

  end block DiagramResetRegisterBlk;

  -- HostRdAccessBlk: ---------------------------------------------------------
  -- This Block contains logic for host rd access to the DiagramReset register.
  -- Host Access to this register is controlled through the BusHold,
  -- and the RegisterAccess components.
  -----------------------------------------------------------------------------
  HostRdAccessBlk : block
    signal bDiagramResetRegister: std_logic_vector(31 downto 0);
  begin

    ---------------------------------------------------------------------------
    -- Flatten/Unflatten the Host Read port
    ---------------------------------------------------------------------------
    -- The host read access issued from the Bushold is a single cycle pulse.
    bHostReadPulse <= to_Boolean(bHostReadIn(0));

    bDiagramResetRegister <= ( kDiagramResetBit => bDiagramResetForHost,
                               others => '0');

    -- Meeting requirement of the bushold component to output '0' when the
    -- register is not accessed
    bHostReadData <= bDiagramResetRegister when bHostReadPulse else (others => '0');

    -- Wire HostReadPulse as DataValid
    bHostReadOut(0) <= to_StdLogic(bHostReadPulse);
    -- DiagramReset register data is bits 1 to 32.
    bHostReadOut(32 downto 1) <= bHostReadData;

  end block HostRdAccessBlk;

  --synopsys translate_off
  -- ErrorBlk: ----------------------------------------------------------------
  -- This block contains error detection circuitry.  It checks:
  -- 1). If Path 1 and 2 have correct timing.
  -- 2). If the host read strobe is a single cycle pulse.
  -- 3). If the host write strobe is a single cycle pulse.
  -- 4). If the host read, and write port widths are consistent.
  -----------------------------------------------------------------------------
  ErrorBlk : block
  begin

  -- Path1TimingChk: --------------------------------------------------------
  -- This process checks path 1 timing. The path has been described in the
  -- file header.
  ---------------------------------------------------------------------------
    Path1TimingChk : process
    begin

      wait until rStartFsmByHostPulse1;

      wait until rising_edge(ReliableClk);

      wait until rising_edge(BusClk);
      wait until rising_edge(BusClk);
      wait until rising_edge(BusClk);

      wait until falling_edge(BusClk);
      assert not bReady
        report "Entity: DiagramReset, Process: Path1TimingChk" & LF &
               "bReady should not have asserted"
        severity failure;

    -- In case ReliableClk and BusClk are sourced from the same clock, with only
    -- delta cycle delays between them, then moving from the ReliableClk
    -- rising edge to the BusClk rising edge - as performed above - would occur
    -- immediately, and not one clock cycle later as expected.
      -- The extra BusClk cycle delay below is needed in order to avoid just such
    -- a case, which could result in false failures.
      wait until falling_edge(BusClk);

      wait until falling_edge(BusClk);
      assert bReady
        report "Entity: DiagramReset, Process: Path1TimingChk" & LF &
               "bReady should have asserted"
        severity failure;

    end process Path1TimingChk;

    -- Path2TimingChk: --------------------------------------------------------
    -- This process checks path 2 timing. The path has been described in the
    -- file header.
    ---------------------------------------------------------------------------
    Path2TimingChk : process
    begin

      wait until rStartFsmByHostPulse1;

      wait until rising_edge(ReliableClk);

      wait until rising_edge(BusClk);
      wait until rising_edge(BusClk);

      wait until falling_edge(BusClk);
      assert (bDiagramResetForHost = rDiagramResetForHost)
        report "Entity: DiagramReset, Process: Path2TimingChk" & LF &
               "DiagramReset for host should have updated."
        severity failure;

    end process Path2TimingChk;

    -- ReadPulseChk:-----------------------------------------------------------
    -- Makes sure that the read strobe from the host is a single cycle pulse.
    ---------------------------------------------------------------------------
    ReadPulseChk : process
    begin
      wait until bHostReadPulse and rising_edge(BusClk);
      wait until rising_edge(BusClk);
      assert not bHostReadPulse
        report "Entity: DiagramReset, Process: ReadPulseChk" & LF &
               "Read strobe from the host should be a single cycle pulse"
        severity error;
    end process ReadPulseChk;

    -- WritePulseChk: ---------------------------------------------------------
    -- Makes sure that the write strobe from the host is a single cycle pulse.
    ---------------------------------------------------------------------------
    WritePulseChk : process
    begin
      wait until bHostWritePulse and rising_edge(BusClk);
      wait until rising_edge(BusClk);
      assert not bHostWritePulse
        report "Entity: DiagramReset, Process: WritePulseChk" & LF &
               "Write strobe from the host should be a single cycle pulse"
        severity error;
    end process WritePulseChk;

    -- Make sure that the read port and the write port are consistent
    assert kHostWriteWidthIn = kHostReadWidthOut + 1
      report "Entity: DiagramReset, Block: ErrorBlk" & LF &
             "Inconsistent size between Read and Write ports"
      severity error;

  end block ErrorBlk;
  --synopsys translate_on

end architecture rtl;
