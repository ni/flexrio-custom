------------------------------------------------------------------------------------------
--
-- File: NiFpgaLutRamFifo.vhd
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
-- Purpose: This FIFO follows the same interface as NiFpgaFlipFlopFifo, but is
-- implementing using a LUTRAM instead. This allows for a much smaller footprint.
--
-- Additionally, we gain considerably better timing performance, because we avoid large
-- fanouts from both the FifoFlags and the EnableChain. In the NiFpgaFlipFlopFifo, there's
-- a (deep) path from the FifoFlags to each of the FlipFlops in the FIFO. Because there
-- are kDepth*kWidth*kNumOfElements FFs in a FlipFlop Fifo design, this creates a very
-- large fanout for wide FIFOs.
--
-- Meanwhile, although the flags do need to go to each of the LUTRAMs instantiated here,
-- there's only one LUTRAM per data bit, so there are only kWidth*kNumOfElements LUTRAMs.
--
-- vreview_group LutRamPopBuffer
-- vreview_closed http://review-board.natinst.com/r/230293/
-- vreview_reviewers rortega butler
------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.PkgNiUtilities.all;

entity NiFpgaLutRamFifo is
  generic(
    kWidth          : positive;
    kDepth          : positive;
    kNumOfElements  : positive
    );
  port (
    aReset : in boolean;

    Clk    : in std_logic;
    cReset : in boolean;

    cDataIn     : in  std_logic_vector(kWidth*kNumOfElements-1 downto 0);
    cPush       : in  boolean;
    cFull       : out boolean;
    cEmptyCount : out unsigned(Log2(kDepth+1)-1 downto 0);

    cDataOut   : out std_logic_vector(kWidth*kNumOfElements-1 downto 0);
    cPop       : in  boolean;
    cEmpty     : out boolean;
    cFullCount : out unsigned(Log2(kDepth+1)-1 downto 0)
    );
end entity NiFpgaLutRamFifo;

architecture rtl of NiFpgaLutRamFifo is

  -- kDepth is provided to us in terms of Elements. Which is silly, because our data word
  -- is kWidth * kNumOfElements. So we'll use an internal kFifoDepth value that is given
  -- in terms of "real" words. This constant always resolves to an integer, because
  -- kDepth is always a multiple of kNumOfElements.
  constant kFifoDepth : natural := kDepth / kNumOfElements;

  -- Our Address Width needs to be such that it can accommodate the depth.
  constant kAddressWidth : natural := Log2(kFifoDepth);
  -- This definition simply matches the module's IO definition.
  constant kDataWidth : natural := kWidth*kNumOfElements;

  --vhook_sigstart
  signal cEmptyCountL: unsigned(Log2(kFifoDepth)downto 0);
  signal cFullCountL: unsigned(Log2(kFifoDepth)downto 0);
  signal cRdAddr: unsigned(Log2(kFifoDepth)-1 downto 0);
  signal cWtAddr: unsigned(Log2(kFifoDepth)-1 downto 0);
  --vhook_sigend

  -- Intermediate signal names for auto-assignment
  signal cWrite, cRead : boolean := false;

  signal cEmptyLoc : boolean;
  signal cFullLoc : boolean;

begin  -- architecture rtl

  assert Log2(kNumOfElements+1)-1 = Log2(kNumOfElements)
    report "kNumOfElements must be a power of 2."
    severity error;

  -- Name re-assignment.
  cWrite <= cPush and not cFullLoc;
  cRead  <= cPop and not cEmptyLoc;

  --vhook_e LutRamFifoFlags
  --vhook_a cClkEn      true
  --vhook_a cFullCount  cFullCountL
  --vhook_a cEmptyCount cEmptyCountL
  --vhook_a cDataValid  open
  --vhook_a {cMem(.*)}  c$1
  LutRamFifoFlagsx: entity work.LutRamFifoFlags (rtl)
    generic map (
      kFifoDepth => kFifoDepth)  -- in  positive
    port map (
      aReset      => aReset,        -- in  boolean
      Clk         => Clk,           -- in  std_logic
      cReset      => cReset,        -- in  boolean
      cWrite      => cWrite,        -- in  boolean
      cRead       => cRead,         -- in  boolean
      cClkEn      => true,          -- in  boolean
      cFullCount  => cFullCountL,   -- out unsigned(Log2(kFifoDepth)downto 0)
      cEmptyCount => cEmptyCountL,  -- out unsigned(Log2(kFifoDepth)downto 0)
      cDataValid  => open,          -- out boolean
      cMemWtAddr  => cWtAddr,       -- out unsigned(Log2(kFifoDepth)-1 downto 0)
      cMemRdAddr  => cRdAddr);      -- out unsigned(Log2(kFifoDepth)-1 downto 0)

  -- In order to compute the full count in terms of elements, like the downstream logic
  -- expects, we need to do two things:
  -- 1. Resize cFullCountL, which is defined as 'Log2(kDepth / kNumOfElements) downto 0',
  --    basically counting FIFO words. In the context of multi-element FIFOs, such a word contains
  --    more than one element. cFullCount will expose the number of elements, therefore it will have
  --    at least the same number of bits as cFullCountL (if kNumOfElements = 1), or more bits than 
  --    cFullCountL (if kNumOfElements > 1). 
  -- 2. Shift left with kNumOfElements, which is equivalent with a multiplication, 
  --    since kNumOfElements is always a power of 2. This way, by having the FIFO word count, 
  -- we compute the FIFO element count, visible to downstream logic.
  -- **Note on resizing: we are resizing a vector of Log2(kDepth / kNumOfElements) + 1 bits
  -- to a vector of Log2(kDepth + 1) bits. In the edge case where kNumOfElements = 1, this resizing 
  -- turns a vector of Log2(kDepth) + 1 into one of Log2(kDepth + 1). Basically, we expect that the relation
  -- Log2(kDepth) + 1 <= Log2(kDepth + 1) will hold. This relation does not hold for cases where
  -- kDepth has a non-power-of-2 value. But, another restriction to take into account is that 
  -- the counts values can never be greater than kDepth (enforced by LutRamFifoFlags), so two cases arise:
  -- a. If kDepth is a power of 2, then Log2(kDepth+1) = Log2(kDepth)+1, so the count will
  --    fit into 'Log2(kDepth+1) - 1 downto 0'.
  -- b. If kDepth is *not* a power of 2, then 'Log2(kDepth+1)-1 downto 0' is guaranteed to
  --    at least fit the value 'kDepth', which is the maximum number that can be
  --    represented by cFullCountL.
  cFullCount <= resize(cFullCountL , cFullCount'length) sll Log2(kNumOfElements); 
  -- The exact same logic applies to cEmptyCount. 
  cEmptyCount <= resize(cEmptyCountL, cEmptyCount'length) sll Log2(kNumOfElements); 

  -- cEmpty is true whenever our fullness is 0.
  cEmptyLoc <= cFullCountL = 0;
  cEmpty <= cEmptyLoc;

  -- cFull is true whenever our emptiness is 0.
  cFullLoc <= cEmptyCountL = 0;
  cFull <= cFullLoc;

  --vhook_e NiFpgaLowLatencyLutRam
  --vhook_g kWidth      kDataWidth
  --vhook_a cWtData     cDataIn
  --vhook_a cRdData     cDataOut
  NiFpgaLowLatencyLutRamx: entity work.NiFpgaLowLatencyLutRam (struct)
    generic map (
      kAddressWidth => kAddressWidth,  -- in  positive range 1 to 5 := 5
      kWidth        => kDataWidth)     -- in  natural := 32
    port map (
      Clk     => Clk,       -- in  std_logic
      cWrite  => cWrite,    -- in  boolean
      cWtAddr => cWtAddr,   -- in  unsigned(kAddressWidth-1 downto 0)
      cWtData => cDataIn,   -- in  std_logic_vector(kWidth-1 downto 0)
      cRdAddr => cRdAddr,   -- in  unsigned(kAddressWidth-1 downto 0)
      cRdData => cDataOut); -- out std_logic_vector(kWidth-1 downto 0)



end architecture rtl;
