# simulation.f -- Transformer_top RTL pre-sim, FFN1 / FFN2 / SOFTMAX  (school box)
# In pre_sim/:   source simulation.f
# Pick the layer with `define FFN1 / FFN2 / SOFTMAX at the top of ../tb/Transformer_tb.sv.
#
# Adapted from the senior's simulation.f. Changes and why:
#   +define+GATE        -> +define+ASIC +define+RTL   (RTL pre-sim, ASIC branches on)
#   +neg_tchk           removed                       (only meaningful with SDF timing)
#   -y ../              -> -y $SYNOPSYS/dw/sim_ver    (resolves DW_sqrt / DW_mult_pipe /
#                                                      DW02_mult_3_stage on demand)
#   tb + -top           explicit, so VCS does not have to guess the top
mkdir -p sim_log
vcs -full64 -R -kdb \
-debug_access+all \
-override_timescale=1ns/100ps \
-sverilog +v2k \
-l sim_log/presim_ffn.log \
+incdir+../src \
-y ${SYNOPSYS}/dw/sim_ver +libext+.v \
-f vcode.f \
../tb/Transformer_tb.sv -top Transformer_tb \
+define+ASIC +define+RTL \
-P ${VERDI_HOME}/share/PLI/VCS/LINUX64/novas.tab \
${VERDI_HOME}/share/PLI/VCS/LINUX64/pli.a \
-race
