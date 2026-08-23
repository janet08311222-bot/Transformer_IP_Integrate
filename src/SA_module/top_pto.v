// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2022.01.30
// Ver      : 1.0
// Func     : DLA_512MAC top module 
//  	----parameter reset active low -- https://youtu.be/KyQuVydW1n8
//  	----high fanout pin fixed by DC synthesis, do not code buffer.
//  	----get_ins module : distinguish data or instruction for this time.
//  	----signal port naming : should not use common port name for every top module port naming.
//  	----output signal tips : should not use output signal for flow controlling like "busy".
// Log		: 
// 		2023.03.02-- pe to output module integrate start
// 		2023.04.12-- New kernel config, cfg_mast_state replace mast_fsm_state
// 		2023.04.26-- New assignment signal endian_data_in deal with zcu102 data Endianness
//					 move quantization config to instruction input
// 		2023.04.26-- change reset to negative reset 
// 		2023.08.07-- add ila check setting
// ============================================================================
//`include "./defparm.v"
//----    define for testing    -----
//`define FPGA_SRAM_SETTING
`define LEFT_3CP
`define FPGA_ILA_CHK_SETTING
// `define LEFT_5CP
// `define RIGH_3CP
// `define RIGH_5CP
`define BIG_ENDIAN



module dla512_top #(
		parameter TBITS = 64	
	,	parameter TBYTE = 8		

)
(	clk	
	,	resetn	
	,	isif_data_dout	
	,	isif_strb_dout	
	,	isif_last_dout	
	,	isif_user_dout	
	,	isif_empty_n	
	,	osif_full_n 
	,	M_AXIS_S2MM_TREADY

	,	isif_read	
	,	osif_data_din 		
	,	osif_last_din 		
	,	osif_write 
	,	rdwd_done		

	`ifdef FPGA_ILA_CHK_SETTING

	`endif

);


localparam KER_ADDR_CNT_BITS	 =	12	 ;  //20250706 ??�改計畫範�??+
localparam STARTER_BITS			 =	8	 ;
localparam PADLEN_BITS			 =	8	 ;
localparam BUF_TAG_BITS 		 =	8	 ;

localparam PEBLKROW_NUM			 =	8	 ;	// PE block number //20250706 ??�改計畫範�??+

localparam CNTSTP_WIDTH			 = 	3	 ; 	//config input setting
localparam IFWSTG0_CNTBITS		 = 	8	 ;	//config input setting
localparam IFWSTG1_CNTBITS		 = 	7	 ;	//config input setting
localparam DATAIN_CNT_BITS		 = 	16	 ;	//config input setting

localparam OTSRAM_ADDR_BITS		 = 12 	 ;			
localparam OTSRAM_DATA_BITS		 = TBITS ;
localparam IFMAP_SRAM_ADDBITS	 = 10  	 ;
localparam IFMAP_SRAM_DATA_WIDTH = 64	 ;
localparam BIAS_WORD_LENGTH 	 = 32	 ;
localparam BIAS_ADDR_BITS 		 = 9	 ;

parameter RESET_ACTIVE_LOW 		 = 1	 ;
wire ap_rst;


//==============================================================================
//========    I/O port declare    ========
//==============================================================================

	input wire clk	;
	input wire resetn	;

	input wire [TBITS-1:0] isif_data_dout	;
	input wire [TBYTE-1:0] isif_strb_dout	;
	input wire [1-1:0]     isif_last_dout	;
	input wire [1-1:0]     isif_user_dout	;
	input wire     		   isif_empty_n		;
	output wire  		   isif_read		;
	output wire [TBITS-1:0]		   osif_data_din 	;	
	output wire [1-1:0]		   	   osif_last_din 	;
	input wire 					   osif_full_n		;		
	output wire [1-1:0]    		   osif_write 		;	
	
	
	input  wire             M_AXIS_S2MM_TREADY	;
	output wire				rdwd_done			;

	`ifdef FPGA_ILA_CHK_SETTING

	`endif



	wire [TBITS-1:0]dout_ke_0 , dout_ke_1 , dout_ke_2 , dout_ke_3 , dout_ke_4 , dout_ke_5 , dout_ke_6 , dout_ke_7 ;
	wire [BIAS_WORD_LENGTH-1:0]dout_bi_0 , dout_bi_1 , dout_bi_2 , dout_bi_3 , dout_bi_4 , dout_bi_5 , dout_bi_6 , dout_bi_7 ;




//-- output fifo signal --

wire [TBYTE-1: 0 ]	osif_strb_din			;
wire 				osif_user_din			;

wire [TBITS-1: 0 ]	endian_data_in			;// new assignment signal endian_data_in deal with zcu102 data Endianness

//---- schedule ctrl ----
wire if_write_done		;
wire if_write_busy		;
wire if_write_start		;
wire if_read_done		;
wire if_read_busy		;
wire if_read_start		;
wire if_pad_done 		;
wire if_pad_busy 		;
wire if_pad_start		;

wire ker_write_start	;
wire ker_write_busy		;
wire ker_write_en		;
wire ker_write_done		;
wire bias_write_start	;
wire bias_write_busy	;
wire bias_write_done	;

wire ker_read_start		;
wire ker_read_busy		;
wire ker_read_done		;
wire bias_read_start	;
wire bias_read_busy		;
wire bias_read_done		;

wire sche_fsld_end 		;
wire sche_left_done 	;
wire sche_base_done 	;
wire sche_right_done	;
wire[3-1:0] sche_fsld_curr_state ;

//----fsm----
wire [3-1:0] fsm_mast_state;

//---- get instruction ----
wire empty_n_from_gi	;
wire read_for_gi		;
wire gi_start ;

wire [64-1:0] config_param00	;
wire [64-1:0] config_param01	;
wire [64-1:0] config_param02	;
wire [64-1:0] config_param03	;
wire [64-1:0] config_param04	;
wire [64-1:0] config_param05	;
wire [64-1:0] config_param06	;
wire [64-1:0] config_param07	;
wire [64-1:0] config_param08	;
wire [64-1:0] config_param09	;
wire [64-1:0] config_param10	;
wire [64-1:0] config_param11	;
wire [64-1:0] config_param12	;
wire [64-1:0] config_param13	;
wire [64-1:0] config_param14	;
wire [64-1:0] config_param15	;
//---- if_rw ----
wire [TBITS-1:0]	if_write_data_din		;
wire if_write_empty_n		;
wire if_write_read			;
wire if_write_en			;
wire if_read_last			;
// wire rdwd_done				;  //20251127



wire if_row_finish		;	//if_rw -> schedule
wire if_dy2_conv_finish	;   
wire [2:0] if_read_current_state;  //schedule -> if_rw

wire [TBITS-1:0] ifr_data_0 , ifr_data_1 , ifr_data_2 , ifr_data_3 , ifr_data_4 , ifr_data_5 , ifr_data_6 , ifr_data_7	;
wire	ifr_valid_0 , ifr_valid_1 , ifr_valid_2 , ifr_valid_3 , ifr_valid_4 , ifr_valid_5 , ifr_valid_6 , ifr_valid_7	;
wire	ifr_final_0 , ifr_final_1 , ifr_final_2 , ifr_final_3 , ifr_final_4 , ifr_final_5 , ifr_final_6 , ifr_final_7	;


//---- kernel_rw ----
wire ker_write_empty_n	 ;
wire ker_write_read		 ;
wire ker_read_en_ker_cnt ;
wire [8-1:0]ker_read_cnt_ker ;

wire [TBITS-1:0] ksr_data_0 , ksr_data_1 , ksr_data_2 , ksr_data_3 , ksr_data_4 , ksr_data_5 , ksr_data_6 , ksr_data_7	;
wire 	ksr_valid_0 , ksr_valid_1 , ksr_valid_2 , ksr_valid_3 , ksr_valid_4 , ksr_valid_5 , ksr_valid_6 , ksr_valid_7;
wire 	ksr_final_0 , ksr_final_1 , ksr_final_2 , ksr_final_3 , ksr_final_4 , ksr_final_5 , ksr_final_6 , ksr_final_7;



//---- bias_rw ----
wire bias_write_empty_n		;
wire bias_write_read		;
wire bias_write_en ;

//----------- bias output signal -----------------------------
	// ====		replace bias reg		====
	wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_curr_0	;
	wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_curr_1	;
	wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_curr_2	;
	wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_curr_3	;
	wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_curr_4	;
	wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_curr_5	;
	wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_curr_6	;
	wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_curr_7	;

	wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_next_0	;
	wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_next_1	;
	wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_next_2	;
	wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_next_3	;
	wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_next_4	;
	wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_next_5	;
	wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_next_6	;
	wire signed [ BIAS_WORD_LENGTH -1 : 0 ] bias_reg_next_7	;
	// ====		Tag of bias reg		====
	wire [BUF_TAG_BITS-1 : 0 ] tag_bias_curr_0	;
	wire [BUF_TAG_BITS-1 : 0 ] tag_bias_curr_1	;
	wire [BUF_TAG_BITS-1 : 0 ] tag_bias_curr_2	;
	wire [BUF_TAG_BITS-1 : 0 ] tag_bias_curr_3	;
	wire [BUF_TAG_BITS-1 : 0 ] tag_bias_curr_4	;
	wire [BUF_TAG_BITS-1 : 0 ] tag_bias_curr_5	;
	wire [BUF_TAG_BITS-1 : 0 ] tag_bias_curr_6	;
	wire [BUF_TAG_BITS-1 : 0 ] tag_bias_curr_7	;

	wire [BUF_TAG_BITS-1 : 0 ] tag_bias_next_0	;
	wire [BUF_TAG_BITS-1 : 0 ] tag_bias_next_1	;
	wire [BUF_TAG_BITS-1 : 0 ] tag_bias_next_2	;
	wire [BUF_TAG_BITS-1 : 0 ] tag_bias_next_3	;
	wire [BUF_TAG_BITS-1 : 0 ] tag_bias_next_4	;
	wire [BUF_TAG_BITS-1 : 0 ] tag_bias_next_5	;
	wire [BUF_TAG_BITS-1 : 0 ] tag_bias_next_6	;
	wire [BUF_TAG_BITS-1 : 0 ] tag_bias_next_7	;


	wire signed [32-1 : 0 ] bias_sel_ot_0 ;
	wire signed [32-1 : 0 ] bias_sel_ot_1 ;
	wire signed [32-1 : 0 ] bias_sel_ot_2 ;
	wire signed [32-1 : 0 ] bias_sel_ot_3 ;
	wire signed [32-1 : 0 ] bias_sel_ot_4 ;
	wire signed [32-1 : 0 ] bias_sel_ot_5 ;
	wire signed [32-1 : 0 ] bias_sel_ot_6 ;
	wire signed [32-1 : 0 ] bias_sel_ot_7 ;

	reg [BUF_TAG_BITS -1 : 0 ] otker_align_dly0 , otker_align_dly1 , otker_align_dly2 , otker_align_dly3,
		otker_align_dly4 , otker_align_dly5 , otker_align_dly6 , otker_align_dly7,
		otker_align_dly8 , otker_align_dly9 , otker_align_dly10		;
	reg otenker_align_dly0 , otenker_align_dly1 , otenker_align_dly2 , otenker_align_dly3 , otenker_align_dly4 , otenker_align_dly5 , 
 	otenker_align_dly6 , otenker_align_dly7 , otenker_align_dly8 , otenker_align_dly9 , otenker_align_dly10	;

	wire bias_read_en_buf_sw ;
//----------------------------------------------------------------------------
	//----    output module declare    -----
	wire	ot2fifo_full_n	;
	wire	ot2fifo_write	;
	wire	ot2fifo_last	;
	wire	[ TBITS-1 : 0 ]	ot2fifo_data		;
	//-----------------------------------------------------------------------------
	//----    PE module declare    -----
	wire	[PEBLKROW_NUM*TBITS-1 :0 ]	pe2o_allq_dout		;
	wire	[PEBLKROW_NUM-1 :0 ]	pe2o_allvalid_dout	;

	wire pe_valid_0 ,	pe_valid_1 ,	pe_valid_2 ,	pe_valid_3 ,	pe_valid_4 ,	pe_valid_5 ,	pe_valid_6 ,	pe_valid_7 ;
	wire pe_final_0 ,	pe_final_1 ,	pe_final_2 ,	pe_final_3 ,	pe_final_4 ,	pe_final_5 ,	pe_final_6 ,	pe_final_7 ;
//-----------------------------------------------------------------------------
//---- ot ----
	wire	ot_buf_ready	;








//==============================================================================
//========    Temporary cfg setting    ========
//==============================================================================



////----    Config register    -----
	wire		[8-1:0]	cfg_atlchin			;	
	wire		[3-1:0]	cfg_conv_switch		;	
	wire		[2-1:0]	cfg_mast_state		;
	wire		[IFMAP_SRAM_ADDBITS-1:0]	cfg_pd_list_0		;
	wire		[IFMAP_SRAM_ADDBITS-1:0]	cfg_pd_list_1		;
	wire		[IFMAP_SRAM_ADDBITS-1:0]	cfg_pd_list_2		;
	wire		[IFMAP_SRAM_ADDBITS-1:0]	cfg_pd_list_3		;
	wire		[IFMAP_SRAM_ADDBITS-1:0]	cfg_pd_list_4		;
	wire		[CNTSTP_WIDTH-1:0]	cfg_cnt_step_p1		;
	wire		[CNTSTP_WIDTH-1:0]	cfg_cnt_step_p2	;

	wire		[8-1:0]		cfg_pdlf	;	// no use
	wire		[8-1:0]		cfg_pdrg	;	// no use
	wire		[8-1:0]		cfg_nor		;	// no use
	wire		[IFWSTG0_CNTBITS-1 :0]	cfg_stg0_nor_finum	;
	wire		[IFWSTG0_CNTBITS-1 :0]	cfg_stg0_pdb0_finum	;
	wire		[IFWSTG0_CNTBITS-1 :0]	cfg_stg0_pdb1_finum	;
	wire		[IFWSTG1_CNTBITS-1 :0]	cfg_stg1_eb_col		;
	wire		[DATAIN_CNT_BITS-1 :0]	cfg_dincnt_finum		;
	wire		[3-1 :0]	cfg_rowcnt_finum		;

	wire		[8-1:0]	cfg_ifr_window	;
	wire		[7:0]   cfg_ift_total_window;


//----    kernel read cfg    -----
wire	[BUF_TAG_BITS-1:0]  	cfg_kernum_sub1		;	//8bits
wire	[KER_ADDR_CNT_BITS-1:0]		cfg_colout_sub1		;	//10bits
wire	[KER_ADDR_CNT_BITS-1:0]		cfg_normal_length	;	//10bits

wire	[STARTER_BITS*5	-1:0]	cfgin_top_starter		;	//8*5bits
wire	[PADLEN_BITS*5	-1:0]	cfgin_toppad_length		;	//8*5bits
wire	[PADLEN_BITS*5	-1:0]	cfgin_botpad_length		;	//8*5bits

//----    kernel write cfg    -----
wire	[KER_ADDR_CNT_BITS-1:0 ]	cfg_kerw_buflength ;	//10bits

//----    bias r_w cfg    -----
wire	[BIAS_ADDR_BITS-1:0 ]	cfg_bir_rg_prep			;
wire	[BIAS_ADDR_BITS-1:0 ]	cfg_biw_lengthsub1		;

//----    output module config    -----
wire	[ OTSRAM_ADDR_BITS-1 : 0 ]	cfg_ot_rnd_finsub1	;	//YWJ
wire	[ OTSRAM_ADDR_BITS-1 : 0 ]	cfg_ot_tgpfnsub1	;	//YWJ
wire	[ OTSRAM_ADDR_BITS-1 : 0 ]	cfg_ot_tcolfnsub1	;	//YWJ
wire	[ OTSRAM_ADDR_BITS-1 : 0 ]		cfg_ot_tchafnsub1	;	//YWJ
wire	[ OTSRAM_ADDR_BITS-1 : 0 ]	cfg_ot_sft_gp		;	//YWJ
wire	[ OTSRAM_ADDR_BITS-1 : 0 ]	cfg_ot_sft_colpra	;	//YWJ

wire    [8:0]   cfg_total_row   ;		//YWJ
wire    [5:0]   cfg_base_number ; 


//----    quantization config    -----
wire	[31:0]  cfg_m0_scale	;
wire	[ 7:0]  cfg_index		;
wire	[15:0]  cfg_z_of_weight	;
wire	[ 7:0]  cfg_z3			;
//-----------------------------------------------------------------------------

//==============================================================================
//========    ILA check signal assignment   ========
//==============================================================================
//----    FPGA ILA Check I/O    -----
`ifdef FPGA_ILA_CHK_SETTING
	//----    schedule    -----
	assign ick_if_write_done	=	if_write_done	;
	assign ick_if_write_busy	=	if_write_busy	;
	assign ick_if_write_start	=	if_write_start	;
	assign ick_if_read_done		=	if_read_done	;
	assign ick_if_read_busy		=	if_read_busy	;
	assign ick_if_read_start	=	if_read_start	;

assign ick_ker_write_start		=	ker_write_start		;
	assign ick_ker_write_busy		=	ker_write_busy		;
	assign ick_ker_write_en			=	ker_write_en		;
	assign ick_ker_write_done		=	ker_write_done		;
	assign ick_bias_write_start		=	bias_write_start	;
	assign ick_bias_write_busy		=	bias_write_busy		;
	assign ick_bias_write_done		=	bias_write_done		;

assign ick_ker_read_start		=	if_read_start		;
	assign ick_ker_read_busy		=	ker_read_busy		;
	assign ick_ker_read_done		=	ker_read_done		;
	assign ick_bias_read_start		=	if_read_start		;
	assign ick_bias_read_busy		=	bias_read_busy		;
	assign ick_bias_read_done		=	bias_read_done		;


	assign ick_ifr_data_0	=	ifr_data_0		;
	assign ick_ksr_data_0	=	ksr_data_0		;
	assign ick_ifr_data_7	=	ifr_data_7		;
	assign ick_ksr_data_7	=	ksr_data_7		;
	assign ick_pe_valid_0	=	pe_valid_0		;
	assign ick_pe_valid_7	=	pe_valid_7		;
	assign ick_pe_final_0	=	pe_final_0		;
	assign ick_pe_final_7	=	pe_final_7		;
	assign ick_pe2o_allvalid_dout	=	pe2o_allvalid_dout	;

`endif 







// ===========================================================================
// =======		instance 	==================================================
// ===========================================================================


	fsm64 fs01(
			.clk	(	clk	)
		,	.reset		(	ap_rst		)
		,	.start		(	gi_start	)
		,	.outmast_curr_state (	fsm_mast_state	)
		,	.flag_fsld_end 	(	sche_fsld_end		)
		,	.left_done 		(	sche_left_done		)
		,	.base_done 		(	sche_base_done		)
		,	.right_done  	(	sche_right_done		)

		,	.cfg_base_number(	cfg_base_number		)

	);

	get_ins gi01(	
		.clk 	(	clk	)
	,	.reset 	(	ap_rst	)

	,	.fifo_data_din		(	endian_data_in		)
	,	.fifo_strb_din		(	isif_strb_dout		)
	,	.fifo_last_din		(	isif_last_dout		)
	,	.fifo_user_din		(	isif_user_dout		)
	,	.fifo_empty_n_din	(	isif_empty_n		)
	,	.fifo_read_dout		(	isif_read			)

	,	.ds_empty_n			(	empty_n_from_gi		)	// output
	,	.ds_read			(	read_for_gi			)	// input

	,	.instr_code00	(	config_param00		)
	,	.instr_code01	(	config_param01		)	//quantization config
	,	.instr_code02	(	config_param02		)	//fsm & sche config
	,	.instr_code03	(	config_param03		)	//if_pd config
	,	.instr_code04	(	config_param04		)	//if_pd config
	,	.instr_code05	(	config_param05		)	//if_w config
	,	.instr_code06	(	config_param06		)	//if_w config
	,	.instr_code07	(	config_param07		)	//if_r config
	,	.instr_code08	(	config_param08		)	//if_r config
	,	.instr_code09	(	config_param09		)	//if_r config
	,	.instr_code10	(	config_param10		)	//if_r config
	,	.instr_code11	(	config_param11		)	//if_r config
	,	.instr_code12	(	config_param12		)	//if_r config
	,	.instr_code13	(	config_param13		)	//if_r config
	,	.instr_code14	(	config_param14		)	//if_r config
	,	.instr_code15	(	config_param15		)	//if_r config

	,	.start_reg		(	gi_start	)

	,	.mast_curr_state		(	fsm_mast_state	)

	);



schedule_ctrl sche00(
		.clk 	(	clk	)
	,	.reset 	(	ap_rst	)

	,	.mast_curr_state 		(	fsm_mast_state	)	
	,	.cfg_conv_switch		(	cfg_conv_switch			)		

	,	.if_write_start			(	if_write_start		)
	,	.if_write_busy			(	if_write_busy		)
	,	.if_write_done			(	if_write_done		)

	,	.if_pad_done 			(	if_pad_done 	)
	,	.if_pad_busy 			(	if_pad_busy 	)
	,	.if_pad_start			(	if_pad_start	)

	,	.ker_write_start		(	ker_write_start		)
	,	.ker_write_busy			(	ker_write_busy		)
	,	.ker_write_done			(	ker_write_done		)

	,	.bias_write_start		(	bias_write_start	)
	,	.bias_write_busy		(	bias_write_busy		)
	,	.bias_write_done		(	bias_write_done		)

	,	.if_read_done 			(	if_read_done		)	//if_rw -> schedule
	,	.if_read_busy 			(	if_read_busy		)	//if_rw -> schedule
	,	.if_read_start			(	if_read_start		)	//schedule -> if_rw

	,	.chk_ot_ready			(	ot_buf_ready		)	//ot -> schedule

	// //--------------Read sram I/O------------
	,	.if_row_finish		(	if_row_finish		)	//if_rw -> schedule
	,	.if_dy2_conv_finish	(	if_dy2_conv_finish	)   
	,	.if_read_current_state		(	if_read_current_state	)	//schedule -> if_rw
	//-------------------------------------------------
	,	.flag_fsld_end		(	sche_fsld_end		)
	,	.left_done			(	sche_left_done		)
	,	.base_done			(	sche_base_done		)
	,	.right_done			(	sche_right_done		)
	//----testing ----
	,	.sche_fsld_curr_state			(	sche_fsld_curr_state	)

	//config schedule setting
	,	.cfg_total_row     (cfg_total_row)
	//---------------------------------------------
	,	.if_write_empty_n_din	(	if_write_empty_n	)
	,	.if_read_last		(if_read_last)
	,	.rdwd_done			(rdwd_done)
);




	d_empn_rd_mux dmx_0(
			.if_write_empty_n		(	if_write_empty_n	)	// input feature write module empty_n signal
		,	.ker_write_empty_n		(	ker_write_empty_n	)	// kernel write module empty_n signal
		,	.bias_write_empty_n		(	bias_write_empty_n	)	// bias write module empty_n signal
		,	.if_write_read			(	if_write_read		)	// input feature write module read signal
		,	.ker_write_read			(	ker_write_read		)	// kernel write module read signal
		,	.bias_write_read		(	bias_write_read		)	// bias write module read signal

		,	.empty_n_from_gi		(	empty_n_from_gi		)
		,	.read_for_gi			(	read_for_gi			)

		,	.mast_current_state		(	fsm_mast_state	)
		,	.fsld_current_state		(	sche_fsld_curr_state	)
		,	.if_write_enable		(	if_write_en	)

		,	.ker_write_en			(	ker_write_en	)
		,	.bias_write_enable		(	bias_write_en	)
	);



		
	ifsram_rw #(    
			.TBITS(	TBITS 	)     
		,	.IFMAP_SRAM_ADDBITS		(	IFMAP_SRAM_ADDBITS	)
		,	.IFMAP_SRAM_DATA_WIDTH 	(	IFMAP_SRAM_DATA_WIDTH	)
		,	.CNTSTP_WIDTH			(	CNTSTP_WIDTH	)
		,	.IFWSTG0_CNTBITS		(	IFWSTG0_CNTBITS	)
		,	.IFWSTG1_CNTBITS		(	IFWSTG1_CNTBITS	)
		,	.DATAIN_CNT_BITS		(	DATAIN_CNT_BITS	)
	)ifa01(	
			.clk	(	clk		)
		,	.reset	(	ap_rst	)

		,	.if_write_data_din		(	endian_data_in		)			
		,	.if_write_empty_n_din	(	if_write_empty_n	)		
		,	.if_write_read_dout		(	if_write_read		)		

		,	.if_write_done			(	if_write_done	)	
		,	.if_write_busy			(	if_write_busy	)	
		,	.if_write_start			(	if_write_start	)	
		,	.if_write_en			(	if_write_en		)

		,	.if_read_done			(	if_read_done	) 		
		,	.if_read_busy			(	if_read_busy	) 		
		,	.if_read_start			(	if_read_start	)		

		,	.if_pad_done 			(	if_pad_done 	)
		,	.if_pad_busy 			(	if_pad_busy 	)
		,	.if_pad_start			(	if_pad_start	)

		,	.row_finish				(	if_row_finish			)
		,	.dy2_conv_finish			(	if_dy2_conv_finish		)
		,	.if_read_current_state	(	if_read_current_state	)  
		,	.if_read_last		(if_read_last)
		,	.rdwd_done			(rdwd_done)

		//----    for PE data    -----
		,	.dout_ifsr_0	(	ifr_data_0 	)	, .ifr_valid_0  ( ifr_valid_0 ), .ifr_final_0  ( ifr_final_0 )	
		,	.dout_ifsr_1	(	ifr_data_1	)	, .ifr_valid_1  ( ifr_valid_1 ), .ifr_final_1  ( ifr_final_1 )
		,	.dout_ifsr_2	(	ifr_data_2	)	, .ifr_valid_2  ( ifr_valid_2 ), .ifr_final_2  ( ifr_final_2 )
		,	.dout_ifsr_3	(	ifr_data_3	)	, .ifr_valid_3  ( ifr_valid_3 ), .ifr_final_3  ( ifr_final_3 )
		,	.dout_ifsr_4	(	ifr_data_4	)	, .ifr_valid_4  ( ifr_valid_4 ), .ifr_final_4  ( ifr_final_4 )
		,	.dout_ifsr_5	(	ifr_data_5	)	, .ifr_valid_5  ( ifr_valid_5 ), .ifr_final_5  ( ifr_final_5 )
		,	.dout_ifsr_6	(	ifr_data_6	)	, .ifr_valid_6  ( ifr_valid_6 ), .ifr_final_6  ( ifr_final_6 )
		,	.dout_ifsr_7	(	ifr_data_7	)	, .ifr_valid_7  ( ifr_valid_7 ), .ifr_final_7  ( ifr_final_7 )

		//config input setting(ifsram_pd)
		,	.cfg_atlchin				(	cfg_atlchin				)
		,	.cfg_conv_switch			(	cfg_conv_switch			)
		,	.cfg_mast_state				(	fsm_mast_state			)
		,	.cfg_pd_list_0				(	cfg_pd_list_0			)
		,	.cfg_pd_list_1				(	cfg_pd_list_1			)
		,	.cfg_pd_list_2				(	cfg_pd_list_2			)
		,	.cfg_pd_list_3				(	cfg_pd_list_3			)
		,	.cfg_pd_list_4				(	cfg_pd_list_4			)
		,	.cfg_cnt_step_p1			(	cfg_cnt_step_p1			)
		,	.cfg_cnt_step_p2			(	cfg_cnt_step_p2			)

		//config input setting(ifsram_w)
		// ,	.cfg_pdlf					(	cfg_pdlf				)
		// ,	.cfg_pdrg					(	cfg_pdrg				)
		// ,	.cfg_nor					(	cfg_nor					)
		,	.cfg_stg0_nor_finum			(	cfg_stg0_nor_finum		)
		,	.cfg_stg0_pdb0_finum		(	cfg_stg0_pdb0_finum		)
		,	.cfg_stg0_pdb1_finum		(	cfg_stg0_pdb1_finum		)
		,	.cfg_stg1_eb_col			(	cfg_stg1_eb_col			)
		,	.cfg_dincnt_finum			(	cfg_dincnt_finum		)
		,	.cfg_rowcnt_finum			(	cfg_rowcnt_finum		)

		//config input setting(ifsram_r)
		,	.cfg_ifr_window				(	cfg_ifr_window	)
		,   .cfg_ifr_kernel_repeat      (	cfg_kernum_sub1	)
		,	.cfg_ift_total_window		(cfg_ift_total_window)	

		`ifdef FPGA_ILA_CHK_SETTING
		,	.ick_addrb_sram_if0b0	(	ick_addrb_sram_if0b0			)
		`endif
	);


	ker_top  #(    
			.KER_ADDR_CNT_BITS(	KER_ADDR_CNT_BITS 	)     
		,	.BUF_TAG_BITS	(	BUF_TAG_BITS	)
		,	.STARTER_BITS	(	STARTER_BITS	)
		,	.PADLEN_BITS	(	PADLEN_BITS	)
	)kea01(		
			.clk	(	clk		)
		,	.reset	(	ap_rst	)

		,	.ker_write_data_din		(	endian_data_in		)
		,	.ker_write_empty_n_din	(	ker_write_empty_n		)
		,	.ker_write_read_dout	(	ker_write_read		)

		,	.ker_write_done 		(	ker_write_done	)
		,	.ker_write_busy 		(	ker_write_busy	)
		,	.ker_write_en 			(	ker_write_en	)
		,	.start_ker_write		(	ker_write_start	)

		,	.ker_read_done 			(	ker_read_done 	)
		,	.ker_read_busy 			(	ker_read_busy 	)
		,	.start_ker_read			(	if_read_start	)

		//----generated by ker_top_mod.py------ 
		//----top port list for other module instance------ 
		,	.dout_kersr_0 ( ksr_data_0 ), .ksr_valid_0  ( ksr_valid_0 ), .ksr_final_0  ( ksr_final_0 ) //----instance KER top_0---------
		,	.dout_kersr_1 ( ksr_data_1 ), .ksr_valid_1  ( ksr_valid_1 ), .ksr_final_1  ( ksr_final_1 ) //----instance KER top_1---------
		,	.dout_kersr_2 ( ksr_data_2 ), .ksr_valid_2  ( ksr_valid_2 ), .ksr_final_2  ( ksr_final_2 ) //----instance KER top_2---------
		,	.dout_kersr_3 ( ksr_data_3 ), .ksr_valid_3  ( ksr_valid_3 ), .ksr_final_3  ( ksr_final_3 ) //----instance KER top_3---------
		,	.dout_kersr_4 ( ksr_data_4 ), .ksr_valid_4  ( ksr_valid_4 ), .ksr_final_4  ( ksr_final_4 ) //----instance KER top_4---------
		,	.dout_kersr_5 ( ksr_data_5 ), .ksr_valid_5  ( ksr_valid_5 ), .ksr_final_5  ( ksr_final_5 ) //----instance KER top_5---------
		,	.dout_kersr_6 ( ksr_data_6 ), .ksr_valid_6  ( ksr_valid_6 ), .ksr_final_6  ( ksr_final_6 ) //----instance KER top_6---------
		,	.dout_kersr_7 ( ksr_data_7 ), .ksr_valid_7  ( ksr_valid_7 ), .ksr_final_7  ( ksr_final_7 ) //----instance KER top_7---------

		,	.output_of_cnt_ker 			(	ker_read_cnt_ker 		)
		,	.output_of_enable_ker_cnt 	(	ker_read_en_ker_cnt 	)


		,	.cfg_kernum_sub1			(	cfg_kernum_sub1			)
		,	.cfg_colout_sub1			(	cfg_colout_sub1			)
		,	.cfg_normal_length			(	cfg_normal_length		)
		,	.cfgin_top_starter			(	cfgin_top_starter		)
		,	.cfgin_toppad_length		(	cfgin_toppad_length		)
		,	.cfgin_botpad_length		(	cfgin_botpad_length		)
		,	.cfg_kerw_buflength			(	cfg_kerw_buflength		)
		,	.cfg_atlchin				(	cfg_atlchin				)

		,	.if_r_state			(	if_read_current_state		)
	);



	bias_top #(    
			.BUF_TAG_BITS(	BUF_TAG_BITS 		)     
		,	.BIAS_WORD_LENGTH	(	BIAS_WORD_LENGTH	)
		,	.BIAS_ADDR_BITS		(	BIAS_ADDR_BITS		)
	)bia01(	
			.clk	(	clk		)
		,	.reset	(	ap_rst	)

		,	.if_r_state(	if_read_current_state	)
		, 	.rdwd_done(	rdwd_done	)

		,	.bias_write_data_din	(	endian_data_in		)
		,	.bias_write_empty_n_din	(	bias_write_empty_n		)
		,	.bias_write_read_dout	(	bias_write_read			)

		,	.bias_write_en 			(	bias_write_en		)
		,	.bias_write_done 		(	bias_write_done		)
		,	.bias_write_busy 		(	bias_write_busy		)
		,	.start_bias_write		(	bias_write_start	)

		,	.bias_read_done 		(	bias_read_done 	)
		,	.bias_read_busy 		(	bias_read_busy 	)
		,	.start_bias_read		(	if_read_start	)
		// ====		replace bias reg		====
		,	.bias_reg_curr_0		(	bias_reg_curr_0		)
		,	.bias_reg_curr_1		(	bias_reg_curr_1		)
		,	.bias_reg_curr_2		(	bias_reg_curr_2		)
		,	.bias_reg_curr_3		(	bias_reg_curr_3		)
		,	.bias_reg_curr_4		(	bias_reg_curr_4		)
		,	.bias_reg_curr_5		(	bias_reg_curr_5		)
		,	.bias_reg_curr_6		(	bias_reg_curr_6		)
		,	.bias_reg_curr_7		(	bias_reg_curr_7		)

		,	.bias_reg_next_0		(	bias_reg_next_0		)
		,	.bias_reg_next_1		(	bias_reg_next_1		)
		,	.bias_reg_next_2		(	bias_reg_next_2		)
		,	.bias_reg_next_3		(	bias_reg_next_3		)
		,	.bias_reg_next_4		(	bias_reg_next_4		)
		,	.bias_reg_next_5		(	bias_reg_next_5		)
		,	.bias_reg_next_6		(	bias_reg_next_6		)
		,	.bias_reg_next_7		(	bias_reg_next_7		)
		// ====		Tag of bias reg	(				)	====
		,	.tag_bias_curr_0		(	tag_bias_curr_0		)
		,	.tag_bias_curr_1		(	tag_bias_curr_1		)
		,	.tag_bias_curr_2		(	tag_bias_curr_2		)
		,	.tag_bias_curr_3		(	tag_bias_curr_3		)
		,	.tag_bias_curr_4		(	tag_bias_curr_4		)
		,	.tag_bias_curr_5		(	tag_bias_curr_5		)
		,	.tag_bias_curr_6		(	tag_bias_curr_6		)
		,	.tag_bias_curr_7		(	tag_bias_curr_7		)

		,	.tag_bias_next_0		(	tag_bias_next_0		)
		,	.tag_bias_next_1		(	tag_bias_next_1		)
		,	.tag_bias_next_2		(	tag_bias_next_2		)
		,	.tag_bias_next_3		(	tag_bias_next_3		)
		,	.tag_bias_next_4		(	tag_bias_next_4		)
		,	.tag_bias_next_5		(	tag_bias_next_5		)
		,	.tag_bias_next_6		(	tag_bias_next_6		)
		,	.tag_bias_next_7		(	tag_bias_next_7		)

		,	.tst_cp_ker_num			(	otker_align_dly2	)
		,	.tst_en_buf_sw			(	bias_read_en_buf_sw		)
		,	.tst_ker_read_done		(	ker_read_done		)

		,	.cfg_kernum_sub1		(	cfg_kernum_sub1		)
		,	.cfg_bir_rg_prep		(	cfg_bir_rg_prep		)		
		,	.cfg_biw_lengthsub1		(	cfg_biw_lengthsub1	)	
	);

	// INPUT_STREAM_if		#(
	// 		.TBITS	(	TBITS	)
	// 	,	.TBYTE	(	TBYTE	)
	// )axififo_in (
	// 	// AXI4-Stream singals
	// 		.ACLK       (	clk	)
	// 	,	.ARESETN    (	resetn	)
	// 	,	.TVALID     (	S_AXIS_MM2S_TVALID	)
	// 	,	.TREADY     (	S_AXIS_MM2S_TREADY	)
	// 	,	.TDATA      (	S_AXIS_MM2S_TDATA	)
	// 	,	.TKEEP      (	S_AXIS_MM2S_TKEEP	)
	// 	,	.TLAST      (	S_AXIS_MM2S_TLAST	)
	// 	,	.TUSER      ( 1'b0 )

	// 		// User signals
	// 	,	.isif_data_dout         (	isif_data_dout		)
	// 	,	.isif_strb_dout         (	isif_strb_dout		)
	// 	,	.isif_last_dout         (	isif_last_dout		)
	// 	,	.isif_user_dout         (	isif_user_dout		)
	// 	,	.isif_empty_n           (	isif_empty_n		)
	// 	,	.isif_read				(	isif_read			)
	// );

	// //----    PE to output instance    -----
	// OUTPUT_STREAM_if #(
	// 		.TBITS 			(	TBITS				) 
	// 	,	.TBYTE 			(	TBYTE				)
	// )axififo_out (
	// 		.ACLK 			( 	clk 				) 
	// 	,	.ARESETN 		( 	resetn 				) 
	// 	,	.TVALID 		(	M_AXIS_S2MM_TVALID	) 
	// 	,	.TREADY 		(	M_AXIS_S2MM_TREADY	) 
	// 	,	.TDATA 			(	M_AXIS_S2MM_TDATA 	) 
	// 	,	.TKEEP 			(	M_AXIS_S2MM_TKEEP 	) 
	// 	,	.TLAST 			(	M_AXIS_S2MM_TLAST 	)     
	// 		// .TUSER (  ) ,

	// 	,	.osif_data_din 	( 	osif_data_din 	) 
	// 	,	.osif_strb_din 	( 	8'hff 			) 
	// 	,	.osif_last_din 	( 	osif_last_din 	) 
	// 	,	.osif_user_din 	( 	1'b0 			) 
	// 	,	.osif_full_n 	( 	osif_full_n 	) 
	// 	,	.osif_write 	( 	osif_write 		) 
	// );  

	ot_top 	#(
			.TBITS 				(	TBITS					)
		,	.TBYTE 				(	TBYTE					)
		,	.PEBLKROW_NUM		(	PEBLKROW_NUM			)
		,	.SRAM_ADDR_BITS		(	OTSRAM_ADDR_BITS		)
		,	.SRAM_DATA_BITS		(	OTSRAM_DATA_BITS		)
	)ota01(
			.clk				(	clk						)
		,	.reset				(	ap_rst					)		

		,	.din_s2mm_tready	(	M_AXIS_S2MM_TREADY		)
		,	.fifo_full_n		(	osif_full_n				)
		,	.fifo_write			(	ot2fifo_write			)
		,	.fifo_last			(	ot2fifo_last			)
		,	.fifo_data			(	ot2fifo_data			)

		,	.valid_din 			(	pe2o_allvalid_dout		)
		,	.data_din			(	pe2o_allq_dout			)

		,	.ot_ready			(	ot_buf_ready			)

		,	.cfg_ot_rnd_finsub1	(	cfg_ot_rnd_finsub1		)
		,	.cfg_ot_tgpfnsub1	(	cfg_ot_tgpfnsub1		)
		,	.cfg_ot_tcolfnsub1	(	cfg_ot_tcolfnsub1		)
		,	.cfg_ot_tchafnsub1	(	cfg_ot_tchafnsub1		)
		,	.cfg_ot_sft_gp		(	cfg_ot_sft_gp			)
		,	.cfg_ot_sft_colpra	(	cfg_ot_sft_colpra		)
	);


	pe_top	#(
			.TBITS 				(	TBITS	)
		,	.TBYTE 			(	TBYTE	)
		,	.PEBLKROW_NUM	(	PEBLKROW_NUM	)
	)pea01(
			.clk	(	clk		)
		,	.reset	(	ap_rst	)	
		,	.cfg_m0_scale 	(	cfg_m0_scale 		)
		,	.cfg_index 		(	cfg_index 			)
		,	.cfg_z_of_weight	(	cfg_z_of_weight		)
		,	.cfg_z3			(	cfg_z3				)

		,	.flat_ker_din		(	{ksr_data_0 , ksr_data_1 , ksr_data_2 , ksr_data_3 , ksr_data_4 , ksr_data_5 , ksr_data_6 , ksr_data_7	} )
		,	.flat_bias_din		(	{bias_sel_ot_0 , bias_sel_ot_1 , bias_sel_ot_2 , bias_sel_ot_3 , bias_sel_ot_4 , bias_sel_ot_5 , bias_sel_ot_6 , bias_sel_ot_7	}	)
		,	.flat_valid_din		(	{pe_valid_0 , pe_valid_1,  pe_valid_2,  pe_valid_3,  pe_valid_4,  pe_valid_5,  pe_valid_6,  pe_valid_7	})
		,	.flat_final_din		(	{pe_final_0 , pe_final_1 , pe_final_2 , pe_final_3 , pe_final_4 , pe_final_5 , pe_final_6 , pe_final_7	})
		,	.flat_act_din		(	{ifr_data_0 , ifr_data_1 , ifr_data_2 , ifr_data_3 , ifr_data_4 , ifr_data_5 , ifr_data_6 , ifr_data_7	})
		// ,	.flat_act_din	({})

		`ifdef FPGA_ILA_CHK_SETTING
			,	.ick_pkg64_result_0	(	ick_pkg64_result_0			)
			,	.ick_q_result_0	(	ick_q_result_0			)
			,	.ick_pkg64_result_7	(	ick_pkg64_result_7			)
			,	.ick_q_result_7	(	ick_q_result_7			)

			,	.ick_q_valid_0			(			ick_q_valid_0)
			,	.ick_rcfg_m0_scale 		(			ick_rcfg_m0_scale 	)
			,	.ick_rcfg_index 		(			ick_rcfg_index 		)	
			,	.ick_rcfg_z_of_weight	(		ick_rcfg_z_of_weight)
			,	.ick_rcfg_z3			(			ick_rcfg_z3			)	
			,	.ick_valid_forpe_0	(			ick_valid_forpe_0	)
			,	.ick_final_forpe_0	(			ick_final_forpe_0	)
			,	.ick_act_forpe_0		(			ick_act_forpe_0		)
			,	.ick_frowpe_ker_0	(			ick_frowpe_ker_0	)
			,	.ick_frowpe_ker_1	(			ick_frowpe_ker_1	)
			,	.ick_frowpe_ker_2	(			ick_frowpe_ker_2	)
			,	.ick_frowpe_ker_3	(			ick_frowpe_ker_3	)
			,	.ick_frowpe_ker_4	(			ick_frowpe_ker_4	)
			,	.ick_frowpe_ker_5	(			ick_frowpe_ker_5	)
			,	.ick_frowpe_ker_6	(			ick_frowpe_ker_6	)
			,	.ick_frowpe_ker_7	(			ick_frowpe_ker_7	)
			,	.ick_frowpe_bias_0	(			ick_frowpe_bias_0	)
			,	.ick_frowpe_bias_1	(			ick_frowpe_bias_1	)
			,	.ick_frowpe_bias_2	(			ick_frowpe_bias_2	)
			,	.ick_frowpe_bias_3	(			ick_frowpe_bias_3	)
			,	.ick_frowpe_bias_4	(			ick_frowpe_bias_4	)
			,	.ick_frowpe_bias_5	(			ick_frowpe_bias_5	)
			,	.ick_frowpe_bias_6	(			ick_frowpe_bias_6	)
			,	.ick_frowpe_bias_7	(			ick_frowpe_bias_7	)
		`endif

		,	.allq_dout			(	pe2o_allq_dout			)
		,	.allvalid_dout		(	pe2o_allvalid_dout		)
	);

	yolo_rst_if #(
			.RESET_ACTIVE_LOW ( RESET_ACTIVE_LOW ) )
	yolo_rst_if_U(
			.dout ( ap_rst ) 
		,	.din ( resetn ) 
	);  // yolo_rst_if_U



//----	IF KER BIAS valid and final assignment-------------------------------------------------------------------

	assign pe_valid_0 = (ksr_valid_0 & ifr_valid_0) ;
	assign pe_valid_1 = (ksr_valid_1 & ifr_valid_1) ;
	assign pe_valid_2 = (ksr_valid_2 & ifr_valid_2) ;
	assign pe_valid_3 = (ksr_valid_3 & ifr_valid_3) ;
	assign pe_valid_4 = (ksr_valid_4 & ifr_valid_4) ;
	assign pe_valid_5 = (ksr_valid_5 & ifr_valid_5) ;
	assign pe_valid_6 = (ksr_valid_6 & ifr_valid_6) ;
	assign pe_valid_7 = (ksr_valid_7 & ifr_valid_7) ;

	assign pe_final_0 = (ksr_final_0 & ifr_final_0) ;
	assign pe_final_1 = (ksr_final_1 & ifr_final_1) ;
	assign pe_final_2 = (ksr_final_2 & ifr_final_2) ;
	assign pe_final_3 = (ksr_final_3 & ifr_final_3) ;
	assign pe_final_4 = (ksr_final_4 & ifr_final_4) ;
	assign pe_final_5 = (ksr_final_5 & ifr_final_5) ;
	assign pe_final_6 = (ksr_final_6 & ifr_final_6) ;
	assign pe_final_7 = (ksr_final_7 & ifr_final_7) ;
//


//----	output FIFO assignment-------------------------------------------------------------------

// assign osif_data_din	=	ot2fifo_data	;
	assign osif_last_din	=	ot2fifo_last	;
	assign osif_write		=	ot2fifo_write	;

	`ifdef BIG_ENDIAN
	assign endian_data_in          = { isif_data_dout[ 7 :  0], 
	                            isif_data_dout[15 :  8],
	                            isif_data_dout[23 : 16],
	                            isif_data_dout[31 : 24],
	                            isif_data_dout[39 : 32],
	                            isif_data_dout[47 : 40],
	                            isif_data_dout[55 : 48],
	                            isif_data_dout[63 : 56]
	                          };
	
	assign osif_data_din    = { ot2fifo_data[ 7 :  0], 
                            ot2fifo_data[15 :  8],
                            ot2fifo_data[23 : 16],
                            ot2fifo_data[31 : 24],
                            ot2fifo_data[39 : 32],
                            ot2fifo_data[47 : 40],
                            ot2fifo_data[55 : 48],
                            ot2fifo_data[63 : 56]
                          }; 
	
	`else
	assign endian_data_in          = isif_data_dout;
	assign osif_data_din    = ot2fifo_data;
	`endif


//---- bias select by tag version 1 : 2022.12.05 ----
assign bias_sel_ot_0 = ( otker_align_dly2 == tag_bias_curr_0 ) ? bias_reg_curr_0 : bias_reg_next_0 ;
assign bias_sel_ot_1 = ( otker_align_dly3 == tag_bias_curr_1 ) ? bias_reg_curr_1 : bias_reg_next_1 ;
assign bias_sel_ot_2 = ( otker_align_dly4 == tag_bias_curr_2 ) ? bias_reg_curr_2 : bias_reg_next_2 ;
assign bias_sel_ot_3 = ( otker_align_dly5 == tag_bias_curr_3 ) ? bias_reg_curr_3 : bias_reg_next_3 ;
assign bias_sel_ot_4 = ( otker_align_dly6 == tag_bias_curr_4 ) ? bias_reg_curr_4 : bias_reg_next_4 ;
assign bias_sel_ot_5 = ( otker_align_dly7 == tag_bias_curr_5 ) ? bias_reg_curr_5 : bias_reg_next_5 ;
assign bias_sel_ot_6 = ( otker_align_dly8 == tag_bias_curr_6 ) ? bias_reg_curr_6 : bias_reg_next_6 ;
assign bias_sel_ot_7 = ( otker_align_dly9 == tag_bias_curr_7 ) ? bias_reg_curr_7 : bias_reg_next_7 ;


	always @(posedge clk ) begin
		if( ap_rst )begin
			otker_align_dly0	<= 0 ;
			otker_align_dly1	<= 0 ;
			otker_align_dly2	<= 0 ;
			otker_align_dly3	<= 0 ;
			otker_align_dly4	<= 0 ;
			otker_align_dly5	<= 0 ;
			otker_align_dly6	<= 0 ;
			otker_align_dly7	<= 0 ;
			otker_align_dly8	<= 0 ;
			otker_align_dly9	<= 0 ;
			otker_align_dly10	<= 0 ;

			otenker_align_dly0	<= 0 ;
			otenker_align_dly1	<= 0 ;
			otenker_align_dly2	<= 0 ;
			otenker_align_dly3	<= 0 ;
			otenker_align_dly4	<= 0 ;
			otenker_align_dly5	<= 0 ;
			otenker_align_dly6	<= 0 ;
			otenker_align_dly7	<= 0 ;
			otenker_align_dly8	<= 0 ;
			otenker_align_dly9	<= 0 ;
			otenker_align_dly10	<= 0 ;			
		end
		else if (if_read_busy)begin
			otker_align_dly0	<= ker_read_cnt_ker ;
			otker_align_dly1	<= otker_align_dly0 ;
			otker_align_dly2	<= otker_align_dly1 ;
			otker_align_dly3	<= otker_align_dly2 ;
			otker_align_dly4	<= otker_align_dly3 ;
			otker_align_dly5	<= otker_align_dly4 ;
			otker_align_dly6	<= otker_align_dly5 ;
			otker_align_dly7	<= otker_align_dly6 ;
			otker_align_dly8	<= otker_align_dly7 ;
			otker_align_dly9	<= otker_align_dly8 ;
			otker_align_dly10	<= otker_align_dly9 ;
	
			otenker_align_dly0	<= ker_read_en_ker_cnt ;
			otenker_align_dly1	<= otenker_align_dly0 ;
			otenker_align_dly2	<= otenker_align_dly1 ;
			otenker_align_dly3	<= otenker_align_dly2 ;
			otenker_align_dly4	<= otenker_align_dly3 ;
			otenker_align_dly5	<= otenker_align_dly4 ;
			otenker_align_dly6	<= otenker_align_dly5 ;
			otenker_align_dly7	<= otenker_align_dly6 ;
			otenker_align_dly8	<= otenker_align_dly7 ;
			otenker_align_dly9	<= otenker_align_dly8 ;
			otenker_align_dly10	<= otenker_align_dly9 ;
		end
		else begin
			otker_align_dly0	<= otker_align_dly0 ;
			otker_align_dly1	<= otker_align_dly1 ;
			otker_align_dly2	<= otker_align_dly2 ;
			otker_align_dly3	<= otker_align_dly3 ;
			otker_align_dly4	<= otker_align_dly4 ;
			otker_align_dly5	<= otker_align_dly5 ;
			otker_align_dly6	<= otker_align_dly6 ;
			otker_align_dly7	<= otker_align_dly7 ;
			otker_align_dly8	<= otker_align_dly8 ;
			otker_align_dly9	<= otker_align_dly9 ;
			otker_align_dly10	<= otker_align_dly10 ;
	
			otenker_align_dly0	<= otenker_align_dly0 ;
			otenker_align_dly1	<= otenker_align_dly1 ;
			otenker_align_dly2	<= otenker_align_dly2 ;
			otenker_align_dly3	<= otenker_align_dly3 ;
			otenker_align_dly4	<= otenker_align_dly4 ;
			otenker_align_dly5	<= otenker_align_dly5 ;
			otenker_align_dly6	<= otenker_align_dly6 ;
			otenker_align_dly7	<= otenker_align_dly7 ;
			otenker_align_dly8	<= otenker_align_dly8 ;
			otenker_align_dly9	<= otenker_align_dly9 ;
			otenker_align_dly10	<= otenker_align_dly10 ;
		end
	end
		
//---- I/O Port assignment ----
assign dout_bi_0 = bias_sel_ot_0 ;
assign dout_bi_1 = bias_sel_ot_1 ;
assign dout_bi_2 = bias_sel_ot_2 ;
assign dout_bi_3 = bias_sel_ot_3 ;
assign dout_bi_4 = bias_sel_ot_4 ;
assign dout_bi_5 = bias_sel_ot_5 ;
assign dout_bi_6 = bias_sel_ot_6 ;
assign dout_bi_7 = bias_sel_ot_7 ;

assign bias_read_en_buf_sw = otenker_align_dly9 ;

assign dout_ke_0 = ksr_data_0 ;
assign dout_ke_1 = ksr_data_1 ;
assign dout_ke_2 = ksr_data_2 ;
assign dout_ke_3 = ksr_data_3 ;
assign dout_ke_4 = ksr_data_4 ;
assign dout_ke_5 = ksr_data_5 ;
assign dout_ke_6 = ksr_data_6 ;
assign dout_ke_7 = ksr_data_7 ;

//==============================================================================
//========    config Port assignment    ========
//==============================================================================

assign cfg_m0_scale		=	config_param01[63 -: 32];		//----    quantization config assignment    -----
assign cfg_index		=	config_param01[(63-32) -: 8];
assign cfg_z_of_weight	=	config_param01[(63-40) -: 16];
assign cfg_z3			=	config_param01[(63-56) -: 8];

assign cfg_total_row    =	config_param02[63 -: 9];		//YWJ
assign cfg_base_number  = 	config_param02[(47-2) -: 6];

assign cfg_atlchin 		= 	config_param03[(63):56]; 	//if_pd config
assign cfg_conv_switch 	= 	config_param03[(55-5):48];
assign cfg_mast_state 	= 	config_param03[(47-6):40];
assign cfg_pd_list_0 	= 	config_param03[(39-3):24];
assign cfg_pd_list_1 	= 	config_param03[(23-3):8];

assign cfg_pd_list_2 	= 	config_param04[(63-3):48];	//if_pd config
assign cfg_pd_list_3 	= 	config_param04[(47-3):32];	//YWJ
assign cfg_pd_list_4 	= 	config_param04[(31-5):16];
assign cfg_cnt_step_p1 	= 	config_param04[(15-5):8];
assign cfg_cnt_step_p2 	= 	config_param04[(7-5):0];


assign cfg_pdlf 			= config_param05[(63-0 )	-: 8];	// no use
assign cfg_pdrg 			= config_param05[(63-8 )	-: 8];	// no use
assign cfg_nor 				= config_param05[(63-8*2 )	-: 8];	// no use
assign cfg_stg0_nor_finum 	= config_param05[(63-8*4 + IFWSTG0_CNTBITS)	-:	IFWSTG0_CNTBITS	];	// if_w_config
assign cfg_stg0_pdb0_finum 	= config_param05[(63-8*5 + IFWSTG0_CNTBITS)	-:	IFWSTG0_CNTBITS	];	// if_w_config
assign cfg_stg0_pdb1_finum 	= config_param05[(63-8*6 + IFWSTG0_CNTBITS)	-:	IFWSTG0_CNTBITS	];	// if_w_config
assign cfg_stg1_eb_col 		= config_param05[(63-8*7 + IFWSTG1_CNTBITS)	-:	IFWSTG1_CNTBITS	];	// if_w_config
// assign cfg_pdlf 			= config_param05[(63-2):56];	//if_w config
// assign cfg_pdrg 			= config_param05[(55-2):48];
// assign cfg_nor 				= config_param05[(47-2):40];
// assign cfg_stg0_nor_finum 	= config_param05[(39-3):32];
// assign cfg_stg0_pdb0_finum 	= config_param05[(31-3):24];
// assign cfg_stg0_pdb1_finum 	= config_param05[(23-3):16];
// assign cfg_stg1_eb_col 		= config_param05[(15-5):8];

assign cfg_dincnt_finum 	= config_param06[(63-16+DATAIN_CNT_BITS) -: DATAIN_CNT_BITS];	//if_w config
assign cfg_rowcnt_finum 	= config_param06[(63-16) -: 8];

assign cfg_ifr_window 		= config_param07[63 -:	8];	//if_r config
assign cfg_ift_total_window = config_param07[55 -: 8];	//if_t config	no use

//----    kernel config    -----
assign cfg_kernum_sub1		= config_param08[63 -: BUF_TAG_BITS];
assign cfg_colout_sub1		= config_param08[(63-BUF_TAG_BITS		-(16-KER_ADDR_CNT_BITS) )	-: KER_ADDR_CNT_BITS];
assign cfg_normal_length	= config_param08[(63-BUF_TAG_BITS -16	-(16-KER_ADDR_CNT_BITS) )	-: KER_ADDR_CNT_BITS];
assign cfgin_top_starter	= config_param09[63 -:STARTER_BITS*5	];
assign cfgin_toppad_length	= config_param10[63 -:PADLEN_BITS*5		];
assign cfgin_botpad_length	= config_param11[63 -:PADLEN_BITS*5		];
assign cfg_kerw_buflength	= config_param12[(63 -16 +KER_ADDR_CNT_BITS ) -:KER_ADDR_CNT_BITS		];

//----    bias congfig    -----
assign cfg_bir_rg_prep		= config_param13[(63 -16 +BIAS_ADDR_BITS ) -:  BIAS_ADDR_BITS ]	;
assign cfg_biw_lengthsub1	= config_param13[(63 -32 +BIAS_ADDR_BITS ) -:  BIAS_ADDR_BITS ]	;

//----    output config    -----
assign cfg_ot_rnd_finsub1	= config_param14[(63  ) 					-: 	OTSRAM_ADDR_BITS ]	;		//YWJ
assign cfg_ot_tgpfnsub1		= config_param14[(63 - OTSRAM_ADDR_BITS )   -:  OTSRAM_ADDR_BITS ]	;		//YWJ
assign cfg_ot_tcolfnsub1	= config_param14[(63 - OTSRAM_ADDR_BITS*2 ) -:  OTSRAM_ADDR_BITS ]	;		//YWJ
assign cfg_ot_tchafnsub1	= config_param15[(63  ) 					-:  OTSRAM_ADDR_BITS ]	;		//YWJ
assign cfg_ot_sft_gp		= config_param15[(63 - OTSRAM_ADDR_BITS )   -:  OTSRAM_ADDR_BITS ]	;		//YWJ
assign cfg_ot_sft_colpra	= config_param15[(63 - OTSRAM_ADDR_BITS*2 ) -:  OTSRAM_ADDR_BITS ]	;		//YWJ

endmodule
