// ============================================================================
// Designer : Yi_Yuan Chen
// Modify   : Added 2-Row Parallel Read, FWFT Skid Buffer & Perfect Alignment
// Func     : output read sram module (Fully AXI-Stream Compliant)
// ============================================================================

module ot_read #(
	parameter	SRAM_DATA_BITS = 64
	,	SRAM_ADDR_BITS = 12  //HYR
)
(
	input wire clk			
	,	input wire reset		

	,	input wire start		
	,	output wire busy		
	,	output reg done	

	,	input wire din_s2mm_tready	
	,	input wire fifo_full_n		
	,	output wire fifo_write		
	,	output wire fifo_last		
	,	output wire [ SRAM_DATA_BITS-1 : 0 ] fifo_data		

	// --- Row 0 SRAM Input ---
	,	input wire [ SRAM_DATA_BITS-1 : 0 ] data_from_sram	
	// --- Row 1 SRAM Input ---
	,	input wire [ SRAM_DATA_BITS-1 : 0 ] data_from_sram_r1

	,	output wire [ SRAM_ADDR_BITS-1 : 0 ] addr_otsr	
	,	output wire cen_otsr	
	,	output wire wen_otsr

	,	input wire [SRAM_ADDR_BITS-1:0] cfg_ot_tgpfnsub1		
	,	input wire [SRAM_ADDR_BITS-1:0] cfg_ot_tcolfnsub1		
	,	input wire [SRAM_ADDR_BITS-1:0] cfg_ot_tchafnsub1		
	,	input wire [SRAM_ADDR_BITS-1:0] cfg_ot_sft_gp			
	,	input wire [SRAM_ADDR_BITS-1:0] cfg_ot_sft_colpra		

);

	//---- address FSM ----
	localparam AD_IDLE 		= 3'd0 ;
	localparam AD_READ_R0 	= 3'd1 ;
	localparam AD_WAIT_SW 	= 3'd2 ; // ���� Row �ɪ��L�窬�A
	localparam AD_READ_R1 	= 3'd3 ;
	localparam AD_RST_CNT	= 3'd4 ;
	
	reg [2:0] addr_curr_state ;
	reg [2:0] addr_next_state ;

	//---- main FSM ----
	localparam IDLE 		= 2'd0 ;
	localparam BASE_BUSY	= 2'd1 ;
	localparam RST_CNT		= 2'd2 ;

	reg [1:0] current_state;
	reg [1:0] next_state;

	// ============================================================================
	// ���� FWFT FIFO �ŧi (�Ω��� AXI-Stream �I���P�ᵲ�޽u)
	// ============================================================================
	reg [SRAM_DATA_BITS-1:0] fifo_mem [0:15];
	reg fifo_last_mem [0:15];
	reg [4:0] wptr;
	reg [4:0] rptr;

	wire [4:0] fifo_count = wptr - rptr;
	// �� FIFO �ֺ��� (�d 4 ��Ϋ׵����� Pipeline �ݯd���)�A�Ȱ� SRAM Ū��
	wire internal_fifo_full = (fifo_count >= 5'd12);
	wire internal_fifo_empty = (wptr == rptr);

	// SRAM Ū���P��G�u�n���A���T�B���� FIFO �˱o�U�A�N���t�e�i�A�������ޥ~�� TREADY
	wire sram_read_en = (addr_curr_state == AD_READ_R0 || addr_curr_state == AD_READ_R1) && !internal_fifo_full;

	//---- Counter & Control Signals ----
	wire addr_last ;
	wire fsm_rstcnt	;
	wire acnt_rst		;
	wire [SRAM_ADDR_BITS-1:0] ct_gp	;
	wire [SRAM_ADDR_BITS-1:0] ct_gp_finnumsub1	;
	wire [SRAM_ADDR_BITS-1:0] ct_cha	;
	wire [SRAM_ADDR_BITS-1:0] ct_cha_finnumsub1	;
	wire [SRAM_ADDR_BITS-1:0] ct_col	;
	wire [SRAM_ADDR_BITS-1:0] ct_col_finnumsub1	;

	wire ct_col_en	;
	wire ct_col_last	;
	wire ct_cha_en	;
	wire ct_cha_last	;
	wire ct_gp_en	;
	wire ct_gp_last	;


	// ��T���𱱨��� (2 �穵��A������� BRAM ��}���ƿ�X�� Latency)
	reg pipe_valid_d1, pipe_valid_d2;
	reg pipe_row_sel_d1, pipe_row_sel_d2;
	reg pipe_last_d1, pipe_last_d2;

	// ============================================================================
	// FSM �޿�
	// ============================================================================
	always @(posedge clk) begin
		if (reset) current_state <= IDLE ;
		else current_state <= next_state ;
	end

	always @(*) begin
		case (current_state)
			IDLE		: next_state = (start) ? BASE_BUSY : IDLE ;
			BASE_BUSY	: next_state = (addr_curr_state == AD_RST_CNT) ? RST_CNT : BASE_BUSY ;
			RST_CNT		: next_state = IDLE	;
			default: next_state = IDLE ;
		endcase
	end

	assign busy = (current_state == BASE_BUSY || current_state == RST_CNT) ? 1'b1 : 1'b0 ;

	always @(*) begin
		done = (!busy) ? 1'b0 : (current_state == RST_CNT) ? 1'b1 : 1'b0 ;
	end

	always @(posedge clk) begin
		if (reset) begin
			addr_curr_state <= AD_IDLE ;
		end else begin
			addr_curr_state <= addr_next_state ;
		end
	end

	always @(*) begin
		case (addr_curr_state)
			AD_IDLE		: addr_next_state = (current_state == BASE_BUSY) ? AD_READ_R0 : AD_IDLE ;
			AD_READ_R0	: addr_next_state = (addr_last) ? AD_WAIT_SW : AD_READ_R0 ;
			AD_WAIT_SW	: addr_next_state = AD_READ_R1; // ���p�ƾ� 1 cycle reset �ɶ�
			AD_READ_R1	: addr_next_state = (addr_last) ? AD_RST_CNT : AD_READ_R1 ;
			AD_RST_CNT	: addr_next_state = AD_IDLE ;
			default: addr_next_state = AD_IDLE ;
		endcase
	end

	// ============================================================================
	// SRAM �������� �P ��} Pipeline
	// ============================================================================
	assign cen_otsr = ~sram_read_en;
	assign wen_otsr = 1'b1; // ��Ū
	// Address is combinational from the counters.  Registering it (the old
	// shtidx_* stage) made the address lag the burst by one cycle, so the burst's
	// 64 enabled cycles only ever presented addresses 0..62 -- the final address
	// was issued after the state had already moved on and the last word of every
	// 64-word half came out as a duplicate of word 62.
	assign addr_otsr = (ct_gp * cfg_ot_sft_gp) + (ct_cha * cfg_ot_sft_colpra) + ct_col ;

	assign addr_last = (!sram_read_en) ? 1'b0 :
						(ct_col_last && ct_cha_last && ct_gp_last) ? 1'b1 : 1'b0 ;

	// ============================================================================
	// Pipeline ����T���P�B�� (�ѨM���� Row �_�y�P Mismatch)
	// ============================================================================
	always @(posedge clk) begin
		if (reset) begin
			pipe_valid_d1   <= 1'b0;
			pipe_valid_d2   <= 1'b0;
			pipe_row_sel_d1 <= 1'b0;
			pipe_row_sel_d2 <= 1'b0;
			pipe_last_d1    <= 1'b0;
			pipe_last_d2    <= 1'b0;
		end else begin
			// ���� Valid �T��
			pipe_valid_d1   <= sram_read_en;
			pipe_valid_d2   <= pipe_valid_d1;
			
			// ���� Row ��ܱ��� (�H���֤ͮߦ�}���U�����A����)
			pipe_row_sel_d1 <= (addr_curr_state == AD_READ_R1);
			pipe_row_sel_d2 <= pipe_row_sel_d1;
			
			// �Ȧb Row 1 ���̫�@����ƥͦ� AXI TLAST
			pipe_last_d1    <= (addr_last && (addr_curr_state == AD_READ_R1));
			pipe_last_d2    <= pipe_last_d1;
		end
	end

	// ============================================================================
	// �g�J���� FIFO (SRAM ��Ʀ��e)
	// ============================================================================
	// �ھں�T�P�B�᪺ pipe_row_sel_d2 �M�w���e������@�� Row �����
	// One pipeline stage, not two : with the combinational address the SRAM data
	// for the read issued in cycle T is valid in cycle T+1, which is exactly when
	// the d1 registers describe that read.  (The d2 stage is what mis-tagged the
	// word at the Row0 -> Row1 hand-over.)
	wire [SRAM_DATA_BITS-1:0] chosen_sram_data = pipe_row_sel_d1 ? data_from_sram_r1 : data_from_sram;

	always @(posedge clk) begin
		if (reset) begin
			wptr <= 0;
		end else if (pipe_valid_d1) begin
			fifo_mem[wptr[3:0]] <= chosen_sram_data;
			fifo_last_mem[wptr[3:0]] <= pipe_last_d1;
			wptr <= wptr + 1;
		end
	end

	// ============================================================================
	// �q���� FIFO Ū�X�� AXI-Stream ��f (�����䴩 TREADY �I��)
	// ============================================================================
	// fifo_write is the WRITE STROBE of the downstream OUTPUT_STREAM_if FIFO, not
	// the AXI TVALID (that one is driven by the output FIFO's own empty_n).  It
	// must therefore be qualified with the downstream fifo_full_n, and rptr must
	// advance on exactly the same event -- push and pop are one handshake.
	//
	// The previous version used   fifo_write = !internal_fifo_empty   and popped
	// on the external din_s2mm_tready.  With TREADY low the strobe stayed high
	// while rptr stood still, so the same word was pushed into the output FIFO
	// over and over (and once that FIFO filled, words were silently dropped) --
	// every AXI back-pressure window corrupted the rest of the output row.
	assign fifo_write = !internal_fifo_empty && fifo_full_n ;
	assign fifo_data  = fifo_mem[rptr[3:0]];  // TDATA
	assign fifo_last  = fifo_last_mem[rptr[3:0]];  // TLAST

	wire fifo_read_ack = fifo_write ;

	always @(posedge clk) begin
		if (reset) begin
			rptr <= 0;
		end else if (fifo_read_ack) begin
			rptr <= rptr + 1;
		end
	end

	// ============================================================================
	// �p�ƾ������޿�
	// ============================================================================
	assign ct_gp_finnumsub1   = cfg_ot_tgpfnsub1;
	assign ct_cha_finnumsub1  = cfg_ot_tchafnsub1;
	assign ct_col_finnumsub1  = cfg_ot_tcolfnsub1;

	assign ct_gp_en   = (ct_col_last && ct_cha_last) ? sram_read_en : 1'b0;
	assign ct_cha_en  = sram_read_en;
	assign ct_col_en  = (ct_cha_last) ? sram_read_en : 1'b0;

	assign fsm_rstcnt = (addr_curr_state == AD_RST_CNT || addr_curr_state == AD_WAIT_SW) ? 1'b1 : 1'b0 ;
	assign acnt_rst	  = reset | fsm_rstcnt ;

	count_yi_v4 #(
		.BITS_OF_END_NUMBER ( SRAM_ADDR_BITS )
	) otr_ct00 (
		.clk          ( clk ),
		.reset        ( acnt_rst ),
		.enable       ( ct_gp_en ),
		.final_number ( ct_gp_finnumsub1 ),
		.last         ( ct_gp_last ),
		.total_q      ( ct_gp )
	);

	count_yi_v4 #(
		.BITS_OF_END_NUMBER ( SRAM_ADDR_BITS )
	) otr_ct01 (
		.clk          ( clk ),
		.reset        ( acnt_rst ),
		.enable       ( ct_cha_en ),
		.final_number ( ct_cha_finnumsub1 ),
		.last         ( ct_cha_last ),
		.total_q      ( ct_cha )
	);

	count_yi_v4 #(
		.BITS_OF_END_NUMBER ( SRAM_ADDR_BITS )
	) otr_ct02 (
		.clk          ( clk ),
		.reset        ( acnt_rst ),
		.enable       ( ct_col_en ),
		.final_number ( ct_col_finnumsub1 ),
		.last         ( ct_col_last ),
		.total_q      ( ct_col )
	);

endmodule