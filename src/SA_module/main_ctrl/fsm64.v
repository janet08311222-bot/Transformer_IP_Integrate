// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2022.09.19
// Ver      : 2.0
// Func     : master and slave FSM, use curr_of_row control, only FSLD and LEFT
// 				for 64 MACs version DLA.
// 		2022.11.15 : remove slav fsm, 
// ============================================================================
// finite state machine

module fsm64 (
	clk
	,	reset
	,	start 	
	,	outmast_curr_state	
	,	flag_fsld_end 	
	,	left_done 
	,	base_done
	,	right_done	
	
	//  configuration
	,	cfg_base_number

);
//------- master FSM parameter -----------
localparam MAST_FSM_BITS 	= 3;
localparam M_IDLE 	= 3'd0;
localparam LEFT 	= 3'd1;
localparam BASE 	= 3'd2;
localparam RIGHT 	= 3'd3;
localparam FSLD 	= 3'd7;	// First load sram0
//---------------------------------------------


output wire  [ MAST_FSM_BITS -1 : 0 ] outmast_curr_state ;


input wire clk ;
input wire reset ;

input wire flag_fsld_end ;
input wire start ;
input wire left_done ;
input wire base_done ;
input wire right_done ;

input wire [5:0] cfg_base_number; //config 

reg [ MAST_FSM_BITS -1 : 0 ] mast_curr_state ;
reg [ MAST_FSM_BITS -1 : 0 ] mast_next_state ;

reg [1:0] block_finish;
reg [5:0] base_numebr;


assign outmast_curr_state = mast_curr_state ;

always @ (posedge clk)begin
	if(reset)
		base_numebr <= 0;
	else if(mast_curr_state == RIGHT)
		base_numebr <= 0;
	else if(base_done || left_done)
		base_numebr <= base_numebr + 1;
	else
		base_numebr <= base_numebr;
end



always @ (posedge clk)begin
	if(reset)
		block_finish <= 0;
	else if(left_done)
		block_finish <= 1;
	else if(base_done && base_numebr == cfg_base_number)
		block_finish <= 2;
	else if(right_done)
		block_finish <= 0;
	else
		block_finish <= block_finish;
end


always@(*)begin
	case( mast_curr_state )
		// M_IDLE 	:	mast_next_state = ( start )? (block_finish == 0)? FSLD : ( block_finish == 1)? BASE : (block_finish == 2)? RIGHT : M_IDLE : M_IDLE;
		M_IDLE 	:	mast_next_state = ( start )?  FSLD : M_IDLE;
		LEFT 	:	mast_next_state = ( left_done )? M_IDLE : LEFT ;
		BASE 	:	mast_next_state = ( base_done )? M_IDLE : BASE ;
		RIGHT 	:	mast_next_state = ( right_done )? M_IDLE : RIGHT ;
		FSLD 	:	mast_next_state = ( flag_fsld_end )? LEFT : FSLD ;
		default :	mast_next_state = M_IDLE ;
	endcase	
end


always@( posedge clk )begin
	if( reset )begin
		mast_curr_state <= M_IDLE	;
	end 
	else begin
		mast_curr_state <= mast_next_state	;
	end
end




endmodule