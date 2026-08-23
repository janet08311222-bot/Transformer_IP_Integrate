// ============================================================================
//  FPGA-side stand-in for Synopsys DesignWare DW_mult_pipe.
//
//  The softmax block instantiates DW_mult_pipe directly (exp_ln2_based.v and
//  softmax_top.v). That part only exists in a DesignWare-licensed flow, so the
//  ASIC build gets the real one and the FPGA build gets this. Same pattern the
//  FFN uses for its multipliers (Xilinx mult IP on FPGA, DesignWare on ASIC).
//
//  Guarded so an ASIC filelist can include this file harmlessly.
//
//  Semantics modelled (matching how the softmax RTL uses it):
//    product width  = a_width + b_width
//    latency        = num_stages - 1 clock cycles
//    stall_mode = 0 : en ignored, pipeline always advances
//    stall_mode = 1 : en is a clock enable, pipeline holds when low
//    tc         = 0 : unsigned  |  tc = 1 : two's complement
//    rst_mode   = 1 : asynchronous active-low reset (the only mode used here,
//                     and the only one modelled - see the elaboration guard)
//
//  The latency convention is confirmed by softmax_top.v, which aligns the
//  multiplier output against p_pipe[DIV_STAGES-2] and div_valid_pipe
//  [DIV_STAGES-2] - both DIV_STAGES-1 enabled cycles deep.
// ============================================================================
`ifndef ASIC

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

`endif
