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
// Phase 3: i-GELU enable is a RUNTIME CFG bit, not a compile switch — see the
//   quant instances below (cfg_gelu_en = cfg_z3[0]; FFN1=1, FFN2=0).

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
	wire 			q_valid		[0:PEBLKCOL_NUM-1]	;
	wire [32-1:0]	mac_result	[0:PEBLKCOL_NUM-1]	;
	wire [32-1:0]	act_sum		[0:PEBLKCOL_NUM-1]	;

	//----    flat buses to FFN_getpe_result serializer    -----
	wire [PEBLKCOL_NUM*(32+1)-1: 0]	pe_result_flat	;
	wire [PEBLKCOL_NUM*32-1: 0]		pe_actsum_flat	;
	
	//----    result get declare    -----
	wire 			serial_valid	;
	wire [32-1:0]	serial_conv		;
	wire [32-1:0]	serial_actsum	;
	
	genvar gi ;
	generate
	    for (gi = 0; gi<PEBLKCOL_NUM; gi=gi+1) begin : ker_slice
	        assign ker_din[gi]  = array_ker_din[(TBITS*(PEBLKCOL_NUM-gi)-1) -: TBITS];
	        assign bias_din[gi] = array_bias_din[(BIAS_BITS*(PEBLKCOL_NUM-gi)-1) -: BIAS_BITS];

	        // re-pack registered ker/bias back out in the same MSB-first order
	        assign pass_array_ker_dout[(TBITS*(PEBLKCOL_NUM-gi)-1) -: TBITS]      = pass_ker_dout[gi]  ;
	        assign pass_array_bias_dout[(BIAS_BITS*(PEBLKCOL_NUM-gi)-1) -: BIAS_BITS] = pass_bias_dout[gi] ;

	        // flat buses for the serializer (PE index gi in slot gi; order-independent)
	        assign pe_result_flat[gi*(32+1) +: (32+1)] = { q_valid[gi], mac_result[gi] } ;
	        assign pe_actsum_flat[gi*32     +: 32]      = act_sum[gi] ;
	    end
	endgenerate
	
	// Phase 3: both requantize paths are instantiated; cfg_gelu_en (= cfg_z3[0])
	// selects between them at RUNTIME, so one compiled design serves both layers:
	//   FFN1 -> cfg_z3[0]=1 -> i-GELU path ;  FFN2 -> cfg_z3[0]=0 -> plain M0 path.
	wire        cfg_gelu_en = cfg_z3[0] ;
	wire [7:0]  qz_m0_dout, qz_gelu_dout ;
	wire        qz_m0_valid, qz_gelu_valid ;

	// FFN2 (and any non-GELU layer): original M0 requantize
	FFN_quan2uint8 q0_m0(
			.clk ( clk )
		,	.reset 	( reset )
		,	.m0_scale		(	cfg_m0_scale 		)
		,	.index			(	cfg_index 			)
		,	.z_of_weight	(	cfg_z_of_weight		)
		,	.valid_in		(	serial_valid	)
		,	.serial32_in	(	serial_conv		)
		,	.act_sum_in		(	serial_actsum	)
		,	.q_out			(	qz_m0_dout		)
		,	.valid_out		(	qz_m0_valid		)
	);

	// FFN1: I-BERT i-GELU + requantize (bit-exact to tools/FFN1_igelu_out.dat)
	FFN_quan2uint8_gelu q0_gelu(
			.clk ( clk )
		,	.reset 	( reset )
		,	.z_of_weight	(	cfg_z_of_weight		)
		,	.valid_in		(	serial_valid	)
		,	.serial32_in	(	serial_conv		)
		,	.act_sum_in		(	serial_actsum	)
		,	.q_out			(	qz_gelu_dout	)
		,	.valid_out		(	qz_gelu_valid	)
	);

	assign q_result_dout = cfg_gelu_en ? qz_gelu_dout  : qz_m0_dout  ;
	assign valid_dout    = cfg_gelu_en ? qz_gelu_valid : qz_m0_valid ;
	
	FFN_getpe_result #(
			.INV_BITS(	1 	) 	// input valid bits
		,	.OUTQ_BITS(	32 	) 	// output bits for quantization
		,	.NUM_PE(	PEBLKCOL_NUM	)
	)gr00(
			.clk ( clk )
		,	.reset ( reset )
		,	.pe_result_flat		(	pe_result_flat	)
		,	.pe_actsum_flat		(	pe_actsum_flat	)
		,	.valid_out 			(	serial_valid	)
		,	.serial_result 		(	serial_conv		)
		,	.serial_actresult 	(	serial_actsum	)
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
	)pe_col0(
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
			)pe_col1(
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