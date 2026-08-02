-------------------------------------------------------------------------------
--
-- File: DmaPortCommIfcSimpleDualPortRAM_ByteEnable.vhd
-- Author: Florin Hurgoi
-- Original Project: Zynq support for LabVIEW FPGA
-- Date: 08 February 2012
--
-------------------------------------------------------------------------------
-- (c) 2011 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--
--  This component was written based on the information provided in the XST User Guide
--   for Virtex-6, Spartan-6 and 7 Series Devices, UG687 (v 13.2) July 6, 2011.
--
--  This component will always infer block RAM for any RAM size.
--   The RAM smaller than 512 bits will be inferred using distributed RAM and
--   everithing above will use block RAM. This approach will lead to optimal performance.
--
--  Component configuraion:
--   kAddrWidth is the number of address bits needed to represent the number
--    of RAM locations.
--   kDataWidth is the width of the input and output data buses. The data port width
--    needs to be a power of two.
--   kReadDataLatency sets the component read latency to 1 or 2 OClk. When the read
--    latency is set to 2 the BRAM's optional output register will be used.
--
--  What has been specifically verified to synthesize a Block RAM:
--  *  Xilinx ISE 13.4 (kRamReadLatency = 1, or 2)
--        Spartan 6
--        Kintex 7
--
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.PkgNiUtilities.all;

entity DmaPortCommIfcSimpleDualPortRAM_ByteEnable is

  generic (
    kAddrWidth  : integer := 10;
    kDataWidth  : integer := 64;
    kReadDataLatency : integer range 1 to 2 :=1
  );

  port (
    IClk          : in std_logic;
    iWrite        : in BooleanVector(kDataWidth/8-1 downto 0);
    iAddr         : in unsigned(kAddrWidth-1 downto 0);
    iDataIn       : in std_logic_vector(kDataWidth-1 downto 0);

    OClk          : in std_logic;
    oReset        : in boolean;
    oAddr         : in unsigned(kAddrWidth-1 downto 0);
    oDataOut      : out std_logic_vector(kDataWidth-1 downto 0)
  );

end DmaPortCommIfcSimpleDualPortRAM_ByteEnable;


architecture rtl of DmaPortCommIfcSimpleDualPortRAM_ByteEnable is

  


begin

  --vhook_e NiFpgaSimpleDualPortRAM_ByteEnable
  NiFpgaSimpleDualPortRAM_ByteEnablex: entity work.NiFpgaSimpleDualPortRAM_ByteEnable (rtl)
    generic map (
      kAddrWidth       => kAddrWidth,        -- in  integer := 10
      kDataWidth       => kDataWidth,        -- in  integer := 64
      kReadDataLatency => kReadDataLatency)  -- in  integer range 1 to 2 := 1
    port map (
      IClk     => IClk,      -- in  std_logic
      iWrite   => iWrite,    -- in  BooleanVector(kDataWidth / 8-1 downto 0)
      iAddr    => iAddr,     -- in  unsigned(kAddrWidth-1 downto 0)
      iDataIn  => iDataIn,   -- in  std_logic_vector(kDataWidth-1 downto 0)
      OClk     => OClk,      -- in  std_logic
      oReset   => oReset,    -- in  boolean
      oAddr    => oAddr,     -- in  unsigned(kAddrWidth-1 downto 0)
      oDataOut => oDataOut); -- out std_logic_vector(kDataWidth-1 downto 0)

end rtl;
