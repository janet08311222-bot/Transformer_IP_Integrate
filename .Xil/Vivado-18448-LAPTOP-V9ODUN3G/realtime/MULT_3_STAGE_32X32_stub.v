// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "mult_gen_v12_0_15,Vivado 2019.1" *)
module MULT_3_STAGE_32X32(CLK, A, B, P);
  input CLK;
  input [31:0]A;
  input [31:0]B;
  output [63:0]P;
endmodule
