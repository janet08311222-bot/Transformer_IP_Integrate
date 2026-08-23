// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2023.02.15
// Ver      : 1.0
// Func     : packing counter and write_FSM
// 		2023.xx.xx : 
// ============================================================================


// ifw_cnt_fsm	#(
//     .CNT00_WIDTH	(		)
//     ,	.CNT01_WIDTH		(		)
//     ,	.WS_ADDR_WIDTH		(		)
//     // ,	parameter BITS_WIDTH 	= 10
// )	wr_buf_0 (
//     .clk	(		)
//     ,	.reset 	 
// 	,	.din_row_last 			(		)
// 	,	.din_ifw_curr_state 	(		)	
// 	,	.din_cfg_mast_state 	(		)	
// 	,	.dout_wr_curr_state 	(		)	
// 	,	.dout_wr_cnt00 			(		)
// 	,	.dout_wr_cnt01 			(		)
// 	,	.dout_wr_srad_cnt		(		)
// 	,	.dout_wr_stg0_last		(		)
// 	,	.dout_wr_stg1_last		(		)
// 	,	.dout_wr_srad_last		(		)

// 	,	.wr_stg0_en 			(		)	
// 	,	.wr_stg1_en 			(		)	

// 	,	.wr_cnt00_finalnum 		(		)

// 	,	.wr_cnt01_finalnum 		(		)

// 	,	.wr_srad_finalnum		(		)

// );


// ============================================================================
module ifw_cnt_fsm#(
    parameter CNT00_WIDTH = 10
    ,	parameter CNT01_WIDTH 			= 10
    ,	parameter WS_ADDR_WIDTH 		= 10
    // ,	parameter BITS_WIDTH 	= 10
)(
    clk		
    ,	reset 	 
	,	din_row_last 			
	,	din_idle2start 			
	,	din_ifw_curr_state 		
	,	din_cfg_mast_state 		

	,	dout_wr_curr_state 		
	,	dout_wr_cnt00 			
	,	dout_wr_cnt01 			
	,	dout_wr_srad_cnt		
	,	dout_wr_stg0_last		
	,	dout_wr_stg1_last		
	,	dout_wr_srad_last		

	,	wr_stg0_en 				
	,	wr_stg1_en 				
	,	wr_cnt00_finalnum 		
	,	wr_cnt01_finalnum 		
	,	wr_srad_finalnum		
	// ,	wr_srad_startnum		
	// ,	wr_cnt01_startnum 		
	// ,	wr_cnt00_startnum 	


);

//----    cfg_mast_state label    -----
localparam LEFT 	= 3'd1;
localparam NORMAL 	= 3'd2;
localparam RIGH 	= 3'd3;

//----    IW FSM for busy done and en signal declare    -----
localparam IW_IDLE	= 3'd0;
localparam IW_DLOD	= 3'd1;	// fifo data load state
localparam IW_WABF	= 3'd2;	// wait buffer 7 write done, and write_en signal should "0"
localparam IW_RST	= 3'd3;	// reset all counter for next idle
localparam IW_DONE	= 3'd4;	// done for if_write done signal


//----    write buffer fsm parameter declare    -----
localparam  WRFSM_WIDTH 	= 3 ;
// ============================================================================
// ====================		I/O declare		===================================
// ============================================================================
input	wire clk ;
input	wire reset ;


input	wire din_row_last ;
input	wire din_idle2start ;

input	wire [3-1:0]				din_ifw_curr_state ;
input	wire [3-1:0]				din_cfg_mast_state ;

output	wire [WRFSM_WIDTH-1:0]				dout_wr_curr_state ;
output	wire [CNT00_WIDTH-1:0]		dout_wr_cnt00 ;
output	wire [CNT00_WIDTH-1:0]		dout_wr_cnt01 ;
output	wire [WS_ADDR_WIDTH-1:0] 	dout_wr_srad_cnt ;
output	wire 						dout_wr_stg0_last ;
output	wire 						dout_wr_stg1_last ;
output	wire 						dout_wr_srad_last ;


input	wire wr_stg0_en ;
input	wire wr_stg1_en ;

input	wire [CNT00_WIDTH-1 :0] wr_cnt00_finalnum ;
input	wire [CNT01_WIDTH-1 :0] wr_cnt01_finalnum ;

input	wire [WS_ADDR_WIDTH-1 :0] wr_srad_finalnum ;

// input	wire [CNT01_WIDTH-1 :0] wr_cnt01_startnum ;
// input	wire [WS_ADDR_WIDTH-1 :0] wr_srad_startnum ;
// input	wire [CNT00_WIDTH-1 :0] wr_cnt00_startnum ;
// ============================================================================




//----    write buffer 0 padding fsm    -----
reg [WRFSM_WIDTH-1 :0] wr_current_state ;
reg [WRFSM_WIDTH-1 :0] wr_next_state ;

localparam WR_IDLE 		= 3'd0;
localparam WR_NORMAL	= 3'd1;
localparam WR_LEFT		= 3'd2;
localparam WR_RIGH		= 3'd3;
localparam WR_DONE		= 3'd4;

//----    counter signal declare    -----
wire [CNT00_WIDTH-1:0]	wr_cnt00 ;
wire [CNT01_WIDTH-1:0]	wr_cnt01 ;
wire wr_stg0_last ;
wire wr_stg1_last ;
wire [WS_ADDR_WIDTH-1:0] wr_srad_cnt ;
wire wr_srad_last ;

wire wr_srad_en ;


//----    I/O assignment    -----

assign dout_wr_curr_state 	= wr_current_state ;
assign dout_wr_cnt00	=	wr_cnt00	;
assign dout_wr_cnt01	=	wr_cnt01	;
assign dout_wr_srad_cnt	=	wr_srad_cnt	;
assign dout_wr_stg0_last	=	wr_stg0_last	;
assign dout_wr_stg1_last	=	wr_stg1_last	;
assign dout_wr_srad_last	=	wr_srad_last	;	// SRAM address
//-----------------------------------------------------------------------------

count_yi_v4 #(
    .BITS_OF_END_NUMBER (	CNT00_WIDTH	)
)b0_ct00(
    .clk		( clk )
    ,	.reset 	 		(	reset	)
    ,	.enable	 		(	wr_stg0_en	)

	,	.final_number	(	wr_cnt00_finalnum	)
	,	.last			(	wr_stg0_last	)
    ,	.total_q		(	wr_cnt00	)
);
count_yi_v4 #(
    .BITS_OF_END_NUMBER (	CNT01_WIDTH	)
)b0_ct01(
    .clk		( clk )
    ,	.reset 	 		(	reset	)
    ,	.enable	 		(	wr_stg1_en	)

	,	.final_number	(	wr_cnt01_finalnum	)
	,	.last			(	wr_stg1_last	)
    ,	.total_q		(	wr_cnt01	)
);
count_yi_v4 #(
    .BITS_OF_END_NUMBER (	WS_ADDR_WIDTH	)
)b0_addrct00(
    .clk		( clk )
    ,	.reset 	 		(	reset	)
    ,	.enable	 		(	wr_srad_en	)

	,	.final_number	(	wr_srad_finalnum	)
	,	.last			(	wr_srad_last	)
    ,	.total_q		(	wr_srad_cnt	)
);

assign wr_srad_en = wr_stg0_en ;

//----    write buffer 0 padding fsm    -----
always @(posedge clk ) begin
	if( reset ) wr_current_state <= WR_IDLE ;
	else wr_current_state <= wr_next_state ;
end
always @(*) begin
	case (wr_current_state)
		// WR_IDLE :	wr_next_state = ( ~(  (din_ifw_curr_state == IW_DLOD)	||	(din_ifw_curr_state == IW_WABF) ) ) ? WR_IDLE :
		WR_IDLE :	wr_next_state = ( !din_idle2start  ) ? WR_IDLE :
									( din_cfg_mast_state == LEFT ) ? WR_LEFT : WR_NORMAL ;
										// ( din_cfg_mast_state == RIGH ) ? WR_RIGH  : WR_NORMAL ;

		WR_LEFT :  	wr_next_state = ( wr_stg0_last & wr_cnt01_finalnum ) ? WR_NORMAL : WR_LEFT ;
		// WR_LEFT :  	wr_next_state = ( wr_stg0_last && wr_cnt01_finalnum ) ? WR_NORMAL : WR_LEFT ;


		WR_RIGH :  	wr_next_state = ( wr_stg0_last  & (wr_stg1_last) & ( din_row_last ) ) ? WR_DONE : 
										( wr_stg0_last  &  ( wr_stg1_last ) & ( !din_row_last ) ) ? WR_NORMAL : WR_RIGH ;

		WR_NORMAL :	begin
			case (din_cfg_mast_state)
				LEFT: wr_next_state = ( wr_stg0_last  & (wr_stg1_last) & ( !din_row_last ) ) ?  WR_LEFT: 
											( wr_stg0_last  & (wr_stg1_last) & ( din_row_last ) ) ?  WR_DONE : WR_NORMAL ;

				RIGH: wr_next_state = ( wr_stg0_last  & (wr_cnt01 == wr_cnt01_finalnum-1 ) ) ?  WR_RIGH : WR_NORMAL;
				NORMAL : wr_next_state = ( wr_stg0_last  & (wr_stg1_last) & ( din_row_last ) ) ?  WR_DONE : WR_NORMAL ;
				default: wr_next_state = WR_IDLE ;	// when it doesn't figure out which state it wants.
			endcase
		end
			
		WR_DONE : wr_next_state = WR_IDLE ;
		default: wr_next_state = WR_IDLE ;
	endcase
end

//-----------------------------------------------------------------------------


endmodule

