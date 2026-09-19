// vcode.f -- Transformer_top RTL PRE-SIM (ASIC path), school-box layout.
// Run from pre_sim/ ; everything is ../ from here, like the senior's flow.
//
//   Transformer/            <- root
//     pre_sim/              <- run here:  source simulation.f  (or simulation_sa.f)
//     src/  sram/  tb/  pat/  sram_dir/  syn/
//
// This replaces the senior's vcode.f in pre_sim/, which was set up for GATE
// sim (CHIP_syn.v netlist + StdCell/StdIO + +define+GATE) - not RTL pre-sim.

// ---- testbench (pick ONE; simulation.f / simulation_sa.f each list theirs) ----
// ../tb/Transformer_tb.sv      FFN1 / FFN2 / SOFTMAX  (top: Transformer_tb)
// ../tb/new_tb_512MAC.sv       Self-Attention          (top: fsm_check_tb)

// ---- top ----
../src/Transformer_top.v
../src/Transformer_FSM.v

// ---- shared leaves ----
../src/common_module/counter/count_yi_v3.v
../src/common_module/counter/count_yi_v4.v
../src/common_module/counter/count_yi_v5.v
../src/common_module/fifo/INPUT_STREAM_if.v
../src/common_module/fifo/OUTPUT_STREAM_if.v
../src/common_module/yolo_rst_if.v
// ifndef ASIC: empty under +define+ASIC
../src/common_module/DW_mult_pipe_fpga.v

// ---- Self-Attention ----
../src/SA_module/bias_rw/biassram_r.v
../src/SA_module/bias_rw/biassram_w.v
../src/SA_module/bias_rw/bias_top.v
../src/SA_module/compute_engine/pe_8_ver3.v
../src/SA_module/compute_engine/pe_blk64.v
../src/SA_module/compute_engine/pe_qz_pkg.v
../src/SA_module/compute_engine/pe_top.v
../src/SA_module/compute_engine/re_quantize.v
../src/SA_module/compute_engine/ru_get.v
../src/SA_module/defparm.v
../src/SA_module/ifmap_rw/ifsram_pd.v
../src/SA_module/ifmap_rw/ifsram_r.v
../src/SA_module/ifmap_rw/ifsram_w.v
../src/SA_module/ifmap_rw/ifw_cnt_fsm.v
../src/SA_module/ifmap_rw/if_dout_mux.v
../src/SA_module/ifmap_rw/if_top.v
../src/SA_module/kernel_rw/kersram_r.v
../src/SA_module/kernel_rw/kersram_w.v
../src/SA_module/kernel_rw/ker_top.v
../src/SA_module/main_ctrl/d_empn_rd_mux.v
../src/SA_module/main_ctrl/fsm64.v
../src/SA_module/main_ctrl/get_ins.v
../src/SA_module/main_ctrl/schedule_ctrl.v
../src/SA_module/output_module/ot_fifo.v
../src/SA_module/output_module/ot_read.v
../src/SA_module/output_module/ot_top.v
../src/SA_module/output_module/ot_write.v
../src/SA_module/top_pto.v

// ---- FFN ----
../src/FFN_module/bias_module/FFN_biassram_r.v
../src/FFN_module/bias_module/FFN_biassram_w.v
../src/FFN_module/bias_module/FFN_bias_top.v
../src/FFN_module/compute_engine/FFN_getpe_result.v
../src/FFN_module/compute_engine/FFN_i_gelu.v
../src/FFN_module/compute_engine/FFN_pe_8e.v
../src/FFN_module/compute_engine/FFN_pe_array.v
../src/FFN_module/compute_engine/FFN_pe_qz_pkg.v
../src/FFN_module/compute_engine/FFN_pe_top.v
../src/FFN_module/compute_engine/FFN_quan2uint8.v
../src/FFN_module/compute_engine/FFN_quan2uint8_gelu.v
../src/FFN_module/FFN_top.v
../src/FFN_module/input_module/FFN_ifsram_r.v
../src/FFN_module/input_module/FFN_ifsram_w.v
../src/FFN_module/input_module/FFN_if_top.v
../src/FFN_module/kernel_module/FFN_kersram_r.v
../src/FFN_module/kernel_module/FFN_kersram_w.v
../src/FFN_module/kernel_module/FFN_ker_top.v
../src/FFN_module/main_ctrl/FFN_d_empn_rd_mux.v
../src/FFN_module/main_ctrl/FFN_fsm64.v
../src/FFN_module/main_ctrl/FFN_get_ins.v
../src/FFN_module/main_ctrl/FFN_schedule_ctrl.v
../src/FFN_module/output_module/FFN_otsram_r.v
../src/FFN_module/output_module/FFN_otsram_w.v
../src/FFN_module/output_module/FFN_ot_fifo.v
../src/FFN_module/output_module/FFN_ot_top.v

// ---- Softmax ----
../src/SOFTMAX_module/exp_ln2_based.v
../src/SOFTMAX_module/pre_processor.v
../src/SOFTMAX_module/recip_lut.v
../src/SOFTMAX_module/softmax_top.v

// ---- Add & Norm ----
../src/Add_Norm_module/add.v
../src/Add_Norm_module/addnormtop.v
../src/Add_Norm_module/div.v
../src/Add_Norm_module/mean.v
../src/Add_Norm_module/sub.v
../src/Add_Norm_module/var.v

// ---- ASIC SRAM wrappers: BOTH files, same module names would collide otherwise ----
// IF_SRAM / KER_SRAM / BIAS_SRAM / OT_SRAM  (SA)
../sram/sa_sram_wrappers.v
// FFN_IF_SRAM / FFN_KER_SRAM / FFN_BIAS_SRAM / FFN_OT_SRAM  (FFN)
../sram/ffn_sram_wrappers.v

// ---- N16FFC macro sim models (same four the senior listed; CMD_SRAM 32x88 is not used) ----
../sram_dir/BIAS_SRAM/VERILOG/FPGA/ts1n16ffcllulvta512x32m8swbsho_120a.v
../sram_dir/OT_SRAM/VERILOG/FPGA/ts1n16ffcllulvta4096x64m8swbsho_120a.v
../sram_dir/SRAM_I/VERILOG/FPGA/tsdn16ffcllulvta512x64m4wbsho_130a.v
../sram_dir/SRAM_W/VERILOG/FPGA/ts1n16ffcllulvta512x64m8swbsho_120a.v

// ---- DesignWare (DW02_mult_3_stage, DW_mult_pipe, DW_sqrt) ----
// resolved by -y $SYNOPSYS/dw/sim_ver in simulation.f, not listed here
