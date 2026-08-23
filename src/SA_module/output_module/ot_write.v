// ============================================================================
// Designer : Yi_Yuan Chen
// Modify   : Fixed 2-Row Parallel Write Data Drop / Alignment Bug
// Func     : output write sram module
// ============================================================================

module ot_write #(
	parameter SRAM_DATA_BITS = 64	
	,	SRAM_ADDR_BITS = 12  //HYR
)
(
		clk			
	,	reset			
	
	// --- Row 0 FIFO ---
	,	data_in				
	,	fifo_empty_n		
	,	fifo_read 			

	// --- Row 1 FIFO ---
	,	data_in_r1				
	,	fifo_empty_n_r1		
	,	fifo_read_r1

	,	last				

	,	addr_otsr			
	,	cen_otsr			
	,	wen_otsr			
	,	data_for_sram		// Row 0 data
	,	data_for_sram_r1	// Row 1 data

	,	cfg_ot_rnd_finsub1		
);

//========    Input/Output    ========
	input clk		;
	input reset		;

	input [ SRAM_DATA_BITS-1 : 0 ]		data_in		;
	input	fifo_empty_n 	;
	output	fifo_read 	;

	input [ SRAM_DATA_BITS-1 : 0 ]		data_in_r1	;
	input	fifo_empty_n_r1 ;
	output	fifo_read_r1 	;

	output wire last ;

	output cen_otsr	;
	output wen_otsr	;
	output [ SRAM_ADDR_BITS-1 : 0 ]		addr_otsr		;
	output [ SRAM_DATA_BITS-1 : 0 ]		data_for_sram	;
	output [ SRAM_DATA_BITS-1 : 0 ]		data_for_sram_r1;

	input wire [ SRAM_ADDR_BITS-1 : 0 ]		cfg_ot_rnd_finsub1 ;

//-----------------------------------------------------------------------------

wire cnt_addr_en ;
// cnt_addr_last : counter .last tap, unread -- left open
wire [ SRAM_ADDR_BITS-1 : 0 ]		cnt_addr_finnumsub1		;		
wire [ SRAM_ADDR_BITS-1 : 0 ]		cnt_addr		;

reg valid_in_dly0 ;
reg [SRAM_DATA_BITS-1:0] data_in_dly0 ;
reg [SRAM_DATA_BITS-1:0] data_in_r1_dly0 ;

// ---- Row0 / Row1 independent staging registers ----
reg have0, have1 ;
reg [SRAM_DATA_BITS-1:0] stage0, stage1 ;

wire take0 = fifo_empty_n    & ~have0 ;
wire take1 = fifo_empty_n_r1 & ~have1 ;
wire both_ready = (have0 | take0) & (have1 | take1) ;

assign fifo_read    = both_ready ? take0 : take0;
assign fifo_read_r1 = both_ready ? take1 : take1;

assign cen_otsr = ~valid_in_dly0 ;
assign wen_otsr = ~valid_in_dly0 ;

assign data_for_sram    = ( valid_in_dly0 )? data_in_dly0 : 64'd0 ;
assign data_for_sram_r1 = ( valid_in_dly0 )? data_in_r1_dly0 : 64'd0 ;

assign addr_otsr = cnt_addr ;
assign last = (  !valid_in_dly0 )? 1'd0 : 
				(cnt_addr == cnt_addr_finnumsub1) ? 1'd1 : 1'd0 ;

always @(posedge clk ) begin
	if( reset ) begin
		have0  <= 1'b0 ;
		have1  <= 1'b0 ;
		stage0 <= {SRAM_DATA_BITS{1'b0}} ;
		stage1 <= {SRAM_DATA_BITS{1'b0}} ;
	end
	else begin
		if ( both_ready ) begin
			// �p�G���䳣�ǳƦn�F�A�M�żȦs�мСA���U�@����ƥi�H�i��
			have0 <= 1'b0 ;
			have1 <= 1'b0 ;
		end
		else begin
			// �p�G�٨S����A�N��Ū�X�Ӫ���Ʀwí�a��i�Ȧs��
			if ( take0 ) begin stage0 <= data_in;    have0 <= 1'b1 ; end
			if ( take1 ) begin stage1 <= data_in_r1; have1 <= 1'b1 ; end
		end
	end
end

always @(posedge clk ) begin
	if( reset )
		valid_in_dly0 <= 1'b0 ;
	else
		valid_in_dly0 <= both_ready ;
end

always @(posedge clk ) begin
	// �� both_ready ���߮ɡA��ƥi��ӦۼȦs�� (have)�A�]�i�ઽ���Ӧۭ�Ū�X�� FIFO (take)
	data_in_dly0    <= have0 ? stage0 : data_in ;
	data_in_r1_dly0 <= have1 ? stage1 : data_in_r1 ;
end

assign cnt_addr_en = valid_in_dly0 ;
assign cnt_addr_finnumsub1 = cfg_ot_rnd_finsub1 ;

count_yi_v4 #(
    .BITS_OF_END_NUMBER (	SRAM_ADDR_BITS		)
)b0_ct00(
    	.clk			( 	clk 				)
    ,	.reset 	 		(	reset				)
    ,	.enable	 		(	cnt_addr_en			)
	,	.final_number	(	cnt_addr_finnumsub1	)
	,	.last			(						)
    ,	.total_q		(	cnt_addr			)
);

endmodule