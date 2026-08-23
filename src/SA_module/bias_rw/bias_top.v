// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2022.11.20
// Ver      : 1.0
// Func     : kernel sram read module
// 			after all kernel and activation compute done 
// 			both read&write module will IDLE and busy="0"
// Log		: big endian just for u8 data in SDK, but bias is u64 data in SDK.
//			so transform again.
// ============================================================================
// ============================================================================
//		2022.12.03 check
//      Verilog model for Synchronous Single-Port Ram
//
//      Instance Name:              BIAS_SRAM
//      Words:                      512
//      Bits:                       32
//      Mux:                        8
//      Drive:                      6
//      Write Mask:                 Off
//      Extra Margin Adjustment:    On
//      Accelerated Retention Test: Off
//      Redundant Rows:             0
//      Redundant Columns:          0
//      Test Muxes                  Off
// ============================================================================
`ifndef ASIC
`define FPGA_SRAM_SETTING	// FPGA (Vivado BRAM) path ; build with +define+ASIC to use the N16 SRAM macros in sram.v
`endif
`define	BIG_ENDIAN



module bias_top 
#(
	parameter	BUF_TAG_BITS		= 8
	,	BIAS_WORD_LENGTH	= 32
	,	BIAS_ADDR_BITS		= 9
)(

	clk
	,	reset

	,	if_r_state
	,	rdwd_done

	,	bias_write_data_din		
	,	bias_write_empty_n_din	
	,	bias_write_read_dout	

	,	bias_write_en 		
	,	bias_write_done 		
	,	bias_write_busy 		
	,	start_bias_write		

	,	bias_read_done 		
	,	bias_read_busy 		
	,	start_bias_read		



// ====		replace bias reg		====
	,	bias_reg_curr_0		
	,	bias_reg_curr_1		
	,	bias_reg_curr_2		
	,	bias_reg_curr_3		
	,	bias_reg_curr_4		
	,	bias_reg_curr_5		
	,	bias_reg_curr_6		
	,	bias_reg_curr_7		

	,	bias_reg_next_0		
	,	bias_reg_next_1		
	,	bias_reg_next_2		
	,	bias_reg_next_3		
	,	bias_reg_next_4		
	,	bias_reg_next_5		
	,	bias_reg_next_6		
	,	bias_reg_next_7		
// ====		Tag of bias reg		====
	,	tag_bias_curr_0		
	,	tag_bias_curr_1		
	,	tag_bias_curr_2		
	,	tag_bias_curr_3		
	,	tag_bias_curr_4		
	,	tag_bias_curr_5		
	,	tag_bias_curr_6		
	,	tag_bias_curr_7		

	,	tag_bias_next_0		
	,	tag_bias_next_1		
	,	tag_bias_next_2		
	,	tag_bias_next_3		
	,	tag_bias_next_4		
	,	tag_bias_next_5		
	,	tag_bias_next_6		
	,	tag_bias_next_7		


	,	tst_cp_ker_num		
	,	tst_ker_read_done		
	,	tst_en_buf_sw		
	
	,	cfg_bir_rg_prep			
	,	cfg_biw_lengthsub1		
	,	cfg_kernum_sub1
);
// ====			declare parameter		====
// localparam BUF_TAG_BITS = 8;
// localparam BIAS_WORD_LENGTH = 32;
// localparam BIAS_ADDR_BITS = 9;


//-------------		I/O		----------------------
	input wire clk ;
	input wire reset ;


	input wire [ 63 : 0 ] bias_write_data_din	;
	input wire [2:0]	if_r_state	;
	input wire			rdwd_done	;
	
	input wire		bias_write_empty_n_din	;
	output wire		bias_write_read_dout		;

	output wire 		bias_write_en 			;
	output wire 		bias_write_done 		;
	output wire 		bias_write_busy 		;
	input wire 		start_bias_write		;

	output wire 	bias_read_done 		;
	output wire 	bias_read_busy 		;
	input wire 		start_bias_read		;


//----ker w test input declare start------ 
    // input wire tst_sram_rw ;	// scheduler control 
    input wire [BUF_TAG_BITS-1:0] tst_cp_ker_num ;	// testbench simulate ker_r module
    input wire 	tst_ker_read_done ;	// testbench simulate ker_r module
    input wire 	tst_en_buf_sw ;	// testbench simulate ker_r module



// ====		replace bias reg		====
	output wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_curr_0	;
	output wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_curr_1	;
	output wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_curr_2	;
	output wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_curr_3	;
	output wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_curr_4	;
	output wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_curr_5	;
	output wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_curr_6	;
	output wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_curr_7	;

	output wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_next_0	;
	output wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_next_1	;
	output wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_next_2	;
	output wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_next_3	;
	output wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_next_4	;
	output wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_next_5	;
	output wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_next_6	;
	output wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_next_7	;
// ====		Tag of bias reg		====
	output wire [BUF_TAG_BITS-1 : 0 ] tag_bias_curr_0	;
	output wire [BUF_TAG_BITS-1 : 0 ] tag_bias_curr_1	;
	output wire [BUF_TAG_BITS-1 : 0 ] tag_bias_curr_2	;
	output wire [BUF_TAG_BITS-1 : 0 ] tag_bias_curr_3	;
	output wire [BUF_TAG_BITS-1 : 0 ] tag_bias_curr_4	;
	output wire [BUF_TAG_BITS-1 : 0 ] tag_bias_curr_5	;
	output wire [BUF_TAG_BITS-1 : 0 ] tag_bias_curr_6	;
	output wire [BUF_TAG_BITS-1 : 0 ] tag_bias_curr_7	;

	output wire [BUF_TAG_BITS-1 : 0 ] tag_bias_next_0	;
	output wire [BUF_TAG_BITS-1 : 0 ] tag_bias_next_1	;
	output wire [BUF_TAG_BITS-1 : 0 ] tag_bias_next_2	;
	output wire [BUF_TAG_BITS-1 : 0 ] tag_bias_next_3	;
	output wire [BUF_TAG_BITS-1 : 0 ] tag_bias_next_4	;
	output wire [BUF_TAG_BITS-1 : 0 ] tag_bias_next_5	;
	output wire [BUF_TAG_BITS-1 : 0 ] tag_bias_next_6	;
	output wire [BUF_TAG_BITS-1 : 0 ] tag_bias_next_7	;

	input wire	[BIAS_ADDR_BITS-1:0]	cfg_bir_rg_prep		;
	input wire	[BIAS_ADDR_BITS-1:0]	cfg_biw_lengthsub1	;
	input wire	[BUF_TAG_BITS-1:0]  	cfg_kernum_sub1		;

//==============================================================================
//========    config declare    ========
//==============================================================================
//----    bias read config    -----
// wire [BIAS_ADDR_BITS-1:0]	cfg_bir_rg_prep	;

reg [BUF_TAG_BITS-1:0]		rcfg_kernum_sub1	;
reg [BIAS_ADDR_BITS-1:0]	rcfg_bir_rg_prep	;
reg [BIAS_ADDR_BITS-1:0]	rcfg_biw_lengthsub1	;
//----    bias write config    -----


//----    rd first time read bias for curr and next buffer    -----
wire bias_rd1st_start ;
wire bias_rd1st_done ;
wire bias_rd1st_busy ;
//-----------------------------------------------------------------------------



//-----------------------------------------------------------------------------
//----generated by bias_top_mod.py------ 
//---- bias top declare BIAS_SRAM start------ 
wire cen_biassr_0 ; 
wire wen_biassr_0 ; 
wire [ BIAS_ADDR_BITS -1 : 0 ] addr_biassr_0 ; 
wire [ BIAS_WORD_LENGTH -1 : 0 ] din_biassr_0 ; 
wire [ BIAS_WORD_LENGTH -1 : 0 ] dout_biassr_0 ; 
//---- bias top declare BIAS_SRAM end------ 

//----declare bias_top sram read signal start------ 
wire bsr_cen_biassr_0 ; 
wire bsr_wen_biassr_0 ; 
wire [ BIAS_ADDR_BITS -1 : 0 ] bsr_addr_biassr_0 ; 
//----declare bias_top sram read signal  end------ 

//----declare bias_top sram write signal start------ 
wire bsw_cen_biassr_0 ; 
wire bsw_wen_biassr_0 ; 
wire [ BIAS_ADDR_BITS -1 : 0 ] bsw_addr_biassr_0 ; 
wire [ BIAS_WORD_LENGTH -1 : 0 ] bsw_din_biassr_0 ; 
//----declare bias_top sram write signal  end------ 

//----    actually cen wen signal declare    -----
wire	atl_cen_biassr_0	;	// for actually connection between FPGA and CBDK
wire	atl_wen_biassr_0	;	// for actually connection between FPGA and CBDK

//----    bias endian data in    -----
wire [ 63 : 0 ] endian_data_in	;



assign cen_biassr_0 = 	( bias_write_busy )?  (bias_rd1st_busy) ? bsr_cen_biassr_0		: bsw_cen_biassr_0		:  bsr_cen_biassr_0			;
assign wen_biassr_0 =	( bias_write_busy )?  (bias_rd1st_busy) ? bsr_wen_biassr_0		: bsw_wen_biassr_0		:  bsr_wen_biassr_0			;
assign addr_biassr_0 =	( bias_write_busy )?  (bias_rd1st_busy) ? bsr_addr_biassr_0		: bsw_addr_biassr_0		:  bsr_addr_biassr_0		;
assign din_biassr_0 =	( bias_write_busy )?   bsw_din_biassr_0		: 32'd0 ;



// //----    actually cen wen signal declare    -----
// wire	atl_cen_biassr_0	;	// for actually connection between FPGA and CBDK
// wire	atl_wen_biassr_0	;	// for actually connection between FPGA and CBDK
//==============================================================================
//========    SRAM instance and assignment    ========
//==============================================================================

`ifdef FPGA_SRAM_SETTING
	assign atl_cen_biassr_0 = ~cen_biassr_0	;
	assign atl_wen_biassr_0 = ~wen_biassr_0	;
`else 
	assign atl_cen_biassr_0 = cen_biassr_0	;
	assign atl_wen_biassr_0 = wen_biassr_0	;
`endif 


`ifdef FPGA_SRAM_SETTING
	BRAM_BIAS bias_0 ( .clka( clk ) ,.ena( atl_cen_biassr_0 )	,.wea( atl_wen_biassr_0 )	,.addra( addr_biassr_0 ),.dina( din_biassr_0 )	,.douta( dout_biassr_0 ) );
`else 
	BIAS_SRAM bias_0(.Q(	dout_biassr_0 ),	.CLK( clk ),.CEN( cen_biassr_0 ),.WEN( wen_biassr_0 ),.A( addr_biassr_0 ),.D( din_biassr_0 ),.EMA( 3'b0 ));
`endif 
//-----------------------------------------------------------------------------





`ifdef BIG_ENDIAN
	assign endian_data_in	= { bias_write_data_din[ 7 :  0], 
								bias_write_data_din[15 :  8],
								bias_write_data_din[23 : 16],
								bias_write_data_din[31 : 24],
								bias_write_data_din[39 : 32],
								bias_write_data_din[47 : 40],
								bias_write_data_din[55 : 48],
								bias_write_data_din[63 : 56]
							};
                          

`else
	assign endian_data_in      = bias_write_data_din;

`endif


//-------------------------------------------------------------------
//----------------		kernel sram write module		-------------
//-------------------------------------------------------------------

biassram_w  #(    .ADDR_CNT_BITS(	BIAS_ADDR_BITS 	)     

    )bias_write01(
	.clk	(	clk		)
	,	.reset	(	reset	)

//----bias_top write module sram signal instanse------ 
    ,	.cen_biasr_0	( bsw_cen_biassr_0		)
    ,	.wen_biasr_0	( bsw_wen_biassr_0		)
    ,	.addr_biasr_0	( bsw_addr_biassr_0		)
    ,	.din_biasr_0	( bsw_din_biassr_0		)
//----bias_top write module sram signal instanse end------ 


	,	.bias_write_data_din	(	endian_data_in		)
	,	.bias_write_empty_n_din	(	bias_write_empty_n_din	)
	,	.bias_write_read_dout	(	bias_write_read_dout	)

	,	.bias_rd1st_start 		(	bias_rd1st_start	)	// read first bias value to reg buffer
	,	.bias_rd1st_busy 		(	bias_rd1st_busy		)	// read first bias value to reg buffer
	,	.bias_rd1st_done 		(	bias_rd1st_done		)	// read first bias value to reg buffer

	,	.bias_write_en 			(	bias_write_en 		)
	,	.bias_write_done 		(	bias_write_done 	)
	,	.bias_write_busy 		(	bias_write_busy 	)
	,	.start_bias_write		(	start_bias_write	)

	,	.cfg_biw_lengthsub1		(	rcfg_biw_lengthsub1	)
	
);

//-------------------------------------------------------------------
//----------------		kernel sram read module		-------------
//-------------------------------------------------------------------

biassram_r  #(    .ADDR_CNT_BITS(	BIAS_ADDR_BITS 	)     
	,	.BUF_TAG_BITS		(	BUF_TAG_BITS		)
	,	.BIAS_WORD_LENGTH	(	BIAS_WORD_LENGTH	)
    )bias_read01(
	.clk	(	clk		)
	,.reset	(	reset	)
	,.if_r_state(if_r_state)
	,.rdwd_done(rdwd_done)

	,.cen_biasr_0	(	bsr_cen_biassr_0	)	
	,.wen_biasr_0	(	bsr_wen_biassr_0	)
	,.addr_biasr_0	(	bsr_addr_biassr_0	)
	,.dout_biasr_0	(	dout_biassr_0	)

	,.cp_ker_num		(	tst_cp_ker_num	)		// testbench simulate ker_r module
	,.ker_read_done	(	tst_ker_read_done	)		// testbench simulate ker_r module
	,.en_buf_sw		(	tst_en_buf_sw	)		// testbench simulate ker_r module

// ====		replace bias reg		====
	,	.bias_reg_curr_0		(		bias_reg_curr_0		)
	,	.bias_reg_curr_1		(		bias_reg_curr_1		)
	,	.bias_reg_curr_2		(		bias_reg_curr_2		)
	,	.bias_reg_curr_3		(		bias_reg_curr_3		)
	,	.bias_reg_curr_4		(		bias_reg_curr_4		)
	,	.bias_reg_curr_5		(		bias_reg_curr_5		)
	,	.bias_reg_curr_6		(		bias_reg_curr_6		)
	,	.bias_reg_curr_7		(		bias_reg_curr_7		)

	,	.bias_reg_next_0		(		bias_reg_next_0		)
	,	.bias_reg_next_1		(		bias_reg_next_1		)
	,	.bias_reg_next_2		(		bias_reg_next_2		)
	,	.bias_reg_next_3		(		bias_reg_next_3		)
	,	.bias_reg_next_4		(		bias_reg_next_4		)
	,	.bias_reg_next_5		(		bias_reg_next_5		)
	,	.bias_reg_next_6		(		bias_reg_next_6		)
	,	.bias_reg_next_7		(		bias_reg_next_7		)
// ====		Tag of bias reg	(				)	====
	,	.tag_bias_curr_0		(		tag_bias_curr_0		)
	,	.tag_bias_curr_1		(		tag_bias_curr_1		)
	,	.tag_bias_curr_2		(		tag_bias_curr_2		)
	,	.tag_bias_curr_3		(		tag_bias_curr_3		)
	,	.tag_bias_curr_4		(		tag_bias_curr_4		)
	,	.tag_bias_curr_5		(		tag_bias_curr_5		)
	,	.tag_bias_curr_6		(		tag_bias_curr_6		)
	,	.tag_bias_curr_7		(		tag_bias_curr_7		)

	,	.tag_bias_next_0		(		tag_bias_next_0		)
	,	.tag_bias_next_1		(		tag_bias_next_1		)
	,	.tag_bias_next_2		(		tag_bias_next_2		)
	,	.tag_bias_next_3		(		tag_bias_next_3		)
	,	.tag_bias_next_4		(		tag_bias_next_4		)
	,	.tag_bias_next_5		(		tag_bias_next_5		)
	,	.tag_bias_next_6		(		tag_bias_next_6		)
	,	.tag_bias_next_7		(		tag_bias_next_7		)


	,	.bias_rd1st_start 		(	bias_rd1st_start	)
	,	.bias_rd1st_busy 		(	bias_rd1st_busy		)
	,	.bias_rd1st_done 		(	bias_rd1st_done		)


	,	.bias_read_done 		(	bias_read_done 		)
	,	.bias_read_busy 		(	bias_read_busy 		)
	,	.start_bias_read		(	start_bias_read		)
	,	.cfg_bir_rg_prep		(	rcfg_bir_rg_prep		)
	,	.cfg_kernum_sub1		(	rcfg_kernum_sub1		)

);


always @(posedge clk ) begin
	if(reset)begin
		rcfg_bir_rg_prep <= 8;
		rcfg_kernum_sub1 <= 3;
		rcfg_biw_lengthsub1 <= 63;
	end
	else begin
		rcfg_bir_rg_prep 	<= cfg_bir_rg_prep		;
		rcfg_kernum_sub1 	<= cfg_kernum_sub1		;
		rcfg_biw_lengthsub1 <= cfg_biw_lengthsub1	;
	end
end


endmodule


