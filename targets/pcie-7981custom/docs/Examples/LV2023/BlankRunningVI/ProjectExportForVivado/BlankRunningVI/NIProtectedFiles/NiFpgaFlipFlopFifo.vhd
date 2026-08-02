-------------------------------------------------------------------------------
--
-- File: NiFpgaFlipFlopFifo.vhd
-- Author: Dustyn Blasig
-- Original Project: LabVIEW FPGA Fifos
-- Date: 2 February 2005
--
-------------------------------------------------------------------------------
-- (c) 2005 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--
--   the flip-flop made fifo used in labview fpga designs. this fifo uses
--   the embedded slices of the fpga, so the element width and queue depth
--   should be minimized as much as possible to save space.
--
--   the current implementation does not allow simulataneous pushes and pops
--   when the fifo is full or empty to remove the possibility of combinatorial
--   feedback paths. in addition, if we allowed a push and pop while the fifo
--   was empty, the input data would have to feed through the component out the
--   output path with no registers possibly creating a very long path.
--
--   for information on how to use the flags, see the documentation in the doc
--   directory of the component under perforce.
--
--   the threshold generics describe when the component should raise the push
--   and pop flags. cPushFlag will be asserted when there are kPushThreshold
--   empty elements remaining in the fifo and cPopFlag will be asserted when 
--   there are kPopThreshold or less remaining elements in the fifo.
--
--   one or more elements can be pushed and popped from the fifo during each 
--   operation based on the value of the kNumOfElements generic. the width 
--   of the data buses is the width of one element multiplied by the selected
--   number of elements that are pushed or popped. 
--
--   the depth of the fifo is the number of push operations that will fill the fifo.
--   for example, when kDepth is 6 and kNumOfElements is 4, the buffer can contain 
--   up to 24 individual elements, but 4 elements will be pushed or popped in each 
--   transaction. 
--
--
--   Bogdan Popa - 08/12/2013
--   Added cAlmostFull flag, used for generating the Ready For Input signal for 
--   the Handshaking interface for FIFOs. This flag will assert when there is only 
--   one empty slot in the FIFO. Because the FF FIFO exposes optional counts, we
--   need to generate this flag from the shift register used for generating 
--   cEmpty and cFull flags.
-------------------------------------------------------------------------------

library ieee, work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.PkgNiUtilities.all;

entity NiFpgaFlipFlopFifo is
  generic(
    kWidth          : positive;
    kNumOfElements  : positive := 1;
    kDepth          : positive;
    kPushThreshold  : natural;
    kPopThreshold   : natural;
    kGenerateCounts : boolean := true
    );
  port (
    aReset : in boolean;

    Clk    : in std_logic;
    cReset : in boolean;

    cDataIn     : in  std_logic_vector(kWidth*kNumOfElements-1 downto 0);
    cPush       : in  boolean;
    cFull       : out boolean;
    cEmptyCount : out unsigned(Log2(kDepth+1)-1 downto 0);
    cPushFlag   : out boolean := false;
    cAlmostFull : out boolean;

    cDataOut   : out std_logic_vector(kWidth*kNumOfElements-1 downto 0);
    cPop       : in  boolean;
    cEmpty     : out boolean;
    cFullCount : out unsigned(Log2(kDepth+1)-1 downto 0);
    cPopFlag   : out boolean := false
    );
end NiFpgaFlipFlopFifo;

architecture rtl of NiFpgaFlipFlopFifo is

  constant kFlagsDepth : positive := kDepth / kNumOfElements;
  
  type Fifo_t
    is array (kFlagsDepth-1 downto 0)
    of std_logic_vector(kWidth*kNumOfElements-1 downto 0);
  
  subtype FifoFlags_t is std_logic_vector(kFlagsDepth downto 0);
  -- flags for managing the state of the fifo. the flags are one bigger than
  -- cFifo for detecting fullness MSB is initially set indicating That the end
  -- of cFifo will be the first enqueue position. The '1' then gets shifted
  -- down on a cInternalPush and up on a cInternalPop.

  -----------------------------------------------------------------------------

  constant kFlagsInit : FifoFlags_t := '1' & Zeros(kFlagsDepth);
  signal cFlags : FifoFlags_t := kFlagsInit;
  signal cNxFlags : FifoFlags_t;
  signal cFifo, cNxFifo   : Fifo_t;  -- cFifo(kFlagsDepth-1) is the oldest element

  signal cEmptyLoc, cFullLoc : boolean;
  signal cPushQual, cPopQual : boolean;  -- Qual short for Qualified

  signal cFullCountLoc
    : unsigned(cFullCount'range)
    := to_unsigned(0, cFullCount'length);

  signal cEmptyCountLoc
    : unsigned(cEmptyCount'range)
    := to_unsigned(kDepth, cEmptyCount'length);

begin

  cEmpty <= cEmptyLoc;
  cFull  <= cFullLoc;
  
  cAlmostFull <= to_boolean(cFlags(1)); 

  cEmptyLoc <= to_boolean(cFlags(kFlagsDepth));
  cFullLoc  <= to_boolean(cFlags(0));

  cPushQual <= cPush and not cFullLoc;
  cPopQual  <= cPop and not cEmptyLoc;

  -----------------------------------------------------------------------------
  -- Flags Generation
  -----------------------------------------------------------------------------

  -- These flags are used to track the fullness or emptiness of the fifos.
  -- cFlags(kFlagsDepth) is the empty flag while cFlags(0) means that the fifo
  -- is full.

  cNxFlags <= '0' & cFlags(kFlagsDepth downto 1) when cPushQual and not cPopQual else
              cFlags(kFlagsDepth-1 downto 0) & '0' when cPopQual and not cPushQual else
              cFlags;

  FlagsReg : process(aReset, Clk)
  begin
    if aReset then
      cFlags <= kFlagsInit;
    elsif rising_edge(Clk) then
      if cReset then
        cFlags <= kFlagsInit;
      else
        cFlags <= cNxFlags;
      end if;
    end if;
  end process FlagsReg;

  -----------------------------------------------------------------------------
  -- Data Registers
  -----------------------------------------------------------------------------

  -- the data shift register. data is always shifted on a pop. incoming data is
  -- inserted in the apropriate location in the shift register based on the
  -- flags register. cNxFlags is used so the input data is registered in the
  -- correct location if a push and pop occur at the same time alleviating us
  -- from having to duplicate similar logic here.

  GenNxFifo : for i in cNxFifo'range generate

    cNxFifo(i) <= cDataIn when cPushQual and (cNxFlags(i) = '1') else
                  cFifo(larger(0, i-1)) when cPopQual else
                  cFifo(i);
    
  end generate GenNxFifo;

  DataRegs : process(aReset, Clk)
  begin
    if aReset then
      cFifo <= (others => (others => '0'));
    elsif rising_edge(Clk) then
      cFifo <= cNxFifo;
    end if;
  end process DataRegs;

  cDataOut <= cFifo(cFifo'left);

  -----------------------------------------------------------------------------
  -- Flags generation if needed
  -----------------------------------------------------------------------------

  -- These flags provide information about the almost full
  -- state and almost empty state. The push and pop flags are asserted
  -- when the FIFO count is within the push and pop thresholds of being
  -- full and empty.

  PushFlagRequested : if kPushThreshold < kDepth generate
    cPushFlag <= to_boolean(OrVector(cFlags(kPushThreshold downto 0)));
  end generate;

  PopFlagRequested : if kPopThreshold < kDepth generate
    cPopFlag <= to_boolean(OrVector(cFlags(kDepth downto kDepth - kPopThreshold)));
  end generate;

  -----------------------------------------------------------------------------
  -- Count Generation
  -----------------------------------------------------------------------------

  GenCounts : if kGenerateCounts generate

    -- this block generates the count values. the fifo is controlled by another
    -- set of flags. here we generate some up/down counters to generate numbers
    -- instead of a one-hot flags array. xilinx should be able to optimize out
    -- the counters if they are left unwired by upper modules.
    --
    -- the implementation below creates two up/down counters. an alternate
    -- implementation would be to have one counter and then do a subtract to
    -- get the other. the alternative would use an equivalent amount of logic
    -- while serializing the operation decreasing the maximum achievable clock
    -- rate. the dual counters below operate in parallel.
    
    signal cNxFullCount  : unsigned(cFullCount'range);
    signal cNxEmptyCount : unsigned(cEmptyCount'range);
    
  begin

    cNxFullCount <= cFullCountLoc + kNumOfElements when (cPushQual and not cPopQual) else
                    cFullCountLoc - kNumOfElements when (cPopQual and not cPushQual) else
                    cFullCountLoc;

    cNxEmptyCount <= cEmptyCountLoc - kNumOfElements when (cPushQual and not cPopQual) else
                     cEmptyCountLoc + kNumOfElements when (cPopQual and not cPushQual) else
                     cEmptyCountLoc;

    CountRegs : process (Clk, aReset)
    begin
      if aReset then
        cFullCountLoc  <= to_unsigned(0, cFullCountLoc'length);
        cEmptyCountLoc <= to_unsigned(kDepth, cEmptyCountLoc'length);
      elsif rising_edge(Clk) then
        if cReset then
          cFullCountLoc  <= to_unsigned(0, cFullCountLoc'length);
          cEmptyCountLoc <= to_unsigned(kDepth, cEmptyCountLoc'length);
        else
          cFullCountLoc  <= cNxFullCount;
          cEmptyCountLoc <= cNxEmptyCount;
        end if;
      end if;
    end process CountRegs;

  end generate GenCounts;

  cFullCount  <= cFullCountLoc;
  cEmptyCount <= cEmptyCountLoc;
  
end rtl;

