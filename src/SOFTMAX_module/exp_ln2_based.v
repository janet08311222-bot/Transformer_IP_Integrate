`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/06/21 13:13:29
// Design Name: 
// Module Name: exp
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module exp_ln2_based(clk, rst, valid_in, valid_out, t_exp_in, signed_exp_out);
input clk;
input rst;
input valid_in;
output valid_out;
input signed [15:0] t_exp_in;
output wire [15:0] signed_exp_out;
parameter MULT_STAGES = 3;
parameter signed ln_2 = 16'b0000000010110001;
parameter ln_256 = 16'b	0000010110001100;
parameter one = 16'h0100;
reg [15:0] exp_in;
wire [15:0] divid_wire_out;
reg [15:0] divid_reg_out;
wire [15:0] remain;
reg [15:0] remain_r;
wire [15:0] positive_in;
localparam IDLE 	= 4'd0;
localparam LOAD 	= 4'd1;
localparam DIV1 	= 4'd2;
localparam DIV2 	= 4'd3;
localparam MULT_WAIT1 = 4'd4;
localparam OUTSTREAM 	= 4'd5;
localparam MULT_WAIT2 = 4'd6;
reg [7:0] curr_state ;
reg [7:0] next_state ;
always@(*)begin
	case( curr_state )
		IDLE 	    :	next_state = (valid_in == 1)? LOAD : IDLE;
		LOAD 	    :	next_state = DIV1;
		DIV1 	    :	next_state = DIV2;
	  	DIV2 	    :	next_state = MULT_WAIT1;
		MULT_WAIT1  :	next_state = OUTSTREAM;
		MULT_WAIT2  :	next_state = OUTSTREAM;
		OUTSTREAM 	:	next_state = IDLE;
		default     :	next_state = IDLE ;
	endcase	
end
always@( posedge clk)begin
    if( rst )
          curr_state <= IDLE	;
	else
	      curr_state <= next_state	;
end
reg sign_save;
always@( posedge clk)begin
    if( rst )
          sign_save <= 0	;
    else if(curr_state==LOAD)
          sign_save <= t_exp_in[15]	;
	else
	      sign_save <= sign_save	;
end
assign positive_in = (t_exp_in[15]) ? (t_exp_in + ln_256) : t_exp_in;

always@(posedge clk)
begin
    if(rst)
    begin
        exp_in <= 0;
    end
    else if(curr_state == LOAD)
    begin
        exp_in <= positive_in;
    end
end

assign valid_out = (curr_state == OUTSTREAM)? 1 : 0;

wire [2:0] rnd;
assign rnd = 3'b001;
wire signed [15:0] quotient;

// 使用常數乘法器取代除法與取餘數
// 1 / 177 約等於 94787 / 2^24
wire [35:0] q_mult = exp_in * 36'd94787;
assign quotient = q_mult[35:24];
assign remain = exp_in - (quotient * 16'd177);

always@(posedge clk or posedge rst)
begin
    if(rst) begin
        divid_reg_out <= 0;
        remain_r <= 0;
    end
    else if(curr_state == DIV1) begin
        divid_reg_out <= quotient;
        remain_r <= remain;
    end
end
        

wire [31:0] r_sqr_wire;
wire [15:0] r_sqr = r_sqr_wire[15:0];
wire [15:0] r_sqr_Q8_8;

assign r_sqr_Q8_8 = r_sqr[15:8];

DW_mult_pipe #(
    .a_width(16),
    .b_width(16),
    .num_stages(MULT_STAGES),
    .stall_mode(0),
    .rst_mode(1),
    .op_iso_mode(0)
) m0 (
    .clk(clk),
    .rst_n(~rst),
    .en(1'b1),
    .tc(1'b0),
    .a(remain_r),
    .b(remain_r),
    .product(r_sqr_wire)
);


wire [15:0] exp_out;
assign exp_out = ((r_sqr_Q8_8>>1) + one + remain) << (divid_reg_out);
assign signed_exp_out = (sign_save) ? ((exp_out>>8) + exp_out[6]) : exp_out;

endmodule
