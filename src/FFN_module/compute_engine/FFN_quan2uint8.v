//========================================================================================================//
// Designer : Yen-Ren Hou
// Create   : 2023.8.25
// Ver      : 2.0
// Func     : re-quantize the 32bits MAC+Bias result to uint8 anwser
//   take 32bits data per clk when valid_in = 1 from ru_get.v module .
//========================================================================================================//

module FFN_quan2uint8(
           clk
           ,	reset
           ,	m0_scale
           ,	index
           ,	z_of_weight
           ,	valid_in
           ,	serial32_in
           ,	act_sum_in
           ,	q_out
           ,	valid_out

       );


//IO
input wire    		clk;
input wire     		reset;
input wire    		valid_in;
input wire   [31:0] 	serial32_in; // ifm x ker + bias
input wire   [31:0] 	act_sum_in;  // ifm
input wire   [31:0] 	m0_scale;    // m0
input wire   [7 :0] 	index;
input wire   [15:0] 	z_of_weight; // zw

output reg   [7 :0] 	q_out;
output reg  		valid_out;


// Difine
reg signed	     [44:0]	s_reg; //s
reg signed	     [44:0]	s_reg_1; //s
reg signed           [ 7:0]     index_reg;
reg signed           [31:0]     act_zofw_reg;
reg signed           [31:0]     m0_scale_reg;
reg signed           [31:0]     serial32_reg;
reg signed           [31:0]     bfm0_reg;
reg signed           [63:0]     after_m0_reg;
reg signed           [31:0]     saturatingrounding;


reg                	stage0_valid_in;
reg                	stage1_valid_in;
reg                	stage2_valid_in;

//operation


//////////////////valid_in/////////////////////////////
always@( posedge clk ) begin
    if( reset ) begin
        act_zofw_reg <= 'd0;
        m0_scale_reg <= 'd0;
        serial32_reg <= 'd0;
        index_reg <= 'd0;
    end
    else if(valid_in) begin
        act_zofw_reg <= act_sum_in * z_of_weight;	//放進訊號線再計算會多等一個CLK
        serial32_reg <= serial32_in;
        m0_scale_reg <= m0_scale;
        index_reg <= index;
    end
    else begin
        act_zofw_reg <= 'd0;
        serial32_reg <= 'd0;
        m0_scale_reg <= m0_scale_reg;
        index_reg <= index_reg;
    end
end
////////////////////////////////////////////////////

always@( posedge clk ) begin
    if( reset ) begin
        bfm0_reg <= 'd0;
    end
    else begin
        bfm0_reg <= serial32_reg - act_zofw_reg;
    end
end



always@(*) begin
    if( bfm0_reg > 0 ) begin
        s_reg = 1 << (31 + index_reg);
    end
    else if( bfm0_reg < 0 ) begin
        s_reg = -1 << (31 + index_reg);
    end
    else begin
        s_reg = 'd0;
    end
end

always@( posedge clk ) begin
    if( reset ) begin
        s_reg_1 <= 'd0;
    end
    else begin
        s_reg_1 <= s_reg;
    end
end


always@( posedge clk ) begin
    if( reset ) begin
        after_m0_reg <= 'd0;
    end
    else begin
        after_m0_reg <= m0_scale_reg * bfm0_reg;
    end
end

// saruratingrounding shift 31bit
always@( posedge clk) begin
    if(reset)
        saturatingrounding <= 0;

    else
        saturatingrounding <= (after_m0_reg + s_reg_1) >>> (31+index_reg);
end

always@(*) begin
    if(saturatingrounding>255)
        q_out = 255;
    else if (saturatingrounding<0)
        q_out = 0;
    else
        q_out = saturatingrounding[7:0];
end

always@( posedge clk ) begin
    stage0_valid_in <= valid_in;
    stage1_valid_in <= stage0_valid_in;
    stage2_valid_in <= stage1_valid_in;
    valid_out <= stage2_valid_in;
end


endmodule


// //========================================================================================================//
// // Designer : Yen-Ren Hou
// // Create   : 2023.8.25
// // Ver      : 2.0
// // Func     : re-quantize the 32bits MAC+Bias result to uint8 anwser
// //   take 32bits data per clk when valid_in = 1 from ru_get.v module .
// //========================================================================================================//
// // `define FPGA_SETTING

// module FFN_quan2uint8(
//         clk
//     ,	reset
//     ,	m0_scale
//     ,	index
//     ,	z_of_weight
//     ,	valid_in
//     ,	serial32_in
//     ,	act_sum_in
//     ,	q_out
//     ,	valid_out

// );


//     //IO
//     input wire    		    clk;
//     input wire     		    reset;
//     input wire    		    valid_in;
//     input wire   [31:0] 	serial32_in; // ifm x ker + bias
//     input wire   [31:0] 	act_sum_in;  // ifm
//     input wire   [31:0] 	m0_scale;    // m0
//     input wire   [7 :0] 	index;
//     input wire   [15:0] 	z_of_weight; // zw
    
//     output reg   [7 :0] 	q_out;
//     output reg  		    valid_out;
    
    
//     // Difine
//     reg signed  [44:0]	s_reg; //s
//     reg signed  [44:0]	s_reg_1; //s
//     reg signed  [44:0]  s_reg_2; //s
//     reg signed  [44:0]  s_reg_3; //s
//     reg signed  [ 7:0]  index_stage1;
//     reg signed  [ 7:0]  index_stage2;
//     reg signed  [ 7:0]  index_stage3;
//     reg signed  [ 7:0]  index_stage4;

//     // reg signed  [31:0]  act_zofw_reg;
//     wire signed [47:0]  act_zofw_reg;
//     reg signed  [31:0]  m0_scale_stage1;
//     reg signed  [31:0]  m0_scale_stage2;
//     reg signed  [31:0]  serial32_stage1;
//     reg signed  [31:0]  serial32_stage2;
//     reg signed  [31:0]  bfm0_reg;
//     // reg signed  [63:0]  after_m0_reg;
//     wire signed [63:0]  after_m0_reg;
//     reg signed  [31:0]  saturatingrounding;
    
    
//     reg                	stage0_valid_in;
//     reg                	stage1_valid_in;
//     reg                	stage2_valid_in;
//     reg                	stage3_valid_in;
//     reg                 stage4_valid_in;
//     reg                	stage5_valid_in;

//     //operation
    
    
//     //////////////////valid_in/////////////////////////////
//     always@( posedge clk ) begin
//         if( reset ) begin
//             // act_zofw_reg <= 'd0;
//             serial32_stage1 <= 'd0;
//             m0_scale_stage1 <= 'd0;
//             index_stage1 <= 'd0;
//         end
//         else if(valid_in) begin
//             // act_zofw_reg <= act_sum_in * z_of_weight;	//放進訊號線再計算會多等一個CLK
//             serial32_stage1 <= serial32_in;
//             m0_scale_stage1 <= m0_scale;
//             index_stage1 <= index;
//         end
//         else begin
//             // act_zofw_reg <= 'd0;
//             serial32_stage1 <= 'd0;
//             m0_scale_stage1 <= m0_scale_stage1;
//             index_stage1 <= index_stage1;
//         end
//     end
//     ////////////////////////////////////////////////////

//     always @(posedge clk) begin
//         if(reset) begin
//             serial32_stage2 <= 'd0;
//             m0_scale_stage2 <= 'd0;
//             index_stage2 <= 'd0;
//         end
//         else begin
//             serial32_stage2 <= serial32_stage1;
//             m0_scale_stage2 <= m0_scale_stage1;
//             index_stage2 <= index_stage1;
//         end
//     end

//     `ifdef FPGA_SETTING
//         always @(posedge clk) begin
//             if(reset) begin
//                 index_stage3 <= 'd0;
//                 index_stage4 <= 'd0;
//             end
//             else begin
//                 index_stage3 <= index_stage2;
//                 index_stage4 <= index_stage3;
//             end
//         end
//     `else
//         always @(posedge clk) begin
//             if(reset)
//                 index_stage3 <= 'd0;
//             else
//                 index_stage3 <= index_stage2;
//         end
//     `endif

//     `ifdef FPGA_SETTING
//         MULT_2_STAGE_32X16 mult_2_stage_inst0(
//                 .CLK ( clk          )
//             ,   .A   ( act_sum_in   )
//             ,   .B   ( z_of_weight  )
            
//             ,   .P   ( act_zofw_reg )
//         );
//     `else
//         DW02_mult_3_stage #(
//                 .A_width ( 32 )
//             ,   .B_width ( 16 )
//         )mult_3_stage_inst0(
//                 .CLK ( clk          )
//             ,   .A   ( act_sum_in   )
//             ,   .B   ( z_of_weight  )
//             ,   .TC  ( 1'b1         )

//             ,   .PRODUCT (  act_zofw_reg    )
//         );
//     `endif
    
//     always@( posedge clk ) begin
//         if( reset ) begin
//             bfm0_reg <= 'd0;
//         end
//         else begin
//             bfm0_reg <= serial32_stage2 - act_zofw_reg[31:0];
//         end
//     end
    
//     always@(*) begin
//         if( bfm0_reg > 0 ) begin
//             s_reg = 1 << (31 + index_stage2);
//         end
//         else if( bfm0_reg < 0 ) begin
//             s_reg = -1 << (31 + index_stage2);
//         end
//         else begin
//             s_reg = 'd0;
//         end
//     end
    
//     always@( posedge clk ) begin
//         if( reset ) begin
//             s_reg_1 <= 'd0;
//             s_reg_2 <= 'd0;
//         end
//         else begin
//             s_reg_1 <= s_reg;
//             s_reg_2 <= s_reg_1;
//         end
//     end

//     `ifdef FPGA_SETTING
//         always@( posedge clk ) begin
//             if( reset )
//                 s_reg_3 <= 'd0;
//             else
//                 s_reg_3 <= s_reg_2;
//         end
//     `endif
    
//     // always@( posedge clk ) begin
//     //     if( reset ) begin
//     //         after_m0_reg <= 'd0;
//     //     end
//     //     else begin
//     //         after_m0_reg <= m0_scale_reg * bfm0_reg;
//     //     end
//     // end

//     `ifdef FPGA_SETTING
//         MULT_3_STAGE_32X32 mult_3_stage_inst1(
//                 .CLK ( clk             )
//             ,   .A   ( m0_scale_stage2 )
//             ,   .B   ( bfm0_reg        )
            
//             ,   .P   ( after_m0_reg )
//         );
//     `else
//         DW02_mult_3_stage #(
//                 .A_width ( 32 )
//             ,   .B_width ( 32 )
//         )mult_3_stage_inst1(
//                 .CLK ( clk             )
//             ,   .A   ( m0_scale_stage2 )
//             ,   .B   ( bfm0_reg        )
//             ,   .TC  ( 1'b1            )

//             ,   .PRODUCT (  after_m0_reg    )
//         );
//     `endif
    
//     // saruratingrounding shift 31bit
//     `ifdef  FPGA_SETTING
//         always@( posedge clk ) begin
//             if(reset)
//                 saturatingrounding <= 0;
//             else
//                 saturatingrounding <= (after_m0_reg + s_reg_3) >>> (31+index_stage3);
//         end
//     `else
//         always@( posedge clk ) begin
//             if(reset)
//                 saturatingrounding <= 0;
//             else
//                 saturatingrounding <= (after_m0_reg + s_reg_2) >>> (31+index_stage2);
//         end
//     `endif
    
//     always@(*) begin
//         if(saturatingrounding>255)
//             q_out = 255;
//         else if (saturatingrounding<0)
//             q_out = 0;
//         else
//             q_out = saturatingrounding[7:0];
//     end
    
//     `ifdef FPGA_SETTING
//         always@( posedge clk ) begin
//             if(reset) begin
//                 stage0_valid_in <= 0;
//                 stage1_valid_in <= 0;
//                 stage2_valid_in <= 0;
//                 stage3_valid_in <= 0;
//                 stage4_valid_in <= 0;
//                 stage5_valid_in <= 0;
//                 valid_out <= 0;
//             end
//             else begin
//                 stage0_valid_in <= valid_in;
//                 stage1_valid_in <= stage0_valid_in;
//                 stage2_valid_in <= stage1_valid_in;
//                 stage3_valid_in <= stage2_valid_in;
//                 stage4_valid_in <= stage3_valid_in;
//                 stage5_valid_in <= stage4_valid_in;
//                 valid_out <= stage5_valid_in;
//             end
//         end
//     `else
//         always@( posedge clk ) begin
//             if(reset) begin
//                 stage0_valid_in <= 0;
//                 stage1_valid_in <= 0;
//                 stage2_valid_in <= 0;
//                 stage3_valid_in <= 0;
//                 stage4_valid_in <= 0;
//                 valid_out <= 0;
//             end
//             else begin
//                 stage0_valid_in <= valid_in;
//                 stage1_valid_in <= stage0_valid_in;
//                 stage2_valid_in <= stage1_valid_in;
//                 stage3_valid_in <= stage2_valid_in;
//                 stage4_valid_in <= stage3_valid_in;
//                 valid_out <= stage4_valid_in;
//             end
//         end
//     `endif

// endmodule
