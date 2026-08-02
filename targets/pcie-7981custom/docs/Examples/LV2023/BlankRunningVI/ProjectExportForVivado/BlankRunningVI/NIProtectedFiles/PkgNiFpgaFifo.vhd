-------------------------------------------------------------------------------
--
-- File: PkgNiFpgaFifo.vhd
-- Author: Dustyn Blasig
-- Original Project: LabVIEW FPGA Fifos
-- Date: 18 August 2008
--
-------------------------------------------------------------------------------
-- (c) 2008 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
--
--   Types, constants, and utility functions.
--
-------------------------------------------------------------------------------

package PkgNiFpgaFifo is

  type FifoRamType_t is (kFlipFlop, kDistributed, kBlock, kUltra);

  function GetPopBufferDepth (kRamLatency : natural) return positive;
  function GetPopBufferDepth (kRamLatency : natural;
                              kRamType    : FifoRamType_t;
                              kSingleClock: boolean) return positive;
  
end PkgNiFpgaFifo;

package body PkgNiFpgaFifo is

  function GetPopBufferDepth (kRamLatency : natural) return positive is
    -- currently the pop buffer depth is calculated as 4 more than the ram read
    -- latency. this calculation is based on the original pop buffer design
    -- that did not calculate true full count values. the current design should
    -- work appropriately with the two more than the ram latency but we have
    -- yet to prove that formally so we're playing it safe.
  begin
    return kRamLatency + 4;
  end function GetPopBufferDepth;

  function GetPopBufferDepth (kRamLatency : natural;
                              kRamType    : FifoRamType_t;
                              kSingleClock: boolean) return positive is
    -- Since single clock fifo implementation uses the entire RAM address space,
    -- the total size is 2^N + buffersize, compared to 2^N-1+buffersize of the
    -- original dual clock version. In order to keep the total size the same as before,
    -- the buffer size is reduced by 1 for the single clock fifo, which should still
    -- guarantee correct behavior.
  begin
    if kRamType=kBlock and kSingleClock then
      return GetPopBufferDepth(kRamLatency)-1;
    else
      return GetPopBufferDepth(kRamLatency);
    end if;
  end function GetPopBufferDepth;

end PkgNiFpgaFifo;
