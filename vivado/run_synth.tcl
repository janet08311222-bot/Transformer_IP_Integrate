# ============================================================================
#  Synthesise Transformer_top against the REAL generated IP (not sim/stubs_*.v).
#  This is the check that catches IP port/width mismatches - the stubs cannot,
#  because they are written to match the RTL rather than the core.
#
#      vivado -mode batch -source vivado/run_synth.tcl
# ============================================================================
set repo_dir [file normalize [file dirname [info script]]/..]
open_project $repo_dir/vivado/build/Transformer_IP/Transformer_IP.xpr
update_compile_order -fileset sources_1

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "==== SYNTHESIS FAILED ===="
    puts [get_property STATUS [get_runs synth_1]]
    exit 1
}

open_run synth_1 -name synth_1
report_utilization -file $repo_dir/vivado/build/utilization.rpt
report_timing_summary -file $repo_dir/vivado/build/timing.rpt
puts "==== SYNTHESIS OK ===="
