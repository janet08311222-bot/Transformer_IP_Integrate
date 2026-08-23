// ============================================================================
// Designer : Chao_Ping Liu
// Create   : 2025.07.03
// Ver      : 1.0
// Func     : bias top module
// ============================================================================
//      Instance Name:              BIAS_SRAM
//      Words:                      512
//      Bits:                       32
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

module FFN_bias_top #(
	parameter TBITS = 64
	,	TBYTE = 8
	,	BIAS_SRAM_ADDR_BITS = 9
	,	BIAS_SRAM_DATA_WIDTH = 32
	,	NUM_BANK = 8
)(
		clk
	,	reset

	,	bias_write_data_din		
	,	bias_write_empty_n_din	
	,	bias_write_read_dout	
		
	,	bias_write_start
	,	bias_write_busy 		
	,	bias_write_done 		
	,	bias_write_en 	

	,	bias_read_start
	,	bias_read_busy 		
	,	bias_read_done 		

	,	dout_bias_flat

    ,	cfg_bias_once_load_size_sub1
    ,   cfg_bias_readnums
	// ,	cfg_cal_type		
	// ,	cfg_d_model			
	// ,	cfg_seq_size
	// ,	cfg_head			
	// ,	cfg_length			
	// ,	cfg_max_length

);

    // ============================= I/O port Declare ===============================
    input  wire clk     ;
    input  wire reset   ;

    input  wire [TBITS-1:0] bias_write_data_din     ;
    input  wire             bias_write_empty_n_din  ;
    output wire             bias_write_read_dout    ;

    input  wire             bias_write_start     ;
    output wire             bias_write_busy      ;
    output wire             bias_write_done      ;
    output wire             bias_write_en        ;

    input  wire             bias_read_start     ;
    output wire             bias_read_busy      ;
    output wire             bias_read_done      ;

    output wire [NUM_BANK*BIAS_SRAM_DATA_WIDTH-1:0] dout_bias_flat ;

    input  wire [BIAS_SRAM_ADDR_BITS-1:0] cfg_bias_once_load_size_sub1 ;
    input  wire [2:0] cfg_bias_readnums ; // the number of one bias should be read in once computation

    //---- declare FFN_bias_top signal ------
    wire cen_bias_sram ;
    wire wen_bias_sram ;
    wire [BIAS_SRAM_ADDR_BITS-1:0] addr_bias_sram ;
    wire [BIAS_SRAM_DATA_WIDTH-1:0] din_bias_sram ;
    wire [BIAS_SRAM_DATA_WIDTH-1:0] dout_bias_sram ;

    //---- declare FFN_bias_top write signal ----
    wire write_cen_bias_sram ;
    wire write_wen_bias_sram ;
    wire [BIAS_SRAM_ADDR_BITS-1:0] write_addr_bias_sram ;
    wire [BIAS_SRAM_DATA_WIDTH-1:0] write_din_bias_sram ;

    //---- declare FFN_bias_top read signal ----
    wire read_cen_bias_sram ;
    wire [BIAS_SRAM_ADDR_BITS-1:0] read_addr_bias_sram ;

    //---- actually cen wen signal declare ----
    wire alt_cen_bias_sram ;
    wire alt_wen_bias_sram ;

    //---- FFN_bias_top assign cen ----
    assign cen_bias_sram = (bias_write_busy) ? write_cen_bias_sram : read_cen_bias_sram;
    //---- FFN_bias_top assign wen ----
    assign wen_bias_sram = (bias_write_busy) ? write_wen_bias_sram : 1'd1;
    //---- FFN_bias_top assign addr ----
    assign addr_bias_sram = (bias_write_busy) ? write_addr_bias_sram : read_addr_bias_sram;
    //---- FFN_bias_top assign din ----
    assign din_bias_sram = (bias_write_busy) ? write_din_bias_sram : 32'd0;

    //==============================================================================
    //========    SRAM instance and assignment    ========
    //==============================================================================
    `ifdef FPGA_SRAM_SETTING
        assign alt_cen_bias_sram = ~cen_bias_sram;
        assign alt_wen_bias_sram = ~wen_bias_sram;

        FFN_BRAM_BIAS bias_0(.clka(clk), .ena(alt_cen_bias_sram), .wea(alt_wen_bias_sram), .addra(addr_bias_sram), .dina(din_bias_sram), .douta(dout_bias_sram));
    `else
        assign alt_cen_bias_sram = cen_bias_sram;
        assign alt_wen_bias_sram = wen_bias_sram;

        FFN_BIAS_SRAM bias_0(.Q(dout_bias_sram), .CLK(clk), .CEN(alt_cen_bias_sram), .WEN(alt_wen_bias_sram), .A(addr_bias_sram), .D(din_bias_sram), .EMA(3'b0));
    `endif

    //-------------------------------------------------------------------
    //----------------		bias sram write module		-----------------
    //-------------------------------------------------------------------
    FFN_biassram_w #(
            .TBITS  (   TBITS    )
        ,   .BIAS_SRAM_ADDR_BITS    (   BIAS_SRAM_ADDR_BITS     )
        ,   .BIAS_SRAM_DATA_WIDTH   (   BIAS_SRAM_DATA_WIDTH    )
    ) bias_w_inst (
            .clk    (   clk    )
        ,   .reset  (   reset  )

        ,   .bias_write_data_din    (   bias_write_data_din    )
        ,   .bias_write_empty_n_din (   bias_write_empty_n_din )
        ,   .bias_write_read_dout   (   bias_write_read_dout   )

        ,   .bias_write_start        (   bias_write_start        )
        ,   .bias_write_busy         (   bias_write_busy         )
        ,   .bias_write_done         (   bias_write_done         )
        ,   .bias_write_en           (   bias_write_en           )

        ,   .cen_bias_sram           (   write_cen_bias_sram     )
        ,   .wen_bias_sram           (   write_wen_bias_sram     )
        ,   .addr_bias_sram          (   write_addr_bias_sram    )
        ,   .din_bias_sram           (   write_din_bias_sram     )

        ,   .cfg_bias_once_load_size_sub1     (   cfg_bias_once_load_size_sub1     )
    );

    //-------------------------------------------------------------------
    //----------------		bias sram read module		-----------------
    //-------------------------------------------------------------------
    FFN_biassram_r #(
            .BIAS_SRAM_ADDR_BITS    (   BIAS_SRAM_ADDR_BITS     )
        ,   .BIAS_SRAM_WORDS_BITS   (   BIAS_SRAM_DATA_WIDTH    )
        ,   .NUM_BANK               (   NUM_BANK                )
    ) bias_r_inst (
            .clk    (   clk    )
        ,   .reset  (   reset  )

        ,   .dout_bias_sram          (   dout_bias_sram          )

        ,   .dout_bias_flat          (   dout_bias_flat          )

        ,   .cen_bias_sram           (   read_cen_bias_sram      )
        ,   .addr_bias_sram          (   read_addr_bias_sram     )

        ,   .bias_read_start         (   bias_read_start         )
        ,   .bias_read_busy          (   bias_read_busy          )
        ,   .bias_read_done          (   bias_read_done          )

        ,   .cfg_bias_readnums       ( cfg_bias_readnums       )
    );

endmodule