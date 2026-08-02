-------------------------------------------------------------------------------
--
-- File: DFlopFallingEdge.vhd
-- Author: Tamas Gyorfi
-- Original Project: Vivado support for 7-series LabVIEW FPGA targets
-- Date: 16 July 2013
--
-------------------------------------------------------------------------------
-- (c) 2013 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--    This creates a falling-edge flip-flop using either the FDCE or FDPE Xilinx
--    primitives, depending on the desired async. reset value of the Flop.
--    The implementation described in this component is specific to Vivado,
--    since Vivado no longer supports the FDCPE primitive on newer FPGAs (>V6).
--
--    The kAsyncReg generic is helping to set the ASYNC_REG attribute 
--    for the instantiated FDCE or FDPE primitives. 
--    This cannot be done from the upper levels where the DFlop is instantiated,
--    since the attribute can not propagate from the net to his driver FF. 
--    We set the default value to "false" so the already existing instances 
--    would not require to be updated.             

--    The ASYNC_REG attribute affects optimization, placement, and routing to improve Mean 
--    Time Between Failure (MTBF) for registers that may go metastable. If ASYNC_REG is applied, 
--    the placer will ensure the flip-flops on a synchronization chain are placed closely to 
--    maximize MTBF. Registers with ASYNC_REG that are directly connected will be grouped and 
--    placed together into a single SLICE, assuming they have a compatible control set and the 
--    number of registers does not exceed the available resources of the SLICE    
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;

library work;
  use work.PkgNiUtilities.all;

library UNISIM;
  use UNISIM.vcomponents.all;

entity DFlopFallingEdge is
  generic (kResetVal : std_logic := '0';
           kAsyncReg : string := "false");
  port (
    aReset, cEn  : in boolean;
    Clk, cD   : in std_logic;
    cQ   : out std_logic := kResetVal
  );
end DFlopFallingEdge;

architecture rtl of DFlopFallingEdge is
  attribute ASYNC_REG : string;
begin

  -- This VScan model helps VScan analyze this as a flip-flop and not
  -- be fooled by the delta delay that occurs on the PRE and CLR signals.
  GenVScanModel: if false generate
    process (aReset, Clk)
    begin
      if aReset then
        cQ <= '0';
      elsif falling_edge(Clk) then
        if cEn then cQ <= cD; end if;
      end if;
    end process;
  end generate GenVScanModel;

  --vscan vscan_off
  
  -- !!NOTE:
  -- If you change the instance names in this component, consider updating
  -- DFlop module generator as well: vi.lib\rvi\nicores\ClockBoundaryCrossing\DFlopBaseniFpgaDflopInstanceName.vi
    
  GenClr: if kResetVal='0' generate
    attribute ASYNC_REG of ClearFDCPEx : label is kAsyncReg;
    begin
  
    --vhook_i FDCE_1 ClearFDCPEx
    --vhook_a INIT '0'
    --vhook_a CLR To_StdLogic(aReset)
    --vhook_a C Clk
    --vhook_a CE To_StdLogic(cEn)
    --vhook_a D cD
    --vhook_a Q cQ
    ClearFDCPEx: FDCE_1
      generic map (
        INIT => '0')  -- in  bit := '0'
      port map (
        CLR => To_StdLogic(aReset),  -- in  std_logic
        C   => Clk,                  -- in  std_logic
        CE  => To_StdLogic(cEn),     -- in  std_logic
        D   => cD,                   -- in  std_logic
        Q   => cQ);                  -- out std_logic
  
  end generate GenClr;
  
  GenSet: if kResetVal='1' generate
    attribute ASYNC_REG of PresetFDCPEx : label is kAsyncReg;
    begin     
  
    --vhook_i FDPE_1 PresetFDCPEx
    --vhook_a INIT '1'
    --vhook_a PRE To_StdLogic(aReset)
    --vhook_a C Clk
    --vhook_a CE To_StdLogic(cEn)
    --vhook_a D cD
    --vhook_a Q cQ
    PresetFDCPEx: FDPE_1
      generic map (
        INIT => '1')  -- in  bit := '1'
      port map (
        PRE => To_StdLogic(aReset),  -- in  std_logic
        C   => Clk,                  -- in  std_logic
        CE  => To_StdLogic(cEn),     -- in  std_logic
        D   => cD,                   -- in  std_logic
        Q   => cQ);                  -- out std_logic
  
  end generate GenSet;

  --vscan vscan_on

end rtl;
