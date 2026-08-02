-------------------------------------------------------------------------------
--
-- File: NiFpgaPipelinedOrGateTreeSlv.vhd
-- Author: Wenxun Huang
-- Original Project: Optimizing Control/Indicator Access logic
-- Date: August 2011
--
-------------------------------------------------------------------------------
-- (c) 2011 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
-- The or gate component is used in LvFpga reg interface to optimize the timing
-- when very wide or gate is used. Results are calculated for every kMaxFanIn
-- number of input vectors and registered before sent to the next level, so
-- that the compiler won't need to route all signals to one place, hopefully
-- reducing the difficulty for P&R.
-- This component takes a std_logic_vector and computes the or of all its bits.
-- It's similar to OrVector except that it is staged. Use kMaxFanIn to specify 
-- the maximum fanin allowed for each OR gate.
-- Due to the limitation of VHDL standard prior to 2008, variable array element
-- size is not allowed. If the elements to be ORed are not single bits, use
-- a for-generate statement to instantiate this component for every bit of the
-- input signals.
-------------------------------------------------------------------------------

library ieee, work;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.PkgNiUtilities.all;

entity NiFpgaPipelinedOrGateTreeSlv is
  generic(
    kMaxFanIn  : positive := 6
  );
  port(
    aReset     : in boolean;

    Clock      : in std_logic;
    cSignalsIn : in std_logic_vector;
    cSignalOut : out std_logic
  );
end entity NiFpgaPipelinedOrGateTreeSlv;

architecture rtl of NiFpgaPipelinedOrGateTreeSlv is

  constant kInputLength : positive := cSignalsIn'length;
  -- Ceiling division of kInputLength/kMaxFanIn
  constant kNumberOfGroups: positive := 1+(kInputLength-1)/kMaxFanIn;

  signal cSignalsInLoc : std_logic_vector(kInputLength-1 downto 0);
  signal cAryToNextStageNx, cAryToNextStage : std_logic_vector(kNumberOfGroups-1 downto 0);
  
begin

  -- Adjust the range of input array 
  cSignalsInLoc <= cSignalsIn;

  -- OR operation on every kMaxFanIn number of inputs to produce output
  -- vector.
  Reducer : process(cSignalsInLoc) is
    variable OutputVecs : std_logic_vector(kNumberOfGroups-1 downto 0);
  begin

    OutputVecs := (others => '0');
    for i in cSignalsInLoc'range loop
      OutputVecs(i / kMaxFanIn) := OutputVecs(i / kMaxFanIn) or cSignalsInLoc(i);
    end loop;
    cAryToNextStageNx <= OutputVecs;
  end process Reducer;

  -- Register results before sending to the next OR gate level
  Pipeline : process(aReset, Clock)
  begin
    if aReset then
      cAryToNextStage <= (others => '0');
    elsif rising_edge(Clock) then
      cAryToNextStage <= cAryToNextStageNx;
    end if;
  end process Pipeline;

  MoreLevels: if kNumberOfGroups > 1 generate

    --vhook_e NiFpgaPipelinedOrGateTreeSlv
    --vhook_p cSignalsIn cAryToNextStage 
    NiFpgaPipelinedOrGateTreeSlvx: entity work.NiFpgaPipelinedOrGateTreeSlv (rtl)
      generic map (
        kMaxFanIn => kMaxFanIn)
      port map (
        aReset     => aReset,
        Clock      => Clock,
        cSignalsIn => cAryToNextStage,
        cSignalOut => cSignalOut);
        
  end generate MoreLevels;

  ProduceOutput: if kNumberOfGroups = 1 generate
    cSignalOut <= cAryToNextStage(0);
  end generate ProduceOutput;
  
  -- Error checking
  assert kInputLength > 0
    report "Input vector must not be empty!"
    severity failure;

  assert kMaxFanIn > 1
    report "Maximum fan-in must be at least 2!"
    severity failure;

end architecture rtl;
