------------------------------------------------------------------------------------------
--
-- File: NiFpgaLowLatencyLutRam.vhd
-- Author: Rolando Ortega
-- Original Project: The Macallan Next FlexRIO
-- Date: 03 April 2018
--
------------------------------------------------------------------------------------------
-- (c) 2018 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
------------------------------------------------------------------------------------------
--
-- Purpose: This module implements a shallow RAM with a Write Latency of 1 and a Read
-- Latency of 0, meaning the write is synchronous but the read is asynchronous.
--
-- The implementation is an inferred RAM, and we use the Xilinx-recommended inference
-- pattern as well as a special attribute to nudge the synthesizer to implement this as a
-- LUTRAM.
--
-- This module makes no allowance for LUTRAMs deeper than 32, so its input address width
-- is restricted. It's possible that these LUTRAMs would be correctly implemented by the
-- tool, it's just that we have not tested this case.
--
-- vreview_group LutRamPopBuffer
-- vreview_closed http://review-board.natinst.com/r/230293/
-- vreview_reviewers rortega butler
------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity NiFpgaLowLatencyLutRam is

  generic (
    kAddressWidth : positive range 1 to 5 := 5;
    kWidth        : natural := 32);

  port (
    Clk     : in  std_logic;
    cWrite  : in  boolean;
    cWtAddr : in  unsigned(kAddressWidth-1 downto 0);
    cWtData : in  std_logic_vector(kWidth-1 downto 0);
    cRdAddr : in  unsigned(kAddressWidth-1 downto 0);
    cRdData : out std_logic_vector(kWidth-1 downto 0));

end entity NiFpgaLowLatencyLutRam;

architecture struct of NiFpgaLowLatencyLutRam is

  type RamArray_t is array (2**kAddressWidth-1 downto 0) of std_logic_vector(kWidth-1 downto 0);
  signal cRam : RamArray_t;

  -- VSMake complains of no initial value and no reset value for cRam. The Xilinx RAM
  -- inference template assigns no initial value, and a LutRam can't be reset. So we'll
  -- ignore the warning.
  --vhook_nowarn cRam id=Misc12

  -- Make sure this RAM is implemented as a LUTRAM.
  attribute ram_style : string;
  attribute ram_style of cRam : signal is "distributed";

begin  -- architecture struct

  -- Following the inference examples from UG901.

  -- The write is a fully-synchronous process.
  WriteProc : process (Clk)
  begin -- process WriteProc
    if rising_edge(Clk) then
      if cWrite then
        cRam(to_integer(cWtAddr)) <= cWtData;
      end if;
    end if;
  end process WriteProc;

  -- We use an asynchronous read to cut down on the latency through the RAM.
  cRdData <= cRam(to_integer(cRdAddr));

end architecture struct;
