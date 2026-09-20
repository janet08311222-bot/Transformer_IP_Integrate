#!/usr/bin/env bash
# ============================================================================
#  LOCAL ASIC-path pre-sim (xsim + behavioural stubs). Run from the repo root.
#
#      bash adfp/sim/run_asic_sim.sh                 # Transformer_tb : FFN1/FFN2/SOFTMAX
#      bash adfp/sim/run_asic_sim.sh fsm_check_tb    # Self-Attention
#
#  Same RTL, same testbenches, same gold as the FPGA runs - but compiled with
#  +define+ASIC so every block takes its ASIC branch (N16FFC SRAM wrappers,
#  DesignWare multipliers / sqrt). A bit-exact PASS here means the ASIC branch
#  computes exactly what the verified FPGA branch does; that is the check the
#  school box's VCS presim then repeats with the REAL macro and DesignWare
#  models before DC.
#
#  Stubs (adfp/sim/*_stubs.v) stand in for the PDK / $SYNOPSYS models. They are
#  behavioural and latency-matched (see their headers) - good enough to catch
#  wiring, guard and order-of-declaration mistakes, which is the point.
#
#  Which layer Transformer_tb runs is chosen by `define FFN1 / FFN2 / SOFTMAX
#  at the top of tb/Transformer_tb.sv, exactly as for the FPGA flow.
# ============================================================================
set -e
sim_top="${1:-Transformer_tb}"
#  bash adfp/sim/run_asic_sim.sh Transformer_tb CHIP   -> DUT is the pad-ring CHIP wrapper
chip_def=""; [ "${2:-}" = "CHIP" ] && chip_def="-d CHIP"
#  extra +defines via EXTRA_DEFS="-d XPROBE" bash adfp/sim/run_asic_sim.sh ...
chip_def="$chip_def ${EXTRA_DEFS:-}"
case "$sim_top" in
    Transformer_tb) tb_file=tb/Transformer_tb.sv ;;
    fsm_check_tb)   tb_file=tb/new_tb_512MAC.sv ;;
    *) echo "unknown sim top '$sim_top' (Transformer_tb | fsm_check_tb)"; exit 1 ;;
esac

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_dir"
export PATH="/d/Xilinx/Vivado/2019.1/bin:$PATH"

#  vcode.f paths are repo-root relative, so compile from here; logs go to
#  adfp/sim/log_<top>/ and the xsim work dir is cleaned up afterwards.
log="adfp/sim/log_${sim_top}"
rm -rf "$log" xsim.dir; mkdir -p "$log"

echo "==== compile (+define+ASIC) ===="
xvlog --nolog -d ASIC $chip_def -sv \
    -f adfp/sim/vcode.f \
    adfp/sim/n16_macro_stubs.v \
    adfp/sim/designware_stubs.v \
    adfp/sim/pad_stubs.v \
    "$tb_file" \
    -log "$log/xvlog.log"

echo "==== elaborate ===="
xelab --nolog -d ASIC $chip_def -timescale 1ns/1ps --relax \
    -s "${sim_top}_asic" "$sim_top" -log "$log/xelab.log"

echo "==== simulate ===="
xsim "${sim_top}_asic" -runall -log "$log/simulate.log"

rm -rf xsim.dir xelab.pb xvlog.pb xsim.jou webtalk*.jou
echo "==== done; verdict: ===="
grep -E "RESULT:|CYCLES:|produced|undriven|WATCHDOG|groups done" "$log/simulate.log" || true
