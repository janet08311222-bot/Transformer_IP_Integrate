// ============================================================================
// Designer : Chao_Ping Liu
// Create   : 2025.07.03
// Ver      : 1.0
// Func     : kernel top module
// ============================================================================
//      Instance Name:              KER_SRAM
//      Words:                      512
//      Bits:                       64
//      Mux:                        4
//      Drive:                      6
//      Write Mask:                 Off
//      Extra Margin Adjustment:    On
//      Accelerated Retention Test: Off
//      Redundant Rows:             0
//      Redundant Columns:          0
//      Test Muxes                  Off
//-----------------------------------------------------------------------------
 `define FPGA_SRAM_SETTING

module FFN_ker_top #(
    parameter TBITS = 64
    ,   TBYTE = 8
    ,   KER_SRAM_ADDR_BITS = 9
    ,   KER_SRAM_WORDS_BITS = 64
)(
        clk
    ,   reset

    ,   ker_write_data_din
    ,   ker_write_empty_n_din
    ,   ker_write_read_dout

    ,   mast_curr_state

    ,   ker_write_start
    ,   ker_write_busy
    ,   ker_write_done
    ,   ker_write_en
    ,   ker_write_last

    ,   ker_read_start
    ,   ker_read_busy
    ,   ker_read_done
    ,   ker_read_tile_done

    ,   dout_ker_sram_0,  dout_ker_sram_1,  dout_ker_sram_2,  dout_ker_sram_3,  dout_ker_sram_4,  dout_ker_sram_5,  dout_ker_sram_6,  dout_ker_sram_7
	,	ker_read_valid_0, ker_read_valid_1, ker_read_valid_2, ker_read_valid_3, ker_read_valid_4, ker_read_valid_5, ker_read_valid_6, ker_read_valid_7
	,	ker_read_final_0, ker_read_final_1, ker_read_final_2, ker_read_final_3, ker_read_final_4, ker_read_final_5, ker_read_final_6, ker_read_final_7

    ,   cfg_ker_length_sub1
    ,   cfg_ker_readnums
    ,   cfg_ker_tile_readnums_sub1
    ,   cfg_ker_tile_size_sub1
);

    //---- master FSM parameter ----
	localparam MAST_FSM_BITS 	= 3;
	localparam M_IDLE 	= 3'd0;
	localparam M_FSLD	= 3'd1;
	localparam M_BASE 	= 3'd2;
	localparam M_DONE 	= 3'd3;

    // ============================= I/O port Declare ===============================
    input  wire clk ;
    input  wire reset ;

    input  wire [TBITS-1:0] ker_write_data_din     ;
    input  wire             ker_write_empty_n_din  ;
    output wire             ker_write_read_dout    ;

    input wire [MAST_FSM_BITS-1:0] mast_curr_state ;

    input wire              ker_write_start        ;
    output wire             ker_write_busy         ;
    output wire             ker_write_done         ;
    output wire             ker_write_en           ;
    output wire             ker_write_last         ;

    input wire              ker_read_start         ;
    output wire             ker_read_busy          ;
    output wire             ker_read_done          ;
    output wire             ker_read_tile_done     ;

    output wire [KER_SRAM_WORDS_BITS-1:0] dout_ker_sram_0,  dout_ker_sram_1,  dout_ker_sram_2,  dout_ker_sram_3,  dout_ker_sram_4,  dout_ker_sram_5,  dout_ker_sram_6,  dout_ker_sram_7;
    output reg                           ker_read_valid_0, ker_read_valid_1, ker_read_valid_2, ker_read_valid_3, ker_read_valid_4, ker_read_valid_5, ker_read_valid_6, ker_read_valid_7;
    output reg                           ker_read_final_0, ker_read_final_1, ker_read_final_2, ker_read_final_3, ker_read_final_4, ker_read_final_5, ker_read_final_6, ker_read_final_7;

    input wire [KER_SRAM_ADDR_BITS-1:0] cfg_ker_length_sub1   ;
    input wire [2:0]                    cfg_ker_readnums ; // the number of one kernel should be read in once computation equal token numbers
    input wire [1:0]                    cfg_ker_tile_readnums_sub1 ;
    input wire [5:0]                    cfg_ker_tile_size_sub1 ;

    wire                                ker_read_final ;

    //---- declare ker_top write signal ----
    wire write_cen_ker_sram_0, write_cen_ker_sram_1, write_cen_ker_sram_2, write_cen_ker_sram_3, write_cen_ker_sram_4, write_cen_ker_sram_5, write_cen_ker_sram_6, write_cen_ker_sram_7 ;
    wire write_wen_ker_sram_0, write_wen_ker_sram_1, write_wen_ker_sram_2, write_wen_ker_sram_3, write_wen_ker_sram_4, write_wen_ker_sram_5, write_wen_ker_sram_6, write_wen_ker_sram_7 ;
    wire [KER_SRAM_ADDR_BITS-1:0] write_addr_ker_sram_0, write_addr_ker_sram_1, write_addr_ker_sram_2, write_addr_ker_sram_3, write_addr_ker_sram_4, write_addr_ker_sram_5, write_addr_ker_sram_6, write_addr_ker_sram_7 ;
    wire [KER_SRAM_WORDS_BITS-1:0] write_din_ker_sram_0, write_din_ker_sram_1, write_din_ker_sram_2, write_din_ker_sram_3, write_din_ker_sram_4, write_din_ker_sram_5, write_din_ker_sram_6, write_din_ker_sram_7 ;

    //---- declare ker_top read signal ----
    wire read_cen_ker_sram_0, read_cen_ker_sram_1, read_cen_ker_sram_2, read_cen_ker_sram_3, read_cen_ker_sram_4, read_cen_ker_sram_5, read_cen_ker_sram_6, read_cen_ker_sram_7 ;
    wire [KER_SRAM_ADDR_BITS-1:0] read_addr_ker_sram_0, read_addr_ker_sram_1, read_addr_ker_sram_2, read_addr_ker_sram_3, read_addr_ker_sram_4, read_addr_ker_sram_5, read_addr_ker_sram_6, read_addr_ker_sram_7 ;

    //---- actually cen wen signal declare ----
    wire alta_cen_ker_sram_0, alta_cen_ker_sram_1, alta_cen_ker_sram_2, alta_cen_ker_sram_3, alta_cen_ker_sram_4, alta_cen_ker_sram_5, alta_cen_ker_sram_6, alta_cen_ker_sram_7 ;
    wire altb_cen_ker_sram_0, altb_cen_ker_sram_1, altb_cen_ker_sram_2, altb_cen_ker_sram_3, altb_cen_ker_sram_4, altb_cen_ker_sram_5, altb_cen_ker_sram_6, altb_cen_ker_sram_7 ;
    wire alta_wen_ker_sram_0, alta_wen_ker_sram_1, alta_wen_ker_sram_2, alta_wen_ker_sram_3, alta_wen_ker_sram_4, alta_wen_ker_sram_5, alta_wen_ker_sram_6, alta_wen_ker_sram_7 ;

    //==============================================================================
    //========    SRAM instance and assignment    ========
    //==============================================================================
    `ifdef FPGA_SRAM_SETTING
        assign alta_cen_ker_sram_0 = ~write_cen_ker_sram_0;
        assign alta_cen_ker_sram_1 = ~write_cen_ker_sram_1;
        assign alta_cen_ker_sram_2 = ~write_cen_ker_sram_2;
        assign alta_cen_ker_sram_3 = ~write_cen_ker_sram_3;
        assign alta_cen_ker_sram_4 = ~write_cen_ker_sram_4;
        assign alta_cen_ker_sram_5 = ~write_cen_ker_sram_5;
        assign alta_cen_ker_sram_6 = ~write_cen_ker_sram_6;
        assign alta_cen_ker_sram_7 = ~write_cen_ker_sram_7;

        assign altb_cen_ker_sram_0 = ~read_cen_ker_sram_0;
        assign altb_cen_ker_sram_1 = ~read_cen_ker_sram_1;
        assign altb_cen_ker_sram_2 = ~read_cen_ker_sram_2;
        assign altb_cen_ker_sram_3 = ~read_cen_ker_sram_3;
        assign altb_cen_ker_sram_4 = ~read_cen_ker_sram_4;
        assign altb_cen_ker_sram_5 = ~read_cen_ker_sram_5;
        assign altb_cen_ker_sram_6 = ~read_cen_ker_sram_6;
        assign altb_cen_ker_sram_7 = ~read_cen_ker_sram_7;

        assign alta_wen_ker_sram_0 = ~write_wen_ker_sram_0;
        assign alta_wen_ker_sram_1 = ~write_wen_ker_sram_1;
        assign alta_wen_ker_sram_2 = ~write_wen_ker_sram_2;
        assign alta_wen_ker_sram_3 = ~write_wen_ker_sram_3;
        assign alta_wen_ker_sram_4 = ~write_wen_ker_sram_4;
        assign alta_wen_ker_sram_5 = ~write_wen_ker_sram_5;
        assign alta_wen_ker_sram_6 = ~write_wen_ker_sram_6;
        assign alta_wen_ker_sram_7 = ~write_wen_ker_sram_7;

        FFN_BRAM_KER FFN_ker_0(.clka(clk), .clkb(clk), .ena(alta_cen_ker_sram_0), .enb(altb_cen_ker_sram_0), .wea(alta_wen_ker_sram_0), .addra(write_addr_ker_sram_0), .addrb(read_addr_ker_sram_0), .dina(write_din_ker_sram_0), .doutb(dout_ker_sram_0));
        FFN_BRAM_KER FFN_ker_1(.clka(clk), .clkb(clk), .ena(alta_cen_ker_sram_1), .enb(altb_cen_ker_sram_1), .wea(alta_wen_ker_sram_1), .addra(write_addr_ker_sram_1), .addrb(read_addr_ker_sram_1), .dina(write_din_ker_sram_1), .doutb(dout_ker_sram_1));
        FFN_BRAM_KER FFN_ker_2(.clka(clk), .clkb(clk), .ena(alta_cen_ker_sram_2), .enb(altb_cen_ker_sram_2), .wea(alta_wen_ker_sram_2), .addra(write_addr_ker_sram_2), .addrb(read_addr_ker_sram_2), .dina(write_din_ker_sram_2), .doutb(dout_ker_sram_2));
        FFN_BRAM_KER FFN_ker_3(.clka(clk), .clkb(clk), .ena(alta_cen_ker_sram_3), .enb(altb_cen_ker_sram_3), .wea(alta_wen_ker_sram_3), .addra(write_addr_ker_sram_3), .addrb(read_addr_ker_sram_3), .dina(write_din_ker_sram_3), .doutb(dout_ker_sram_3));
        FFN_BRAM_KER FFN_ker_4(.clka(clk), .clkb(clk), .ena(alta_cen_ker_sram_4), .enb(altb_cen_ker_sram_4), .wea(alta_wen_ker_sram_4), .addra(write_addr_ker_sram_4), .addrb(read_addr_ker_sram_4), .dina(write_din_ker_sram_4), .doutb(dout_ker_sram_4));
        FFN_BRAM_KER FFN_ker_5(.clka(clk), .clkb(clk), .ena(alta_cen_ker_sram_5), .enb(altb_cen_ker_sram_5), .wea(alta_wen_ker_sram_5), .addra(write_addr_ker_sram_5), .addrb(read_addr_ker_sram_5), .dina(write_din_ker_sram_5), .doutb(dout_ker_sram_5));
        FFN_BRAM_KER FFN_ker_6(.clka(clk), .clkb(clk), .ena(alta_cen_ker_sram_6), .enb(altb_cen_ker_sram_6), .wea(alta_wen_ker_sram_6), .addra(write_addr_ker_sram_6), .addrb(read_addr_ker_sram_6), .dina(write_din_ker_sram_6), .doutb(dout_ker_sram_6));
        FFN_BRAM_KER FFN_ker_7(.clka(clk), .clkb(clk), .ena(alta_cen_ker_sram_7), .enb(altb_cen_ker_sram_7), .wea(alta_wen_ker_sram_7), .addra(write_addr_ker_sram_7), .addrb(read_addr_ker_sram_7), .dina(write_din_ker_sram_7), .doutb(dout_ker_sram_7));  
    `else
        assign alta_cen_ker_sram_0 = write_cen_ker_sram_0;
        assign alta_cen_ker_sram_1 = write_cen_ker_sram_1;
        assign alta_cen_ker_sram_2 = write_cen_ker_sram_2;
        assign alta_cen_ker_sram_3 = write_cen_ker_sram_3;
        assign alta_cen_ker_sram_4 = write_cen_ker_sram_4;
        assign alta_cen_ker_sram_5 = write_cen_ker_sram_5;
        assign alta_cen_ker_sram_6 = write_cen_ker_sram_6;
        assign alta_cen_ker_sram_7 = write_cen_ker_sram_7;

        assign altb_cen_ker_sram_0 = read_cen_ker_sram_0;
        assign altb_cen_ker_sram_1 = read_cen_ker_sram_1;
        assign altb_cen_ker_sram_2 = read_cen_ker_sram_2;
        assign altb_cen_ker_sram_3 = read_cen_ker_sram_3;
        assign altb_cen_ker_sram_4 = read_cen_ker_sram_4;
        assign altb_cen_ker_sram_5 = read_cen_ker_sram_5;
        assign altb_cen_ker_sram_6 = read_cen_ker_sram_6;
        assign altb_cen_ker_sram_7 = read_cen_ker_sram_7;

        assign alta_wen_ker_sram_0 = write_wen_ker_sram_0;
        assign alta_wen_ker_sram_1 = write_wen_ker_sram_1;
        assign alta_wen_ker_sram_2 = write_wen_ker_sram_2;
        assign alta_wen_ker_sram_3 = write_wen_ker_sram_3;
        assign alta_wen_ker_sram_4 = write_wen_ker_sram_4;
        assign alta_wen_ker_sram_5 = write_wen_ker_sram_5;
        assign alta_wen_ker_sram_6 = write_wen_ker_sram_6;
        assign alta_wen_ker_sram_7 = write_wen_ker_sram_7;

        KER_SRAM ker_0(.CLKA(clk), .CENA(alta_cen_ker_sram_0), .WENA(alta_wen_ker_sram_0), .AA(write_addr_ker_sram_0), .DA(write_din_ker_sram_0), .CLKB(clk), .CENB(altb_cen_ker_sram_0), .WENB(1'b1), .AB(read_addr_ker_sram_0), .QB(dout_ker_sram_0), .EMAA(3'd0), .EMAB(3'd0));
        KER_SRAM ker_1(.CLKA(clk), .CENA(alta_cen_ker_sram_1), .WENA(alta_wen_ker_sram_1), .AA(write_addr_ker_sram_1), .DA(write_din_ker_sram_1), .CLKB(clk), .CENB(altb_cen_ker_sram_1), .WENB(1'b1), .AB(read_addr_ker_sram_1), .QB(dout_ker_sram_1), .EMAA(3'd0), .EMAB(3'd0));
        KER_SRAM ker_2(.CLKA(clk), .CENA(alta_cen_ker_sram_2), .WENA(alta_wen_ker_sram_2), .AA(write_addr_ker_sram_2), .DA(write_din_ker_sram_2), .CLKB(clk), .CENB(altb_cen_ker_sram_2), .WENB(1'b1), .AB(read_addr_ker_sram_2), .QB(dout_ker_sram_2), .EMAA(3'd0), .EMAB(3'd0));
        KER_SRAM ker_3(.CLKA(clk), .CENA(alta_cen_ker_sram_3), .WENA(alta_wen_ker_sram_3), .AA(write_addr_ker_sram_3), .DA(write_din_ker_sram_3), .CLKB(clk), .CENB(altb_cen_ker_sram_3), .WENB(1'b1), .AB(read_addr_ker_sram_3), .QB(dout_ker_sram_3), .EMAA(3'd0), .EMAB(3'd0));
        KER_SRAM ker_4(.CLKA(clk), .CENA(alta_cen_ker_sram_4), .WENA(alta_wen_ker_sram_4), .AA(write_addr_ker_sram_4), .DA(write_din_ker_sram_4), .CLKB(clk), .CENB(altb_cen_ker_sram_4), .WENB(1'b1), .AB(read_addr_ker_sram_4), .QB(dout_ker_sram_4), .EMAA(3'd0), .EMAB(3'd0));
        KER_SRAM ker_5(.CLKA(clk), .CENA(alta_cen_ker_sram_5), .WENA(alta_wen_ker_sram_5), .AA(write_addr_ker_sram_5), .DA(write_din_ker_sram_5), .CLKB(clk), .CENB(altb_cen_ker_sram_5), .WENB(1'b1), .AB(read_addr_ker_sram_5), .QB(dout_ker_sram_5), .EMAA(3'd0), .EMAB(3'd0));
        KER_SRAM ker_6(.CLKA(clk), .CENA(alta_cen_ker_sram_6), .WENA(alta_wen_ker_sram_6), .AA(write_addr_ker_sram_6), .DA(write_din_ker_sram_6), .CLKB(clk), .CENB(altb_cen_ker_sram_6), .WENB(1'b1), .AB(read_addr_ker_sram_6), .QB(dout_ker_sram_6), .EMAA(3'd0), .EMAB(3'd0));
        KER_SRAM ker_7(.CLKA(clk), .CENA(alta_cen_ker_sram_7), .WENA(alta_wen_ker_sram_7), .AA(write_addr_ker_sram_7), .DA(write_din_ker_sram_7), .CLKB(clk), .CENB(altb_cen_ker_sram_7), .WENB(1'b1), .AB(read_addr_ker_sram_7), .QB(dout_ker_sram_7), .EMAA(3'd0), .EMAB(3'd0));
    `endif

    //-------------------------------------------------------------------
    //----------------	  kernel sram write module		-----------------
    //-------------------------------------------------------------------
    FFN_kersram_w #(
            .KER_SRAM_ADDR_BITS     (   KER_SRAM_ADDR_BITS  )
        ,   .KER_SRAM_WORDS_BITS    (   KER_SRAM_WORDS_BITS )
    ) FFN_kersram_w_inst(
            .clk                   (   clk      )
        ,   .reset                 (   reset    )

        ,   .ker_write_data_din    (   ker_write_data_din       )
        ,   .ker_write_empty_n_din (   ker_write_empty_n_din    )
        ,   .ker_write_read_dout   (   ker_write_read_dout      )

        ,   .cen_ker_sram_0 ( write_cen_ker_sram_0 ), .cen_ker_sram_1 ( write_cen_ker_sram_1 ), .cen_ker_sram_2 ( write_cen_ker_sram_2 ), .cen_ker_sram_3 ( write_cen_ker_sram_3 ), .cen_ker_sram_4 ( write_cen_ker_sram_4 ), .cen_ker_sram_5 ( write_cen_ker_sram_5 ), .cen_ker_sram_6 ( write_cen_ker_sram_6 ), .cen_ker_sram_7 ( write_cen_ker_sram_7 )
        ,   .wen_ker_sram_0 ( write_wen_ker_sram_0 ), .wen_ker_sram_1 ( write_wen_ker_sram_1 ), .wen_ker_sram_2 ( write_wen_ker_sram_2 ), .wen_ker_sram_3 ( write_wen_ker_sram_3 ), .wen_ker_sram_4 ( write_wen_ker_sram_4 ), .wen_ker_sram_5 ( write_wen_ker_sram_5 ), .wen_ker_sram_6 ( write_wen_ker_sram_6 ), .wen_ker_sram_7 ( write_wen_ker_sram_7 )
        ,   .addr_ker_sram_0 (write_addr_ker_sram_0), .addr_ker_sram_1 (write_addr_ker_sram_1), .addr_ker_sram_2 (write_addr_ker_sram_2), .addr_ker_sram_3 (write_addr_ker_sram_3), .addr_ker_sram_4 (write_addr_ker_sram_4), .addr_ker_sram_5 (write_addr_ker_sram_5), .addr_ker_sram_6 (write_addr_ker_sram_6), .addr_ker_sram_7 (write_addr_ker_sram_7)
        ,   .din_ker_sram_0 ( write_din_ker_sram_0 ), .din_ker_sram_1 ( write_din_ker_sram_1 ), .din_ker_sram_2 ( write_din_ker_sram_2 ), .din_ker_sram_3 ( write_din_ker_sram_3 ), .din_ker_sram_4 ( write_din_ker_sram_4 ), .din_ker_sram_5 ( write_din_ker_sram_5 ), .din_ker_sram_6 ( write_din_ker_sram_6 ), .din_ker_sram_7 ( write_din_ker_sram_7 )

        ,   .mast_curr_state        (   mast_curr_state            )

        ,   .ker_write_start        (   ker_write_start            )
        ,   .ker_write_busy         (   ker_write_busy             )
        ,   .ker_write_done         (   ker_write_done             )
        ,   .ker_write_en           (   ker_write_en               )
        ,   .ker_write_last         (   ker_write_last             )

        ,   .cfg_ker_length_sub1          (   cfg_ker_length_sub1          )
        ,   .cfg_ker_tile_size_sub1       (   cfg_ker_tile_size_sub1       )
        ,   .cfg_ker_tile_readnums_sub1   (   cfg_ker_tile_readnums_sub1   )
    );

    //-------------------------------------------------------------------
    //----------------	   kernel sram read module		-----------------
    //-------------------------------------------------------------------
    FFN_kersram_r #(
            .KER_SRAM_ADDR_BITS     (   KER_SRAM_ADDR_BITS  )
        ,   .KER_SRAM_WORDS_BITS    (   KER_SRAM_WORDS_BITS )
    ) FFN_kersram_r_inst(
            .clk                   (   clk      )
        ,   .reset                 (   reset    )

        ,   .cen_ker_sram_0 ( read_cen_ker_sram_0 ), .cen_ker_sram_1 ( read_cen_ker_sram_1 ), .cen_ker_sram_2 ( read_cen_ker_sram_2 ), .cen_ker_sram_3 ( read_cen_ker_sram_3 ), .cen_ker_sram_4 ( read_cen_ker_sram_4 ), .cen_ker_sram_5 ( read_cen_ker_sram_5 ), .cen_ker_sram_6 ( read_cen_ker_sram_6 ), .cen_ker_sram_7 ( read_cen_ker_sram_7 )
        ,   .addr_ker_sram_0 (read_addr_ker_sram_0), .addr_ker_sram_1 (read_addr_ker_sram_1), .addr_ker_sram_2 (read_addr_ker_sram_2), .addr_ker_sram_3 (read_addr_ker_sram_3), .addr_ker_sram_4 (read_addr_ker_sram_4), .addr_ker_sram_5 (read_addr_ker_sram_5), .addr_ker_sram_6 (read_addr_ker_sram_6), .addr_ker_sram_7 (read_addr_ker_sram_7)

        ,   .ker_read_start         (   ker_read_start             )
        ,   .ker_read_busy          (   ker_read_busy              )
        ,   .ker_read_done          (   ker_read_done              )
        ,   .ker_read_final         (   ker_read_final             )
        ,   .ker_read_tile_done     (   ker_read_tile_done         )

        ,   .cfg_ker_length_sub1        (   cfg_ker_length_sub1         )
        ,   .cfg_ker_readnums           (   cfg_ker_readnums            )
        ,   .cfg_ker_tile_size_sub1     (   cfg_ker_tile_size_sub1      )
    ) ;

    always @(*) ker_read_final_0 = ker_read_final ;

endmodule