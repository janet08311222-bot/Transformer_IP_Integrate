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


module pe_blk64 
#(
	parameter TBITS = 64 
	,	TBYTE = 8
	,	BIAS_BITS = 32 
)(
	clk			
	,	reset	
	,	cfg_m0_scale 	
	,	cfg_index 		
	,	cfg_z_of_weight	
	,	cfg_z3			
	,	valid_din		
	,	final_din		
	,	act_din			
	,	ker_din_0		
	,	ker_din_1		
	,	ker_din_2		
	,	ker_din_3		
	,	ker_din_4		
	,	ker_din_5		
	,	ker_din_6		
	,	ker_din_7		
	,	bias_din_0		
	,	bias_din_1		
	,	bias_din_2		
	,	bias_din_3		
	,	bias_din_4		
	,	bias_din_5		
	,	bias_din_6		
	,	bias_din_7		
	,	pass_ker_dout_0			
	,	pass_ker_dout_1			
	,	pass_ker_dout_2			
	,	pass_ker_dout_3			
	,	pass_ker_dout_4			
	,	pass_ker_dout_5			
	,	pass_ker_dout_6			
	,	pass_ker_dout_7			
	,	pass_bias_dout_0		
	,	pass_bias_dout_1		
	,	pass_bias_dout_2		
	,	pass_bias_dout_3		
	,	pass_bias_dout_4		
	,	pass_bias_dout_5		
	,	pass_bias_dout_6		
	,	pass_bias_dout_7		
	,	q_result_dout			
	,	valid_dout				

);

//==============================================================================
//========    I/O Port declare    ==============================================
//==============================================================================
	input wire clk	;
	input wire reset	;
	
input wire	[ 32	-1 :0	]	cfg_m0_scale 		;
input wire	[ 8		-1 :0	]	cfg_index 			;
input wire	[ 16	-1 :0	]	cfg_z_of_weight		;
input wire	[ 8		-1 :0	]	cfg_z3				;

input wire									valid_din			;
input wire									final_din			;
input wire			[TBITS-1:0]				act_din 			;

input wire			[TBITS-1:0]			ker_din_0 , ker_din_1 , ker_din_2 , ker_din_3 , ker_din_4 , ker_din_5 , ker_din_6 , ker_din_7			;
input wire			[BIAS_BITS	-1:0]	bias_din_0 , bias_din_1 , bias_din_2 , bias_din_3 , bias_din_4 , bias_din_5 , bias_din_6 , bias_din_7	;	
output wire			[TBITS-1 : 0 ] 		pass_ker_dout_0 , pass_ker_dout_1 , pass_ker_dout_2 , pass_ker_dout_3 , pass_ker_dout_4 , pass_ker_dout_5 , pass_ker_dout_6 , pass_ker_dout_7		;
output wire signed	[BIAS_BITS-1 : 0 ] 	pass_bias_dout_0 , pass_bias_dout_1 , pass_bias_dout_2 , pass_bias_dout_3 , pass_bias_dout_4 , pass_bias_dout_5 , pass_bias_dout_6 , pass_bias_dout_7	;

output wire [8-1	:0	]	q_result_dout	;
output wire 				valid_dout		;
//-----------------------------------------------------------------------------

//----    PE input shifter    -----
reg	[TBITS-1:0]		act_shf		[0:7] 	;
reg 				valid_pe	[0:7] 	;
reg 				final_pe	[0:7] 	;
// reg	[TBITS-1:0]		ker_shf		[0:7] 	;
// reg	[32-1:0]		bi_buf		[0:7] 	;
//----    PE out connection    -----
wire q_valid[0:7]	;
wire [32-1:0]	mac_result	[0:7]	;
wire [32-1:0]	act_sum		[0:7]	;

//----    result get declare    -----
wire 			serial_valid		;
wire [32-1:0]	serial_conv		;
wire [32-1:0]	serial_actsum	;


integer i0 ;

always @(*) begin
	act_shf[0] 		= act_din ;
	valid_pe[0] 	= valid_din ;
	final_pe[0] 	= final_din ;
end
always @(posedge clk ) begin
	if(reset)begin
		for (i0 =1 ;i0<8 ;i0=i0+1 ) begin
			act_shf[i0]		<= 0 ;
			valid_pe[i0]	<= 0 ;
			final_pe[i0]	<= 0 ;
		end
	end
	else begin
		for (i0 =1 ;i0<8 ;i0=i0+1 ) begin
			act_shf[i0]		<= act_shf[i0-1]	;
			valid_pe[i0]	<= valid_pe[i0-1]	;
			final_pe[i0]	<= final_pe[i0-1]	;
		end
	end
end


quan2uint8	q0(
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


getpe_result #(
	.INV_BITS(	1 	) 		// input valid bits
	,	.OUTQ_BITS(	32 	) 	// output bits for quantization
) gr00(
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
	,	.valid_out 			(	serial_valid			)
	,	.serial_result 		(	serial_conv			)
	,	.serial_actresult 	(	serial_actsum		)

);

//==============================================================================
//========    8MAC PE instance    ========
//==============================================================================
//----instance pe generate by pe_instcode.py------ 
//----pe row0 col_0---------
pe_8e  #(    .ELE_BITS(	8 	)     ,   .OUT_BITS(	32	)     ,   .BIAS_BITS(	32	) 
    )pe_r0_col_0(.clk ( clk )  ,    .reset ( reset ) 
    , .act_0( act_shf[0][63-:8] )
    , .act_1( act_shf[0][55-:8] )
    , .act_2( act_shf[0][47-:8] )
    , .act_3( act_shf[0][39-:8] )
    , .act_4( act_shf[0][31-:8] )
    , .act_5( act_shf[0][23-:8] )
    , .act_6( act_shf[0][15-:8] )
    , .act_7( act_shf[0][ 7-:8] )
    ,  .valid_in( valid_pe[0] )
    ,  .final_in( final_pe[0] )

//---- kernel ----//
    ,  .ker_0( ker_din_0[63-:8] )
    ,  .ker_1( ker_din_0[55-:8] )
    ,  .ker_2( ker_din_0[47-:8] )
    ,  .ker_3( ker_din_0[39-:8] )
    ,  .ker_4( ker_din_0[31-:8] )
    ,  .ker_5( ker_din_0[23-:8] )
    ,  .ker_6( ker_din_0[15-:8] )
    ,  .ker_7( ker_din_0[ 7-:8] )
//---- bias ----//
    ,  .bias_in	( bias_din_0 )	
    ,  .pass_ker ( pass_ker_dout_0 )	
    ,  .pass_bias ( pass_bias_dout_0 )	
    ,  .valid_out ( q_valid[0] )	
    ,  .outmacb_sum ( mac_result[0] )	
    ,  .outact_sum ( act_sum[0] )	
    );
//----pe row0 col_1---------
pe_8e  #(    .ELE_BITS(	8 	)     ,   .OUT_BITS(	32	)     ,   .BIAS_BITS(	32	) 
    )pe_r0_col_1(.clk ( clk )  ,    .reset ( reset ) 
    , .act_0( act_shf[1][63-:8] )
    , .act_1( act_shf[1][55-:8] )
    , .act_2( act_shf[1][47-:8] )
    , .act_3( act_shf[1][39-:8] )
    , .act_4( act_shf[1][31-:8] )
    , .act_5( act_shf[1][23-:8] )
    , .act_6( act_shf[1][15-:8] )
    , .act_7( act_shf[1][ 7-:8] )
    ,  .valid_in( valid_pe[1] )
    ,  .final_in( final_pe[1] )

//---- kernel ----//
    ,  .ker_0( ker_din_1[63-:8] )
    ,  .ker_1( ker_din_1[55-:8] )
    ,  .ker_2( ker_din_1[47-:8] )
    ,  .ker_3( ker_din_1[39-:8] )
    ,  .ker_4( ker_din_1[31-:8] )
    ,  .ker_5( ker_din_1[23-:8] )
    ,  .ker_6( ker_din_1[15-:8] )
    ,  .ker_7( ker_din_1[ 7-:8] )
//---- bias ----//
    ,  .bias_in	( bias_din_1 )	
    ,  .pass_ker ( pass_ker_dout_1 )	
    ,  .pass_bias ( pass_bias_dout_1 )	
    ,  .valid_out ( q_valid[1] )	
    ,  .outmacb_sum ( mac_result[1] )	
    ,  .outact_sum ( act_sum[1] )	
    );
//----pe row0 col_2---------
pe_8e  #(    .ELE_BITS(	8 	)     ,   .OUT_BITS(	32	)     ,   .BIAS_BITS(	32	) 
    )pe_r0_col_2(.clk ( clk )  ,    .reset ( reset ) 
    , .act_0( act_shf[2][63-:8] )
    , .act_1( act_shf[2][55-:8] )
    , .act_2( act_shf[2][47-:8] )
    , .act_3( act_shf[2][39-:8] )
    , .act_4( act_shf[2][31-:8] )
    , .act_5( act_shf[2][23-:8] )
    , .act_6( act_shf[2][15-:8] )
    , .act_7( act_shf[2][ 7-:8] )
    ,  .valid_in( valid_pe[2] )
    ,  .final_in( final_pe[2] )

//---- kernel ----//
    ,  .ker_0( ker_din_2[63-:8] )
    ,  .ker_1( ker_din_2[55-:8] )
    ,  .ker_2( ker_din_2[47-:8] )
    ,  .ker_3( ker_din_2[39-:8] )
    ,  .ker_4( ker_din_2[31-:8] )
    ,  .ker_5( ker_din_2[23-:8] )
    ,  .ker_6( ker_din_2[15-:8] )
    ,  .ker_7( ker_din_2[ 7-:8] )
//---- bias ----//
    ,  .bias_in	( bias_din_2 )	
    ,  .pass_ker ( pass_ker_dout_2 )	
    ,  .pass_bias ( pass_bias_dout_2 )	
    ,  .valid_out ( q_valid[2] )	
    ,  .outmacb_sum ( mac_result[2] )	
    ,  .outact_sum ( act_sum[2] )	
    );
//----pe row0 col_3---------
pe_8e  #(    .ELE_BITS(	8 	)     ,   .OUT_BITS(	32	)     ,   .BIAS_BITS(	32	) 
    )pe_r0_col_3(.clk ( clk )  ,    .reset ( reset ) 
    , .act_0( act_shf[3][63-:8] )
    , .act_1( act_shf[3][55-:8] )
    , .act_2( act_shf[3][47-:8] )
    , .act_3( act_shf[3][39-:8] )
    , .act_4( act_shf[3][31-:8] )
    , .act_5( act_shf[3][23-:8] )
    , .act_6( act_shf[3][15-:8] )
    , .act_7( act_shf[3][ 7-:8] )
    ,  .valid_in( valid_pe[3] )
    ,  .final_in( final_pe[3] )

//---- kernel ----//
    ,  .ker_0( ker_din_3[63-:8] )
    ,  .ker_1( ker_din_3[55-:8] )
    ,  .ker_2( ker_din_3[47-:8] )
    ,  .ker_3( ker_din_3[39-:8] )
    ,  .ker_4( ker_din_3[31-:8] )
    ,  .ker_5( ker_din_3[23-:8] )
    ,  .ker_6( ker_din_3[15-:8] )
    ,  .ker_7( ker_din_3[ 7-:8] )
//---- bias ----//
    ,  .bias_in	( bias_din_3 )	
    ,  .pass_ker ( pass_ker_dout_3 )	
    ,  .pass_bias ( pass_bias_dout_3 )	
    ,  .valid_out ( q_valid[3] )	
    ,  .outmacb_sum ( mac_result[3] )	
    ,  .outact_sum ( act_sum[3] )	
    );
//----pe row0 col_4---------
pe_8e  #(    .ELE_BITS(	8 	)     ,   .OUT_BITS(	32	)     ,   .BIAS_BITS(	32	) 
    )pe_r0_col_4(.clk ( clk )  ,    .reset ( reset ) 
    , .act_0( act_shf[4][63-:8] )
    , .act_1( act_shf[4][55-:8] )
    , .act_2( act_shf[4][47-:8] )
    , .act_3( act_shf[4][39-:8] )
    , .act_4( act_shf[4][31-:8] )
    , .act_5( act_shf[4][23-:8] )
    , .act_6( act_shf[4][15-:8] )
    , .act_7( act_shf[4][ 7-:8] )
    ,  .valid_in( valid_pe[4] )
    ,  .final_in( final_pe[4] )

//---- kernel ----//
    ,  .ker_0( ker_din_4[63-:8] )
    ,  .ker_1( ker_din_4[55-:8] )
    ,  .ker_2( ker_din_4[47-:8] )
    ,  .ker_3( ker_din_4[39-:8] )
    ,  .ker_4( ker_din_4[31-:8] )
    ,  .ker_5( ker_din_4[23-:8] )
    ,  .ker_6( ker_din_4[15-:8] )
    ,  .ker_7( ker_din_4[ 7-:8] )
//---- bias ----//
    ,  .bias_in	( bias_din_4 )	
    ,  .pass_ker ( pass_ker_dout_4 )	
    ,  .pass_bias ( pass_bias_dout_4 )	
    ,  .valid_out ( q_valid[4] )	
    ,  .outmacb_sum ( mac_result[4] )	
    ,  .outact_sum ( act_sum[4] )	
    );
//----pe row0 col_5---------
pe_8e  #(    .ELE_BITS(	8 	)     ,   .OUT_BITS(	32	)     ,   .BIAS_BITS(	32	) 
    )pe_r0_col_5(.clk ( clk )  ,    .reset ( reset ) 
    , .act_0( act_shf[5][63-:8] )
    , .act_1( act_shf[5][55-:8] )
    , .act_2( act_shf[5][47-:8] )
    , .act_3( act_shf[5][39-:8] )
    , .act_4( act_shf[5][31-:8] )
    , .act_5( act_shf[5][23-:8] )
    , .act_6( act_shf[5][15-:8] )
    , .act_7( act_shf[5][ 7-:8] )
    ,  .valid_in( valid_pe[5] )
    ,  .final_in( final_pe[5] )

//---- kernel ----//
    ,  .ker_0( ker_din_5[63-:8] )
    ,  .ker_1( ker_din_5[55-:8] )
    ,  .ker_2( ker_din_5[47-:8] )
    ,  .ker_3( ker_din_5[39-:8] )
    ,  .ker_4( ker_din_5[31-:8] )
    ,  .ker_5( ker_din_5[23-:8] )
    ,  .ker_6( ker_din_5[15-:8] )
    ,  .ker_7( ker_din_5[ 7-:8] )
//---- bias ----//
    ,  .bias_in	( bias_din_5 )	
    ,  .pass_ker ( pass_ker_dout_5 )	
    ,  .pass_bias ( pass_bias_dout_5 )	
    ,  .valid_out ( q_valid[5] )	
    ,  .outmacb_sum ( mac_result[5] )	
    ,  .outact_sum ( act_sum[5] )	
    );
//----pe row0 col_6---------
pe_8e  #(    .ELE_BITS(	8 	)     ,   .OUT_BITS(	32	)     ,   .BIAS_BITS(	32	) 
    )pe_r0_col_6(.clk ( clk )  ,    .reset ( reset ) 
    , .act_0( act_shf[6][63-:8] )
    , .act_1( act_shf[6][55-:8] )
    , .act_2( act_shf[6][47-:8] )
    , .act_3( act_shf[6][39-:8] )
    , .act_4( act_shf[6][31-:8] )
    , .act_5( act_shf[6][23-:8] )
    , .act_6( act_shf[6][15-:8] )
    , .act_7( act_shf[6][ 7-:8] )
    ,  .valid_in( valid_pe[6] )
    ,  .final_in( final_pe[6] )

//---- kernel ----//
    ,  .ker_0( ker_din_6[63-:8] )
    ,  .ker_1( ker_din_6[55-:8] )
    ,  .ker_2( ker_din_6[47-:8] )
    ,  .ker_3( ker_din_6[39-:8] )
    ,  .ker_4( ker_din_6[31-:8] )
    ,  .ker_5( ker_din_6[23-:8] )
    ,  .ker_6( ker_din_6[15-:8] )
    ,  .ker_7( ker_din_6[ 7-:8] )
//---- bias ----//
    ,  .bias_in	( bias_din_6 )	
    ,  .pass_ker ( pass_ker_dout_6 )	
    ,  .pass_bias ( pass_bias_dout_6 )	
    ,  .valid_out ( q_valid[6] )	
    ,  .outmacb_sum ( mac_result[6] )	
    ,  .outact_sum ( act_sum[6] )	
    );
//----pe row0 col_7---------
pe_8e  #(    .ELE_BITS(	8 	)     ,   .OUT_BITS(	32	)     ,   .BIAS_BITS(	32	) 
    )pe_r0_col_7(.clk ( clk )  ,    .reset ( reset ) 
    , .act_0( act_shf[7][63-:8] )
    , .act_1( act_shf[7][55-:8] )
    , .act_2( act_shf[7][47-:8] )
    , .act_3( act_shf[7][39-:8] )
    , .act_4( act_shf[7][31-:8] )
    , .act_5( act_shf[7][23-:8] )
    , .act_6( act_shf[7][15-:8] )
    , .act_7( act_shf[7][ 7-:8] )
    ,  .valid_in( valid_pe[7] )
    ,  .final_in( final_pe[7] )

//---- kernel ----//
    ,  .ker_0( ker_din_7[63-:8] )
    ,  .ker_1( ker_din_7[55-:8] )
    ,  .ker_2( ker_din_7[47-:8] )
    ,  .ker_3( ker_din_7[39-:8] )
    ,  .ker_4( ker_din_7[31-:8] )
    ,  .ker_5( ker_din_7[23-:8] )
    ,  .ker_6( ker_din_7[15-:8] )
    ,  .ker_7( ker_din_7[ 7-:8] )
//---- bias ----//
    ,  .bias_in	( bias_din_7 )	
    ,  .pass_ker ( pass_ker_dout_7 )	
    ,  .pass_bias ( pass_bias_dout_7 )	
    ,  .valid_out ( q_valid[7] )	
    ,  .outmacb_sum ( mac_result[7] )	
    ,  .outact_sum ( act_sum[7] )	
    );
//----instance pe with bias end------ 


//-----------------------------------------------------------------------------





endmodule
