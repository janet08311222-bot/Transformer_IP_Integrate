// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2022.11.23
// Ver      : 1.0
// Func     : bias sram write module, just deal with data from fifo_in
// ============================================================================



module biassram_w #(
    parameter ADDR_CNT_BITS = 9
)(
	clk,
	reset,

	bias_write_data_din			,
	bias_write_empty_n_din		,
	bias_write_read_dout		,

	cen_biasr_0 ,wen_biasr_0 ,addr_biasr_0 ,din_biasr_0 ,//----bias SRAM_0---------


	bias_rd1st_start 		,
	bias_rd1st_busy 		,
	bias_rd1st_done 		,

	bias_write_en 			,
	bias_write_done 		,
	bias_write_busy 		,
	start_bias_write		,
	cfg_biw_lengthsub1
	
);

//---------- config parameter -----------------------
	parameter BIAS_ST_LENGTH = 64;		// every layer has different bias number

//--------- local parameter --------------------------
	// parameter ADDR_CNT_BITS = 9;	
	parameter BIAS_SRAM_WLEN = 32;		// Bias sram word length for declare
//---------------------------------------------------------

//---------				I/O 			-------------------
	input wire clk ;
	input wire reset ;
	
	input wire [ 63 : 0 ] 	bias_write_data_din			;
	input wire				bias_write_empty_n_din		;
	output reg				bias_write_read_dout		;	// need cut 32 bits 

	output reg 				bias_write_done 			;
	output reg 				bias_write_busy 			;
	input wire 				start_bias_write			;

	output reg 				bias_rd1st_start 	;
	input wire 				bias_rd1st_busy 	;
	input wire 				bias_rd1st_done 	;

	output wire 			bias_write_en 		;
	output wire cen_biasr_0 	;
	output wire wen_biasr_0 	;
	output wire [ADDR_CNT_BITS -1 : 0	]	addr_biasr_0 	;
	output wire [	32	 -1 : 0	]	din_biasr_0 	;//----bias SRAM_0---------

	input wire	[ADDR_CNT_BITS-1:0] cfg_biw_lengthsub1	;
//---------------------------------------------------------




//----    busy and done    ----
reg [ 1 : 0 ] bd_current_state	;
reg [ 1 : 0 ] bd_next_state		;

wire en_ibw_cnt ;
wire [ADDR_CNT_BITS -1 : 0]cnt_inbias ;
wire cnt_inbias_last	;
wire [ADDR_CNT_BITS-1:0] cnt_ib_final	;

wire write_done_flag ;


assign bias_write_en = (bd_current_state == 2'd1 ) ? 1'd1 : 1'd0;
//===================================================================
//=============			busy and done 		=========================
//===================================================================
always @(posedge clk ) begin
	if( reset )begin
		bd_current_state <= 2'd0;
	end
	else begin
		bd_current_state <= bd_next_state ;
	end
end

always @(*) begin
	case (bd_current_state)
		2'd0: bd_next_state = ( start_bias_write ) ? 2'd1 : 2'd0 ;
		2'd1: bd_next_state = ( write_done_flag ) ? 2'd2 : 2'd1 ;	// busy
		2'd2: bd_next_state = ( bias_rd1st_done ) ? 2'd3 : 2'd2	;	// bias first read
		2'd3: bd_next_state = 2'd0 ;
		default: bd_current_state <= 2'd0;
	endcase
end

always @( * ) begin
	bias_write_busy = (bd_current_state == 2'd0 ) ? 1'd0 : 1'd1  ;
	bias_write_done = (bd_current_state == 2'd3 ) ? 1'd1 : 1'd0  ;
end

// // always @(posedge clk ) begin
// 	if( reset )begin
// 		bias_write_done <= 1'd0 ;
// 	end
// 	else begin
// 		if( (bd_current_state == 2'd3) 	 )begin		// need change
// 			bias_write_done <= 1'd1 ;
// 		end
// 		else begin
// 			bias_write_done <= 1'd0 ;
// 		end
// 	end
// end



always @(posedge clk ) begin
	if ( reset )begin
		bias_rd1st_start <= 1'd0;
	end 
	else begin
		if ( bd_current_state == 2'd2 )begin
			if( bias_rd1st_busy != 1'd1 )begin
				bias_rd1st_start <= 1'd1 ;
			end
			else begin
				bias_rd1st_start <= 1'd0 ;
			end
		end
		else begin
			bias_rd1st_start <= 1'd0 ;
		end
	end
end
//===================================================================


//===================================================================
//=============			fifo signal control		=====================
//===================================================================

// bias_write_read_dout
always @(posedge clk ) begin
	if( reset )begin
		bias_write_read_dout <= 1'd0 ;
	end
	else begin
		if( bias_write_en & bias_write_empty_n_din )begin
			bias_write_read_dout <= 1'd1 ;
		end
		else begin
			bias_write_read_dout <= 1'd0 ;
		end
	end
end

//----- input data number cnt ----------


assign en_ibw_cnt = (bias_write_empty_n_din & bias_write_read_dout ) ?	1'd1 : 1'd0 ;

// count_yi_v3 #(    .BITS_OF_END_NUMBER( ADDR_CNT_BITS  ) 
//     ) wrbias_cnt(.clk ( clk ), .reset ( reset ), .enable ( en_ibw_cnt ), .cnt_q ( cnt_inbias ),	
//     .final_number(	BIAS_ST_LENGTH	)	// it will count to final_num-1 then goes to zero
// );
count_yi_v4 #(
    .BITS_OF_END_NUMBER (	ADDR_CNT_BITS	)
)rebias_cnt00(
    .clk		( clk )
    ,	.reset 	 		(	reset	)
    ,	.enable	 		(	en_ibw_cnt	)

	,	.final_number	(	cnt_ib_final	)
	,	.last			(	cnt_inbias_last		)
    ,	.total_q		(	cnt_inbias	)
);


assign cnt_ib_final = cfg_biw_lengthsub1 ;


assign cen_biasr_0 	= ~en_ibw_cnt ;
assign wen_biasr_0 	= ~en_ibw_cnt ;
assign addr_biasr_0 	= cnt_inbias ;
assign din_biasr_0 	= bias_write_data_din[31-:32] ;

assign write_done_flag = cnt_inbias_last ;
// assign write_done_flag = ( cnt_inbias == BIAS_ST_LENGTH-1 )? 1'd1 : 1'd0 ;


endmodule