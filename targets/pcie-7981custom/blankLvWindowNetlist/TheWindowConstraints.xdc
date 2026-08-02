
# BEGIN_LV_FPGA_PERIOD_CONSTRAINTS

 set ToplevelClockPeriod 12.490


# END_LV_FPGA_PERIOD_CONSTRAINTS

# BEGIN_LV_FPGA_CLIP_CONSTRAINTS

 
#niFpga_Keep

current_instance TheLvWindowWrapper/TheLvWindow/theCLIPs/Routing_CLIP0/RegisteredRouting_1
#########################################################################################
## Clock Crossing
#########################################################################################

# # this data is resynced across from the Clk100 to the bus clock.
# set_false_path \
#     -from [get_pins {*/SyncPulse.sSyncPulseTimestampReg_reg[*]/C}] \
#     -to   [get_pins {*/SyncPulse.bSyncPulseTimestampReg_ms_reg[*]/D}]

# This might be a little too liberal, but it gets the job done
set hsPath */HBx

set_false_path \
    -from [get_pins ${hsPath}/BlkIn.iLclStoredData_reg[*]/C] \
    -to   [get_pins ${hsPath}/BlkOut.ODataFlop/GenFlops[*].DFlopx/GenClr.ClearFDCPEx/D]

set_false_path \
    -from [get_pins ${hsPath}/BlkIn.iPushToggle_reg/C] \
    -to   [get_pins ${hsPath}/BlkOut.oPushToggle0_ms_reg/D]

set_false_path \
    -from [get_pins ${hsPath}/BlkOut.oPushToggleToReady_reg/C] \
    -to   [get_pins ${hsPath}/BlkRdy.iRdyPushToggle_ms_reg/D]

# Specialize boolean handshake
set_false_path \
    -from [get_pins */HandshakeBasex/BlkIn.iPushToggle_reg/C] \
    -to   [get_pins */HandshakeBasex/BlkOut.oPushToggle0_ms_reg/D]

set_false_path \
    -from [get_pins SyncPulse.sSyncPulseAssert_reg/C] \
    -to   [get_pins TClkBlock.Measurement.TdcAssertSender.dSyncPulseCap_ms_reg/D]

set_false_path \
    -from [get_pins TClkBlock.Measurement.TdcAssertSender.dTDCAssertLcl_reg/C] \
    -to   [get_pins TClkBlock.Measurement.DeassertSender.sTDCAssert_ms_reg/D]

set_false_path \
    -from [get_pins TClkBlock.Measurement.DeassertSender.sTdcDeassertTclk_reg/C] \
    -to   [get_pins TClkBlock.Measurement.TdcAssertSender.dTdcDeassertTclk_ms_reg/D]

# added for GPIO to GPIO debug register
# Note, a -from constraint might be a good idea on this
#set_false_path -to [get_pins RoutingRegisterInterfaceBlock.gpio_ms_reg[*]/D]

set_false_path -to [get_pins TClkBlock.Measurement.DoubleSynchronizeSignals.*_ms_reg/D]

#########################################################################################
## Trigger Routing Exceptions
#########################################################################################

set base "RoutingMuxBlock.PxiTriggerRouting_1"

########## Exception for PxiTrigger Muxes

# We want the PxiTrigger routing matrix to be (almost) fully asynchronous, in that we
# don't want timing analyzed through the PXI Triggers. There is one exception to this:
# timing should be analyzed for the Sync Pulse Generator, because we need to meet Clk10
# timing on it.

# If we had no synchronous paths in our routing matrix, all we would have to do to achieve
# a fully asynchronous matrix would be to false-path all outputs of the matrix, namely all
# the PXI Triggers. But because of our Sync Pulse Exception, we can't do that. Instead,
# we'll false-path all _inputs_ to the matrix (Data as well as Selectors), with the
# exception of the Sync Pulse, of course.

# First, grab all the PxiTrigger Mux cells.
set muxes [get_cells $base/PxiTrigToBusGen[*].PxiTrigToBusMux]

# Now false-path all the selector pins from each mux
set selectors [get_pins -of $muxes -filter {NAME =~ *aInputSel[*]}]
set_false_path -through $selectors

# Now grab the input vector elements:
set inputs [get_pins -of $muxes -filter {NAME =~ *aInputVec[*]}]
# and filter out input pin 2, since that's the one sourced by aSourceSyncPulse.
set inputs [filter $inputs {NAME !~ *aInputVec[2]}]
# We can false path the remaining paths.
set_false_path -through $inputs

########## Exception for Destination Muxes

# Analogously to the above, we want a routing matrix that is asynchronous to all destinations except for the Sync Pulse Synchronizer. All other destinations will be double-synchronized into the
# user's clock domain upon entering the diagram, and we want to prevent spurious
# clock-domain crossings.

# To achieve this, we need to do 2 things:
#
#  1. False path the output of all routing muxes, except for the one that goes to the Sync
#     Pulse Synchronizer.
#
#  2. For the Sync Pulse Synchronizer, false path the mux selectors and all mux inputs
#     which are _not_ PXI Triggers, so that the timing analyzer doesn't see a potential
#     clock-crossing path between one of the local FPGA sources and the Sync Pulse
#     Synchronizer.
#
# Of course, we could do #2 to all Muxes, but that's not necessary once their outputs have
# been false-pathed.

# First we need to gather all the DestinationMux cells
set muxes [get_cells $base/DestinationGen[*].DestinationMux]

# Filter out Destination 0, which is always the Sync Pulse.
set muxes [filter $muxes {NAME !~ *DestinationGen[0].DestinationMux}]

# Grab the output pins for all the selected muxes, false-path them.
set outputs [get_pins -of $muxes -filter {NAME =~ *aMuxOut}]
set_false_path -through $outputs

# Now grab _only_ mux 0.
set muxes [get_cells $base/DestinationGen[0].DestinationMux]

# Get and false-path its selectors.
set selectors [get_pins -of $muxes -filter {NAME =~ *aInputSel[*]}]
set_false_path -through $selectors

# Now grab the input vector elements:
set inputs [get_pins -of $muxes -filter {NAME =~ *aInputVec[*]}]
# and filter out input pins 2-10, since those are the PxiTriggers (including Star).
set inputs [filter -regexp $inputs {NAME !~ ".*aInputVec\[([2-9]|10)\]"}]
# We can false path the remaining paths.
set_false_path -through $inputs

########## Exception for Debug Registers

# There are two sets of registers that track the status of the destinations and gpio. We
# will false-path the input to those, since they are double-synchronized.

set destregs [get_cells RoutingRegisterInterfaceBlock.dest_ms_reg*]
set destpins [get_pins -of $destregs -filter {REF_PIN_NAME == D}]

set_false_path -through $destpins

set gpioregs [get_cells RoutingRegisterInterfaceBlock.gpio_ms_reg*]
set gpiopins [get_pins -of $gpioregs -filter {REF_PIN_NAME == D}]

set_false_path -through $gpiopins

#########################################################################################
## Sync Pulse Identity
#########################################################################################

# We need to identify the FFs that generate / consume the SyncPulse, and store their name
# in a variable. Then the top-level constraints for each target will use that information
# to properly constrain the trigger path.

set TriggerClipSyncPulseSrc [get_cells SyncPulse.aSourceSyncPulseInt_reg]
set TriggerClipSyncPulseDest [get_cells SyncPulse.sSyncPulseCap_ms_reg]
current_instance


#niFpga_EndKeep





# END_LV_FPGA_CLIP_CONSTRAINTS

set TopInstanceLvTargetFromTo [current_instance .]
current_instance TheLvWindowWrapper
# BEGIN_LV_FPGA_FROM_TO_CONSTRAINTS

 set TNM_Custom1 [get_cells {*n_bushold/*ShiftRegister/SyncBusReset/*iHoldSigInx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom2 [get_cells {*n_bushold/*ShiftRegister/SyncBusReset/*oHoldSigIn_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom3 [get_cells {*n_bushold/*ShiftRegister/SyncBusReset/*oLocalSigOutx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom4 [get_cells {*n_bushold/*ShiftRegister/SyncBusReset/*iSigOut_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom5 [get_cells {*n_bushold/*ShiftRegister/SyncBusReset/*oLocalSigOutCEx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom7 [get_cells {*DmaPortCommIfcIrqInterfacex/DoubleSyncSLx*iDlySigx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom8 [get_cells {*DmaPortCommIfcIrqInterfacex/DoubleSyncSLx*DoubleSyncAsyncInBasex/oSig_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom9 [get_cells {*DmaPortCommIfcLvFpgaIrq*bIpIrq_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom10 [get_cells {*DmaPortCommIfcLvFpgaIrq*bIpIrq*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom11 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom12 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom13 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom14 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom16 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom17 [get_cells {*ViControlx*BusClkToReliableClkHS/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom18 [get_cells {*ViControlx*BusClkToReliableClkHS/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom19 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom20 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom21 [get_cells {*ViControlx*BusClkToReliableClkHS/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom22 [get_cells {*ViControlx*BusClkToReliableClkHS/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom23 [get_cells {*ViControlx*BusClkToReliableClkHS/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom24 [get_cells {*ViControlx*BusClkToReliableClkHS/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom25 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom26 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom27 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom28 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom29 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom30 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom31 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom32 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom33 [get_cells {*ViControlx*rEnableIn*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom34 [get_cells {*ViControlx*tEnableIn_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom35 [get_cells {*ViControlx*rEnableClear*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom36 [get_cells {*ViControlx*tEnableClear_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom38 [get_cells {*ViControlx*bEnableIn_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom40 [get_cells {*ViControlx*bEnableClear_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom41 [get_cells {*ViControlx*rDerivedClkLostLock*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom42 [get_cells {*ViControlx*bDerivedClkLostLock_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom43 [get_cells {*ViControlx*rGatedClkStartupErr*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom44 [get_cells {*ViControlx*bGatedClkStartupErr_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom45 [get_cells {*ViControlx*rEnableDeassertionErr*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom46 [get_cells {*ViControlx*bEnableDeassertionErr_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom47 [get_cells {*DiagramResetx*rDiagramResetAssertionErr*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom48 [get_cells {*ViControlx*bDiagramResetAssertionErr_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom49 [get_cells {*ViControlx*tDiagramEnableOutReg*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom50 [get_cells {*ViControlx*bEnableOut_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom51 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom52 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom53 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom54 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom56 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom57 [get_cells {*DiagramResetx*BusClkToReliableClkHS/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom58 [get_cells {*DiagramResetx*BusClkToReliableClkHS/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom59 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom60 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom61 [get_cells {*DiagramResetx*BusClkToReliableClkHS/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom62 [get_cells {*DiagramResetx*BusClkToReliableClkHS/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom63 [get_cells {*DiagramResetx*BusClkToReliableClkHS/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom64 [get_cells {*DiagramResetx*BusClkToReliableClkHS/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom65 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom66 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom67 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom68 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom69 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom70 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom71 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom72 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom73 [get_cells {*DiagramResetx*rSafeToEnableGatedClksLoc*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom74 [get_cells {*DiagramResetx*rDiagramResetForHost*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom75 [get_cells {*DiagramResetx*bDiagramResetForHost_ms*} -filter {IS_SEQUENTIAL==true}]


set_max_delay -from $TNM_Custom1 -to $TNM_Custom2 -datapath_only 29.2470003000
set_max_delay -from $TNM_Custom3 -to $TNM_Custom4 -datapath_only 29.2470003000
set_max_delay -from $TNM_Custom5 -to $TNM_Custom4 -datapath_only 29.2470003000
set_max_delay -from $TNM_Custom7 -to $TNM_Custom8 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom9 -to $TNM_Custom10 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom11 -to $TNM_Custom12  24.4975002500
set_max_delay -from $TNM_Custom21 -to $TNM_Custom22 -datapath_only 4.8745000500
set_max_delay -from $TNM_Custom23 -to $TNM_Custom24 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom25 -to $TNM_Custom26 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom27 -to $TNM_Custom28 -datapath_only 4.8745000500
set_max_delay -from $TNM_Custom29 -to $TNM_Custom30 -datapath_only 4.8745000500
set_max_delay -from $TNM_Custom31 -to $TNM_Custom32 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom33 -to $TNM_Custom34 -datapath_only 73.4925007499
set_max_delay -from $TNM_Custom35 -to $TNM_Custom36 -datapath_only 73.4925007499
set_max_delay -from $TNM_Custom33 -to $TNM_Custom38 -datapath_only 12.2487501250
set_max_delay -from $TNM_Custom35 -to $TNM_Custom40 -datapath_only 12.2487501250
set_max_delay -from $TNM_Custom41 -to $TNM_Custom42 -datapath_only 73.4925007499
set_max_delay -from $TNM_Custom43 -to $TNM_Custom44 -datapath_only 73.4925007499
set_max_delay -from $TNM_Custom45 -to $TNM_Custom46 -datapath_only 73.4925007499
set_max_delay -from $TNM_Custom47 -to $TNM_Custom48 -datapath_only 73.4925007499
set_max_delay -from $TNM_Custom49 -to $TNM_Custom50 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom51 -to $TNM_Custom52  24.4975002500
set_max_delay -from $TNM_Custom61 -to $TNM_Custom62 -datapath_only 4.8745000500
set_max_delay -from $TNM_Custom63 -to $TNM_Custom64 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom65 -to $TNM_Custom66 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom67 -to $TNM_Custom68 -datapath_only 4.8745000500
set_max_delay -from $TNM_Custom69 -to $TNM_Custom70 -datapath_only 4.8745000500
set_max_delay -from $TNM_Custom71 -to $TNM_Custom72 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom73  -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom74 -to $TNM_Custom75 -datapath_only 12.2487501250
set_max_delay -from $TNM_Custom53 -to $TNM_Custom54 -datapath_only 19.4980002000
set_max_delay -from $TNM_Custom13 -to $TNM_Custom14 -datapath_only 19.4980002000
set_max_delay -from $TNM_Custom57 -to $TNM_Custom58 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom17 -to $TNM_Custom18 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom59 -to $TNM_Custom60 -datapath_only 9.7490001000
set_max_delay -from $TNM_Custom51 -to $TNM_Custom56 -datapath_only 9.7490001000
set_max_delay -from $TNM_Custom19 -to $TNM_Custom20 -datapath_only 9.7490001000
set_max_delay -from $TNM_Custom11 -to $TNM_Custom16 -datapath_only 9.7490001000





# This constraint is required to disable the tools from performing timing 
# analysis on the aDiagramResetLoc net which is meant to be used as an 
# asynchronous reset. This constraint is really only required for 
# Spartan6/Virtex 6/Kintex7/Zynq/Virtex7 and later devices as the tools perform 
# asynchronous reset  recovery timing analysis for these devices, but it doesn't 
# hurt to have them for other devices as well.
# Please note that this constraint is required in addition to having 
# "DISABLE = reg_sr_r;" constraint, as the DISABLE constraint is buggy 
# and does not disable timing analysis for asynchronous resets in certain
# situations.
# It is possible that we would remove the DISABLE constraint and keep
# the timing ignore constraint, but this has not been verified.
#There is no equivalent flag known yet in Vivado for DISABLE=reg_sr_r;
#set_false_path is used to ignore reset recovery checks of  
#asynchronous reset paths on clock domains crossing 
set_false_path -through [get_nets {*DiagramResetx*aDiagramResetLoc*}]



# END_LV_FPGA_FROM_TO_CONSTRAINTS
current_instance -quiet
current_instance $TopInstanceLvTargetFromTo

