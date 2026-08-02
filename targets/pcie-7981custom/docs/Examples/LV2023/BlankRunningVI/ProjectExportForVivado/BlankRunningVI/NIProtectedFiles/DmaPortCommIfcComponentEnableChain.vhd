-------------------------------------------------------------------------------
--
-- File: DmaPortCommIfcComponentEnableChain.vhd
-- Author: Gregory Voirin, Matthew Koenn
-- Original Project: LvFPGA DMA FIFO
-- Date: 23 February 2007
--
-------------------------------------------------------------------------------
-- (c) 2007 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--                                                                           
-- Purpose:   
--         from the register to build the Push/Pop signal and the Clear signals
--         to be sent to the FIFO.
--         It is also responsible for registering data sent to the resholder 
--         when appropriate.
--
-- Note: 
--       There is an asynchronous path from pEnableIn to pPushPop. This is safe
--       because the Flag signal that is used to build the pPushPop is 
--       registered in the FIFO, preventing us from having an asynchronous 
--       feedback loop.   
--
-- Edited by Matthew Koenn, 15 October 2007
--  * Changed the data widths to be generic to support variable data width
--    DMA channels
--  * Changed some signal names specific for the Mite
-- 
-- GENERICS:
--
--  kInput:  This generic apecifies if the channel is used for input (board to
--           host) or for an output (host to board)       
--
--  kSCL:    Specifies if the diagram port (pop for input, push for output)
--           is used in a Single Cycle Loop        
--
--  kDataWidth : The width (in bits) of the data for this DMA channel
--
--  kHandshaking : True if using Handshaking interface.
--
-- SIGNALS:
--
--  aReset:                Asynchronously resets all flip-flops.  
--
--  PClk:                  This should be the diagram port's clock .
--
--  BusClk:                This should be the miniMite's clock output.
--
--  pEnableIn,
--  pEnableOut,
--  pEnableClear:          The enable chain from the diagram's port
--
--  pHandshakingPushPopRequest: Push/Pop request when using the HS interface.
--
--  pPushPop:              The signal that is sent to the FIFO component to 
--                         do the push (output) or pop (input)
--
--  pResetForFifo:         The reset for the diagram's port
--
--  bResetForFifo:         The reset for the Mite's port
--
--  bResetBitFromRegister: This signal should be directly wired to the ResetBit
--                         in the reset register. Not a registered output.
--
--  bResetDone:            Signal sent to the Reset register to clear the reset
--                         bit. It is a one clock cycle pulse.
--
--  pTimeout,
--  pDataIn, 
--  pDataOut,
--  pFlag:                 Signals used by the diagram resholder. pDataIn is 
--                         used in the output case, and pDataOut in the input 
--                         case.
--
--  pDataOutFromFifo:      This signal should be connected directly to the data
--                         ouput of the Fifo component.
--
--  pFlagFromFifo:        This signal should be connected directly to the flag
--                         ouput of the Fifo component.
-------------------------------------------------------------------------------
library IEEE;
  use IEEE.std_logic_1164.all;
  use IEEE.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;
  use work.PkgCommunicationInterface.all;
  use work.PkgDmaPortCommunicationInterface.all;

entity DmaPortCommIfcComponentEnableChain is
  generic(
    kInput       : boolean := true;
    kSCL         : boolean := false;
    kDataWidth   : natural := 32;
    kHandshaking : boolean := false);
  port(
    
    aReset : in  boolean;

    PClk   : in std_logic; 
    BusClk : in std_logic; 

    pEnableIn    : in  boolean; 
    pEnableOut   : out boolean;
    pEnableClear : in  boolean;

    pHandshakingPushPopRequest  : in  boolean;
    pPushPop                    : out boolean; 
    pDisable                    : out boolean; 

    pResetForFifo : out boolean; 
    bResetForFifo : out boolean;

    bResetBitFromRegister : in  boolean; 
    bResetDone            : out boolean;
    
    pStateDisable         : in boolean; 
    
    -- Diagram signals
    pTimeout      : in  std_logic_vector(31 downto 0);
    pDataOut         : out std_logic_vector(kDataWidth-1 downto 0);
    pFlag            : out std_logic;
    
    -- FIFO signals
    pDataOutFromFifo : in  std_logic_vector(kDataWidth-1 downto 0);
    pFlagFromFifo    : in  std_logic
  );
end DmaPortCommIfcComponentEnableChain;

architecture rtl of DmaPortCommIfcComponentEnableChain  is

  -- Signal used to build a pulse in the non SCL case
  signal pEnableInDly, pEnableInPulse : boolean;

  -- Signals for the timeout management code
  signal pStartTimeout, pHasTimedOut : std_logic;
  type TimeoutState_t is (Idle, Waiting, Done); 
  signal pTimeoutState, pTimeoutNextState : TimeoutState_t; 

  -- Signals used to emulate the enable chain from the
  -- ClearBit in the Reset register
  signal bEnableIn     : boolean; 
  signal bEnableClr    : boolean;  
  signal bEnableOut    : boolean;  
  signal bEnableOutDly : boolean;  
  
  -- Disable signal
  signal pDisableLoc : boolean;
  -- Local signals
  signal pPushPopLoc : boolean;

  signal bDisablePortWrapBack : boolean;
  
begin

  ---------------------------------------------------------------------
  -- Common code for input and output : Enable Chain
  ---------------------------------------------------------------------
  
  -- PushPop needs to be gated by the Disable signals from the 
  -- ClearController to prevent pushing or poping during reset
  pPushPop <= pPushPopLoc when not (pDisableLoc or pStateDisable) else false;
  pDisable <= pDisableLoc or pStateDisable;
  
  ---------------------------------------------------------------------
  -- SCL
  ---------------------------------------------------------------------
  -- In the SCL case, no signal is registered
  SCL : if kSCL generate
    pEnableOut  <= pEnableIn;
    pFlag       <= to_stdLogic((pFlagFromFifo = '1' or pDisableLoc or pStateDisable)
                               and pEnableIn);
    pDataOut    <= pDataOutFromFifo;
    pPushPopLoc <= pEnableIn when not kHandshaking else
                    (pHandshakingPushPopRequest and pEnableIn);
  end generate SCL; 
  ---------------------------------------------------------------------

  ---------------------------------------------------------------------
  --  NON SCL
  ---------------------------------------------------------------------
  -- In the non SCL case, signals need to be registered
  -- and the timeout needs to be handled
  NoSCL : if not kSCL generate

   -- Create a pulse on the rising_edge of pEnableIn
    Delayer1:process (aReset, PClk)
    begin
      if aReset then
        pEnableInDly <= false;
      elsif rising_edge(PClk) then
        pEnableInDly <= pEnableIn;
      end if;
    end process Delayer1;
    pEnableInPulse <= pEnableIn and not pEnableInDly;
  
   Timer: entity work.TimeoutManager (rtl)
     generic map(
        kWidth   => 32)
     port map(
        aReset   => aReset,
        Clk      => PClk,
        cStart   => pStartTimeout,
        cLimit   => pTimeout,
        cTimeout => pHasTimedOut);

    pStartTimeout <= to_StdLogic(pEnableInPulse);
    
    -- State Machine to handle the timeout
    NextState: process (pEnableInPulse, pHasTimedOut, pFlagFromFifo, pTimeoutState,
                        pStateDisable, pDisableLoc)
    begin
      pTimeoutNextState <= pTimeoutState;
      case (pTimeoutState) is
        when Idle =>
          if pEnableInPulse then
            if pFlagFromFifo = '1' or pStateDisable or pDisableLoc then
              pTimeoutNextState <= Waiting;
            else
              pTimeoutNextState <= Done;
            end if;
          end if;
        when Waiting =>
          if ((pFlagFromFifo='0' and not pStateDisable and not pDisableLoc) or 
            pHasTimedOut = '1') then
            pTimeoutNextState <= Done;
          end if;
        when Done =>
          pTimeoutNextState <= Idle;
        when others =>
          pTimeoutNextState <= Idle;
      end case;      
    end process;

    process (aReset, PClk)
    begin
      if aReset then
        pTimeoutState <= Idle;
      elsif rising_edge(PClk) then
        pTimeoutState <= pTimeoutNextState;
      end if;
    end process;

    -- Register the flag and data out from the resource on the EnableIn pulse
    RegisterOutputs:process (aReset, PClk)
    begin
      if aReset then
        pFlag    <= '0';
        pDataOut <= (others=>'0');
      elsif rising_edge(PClk) then
        if pTimeoutNextState = Done then
          pFlag    <= pFlagFromFifo or to_StdLogic(pDisableLoc) or 
                      to_StdLogic(pStateDisable);
          pDataOut <= pDataOutFromFifo;
        end if;
      end if;
    end process RegisterOutputs; 

    -- Assign PushPop to the Resource (just the pulse)
    -- I am using the NextState instead of the registered state because
    -- I don't want to waste a clock cycle, especially in the case
    -- when the Flag is not set and the Timeout is 0
    -- Also note that we will send a Push/Pop pulse even if we timeout 
    -- on a Full/Empty FIFO. Therefore, we depend on the FIFO to be
    -- configured in SafeMode.
    pPushPopLoc <= pTimeoutNextState = Done;                          
    
    
    -- Build bEnableOut
    EnableChain:process (aReset, PClk)
    begin
      if aReset then
        pEnableOut <= false;
      elsif rising_edge(PClk) then
        if pEnableClear then
          pEnableOut <= false;
        elsif pTimeoutNextState = Done then
          pEnableOut <= true;
        end if;
      end if;
    end process EnableChain;

  end generate NoSCL; 
  ---------------------------------------------------------------------

  ---------------------------------------------------------------------
  -- End of common code for input and output : Enable Chain
  ---------------------------------------------------------------------

  -- As this component is in control of unsetting the Reset bit in the 
  -- Reset register, we don't need to emulate a full enable chain for 
  -- the Clear signal sent to the ClearController
  -- We will not unset the Reset bit until the reset is fully done, 
  -- allowing us not to worry about a second enable_in before the 
  -- reset is complete.
  -- Along the same line, we will give priority to the unsetting of 
  -- the reset bit in the register against setting it from the host
  -- write: this will ensure that the enable_in bit is un asserted
  -- for at least one clock cycle after the reset is done.
  -- Therefore, we can use only the ResetBitFromRegister to 
  -- build enable_in and enable_clr.
  bEnableIn  <= bResetBitFromRegister;
  bEnableClr <= not bResetBitFromRegister;

  EnableOutDelayer:process (aReset, BusClk)
  begin
    if aReset then
      bEnableOutDly <= false;
    elsif rising_edge(BusClk) then
      bEnableOutDly <= bEnableOut;
    end if;
  end process EnableOutDelayer;
  bResetDone <= bEnableOut and not bEnableOutDly;
  

  ---------------------------------------------------------------------
  -- This component is used to handle the reset. It disables the push
  -- and pop port, resets the FIFO and re-enables the push and pop
  -- ports. 
  ---------------------------------------------------------------------
  Input:if kInput generate
    FifoClearController: entity work.NiFpgaFifoClearControl(rtl)
      generic map (
        kSingleCycleLoop        => false, 
        kClearPushClockCrossing => true, -- crossing in the input case
        kClearPopClockCrossing  => false,-- no crossing in the input case
        kPushPopClockCrossing   => true  -- BusClk to anything but not BusClk
      )
      port map(
        aReset        => aReset,
        IClk          => PClk,
        OClk          => BusClk,
        CClk          => BusClk,
        iDisablePush  => pDisableLoc,
        iPushDisabled => pDisableLoc,
        oDisablePop   => bDisablePortWrapBack, -- this port will be disabled through 
        oPopDisabled  => bDisablePortWrapBack, -- the registers
        cEnableIn     => bEnableIn,
        cEnableClr    => bEnableClr,
        cEnableOut    => bEnableOut,
        iReset        => pResetForFifo,
        oReset        => bResetForFifo
      );
  end generate Input;
  
  Output:if not kInput generate
    FifoClearController: entity work.NiFpgaFifoClearControl(rtl)
      generic map (
        kSingleCycleLoop        => false, 
        kClearPushClockCrossing => false,-- no crossing in the output case
        kClearPopClockCrossing  => true, -- crossing in the output case
        kPushPopClockCrossing   => true  -- BusClk to anything but not BusClk
      )
      port map(
        aReset        => aReset,
        IClk          => BusClk,
        OClk          => PClk,
        CClk          => BusClk,
        iDisablePush  => bDisablePortWrapBack, -- this port will be disabled through 
        iPushDisabled => bDisablePortWrapBack, -- the registers
        oDisablePop   => pDisableLoc,
        oPopDisabled  => pDisableLoc,
        cEnableIn     => bEnableIn,
        cEnableClr    => bEnableClr,
        cEnableOut    => bEnableOut,
        iReset        => bResetForFifo,
        oReset        => pResetForFifo
      );
  end generate Output;
  ---------------------------------------------------------------------

end rtl;



