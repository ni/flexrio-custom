-------------------------------------------------------------------------------
--
-- File: PkgNiFpgaViControlRegister.vhd
-- Author: Newton Petersen
-- Original Project: Derived Clocks
-- Date: 18 December 2009
--
-------------------------------------------------------------------------------
-- (c) 2009 Copyright National Instruments Corporation
-- All Rights Reserved
-- National Instruments Internal Information
-------------------------------------------------------------------------------
--
-- Purpose:
-- This file provides a common location for constants defining
-- the bit locations of control bits in the control register.
--
-------------------------------------------------------------------------------
package PkgNiFpgaViControlRegister is

--   ViControl Register Bits:
--     The control register is made up of muliple bits as described below.
--
--     Bit 0: EnableOut (R) :     This bit is asserted by the FPGA to indicate 
--                                that the diagram has finished execution. It 
--                                remains asserted until EnableClear asserts.
--     Bit 1: EnableIn (R/W) :    This bit is asserted to start the diagram 
--                                execution. It can only be asserted by the 
--                                host, except for the first diagram execution
--                                of the Autorun bitstream, which is started by
--                                the FPGA. It should remain asserted until 
--                                EnableClear asserts. If kInitDuration > 0:
--                                when de-asserted, EnableIn will remain 
--                                de-asserted for kInitDuration. Any request to 
--                                assert EnableIn will be defered until the end 
--                                of this period.
--     Bit 2: EnableClear (R/W) : This bit can only be controlled by the Host. It 
--                                provides a mechanism of resetting the enable
--                                chain for subsequent diagram execution.
--     Bit 4: Timeout (R) :       This bit is asserted to indicate that a 
--                                timeout has occured during a rd/wt register  
--                                access by the host.
--     Bit 5: ExecutionDisabled(R) :  
--                                This bit is asserted to indicate that the 
--                                execute-disable signal provided by the   
--                                socketed CLIP signals indicated that 
--                                execution is being actively prevented.
--                                Please refer to the Plugin Manual's ViControl
--                                section for additional information
--     Bit 6: Derived Clock Lost Lock (R) :
--                                This bit indicates a derived clock lost lock
--                                sometime when the diagram reset was not 
--                                asserted.
--     Bit 7: Gated Clocks Startup Error (R) :
--                                This bit indicates if a gated base or derived
--                                clock started running before the clock enable
--                                asserted or after the clock valid signal asserted.
--     Bit 8: Enable Deassertion Not Supported Error (R) :
--                                This bit indicates if Enable deassertion was 
--                                requested when enable removal optimization was set - 
--                                Enable deassertion is not supported in this case.
--     Bit 9: Diagram Reset Assertion Not Supported Error (R):
--                                This bit indicates if Diagram Reset assertion was
--                                requested by the host when enable removal optimization
--                                was set - Diagram reset assertion is not supported
--                                in this case.
  constant kEnableOutBit                            : integer := 0;
  constant kEnableInBit                             : integer := 1;
  constant kEnableClearBit                          : integer := 2;
  constant kTimeoutBit                              : integer := 4;
  constant kExecuteDisableBit                       : integer := 5;
  constant kLostLockBit                             : integer := 6;
  constant kGatedClkStartupErrBit                   : integer := 7;
  constant kEnableDeassertionNotSupportedErrBit     : integer := 8;
  constant kDiagramResetAssertionNotSupportedErrBit : integer := 9;
  
end package PkgNiFpgaViControlRegister;  
