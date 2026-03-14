open_project PROJ_NAME
update_compile_order -fileset sources_1
launch_runs impl_1 -to_step write_bitstream -jobs 11
wait_on_run impl_1
exit