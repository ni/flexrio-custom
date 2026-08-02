library ieee;
use ieee.std_logic_1164.all;
use work.PkgNiFpgaSimDma.all;
use work.PkgCommIntConfiguration.all;

package PkgNiFpgaSimulationModel is

  macro_DmaChannelConstants

  ---------------------------------------------------------------------------------------
  -- tInputClocks
  -- Includes any input clocks to the simulation model. Use the test bench to drive
  -- these clocks. Because the FPGA VI design determines the frequency of these clocks,
  -- do not modify the frequency manually.
  ---------------------------------------------------------------------------------------
  type tInputClocks is record
    macro_Define_tInputClocks
  end record tInputClocks;

  ---------------------------------------------------------------------------------------
  -- tDiagramClocks
  -- Includes all clocks that the simulation model uses. tDiagramClocks includes:
  -- * clocks in the LabVIEW FPGA VI block diagram
  -- * clocks in CLIP and the IP Integration Node
  ---------------------------------------------------------------------------------------

  type tDiagramClocks is record
    macro_Define_tDiagramClocks
    
  end record tDiagramClocks;

  ---------------------------------------------------------------------------------------
  -- Target Specific Constants
  ---------------------------------------------------------------------------------------
  macro_BusInterfaceConstants
    constant kFpgaTargetSupportsIrqs : boolean := TRUE;


  ---------------------------------------------------------------------------------------
  -- BusClk and fiClock Period
  ---------------------------------------------------------------------------------------
  macro_SimulationClockConstants  
  
  ---------------------------------------------------------------------------------------
  -- Utility Functions
  ---------------------------------------------------------------------------------------
    function GetFifoWidth(ChannelNumber : natural) return natural;
  constant kDmaChannelConfigArray : tDmaChannelConfigArray;


end package PkgNiFpgaSimulationModel;

package body PkgNiFpgaSimulationModel is

    ---------------------------------------------------------------------------------------
  -- GetFifoWidth
  --
  -- Determine the actual width of the data as it is transferred on the bus.  Note that
  -- this could differ from the size it is represented as on the FPGA.
  ---------------------------------------------------------------------------------------
  function GetFifoWidth(ChannelNumber : natural) return natural is
  begin
    
    -- For CHInCh, FXP types are always transferred as 64 bits.
    if kDmaFifoConfArray(ChannelNumber).FxpType then
      return 64;
    end if;
    
    -- If it is not a FXP type, it is rounded up to 8, 16, 32, or 64 bits.
    if kDmaFifoConfArray(ChannelNumber).FifoWidth <= 8 then
      return 8;
    elsif kDmaFifoConfArray(ChannelNumber).FifoWidth <= 16 then
      return 16;
    elsif kDmaFifoConfArray(ChannelNumber).FifoWidth <= 32 then
      return 32;
    else
      return 64;
    end if;
    
  end function GetFifoWidth;

  function ReturnDmaChannelConfigArray return tDmaChannelConfigArray is
    variable ret : tDmaChannelConfigArray(kDmaFifoConfArray'range) := 
      (others => (Mode      => None,
                  FifoWidth => 0));
  begin

    for i in kDmaFifoConfArray'range loop
    
      case kDmaFifoConfArray(i).Mode is
        when Disabled =>  ret(i).Mode := None;
        when NiFpgaTargetToHost | NiCoreTargetToHost =>
          ret(i).Mode := TargetToHost;
        when NiFpgaHostToTarget | NiCoreHostToTarget =>
          ret(i).Mode := HostToTarget;
        when others =>
          ret(i).Mode := None;
      end case;
      
      ret(i).FifoWidth := GetFifoWidth(i);
      
    end loop;
    return ret;
  end function ReturnDmaChannelConfigArray;

  constant kDmaChannelConfigArray : tDmaChannelConfigArray := ReturnDmaChannelConfigArray;


end package body PkgNiFpgaSimulationModel;
