# ============================================================================
#  Emit the xsim compile/elaborate/simulate scripts instead of running them.
#
#  Vivado's launch_simulation spawns compile.bat as a child process, and on
#  this machine that spawn fails ("Spawn failed: Broken pipe") whenever
#  Vivado's own stdout is a pipe - which it always is when driven from a
#  script. Generating the scripts and running them ourselves sidesteps it
#  and gives the same result, since the scripts are what launch_simulation
#  would have run anyway.
#
#      vivado -mode batch -source vivado/gen_sim_scripts.tcl
#      cd vivado/build/Transformer_IP/Transformer_IP.sim/sim_1/behav/xsim
#      cmd /c compile.bat && cmd /c elaborate.bat && cmd /c simulate.bat
#
#  (vivado/run_sim.sh does those steps for you.)
# ============================================================================
set repo_dir [file normalize [file dirname [info script]]/..]
open_project $repo_dir/vivado/build/Transformer_IP/Transformer_IP.xpr

#  The project's source list was globbed when it was created, so files added
#  since (e.g. a new module in a swapped-in block) are not in it. Re-glob every
#  time; add_files -quiet ignores the ones already present.
add_files -quiet -norecurse [glob \
    $repo_dir/src/*.v \
    $repo_dir/src/common_module/*.v \
    $repo_dir/src/common_module/counter/*.v \
    $repo_dir/src/common_module/fifo/*.v \
    $repo_dir/src/SA_module/*.v \
    $repo_dir/src/SA_module/*/*.v \
    $repo_dir/src/FFN_module/*.v \
    $repo_dir/src/FFN_module/*/*.v \
    $repo_dir/src/SOFTMAX_module/*.v \
    $repo_dir/src/Add_Norm_module/*.v \
]
set_property top Transformer_top [current_fileset]
update_compile_order -fileset sources_1

#  Which testbench to run. Pass it in with -tclargs, e.g.
#      vivado -mode batch -source vivado/gen_sim_scripts.tcl -tclargs fsm_check_tb
#  Transformer_tb  -> FFN1 / FFN2 / SOFTMAX (tb/Transformer_tb.sv)
#  fsm_check_tb    -> Self-Attention        (tb/new_tb_512MAC.sv)
set sim_top [expr {$argc > 0 ? [lindex $argv 0] : "Transformer_tb"}]
puts "==== sim top: $sim_top ===="

#  Add only the tb being run. tb/ also holds FFN_tb.sv, the STANDALONE FFN
#  testbench, which drives FFN_top through its old AXI-Stream ports - those no
#  longer exist now that FFN_top is fifo-level, so keep it out of the fileset.
switch -- $sim_top {
    Transformer_tb { set tb_file tb/Transformer_tb.sv }
    fsm_check_tb   { set tb_file tb/new_tb_512MAC.sv }
    default        { error "unknown sim top '$sim_top' (expected Transformer_tb or fsm_check_tb)" }
}
foreach f [get_files -quiet -of_objects [get_filesets sim_1] *.sv] { remove_files -fileset sim_1 $f }
add_files -fileset sim_1 -norecurse $repo_dir/$tb_file
set_property top $sim_top [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
update_compile_order -fileset sim_1

launch_simulation -scripts_only
puts "==== sim scripts generated ===="
