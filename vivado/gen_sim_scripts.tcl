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

set_property top Transformer_tb [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
update_compile_order -fileset sim_1

launch_simulation -scripts_only
puts "==== sim scripts generated ===="
