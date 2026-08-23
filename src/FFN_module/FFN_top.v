// ============================================================================
// Designer : Chao_Ping Liu
// Create   : 2025.06.26
// Ver      : 1.0
// Func     : FFN top module 
//  	----parameter reset active low -- https://youtu.be/KyQuVydW1n8
//  	----high fanout pin fixed by DC synthesis, do not code buffer.
//  	----FFN_get_ins module : distinguish data or instruction for this time.
//  	----signal port naming : should not use common port name for every top module port naming.
//  	----output signal tips : should not use output signal for flow controlling like "busy".
// Log		: 
// ============================================================================
//----    define for testing    -----
// `define FPGA_SRAM_SETTING
// `define FPGA_ILA_CHK_SETTING

module FFN_top #(
        parameter TBITS = 64
    ,   parameter TBYTE = 8
)(
        clk
    ,   resetn

	,	FFN_done

	,   M_AXIS_S2MM_TREADY

	,	isif_data_dout
	,	isif_last_dout
	,	isif_empty_n
	,	isif_strb_dout
	,	isif_user_dout
	,	isif_read

	,	osif_full_n
	,	ot2fifo_write
	,	ot2fifo_data
	,	ot2fifo_last
	,	osif_strb_din
	,	osif_user_din

`ifdef FPGA_ILA_CHK_SETTING

`endif

);

	localparam MAST_FSM_BITS 	= 3;

	localparam IF_SRAM_ADDR_BITS	= 9		;
	localparam IF_SRAM_WORDS_BITS	= 64	;

	localparam BIAS_SRAM_ADDR_BITS	= 9		;
	localparam BIAS_SRAM_WORDS_BITS	= 32	;

	localparam KER_SRAM_ADDR_BITS	= 9		;
	localparam KER_SRAM_WORDS_BITS	= 64	;

	localparam OT_SRAM_ADDR_BITS	= 9		;
	localparam OT_SRAM_WORDS_BITS	= 64	;

    localparam KER_ADDR_BITS	=	10	;
    localparam STARTER_BITS		=	8	;
    localparam PADLEN_BITS		=	8	;
    localparam BUF_TAG_BITS 	=	8	;

    localparam PEBLKROW_NUM		=	1	;	// PE block number
	localparam PEBLKCOL_NUM		=	16	;	// PE block number (Phase 1b: 8 -> 16 for ~2x single-token speed)

    localparam CNTSTP_WIDTH			= 3		; 		//config input setting
    localparam IFWSTG0_CNTBITS		= 7		;		//config input setting
    localparam IFWSTG1_CNTBITS		= 7		;		//config input setting
    localparam DATAIN_CNT_BITS		= 16	;		//config input setting

    localparam IFMAP_SRAM_ADDBITS	= 13 ;
    localparam IFMAP_SRAM_DATA_WIDTH = 64;
    localparam BIAS_WORD_LENGTH =	32	;
    localparam BIAS_ADDR_BITS 	=	9	;

    parameter RESET_ACTIVE_LOW = 1;
    wire reset ;

    // ============================= I/O port Declare ===============================
    
    input wire clk	;
    input wire resetn	;

	output wire	FFN_done	;

    //-- input fifo signal (driven by Transformer_top) --
    input [TBITS-1: 0 ]	isif_data_dout			;
    input 				isif_last_dout			;
    input 				isif_empty_n			;
    input [TBYTE-1: 0 ]	isif_strb_dout			;
    input 				isif_user_dout			;
    output 				isif_read				;
    //-- output fifo signal (to Transformer_top) --
    input 					osif_full_n				;
    output 					ot2fifo_write			;
    output [TBITS-1: 0 ]	ot2fifo_data			;
    output 					ot2fifo_last			;
    output [TBYTE-1: 0 ]	osif_strb_din			;
    output 					osif_user_din			;

    // AXI-Stream now terminates in Transformer_top; only S2MM ready is still needed
    // by FFN_ot_top for output back-pressure.
    input  wire             M_AXIS_S2MM_TREADY	;

    //-----------------------------------------------------------------------------
    //----    FPGA ILA Check I/O    -----
    `ifdef FPGA_ILA_CHK_SETTING
    
    `endif 
    //-----------------------------------------------------------------------------

    //-- input fifo signal --
    wire [TBITS-1: 0 ]	isif_data_dout			;
    wire 				isif_last_dout			;
    wire 				isif_empty_n			;
    wire [TBYTE-1: 0 ]	isif_strb_dout			;
    wire 				isif_user_dout			;
    wire 				isif_read				;
    //-- output fifo signal --
    wire 				osif_full_n				;
    wire 				ot2fifo_write			;
    wire [TBITS-1: 0 ]	ot2fifo_data			;
    wire 				ot2fifo_last			;
    wire [TBYTE-1: 0 ]	osif_strb_din			;
    wire 				osif_user_din			;

    //---- schedule ctrl ----
    wire if_write_done		;
    wire if_write_busy		;
    wire if_write_start		;
    wire if_read_done		;
    wire if_read_busy		;
    wire if_read_start		;

    wire ker_write_start	;
    wire ker_write_busy		;
    wire ker_write_done		;
    wire ker_read_start		;
    wire ker_read_busy		;
    wire ker_read_done		;
	wire ker_read_tile_done	;
	wire ker_read_last		;
	wire ker_write_tile_done	;

    wire bias_write_start	;
    wire bias_write_busy	;
    wire bias_write_done	;
    wire bias_read_start	;
    wire bias_read_busy		;
    wire bias_read_done		;

	wire fsld_done	;
	wire base_done	;

	//---- get instruction ----
	wire empty_n_from_gi	;
	wire read_for_gi		;
	wire gi_start			;

	wire [TBITS-1:0] config_param00	;
	wire [TBITS-1:0] config_param01	;
	wire [TBITS-1:0] config_param02	;
	wire [TBITS-1:0] config_param03	;
	wire [TBITS-1:0] config_param04	;
	wire [TBITS-1:0] config_param05	;
	wire [TBITS-1:0] config_param06	;
	wire [TBITS-1:0] config_param07	;
	wire [TBITS-1:0] config_param08	;
	wire [TBITS-1:0] config_param09	;
	wire [TBITS-1:0] config_param10	;
	wire [TBITS-1:0] config_param11	;
	wire [TBITS-1:0] config_param12	;
	wire [TBITS-1:0] config_param13	;
	wire [TBITS-1:0] config_param14	;
	wire [TBITS-1:0] config_param15	;

	//---- fsm ----
	wire [MAST_FSM_BITS-1:0]	fsm_mast_state	;

	//---- FFN_d_empn_rd_mux ----
	wire if_write_empty_n	;
	wire ker_write_empty_n	;
	wire bias_write_empty_n	;

	//---- input ----
	wire if_write_read	;
	wire if_write_en	;

	wire [TBITS-1:0]	dout_if_sram_0	;
	wire if_read_valid	;
	wire if_read_final	;

	wire [2:0]						cfg_if_token_nums_sub1	;
	wire [IF_SRAM_ADDR_BITS-1:0] 	cfg_if_totalsize_sub1	;
	wire [IF_SRAM_ADDR_BITS-1:0] 	cfg_if_length_sub1		;

	//---- bias ----
	wire bias_write_read	;
	wire bias_write_en		;

	wire [PEBLKCOL_NUM*BIAS_SRAM_WORDS_BITS-1:0] dout_bias_flat	;

	wire [BIAS_SRAM_ADDR_BITS-1:0] 	cfg_bias_once_load_size_sub1	;

	//---- kernel ----
	wire ker_write_read	;
	wire ker_write_en	;

	wire [PEBLKCOL_NUM*KER_SRAM_WORDS_BITS-1:0] dout_ker_flat	;
	wire ker_read_final	;

	wire [KER_SRAM_ADDR_BITS-1:0] 	cfg_ker_length_sub1	;
	wire [5:0]						cfg_ker_tile_size_sub1 ;
	wire [1:0]						cfg_ker_tile_readnums_sub1 ;

	//---- pe ----
	wire [PEBLKROW_NUM * TBITS-1: 0]	allq_dout		;
	wire [PEBLKROW_NUM-1: 0]	        allvalid_dout	;

	//---- output ----
	wire							ot_buf_ready		;

	wire [OT_SRAM_ADDR_BITS-1:0] 	cfg_ot_rnd_finsub1	;
	wire [OT_SRAM_ADDR_BITS-1:0]	cfg_ot_tgpfnsub1	;
	wire [OT_SRAM_ADDR_BITS-1:0]	cfg_ot_tcolfnsub1	;
	wire [OT_SRAM_ADDR_BITS-1:0]	cfg_ot_tchafnsub1	;
	wire [OT_SRAM_ADDR_BITS-1:0]	cfg_ot_sft_gp		;
	wire [OT_SRAM_ADDR_BITS-1:0]	cfg_ot_sft_colpra	;
	wire [OT_SRAM_ADDR_BITS-1:0]	cfg_ot_sft_col		;

    // ===========================================================================
    // =======		instance 	==================================================
    // ===========================================================================

	//----    input AXI-Stream fifo lives in Transformer_top now    -----
	// INPUT_STREAM_if	#(
	// 		.TBITS	(	TBITS	)
	// 	,	.TBYTE	(	TBYTE	)
	// )axififo_in(
	// 	// AXI4-Stream singals
	// 		.ACLK       (	clk		)
	// 	,	.ARESETN    (	resetn	)
	// 	,	.TVALID     (	S_AXIS_MM2S_TVALID	)
	// 	,	.TREADY     (	S_AXIS_MM2S_TREADY	)
	// 	,	.TDATA      (	S_AXIS_MM2S_TDATA	)
	// 	,	.TKEEP      (	S_AXIS_MM2S_TKEEP	)
	// 	,	.TLAST      (	S_AXIS_MM2S_TLAST	)
	// 	// ,	.TUSER      (   1'b0                )

	// 	// User signals
	// 	,	.isif_data_dout         (	isif_data_dout		)
	// 	,	.isif_strb_dout         (	isif_strb_dout		)
	// 	,	.isif_last_dout         (	isif_last_dout		)
	// 	,	.isif_user_dout         (	isif_user_dout		)
	// 	,	.isif_empty_n           (	isif_empty_n		)
	// 	,	.isif_read				(	isif_read			)
	// );

    FFN_get_ins #(
			.TBITS	(	TBITS	)
		,	.TBYTE	(	TBYTE	)
	)get_ins_inst(	
			.clk 	(	clk		)
		,	.reset 	(	reset	)

		,	.fifo_data_din		(	isif_data_dout		)
		,	.fifo_strb_din		(	isif_strb_dout		)
		,	.fifo_last_din		(	isif_last_dout		)
		,	.fifo_user_din		(	isif_user_dout		)
		,	.fifo_empty_n_din	(	isif_empty_n		)
		,	.fifo_read_dout		(	isif_read			)

		,	.ds_empty_n			(	empty_n_from_gi		)
		,	.ds_read			(	read_for_gi			)

		,	.instr_code00	(	config_param00		)
		,	.instr_code01	(	config_param01		)
		,	.instr_code02	(	config_param02		)
		,	.instr_code03	(	config_param03		)
		,	.instr_code04	(	config_param04		)
		,	.instr_code05	(	config_param05		)
		,	.instr_code06	(	config_param06		)
		,	.instr_code07	(	config_param07		)
		,	.instr_code08	(	config_param08		)
		,	.instr_code09	(	config_param09		)
		,	.instr_code10	(	config_param10		)
		,	.instr_code11	(	config_param11		)
		,	.instr_code12	(	config_param12		)
		,	.instr_code13	(	config_param13		)
		,	.instr_code14	(	config_param14		)
		,	.instr_code15	(	config_param15		)

		,	.mast_curr_state	(	fsm_mast_state	)
		,	.start_reg			(	gi_start		)
	);

    FFN_fsm64 fsm64_inst(
			.clk	(	clk		)
		,	.reset	(	reset	)

		,	.start				(	gi_start		)
		,	.fsld_done 			(	fsld_done		)
		,	.base_done 			(	base_done		)
		,	.outmast_curr_state (	fsm_mast_state	)
	);

	FFN_schedule_ctrl #(
			.TBITS	(	TBITS	)
		,	.TBYTE	(	TBYTE	)
	)schedule_ctrl_inst(
			.clk	(	clk		)
		,	.reset	(	reset	)
		
		,	.mast_curr_state	(	fsm_mast_state	)

		,	.if_write_start	(	if_write_start	)
		,	.if_write_busy	(	if_write_busy	)
		,	.if_write_done	(	if_write_done	)

		,	.if_read_start	(	if_read_start	)
		,	.if_read_busy 	(	if_read_busy	)
		,	.if_read_done	(	if_read_done	)

		,	.ker_write_start	(	ker_write_start	)
		,	.ker_write_busy		(	ker_write_busy	)
		,	.ker_write_done		(	ker_write_done	)
		,	.ker_write_last		(	ker_write_last	)
		,	.ker_write_tile_done	(	ker_write_tile_done	)

		,	.ker_read_start		(	ker_read_start		)
		,	.ker_read_busy 		(	ker_read_busy		)
		,   .ker_read_done		(	ker_read_done		)
		,	.ker_read_tile_done	(	ker_read_tile_done	)

		,	.bias_write_start	(	bias_write_start	)
		,	.bias_write_busy	(	bias_write_busy		)
		,	.bias_write_done	(	bias_write_done		)

		,	.bias_read_start	(	bias_read_start		)
		,	.bias_read_busy		(	bias_read_busy		)
		,	.bias_read_done		(	bias_read_done		)

		,	.chk_ot_ready	(	ot_buf_ready	)
			
		,	.fsld_done	(	fsld_done	)
		,	.base_done	(	base_done	)

	);

	FFN_d_empn_rd_mux d_empn_rd_mux_inst(
			.if_write_empty_n	(	if_write_empty_n	)
		,	.ker_write_empty_n	(	ker_write_empty_n	)
		,	.bias_write_empty_n	(	bias_write_empty_n	)

		,	.if_write_read		(	if_write_read		)
		,	.ker_write_read		(	ker_write_read		)
		,	.bias_write_read	(	bias_write_read		)

		,   .empty_n_from_gi	(	empty_n_from_gi		)
		,   .read_for_gi		(	read_for_gi			)

		,   .mast_curr_state	(	fsm_mast_state		)

		,   .if_write_en	(	if_write_en		)
		,   .ker_write_en	(	ker_write_en	)
		,   .bias_write_en	(	bias_write_en	)

	);

	FFN_if_top #(
			.IF_SRAM_WORDS_BITS (	IF_SRAM_WORDS_BITS	)
		,	.IF_SRAM_ADDR_BITS	(	IF_SRAM_ADDR_BITS	)
	)if_top_inst(
			.clk	(	clk		)
		,	.reset	(	reset	)	

		,	.if_write_data_din		(	isif_data_dout		)
		,	.if_write_empty_n_din	(	if_write_empty_n	)
		,	.if_write_read_dout		(	if_write_read		)

		,	.if_write_start	(	if_write_start	)
		,	.if_write_busy	(	if_write_busy	)
		,	.if_write_done	(	if_write_done	)
		,	.if_write_en	(	if_write_en		)
				
		,	.if_read_start	(	if_read_start	)
		,	.if_read_busy	(	if_read_busy	)
		,	.if_read_done	(	if_read_done	)

		,	.dout_if_sram_0	(	dout_if_sram_0	)
		,	.if_read_valid	(	if_read_valid	)

		,   .cfg_if_totalsize_sub1	(	cfg_if_totalsize_sub1	)
	);

	FFN_ker_top #(
			.TBITS	(	TBITS	)
		,	.TBYTE	(	TBYTE	)
		,	.KER_SRAM_ADDR_BITS		(	KER_SRAM_ADDR_BITS	)
		,	.KER_SRAM_WORDS_BITS	(	KER_SRAM_WORDS_BITS	)
		,	.NUM_BANK				(	PEBLKCOL_NUM		)
	)ker_top_inst(
			.clk	(	clk		)
		,	.reset	(	reset	)

		,	.ker_write_data_din		(	isif_data_dout			)
		,	.ker_write_empty_n_din	(	ker_write_empty_n		)
		,	.ker_write_read_dout	(	ker_write_read			)

		,   .mast_curr_state		(	fsm_mast_state			)

		,	.ker_write_start		(	ker_write_start			)
		,	.ker_write_busy			(	ker_write_busy			)
		,	.ker_write_done			(	ker_write_done			)
		,	.ker_write_en			(	ker_write_en			)
		,	.ker_write_last			(	ker_write_last			)
		,	.ker_write_tile_done	(	ker_write_tile_done		)

		,	.ker_read_start			(	ker_read_start			)
		,	.ker_read_busy			(	ker_read_busy			)
		,	.ker_read_done			(	ker_read_done			)
		,	.ker_read_tile_done		(	ker_read_tile_done		)

		,	.dout_ker_flat	(	dout_ker_flat	)
		,	.ker_read_final	(	ker_read_final	)

		,	.cfg_ker_length_sub1		(	cfg_ker_length_sub1			)
		,	.cfg_ker_readnums			(	cfg_if_token_nums_sub1		)
		,	.cfg_ker_tile_readnums_sub1	(	cfg_ker_tile_readnums_sub1	)
		,	.cfg_ker_tile_size_sub1		(	cfg_ker_tile_size_sub1		)
	);

	FFN_bias_top #(
			.TBITS	(	TBITS	)
		,	.TBYTE	(	TBYTE	)
		,	.BIAS_SRAM_ADDR_BITS  ( BIAS_SRAM_ADDR_BITS  )
		,	.BIAS_SRAM_DATA_WIDTH ( BIAS_SRAM_WORDS_BITS )
		,	.NUM_BANK             ( PEBLKCOL_NUM         )
	)bias_top_inst(
			.clk	(	clk		)
		,	.reset	(	reset	)

		,	.bias_write_data_din		(	isif_data_dout			)
		,	.bias_write_empty_n_din		(	bias_write_empty_n		)
		,	.bias_write_read_dout		(	bias_write_read			)

		,	.bias_write_start			(	bias_write_start	)
		,	.bias_write_busy			(	bias_write_busy		)
		,	.bias_write_done			(	bias_write_done		)
		,	.bias_write_en				(	bias_write_en		)

		,	.bias_read_start		(	bias_read_start		)
		,	.bias_read_busy			(	bias_read_busy		)
		,	.bias_read_done			(	bias_read_done		)

		,	.dout_bias_flat ( dout_bias_flat )

		,	.cfg_bias_once_load_size_sub1	(	cfg_bias_once_load_size_sub1	)
		,	.cfg_bias_readnums				( 	cfg_if_token_nums_sub1			)
	);

	FFN_pe_top #(
			.TBITS	(	TBITS	)
		,	.TBYTE	(	TBYTE	)
		,	.PEBLKROW_NUM ( PEBLKROW_NUM )
		,	.PEBLKCOL_NUM ( PEBLKCOL_NUM )
	)pe_top_inst(
			.clk	(	clk		)
		,	.reset	(	reset	)

		,	.cfg_m0_scale			(	config_param01[63 -: 32]	)	// m0 scale
		,	.cfg_index				(	config_param01[31 -: 8]		)	// index
		,	.cfg_z_of_weight		(	config_param01[23 -: 16]	)	// z of weight
		,	.cfg_z3					(	config_param01[7  -: 8]		)	// z3

		,	.flat_act_din		(	dout_if_sram_0				)
		,	.flat_ker_din		(	dout_ker_flat				)
		,	.flat_bias_din		(	dout_bias_flat				)
		,	.flat_valid_din		(	if_read_valid				)
		,	.flat_final_din		(	ker_read_final				)

		,	.allq_dout			(	allq_dout					)
		,	.allvalid_dout		(	allvalid_dout				)
	);

	FFN_ot_top #(
			.TBITS	(	TBITS	)
		,	.TBYTE	(	TBYTE	)
		,	.PEBLKROW_NUM	(	PEBLKROW_NUM		)
		,	.SRAM_DATA_BITS	(	OT_SRAM_WORDS_BITS	)
		,	.SRAM_ADDR_BITS	(	OT_SRAM_ADDR_BITS	)
	)ot_top_inst(
			.clk	(	clk		)
		,   .reset	(	reset	)

		,	.FFN_done			(	FFN_done			)

		,	.din_s2mm_tready	(	M_AXIS_S2MM_TREADY	)
		,	.fifo_full_n		(	osif_full_n			)
		,	.fifo_write			(	ot2fifo_write		)
		,	.fifo_last			(	ot2fifo_last		)
		,	.fifo_data			(	ot2fifo_data		)

		,	.ot_ready	(	ot_buf_ready	)

		,	.valid_din	(	allvalid_dout	)
		,	.data_din	(	allq_dout		)

		,	.cfg_ker_tile_readnums_sub1	(	cfg_ker_tile_readnums_sub1	)

		,	.cfg_ot_rnd_finsub1	(	cfg_ot_rnd_finsub1	)
		,	.cfg_ot_tgpfnsub1	(	cfg_ot_tgpfnsub1	)
		,	.cfg_ot_tcolfnsub1	(	cfg_ot_tcolfnsub1	)
		,	.cfg_ot_tchafnsub1	(	cfg_ot_tchafnsub1	)
		,	.cfg_ot_sft_gp		(	cfg_ot_sft_gp		)
		,	.cfg_ot_sft_colpra	(	cfg_ot_sft_colpra	)
		,	.cfg_ot_sft_col		(	cfg_ot_sft_col		)
	) ;

    //----    output AXI-Stream fifo lives in Transformer_top now    -----
	// OUTPUT_STREAM_if #(
	// 		.TBITS  (   TBITS   )
	// 	,	.TBYTE  (   TBYTE   )
	// )axififo_out(
	// 		.ACLK       (   clk 	)
	// 	,	.ARESETN    (   resetn  )
	// 	,	.TVALID     (   M_AXIS_S2MM_TVALID  )
	// 	,	.TREADY     (   M_AXIS_S2MM_TREADY  )
	// 	,	.TDATA      (   M_AXIS_S2MM_TDATA   )
	// 	,	.TKEEP      (   M_AXIS_S2MM_TKEEP   )
	// 	,	.TLAST      (   M_AXIS_S2MM_TLAST   )
	// 	// ,   .TUSER      (                       )

	// 	,	.osif_data_din  (   ot2fifo_data   	)
	// 	,	.osif_strb_din  (   8'hff           )
	// 	,	.osif_last_din  (   ot2fifo_last   	)
	// 	,	.osif_user_din  (   1'b0            )
	// 	,	.osif_full_n    (   osif_full_n     )
	// 	,	.osif_write     (   ot2fifo_write   )
	// );

	//----    strb/user are constants at Transformer level    -----
	assign osif_strb_din = 8'hff ;
	assign osif_user_din = 1'b0  ;

  	// yolo_rst_if_U
    yolo_rst_if #(
			.RESET_ACTIVE_LOW ( RESET_ACTIVE_LOW ) 
	)yolo_rst_if_U(
			.dout ( reset ) 
		,	.din ( resetn ) 
	);

	assign cfg_if_token_nums_sub1 		= config_param02[11:9] ;
	assign cfg_if_totalsize_sub1 		= config_param02[8:0];	// maximum number is 512 means FFN1 can load 8 tokens FFN2 can load 2 token2
	assign cfg_if_length_sub1 			= cfg_ker_length_sub1;
	assign cfg_bias_once_load_size_sub1 = config_param03[8:0];
	assign cfg_ker_length_sub1 			= config_param04[8:0]; // one col kernel need the numbers of addr FFN1 can load 8 col kernel FFN2 can load 2 col kernel
	assign cfg_ker_tile_size_sub1 		= config_param04[14:9] ; // means one token tile output need how much addr
	assign cfg_ker_tile_readnums_sub1 	= config_param04[16:15] ; // FFN1 4-1 FFN2 1-1

	//----    output config    -----
	assign cfg_ot_rnd_finsub1	= config_param14[(63  ) 					-: 	OT_SRAM_ADDR_BITS ]		;
	assign cfg_ot_tgpfnsub1		= config_param14[(63 - OT_SRAM_ADDR_BITS )   -:  OT_SRAM_ADDR_BITS ]	;
	assign cfg_ot_tcolfnsub1	= config_param14[(63 - OT_SRAM_ADDR_BITS*2 ) -:  OT_SRAM_ADDR_BITS ]	;
	assign cfg_ot_tchafnsub1	= config_param15[(63  ) 					-:  OT_SRAM_ADDR_BITS ]		;
	assign cfg_ot_sft_gp		= config_param15[(63 - OT_SRAM_ADDR_BITS )   -:  OT_SRAM_ADDR_BITS ]	;
	assign cfg_ot_sft_colpra	= config_param15[(63 - OT_SRAM_ADDR_BITS*2 ) -:  OT_SRAM_ADDR_BITS ]	;
	assign cfg_ot_sft_col		= config_param15[(63 - OT_SRAM_ADDR_BITS*3 ) -:  OT_SRAM_ADDR_BITS ]	;

endmodule