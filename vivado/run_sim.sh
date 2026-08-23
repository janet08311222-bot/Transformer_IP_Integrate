#!/usr/bin/env bash
# ============================================================================
#  Run the behavioural simulation via the xsim scripts Vivado generated.
#
#  Why not just `vivado -source vivado/run_sim.tcl`? launch_simulation spawns
#  compile.bat as a child process, and that spawn fails on this machine with
#  "Spawn failed: Broken pipe" whenever Vivado's stdout is a pipe (i.e. any
#  time it is driven from a script rather than the GUI). Running the generated
#  scripts directly does exactly the same work without the spawn.
#
#  Regenerate the scripts after changing the tb or the file list:
#      vivado -mode batch -source vivado/gen_sim_scripts.tcl
#
#  Then:
#      bash vivado/run_sim.sh
# ============================================================================
set -e

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sim_dir="$repo_dir/vivado/build/Transformer_IP/Transformer_IP.sim/sim_1/behav/xsim"

export PATH="/d/Xilinx/Vivado/2019.1/bin:$PATH"
cd "$sim_dir"

#  The .bat wrappers just call these three tools; invoking them directly keeps
#  everything inside one shell and makes failures visible.
XLIBS="-L blk_mem_gen_v8_4_3 -L xil_defaultlib -L xbip_utils_v3_0_10 \
-L xbip_pipe_v3_0_6 -L xbip_bram18k_v3_0_6 -L mult_gen_v12_0_15 \
-L c_reg_fd_v12_0_6 -L xbip_dsp48_wrapper_v3_0_4 -L xbip_dsp48_addsub_v3_0_6 \
-L xbip_addsub_v3_0_6 -L c_addsub_v12_0_13 -L axi_utils_v2_0_6 \
-L cordic_v6_0_15 -L unisims_ver -L unimacro_ver -L secureip -L xpm"

echo "==== compile (verilog) ===="
xvlog --relax -prj Transformer_tb_vlog.prj -log xvlog.log

#  mult_gen and cordic ship VHDL simulation models, so this step is NOT
#  optional - without it MULT_2/3_STAGE_* and DW_sqrt are missing at elaborate.
echo "==== compile (vhdl) ===="
xvhdl --relax -prj Transformer_tb_vhdl.prj -log xvhdl.log

echo "==== elaborate ===="
xelab --debug typical --relax --mt 2 $XLIBS \
    --snapshot Transformer_tb_behav \
    xil_defaultlib.Transformer_tb xil_defaultlib.glbl -log elaborate.log

echo "==== simulate ===="
xsim Transformer_tb_behav -runall -log simulate.log

echo "==== done; verdict: ===="
grep -E "RESULT:|CYCLES:|compared|WATCHDOG" simulate.log || true
