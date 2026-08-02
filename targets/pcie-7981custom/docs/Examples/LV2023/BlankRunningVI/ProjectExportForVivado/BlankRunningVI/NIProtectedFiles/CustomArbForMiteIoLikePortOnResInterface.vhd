-------------------------------------------------------------------------------
--
-- File: RegisterFmWk.vhd
-- Author: Gregory Voirin
-- Original Project: LvFpga Register Read/Write 32 bits
-- Date: 9 July 2004
--
-------------------------------------------------------------------------------
-- (c) 2004 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--
-------------------------------------------------------------------------------

library IEEE;
  use IEEE.std_logic_1164.all;
  use IEEE.numeric_std.all;

library work;
  use work.PkgCommunicationInterface.all;

entity CustomArbForMiteIoLikePortOnResInterface is
  generic (
    kNumResholders : POSITIVE := 1;
    kResWidthIn : NATURAL := 34;
    kResWidthOut : NATURAL := 51;
    kResName : STRING := "Interface";
    kResPortName : STRING := "MiteIoLike"
  );

  port (
   Clk : in std_logic ;
   reset : in std_logic ;
   interfaceClockToRes : out std_logic_vector(kResWidthIn-1 downto 0);
   interfaceClockFromRes : in std_logic_vector(kResWidthOut-1 downto 0);
   interfaceClockFromResholder00000000 : in std_logic_vector(kResWidthIn-1 downto 0);
   interfaceClockToResholder00000000 : out std_logic_vector(kResWidthOut-1 downto 0)
  );
end entity CustomArbForMiteIoLikePortOnResInterface;

architecture rtl of CustomArbForMiteIoLikePortOnResInterface is

  signal interfaceClockRegPortIn : RegPortIn_t;
  signal interfaceClockRegPortOut : RegPortOut_t;
  signal interfaceClockRegPortOutArray : RegPortOutArray_t(0 to kNumResHolders - 1);

begin

  interfaceClockRegPortIn <= BuildRegPortIn( interfaceClockFromRes);
  interfaceClockToRes <= to_StdLogicVector( interfaceClockRegPortOut);
   interfaceClockRegPortOut <= SelectPort( interfaceClockRegPortOutArray);

  -- For each ResHolder
   interfaceClockRegPortOutArray(0) <= BuildRegPortOut( interfaceClockFromResholder00000000);
   interfaceClockToResholder00000000 <=  interfaceClockFromRes;

end rtl;
