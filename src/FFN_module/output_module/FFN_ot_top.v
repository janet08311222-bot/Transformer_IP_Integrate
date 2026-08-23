// ============================================================================
// Designer : Chao_Ping Liu
// Create   : 2025.07.06
// Ver      : 1.0
// Func     : output top module
// ============================================================================
//      Instance Name:              OT_SRAM
//      Words:                      512
//      Bits:                       64
//      Mux:                        8
//      Drive:                      6
//      Write Mask:                 Off
//      Extra Margin Adjustment:    On
//      Accelerated Retention Test: Off
//      Redundant Rows:             0
//      Redundant Columns:          0
//      Test Muxes                  Off
//-----------------------------------------------------------------------------
`ifndef ASIC
`define FPGA_SRAM_SETTING   // FPGA default; ASIC build passes +define+ASIC -> ASIC SRAM path
`endif

module FFN_ot_top #(
	parameter TBITS = 64 
	,	TBYTE = 8
	,	PEBLKROW_NUM = 1
	,	SRAM_DATA_BITS = 64
	,	SRAM_ADDR_BITS = 9
)(
        clk
    ,   reset

    ,   FFN_done

    ,	din_s2mm_tready
	,	fifo_full_n
	,	fifo_write
	,	fifo_last
	,	fifo_data

	,	ot_ready

	,	valid_din
	,	data_din

	,	cfg_ker_tile_readnums_sub1

	,	cfg_ot_rnd_finsub1
	,	cfg_ot_tgpfnsub1	
	,	cfg_ot_tcolfnsub1	
	,	cfg_ot_tchafnsub1	
	,	cfg_ot_sft_gp
	,	cfg_ot_sft_colpra
	,	cfg_ot_sft_col
) ;

	//==============================================================================    
	//========    I/O Port declare    ==============================================
	//==============================================================================
	
	input  wire	clk			;
	input  wire reset		;

	output wire	FFN_done	;	// pulses when the last output tile has been streamed out

	input  wire 						din_s2mm_tready	;
	input  wire 						fifo_full_n		;
	output wire 						fifo_write		;
	output wire 						fifo_last		;
	output wire	[SRAM_DATA_BITS-1:0]	fifo_data		;

	output wire	ot_ready	;

	input  wire [PEBLKROW_NUM-1:0]			valid_din		;
	input  wire [PEBLKROW_NUM*TBITS-1:0]	data_din		;
	
	//----    config in    -----
	input wire	[1:0]						cfg_ker_tile_readnums_sub1	;

	input wire	[ SRAM_ADDR_BITS-1 : 0 ]	cfg_ot_rnd_finsub1	;
	input wire	[ SRAM_ADDR_BITS-1 : 0 ]	cfg_ot_tgpfnsub1	;
	input wire	[ SRAM_ADDR_BITS-1 : 0 ]	cfg_ot_tcolfnsub1	;
	input wire	[ SRAM_ADDR_BITS-1 : 0 ]	cfg_ot_tchafnsub1	;
	input wire	[ SRAM_ADDR_BITS-1 : 0 ]	cfg_ot_sft_gp		;
	input wire	[ SRAM_ADDR_BITS-1 : 0 ]	cfg_ot_sft_colpra	;
	input wire	[ SRAM_ADDR_BITS-1 : 0 ]	cfg_ot_sft_col		;

	//==============================================================================

	//---- FSM Declare ----
	reg	[1:0]	ot_curr_state	;
	reg [1:0]	ot_next_state	;
	localparam	OT_IDLE		= 2'd0 ;
	localparam	OT_WRITE	= 2'd1 ;
	localparam	OT_READ		= 2'd2 ;
	localparam	OT_DONE		= 2'd3 ;

	//---- ot fifo
	wire						fifo_empty_n	;
	wire						fifo_read		;
	wire [SRAM_DATA_BITS-1:0]	fifo_data_out	;


	//---- control signal ---
	wire	ot_write_busy 	;
	wire	ot_write_last	;

	reg		read_start		;
	wire 	read_busy		;
	wire	read_done		;
	
	//---- declare FFN_ot_top signal ----
	wire cen_ot_sram ;
	wire wen_ot_sram ;
	wire [SRAM_ADDR_BITS-1:0] addr_ot_sram ;
	wire [SRAM_DATA_BITS-1:0] din_ot_sram  ;
	wire [SRAM_DATA_BITS-1:0] dout_ot_sram ;

	//---- declare FFN_ot_top write signal ----
	wire write_cen_ot_sram ;
	wire write_wen_ot_sram ;
	wire [SRAM_ADDR_BITS-1:0] write_addr_ot_sram ;
	wire [SRAM_DATA_BITS-1:0] write_din_ot_sram ;

	//---- declare FFN_ot_top read signal ----
	wire read_cen_ot_sram ;
	wire [SRAM_ADDR_BITS-1:0] read_addr_ot_sram ;

	//---- actually cen wen signal declare ----
	wire alt_cen_ot_sram ;
	wire alt_wen_ot_sram ;

	always @(posedge clk) begin
		if(reset)
			ot_curr_state <= OT_IDLE ;
		else
			ot_curr_state <= ot_next_state ;
	end
	always @(*) begin
		case(ot_curr_state)
			OT_IDLE		: ot_next_state = OT_WRITE ;
			OT_WRITE	: ot_next_state = (ot_write_last) ? OT_READ : OT_WRITE ;
			OT_READ		: ot_next_state = (read_done) ? OT_DONE : OT_READ ;
			OT_DONE		: ot_next_state = OT_IDLE ;
			default		: ot_next_state = OT_IDLE ;
		endcase
	end

	//---- FFN_ot_top assign cen ----
	assign cen_ot_sram = (ot_write_busy) ? write_cen_ot_sram : read_cen_ot_sram ;
	//---- FFN_ot_top assign wen ----
	assign wen_ot_sram = (ot_write_busy) ? write_wen_ot_sram : 1'd1 ;
	//---- FFN_ot_top assign addr ----
	assign addr_ot_sram = (ot_write_busy) ? write_addr_ot_sram : read_addr_ot_sram ;
	//---- FFN_ot_top assign din ----
	assign din_ot_sram = (ot_write_busy) ? write_din_ot_sram : 'd0 ;

	 //==============================================================================
    //========    SRAM instance and assignment    ========
    //==============================================================================
    `ifdef FPGA_SRAM_SETTING
        assign alt_cen_ot_sram = ~cen_ot_sram;
        assign alt_wen_ot_sram = ~wen_ot_sram;

        BRAM_OT ot_0(.clka(clk), .ena(alt_cen_ot_sram), .wea(alt_wen_ot_sram), .addra(addr_ot_sram), .dina(din_ot_sram), .douta(dout_ot_sram));
    `else
        assign alt_cen_ot_sram = cen_ot_sram;
        assign alt_wen_ot_sram = wen_ot_sram;

        OT_SRAM ot_0(.Q(dout_ot_sram), .CLK(clk), .CEN(alt_cen_ot_sram), .WEN(alt_wen_ot_sram), .A(addr_ot_sram), .D(din_ot_sram), .EMA(3'b0));
    `endif

	FFN_ot_fifo ot_fifo_inst (
			.clk			( clk				)
		,	.reset			( reset				)

		,	.valid_in		( valid_din			)
		,	.data_in		( data_din			)

		,	.empty_n		( fifo_empty_n		)
		,	.read			( fifo_read			)
		,	.data_out		( fifo_data_out		)
	) ;

	FFN_otsram_w #(
			.OT_SRAM_WORDS_BITS	( SRAM_DATA_BITS )
		,   .OT_SRAM_ADDR_BITS	( SRAM_ADDR_BITS )
	) ot_w_inst (
		    .clk	(	clk		)
		,   .reset	(	reset	)

		,   .ot_write_data_din		(	fifo_data_out	)
		,   .ot_write_empty_n_din	(	fifo_empty_n	)
		,   .ot_write_read_dout		(	fifo_read		)
		,	.ot_write_last			(	ot_write_last	)

		,   .cen_ot_sram	(	write_cen_ot_sram	)
		,   .wen_ot_sram	(	write_wen_ot_sram	)
		,   .addr_ot_sram	(	write_addr_ot_sram	)
		,   .din_ot_sram	(	write_din_ot_sram	)
		
		,   .cfg_ot_rnd_finsub1	(	cfg_ot_rnd_finsub1	)
	) ;

	assign ot_write_busy = (ot_curr_state == OT_WRITE) ? 1'b1 : 1'b0 ;

	FFN_otsram_r #(
			.SRAM_DATA_BITS	( SRAM_DATA_BITS )
		,	.SRAM_ADDR_BITS	( SRAM_ADDR_BITS )
	) ot_r_inst (
			.clk	(	clk		)
		,	.reset	(	reset	)

		,	.start	(	read_start	)
		,	.busy	(	read_busy	)
		,	.done	(	read_done	)

		,	.FFN_done	(	FFN_done	)

		,	.din_s2mm_tready	(	din_s2mm_tready	)
		,	.fifo_full_n		(	fifo_full_n		)
		,	.fifo_write			(	fifo_write		)
		,	.fifo_last			(	fifo_last		)
		,	.fifo_data			(	fifo_data		)

		,	.data_from_sram		(	dout_ot_sram		)
		,	.addr_otsr			(	read_addr_ot_sram	)
		,	.cen_otsr			(	read_cen_ot_sram	)

		,	.cfg_ker_tile_readnums_sub1	(	cfg_ker_tile_readnums_sub1	)

		,	.cfg_ot_tgpfnsub1	(	cfg_ot_tgpfnsub1	)
		,	.cfg_ot_tcolfnsub1	(	cfg_ot_tcolfnsub1	)
		,	.cfg_ot_tchafnsub1	(	cfg_ot_tchafnsub1	)
		,	.cfg_ot_sft_gp		(	cfg_ot_sft_gp		)
		,	.cfg_ot_sft_colpra	(	cfg_ot_sft_colpra	)
		,	.cfg_ot_sft_col		(	cfg_ot_sft_col		)
	) ;

	always @(posedge clk) begin
		if(reset)
			read_start <= 0 ;
		else if(ot_curr_state == OT_READ)
			read_start <= ~read_busy & ~read_done ;
	end

	assign ot_ready = (ot_curr_state != OT_READ) ? 1'd1 : 1'd0 ;

endmodule