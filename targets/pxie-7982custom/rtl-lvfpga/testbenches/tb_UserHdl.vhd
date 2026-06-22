-------------------------------------------------------------------------------
--
-- File: tb_UserHdl.vhd
--
-------------------------------------------------------------------------------
-- (c) 2026 Copyright National Instruments Corporation
--
-- SPDX-License-Identifier: MIT
-------------------------------------------------------------------------------
--
-- Purpose:
--   Smoke/integration testbench for this target's UserHdl.
--
--   The entire test sequence lives in the single-sourced work.UserHdlTestCore
--   entity (targets/common/rtl-lvfpga/testbenches/UserHdlTestCore.vhd). This
--   wrapper only supplies the board-specific generics.
--
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;

entity tb_UserHdl is
end entity tb_UserHdl;

architecture sim of tb_UserHdl is
begin

  TestCore : entity work.UserHdlTestCoreBidir
    generic map(
      kSignature => x"7982BEEF",
      kNumAuxIoData => 8
    );

end architecture sim;
