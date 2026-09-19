`timescale 1ns/1ps
// ============================================================================
//  N16ADFP_StdIO pad-cell behavioural stubs - LOCAL SIM ONLY.
//  On the school box the real models come from
//  /process/ADFP/Executable_Package/Collaterals/IP/stdio/N16ADFP_StdIO/VERILOG/N16ADFP_StdIO.v
//  and this file is NOT compiled.
//
//  PDCDG_V / PDCDG_H: bidirectional digital pad, identical behaviour, the
//  suffix is just placement orientation.
//      OEN = 1 -> output driver off (input pad);  OEN = 0 -> PAD driven by I
//      IE  = 1 -> C follows PAD (input enable);   IE  = 0 -> C not driven (0)
// ============================================================================
module PDCDG_V (input OEN, input IE, input I, inout PAD, output C);
    assign PAD = OEN ? 1'bz : I;
    assign C   = IE  ? PAD  : 1'b0;
endmodule

module PDCDG_H (input OEN, input IE, input I, inout PAD, output C);
    assign PAD = OEN ? 1'bz : I;
    assign C   = IE  ? PAD  : 1'b0;
endmodule
