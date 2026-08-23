// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2022.12.15
// Ver      : 1.0
// Func     : output read sram module
//			the config and counter formula = ct_gp * cfg_ot_sft_gp + ct_cha * cfg_ot_sft_colpra + ct_col	
// ============================================================================

module ot_read #(
	parameter	SRAM_DATA_BITS = 64
	,	SRAM_ADDR_BITS = 12  //HYR
)
(
	clk			
	,	reset		

	,	start		
	,	busy		
	,	done	

	,	din_s2mm_tready	
	,	fifo_full_n		
	,	fifo_write		
	,	fifo_last		
	,	fifo_data		

	,	data_from_sram	
	,	addr_otsr	
	,	cen_otsr	
	,	wen_otsr

	,	cfg_ot_tgpfnsub1		
	,	cfg_ot_tcolfnsub1		
	,	cfg_ot_tchafnsub1		
	,	cfg_ot_sft_gp			
	,	cfg_ot_sft_colpra		

);




	// localparam SRAM_DATA_BITS = 64;
	// localparam SRAM_ADDR_BITS = 10;
//-----------------------------------------------------------------------------

	input clk		;
	input reset		;

	input	wire 	start		;
	output	wire 	busy		;
	output	reg 	done		;

	
	input	wire 	din_s2mm_tready		;
	input	wire 	fifo_full_n		;
	output	wire 	fifo_write		;
	output	wire 	fifo_last		;
	output	wire [ SRAM_DATA_BITS-1 : 0 ] fifo_data ;

	output cen_otsr	;
	output wen_otsr	;
	output [ SRAM_ADDR_BITS-1 : 0 ]		addr_otsr		;
	input	wire [ SRAM_DATA_BITS-1 : 0 ] data_from_sram ;


	input wire [SRAM_ADDR_BITS-1:0]	cfg_ot_tgpfnsub1	;// counter for column group. col_out /8 -1= 16/8-1= 1 
	input wire [SRAM_ADDR_BITS-1:0]	cfg_ot_tcolfnsub1	;// counter for column in PE column parallel number . 8-1=7
	input wire [SRAM_ADDR_BITS-1:0]	cfg_ot_tchafnsub1	;// counter for output channel divide 8  . ch_out/8-1= 64/8-1 = 7
	input wire [SRAM_ADDR_BITS-1:0]	cfg_ot_sft_gp		;// shifter for each column group address in output SRAM, 8col_parallel* ch_out /8 = 8*64/8=64
	input wire [SRAM_ADDR_BITS-1:0]	cfg_ot_sft_colpra	;// shifter for total PE column parallel number = 8
//-----------------------------------------------------------------------------
//------	Declare		-----------------------------------------------------

	//---- sram reading address generate ----
	reg en_write ;
	wire addr_last ;
	// reg [ SRAM_ADDR_BITS -1 : 0 ] cnt_addr ;
	//-----------------------------------------------------------------------------
	
	wire fsm_rstcnt	;
	wire acnt_rst		;
	wire [SRAM_ADDR_BITS-1:0]ct_gp	;
	wire [SRAM_ADDR_BITS-1:0]ct_gp_finnumsub1	;

	wire [SRAM_ADDR_BITS-1:0]ct_cha	;
	wire [SRAM_ADDR_BITS-1:0]ct_cha_finnumsub1	;

	wire [SRAM_ADDR_BITS-1:0]ct_col	;
	wire [SRAM_ADDR_BITS-1:0]ct_col_finnumsub1	;

	wire ct_col_en	;
	wire ct_col_last	;

	wire ct_cha_en	;
	wire ct_cha_last	;

	wire ct_gp_en	;
	wire ct_gp_last	;

	//----    shift index for     -----
	reg [SRAM_ADDR_BITS-1:0]shtidx_cha	;
	reg [SRAM_ADDR_BITS-1:0]shtidx_gp	;
	reg [SRAM_ADDR_BITS-1:0]shtidx_col	;


	//---- synchronize sram reading data ----

	reg valid_srdata_dly0 ;
	reg valid_srdata_dly1 ;
	reg valid_srdata_dly2 ;

	reg addr_last_dly0;
	reg addr_last_dly1;
	reg addr_last_dly2;

	reg [ SRAM_DATA_BITS-1 : 0 ] srdata_dly0 ;
	reg [ SRAM_DATA_BITS-1 : 0 ] srdata_dly1 ;
	reg [ SRAM_DATA_BITS-1 : 0 ] srdata_dly2 ;
	//---- address FSM ----

	localparam AD_READ_SRAM = 2'd1 ;
	reg [2-1:0] addr_curr_state ;
	reg [2-1:0] addr_next_state ;
	//----    s2mm ready check    -----
	reg chk_s2mm_tready ;

// ============================================================================
// ===== busy & done
// ============================================================================
	localparam FSM_BITS = 2 ;
	localparam IDLE 		=	2'd0 ;
	localparam BASE_BUSY	=	2'd1 ;
	localparam RST_CNT		=	2'd2 ;

	reg [FSM_BITS -1 : 0 ]current_state;
	reg [FSM_BITS -1 : 0 ]next_state;
	
always @(posedge clk ) begin
	if ( reset ) current_state <= IDLE ;
	else current_state <= next_state ;
end
always @(*) begin
	case (current_state)
		IDLE		: next_state = ( start ) ? BASE_BUSY : IDLE ;
		BASE_BUSY	: next_state = ( addr_curr_state==RST_CNT ) ?	RST_CNT : BASE_BUSY ;
		RST_CNT		: next_state =  IDLE	;
		default: next_state = IDLE ;
	endcase
end

assign busy = ( current_state == BASE_BUSY | current_state == RST_CNT ) ?  1'd1 : 1'd0 ;

always @(*) begin
	done = ( !busy ) ? 1'd0 :
			(current_state== RST_CNT) ? 1'd1 : 1'd0 ;
end
// always @(posedge clk ) begin
// 	if( reset )begin
// 		done <= 1'd0 ;
// 	end
// 	else begin
// 		if( busy )begin
// 			if( current_state== RST_CNT)begin
// 				done <= 1'd1 ;
// 			end
// 			else begin
// 				done <= 1'd0 ;
// 			end
// 		end
// 		else begin
// 			done <= 1'd0 ;
// 		end
// 	end
// end

//--------------------------------------------------------------------------------
// ============================================================================
// =====  output fifo signal connection
// ============================================================================
assign fifo_write	= valid_srdata_dly2 ;
assign fifo_last	= addr_last_dly2 ;
assign fifo_data	= srdata_dly0	;



// ============================================================================
// =====  sram reading address generate 
// ============================================================================
always @(posedge clk ) begin
	if(reset )begin
		chk_s2mm_tready <= 1'd0;
	end
	else begin
		chk_s2mm_tready <= din_s2mm_tready ;
	end
end

always @(posedge clk ) begin
	if(reset )begin
		addr_curr_state <= IDLE ;
	end
	else begin
		addr_curr_state <= addr_next_state ;
	end
end
always @(*) begin
	case (addr_curr_state)
		IDLE	: addr_next_state = ( current_state == BASE_BUSY  )? AD_READ_SRAM : IDLE ;
		AD_READ_SRAM	: addr_next_state = ( addr_last  )? RST_CNT : AD_READ_SRAM ;
		RST_CNT	: addr_next_state = IDLE ;
		default: addr_next_state = IDLE ;
	endcase
end

//---- control ----
always @(*) begin
	if(reset)begin
		en_write = 1'd0;
	end
	else begin
		case (addr_curr_state)
			IDLE			: en_write = 1'd0 ;
			// AD_READ_SRAM	: en_write = fifo_full_n ;
			AD_READ_SRAM	: en_write = chk_s2mm_tready ;
			RST_CNT			: en_write = 1'd0 ;
			default: en_write = 1'd0 ;
		endcase	
	end

end

assign cen_otsr = ~valid_srdata_dly0 ;
assign wen_otsr = 1'd1 ;

assign addr_otsr = shtidx_gp + shtidx_cha + shtidx_col  ;
// assign addr_otsr = ct_gp * cfg_ot_sft_gp + ct_cha * cfg_ot_sft_colpra + ct_col  ;

// assign addr_last = ( !en_write )? 1'd0 :
// 					( cnt_addr ==  ADDR_FINAL-1) ? 1'd1 : 1'd0 ;
assign addr_last = ( !en_write )? 1'd0 :
						( ct_col_last & ct_cha_last & ct_gp_last )? 1'd1 : 1'd0 ;



//----    address stage pipeline    -----

always @(posedge clk ) begin
	if( reset )begin
		shtidx_cha <= 0;
		shtidx_gp <= 0 ;
		shtidx_col <= 0 ;
	end
	else begin
		shtidx_cha	<= ct_cha * cfg_ot_sft_colpra ;
		shtidx_gp	<= ct_gp * cfg_ot_sft_gp ;
		shtidx_col	<= ct_col  ;
	end
end

//================================================	
//========    address generate counter    ========	
//================================================	

//ct_gp * cfg_ot_sft_gp + ct_cha * cfg_ot_sft_colpra + ct_col

// cfg_ot_tgpfnsub1	
// cfg_ot_tcolfnsub1	
// cfg_ot_tchafnsub1	
// cfg_ot_sft_gp		
// cfg_ot_sft_colpra	




assign ct_gp_finnumsub1		=	cfg_ot_tgpfnsub1	;
assign ct_cha_finnumsub1	=	cfg_ot_tchafnsub1	;
assign ct_col_finnumsub1	=	cfg_ot_tcolfnsub1	;
assign ct_gp_en		= ( ct_col_last & ct_cha_last )? en_write : 1'd0 ;
assign ct_cha_en	= en_write ;
assign ct_col_en	= ( ct_cha_last )? en_write : 1'd0 ;
// assign ct_gp_en		= ( ct_col_last & ct_cha_last )? en_write : 1'd0 ;
// assign ct_cha_en	= ( ct_col_last )? en_write : 1'd0 ;
// assign ct_col_en	= en_write	;


//----    reset all cnt    -----
assign fsm_rstcnt	= (addr_curr_state== RST_CNT) ? 1'd1 : 1'd0 ;
assign acnt_rst		= reset | fsm_rstcnt ;

count_yi_v4 #(
    .BITS_OF_END_NUMBER (	SRAM_ADDR_BITS	)
)otr_ct00(
    .clk		( clk )
    ,	.reset 	 		(	acnt_rst	)
    ,	.enable	 		(	ct_gp_en	)

	,	.final_number	(	ct_gp_finnumsub1	)
	,	.last			(	ct_gp_last	)
    ,	.total_q		(	ct_gp	)
);
count_yi_v4 #(
    .BITS_OF_END_NUMBER (	SRAM_ADDR_BITS	)
)otr_ct01(
    .clk		( clk )
    ,	.reset 	 		(	acnt_rst	)
    ,	.enable	 		(	ct_cha_en	)

	,	.final_number	(	ct_cha_finnumsub1	)
	,	.last			(	ct_cha_last	)
    ,	.total_q		(	ct_cha	)
);
count_yi_v4 #(
    .BITS_OF_END_NUMBER (	SRAM_ADDR_BITS	)
)otr_ct02(
    .clk		( clk )
    ,	.reset 	 		(	acnt_rst	)
    ,	.enable	 		(	ct_col_en	)

	,	.final_number	(	ct_col_finnumsub1	)
	,	.last			(	ct_col_last	)
    ,	.total_q		(	ct_col	)
);
//---- counter for address -----
// always @(posedge clk ) begin
// 	if( reset )begin
// 		cnt_addr <= 10'd0 ;
// 	end
// 	else begin
// 		if( en_write )begin
// 			if ( cnt_addr < ADDR_FINAL-1 )begin
// 				cnt_addr <= cnt_addr + 10'd1 ;
// 			end
// 			else begin
// 				cnt_addr <= 10'd0 ;		// if over or equal final number then clear cnt
// 			end
// 		end
// 		else begin
// 			if( addr_curr_state == RST_CNT) begin
// 				cnt_addr <= 10'd0 ;
// 			end
// 			else begin
// 				cnt_addr <= cnt_addr ;	
// 			end

// 		end
// 	end
// end


// ============================================================================
// =====  synchronize sram reading data
// ============================================================================
always @(posedge clk ) begin
	if(  reset )begin
		valid_srdata_dly0 <= 1'd0 ;
		valid_srdata_dly1 <= 1'd0 ;
		valid_srdata_dly2 <= 1'd0 ;
	end
	else begin
		valid_srdata_dly0 <= en_write ;
		valid_srdata_dly1 <= valid_srdata_dly0 ;
		valid_srdata_dly2 <= valid_srdata_dly1 ;
	end
end

always @(posedge clk ) begin
	addr_last_dly0 <= addr_last ;
	addr_last_dly1 <= addr_last_dly0 ;
	addr_last_dly2 <= addr_last_dly1 ;
end


always @(posedge clk ) begin
	srdata_dly0 <= data_from_sram ;
	srdata_dly1 <= srdata_dly0 ;
	srdata_dly2 <= srdata_dly1 ;
end


//-------------------------------------------------------------------
endmodule
