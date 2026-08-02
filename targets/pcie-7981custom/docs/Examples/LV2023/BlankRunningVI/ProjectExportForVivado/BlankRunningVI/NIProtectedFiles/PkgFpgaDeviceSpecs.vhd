-------------------------------------------------------------------------------
--
-- File: PkgFpgaDeviceSpecs.vhd
-- Author: Laszlo3 Nagy
-- Original Project: 
-- Date: 13 December 2012
--
-------------------------------------------------------------------------------
--
-- Purpose:
--
--   This package is intended to contain information about in-use FPGA capabilities.
--   It is dynamically generated from G code based on selected FPGA target device.
--
-------------------------------------------------------------------------------


package PkgFpgaDeviceSpecs is


  type DeviceFamily_t is(
    Artix7,
    Kintex7,
    kintexu,
    kintexup,
    qrvitex5,
    spartan3,
    spartan3adsp,
    spartan3e,
    spartan6,
    versalaicore,
    versalaiedge,
    versalhbm,
    versalpremium,
    versalprime,
    Virtex2,
    Virtex2P,
    Virtex5,
    Virtex6,
    Virtex7,
    virtexup,
    Zynq,
    zynquplus
  );

  -- CONSTANTS ----------------------------------------------------------------
  -- Current FPGA description  
  
  constant kDeviceFamily  : DeviceFamily_t  := kintexu;

  constant kUseLutRamPopBuffers : boolean := true;

   -- FUNCTIONS ----------------------------------------------------------------

end PkgFpgaDeviceSpecs;

