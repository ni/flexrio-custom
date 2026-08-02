-------------------------------------------------------------------------------
--
-- File: NiSharedHostRegister.vhd

--
-------------------------------------------------------------------------------
-- (c) 2025 Copyright National Instruments Corporation
-- 
-- SPDX-License-Identifier: MIT
-------------------------------------------------------------------------------
--
-- Purpose:
-- This entity implements one 32-bit shared register that is visible to both:
--   1) the host (through RegPortIn/RegPortOut), and
--   2) FPGA-side logic (through bFpga* ports).
--
-- RegPortIn/RegPortOut protocol details are documented in:
--   register/docs/RegPort_Theory_of_Operation.md
--
-- Host-side behavior (high level):
-- - Address decode compares the incoming register byte address against kOffset.
-- - A host read at the matching address returns the current register value and pulses
--   DataValid for one BusClk cycle.
-- - A host write at the matching address updates the register unless kReadOnly=true.
-- - bFpgaHostWrite pulses for one BusClk cycle whenever the host writes this register
--   address (useful as an FPGA-side "host wrote me" event).
--
-- FPGA-side behavior:
-- - bFpgaDataOut continuously reflects the current register contents.
-- - When bFpgaWrite=true on a BusClk rising edge, bFpgaDataIn is written into the
--   register.
-- - FPGA writes have priority over host writes when both occur on the same clock edge.
--
-- Reset/default behavior:
-- - On aReset, the register initializes to kDefault.
-- - After reset, the register retains its value until modified by host or FPGA write.
--
-- Ready/acknowledgment behavior:
-- - If kUseFpgaAck=false, Ready remains asserted (register is always ready).
-- - If kUseFpgaAck=true, Ready deasserts when the register is newly addressed and stays
--   low until bFpgaAck is asserted, then returns high.  Take special care when using this
--   mode to avoid deadlock (e.g. FPGA must eventually assert bFpgaAck in response to a 
--   host request or all subsequent host requests will be stalled).
--
-------------------------------------------------------------------------------

library IEEE;
  use IEEE.std_logic_1164.all;
  use IEEE.numeric_std.all;
  
library work;
  use work.PkgNiUtilities.all;
  use work.PkgCommunicationInterface.all;
  
entity NiSharedHostRegister is
  generic(
    kMaxHdlRegOffset : natural;
    kOffset  : natural := 0;
    kDefault  : std_logic_vector(31 downto 0);
    kReadOnly : boolean := false;
    kUseFpgaAck : boolean := false
  );
  port(
    BusClk      : in std_logic;
    aReset      : in boolean;

    -- Host Register Access
    bRegPortIn  : in RegPortIn_t;
    bRegPortOut : out RegPortOut_t;    

    -- FPGA Register Access
    bFpgaHostWrite    : out boolean;
    bFpgaAck          : in boolean;
    bFpgaWrite        : in boolean;
    bFpgaDataIn       : in std_logic_vector(31 downto 0);
    bFpgaDataOut      : out std_logic_vector(31 downto 0)

  );  
end entity NiSharedHostRegister;

architecture rtl of NiSharedHostRegister is

  signal bRegData : std_logic_vector(31 downto 0);
  signal bRegAddressed : boolean;
  signal bRegAddressedDly : boolean;  
  
begin

  -- Compile-time bound check: this register's byte offset must fit within the HDL
  -- register space the LabVIEW FPGA target reserves (kMaxHdlRegOffset). Because the
  -- check lives in the fundamental register block, every register the user drops --
  -- bare, in an array, or via the common-regs block -- self-checks at elaboration in
  -- both Vivado synthesis and ModelSim simulation, instead of silently colliding
  -- with LabVIEW register space.
  assert kOffset <= kMaxHdlRegOffset
    report "NiSharedHostRegister kOffset (" & integer'image(kOffset)
         & ") exceeds kMaxHdlRegOffset (" & integer'image(kMaxHdlRegOffset)
         & "). Increase set_max_hdl_reg_offset in nihdlsettings.py or move the register."
    severity failure;

  -- Address from RegPortIn is in 32 bit words so we need to multiply by 4 (shift left by 2) to get
  -- byte address and compare with our offset
  bRegAddressed  <= (unsigned(bRegPortIn.Address & "00") = kOffset);

  -- Write process: we always grant the priority to the FPGA write
  -- so if both write signal are high at the same time, only the 
  -- FpgaWrite makes it
  Writing:process (aReset, BusClk)
  begin
    if aReset then
      bRegData <= kDefault;
    elsif rising_edge(BusClk) then
      if bFpgaWrite then
        bRegData <= bFpgaDataIn;
      elsif bRegAddressed and bRegPortIn.Wt and not kReadOnly then
        bRegData <= bRegPortIn.Data;
      end if;
    end if;
  end process Writing;

  -- Read process: output data to the host must be valid for one clock cycle
  -- after a read request 
  Reading:process (BusClk)
  begin
    if aReset then
      bRegPortOut.Data <= (others => '0');
      bRegPortOut.DataValid <= false;
    elsif rising_edge(BusClk) then
      -- Host read response - assert data and valid for one clock cycle
      if bRegAddressed and bRegPortIn.Rd then
        bRegPortOut.Data <= bRegData;
        bRegPortOut.DataValid <= true;
      else
        bRegPortOut.Data <= (others => '0');
        bRegPortOut.DataValid <= false;
      end if;

      -- Assert FPGA host write for one cycle
      if bRegAddressed and bRegPortIn.Wt then
        bFpgaHostWrite <= true;
      else
        bFpgaHostWrite <= false;
      end if;

    end if;
  end process Reading;

  Ready:process (aReset, BusClk)
  begin
    if aReset then
      bRegPortOut.Ready <= true;
      bRegAddressedDly <= false;
    elsif rising_edge(BusClk) then
      bRegAddressedDly <= bRegAddressed;      
      if kUseFpgaAck then
        -- When using FPGA acknowledgment, deassert Ready when register becomes addressed
        -- and hold it low until bFpgaAck asserts
        if bFpgaAck then
          -- Reassert ready when FPGA acknowledges
          bRegPortOut.Ready <= true;
        elsif bRegAddressed and not bRegAddressedDly then
          -- Deassert ready when the register first becomes addressed
          bRegPortOut.Ready <= false;
        end if;
      else
        -- Register is always ready to accept host requests
        bRegPortOut.Ready <= true;
      end if;
    end if;
  end process Ready;



  -- Data is always available on the FPGA side when requested
  bFpgaDataOut <= bRegData;

  -- synthesis translate_off
  -- Simulation-only protocol monitor. Continuously asserts that both sides honor
  -- the RegPort contract: the master driving bRegPortIn (mutually exclusive
  -- Rd/Wt, known address/data) and this block's own slave response on
  -- bRegPortOut (zero data when not valid so outputs OR-combine, monotonic
  -- Ready, known read data). It is passive and fenced out of synthesis. This
  -- both self-checks the reference register and models the check a user should
  -- keep if they lift the RegPort state machine into their own logic.
  RegPortProtocolCheck : entity work.RegPortProtocolChecker
    generic map (
      kName => "NiSharedHostRegister"
    )
    port map (
      BusClk         => BusClk,
      aReset         => aReset,
      bRegPortIn     => bRegPortIn,
      bRegPortOut    => bRegPortOut,
      ViolationCount => open
    );
  -- synthesis translate_on

end rtl;
