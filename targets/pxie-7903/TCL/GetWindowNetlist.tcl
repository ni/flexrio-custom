# githubvisible=true

set error false

# Configure message settings
set_msg_config -id {*INFO*} -suppress
set_msg_config -id {*WARNING*} -suppress
set_msg_config -string {Parameter} -suppress
set_msg_config -string {CRITICAL WARNING} -suppress

# Set top level and synthesis options
if {[catch {set_property top TheWindow [current_fileset]} result]} {
    puts "ERROR: Failed to set top-level module: $result"
    set error true
}

if {[catch {set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]} result]} {
    puts "ERROR: Failed to set synthesis options: $result"
    set error true
}

# Reset and launch synthesis
reset_run synth_1
puts "Starting synthesis run..."
if {[catch {launch_runs synth_1 -jobs 11} result]} {
    puts "ERROR: Failed to launch synthesis: $result"
    set error true
}

# Wait for synthesis to complete
puts "Waiting for synthesis to complete..."
if {[catch {wait_on_run synth_1} result]} {
    puts "ERROR: Error while waiting for synthesis: $result"
    set error true
}

# Check if synthesis completed successfully
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed to complete"
    set error true
}

if {[get_property STATUS [get_runs synth_1]] != "synth_design Complete!"} {
    puts "ERROR: Synthesis failed: [get_property STATUS [get_runs synth_1]]"
    set error true
}

# Open synthesis run and write EDIF
puts "Opening synthesis results..."
if {[catch {open_run synth_1 -name synth_1} result]} {
    puts "ERROR: Failed to open synthesis results: $result"
    set error true
}

puts "Writing EDIF file..."
if {[catch {write_edif -security_mode all TheWindow -force} result]} {
    puts "ERROR: Failed to write EDIF file: $result"
    set error true
}
    

# Check for script errors
if {$error} {
    # The python script that runs Vivado to exeucte this TCL script looks for that exact string in the
    # vivado.log file after the script completes.  Do not change that string without updating the corresponding
    # python script get_window_netlist.py in LV FPGA HDL Tools    
    #
    # We have to concatenate the two parts of the failure string because this whole script gets printed into the 
    # Vivado log and we only want the failure string to be printed in the case of an actual failure
    set FIRST "GET_WINDOW="
    set SECOND "FAILED"
    puts "${FIRST}${SECOND}"
    puts "SCRIPT ERROR: $script_error"
    exit 1
} else {
    exit 0
}