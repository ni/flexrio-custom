open_project MySasquatchProj.xpr
update_compile_order -fileset sources_1
reset_run synth_1
launch_runs synth_1 -jobs 11
wait_on_run synth_1
exit