//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/09/21 15:41:58
// Design Name: 
// Module Name: log
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
module pre_processor (
    input wire clk	,
    input wire rst,
    input signed [7:0] data_0,
    input signed [7:0] data_1,
    input signed [7:0] data_2,
    input signed [7:0] data_3,
    input signed [7:0] data_4,
    input signed [7:0] data_5,
    input signed [7:0] data_6,
    input signed [7:0] data_7,
    input signed [7:0] state,
    output signed [7:0] max,
    output [1:0] max_cnt_wire
);

reg [1:0] max_cnt;
reg signed [7:0] max_0;
reg signed [7:0] max_1;
reg signed [7:0] max_2;
reg signed [7:0] max_3;
reg signed [7:0] max_4;
reg signed [7:0] max_5;
reg signed [7:0] max_6;
reg signed [7:0] max_7;

parameter IDLE = 0;
parameter LOAD = 1;
parameter MAX = 2;
parameter SHIFT = 3;
parameter EXP = 4;
parameter ACC = 5;
parameter DIV = 6;
parameter RES = 7;

always @(posedge clk) begin
    if (rst) begin
        max_0 <= 0;
        max_1 <= 0;
        max_2 <= 0;
        max_3 <= 0;
        max_4 <= 0;
        max_5 <= 0;
        max_6 <= 0;
        max_7 <= 0;
    end
    else if ((state == MAX) && (max_cnt == 0)) begin
        max_0 <= (data_0 >= data_1)? data_0 : data_1;
        max_1 <= (data_2 >= data_3)? data_2 : data_3;
        max_2 <= (data_4 >= data_5)? data_4 : data_5;
        max_3 <= (data_6 >= data_7)? data_6 : data_7;
    end
    else if ((state == MAX) && (max_cnt == 1)) begin
        max_4 <= (max_0 >= max_1)? max_0 : max_1;
        max_5 <= (max_2 >= max_3)? max_2 : max_3;
    end
    else if ((state == MAX) && (max_cnt == 2)) begin
        max_6 <= (max_4 >= max_5)? max_4 : max_5;
    end
    else if ((state == MAX) && (max_cnt == 3)) begin
        max_7 <= (max_6 >= max_7)? max_6 : max_7;
    end
    else if (state == RES) begin
        max_7 <= 0;
    end
    else begin
        max_7 <= max_7;
    end
end

assign max = max_7;
assign max_cnt_wire = max_cnt;

always @(posedge clk) begin
    if (rst) begin
        max_cnt <= 0;
    end
    else if (state == MAX) begin
        max_cnt <= max_cnt + 1;
    end
    else begin
        max_cnt <= max_cnt;
    end
end

endmodule

