
# BEGIN_LV_FPGA_PERIOD_CONSTRAINTS

 set ToplevelClockPeriod 12.490


# END_LV_FPGA_PERIOD_CONSTRAINTS

# BEGIN_LV_FPGA_CLIP_CONSTRAINTS

 
#niFpga_Keep

set RoutingClipInstanceRestore [current_instance .]
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
current_instance $RoutingClipInstanceRestore


#niFpga_EndKeep





# END_LV_FPGA_CLIP_CONSTRAINTS

set TopInstanceLvTargetFromTo [current_instance .]
current_instance TheLvWindowWrapper
# BEGIN_LV_FPGA_FROM_TO_CONSTRAINTS

 set TNM_Custom1 [get_cells {*PllClk80ToInterface/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom2 [get_cells {*PllClk80ToInterface/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom3 [get_cells {*PllClk80ToInterface/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom4 [get_cells {*PllClk80ToInterface/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom6 [get_cells {*PllClk80ToInterface/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom7 [get_cells {*PllClk80ToInterface/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom8 [get_cells {*PllClk80ToInterface/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom9 [get_cells {*PllClk80ToInterface/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom10 [get_cells {*PllClk80ToInterface/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom11 [get_cells {*PllClk80ToInterface/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom12 [get_cells {*PllClk80ToInterface/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom13 [get_cells {*PllClk80ToInterface/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom14 [get_cells {*PllClk80ToInterface/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom15 [get_cells {*PllClk80ToInterface/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom16 [get_cells {*PllClk80ToInterface/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom17 [get_cells {*PllClk80ToInterface/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom18 [get_cells {*PllClk80ToInterface/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom19 [get_cells {*PllClk80ToInterface/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom20 [get_cells {*PllClk80ToInterface/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom21 [get_cells {*PllClk80ToInterface/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom22 [get_cells {*PllClk80ToInterface/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom23 [get_cells {*PllClk80FromInterface/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom24 [get_cells {*PllClk80FromInterface/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom25 [get_cells {*PllClk80FromInterface/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom26 [get_cells {*PllClk80FromInterface/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom28 [get_cells {*PllClk80FromInterface/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom29 [get_cells {*PllClk80FromInterface/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom30 [get_cells {*PllClk80FromInterface/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom31 [get_cells {*PllClk80FromInterface/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom32 [get_cells {*PllClk80FromInterface/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom33 [get_cells {*PllClk80FromInterface/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom34 [get_cells {*PllClk80FromInterface/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom35 [get_cells {*PllClk80FromInterface/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom36 [get_cells {*PllClk80FromInterface/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom37 [get_cells {*PllClk80FromInterface/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom38 [get_cells {*PllClk80FromInterface/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom39 [get_cells {*PllClk80FromInterface/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom40 [get_cells {*PllClk80FromInterface/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom41 [get_cells {*PllClk80FromInterface/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom42 [get_cells {*PllClk80FromInterface/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom43 [get_cells {*PllClk80FromInterface/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom44 [get_cells {*PllClk80FromInterface/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom45 [get_cells {*n_bushold/*ShiftRegister/SyncBusReset/*iHoldSigInx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom46 [get_cells {*n_bushold/*ShiftRegister/SyncBusReset/*oHoldSigIn_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom47 [get_cells {*n_bushold/*ShiftRegister/SyncBusReset/*oLocalSigOutx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom48 [get_cells {*n_bushold/*ShiftRegister/SyncBusReset/*iSigOut_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom49 [get_cells {*n_bushold/*ShiftRegister/SyncBusReset/*oLocalSigOutCEx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom51 [get_cells {*DmaPortCommIfcIrqInterfacex/DoubleSyncSLx*iDlySigx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom52 [get_cells {*DmaPortCommIfcIrqInterfacex/DoubleSyncSLx*DoubleSyncAsyncInBasex/oSig_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom53 [get_cells {*DmaPortCommIfcLvFpgaIrq*bIpIrq_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom54 [get_cells {*DmaPortCommIfcLvFpgaIrq*bIpIrq*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom55 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToBusClkDomain/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom56 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToBusClkDomain/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom57 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToBusClkDomain/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom58 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToBusClkDomain/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom60 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToBusClkDomain/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom61 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToBusClkDomain/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom62 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToBusClkDomain/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom63 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToBusClkDomain/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom64 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToBusClkDomain/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom65 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToBusClkDomain/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom66 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToBusClkDomain/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom67 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToBusClkDomain/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom68 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToBusClkDomain/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom69 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToBusClkDomain/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom70 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToBusClkDomain/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom71 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToBusClkDomain/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom72 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToBusClkDomain/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom73 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToBusClkDomain/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom74 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToBusClkDomain/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom75 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToBusClkDomain/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom76 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToBusClkDomain/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom77 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflowStopRequest/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom78 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflowStopRequest/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom79 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflowStopRequest/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom80 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflowStopRequest/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom82 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflowStopRequest/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom83 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflowStopRequest/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom84 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflowStopRequest/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom85 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflowStopRequest/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom86 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflowStopRequest/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom87 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflowStopRequest/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom88 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflowStopRequest/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom89 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflowStopRequest/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom90 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflowStopRequest/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom91 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflowStopRequest/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom92 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflowStopRequest/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom93 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflowStopRequest/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom94 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflowStopRequest/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom95 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflowStopRequest/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom96 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflowStopRequest/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom97 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflowStopRequest/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom98 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflowStopRequest/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom99 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflow/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom100 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflow/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom101 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflow/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom102 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflow/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom104 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflow/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom105 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflow/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom106 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflow/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom107 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflow/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom108 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflow/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom109 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflow/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom110 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflow/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom111 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflow/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom112 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflow/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom113 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflow/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom114 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflow/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom115 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflow/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom116 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflow/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom117 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflow/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom118 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflow/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom119 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflow/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom120 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeOverflow/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom121 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom122 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom123 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom124 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom126 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom127 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom128 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom129 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom130 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom131 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom132 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom133 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom134 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom135 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom136 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom137 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom138 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom139 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom140 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom141 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom142 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom143 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom144 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom145 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom146 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom148 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom149 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionTimeoutRequest/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom150 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionTimeoutRequest/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom151 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom152 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom153 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionTimeoutRequest/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom154 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionTimeoutRequest/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom155 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionTimeoutRequest/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom156 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionTimeoutRequest/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom157 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom158 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom159 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom160 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom161 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom162 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom163 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom164 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom165 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom166 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionRequest/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom167 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionRequest/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom168 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionRequest/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom170 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom171 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionRequest/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom172 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionRequest/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom173 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionRequest/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom174 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionRequest/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom175 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionRequest/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom176 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionRequest/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom177 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionRequest/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom178 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionRequest/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom179 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom180 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom181 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom182 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom183 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionRequest/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom184 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionRequest/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom185 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionRequest/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom186 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StartEnableChain*HandshakeTransitionRequest/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom187 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom188 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom189 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom190 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom192 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom193 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionTimeoutRequest/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom194 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionTimeoutRequest/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom195 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom196 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom197 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionTimeoutRequest/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom198 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionTimeoutRequest/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom199 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionTimeoutRequest/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom200 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionTimeoutRequest/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom201 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom202 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom203 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom204 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom205 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom206 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom207 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom208 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom209 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom210 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionRequest/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom211 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionRequest/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom212 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionRequest/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom214 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom215 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionRequest/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom216 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionRequest/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom217 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionRequest/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom218 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionRequest/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom219 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionRequest/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom220 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionRequest/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom221 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionRequest/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom222 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionRequest/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom223 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom224 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom225 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom226 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom227 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionRequest/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom228 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionRequest/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom229 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionRequest/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom230 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopEnableChain*HandshakeTransitionRequest/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom231 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom232 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionTimeoutRequest/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom233 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionTimeoutRequest/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom234 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom236 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom237 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionTimeoutRequest/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom238 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionTimeoutRequest/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom239 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionTimeoutRequest/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom240 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom241 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionTimeoutRequest/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom242 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionTimeoutRequest/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom243 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionTimeoutRequest/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom244 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionTimeoutRequest/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom245 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom246 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom247 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom248 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom249 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom250 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom251 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom252 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom253 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom254 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionRequest/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom255 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionRequest/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom256 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionRequest/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom258 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom259 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionRequest/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom260 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionRequest/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom261 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionRequest/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom262 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionRequest/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom263 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionRequest/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom264 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionRequest/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom265 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionRequest/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom266 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionRequest/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom267 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom268 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom269 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom270 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom271 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionRequest/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom272 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionRequest/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom273 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionRequest/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom274 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*StopWithFlushEnableChain*HandshakeTransitionRequest/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom275 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToViClkDomain/*iLclStoredData*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom276 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToViClkDomain/*ODataFlop**FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom277 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToViClkDomain/*iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom278 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToViClkDomain/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom279 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToViClkDomain/*oPushToggleToReady*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom280 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToViClkDomain/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom282 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToViClkDomain/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom283 [get_cells {*iReset_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom284 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToViClkDomain/*iReset*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom286 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToViClkDomain/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom287 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToDefaultClkDomain/*iLclStoredData*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom288 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToDefaultClkDomain/*ODataFlop**FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom289 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToDefaultClkDomain/*iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom290 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToDefaultClkDomain/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom291 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToDefaultClkDomain/*oPushToggleToReady*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom292 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToDefaultClkDomain/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom294 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToDefaultClkDomain/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom296 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToDefaultClkDomain/*iReset*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom298 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0]*HandshakeStateToDefaultClkDomain/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom299 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0].DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/OClkToIClkCrossing.SyncToIClk/oAck*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom300 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0].DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/OClkToIClkCrossing.SyncToIClk/iAckRcvd_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom302 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0].DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/OClkToIClkCrossing.SyncToIClk/iAckRcvd*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom303 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0].DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/OClkToIClkCrossing.SyncToIClk/iTogglePush*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom304 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0].DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/OClkToIClkCrossing.SyncToIClk/oPushRcvd_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom306 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0].DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/OClkToIClkCrossing.SyncToIClk/oPushRcvd*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom307 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0].DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/OClkToIClkCrossing.SyncToIClk/iDataToPush*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom308 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0].DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/OClkToIClkCrossing.SyncToIClk/DataReg/GenFlops[*].DFlopx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom309 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0].DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/iWriteSamplePtrUnsGray*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom310 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0].DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/SyncToOClk/GrayPtrClockCrossing.OutputGrayReg_ms/GenFlops[*].DFlopx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom311 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0].DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/iWritesDisabledSampPtrUnsGray*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom312 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0].DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/SyncToOClk/DisableSignalClockCrossing.SyncToOClk_ms/*DFlopx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom313 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0].DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/o*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom314 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[0].DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom315 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*.DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/PushSynchNeeded.FromPushDblSync*iDlySigx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom316 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*.DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/PushSynchNeeded.FromPushDblSync*DoubleSyncAsyncInBasex/oSig_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom317 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*.DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/PushSynchNeeded.ToPushDblSync*iDlySigx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom318 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*.DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/PushSynchNeeded.ToPushDblSync*DoubleSyncAsyncInBasex/oSig_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom319 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*.DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/NiFpgaFifoPortResetx/Crossing.PushToPop/*iHoldSigInx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom320 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*.DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/NiFpgaFifoPortResetx/Crossing.PushToPop/*oHoldSigIn_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom321 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*.DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/NiFpgaFifoPortResetx/Crossing.PushToPop/*oLocalSigOutx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom322 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*.DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/NiFpgaFifoPortResetx/Crossing.PushToPop/*iSigOut_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom323 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*.DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/NiFpgaFifoPortResetx/Crossing.PushToPop/*oLocalSigOutCEx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom325 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*.DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/NiFpgaFifoPortResetx/Crossing.PopToPush/*iHoldSigInx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom326 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*.DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/NiFpgaFifoPortResetx/Crossing.PopToPush/*oHoldSigIn_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom327 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*.DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/NiFpgaFifoPortResetx/Crossing.PopToPush/*oLocalSigOutx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom328 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*.DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/NiFpgaFifoPortResetx/Crossing.PopToPush/*iSigOut_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom329 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*.DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/NiFpgaFifoPortResetx/Crossing.PopToPush/*oLocalSigOutCEx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom331 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*.DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/NiFpgaFifoPortResetx/Crossing.ClearToPush*oRegisteredSigAck*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom332 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*.DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/NiFpgaFifoPortResetx/Crossing.ClearToPush*PulseSyncBasex*iSigOut_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom333 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*.DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/NiFpgaFifoPortResetx/Crossing.ClearToPush/*iHoldSigInx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom334 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*.DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/NiFpgaFifoPortResetx/Crossing.ClearToPush/*oHoldSigIn_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom335 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*.DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/NiFpgaFifoPortResetx/Crossing.ClearToPush/*oLocalSigOutx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom336 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*.DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/NiFpgaFifoPortResetx/Crossing.ClearToPush/*iSigOut_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom337 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*.DmaInput.DmaPortCommIfcInputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/NiFpgaFifoPortResetx/Crossing.ClearToPush/*oLocalSigOutCEx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom339 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToBusClkDomain/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom340 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToBusClkDomain/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom341 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToBusClkDomain/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom342 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToBusClkDomain/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom344 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToBusClkDomain/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom345 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToBusClkDomain/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom346 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToBusClkDomain/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom347 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToBusClkDomain/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom348 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToBusClkDomain/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom349 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToBusClkDomain/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom350 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToBusClkDomain/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom351 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToBusClkDomain/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom352 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToBusClkDomain/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom353 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToBusClkDomain/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom354 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToBusClkDomain/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom355 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToBusClkDomain/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom356 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToBusClkDomain/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom357 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToBusClkDomain/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom358 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToBusClkDomain/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom359 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToBusClkDomain/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom360 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToBusClkDomain/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom361 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflowStopRequest/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom362 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflowStopRequest/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom363 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflowStopRequest/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom364 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflowStopRequest/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom366 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflowStopRequest/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom367 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflowStopRequest/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom368 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflowStopRequest/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom369 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflowStopRequest/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom370 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflowStopRequest/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom371 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflowStopRequest/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom372 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflowStopRequest/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom373 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflowStopRequest/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom374 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflowStopRequest/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom375 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflowStopRequest/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom376 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflowStopRequest/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom377 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflowStopRequest/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom378 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflowStopRequest/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom379 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflowStopRequest/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom380 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflowStopRequest/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom381 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflowStopRequest/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom382 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflowStopRequest/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom383 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflow/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom384 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflow/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom385 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflow/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom386 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflow/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom388 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflow/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom389 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflow/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom390 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflow/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom391 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflow/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom392 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflow/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom393 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflow/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom394 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflow/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom395 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflow/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom396 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflow/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom397 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflow/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom398 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflow/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom399 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflow/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom400 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflow/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom401 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflow/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom402 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflow/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom403 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflow/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom404 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeUnderflow/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom405 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeFullCount/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom406 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeFullCount/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom407 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeFullCount/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom408 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeFullCount/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom410 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeFullCount/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom411 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeFullCount/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom412 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeFullCount/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom413 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeFullCount/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom414 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeFullCount/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom415 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeFullCount/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom416 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeFullCount/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom417 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeFullCount/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom418 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeFullCount/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom419 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeFullCount/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom420 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeFullCount/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom421 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeFullCount/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom422 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeFullCount/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom423 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeFullCount/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom424 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeFullCount/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom425 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeFullCount/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom426 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeFullCount/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom427 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom428 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom429 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom430 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom432 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom433 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionTimeoutRequest/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom434 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionTimeoutRequest/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom435 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom436 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom437 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionTimeoutRequest/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom438 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionTimeoutRequest/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom439 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionTimeoutRequest/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom440 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionTimeoutRequest/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom441 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom442 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom443 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom444 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom445 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom446 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom447 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom448 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom449 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom450 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionRequest/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom451 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionRequest/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom452 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionRequest/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom454 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom455 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionRequest/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom456 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionRequest/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom457 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionRequest/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom458 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionRequest/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom459 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionRequest/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom460 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionRequest/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom461 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionRequest/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom462 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionRequest/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom463 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom464 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom465 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom466 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom467 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionRequest/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom468 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionRequest/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom469 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionRequest/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom470 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StartEnableChain*HandshakeTransitionRequest/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom471 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom472 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom473 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom474 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom476 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom477 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionTimeoutRequest/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom478 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionTimeoutRequest/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom479 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom480 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom481 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionTimeoutRequest/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom482 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionTimeoutRequest/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom483 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionTimeoutRequest/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom484 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionTimeoutRequest/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom485 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom486 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom487 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom488 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom489 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom490 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom491 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom492 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionTimeoutRequest/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom493 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom494 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionRequest/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom495 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionRequest/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom496 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionRequest/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom498 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom499 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionRequest/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom500 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionRequest/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom501 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionRequest/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom502 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionRequest/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom503 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionRequest/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom504 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionRequest/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom505 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionRequest/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom506 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionRequest/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom507 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom508 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom509 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom510 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionRequest/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom511 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionRequest/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom512 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionRequest/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom513 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionRequest/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom514 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*StopEnableChain*HandshakeTransitionRequest/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom515 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToDefaultClkDomain/*iLclStoredData*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom516 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToDefaultClkDomain/*ODataFlop**FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom517 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToDefaultClkDomain/*iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom518 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToDefaultClkDomain/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom519 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToDefaultClkDomain/*oPushToggleToReady*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom520 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToDefaultClkDomain/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom522 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToDefaultClkDomain/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom524 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToDefaultClkDomain/*iReset*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom526 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1]*HandshakeStateToDefaultClkDomain/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom527 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortOutStrmFifox/DmaPortOutStrmFifoFlagsx/IClkToOClkCrossing.SyncToOClk/oAck*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom528 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortOutStrmFifox/DmaPortOutStrmFifoFlagsx/IClkToOClkCrossing.SyncToOClk/iAckRcvd_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom530 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortOutStrmFifox/DmaPortOutStrmFifoFlagsx/IClkToOClkCrossing.SyncToOClk/iAckRcvd*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom531 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortOutStrmFifox/DmaPortOutStrmFifoFlagsx/IClkToOClkCrossing.SyncToOClk/iTogglePush*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom532 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortOutStrmFifox/DmaPortOutStrmFifoFlagsx/IClkToOClkCrossing.SyncToOClk/oPushRcvd_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom534 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortOutStrmFifox/DmaPortOutStrmFifoFlagsx/IClkToOClkCrossing.SyncToOClk/oPushRcvd*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom535 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortOutStrmFifox/DmaPortOutStrmFifoFlagsx/IClkToOClkCrossing.SyncToOClk/iDataToPush*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom536 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortOutStrmFifox/DmaPortOutStrmFifoFlagsx/IClkToOClkCrossing.SyncToOClk/DataReg/GenFlops[*].DFlopx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom537 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortOutStrmFifox/DmaPortOutStrmFifoFlagsx/oReadSamplePtrUnsGray*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom538 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortOutStrmFifox/DmaPortOutStrmFifoFlagsx/iReadSamplePtrUnsGray*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom539 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortOutStrmFifox/DmaPortOutStrmFifoFlagsx/i*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom540 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[1].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortOutStrmFifox/DmaPortOutStrmFifoFlagsx/i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom541 [get_cells {*SyncStopRequestStrobeToViClk*PulseSyncBasex/*iHoldSigInx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom542 [get_cells {*SyncStopRequestStrobeToViClk*PulseSyncBasex/*oHoldSigIn_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom543 [get_cells {*SyncStopRequestStrobeToViClk*PulseSyncBasex/*oLocalSigOutx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom544 [get_cells {*SyncStopRequestStrobeToViClk*PulseSyncBasex/*iSigOut_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom545 [get_cells {*SyncStopRequestStrobeToViClk*PulseSyncBasex/*oLocalSigOutCEx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom547 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Output.FifoClearController/PopSynchNeeded.FromPopDblSync*iDlySigx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom548 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Output.FifoClearController/PopSynchNeeded.FromPopDblSync*DoubleSyncAsyncInBasex/oSig_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom549 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Output.FifoClearController/PopSynchNeeded.ToPopDblSync*iDlySigx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom550 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Output.FifoClearController/PopSynchNeeded.ToPopDblSync*DoubleSyncAsyncInBasex/oSig_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom551 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Output.FifoClearController/NiFpgaFifoPortResetx/Crossing.PushToPop/*iHoldSigInx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom552 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Output.FifoClearController/NiFpgaFifoPortResetx/Crossing.PushToPop/*oHoldSigIn_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom553 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Output.FifoClearController/NiFpgaFifoPortResetx/Crossing.PushToPop/*oLocalSigOutx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom554 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Output.FifoClearController/NiFpgaFifoPortResetx/Crossing.PushToPop/*iSigOut_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom555 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Output.FifoClearController/NiFpgaFifoPortResetx/Crossing.PushToPop/*oLocalSigOutCEx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom557 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Output.FifoClearController/NiFpgaFifoPortResetx/Crossing.PopToPush/*iHoldSigInx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom558 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Output.FifoClearController/NiFpgaFifoPortResetx/Crossing.PopToPush/*oHoldSigIn_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom559 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Output.FifoClearController/NiFpgaFifoPortResetx/Crossing.PopToPush/*oLocalSigOutx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom560 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Output.FifoClearController/NiFpgaFifoPortResetx/Crossing.PopToPush/*iSigOut_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom561 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Output.FifoClearController/NiFpgaFifoPortResetx/Crossing.PopToPush/*oLocalSigOutCEx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom563 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Output.FifoClearController/NiFpgaFifoPortResetx/Crossing.ClearToPop*oRegisteredSigAck*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom564 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Output.FifoClearController/NiFpgaFifoPortResetx/Crossing.ClearToPop*PulseSyncBasex*iSigOut_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom565 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Output.FifoClearController/NiFpgaFifoPortResetx/Crossing.ClearToPop/*iHoldSigInx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom566 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Output.FifoClearController/NiFpgaFifoPortResetx/Crossing.ClearToPop/*oHoldSigIn_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom567 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Output.FifoClearController/NiFpgaFifoPortResetx/Crossing.ClearToPop/*oLocalSigOutx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom568 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Output.FifoClearController/NiFpgaFifoPortResetx/Crossing.ClearToPop/*iSigOut_msx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom569 [get_cells {*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*].DmaOutput.DmaPortCommIfcOutputFifoInterfacex/DmaPortCommIfcComponentEnableChainx/Output.FifoClearController/NiFpgaFifoPortResetx/Crossing.ClearToPop/*oLocalSigOutCEx/*FDCPEx} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom571 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom572 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom573 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom574 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom576 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom577 [get_cells {*ViControlx*BusClkToReliableClkHS/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom578 [get_cells {*ViControlx*BusClkToReliableClkHS/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom579 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom580 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom581 [get_cells {*ViControlx*BusClkToReliableClkHS/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom582 [get_cells {*ViControlx*BusClkToReliableClkHS/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom583 [get_cells {*ViControlx*BusClkToReliableClkHS/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom584 [get_cells {*ViControlx*BusClkToReliableClkHS/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom585 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom586 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom587 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom588 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom589 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom590 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom591 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom592 [get_cells {*ViControlx*BusClkToReliableClkHS/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom593 [get_cells {*ViControlx*rEnableIn*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom594 [get_cells {*ViControlx*tEnableIn_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom595 [get_cells {*ViControlx*rEnableClear*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom596 [get_cells {*ViControlx*tEnableClear_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom598 [get_cells {*ViControlx*bEnableIn_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom600 [get_cells {*ViControlx*bEnableClear_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom601 [get_cells {*ViControlx*rDerivedClkLostLock*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom602 [get_cells {*ViControlx*bDerivedClkLostLock_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom603 [get_cells {*ViControlx*rGatedClkStartupErr*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom604 [get_cells {*ViControlx*bGatedClkStartupErr_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom605 [get_cells {*ViControlx*rEnableDeassertionErr*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom606 [get_cells {*ViControlx*bEnableDeassertionErr_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom607 [get_cells {*DiagramResetx*rDiagramResetAssertionErr*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom608 [get_cells {*ViControlx*bDiagramResetAssertionErr_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom609 [get_cells {*ViControlx*tDiagramEnableOutReg*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom610 [get_cells {*ViControlx*bEnableOut_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom611 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.SyncIReset/c1ResetFastLclx*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom612 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkIn.iPushTogglex*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom613 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkIn.i*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom614 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.o*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom616 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.SyncIReset/c2ResetFe_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom617 [get_cells {*DiagramResetx*BusClkToReliableClkHS/Blk*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom618 [get_cells {*DiagramResetx*BusClkToReliableClkHS/Blk*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom619 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkIn.iPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom620 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom621 [get_cells {*DiagramResetx*BusClkToReliableClkHS/*oPushToggle0_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom622 [get_cells {*DiagramResetx*BusClkToReliableClkHS/*oPushToggle1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom623 [get_cells {*DiagramResetx*BusClkToReliableClkHS/*iRdyPushToggle_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom624 [get_cells {*DiagramResetx*BusClkToReliableClkHS/*iRdyPushToggle*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom625 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.SyncIReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom626 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.SyncIReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom627 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.SyncOReset*c1*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom628 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.SyncOReset*c1*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom629 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.SyncIReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom630 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.SyncIReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom631 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.SyncOReset*c2*_ms*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom632 [get_cells {*DiagramResetx*BusClkToReliableClkHS/BlkOut.SyncOReset*c2*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom633 [get_cells {*DiagramResetx*rSafeToEnableGatedClksLoc*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom634 [get_cells {*DiagramResetx*rDiagramResetForHost*} -filter {IS_SEQUENTIAL==true}]
set TNM_Custom635 [get_cells {*DiagramResetx*bDiagramResetForHost_ms*} -filter {IS_SEQUENTIAL==true}]


set_max_delay -from $TNM_Custom1 -to $TNM_Custom2  24.4975002500
set_max_delay -from $TNM_Custom11 -to $TNM_Custom12 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom13 -to $TNM_Custom14 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom15 -to $TNM_Custom16 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom17 -to $TNM_Custom18 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom19 -to $TNM_Custom20 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom21 -to $TNM_Custom22 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom23 -to $TNM_Custom24  24.4975002500
set_max_delay -from $TNM_Custom33 -to $TNM_Custom34 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom35 -to $TNM_Custom36 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom37 -to $TNM_Custom38 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom39 -to $TNM_Custom40 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom41 -to $TNM_Custom42 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom43 -to $TNM_Custom44 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom45 -to $TNM_Custom46 -datapath_only 29.2470003000
set_max_delay -from $TNM_Custom47 -to $TNM_Custom48 -datapath_only 29.2470003000
set_max_delay -from $TNM_Custom49 -to $TNM_Custom48 -datapath_only 29.2470003000
set_max_delay -from $TNM_Custom51 -to $TNM_Custom52 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom53 -to $TNM_Custom54 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom55 -to $TNM_Custom56  24.4975002500
set_max_delay -from $TNM_Custom65 -to $TNM_Custom66 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom67 -to $TNM_Custom68 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom69 -to $TNM_Custom70 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom71 -to $TNM_Custom72 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom73 -to $TNM_Custom74 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom75 -to $TNM_Custom76 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom77 -to $TNM_Custom78  24.4975002500
set_max_delay -from $TNM_Custom87 -to $TNM_Custom88 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom89 -to $TNM_Custom90 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom91 -to $TNM_Custom92 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom93 -to $TNM_Custom94 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom95 -to $TNM_Custom96 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom97 -to $TNM_Custom98 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom99 -to $TNM_Custom100  24.4975002500
set_max_delay -from $TNM_Custom109 -to $TNM_Custom110 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom111 -to $TNM_Custom112 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom113 -to $TNM_Custom114 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom115 -to $TNM_Custom116 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom117 -to $TNM_Custom118 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom119 -to $TNM_Custom120 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom121 -to $TNM_Custom122  24.4975002500
set_max_delay -from $TNM_Custom131 -to $TNM_Custom132 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom133 -to $TNM_Custom134 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom135 -to $TNM_Custom136 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom137 -to $TNM_Custom138 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom139 -to $TNM_Custom140 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom141 -to $TNM_Custom142 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom143 -to $TNM_Custom144  24.4975002500
set_max_delay -from $TNM_Custom153 -to $TNM_Custom154 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom155 -to $TNM_Custom156 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom157 -to $TNM_Custom158 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom159 -to $TNM_Custom160 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom161 -to $TNM_Custom162 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom163 -to $TNM_Custom164 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom165 -to $TNM_Custom166  24.4975002500
set_max_delay -from $TNM_Custom175 -to $TNM_Custom176 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom177 -to $TNM_Custom178 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom179 -to $TNM_Custom180 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom181 -to $TNM_Custom182 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom183 -to $TNM_Custom184 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom185 -to $TNM_Custom186 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom187 -to $TNM_Custom188  24.4975002500
set_max_delay -from $TNM_Custom197 -to $TNM_Custom198 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom199 -to $TNM_Custom200 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom201 -to $TNM_Custom202 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom203 -to $TNM_Custom204 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom205 -to $TNM_Custom206 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom207 -to $TNM_Custom208 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom209 -to $TNM_Custom210  24.4975002500
set_max_delay -from $TNM_Custom219 -to $TNM_Custom220 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom221 -to $TNM_Custom222 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom223 -to $TNM_Custom224 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom225 -to $TNM_Custom226 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom227 -to $TNM_Custom228 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom229 -to $TNM_Custom230 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom231 -to $TNM_Custom232  24.4975002500
set_max_delay -from $TNM_Custom241 -to $TNM_Custom242 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom243 -to $TNM_Custom244 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom245 -to $TNM_Custom246 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom247 -to $TNM_Custom248 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom249 -to $TNM_Custom250 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom251 -to $TNM_Custom252 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom253 -to $TNM_Custom254  24.4975002500
set_max_delay -from $TNM_Custom263 -to $TNM_Custom264 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom265 -to $TNM_Custom266 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom267 -to $TNM_Custom268 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom269 -to $TNM_Custom270 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom271 -to $TNM_Custom272 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom273 -to $TNM_Custom274 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom275 -to $TNM_Custom276 -datapath_only 23.4975002500
set_max_delay -from $TNM_Custom277 -to $TNM_Custom278 -datapath_only 36.7462503750
set_max_delay -from $TNM_Custom279 -to $TNM_Custom280 -datapath_only 11.2488001200
set_max_delay -from $TNM_Custom278 -to $TNM_Custom282 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom283 -to $TNM_Custom284 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom280 -to $TNM_Custom286 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom287 -to $TNM_Custom288 -datapath_only 23.4975002500
set_max_delay -from $TNM_Custom289 -to $TNM_Custom290 -datapath_only 36.7462503750
set_max_delay -from $TNM_Custom291 -to $TNM_Custom292 -datapath_only 11.2488001200
set_max_delay -from $TNM_Custom290 -to $TNM_Custom294 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom283 -to $TNM_Custom296 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom292 -to $TNM_Custom298 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom299 -to $TNM_Custom300 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom300 -to $TNM_Custom302 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom303 -to $TNM_Custom304 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom304 -to $TNM_Custom306 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom307 -to $TNM_Custom308 -datapath_only 24.4975002500
set_max_delay -from $TNM_Custom309 -to $TNM_Custom310 -datapath_only 1.7496000400
set_max_delay -from $TNM_Custom311 -to $TNM_Custom312 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom313 -to $TNM_Custom314 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom315 -to $TNM_Custom316 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom317 -to $TNM_Custom318 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom319 -to $TNM_Custom320 -datapath_only 36.7462503750
set_max_delay -from $TNM_Custom321 -to $TNM_Custom322 -datapath_only 11.2488001200
set_max_delay -from $TNM_Custom323 -to $TNM_Custom322 -datapath_only 11.2488001200
set_max_delay -from $TNM_Custom325 -to $TNM_Custom326 -datapath_only 11.2488001200
set_max_delay -from $TNM_Custom327 -to $TNM_Custom328 -datapath_only 36.7462503750
set_max_delay -from $TNM_Custom329 -to $TNM_Custom328 -datapath_only 36.7462503750
set_max_delay -from $TNM_Custom331 -to $TNM_Custom332 -datapath_only 36.7462503750
set_max_delay -from $TNM_Custom333 -to $TNM_Custom334 -datapath_only 11.2488001200
set_max_delay -from $TNM_Custom335 -to $TNM_Custom336 -datapath_only 36.7462503750
set_max_delay -from $TNM_Custom337 -to $TNM_Custom336 -datapath_only 36.7462503750
set_max_delay -from $TNM_Custom339 -to $TNM_Custom340  24.4975002500
set_max_delay -from $TNM_Custom349 -to $TNM_Custom350 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom351 -to $TNM_Custom352 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom353 -to $TNM_Custom354 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom355 -to $TNM_Custom356 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom357 -to $TNM_Custom358 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom359 -to $TNM_Custom360 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom361 -to $TNM_Custom362  24.4975002500
set_max_delay -from $TNM_Custom371 -to $TNM_Custom372 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom373 -to $TNM_Custom374 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom375 -to $TNM_Custom376 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom377 -to $TNM_Custom378 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom379 -to $TNM_Custom380 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom381 -to $TNM_Custom382 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom383 -to $TNM_Custom384  24.4975002500
set_max_delay -from $TNM_Custom393 -to $TNM_Custom394 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom395 -to $TNM_Custom396 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom397 -to $TNM_Custom398 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom399 -to $TNM_Custom400 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom401 -to $TNM_Custom402 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom403 -to $TNM_Custom404 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom405 -to $TNM_Custom406  24.4975002500
set_max_delay -from $TNM_Custom415 -to $TNM_Custom416 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom417 -to $TNM_Custom418 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom419 -to $TNM_Custom420 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom421 -to $TNM_Custom422 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom423 -to $TNM_Custom424 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom425 -to $TNM_Custom426 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom427 -to $TNM_Custom428  24.4975002500
set_max_delay -from $TNM_Custom437 -to $TNM_Custom438 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom439 -to $TNM_Custom440 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom441 -to $TNM_Custom442 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom443 -to $TNM_Custom444 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom445 -to $TNM_Custom446 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom447 -to $TNM_Custom448 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom449 -to $TNM_Custom450  24.4975002500
set_max_delay -from $TNM_Custom459 -to $TNM_Custom460 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom461 -to $TNM_Custom462 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom463 -to $TNM_Custom464 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom465 -to $TNM_Custom466 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom467 -to $TNM_Custom468 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom469 -to $TNM_Custom470 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom471 -to $TNM_Custom472  24.4975002500
set_max_delay -from $TNM_Custom481 -to $TNM_Custom482 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom483 -to $TNM_Custom484 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom485 -to $TNM_Custom486 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom487 -to $TNM_Custom488 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom489 -to $TNM_Custom490 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom491 -to $TNM_Custom492 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom493 -to $TNM_Custom494  24.4975002500
set_max_delay -from $TNM_Custom503 -to $TNM_Custom504 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom505 -to $TNM_Custom506 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom507 -to $TNM_Custom508 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom509 -to $TNM_Custom510 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom511 -to $TNM_Custom512 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom513 -to $TNM_Custom514 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom515 -to $TNM_Custom516 -datapath_only 23.4975002500
set_max_delay -from $TNM_Custom517 -to $TNM_Custom518 -datapath_only 36.7462503750
set_max_delay -from $TNM_Custom519 -to $TNM_Custom520 -datapath_only 11.2488001200
set_max_delay -from $TNM_Custom518 -to $TNM_Custom522 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom283 -to $TNM_Custom524 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom520 -to $TNM_Custom526 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom527 -to $TNM_Custom528 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom528 -to $TNM_Custom530 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom531 -to $TNM_Custom532 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom532 -to $TNM_Custom534 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom535 -to $TNM_Custom536 -datapath_only 24.4975002500
set_max_delay -from $TNM_Custom537 -to $TNM_Custom538 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom539 -to $TNM_Custom540 -datapath_only 1.8748000200
set_max_delay -from $TNM_Custom541 -to $TNM_Custom542 -datapath_only 36.7462503750
set_max_delay -from $TNM_Custom543 -to $TNM_Custom544 -datapath_only 36.7462503750
set_max_delay -from $TNM_Custom545 -to $TNM_Custom544 -datapath_only 36.7462503750
set_max_delay -from $TNM_Custom547 -to $TNM_Custom548 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom549 -to $TNM_Custom550 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom551 -to $TNM_Custom552 -datapath_only 36.7462503750
set_max_delay -from $TNM_Custom553 -to $TNM_Custom554 -datapath_only 11.2488001200
set_max_delay -from $TNM_Custom555 -to $TNM_Custom554 -datapath_only 11.2488001200
set_max_delay -from $TNM_Custom557 -to $TNM_Custom558 -datapath_only 11.2488001200
set_max_delay -from $TNM_Custom559 -to $TNM_Custom560 -datapath_only 36.7462503750
set_max_delay -from $TNM_Custom561 -to $TNM_Custom560 -datapath_only 36.7462503750
set_max_delay -from $TNM_Custom563 -to $TNM_Custom564 -datapath_only 11.2488001200
set_max_delay -from $TNM_Custom565 -to $TNM_Custom566 -datapath_only 36.7462503750
set_max_delay -from $TNM_Custom567 -to $TNM_Custom568 -datapath_only 11.2488001200
set_max_delay -from $TNM_Custom569 -to $TNM_Custom568 -datapath_only 11.2488001200
set_max_delay -from $TNM_Custom571 -to $TNM_Custom572  24.4975002500
set_max_delay -from $TNM_Custom581 -to $TNM_Custom582 -datapath_only 4.8745000500
set_max_delay -from $TNM_Custom583 -to $TNM_Custom584 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom585 -to $TNM_Custom586 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom587 -to $TNM_Custom588 -datapath_only 4.8745000500
set_max_delay -from $TNM_Custom589 -to $TNM_Custom590 -datapath_only 4.8745000500
set_max_delay -from $TNM_Custom591 -to $TNM_Custom592 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom593 -to $TNM_Custom594 -datapath_only 73.4925007499
set_max_delay -from $TNM_Custom595 -to $TNM_Custom596 -datapath_only 73.4925007499
set_max_delay -from $TNM_Custom593 -to $TNM_Custom598 -datapath_only 12.2487501250
set_max_delay -from $TNM_Custom595 -to $TNM_Custom600 -datapath_only 12.2487501250
set_max_delay -from $TNM_Custom601 -to $TNM_Custom602 -datapath_only 73.4925007499
set_max_delay -from $TNM_Custom603 -to $TNM_Custom604 -datapath_only 73.4925007499
set_max_delay -from $TNM_Custom605 -to $TNM_Custom606 -datapath_only 73.4925007499
set_max_delay -from $TNM_Custom607 -to $TNM_Custom608 -datapath_only 73.4925007499
set_max_delay -from $TNM_Custom609 -to $TNM_Custom610 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom611 -to $TNM_Custom612  24.4975002500
set_max_delay -from $TNM_Custom621 -to $TNM_Custom622 -datapath_only 4.8745000500
set_max_delay -from $TNM_Custom623 -to $TNM_Custom624 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom625 -to $TNM_Custom626 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom627 -to $TNM_Custom628 -datapath_only 4.8745000500
set_max_delay -from $TNM_Custom629 -to $TNM_Custom630 -datapath_only 4.8745000500
set_max_delay -from $TNM_Custom631 -to $TNM_Custom632 -datapath_only 6.1243750625
set_max_delay -from $TNM_Custom633  -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom634 -to $TNM_Custom635 -datapath_only 12.2487501250
set_max_delay -from $TNM_Custom613 -to $TNM_Custom614 -datapath_only 19.4980002000
set_max_delay -from $TNM_Custom573 -to $TNM_Custom574 -datapath_only 19.4980002000
set_max_delay -from $TNM_Custom25 -to $TNM_Custom26 -datapath_only 24.4975002500
set_max_delay -from $TNM_Custom79 -to $TNM_Custom80 -datapath_only 7.4992000800
set_max_delay -from $TNM_Custom57 -to $TNM_Custom58 -datapath_only 7.4992000800
set_max_delay -from $TNM_Custom495 -to $TNM_Custom496 -datapath_only 7.4992000800
set_max_delay -from $TNM_Custom473 -to $TNM_Custom474 -datapath_only 7.4992000800
set_max_delay -from $TNM_Custom451 -to $TNM_Custom452 -datapath_only 7.4992000800
set_max_delay -from $TNM_Custom429 -to $TNM_Custom430 -datapath_only 7.4992000800
set_max_delay -from $TNM_Custom407 -to $TNM_Custom408 -datapath_only 7.4992000800
set_max_delay -from $TNM_Custom385 -to $TNM_Custom386 -datapath_only 7.4992000800
set_max_delay -from $TNM_Custom363 -to $TNM_Custom364 -datapath_only 7.4992000800
set_max_delay -from $TNM_Custom341 -to $TNM_Custom342 -datapath_only 7.4992000800
set_max_delay -from $TNM_Custom255 -to $TNM_Custom256 -datapath_only 7.4992000800
set_max_delay -from $TNM_Custom233 -to $TNM_Custom234 -datapath_only 7.4992000800
set_max_delay -from $TNM_Custom211 -to $TNM_Custom212 -datapath_only 7.4992000800
set_max_delay -from $TNM_Custom189 -to $TNM_Custom190 -datapath_only 7.4992000800
set_max_delay -from $TNM_Custom167 -to $TNM_Custom168 -datapath_only 7.4992000800
set_max_delay -from $TNM_Custom145 -to $TNM_Custom146 -datapath_only 7.4992000800
set_max_delay -from $TNM_Custom123 -to $TNM_Custom124 -datapath_only 7.4992000800
set_max_delay -from $TNM_Custom101 -to $TNM_Custom102 -datapath_only 7.4992000800
set_max_delay -from $TNM_Custom3 -to $TNM_Custom4 -datapath_only 24.4975002500
set_max_delay -from $TNM_Custom83 -to $TNM_Custom84 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom7 -to $TNM_Custom8 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom617 -to $TNM_Custom618 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom61 -to $TNM_Custom62 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom577 -to $TNM_Custom578 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom499 -to $TNM_Custom500 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom477 -to $TNM_Custom478 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom455 -to $TNM_Custom456 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom433 -to $TNM_Custom434 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom411 -to $TNM_Custom412 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom389 -to $TNM_Custom390 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom367 -to $TNM_Custom368 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom345 -to $TNM_Custom346 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom29 -to $TNM_Custom30 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom259 -to $TNM_Custom260 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom237 -to $TNM_Custom238 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom215 -to $TNM_Custom216 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom193 -to $TNM_Custom194 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom171 -to $TNM_Custom172 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom149 -to $TNM_Custom150 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom127 -to $TNM_Custom128 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom105 -to $TNM_Custom106 -datapath_only 100.0000000000
set_max_delay -from $TNM_Custom619 -to $TNM_Custom620 -datapath_only 9.7490001000
set_max_delay -from $TNM_Custom611 -to $TNM_Custom616 -datapath_only 9.7490001000
set_max_delay -from $TNM_Custom579 -to $TNM_Custom580 -datapath_only 9.7490001000
set_max_delay -from $TNM_Custom571 -to $TNM_Custom576 -datapath_only 9.7490001000
set_max_delay -from $TNM_Custom31 -to $TNM_Custom32 -datapath_only 12.2487501250
set_max_delay -from $TNM_Custom23 -to $TNM_Custom28 -datapath_only 12.2487501250
set_max_delay -from $TNM_Custom99 -to $TNM_Custom104 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom85 -to $TNM_Custom86 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom77 -to $TNM_Custom82 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom63 -to $TNM_Custom64 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom55 -to $TNM_Custom60 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom501 -to $TNM_Custom502 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom493 -to $TNM_Custom498 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom479 -to $TNM_Custom480 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom471 -to $TNM_Custom476 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom457 -to $TNM_Custom458 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom449 -to $TNM_Custom454 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom435 -to $TNM_Custom436 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom427 -to $TNM_Custom432 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom413 -to $TNM_Custom414 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom405 -to $TNM_Custom410 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom391 -to $TNM_Custom392 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom383 -to $TNM_Custom388 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom369 -to $TNM_Custom370 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom361 -to $TNM_Custom366 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom347 -to $TNM_Custom348 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom339 -to $TNM_Custom344 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom261 -to $TNM_Custom262 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom253 -to $TNM_Custom258 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom239 -to $TNM_Custom240 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom231 -to $TNM_Custom236 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom217 -to $TNM_Custom218 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom209 -to $TNM_Custom214 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom195 -to $TNM_Custom196 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom187 -to $TNM_Custom192 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom173 -to $TNM_Custom174 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom165 -to $TNM_Custom170 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom151 -to $TNM_Custom152 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom143 -to $TNM_Custom148 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom129 -to $TNM_Custom130 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom121 -to $TNM_Custom126 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom107 -to $TNM_Custom108 -datapath_only 3.7496000400
set_max_delay -from $TNM_Custom9 -to $TNM_Custom10 -datapath_only 12.2487501250
set_max_delay -from $TNM_Custom1 -to $TNM_Custom6 -datapath_only 12.2487501250




# DmaPortInStrmFifoFlags component instantiates HandshakeBaseResetCross component with instance name WritePointerHandshake. 
# Synchronous reset signals - iReset and oReset - are connected to asychronous reset ports on HandshakeBaseResetCross
# - aIReset, aOReset - on WritePointerHandshake instance respectively. This results in Vivado performing asynchronous 
# reset recovery timing analysis to the asychronous reset and preset pin on every flop in the HandshakeBaseResetCross 
# component that aIReset and aOReset are connected to, thereby making timing challenging to meet especially at higher
# clock rates.
#
# We have concerns about the pre-existing logic in DmaPortInStrmFifoFlags because there are reset domain crossings between flops
# reset by aReset and flops reset by aIReset and aOReset. The reset recovery analysis done by Xilinx may mitigate this
# concern but we are struggling to convince ourselves. In the interest of making the smallest change possible to alleviate
# critical paths that show up for Cascadia, we are just going to set false paths to disable the automatic reset recovery
# analysis on flops that are already marked as metastable. It may be no worse to set false paths to ALL asynchronous reset
# destinations but we are worried that takes a questionable design and makes it even more questionable. Clearly if that
# can be done we would get the best possible timing performance. We will leave that as an exercise for another time.
#
set_false_path -from [get_cells "*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*DmaPortCommIfcComponentEnableChainx/Input.FifoClearController/NiFpgaFifoPortResetx/Crossing.ClearToPop/PulseSyncBasex/oLocalSigOutx*"] -to [get_pins "*DmaPortCommIfcFifosx/DmaBlk.DmaComponents[*]*DmaPortInStrmFifox/DmaPortInStrmFifoFlagsx/WritePointerHandshake/BlkOut.SyncIReset/c2ResetFe_msx/*/CLR"]

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

