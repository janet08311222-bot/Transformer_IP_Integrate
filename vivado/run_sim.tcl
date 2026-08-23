# ============================================================================
#  Behavioural simulation of Transformer_top + Transformer_tb, using the REAL
#  generated IP (blk_mem_gen / mult_gen / cordic simulation models), not the
#  hand-written sim/stubs_*.v.
#
#      vivado -mode batch -source vivado/run_sim.tcl
#
#  Which layer runs is selected by `define FFN1 / `define FFN2 at the top of
#  tb/Transformer_tb.sv.
# ============================================================================
set repo_dir [file normalize [file dirname [info script]]/..]
open_project $repo_dir/vivado/build/Transformer_IP/Transformer_IP.xpr

set_property top Transformer_tb [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
update_compile_order -fileset sim_1

launch_simulation
puts "==== simulation finished ===="
