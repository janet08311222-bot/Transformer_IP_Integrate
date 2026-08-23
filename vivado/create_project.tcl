# ============================================================================
#  Transformer_IP_Integrate - Vivado project generator
#
#  Creates the project, adds the RTL, and generates every IP core the design
#  instantiates. Run headless from the repo root:
#
#      vivado -mode batch -source vivado/create_project.tcl
#
#  The project is written to vivado/build/ (gitignored) so it can always be
#  regenerated from scratch; only this script is version controlled.
#
#  IP naming: SA and FFN both instantiate block RAMs, with the SAME names but
#  DIFFERENT geometry. FFN's carry an FFN_ prefix, SA's use the plain names.
#  See src/FFN_module and src/SA_module.
# ============================================================================

set repo_dir  [file normalize [file dirname [info script]]/..]
set build_dir $repo_dir/vivado/build
set proj_name Transformer_IP
set part      xc7z020clg484-1

file mkdir $build_dir
create_project $proj_name $build_dir/$proj_name -part $part -force

# ---------------------------------------------------------------------------
#  RTL sources
# ---------------------------------------------------------------------------
add_files -norecurse [glob \
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

add_files -fileset sim_1 -norecurse $repo_dir/tb/Transformer_tb.sv
set_property top Transformer_tb [get_filesets sim_1]

# ---------------------------------------------------------------------------
#  Block RAMs
#
#  bram {name depth width type ena enb} - settings copied from the IPs the
#  standalone FFN project already used (FFN_BD), so the FFN memories are
#  bit-identical to what the FFN was verified against. SA's are derived from
#  its RTL (address/data widths and which ports are driven).
# ---------------------------------------------------------------------------
proc make_bram {name depth width mem_type enable_b {read_width_b ""}} {
    if {$read_width_b eq ""} { set read_width_b $width }
    create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 \
        -module_name $name
    set_property -dict [list \
        CONFIG.Memory_Type                                $mem_type \
        CONFIG.Write_Depth_A                              $depth \
        CONFIG.Write_Width_A                              $width \
        CONFIG.Read_Width_A                               $width \
        CONFIG.Write_Width_B                              $read_width_b \
        CONFIG.Read_Width_B                               $read_width_b \
        CONFIG.Enable_A                                   {Use_ENA_Pin} \
        CONFIG.Enable_B                                   $enable_b \
        CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
        CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \
        CONFIG.Use_RSTA_Pin                               {false} \
        CONFIG.Use_RSTB_Pin                               {false} \
        CONFIG.Use_REGCEA_Pin                             {false} \
        CONFIG.Use_REGCEB_Pin                             {false} \
        CONFIG.Use_Byte_Write_Enable                      {false} \
        CONFIG.Load_Init_File                             {false} \
        CONFIG.Assume_Synchronous_Clk                     {false} \
    ] [get_ips $name]
}

#----    FFN memories (PEBLKCOL_NUM = 16 -> 16 kernel banks)    -----
make_bram FFN_BRAM_IF   512 64 {Single_Port_RAM}      {Always_Enabled}
make_bram FFN_BRAM_BIAS 512 32 {Single_Port_RAM}      {Always_Enabled}
make_bram FFN_BRAM_OT   512 64 {Single_Port_RAM}      {Always_Enabled}
make_bram FFN_BRAM_KER  512 64 {Simple_Dual_Port_RAM} {Use_ENB_Pin}

#----    SA memories    -----
#  BRAM_IF drives A (write) and reads B; douta is instantiated but unused, so
#  the core must be true dual port to expose it.
make_bram BRAM_IF   1024 64 {True_Dual_Port_RAM} {Use_ENB_Pin}
make_bram BRAM_KER  4096 64 {Single_Port_RAM}    {Always_Enabled}
make_bram BRAM_BIAS  512 32 {Single_Port_RAM}    {Always_Enabled}
make_bram BRAM_OT   4096 64 {Single_Port_RAM}    {Always_Enabled}

# ---------------------------------------------------------------------------
#  FFN requantize multipliers
# ---------------------------------------------------------------------------
proc make_mult {name b_width pipe out_high} {
    create_ip -name mult_gen -vendor xilinx.com -library ip -version 12.0 \
        -module_name $name
    set_property -dict [list \
        CONFIG.MultType                {Parallel_Multiplier} \
        CONFIG.Multiplier_Construction {Use_Mults} \
        CONFIG.OptGoal                 {Speed} \
        CONFIG.PortAType               {Signed} \
        CONFIG.PortAWidth              {32} \
        CONFIG.PortBType               {Signed} \
        CONFIG.PortBWidth              $b_width \
        CONFIG.PipeStages              $pipe \
        CONFIG.OutputWidthHigh         $out_high \
        CONFIG.OutputWidthLow          {0} \
        CONFIG.ClockEnable             {false} \
        CONFIG.SyncClear               {false} \
        CONFIG.UseRounding             {false} \
    ] [get_ips $name]
}

make_mult MULT_2_STAGE_32X16 16 2 47
make_mult MULT_3_STAGE_32X32 32 3 63

# ---------------------------------------------------------------------------
#  Add&Norm square root
#
#  Named DW_sqrt in the RTL but it is a Vivado CORDIC core (aclk /
#  s_axis_cartesian_tdata / m_axis_dout_tdata), no tvalid/tready handshake.
#  Widths follow addnormtop's TBITS=8, fixed=8:
#      variance      [32:0] -> 33-bit input
#      sqrt_variance [16:0] -> 17-bit output
# ---------------------------------------------------------------------------
create_ip -name cordic -vendor xilinx.com -library ip -version 6.0 \
    -module_name DW_sqrt
set_property -dict [list \
    CONFIG.Functional_Selection {Square_Root} \
    CONFIG.Data_Format          {UnsignedInteger} \
    CONFIG.Input_Width          {33} \
    CONFIG.Output_Width         {17} \
    CONFIG.flow_control         {NonBlocking} \
    CONFIG.aclken               {false} \
    CONFIG.aresetn              {false} \
] [get_ips DW_sqrt]

# ---------------------------------------------------------------------------
generate_target all [get_ips]
puts "==== IP summary ===="
foreach ip [get_ips] { puts [format "  %-24s %s" $ip [get_property IPDEF [get_ips $ip]]] }
puts "==== project created at $build_dir/$proj_name ===="
