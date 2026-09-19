`timescale 1ns/1ps
// ============================================================================
//  Synopsys DesignWare behavioural stubs - LOCAL ELABORATION / SIM ONLY.
//
//  On the school box the real components come from $SYNOPSYS/dw/sim_ver and
//  this file is NOT compiled. Here they let the +define+ASIC path run under
//  xsim so the ASIC-only branches (DW02_mult_3_stage in FFN, DW_mult_pipe in
//  softmax, DW_sqrt in Add&Norm) are exercised against the same gold the
//  FPGA path passes.
//
//  Latency fidelity matters for the two multipliers because their consumers
//  use fixed-depth valid shifts, not handshakes:
//    DW02_mult_3_stage  2 register stages. The FPGA path uses a Xilinx
//                       MULT_2_STAGE (PipeStages = 2) in the same slot and
//                       both are bit-exact against gold, so they agree.
//    DW_mult_pipe       num_stages-1 enabled cycles, identical to
//                       src/common_module/DW_mult_pipe_fpga.v, which the
//                       softmax gold (generated with the REAL DesignWare
//                       component) already confirmed.
//    DW_sqrt            combinational, like the real one.
// ============================================================================

// ---------------------------------------------------------------------------
//  DW02_mult_3_stage : signed/unsigned (TC) pipelined multiplier, latency 2
// ---------------------------------------------------------------------------
module DW02_mult_3_stage #(
      parameter A_width = 8
    , parameter B_width = 8
)(
      input  wire                     CLK
    , input  wire [A_width-1:0]       A
    , input  wire [B_width-1:0]       B
    , input  wire                     TC
    , output reg  [A_width+B_width-1:0] PRODUCT
);
    reg [A_width+B_width-1:0] p_s1;
    wire signed [A_width+B_width-1:0] p_signed   = $signed(A) * $signed(B);
    wire        [A_width+B_width-1:0] p_unsigned = A * B;
    always @(posedge CLK) begin
        p_s1    <= TC ? p_signed : p_unsigned;
        PRODUCT <= p_s1;
    end
endmodule

// ---------------------------------------------------------------------------
//  DW_sqrt : combinational integer square root, root = floor(sqrt(a))
// ---------------------------------------------------------------------------
module DW_sqrt #(
      parameter width   = 8
    , parameter tc_mode = 0
)(
      input  wire [width-1:0]       a
    , output reg  [(width+1)/2-1:0] root
);
    localparam RW = (width+1)/2;
    integer i;
    reg [width+1:0] rem;
    reg [width+1:0] trial;
    reg [RW-1:0]    res;
    always @(*) begin
        // standard digit-by-digit (restoring) binary square root: bring down
        // two bits of a per step, compare against 4*res+1.
        rem = 0;
        res = 0;
        for (i = RW-1; i >= 0; i = i - 1) begin
            rem   = (rem << 2) | ((a >> (2*i)) & 2'b11);
            trial = ({{(width+2-RW){1'b0}}, res} << 2) | 2'b01;
            if (rem >= trial) begin
                rem = rem - trial;
                res = (res << 1) | 1'b1;
            end else begin
                res = res << 1;
            end
        end
        root = res;
    end
endmodule

module DW_mult_pipe #(
      parameter a_width     = 8
    , parameter b_width     = 8
    , parameter num_stages  = 2
    , parameter stall_mode  = 1
    , parameter rst_mode    = 1
    , parameter op_iso_mode = 0
)(
      input  wire                       clk
    , input  wire                       rst_n
    , input  wire                       en
    , input  wire                       tc
    , input  wire [a_width-1:0]         a
    , input  wire [b_width-1:0]         b
    , output wire [a_width+b_width-1:0] product
);

    localparam P_WIDTH = a_width + b_width ;
    localparam DEPTH   = ( num_stages < 2 ) ? 1 : num_stages - 1 ;

    // synthesis translate_off
    initial begin
        if ( rst_mode != 1 )
            $display("WARNING: %m - DW_mult_pipe stand-in only models rst_mode=1 (async), got %0d", rst_mode);
    end
    // synthesis translate_on

    wire [P_WIDTH-1:0] prod_unsigned = a * b ;
    wire [P_WIDTH-1:0] prod_signed   = $signed(a) * $signed(b) ;
    wire [P_WIDTH-1:0] prod          = tc ? prod_signed : prod_unsigned ;

    reg [P_WIDTH-1:0] pipe [0:DEPTH-1] ;
    integer i ;

    always @( posedge clk or negedge rst_n ) begin
        if ( !rst_n ) begin
            for ( i = 0 ; i < DEPTH ; i = i + 1 )
                pipe[i] <= {P_WIDTH{1'b0}} ;
        end
        else if ( ( stall_mode == 0 ) || en ) begin
            pipe[0] <= prod ;
            for ( i = 1 ; i < DEPTH ; i = i + 1 )
                pipe[i] <= pipe[i-1] ;
        end
    end

    assign product = pipe[DEPTH-1] ;

endmodule
