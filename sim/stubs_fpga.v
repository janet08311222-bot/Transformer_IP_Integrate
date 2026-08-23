// ============================================================================
//  Simulation/elaboration stubs for the Xilinx IP the FPGA path instantiates.
//
//  These are NOT part of the design. They exist so the RTL can be elaborated
//  from the command line (xvlog/xelab) without the blk_mem_gen / mult_gen IP
//  cores that only exist inside the Vivado project. In the real Vivado project
//  the generated IP is used instead and this file must be EXCLUDED.
//
//  Port lists match the instantiations in the *_top.v FPGA path.
// ============================================================================

//----    FFN block memories (FFN_-prefixed: SA has its own BRAM_* with different geometry)    -----
module FFN_BRAM_IF (
    input        clka, input ena, input wea,
    input  [8:0] addra, input [63:0] dina, output [63:0] douta
);
    reg [63:0] mem [0:511];
    reg [63:0] q;
    always @(posedge clka) if (ena) begin
        if (wea) mem[addra] <= dina;
        q <= mem[addra];
    end
    assign douta = q;
endmodule

module FFN_BRAM_BIAS (
    input        clka, input ena, input wea,
    input  [8:0] addra, input [31:0] dina, output [31:0] douta
);
    reg [31:0] mem [0:511];
    reg [31:0] q;
    always @(posedge clka) if (ena) begin
        if (wea) mem[addra] <= dina;
        q <= mem[addra];
    end
    assign douta = q;
endmodule

module FFN_BRAM_OT (
    input        clka, input ena, input wea,
    input  [8:0] addra, input [63:0] dina, output [63:0] douta
);
    reg [63:0] mem [0:511];
    reg [63:0] q;
    always @(posedge clka) if (ena) begin
        if (wea) mem[addra] <= dina;
        q <= mem[addra];
    end
    assign douta = q;
endmodule

module FFN_BRAM_KER (
    input        clka, input clkb, input ena, input enb, input wea,
    input  [8:0] addra, input [8:0] addrb,
    input  [63:0] dina, output [63:0] doutb
);
    reg [63:0] mem [0:511];
    reg [63:0] q;
    always @(posedge clka) if (ena && wea) mem[addra] <= dina;
    always @(posedge clkb) if (enb) q <= mem[addrb];
    assign doutb = q;
endmodule

//----    FFN requantize multipliers    -----
module MULT_2_STAGE_32X16 (
    input CLK, input [31:0] A, input [15:0] B, output [47:0] P
);
    reg signed [47:0] s1, s2;
    always @(posedge CLK) begin
        s1 <= $signed(A) * $signed(B);
        s2 <= s1;
    end
    assign P = s2;
endmodule

module MULT_3_STAGE_32X32 (
    input CLK, input [31:0] A, input [31:0] B, output [63:0] P
);
    reg signed [63:0] s1, s2, s3;
    always @(posedge CLK) begin
        s1 <= $signed(A) * $signed(B);
        s2 <= s1;
        s3 <= s2;
    end
    assign P = s3;
endmodule
