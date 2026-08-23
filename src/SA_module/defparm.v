// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2022.01.30
// Ver      : 1.0
// Func     : use this file define FPGA or EDA version
// ============================================================================
//----    define for testing    -----
`ifndef ASIC
`define FPGA_SRAM_SETTING	// FPGA (Vivado BRAM) path ; build with +define+ASIC to use the N16 SRAM macros in sram.v
`endif
`define BIG_ENDIAN


