// ============================================================================
// Designer : Chao_Ping Liu
// Create   : 2025.07.03
// Ver      : 1.0
// Func     : kernel top module
// ============================================================================
//      Instance Name:              KER_SRAM
//      Words:                      512
//      Bits:                       64
//-----------------------------------------------------------------------------
// Modified : 2026 -- parameterized bank count (Phase 1a of PE-col scaling).
//   The hand-unrolled 8-bank memory array + write/read wiring is now a
//   generate over NUM_BANK, and kernel data is exchanged with the PE side as
//   a single packed bus dout_ker_flat (bank 0 in the MSB slot, matching the
//   old {dout_ker_sram_0,..,_7} concatenation). At NUM_BANK=8 this is
//   structurally identical to the previous version.
// ============================================================================
`ifndef ASIC
`define FPGA_SRAM_SETTING   // FPGA default; ASIC build passes +define+ASIC -> ASIC SRAM path
`endif

module FFN_ker_top #(
    parameter TBITS = 64
    ,   TBYTE = 8
    ,   KER_SRAM_ADDR_BITS = 9
    ,   KER_SRAM_WORDS_BITS = 64
    ,   NUM_BANK = 8
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
    ,   ker_write_tile_done

    ,   ker_read_start
    ,   ker_read_busy
    ,   ker_read_done
    ,   ker_read_tile_done

    ,   dout_ker_flat          // [NUM_BANK*WORDS_BITS-1:0] , bank 0 in MSB slot
    ,   ker_read_final

    ,   cfg_ker_length_sub1
    ,   cfg_ker_readnums
    ,   cfg_ker_tile_readnums_sub1
    ,   cfg_ker_tile_size_sub1
);

    //---- master FSM parameter ----
	localparam MAST_FSM_BITS 	= 3;

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
    output wire             ker_write_tile_done    ;

    input wire              ker_read_start         ;
    output wire             ker_read_busy          ;
    output wire             ker_read_done          ;
    output wire             ker_read_tile_done     ;

    output wire [NUM_BANK*KER_SRAM_WORDS_BITS-1:0] dout_ker_flat ;
    output reg                                     ker_read_final ;

    input wire [KER_SRAM_ADDR_BITS-1:0] cfg_ker_length_sub1   ;
    input wire [2:0]                    cfg_ker_readnums ;
    input wire [1:0]                    cfg_ker_tile_readnums_sub1 ;
    input wire [5:0]                    cfg_ker_tile_size_sub1 ;

    wire                                ker_read_final_w ;

    //---- write control buses (from FFN_kersram_w) ----
    wire [NUM_BANK-1:0]                    write_cen_flat  ;
    wire [NUM_BANK-1:0]                    write_wen_flat  ;
    wire [NUM_BANK*KER_SRAM_ADDR_BITS-1:0] write_addr_flat ;
    wire [NUM_BANK*KER_SRAM_WORDS_BITS-1:0] write_din_flat ;

    //---- read control buses (from FFN_kersram_r) ----
    wire [NUM_BANK-1:0]                    read_cen_flat  ;
    wire [NUM_BANK*KER_SRAM_ADDR_BITS-1:0] read_addr_flat ;

    //---- per-bank read data ----
    wire [KER_SRAM_WORDS_BITS-1:0] dout_bank [0:NUM_BANK-1] ;

    //==============================================================================
    //========    SRAM instances (generate over NUM_BANK)    =======================
    //==============================================================================
    genvar b ;
    generate
        for (b = 0; b < NUM_BANK; b = b + 1) begin : ker_bank
            wire                          w_cen  = write_cen_flat[b] ;
            wire                          w_wen  = write_wen_flat[b] ;
            wire                          r_cen  = read_cen_flat[b] ;
            wire [KER_SRAM_ADDR_BITS-1:0] w_addr = write_addr_flat[b*KER_SRAM_ADDR_BITS +: KER_SRAM_ADDR_BITS] ;
            wire [KER_SRAM_ADDR_BITS-1:0] r_addr = read_addr_flat [b*KER_SRAM_ADDR_BITS +: KER_SRAM_ADDR_BITS] ;
            wire [KER_SRAM_WORDS_BITS-1:0] w_din = write_din_flat [b*KER_SRAM_WORDS_BITS +: KER_SRAM_WORDS_BITS] ;

            `ifdef FPGA_SRAM_SETTING
                FFN_BRAM_KER ker_inst(
                        .clka(clk), .clkb(clk)
                    ,   .ena(~w_cen), .enb(~r_cen), .wea(~w_wen)
                    ,   .addra(w_addr), .addrb(r_addr)
                    ,   .dina(w_din),  .doutb(dout_bank[b])
                );
            `else
                FFN_KER_SRAM ker_inst(
                        .CLKA(clk), .CENA(w_cen), .WENA(w_wen), .AA(w_addr), .DA(w_din)
                    ,   .CLKB(clk), .CENB(r_cen), .WENB(1'b1),  .AB(r_addr), .QB(dout_bank[b])
                    ,   .EMAA(3'd0), .EMAB(3'd0)
                );
            `endif

            // pack bank b into the MSB-first bus (bank 0 occupies the top slot,
            // matching the old {dout_ker_sram_0,..,_7} ordering used by FFN_pe_array)
            assign dout_ker_flat[(NUM_BANK-b)*KER_SRAM_WORDS_BITS-1 -: KER_SRAM_WORDS_BITS] = dout_bank[b] ;
        end
    endgenerate

    //-------------------------------------------------------------------
    //----------------	  kernel sram write module		-----------------
    //-------------------------------------------------------------------
    FFN_kersram_w #(
            .KER_SRAM_ADDR_BITS     (   KER_SRAM_ADDR_BITS  )
        ,   .KER_SRAM_WORDS_BITS    (   KER_SRAM_WORDS_BITS )
        ,   .NUM_BANK               (   NUM_BANK            )
    ) kersram_w_inst(
            .clk                   (   clk      )
        ,   .reset                 (   reset    )

        ,   .ker_write_data_din    (   ker_write_data_din       )
        ,   .ker_write_empty_n_din (   ker_write_empty_n_din    )
        ,   .ker_write_read_dout   (   ker_write_read_dout      )

        ,   .cen_ker_flat  ( write_cen_flat  )
        ,   .wen_ker_flat  ( write_wen_flat  )
        ,   .addr_ker_flat ( write_addr_flat )
        ,   .din_ker_flat  ( write_din_flat  )

        ,   .mast_curr_state        (   mast_curr_state            )

        ,   .ker_write_start        (   ker_write_start            )
        ,   .ker_write_busy         (   ker_write_busy             )
        ,   .ker_write_done         (   ker_write_done             )
        ,   .ker_write_en           (   ker_write_en               )
        ,   .ker_write_last         (   ker_write_last             )
        ,   .ker_write_tile_done    (   ker_write_tile_done        )

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
        ,   .NUM_BANK               (   NUM_BANK            )
    ) kersram_r_inst(
            .clk                   (   clk      )
        ,   .reset                 (   reset    )

        ,   .cen_ker_flat  ( read_cen_flat  )
        ,   .addr_ker_flat ( read_addr_flat )

        ,   .ker_read_start         (   ker_read_start             )
        ,   .ker_read_busy          (   ker_read_busy              )
        ,   .ker_read_done          (   ker_read_done              )
        ,   .ker_read_final         (   ker_read_final_w           )
        ,   .ker_read_tile_done     (   ker_read_tile_done         )

        ,   .cfg_ker_length_sub1        (   cfg_ker_length_sub1         )
        ,   .cfg_ker_readnums           (   cfg_ker_readnums            )
        ,   .cfg_ker_tile_size_sub1     (   cfg_ker_tile_size_sub1      )
    ) ;

    always @(*) ker_read_final = ker_read_final_w ;

endmodule
