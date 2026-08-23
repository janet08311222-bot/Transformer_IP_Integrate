// ============================================================================
// Designer : Chao-Ping Liu
// Create   : 2024.06.26
// Ver      : 1.0
// Func     : mutiplexor for input_fifo signal empty_n and read
// Log		: 
// ============================================================================

module FFN_d_empn_rd_mux(

    // write module empty_n signal
        if_write_empty_n
	,	ker_write_empty_n
	,	bias_write_empty_n

    // write module read signal
	,	if_write_read
	,	ker_write_read
	,	bias_write_read

    ,   empty_n_from_gi
    ,   read_for_gi

    ,   mast_curr_state

    ,   if_write_en
    ,   ker_write_en
    ,   bias_write_en

);

    //------- master FSM parameter -----------
	localparam MAST_FSM_BITS 	= 3;
	localparam M_IDLE 	= 3'd0;
	localparam M_FSLD	= 3'd1;
	localparam M_BASE 	= 3'd2;
	localparam M_DONE 	= 3'd3;

    //==============================================================================
    //========    Input/Output    ========
    //==============================================================================
    output reg  if_write_empty_n    ;
    output reg  ker_write_empty_n   ;
    output reg  bias_write_empty_n  ;

    input wire  if_write_read   ;
    input wire  ker_write_read  ;
    input wire  bias_write_read ;

    input wire  empty_n_from_gi ;
    output reg  read_for_gi     ;

    input wire  [MAST_FSM_BITS-1:0] mast_curr_state ;

    input wire  if_write_en     ;
    input wire  ker_write_en    ;
    input wire  bias_write_en   ;

    //-----------------------------------------------------------------------------
    //------------			empty_n signal			-------------------------------
    //-----------------------------------------------------------------------------
    always @(*) begin
        case(mast_curr_state)
            M_FSLD  : if_write_empty_n = (if_write_en) ? empty_n_from_gi : 1'd0 ;
            default : if_write_empty_n = 1'd0 ;
        endcase
    end

    always @(*) begin
        case(mast_curr_state)
            M_BASE  : ker_write_empty_n = (ker_write_en) ? empty_n_from_gi : 1'd0 ;
            M_FSLD  : ker_write_empty_n = (ker_write_en) ? empty_n_from_gi : 1'd0 ;
            default : ker_write_empty_n = 1'd0 ;
        endcase
    end

    always @(*) begin
        case(mast_curr_state)
            M_BASE  : bias_write_empty_n = (bias_write_en) ? empty_n_from_gi : 1'd0 ;
            M_FSLD  : bias_write_empty_n = (bias_write_en) ? empty_n_from_gi : 1'd0 ;
            default : bias_write_empty_n = 1'd0 ;
        endcase
    end

    //-----------------------------------------------------------------------------
    //--------------------    read signal    --------------------------------------
    //-----------------------------------------------------------------------------
    always @(*) begin
        case(mast_curr_state)
            M_BASE  : read_for_gi = (ker_write_en) ? ker_write_read :
                                    (bias_write_en) ? bias_write_read : 1'd0 ;
            M_FSLD  : read_for_gi = (if_write_en) ? if_write_read :
                                    (ker_write_en) ? ker_write_read :
                                    (bias_write_en) ? bias_write_read : 1'd0 ;
            default : read_for_gi = 1'd0 ;
        endcase
    end

endmodule