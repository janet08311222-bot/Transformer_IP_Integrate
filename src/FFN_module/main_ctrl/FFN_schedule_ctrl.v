// ============================================================================
// Designer : Chao-Ping Liu
// Create   : 2025.06.26
// Ver      : 1.0
// Func     : schedule control, generate start signal for sram r/w module
// Log		:
// ============================================================================


module FFN_schedule_ctrl #(
    parameter TBITS = 64
    ,   TBYTE = 8
)(
		clk
	,	reset
	
	,	mast_curr_state 	

	,	if_write_start
	,	if_write_busy
	,	if_write_done

	,	if_read_start 
	,	if_read_busy 
	,	if_read_done	

	,	ker_write_start
	,	ker_write_busy
	,	ker_write_done
	,	ker_write_last
	,	ker_write_tile_done

	,	ker_read_start
	,	ker_read_busy 	
    ,   ker_read_done
	,	ker_read_tile_done

	,	bias_write_start
	,	bias_write_busy	
	,	bias_write_done

	,	bias_read_start
	,	bias_read_busy
	,	bias_read_done

	,	chk_ot_ready
		
	,	fsld_done
	,	base_done
);

    //---- master FSM parameter ----
	localparam MAST_FSM_BITS 	= 3;
	localparam M_IDLE 	= 3'd0;
	localparam M_FSLD	= 3'd1;
	localparam M_BASE 	= 3'd2;
	localparam M_DONE 	= 3'd3;

    // ============================= I/O port Declare ===============================
	input wire clk		;
	input wire reset	;

	input wire [ MAST_FSM_BITS -1 : 0 ] mast_curr_state	;

	output reg	if_write_start		;
	input wire	if_write_busy		;
	input wire 	if_write_done		;

	output reg 	if_read_start		;	
    input wire 	if_read_busy		;	
    input wire 	if_read_done		;	

	output reg 	ker_write_start 	;
	input wire	ker_write_done 		;
	input wire	ker_write_busy 		;
	input wire  ker_write_last		;
	input wire  ker_write_tile_done	;

	output reg	ker_read_start		;
	input wire	ker_read_done 		;
	input wire	ker_read_busy 		;
	input wire	ker_read_tile_done	;
	
	output reg 	bias_write_start 	;
	input wire	bias_write_done 	;
	input wire	bias_write_busy 	;

	output reg 	bias_read_start		;
	input wire	bias_read_done		;	
	input wire	bias_read_busy		;	

	input wire	chk_ot_ready		;

	output reg 	fsld_done			;
	output reg	base_done			;

    // ============================= Declare ===============================

    //--------------- master state = M_FSLD -----------------------------
	reg [3:0] fsld_curr_state ;
	reg [3:0] fsld_next_state ;
	localparam FS_IDLE 	= 3'd0;
	localparam FS_IF 	= 3'd1;
	localparam FS_BIAS 	= 3'd2;
	localparam FS_KER 	= 3'd3;
	localparam FS_DONE 	= 3'd7;
    //--------------- master state = M_BASE -----------------------------
	reg [3:0] block_curr_state ;
	reg [3:0] block_next_state ;
	localparam BK_IDLE 		= 3'd0;
	localparam BK_RDWT		= 3'd1;
	localparam BK_BIWT		= 3'd2;
	localparam BK_OUT		= 3'd3;	// s2mm output state
	localparam BK_RDWEIGHT 	= 3'd4; // read weight state
	localparam BK_DONE		= 3'd5;

	//---- gate BK_RDWT->BK_BIWT until BOTH the kernel READ (compute, ker_read_tile_done)
	//     and the kernel WRITE prefetch chunk (ker_write_tile_done) for the tile are done.
	//     16-way halves tile_size so compute finishes ~2x before the kernel-write chunk
	//     drains; the old transition (ker_read_tile_done only) let the bias write start
	//     while kernel data was still streaming -> kernel data corrupted the bias SRAM
	//     (kernel/bias write overlap through FFN_d_empn_rd_mux). 8-way: both pulses fire
	//     together, so this is behavior-preserving there.
	reg  rd_tile_done_l ;
	reg  wr_tile_done_l ;
	wire bk_rdwt_done = ( rd_tile_done_l | ker_read_tile_done ) & ( wr_tile_done_l | ker_write_tile_done ) ;
	//==============================================================================
	//========    first load FSM and fsld_done    ========
	//==============================================================================
	
	//--------------- KERNEL SRAM parameter -----------------------------
	//--------------- KERNEL READ FSM -----------------------------
	localparam KER_READ_IDLE 	= 2'd0;
	localparam KER_READ_BUSY 	= 2'd1;
	localparam KER_READ_DONE 	= 2'd2;

    //==============================================================================
    //========    first load FSM and fsld_done    ========
    //==============================================================================
    always @(posedge clk ) begin
        if ( reset )
            fsld_curr_state <= 3'd0 ;
        else
            fsld_curr_state <= fsld_next_state ;
    end
    always @(*) begin
        case (fsld_curr_state)
            FS_IDLE 	:	fsld_next_state = ( mast_curr_state == M_FSLD )	? FS_IF   : FS_IDLE ;
            FS_IF 	    :	fsld_next_state = ( if_write_done )				? FS_BIAS : FS_IF   ;
            FS_BIAS 	:	fsld_next_state = ( bias_write_done )			? FS_KER  : FS_BIAS ;
            FS_KER 		:	fsld_next_state = ( ker_write_done )			? FS_DONE : FS_KER  ;
            FS_DONE 	:	fsld_next_state = FS_IDLE   ;
            default		: 	fsld_next_state = FS_IDLE   ;
        endcase
    end

    //----    output fsld_done signal for master FSM    -----
    always @(*) begin
        if(mast_curr_state == M_FSLD && fsld_curr_state == FS_DONE)
            fsld_done = 1'd1 ;
        else
            fsld_done = 1'd0 ;
    end

    //-----------------------------------------------------------------------------
    //-----------------------------------------------------------------------------

    //==============================================================================
    //========    block FSM and base_done    ========
    //==============================================================================
    always @(posedge clk) begin
        if(reset) begin
            block_curr_state <= 3'd0 ;
        end
        else begin
            block_curr_state <= block_next_state ;
        end
    end
    always @(*) begin
        case (block_curr_state)
            BK_IDLE 	:	block_next_state = ( mast_curr_state == M_BASE ) ? BK_RDWT : BK_IDLE ;
            BK_RDWT     :   block_next_state = ( ker_write_last ) ? BK_RDWEIGHT : ( bk_rdwt_done ) ? BK_BIWT : BK_RDWT ;
            BK_BIWT     :   block_next_state = ( bias_write_done ) ? BK_OUT : BK_BIWT ;
			BK_OUT		:	block_next_state = ( chk_ot_ready ) ? BK_RDWT : BK_OUT ;
			BK_RDWEIGHT	:	block_next_state = ( ker_read_done ) ? BK_DONE : BK_RDWEIGHT ;
            BK_DONE 	:	block_next_state = BK_IDLE ;
            default     :   block_next_state = BK_IDLE ; 
        endcase
    end

    //----    output base_done signal for master FSM    -----
    always @(*) begin
		if(mast_curr_state == M_BASE && block_curr_state == BK_DONE)
			base_done = 1'd1;
		else
			base_done = 1'd0;
	end

	//----    latch the per-tile read/write done pulses within one BK_RDWT    -----
	//   cleared whenever not in BK_RDWT so each tile starts fresh; bk_rdwt_done
	//   (above) asserts once both have been seen -> only then start the bias write.
	always @(posedge clk) begin
		if( reset || block_curr_state != BK_RDWT ) begin
			rd_tile_done_l <= 1'b0 ;
			wr_tile_done_l <= 1'b0 ;
		end
		else begin
			if( ker_read_tile_done  ) rd_tile_done_l <= 1'b1 ;
			if( ker_write_tile_done ) wr_tile_done_l <= 1'b1 ;
		end
	end

    //=========================== input control ===============
    always @(posedge clk) begin
    	if(reset)
            if_write_start <= 1'd0 ;
    	else
            if_write_start <= ( fsld_curr_state == FS_IF ) ? ((!if_write_busy) && (!if_write_done)) : 1'd0;
    end

	always @(*) begin
		if_read_start = ker_read_start ;
	end

    //=========================== kernel control ==============
    always @(posedge clk) begin
    	if (reset)
            ker_write_start <= 1'd0 ;
    	else
            ker_write_start <= ( fsld_curr_state == FS_KER || block_curr_state == BK_RDWT ) ? (~ker_write_busy & ~ker_write_done & ~ker_read_busy) : 1'd0;
    end

    always @(posedge clk ) begin
		if (reset)
			ker_read_start <= 1'd0 ; 
		else begin
			if( block_curr_state == BK_RDWT || block_curr_state == BK_RDWEIGHT )
				ker_read_start <= ~ker_read_busy & ~ker_read_done & ~ker_write_busy ;
			else
				ker_read_start <= 1'd0;
		end
	end

    //=========================== bias control ================
    always @(posedge clk ) begin
    	if (reset)
            bias_write_start <= 1'd0 ;
    	else
            bias_write_start <= ( fsld_curr_state == FS_BIAS || block_curr_state == BK_BIWT ) ? ((!bias_write_busy) && (!bias_write_done) && (!ker_write_busy)) : 1'd0;
    end

	always @(*) begin
		bias_read_start = ker_read_start ;
	end

endmodule