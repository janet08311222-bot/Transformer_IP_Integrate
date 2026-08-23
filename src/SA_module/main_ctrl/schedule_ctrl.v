// ============================================================================
// Designer : Yi_Yuan Chen
// Modify   : Fixed `read_cheak` 2-cycle timeout Deadlock for 2-Row Parallel 
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

	input wire clk		;
	input wire reset	;
	input wire [ MAST_FSM_BITS -1 : 0 ] mast_curr_state	;
	input wire [3-1:0]	cfg_conv_switch		;

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
	output wire left_done;
	output wire base_done;
	output wire right_done;

	output reg if_read_start;  
    input wire if_read_busy;   
    input wire if_read_done;   

    input wire if_row_finish;       
	input wire if_dy2_conv_finish;  
    output reg [2:0] if_read_current_state; 
	output reg rdwd_done;		

	output wire[3-1:0] sche_fsld_curr_state ;
	
	input wire [8:0] cfg_total_row;
	input wire if_write_empty_n_din;
	output wire if_read_last;

//-------------------   done flag    --------------------------------
	// sche_if_done / sche_ker_done / sche_bias_done : declared, never driven or read
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

//--------------- 2-row parallel ------------------------------------
//	ifsram_r reads the row pair { row , row+1 } every read pass, so one pass
//	consumes ROWS_PER_PASS ifmap rows and produces ROWS_PER_PASS output rows.
//	The schedule therefore has to load 2 new rows per pass instead of 1.
//
//	NOTE on the buffer depth : ifsram_w only ever drives two physical locations,
//	address 0 of bank-group A (wr_row_parity = 0) and address 0+atl_ch of group B
//	(wr_row_parity = 1) -- measured on the SRAM ports.  So the ifmap buffer holds
//	exactly ONE row pair, which the loader overwrites every time.  There is no
//	{0,1} / {2,3} double buffer to ping-pong between: the read window must stay
//	on row 0 (pair A@0 / B@atl_ch) and the reload must NOT overlap the compute
//	pass, otherwise the loader rewrites the very rows being read.
	localparam ROWS_PER_PASS = 2 ;

	//---- if schedule need ----
	reg [8:0] write_row_number;		//YWJ
	reg [1:0] dy_if_write_start;
	reg [1:0] dy_if_read_start;

	reg read_last;
	reg read_last_cheak;
    reg read_cheak;

	reg [2:0] wr_in_pass ;			// rows loaded since the current read pass began
	reg       dly_if_read_start_lv ;
	reg       rd_gap ;				// 1 = between two read passes, safe to reload
	wire      wr_quota_left ;		// this pass may still issue another load
	wire      wr_pass_full ;		// the pair for the NEXT pass is loaded
	wire      wr_idle ;				// no load issued and none running

assign bk_state_lr = ( mast_curr_state== LEFT || mast_curr_state== RIGH ) ? 1'd1 : 1'd0 ;
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

always @(*) begin
	if (mast_curr_state == FSLD ) begin
		if ( fsld_current_state == FS_DONE ) flag_fsld_end = 1'd1;
		else flag_fsld_end = 1'd0;
	end
	else flag_fsld_end = 1'd0;
end

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
		BK_PADD     :   block_next_state = (if_pad_done) 			  ? BK_FSLD : BK_PADD ;
		// 2-row parallel : pre-load ROWS_PER_PASS rows (slot 0 and slot 1) before
		// the first read pass, otherwise the pass reads a slot that has not been
		// written yet.
		BK_FSLD     :   block_next_state = (if_write_done && (write_row_number >= ROWS_PER_PASS-1)) ? BK_RDWT : BK_FSLD ;
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
		// 2-row parallel : the loader always refills the same physical row pair
		// (see the note above), so the read window has to stay on row 0 --
		// ROW_ADDR_012 self-loops instead of walking 012->123->230->301.
		// ROW_ADDR_123 / 230 / 301 address slots the loader never writes; their
		// arcs are left alone for the 3x3 configuration but are unreachable here.
		IDLE         : if_read_next_state = (block_current_state == BK_RDWT && !rdwd_done) ?  UP_PADDING : IDLE;
		UP_PADDING   : if_read_next_state = (if_read_done) ? (read_last_cheak) ? DOWN_PADDING : ROW_ADDR_012 : UP_PADDING;
		ROW_ADDR_012 : if_read_next_state = (if_read_done) ? (read_last_cheak) ? DOWN_PADDING : ROW_ADDR_012 : ROW_ADDR_012;
		ROW_ADDR_123 : if_read_next_state = (if_read_done) ? (read_last_cheak) ? DOWN_PADDING : ROW_ADDR_230 : ROW_ADDR_123;
		ROW_ADDR_230 : if_read_next_state = (if_read_done) ? (read_last_cheak) ? DOWN_PADDING : ROW_ADDR_301 : ROW_ADDR_230;
		ROW_ADDR_301 : if_read_next_state = (if_read_done) ? (read_last_cheak) ? DOWN_PADDING : ROW_ADDR_012 : ROW_ADDR_301;
		DOWN_PADDING : if_read_next_state = (if_read_done) ? IDLE     : DOWN_PADDING;
		default      : if_read_next_state = IDLE;
	endcase
end

always @ (*)begin
	if(write_row_number >= cfg_total_row)
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

//-----------------if write signal-----------------

// ---- how many ifmap rows have been loaded during the current read pass ----
//	Counted on the rising edge of if_write_start (not if_write_done) so the quota
//	is taken the moment a load is issued -- if_write_busy needs a few cycles to
//	come up and would otherwise let a second load slip through.
always @(posedge clk) begin
	if(reset)	dly_if_read_start_lv <= 1'b0 ;
	else		dly_if_read_start_lv <= if_read_start ;
end

always @(posedge clk) begin
	if(reset)
		wr_in_pass <= 3'd0 ;
	else if(if_read_start && !dly_if_read_start_lv)		// a new read pass begins
		wr_in_pass <= 3'd0 ;
	else if(if_write_start && (dy_if_write_start == 2'd0))
		wr_in_pass <= wr_in_pass + 3'd1 ;
	else
		wr_in_pass <= wr_in_pass ;
end

assign wr_quota_left = ( wr_in_pass <  ROWS_PER_PASS ) ;
assign wr_pass_full  = ( wr_in_pass >= ROWS_PER_PASS ) ;
assign wr_idle       = ( !if_write_busy && !if_write_start ) ;

// rd_gap : high between two read passes.  The loader overwrites the row pair the
// compute pass is reading, so reloading is only safe here.
always @(posedge clk) begin
	if(reset)					rd_gap <= 1'b1 ;
	else if(if_read_start)		rd_gap <= 1'b0 ;
	else if(if_read_done)		rd_gap <= 1'b1 ;
	else						rd_gap <= rd_gap ;
end

always @(posedge clk) begin
	if(reset)
		if_write_start <= 0;
	else if(dy_if_write_start == 3)
		if_write_start <= 0;
	// first load : pre-fill the first row pair before any read pass runs
	else if(block_current_state == BK_FSLD && !if_write_busy && !if_read_busy)
		if_write_start <= 1;
	// 2-row parallel : reload ROWS_PER_PASS rows in the gap after each compute
	// pass.  rd_gap (not !if_read_busy) is the guard -- if_read_busy lags
	// if_read_start by two cycles, which used to let one load slip in on top of
	// the row pair the pass had just started reading.
	// No "input stream has data" term here on purpose : if_write_empty_n_din is
	// only visible while ifsram_w is already loading (if_write_en), so using it
	// as a precondition is circular.  ifsram_w simply stalls inside its load FSM
	// until data arrives, exactly like it does for the BK_FSLD pre-load above.
	else if(((if_read_current_state >= UP_PADDING)&&(if_read_current_state <= ROW_ADDR_301) ) && rd_gap && !if_write_busy && wr_quota_left && (write_row_number < cfg_total_row))
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
		dy_if_write_start <= 0; 
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
		write_row_number <= write_row_number + 5'd1;             
	else if(block_current_state == BK_RDWT && if_write_done )
		write_row_number <= write_row_number + 5'd1;
	else
		write_row_number <= write_row_number;
end

//-----------------if read signal-----------------
// �� FIX: ���� 2-cycle timeout�A��� Persistent Ready Flag ���� chk_ot_ready �N�� ��

always @(posedge clk) begin
	if (reset)
		read_cheak <= 0;
	else if (if_read_start) // ���o�eŪ���R�O��A���Ӧ� Ready �X��
		read_cheak <= 0;
	else if (if_write_empty_n_din) // FIFO �@����ƴN�L�����O�� Ready
		read_cheak <= 1;
end

always @(posedge clk) begin
	if(reset)
		if_read_start <= 0;
	else if(dy_if_read_start == 3)
		if_read_start <= 0;
	else if(((if_read_current_state == UP_PADDING)||(if_read_current_state == DOWN_PADDING))&& !if_read_busy  && ! if_read_done && wr_idle && chk_ot_ready)
		if_read_start <= 1;
	// 2-row parallel : the next pass may only start once the row pair it is going
	// to read has actually been loaded during the current pass (wr_pass_full).
	// read_cheak used to serve this role but it only tracks "the input FIFO had
	// data at some point", which no longer says anything about how many rows are
	// in the buffer now that a pass consumes two of them.
	else if((if_read_current_state >= ROW_ADDR_012 && if_read_current_state <= ROW_ADDR_301)&& !if_read_busy && (wr_pass_full || read_last) && wr_idle && chk_ot_ready)
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
reg ard_last_threerow; 

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
	else
		last_threerow <= last_threerow;
end

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