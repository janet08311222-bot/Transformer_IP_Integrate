# Device-level utilization summary (percent of xc7z020), from the synth_1 run.
#     vivado -mode batch -source vivado/report_fit.tcl
set repo_dir [file normalize [file dirname [info script]]/..]
open_project $repo_dir/vivado/build/Transformer_IP/Transformer_IP.xpr
open_run synth_1 -name synth_1
report_utilization -file $repo_dir/vivado/build/utilization_summary.rpt
puts "==== fit report written ===="
