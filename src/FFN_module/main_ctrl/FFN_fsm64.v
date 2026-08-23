// ============================================================================
// Designer : Chao-Ping Liu
// Create   : 2025.06.26
// Ver      : 1.0
// Func     : master and slave FSM, only FSLD and BASE
// 				
// ============================================================================

module FFN_fsm64 (
		clk
	,	reset

	,	start 
	,	fsld_done
	,	base_done	
	,	outmast_curr_state	

);
//------- master FSM parameter -----------
	localparam MAST_FSM_BITS 	= 3;
	localparam M_IDLE 	= 3'd0;
	localparam M_FSLD	= 3'd1;
	localparam M_BASE 	= 3'd2;
	localparam M_DONE 	= 3'd3;

// ============================= I/O port Declare ===============================
	input wire clk 		;
	input wire reset 	;

	input wire start 		;
	input wire fsld_done	;
	input wire base_done 	;
	output wire  [ MAST_FSM_BITS -1 : 0 ] outmast_curr_state ;

// ============================= Declare ===============================
	reg [ MAST_FSM_BITS -1 : 0 ] mast_curr_state ;
	reg [ MAST_FSM_BITS -1 : 0 ] mast_next_state ;

	assign outmast_curr_state = mast_curr_state ;
	
    always@( posedge clk )begin
		if( reset )begin
			mast_curr_state <= M_IDLE	;
		end 
		else begin
			mast_curr_state <= mast_next_state	;
		end
	end
	always@(*)begin
		case( mast_curr_state )
			M_IDLE 	:	mast_next_state = ( start ) ?		M_FSLD : M_IDLE ;
			M_FSLD 	:	mast_next_state = ( fsld_done ) ?	M_BASE : M_FSLD ;
			M_BASE 	:	mast_next_state = ( base_done ) ? 	M_DONE : M_BASE ;
			M_DONE	:	mast_next_state = M_IDLE ;
			default :	mast_next_state = M_IDLE ;
		endcase	
	end

endmodule