module Transformer_FSM  #(
    parameter TBITS = 64,
    parameter TBYTE = 8
)(
		clk 
	,	reset 

	,	fifo_data_din
	,	fifo_strb_din
	,	fifo_last_din
	,	fifo_user_din
	,	fifo_empty_n_din
	,	fifo_read_dout

	,	fifo_read_din

	,	SA_busy
	,	SOFTMAX_busy
	,	NORM_busy
	,	FFN_busy

	,	SA_done
	,	SOFTMAX_done
	,	NORM_done
	,	FFN_done

    ,   curr_state
    ,   mode
);

    //==============================================================================
    //========    Input/Output    ========
    //==============================================================================
    input	wire 				clk		;
    input	wire 				reset	;
    input	wire [TBITS-1: 0 ]	fifo_data_din		;
    input	wire [TBYTE-1: 0 ]	fifo_strb_din		;
    input	wire 				fifo_last_din		;
    input	wire 				fifo_user_din		;
    input	wire 				fifo_empty_n_din	;
    output	reg 				fifo_read_dout		;

	input	wire 				fifo_read_din		;

	output  reg			SA_busy			;
	output	reg			SOFTMAX_busy	;
	output	reg			NORM_busy		;
	output	reg			FFN_busy		;

	input   wire            SA_done         ;
	input   wire            SOFTMAX_done    ;
	input   wire            NORM_done       ;
	input   wire            FFN_done        ;

    output  [ 3-1 : 0 ] curr_state ;
    output  [   1 : 0 ] mode ;

    // ============================= Declare ===============================
    localparam SA_HEAD          = 64'h0011223344556677 ;
    localparam SOFTMAX_HEAD     = 64'h8899aabbccddeeff ;
    localparam NORM_HEAD        = 64'h7766554433221100 ;
    localparam FFN_HEAD         = 64'hffeeddccbbaa9988 ;
    
    //---- FSM -----
    reg [ 3-1 : 0 ] curr_state ;
	reg [ 3-1 : 0 ] next_state ;
	localparam IDLE     = 3'd0 ;
	localparam CH00     = 3'd1 ;
	localparam CH01     = 3'd2 ;
	localparam CHEK     = 3'd3 ;
	localparam SA       = 3'd4 ;
	localparam SOFTMAX  = 3'd5 ;
	localparam NORM     = 3'd6 ;
    localparam FFN      = 3'd7 ;

    //========    check instruction    ===============================
    reg [TBITS-1:0] ck_reg_0;
    reg [TBITS-1:0] ck_reg_1;

    reg [1:0]   mode ;
    localparam MODE_SA      = 2'd0 ;
    localparam MODE_SOFTMAX = 2'd1 ;
    localparam MODE_NORM    = 2'd2 ;
    localparam MODE_FFN     = 2'd3 ;

    //---- state reg ----
	reg SA_start        ;
	reg SOFTMAX_start   ;
    reg NORM_start      ;
    reg FFN_start       ;

	reg headins_done ;
	
	reg [2:0] head_cnt ;

    always@( posedge clk )begin
        if( reset )
            curr_state <= IDLE ;
        else
            curr_state <= next_state ;
	end
    always@( * )begin
		case( curr_state )
			IDLE    : next_state = ( fifo_empty_n_din ) ? CH00 : IDLE ;
			CH00    : next_state = ( headins_done ) ? CHEK : CH00 ;
			CHEK    : next_state = ( SA_start ) ? SA : ( SOFTMAX_start ) ? SOFTMAX : ( NORM_start ) ? NORM : ( FFN_start ) ? FFN : CHEK;
			SA      : next_state = ( SA_done ) ? IDLE : SA ;
			SOFTMAX : next_state = ( SOFTMAX_done ) ? IDLE : SOFTMAX ;
			NORM    : next_state = ( NORM_done ) ? IDLE : NORM ;
            FFN     : next_state = ( FFN_done ) ? IDLE : FFN ;
			default : next_state = IDLE ;
		endcase	
	end

    always @(posedge clk) begin
        if( reset )
            mode <= MODE_SA ;
        else begin
            case( curr_state )
                SA      : mode <= MODE_SA ;
                SOFTMAX : mode <= MODE_SOFTMAX ;
                NORM    : mode <= MODE_NORM ;
                FFN     : mode <= MODE_FFN ;
                default : mode <= mode ;
            endcase
        end
    end

    always @(posedge clk ) begin
		if( reset )
			fifo_read_dout <= 1'd0 ;
		else if(curr_state == CH00 && !headins_done )
			fifo_read_dout <= (head_cnt < 'd2) ? fifo_empty_n_din : 1'd0 ;
		else
			fifo_read_dout <= 1'd0 ;
	end

    always @(*) begin
		headins_done =  (curr_state == CH00) ? ((head_cnt >= 'd1 ) && fifo_empty_n_din && fifo_read_dout ) ? 1'd1 : 1'd0  : 1'd0 ;
	end

	always @(*) begin
		SA_start = ((ck_reg_0 == SA_HEAD) && (ck_reg_1 == SA_HEAD)) ? 1'd1 : 1'd0 ;
		SOFTMAX_start = ((ck_reg_0 == SOFTMAX_HEAD) && (ck_reg_1 == SOFTMAX_HEAD )) ? 1'd1 : 1'd0 ;
		NORM_start = ((ck_reg_0 == NORM_HEAD) && (ck_reg_1 == NORM_HEAD)) ? 1'd1 : 1'd0 ;
		FFN_start = ((ck_reg_0 == FFN_HEAD) && (ck_reg_1 == FFN_HEAD)) ? 1'd1 : 1'd0 ;
	end

	always @(*) begin
		// SA_busy = (SA_start && (curr_state != IDLE) && (curr_state != CH00)) ? 1'd1 : 1'd0 ;
		SA_busy = (curr_state == SA) ? 1'd1 : 1'd0 ;
		// SOFTMAX_busy = (SOFTMAX_start && (curr_state != IDLE) && (curr_state != CH00)) ? 1'd1 : 1'd0 ;
		SOFTMAX_busy = (curr_state == SOFTMAX) ? 1'd1 : 1'd0 ;
		// NORM_busy = (NORM_start && (curr_state != IDLE) && (curr_state != CH00)) ? 1'd1 : 1'd0 ;
		NORM_busy = (curr_state == NORM) ? 1'd1 : 1'd0 ;
		// FFN_busy = (FFN_start && (curr_state != IDLE) && (curr_state != CH00)) ? 1'd1 : 1'd0 ;
		FFN_busy = (curr_state == FFN) ? 1'd1 : 1'd0 ;
	end

    //---- head count ----
	always@( posedge clk )begin
		if( reset )begin
			head_cnt <= 'd0 ;
		end
		else begin
			if( curr_state == CH00) begin
				if( (head_cnt <2 )&&  fifo_empty_n_din && fifo_read_dout)
					head_cnt <= head_cnt + 'd1 ;
				else
					head_cnt <= head_cnt ;
			end
			else
				head_cnt <= 'd0 ;
		end
	end	

	always @(posedge clk ) begin
		if (reset) begin
			ck_reg_0 <= 64'd0 ;
			ck_reg_1 <= 64'd0 ;
		end
		else begin
			if( curr_state == CH00 )begin
				if (fifo_empty_n_din && fifo_read_dout) begin
					ck_reg_0 <= ( head_cnt == 3'd0 )? fifo_data_din : ck_reg_0 ;
					ck_reg_1 <= ( head_cnt == 3'd1 )? fifo_data_din : ck_reg_1 ;
				end
				else begin
					ck_reg_0 <= ck_reg_0 ;
					ck_reg_1 <= ck_reg_1 ;
				end
			end
			else begin
				ck_reg_0 <= ck_reg_0 ;
				ck_reg_1 <= ck_reg_1 ;
			end
		end
	end

endmodule