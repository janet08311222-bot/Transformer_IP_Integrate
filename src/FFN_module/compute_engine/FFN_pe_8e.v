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

// ============================================================================
// Designer : Chao-Ping Liu
// Create   : 2025.06.24
// Ver      : 1.0
// Func     : PE element    ----
//                          -pe-
//                          ----
// ============================================================================
// `define FPGA_SETTING
// `define FPGA_ILA_CHK_SETTING

// ---------------------------------------------------------------------------
// DSP mapping is controlled PER-SIGNAL below, not module-wide:
//   - multiply products (stage1_multsigned_pd_*) -> DSP48E1   (* use_dsp = "yes" *)
//   - adder tree / accumulators                  -> LUT fabric (* use_dsp = "no"  *)
// Rationale (xc7z020, 16-way PE column):
//   128 9x9 multiplies = 128 DSP (irreducible without packing). A module-wide
//   (* use_dsp = "yes"/"simd" *) ALSO packed the ~96 adder/accumulator ops into
//   DSP48E1 post-adders -> 224 DSP synth (+6 quant black-box = 230 impl) > 220.
//   Pinning only the multiplies to DSP and pushing the adders into the (idle,
//   ~10% used) LUT fabric drops the PE array to 128 DSP. Pure synthesis mapping,
//   no RTL semantic change -> bit-exact.

module FFN_pe_8e #(
	parameter ELE_BITS = 8 ,	// PE each pixel bits
	parameter OUT_BITS = 32,
	parameter BIAS_BITS = 32
)(
        clk
    ,	reset

    ,	input_0
    ,	input_1
    ,	input_2
    ,	input_3
    ,	input_4
    ,	input_5
    ,	input_6
    ,	input_7
    ,	ker_0
    ,	ker_1
    ,	ker_2
    ,	ker_3
    ,	ker_4
    ,	ker_5
    ,	ker_6
    ,	ker_7
    ,	bias

    ,	valid_in
    ,	final_in

    ,   pass_input
    ,	pass_ker
    ,	pass_bias

    ,   pass_valid_in
    ,   pass_final_in

    ,	valid_out
    ,	outmacb_sum
    ,	outact_sum

);

    //========================================================================
    //========    I/O Declare    =============================================
    //========================================================================
    input clk 	    ;
    input reset 	;
    input [ELE_BITS-1: 0] input_0    ;
    input [ELE_BITS-1: 0] input_1    ;
    input [ELE_BITS-1: 0] input_2    ;
    input [ELE_BITS-1: 0] input_3    ;
    input [ELE_BITS-1: 0] input_4    ;
    input [ELE_BITS-1: 0] input_5    ;
    input [ELE_BITS-1: 0] input_6    ;
    input [ELE_BITS-1: 0] input_7    ;
    input [ELE_BITS-1: 0] ker_0      ;
    input [ELE_BITS-1: 0] ker_1      ;
    input [ELE_BITS-1: 0] ker_2      ;
    input [ELE_BITS-1: 0] ker_3      ;
    input [ELE_BITS-1: 0] ker_4      ;
    input [ELE_BITS-1: 0] ker_5      ;
    input [ELE_BITS-1: 0] ker_6      ;
    input [ELE_BITS-1: 0] ker_7      ;
    input signed [BIAS_BITS-1: 0] bias ;
    input valid_in 	;
    input final_in 	;
    
    output wire [8*ELE_BITS-1: 0]   pass_input 	;
    output wire	[8*ELE_BITS-1: 0] 	pass_ker 	;
    output wire signed	[BIAS_BITS-1: 0] 	pass_bias 	;
    output wire pass_valid_in   ;
    output wire pass_final_in   ;
    
    output reg valid_out ;
    output reg signed  [OUT_BITS-1: 0] outmacb_sum ;
    output reg signed  [OUT_BITS-1: 0] outact_sum ;
    //-----------------------------------------------------------------------------
    
    //-------------Declare-----------------------------------------//
    
    reg valid_in_dly0, valid_in_dly1, valid_in_dly2, valid_in_dly3, valid_in_dly4, valid_in_dly5, valid_in_dly6, valid_in_dly7;
    reg final_in_dly0, final_in_dly1, final_in_dly2, final_in_dly3, final_in_dly4, final_in_dly5, final_in_dly6, final_in_dly7;
    
    reg signed [BIAS_BITS-1: 0] bias_dly0, bias_dly1, bias_dly2, bias_dly3, bias_dly4, bias_dly5, bias_dly6, bias_dly7;
    reg signed [BIAS_BITS-1: 0] stage0_bias ;
    reg signed [BIAS_BITS-1: 0] stage1_bias ;
    reg signed [BIAS_BITS-1: 0] stage2_bias ;
    reg signed [BIAS_BITS-1: 0] stage3_bias ;
    reg signed [BIAS_BITS-1: 0] stage4_bias ;
    reg signed [BIAS_BITS-1: 0] stage5_bias ;
    reg signed [BIAS_BITS-1: 0] stage6_bias ;
    reg signed [BIAS_BITS-1: 0] stage7_bias ;
    
    reg     stage0_final_in	;
    reg     stage1_final_in	;
    reg     stage2_final_in	;
    reg     stage3_final_in	;
    reg     stage4_final_in	;
    reg     stage5_final_in	;
    reg     stage6_final_in	;
    reg     stage7_final_in	;
    
    reg 	stage0_valid_in	;
    reg 	stage1_valid_in	;
    reg 	stage2_valid_in	;
    reg 	stage3_valid_in	;
    reg 	stage4_valid_in	;
    reg 	stage5_valid_in	;
    reg 	stage6_valid_in	;
    reg 	stage7_valid_in	;
    
    //-- stage 0 --//
    reg [ELE_BITS-1: 0] stage0_input_0 ;
    reg [ELE_BITS-1: 0] stage0_input_1 ;
    reg [ELE_BITS-1: 0] stage0_input_2 ;
    reg [ELE_BITS-1: 0] stage0_input_3 ;
    reg [ELE_BITS-1: 0] stage0_input_4 ;
    reg [ELE_BITS-1: 0] stage0_input_5 ;
    reg [ELE_BITS-1: 0] stage0_input_6 ;
    reg [ELE_BITS-1: 0] stage0_input_7 ;
    
    reg [ELE_BITS-1: 0] stage0_ker_0 ;
    reg [ELE_BITS-1: 0] stage0_ker_1 ;
    reg [ELE_BITS-1: 0] stage0_ker_2 ;
    reg [ELE_BITS-1: 0] stage0_ker_3 ;
    reg [ELE_BITS-1: 0] stage0_ker_4 ;
    reg [ELE_BITS-1: 0] stage0_ker_5 ;
    reg [ELE_BITS-1: 0] stage0_ker_6 ;
    reg [ELE_BITS-1: 0] stage0_ker_7 ;
    
    //-- stage 1 --//  multiplies pinned to DSP48E1
    (* use_dsp = "yes" *) reg signed [2*ELE_BITS+1: 0] stage1_multsigned_pd_0 ;
    (* use_dsp = "yes" *) reg signed [2*ELE_BITS+1: 0] stage1_multsigned_pd_1 ;
    (* use_dsp = "yes" *) reg signed [2*ELE_BITS+1: 0] stage1_multsigned_pd_2 ;
    (* use_dsp = "yes" *) reg signed [2*ELE_BITS+1: 0] stage1_multsigned_pd_3 ;
    (* use_dsp = "yes" *) reg signed [2*ELE_BITS+1: 0] stage1_multsigned_pd_4 ;
    (* use_dsp = "yes" *) reg signed [2*ELE_BITS+1: 0] stage1_multsigned_pd_5 ;
    (* use_dsp = "yes" *) reg signed [2*ELE_BITS+1: 0] stage1_multsigned_pd_6 ;
    (* use_dsp = "yes" *) reg signed [2*ELE_BITS+1: 0] stage1_multsigned_pd_7 ;
    
    //-- stage 2 --//  adder tree forced to LUT fabric (off DSP)
    (* use_dsp = "no" *) reg signed [2*ELE_BITS+2: 0] stage2_addmult_0 ;
    (* use_dsp = "no" *) reg signed [2*ELE_BITS+2: 0] stage2_addmult_1 ;
    (* use_dsp = "no" *) reg signed [2*ELE_BITS+2: 0] stage2_addmult_2 ;
    (* use_dsp = "no" *) reg signed [2*ELE_BITS+2: 0] stage2_addmult_3 ;

    //-- stage 3 --//
    (* use_dsp = "no" *) reg signed [2*ELE_BITS+3: 0] stage3_add2_0 ;
    (* use_dsp = "no" *) reg signed [2*ELE_BITS+3: 0] stage3_add2_1 ;

    //-- stage 4 --//
    (* use_dsp = "no" *) reg signed [OUT_BITS-1: 0] stage4_addend_0 ;

    //-- stage 5 --//  accumulators forced to LUT fabric (off DSP)
    (* use_dsp = "no" *) reg signed [OUT_BITS-1: 0] stage5_acc_0 ;
    (* use_dsp = "no" *) reg signed [OUT_BITS-1: 0] stage5_accout ;

    //-- stage 6 --//
    (* use_dsp = "no" *) reg signed [OUT_BITS-1: 0] stage6_ab_0 ;
    
    //--- act unsigned add reg ----
    reg  [ELE_BITS: 0] stage1_addact_ru_0	;
    reg  [ELE_BITS: 0] stage1_addact_ru_1	;
    reg  [ELE_BITS: 0] stage1_addact_ru_2	;
    reg  [ELE_BITS: 0] stage1_addact_ru_3	;
    
    reg  [ELE_BITS+1: 0] stage2_addact_ru_0	;
    reg  [ELE_BITS+1: 0] stage2_addact_ru_1	;
    
    reg  [ELE_BITS+2: 0] stage3_addact_ru_0	;
    
    reg  [17: 0] stage4_addact_acc_0 ;
    reg  [17: 0] stage4_asum_out_0 ;
    
    reg  [17: 0] stage5_asum_out_0 ;
    reg  [17: 0] stage6_actsum ;
    
    //----    pass {ker,bias} registed    -----
    assign pass_ker         =	{stage0_ker_0, stage0_ker_1, stage0_ker_2, stage0_ker_3, stage0_ker_4, stage0_ker_5, stage0_ker_6, stage0_ker_7};
    assign pass_input       =   {stage0_input_0, stage0_input_1, stage0_input_2, stage0_input_3, stage0_input_4 ,stage0_input_5, stage0_input_6, stage0_input_7};
    assign pass_bias 	    =	stage0_bias	    ;
    assign pass_valid_in    =   stage1_valid_in ;
    assign pass_final_in    =   stage1_final_in ;
    //-----------------------------------------------------------------------------
    
    //==============================================================================
    //========    biasing block    =================================================
    //==============================================================================
    always @(posedge clk ) begin
    	bias_dly0 <= bias ;
    	bias_dly1 <= bias_dly0 ;
    	bias_dly2 <= bias_dly1 ;
    	bias_dly3 <= bias_dly2 ;
    	bias_dly4 <= bias_dly3 ;
    	bias_dly5 <= bias_dly4 ;
    	bias_dly6 <= bias_dly5 ;
    	bias_dly7 <= bias_dly6 ;
    end
    
    //==============================================================================
    //========    alignment bias in with align final    ========
    //==============================================================================
    always @(*) begin
    	stage0_bias	= bias_dly0	;
    	stage1_bias	= bias_dly0	;
    	stage2_bias	= bias_dly0	;
    	stage3_bias	= bias_dly1	;
    	stage4_bias	= bias_dly2	;
    	stage5_bias	= bias_dly3	;
    	stage6_bias	= bias_dly4	;	// stage 6 need bias data make sure stage5_align_final=1, with correct bias data.
    	stage7_bias	= bias_dly5	;
    end
    
    //==============================================================================
    //========    valid and final     ========
    //=============================================================================
    
    // valid in
    always @(*) begin
        stage0_valid_in	= valid_in ;
        stage1_valid_in	= valid_in_dly0 ;
        stage2_valid_in	= valid_in_dly1 ;
        stage3_valid_in	= valid_in_dly2 ;
        stage4_valid_in	= valid_in_dly3 ;
        stage5_valid_in	= valid_in_dly4 ;
        stage6_valid_in	= valid_in_dly5 ;
        stage7_valid_in	= valid_in_dly6 ;
    end
    always @(posedge clk) begin
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
    
    // final in
    always @(*) begin
        stage0_final_in	= final_in;
        stage1_final_in	= final_in_dly0 ;
        stage2_final_in	= final_in_dly1 ;
        stage3_final_in	= final_in_dly2 ;
        stage4_final_in	= final_in_dly3 ;
        stage5_final_in	= final_in_dly4 ;
        stage6_final_in	= final_in_dly5 ;
        stage7_final_in	= final_in_dly6 ;
    end
    always @(posedge clk) begin
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
    //========    stage 0    ========
    //==============================================================================
    
    // check input valid  stage0_valid_in
    always @(posedge clk) begin
        if(reset) begin
            stage0_input_0 <= 'd0	;
            stage0_input_1 <= 'd0	;
            stage0_input_2 <= 'd0	;
            stage0_input_3 <= 'd0	;
            stage0_input_4 <= 'd0	;
            stage0_input_5 <= 'd0	;
            stage0_input_6 <= 'd0	;
            stage0_input_7 <= 'd0	;
        end
        else if(stage0_valid_in) begin
            stage0_input_0 <= input_0	;
            stage0_input_1 <= input_1	;
            stage0_input_2 <= input_2	;
            stage0_input_3 <= input_3	;
            stage0_input_4 <= input_4	;
            stage0_input_5 <= input_5	;
            stage0_input_6 <= input_6	;
            stage0_input_7 <= input_7	;
        end
        else begin
            stage0_input_0 <= 'd0	;
            stage0_input_1 <= 'd0	;
            stage0_input_2 <= 'd0	;
            stage0_input_3 <= 'd0	;
            stage0_input_4 <= 'd0	;
            stage0_input_5 <= 'd0	;
            stage0_input_6 <= 'd0	;
            stage0_input_7 <= 'd0	;
        end
    end
    
    always @(posedge clk) begin
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
        else if(stage0_valid_in) begin
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
    
    //==============================================================================
    //========    stage 1    =======================================================
    //==============================================================================
    
    // signed multiply
    always @(posedge clk) begin
        if(reset) begin
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
            stage1_multsigned_pd_0 <= $signed( {1'd0 , stage0_input_0} ) * $signed( {1'd0 , stage0_ker_0} )	;
            stage1_multsigned_pd_1 <= $signed( {1'd0 , stage0_input_1} ) * $signed( {1'd0 , stage0_ker_1} )	;
            stage1_multsigned_pd_2 <= $signed( {1'd0 , stage0_input_2} ) * $signed( {1'd0 , stage0_ker_2} )	;
            stage1_multsigned_pd_3 <= $signed( {1'd0 , stage0_input_3} ) * $signed( {1'd0 , stage0_ker_3} )	;
            stage1_multsigned_pd_4 <= $signed( {1'd0 , stage0_input_4} ) * $signed( {1'd0 , stage0_ker_4} )	;
            stage1_multsigned_pd_5 <= $signed( {1'd0 , stage0_input_5} ) * $signed( {1'd0 , stage0_ker_5} )	;
            stage1_multsigned_pd_6 <= $signed( {1'd0 , stage0_input_6} ) * $signed( {1'd0 , stage0_ker_6} )	;
            stage1_multsigned_pd_7 <= $signed( {1'd0 , stage0_input_7} ) * $signed( {1'd0 , stage0_ker_7} )	;
        end
    end
    
    // tree signed addition with unsigned number activation
    always @(posedge clk) begin
        if(reset) begin
            stage1_addact_ru_0 <= 'd0 ;
            stage1_addact_ru_1 <= 'd0 ;
            stage1_addact_ru_2 <= 'd0 ;
            stage1_addact_ru_3 <= 'd0 ;
        end
        else begin
            stage1_addact_ru_0 <= stage0_input_0 + stage0_input_1	;
            stage1_addact_ru_1 <= stage0_input_2 + stage0_input_3	;
            stage1_addact_ru_2 <= stage0_input_4 + stage0_input_5	;
            stage1_addact_ru_3 <= stage0_input_6 + stage0_input_7	;
        end
    end
    
    //==============================================================================
    //========    stage 2    ========
    //==============================================================================
    
    // add stage1 mult
    always @(posedge clk) begin
        if(reset) begin
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
    always @(posedge clk) begin
        if(reset) begin
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
    
    always @(posedge clk) begin
        if(reset) begin
            stage3_add2_0 <= 'd0 ;
            stage3_add2_1 <= 'd0 ;
        end
        else begin
            stage3_add2_0 <= $signed( stage2_addmult_0 ) + $signed( stage2_addmult_1 )	;
            stage3_add2_1 <= $signed( stage2_addmult_2 ) + $signed( stage2_addmult_3 )	;
        end
    end
    
    // tree signed addition activation
    always @(posedge clk) begin
        if(reset) begin
            stage3_addact_ru_0 <= 'd0 ;
        end
        else begin
            stage3_addact_ru_0 <= stage2_addact_ru_0 + stage2_addact_ru_1 ;
        end
    end
    
    //==============================================================================
    //========    stage 4    ========
    //==============================================================================
    
    // signed add for MAC
    always @(posedge clk) begin
        if(reset) begin
            stage4_addend_0 <= 'd0 ;
        end
        else begin
            stage4_addend_0 <= $signed( stage3_add2_0 ) + $signed( stage3_add2_1 )	;
        end
    end
    
    // acculmator for Act_sum operation, check final flag for necessary ACC
    always @(posedge clk) begin
        if(reset) begin
            stage4_addact_acc_0 <= 'd0 ;
        end
        else begin
            if(stage4_valid_in) begin
                if(!stage4_final_in) begin
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
    always @(posedge clk) begin
        if(reset) begin
            stage4_asum_out_0 <= 0 ;
        end
        else begin
            if(stage4_final_in) begin
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
        if(reset) begin
            stage5_accout <= 'd0 ;
        end
        else begin
            if(stage5_final_in) begin
                stage5_accout <= $signed( stage5_acc_0 ) + $signed( stage4_addend_0 )	;
            end
            else begin
                stage5_accout <= 'd0 ;
            end
        end
    end
    
    // acculmator for MAC operation, check final flag for necessary ACC
    always @(posedge clk) begin
        if(reset) begin
            stage5_acc_0 <= 'd0 ;
        end
        else begin
            if(stage5_valid_in) begin
                if(!stage5_final_in) begin
                    stage5_acc_0 <= $signed( stage5_acc_0 ) + $signed( stage4_addend_0 )	;
                end
                else begin
                    stage5_acc_0 <= 'd0 	;
                end
            end
            else begin
                stage5_acc_0 <= stage5_acc_0	;
            end
        end
    end
    // shift  act_sum  to stage 5
    always @(posedge clk) begin
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
    always @(posedge clk) begin
        if(reset) begin
            stage6_ab_0 <= 32'd0	;
        end
        else begin
            if(stage6_final_in) begin
                stage6_ab_0 <= stage5_accout + stage6_bias;
            end
            else begin
                stage6_ab_0 <= 32'd0 ;
            end
        end
    end
    
    // shift act_sum to stage 6 for final stage output
    always @(posedge clk) begin
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
    always @(posedge clk) begin
        if(reset) begin
            outmacb_sum <= 32'd0 ;
            outact_sum <= 32'd0 ;
            valid_out <= 0 ;
        end
        else begin
            if(stage7_valid_in) begin
                if(stage7_final_in) begin
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

endmodule