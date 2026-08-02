------------------------------------------------------------------------------------------
--
-- File: PkgNiHdlSettings.vhd
--
------------------------------------------------------------------------------------------
-- (c) 2026 Copyright National Instruments Corporation
--
-- SPDX-License-Identifier: MIT
------------------------------------------------------------------------------------------
--
-- Purpose:
--   GENERATED FILE - DO NOT EDIT.
--
--   This package is generated from nihdlsettings.py (the single source of truth
--   shared with the LabVIEW FPGA target plugin) by the nihdl tooling. It exposes
--   those settings to the HDL so the UserHdl block can self-check them during
--   elaboration (synthesis and simulation):
--
--     kMaxHdlRegOffset : maximum byte offset available for HDL registers
--                        (from set_max_hdl_reg_offset)
--     kNumHdlFifos     : number of user HDL DMA FIFOs reserved for UserHdl
--                        (from set_num_hdl_fifos)
--     kNumFixedLogicDmaStreams : number of DMA streams consumed by the fixed
--                        (non-user) logic; user HDL FIFOs occupy the DMA
--                        channels just below these (derived from target family)
--
--   This template is shared by all targets; the per-target values come from
--   each target's nihdlsettings.py.
--
------------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package PkgNiHdlSettings is

  constant kMaxHdlRegOffset         : natural := 1024;
  constant kNumHdlFifos             : natural := 2;
  constant kNumFixedLogicDmaStreams : natural := 4;

end PkgNiHdlSettings;
