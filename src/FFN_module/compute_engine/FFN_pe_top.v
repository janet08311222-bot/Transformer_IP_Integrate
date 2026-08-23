// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2023.03.03
// Ver      : 1.0
// Func     : 256MACs PE top with all 64MAC blocks
//			pass {ker,bias} by reg here 
// ============================================================================

// ============================================================================================================
// Designer : Chao-Ping Liu
// Create   : 2025.06.24
// Ver      : 1.0
// Func     : PE top with one pe row total 64MAC
//                      |--- ---- ---- ---- ---- ---- ---- ---|
//                      |--- ---- ---- PE array ---- ---- ----|
//                      |-- ---- ---- ---- ---- ---- ---- ----|
// ============================================================================================================
// `define FPGA_SETTING
// `define FPGA_ILA_CHK_SETTING

`ifdef FPGA_SRAM_SETTING
(* use_dsp = "yes" *)
`else

`endif

module FFN_pe_top #(
    parameter TBITS = 64
    ,	TBYTE = 8
    ,	PEBLKROW_NUM = 1
    ,   PEBLKCOL_NUM = 8
)(
        clk
    ,	reset

    ,	cfg_m0_scale
    ,	cfg_index
    ,	cfg_z_of_weight
    ,	cfg_z3

    ,	flat_act_din
    ,	flat_ker_din
    ,	flat_bias_din
    ,	flat_valid_din
    ,	flat_final_din

    ,	allq_dout
    ,	allvalid_dout


`ifdef FPGA_ILA_CHK_SETTING

`endif

);
    localparam BIAS_BITS = 32;
    
    //==============================================================================
    //========    I/O Port declare    ==============================================
    //==============================================================================
    
    input wire clk	    ;
    input wire reset	;
    
    input wire	[ 32	-1: 0]	cfg_m0_scale 		;
    input wire	[ 8		-1: 0]	cfg_index 			;
    input wire	[ 16	-1: 0]	cfg_z_of_weight		;
    input wire	[ 8		-1: 0]	cfg_z3				;
    
    input wire	[PEBLKROW_NUM * TBITS-1: 0]	        flat_act_din		;
    input wire  [PEBLKCOL_NUM * TBITS-1: 0]	        flat_ker_din		;
    input wire	[PEBLKCOL_NUM * BIAS_BITS-1: 0]		flat_bias_din		;
    input wire	[PEBLKROW_NUM-1: 0]			        flat_valid_din		;
    input wire	[PEBLKROW_NUM-1: 0]			        flat_final_din		;
    
    output wire [PEBLKROW_NUM * TBITS-1: 0]	allq_dout		;
    output wire	[PEBLKROW_NUM-1: 0]	        allvalid_dout	;
    //-----------------------------------------------------------------------------
    
    ///////////////////////////////////////////////////
    `ifdef FPGA_ILA_CHK_SETTING
    
    `endif 
    ///////////////////////////////////////////////////
    
    wire				        valid_din_r	[0:PEBLKROW_NUM-1]	;
    wire				        final_din_r	[0:PEBLKROW_NUM-1]	;
    wire	[TBITS-1:0]	        act_din_r 	[0:PEBLKROW_NUM-1]	;
    
    wire    [PEBLKCOL_NUM * TBITS-1: 0]	        pass_flat_ker	[0:PEBLKROW_NUM-1]	;
    wire    [PEBLKCOL_NUM * BIAS_BITS-1: 0]		pass_flat_bias	[0:PEBLKROW_NUM-1]	;
    
    wire	[8-1:0]		q_result	[0:PEBLKROW_NUM-1]	;
    wire				q_valid		[0:PEBLKROW_NUM-1]	;
    
    wire    [TBITS-1:0]	pkg64_result	[0:PEBLKROW_NUM-1]	;
    wire				pkg64_valid		[0:PEBLKROW_NUM-1]	;
    
    reg [32	-1:0]	rcfg_m0_scale 		;
    reg [8	-1:0]	rcfg_index 			;
    reg [16	-1:0]	rcfg_z_of_weight	;
    reg [8	-1:0]	rcfg_z3				;
    
    always @(posedge clk ) begin
    	if(reset)begin
    		rcfg_m0_scale 		<= 32'h4c138271	;
    		rcfg_index 			<= 8'd7	        ;
    		rcfg_z_of_weight	<= 16'd158	    ;
    		rcfg_z3				<= 8'd0	        ;
    	end
    	else begin
    		rcfg_m0_scale 		<= cfg_m0_scale 	;
    		rcfg_index 			<= cfg_index 		;
    		rcfg_z_of_weight	<= cfg_z_of_weight	;
    		rcfg_z3				<= cfg_z3			;
    	end
    end
    
    genvar i0 ;
    generate
    	for (i0 = 0; i0<PEBLKROW_NUM; i0=i0+1) begin		
    		assign valid_din_r[i0] = flat_valid_din[ (PEBLKROW_NUM-i0-1) -: 1];
    		assign final_din_r[i0] = flat_final_din[ (PEBLKROW_NUM-i0-1) -: 1];
    		assign act_din_r[i0] = flat_act_din[(TBITS*(PEBLKROW_NUM-i0)-1) -: TBITS];
    
    		assign allq_dout[(TBITS*(PEBLKROW_NUM-i0)-1) -: TBITS] = pkg64_result[i0]	;
    		assign allvalid_dout[((PEBLKROW_NUM-i0)-1) -: 1] = pkg64_valid[i0]	;
    	end
    endgenerate
    
    //----    quan to buffer module instance    -----
    genvar gx ;
    generate
    	for(gx=0; gx< PEBLKROW_NUM; gx=gx+1)begin	: inst_pkg
    		FFN_pe_qz_pkg #(
    			    .TBITS(	TBITS 	)
                ,   .TBYTE(	TBYTE	)
    		)FFN_pk_0 (
    			    .clk    ( clk   )  
    			,	.reset  ( reset ) 
    			,	.data8_din		(	q_result[gx]		)
    			,	.valid8_din 	(	q_valid[gx]		    )
    			,	.data64_dout	(	pkg64_result[gx]	)
    			,	.valid64_dout	(	pkg64_valid	[gx]	)
    		);
    	end
    endgenerate
    
    //==============================================================================
    //========    instance 64 MAC by PE_array    ===================================
    //==============================================================================
    FFN_pe_array #(
            .TBITS          (	TBITS 	        )
        ,   .TBYTE          (	TBYTE	        )     
        ,   .BIAS_BITS      (	BIAS_BITS	    ) 
        ,   .PEBLKCOL_NUM   (   PEBLKCOL_NUM    )
    )FFN_blkpe_r0(
            .clk    ( clk   )  
    	,	.reset  ( reset )	
    
        ,   .cfg_m0_scale 		( rcfg_m0_scale     )
        ,   .cfg_index 		    ( rcfg_index 		)
        ,   .cfg_z_of_weight	( rcfg_z_of_weight	)
        ,   .cfg_z3			    ( rcfg_z3			)
    
        ,   .valid_din			( valid_din_r[0]	)
        ,   .final_din			( final_din_r[0]	)
    
        ,   .input_data			( act_din_r[0]	    )
        ,   .array_ker_din	    ( flat_ker_din      )
        ,   .array_bias_din     ( flat_bias_din     )
        
        ,   .pass_array_ker_dout  ( pass_flat_ker[0]	)
        ,   .pass_array_bias_dout ( pass_flat_bias[0]	)
    
        ,   .q_result_dout	( q_result[0]		 )
        ,   .valid_dout		( q_valid[0]		 )
    );
    
    genvar pi ;
    generate
    	for(pi=1; pi<PEBLKROW_NUM; pi=pi+1) begin	: array64pe_inst
    		FFN_pe_array #(
                    .TBITS          (	TBITS 	        )
                ,   .TBYTE          (	TBYTE	        )     
                ,   .BIAS_BITS      (	BIAS_BITS	    ) 
                ,   .PEBLKCOL_NUM   (   PEBLKCOL_NUM    )
    		)FFN_arraype_r1(
                    .clk    ( clk   )  
                ,	.reset  ( reset )	
    
                ,   .cfg_m0_scale 		( rcfg_m0_scale     )
                ,   .cfg_index 		    ( rcfg_index 		)
                ,   .cfg_z_of_weight	( rcfg_z_of_weight	)
                ,   .cfg_z3			    ( rcfg_z3			)
    
                ,   .valid_din			( valid_din_r[pi]	)
                ,   .final_din			( final_din_r[pi]	)
    
                ,   .input_data			( act_din_r[pi]	            )
                ,   .array_ker_din	    ( pass_flat_ker[pi-1]       )
                ,   .array_bias_din     ( pass_flat_bias[pi-1]      )
                
                ,   .pass_array_ker_dout  ( pass_flat_ker[pi]	    )
                ,   .pass_array_bias_dout ( pass_flat_bias[pi]	    )
    
                ,   .q_result_dout	( q_result[pi]		 )
                ,   .valid_dout		( q_valid[pi]		 )
    		);
    	end
    endgenerate

endmodule
