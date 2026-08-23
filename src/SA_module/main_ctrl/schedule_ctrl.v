
// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2022.10.24
// Ver      : 1.0
// Func     : schedule control, generate start signal for sram r/w module
// Log		:
// 		----2023.02.01: move out if_top module
// 		----2023.02.23: add padding module control
// ============================================================================


module schedule_ctrl (
	clk
	,	reset
	
	,	mast_curr_state 		
	,	cfg_conv_switch		

	,	if_write_start			
	,	if_write_busy			
	,	if_write_done			

	,	if_pad_done 		
	,	if_pad_busy 		
	,	if_pad_start		

	,	ker_write_start		
	,	ker_write_busy			
	,	ker_write_done			

	,	bias_write_start		
	,	bias_write_busy		
	,	bias_write_done		

	,	if_read_done 				//if_rw -> schedule
	,	if_read_busy 				//if_rw -> schedule
	,	if_read_start				//schedule -> if_rw

	,	chk_ot_ready

	// --------------Read sram I/O------------

	,	if_row_finish				//if_rw -> schedule
	,	if_dy2_conv_finish  
	,	if_read_current_state			//schedule -> if_rw & ker_rw
	//---------------------------------------------
	,	flag_fsld_end		
	,	left_done
	,	base_done
	,   right_done			

	//----testing ----
	,	sche_fsld_curr_state	

	//config schedule setting

	,	cfg_total_row
	//---------------------------------------------
	,   if_write_empty_n_din
	,	if_read_last	//YWJ
	,	rdwd_done
);

	parameter TBITS = 64;
	parameter TBYTE = 8;


	//------- master FSM parameter -----------
	localparam MAST_FSM_BITS 	= 3;
	localparam M_IDLE 	= 3'd0;
	localparam LEFT 	= 3'd1;
	localparam BASE 	= 3'd2;
	localparam RIGH 	= 3'd3;
	localparam FSLD 	= 3'd7;	// First load sram0
	//---------------------------------------------


	input wire clk		;
	input wire reset	;

	input wire [ MAST_FSM_BITS -1 : 0 ] mast_curr_state	;
	input wire [3-1:0]	cfg_conv_switch		;


	//-----------------buffer ctrl io -----------------------------

	input wire	if_write_done 		;
	input wire	if_write_busy		;
	output reg 	if_write_start		;

	input wire	if_pad_done 		;
	input wire	if_pad_busy 		;
	output reg	if_pad_start		;



	input wire	ker_write_done 		;
	input wire	bias_write_done 	;

	input wire	ker_write_busy 		;
	input wire	bias_write_busy 	;

	input wire	chk_ot_ready 		;

	output reg 	ker_write_start 	;
	output reg 	bias_write_start 	;


	output reg 	flag_fsld_end 		;
	output wire  left_done;
	output wire  base_done;
	output wire  right_done;

	output reg if_read_start;  //schedule -> if_rw
    input wire if_read_busy;   //if_rw -> schedule
    input wire if_read_done;    //if_rw -> schedule


    input wire if_row_finish;        //if_rw -> schedule
	input wire if_dy2_conv_finish;        //if_rw -> schedule
    output reg [2:0] if_read_current_state;  //schedule -> if_rw
	output reg  rdwd_done;		//schedule -> if_rw

	//-----------------test -----------------------------
	output wire[3-1:0] sche_fsld_curr_state ;
	//---------------------------------------------------
	
	//-----------config parameters --------------------------------
	input wire [8:0] cfg_total_row;
	input wire if_write_empty_n_din;
	output wire if_read_last;

//-----------------------------------------------------------

//-----------------buffer ctrl io -----------------------------

//-------------------   done flag    --------------------------------
	reg [0:0]	sche_if_done ;
	reg [0:0]	sche_ker_done ;
	reg [0:0]	sche_bias_done ;
	reg [2:0]   if_read_next_state;
	


//--------------- master state = fsld -------------------------------
	reg [3:0] fsld_current_state ;
	reg [3:0] fsld_next_state ;
	localparam FS_IDLE 	= 3'd0;
	localparam FS_KER 	= 3'd1;
	localparam FS_BIAS 	= 3'd2;
	localparam FS_IFPD 	= 3'd3;
	localparam FS_DONE 	= 3'd7;
//--------------- master state = LEFT -------------------------------
	reg [3:0] block_current_state ;
	reg [3:0] block_next_state ;
	localparam BK_IDLE 	= 3'd0;
	localparam BK_FSLD	= 3'd1;
	localparam BK_RDWT	= 3'd2;
	localparam BK_PADD	= 3'd3;

	// localparam LF_03	= 3'd3;
	// localparam LF_04	= 3'd3;
	// localparam LF_05	= 3'd3;
	// localparam LF_06	= 3'd3;
	wire bk_state_lr 	;
	wire bk_state_bs 	;
//--------------- master state = LEFT & block state = RDWT-------------------------------
	localparam [2:0] 
		IDLE          = 3'd0,
		UP_PADDING    = 3'd1,
		ROW_ADDR_012  = 3'd2,   
		ROW_ADDR_123  = 3'd3, 
		ROW_ADDR_230  = 3'd4,
		ROW_ADDR_301  = 3'd5,
		DOWN_PADDING  = 3'd6;
//-------------------------------------------------------------------
	//---- if schedule need ----
	reg [8:0] write_row_number;		//YWJ
	reg [1:0] dy_if_write_start;
	reg [1:0] dy_if_read_start;
	//reg state_stay;

	reg read_last;
	reg read_last_cheak;

//---- testing instance ----
    // ifsram_rw iftest(
    //     .clk(clk),
    //     .reset(reset),

    //     .if_write_data_din(if_write_data_din)		,
    //     .if_write_empty_n_din(if_write_empty_n_din)		,
    //     .if_write_read_dout(if_write_read_dout)		,

    //     .if_write_done(if_write_done) 		,
    //     .if_write_busy(if_write_busy) 		,
    //     .if_write_start(if_write_start)		,	

    //     .if_read_done(if_read_done) 		,
    //     .if_read_busy(if_read_busy) 		,
    //     .if_read_start(if_read_start)		,

    //     .ifsram0_read(ifsram0_read)		,
    //     .ifsram1_read(ifsram1_read)		,
    //     .ifsram0_write(ifsram0_write)	,
    //     .ifsram1_write(ifsram1_write)   ,
    //     .if_row_finish(if_row_finish),
    //     .if_change_sram(if_change_sram),
    //     .current_state(if_read_current_state)   
    // );




assign bk_state_lr = ( mast_curr_state== LEFT ||   mast_curr_state== RIGH ) ? 1'd1 : 1'd0 ;
assign bk_state_bs = ( mast_curr_state== BASE ) ? 1'd1 : 1'd0 ;

assign sche_fsld_curr_state = fsld_current_state ;

assign if_read_last = read_last;

//==============================================================================
//========    first load FSM and fsld_end    ========
//==============================================================================

always @(posedge clk ) begin
	if ( reset ) begin
		fsld_current_state <= 3'd0 ;
	end
	else begin
		fsld_current_state <= fsld_next_state ;
	end
end


always @(*) begin
	case (fsld_current_state)
		FS_IDLE 	:	fsld_next_state = ( mast_curr_state == FSLD )	? FS_KER  : FS_IDLE ;
		FS_KER 		:	fsld_next_state = ( ker_write_done )			? FS_BIAS : FS_KER  ;
		FS_BIAS 	:	fsld_next_state = ( bias_write_done )			? FS_IFPD : FS_BIAS ;
		FS_IFPD 	:	fsld_next_state = ( if_pad_done )				? FS_DONE : FS_IFPD ;
		FS_DONE 	:	fsld_next_state = FS_IDLE	;

		default		: 	fsld_next_state = FS_IDLE ; 
	endcase
end

//----    output fsld end signal for master FSM    -----
always @(*) begin
	if (mast_curr_state == FSLD ) begin
		if ( fsld_current_state == FS_DONE )begin
			flag_fsld_end = 1'd1;
		end
		else begin
			flag_fsld_end = 1'd0;
		end
	end
	else begin
		flag_fsld_end = 1'd0;
	end
end
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------


//----------------block control-------------------
always @(posedge clk ) begin
	if ( reset ) begin
		block_current_state <= 3'd0 ;
	end
	else begin
		block_current_state <= block_next_state ;
	end
end


 
always @(*) begin
	case (block_current_state)
		BK_IDLE 	:	block_next_state = ( bk_state_lr ) ? BK_PADD : 
										   ( bk_state_bs ) ? BK_FSLD :  BK_IDLE ;
		BK_PADD     :   block_next_state = (if_pad_done) 			  ? BK_FSLD : BK_PADD ; //input data first load
		BK_FSLD     :   block_next_state = (if_write_done) 			  ? BK_RDWT : BK_FSLD ; //input data first load
		BK_RDWT 	:	block_next_state = ( rdwd_done )	  ? BK_IDLE :BK_RDWT ;
		default     :   block_next_state = BK_IDLE ; 
	endcase
end

assign left_done = ( mast_curr_state == LEFT ) ? rdwd_done : 0;
assign base_done = ( mast_curr_state == BASE ) ? rdwd_done : 0;
assign right_done = ( mast_curr_state == RIGH ) ? rdwd_done : 0;

always @(posedge clk ) begin
	if(reset)
		rdwd_done <= 0;
	else if(rdwd_done)
		rdwd_done <= 0;
	// else if(read_last && if_read_current_state == DOWN_PADDING && if_read_start)
	// 	rdwd_done <= 1;
	else if(read_last && if_read_current_state == DOWN_PADDING && if_read_done)
		rdwd_done <= 1;
	else
		rdwd_done <= rdwd_done;
end


//--------------------block rdwd control--------------





always @(posedge clk) begin
	if ( reset ) begin
		if_read_current_state <= 3'd0 ;
	end
	else begin
		if_read_current_state <= if_read_next_state ;
	end
end


always @(*) begin
	case (if_read_current_state)
		IDLE         : if_read_next_state = (block_current_state == BK_RDWT && !rdwd_done) ?  UP_PADDING : IDLE;
		//UP_PADDING   : if_read_next_state = (if_read_done) ? ROW_ADDR_012 : UP_PADDING;  //20251015 LYC
		//UP_PADDING   : if_read_next_state = (if_read_done) ? read_last_cheak) ? DOWN_PADDING : (cfg_conv_switch) ? UP_PADDING : ROW_ADDR_012 : UP_PADDING;
		UP_PADDING   : if_read_next_state = (if_read_done) ? (read_last_cheak) ? DOWN_PADDING : ROW_ADDR_012 : UP_PADDING;
		ROW_ADDR_012 : if_read_next_state = (if_read_done) ? (read_last_cheak) ? DOWN_PADDING : UP_PADDING : ROW_ADDR_012;
		//ROW_ADDR_012 : if_read_next_state = (if_read_done) ? (read_last_cheak) ? DOWN_PADDING : ROW_ADDR_123 : ROW_ADDR_012;
		ROW_ADDR_123 : if_read_next_state = (if_read_done) ? (read_last_cheak) ? DOWN_PADDING : ROW_ADDR_230 : ROW_ADDR_123;
		ROW_ADDR_230 : if_read_next_state = (if_read_done) ? (read_last_cheak) ? DOWN_PADDING : ROW_ADDR_301 : ROW_ADDR_230;
		ROW_ADDR_301 : if_read_next_state = (if_read_done) ? (read_last_cheak) ? DOWN_PADDING : ROW_ADDR_012 : ROW_ADDR_301;
		DOWN_PADDING : if_read_next_state = (if_read_done) ? IDLE     : DOWN_PADDING;
		// DOWN_PADDING : if_read_next_state = (left_done) ? IDLE     : DOWN_PADDING;
		default      : if_read_next_state = IDLE;
	endcase
end

always @ (*)begin
	if(write_row_number >= (cfg_total_row-1))
		read_last = 1;
	else
		read_last = 0;
end

always @ (posedge clk)begin
	if (reset) begin
		read_last_cheak <= 0;
	end
	else if (read_last && if_read_start) begin
		read_last_cheak <= 1;
	end
	else if (read_last == 0) begin
		read_last_cheak <= 0;
	end
	else begin
		read_last_cheak <= read_last_cheak ;
	end
end

//=======================================================================

//-----------------if write signal-----------------


always @(posedge clk) begin
	if(reset)
		if_write_start <= 0;
	else if(dy_if_write_start == 3)
		if_write_start <= 0;
	else if(block_current_state == BK_FSLD && !if_write_busy && !if_read_busy)
		if_write_start <= 1;
	else if(((if_read_current_state >= ROW_ADDR_012)&&(if_read_current_state <= ROW_ADDR_301) ) && !if_write_busy && !if_read_busy  && (write_row_number != cfg_total_row) && chk_ot_ready)
		if_write_start <= 1;
	else if(((if_read_current_state >= UP_PADDING)&&(if_read_current_state <= ROW_ADDR_301) ) && !if_write_busy && !if_read_busy  && (write_row_number < cfg_total_row && write_row_number>0) && chk_ot_ready)
		if_write_start <= 1;
	else 
		if_write_start <= if_write_start;
end

always@ (posedge clk)begin
	if(reset)
		dy_if_write_start <= 0;
	else if(dy_if_write_start == 3)
		dy_if_write_start <= 0;
	else if(read_last_cheak)
		dy_if_write_start <= 0;  //20251202
	else if(if_write_start)
		dy_if_write_start <= dy_if_write_start + 1;
	else 
		dy_if_write_start <= dy_if_write_start;
end



always@ (posedge clk)begin
	if(reset)
		write_row_number <= 0;
	else if(block_current_state == BK_IDLE)
		write_row_number <= 0;
	else if(block_current_state == BK_FSLD && if_write_done )
		write_row_number <= write_row_number + 5'd1;             //20250707 LYC : 3 to 1
	else if(block_current_state == BK_RDWT && if_write_done )
		write_row_number <= write_row_number + 5'd1;
	else
		write_row_number <= write_row_number;
end





//--------------------------------------------------

//-----------------if read signal-----------------
wire read_cheak;
reg [1:0] read_cnt;
assign read_cheak = (0<read_cnt && read_cnt<3)? 1: 0;

always@ (posedge clk)begin
	if(~if_write_empty_n_din)
		read_cnt <= 0;
	else if(read_cnt == 3)
		read_cnt <= 3;
	else if(if_write_empty_n_din)
		read_cnt <= read_cnt + 1;
	else 
		read_cnt <= read_cnt;
end
always @(posedge clk) begin
	if(reset)
		if_read_start <= 0;
	else if(dy_if_read_start == 3)
		if_read_start <= 0;
	else if(((if_read_current_state == UP_PADDING)||(if_read_current_state == DOWN_PADDING))&& !if_read_busy  && ! if_read_done && chk_ot_ready)
	// else if(if_read_current_state == UP_PADDING && !if_read_busy  && ! if_read_done && chk_ot_ready)
		if_read_start <= 1;
	// else if((if_read_current_state >= ROW_ADDR_012 && if_read_current_state <= ROW_ADDR_301)&& !if_read_busy && (read_cheak ||(write_row_number == cfg_total_row)))
	//	else if((if_read_current_state >= UP_PADDING && if_read_current_state <= ROW_ADDR_301) && !if_write_busy && !if_read_busy )
	else if((if_read_current_state >= ROW_ADDR_012 && if_read_current_state <= ROW_ADDR_301)&& !if_read_busy && (read_cheak ||read_last) && chk_ot_ready)
		if_read_start <= 1;
	else 
		if_read_start <= if_read_start;
end


always@ (posedge clk)begin
	if(reset)
		dy_if_read_start <= 0;
	else if(dy_if_read_start == 3)
		dy_if_read_start <= 0;
	else if(if_read_start)
		dy_if_read_start <= dy_if_read_start + 1;
	else 
		dy_if_read_start <= dy_if_read_start;
end

reg stay_last_sram_top;
reg last_threerow;




reg ard_last_threerow; // already last_threerow

always @ (posedge clk)begin
	if(reset)
		ard_last_threerow <= 0;
	else if(!if_read_start)
		ard_last_threerow <= 0;
	else if(last_threerow)
		ard_last_threerow <= 1;
	else
		ard_last_threerow <= ard_last_threerow;
		
end

always @ (posedge clk)begin
	if(reset)
		last_threerow <= 0;
	else if(last_threerow)
		last_threerow <= 0;
	else if(if_read_start && read_last && if_read_current_state == ROW_ADDR_012 && !ard_last_threerow)
		last_threerow <= 1;
	// else if(if_read_start && read_last && (if_read_current_state == ROW_ADDR_012 || if_read_current_state == UP_PADDING)&& !ard_last_threerow)  //20251203
	// 	last_threerow <= 1;
	
	else
		last_threerow <= last_threerow;

end






//------------------------------------------------
//------

//===========================kernel and bias control===============

always @(posedge clk ) begin
	if (reset) begin ker_write_start<= 1'd0 ; end
	else begin
		if( fsld_current_state == FS_KER  )begin
			ker_write_start<= ~ker_write_busy & ~ker_write_done ;
		end
		else begin
			ker_write_start<= 1'd0;
		end
	end
end


always @(posedge clk ) begin
	if (reset) begin bias_write_start<= 1'd0 ; end
	else begin
		if( fsld_current_state == FS_BIAS  )begin
			bias_write_start<= ~bias_write_busy & ~bias_write_done ;
		end
		else begin
			bias_write_start<= 1'd0;
		end
	end
end

//==============================================================================
//========    if padding control start signal    ========
//==============================================================================

always @(posedge clk ) begin
	if(reset)if_pad_start <= 1'd0 ;
	else begin
		if( fsld_current_state == FS_IFPD  )begin
			if_pad_start<= (!if_pad_busy) & (!if_pad_done)  ;
		end
		else if ( block_current_state==BK_PADD )begin
			if_pad_start<= (!if_pad_busy) & (!if_pad_done)  ;
		end
		else begin
			if_pad_start<= 1'd0;
		end
	end
end


endmodule
