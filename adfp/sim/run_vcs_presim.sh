#!/usr/bin/env bash
# ============================================================================
#  ADFP RTL pre-sim of Transformer_top with VCS - SCHOOL BOX ONLY.
#  Run from the REPO ROOT (vcode.f and the tb pattern paths assume it):
#
#      bash adfp/sim/run_vcs_presim.sh                  # Transformer_tb (FFN1/FFN2/SOFTMAX)
#      bash adfp/sim/run_vcs_presim.sh fsm_check_tb     # Self-Attention
#
#  Set these two for your environment (or export them before running):
#      SRAM_DIR  directory holding the four N16FFC macro sim models (.v)
#      DW_DIR    $SYNOPSYS/dw/sim_ver  (DesignWare simulation models)
#
#  Which layer Transformer_tb runs: `define FFN1 / FFN2 / SOFTMAX at the top
#  of tb/Transformer_tb.sv, same as the FPGA flow. Expect bit-exact against
#  the same gold the FPGA and the local stub-based ASIC runs pass:
#      FFN1 2048/2048   FFN2 512/512   SOFTMAX 3328/3328   SA 4096/4096
#
#  This is the same recipe as FFN Phase 4 (adfp/sim/simulation.f there):
#      +define+ASIC   every block takes its ASIC branch
#      +define+RTL    tb uses repo-relative pat/ paths and CYCLE = 10
#      -timescale     the RTL is a mix of files with and without `timescale
# ============================================================================
set -e
sim_top="${1:-Transformer_tb}"
case "$sim_top" in
    Transformer_tb) tb_file=tb/Transformer_tb.sv ;;
    fsm_check_tb)   tb_file=tb/new_tb_512MAC.sv ;;
    *) echo "unknown sim top '$sim_top' (Transformer_tb | fsm_check_tb)"; exit 1 ;;
esac

: "${SRAM_DIR:?set SRAM_DIR to the N16FFC macro model directory}"
: "${DW_DIR:=$SYNOPSYS/dw/sim_ver}"

log="adfp/sim/vcs_log_${sim_top}"
mkdir -p "$log"

vcs -full64 -sverilog -debug_access+all \
    +define+ASIC +define+RTL \
    -timescale=1ns/1ps \
    +vcs+lic+wait \
    -f adfp/sim/vcode.f \
    "$SRAM_DIR/TS1N16FFCLLULVTA4096X64M8SWBSHO.v" \
    "$SRAM_DIR/TS1N16FFCLLULVTA512X32M8SWBSHO.v" \
    "$SRAM_DIR/TS1N16FFCLLULVTA512X64M8SWBSHO.v" \
    "$SRAM_DIR/TSDN16FFCLLULVTA512X64M4WBSHO.v" \
    "$DW_DIR/DW02_mult_3_stage.v" \
    "$DW_DIR/DW_mult_pipe.v" \
    "$DW_DIR/DW_sqrt.v" \
    "$tb_file" \
    -top "$sim_top" \
    -l "$log/compile.log" \
    -o "$log/simv"

"$log/simv" -l "$log/run.log"

echo "==== verdict ===="
grep -E "RESULT:|CYCLES:|produced|undriven|WATCHDOG|groups done" "$log/run.log" || true
