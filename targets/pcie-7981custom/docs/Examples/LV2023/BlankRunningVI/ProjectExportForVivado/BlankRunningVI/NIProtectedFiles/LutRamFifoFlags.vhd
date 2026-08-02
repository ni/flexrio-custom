-------------------------------------------------------------------------------
--
-- File: LutRamFifoFlags.vhd
-- Author: Craig Conway, James Nicholson, Paul Butler
-- Original Project: NiCores
-- Date: 11 April 2003
--
-------------------------------------------------------------------------------
-- (c) 2003 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose: Local version of the ni core integrated from core version exported in
--
--  //ASIC/nicores/CoreComponents3/CommonCores/export/1.0/1.0.0a11/CommonFiles/Fifo/SingleClock/LutRamFifoFlags.vhd
--
--  in order to cut down on write latency, to support a low-latency LutRam exclusively.
--  This module will no longer support BRAMs, or really anything other than the
--  NiFpgaLowLatencyLutRam as FIFO memory implementation.
--
-- Original Purpose:
--
--   This file implements FIFO management flags for a DualPortRAM block,
-- creating a configurable-depth FIFO.  While DualPortRAM might support
-- different input and output clock domains, this version of FifoFlags
-- supports only one shared clock domain for queue and dequeue.
--   The FIFO depth is 2**kAddressWidth, so the RAM is completely
-- used, unlike previous FIFO implementations where one element of the
-- RAM would be unusable.
--   This means that there is an extra bit for the address and
-- full/empty count adders and so timing will be slightly harder to
-- meet.
--
-- IMPORTANT NOTE 1:
--   You should use cFullCount to determine when to read the FIFO and
-- cEmptyCount to determine when to write the FIFO.
--   cFullCount and cEmptyCount update quickly after cWrite or cRead
-- assert.  This means that if you have an empty FIFO and perform a write,
-- cFullCount and cEmptyCount may update even though data won't actually
-- actually appear at the outputs until the read latencies are satisfied.
--   This is not a problem as long as you never take data from the FIFO
-- without qualifying it with the cDataValid signal, which can't assert
-- until you assert cRead.  Because you must assert cRead and wait for
-- cDataValid, it won't be possible for you to read data from the FIFO
-- before it's ready.
--
-- IMPORTANT NOTE 2:
-- This component does not contain the memory, but rather has
-- connections to the address and data ports of the external memory. The
-- memory is assumed to be synchronous single cycle read and write, with a
-- latency of kRamReadLatency.
--
-- vreview_group LutRamPopBuffer
-- vreview_closed http://review-board.natinst.com/r/230293/
-- vreview_reviewers rortega butler
-- vreview_closed http://review-board.natinst.com/r/116527/
-- vreview_closed http://review-board.natinst.com/r/112171/
-- vreview_closed http://review-board.natinst.com/r/111460/
-- vreview_closed http://review-board.natinst.com/r/90218/
-- vreview_closed http://review-board.natinst.com/r/90007/
-- vreview_closed http://review-board.natinst.com/r/79838/
--
-------------------------------------------------------------------------------
--
-- Theory of Operation
--
--   Previous FIFO versions had the depth as 2^AddressWidth-1, instead of
-- 2^AddressWidth, because full use of the memory would require an extra bit
-- in the pointers, increasing the size of the counters and potentially slowing
-- the circuit down.  We have opted to change this policy since the FIFO flags
-- are rarely the critical path in a circuit and it is probably overly wasteful
-- to skip one value on a very shallow FIFO.
--
--   This module maintains the read and write pointers separately from
-- the full and empty counts.  This allows all four values to update within
-- one clock of the assertion of read or write.  Another method of
-- maintaining the full/empty counts would be to perform math on the
-- current state of the read and write pointers.  Since that would add
-- additional latency, this module opts for the former approach.
--
-------------------------------------------------------------------------------
--
-- Ports
--
-- aReset
--   Asynchronous reset to all internal FFs
-- Clk
--   Clock to all internal FFs
-- cReset
--   Synchronous reset.
-- cWrite
--   Strobe to indicate when to write the memory
-- cRead
--   Strobe requesting to read the next element from the FIFO. This may not
--   be asserted at the same time as cReadRewind, nor may it be asserted
--   one clock after cReset or cReadRewind are deasserted.
-- cFullCount
--   Indicates the number of elements available to be read. This updates
--   one Clk cycle after a read.  If kRamReadLatency is 1, it updates
--   two cycles after a write.  If kRamReadLatency is > 1, it updates
--   only one cycle after a write.This should be used to determine when
--   to read the FIFO.
-- cEmptyCount
--   Indicates the number of spaces available to be written. This
--   updates one Clk cycle after a read or a write. This should be used
--   to determine when to write the FIFO.
-- cMemWtAddr
--   The write pointer into the memory.
-- cMemWt
--   Signal to indicate when to write into the data memory.
--   This may remain asserted for back to back writes.
--   Just passes through cWrite.
-- cMemRdAddr
--   The read pointer into the memory. By the time cFullCount is
--   non-zero, cMemRdAddr always points to the location of the first
--   read element. In this manner it is possible to "prefetch" the next
--   read data so as to allow a single-cycle read. If kSynchronousRead
--   is true, then cMemRdAddr will change to the next address
--   combinatorially from cRead, reducing the overall FIFO read
--   latency by one clock.
--
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;

entity LutRamFifoFlags is
  generic (
    kFifoDepth : positive
  );
  port (
    aReset : in boolean;
    Clk : in std_logic;

    cReset : in boolean;

    -- FIFO Interface
    cWrite,
    cRead,
    cClkEn : in boolean;

    cFullCount,
    cEmptyCount : out unsigned(Log2(kFifoDepth) downto 0);

    cDataValid : out boolean;

    -- Memory Interface
    cMemWtAddr,
    cMemRdAddr : out unsigned(Log2(kFifoDepth)-1 downto 0)
  );

end LutRamFifoFlags;

architecture rtl of LutRamFifoFlags is

  constant kAddressWidth : positive := Log2(kFifoDepth);
  constant kFifoDepthUns : unsigned(kAddressWidth downto 0)
    := To_Unsigned(kFifoDepth, kAddressWidth+1);

  constant kResetVal : unsigned(kAddressWidth-1 downto 0) := (others => '0');
  constant kResetValC : unsigned(kAddressWidth downto 0) := (others => '0');

  -- These values used to be specified as generics, but the following are the only
  -- supported values for the LutRamFifo application:
  constant kFifoAdditiveLatency : natural := 1;
  constant kRamReadLatency : natural := 0;

begin

  -----------------------------------------------------------------------------
  -- This block maintains the read and write addresses to the RAM.
  -----------------------------------------------------------------------------
  BlkAddr: block
    signal cNxWAddr, cWAddr, cNxRAddr, cRAddr : unsigned (kAddressWidth-1 downto 0);
  begin

    cNxWAddr <= (others => '0') when cReset else
                cWAddr + 1 when cWrite else
                cWAddr;

    cNxRAddr <= (others => '0') when cReset else
                cRAddr + 1 when cRead else
                cRAddr;

    ------------------------------------------------------
    --Start of local change 1 of 2. Replacing DFlopUnsigned with inferred flops
    --  This will allow to place a MAX_FANOUT attribute to the flops and cause
    --  replication at synthesis. Attribute is not added here to make it more flexible
    --  and portable. For example, in Xilinx, it can be added in the XDC file
    --  selectively per instance

    AddrFlops: process(Clk, aReset)
    begin
      if aReset then
        cWAddr <= kResetVal;
        cRAddr <= kResetVal;
      elsif rising_edge(Clk) then
        if cClkEn then
          cWAddr <= cNxWAddr;
          cRAddr <= cNxRAddr;
        end if;
      end if;
    end process; -- AddrFlops

    --End of local change 1 of 2
    ------------------------------------------------------

    -- Memory Interface
    cMemWtAddr <= cWAddr;
    cMemRdAddr <= cNxRAddr when kFifoAdditiveLatency=0 else cRAddr;

  end block BlkAddr;

  -----------------------------------------------------------------------------
  -- Generate the data valid signal
  -----------------------------------------------------------------------------

  ------------------------------------------------------
  --Start of local change 2 of 2. Replacing instance of GenDataValid core with
  -- inferred flops that behave exactly the same way in order to avoid a local
  -- version of that core and possibly interfering with other components that instantiate
  -- it

  GenDataValid: block
    -- The total latency is the sum of the two generics. kRamReadLatency reflects
    -- what the RAM actually does, while kFifoAdditiveLatency is additional delay
    -- requested by the user. Note that the type is 'positive' ensuring that
    -- its value will be at least 1 or there will be an error generated.
    constant kFifoReadLatency : positive := kRamReadLatency + kFifoAdditiveLatency;
    signal cD, cQ : BooleanVector(kFifoReadLatency+2 downto 1);
    constant kGenDvResetVal : BooleanVector(kFifoReadLatency+2 downto 1) := (others => false);
  begin

    -- First bit of shift register asserts on cRead.
    cD(1) <= cRead and not cReset;
    cD(cD'high downto 2) <= (others => false) when cReset else cQ(cD'high-1 downto 1);

    BoolFlopVector: process(Clk, aReset)
    begin
      if aReset then
        cQ <= kGenDvResetVal;
      elsif rising_edge(Clk) then
        if cClkEn then
          cQ <= cD;
        end if;
      end if;
    end process; -- BoolFlopVector

    -- Note that we're looking at cD, not cQ here. This means that if kFifoReadLatency=1,
    -- cDataValid will assert in the same clock cycle as cRead. The latency refers to the
    -- number of clocks after cRead asserts that the data will change, so the last cycle
    -- in which the data can be captured is kFifoReadLatency-1.
    cDataValid <= cD(kFifoReadLatency);

  end block GenDataValid;

  --End of local change 2 of 2
  ------------------------------------------------------

  -----------------------------------------------------------------------------
  -- This block creates the Full and Empty counts and the Overflow/Underflow
  -- signals.
  -----------------------------------------------------------------------------
  BlkFlags: block
    signal cNxFullCount, cLclFullCount,
           cNxEmptyCount, cLclEmptyCount : unsigned(kAddressWidth downto 0);
    signal cOverflow, cUnderflow : boolean := false;

  begin

    cNxFullCount <= (others => '0') when cReset else
                    cLclFullCount + 1 when cWrite and not cRead else
                    cLclFullCount - 1 when cRead and not cWrite else
                    cLclFullCount;

    --vhook_e DFlopUnsigned cFullCountx
    --vhook_a kResetVal kResetValC
    --vhook_a cEn cClkEn
    --vhook_a cD cNxFullCount
    --vhook_a cQ cLclFullCount
    cFullCountx: entity work.DFlopUnsigned (rtl)
      generic map (kResetVal => kResetValC)  --unsigned
      port map (
        aReset => aReset,         --in  boolean
        cEn    => cClkEn,         --in  boolean
        Clk    => Clk,            --in  std_logic
        cD     => cNxFullCount,   --in  unsigned(kResetVal'length-1:0)
        cQ     => cLclFullCount); --out unsigned(kResetVal'length-1:0)

    cNxEmptyCount <= kFifoDepthUns when cReset else
                     cLclEmptyCount - 1 when cWrite and not cRead else
                     cLclEmptyCount + 1 when cRead and not cWrite else
                     cLclEmptyCount;

    --vhook_e DFlopUnsigned cEmptyCountx
    --vhook_a kResetVal kFifoDepthUns
    --vhook_a cEn cClkEn
    --vhook_a cD cNxEmptyCount
    --vhook_a cQ cLclEmptyCount
    cEmptyCountx: entity work.DFlopUnsigned (rtl)
      generic map (kResetVal => kFifoDepthUns)  --unsigned
      port map (
        aReset => aReset,          --in  boolean
        cEn    => cClkEn,          --in  boolean
        Clk    => Clk,             --in  std_logic
        cD     => cNxEmptyCount,   --in  unsigned(kResetVal'length-1:0)
        cQ     => cLclEmptyCount); --out unsigned(kResetVal'length-1:0)

    cFullCount <= cLclFullCount;
    cEmptyCount <= cLclEmptyCount;

    --synthesis translate_off
    process (aReset, Clk)
    begin
      if aReset then
        cOverflow <= false;
        cUnderflow <= false;
      elsif rising_edge(Clk) then
        cOverflow <= cWrite and cClkEn and cLclEmptyCount=0;
        cUnderflow <= cRead and cClkEn and cLclFullCount=0;
      end if;
    end process;

    assert not cUnderflow report "Underflow error" severity error;
    assert not cOverflow report "Overflow error" severity error;
    --synthesis translate_on

  end block BlkFlags;

end rtl;
