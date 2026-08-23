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

module softmax_top (clk, rst, hw_ready, valid_in, valid_out, SOFT_INPUT, SOFT_OUT, osif_last_din, out_ready, softmax_done);

input clk;
input rst;
input out_ready;
input valid_in;
output reg valid_out;
output reg hw_ready;
input signed [63:0] SOFT_INPUT;
output reg [15:0] SOFT_OUT;
output reg osif_last_din;
output softmax_done;

reg [7:0] state;
reg [7:0] next_state;
reg signed [63:0] soft_input_reg;
reg signed [15:0] data_0_fix,data_1_fix,data_2_fix,data_3_fix;
reg signed [15:0] data_4_fix,data_5_fix,data_6_fix,data_7_fix;
wire exp_valid_out0,exp_valid_out1,exp_valid_out2,exp_valid_out3;
wire exp_valid_out4,exp_valid_out5,exp_valid_out6,exp_valid_out7;
reg [16:0] t_acc0,t_acc1,t_acc2,t_acc3;
reg [17:0] t_acc4,t_acc5;
reg [18:0] t_acc6;
reg [31:0] accumulator;
reg [2:0] acc_cnt;
reg [2:0] col_cnt;
reg [15:0] exp_ary [0:63];
reg [6:0] out_cnt;
reg div_cnt;
reg idle_cnt;

wire signed [7:0] data_0,data_1,data_2,data_3;
wire signed [7:0] data_4,data_5,data_6,data_7;
wire exp_valid_in0,exp_valid_in1,exp_valid_in2,exp_valid_in3;
wire exp_valid_in4,exp_valid_in5,exp_valid_in6,exp_valid_in7;
wire [15:0] exp_fix_out0,exp_fix_out1,exp_fix_out2,exp_fix_out3;
wire [15:0] exp_fix_out4,exp_fix_out5,exp_fix_out6,exp_fix_out7;
wire [22:0] quotient;
wire [31:0] remainder;
wire [31:0] divisor;
wire [22:0] dividend;
wire [8:0] addr;
wire [15:0] soft_out_w;
wire ready_w;
wire [8:0] addr_1;
wire [8:0] addr_2;
wire [8:0] addr_3;
wire [8:0] addr_4;
wire [8:0] addr_5;
wire [8:0] addr_6;
wire [8:0] addr_7;
wire osif_last_din_w;
wire softmax_done;

wire [7:0] max;
wire [1:0] max_cnt;


integer i;

parameter DIV_STAGES = 6;
parameter IDLE = 0;
parameter LOAD = 1;
parameter MAX = 2;
parameter SHIFT = 3;
parameter EXP = 4;
parameter ACC = 5;
parameter DIV = 6;
parameter RES = 7;
parameter WAIT_DIV = 8;

reg [DIV_STAGES-1:0] div_valid_pipe;
reg [6:0] out_collected_cnt;

assign osif_last_din_w = ((state == DIV) && (out_collected_cnt == 63) && out_ready && div_valid_pipe[DIV_STAGES-2])? 1 : 0;
assign softmax_done  = osif_last_din;

always @(posedge clk) begin
    if (rst) begin
        osif_last_din <= 0;
    end
    else begin
        osif_last_din <= osif_last_din_w;
    end
end

always @(posedge clk) begin
    if (rst) begin
        state <= 0;
    end
    else begin
        state <= next_state;
    end
end

always @(*) begin
    case (state)
        IDLE: next_state = (valid_in == 1)? LOAD : IDLE;
        LOAD: next_state = MAX;
        MAX: next_state = ((max_cnt == 3) && (col_cnt == 7))? SHIFT : (max_cnt == 3)? IDLE :MAX;
        SHIFT: next_state = EXP;
        EXP: next_state = (exp_valid_out0 == 1)? ACC : EXP;
        ACC: next_state = ((acc_cnt == 3'd3) && (col_cnt == 7))? WAIT_DIV : (acc_cnt == 3'd3)? SHIFT : ACC;
        WAIT_DIV: next_state = DIV;
        DIV: next_state = ((out_collected_cnt == 63) && out_ready && div_valid_pipe[DIV_STAGES-2]) ? RES : DIV;
        RES: next_state = IDLE;
        default:next_state = IDLE;
    endcase
end



always @(posedge clk) begin
    if (rst) begin
        soft_input_reg <= 0;
    end
    else begin
        if (state == LOAD) begin
            soft_input_reg <= SOFT_INPUT;
        end
        else begin
            soft_input_reg <= soft_input_reg;
        end
    end
end

assign	data_0	=  soft_input_reg[63:56];
assign	data_1	=  soft_input_reg[55:48];
assign	data_2	=  soft_input_reg[47:40];
assign	data_3	=  soft_input_reg[39:32];
assign	data_4	=  soft_input_reg[31:24];
assign	data_5	=  soft_input_reg[23:16];
assign	data_6	=  soft_input_reg[15:8];
assign	data_7	=  soft_input_reg[7:0];

// split_to_8 spl(.clk(clk), .rst(rst), .input_data(soft_input_reg), .data_0(data_0), .data_1(data_1), 
//                 .data_2(data_2), .data_3(data_3), .data_4(data_4), .data_5(data_5), .data_6(data_6), .data_7(data_7));

pre_processor m0(.clk(clk), .rst(rst), .data_0(data_0), .data_1(data_1), .data_2(data_2), .data_3(data_3), .data_4(data_4), 
                .data_5(data_5), .data_6(data_6), .data_7(data_7), .state(state), .max(max), .max_cnt_wire(max_cnt));

assign addr_1 = addr + 1;
assign addr_2 = addr + 2;
assign addr_3 = addr + 3;
assign addr_4 = addr + 4;
assign addr_5 = addr + 5;
assign addr_6 = addr + 6;
assign addr_7 = addr + 7;

always @(posedge clk) begin
    if (rst) begin
        data_0_fix <= 0;
        data_1_fix <= 0;
        data_2_fix <= 0;
        data_3_fix <= 0;
        data_4_fix <= 0;
        data_5_fix <= 0;
        data_6_fix <= 0;
        data_7_fix <= 0;
    end
    else begin
        if (state == SHIFT) begin
            data_0_fix <= (exp_ary[addr] - max) << 8;
            data_1_fix <= (exp_ary[addr_1] - max) << 8;
            data_2_fix <= (exp_ary[addr_2] - max) << 8;
            data_3_fix <= (exp_ary[addr_3] - max) << 8;
            data_4_fix <= (exp_ary[addr_4] - max) << 8;
            data_5_fix <= (exp_ary[addr_5] - max) << 8;
            data_6_fix <= (exp_ary[addr_6] - max) << 8;
            data_7_fix <= (exp_ary[addr_7] - max) << 8;
        end
        else begin
            data_0_fix <= data_0_fix;
            data_1_fix <= data_1_fix;
            data_2_fix <= data_2_fix;
            data_3_fix <= data_3_fix;
            data_4_fix <= data_4_fix;
            data_5_fix <= data_5_fix;
            data_6_fix <= data_6_fix;
            data_7_fix <= data_7_fix;
        end
    end
end

exp_ln2_based exp0(.clk(clk), .rst(rst), .valid_in(exp_valid_in0), .valid_out(exp_valid_out0), .t_exp_in(data_0_fix), .signed_exp_out(exp_fix_out0));
exp_ln2_based exp1(.clk(clk), .rst(rst), .valid_in(exp_valid_in1), .valid_out(exp_valid_out1), .t_exp_in(data_1_fix), .signed_exp_out(exp_fix_out1));
exp_ln2_based exp3(.clk(clk), .rst(rst), .valid_in(exp_valid_in2), .valid_out(exp_valid_out2), .t_exp_in(data_3_fix), .signed_exp_out(exp_fix_out3));
exp_ln2_based exp2(.clk(clk), .rst(rst), .valid_in(exp_valid_in3), .valid_out(exp_valid_out3), .t_exp_in(data_2_fix), .signed_exp_out(exp_fix_out2));
exp_ln2_based exp4(.clk(clk), .rst(rst), .valid_in(exp_valid_in4), .valid_out(exp_valid_out4), .t_exp_in(data_4_fix), .signed_exp_out(exp_fix_out4));
exp_ln2_based exp5(.clk(clk), .rst(rst), .valid_in(exp_valid_in5), .valid_out(exp_valid_out5), .t_exp_in(data_5_fix), .signed_exp_out(exp_fix_out5));
exp_ln2_based exp6(.clk(clk), .rst(rst), .valid_in(exp_valid_in6), .valid_out(exp_valid_out6), .t_exp_in(data_6_fix), .signed_exp_out(exp_fix_out6));
exp_ln2_based exp7(.clk(clk), .rst(rst), .valid_in(exp_valid_in7), .valid_out(exp_valid_out7), .t_exp_in(data_7_fix), .signed_exp_out(exp_fix_out7));

always @(posedge clk) begin
    if (rst) begin
        t_acc0 <= 0;
        t_acc1 <= 0;
        t_acc2 <= 0;
        t_acc3 <= 0;
        t_acc4 <= 0;
        t_acc5 <= 0;
        t_acc6 <= 0;
        accumulator <= 0;
    end
    else if (state == ACC) begin
        case (acc_cnt)
            0: begin
                t_acc0 <= exp_fix_out0 + exp_fix_out1;
                t_acc1 <= exp_fix_out2 + exp_fix_out3;
                t_acc2 <= exp_fix_out4 + exp_fix_out5;
                t_acc3 <= exp_fix_out6 + exp_fix_out7;
            end
            1: begin
                t_acc4 <= t_acc0 + t_acc1;
                t_acc5 <= t_acc2 + t_acc3;
            end
            2: begin
                t_acc6 <= t_acc4 + t_acc5;
            end
            3: begin
                accumulator <= accumulator + t_acc6;
            end
            default: accumulator <= accumulator;
        endcase
    end
    else if (state == RES) begin
        t_acc0 <= 0;
        t_acc1 <= 0;
        t_acc2 <= 0;
        t_acc3 <= 0;
        t_acc4 <= 0;
        t_acc5 <= 0;
        t_acc6 <= 0;
        accumulator <= 0;
    end
    else begin
        t_acc0 <= t_acc0;
        t_acc1 <= t_acc1;
        t_acc2 <= t_acc2;
        t_acc3 <= t_acc3;
        t_acc4 <= t_acc4;
        t_acc5 <= t_acc5;
        t_acc6 <= t_acc6;
        accumulator <= accumulator;
    end
end

assign addr = 4'd8 * col_cnt;

always @(posedge clk) begin
    if (rst) begin
        for (i = 0; i<=63; i = i+1) begin
            exp_ary[i] <= 0;
        end
    end
    else if ((state == MAX) && (max_cnt == 0)) begin
        exp_ary[addr] <= data_0;
        exp_ary[addr + 1] <= data_1;
        exp_ary[addr + 2] <= data_2;
        exp_ary[addr + 3] <= data_3;
        exp_ary[addr + 4] <= data_4;
        exp_ary[addr + 5] <= data_5;
        exp_ary[addr + 6] <= data_6;
        exp_ary[addr + 7] <= data_7;
    end
    else if ((state == ACC) && (acc_cnt == 0)) begin
        exp_ary[addr] <= exp_fix_out0;
        exp_ary[addr + 1] <= exp_fix_out1;
        exp_ary[addr + 2] <= exp_fix_out2;
        exp_ary[addr + 3] <= exp_fix_out3;
        exp_ary[addr + 4] <= exp_fix_out4;
        exp_ary[addr + 5] <= exp_fix_out5;
        exp_ary[addr + 6] <= exp_fix_out6;
        exp_ary[addr + 7] <= exp_fix_out7;
    end
    else begin
        exp_ary[addr] <= exp_ary[addr];
        exp_ary[addr + 1] <= exp_ary[addr + 1];
        exp_ary[addr + 2] <= exp_ary[addr + 2];
        exp_ary[addr + 3] <= exp_ary[addr + 3];
        exp_ary[addr + 4] <= exp_ary[addr + 4];
        exp_ary[addr + 5] <= exp_ary[addr + 5];
        exp_ary[addr + 6] <= exp_ary[addr + 6];
        exp_ary[addr + 7] <= exp_ary[addr + 7];
    end
end

wire [22:0] dividend_in = (out_cnt < 64) ? (exp_ary[out_cnt[5:0]] << 8) : 23'd0;
// ----- 倒數乘法器取代除法器 -----
wire [4:0] p;
assign p = (accumulator[31]) ? 5'd31 : (accumulator[30]) ? 5'd30 : (accumulator[29]) ? 5'd29 : (accumulator[28]) ? 5'd28 :
           (accumulator[27]) ? 5'd27 : (accumulator[26]) ? 5'd26 : (accumulator[25]) ? 5'd25 : (accumulator[24]) ? 5'd24 :
           (accumulator[23]) ? 5'd23 : (accumulator[22]) ? 5'd22 : (accumulator[21]) ? 5'd21 : (accumulator[20]) ? 5'd20 :
           (accumulator[19]) ? 5'd19 : (accumulator[18]) ? 5'd18 : (accumulator[17]) ? 5'd17 : (accumulator[16]) ? 5'd16 :
           (accumulator[15]) ? 5'd15 : (accumulator[14]) ? 5'd14 : (accumulator[13]) ? 5'd13 : (accumulator[12]) ? 5'd12 :
           (accumulator[11]) ? 5'd11 : (accumulator[10]) ? 5'd10 : (accumulator[9])  ? 5'd9  : (accumulator[8])  ? 5'd8  :
           (accumulator[7])  ? 5'd7  : (accumulator[6])  ? 5'd6  : (accumulator[5])  ? 5'd5  : (accumulator[4])  ? 5'd4  :
           (accumulator[3])  ? 5'd3  : (accumulator[2])  ? 5'd2  : (accumulator[1])  ? 5'd1  : 5'd0;

wire [8:0] M;
assign M = (p >= 5'd8) ? (accumulator >> (p - 5'd8)) : (accumulator << (5'd8 - p));

wire [17:0] R;
recip_lut r_lut (
    .clk(clk),
    .index(M[7:0]),
    .recip(R)
);

wire [40:0] product;
DW_mult_pipe #(
    .a_width(23), 
    .b_width(18), 
    .num_stages(DIV_STAGES), 
    .stall_mode(1), 
    .rst_mode(1), 
    .op_iso_mode(0)
) mult_recip_inst (
    .clk(clk), 
    .rst_n(~rst), 
    .en(out_ready && (state == DIV)), 
    .tc(1'b0), 
    .a(dividend_in), 
    .b(R), 
    .product(product)
);

integer j;
reg [4:0] p_pipe [0:DIV_STAGES-1];
always @(posedge clk) begin
    if (rst) begin
        for (j = 0; j < DIV_STAGES; j = j + 1) begin
            p_pipe[j] <= 0;
        end
    end else if (out_ready && (state == DIV)) begin
        p_pipe[0] <= p;
        for (j = 1; j < DIV_STAGES; j = j + 1) begin
            p_pipe[j] <= p_pipe[j-1];
        end
    end
end

wire [5:0] shift_amount = p_pipe[DIV_STAGES-2] + 6'd17;
assign quotient = product >> shift_amount;
// --------------------------------

assign soft_out_w = ((state == DIV) && out_ready && div_valid_pipe[DIV_STAGES-2]) ? quotient : SOFT_OUT;
assign valid_out_w = ((state == DIV) && out_ready && div_valid_pipe[DIV_STAGES-2]) ? 1 : 0;

always @(posedge clk) begin
    if (rst) begin
        SOFT_OUT <= 0;
        valid_out <= 0;
    end
    else begin
        SOFT_OUT <= soft_out_w;
        valid_out <= valid_out_w;
    end
end

//----------------------------------------signal----------------------------------------

assign exp_valid_in0 = (state == EXP)? 1 : 0;
assign exp_valid_in1 = (state == EXP)? 1 : 0;
assign exp_valid_in2 = (state == EXP)? 1 : 0;
assign exp_valid_in3 = (state == EXP)? 1 : 0;
assign exp_valid_in4 = (state == EXP)? 1 : 0;
assign exp_valid_in5 = (state == EXP)? 1 : 0;
assign exp_valid_in6 = (state == EXP)? 1 : 0;
assign exp_valid_in7 = (state == EXP)? 1 : 0;

assign ready_w = ((state == IDLE) && (valid_in))? 1 : 0;

always @(posedge clk) begin
    if (rst) begin
        idle_cnt <= 0;
    end
    else if (state == IDLE) begin
        idle_cnt <= idle_cnt + 1;
    end
    else begin
        idle_cnt <= idle_cnt;
    end
end

always @(posedge clk) begin
    if (rst) begin
        hw_ready <= 0;
    end
    else begin
        hw_ready <= ready_w;
    end
end

//always @(posedge clk) begin
//    if (rst) begin
//        ready <= 0;
//    end
//    else begin
//        ready <= ready_w;
//    end
//end

always @(posedge clk) begin
    if (rst) begin
        acc_cnt <= 0;
    end
    else if ((state == ACC) && (acc_cnt != 3)) begin
        acc_cnt <= acc_cnt + 1;
    end
    else begin
        acc_cnt <= 0;
    end
end

always @(posedge clk) begin
    if (rst) begin
        div_cnt <= 0;
        out_cnt <= 0;
        div_valid_pipe <= 0;
        out_collected_cnt <= 0;
    end
    else if (state == DIV) begin
        if (out_ready) begin
            if (out_cnt < 64) begin
                out_cnt <= out_cnt + 1;
            end
            div_valid_pipe <= {div_valid_pipe[DIV_STAGES-2:0], (out_cnt < 64)};
            
            if (div_valid_pipe[DIV_STAGES-2]) begin
                out_collected_cnt <= out_collected_cnt + 1;
            end
        end
    end
    else begin
        div_cnt <= 0;
        out_cnt <= 0;
        div_valid_pipe <= 0;
        out_collected_cnt <= 0;
    end
end

always @(posedge clk) begin
    if (rst) begin
        col_cnt <= 0;
    end
    else if (((state == ACC) && (acc_cnt == 3)) || ((state == MAX) && (max_cnt == 3))) begin
        col_cnt <= col_cnt + 1;
    end
    else begin
        col_cnt <= col_cnt;
    end
end

endmodule
