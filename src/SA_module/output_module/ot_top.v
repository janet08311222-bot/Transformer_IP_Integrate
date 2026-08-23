// ============================================================================
// Designer : Yi_Yuan Chen
// Modify   : Added 2-Row Parallel Write Support
// Func     : output top module
// ============================================================================
`ifndef ASIC
`define FPGA_SRAM_SETTING	// FPGA (Vivado BRAM) path ; build with +define+ASIC to use the N16 SRAM macros in sram.v
`endif

module ot_top 
#(
	parameter TBITS = 64 
	,	TBYTE = 8
	,	PEBLKROW_NUM = 8
	,	SRAM_DATA_BITS = 64
	,	SRAM_ADDR_BITS = 12  //HYR
)(
	clk 	
	,	reset 				

	,	din_s2mm_tready			
	,	fifo_full_n			
	,	fifo_write			
	,	fifo_last			
	,	fifo_data	

	,	ot_ready		

	,	valid_din 			
	,	data_din		
	
	// --- Add Row 1 input ---
	,	valid_din_r1
	,	data_din_r1

	,	cfg_ot_rnd_finsub1	
	,	cfg_ot_tgpfnsub1	
	,	cfg_ot_tcolfnsub1	
	,	cfg_ot_tchafnsub1	
	,	cfg_ot_sft_gp		
	,	cfg_ot_sft_colpra	
);

	input clk ;
	input reset	;
	input [ PEBLKROW_NUM-1		 : 0 ]	valid_din ;
	input [ PEBLKROW_NUM*TBITS-1 : 0 ]	data_din ;

	input [ PEBLKROW_NUM-1		 : 0 ]	valid_din_r1 ;
	input [ PEBLKROW_NUM*TBITS-1 : 0 ]	data_din_r1 ;

	input 	din_s2mm_tready		;
	input 	fifo_full_n		;
	output	fifo_write		;
	output	fifo_last		;
	output	reg ot_ready ;

	output [ SRAM_DATA_BITS-1 : 0 ]	fifo_data		;
	
	//----    config in    -----
	input wire	[ SRAM_ADDR_BITS-1 : 0 ]	cfg_ot_rnd_finsub1	;
	input wire	[ SRAM_ADDR_BITS-1 : 0 ]	cfg_ot_tgpfnsub1	;
	input wire	[ SRAM_ADDR_BITS-1 : 0 ]	cfg_ot_tcolfnsub1	;
	input wire	[ SRAM_ADDR_BITS-1 : 0 ]	cfg_ot_tchafnsub1	;
	input wire	[ SRAM_ADDR_BITS-1 : 0 ]	cfg_ot_sft_gp		;
	input wire	[ SRAM_ADDR_BITS-1 : 0 ]	cfg_ot_sft_colpra	;

reg [ SRAM_ADDR_BITS-1 : 0 ]	rcfg_ot_rnd_finsub1 ;
reg [ SRAM_ADDR_BITS-1 : 0 ]	rcfg_ot_tgpfnsub1	;
reg [ SRAM_ADDR_BITS-1 : 0 ]	rcfg_ot_tcolfnsub1	;
reg [ SRAM_ADDR_BITS-1 : 0 ]	rcfg_ot_tchafnsub1	;
reg [ SRAM_ADDR_BITS-1 : 0 ]	rcfg_ot_sft_gp		;
reg [ SRAM_ADDR_BITS-1 : 0 ]	rcfg_ot_sft_colpra	;

always @(posedge clk ) begin
	if(reset)begin
		rcfg_ot_rnd_finsub1 <= 191	;
		rcfg_ot_tgpfnsub1	<= 1	;
		rcfg_ot_tcolfnsub1	<= 7	;
		rcfg_ot_tchafnsub1	<= 7	;
		rcfg_ot_sft_gp		<= 64	;
		rcfg_ot_sft_colpra	<= 8	;
	end
	else begin
		rcfg_ot_rnd_finsub1 <= cfg_ot_rnd_finsub1	;
		rcfg_ot_tgpfnsub1	<= cfg_ot_tgpfnsub1	;
		rcfg_ot_tcolfnsub1	<= cfg_ot_tcolfnsub1	;
		rcfg_ot_tchafnsub1	<= cfg_ot_tchafnsub1	;
		rcfg_ot_sft_gp		<= cfg_ot_sft_gp		;
		rcfg_ot_sft_colpra	<= cfg_ot_sft_colpra	;
	end
end

wire cen_otsr_0 ,cen_otsr_1 ; 
wire wen_otsr_0 ,wen_otsr_1 ;
wire [ SRAM_ADDR_BITS -1 : 0 ] addr_otsr_0 ,addr_otsr_1 ; 
wire [ SRAM_DATA_BITS -1 : 0 ] din_otsr_0 ,din_otsr_1 ;
wire [ SRAM_DATA_BITS -1 : 0 ] dout_otsr_0 ,dout_otsr_1 ;

// Row 1 SRAM signals
wire cen_otsr_r1_0 ,cen_otsr_r1_1 ; 
wire wen_otsr_r1_0 ,wen_otsr_r1_1 ;
wire [ SRAM_ADDR_BITS -1 : 0 ] addr_otsr_r1_0 ,addr_otsr_r1_1 ; 
wire [ SRAM_DATA_BITS -1 : 0 ] din_otsr_r1_0 ,din_otsr_r1_1 ;
wire [ SRAM_DATA_BITS -1 : 0 ] dout_otsr_r1_0 ,dout_otsr_r1_1 ;

wire osr_cen_otsr_0 ; 
// osr_wen_otsr_0 : ot_write's wen_otsr tap, unread -- left open
wire [ SRAM_ADDR_BITS -1 : 0 ] osr_addr_otsr_0 ; 
wire [ SRAM_DATA_BITS -1 : 0 ] osr_dout_otsr_0 ;
wire [ SRAM_DATA_BITS -1 : 0 ] osr_dout_otsr_r1 ;

wire osw_cen_otsr_0 ; 
wire osw_wen_otsr_0 ;
wire [ SRAM_ADDR_BITS -1 : 0 ] osw_addr_otsr_0 ; 
wire [ SRAM_DATA_BITS -1 : 0 ] osw_din_otsr_0 ;
wire [ SRAM_DATA_BITS -1 : 0 ] osw_din_otsr_r1 ;

localparam BUF_STATE_BITS = 3;
localparam IDLE 	= 3'd0;
localparam READY 	= 3'd1;
localparam WRING 	= 3'd2;
localparam WR_DONE 	= 3'd3;
localparam RDING 	= 3'd4;
localparam RD_DONE 	= 3'd5;

reg [BUF_STATE_BITS-1: 0 ] bf0_current_state ;
reg [BUF_STATE_BITS-1: 0 ] bf0_next_state ;
reg [BUF_STATE_BITS-1: 0 ] bf1_current_state ;
reg [BUF_STATE_BITS-1: 0 ] bf1_next_state ;

wire write_last ;
reg read_start ;
wire read_busy ;
wire read_done ;

//------- qtb and fifo signal --------
wire fifo_empty_n 	;
wire fifo_read 		;
wire [ TBITS-1 : 0 ] fifo_data64 ;
wire fifo_w_empty_n	;
wire fifo_w_read	;

// Row 1 FIFO signals
wire fifo_empty_n_r1 	;
wire fifo_read_r1 		;
wire [ TBITS-1 : 0 ] fifo_data64_r1 ;
wire fifo_w_empty_n_r1	;
wire fifo_w_read_r1	;

wire [ TBITS-1 : 0 ]	qtb_qresult		[0:PEBLKROW_NUM-1]	;
wire					qtb_qvalid		[0:PEBLKROW_NUM-1]	;
// qtb_64bitsout / qtb_validout : left over from the removed ot_qtbuf instance

wire [ TBITS-1 : 0 ]	qtb_qresult_r1	[0:PEBLKROW_NUM-1]	;
wire					qtb_qvalid_r1	[0:PEBLKROW_NUM-1]	;

wire atl_cen_otsr_0 , atl_wen_otsr_0 , atl_cen_otsr_1 , atl_wen_otsr_1 ;
wire atl_cen_otsr_r1_0 , atl_wen_otsr_r1_0 , atl_cen_otsr_r1_1 , atl_wen_otsr_r1_1 ;

`ifdef FPGA_SRAM_SETTING
	BRAM_OT otbf_0 ( .clka( clk ) ,.ena( atl_cen_otsr_0 )	,.wea( atl_wen_otsr_0 )	,.addra( addr_otsr_0 ),.dina( din_otsr_0 )	,.douta( dout_otsr_0 ) );
	BRAM_OT otbf_1 ( .clka( clk ) ,.ena( atl_cen_otsr_1 )	,.wea( atl_wen_otsr_1 )	,.addra( addr_otsr_1 ),.dina( din_otsr_1 )	,.douta( dout_otsr_1 ) );
	
    // Row 1 SRAM
    BRAM_OT otbf_r1_0 ( .clka( clk ) ,.ena( atl_cen_otsr_r1_0 )	,.wea( atl_wen_otsr_r1_0 )	,.addra( addr_otsr_r1_0 ),.dina( din_otsr_r1_0 )	,.douta( dout_otsr_r1_0 ) );
	BRAM_OT otbf_r1_1 ( .clka( clk ) ,.ena( atl_cen_otsr_r1_1 )	,.wea( atl_wen_otsr_r1_1 )	,.addra( addr_otsr_r1_1 ),.dina( din_otsr_r1_1 )	,.douta( dout_otsr_r1_1 ) );
`else 
	OT_SRAM otbf_0(.Q(	dout_otsr_0 ),	.CLK( clk ),.CEN( atl_cen_otsr_0 ),.WEN( atl_wen_otsr_0 ),.A( addr_otsr_0 ),.D( din_otsr_0 ),.EMA( 3'b0 ));
	OT_SRAM otbf_1(.Q(	dout_otsr_1 ),	.CLK( clk ),.CEN( atl_cen_otsr_1 ),.WEN( atl_wen_otsr_1 ),.A( addr_otsr_1 ),.D( din_otsr_1 ),.EMA( 3'b0 ));
    
    OT_SRAM otbf_r1_0(.Q(	dout_otsr_r1_0 ),	.CLK( clk ),.CEN( atl_cen_otsr_r1_0 ),.WEN( atl_wen_otsr_r1_0 ),.A( addr_otsr_r1_0 ),.D( din_otsr_r1_0 ),.EMA( 3'b0 ));
	OT_SRAM otbf_r1_1(.Q(	dout_otsr_r1_1 ),	.CLK( clk ),.CEN( atl_cen_otsr_r1_1 ),.WEN( atl_wen_otsr_r1_1 ),.A( addr_otsr_r1_1 ),.D( din_otsr_r1_1 ),.EMA( 3'b0 ));
`endif 

// Write module connected to BOTH FIFOs
ot_write #(
		.SRAM_DATA_BITS		( 	SRAM_DATA_BITS 			)
	,	.SRAM_ADDR_BITS		( 	SRAM_ADDR_BITS 			)
)ow000 
(
		.clk				(	clk						)
	,	.reset				(	reset					)
    // Row 0
	,	.data_in			(	fifo_data64				)
	,	.fifo_empty_n		(	fifo_w_empty_n			)
	,	.fifo_read 			(	fifo_w_read				)
    // Row 1
    ,	.data_in_r1			(	fifo_data64_r1			)
	,	.fifo_empty_n_r1	(	fifo_w_empty_n_r1		)
	,	.fifo_read_r1		(	fifo_w_read_r1			)

	,	.last				(	write_last				)
	,	.cen_otsr			(	osw_cen_otsr_0			)
	,	.wen_otsr			(	osw_wen_otsr_0			)
	,	.addr_otsr			(	osw_addr_otsr_0			)
    
	,	.data_for_sram		(	osw_din_otsr_0			)
    ,	.data_for_sram_r1	(	osw_din_otsr_r1			)
	
    ,	.cfg_ot_rnd_finsub1	(	rcfg_ot_rnd_finsub1		)
);

// Note: ot_read (v2) already implements the Row0->Row1 serialize FSM (AD_READ_R0 -> AD_WAIT_SW ->
// AD_READ_R1 -> AD_RST_CNT) so both rows drain through the single 64-bit AXI stream correctly.
// This is expected/by design: total AXI output bandwidth stays 1x (bounded by the external
// S2MM width), only the internal compute (ifsram read + PE) is 2x -- output naturally serializes.
ot_read #(
		.SRAM_DATA_BITS		( SRAM_DATA_BITS 			)
	,	.SRAM_ADDR_BITS		( SRAM_ADDR_BITS 			)
)
or111 (
		.clk				(	clk						)
	,	.reset				(	reset					)
	,	.start				(	read_start				)
	,	.busy				(	read_busy				)
	,	.done				(	read_done				)
	,	.din_s2mm_tready	(	din_s2mm_tready			)
	,	.fifo_full_n		(	fifo_full_n				)
	,	.fifo_write			(	fifo_write				)
	,	.fifo_last			(	fifo_last				)
	,	.fifo_data			(	fifo_data				)

	,	.data_from_sram		(	osr_dout_otsr_0			)
	,	.data_from_sram_r1	(	osr_dout_otsr_r1		)
	,	.addr_otsr			(	osr_addr_otsr_0			)
	,	.cen_otsr			(	osr_cen_otsr_0			)
	,	.wen_otsr			(							)

	,	.cfg_ot_tgpfnsub1	(	rcfg_ot_tgpfnsub1		)
	,	.cfg_ot_tcolfnsub1	(	rcfg_ot_tcolfnsub1		)
	,	.cfg_ot_tchafnsub1	(	rcfg_ot_tchafnsub1		)
	,	.cfg_ot_sft_gp		(	rcfg_ot_sft_gp			)
	,	.cfg_ot_sft_colpra	(	rcfg_ot_sft_colpra		)
);

ot_fifo  qtbfifo(
		.clk			(	clk				 )
	,	.reset			(	reset			 )
	,	.valid_in 		(	qtb_qvalid[0]	 )
	,	.data_in		(	qtb_qresult[0]	 )   
	,	.empty_n		(	fifo_empty_n	 )
	,	.read			(	fifo_read		 )
	,	.data_out		(	fifo_data64		 )
);

ot_fifo  qtbfifo_r1(
		.clk			(	clk				 )
	,	.reset			(	reset			 )
	,	.valid_in 		(	qtb_qvalid_r1[0] )
	,	.data_in		(	qtb_qresult_r1[0])   
	,	.empty_n		(	fifo_empty_n_r1	 )
	,	.read			(	fifo_read_r1	 )
	,	.data_out		(	fifo_data64_r1	 )
);

genvar gy ;
generate
	for (gy = 0; gy<PEBLKROW_NUM; gy=gy+1) begin	:assq_result
		assign	qtb_qresult[gy] = data_din  [ (TBITS*(PEBLKROW_NUM-gy)-1) -:	TBITS ] ;
		assign	qtb_qvalid [gy] = valid_din [ (PEBLKROW_NUM-1 -gy)	      -:	1	  ] ;

        assign	qtb_qresult_r1[gy] = data_din_r1  [ (TBITS*(PEBLKROW_NUM-gy)-1) -:	TBITS ] ;
		assign	qtb_qvalid_r1 [gy] = valid_din_r1 [ (PEBLKROW_NUM-1 -gy)	      -:	1	  ] ;
	end
endgenerate

`ifdef FPGA_SRAM_SETTING
	assign atl_cen_otsr_0 	= ~cen_otsr_0;
	assign atl_wen_otsr_0 	= ~wen_otsr_0;
	assign atl_cen_otsr_1 	= ~cen_otsr_1;
	assign atl_wen_otsr_1 	= ~wen_otsr_1;
    
    assign atl_cen_otsr_r1_0 	= ~cen_otsr_r1_0;
	assign atl_wen_otsr_r1_0 	= ~wen_otsr_r1_0;
	assign atl_cen_otsr_r1_1 	= ~cen_otsr_r1_1;
	assign atl_wen_otsr_r1_1 	= ~wen_otsr_r1_1;
`else 
	assign atl_cen_otsr_0 	= cen_otsr_0	;
	assign atl_wen_otsr_0 	= wen_otsr_0	;
	assign atl_cen_otsr_1 	= cen_otsr_1	;
	assign atl_wen_otsr_1 	= wen_otsr_1	;

    assign atl_cen_otsr_r1_0 	= cen_otsr_r1_0	;
	assign atl_wen_otsr_r1_0 	= wen_otsr_r1_0	;
	assign atl_cen_otsr_r1_1 	= cen_otsr_r1_1	;
	assign atl_wen_otsr_r1_1 	= wen_otsr_r1_1	;
`endif 

// Ping pong assign logic for Row 0
assign cen_otsr_0 	= ( bf0_current_state == WRING )? osw_cen_otsr_0 : 
						( bf0_current_state == RDING )? osr_cen_otsr_0 : 1'd1 	;
assign wen_otsr_0 	= ( bf0_current_state == WRING )? osw_wen_otsr_0 :  1'd1 	;
assign din_otsr_0 	= osw_din_otsr_0	;
assign addr_otsr_0	= ( bf0_current_state == WRING )? osw_addr_otsr_0 : 
						( bf0_current_state == RDING )? osr_addr_otsr_0 : 10'd0 	;

assign cen_otsr_1 	= ( bf1_current_state == WRING )? osw_cen_otsr_0 : 
						( bf1_current_state == RDING )? osr_cen_otsr_0 : 1'd1 	;
assign wen_otsr_1 	= ( bf1_current_state == WRING )? osw_wen_otsr_0 :  1'd1 	;
assign din_otsr_1 	= osw_din_otsr_0	;
assign addr_otsr_1	= ( bf1_current_state == WRING )? osw_addr_otsr_0 : 
						( bf1_current_state == RDING )? osr_addr_otsr_0 : 10'd0 	;

// Ping pong assign logic for Row 1 (Mirroring Row 0's FSM)
assign cen_otsr_r1_0 	= cen_otsr_0;
assign wen_otsr_r1_0 	= wen_otsr_0;
assign din_otsr_r1_0 	= osw_din_otsr_r1;
assign addr_otsr_r1_0	= addr_otsr_0;

assign cen_otsr_r1_1 	= cen_otsr_1;
assign wen_otsr_r1_1 	= wen_otsr_1;
assign din_otsr_r1_1 	= osw_din_otsr_r1;
assign addr_otsr_r1_1	= addr_otsr_1;

assign osr_dout_otsr_0 = ( bf0_current_state == RDING )? dout_otsr_0 :
							( bf1_current_state == RDING )? dout_otsr_1 :	64'd0 ;
							
assign osr_dout_otsr_r1 = ( bf0_current_state == RDING )? dout_otsr_r1_0 :
							( bf1_current_state == RDING )? dout_otsr_r1_1 : 64'd0 ;

// FIFO empty / read connections
assign fifo_w_empty_n = (  (bf0_current_state == WRING ) | ( bf1_current_state == WRING ) ) ? fifo_empty_n : 1'd0 ;
assign fifo_read = (  (bf0_current_state == WRING ) | ( bf1_current_state == WRING ) ) ? fifo_w_read : 1'd0 ;

assign fifo_w_empty_n_r1 = (  (bf0_current_state == WRING ) | ( bf1_current_state == WRING ) ) ? fifo_empty_n_r1 : 1'd0 ;
assign fifo_read_r1 = (  (bf0_current_state == WRING ) | ( bf1_current_state == WRING ) ) ? fifo_w_read_r1 : 1'd0 ;


//========    Buffer read/write control    ========
always @(posedge clk ) begin
	if(reset )begin
		bf0_current_state <= WRING ;
		bf1_current_state <= IDLE ;
	end
	else begin
		bf0_current_state <= bf0_next_state ;
		bf1_current_state <= bf1_next_state ;
	end
end

always @(*) begin
	case (bf0_current_state)
		IDLE 	:	bf0_next_state = ( bf1_current_state == IDLE ) ? WRING : IDLE ;
		WRING 	:	bf0_next_state = (		!write_last		) ? 			WRING	:
										( bf1_current_state == RD_DONE ) ?	READY	: WR_DONE	;
		READY	:	bf0_next_state = RDING ;
		WR_DONE	:	bf0_next_state = ( bf1_current_state==RDING ) ? 		(read_done)? READY : WR_DONE 	: 
										( bf1_current_state==RD_DONE ) ? READY : 
											( (bf1_current_state==IDLE) | (bf1_current_state==WRING) ) ? READY : WR_DONE ;
		RDING 	:	bf0_next_state = ( read_done ) ? RD_DONE : RDING ;		
		RD_DONE :	bf0_next_state = ( bf1_current_state== WRING ) ? RD_DONE : WRING ;
		default: bf0_next_state = IDLE ;
	endcase
end

always @(*) begin
	case (bf1_current_state)
		IDLE 	:	bf1_next_state = ( bf0_current_state == IDLE ) ? IDLE : 
										( (bf0_current_state == WRING) & write_last ) ? WRING : IDLE ;
		WRING 	:	bf1_next_state = (		!write_last		) ? WRING	:
										( bf0_current_state == RD_DONE ) ?	READY	: WR_DONE	;
		READY	:	bf1_next_state = RDING ;
		WR_DONE	:	bf1_next_state = ( bf0_current_state==RDING ) ? 		(read_done)? READY : WR_DONE 	: 
										( bf0_current_state==RD_DONE ) ? READY : 
											( (bf0_current_state==IDLE) | (bf0_current_state==WRING) ) ? READY : WR_DONE ;
		RDING 	:	bf1_next_state = ( read_done ) ? RD_DONE : RDING ;		
		RD_DONE :	bf1_next_state = ( bf0_current_state== WRING ) ? RD_DONE : WRING ;
		default: bf1_next_state = IDLE ;
	endcase
end

always @(posedge clk ) begin
	if( reset )begin
		read_start <= 1'd0 ;
	end
	else begin
		if( (bf0_current_state==RDING ) | (bf1_current_state==RDING ))begin
			if( !read_busy )begin
				read_start <= 1'd1 ;
			end
			else begin
				read_start <= 1'd0 ;
			end
		end
		else begin
			read_start <= 1'd0 ;
		end
	end
end

always @(*) begin
	if ( (bf0_current_state==WRING )  ) begin
		if ( bf1_current_state == RDING ) begin
			ot_ready = 1'd0 ;
		end
		else begin
			ot_ready = 1'd1 ;
		end
	end
	else if (bf1_current_state==WRING ) begin
		if ( bf0_current_state == RDING ) begin
			ot_ready = 1'd0 ;
		end
		else begin
			ot_ready = 1'd1 ;
		end
	end
	else begin
		ot_ready = 1'd0 ;
	end
end

endmodule