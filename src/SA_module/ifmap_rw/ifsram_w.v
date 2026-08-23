// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2022.11.09
// Ver      : 3.0 (Decoupled Dual-Bank SRAM for Parallel 2-Row Read Support)
// Func     : input feature sram write module
// ============================================================================

module ifsram_w
#(
		parameter TBITS = 64 
	,	parameter TBYTE = 8
	,	parameter IFMAP_SRAM_ADDBITS = 11 			
	,	parameter IFMAP_SRAM_DATA_WIDTH = 64		
	,	parameter DATAIN_CNT_BITS = 9				
	,	parameter IFWSTG0_CNTBITS = 5					
	,	parameter IFWSTG1_CNTBITS = 3					
	
)(
 		clk			
	,	reset		

	,	ifstore_data_din		
	,	ifstore_empty_n_din		
	,	ifstore_read_dout
	,	if_read_last
	,	rdwd_done	

	,	if_write_done 			
	,	if_write_busy 			
	,	if_write_start			
	,	if_write_en			
	,	wr_row_parity

	,	dout_wrb0_cen	
	,	dout_wrb1_cen	
	,	dout_wrb2_cen	
	,	dout_wrb3_cen	
	,	dout_wrb4_cen	
	,	dout_wrb5_cen	
	,	dout_wrb6_cen	
	,	dout_wrb7_cen	

	,	dout_wrb0_wen	
	,	dout_wrb1_wen	
	,	dout_wrb2_wen	
	,	dout_wrb3_wen	
	,	dout_wrb4_wen	
	,	dout_wrb5_wen	
	,	dout_wrb6_wen	
	,	dout_wrb7_wen	

	,	dout_wrb0_addr	
	,	dout_wrb1_addr	
	,	dout_wrb2_addr	
	,	dout_wrb3_addr	
	,	dout_wrb4_addr	
	,	dout_wrb5_addr	
	,	dout_wrb6_addr	
	,	dout_wrb7_addr	

	,	dout_wrb0_data	
	,	dout_wrb1_data	
	,	dout_wrb2_data	
	,	dout_wrb3_data	
	,	dout_wrb4_data	
	,	dout_wrb5_data	
	,	dout_wrb6_data	
	,	dout_wrb7_data	

	//config input setting
	,	cfg_atlchin
	,	cfg_conv_switch
	,	cfg_mast_state
	,	cfg_stg0_nor_finum
	,	cfg_stg0_pdb0_finum
	,	cfg_stg0_pdb1_finum
	,	cfg_stg1_eb_col
	,	cfg_dincnt_finum
	,	cfg_rowcnt_finum

);

//----------------------------------------------------------------------------
//---------------		I/O	Declare		--------------------------------------
//----------------------------------------------------------------------------
input	wire 				clk		;
input	wire 				reset	;
input	wire [TBITS-1: 0 ]	ifstore_data_din		;
input	wire 				ifstore_empty_n_din		;
input	wire 				if_read_last			;
input	wire				rdwd_done				;
output	reg 				ifstore_read_dout		;

output 	reg 				if_write_done		;	
output	reg					if_write_busy		;
output	reg					if_write_en		;	
input	wire				if_write_start			;
output  wire                wr_row_parity           ;

output	wire dout_wrb0_cen , dout_wrb1_cen , dout_wrb2_cen , dout_wrb3_cen , dout_wrb4_cen , dout_wrb5_cen , dout_wrb6_cen , dout_wrb7_cen	;
output	wire dout_wrb0_wen , dout_wrb1_wen , dout_wrb2_wen , dout_wrb3_wen , dout_wrb4_wen , dout_wrb5_wen , dout_wrb6_wen , dout_wrb7_wen	;
output	wire [IFMAP_SRAM_ADDBITS-1 : 0]dout_wrb0_addr , dout_wrb1_addr , dout_wrb2_addr , dout_wrb3_addr 
										, dout_wrb4_addr , dout_wrb5_addr , dout_wrb6_addr , dout_wrb7_addr	;
output	wire [TBITS-1 : 0]dout_wrb0_data , dout_wrb1_data , dout_wrb2_data , dout_wrb3_data 
							, dout_wrb4_data , dout_wrb5_data , dout_wrb6_data , dout_wrb7_data	;
//config input setting
input	wire	[8-1:0]		cfg_atlchin ;
input	wire	[3-1:0] 	cfg_conv_switch ;
input	wire	[3-1:0]		cfg_mast_state	;
input	wire	[IFWSTG0_CNTBITS-1 :0]	cfg_stg0_nor_finum	;
input	wire	[IFWSTG0_CNTBITS-1 :0]	cfg_stg0_pdb0_finum	;
input	wire	[IFWSTG0_CNTBITS-1 :0]	cfg_stg0_pdb1_finum	;
input	wire	[IFWSTG1_CNTBITS-1 :0]	cfg_stg1_eb_col		;
input	wire	[DATAIN_CNT_BITS-1 :0]	cfg_dincnt_finum	;
input	wire	[3-1 :0]	cfg_rowcnt_finum	;

//----    IW FSM for busy done and en signal declare    -----
localparam IW_IDLE	= 3'd0;
localparam IW_DLOD	= 3'd1;	
localparam IW_WABF	= 3'd2;
localparam IW_RST	= 3'd3;
localparam IW_DONE	= 3'd4;	
localparam IW_SECLOD	= 3'd5;
// NOTE: an orphan current_state/next_state pair used to be declared here --
//       nothing drove them and nothing read them. The real per-bank state
//       lives in wrb0..7_current_state below.
localparam LEFT 	= 3'd1;
localparam NORMAL 	= 3'd2;
localparam RIGH 	= 3'd3;

//-------  input data stream ------
reg [DATAIN_CNT_BITS-1:0]			dr_num_dly0	;
reg [DATAIN_CNT_BITS-1:0]			dr_num_dly1	;
reg [DATAIN_CNT_BITS-1:0]			dr_num_dly2	;
reg [DATAIN_CNT_BITS-1:0]			dr_num_dly3	;
reg [DATAIN_CNT_BITS-1:0]			dr_num_dly4	;
reg [DATAIN_CNT_BITS-1:0]			dr_num_dly5	;
reg [DATAIN_CNT_BITS-1:0]			dr_num_dly6	;
reg [DATAIN_CNT_BITS-1:0]			dr_num_dly7	;

reg [TBITS-1:0] 	dr_data_dly0	;
reg [TBITS-1:0] 	dr_data_dly1	;
reg [TBITS-1:0] 	dr_data_dly2	;
reg [TBITS-1:0] 	dr_data_dly3	;
reg [TBITS-1:0] 	dr_data_dly4	;
reg [TBITS-1:0] 	dr_data_dly5	;
reg [TBITS-1:0] 	dr_data_dly6	;
reg [TBITS-1:0] 	dr_data_dly7	;

reg valid_drdata ;
reg valid_drdata_dly0 ;
reg valid_drdata_dly1 ;
reg valid_drdata_dly2 ;
reg valid_drdata_dly3 ;
reg valid_drdata_dly4 ;
reg valid_drdata_dly5 ;
reg valid_drdata_dly6 ;
reg valid_drdata_dly7 ;
reg valid_drdata_dly8 ;
reg valid_drdata_dly9 ;

localparam CNT_ROW_BITS = 3 ;
localparam ROW_CNT_START = 'd0 ;
wire [CNT_ROW_BITS -1 : 0]	row_count	;
wire row_last ;
wire en_row_count ;
reg		[ DATAIN_CNT_BITS -1 : 0 ] cnt00 ;

reg [2:0] write_state,next_write_state;
reg wr_sec_start;
wire	[TBITS -1 : 0 ] 			align_data_in 	;
wire	[ DATAIN_CNT_BITS -1 : 0 ]	align_din_index ;
wire								align_din_valid ;

reg [1:0] write_row_cnt;
reg next_wrb_idle2start;

localparam WR_IDLE 		= 3'd0;
localparam WR_NORMAL	= 3'd1;
localparam WR_LEFT		= 3'd2;
localparam WR_RIGH		= 3'd3;
localparam WR_DONE		= 3'd4;

localparam 	wr_srad_finalnum_para	= 10'd127;	

wire [IFWSTG0_CNTBITS-1:0]	wrb0_cnt00 , wrb1_cnt00 , wrb2_cnt00 , wrb3_cnt00 , wrb4_cnt00 , wrb5_cnt00 , wrb6_cnt00 , wrb7_cnt00 ;
wire [IFWSTG0_CNTBITS-1:0]	wrb0_cnt01 , wrb1_cnt01 , wrb2_cnt01 , wrb3_cnt01 , wrb4_cnt01 , wrb5_cnt01 , wrb6_cnt01 , wrb7_cnt01 ;
wire wrb0_stg0_en , wrb1_stg0_en , wrb2_stg0_en , wrb3_stg0_en , wrb4_stg0_en , wrb5_stg0_en , wrb6_stg0_en , wrb7_stg0_en ;
wire wrb0_stg1_en , wrb1_stg1_en , wrb2_stg1_en , wrb3_stg1_en , wrb4_stg1_en , wrb5_stg1_en , wrb6_stg1_en , wrb7_stg1_en ;
wire wrb0_stg0_last , wrb1_stg0_last , wrb2_stg0_last , wrb3_stg0_last , wrb4_stg0_last , wrb5_stg0_last , wrb6_stg0_last , wrb7_stg0_last ;
wire wrb7_stg1_last ;	// only bank7's stg1_last is read (wrb_end_check)
wire [IFMAP_SRAM_ADDBITS-1:0] wrb0_sram_addrcnt , wrb1_sram_addrcnt , wrb2_sram_addrcnt , wrb3_sram_addrcnt , wrb4_sram_addrcnt
	, wrb5_sram_addrcnt , wrb6_sram_addrcnt , wrb7_sram_addrcnt;
// wrb0..7_sram_addrcnt_last : unread on all 8 banks -- removed, taps left open
wire [IFWSTG0_CNTBITS-1 :0] wrb0_cnt00_finalnum ;
wire [IFWSTG1_CNTBITS-1 :0] wrb0_cnt01_finalnum ;

wire [IFWSTG0_CNTBITS-1 :0] wrb1_cnt00_finalnum ;
wire [IFWSTG1_CNTBITS-1 :0] wrb1_cnt01_finalnum ;
wire [IFWSTG0_CNTBITS-1 :0] wrb2_cnt00_finalnum ;
wire [IFWSTG1_CNTBITS-1 :0] wrb2_cnt01_finalnum ;

wire [IFWSTG0_CNTBITS-1 :0] wrb3_cnt00_finalnum ;
wire [IFWSTG1_CNTBITS-1 :0] wrb3_cnt01_finalnum ;
wire [IFWSTG0_CNTBITS-1 :0] wrb4_cnt00_finalnum ;
wire [IFWSTG1_CNTBITS-1 :0] wrb4_cnt01_finalnum ;

wire [IFWSTG0_CNTBITS-1 :0] wrb5_cnt00_finalnum ;
wire [IFWSTG1_CNTBITS-1 :0] wrb5_cnt01_finalnum ;
wire [IFWSTG0_CNTBITS-1 :0] wrb6_cnt00_finalnum ;
wire [IFWSTG1_CNTBITS-1 :0] wrb6_cnt01_finalnum ;

wire [IFWSTG0_CNTBITS-1 :0] wrb7_cnt00_finalnum ;
wire [IFWSTG1_CNTBITS-1 :0] wrb7_cnt01_finalnum ;
wire 	[IFMAP_SRAM_ADDBITS-1:0] wr_cpr_0	;	
wire 	[IFMAP_SRAM_ADDBITS-1:0] wr_cpr_1	;	
wire 	[IFMAP_SRAM_ADDBITS-1:0] wr_cpr_2	;	
wire 	[IFMAP_SRAM_ADDBITS-1:0] wr_cpr_3	;
wire 	[IFMAP_SRAM_ADDBITS-1:0] wr_cpr_4	;	
wire 	[IFMAP_SRAM_ADDBITS-1:0] wr_cpr_5	;	
wire 	[IFMAP_SRAM_ADDBITS-1:0] wr_cpr_6	;	
wire 	[IFMAP_SRAM_ADDBITS-1:0] wr_cpr_7	;

wire row_fin_index	;	

reg row_last_dly0 , row_last_dly1 , row_last_dly2 , row_last_dly3 , row_last_dly4 , row_last_dly5 , row_last_dly6 , row_last_dly7 ;
wire wrb0_row_last , wrb1_row_last , wrb2_row_last , wrb3_row_last , wrb4_row_last , wrb5_row_last , wrb6_row_last , wrb7_row_last	;
// only bank0 / bank7 state is read (cnt00_finalnum padding select)
wire [3-1:0] wrb0_current_state;
wire [3-1:0] wrb7_current_state;

wire	[5-1:0] b0_padding_parm	;
wire	[5-1:0]	b1_padding_parm ;
reg 	[7-1:0]	gen_pdshifter_0 	;	
reg 	[7-1:0]	gen_pdshifter_1 	;
reg 	[7-1:0]	gen_norshifter 		;
reg [IFMAP_SRAM_ADDBITS-1:0]	cpr0_acc_step	;
reg [IFMAP_SRAM_ADDBITS-1:0]	cpr0_acc_shifter	;
reg [IFMAP_SRAM_ADDBITS-1:0]	cpr1_acc_step	;
reg [IFMAP_SRAM_ADDBITS-1:0]	cpr1_acc_shifter	;
reg [8-1:0] strwind_sht_0 ;
reg [8-1:0] strwind_sht_1 ;  
reg [8-1:0] strwind_sht_2 ;
reg [8-1:0] strwind_sht_3 ;  
reg [8-1:0] strwind_sht_4 ;
reg [8-1:0] strwind_sht_5 ;  
reg [8-1:0] strwind_sht_6 ;
reg [8-1:0] strwind_sht_7 ;  

wire [6-1:0] strb0_shift ;
wire [6-1:0] strb1_shift ;
wire [6-1:0] strb2_shift ;
wire [6-1:0] strb3_shift ;
wire [6-1:0] strb4_shift ;
wire [6-1:0] strb5_shift ;
wire [6-1:0] strb6_shift ;
wire [6-1:0] strb7_shift ;

wire [8-1:0]	wrb0_pdaddr_shifter	;
wire [8-1:0]	wrb7_pdaddr_shifter	;

reg	 [8-1:0]	wrb0_pdaddr_shifter_reg ;
reg	 [8-1:0]	wrb1_pdaddr_shifter_reg ;
reg	 [8-1:0]	wrb2_pdaddr_shifter_reg ;
reg	 [8-1:0]	wrb3_pdaddr_shifter_reg ;
reg	 [8-1:0]	wrb4_pdaddr_shifter_reg ;
reg	 [8-1:0]	wrb5_pdaddr_shifter_reg ;
reg	 [8-1:0]	wrb6_pdaddr_shifter_reg ;
reg	 [8-1:0]	wrb7_pdaddr_shifter_reg	;

wire wrb_end_check ;
wire wrb_rst ;
wire wrcaf_reset ;	
wire wrb_ld_done ;
wire wrb_idle2start	;

assign wrcaf_reset = reset | wrb_rst | rdwd_done	;
assign align_data_in	=	dr_data_dly0	;
assign align_din_index	=	dr_num_dly0		;
assign align_din_valid	=	valid_drdata_dly0		;
assign wr_row_parity    =   write_row_cnt[0];

count_yi_v4 #(
    .BITS_OF_END_NUMBER (	3	)
)ins_name(
    .clk		( clk )
    ,	.reset 	 		(	wrcaf_reset	)
    ,	.enable	 		(	en_row_count	)
	,	.final_number	(	cfg_rowcnt_finum	)
	,	.last			(	row_last	)
    ,	.total_q		(	row_count	)
);

ifw_cnt_fsm	#(
	.CNT00_WIDTH	(	IFWSTG0_CNTBITS	)
	,	.CNT01_WIDTH		(	IFWSTG1_CNTBITS	)
	,	.WS_ADDR_WIDTH		(	IFMAP_SRAM_ADDBITS	)
)	wr_buf_0 (
	  .clk	(	clk		)
	,	.reset	(	wrcaf_reset	)
	,  .din_idle2start 	 	(	wrb_idle2start	)	
	,	.din_ifw_curr_state 	(	write_state	)	
	,	.din_cfg_mast_state 	(	cfg_mast_state	)	
	,	.din_row_last 			(	wrb0_row_last	)
	,	.dout_wr_curr_state 	(	wrb0_current_state	)	
	,	.dout_wr_cnt00 			(	wrb0_cnt00	)
	,	.dout_wr_cnt01 			(	wrb0_cnt01	)
	,	.dout_wr_srad_cnt		(	wrb0_sram_addrcnt	)
	,	.dout_wr_stg0_last		(	wrb0_stg0_last	)
	,	.dout_wr_stg1_last		(							)
	,	.dout_wr_srad_last		(							)
	,	.wr_stg0_en 			(	wrb0_stg0_en	)	
	,	.wr_stg1_en 			(	wrb0_stg1_en	)	
	,	.wr_cnt00_finalnum 		(	wrb0_cnt00_finalnum	)
	,	.wr_cnt01_finalnum 		(	wrb0_cnt01_finalnum	)
	,	.wr_srad_finalnum		(	wr_srad_finalnum_para	)
);

ifw_cnt_fsm	#(
    .CNT00_WIDTH	(	IFWSTG0_CNTBITS	)
    ,	.CNT01_WIDTH		(	IFWSTG1_CNTBITS	)
    ,	.WS_ADDR_WIDTH		(	IFMAP_SRAM_ADDBITS	)
)	wr_buf_1 (
    .clk	(	clk		)
    ,	.reset	(	wrcaf_reset	)
	,	.din_idle2start 	 	(	wrb_idle2start	)	
	,	.din_ifw_curr_state 	(	write_state	    )	
	,	.din_cfg_mast_state 	(	cfg_mast_state	)	
	,	.din_row_last 			(	wrb1_row_last	)
	,	.dout_wr_curr_state 	(							)	
	,	.dout_wr_cnt00 			(	wrb1_cnt00	)
	,	.dout_wr_cnt01 			(	wrb1_cnt01	)
	,	.dout_wr_srad_cnt		(	wrb1_sram_addrcnt	)
	,	.dout_wr_stg0_last		(	wrb1_stg0_last	)
	,	.dout_wr_stg1_last		(							)
	,	.dout_wr_srad_last		(							)
	,	.wr_stg0_en 			(	wrb1_stg0_en	)	
	,	.wr_stg1_en 			(	wrb1_stg1_en	)	
	,	.wr_cnt00_finalnum 		(	wrb1_cnt00_finalnum	)
	,	.wr_cnt01_finalnum 		(	wrb1_cnt01_finalnum	)
	,	.wr_srad_finalnum		(	wr_srad_finalnum_para	)
);

ifw_cnt_fsm	#(
    .CNT00_WIDTH	(	IFWSTG0_CNTBITS	)
    ,	.CNT01_WIDTH		(	IFWSTG1_CNTBITS	)
    ,	.WS_ADDR_WIDTH		(	IFMAP_SRAM_ADDBITS	)
)	wr_buf_2 (
    .clk	(	clk		)
    ,	.reset	(	wrcaf_reset	)
	,	.din_idle2start 	 	(	wrb_idle2start	)	
	,	.din_ifw_curr_state 	(	write_state 	)	
	,	.din_cfg_mast_state 	(	cfg_mast_state	)	
	,	.din_row_last 			(	wrb2_row_last	)
	,	.dout_wr_curr_state 	(							)	
	,	.dout_wr_cnt00 			(	wrb2_cnt00	)
	,	.dout_wr_cnt01 			(	wrb2_cnt01	)
	,	.dout_wr_srad_cnt		(	wrb2_sram_addrcnt	)
	,	.dout_wr_stg0_last		(	wrb2_stg0_last	)
	,	.dout_wr_stg1_last		(							)
	,	.dout_wr_srad_last		(							)
	,	.wr_stg0_en 			(	wrb2_stg0_en	)	
	,	.wr_stg1_en 			(	wrb2_stg1_en	)	
	,	.wr_cnt00_finalnum 		(	wrb2_cnt00_finalnum	)
	,	.wr_cnt01_finalnum 		(	wrb2_cnt01_finalnum	)
	,	.wr_srad_finalnum		(	wr_srad_finalnum_para	)
);

ifw_cnt_fsm	#(
    .CNT00_WIDTH	(	IFWSTG0_CNTBITS	)
    ,	.CNT01_WIDTH		(	IFWSTG1_CNTBITS	)
    ,	.WS_ADDR_WIDTH		(	IFMAP_SRAM_ADDBITS	)
)	wr_buf_3 (
    .clk	(	clk		)
    ,	.reset	(	wrcaf_reset	)
	,	.din_idle2start 	 	(	wrb_idle2start	)	
	,	.din_ifw_curr_state 	(	write_state  	)	
	,	.din_cfg_mast_state 	(	cfg_mast_state	)	
	,	.din_row_last 			(	wrb3_row_last	)
	,	.dout_wr_curr_state 	(							)	
	,	.dout_wr_cnt00 			(	wrb3_cnt00	)
	,	.dout_wr_cnt01 			(	wrb3_cnt01	)
	,	.dout_wr_srad_cnt		(	wrb3_sram_addrcnt	)
	,	.dout_wr_stg0_last		(	wrb3_stg0_last	)
	,	.dout_wr_stg1_last		(							)
	,	.dout_wr_srad_last		(							)
	,	.wr_stg0_en 			(	wrb3_stg0_en	)	
	,	.wr_stg1_en 			(	wrb3_stg1_en	)	
	,	.wr_cnt00_finalnum 		(	wrb3_cnt00_finalnum	)
	,	.wr_cnt01_finalnum 		(	wrb3_cnt01_finalnum	)
	,	.wr_srad_finalnum		(	wr_srad_finalnum_para	)
);

ifw_cnt_fsm	#(
    .CNT00_WIDTH	(	IFWSTG0_CNTBITS	)
    ,	.CNT01_WIDTH		(	IFWSTG1_CNTBITS	)
    ,	.WS_ADDR_WIDTH		(	IFMAP_SRAM_ADDBITS	)
)	wr_buf_4 (
    .clk	(	clk		)
    ,	.reset	(	wrcaf_reset	)
	,	.din_idle2start 	 	(	wrb_idle2start	)
	,	.din_ifw_curr_state 	(	write_state     )	
	,	.din_cfg_mast_state 	(	cfg_mast_state	)	
	,	.din_row_last 			(	wrb4_row_last	)
	,	.dout_wr_curr_state 	(							)	
	,	.dout_wr_cnt00 			(	wrb4_cnt00	)
	,	.dout_wr_cnt01 			(	wrb4_cnt01	)
	,	.dout_wr_srad_cnt		(	wrb4_sram_addrcnt	)
	,	.dout_wr_stg0_last		(	wrb4_stg0_last	)
	,	.dout_wr_stg1_last		(							)
	,	.dout_wr_srad_last		(							)
	,	.wr_stg0_en 			(	wrb4_stg0_en	)	
	,	.wr_stg1_en 			(	wrb4_stg1_en	)	
	,	.wr_cnt00_finalnum 		(	wrb4_cnt00_finalnum	)
	,	.wr_cnt01_finalnum 		(	wrb4_cnt01_finalnum	)
	,	.wr_srad_finalnum		(	wr_srad_finalnum_para	)
);

ifw_cnt_fsm	#(
    .CNT00_WIDTH	(	IFWSTG0_CNTBITS	)
    ,	.CNT01_WIDTH		(	IFWSTG1_CNTBITS	)
    ,	.WS_ADDR_WIDTH		(	IFMAP_SRAM_ADDBITS	)
)	wr_buf_5 (
    .clk	(	clk		)
    ,	.reset	(	wrcaf_reset	)
	,	.din_idle2start 	 	(	wrb_idle2start	)
	,	.din_ifw_curr_state 	(	write_state 	)	
	,	.din_cfg_mast_state 	(	cfg_mast_state	)	
	,	.din_row_last 			(	wrb5_row_last	)
	,	.dout_wr_curr_state 	(							)	
	,	.dout_wr_cnt00 			(	wrb5_cnt00	)
	,	.dout_wr_cnt01 			(	wrb5_cnt01	)
	,	.dout_wr_srad_cnt		(	wrb5_sram_addrcnt	)
	,	.dout_wr_stg0_last		(	wrb5_stg0_last	)
	,	.dout_wr_stg1_last		(							)
	,	.dout_wr_srad_last		(							)
	,	.wr_stg0_en 			(	wrb5_stg0_en	)	
	,	.wr_stg1_en 			(	wrb5_stg1_en	)	
	,	.wr_cnt00_finalnum 		(	wrb5_cnt00_finalnum	)
	,	.wr_cnt01_finalnum 		(	wrb5_cnt01_finalnum	)
	,	.wr_srad_finalnum		(	wr_srad_finalnum_para	)
);

ifw_cnt_fsm	#(
    .CNT00_WIDTH	(	IFWSTG0_CNTBITS	)
    ,	.CNT01_WIDTH		(	IFWSTG1_CNTBITS	)
    ,	.WS_ADDR_WIDTH		(	IFMAP_SRAM_ADDBITS	)
)	wr_buf_6 (
    .clk	(	clk		)
    ,	.reset	(	wrcaf_reset	)
	,	.din_idle2start 	 	(	wrb_idle2start	)
	,	.din_ifw_curr_state 	(	write_state  	)	
	,	.din_cfg_mast_state 	(	cfg_mast_state	)	
	,	.din_row_last 			(	wrb6_row_last	)
	,	.dout_wr_curr_state 	(							)	
	,	.dout_wr_cnt00 			(	wrb6_cnt00	)
	,	.dout_wr_cnt01 			(	wrb6_cnt01	)
	,	.dout_wr_srad_cnt		(	wrb6_sram_addrcnt	)
	,	.dout_wr_stg0_last		(	wrb6_stg0_last	)
	,	.dout_wr_stg1_last		(							)
	,	.dout_wr_srad_last		(							)
	,	.wr_stg0_en 			(	wrb6_stg0_en	)	
	,	.wr_stg1_en 			(	wrb6_stg1_en	)	
	,	.wr_cnt00_finalnum 		(	wrb6_cnt00_finalnum	)
	,	.wr_cnt01_finalnum 		(	wrb6_cnt01_finalnum	)
	,	.wr_srad_finalnum		(	wr_srad_finalnum_para	)
);

ifw_cnt_fsm	#(
    .CNT00_WIDTH	(	IFWSTG0_CNTBITS	)
    ,	.CNT01_WIDTH		(	IFWSTG1_CNTBITS	)
    ,	.WS_ADDR_WIDTH		(	IFMAP_SRAM_ADDBITS	)
)	wr_buf_7 (
    .clk	(	clk		)
    ,	.reset	(	wrcaf_reset	)
	,	.din_idle2start 	 	(	wrb_idle2start	)
	,	.din_ifw_curr_state 	(	write_state 	)	
	,	.din_cfg_mast_state 	(	3'd3	)		
	,	.din_row_last 			(	wrb7_row_last	)
	,	.dout_wr_curr_state 	(	wrb7_current_state	)	
	,	.dout_wr_cnt00 			(	wrb7_cnt00	)
	,	.dout_wr_cnt01 			(	wrb7_cnt01	)
	,	.dout_wr_srad_cnt		(	wrb7_sram_addrcnt	)
	,	.dout_wr_stg0_last		(	wrb7_stg0_last	)
	,	.dout_wr_stg1_last		(	wrb7_stg1_last	)
	,	.dout_wr_srad_last		(							)
	,	.wr_stg0_en 			(	wrb7_stg0_en	)	
	,	.wr_stg1_en 			(	wrb7_stg1_en	)	
	,	.wr_cnt00_finalnum 		(	wrb7_cnt00_finalnum	)
	,	.wr_cnt01_finalnum 		(	wrb7_cnt01_finalnum	)
	,	.wr_srad_finalnum		(	wr_srad_finalnum_para	)
);

assign	dout_wrb0_cen	=	(wrb0_stg0_en)	?	1'd0	: 1'd1	;
assign	dout_wrb1_cen	=	(wrb1_stg0_en)	?	1'd0	: 1'd1	;
assign	dout_wrb2_cen	=	(wrb2_stg0_en)	?	1'd0	: 1'd1	;
assign	dout_wrb3_cen	=	(wrb3_stg0_en)	?	1'd0	: 1'd1	;
assign	dout_wrb4_cen	=	(wrb4_stg0_en)	?	1'd0	: 1'd1	;
assign	dout_wrb5_cen	=	(wrb5_stg0_en)	?	1'd0	: 1'd1	;
assign	dout_wrb6_cen	=	(wrb6_stg0_en)	?	1'd0	: 1'd1	;
assign	dout_wrb7_cen	=	(wrb7_stg0_en)	?	1'd0	: 1'd1	;

assign	dout_wrb0_wen	=	dout_wrb0_cen	;
assign	dout_wrb1_wen	=	dout_wrb1_cen	;
assign	dout_wrb2_wen	=	dout_wrb2_cen	;
assign	dout_wrb3_wen	=	dout_wrb3_wen	;
assign	dout_wrb4_wen	=	dout_wrb4_cen	;
assign	dout_wrb5_wen	=	dout_wrb5_cen	;
assign	dout_wrb6_wen	=	dout_wrb6_cen	;
assign	dout_wrb7_wen	=	dout_wrb7_cen	;

assign	dout_wrb0_data	=	align_data_in	;
assign	dout_wrb1_data	=	dr_data_dly1	;
assign	dout_wrb2_data	=	dr_data_dly2	;
assign	dout_wrb3_data	=	dr_data_dly3	;
assign	dout_wrb4_data	=	dr_data_dly4	;
assign	dout_wrb5_data	=	dr_data_dly5	;
assign	dout_wrb6_data	=	dr_data_dly6	;
assign	dout_wrb7_data	=	dr_data_dly7	;

assign	dout_wrb0_addr	=	wrb0_sram_addrcnt	;
assign	dout_wrb1_addr	=	wrb1_sram_addrcnt	;
assign	dout_wrb2_addr	=	wrb2_sram_addrcnt	;
assign	dout_wrb3_addr	=	wrb3_sram_addrcnt	;
assign	dout_wrb4_addr	=	wrb4_sram_addrcnt	;
assign	dout_wrb5_addr	=	wrb5_sram_addrcnt	;
assign	dout_wrb6_addr	=	wrb6_sram_addrcnt	;
assign	dout_wrb7_addr	=	wrb7_sram_addrcnt	+	wrb7_pdaddr_shifter	;

assign	wrb0_pdaddr_shifter = ( write_state <= 1 ) ? 'd0   : ( cfg_mast_state == LEFT ) ?
(cfg_atlchin * ( row_count + 1 ) ) : (cfg_atlchin * ( write_row_cnt + 1 )) ;
assign	wrb7_pdaddr_shifter = wrb7_pdaddr_shifter_reg - cfg_atlchin	;

always @(posedge clk ) begin
	if(reset) begin
		wrb0_pdaddr_shifter_reg <= 0	;
		wrb1_pdaddr_shifter_reg <= 0	;
		wrb2_pdaddr_shifter_reg <= 0	;
		wrb3_pdaddr_shifter_reg <= 0	;
		wrb4_pdaddr_shifter_reg <= 0	;
		wrb5_pdaddr_shifter_reg <= 0	;
		wrb6_pdaddr_shifter_reg <= 0	;
		wrb7_pdaddr_shifter_reg <= 0	;
	end
	else begin
		wrb0_pdaddr_shifter_reg <= wrb0_pdaddr_shifter	;
		wrb1_pdaddr_shifter_reg <= wrb0_pdaddr_shifter_reg	;
		wrb2_pdaddr_shifter_reg <= wrb1_pdaddr_shifter_reg	;
		wrb3_pdaddr_shifter_reg <= wrb2_pdaddr_shifter_reg	;
		wrb4_pdaddr_shifter_reg <= wrb3_pdaddr_shifter_reg	;
		wrb5_pdaddr_shifter_reg <= wrb4_pdaddr_shifter_reg	;
		wrb6_pdaddr_shifter_reg <= wrb5_pdaddr_shifter_reg	;
		wrb7_pdaddr_shifter_reg <= wrb6_pdaddr_shifter_reg	;
	end
end

assign wrb0_stg0_en = ((wr_cpr_0 == align_din_index) && align_din_valid )? 1'd1 : 1'd0 ;	
assign wrb0_stg1_en = ( wrb0_stg0_en && wrb0_stg0_last )? 1'd1 : 1'd0 ;
assign wrb0_cnt00_finalnum = 	( wrb0_current_state == WR_NORMAL ) ? cfg_stg0_nor_finum :
									( wrb0_current_state == WR_LEFT ) ? cfg_stg0_pdb0_finum : cfg_stg0_nor_finum ;
assign wrb0_cnt01_finalnum =	cfg_stg1_eb_col	;

assign wrb1_stg0_en = ((wr_cpr_1 == dr_num_dly1) && valid_drdata_dly1 )? 1'd1 : 1'd0 ;
assign wrb1_stg1_en = ( wrb1_stg0_en && wrb1_stg0_last )? 1'd1 : 1'd0 ;	
assign wrb1_cnt00_finalnum = 	cfg_stg0_nor_finum	;
assign wrb1_cnt01_finalnum =	cfg_stg1_eb_col	;

assign wrb2_stg0_en = ((wr_cpr_2 == dr_num_dly2) && valid_drdata_dly2 )? 1'd1 : 1'd0 ;
assign wrb2_stg1_en = ( wrb2_stg0_en && wrb2_stg0_last )? 1'd1 : 1'd0 ;	
assign wrb2_cnt00_finalnum = 	cfg_stg0_nor_finum	;
assign wrb2_cnt01_finalnum =	cfg_stg1_eb_col	;

assign wrb3_stg0_en = ((wr_cpr_3 == dr_num_dly3) && valid_drdata_dly3 )? 1'd1 : 1'd0 ;
assign wrb3_stg1_en = ( wrb3_stg0_en && wrb3_stg0_last )? 1'd1 : 1'd0 ;	
assign wrb3_cnt00_finalnum = 	cfg_stg0_nor_finum	;
assign wrb3_cnt01_finalnum =	cfg_stg1_eb_col	;

assign wrb4_stg0_en = ((wr_cpr_4 == dr_num_dly4) && valid_drdata_dly4 )? 1'd1 : 1'd0 ;
assign wrb4_stg1_en = ( wrb4_stg0_en && wrb4_stg0_last )? 1'd1 : 1'd0 ;	
assign wrb4_cnt00_finalnum = 	cfg_stg0_nor_finum	;
assign wrb4_cnt01_finalnum =	cfg_stg1_eb_col	;

assign wrb5_stg0_en = ((wr_cpr_5 == dr_num_dly5) && valid_drdata_dly5 )? 1'd1 : 1'd0 ;
assign wrb5_stg1_en = ( wrb5_stg0_en && wrb5_stg0_last )? 1'd1 : 1'd0 ;	
assign wrb5_cnt00_finalnum = 	cfg_stg0_nor_finum	;
assign wrb5_cnt01_finalnum =	cfg_stg1_eb_col	;

assign wrb6_stg0_en = ((wr_cpr_6 == dr_num_dly6) && valid_drdata_dly6 )? 1'd1 : 1'd0 ;
assign wrb6_stg1_en = ( wrb6_stg0_en && wrb6_stg0_last )? 1'd1 : 1'd0 ;	
assign wrb6_cnt00_finalnum = 	cfg_stg0_nor_finum	;
assign wrb6_cnt01_finalnum =	cfg_stg1_eb_col	;

assign wrb7_stg0_en = ((wr_cpr_7 == dr_num_dly7) && valid_drdata_dly7 )? 1'd1 : 1'd0 ;
assign wrb7_stg1_en = ( wrb7_stg0_en && wrb7_stg0_last )? 1'd1 : 1'd0 ;
assign wrb7_cnt00_finalnum = 	( wrb7_current_state == WR_NORMAL ) ? cfg_stg0_nor_finum :
									( wrb7_current_state == WR_RIGH ) ? cfg_stg0_pdb0_finum : cfg_stg0_nor_finum ;
assign wrb7_cnt01_finalnum =	cfg_stg1_eb_col 	;

assign row_fin_index = ( row_count == cfg_rowcnt_finum ) ? 1'd1 : 1'd0 ;
assign wrb0_row_last	=	row_fin_index		;
assign wrb1_row_last	=	row_last_dly0	;
assign wrb2_row_last	=	row_last_dly1	;
assign wrb3_row_last	=	row_last_dly2	;
assign wrb4_row_last	=	row_last_dly3	;
assign wrb5_row_last	=	row_last_dly4	;
assign wrb6_row_last	=	row_last_dly5	;
assign wrb7_row_last 	=	row_last_dly6	;

always @(posedge clk ) begin
	if(reset)begin
		row_last_dly0 <= 0	;
		row_last_dly1 <= 0	;
		row_last_dly2 <= 0	;
		row_last_dly3 <= 0	;
		row_last_dly4 <= 0	;
		row_last_dly5 <= 0	;
		row_last_dly6 <= 0	;
		row_last_dly7 <= 0	;		
	end
	else begin
		row_last_dly0 <= row_fin_index		;
		row_last_dly1 <= row_last_dly0	;
		row_last_dly2 <= row_last_dly1	;
		row_last_dly3 <= row_last_dly2	;
		row_last_dly4 <= row_last_dly3	;
		row_last_dly5 <= row_last_dly4	;
		row_last_dly6 <= row_last_dly5	;
		row_last_dly7 <= row_last_dly6	;
	end
end

assign strb0_shift = strwind_sht_0	;
assign strb1_shift = ( !(cfg_mast_state == LEFT) )?	strwind_sht_1 : strwind_sht_0	;
assign strb2_shift = ( !(cfg_mast_state == LEFT) )? strwind_sht_2 : strwind_sht_1	;
assign strb3_shift = ( !(cfg_mast_state == LEFT) )?	strwind_sht_3 : strwind_sht_2	;
assign strb4_shift = ( !(cfg_mast_state == LEFT) )?	strwind_sht_4 : strwind_sht_3	;
assign strb5_shift = ( !(cfg_mast_state == LEFT) )? strwind_sht_5 : strwind_sht_4	;
assign strb6_shift = ( !(cfg_mast_state == LEFT) )?	strwind_sht_6 : strwind_sht_5	;
assign strb7_shift = ( !(cfg_mast_state == LEFT) )?	strwind_sht_7 : strwind_sht_6	;

always @(posedge clk ) begin		
	if(reset)begin
		strwind_sht_0 <= 'd0 ;
		strwind_sht_1 <= 'd0 ;
		strwind_sht_2 <= 'd0 ;
		strwind_sht_3 <= 'd0 ;
		strwind_sht_4 <= 'd0 ;
		strwind_sht_5 <= 'd0 ;
		strwind_sht_6 <= 'd0 ;
		strwind_sht_7 <= 'd0 ;
	end
	else begin
		strwind_sht_0 <= 'd0 ;
		strwind_sht_1 <=  strwind_sht_0 + cfg_atlchin ;
		strwind_sht_2 <=  strwind_sht_1 + cfg_atlchin ;
		strwind_sht_3 <=  strwind_sht_2 + cfg_atlchin ;
		strwind_sht_4 <=  strwind_sht_3 + cfg_atlchin ;
		strwind_sht_5 <=  strwind_sht_4 + cfg_atlchin ;
		strwind_sht_6 <=  strwind_sht_5 + cfg_atlchin ;
		strwind_sht_7 <=  strwind_sht_6 + cfg_atlchin ;
	end
end

always @(*) begin
	if (wrb0_cnt01 == 'd0 ) begin
		cpr0_acc_step = gen_pdshifter_0 ;
	end
	else if (wrb0_cnt01 >= 'd1 )begin
		cpr0_acc_step = gen_norshifter ;
	end
	else begin
		cpr0_acc_step = gen_norshifter ;
	end
end

always @(posedge clk ) begin
	if ( reset ) begin
		cpr0_acc_shifter <= 'd0 ;
	end
	else begin
		if ( wrb0_stg1_en ) begin
			if  ( wrb0_cnt01 == wrb0_cnt01_finalnum )begin
				cpr0_acc_shifter <= 'd0 ;
			end
			else begin
				cpr0_acc_shifter <= cpr0_acc_shifter + cpr0_acc_step;
			end
		end
		else begin
			cpr0_acc_shifter <= cpr0_acc_shifter ;
		end
	end
end

always @(*) begin
	if (wrb0_cnt01 == 'd0 ) begin
		cpr1_acc_step = gen_pdshifter_1 ;
	end
	else if (wrb0_cnt01 >= 'd1 )begin
		cpr1_acc_step = gen_norshifter ;
	end
	else begin
		cpr1_acc_step = gen_norshifter ;
	end
end

always @(posedge clk ) begin
	if ( reset ) begin
		cpr1_acc_shifter <= 'd0 ;
	end
	else begin
		if ( wrb1_stg1_en ) begin
			if  ( wrb1_cnt01 == wrb1_cnt01_finalnum )begin
				cpr1_acc_shifter <= 'd0 ;
			end
			else begin
				cpr1_acc_shifter <= cpr1_acc_shifter + cpr1_acc_step;
			end
		end
		else begin
			cpr1_acc_shifter <= cpr1_acc_shifter ;
		end
	end
end

always @(posedge clk ) begin	
	if(reset)begin
		gen_pdshifter_0 <= 6'd0 ;
		gen_pdshifter_1 <= 6'd0 ;
		gen_norshifter 	<= 6'd0 ;
	end
	else begin
		gen_pdshifter_0 <= cfg_atlchin*b0_padding_parm ;
		gen_pdshifter_1 <= cfg_atlchin*b1_padding_parm ;
		gen_norshifter 	<= cfg_atlchin*8	;
	end
end

assign b0_padding_parm = 	( !(cfg_mast_state == LEFT) )? 5'd8 :				
								( cfg_conv_switch == 3'd2 )? 5'd7 :				
									(cfg_conv_switch == 3'd3 )? 5'd6 : 5'd0 ;
assign b1_padding_parm =	 ( !(cfg_mast_state == LEFT) )? 5'd8 :
									(cfg_conv_switch == 3'd3 )? 5'd7 : 5'd8 ;

assign wr_cpr_0 = wrb0_cnt00 + strb0_shift +cpr0_acc_shifter ;
assign wr_cpr_1 = wrb1_cnt00 + strb1_shift +cpr1_acc_shifter ;
assign wr_cpr_2 = wrb2_cnt00				+ strb2_shift + gen_norshifter * wrb2_cnt01	;
assign wr_cpr_3 = wrb3_cnt00				+ strb3_shift + gen_norshifter * wrb3_cnt01	;
assign wr_cpr_4 = wrb4_cnt00				+ strb4_shift + gen_norshifter * wrb4_cnt01	;
assign wr_cpr_5 = wrb5_cnt00				+ strb5_shift + gen_norshifter * wrb5_cnt01	;
assign wr_cpr_6 = wrb6_cnt00				+ strb6_shift + gen_norshifter * wrb6_cnt01	;
assign wr_cpr_7 = wrb7_cnt00				+ strb7_shift + gen_norshifter * wrb7_cnt01	;

always@( posedge clk )begin
	if( reset )begin
		write_state <= IW_IDLE ;
	end
	else begin
		write_state <= next_write_state ;
	end
end

always @(*) begin
	case (write_state)
		IW_IDLE		: next_write_state = (~if_write_start) ? IW_IDLE : (wr_sec_start) ? IW_SECLOD : IW_DLOD ;
		IW_DLOD		: next_write_state = (wrb_ld_done) ? IW_WABF : IW_DLOD ;
		IW_WABF		: next_write_state = (wrb_end_check) ? (write_row_cnt==3) ? IW_RST:IW_DONE : IW_WABF ;	
		IW_RST		: next_write_state = IW_DONE ;
		IW_DONE		: next_write_state = IW_IDLE ;
		IW_SECLOD	: next_write_state = (en_row_count) ? IW_WABF : IW_SECLOD ;
		default:  next_write_state = IW_IDLE ;
	endcase	
end

always@( posedge clk )begin
	if( reset )begin
		wr_sec_start <= 0 ;
	end
	else if(write_state == IW_DLOD) begin
		wr_sec_start <= 1 ;
	end
	else if(if_read_last == 1)begin
		wr_sec_start <=  0 ;
	end
	else begin
		wr_sec_start <=  wr_sec_start ; 
	end
end

always @( * ) begin
	if_write_busy =	((write_state >= 3'd1 ) && (write_state <= 3'd5) )? 1'd1 : 1'd0 ;
	if_write_done =	((write_state == IW_DONE)) ? 1'd1 : 1'd0  ;
	if_write_en	=	((write_state == IW_DLOD) || (write_state == IW_SECLOD)) ? 1'd1 : 1'd0 ;
end

assign	wrb_ld_done = row_last	;
assign 	wrb_end_check 	= ( wrb7_stg1_last == 1 ) ? 1'd1 : 1'd0 ;
assign 	wrb_rst 		= ( write_state == IW_RST ) ? 1'd1 : 1'd0 ;	

always @ (posedge clk )
	if (reset)
		next_wrb_idle2start <= 1'd0;
	else if(if_write_start)
		next_wrb_idle2start <= 1'd1;
	else if(rdwd_done)
		next_wrb_idle2start <= 1'd0;		
	else 
		next_wrb_idle2start <= next_wrb_idle2start;
assign wrb_idle2start = next_wrb_idle2start;	

always @(posedge clk ) begin
	if(reset)begin
		ifstore_read_dout <= 1'd0;
	end		
	else begin
		if( if_write_busy ) begin
			if( ifstore_empty_n_din == 1'd1 )begin
				ifstore_read_dout <= 1'd1;
			end
			else begin
				ifstore_read_dout <= 1'd0;
			end
		end
		else begin
			ifstore_read_dout <= 1'd0;
		end
	end	
end

always @(*) begin
	valid_drdata = ifstore_read_dout & ifstore_empty_n_din;
end

always@(posedge clk )begin
	if(reset)begin
		valid_drdata_dly0 <= 0 ;
		valid_drdata_dly1 <= 0 ;
		valid_drdata_dly2 <= 0 ;
		valid_drdata_dly3 <= 0 ;
		valid_drdata_dly4 <= 0 ;
		valid_drdata_dly5 <= 0 ;
		valid_drdata_dly6 <= 0 ;
		valid_drdata_dly7 <= 0 ;
		valid_drdata_dly8 <= 0 ;
		valid_drdata_dly9 <= 0 ;	
		end
	else begin
		valid_drdata_dly0 <= valid_drdata;
		valid_drdata_dly1 <= valid_drdata_dly0;
		valid_drdata_dly2 <= valid_drdata_dly1;
		valid_drdata_dly3 <= valid_drdata_dly2;
		valid_drdata_dly4 <= valid_drdata_dly3;
		valid_drdata_dly5 <= valid_drdata_dly4;
		valid_drdata_dly6 <= valid_drdata_dly5;
		valid_drdata_dly7 <= valid_drdata_dly6;
		valid_drdata_dly8 <= valid_drdata_dly7;
		valid_drdata_dly9 <= valid_drdata_dly8;
	end
end

always@(posedge clk )begin
	if(reset)begin
		dr_num_dly0 <= 0 ;
		dr_num_dly1	<= 0 ;
		dr_num_dly2	<= 0 ;
		dr_num_dly3	<= 0 ;
		dr_num_dly4	<= 0 ;
		dr_num_dly5	<= 0 ;
		dr_num_dly6	<= 0 ;
		dr_num_dly7 <= 0 ;
		dr_data_dly0 	<= 0 ;
		dr_data_dly1	<= 0 ;
		dr_data_dly2	<= 0 ;
		dr_data_dly3	<= 0 ;
		dr_data_dly4	<= 0 ;
		dr_data_dly5	<= 0 ;
		dr_data_dly6	<= 0 ;
		dr_data_dly7	<= 0 ;
	end
	else begin	
		dr_num_dly0 <= cnt00;
		dr_num_dly1	<= dr_num_dly0	;
		dr_num_dly2	<= dr_num_dly1	;
		dr_num_dly3	<= dr_num_dly2	;
		dr_num_dly4	<= dr_num_dly3	;
		dr_num_dly5	<= dr_num_dly4	;
		dr_num_dly6	<= dr_num_dly5	;
		dr_num_dly7	<= dr_num_dly6	;
		dr_data_dly0 	<= ifstore_data_din;
		dr_data_dly1	<= dr_data_dly0		;
		dr_data_dly2	<= dr_data_dly1		;
		dr_data_dly3	<= dr_data_dly2		;
		dr_data_dly4	<= dr_data_dly3		;
		dr_data_dly5	<= dr_data_dly4		;
		dr_data_dly6	<= dr_data_dly5		;
		dr_data_dly7	<= dr_data_dly6		;
	end	
end

always @(posedge clk ) begin
	if( reset )begin
		cnt00 <= 0;
	end
	else begin
		if ( valid_drdata )begin
			if( cnt00 >= cfg_dincnt_finum ) cnt00 <= 'd0;
			else cnt00 <= cnt00 +1 ;
		end
		else begin
			cnt00 <= cnt00 ;
		end
	end
end

assign en_row_count = ( (  cnt00 >= cfg_dincnt_finum )   ) ? 1'd1 : 1'd0 ;

always @ (posedge clk) begin
	if (reset) begin
		write_row_cnt <= 2;
	end
	else if (if_write_done)	begin
		write_row_cnt <= write_row_cnt +1 ;
	end
	else if (if_read_last) begin
		write_row_cnt <= 2;
	end
	else begin
		write_row_cnt <= write_row_cnt;
	end
end

endmodule
