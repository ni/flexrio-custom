-------------------------------------------------------------------------------
--
-- File: ViControl.vhd
-- Author: Asrar Rangwala
-- Original Project: Improving Fpga Reset Scheme
-- Date: 5 March 2008
--
-------------------------------------------------------------------------------
-- (c) 2008 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--   This component houses the VIControl register. Description of the register
--   is given below.
--
--   It also uses the SafeBusCrossing component to protect the ViControl
--   register from unreliable bus behavior during host warm-reboot.
--
--   To preclude asynchronous reset crossings to/from this component over the 
--   BusClk ports: Drive the aBusReset port only if the BusClk port accessor 
--   (RegisterAccess component in the CommunicationInterface) is also using 
--   the same reset. Otherwise, use the bBusReset port.
--
--   ViControl Register:
--     This register is made up of muliple bits as described in
--     PkgNiFpgaViControlRegister.vhd.
--
-- Timing:
--   The following analysis will prove that after a host write access, host
--   reads fetch the hardware value, thus getting rid of any race condition on
--   reads after writes.
--
--   Path 1: After DataValid(SafeBusCrossing) asserts, it takes 5-6 BusClk
--   + 1 ReliableClk cycles for IoReady(RegisterAccess) to be asserted:
--     * 4-5 BusClk + 1 ReliableClk by SafeBusCrossing Component
--     * 1 BusClk by RegisterAccess Component.
--
--   Path 2: After DataValid(SafeBusCrossing) asserts, it takes 2-3 BusClk
--   + 1 ReliableClk cycles for bHostReadOut to be updated:
--     * 1 ReliableClk by the ReliableClkPrc process in EnableInBlk, and 
--       EnableClrBlk blocks.
--     * 2-3 BusClks by the BusClkPrc process in  EnableInBlk, and EnableClrBlk
--       blocks.
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
--   kInitDuration :          This is the duration (specified as the no. of
--                            ReliableClk cycles) for which EnableIn should
--                            remain deasserted between VI Re-runs, and
--                            after DiagramReset. Its value is determined
--                            dynamically during code generation by
--                            considering the maximum initialization time
--                            requested by all the components. A value of '0'
--                            indicates that initialization duration was not
--                            requested.
--
--   kAutoRun :               True for an Autorun bitstream. For an autorun 
--                            bitstream after configuration, the first 
--                            execution of the VI is started by the FPGA. Only
--                            subsequent runs are controlled by the host.
--
--   kAllowEnableRemoval :    This boolean indicates if enable chain removal
--                            optimization was set in the build specification. 
--
--   kHostReadWidthIn :       Defines width of bHostReadIn port.
--
--   kHostReadWidthOut :      Defines width of bHostReadOut port.
--
--   kHostWriteWidthIn :      Defines width of bHostWriteIn port.
--
--   kHostWriteWidthOut :     Defines width of bHostWriteOut port.
--
-- Ports:
--   aBusReset :              This is the asynchronous bus reset.
--
--   BusClk :                 This is the bus clock.
--
--   bBusReset :              This is the bus reset synchronous to the BusClk.
--
--   bCommunicationTimeout :  This is the Communication timeout signal from
--                            the communication interface.
--
--   bIoWtToEnSafeBusCrossing:This is the Io Write strobe from the Bus. Ideally
--                            it should be connected directly to the I/O pin or
--                            an IOB register. It is imp that it is asserted one
--                            clock cycle before bHostWriteIn(0) asserts. Also,
--                            this signal may be asserted for any arbitrary 
--                            no. of clock cycles. This signal is only used to
--                            enable the safebuscrossing component.
--
--   bHostReadIn :            Bit 0 - This is a single cycle pulse indicating
--                            host read access to ViControl register.
--                            Bit 1 - Unused.
--
--   bHostReadOut :           Bit 0 - This is a single cycle pulse indicating
--                            data valid for host read access.
--                            Bit 1 to 32 - This is the Control Register data.
--                            This output is NOT registered.
--
--   bHostWriteIn :           Bit 0 - This is a single cycle pulse indicating
--                            host write access to ViControl register.
--                            Bit 1 - Unused.
--                            Bit 2 to 33 - This is the Control Register data.
--
--   bHostWriteOut :          Bit 0 - This is the Ready signal. It is de-
--                            asserted a clock cycle after bHostWriteIn(0) 
--                            asserts. It is asserted back at the completion of
--                            host write access. This output is registered.
--
--   aDiagramReset :          This is the asynchronous diagram reset.
--
--   TopLvClk :               This is the top level clock for the diagram.
--
--   tDiagramEnableOut :      This is the diagram EnableOut.
--
--   tDiagramEnableIn :       This is the diagram EnableIn. This output is 
--                            registered.
--
--   tDiagramEnableClear :    This is the diagram EnableClear. This output is 
--                            registered.
--
--   ReliableClk :            This is a raw clock generated straight from an 
--                            on-board oscillator. It is considered glitch-free
--
--   rDiagramResetStatus :    It indicates reset status of the diagram 
--                            components. It asserts synchronously with 
--                            aDiagramReset, and de-asserts after the worst 
--                            case de-assertion propagation delay of 
--                            aDiagramReset.
--
--   rDerivedClksValid :      This should be asserted to indicate that all the
--                            FPGA derived clocks are valid, and good for use. 
--                            Ideally, this port should be
--                            driven by the logical AND of Locked output from 
--                            all the internal DCM/PLLs that run off the FPGA 
--                            base clocks. Locked output from the Xilinx DCM/PLL
--                            are known to be un-reliable a few CC after DCM/PLL
--                            reset/ configuration , and so it is imperative for
--                            this port to be driven from a valid source. It is
--                            assumed that this signal is not reset asynchronously.
--
--   rDiagramReset :          This is the diagram reset signal that resets the
--                            diagram components. This signal is initilized to '1'
--                            on device startup and is not asynchronously reset.
--                            Note: this is the same as aDiagramReset but we're
--                            using a synchronous name to make it obvious we're
--                            using it in a synchronous fashion.
--
--   rDerivedClockLostLockError:
--                            This is the error bit that indicates if a derived
--                            clock lost lock while the diagram was not in 
--                            reset. This is meant to go out TheWindow so
--                            clients can expose it in their own register maps
--                            if they desire.
--
--   rInternalClksValid :     This signal indicates that all the gated base and derived  
--                            clocks (excluding external clocks) are running and valid. 
--                            Its value is checked in the EnableIn FSM before asserting  
--                            the 'enable in' signal for the VI.
--
--   rEnableClksForViRun :    This signal is asserted to indicate a request for the gated
--                            base and derived clocks to be enabled. 
--                            Note: this signal is read in the DiagramReset FSM only when 
--                            'kAllowEnableRemoval' is true.
--                          
--   rDerivedClkStartupErr :  This signal indicates if a gated derived clock started
--                            running before the clock enable was asserted or
--                            after the gated base clock valid signal asserted.
--
--   rGatedBaseClkStartupErr : 
--                            This signal indicates if a gated base clock started
--                            running before the clock enable was asserted or
--                            after the gated base clock valid signal asserted.
--
--  rDiagramResetAssertionErr : 
--                            This signal indicates an error if Diagram Reset was 
--                            requested by host when the VI was built with enable removal 
--                            optimization set - in this case Diagram Reset assertion
--                            is not supported.
-----------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;
  use work.PkgNiFpgaViControlRegister.all;
  
entity ViControl is
  generic (
    kInitDuration : natural := 0;
    kAutoRun : boolean := false;
    kAllowEnableRemoval : boolean := false;
    kHostReadWidthIn : positive range 2 to 2 := 2;
    kHostReadWidthOut : positive range 9 to 33 := 33;
    kHostWriteWidthIn : positive range 10 to 34 := 34;
    kHostWriteWidthOut : positive range 1 to 1 := 1
  );
  port (
    aBusReset : in boolean;
    BusClk : in std_logic;
    bBusReset : in boolean;
    bCommunicationTimeout : in boolean;
    bIoWtToEnSafeBusCrossing : in boolean;
    bHostReadIn : in std_logic_vector(kHostReadWidthIn-1 downto 0);
    bHostReadOut : out std_logic_vector(kHostReadWidthOut-1 downto 0);
    bHostWriteIn : in std_logic_vector(kHostWriteWidthIn-1 downto 0);
    bHostWriteOut : out std_logic_vector(kHostWriteWidthOut-1 downto 0);
    
    aDiagramReset : in boolean;
    TopLvClk : in std_logic;
    tDiagramEnableOut : in std_logic;
    tDiagramEnableIn : out std_logic;
    tDiagramEnableClear : out std_logic;
    
    ReliableClk : in std_logic;
    rDiagramResetStatus : in boolean;
    rDerivedClksValid : in boolean;
    rInternalClksValid : in boolean;
    rDiagramReset : in boolean;
    rDerivedClockLostLockError : out std_logic;
    rEnableClksForViRun : out std_logic;
    rGatedBaseClkStartupErr : in boolean;
    rDerivedClkStartupErr : in boolean;
    rDiagramResetAssertionErr : in boolean
  );
   
end entity ViControl;

architecture rtl of ViControl is
  
  -----------------------------------------------------------------------------
  -- Shared signals between blocks
  -----------------------------------------------------------------------------
  signal bHostWritePulse, bHostReadPulse, rHostWritePulse : boolean;
  signal bHostWriteData, 
         rHostWriteData : std_logic_vector(kEnableClearBit downto kEnableInBit);
  signal bHostReadData : std_logic_vector(31 downto 0);      
  signal bEnableOut, bEnableIn, bEnableClear, bTimeout : std_logic := '0';
  signal bDerivedClkLostLock : std_logic := '0';
  signal bGatedClkStartupErr : std_logic := '0';
  signal bEnableDeassertionErr : std_logic := '0';
  signal bDiagramResetAssertionErr : std_logic := '0';
  signal bReady : boolean;
  signal rEnableIn, rEnableClear : std_logic := '0';
  signal rEnableDeassertionErrNx : std_logic := '0';
  
  -- !CONSTRAINT! -------------------------------------------------------------
  -- keep constraints ensure that the signals they apply to are not lost
  -- or changed through optimization. This is done because there are
  -- FROM TO constraints on these signals which would otherwise go unrecognized
  -- if the signals were changed.
  -----------------------------------------------------------------------------
  attribute keep : string;
  attribute keep of rEnableIn : signal is "true";
  attribute keep of rEnableClear : signal is "true";
  
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of bEnableIn,bEnableOut : signal is "true";
  attribute ASYNC_REG of bEnableClear : signal is "true";
  attribute ASYNC_REG of bDerivedClkLostLock : signal is "true";
  attribute ASYNC_REG of bGatedClkStartupErr : signal is "true";
  attribute ASYNC_REG of bDiagramResetAssertionErr : signal is "true";
  attribute ASYNC_REG of bEnableDeassertionErr : signal is "true";
begin
  
  -- HostWtAccessBlk: ---------------------------------------------------------
  -- This Block contains logic for host wt access to the ViControl register.
  -- Host Access to the VIControl Register is controlled through the bushold, 
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
    -- Bits 2 to 33 is Control Register data. Host can only update EnableIn, 
    -- and EnableClear, and so only handshaking these bits to ReliableClk 
    -- domain.
    bHostWriteData <= bHostWriteIn (kEnableClearBit+2 downto kEnableInBit+2);
    
    -- BusClkToReliableClkHS: -------------------------------------------------
    -- !CLOCK BOUNDARY CROSSING! This component provides safe data HS from the 
    -- BusClk to the ReliableClk. It only transfers EnableIn, and EnableClear 
    -- bits, as only these can be updated by host write.
    --
    -- !CONSTRAINTS! Constraints should be set on this component. Refer to the
    -- SafeBusCrossing component for more information.
    ---------------------------------------------------------------------------
    --vhook_e SafeBusCrossing BusClkToReliableClkHS
    --vhook_a kDataWidth 2
    --vhook_a bPush bHostWritePulse
    --vhook_a bPushEn bIoWtToEnSafeBusCrossing
    --vhook_a bData bHostWriteData
    --vhook_a rData rHostWriteData
    --vhook_a rDataValid rHostWritePulse
    BusClkToReliableClkHS: entity work.SafeBusCrossing (rtl)
      generic map (
        kDataWidth => 2)
      port map (
        aBusReset   => aBusReset,
        BusClk      => BusClk,
        bPush       => bHostWritePulse,
        bPushEn     => bIoWtToEnSafeBusCrossing,
        bData       => bHostWriteData,
        bReady      => bReady,
        ReliableClk => ReliableClk,
        rData       => rHostWriteData,
        rDataValid  => rHostWritePulse);
        
    -- Wire Ready from SafeBusCrossing component back to the Bushold.
    bHostWriteOut(0) <= to_StdLogic(bReady);
                                               
  end block HostWtAccessBlk;
  
  -- EnableOutBlk: ------------------------------------------------------------
  -- This Block contains logic for the Diagram EnableOut bit.
  -----------------------------------------------------------------------------
  EnableOutBlk : block
  
    -- EnableOut Signals
    signal tDiagramEnableOutReg, bEnableOut_ms : std_logic := '0';
    
    attribute ASYNC_REG of bEnableOut_ms: signal is "true";
    
  begin
    
    -- TopLvClkPrc: -----------------------------------------------------------
    -- This process registers the EnableOut input. It is prudent to register
    -- this signal as the input port tDiagramEnableOut may be driven from a
    -- logic cloud.
    ---------------------------------------------------------------------------    
    TopLvClkPrc : process (aDiagramReset, TopLvClk)
    begin
      if aDiagramReset then
        tDiagramEnableOutReg <= '0';
      elsif rising_edge(TopLvClk) then
        tDiagramEnableOutReg <= tDiagramEnableOut;
      end if;
    end process TopLvClkPrc;
    
    -- BusClkPrc: -------------------------------------------------------------
    -- Intentionally removed async reset to preclude possible reset crossings
    -- from EnableOut signal to communication interface.
    --
    -- !CLOCK BOUNDARY CROSSING! This process double synchronizes 
    -- tDiagramEnableOutReg to BusClk for host read.
    --
    -- No Constraint on the dbl synch by design.
    ---------------------------------------------------------------------------    
    BusClkPrc : process (BusClk)
    begin
      if rising_edge(BusClk) then
        -- EnableOut can only be updated by the FPGA
        bEnableOut_ms <= tDiagramEnableOutReg;
        bEnableOut <= bEnableOut_ms;
      end if;
    end process BusClkPrc; 
        
  end block EnableOutBlk;

  -- EnableInBlk: -------------------------------------------------------------
  -- This Block contains logic for the Diagram EnableIn bit.
  -----------------------------------------------------------------------------
  EnableInBlk : block
  
    -- Signals for EnableIn  
    signal tEnableInLoc, tEnableIn_ms, bEnableIn_ms : std_logic := '0';
    
    attribute ASYNC_REG of tEnableIn_ms,tEnableInLoc : signal is "true";
    attribute ASYNC_REG of bEnableIn_ms : signal is "true";
    
    type EnableInState_t is (  
      
    -- Idle:                    Keep EnableIn de-asserted. When the diagram 
    --                          comes out of reset, start the timer, and move 
    --                          to EnableInDeAsserted state.
    Idle,
    
    -- EnableInDeAsserted:      Keep EnableIn de-asserted and wait for host or an 
    --                          FPGA request (for the first run of an autorun 
    --                          bitstream) to assert EnableIn.
    --                          If enable removal optimization is set (kAllowEnableRemoval=true)
    --                          then request gated clocks to be enabled and go to
    --                          'WaitUntilInternalClocksBecomeValid' state. Otherwise, 
    --                          go to 'WaitUntilComponentsInit
    EnableInDeAsserted,
    
    -- WaitUntilInternalClocksBecomeValid: 
    --                          Wait until all gated base and derived clocks become
    --                          valid. EnableIn is kept de-asserted in this state.
    --                          This state is hit only if enable removal optimization
    --                          is set.
    WaitUntilInternalClocksBecomeValid,
      
    -- WaitUntilComponentsInit: Keep EnableIn de-asserted until timer expires.
    --                          Then, assert EnableIn, and move to 
    --                          EnableInAsserted state.
    WaitUntilComponentsInit,
      
    -- EnableInAsserted:        Keep EnableIn asserted. 
    --                          If enable removal optimization is set (kAllowEnableRemoval=true)
    --                          and the host requests to de-assert Enable, then go to the
    --                          EnableInDeassertionNotSupportedErr error state.
    --                          Otherwise, if the host requests to de-assert Enable, do that, and move to 
    --                          the Idle state.
    EnableInAsserted,
    
    -- EnableInDeassertionNotSupportedErr:  This is an error state. 
    --                                      Assert 'EnableIn Deassertion Not Supported Error' bit. 
    EnableInDeassertionNotSupportedErr
    );
      
    -- EnableIn state signals
    signal rEnableInState, rNxEnableInState : EnableInState_t := Idle;
      
    -- Timer signals
    signal rTimerSet, rTimerExpired : boolean;
    signal rTimerSetCount : natural range 0 to kInitDuration;
    signal rTimerCount : natural range 0 to kInitDuration := 0;
      
    -- EnableIn control signals
    signal rEnableInAssertionByHost, rEnableInDeAssertionByHost : boolean;
    signal rFirstRunAfterConfig : boolean := true;
    signal rAutoRunStartDiagram : boolean;
    signal rNxEnableIn : std_logic;
    
    -- EnableClk signals
    signal rEnableClksForViRunLoc : boolean := false;
    signal rEnableClksForViRunAssert, rEnableClksForViRunDeassert : boolean;
          
  begin
      
    -- FirstRunAfterConfigProc: -----------------------------------------------
    -- This process generates the rFirstRunAfterConfig signal. It is
    -- asserted on configuration and remains de-asserted after EnableIn has
    -- asserted once.
    ---------------------------------------------------------------------------
    FirstRunAfterConfigProc : process(ReliableClk)
    begin
      if rising_edge(ReliableClk) then
        rFirstRunAfterConfig <= rFirstRunAfterConfig and (rEnableIn = '0');
      end if;
    end process FirstRunAfterConfigProc;
  
    rAutoRunStartDiagram <= kAutoRun and rFirstRunAfterConfig;
      
    rEnableInAssertionByHost <= (rHostWritePulse and 
                                 rHostWriteData(kEnableInBit) = '1');
      
    rEnableInDeAssertionByHost <= (rHostWritePulse and 
                                   rHostWriteData(kEnableInBit) = '0');
      
    -- EnableInStateReg: ----------------------------------------------------
    -- This process registers the next state signal for the EnableIn
    -- state machine.
    -------------------------------------------------------------------------
    EnableInStateReg : process (ReliableClk)
    begin
      if rising_edge(ReliableClk) then
        if rDiagramResetStatus then
          rEnableInState <= Idle;
        else
          rEnableInState <= rNxEnableInState;
        end if;
      end if;
    end process EnableInStateReg;
      
    -- EnableInNxStatePrc: --------------------------------------------------
    -- This is the next state process for the EnableIn state machine.
    -- For FSM theory of operation, refer to the state signal declaration.
    --
    -- !STATE MACHINE STARTUP! This state machine cannot start immediately 
    -- after configuration: rDiagramResetStatus is initialized to true on
    -- configuration by the DiagramReset component, and it does not de-assert
    -- for a few clock cycles until all the components have come out of 
    -- aDiagramReset.
    -------------------------------------------------------------------------
    EnableInNxStatePrc : process (rEnableInState, rAutoRunStartDiagram, rTimerExpired,
                                  rEnableInDeAssertionByHost, rEnableInAssertionByHost,
                                  rInternalClksValid)
    begin
      -- Default signal assign. This ensures that a latch isn't inferred on any
      -- signal.
      rNxEnableInState <= rEnableInState;
      rTimerSet <= false;
      rTimerSetCount <= 0;
      rNxEnableIn <= '0';
      rEnableClksForViRunAssert <= false;
      rEnableClksForViRunDeassert <= false;
      rEnableDeassertionErrNx <= '0';
      
      case rEnableInState is
        
        when Idle =>
          
          rNxEnableInState <= EnableInDeAsserted;
          rTimerSet <= true;
          rTimerSetCount <= kInitDuration;
        
        when EnableInDeAsserted =>
          
          if rEnableInAssertionByHost or rAutoRunStartDiagram then
            if kAllowEnableRemoval then
              rNxEnableInState <= WaitUntilInternalClocksBecomeValid;
              rEnableClksForViRunAssert <= true;
            else
              rNxEnableInState <= WaitUntilComponentsInit;
            end if;
          end if;
          
        when WaitUntilInternalClocksBecomeValid =>
        
          if rInternalClksValid then
            rNxEnableInState <= WaitUntilComponentsInit;
          end if;
          
        when WaitUntilComponentsInit =>
            
           if rTimerExpired then
            rNxEnableInState <= EnableInAsserted;
            rNxEnableIn <= '1';
          end if;
        
        when EnableInAsserted =>
          
          rNxEnableIn <= '1';           
          if rEnableInDeAssertionByHost then
            if kAllowEnableRemoval then
              rNxEnableInState <= EnableInDeassertionNotSupportedErr;
            else
              rNxEnableInState <= Idle;
            end if;
            rNxEnableIn <= '0';
          end if;
        
        when EnableInDeassertionNotSupportedErr =>
          rEnableDeassertionErrNx <= '1';
          
        when others =>
            
          rNxEnableInState <= Idle;
          
      end case;
    end process EnableInNxStatePrc;
    
    -- Timerprc: --------------------------------------------------------------
    -- This process instantiates the timer used by the EnableIn state machine.
    --
    -- !COUNTER STARTUP! The counter cannot transition right after fpga
    -- configuration, as it starts operating only when the FSM is out of the 
    -- "Idle" state.
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
    
    -- ReliableClkPrc: ------------------------------------------------------
    -- This process registers the EnableIn signal. This signal is controlled 
    -- by the EnableIn state machine.
    -------------------------------------------------------------------------
    ReliableClkPrc : process (ReliableClk)
    begin
      if rising_edge(ReliableClk) then
        rEnableIn <= rNxEnableIn;
      end if;
    end process ReliableClkPrc;
    
    -- EnableClksForViRunPrc: -----------------------------------------------
    -- This process registers the EnableClksForViRun signal. The signal is 
    -- controlled by the EnableIn state machine
    -------------------------------------------------------------------------
    EnableClksForViRun : process (ReliableClk)
    begin
      if rising_edge(ReliableClk) then
        if rEnableClksForViRunAssert then
          rEnableClksForViRunLoc <= true;
        elsif rEnableClksForViRunDeassert then
          rEnableClksForViRunLoc <= false;
        end if;
      end if;
    end process EnableClksForViRun;
    rEnableClksForViRun <= to_stdlogic(rEnableClksForViRunLoc);
    
    -- BusClkPrc: -------------------------------------------------------------
    -- Intentionally removed async reset to preclude possible reset crossings
    -- from EnableIn signal to communication interface.
    --    
    -- !CLOCK BOUNDARY CROSSING! This process double synchronizes rEnableIn
    -- to BusClk for host read.
    --
    -- !CONSTRAINT! From rEnableIn To bEnableIn_ms - 1 BusClk.
    -- This is necessary to prove correctness of the design.
    -- Refer to the header for more information.
    ---------------------------------------------------------------------------    
    BusClkPrc : process (BusClk)
    begin     
      if rising_edge(BusClk) then
        bEnableIn_ms <= rEnableIn;
        bEnableIn <= bEnableIn_ms;
      end if;
    end process BusClkPrc;

    -- TopLvClkPrc: -----------------------------------------------------------
    -- !CLOCK BOUNDARY CROSSING! This process double synchronizes rEnableIn
    -- to TopLvClk for FPGA read.
    --
    -- !CONSTRAINT! From rEnableIn To tEnableIn_ms - 6 TopLvClk cycles. 
    -- This is necessary because when the TopLvClk is derived from the 
    -- ReliableClk (related by a non-integral factor eg. 2/3), XST will most
    -- likely try to meet a rigid timing requirement on the dbl sync which may not
    -- be met, thus failing the compilation. The solution is to place a loose 
    -- constraint to pre-empt XST from forcing any timing requirements.
    ---------------------------------------------------------------------------
    TopLvClkPrc : process (aDiagramReset, TopLvClk)
    begin
      if aDiagramReset then
        tEnableIn_ms <= '0';
        tEnableInLoc <= '0';
      elsif rising_edge(TopLvClk) then
        tEnableIn_ms <= rEnableIn;
        tEnableInLoc <= tEnableIn_ms;
      end if;
    end process TopLvClkPrc;
    
    tDiagramEnableIn <= tEnableInLoc;
        
  end block EnableInBlk;
  
  -- EnableClearBlk: ----------------------------------------------------------
  -- This Block contains logic for the Diagram EnableClear bit.
  -----------------------------------------------------------------------------
  EnableClearBlk : block
  
    -- Signals for EnableClear
    signal tEnableClearLoc, bEnableClear_ms, tEnableClear_ms : std_logic := '0';
    
    attribute ASYNC_REG of bEnableClear_ms: signal is "true";
    attribute ASYNC_REG of tEnableClear_ms,tEnableClearLoc: signal is "true";

  begin
    
    -- ReliableClkPrc: --------------------------------------------------------
    -- This process registers the EnableClear bit. This is also the master 
    -- copy as it resides in the ReliableClk domain.
    ---------------------------------------------------------------------------
    ReliableClkPrc : process (aDiagramReset, ReliableClk)
    begin
      if aDiagramReset then
        rEnableClear <= '0';
      elsif rising_edge(ReliableClk) then
        -- EnableClear can only be updated through host write.
        if rHostWritePulse then
          rEnableClear <= rHostWriteData(kEnableClearBit);
        end if;
      end if;
    end process ReliableClkPrc;
    
    -- BusClkPrc: -------------------------------------------------------------
    -- Intentionally removed async reset to preclude possible reset crossings
    -- from EnableClear signal to communication interface.
    --    
    -- !CLOCK BOUNDARY CROSSING! This process double synchronizes rEnableClear
    -- to BusClk for host read.
    --
    -- !CONSTRAINT! From rEnableClear To bEnableClear_ms - 1 BusClk.
    -- This is necessary to prove correctness of the design.
    -- Refer to the header for more information.    
    ---------------------------------------------------------------------------
    BusClkPrc : process (BusClk) 
    begin
      if rising_edge(BusClk) then
        bEnableClear_ms <= rEnableClear;
        bEnableClear <= bEnableClear_ms;
      end if;
    end process BusClkPrc;
    
    -- TopLvClkPrc: -----------------------------------------------------------
    -- !CLOCK BOUNDARY CROSSING! This process double synchronizes rEnableClear
    -- to TopLvClk for FPGA read.
    -- 
    -- !CONSTRAINT! From rEnableClear To tEnableClear_ms - 6 TopLvClk cycles. 
    -- This is necessary because when the TopLvClk is derived from the 
    -- ReliableClk (related by a non-integral factor eg. 2/3), XST will most
    -- likely try to meet a rigid timing requirement on the dbl sync which may not
    -- be met, thus failing the compilation. The solution is to place a loose 
    -- constraint to pre-empt XST from forcing any timing requirements.
    ---------------------------------------------------------------------------
    TopLvClkPrc : process (aDiagramReset, TopLvClk)
    begin
      if aDiagramReset then
        tEnableClear_ms <= '0';
        tEnableClearLoc <= '0';
      elsif rising_edge(TopLvClk) then
        tEnableClear_ms <= rEnableClear;
        tEnableClearLoc <= tEnableClear_ms;
      end if;
    end process TopLvClkPrc;
    
    tDiagramEnableClear <= tEnableClearLoc;
            
  end block EnableClearBlk;
  
  -- TimeoutBlk: --------------------------------------------------------------
  -- This Block contains logic for the Timeout bit.
  -----------------------------------------------------------------------------
  TimeoutBlk : block
  begin
    -- BusClkPrc: -------------------------------------------------------------
    -- This process registers the Timeout bit. It can only be set by the
    -- Communication interface, and cleared on host read.
    -- 
    -- This register must get cleared whenever the bus resets. So, both the 
    -- sync, and async versions of bus reset are used for this register, as the 
    -- async version may not always be driven. (Refer to the file header for 
    -- more info.)
    ---------------------------------------------------------------------------
    BusClkPrc : process (aBusReset, BusClk)
    begin
      if aBusReset then
        bTimeout <= '0';
      elsif rising_edge(BusClk) then
        if bBusReset then
          bTimeout <= '0';
        else
          if bHostReadPulse then
            bTimeout <= '0';
          -- The bit is set when Timeout from the comm. interface is asserted
          elsif bCommunicationTimeout then
            bTimeout <= '1';
          end if;
        end if;
      end if;
    end process BusClkPrc;
        
  end block TimeoutBlk;
  
  -- DerivedClkLockBlk: -------------------------------------------------------
  -- This block contains logic for reporting if a derived clock ever lost lock
  -- when the diagram was out of reset.
  -----------------------------------------------------------------------------
  DerivedClkLockBlk : block
    signal rDerivedClkLostLock, bDerivedClkLostLock_ms : std_logic := '0';
    
    attribute ASYNC_REG of bDerivedClkLostLock_ms : signal is "true";

  begin
    DerivedLockPrc: process(ReliableClk)
    begin
      if rising_edge(ReliableClk) then
        if (rDiagramReset and not kAllowEnableRemoval) or
           (not rInternalClksValid and kAllowEnableRemoval) then
          rDerivedClkLostLock <= '0';
        elsif (not rDerivedClksValid) then
          rDerivedClkLostLock <= '1';
        end if;
      end if;
    end process DerivedLockPrc;
    rDerivedClockLostLockError <= rDerivedClkLostLock;
    
    -- !CONSTRAINT! -----------------------------------------------------------
    -- Some type of constraint needs to exist between rDerivedClkLostLock
    -- and bDerivedClkLostLock_ms just in case the bus and reliable clocks
    -- are related.
    ---------------------------------------------------------------------------
    BusClkPrc: process(BusClk) 
    begin
      if rising_edge(BusClk) then
        bDerivedClkLostLock_ms <= rDerivedClkLostLock;
        bDerivedClkLostLock <= bDerivedClkLostLock_ms;
      end if;
    end process BusClkPrc;
  end block DerivedClkLockBlk;
  
  -- GatedClkStartupErrBlk: -----------------------------------------------------
  -- This block contains logic for reporting if a gated base or derived clock 
  -- started running before asynchronous reset was deasserted or after the 
  -- clock valid signal has asserted.
  ------------------------------------------------------------------------------
  GatedClkStartupErrBlk : block
    signal bGatedClkStartupErr_ms : std_logic := '0';
    signal rGatedClkStartupErr : std_logic := '0';
    signal rGatedClkStartupErrAssert : boolean;

    attribute ASYNC_REG of bGatedClkStartupErr_ms : signal is "true";
    
  begin
    
    rGatedClkStartupErrAssert <= rGatedBaseClkStartupErr or rDerivedClkStartupErr;
    
    process (ReliableClk)
    begin
      if rising_edge(ReliableClk) then
        if rGatedClkStartupErrAssert then
          rGatedClkStartupErr <= '1';
        end if;
      end if;
    end process;
    
    -- BusClkProc: --------------------------------------------------------
    -- This process synchronizes 'rGatedClkEnableErr' from ReliableClk domain to
    -- BusClk domain.
    --
    -- !CONSTRAINT!
    -- Some type of constraint needs to exist between rGatedClkStartupErr
    -- and bGatedClkStartupErr_ms just in case the bus and reliable clocks
    -- are related.
    ----------------------------------------------------------------------------
    BusClkProc : process (BusClk)
    begin
      if rising_edge(BusClk) then
        bGatedClkStartupErr_ms <= rGatedClkStartupErr;
        bGatedClkStartupErr <= bGatedClkStartupErr_ms;
      end if;
    end process BusClkProc;
    
  end block GatedClkStartupErrBlk;
  
  -- EnableDeassertionErrBlk: --------------------------------------------------
  -- This block contains logic for reporting if Enable deassertion was requested
  -- when enable removal optimization is set.
  ------------------------------------------------------------------------------
  EnableDeassertionErrBlk : block
    signal rEnableDeassertionErr : std_logic := '0';
    signal bEnableDeassertionErr_ms : std_logic := '0';
    
    attribute ASYNC_REG of bEnableDeassertionErr_ms : signal is "true";
    
  begin 
   
    -- ReliableClkPrc: ---------------------------------------------------------
    -- This process registers the EnableDeassertionErr signal.
    ----------------------------------------------------------------------------
    ReliableClkPrc : process (ReliableClk)
    begin
      if rising_edge(ReliableClk) then
        rEnableDeassertionErr <= rEnableDeassertionErrNx;
      end if;
    end process ReliableClkPrc;
    
    -- BusClkProc: --------------------------------------------------------
    -- This process double synchronizes 'rEnableDeassertionErr' from ReliableClk 
    -- domain to BusClk domain for host read.
    --
    -- !CONSTRAINT!
    -- Some type of constraint needs to exist between rEnableDeassertionErr
    -- and bEnableDeassertionErr_ms just in case the bus and reliable clocks
    -- are related.
    ----------------------------------------------------------------------------
    BusClkProc : process (BusClk)
    begin
      if rising_edge(BusClk) then
        bEnableDeassertionErr_ms <= rEnableDeassertionErr;
        bEnableDeassertionErr <= bEnableDeassertionErr_ms;
      end if;
    end process BusClkProc;
  
  end block EnableDeassertionErrBlk;
  
  -- DiagramResetAssertionErrBlk: --------------------------------------------------
  -- This block contains logic for reporting if Diagram Reset assertion was requested
  -- by the host when enable removal optimization is set.
  ----------------------------------------------------------------------------------
  DiagramResetAssertionErrBlk : block
    signal bDiagramResetAssertionErr_ms : std_logic := '0';

    attribute ASYNC_REG of bDiagramResetAssertionErr_ms : signal is "true";
  begin 
    
    -- BusClkProc: -----------------------------------------------------------------
    -- This process double synchronizes 'rDiagramResetAssertionErr' from ReliableClk 
    -- domain to BusClk domain for host read.
    --
    -- !CONSTRAINT!
    -- Some type of constraint needs to exist between rDiagramResetAssertionErr
    -- and bDiagramResetAssertionErr_ms just in case the bus and reliable clocks
    -- are related.
    --------------------------------------------------------------------------------
	
    BusClkProc : process (BusClk)
    begin
      if rising_edge(BusClk) then
        bDiagramResetAssertionErr_ms <= to_stdlogic(rDiagramResetAssertionErr);
        bDiagramResetAssertionErr <= bDiagramResetAssertionErr_ms;
      end if;
    end process BusClkProc;
  
  end block DiagramResetAssertionErrBlk;

  -- HostRdAccessBlk: ---------------------------------------------------------
  -- This Block contains logic for host rd access to the ViControl register.
  -- Host Access to the VIControl Register is controlled through the bushold, 
  -- and the RegisterAccess components.
  -----------------------------------------------------------------------------
  HostRdAccessBlk : block  
    signal bControlReg: std_logic_vector(31 downto 0);
  begin
      
    ---------------------------------------------------------------------------
    -- Flatten/Unflatten the Host Read port
    ---------------------------------------------------------------------------
    -- The host read access issued from the Bushold is a single cycle pulse.
    bHostReadPulse <= to_Boolean(bHostReadIn(0));  

    bControlReg <= (kEnableOutBit => bEnableOut,
                    kEnableInBit => bEnableIn,
                    kEnableClearBit => bEnableClear,
                    kTimeoutBit => bTimeout,
                    kLostLockBit => bDerivedClkLostLock,
                    kGatedClkStartupErrBit => bGatedClkStartupErr,
                    kEnableDeassertionNotSupportedErrBit => bEnableDeassertionErr,
                    kDiagramResetAssertionNotSupportedErrBit => bDiagramResetAssertionErr,
                    others => '0');
                    
    -- Meeting requirement of the bushold component to output '0' when the 
    -- register is not accessed
    bHostReadData <= bControlReg when bHostReadPulse else (others=>'0');
    
    -- Wire HostReadPulse as DataValid
    bHostReadOut(0) <= to_StdLogic(bHostReadPulse);
    -- ViControl data is bits 1 to 32
    bHostReadOut(32 downto 1) <= bHostReadData;
    
  end block HostRdAccessBlk;

  --synopsys translate_off          
  -- ErrorBlk: ----------------------------------------------------------------
  -- This block contains error detection circuitry.  It checks:
  -- 1). If Path 1 and 2 have correct timing.
  -- 2). If the host read strobe is a single cycle pulse.
  -- 3). If the host write strobe is a single cycle pulse.
  -- 4). If the host read, and write port widths are consistent.
  -- 5). Make sure EnableIn stays de-asserted for kInitDuration cycles.
  -----------------------------------------------------------------------------
  ErrorBlk : block
  begin
  
    -- Path1TimingChk: --------------------------------------------------------
    -- This process checks path 1 timing. The path has been described in the 
    -- file header.
    ---------------------------------------------------------------------------
    Path1TimingChk : process
    begin
      
      wait until rHostWritePulse;
      
      wait until rising_edge(ReliableClk);
       
      wait until rising_edge(BusClk);
      wait until rising_edge(BusClk);
      wait until rising_edge(BusClk);
      
      wait until falling_edge(BusClk);      
      assert not bReady 
        report "Entity: ViControl, Process: Path1TimingChk" & LF &
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
        report "Entity: ViControl, Process: Path1TimingChk" & LF &
               "bReady should have asserted"
        severity failure;
      
    end process Path1TimingChk;
    
    -- Path2TimingChk: --------------------------------------------------------
    -- This process checks path 2 timing. The path has been described in the 
    -- file header.
    ---------------------------------------------------------------------------
    Path2TimingChk : process
    begin
      
      wait until rHostWritePulse;
    
      wait until rising_edge(ReliableClk);
      
      wait until rising_edge(BusClk);
      wait until rising_edge(BusClk);
   
      wait until falling_edge(BusClk);
      assert (bEnableClear = rEnableClear)
        report "Entity: ViControl, Process: Path2TimingChk" & LF &
               "EnableClear should have updated."
        severity failure;
      -- rEnableIn is updated right away only if it is de-asserted. If
      -- initialization duration is requested, it may take a few more
      -- clock cycles for rEnableIn to assert.
      if rEnableIn = '0' then
        assert (bEnableIn = rEnableIn)
          report "Entity: ViControl, Process: Path2TimingChk" & LF &
                 "EnableIn should have updated."
          severity failure;
      end if;
      
    end process Path2TimingChk;
      
    -- ReadPulseChk:-----------------------------------------------------------
    -- Makes sure that the read strobe from the host is a single cycle pulse.
    ---------------------------------------------------------------------------
    ReadPulseChk : process
    begin  
      wait until bHostReadPulse and rising_edge(BusClk);
      wait until rising_edge(BusClk);
      assert not bHostReadPulse
        report "Entity: ViControl, Process: ReadPulseChk" & LF &
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
        report "Entity: ViControl, Process: WritePulseChk" & LF &
               "Write strobe from the host should be a single cycle pulse"
        severity error;
    end process WritePulseChk;
      
    -- Make sure that the read port and the write port are consistent
    assert kHostWriteWidthIn = kHostReadWidthOut + 1
      report "Entity: ViControl, Block: ErrorBlk" & LF &
             "Inconsistent size between Read and Write ports"
      severity error;
    
    -- EnableInChk: -----------------------------------------------------------
    -- Makes sure that rEnableIn remains de-asserted for atleast kInitDuration
    -- between VI re-runs, and after diagram reset de-assertion.
    ---------------------------------------------------------------------------
    EnableInChk : process
    begin
      wait until rEnableIn = '0' or not rDiagramResetStatus;
      for i in 0 to kInitDuration loop
        wait until rising_edge(ReliableClk);
        assert rEnableIn = '0'
          report "Entity: ViControl, Block: ErrorClk" & LF &
          "rEnableIn asserted less than kInitDuration" & LF &
          "cycles after de-assertion of rEnableIn"
          severity error;
      end loop;
      wait until rEnableIn = '1';      
    end process EnableInChk;
    
  end block ErrorBlk;
  --synopsys translate_on
    
end architecture rtl;

-------------------------------------------------------------------------------
-- Vscan Review
-------------------------------------------------------------------------------

-- Reset crossing Exception ---------------------------------------------------

--vscan Begin Exception Reset crossing over EnableOut
--vscan # The double synchronizer should safely perform asychronous reset
--vscan # crossing for the single bit signal.
--vscan Source Reset: *
--vscan Destination Reset: *
--vscan Start: *EnableOutBlk/tDiagramEnableOutReg
--vscan End: *EnableOutBlk/tDiagramEnableOutReg
--vscan NewQ: *EnableOutBlk/bEnableOut_ms
--vscan Expected Warnings: 1
--vscan End Exception

--vscan Begin Exception Reset crossing over EnableClear
--vscan # The double synchronizer should safely perform asychronous reset
--vscan # crossing for these single bit signals.
--vscan Source Reset: *
--vscan Destination Reset: *
--vscan Start: *rEnableClear
--vscan End: *rEnableClear
--vscan NewQ: *EnableClearBlk/bEnableClear_ms
--vscan Expected Warnings: 1
--vscan End Exception
