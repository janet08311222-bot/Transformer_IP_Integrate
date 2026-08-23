// ============================================================================
// Designer : Chao_Ping Liu
// Create   : 2025.07.01
// Ver      : 1.0
// Func     : input top module
// ============================================================================
//      Instance Name:              IF_SRAM
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

module FFN_if_top #(
	parameter IF_SRAM_WORDS_BITS = 64 
	,	IF_SRAM_ADDR_BITS = 9
)(
		clk
	,	reset		

	,	if_write_data_din				
	,	if_write_empty_n_din			
	,	if_write_read_dout			

	,	if_write_start
	,	if_write_busy
	,	if_write_done
	,	if_write_en		
							
	,	if_read_start
	,	if_read_busy
	,	if_read_done
 
	,	dout_if_sram_0
    ,   if_read_valid

    ,   cfg_if_totalsize_sub1

);

    // ============================= I/O port Declare ===============================
	input  wire clk ;
	input  wire reset ;

    input  wire [IF_SRAM_WORDS_BITS-1:0] if_write_data_din	    ;
	input  wire			                 if_write_empty_n_din   ;
	output wire			                 if_write_read_dout	    ;

	input  wire 		    if_write_start  ;
	output wire 		    if_write_busy   ;
    output wire 		    if_write_done   ;
	output wire 		    if_write_en     ;

	input  wire 		    if_read_start   ;
    output wire 		    if_read_done    ;
	output wire 		    if_read_busy    ;

    output wire [IF_SRAM_WORDS_BITS-1:0] dout_if_sram_0      ; 
    output wire            if_read_valid   ;

    input  wire [IF_SRAM_ADDR_BITS-1:0]  cfg_if_totalsize_sub1   ;

    //---- declare FFN_if_top signal ------ 
    wire cen_if_sram_0 ;
    wire wen_if_sram_0 ;
    wire [IF_SRAM_ADDR_BITS-1:0] addr_if_sram_0 ;
    wire [IF_SRAM_WORDS_BITS-1:0] din_if_sram_0 ;

    //---- declare FFN_if_top write signal ----
    wire write_cen_if_sram_0 ;
    wire write_wen_if_sram_0 ;
    wire [IF_SRAM_ADDR_BITS-1:0] write_addr_if_sram_0 ;
    wire [IF_SRAM_WORDS_BITS-1:0] write_din_if_sram_0  ;

    //---- declare FFN_if_top read signal ----
    wire read_cen_if_sram_0 ;
    wire [IF_SRAM_ADDR_BITS-1:0] read_addr_if_sram_0 ;

    //----    actually cen wen signal declare    -----
	// for actually connection between FPGA and CBDK
	wire atl_cen_if_0 ;
	wire atl_wen_if_0 ;

    //---- FFN_if_top assign cen ------ 
    assign cen_if_sram_0 = ( if_write_busy ) ? write_cen_if_sram_0 : read_cen_if_sram_0 ;
    //---- FFN_if_top assign wen ------ 
    assign wen_if_sram_0 = ( if_write_busy ) ? write_wen_if_sram_0 : 1'd1 ;
    //---- FFN_if_top assign addr ------ 
    assign addr_if_sram_0 =  ( if_write_busy ) ? write_addr_if_sram_0 : read_addr_if_sram_0 ;
    //---- FFN_if_top assign din ------ 
    assign din_if_sram_0 =  ( if_write_busy ) ? write_din_if_sram_0 : 64'd0 ;

    //==============================================================================
    //========    SRAM instance and assignment    ========
    //==============================================================================

    `ifdef FPGA_SRAM_SETTING
        assign atl_cen_if_0 = ~cen_if_sram_0	;
        assign atl_wen_if_0 = ~wen_if_sram_0	;

        FFN_BRAM_IF if_0 (.clka( clk ), .ena( atl_cen_if_0 ), .wea( atl_wen_if_0 ), .addra( addr_if_sram_0 ), .dina( din_if_sram_0 ), .douta( dout_if_sram_0 ));
    `else 
        assign atl_cen_if_0 = cen_if_sram_0	;
        assign atl_wen_if_0 = wen_if_sram_0	;

	    FFN_IF_SRAM if_0(.Q( dout_if_sram_0 ), .CLK( clk ), .CEN( atl_cen_if_0 ), .WEN( atl_wen_if_0 ), .A( addr_if_sram_0 ), .D( din_if_sram_0 ), .EMA( 3'b0 ));
    `endif 

    //-------------------------------------------------------------------
    //----------------		input sram write module		-----------------
    //-------------------------------------------------------------------
    FFN_ifsram_w #(
        .IF_SRAM_WORDS_BITS ( IF_SRAM_WORDS_BITS    )
    ,   .IF_SRAM_ADDR_BITS  ( IF_SRAM_ADDR_BITS     )
    )ifsram_write(
        .clk    (   clk     )
    ,   .reset  (   reset   )

    ,   .if_write_data_din      (   if_write_data_din       )
	,   .if_write_empty_n_din   (   if_write_empty_n_din    )
	,   .if_write_read_dout     (   if_write_read_dout      )

	,   .cen_if_sram_0  (   write_cen_if_sram_0     )
    ,   .wen_if_sram_0  (   write_wen_if_sram_0     )
    ,   .addr_if_sram_0 (   write_addr_if_sram_0    )
    ,   .din_if_sram_0  (   write_din_if_sram_0     )

	,   .if_write_start (   if_write_start  )
	,   .if_write_busy  (   if_write_busy   )
	,   .if_write_done  (   if_write_done   )
	,   .if_write_en    (   if_write_en     )

	,   .cfg_if_totalsize_sub1  (   cfg_if_totalsize_sub1   )
    );

    //-------------------------------------------------------------------
    //----------------		input sram read module		-----------------
    //-------------------------------------------------------------------
    FFN_ifsram_r #(
        .IF_SRAM_WORDS_BITS ( IF_SRAM_WORDS_BITS    )
    ,   .IF_SRAM_ADDR_BITS  ( IF_SRAM_ADDR_BITS     )
    )ifsram_read(
        .clk    (   clk     )
    ,   .reset  (   reset   )

    ,   .cen_if_sram_0  (   read_cen_if_sram_0     )
    ,   .addr_if_sram_0 (   read_addr_if_sram_0    )

    ,   .if_read_start  (   if_read_start   )
    ,   .if_read_busy   (   if_read_busy    )
    ,   .if_read_done   (   if_read_done    )

    ,   .if_read_valid  (   if_read_valid   )

    ,   .cfg_if_totalsize_sub1  (   cfg_if_totalsize_sub1   )
    );

endmodule