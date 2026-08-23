// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2022.09.19
// Ver      : 3.0
// Func     : PE of DLA, using adder tree structure compute 8 element each rounds
// 			throught every stage, more one adder for bias addition
// 			and use shift reg for bias data alive till stage6.
// 			because quantization so need input feature sum
// Log		:
//	--2023.03.03-- delete bias_offset, pass{ker,bias} after registed for next row pe
//	--2023.04.25-- Ensure that the correct 'bias' data is available to the sixth stage of the pipeline when the 'stage_5_align_final' signal is "1".
// ============================================================================

`ifdef FPGA_SRAM_SETTING
	(* use_dsp = "simd" *) 
`else 

`endif 
module pe_8e #(
	parameter ELE_BITS = 8 ,	// PE each pixel bits
	parameter OUT_BITS = 32,
	parameter BIAS_BITS = 32
)(
	clk 		
	,	reset 		
	,	act_0 		
	,	act_1 		
	,	act_2 		
	,	act_3 		
	,	act_4 		
	,	act_5 		
	,	act_6 		
	,	act_7 		
	,	valid_in 		
	,	final_in 		
	//---- kernel ----//
	,	ker_0		
	,	ker_1		
	,	ker_2		
	,	ker_3		
	,	ker_4		
	,	ker_5		
	,	ker_6		
	,	ker_7		
	//---- bias ----//
	,	bias_in	
	//--------------//
	,	pass_ker				
	,	pass_bias				
	,	valid_out				
	,	outmacb_sum 			
	,	outact_sum			

);

//========================================================================
//========    I/O Declare    =============================================
//========================================================================
	input clk 	;
	input reset 	;
	input [ELE_BITS-1 : 0 ] act_0 	;
	input [ELE_BITS-1 : 0 ] act_1 	;
	input [ELE_BITS-1 : 0 ] act_2 	;
	input [ELE_BITS-1 : 0 ] act_3 	;
	input [ELE_BITS-1 : 0 ] act_4 	;
	input [ELE_BITS-1 : 0 ] act_5 	;
	input [ELE_BITS-1 : 0 ] act_6 	;
	input [ELE_BITS-1 : 0 ] act_7 	;
	input valid_in 	;
	input final_in 	;
	//---- kernel ----//
	input [ELE_BITS-1 : 0 ] ker_0 ;
	input [ELE_BITS-1 : 0 ] ker_1 ;
	input [ELE_BITS-1 : 0 ] ker_2 ;
	input [ELE_BITS-1 : 0 ] ker_3 ;
	input [ELE_BITS-1 : 0 ] ker_4 ;
	input [ELE_BITS-1 : 0 ] ker_5 ;
	input [ELE_BITS-1 : 0 ] ker_6 ;
	input [ELE_BITS-1 : 0 ] ker_7 ;
	//---- bias ----//
	input wire signed [BIAS_BITS-1 : 0 ] bias_in ;
	//---- output and pass ----//
	output wire			[ELE_BITS*8-1 : 0 ] 	pass_ker 	;
	output wire signed	[BIAS_BITS-1 : 0 ] 		pass_bias 	;
	output reg valid_out ;
	output reg signed  [OUT_BITS-1 : 0 ] outmacb_sum ;
	output reg signed  [OUT_BITS-1 : 0 ] outact_sum ;
//-----------------------------------------------------------------------------

//-------------Declare-----------------------------------------//

reg valid_in_dly0 , valid_in_dly1 , valid_in_dly2 , valid_in_dly3 , valid_in_dly4 , valid_in_dly5 , valid_in_dly6 , valid_in_dly7 ;
reg final_in_dly0 , final_in_dly1 , final_in_dly2 , final_in_dly3 , final_in_dly4 , final_in_dly5 , final_in_dly6 , final_in_dly7	;


//  只有 stage0 / stage6 的 bias 有人讀,其餘 6 級是沒接出去的複本
reg signed [BIAS_BITS-1 : 0] stage0_bias_in ;
reg signed [BIAS_BITS-1 : 0] stage6_bias_in ;

reg signed [BIAS_BITS-1 : 0] bias_in_dly0 , bias_in_dly1 , bias_in_dly2 , bias_in_dly3 , bias_in_dly4 , bias_in_dly5 , bias_in_dly6 , bias_in_dly7 ;

// reg [ 4-1 : 0] stage0_bias_offset ;
// reg [ 4-1 : 0] stage1_bias_offset ;
// reg [ 4-1 : 0] stage2_bias_offset ;
// reg [ 4-1 : 0] stage3_bias_offset ;
// reg [ 4-1 : 0] stage4_bias_offset ;
// reg [ 4-1 : 0] stage5_bias_offset ;
// reg [ 4-1 : 0] stage6_bias_offset ;
// reg [ 4-1 : 0] stage7_bias_offset ;

// reg signed [ 31 : 0 ] bias_sum ;


//-- stage 0--//
reg		[ELE_BITS-1 : 0 ] stage0_act_0 ;
reg		[ELE_BITS-1 : 0 ] stage0_act_1 ;
reg		[ELE_BITS-1 : 0 ] stage0_act_2 ;
reg		[ELE_BITS-1 : 0 ] stage0_act_3 ;
reg		[ELE_BITS-1 : 0 ] stage0_act_4 ;
reg		[ELE_BITS-1 : 0 ] stage0_act_5 ;
reg		[ELE_BITS-1 : 0 ] stage0_act_6 ;
reg		[ELE_BITS-1 : 0 ] stage0_act_7 ;

reg		[ELE_BITS-1 : 0 ] stage0_ker_0 ;
reg		[ELE_BITS-1 : 0 ] stage0_ker_1 ;
reg		[ELE_BITS-1 : 0 ] stage0_ker_2 ;
reg		[ELE_BITS-1 : 0 ] stage0_ker_3 ;
reg		[ELE_BITS-1 : 0 ] stage0_ker_4 ;
reg		[ELE_BITS-1 : 0 ] stage0_ker_5 ;
reg		[ELE_BITS-1 : 0 ] stage0_ker_6 ;
reg		[ELE_BITS-1 : 0 ] stage0_ker_7 ;

//  stage0..3_final_in 沒人讀(下游從 stage3..6_align_final 取)
reg		stage4_final_in	;
reg		stage5_final_in	;
reg		stage6_final_in	;
reg		stage7_final_in	;

//  stage0/1/2/7_align_final 沒人讀
reg		stage3_align_final	;
reg		stage4_align_final	;
reg		stage5_align_final	;
reg		stage6_align_final	;

//  stage1/2/3/6_valid_in 沒人讀
reg 	stage0_valid_in	;
reg 	stage4_valid_in	;
reg 	stage5_valid_in	;
reg 	stage7_valid_in	;

// wire signed [ 2*ELE_BITS -1 : 0] multsigned_pd_0 ;
// wire signed [ 2*ELE_BITS -1 : 0] multsigned_pd_1 ;
// wire signed [ 2*ELE_BITS -1 : 0] multsigned_pd_2 ;
// wire signed [ 2*ELE_BITS -1 : 0] multsigned_pd_3 ;
// wire signed [ 2*ELE_BITS -1 : 0] multsigned_pd_4 ;
// wire signed [ 2*ELE_BITS -1 : 0] multsigned_pd_5 ;
// wire signed [ 2*ELE_BITS -1 : 0] multsigned_pd_6 ;
// wire signed [ 2*ELE_BITS -1 : 0] multsigned_pd_7 ;
// assign multsigned_pd_0 = $signed( stage0_act_0 ) * $signed( stage0_ker_0 )	;
// assign multsigned_pd_1 = $signed( stage0_act_1 ) * $signed( stage0_ker_1 )	;
// assign multsigned_pd_2 = $signed( stage0_act_2 ) * $signed( stage0_ker_2 )	;
// assign multsigned_pd_3 = $signed( stage0_act_3 ) * $signed( stage0_ker_3 )	;
// assign multsigned_pd_4 = $signed( stage0_act_4 ) * $signed( stage0_ker_4 )	;
// assign multsigned_pd_5 = $signed( stage0_act_5 ) * $signed( stage0_ker_5 )	;
// assign multsigned_pd_6 = $signed( stage0_act_6 ) * $signed( stage0_ker_6 )	;
// assign multsigned_pd_7 = $signed( stage0_act_7 ) * $signed( stage0_ker_7 )	;

reg signed [ 2*ELE_BITS+1  : 0] stage1_multsigned_pd_0 ;
reg signed [ 2*ELE_BITS+1  : 0] stage1_multsigned_pd_1 ;
reg signed [ 2*ELE_BITS+1  : 0] stage1_multsigned_pd_2 ;
reg signed [ 2*ELE_BITS+1  : 0] stage1_multsigned_pd_3 ;
reg signed [ 2*ELE_BITS+1  : 0] stage1_multsigned_pd_4 ;
reg signed [ 2*ELE_BITS+1  : 0] stage1_multsigned_pd_5 ;
reg signed [ 2*ELE_BITS+1  : 0] stage1_multsigned_pd_6 ;
reg signed [ 2*ELE_BITS+1  : 0] stage1_multsigned_pd_7 ;


//--Declare stage 2--//
reg signed [ 2*ELE_BITS+2  : 0] stage2_addmult_0 ;
reg signed [ 2*ELE_BITS+2  : 0] stage2_addmult_1 ;
reg signed [ 2*ELE_BITS+2  : 0] stage2_addmult_2 ;
reg signed [ 2*ELE_BITS+2  : 0] stage2_addmult_3 ;
//--Declare stage 3--//
reg signed [ 2*ELE_BITS+3  : 0] stage3_add2_0 ;
reg signed [ 2*ELE_BITS+3  : 0] stage3_add2_1 ;


//--Declare stage 4--//
reg signed [ OUT_BITS-1  : 0] stage4_addend_0 ;

//--Declare stage 5--//
reg signed [ OUT_BITS-1  : 0] stage5_acc_0 ;
reg signed [ OUT_BITS-1  : 0] stage5_accout ;
//--Declare stage 6--//
reg signed [ OUT_BITS-1  : 0] stage6_ab_0 ;

//--- act unsigned add reg ----
reg  [ ELE_BITS : 0] stage1_addact_ru_0	;
reg  [ ELE_BITS : 0] stage1_addact_ru_1	;
reg  [ ELE_BITS : 0] stage1_addact_ru_2	;
reg  [ ELE_BITS : 0] stage1_addact_ru_3	;

reg  [ ELE_BITS+1 : 0] stage2_addact_ru_0	;
reg  [ ELE_BITS+1 : 0] stage2_addact_ru_1	;

reg  [ ELE_BITS+2 : 0] stage3_addact_ru_0	;

reg  [ 17 : 0] stage4_addact_acc_0 ;
reg  [ 17 : 0] stage4_asum_out_0 ;

reg  [ 17 : 0] stage5_asum_out_0 ;
reg  [ 17 : 0] stage6_actsum ;

//==============================================================================
//========    stage 0    ========
//==============================================================================
//----    pass {ker,bias} registed    -----
assign pass_ker =	{
	stage0_ker_0 , stage0_ker_1 , stage0_ker_2 , stage0_ker_3
	,	stage0_ker_4 , stage0_ker_5 , stage0_ker_6 , stage0_ker_7	};

assign pass_bias 	=	stage0_bias_in	;
//-----------------------------------------------------------------------------


// check input valid  stage0_valid_in
/*
always@( posedge clk )begin
	if ( stage0_valid_in )begin
		stage0_act_0 <= act_0	;
		stage0_act_1 <= act_1	;
		stage0_act_2 <= act_2	;
		stage0_act_3 <= act_3	;
		stage0_act_4 <= act_4	;
		stage0_act_5 <= act_5	;
		stage0_act_6 <= act_6	;
		stage0_act_7 <= act_7	;
	end
	else begin
		stage0_act_0 <= 'd0	;
		stage0_act_1 <= 'd0	;
		stage0_act_2 <= 'd0	;
		stage0_act_3 <= 'd0	;
		stage0_act_4 <= 'd0	;
		stage0_act_5 <= 'd0	;
		stage0_act_6 <= 'd0	;
		stage0_act_7 <= 'd0	;
	end
end
*/
always@( posedge clk )begin
	if(reset) begin
		stage0_act_0 <= 'd0	;
		stage0_act_1 <= 'd0	;
		stage0_act_2 <= 'd0	;
		stage0_act_3 <= 'd0	;
		stage0_act_4 <= 'd0	;
		stage0_act_5 <= 'd0	;
		stage0_act_6 <= 'd0	;
		stage0_act_7 <= 'd0	;
	end
	else begin
		if ( stage0_valid_in )begin
			stage0_act_0 <= act_0	;
			stage0_act_1 <= act_1	;
			stage0_act_2 <= act_2	;
			stage0_act_3 <= act_3	;
			stage0_act_4 <= act_4	;
			stage0_act_5 <= act_5	;
			stage0_act_6 <= act_6	;
			stage0_act_7 <= act_7	;
		end
		else begin
			stage0_act_0 <= 'd0	;
			stage0_act_1 <= 'd0	;
			stage0_act_2 <= 'd0	;
			stage0_act_3 <= 'd0	;
			stage0_act_4 <= 'd0	;
			stage0_act_5 <= 'd0	;
			stage0_act_6 <= 'd0	;
			stage0_act_7 <= 'd0	;
		end
	end
end
/*
always@( posedge clk )begin

	if ( stage0_valid_in )begin
		stage0_ker_0 <= ker_0	;
		stage0_ker_1 <= ker_1	;
		stage0_ker_2 <= ker_2	;
		stage0_ker_3 <= ker_3	;
		stage0_ker_4 <= ker_4	;
		stage0_ker_5 <= ker_5	;
		stage0_ker_6 <= ker_6	;
		stage0_ker_7 <= ker_7	;
	end
	else begin
		stage0_ker_0 <= 'd0	;
		stage0_ker_1 <= 'd0	;
		stage0_ker_2 <= 'd0	;
		stage0_ker_3 <= 'd0	;
		stage0_ker_4 <= 'd0	;
		stage0_ker_5 <= 'd0	;
		stage0_ker_6 <= 'd0	;
		stage0_ker_7 <= 'd0	;
	end

end
*/
always@( posedge clk )begin
	if(reset) begin
		stage0_ker_0 <= 'd0	;
		stage0_ker_1 <= 'd0	;
		stage0_ker_2 <= 'd0	;
		stage0_ker_3 <= 'd0	;
		stage0_ker_4 <= 'd0	;
		stage0_ker_5 <= 'd0	;
		stage0_ker_6 <= 'd0	;
		stage0_ker_7 <= 'd0	;
	end
	else begin
		if ( stage0_valid_in )begin
			stage0_ker_0 <= ker_0	;
			stage0_ker_1 <= ker_1	;
			stage0_ker_2 <= ker_2	;
			stage0_ker_3 <= ker_3	;
			stage0_ker_4 <= ker_4	;
			stage0_ker_5 <= ker_5	;
			stage0_ker_6 <= ker_6	;
			stage0_ker_7 <= ker_7	;
		end
		else begin
			stage0_ker_0 <= 'd0	;
			stage0_ker_1 <= 'd0	;
			stage0_ker_2 <= 'd0	;
			stage0_ker_3 <= 'd0	;
			stage0_ker_4 <= 'd0	;
			stage0_ker_5 <= 'd0	;
			stage0_ker_6 <= 'd0	;
			stage0_ker_7 <= 'd0	;
		end
	end

end

//==============================================================================
//========    stage 1    =======================================================
//==============================================================================
// signed multiply
always@( posedge clk )begin
	if( reset )begin
		stage1_multsigned_pd_0 <= 'd0 ;
		stage1_multsigned_pd_1 <= 'd0 ;
		stage1_multsigned_pd_2 <= 'd0 ;
		stage1_multsigned_pd_3 <= 'd0 ;
		stage1_multsigned_pd_4 <= 'd0 ;
		stage1_multsigned_pd_5 <= 'd0 ;
		stage1_multsigned_pd_6 <= 'd0 ;
		stage1_multsigned_pd_7 <= 'd0 ;
	end
	else begin
		stage1_multsigned_pd_0 <= $signed( {1'd0 , stage0_act_0} ) * $signed( {1'd0 , stage0_ker_0} )	;
		stage1_multsigned_pd_1 <= $signed( {1'd0 , stage0_act_1} ) * $signed( {1'd0 , stage0_ker_1} )	;
		stage1_multsigned_pd_2 <= $signed( {1'd0 , stage0_act_2} ) * $signed( {1'd0 , stage0_ker_2} )	;
		stage1_multsigned_pd_3 <= $signed( {1'd0 , stage0_act_3} ) * $signed( {1'd0 , stage0_ker_3} )	;
stage1_multsigned_pd_4 <= $signed( {1'd0 , stage0_act_4} ) * $signed( {1'd0 , stage0_ker_4} )	;
		stage1_multsigned_pd_5 <= $signed( {1'd0 , stage0_act_5} ) * $signed( {1'd0 , stage0_ker_5} )	;
		stage1_multsigned_pd_6 <= $signed( {1'd0 , stage0_act_6} ) * $signed( {1'd0 , stage0_ker_6} )	;
		stage1_multsigned_pd_7 <= $signed( {1'd0 , stage0_act_7} ) * $signed( {1'd0 , stage0_ker_7} )	;
	end

end



// tree signed addition with unsigned number activation
always@(posedge clk )begin
	if(reset)begin
		stage1_addact_ru_0 <= 'd0 ;
		stage1_addact_ru_1 <= 'd0 ;
		stage1_addact_ru_2 <= 'd0 ;
		stage1_addact_ru_3 <= 'd0 ;

	end
	else begin
		stage1_addact_ru_0 <= stage0_act_0 + stage0_act_1	;
		stage1_addact_ru_1 <= stage0_act_2 + stage0_act_3	;
		stage1_addact_ru_2 <= stage0_act_4 + stage0_act_5	;
		stage1_addact_ru_3 <= stage0_act_6 + stage0_act_7	;
	end
end





//==============================================================================
//========    stage 2    ========
//==============================================================================
// add stage1 mult
always@( posedge clk )begin
	if( reset )begin
		stage2_addmult_0 <= 'd0 ;
		stage2_addmult_1 <= 'd0 ;
		stage2_addmult_2 <= 'd0 ;
		stage2_addmult_3 <= 'd0 ;
	end
	else begin
		stage2_addmult_0 <= $signed( stage1_multsigned_pd_0 ) + $signed( stage1_multsigned_pd_1 )	;
		stage2_addmult_1 <= $signed( stage1_multsigned_pd_2 ) + $signed( stage1_multsigned_pd_3 )	;
		stage2_addmult_2 <= $signed( stage1_multsigned_pd_4 ) + $signed( stage1_multsigned_pd_5 )	;
		stage2_addmult_3 <= $signed( stage1_multsigned_pd_6 ) + $signed( stage1_multsigned_pd_7 )	;
	end

end
// tree signed addition activation
always@(posedge clk )begin
	if( reset )begin
		stage2_addact_ru_0 <= 'd0 ;
		stage2_addact_ru_1 <= 'd0 ;

	end
	else begin
		stage2_addact_ru_0 <= stage1_addact_ru_0 + stage1_addact_ru_1 ;
		stage2_addact_ru_1 <= stage1_addact_ru_2 + stage1_addact_ru_3 ;
	end
end





//==============================================================================
//========    stage 3    ========
//==============================================================================
always@( posedge clk )begin
	if( reset )begin
		stage3_add2_0 <= 'd0 ;
		stage3_add2_1 <= 'd0 ;
	end
	else begin
		stage3_add2_0	<= $signed( stage2_addmult_0 ) + $signed( stage2_addmult_1 )	;
		stage3_add2_1	<= $signed( stage2_addmult_2 ) + $signed( stage2_addmult_3 )	;
	end
	
end

// tree signed addition activation
always@(posedge clk )begin
	if( reset )begin
		stage3_addact_ru_0 <= 'd0 ;
	end
	else begin
		stage3_addact_ru_0 <= stage2_addact_ru_0 + stage2_addact_ru_1 ;
	end
end
//-----------------------------------------------------------------------------





//==============================================================================
//========    stage 4    ========
//==============================================================================
// signed add for MAC
always@( posedge clk )begin
	if( reset )begin
		stage4_addend_0 <= 'd0 ;
	end
	else begin
		stage4_addend_0 <= $signed( stage3_add2_0 ) + $signed( stage3_add2_1 )	;
	end
end

// acculmator for Act_sum operation, check final flag for necessary ACC
always@(posedge clk )begin
	if( reset )begin
		stage4_addact_acc_0 <= 'd0 ;
	end
	else begin
		if( stage4_valid_in)begin
			if( !stage4_final_in )begin
				stage4_addact_acc_0 <=  stage4_addact_acc_0 +  stage3_addact_ru_0  ;
			end
			else begin
				stage4_addact_acc_0 <=  0  ;
			end
		end
		else begin
			stage4_addact_acc_0 <= stage4_addact_acc_0 ;
		end
	end
end

always @(posedge clk ) begin
	if(reset)begin
		stage4_asum_out_0 <= 0 ;
	end
	else begin
		if(stage4_final_in)begin
			stage4_asum_out_0 <=  stage4_addact_acc_0 +  stage3_addact_ru_0  ;
		end
		else begin
			stage4_asum_out_0 <=  0 ;
		end
	end
end



//==============================================================================
//========    stage 5    ========
//==============================================================================


always @(posedge clk ) begin
	if(reset)begin
		stage5_accout <= 'd0 ;
	end
	else begin
		if(stage5_final_in)begin
			stage5_accout <= $signed( stage5_acc_0 ) + $signed( stage4_addend_0 )	;
		end
		else begin
			stage5_accout <= 'd0 ;
		end
	end
end

// acculmator for MAC operation, check final flag for necessary ACC
always@( posedge clk )begin
	if( reset )begin
		stage5_acc_0 <= 'd0 ;
	end
	else begin
		if( stage5_valid_in )begin
			if( !stage5_final_in)begin
				stage5_acc_0 <= $signed( stage5_acc_0 ) + $signed( stage4_addend_0 )	;
			end
			else begin
				// stage5_acc_0 <= 'd0 + $signed( stage4_addend_0 )	;
				stage5_acc_0 <= 'd0 	;
			end
			
		end
		else begin
			stage5_acc_0 <= stage5_acc_0	;
		end
		
	end
	
end

// shift  act_sum  to stage 5
always@(posedge clk )begin
	if(reset) begin
		stage5_asum_out_0 <= 'd0 ;
	end
	else begin
		stage5_asum_out_0 <= stage4_asum_out_0 ;
	end
end





//==============================================================================
//========    stage 6    ========
//==============================================================================
// add bias
always@(posedge clk )begin
	if(reset)begin
		stage6_ab_0 <= 32'd0	;
	end
	else begin
		if( stage6_final_in )begin
			stage6_ab_0 <= stage5_accout + stage6_bias_in;
		end
		else begin
			stage6_ab_0 <= 32'd0 ;
		end
	end
end

// shift act_sum to stage 6 for final stage output
always@(posedge clk )begin
	if(reset) begin
		stage6_actsum <= 'd0 ;
	end
	else begin
		stage6_actsum <= stage5_asum_out_0 ;
	end
end




//==============================================================================
//========    stage 7    ========
//==============================================================================
//--ver2 pe output logic ----
always@( posedge clk )begin
	if(reset )begin
		outmacb_sum <= 32'd0 ;
		outact_sum <= 32'd0 ;
		valid_out <= 0 ;
	end
	else begin
		if( stage7_valid_in )begin
			if( stage7_final_in)begin
				outmacb_sum <= stage6_ab_0		 ;
				outact_sum <=  stage6_actsum	 ;
				valid_out <= 1 ;
			end
			else begin
				outmacb_sum <= outmacb_sum;
				outact_sum <= outact_sum;
				valid_out <= 0 ;
			end
			
		end
		else begin
			outmacb_sum <= 32'd0	;
			outact_sum <= 32'd0	;
			valid_out <= 0 ;
		end

	end
end




//==============================================================================
//========    valid and final     ========
//==============================================================================
always@( * )begin
	stage3_align_final	= final_in_dly3 ;
	stage4_align_final	= final_in_dly4 ;
	stage5_align_final	= final_in_dly5 ;
	stage6_align_final	= final_in_dly6 ;
end
always@( * )begin
	stage4_final_in	= stage3_align_final ;
	stage5_final_in	= stage4_align_final ;
	stage6_final_in	= stage5_align_final ;
	stage7_final_in	= stage6_align_final ;
end
always@( * )begin
	stage0_valid_in	= valid_in ;
	stage4_valid_in	= valid_in_dly3 ;
	stage5_valid_in	= valid_in_dly4 ;
	stage7_valid_in	= valid_in_dly6 ;
end

/*
always @(posedge clk ) begin
	valid_in_dly0 <= valid_in ;
	valid_in_dly1 <= valid_in_dly0 ;
	valid_in_dly2 <= valid_in_dly1 ;
	valid_in_dly3 <= valid_in_dly2 ;
	valid_in_dly4 <= valid_in_dly3 ;
	valid_in_dly5 <= valid_in_dly4 ;
	valid_in_dly6 <= valid_in_dly5 ;
	valid_in_dly7 <= valid_in_dly6 ;
end
*/

always @(posedge clk ) begin
	if(reset) begin
		valid_in_dly0 <= 0;
		valid_in_dly1 <= 0;
		valid_in_dly2 <= 0;
		valid_in_dly3 <= 0;
		valid_in_dly4 <= 0;
		valid_in_dly5 <= 0;
		valid_in_dly6 <= 0;
		valid_in_dly7 <= 0;
	end
	else begin
		valid_in_dly0 <= valid_in ;
		valid_in_dly1 <= valid_in_dly0 ;
		valid_in_dly2 <= valid_in_dly1 ;
		valid_in_dly3 <= valid_in_dly2 ;
		valid_in_dly4 <= valid_in_dly3 ;
		valid_in_dly5 <= valid_in_dly4 ;
		valid_in_dly6 <= valid_in_dly5 ;
		valid_in_dly7 <= valid_in_dly6 ;
	end
end
/*
always @(posedge clk ) begin
	final_in_dly0 <= final_in ;
	final_in_dly1 <= final_in_dly0 ;
	final_in_dly2 <= final_in_dly1 ;
	final_in_dly3 <= final_in_dly2 ;
	final_in_dly4 <= final_in_dly3 ;
	final_in_dly5 <= final_in_dly4 ;
	final_in_dly6 <= final_in_dly5 ;
	final_in_dly7 <= final_in_dly6 ;
end
*/

always @(posedge clk ) begin
	if(reset) begin
		final_in_dly0 <= 0;
		final_in_dly1 <= 0;
		final_in_dly2 <= 0;
		final_in_dly3 <= 0;
		final_in_dly4 <= 0;
		final_in_dly5 <= 0;
		final_in_dly6 <= 0;
		final_in_dly7 <= 0;
	end
	else begin
		final_in_dly0 <= final_in ;
		final_in_dly1 <= final_in_dly0 ;
		final_in_dly2 <= final_in_dly1 ;
		final_in_dly3 <= final_in_dly2 ;
		final_in_dly4 <= final_in_dly3 ;
		final_in_dly5 <= final_in_dly4 ;
		final_in_dly6 <= final_in_dly5 ;
		final_in_dly7 <= final_in_dly6 ;
	end
end

//==============================================================================
//========    biasing block    =================================================
//==============================================================================
/*
always @(posedge clk ) begin
	bias_in_dly0 <= bias_in ;
	bias_in_dly1 <= bias_in_dly0 ;
	bias_in_dly2 <= bias_in_dly1 ;
	bias_in_dly3 <= bias_in_dly2 ;
	bias_in_dly4 <= bias_in_dly3 ;
	bias_in_dly5 <= bias_in_dly4 ;
	bias_in_dly6 <= bias_in_dly5 ;
	bias_in_dly7 <= bias_in_dly6 ;
end
*/

always @(posedge clk ) begin
	if(reset) begin
		bias_in_dly0 <= 0;
		bias_in_dly1 <= 0;
		bias_in_dly2 <= 0;
		bias_in_dly3 <= 0;
		bias_in_dly4 <= 0;
		bias_in_dly5 <= 0;
		bias_in_dly6 <= 0;
		bias_in_dly7 <= 0;
	end
	else begin
		bias_in_dly0 <= bias_in ;
		bias_in_dly1 <= bias_in_dly0 ;
		bias_in_dly2 <= bias_in_dly1 ;
		bias_in_dly3 <= bias_in_dly2 ;
		bias_in_dly4 <= bias_in_dly3 ;
		bias_in_dly5 <= bias_in_dly4 ;
		bias_in_dly6 <= bias_in_dly5 ;
		bias_in_dly7 <= bias_in_dly6 ;
	end
end



//==============================================================================
//========    alignment bias in with align final    ========
//==============================================================================
always @(*) begin
		stage0_bias_in	= bias_in_dly0	;
		stage6_bias_in	= bias_in_dly4	;	// stage 6 need bias data make sure stage5_align_final=1, with correct bias data.
end

// //---- biasing block ----//
// always@( *)begin
// 	if ( stage0_valid_in )begin
// 		stage0_bias_in	= bias_in	;
// 		// stage0_bias_offset	<= bias_offset	;
// 	end
// 	else begin
// 		stage0_bias_in	= 'd0	;
// 		// stage0_bias_offset	<= 'd0	;
// 	end
// end

// always@( posedge clk )begin
// 	if ( reset )begin
// 		stage1_bias_in	<= 'd0	;
// 		stage2_bias_in	<= 'd0	;
// 		stage3_bias_in	<= 'd0	;
// 		stage4_bias_in	<= 'd0	;
// 		stage5_bias_in	<= 'd0	;
// 		stage6_bias_in	<= 'd0	;
// 		stage7_bias_in	<= 'd0	;

// 		// stage1_bias_offset	<= 'd0	;
// 		// stage2_bias_offset	<= 'd0	;
// 		// stage3_bias_offset	<= 'd0	;
// 		// stage4_bias_offset	<= 'd0	;
// 		// stage5_bias_offset	<= 'd0	;
// 		// stage6_bias_offset	<= 'd0	;
// 		// stage7_bias_offset	<= 'd0	;

// 	end
// 	else begin
// 		stage1_bias_in	<= stage0_bias_in	;
// 		stage2_bias_in	<= stage1_bias_in	;
// 		stage3_bias_in	<= stage2_bias_in	;
// 		stage4_bias_in	<= stage3_bias_in	;
// 		stage5_bias_in	<= stage4_bias_in	;
// 		stage6_bias_in	<= stage5_bias_in	;
// 		stage7_bias_in	<= stage6_bias_in	;

// 		// stage1_bias_offset	<= stage0_bias_offset	;
// 		// stage2_bias_offset	<= stage1_bias_offset	;
// 		// stage3_bias_offset	<= stage2_bias_offset	;
// 		// stage4_bias_offset	<= stage3_bias_offset	;
// 		// stage5_bias_offset	<= stage4_bias_offset	;
// 		// stage6_bias_offset	<= stage5_bias_offset	;
// 		// stage7_bias_offset	<= stage6_bias_offset	;
// 	end
// end
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------




endmodule

