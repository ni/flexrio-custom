-------------------------------------------------------------------------------
--
-- File: NiSharedHostRegisterArray.vhd
--
-------------------------------------------------------------------------------
-- (c) 2025 Copyright National Instruments Corporation
-- 
-- SPDX-License-Identifier: MIT
-------------------------------------------------------------------------------
--
-- Purpose:
-- This entity builds a bank of kNumRegisters independent 32-bit shared registers,
-- each implemented by one NiSharedHostRegister instance.
--
-- Addressing/model:
-- - Register i is placed at byte address: kBaseAddress + (4 * i).
-- - All generated registers observe the same host bus inputs (bRegPortIn).
-- - Only the addressed register responds to a given host transaction.
--
-- Per-register configuration:
-- - kDefault(i) sets the reset/default value for register i.
-- - kReadOnly(i) controls whether host writes are blocked for register i.
-- - kUseFpgaAck(i) controls per-register Ready/ack handshake behavior.
-- - Assertions enforce that these arrays are indexed 0..kNumRegisters-1.
--
-- FPGA-side interface:
-- - bFpgaWrite(i), bFpgaDataIn(i), bFpgaDataOut(i), bFpgaHostWrite(i), and
--   bFpgaAck(i) are routed 1:1 to register i.
-- - This allows FPGA logic to control and observe each register independently.
--
-- Host-side aggregated output behavior:
-- - Data is the bitwise OR of all register Data outputs.
-- - DataValid is the OR of all register DataValid outputs.
-- - Ready is the AND of all register Ready outputs.
--
-- Since only one register should be addressed per transaction, OR-reduction of
-- Data/DataValid provides a single shared response bus while preserving behavior.
--
-------------------------------------------------------------------------------

library IEEE;
  use IEEE.std_logic_1164.all;
  use IEEE.numeric_std.all;
  
library work;
  use work.PkgNiUtilities.all;
  use work.PkgCommunicationInterface.all;
  
entity NiSharedHostRegisterArray is
  generic(
    kMaxHdlRegOffset : natural;
    kNumRegisters : natural;
    kBaseAddress : natural;
    kDefault : Slv32Ary_t;
    kReadOnly : BooleanVector;
    kUseFpgaAck : BooleanVector
  );
  port(
    BusClk : in std_logic;
    aReset : in boolean;

    -- Host Register Access
    bRegPortIn  : in RegPortIn_t;
    bRegPortOut : out RegPortOut_t;    

    -- FPGA Register Access (array for kNumRegisters)
    bFpgaHostWrite : out BooleanVector(0 to kNumRegisters-1);
    bFpgaAck : in BooleanVector(0 to kNumRegisters-1);
    bFpgaWrite  : in BooleanVector(0 to kNumRegisters-1);
    bFpgaDataIn : in Slv32Ary_t(0 to kNumRegisters-1);
    bFpgaDataOut : out Slv32Ary_t(0 to kNumRegisters-1)
  );  
end entity NiSharedHostRegisterArray;

architecture rtl of NiSharedHostRegisterArray is

  type RegPortOutArray_t is array (natural range <>) of RegPortOut_t;
  signal bRegPortOutArray : RegPortOutArray_t(0 to kNumRegisters-1);

begin

  -- Generic consistency checks
  assert kDefault'left = 0 and kDefault'length = kNumRegisters
    report "kDefault must be indexed 0 to kNumRegisters-1"
    severity failure;
  assert kReadOnly'left = 0 and kReadOnly'length = kNumRegisters
    report "kReadOnly must be indexed 0 to kNumRegisters-1"
    severity failure;
  assert kUseFpgaAck'left = 0 and kUseFpgaAck'length = kNumRegisters
    report "kUseFpgaAck must be indexed 0 to kNumRegisters-1"
    severity failure;

  -- Generate instances of NiSharedHostRegister
  GenRegisters: for i in 0 to kNumRegisters-1 generate
    RegInst: entity work.NiSharedHostRegister
      generic map(
        kMaxHdlRegOffset => kMaxHdlRegOffset,
        kOffset => kBaseAddress + (4 * i),
        kDefault => kDefault(i),
        kReadOnly => kReadOnly(i),
        kUseFpgaAck => kUseFpgaAck(i)
      )
      port map(
        BusClk         => BusClk,
        aReset         => aReset,
        bRegPortIn     => bRegPortIn,
        bRegPortOut    => bRegPortOutArray(i),
        bFpgaHostWrite => bFpgaHostWrite(i),
        bFpgaAck       => bFpgaAck(i),
        bFpgaWrite     => bFpgaWrite(i),
        bFpgaDataIn    => bFpgaDataIn(i),
        bFpgaDataOut   => bFpgaDataOut(i)
      );
  end generate GenRegisters;

  -- Combine register outputs using OR reduction for Data/DataValid, AND reduction for Ready
  CombineOutputs: process(bRegPortOutArray)
    variable vCombinedData : std_logic_vector(31 downto 0);
    variable vCombinedValid : boolean;
    variable vCombinedReady : boolean;
  begin
    vCombinedData := (others => '0');
    vCombinedValid := false;
    vCombinedReady := true;
    
    for i in 0 to kNumRegisters-1 loop
      vCombinedData := vCombinedData or bRegPortOutArray(i).Data;
      vCombinedValid := vCombinedValid or bRegPortOutArray(i).DataValid;
      vCombinedReady := vCombinedReady and bRegPortOutArray(i).Ready;
    end loop;
    
    bRegPortOut.Data <= vCombinedData;
    bRegPortOut.DataValid <= vCombinedValid;
    bRegPortOut.Ready <= vCombinedReady;
  end process CombineOutputs;

end rtl;
