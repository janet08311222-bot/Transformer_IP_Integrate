// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2023.03.02
// Ver      : 1.0
// Func     : PE block with 64 MACs
// ============================================================================
//              KER0        KER1           KER7                                
//               │     	     │              │                                  
//           ┌───▼───┐   ┌───▼───┐      ┌───▼───┐                              
//   IFMAP──►│ pe_c0 ├──►│ pe_c1 ├─•••─►│ pe_c7 ├──►                           
//           └───┬───┘   └───┬───┘      └───┬───┘                              
//               │           │              │                                  
//               └──────────┐│     ┌────────┘                                  
//                          ││ ••• │                                                
//                          ▼▼     ▼                                                
//                    ┌──────────────┐                                         
//             ┌──────┤ getPE result │                                         
//             │      └──────────────┘                                         
//             │      ┌──────────────┐                                         
//             └──────► re quantize  ├───► output uint8                        
//                    └──────────────┘                                         
// ===========================================================================

// ============================================================================
// Designer : Chao-Ping Liu
// Create   : 2025.06.24
// Ver      : 1.0
// Func     : PE array                     
// ============================================================================
// `define FPGA_SETTING
// `define FPGA_ILA_CHK_SETTING

module FFN_pe_array #(
	parameter TBITS = 64 
	,	TBYTE = 8
	,	BIAS_BITS = 32 
    ,   PEBLKCOL_NUM = 8
)(
		clk			
	,	reset	

	,	cfg_m0_scale 	
	,	cfg_index 		
	,	cfg_z_of_weight	
	,	cfg_z3			

	,	valid_din		
	,	final_din		

	,	input_data		
	,	array_ker_din	
	,	array_bias_din

	,	pass_array_ker_dout		
	,	pass_array_bias_dout	

	,	q_result_dout			
	,	valid_dout				

);

	//==============================================================================
	//========    I/O Port declare    ==============================================
	//==============================================================================
	input clk	;
	input reset	;
		
	input [ 32	-1: 0]	cfg_m0_scale 		;
	input [ 8	-1: 0]	cfg_index 			;
	input [ 16	-1: 0]	cfg_z_of_weight		;
	input [ 8	-1: 0]	cfg_z3				;
	
	input 				valid_din			;
	input 				final_din			;
	
	input [TBITS-1: 0]						input_data 		;
	input [PEBLKCOL_NUM * TBITS-1: 0]		array_ker_din	;
	input [PEBLKCOL_NUM * BIAS_BITS-1: 0]	array_bias_din	;
	
	output wire [PEBLKCOL_NUM * TBITS-1: 0]		pass_array_ker_dout		;
	output wire [PEBLKCOL_NUM * BIAS_BITS-1: 0]	pass_array_bias_dout	;
	
	output wire [8-1: 0]	q_result_dout	;
	output wire 			valid_dout		;
	//-----------------------------------------------------------------------------
	
	wire [TBITS-1: 0]		ker_din		[0:PEBLKCOL_NUM-1]	;
	wire [BIAS_BITS-1: 0]	bias_din	[0:PEBLKCOL_NUM-1]	;	
	
	wire [TBITS-1: 0]     	pass_input_dout	[0:PEBLKCOL_NUM-1]	;
	wire [TBITS-1: 0] 		pass_ker_dout	[0:PEBLKCOL_NUM-1]	;
	wire [BIAS_BITS-1: 0] 	pass_bias_dout	[0:PEBLKCOL_NUM-1]	;
	wire 					pass_valid_in	[0:PEBLKCOL_NUM-1]	;
	wire 					pass_final_in	[0:PEBLKCOL_NUM-1]	;
	
	//----    PE out connection    -----
	wire 			q_valid		[0:7]	;
	wire [32-1:0]	mac_result	[0:7]	;
	wire [32-1:0]	act_sum		[0:7]	;
	
	//----    result get declare    -----
	wire 			serial_valid	;
	wire [32-1:0]	serial_conv		;
	wire [32-1:0]	serial_actsum	;
	
	genvar gi ;
	generate
	    for (gi = 0; gi<PEBLKCOL_NUM; gi=gi+1) begin
	        assign ker_din[gi] = array_ker_din[(TBITS*(8-gi)-1) -: 64];
	        assign bias_din[gi] = array_bias_din[(BIAS_BITS*(8-gi)-1) -: 32];
	    end
	endgenerate
	
	assign pass_array_ker_dout	= {pass_ker_dout[0], pass_ker_dout[1], pass_ker_dout[2], pass_ker_dout[3], pass_ker_dout[4], pass_ker_dout[5], pass_ker_dout[6], pass_ker_dout[7]}			;
	assign pass_array_bias_dout	= {pass_bias_dout[0], pass_bias_dout[1], pass_bias_dout[2], pass_bias_dout[3], pass_bias_dout[4], pass_bias_dout[5], pass_bias_dout[6], pass_bias_dout[7]}	;
	
	FFN_quan2uint8 FFN_q0(
			.clk ( clk )  
		,	.reset 	( reset ) 		
		,	.m0_scale		(	cfg_m0_scale 		)
		,	.index			(	cfg_index 			)
		,	.z_of_weight	(	cfg_z_of_weight		)
		,	.valid_in		(	serial_valid	)
		,	.serial32_in	(	serial_conv		)
		,	.act_sum_in		(	serial_actsum	)
		,	.q_out			(	q_result_dout	)
		,	.valid_out		(	valid_dout		)
	);
	
	FFN_getpe_result #(
			.INV_BITS(	1 	) 	// input valid bits
		,	.OUTQ_BITS(	32 	) 	// output bits for quantization
	)FFN_gr00(
			.clk ( clk )  
		,	.reset ( reset ) 			
		,	.pe0_result 		(	{	q_valid[0]	,mac_result[0]	}	)
		,	.pe1_result 		(	{	q_valid[1]	,mac_result[1]	}	)
		,	.pe2_result 		(	{	q_valid[2]	,mac_result[2]	}	)
		,	.pe3_result 		(	{	q_valid[3]	,mac_result[3]	}	)
		,	.pe4_result 		(	{	q_valid[4]	,mac_result[4]	}	)
		,	.pe5_result 		(	{	q_valid[5]	,mac_result[5]	}	)
		,	.pe6_result 		(	{	q_valid[6]	,mac_result[6]	}	)
		,	.pe7_result 		(	{	q_valid[7]	,mac_result[7]	}	)
		,	.pe0_actsum 		(	act_sum[0]	)
		,	.pe1_actsum 		(	act_sum[1]	)
		,	.pe2_actsum 		(	act_sum[2]	)
		,	.pe3_actsum 		(	act_sum[3]	)
		,	.pe4_actsum 		(	act_sum[4]	)
		,	.pe5_actsum 		(	act_sum[5]	)
		,	.pe6_actsum 		(	act_sum[6]	)
		,	.pe7_actsum 		(	act_sum[7]	)
		,	.valid_out 			(	serial_valid		)
		,	.serial_result 		(	serial_conv			)
		,	.serial_actresult 	(	serial_actsum		)
	);
	
	//==============================================================================
	//========    8MAC PE instance    ========
	//==============================================================================
	//----instance pe generate by pe_instcode.py------
	//----pe col_0---------
	FFN_pe_8e #(
			.ELE_BITS(	8 	)
		,   .OUT_BITS(	32	)
		,   .BIAS_BITS(	32	) 
	)FFN_pe_col0(
	        .clk ( clk )     
	    ,   .reset ( reset )
	
		//---- input ----//
	    ,   .input_0( input_data[63-:8] )
	    ,   .input_1( input_data[55-:8] )
	    ,   .input_2( input_data[47-:8] )
	    ,   .input_3( input_data[39-:8] )
	    ,   .input_4( input_data[31-:8] )
	    ,   .input_5( input_data[23-:8] )
	    ,   .input_6( input_data[15-:8] )
	    ,   .input_7( input_data[ 7-:8] )
	    //---- kernel ----//
	    ,   .ker_0( ker_din[0][63-:8] )
	    ,   .ker_1( ker_din[0][55-:8] )
	    ,   .ker_2( ker_din[0][47-:8] )
	    ,   .ker_3( ker_din[0][39-:8] )
	    ,   .ker_4( ker_din[0][31-:8] )
	    ,   .ker_5( ker_din[0][23-:8] )
	    ,   .ker_6( ker_din[0][15-:8] )
	    ,   .ker_7( ker_din[0][ 7-:8] )
	    //---- bias ----//
	    ,   .bias	( bias_din[0] )
		
	    ,   .valid_in( valid_din )
	    ,   .final_in( final_din )
	
	    ,   .pass_ker ( pass_ker_dout[0] )
	    ,   .pass_bias ( pass_bias_dout[0] )
	    ,   .pass_input ( pass_input_dout[0] )
		,	.pass_valid_in ( pass_valid_in[0] )
		,	.pass_final_in ( pass_final_in[0] )
	
	    ,   .valid_out ( q_valid[0] )
	    ,   .outmacb_sum ( mac_result[0] )
	    ,   .outact_sum ( act_sum[0] )
	);
	
	genvar pi ;
	generate
		for(pi=1; pi<PEBLKCOL_NUM; pi=pi+1)begin	: pe8e_inst
			FFN_pe_8e #(
					.ELE_BITS(	8 	)
				,   .OUT_BITS(	32	)
				,   .BIAS_BITS(	32	) 
			)FFN_pe_col1(
					.clk ( clk )     
	    		,   .reset ( reset )
			
				//---- input ----//
	    		,   .input_0( pass_input_dout[pi-1][63-:8] )
	    		,   .input_1( pass_input_dout[pi-1][55-:8] )
	    		,   .input_2( pass_input_dout[pi-1][47-:8] )
	    		,   .input_3( pass_input_dout[pi-1][39-:8] )
	    		,   .input_4( pass_input_dout[pi-1][31-:8] )
	    		,   .input_5( pass_input_dout[pi-1][23-:8] )
	    		,   .input_6( pass_input_dout[pi-1][15-:8] )
	    		,   .input_7( pass_input_dout[pi-1][ 7-:8] )
	    		//---- kernel ----//
	    		,   .ker_0( ker_din[pi][63-:8] )
	    		,   .ker_1( ker_din[pi][55-:8] )
	    		,   .ker_2( ker_din[pi][47-:8] )
	    		,   .ker_3( ker_din[pi][39-:8] )
	    		,   .ker_4( ker_din[pi][31-:8] )
	    		,   .ker_5( ker_din[pi][23-:8] )
	    		,   .ker_6( ker_din[pi][15-:8] )
	    		,   .ker_7( ker_din[pi][ 7-:8] )
	    		//---- bias ----//
	    		,   .bias	( bias_din[pi] )
				
	    		,   .valid_in( pass_valid_in[pi-1] )
	    		,   .final_in( pass_final_in[pi-1] )
			
	    		,   .pass_ker ( pass_ker_dout[pi] )
	    		,   .pass_bias ( pass_bias_dout[pi] )
	    		,   .pass_input ( pass_input_dout[pi] )
				,	.pass_valid_in ( pass_valid_in[pi] )
				,	.pass_final_in ( pass_final_in[pi] )
			
	    		,   .valid_out ( q_valid[pi] )
	    		,   .outmacb_sum ( mac_result[pi] )
	    		,   .outact_sum ( act_sum[pi] )
			);
		end
	endgenerate

endmodule