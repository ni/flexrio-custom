------------------------------------------------------------------------------
--
-- File: PkgNiFpgaIrq.vhd
-- Author: Asrar Rangwala
-- Original Project: DRAGOnFLI Interface
-- Date: 31 January 2010
--
------------------------------------------------------------------------------
-- (c) 2010 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
------------------------------------------------------------------------------
--
-- Purpose: This package file contains register offsets for registers that are
--          used by the LabVIEW FPGA IRQ module.
--
------------------------------------------------------------------------------

library work;
  use work.PkgCommIntConfiguration.all;

package PkgNiFpgaIrqRegisters is

  -- Registers:
  --   Interrupt Enable : Bit 0: R/W. Interrupt Enable - Set this bit to a
  --                       '1' to enable all the interrupts from the FPGA.
  --                       This applies to FPGA VI and IP interrupts.
  --                      Bit 1: R. IRQ Interrupt - This bit reads a '1' if
  --                       the IRQ line is asserted. This applies to FPGA
  --                       VI and IP interrupts.
  --
  --   Mask :             Bits 31-0: R/W. Writing an individual bit with a
  --                       '1' enables the corresponding interrupt.
  --                       Writing a '0' disables the interrupt. This
  --                       applies only to FPGA VI interrupts.
  --
  --   Status :           Bits 31-0: R/W. Write a '1' to any bit to clear the
  --                       corresponding interrupt. Read this register to
  --                       determine which interrupts are set. This applies
  --                       only to FPGA VI interrupts.
  --

  -- Convert the unit of irq base offset to word as RegPort advertises word 
  -- addresses.
  constant kIrqBaseWordOffset : natural := kIrqBaseOffset / 4;
  
  -- Register offsets
  constant kIeRegOffset     : natural := kIrqBaseWordOffset;
  constant kMaskRegOffset   : natural := kIrqBaseWordOffset + 2;
  constant kStatusRegOffset : natural := kIrqBaseWordOffset + 3;
  
  -- Bit offsets
  constant kIrqEnableBitOffset    : natural := 0;
  constant kIrqInterruptBitOffset : natural := 1;
  
end package PkgNiFpgaIrqRegisters;