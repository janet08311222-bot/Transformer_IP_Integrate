// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2023.02.20
// Ver      : 1.0
// Func     : just generate if sram signel
//				2nd stage padding control FSM : flow1 padding buf0,7 , flow2 padding 1,6
// 		2023.02.20 : Cause pad<=2 , so only write buffer 0,1,6,7.
// ============================================================================

//==============================================================================
// ifsram_pd #(
// 	.TBITS (	)
// 	,	.TBYTE (	)
// )aaass(
//  	.clk			(		)
// 	,	.reset		(		)
	
// 	,	.if_pad_done 	(		)		
// 	,	.if_pad_busy 	(		)		
// 	,	.if_pad_start	(		)		

// );
//==============================================================================

//----    define for testing    -----
// `define LEFT_3CP
// `define LEFT_5CP
// `define RIGH_3CP
// `define RIGH_5CP



module ifsram_pd #(
	parameter TBITS = 64 
	,	TBYTE = 8
	,	IFMAP_SRAM_ADDBITS 		= 11
	,	IFMAP_SRAM_DATA_WIDTH	= 64
)(
 	clk			
	,	reset		
	
	,	if_pad_done 			
	,	if_pad_busy 			
	,	if_pad_start			

	,	pdb0_cen	
	,	pdb0_wen	
	,	pdb0_addr	
	,	pdb1_cen	
	,	pdb1_wen	
	,	pdb1_addr	
	,	pdb6_cen	
	,	pdb6_wen	
	,	pdb6_addr	
	,	pdb7_cen	
	,	pdb7_wen	
	,	pdb7_addr	
	,	pd_data	

	//config input setting
	,	cfg_atlchin
	,	cfg_conv_switch
	,	cfg_mast_state
	,	cfg_pd_list_0
	,	cfg_pd_list_1
	,	cfg_pd_list_2
	,	cfg_pd_list_3
	,	cfg_pd_list_4
	,	cfg_cnt_step_p1
	,	cfg_cnt_step_p2


);
//----    bit width parameter    -----


localparam CNTSTP_WIDTH = 3;
localparam CNTROW_WIDTH = 3;


//==============================================================================
//========    I/O declare    ========
//==============================================================================

input	wire				clk		;
input	wire				reset	;
output	reg					if_pad_done 	;
output	reg					if_pad_busy 	;
input	wire				if_pad_start	;

output	wire	pdb0_cen ;
output	wire	pdb1_cen ;
output	wire	pdb6_cen ;
output	wire	pdb7_cen ;

output	wire	pdb0_wen ;
output	wire	pdb1_wen ;
output	wire	pdb6_wen ;
output	wire	pdb7_wen ;

output	wire	[IFMAP_SRAM_ADDBITS-1:0] pdb0_addr ;
output	wire	[IFMAP_SRAM_ADDBITS-1:0] pdb1_addr ;
output	wire	[IFMAP_SRAM_ADDBITS-1:0] pdb6_addr ;
output	wire	[IFMAP_SRAM_ADDBITS-1:0] pdb7_addr ;

output	wire	[TBITS-1:0] pd_data ;

//config input setting
input	wire		[8-1:0]	cfg_atlchin 		;
input	wire		[3-1:0] cfg_conv_switch 	;
input	wire		[3-1:0]	cfg_mast_state		;	
input	wire		[IFMAP_SRAM_ADDBITS-1:0]	cfg_pd_list_0		;
input	wire		[IFMAP_SRAM_ADDBITS-1:0]	cfg_pd_list_1		;
input	wire		[IFMAP_SRAM_ADDBITS-1:0]	cfg_pd_list_2		;
input	wire		[IFMAP_SRAM_ADDBITS-1:0]	cfg_pd_list_3		;
input	wire		[IFMAP_SRAM_ADDBITS-1:0]	cfg_pd_list_4		;	
input	wire 		[CNTSTP_WIDTH-1:0] cfg_cnt_step_p1 ;
input	wire 		[CNTSTP_WIDTH-1:0] cfg_cnt_step_p2 ;
//

//-----------------------------------------------------------------------------

//----   config register declare     -----
// reg	[5-1:0]	cfg_atlchin 		;
// reg	[3-1:0] cfg_conv_switch 	;
// reg	[2-1:0]	cfg_mast_state		;

// reg	[IFMAP_SRAM_ADDBITS-1:0]	cfg_pd_list_0		;
// reg	[IFMAP_SRAM_ADDBITS-1:0]	cfg_pd_list_1		;
// reg	[IFMAP_SRAM_ADDBITS-1:0]	cfg_pd_list_2		;
// reg	[IFMAP_SRAM_ADDBITS-1:0]	cfg_pd_list_3		;
// reg	[IFMAP_SRAM_ADDBITS-1:0]	cfg_pd_list_4		;

// reg [CNTSTP_WIDTH-1:0] cfg_cnt_step_p1 ;
// reg [CNTSTP_WIDTH-1:0] cfg_cnt_step_p2 ;
//-----------------------------------------------------------------------------
//--------		Config master state		-----------
localparam LEFT 	= 3'd1;
localparam NORMAL 	= 3'd2;
localparam RIGH 	= 3'd3;
localparam FSLD 	= 3'd7;	// First load sram0

//----    padding fsm    -----
localparam PD_IDLE = 2'd0 ;
localparam PD_LEFT = 2'd1 ;
localparam PD_RIGH = 2'd2 ;
localparam PD_DONE = 2'd3 ;

reg	[2-1:0] pd_current_state ;
reg	[2-1:0] pd_next_state ;

reg	[2-1:0] pd2_current_state ;
reg	[2-1:0] pd2_next_state ;

localparam P2_IDLE 	= 2'd0;	// now padding first column
localparam P2_FLOW1 = 2'd1;	// now padding first column
localparam P2_FLOW2 = 2'd2;	// now padding second column
localparam P2_DR 	= 2'd3;	// counter done and reset

//-----------------------------------------------------------------------------

//----    SRAM signal    -----
wire	[IFMAP_SRAM_ADDBITS-1:0] sram_addr ;
reg		[IFMAP_SRAM_ADDBITS-1:0] pd_row_shifter;
reg [5-1:0] atl_ch_shift ;
//-----------------------------------------------------------------------------

//----    counter declare    -----


wire [CNTSTP_WIDTH-1:0] cnts00;
wire [CNTROW_WIDTH-1:0] cntr01;

wire cnts00_last;
wire cntr01_last;

wire cnts00_enable;
wire cntr01_enable;


localparam BDFSM_WIDTH = 2	;
reg [BDFSM_WIDTH-1:0]	current_state;
reg [BDFSM_WIDTH-1:0]	next_state;
wire pd_end_check ;
wire pd2_flow_done ;


// //-----------------------------------------------------------------------------


// `ifdef LEFT_3CP
// 	localparam PD_LIST_0 = 9'd0		;
// 	localparam PD_LIST_1 = 9'd24	;
// 	localparam PD_LIST_2 = 9'd48	;
// 	localparam PD_LIST_3 = 9'd0		;
// 	localparam PD_LIST_4 = 9'd0		;
// `elsif LEFT_5CP
// 	localparam PD_LIST_0 = 9'd0		;
// 	localparam PD_LIST_1 = 9'd20	;
// 	localparam PD_LIST_2 = 9'd40	;
// 	localparam PD_LIST_3 = 9'd60		;
// 	localparam PD_LIST_4 = 9'd80		;
// `elsif RIGH_3CP
// 	localparam PD_LIST_0 = 9'd44	;
// 	localparam PD_LIST_1 = 9'd56	;
// 	localparam PD_LIST_2 = 9'd68	;
// 	localparam PD_LIST_3 = 9'd0		;
// 	localparam PD_LIST_4 = 9'd0		;
// `elsif RIGH_5CP
// 	localparam PD_LIST_0 = 9'd112		;
// 	localparam PD_LIST_1 = 9'd132		;
// 	localparam PD_LIST_2 = 9'd152		;
// 	localparam PD_LIST_3 = 9'd172		;
// 	localparam PD_LIST_4 = 9'd192		;
// `endif 
// // ============================================================================
// // ========		Config register		 ==========================================
// // ============================================================================
// //----   config register generate     -----
// always @(posedge clk ) begin
// 	if(reset)begin
// 		cfg_atlchin		<= 5'd4		;	// ch64->8 ch32->4 ... = ch_in/8
// 		//----    padding list for shifting    -----
// 		cfg_pd_list_0	<= PD_LIST_0	;	// use c_code compute
// 		cfg_pd_list_1	<= PD_LIST_1	;	// use c_code compute
// 		cfg_pd_list_2	<= PD_LIST_2	;	// use c_code compute
// 		cfg_pd_list_3	<= PD_LIST_3	;	// use c_code compute
// 		cfg_pd_list_4	<= PD_LIST_4	;	// use c_code compute
// 		cfg_cnt_step_p1	<= 3'd7	;		// 3x3 = 3'd3 , 5x5 = 3'd7 
// 		cfg_cnt_step_p2	<= 3'd3	;		// 3x3 = 3'd0 , 5x5 = 3'd3 
// 		// cfg_cnt_row		<= 3'd4	;	// 3x3 = 3'd2 , 5x5 = 3'd4 
// 	end
// 	else begin
// 		cfg_atlchin		<= cfg_atlchin		;
// 		//----    padding list for shifting which reference LEFT RIGHT    -----
// 		cfg_pd_list_0	<= PD_LIST_0	;
// 		cfg_pd_list_1	<= PD_LIST_1	;
// 		cfg_pd_list_2	<= PD_LIST_2	;
// 		cfg_pd_list_3	<= PD_LIST_3	;
// 		cfg_pd_list_4	<= PD_LIST_4	;
// 		cfg_cnt_step_p1	<= cfg_cnt_step_p1	;
// 		cfg_cnt_step_p2	<= cfg_cnt_step_p2	;
// 		// cfg_cnt_row		<= cfg_cnt_row	;
// 	end
// end
// always @(posedge clk ) begin
// 	if(reset)begin
// 		`ifdef LEFT_3CP
// 			cfg_cnt_step_p1	<= 3'd3	;		// atl_ch_in*1 -1 =3
// 			cfg_cnt_step_p2	<= 3'd0	;		
// 			cfg_mast_state	<= LEFT 	;	//NORMAL LEFT RIGH 	
// 			cfg_conv_switch <= 3'd2		;	// 3x3 = 3'd2 , 5x5 = 3'd3 
// 		`elsif LEFT_5CP
// 			cfg_cnt_step_p1	<= 3'd7	;		// atl_ch_in*2 -1 =7
// 			cfg_cnt_step_p2	<= 3'd3	;		// atl_ch_in -1	=3
// 			cfg_mast_state	<= LEFT 	;	//NORMAL LEFT RIGH 	
// 			cfg_conv_switch <= 3'd3		;	// 3x3 = 3'd2 , 5x5 = 3'd3 
// 		`elsif RIGH_3CP
// 			cfg_cnt_step_p1	<= 3'd3	;		
// 			cfg_cnt_step_p2	<= 3'd0	;		
// 			cfg_mast_state	<= RIGH 	;	//NORMAL LEFT RIGH 	
// 			cfg_conv_switch <= 3'd2		;	// 3x3 = 3'd2 , 5x5 = 3'd3 
// 		`elsif RIGH_5CP
// 			cfg_cnt_step_p1	<= 3'd7	;		
// 			cfg_cnt_step_p2	<= 3'd3	;	
// 			cfg_mast_state	<= RIGH 	;	//NORMAL LEFT RIGH 	
// 			cfg_conv_switch <= 3'd3		;	// 3x3 = 3'd2 , 5x5 = 3'd3 
// 		`endif 

// 	end
// 	else begin
// 		cfg_cnt_step_p1	<= cfg_cnt_step_p1	;
// 		cfg_cnt_step_p2	<= cfg_cnt_step_p2	;
// 		cfg_mast_state	<= cfg_mast_state	;	//NORMAL LEFT RIGH 	
// 		cfg_conv_switch <= cfg_conv_switch 	;	// 3x3 = 3'd2 , 5x5 = 3'd3 
// 	end
// end

wire [CNTSTP_WIDTH-1:0] cnts00_finnum ;
wire [CNTSTP_WIDTH-1:0] pd2_cnt_step ;

wire [CNTROW_WIDTH-1:0] cntr01_finnum ;

assign cnts00_finnum =	( cfg_conv_switch == 3'd2) ? cfg_cnt_step_p1 : 
							( cfg_conv_switch == 3'd3) ? pd2_cnt_step : 0 ;
assign cntr01_finnum = 	( cfg_conv_switch == 3'd2) ? 3'd3 :
							( cfg_conv_switch == 3'd3) ? 3'd4 : 3'd5 ;

assign pd2_cnt_step = (pd2_current_state == P2_FLOW1)? cfg_cnt_step_p1 :
						(pd2_current_state == P2_FLOW2)? cfg_cnt_step_p2 : 0 ;


// ============================================================================
// ===== busy & done
// ============================================================================

always @(posedge clk ) begin
	if(reset) begin
		current_state <= 2'd0;
	end
	else begin
		current_state <= next_state;
	end
end
always @(*) begin
	case (current_state)
		2'd0: next_state = (if_pad_start) ? 2'd1 : 2'd0 ;
		2'd1: next_state = (pd_end_check) ? 2'd2 : 2'd1 ;
		2'd2: next_state = 2'd3 ;	// for reset all counter
		2'd3: next_state = 2'd0 ;
		default: next_state = 2'd0 ;
	endcase	
end


always @( * ) begin
	if_pad_busy =	( (current_state == 2'd0) ) ? 1'd0 : 1'd1 ;
	if_pad_done =	(current_state == 2'd3) ? 1'd1 : 1'd0  ;	
end

assign pd_end_check = ( pd_current_state == PD_DONE) ? 1'd1 : 1'd0 ;
//-----------------------------------------------------------------------------
//==============================================================================
//========    left right padding control FSM    ========
//==============================================================================
always @(posedge clk ) begin
	if( reset ) pd_current_state <= PD_IDLE ;
	else pd_current_state <= pd_next_state ;
end
always @(*) begin
	case (pd_current_state)
		PD_IDLE :	pd_next_state = ( !(current_state == 2'd1 ) ) ? PD_IDLE :
										( cfg_mast_state == LEFT ) ? PD_LEFT :	
										( cfg_mast_state == FSLD ) ? PD_LEFT :	
											( cfg_mast_state == RIGH ) ? PD_RIGH :	PD_IDLE	;	// if pd_current_state hold IDLE. it fucked up.
		PD_LEFT :	pd_next_state = (pd2_flow_done)? PD_DONE : PD_LEFT ;
		PD_RIGH :	pd_next_state = (pd2_flow_done)? PD_DONE : PD_RIGH ;
		PD_DONE :	pd_next_state = PD_IDLE	;
		default	:	pd_next_state = PD_IDLE	;
	endcase
end


assign pd2_flow_done = ( pd2_current_state == P2_DR) ? 1'd1 : 1'd0 ;

//==============================================================================
//========    2nd stage padding control FSM    ========
//==============================================================================
//----    pd2 padding flow control FSM    -----
always @(posedge clk ) begin
	if(reset) pd2_current_state <= PD_IDLE ;
	else  pd2_current_state <= pd2_next_state ;
end
always @(*) begin
	case (pd2_current_state)
		P2_IDLE  : pd2_next_state = (( pd_current_state == PD_LEFT ) || ( pd_current_state == PD_RIGH ))? P2_FLOW1 : P2_IDLE ;
		P2_FLOW1 : pd2_next_state = ( !(cnts00_last & cntr01_last)) ? P2_FLOW1 :
										(cfg_conv_switch == 3'd3 )? P2_FLOW2 : P2_DR ;
		P2_FLOW2 : pd2_next_state = ( cnts00_last & cntr01_last) ? P2_DR : P2_FLOW2 ;
		P2_DR : pd2_next_state = P2_IDLE ;
		default:  pd2_next_state = P2_IDLE ;
	endcase
end
// ============================================================================
// ================     instance         ======================================
// ============================================================================
// wire en_cnt ;
// assign en_cnt = (( pd2_current_state == P2_FLOW1) || ( pd2_current_state == P2_FLOW2)) ? 1'd1 : 1'd0 ;

assign cnts00_enable = (( pd2_current_state == P2_FLOW1) || ( pd2_current_state == P2_FLOW2)) ? 1'd1 : 1'd0 ;
assign cntr01_enable = (cnts00_last) ? 1'd1 : 1'd0 ;



count_yi_v4 #(
    .BITS_OF_END_NUMBER (	CNTSTP_WIDTH	)
)pd_ct00(
    .clk		( clk )
    ,	.reset 	 		(	reset	)
    ,	.enable	 		(	cnts00_enable	)

	,	.final_number	(	cnts00_finnum	)
	,	.last			(	cnts00_last	)
    ,	.total_q		(	cnts00	)
);
count_yi_v4 #(
    .BITS_OF_END_NUMBER (	CNTROW_WIDTH	)
)pd_ct01(
    .clk		( clk )
    ,	.reset 	 		(	reset	)
    ,	.enable	 		(	cntr01_enable	)

	,	.final_number	(	cntr01_finnum	)
	,	.last			(	cntr01_last	)
    ,	.total_q		(	cntr01	)
);


//==============================================================================
//========    SRAM signal     ========
//==============================================================================

assign sram_addr = cnts00 + atl_ch_shift + pd_row_shifter ;


always @(*) begin
	case (cntr01)
		3'd0: pd_row_shifter = cfg_pd_list_0 ;
		3'd1: pd_row_shifter = cfg_pd_list_1 ;
		3'd2: pd_row_shifter = cfg_pd_list_2 ;
		3'd3: pd_row_shifter = cfg_pd_list_3 ;
		3'd4: pd_row_shifter = cfg_pd_list_4 ;
		default: pd_row_shifter = 0 ;
	endcase
end


always @(*) begin
	if(pd_current_state == PD_RIGH)begin
		case (pd2_current_state)
			P2_FLOW1 , P2_IDLE	: atl_ch_shift = 5'd0;

			P2_FLOW2	: atl_ch_shift = cfg_atlchin;

			default: atl_ch_shift = 5'd0;
		endcase
	end
	else begin
		atl_ch_shift = 5'd0;
	end
end

//-----------------------------------------------------------------------------

assign pdb0_cen		= (pd_current_state==PD_LEFT) ? ( pd2_current_state == P2_FLOW1 ) ? (  cnts00_enable  ) ? 1'd0 : 1'd1  : 1'd1 : 1'd1 ;
assign pdb0_wen		= pdb0_cen	;
assign pdb0_addr	= sram_addr ;

assign pdb1_cen		= (pd_current_state==PD_LEFT) ? ( pd2_current_state == P2_FLOW2 ) ? (  cnts00_enable  ) ? 1'd0 : 1'd1  : 1'd1 : 1'd1 ;
assign pdb1_wen		= pdb1_cen	;
assign pdb1_addr	= sram_addr ;

assign pdb6_cen		= (pd_current_state==PD_RIGH) ? ( pd2_current_state == P2_FLOW2 ) ? (  cnts00_enable  ) ? 1'd0 : 1'd1  : 1'd1 : 1'd1 ;
assign pdb6_wen		= pdb6_cen	;
assign pdb6_addr	= sram_addr ;

// assign pdb7_cen		= (pd_current_state==PD_RIGH) ? ( pd2_current_state == P2_FLOW1 ) ? (  cnts00_enable  ) ? 1'd0 : 1'd1  : 1'd1 : 1'd1 ;
assign pdb7_wen		= pdb7_cen	;
// assign pdb7_addr	= sram_addr	;
assign pd_data = 64'd0 ;


////////////////YWJ
assign pdb7_cen		= (pd_current_state==PD_LEFT) ? ( pd2_current_state == P2_FLOW1 ) ? (  cnts00_enable  ) ? 1'd0 : 1'd1  : 1'd1 : 1'd1 ;
assign pdb7_addr	=  sram_addr  +	cfg_pd_list_1 -	cfg_atlchin;
///////////



// always @(*) begin
// 	if( pd_current_state == PD_LEFT )begin
// 		if( pd2_current_state == P2_FLOW1 )begin
// 			pdb0_cen = cnts00_enable ;
// 		end
// 	end
// 	else begin
// 		pdb0_cen = 1'd1 ;
// 	end
// end



endmodule