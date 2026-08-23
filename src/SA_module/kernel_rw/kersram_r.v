// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2022.11.16
// Ver      : 2.0
// Func     : kernel sram read module use pad and normal 
// Log :--2023.04.07  cfg_top_starter is for top bottom padding situation
// Log :--2023.04.08  v3 counter replace to v4 counter
// Log :--2023.04.12  cfg_normal_length don't have Left nor right 
// Log :--2023.05.02  valid and final output signal have alignment
// ============================================================================
//		 +---+---+---+
//		 |   |   |   |   address 0  ~ 11
//		 +---+---+---+
//		 |   |   |   |   address 12 ~ 23
//		 +---+---+---+
//		 |   |   |   |   address 24 ~ 35
//		 +---+---+---+
// in 3x3 top padding, we should address 12 ~ 23 24 ~ 35	so starter=12 then top padding length =24
// in 3x3 bot padding, we should address 0 ~ 11 12 ~ 23		just use bot padding length =24 is fine.
//-----------------------------------------------------------------------------
//		 +--+--+--+--+--+
//		 |  |  |  |  |  |   address 00 ~ 19
//		 +--+--+--+--+--+
//		 |  |  |  |  |  |   address 20 ~ 39
//		 +--+--+--+--+--+
//		 |  |  |  |  |  |   address 40 ~ 59
//		 +--+--+--+--+--+
//		 |  |  |  |  |  |   address 60 ~ 79
//		 +--+--+--+--+--+
//		 |  |  |  |  |  |   address 80 ~ 99
//		 +--+--+--+--+--+
// in 5x5 top padding =2 , we need address 40 ~ 59 60 ~ 79 80 ~ 99			--so starter=40 then top padding length = 60 
// in 5x5 top padding =1 , we need address 20 ~ 39 40 ~ 59 60 ~ 79 80 ~ 99	--so starter=20 then top padding length = 80
// in 5x5 bot padding =1 , we need address 00 ~ 19 20 ~ 39 40 ~ 59 60 ~ 79	--just use bot padding length =80 is fine.
// in 5x5 bot padding =2 , we need address 00 ~ 19 20 ~ 39 40 ~ 59 			--just use bot padding length =60 is fine.
//-----------------------------------------------------------------------------


module kersram_r 
#(
	parameter ADDR_CNT_BITS = 10 
	,	BUF_TAG_BITS	= 8
	,	STARTER_BITS	= 8
	,	PADLEN_BITS		= 8
)(

	clk
	,	reset


	//----generate by ker_r_io.py 
	//----signal for sram read module io port start------ 
	,	cen_kersr_0		,addr_kersr_0		,valid_0		,final_0   //----signal for SRAM_0---------
	,	cen_kersr_1		,addr_kersr_1		,valid_1		,final_1   //----signal for SRAM_1---------
	,	cen_kersr_2		,addr_kersr_2		,valid_2		,final_2   //----signal for SRAM_2---------
	,	cen_kersr_3		,addr_kersr_3		,valid_3		,final_3   //----signal for SRAM_3---------
	,	cen_kersr_4		,addr_kersr_4		,valid_4		,final_4   //----signal for SRAM_4---------
	,	cen_kersr_5		,addr_kersr_5		,valid_5		,final_5   //----signal for SRAM_5---------
	,	cen_kersr_6		,addr_kersr_6		,valid_6		,final_6   //----signal for SRAM_6---------
	,	cen_kersr_7		,addr_kersr_7		,valid_7		,final_7   //----signal for SRAM_7---------
	//----signal for sram read dec io port  end------ 

	,	output_of_cnt_ker 			
	,	output_of_enable_ker_cnt 	

	,	ker_read_done 		
	,	ker_read_busy 		
	,	start_ker_read		

	,	cfg_kernum_sub1
	,	cfg_colout_sub1

	,	cfg_normal_length		

	,	cfgin_top_starter		
	,	cfgin_botpad_length		
	,	cfgin_toppad_length
	,	cfg_atlchin		
	
	,	if_r_state		

);

//---------- config parameter -----------------------

// ====	config	sram address counter		====
// localparam CH_ADDR = 4	;	// input channel / 8 = 4
// localparam CP_PIX = 9	;	// 3x3 base convolution
localparam KER_NUM = 8 ;	// number of kernels 64 /8 = 8  need config
localparam COLOUT_NUM = 10'd9 ;
//----------------------------------------

//---------------------------------------------------

input wire clk ;
input wire reset ;

//-------- schedule signal -------------------------
output reg 		ker_read_done 		;
output reg 		ker_read_busy 		;
input wire 		start_ker_read		;

//----generate by ker_r_io.py 
//----declare KER_SRAM read output signal start------ 
output reg cen_kersr_0 ,cen_kersr_1 ,cen_kersr_2 ,cen_kersr_3 ,cen_kersr_4 ,cen_kersr_5 ,cen_kersr_6 ,cen_kersr_7 ; 
// output reg wen_kersr_0 ,wen_kersr_1 ,wen_kersr_2 ,wen_kersr_3 ,wen_kersr_4 ,wen_kersr_5 ,wen_kersr_6 ,wen_kersr_7 ; 
output reg [ ADDR_CNT_BITS -1 : 0 ] addr_kersr_0 ,addr_kersr_1 ,addr_kersr_2 ,addr_kersr_3 ,addr_kersr_4 ,addr_kersr_5 ,addr_kersr_6 ,addr_kersr_7 ; 
output wire valid_0 ,valid_1 ,valid_2 ,valid_3 ,valid_4 ,valid_5 ,valid_6 ,valid_7 ; 
output wire final_0 ,final_1 ,final_2 ,final_3 ,final_4 ,final_5 ,final_6 ,final_7 ; 

// ---- declare signal for bias read module ----
output wire [BUF_TAG_BITS-1:0] 	output_of_cnt_ker 			;
output wire 		output_of_enable_ker_cnt 	;

//----    config connection    -----
input wire	[BUF_TAG_BITS-1:0]  	cfg_kernum_sub1	;
input wire	[ADDR_CNT_BITS-1:0]		cfg_colout_sub1	;
input wire 	[ADDR_CNT_BITS-1:0]		cfg_normal_length	;

input wire 	[STARTER_BITS*5	-1:0]	cfgin_top_starter	;	//aggregate cfg
input wire 	[PADLEN_BITS*5	-1:0] 	cfgin_botpad_length	;	//aggregate cfg
input wire 	[PADLEN_BITS*5	-1:0]	cfgin_toppad_length	;	//aggregate cfg

input wire	[8-1:0]					cfg_atlchin				;

//----    ifmap read FSM state    -----
input wire [3-1:0]	if_r_state	;

//-----------------------------------------------------------------------------


wire 	[STARTER_BITS-1:0]	cfg_top_starter		[0:4];
// cfg_botpad_length[0:4] was unpacked from cfgin_botpad_length and never read
wire 	[PADLEN_BITS-1:0]	cfg_toppad_length	[0:4];

localparam [2:0] 
		IDLE          = 3'd0,
		UP_PADDING    = 3'd1,
		ROW_ADDR_012  = 3'd2,   
		ROW_ADDR_123  = 3'd3, 
		ROW_ADDR_230  = 3'd4,
		ROW_ADDR_301  = 3'd5,
		DOWN_PADDING  = 3'd6;





// =====	busy & done		FSM		======================
reg [2:0] current_state ;
reg [2:0] next_state ;
reg rd_sram_done ;	// for done signal !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

// ==== 	kernel sram read FSM	====
reg [3:0] rd_current_state ;
reg [3:0] rd_next_state ;

//----    counter    -----


// ====		sram address counter		====
reg enable_ker_cnt ;
wire enable_once_cp ;
wire enable_cnt_colout ;

wire	[ADDR_CNT_BITS-1:0] cnt_once_cp			;
wire	[ADDR_CNT_BITS-1:0] cnt_once_cp_final	;
wire						cnt_once_cp_last	;

wire	[ADDR_CNT_BITS-1:0]	cnt_colout			;
wire	[ADDR_CNT_BITS-1:0]	cnt_colout_final	;

wire	[BUF_TAG_BITS-1 : 0 ]	cnt_ker			;
wire	[BUF_TAG_BITS-1 : 0 ]	cnt_ker_final	;
// cnt_colout_last / cnt_ker_last : counter .last taps nobody reads -- left open

reg		[ADDR_CNT_BITS-1:0] sram_address   ;	// sram address
reg		[ADDR_CNT_BITS  :0] once_cp_cycle	;	// end of cp cycle and shifter
reg		[ADDR_CNT_BITS  :0] oncecpcycle_compare	;	


// ====		sram signal delay		====
reg cen_dly0,cen_dly1,cen_dly2,cen_dly3,cen_dly4,cen_dly5,cen_dly6,cen_dly7;
// reg wen_dly0 , wen_dly1 , wen_dly2 , wen_dly3 , wen_dly4 , wen_dly5 , wen_dly6 , wen_dly7 ;
reg [ ADDR_CNT_BITS-1 : 0 ] addr_sr_dly0 , addr_sr_dly1 , addr_sr_dly2 , addr_sr_dly3 , addr_sr_dly4 , addr_sr_dly5 , addr_sr_dly6 , addr_sr_dly7 ;
reg ker_read_busy_dly0 , ker_read_busy_dly1 , ker_read_busy_dly2 , ker_read_busy_dly3 , ker_read_busy_dly4 , ker_read_busy_dly5 , ker_read_busy_dly6 , ker_read_busy_dly7 ;
// valid_dly9 / final_dly9 were the tail of each chain and nothing read them.
// The whole cnt_once_cp_dly0..3 chain is gone too -- its only readers were the
// commented-out final_check variants further down.
reg valid_dly0 , valid_dly1 , valid_dly2 , valid_dly3 , valid_dly4 , valid_dly5 , valid_dly6 , valid_dly7 , valid_dly8 ;
reg final_dly0 , final_dly1 , final_dly2 , final_dly3 , final_dly4 , final_dly5 , final_dly6 , final_dly7 , final_dly8 ;
wire valid_check ;
wire final_check ;


//==============================================================================
//========    config distribute    ========
//==============================================================================
genvar iv0;
generate
for(iv0 = 0;iv0 < 5; iv0 = iv0 + 1) begin : ASSIGN_GEN
    assign cfg_top_starter[iv0] = cfgin_top_starter[		(STARTER_BITS*(5-iv0)-1)	-: STARTER_BITS];
    assign cfg_toppad_length[iv0] = cfgin_toppad_length[	(PADLEN_BITS*(5-iv0)	-1)	-: PADLEN_BITS];
end
endgenerate

// ============================================================================
// ====		Net connection		====
// ============================================================================
assign output_of_cnt_ker 			= cnt_ker 		;
assign output_of_enable_ker_cnt 	= enable_ker_cnt 	;


localparam C_IDLE = 3'd0;
localparam C_BUSY = 3'd1;
localparam C_DONE = 3'd2;
// localparam C_IDLE = 3'd0;
// ============================================================================
// ===== busy & done
// ============================================================================
always @(posedge clk ) begin
	if( reset )begin
		current_state <= C_IDLE ;
	end
	else begin
		current_state <= next_state ;
	end
end
always@( * )begin
	case (current_state)
		C_IDLE	: next_state = ( start_ker_read ) ? C_BUSY : C_IDLE ;
		C_BUSY	: next_state = ( rd_sram_done ) ? C_DONE : C_BUSY ;
		C_DONE	: next_state =  C_IDLE   ;
		default: next_state =  C_IDLE   ;
	endcase
end
always @(*) begin
	ker_read_busy = ( (current_state == C_BUSY ) || (current_state == C_DONE ) ) ? 1'd1 : 1'd0 ;
	ker_read_done = (current_state == C_DONE ) ? 1'd1 : 1'd0 ;
end

// always @(posedge clk ) begin
// 	if(reset)begin
// 		ker_read_done <= 1'd0 ;
// 	end
// 	else begin
// 		if(ker_read_busy)begin
// 			if( rd_sram_done )begin
// 				ker_read_done <= 1'd1 ;
// 			end
// 			else begin
// 				ker_read_done <= 1'd0;
// 			end
// 		end
// 		else begin
// 			ker_read_done <= 1'd0;
// 		end
// 	end
// end

// ============================================================================
// =====		FSM for CONV mode	
// ============================================================================
// address generate mode
localparam MAS_LEFT = 1 ;
localparam MAS_BASE = 2 ;
localparam MAS_RIGT = 3 ;

// ==== 	kernel sram read FSM	====
localparam RD_IDLE 	= 4'd0;
localparam PAD_MODE = 4'd1;
localparam NOR_MODE = 4'd2;
localparam RD_DONE 	= 4'd3;

localparam C3_MODE = 0;		// compute 3x3
localparam C5_MODE = 1;		// compute 5x5
localparam C7_MODE = 2;		// compute 7x7


localparam TOP = 0 ;
localparam MID = 1 ;
localparam BOT = 2 ;

localparam PAD_FINCHO = 3'd1;
reg [2-1 : 0 ] row_pad_condi 	;	// row level padding condition
// reg [2-1 : 0 ] mas_state_condi 	;	// master current state condition : LEFT , BASE , RIGHT
// reg [2-1 : 0 ] ker_conv_condi 	;	// C3_MODE C5_MODE C7_MODE

reg padding_done ;
reg nor_read_done ;

// 3x3-padding leftovers, all unreferenced in the 1x1 configuration:
//   pdad_top_array / pdad_bot_array / pd_start / pd_end / en_pdcho
//   en_kr_over_toplength (was driven from cnt_once_cp, never read)

//-----------------------------------------------------------------------------
// config register
//-----------------------------------------------------------------------------


//----    cfg _ move out already    -----
// integer i ;
// always @( posedge clk ) begin
// 	if( reset )begin
// 		for( i=0 ; i<5 ; i=i+1 )begin
// 			cfg_top_starter[i] <= 8'd0 ;
// 			cfg_toppad_length[i] <= 8'd0 ;
// 			cfg_botpad_length[i] <= 8'd0 ;
			
// 		end
// 	end
// 	else begin
// 		//3x3
// 		cfg_top_starter		[0] <= 8'd12	;
// 		cfg_toppad_length	[0] <= 8'd24	;
// 		cfg_botpad_length	[0] <= 8'd24	;
		

// 		//5x5
// 		// cfg_top_starter		[0] <= 8'd40	;
// 		// cfg_toppad_length	[0] <= 8'd60	;
// 		// cfg_botpad_length	[0] <= 8'd40	;
// 		// cfg_top_starter		[1] <= 8'd20	;
// 		// cfg_toppad_length	[1] <= 8'd80	;
// 		// cfg_botpad_length	[1] <= 8'd80	;
// 	end
// end



//-----------------------------------------------------------------------------



always @(*) begin
	case (if_r_state)
		UP_PADDING   : row_pad_condi = TOP ;
		DOWN_PADDING : row_pad_condi = BOT ;
		default      : row_pad_condi = MID ;
	endcase
end


// always @(*) begin
// 	// row_pad_condi 		= 	( reset ) ? MID 		: TOP		;
// 	// mas_state_condi 	= 	( reset ) ? MAS_BASE 	: MAS_BASE	;
// 	// ker_conv_condi 		= 	( reset ) ? C3_MODE 	: C3_MODE	;
// end

always @(*) begin
	// padding_done = ( (cnt_once_cp == once_cp_cycle-1 ) & (cnt_colout == COLOUT_NUM-1 ) ) ? 1'd1 :1'd0 ;
	// nor_read_done = ( (cnt_once_cp == once_cp_cycle-1 ) & (cnt_colout == COLOUT_NUM-1 ) & ( cnt_ker == KER_NUM-1 ) ) ? 1'd1 : 1'd0;
	nor_read_done = ( (cnt_once_cp == once_cp_cycle-1 ) & (cnt_colout == cnt_colout_final ) & ( cnt_ker == cfg_kernum_sub1 ) ) ? 1'd1 : 1'd0;
end


always @(*) begin
	if( row_pad_condi == TOP)
		padding_done = ( (cnt_once_cp == once_cp_cycle-1 ) & (cnt_colout == cnt_colout_final ) & ( cnt_ker == cfg_kernum_sub1 )) ? 1'd1 :1'd0 ;
	else if( row_pad_condi == BOT	)
		padding_done = ( (cnt_once_cp == once_cp_cycle-1 ) & (cnt_colout == cnt_colout_final ) & ( cnt_ker == cfg_kernum_sub1 )) ? 1'd1 :1'd0 ;
	else 
		padding_done = 1'd0 ;
end


always @(posedge clk ) begin
	if(reset )begin
		rd_current_state <= 4'd0 ;
	end
	else begin
		rd_current_state <= rd_next_state ;
	end
end
always @(*) begin
	case (rd_current_state)
		RD_IDLE : rd_next_state = ( !ker_read_busy  ) ? 				RD_IDLE 	:
									( (row_pad_condi == MID) )?		NOR_MODE 	:	PAD_MODE ;

		PAD_MODE : rd_next_state = ( !padding_done ) ?		PAD_MODE : RD_DONE ;

		NOR_MODE : rd_next_state = ( !nor_read_done ) ?		NOR_MODE : RD_DONE ;

		RD_DONE	: rd_next_state = (current_state == C_DONE)	?	RD_IDLE	:	RD_DONE	;
		default: rd_next_state = RD_IDLE ;
	endcase
end	

always @(*) begin
	// rd_sram_done = ( (cnt_once_cp == once_cp_cycle-1 ) & (cnt_colout == COLOUT_NUM-1 ) & ( cnt_ker == KER_NUM-1 ) ) ? 1'd1 : 1'd0;
	rd_sram_done = ( rd_current_state == RD_DONE ) ? 1'd1 : 1'd0;
end


// ============================================================================
// =====		sram address count 	
// ============================================================================

// config one round convolution address number
// always @(posedge clk ) begin
// 	if( reset )begin
// 		once_cp_cycle <= 10'd0;
// 	end
// 	else begin
// 		once_cp_cycle <= cfg_normal_length ;
// 	end
// end

// always @(*) begin
// 	if ( rd_current_state == PAD_MODE )begin
// 		if( row_pad_condi == TOP)
// 			once_cp_cycle = cfg_toppad_length [0];
// 		else if( row_pad_condi == BOT	)
// 			once_cp_cycle = cfg_toppad_length [0];
// 		else 
// 			once_cp_cycle = cfg_normal_length;
// 	end
// 	else begin
// 		once_cp_cycle = cfg_normal_length;
// 	end
// end

//YWJ
always @(*) begin
	if ( rd_current_state == PAD_MODE )begin
		if( row_pad_condi == TOP) begin
			if(cfg_toppad_length[0] < 9) begin
				once_cp_cycle = 9 ;
			end
			else begin
				once_cp_cycle = cfg_toppad_length[0]; //<<8 + cfg_toppad_length[1] ; //20250715 cfg_toppad_length[0] ;
			end
		end
		else if( row_pad_condi == BOT) begin
			if(cfg_toppad_length[0] < 9) begin
				once_cp_cycle = 9 ;
			end
			else begin
				once_cp_cycle = cfg_toppad_length[0] ;
			end
		end
		else begin
			once_cp_cycle = cfg_normal_length ;
		end
	end
	else begin
		once_cp_cycle = cfg_normal_length ;
	end
end

always @(*) begin
	if ( rd_current_state == PAD_MODE )begin
		if( row_pad_condi == TOP)
			oncecpcycle_compare = cfg_toppad_length[0]<<8 + cfg_toppad_length[1] ; // 20250715 cfg_toppad_length [0];
		else if( row_pad_condi == BOT	)
			oncecpcycle_compare = cfg_toppad_length [0];
		else 
			oncecpcycle_compare = cfg_normal_length;
	end
	else begin
		oncecpcycle_compare = cfg_normal_length;
	end
end




assign enable_once_cp = ( (rd_current_state == NOR_MODE) & ker_read_busy )? 1'd1 : 
							( (rd_current_state == PAD_MODE) & ker_read_busy )? 1'd1 : 1'd0 ;
assign enable_cnt_colout = ( (rd_current_state == NOR_MODE) & (cnt_once_cp == once_cp_cycle-1 ) )? 1'd1 :
								( (rd_current_state == PAD_MODE) & (cnt_once_cp == once_cp_cycle-1 ) )? 1'd1 : 1'd0 ;

// assign enable_ker_cnt = ( (rd_current_state == NOR_MODE) & (cnt_colout == COLOUT_NUM-1 )  & (cnt_once_cp == once_cp_cycle-1 ) )? 1'd1 : 
// 							( (rd_current_state == PAD_MODE) & padding_done )? 1'd1 : 1'd0 ;

// assign sram_address = ( rd_current_state == PAD_MODE ) ? 	(cnt_ker*once_cp_cycle)+cnt_once_cp+cfg_top_starter  :
// 															cnt_ker*once_cp_cycle + cnt_once_cp ;	// sram address
always @(*) begin
	if(  rd_current_state == PAD_MODE  )begin
		if( row_pad_condi == MID )begin
			sram_address = cnt_ker*once_cp_cycle + cnt_once_cp ;
		end
		else if ( row_pad_condi == TOP )begin
			if(cfg_atlchin > 1)begin
				sram_address = cnt_once_cp + cfg_top_starter[0] + cnt_ker*cfg_normal_length;
			end
			else begin
				if(cnt_ker == cfg_kernum_sub1) begin									//in oreder to fix ch8\
					if(cnt_once_cp <= 5) begin
						sram_address = cnt_once_cp + cfg_top_starter[0] + cnt_ker*cfg_normal_length;	
					end
					else begin
						sram_address = 0;
					end
				end
				else begin
					sram_address = cnt_once_cp + cfg_top_starter[0] + cnt_ker*cfg_normal_length;
				end
			end
		end
		else begin
			sram_address = cnt_once_cp + cnt_ker*cfg_normal_length;	//YWJ
		end
	end
	else begin
		sram_address = cnt_ker*once_cp_cycle + cnt_once_cp ;
	end
end

always @( * ) begin
	// case (mas_state_condi)
	// 	MAS_LEFT , MAS_BASE : 
	// 		enable_ker_cnt = ((rd_current_state == NOR_MODE) & nor_read_done) ? 1'd1 : 1'd0 ;

	// 	MAS_RIGT : enable_ker_cnt = ((rd_current_state == PAD_MODE) & padding_done) ? 1'd1 : 1'd0 ;
	// 	default: enable_ker_cnt = 1'd0 ;
	// endcase
	enable_ker_cnt = ((rd_current_state == NOR_MODE) & (cnt_colout == cnt_colout_final ) & (cnt_once_cp == once_cp_cycle-1 )) ? 1'd1 :
						((rd_current_state == PAD_MODE) & (cnt_colout == cnt_colout_final ) & (cnt_once_cp == once_cp_cycle-1 ) ) ? 1'd1 : 1'd0 ;
end



//-----------------------------------------------------------------------------





assign cnt_once_cp_final	= once_cp_cycle - 1		;
assign cnt_colout_final		= cfg_colout_sub1		;
assign cnt_ker_final		= cfg_kernum_sub1		;


count_yi_v4 #(
    .BITS_OF_END_NUMBER (	ADDR_CNT_BITS	)
)kr_cp(
    .clk		( clk )
    ,	.reset 	 		(	reset	)
    ,	.enable	 		(	enable_once_cp	)

	,	.final_number	(	cnt_once_cp_final	)
	,	.last			(	cnt_once_cp_last	)
    ,	.total_q		(	cnt_once_cp	)
);


count_yi_v4 #(
    .BITS_OF_END_NUMBER (	ADDR_CNT_BITS	)
)kr_col(
    .clk		( clk )
    ,	.reset 	 		(	reset	)
    ,	.enable	 		(	enable_cnt_colout	)

	,	.final_number	(	cnt_colout_final	)
	,	.last			(						)
    ,	.total_q		(	cnt_colout			)
);

count_yi_v4 #(
    .BITS_OF_END_NUMBER (	BUF_TAG_BITS	)
)kr_ker(
    .clk		( clk )
    ,	.reset 	 		(	reset	)
    ,	.enable	 		(	enable_ker_cnt	)

	,	.final_number	(	cnt_ker_final	)
	,	.last			(					)
    ,	.total_q		(	cnt_ker	)
);


//----    2023.04.08counter replace to v4    -----
// count_yi_v3 #(
//     .BITS_OF_END_NUMBER (10)
// )cp_once0(
// 	.clk	(	clk		),
// 	.reset	(	reset	),
//     .enable (	enable_once_cp	), 
// 	.final_number(	once_cp_cycle	),
//     .cnt_q	(	cnt_once_cp	)
// );

// count_yi_v3 #(
//     .BITS_OF_END_NUMBER ( BUF_TAG_BITS )
// )cp_kernum0(
// 	.clk	(	clk		),
// 	.reset	(	reset	),
//     .enable (	enable_ker_cnt	), 
// 	.final_number(	KER_NUM	),
//     .cnt_q	(	cnt_ker	)
// );

// count_yi_v3 #(
//     .BITS_OF_END_NUMBER (ADDR_CNT_BITS)
// )cp_colout0(
// 	.clk	(	clk		),
// 	.reset	(	reset	),
//     .enable (	enable_cnt_colout	), 
// 	.final_number(	COLOUT_NUM	),
//     .cnt_q	(	cnt_colout	)
// );
//-----------------------------------------------------------------------------


// ============================================================================
// =====		assign sram signal		==== 	
// ============================================================================
always@(posedge clk )begin
	cen_dly0 <= ~enable_once_cp ;
	cen_dly1 <= cen_dly0 ;
	cen_dly2 <= cen_dly1 ;
	cen_dly3 <= cen_dly2 ;
	cen_dly4 <= cen_dly3 ;
	cen_dly5 <= cen_dly4 ;
	cen_dly6 <= cen_dly5 ;
	cen_dly7 <= cen_dly6 ;
end

always @(posedge clk ) begin
	addr_sr_dly0 <= sram_address ;
	addr_sr_dly1 <= addr_sr_dly0 ;
	addr_sr_dly2 <= addr_sr_dly1 ;
	addr_sr_dly3 <= addr_sr_dly2 ;
	addr_sr_dly4 <= addr_sr_dly3 ;
	addr_sr_dly5 <= addr_sr_dly4 ;
	addr_sr_dly6 <= addr_sr_dly5 ;
	addr_sr_dly7 <= addr_sr_dly6 ;
end


always @(posedge clk ) begin
	ker_read_busy_dly0 <= ker_read_busy;
	ker_read_busy_dly1 <= ker_read_busy_dly0 ;
	ker_read_busy_dly2 <= ker_read_busy_dly1 ;
	ker_read_busy_dly3 <= ker_read_busy_dly2 ;
	ker_read_busy_dly4 <= ker_read_busy_dly3 ;
	ker_read_busy_dly5 <= ker_read_busy_dly4 ;
	ker_read_busy_dly6 <= ker_read_busy_dly5 ;
	ker_read_busy_dly7 <= ker_read_busy_dly6 ;
end


assign valid_check = enable_once_cp;
// assign final_check = ( cnt_once_cp_dly1 == once_cp_cycle-1 ) ? 1'd1 : 1'd0 ;
// assign final_check = ( cnt_once_cp_dly1 == cnt_once_cp_final ) ? 1'd1 : 1'd0 ;
assign final_check = ( cnt_once_cp_last ) ? 1'd1 : 1'd0 ;

always @(posedge clk ) begin
	valid_dly0 <= valid_check ;
	valid_dly1 <= valid_dly0 ;
	valid_dly2 <= valid_dly1 ;
	valid_dly3 <= valid_dly2 ;
	valid_dly4 <= valid_dly3 ;
	valid_dly5 <= valid_dly4 ;
	valid_dly6 <= valid_dly5 ;
	valid_dly7 <= valid_dly6 ;
	valid_dly8 <= valid_dly7 ;
end
always @(posedge clk ) begin
	final_dly0 <= final_check ;
	final_dly1 <= final_dly0 ;
	final_dly2 <= final_dly1 ;
	final_dly3 <= final_dly2 ;
	final_dly4 <= final_dly3 ;
	final_dly5 <= final_dly4 ;
	final_dly6 <= final_dly5 ;
	final_dly7 <= final_dly6 ;
	final_dly8 <= final_dly7 ;
end

assign valid_0 = valid_dly1 ;
assign valid_1 = valid_dly2 ;
assign valid_2 = valid_dly3 ;
assign valid_3 = valid_dly4 ;
assign valid_4 = valid_dly5 ;
assign valid_5 = valid_dly6 ;
assign valid_6 = valid_dly7 ;
assign valid_7 = valid_dly8 ;

assign final_0 = final_dly1 ;
assign final_1 = final_dly2 ;
assign final_2 = final_dly3 ;
assign final_3 = final_dly4 ;
assign final_4 = final_dly5 ;
assign final_5 = final_dly6 ;
assign final_6 = final_dly7 ;
assign final_7 = final_dly8 ;



always @(*) begin
	cen_kersr_0 = ( ker_read_busy_dly0 )? cen_dly0 : 1'd1 ;
	cen_kersr_1 = ( ker_read_busy_dly1 )? cen_dly1 : 1'd1 ;
	cen_kersr_2 = ( ker_read_busy_dly2 )? cen_dly2 : 1'd1 ;
	cen_kersr_3 = ( ker_read_busy_dly3 )? cen_dly3 : 1'd1 ;
	cen_kersr_4 = ( ker_read_busy_dly4 )? cen_dly4 : 1'd1 ;
	cen_kersr_5 = ( ker_read_busy_dly5 )? cen_dly5 : 1'd1 ;
	cen_kersr_6 = ( ker_read_busy_dly6 )? cen_dly6 : 1'd1 ;
	cen_kersr_7 = ( ker_read_busy_dly7 )? cen_dly7 : 1'd1 ;
end




always @(*) begin
	addr_kersr_0 = ( ker_read_busy_dly0 )? addr_sr_dly0 : 11'd0  ;  
	addr_kersr_1 = ( ker_read_busy_dly1 )? addr_sr_dly1 : 11'd0  ;  
	addr_kersr_2 = ( ker_read_busy_dly2 )? addr_sr_dly2 : 11'd0  ;  
	addr_kersr_3 = ( ker_read_busy_dly3 )? addr_sr_dly3 : 11'd0  ;  
	addr_kersr_4 = ( ker_read_busy_dly4 )? addr_sr_dly4 : 11'd0  ;  
	addr_kersr_5 = ( ker_read_busy_dly5 )? addr_sr_dly5 : 11'd0  ;  
	addr_kersr_6 = ( ker_read_busy_dly6 )? addr_sr_dly6 : 11'd0  ;  
	addr_kersr_7 = ( ker_read_busy_dly7 )? addr_sr_dly7 : 11'd0  ;  
end





// =========================================



endmodule