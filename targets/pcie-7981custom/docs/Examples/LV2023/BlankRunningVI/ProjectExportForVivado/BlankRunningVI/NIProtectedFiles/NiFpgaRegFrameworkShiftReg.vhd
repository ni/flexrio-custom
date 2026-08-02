-------------------------------------------------------------------------------
--
-- File: NiFpgaRegFrameworkShiftReg.vhd
-- Author: gregory
-- Original Project: Shift Register Component for Register Framework
-- Date: 5 October 2004
--
-------------------------------------------------------------------------------
-- (c) 2009 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--   The shift register component used in the LvFpga interface to access
--   registers wider than the bus
--
-- Generics:
--   kRegWidth     : The maximum width on the register side
--
--   kBusWidth     : The width on the bus side
--
--   kCounterWidth : It should be log2(ceil(kRegWidth/kBusWidth))
--                   This counter represents the number of bus transactions
--                   necessary to access the widest wide register
--
-- Ports:
--   aReset          : Asynchronously resets all the flip flops.
--                     It is the asynchronous reset for the "Clock"  
--                     clock domain.  For example, for the signature  
--                     register, this is aBusReset if the bus supports 
--                     asynchronous reset.  For  others, it's typically 
--                     aDiagramReset. 
--
--   aBusReset       : Asynchronously asserts when the bus or the host
--                     processor is reset.
--
--                     aBusReset is synchronized to the "Clock" domain 
--                     and used to put the design in the same state as 
--                     an assertion of aReset.  This module assumes that  
--                     aBusReset will assert for at least one period of 
--                     ReliableClk.
--
--   Clock           : Standard clock signal.
--
--   ReliableClk     : The clock that is guaranteed to always be
--                     toggling.
--
--   cCount          : Number of bus accesses needed to read or write a
--                     wide register. NOTE : when reading, the count is the
--                     number minus 1, as we use the first read to handle the
--                     loading and we are outputing the most significant bits
--                     at the same time. Width is controlled by kCounterWidth
--                     generic.
--
--   cBusRead        : This indicates bus read access to a wide register.
--                     This should be a 1 clock cycle pulse.
--
--   cBusWrite       : This indicates bus write access to a wide register.
--                     This should be a 1 clock cycle pulse.
--
--   cBusDataIn      : Bus Write data. Width is controlled by kBusWidth generic.
--
--   cBusDataOut     : Bus Read data. Width is controlled by kBusWidth generic.
--
--   cBusDataOutValid: This is asserted for 1 clock cycle to indicate
--                     validity of cBusDataOut port.
--
--   cRegRead        : This is asserted for 1 clock cycle to indicate
--                     read access to a wide register.
--
--   cRegWrite       : This is asserted for 1 clock cycle to indicate
--                     write access to a wide register.
--
--   cRegDataIn      : Register Read data. Width is controlled by kRegWidth
--                     generic.
--
--   cRegDataInValid : This indicates validity of cRegDataIn port.
--                     It should be a 1 clock cycle pulse.
--
--   cRegDataOut     : Register Write data. Width is controlled by kRegWidth
--                     generic.
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--StaticVHDL Component
  
library work;
  use work.PkgNiUtilities.all;

entity NiFpgaRegFrameworkShiftReg is
  generic(
    kRegWidth     : positive := 64;
    kBusWidth     : positive := 16;
    kCounterWidth : positive := 2
  );
  port(
    aReset          : in boolean;
    aBusReset       : in boolean;

    Clock           : in std_logic;
    ReliableClk     : in std_logic;

    cCount          : in unsigned(kCounterWidth - 1 downto 0);
    cBusRead        : in boolean;
    cBusWrite       : in boolean;
    cBusDataIn      : in  std_logic_vector(kBusWidth - 1 downto 0);
    cBusDataOut     : out std_logic_vector(kBusWidth - 1 downto 0);
    cBusDataOutValid: out boolean;
    cRegRead        : out boolean;
    cRegWrite       : out boolean;
    cRegDataIn      : in  std_logic_vector(kRegWidth - 1 downto 0);
    cRegDataInValid : in boolean;
    cRegDataOut     : out std_logic_vector(kRegWidth - 1 downto 0)
  );
end entity NiFpgaRegFrameworkShiftReg;

architecture rtl of NiFpgaRegFrameworkShiftReg is

  -- To make things readable
  constant kShiftRegWidth : positive := kRegWidth - kBusWidth;

  -- The Shift Register : note that to save on area, the shift register is
  -- not as wide as the widest register but kBusWidth bits smaller
  signal cShiftReg : std_logic_vector(kShiftRegWidth - 1 downto 0) := (others=>'0');

  -- The counter : its width depends on  the maximum number of bus accesses
  -- needed to read and write the widest register connected
  signal cCounter : unsigned(kCounterWidth - 1 downto 0) := (others=>'0');

  -- The signals that controls the shift register and the counter
  signal cLoad  : boolean;
  signal cDone  : boolean;
  signal cShift : boolean;

  -- The signals specific to the read and to the write (used to build
  -- the generic signals above)
  signal cWriteShift : boolean;
  signal cReadShift : boolean := false;

  signal rBusReset : boolean;
  signal cBusReset : boolean;

begin

  -- aBusReset theory of operation:
  --
  -- When aBusReset asserts, we reset portions of the register  
  -- interface.  In particular, the shift register component 
  -- (NiFpgaRegFrameworkShiftReg.vhd) needs to be reset in case we were 
  -- in the middle of accessing a control or indicator that is wider 
  -- than 32 bits when aBusReset asserted.  Otherwise, the shift  
  -- register would be in an unknown state when the host comes out of  
  -- reset. 
  --
  -- This module synchronizes aBusReset to the "Clock" domain and uses 
  -- cBusReset to synchronously put the module in the same state as an 
  -- assertion of aReset.  The reason for translating aBusReset to 
  -- cBusReset instead of just using it asynchronously is to avoid 
  -- introducing extra reset domain boundaries.  For example, for 
  -- controls and indicators this component's aReset is driven by 
  -- aDiagramReset, which is also used as the asynchronous reset for the 
  -- rest of the VI logic.  Using "aReset or aBusReset" as an 
  -- asynchronous reset within this component would introduce a reset 
  -- domain boundary between this component and the rest of the VI 
  -- logic.
  --
  -- The obvious thing to do is just double-synchronize aBusReset to  
  -- the clock domain associated with controls/indicators.  The issue is 
  -- more complicated for controls/indicators synchronous to an external 
  -- clock because such a clock may not be toggling when aBusReset 
  -- asserts.  In that case, a double-synchronizer might never sample 
  -- aBusReset while it is asserted.  A related corner case is if the 
  -- destination clock domain has a long period compared to the pulse 
  -- width of aBusReset.
  --
  -- To deal with this risk, we double-synchronize aBusReset to the 
  -- reliable clock domain, and then use the PulseSync component to 
  -- transmit the pulse on rBusReset to the control/indicator clock 
  -- domain.  It would probably be more intuitive to double-synchronize 
  -- aBusReset to the bus clock domain, and pulse-sync from the bus 
  -- clock to the control/indicator clock, since that would use a total 
  -- of two clocks instead of three.  That would work as long as we're 
  -- guaranteed that the bus clock will toggle while aBusReset is 
  -- asserted.  While we know that to be the case for MITE-based 
  -- designs, we'd need to verify that assumption separately for each 
  -- current and future target.  The solution we've selected does not 
  -- assume that the bus clock toggles while aBusReset is asserted.  One 
  -- remaining assumption is that aBusReset will assert for more than 
  -- one period of ReliableClk. 
  --
  -- We've chosen aReset as the asynchronous reset to the 
  -- synchronization circuit.  There are two cases to consider:  the 
  -- signature register and controls/indicators.  
  --
  -- The signature register for MITE targets uses 
  -- NiFpgaRegFrameworkShiftReg with Clock connected to the bus clock 
  -- and with aReset driven by aBusReset.  In that case, aBusReset 
  -- asynchronously resets everything in this component so there's no 
  -- need to translate aBusReset to cBusReset.  That configuration will 
  -- introduce a race condition at the input to the double synchronizer:  
  -- the data input and the asynchronous input will be unasserting 
  -- simultaneously.  If the reset unassertion completes first, the 
  -- double synchronizer might produce a one clock cycle assertion on 
  -- its output signal, which will result in a short assertion of 
  -- cBusReset a few clock cycles later.  That synchronous reset shortly 
  -- after an asynchronous reset will be unnecessary but harmless.
  --
  -- The signature register for Chinch targets connects aReset to false, 
  -- but aBusReset is driven by the bus reset.  In that case, aBusReset 
  -- will be synchronized to cBusReset and the shift register will be 
  -- synchronously initialized.
  --
  -- For controls/indicators, aReset will be connected to aDiagramReset.  
  -- The case in which aBusReset asserts but aDiagramReset does not 
  -- assert is the main purpose for the following synchronization 
  -- components as described above.  When aDiagramReset asserts, every 
  -- part of this component, including the following synchronization 
  -- components, will be asynchronously cleared, which will cause the 
  -- circuit to forget about any recent assertions of aBusReset.  aReset 
  -- and cBusReset put the design in the same state, so it's harmless 
  -- for aDiagramReset to abort the process of synchronizing aBusReset 
  -- to cBusReset.
  --
  -- aDiagramReset asserts following FPGA configuration and in response 
  -- to a call to the host reset method.  The driver should prevent a 
  -- call to the host reset method from interrupting an access to a wide 
  -- register, so any time aDiagramReset asserts we know that the shift 
  -- register counter will already be 0 -- as a result, there is no risk 
  -- that the host will lose track of the current state of the shift 
  -- register following an assertion of aDiagramReset.
  SyncToReliableClk : entity work.DoubleSyncBoolAsyncIn (rtl)
    port map (
      aSig              => aBusReset,
      aOReset           => aReset,
      OClk              => ReliableClk,
      oSig              => rBusReset);

  SyncBusReset: entity work.PulseSyncBool (behavior)
    port map (
      aReset            => aReset,
      IClk              => ReliableClk,
      iSig              => rBusReset,
      OClk              => clock,
      oSig              => cBusReset);


  -- ReadBlk: -----------------------------------------------------------------
  -- Building the signals that handle the reads
  -----------------------------------------------------------------------------
  ReadBlk : block
      signal cQualifiedReadPulse : boolean;
      signal cRegReadLoc : boolean := false;
    begin

      -- The Read signal minus the first access which is used to load the
      -- shift register and the counter
      -- This signal is glitchy but we are using only the delayed version
      -- which is glitch free as it is the output of a flip-flop
      cQualifiedReadPulse <= cRegDataInValid when cDone else cBusRead;

      -- ReadShift: -----------------------------------------------------------
      -- When Reading, we only want to shift if this is not the first
      -- access (so we use cQualifiedReadPulse)
      -- NOTE : we need one cycle to enable the data on the bus side before
      -- shifting the register, and we need to remove the potential glitch
      -- on cQualifiedReadPulse. This flip-flop solves both issues.
      -------------------------------------------------------------------------
      ReadShift : process (aReset, Clock)
      begin
        if aReset then
          cReadShift <= false;
        elsif rising_edge(Clock) then
          if cBusReset then
            cReadShift <= false;
          else
            cReadShift <= cQualifiedReadPulse;
          end if;
        end if;
      end process ReadShift;

      cBusDataOutValid <= cRegDataInValid or cReadShift;

      -- RegRead: -------------------------------------------------------------
      -- The flip-Flop has been added to remove the critical path due to the
      -- combinatorial path from the Read input to the RegRead output
      -------------------------------------------------------------------------
      RegRead : process (aReset, Clock)
      begin
        if aReset then
          cRegReadLoc <= false;
        elsif rising_edge(Clock) then
          if cBusReset then
            cRegReadLoc <= false;
          else
            cRegReadLoc <= cBusRead and cDone;
          end if;
        end if;
      end process RegRead;

      cRegRead <= cRegReadLoc;

  end block ReadBlk;

  -- WriteBlk: ----------------------------------------------------------------
  -- Building the signals that handle the writes
  -----------------------------------------------------------------------------
  WriteBlk : block
      signal cDelayedWritePulse1, cDelayedWritePulse2 : boolean := false;
    begin

      -- WriteDelayer: --------------------------------------------------------
      -- We are considering the various actions that can be taken in
      -- sequence (load, shift, write). See documentation for further details
      -------------------------------------------------------------------------
      WriteDelayer : process (aReset, Clock)
      begin
        if aReset then
          cDelayedWritePulse1 <= false;
          cDelayedWritePulse2 <= false;
        elsif rising_edge(Clock) then
          if cBusReset then
            cDelayedWritePulse1 <= false;
            cDelayedWritePulse2 <= false;
          else
            cDelayedWritePulse1 <= cBusWrite;
            cDelayedWritePulse2 <= cDelayedWritePulse1;
          end if;
        end if;
      end process WriteDelayer;

      -- The pulse to shift the register and decrement the counter
      cWriteShift <= cDelayedWritePulse2 and not(cDone);

      -- Even if a comparison to one is usually not optimun, the rest of
      -- the logic is now so simplified that it is worth it.
      cRegWrite <= cDelayedWritePulse1 and (cCounter = 1);

  end block WriteBlk;

  -- NoShift: -----------------------------------------------------------------
  -- We need to handle the case when the register width is only twice the
  -- bus width because the shift register will be of the bus width
  -- and no shifting can occur
  -- Otherwise, let the shifting occur
  -----------------------------------------------------------------------------
  NoShift : if (kBusWidth >= kShiftRegWidth) generate

    -- ShiftReg: --------------------------------------------------------------
    -- The Shift Register.
    -- cBusReset has been removed from this register by design. Synchronously
    -- reseting this register would be redundant (as the state registers are
    -- also being reset), and would also use additional resources.
    ---------------------------------------------------------------------------
    ShiftReg : process (aReset, Clock)
    begin
      if aReset then
        cShiftReg <= (others=>'0');
      elsif rising_edge(Clock) then
        if cShift then
          cShiftReg(kShiftRegWidth - 1 downto 0) <=
            cBusDataIn(kBusWidth - 1 downto 0);
        elsif cRegDataInValid then
          cShiftReg <= cRegDataIn(kShiftRegWidth -1 downto 0);
        end if;
      end if;
    end process ShiftReg;

  end generate NoShift;

  -- Shifting: ----------------------------------------------------------------
  -- Standard case with shifting.
  -----------------------------------------------------------------------------
  Shifting : if (kShiftRegWidth > kBusWidth) generate

    -- ShiftReg: --------------------------------------------------------------
    -- The Shift Register.
    -- cBusReset has been removed from this register by design. Synchronously
    -- reseting this register would be redundant (as the state registers are
    -- also being reset), and would also use additional resources.
    ---------------------------------------------------------------------------
    ShiftReg : process (aReset, Clock)
    begin
      if aReset then
        cShiftReg <= (others=>'0');
      elsif rising_edge(Clock) then
        if cShift then
          cShiftReg(kShiftRegWidth - 1 downto kBusWidth) <=
            cShiftReg(kShiftRegWidth - kBusWidth - 1 downto 0);
          cShiftReg(kBusWidth - 1 downto 0) <= cBusDataIn(kBusWidth - 1 downto 0);
        elsif cRegDataInValid then
          cShiftReg <= cRegDataIn(kShiftRegWidth -1 downto 0);
        end if;
      end if;
    end process ShiftReg;

  end generate Shifting;

  -- CounterProcess: ----------------------------------------------------------
  -- Counter
  -----------------------------------------------------------------------------
  CountProcess : process (aReset, Clock)
  begin
    if aReset then
      -- It is very important to reset the counter to 0 in order for
      -- the first access to be considered as a first read or a first write
      cCounter <= (others=>'0');
    elsif rising_edge(Clock) then
      if cBusReset then
        cCounter <= (others=>'0');
      else
        if cLoad then
          -- Load the counter
          cCounter <= cCount;
        elsif not(cDone) and cShift then
          -- Count down if counter is not 0
          cCounter <= cCounter - 1;
        end if;
      end if;
    end if;
  end process CountProcess;

  -- The current access is done
  cDone <= (cCounter = 0);

  -- The pulse to load the register
  cLoad <= (cBusWrite or cBusRead) and cDone;

  -- The shift signal used by the shift register
  cShift <= (cWriteShift or cReadShift);

  -- Output to the register
  cRegDataOut <= cShiftReg & cBusDataIn;

  -- Aligned: -----------------------------------------------------------------
  -- Output to the bus
  -----------------------------------------------------------------------------
  Aligned:if kShiftRegWidth > (kBusWidth - 1) generate
    cBusDataOut <= cRegDataIn(kRegWidth - 1 downto kRegWidth - kBusWidth)
                    when cRegDataInValid
                    else cShiftReg(kShiftRegWidth - 1 downto kShiftRegWidth - kBusWidth);
  end generate Aligned;

  -- Because this assertion is based only on constants, there is no need 
  -- to use translate_off/on comments.  By omitting the translate_off/on 
  -- comments, the synthesizer can, through an error, communicate if the 
  -- assertion fails.
  --
  -- This assertion verifies that the counter is wide enough.  We access 
  -- wide registers with multiple bus transactions, each transferring 
  -- kBusWidth bits each.  To transfer all the register bits in a wide 
  -- register, we must count the bus transactions until the total number 
  -- of bits matches or exceeds the number of bits in the register.  To 
  -- access the widest register in the design, the counter must be large 
  -- enough such that the largest counter value multiplied by the number 
  -- of bits accessed per bus transaction must match or exceed the 
  -- number of bits in the widest register:
  assert ((2**kCounterWidth)-1) -- maximum number of accesses
         * kBusWidth            -- Number of bits per bus transaction
         >= kRegWidth           -- Number of bits in the widest register
    report "error in generic map:  counter not big enough to shift " &
           "largest register."
    severity FAILURE;

end architecture rtl;
