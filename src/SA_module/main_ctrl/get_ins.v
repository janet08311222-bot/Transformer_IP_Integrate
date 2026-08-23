// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2022.09.28
// Ver      : 1.0
// Func     : get instruction or data from dram axi access. use sequence 64 bits data
// 			send before instruction. connect the MEM_store module for storing, tell
//			that can take data from fifo_in.
// 		"efef123abbeeff22" : for instruction
// 		"efef6543dadaff11" : for data 

// Log		: 
// 		2022/10/19 : need to detect fifo_last for every dma transfer. make state go to IDLE
// 			and show HW still need data or not when report instruction is comming.
// 		2023.04.10-- New kernel cfg and inst_code8~13 total 14 instructions
// ============================================================================

module get_ins (
	clk ,
	reset ,

	fifo_data_din	,
	fifo_strb_din	,
	fifo_last_din	,
	fifo_user_din	,
	fifo_empty_n_din	,
	fifo_read_dout		,	// output

	ds_empty_n	,	// output data store empty_n
	ds_read	,		// input

	instr_code00	,
	instr_code01	,
	instr_code02	,
	instr_code03	,
	instr_code04	,
	instr_code05	,
	instr_code06	,
	instr_code07	,
	instr_code08	,
	instr_code09	,
	instr_code10	,
	instr_code11	,
	instr_code12	,
	instr_code13	,
	instr_code14	,
	instr_code15	,

	mast_curr_state	,

	start_reg

);
	
	parameter TBITS = 64;
	parameter TBYTE = 8;

localparam INSTR_FNUM = 4'd15;	// setting how many instruction we need
//----------------------------------------------



//------- master FSM parameter -----------
localparam MAST_FSM_BITS 	= 3;
localparam M_IDLE 	= 3'd0;
localparam LEFT 	= 3'd1;
localparam BASE 	= 3'd2;
localparam RIGHT 	= 3'd3;
localparam FSLD 	= 3'd7;	// First load sram0

//---------------------------------------------

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


output wire	ds_empty_n	;		// data load -state output empty_n
input wire	ds_read		;		// data load -state input read

output wire start_reg ;			// start the total finite state machine

output reg [ 64-1 : 0 ] instr_code00 ;	//config code
output reg [ 64-1 : 0 ] instr_code01 ;
output reg [ 64-1 : 0 ] instr_code02 ;
output reg [ 64-1 : 0 ] instr_code03 ;	//ifsram_pd config code //cfg_atl(10),cfg_conv(10),cfg_mast(10),cfg_pd_0(15),cfg_pd_1(15),4'b0
output reg [ 64-1 : 0 ] instr_code04 ;							//cfg_pd_2(15),cfg_pd_3(15),cfg_pd_4(15),cfg_cnt_p1(5),cfg_cnt_p2(5),9'b0
output reg [ 64-1 : 0 ] instr_code05 ;	//ifsram_w config code	//cfg_pdlf(10),cfg_pdrg(10),cfg_nor(10),cfg_stg0_nor(10),cfg_stg0_pdb0(10),cfg_stg0_pdb1(10),4'b0
output reg [ 64-1 : 0 ] instr_code06 ;							//cfg_stg1_eb_col(10),cfg_dincnt_finum(15),cfg_rowcnt_finum(10),29'b0
output reg [ 64-1 : 0 ] instr_code07 ;	//ifsram_r config code	//cfg_ifr_window(10),54'b0
output reg [ 64-1 : 0 ] instr_code08 ;	
output reg [ 64-1 : 0 ] instr_code09 ;	
output reg [ 64-1 : 0 ] instr_code10 ;	
output reg [ 64-1 : 0 ] instr_code11 ;	
output reg [ 64-1 : 0 ] instr_code12 ;	
output reg [ 64-1 : 0 ] instr_code13 ;	
output reg [ 64-1 : 0 ] instr_code14 ;	
output reg [ 64-1 : 0 ] instr_code15 ;	

input wire [MAST_FSM_BITS-1:0] mast_curr_state ;

//---------- input / output -----------------
//-----------------------------------------------------------------------------

localparam INST_HEAD = 64'hefef123abbeeff22 ;
localparam DATA_HEAD = 64'hefef6543dadaff11 ;

//----    FSM    -----
localparam IDLE = 3'd0 ;
localparam CH00 = 3'd1 ;
localparam CH01 = 3'd2 ;
localparam CHEK = 3'd3 ;
localparam INST = 3'd4 ;
localparam TAFL = 3'd5 ;
localparam DATA = 3'd6 ;

reg [ 3-1 : 0 ] current_state ;
reg [ 3-1 : 0 ] next_state ;

//-----------------------------------------------------------------------------



//========    trace and flush FSM control start signal for mast_FSM    ========
reg [3-1:0]tf_current_state ;
reg [3-1:0]tf_next_state ;
localparam TF_IDLE 	= 0;
localparam TF_TRAC 	= 1;
localparam TF_SET 	= 2;
localparam TF_FLUS 	= 3;
localparam TF_DONE 	= 4;
//-----------------------------------------------------------------------------


reg [TBITS-1: 0 ] ck_reg_0 ;
reg [TBITS-1: 0 ] ck_reg_1 ;

//---- state reg ----
reg str_start ;

reg ins_read ;

//-------------------
reg instr_start ;
reg datald_start ;

reg instr_done	;
reg headins_done	;

reg [2:0] head_cnt ;
reg [3:0] ins_cnt ;


assign start_reg = str_start  ;

assign ds_empty_n = ( current_state == DATA) ? fifo_empty_n_din : 1'd0 ;

always @(*) begin
	case ( current_state )
		CH00 : fifo_read_dout = ins_read	;
		CH01 : fifo_read_dout = ins_read	;
		INST : fifo_read_dout = ins_read	;
		DATA : fifo_read_dout = ds_read		;		// from data store module
		default: fifo_read_dout = 1'd0		;
	endcase
end



always @(*) begin
	headins_done =  (current_state == CH00) ? ((head_cnt >= 'd1 ) && fifo_empty_n_din && fifo_read_dout ) ? 1'd1 : 1'd0  : 1'd0 ;
	instr_done = (ins_cnt == INSTR_FNUM ) ? 1'd1 : 1'd0 ;
end

always @(*) begin
	// instr_start= (ck_reg_0 == INST_HEAD ) ? (ck_reg_1 == INST_HEAD ) ? 1'd1 : 1'd0   : 1'd0 ;
	instr_start= ((ck_reg_0 == INST_HEAD ) & (ck_reg_1 == INST_HEAD )) ? 1'd1 : 1'd0 ;
	datald_start= (ck_reg_0 == DATA_HEAD ) ? (ck_reg_1 == DATA_HEAD ) ? 1'd1 : 1'd0   : 1'd0 ;
end


always@( posedge clk )begin
	if( reset )begin
		current_state <= IDLE ;
	end
	else begin
		current_state <= next_state ;
	end
end


always@( * )begin
	case( current_state )
		IDLE : next_state = ( fifo_empty_n_din   ) ? CH00 : IDLE ;
		CH00 : next_state =	( headins_done ) ? CHEK : CH00 ;
		// CH01 : next_state =	CHEK ;
		CHEK : next_state =  ( instr_start ) ? INST : 
								( datald_start ) ? DATA : CHEK;
		INST : next_state = (instr_done ) ? TAFL : INST ;
		TAFL : next_state = ( tf_current_state == TF_DONE ) ? IDLE : TAFL ;
		DATA : next_state = ( fifo_empty_n_din   ) ? (fifo_last_din ) ? IDLE : DATA  : DATA  ;
		default : next_state = IDLE ;
	endcase	
end		

always @(posedge clk ) begin
	if( reset )begin
		ins_read <= 1'd0 ;
	end
	else begin
		case(current_state)
			CH00 : ins_read <= ( fifo_empty_n_din   ) ?		(head_cnt <2) ? fifo_empty_n_din : 1'd0 	: 1'd0 ;
			// CH01 : ins_read <= ( fifo_empty_n_din   ) ? 1'd1 : 1'd0 ;
			INST : ins_read <= ( fifo_empty_n_din   ) ?		(ins_cnt < INSTR_FNUM) ? 1'd1 : 1'd0		: 1'd0 ;
			
			default : ins_read <= 1'd0 ;
		endcase
	end
end



//---- head count ----
always@( posedge clk )begin
	if( reset )begin
		head_cnt <= 'd0 ;
	end
	else begin
		if( current_state == CH00)begin
			if( (head_cnt <2 )&&  fifo_empty_n_din && fifo_read_dout)begin
				head_cnt <= head_cnt + 'd1 ;
			end
			else begin
				head_cnt <= head_cnt ;
			end
		end
		else begin
			head_cnt <= 'd0 ;
		end

	end
end	

always @(posedge clk ) begin
	if (reset) begin
		ck_reg_0 <= 64'd0 ;
		ck_reg_1 <= 64'd0 ;
	end
	else begin
		if( current_state == CH00 )begin
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


//-----------  ins taker ----------------
always@( posedge clk )begin
	if( reset )begin
		ins_cnt <= 'd0 ;
	end
	else begin
		if( (current_state == INST) &&  fifo_empty_n_din && fifo_read_dout )begin
			if( ins_cnt < INSTR_FNUM )begin
				ins_cnt <= ins_cnt + 'd1 ;
			end
			else begin
				ins_cnt <= 'd0 ;
			end
		end
		else begin
			ins_cnt <= 'd0 ;
		end

	end
end	


always @(posedge clk ) begin
	if (reset) begin
		// instr_code00 <= 64'd0;
		instr_code01 <= 64'd0;
		instr_code02 <= 64'd0;
		instr_code03 <= 64'd0;
		instr_code04 <= 64'd0;
		instr_code05 <= 64'd0;
		instr_code06 <= 64'd0;
		instr_code07 <= 64'd0;
		instr_code08 <= { 8'd7 , 16'd63 , 16'd36 ,24'd0};
		instr_code09 <= {8'd12 , 56'd0	};
		instr_code10 <= {8'd24 , 56'd0	};
		instr_code11 <= {8'd24 , 56'd0	};
		instr_code12 <= {16'd287 , 48'd0	};
		instr_code13 <= {16'd8 , 16'd63 , 32'd0 };
		instr_code14 <= {12'd127 ,12'd2	,12'd7 ,28'd0 };	//HYR
		instr_code14 <= {12'd7 ,12'd64 ,12'd8 ,28'd0 };		//HYR
	end
	else begin
		if( current_state == INST)begin
			if (fifo_empty_n_din && fifo_read_dout) begin
				// instr_code00 <= ( ins_cnt == 4'd1 )? fifo_data_din : instr_code00 ;
				instr_code01 <= ( ins_cnt == 4'd1 )? fifo_data_din : instr_code01 ;
				instr_code02 <= ( ins_cnt == 4'd2 )? fifo_data_din : instr_code02 ;
				instr_code03 <= ( ins_cnt == 4'd3 )? fifo_data_din : instr_code03 ;	
				instr_code04 <= ( ins_cnt == 4'd4 )? fifo_data_din : instr_code04 ;
				instr_code05 <= ( ins_cnt == 4'd5 )? fifo_data_din : instr_code05 ;
				instr_code06 <= ( ins_cnt == 4'd6 )? fifo_data_din : instr_code06 ;
				instr_code07 <= ( ins_cnt == 4'd7 )? fifo_data_din : instr_code07 ;
				instr_code08 <= ( ins_cnt == 4'd8 )? fifo_data_din :	instr_code08 ;
				instr_code09 <= ( ins_cnt == 4'd9 )? fifo_data_din :	instr_code09 ;
				instr_code10 <= ( ins_cnt == 4'd10 )? fifo_data_din :	instr_code10 ;
				instr_code11 <= ( ins_cnt == 4'd11 )? fifo_data_din :	instr_code11 ;
				instr_code12 <= ( ins_cnt == 4'd12 )? fifo_data_din :	instr_code12 ;
				instr_code13 <= ( ins_cnt == 4'd13 )? fifo_data_din :	instr_code13 ;
				instr_code14 <= ( ins_cnt == 4'd14 )? fifo_data_din :	instr_code14 ;
				instr_code15 <= ( ins_cnt == 4'd15 )? fifo_data_din :	instr_code15 ;

			end
			else begin
				// instr_code00 <= instr_code00 ;
				instr_code01 <= instr_code01 ;
				instr_code02 <= instr_code02 ;
				instr_code03 <= instr_code03 ;
				instr_code04 <= instr_code04 ;
				instr_code05 <= instr_code05 ;
				instr_code06 <= instr_code06 ;
				instr_code07 <= instr_code07 ;
				instr_code08 <= instr_code08 ;
				instr_code09 <= instr_code09 ;
				instr_code10 <= instr_code10 ;
				instr_code11 <= instr_code11 ;
				instr_code12 <= instr_code12 ;
				instr_code13 <= instr_code13 ;
				instr_code14 <= instr_code14 ;
				instr_code15 <= instr_code15 ;

			end
		end
		else begin
			// instr_code00 <= instr_code00 ;
			instr_code01 <= instr_code01 ;
			instr_code02 <= instr_code02 ;
			instr_code03 <= instr_code03 ;
			instr_code04 <= instr_code04 ;
			instr_code05 <= instr_code05 ;
			instr_code06 <= instr_code06 ;
			instr_code07 <= instr_code07 ;
			instr_code08 <= instr_code08 ;
			instr_code09 <= instr_code09 ;
			instr_code10 <= instr_code10 ;
			instr_code11 <= instr_code11 ;
			instr_code12 <= instr_code12 ;
			instr_code13 <= instr_code13 ;
			instr_code14 <= instr_code14 ;
			instr_code15 <= instr_code15 ;

		end
	end
end




//==============================================================================
//========    trace and flush FSM control start signal for mast_FSM    ========
//==============================================================================

always @(posedge clk ) begin
	if(reset)begin
		tf_current_state <= TF_IDLE ;
	end
	else begin
		tf_current_state <= tf_next_state ;
	end
end


always @(*) begin
	case (tf_current_state)
		TF_IDLE	:	tf_next_state = ( current_state == TAFL )? TF_TRAC : TF_IDLE ;
		TF_TRAC	:	tf_next_state = ( mast_curr_state == M_IDLE )? TF_SET : TF_TRAC ;
		TF_SET	:	tf_next_state = TF_FLUS ;
		TF_FLUS	:	tf_next_state = TF_DONE ;
		TF_DONE	:	tf_next_state = TF_IDLE ;
		default: tf_next_state = TF_IDLE ;
	endcase
end

//-----------------------------------------------------------------------------


always @(posedge clk ) begin
	if (reset) begin
		instr_code00 <= 64'd0;

	end
	else begin
		if( current_state == INST)begin
			if (fifo_empty_n_din && fifo_read_dout) begin
				instr_code00 <= ( ins_cnt == 4'd0 )? fifo_data_din : instr_code00 ;
			end
			else begin
				instr_code00 <= instr_code00 ;
			end
		end
		else if( current_state == TAFL )begin
			case (tf_current_state)
				TF_FLUS : instr_code00 <= 64'd0 ;
				default: instr_code00 <= instr_code00 ;
			endcase
		end
		else begin
			instr_code00 <= instr_code00 ;
		end

	end
end



always@(*)begin
	str_start = ( tf_current_state== TF_SET) ? instr_code00[ 63 -:1 ] : 1'd0 ;
end
// always @(posedge clk ) begin
// 	if(reset)begin
// 		str_start <= 1'd0 ;
// 	end
// 	else begin
// 		case (tf_current_state)
// 			TF_IDLE	:
// 			TF_TRAC	:
// 			TF_SET	:	str_start <= instr_code00[ 63 -:1 ];
// 			TF_FLUS	:
// 			TF_DONE	:
// 			default: str_start <= instr_code00[ 63 -:1 ];
// 		endcase
// 	end
// end




endmodule