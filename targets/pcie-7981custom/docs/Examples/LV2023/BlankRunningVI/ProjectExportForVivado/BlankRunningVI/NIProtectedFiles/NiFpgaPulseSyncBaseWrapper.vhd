-------------------------------------------------------------------------------
--
-- File: NiFpgaPulseSyncBaseWrapper.vhd
-- Author: Gregory Voirin 
-- Original Project: LabVIEW FPGA Jupiter
-- Date: 21 June 2007
--
-------------------------------------------------------------------------------
-- (c) 2007 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--   Workaround an issue in the NiFpgaPulseSyncBase component that prevents us from 
--   setting timing constraints (oSigAck is not registered in NiFpgaPulseSyncBase).
--   It will also remove a potentially glitchy circuit in front of a
--   clock domain crossing flip flop.
--
--
-------------------------------------------------------------------------------

library ieee, work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.PkgNiUtilities.all;

entity NiFpgaPulseSyncBaseWrapper is
  port (
    aReset : in boolean;

    IClk          : in  std_logic;
    iClkEn        : in  boolean;
    iSig          : in  std_logic;
    iStatusOfoSig : out std_logic;

    OClk    : in  std_logic;
    oClkEn  : in  boolean;
    oSigAck : in  boolean;
    oSigCE  : out std_logic;
    oSig    : out std_logic
    );
end NiFpgaPulseSyncBaseWrapper;

architecture rtl of NiFpgaPulseSyncBaseWrapper is

  --vhook_sigstart
  signal oRegisteredSigAck: std_logic;
  --vhook_sigend

begin

  process (aReset, OClk)
  begin
    if aReset then
      oRegisteredSigAck <= '0';
    elsif rising_edge(OClk) then
      oRegisteredSigAck <= to_stdlogic(oSigAck);
    end if;
  end process;

  --vhook_e PulseSyncBase
  --vhook_p oSigReturn oRegisteredSigAck
  PulseSyncBasex: entity work.PulseSyncBase (behavior)
    port map (
      aReset        => aReset,
      IClk          => IClk,
      iClkEn        => iClkEn,
      iSig          => iSig,
      iStatusOfoSig => iStatusOfoSig,
      OClk          => OClk,
      oClkEn        => oClkEn,
      oSigCE        => oSigCE,
      oSig          => oSig,
      oSigReturn    => oRegisteredSigAck);

end rtl;
