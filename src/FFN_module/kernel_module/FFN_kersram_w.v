// ============================================================================
// Designer : Chao_Ping Liu
// Create   : 2025.07.03
// Ver      : 1.0
// Func     : kernel sram write module
// ============================================================================

module FFN_kersram_w #(
    parameter KER_SRAM_WORDS_BITS = 64 
    ,   KER_SRAM_ADDR_BITS = 9
)(
        clk
    ,   reset

    ,   ker_write_data_din
    ,   ker_write_empty_n_din
    ,   ker_write_read_dout

    ,   cen_ker_sram_0,  cen_ker_sram_1,  cen_ker_sram_2,  cen_ker_sram_3,  cen_ker_sram_4,  cen_ker_sram_5,  cen_ker_sram_6,  cen_ker_sram_7
    ,   wen_ker_sram_0,  wen_ker_sram_1,  wen_ker_sram_2,  wen_ker_sram_3,  wen_ker_sram_4,  wen_ker_sram_5,  wen_ker_sram_6,  wen_ker_sram_7
    ,   addr_ker_sram_0, addr_ker_sram_1, addr_ker_sram_2, addr_ker_sram_3, addr_ker_sram_4, addr_ker_sram_5, addr_ker_sram_6, addr_ker_sram_7
    ,   din_ker_sram_0,  din_ker_sram_1,  din_ker_sram_2,  din_ker_sram_3,  din_ker_sram_4,  din_ker_sram_5,  din_ker_sram_6,  din_ker_sram_7

    ,   mast_curr_state

    ,   ker_write_start
    ,   ker_write_busy
    ,   ker_write_done
    ,   ker_write_en
    ,   ker_write_last

    ,   cfg_ker_length_sub1
    ,   cfg_ker_tile_size_sub1
    ,   cfg_ker_tile_readnums_sub1
);

    //---- master FSM parameter ----
	localparam MAST_FSM_BITS 	= 3;
	localparam M_IDLE 	= 3'd0;
	localparam M_FSLD	= 3'd1;
	localparam M_BASE 	= 3'd2;
	localparam M_DONE 	= 3'd3;

    // ============================= I/O port Declare ===============================
    input wire clk ;
    input wire reset ;

    input wire [KER_SRAM_WORDS_BITS-1:0]  ker_write_data_din     ;
    input wire                            ker_write_empty_n_din  ;
    output reg                            ker_write_read_dout    ;

    output reg                            cen_ker_sram_0,  cen_ker_sram_1,  cen_ker_sram_2,  cen_ker_sram_3,  cen_ker_sram_4,  cen_ker_sram_5,  cen_ker_sram_6,  cen_ker_sram_7 ;
    output reg                            wen_ker_sram_0,  wen_ker_sram_1,  wen_ker_sram_2,  wen_ker_sram_3,  wen_ker_sram_4,  wen_ker_sram_5,  wen_ker_sram_6,  wen_ker_sram_7 ;
    output reg [KER_SRAM_ADDR_BITS-1:0]   addr_ker_sram_0, addr_ker_sram_1, addr_ker_sram_2, addr_ker_sram_3, addr_ker_sram_4, addr_ker_sram_5, addr_ker_sram_6, addr_ker_sram_7 ;
    output reg [KER_SRAM_WORDS_BITS-1:0]  din_ker_sram_0,  din_ker_sram_1,  din_ker_sram_2,  din_ker_sram_3,  din_ker_sram_4,  din_ker_sram_5,  din_ker_sram_6,  din_ker_sram_7 ;

    input wire [MAST_FSM_BITS-1:0]        mast_curr_state ;

    input wire                            ker_write_start        ;
    output reg                            ker_write_busy         ;
    output reg                            ker_write_done         ;
    output reg                            ker_write_en           ;
    output wire                           ker_write_last         ;

    input wire [KER_SRAM_ADDR_BITS-1:0]   cfg_ker_length_sub1    ;
    input wire [1:0]                      cfg_ker_tile_readnums_sub1 ;
    input wire [5:0]                      cfg_ker_tile_size_sub1 ;

    wire                                  ker_write_tile_done   ;

    wire [5:0]                            ker_cnt               ;
    wire [1:0]                            ker_write_tile_nums   ;

    //---- Address counter Declare -----
    reg                            en_ker_addrct    ;
    wire [KER_SRAM_ADDR_BITS-1:0]  ker_addrct       ;
    reg  [KER_SRAM_ADDR_BITS-1:0]  ker_addrct_start ;
    wire [KER_SRAM_ADDR_BITS-1:0]  ker_addrct_final ;
    wire                           ker_addrct_last  ;

    //----    FSM Declare    -----
    reg [3:0] ker_write_curr_state ;
    reg [3:0] ker_write_next_state ;
    localparam KER_WRITE_IDLE      = 4'd0 ;
    localparam KER_WRITE_KER0      = 4'd1 ;
    localparam KER_WRITE_KER1      = 4'd2 ;
    localparam KER_WRITE_KER2      = 4'd3 ;
    localparam KER_WRITE_KER3      = 4'd4 ;
    localparam KER_WRITE_KER4      = 4'd5 ;
    localparam KER_WRITE_KER5      = 4'd6 ;
    localparam KER_WRITE_KER6      = 4'd7 ;
    localparam KER_WRITE_KER7      = 4'd8 ;
    localparam KER_WRITE_DONE      = 4'd9 ;

    always @(posedge clk) begin
        if (reset) 
            ker_write_curr_state <= KER_WRITE_IDLE ;
        else
            ker_write_curr_state <= ker_write_next_state ;
    end
    always @(*) begin
        case(ker_write_curr_state)
            KER_WRITE_IDLE: ker_write_next_state = (ker_write_start) ? KER_WRITE_KER0 : KER_WRITE_IDLE;
            KER_WRITE_KER0: ker_write_next_state = (en_ker_addrct && ker_addrct_last) ? KER_WRITE_KER1 : KER_WRITE_KER0;
            KER_WRITE_KER1: ker_write_next_state = (en_ker_addrct && ker_addrct_last) ? KER_WRITE_KER2 : KER_WRITE_KER1;
            KER_WRITE_KER2: ker_write_next_state = (en_ker_addrct && ker_addrct_last) ? KER_WRITE_KER3 : KER_WRITE_KER2;
            KER_WRITE_KER3: ker_write_next_state = (en_ker_addrct && ker_addrct_last) ? KER_WRITE_KER4 : KER_WRITE_KER3;
            KER_WRITE_KER4: ker_write_next_state = (en_ker_addrct && ker_addrct_last) ? KER_WRITE_KER5 : KER_WRITE_KER4;
            KER_WRITE_KER5: ker_write_next_state = (en_ker_addrct && ker_addrct_last) ? KER_WRITE_KER6 : KER_WRITE_KER5;
            KER_WRITE_KER6: ker_write_next_state = (en_ker_addrct && ker_addrct_last) ? KER_WRITE_KER7 : KER_WRITE_KER6;
            KER_WRITE_KER7: ker_write_next_state = (en_ker_addrct && ker_addrct_last) ? KER_WRITE_DONE : KER_WRITE_KER7;
            KER_WRITE_DONE: ker_write_next_state = KER_WRITE_IDLE;
            default: ker_write_next_state = KER_WRITE_IDLE;
        endcase
    end

    always @(*) begin
        ker_write_busy = (ker_write_curr_state != KER_WRITE_IDLE) ? 1'b1 : 1'b0;
        ker_write_done = (ker_write_curr_state == KER_WRITE_DONE) ? 1'b1 : 1'b0;
        ker_write_en   = (ker_write_curr_state != KER_WRITE_IDLE && ker_write_curr_state != KER_WRITE_DONE) ? 1'b1 : 1'b0;
    end

    // always @(*) begin
    //     cen_ker_sram_0 = (ker_write_curr_state == KER_WRITE_KER0 && en_ker_addrct) ? 1'b0 : 1'b1 ;
    //     cen_ker_sram_1 = (ker_write_curr_state == KER_WRITE_KER1 && en_ker_addrct) ? 1'b0 : 1'b1 ;
    //     cen_ker_sram_2 = (ker_write_curr_state == KER_WRITE_KER2 && en_ker_addrct) ? 1'b0 : 1'b1 ;
    //     cen_ker_sram_3 = (ker_write_curr_state == KER_WRITE_KER3 && en_ker_addrct) ? 1'b0 : 1'b1 ;
    //     cen_ker_sram_4 = (ker_write_curr_state == KER_WRITE_KER4 && en_ker_addrct) ? 1'b0 : 1'b1 ;
    //     cen_ker_sram_5 = (ker_write_curr_state == KER_WRITE_KER5 && en_ker_addrct) ? 1'b0 : 1'b1 ;
    //     cen_ker_sram_6 = (ker_write_curr_state == KER_WRITE_KER6 && en_ker_addrct) ? 1'b0 : 1'b1 ;
    //     cen_ker_sram_7 = (ker_write_curr_state == KER_WRITE_KER7 && en_ker_addrct) ? 1'b0 : 1'b1 ;

    //     wen_ker_sram_0 = cen_ker_sram_0;
    //     wen_ker_sram_1 = cen_ker_sram_1;
    //     wen_ker_sram_2 = cen_ker_sram_2;
    //     wen_ker_sram_3 = cen_ker_sram_3;
    //     wen_ker_sram_4 = cen_ker_sram_4;
    //     wen_ker_sram_5 = cen_ker_sram_5;
    //     wen_ker_sram_6 = cen_ker_sram_6;
    //     wen_ker_sram_7 = cen_ker_sram_7;

    //     addr_ker_sram_0 = (en_ker_addrct && ker_write_curr_state == KER_WRITE_KER0) ? ker_addrct : 'd0 ;
    //     addr_ker_sram_1 = (en_ker_addrct && ker_write_curr_state == KER_WRITE_KER1) ? ker_addrct : 'd0 ;
    //     addr_ker_sram_2 = (en_ker_addrct && ker_write_curr_state == KER_WRITE_KER2) ? ker_addrct : 'd0 ;
    //     addr_ker_sram_3 = (en_ker_addrct && ker_write_curr_state == KER_WRITE_KER3) ? ker_addrct : 'd0 ;
    //     addr_ker_sram_4 = (en_ker_addrct && ker_write_curr_state == KER_WRITE_KER4) ? ker_addrct : 'd0 ;
    //     addr_ker_sram_5 = (en_ker_addrct && ker_write_curr_state == KER_WRITE_KER5) ? ker_addrct : 'd0 ;
    //     addr_ker_sram_6 = (en_ker_addrct && ker_write_curr_state == KER_WRITE_KER6) ? ker_addrct : 'd0 ;
    //     addr_ker_sram_7 = (en_ker_addrct && ker_write_curr_state == KER_WRITE_KER7) ? ker_addrct : 'd0 ;

    //     din_ker_sram_0 = (ker_write_curr_state == KER_WRITE_KER0) ? ker_write_data_din : 'd0 ;
    //     din_ker_sram_1 = (ker_write_curr_state == KER_WRITE_KER1) ? ker_write_data_din : 'd0 ;
    //     din_ker_sram_2 = (ker_write_curr_state == KER_WRITE_KER2) ? ker_write_data_din : 'd0 ;
    //     din_ker_sram_3 = (ker_write_curr_state == KER_WRITE_KER3) ? ker_write_data_din : 'd0 ;
    //     din_ker_sram_4 = (ker_write_curr_state == KER_WRITE_KER4) ? ker_write_data_din : 'd0 ;
    //     din_ker_sram_5 = (ker_write_curr_state == KER_WRITE_KER5) ? ker_write_data_din : 'd0 ;
    //     din_ker_sram_6 = (ker_write_curr_state == KER_WRITE_KER6) ? ker_write_data_din : 'd0 ;
    //     din_ker_sram_7 = (ker_write_curr_state == KER_WRITE_KER7) ? ker_write_data_din : 'd0 ;
    // end

    always @(posedge clk) begin
        if(reset) begin
            cen_ker_sram_0 <= 1'b1;
            cen_ker_sram_1 <= 1'b1;
            cen_ker_sram_2 <= 1'b1;
            cen_ker_sram_3 <= 1'b1;
            cen_ker_sram_4 <= 1'b1;
            cen_ker_sram_5 <= 1'b1;
            cen_ker_sram_6 <= 1'b1;
            cen_ker_sram_7 <= 1'b1;

            wen_ker_sram_0 <= 1'b1;
            wen_ker_sram_1 <= 1'b1;
            wen_ker_sram_2 <= 1'b1;
            wen_ker_sram_3 <= 1'b1;
            wen_ker_sram_4 <= 1'b1;
            wen_ker_sram_5 <= 1'b1;
            wen_ker_sram_6 <= 1'b1;
            wen_ker_sram_7 <= 1'b1;

            addr_ker_sram_0 <= 'd0;
            addr_ker_sram_1 <= 'd0;
            addr_ker_sram_2 <= 'd0;
            addr_ker_sram_3 <= 'd0;
            addr_ker_sram_4 <= 'd0;
            addr_ker_sram_5 <= 'd0;
            addr_ker_sram_6 <= 'd0;
            addr_ker_sram_7 <= 'd0;

            din_ker_sram_0 <= 'd0;
            din_ker_sram_1 <= 'd0;
            din_ker_sram_2 <= 'd0;
            din_ker_sram_3 <= 'd0;
            din_ker_sram_4 <= 'd0;
            din_ker_sram_5 <= 'd0;
            din_ker_sram_6 <= 'd0;
            din_ker_sram_7 <= 'd0;
        end
        else begin
            cen_ker_sram_0 <= (ker_write_curr_state == KER_WRITE_KER0 && en_ker_addrct) ? 1'b0 : 1'b1 ;
            cen_ker_sram_1 <= (ker_write_curr_state == KER_WRITE_KER1 && en_ker_addrct) ? 1'b0 : 1'b1 ;
            cen_ker_sram_2 <= (ker_write_curr_state == KER_WRITE_KER2 && en_ker_addrct) ? 1'b0 : 1'b1 ;
            cen_ker_sram_3 <= (ker_write_curr_state == KER_WRITE_KER3 && en_ker_addrct) ? 1'b0 : 1'b1 ;
            cen_ker_sram_4 <= (ker_write_curr_state == KER_WRITE_KER4 && en_ker_addrct) ? 1'b0 : 1'b1 ;
            cen_ker_sram_5 <= (ker_write_curr_state == KER_WRITE_KER5 && en_ker_addrct) ? 1'b0 : 1'b1 ;
            cen_ker_sram_6 <= (ker_write_curr_state == KER_WRITE_KER6 && en_ker_addrct) ? 1'b0 : 1'b1 ;
            cen_ker_sram_7 <= (ker_write_curr_state == KER_WRITE_KER7 && en_ker_addrct) ? 1'b0 : 1'b1 ;

            wen_ker_sram_0 <= (ker_write_curr_state == KER_WRITE_KER0 && en_ker_addrct) ? 1'b0 : 1'b1 ;
            wen_ker_sram_1 <= (ker_write_curr_state == KER_WRITE_KER1 && en_ker_addrct) ? 1'b0 : 1'b1 ;
            wen_ker_sram_2 <= (ker_write_curr_state == KER_WRITE_KER2 && en_ker_addrct) ? 1'b0 : 1'b1 ;
            wen_ker_sram_3 <= (ker_write_curr_state == KER_WRITE_KER3 && en_ker_addrct) ? 1'b0 : 1'b1 ;
            wen_ker_sram_4 <= (ker_write_curr_state == KER_WRITE_KER4 && en_ker_addrct) ? 1'b0 : 1'b1 ;
            wen_ker_sram_5 <= (ker_write_curr_state == KER_WRITE_KER5 && en_ker_addrct) ? 1'b0 : 1'b1 ;
            wen_ker_sram_6 <= (ker_write_curr_state == KER_WRITE_KER6 && en_ker_addrct) ? 1'b0 : 1'b1 ;
            wen_ker_sram_7 <= (ker_write_curr_state == KER_WRITE_KER7 && en_ker_addrct) ? 1'b0 : 1'b1 ;

            addr_ker_sram_0 <= (en_ker_addrct && ker_write_curr_state == KER_WRITE_KER0) ? ker_addrct : 'd0 ;
            addr_ker_sram_1 <= (en_ker_addrct && ker_write_curr_state == KER_WRITE_KER1) ? ker_addrct : 'd0 ;
            addr_ker_sram_2 <= (en_ker_addrct && ker_write_curr_state == KER_WRITE_KER2) ? ker_addrct : 'd0 ;
            addr_ker_sram_3 <= (en_ker_addrct && ker_write_curr_state == KER_WRITE_KER3) ? ker_addrct : 'd0 ;
            addr_ker_sram_4 <= (en_ker_addrct && ker_write_curr_state == KER_WRITE_KER4) ? ker_addrct : 'd0 ;
            addr_ker_sram_5 <= (en_ker_addrct && ker_write_curr_state == KER_WRITE_KER5) ? ker_addrct : 'd0 ;
            addr_ker_sram_6 <= (en_ker_addrct && ker_write_curr_state == KER_WRITE_KER6) ? ker_addrct : 'd0 ;
            addr_ker_sram_7 <= (en_ker_addrct && ker_write_curr_state == KER_WRITE_KER7) ? ker_addrct : 'd0 ;

            din_ker_sram_0 <= (ker_write_curr_state == KER_WRITE_KER0) ? ker_write_data_din : 'd0 ;
            din_ker_sram_1 <= (ker_write_curr_state == KER_WRITE_KER1) ? ker_write_data_din : 'd0 ;
            din_ker_sram_2 <= (ker_write_curr_state == KER_WRITE_KER2) ? ker_write_data_din : 'd0 ;
            din_ker_sram_3 <= (ker_write_curr_state == KER_WRITE_KER3) ? ker_write_data_din : 'd0 ;
            din_ker_sram_4 <= (ker_write_curr_state == KER_WRITE_KER4) ? ker_write_data_din : 'd0 ;
            din_ker_sram_5 <= (ker_write_curr_state == KER_WRITE_KER5) ? ker_write_data_din : 'd0 ;
            din_ker_sram_6 <= (ker_write_curr_state == KER_WRITE_KER6) ? ker_write_data_din : 'd0 ;
            din_ker_sram_7 <= (ker_write_curr_state == KER_WRITE_KER7) ? ker_write_data_din : 'd0 ;
        end
    end

    count_yi_v4 #(
        .BITS_OF_END_NUMBER (   6   )
    )ker_number_count(
            .clk            (   clk     )
        ,   .reset          (   reset   )
        ,   .enable         (   ker_write_done    )

        ,   .final_number (   cfg_ker_tile_size_sub1   )
        ,   .last         (   ker_write_tile_done      )
        ,   .total_q      (   ker_cnt                  )
    );

    count_yi_v4 #(
        .BITS_OF_END_NUMBER (   2   )
    )ker_write_tile_count(
            .clk            (   clk     )
        ,   .reset          (   reset   )
        ,   .enable         (   ker_write_tile_done    )

        ,   .final_number (   cfg_ker_tile_readnums_sub1  )
        ,   .last         (   ker_write_last              )
        ,   .total_q      (   ker_write_tile_nums         )
    );

    always @(posedge clk) begin
        if(reset)
            ker_addrct_start <= 'd0 ;
        else if(ker_write_done)
            ker_addrct_start <= ker_addrct_start + cfg_ker_length_sub1 + 1 ;
    end
    assign ker_addrct_final = ker_addrct_start + cfg_ker_length_sub1 ;

    always @(*) begin
        en_ker_addrct = ker_write_empty_n_din && ker_write_read_dout ;
    end

    count_yi_v5 #(
            .BITS_OF_END_NUMBER (   KER_SRAM_ADDR_BITS   )
    )ker_write_addr_count(
            .clk            (   clk     )
        ,   .reset          (   reset   )
        ,   .enable         (   en_ker_addrct     )

        ,   .start_number (   ker_addrct_start   )
        ,   .final_number (   ker_addrct_final   )
        ,   .last         (   ker_addrct_last    )
        ,   .total_q      (   ker_addrct         )
    );

    // ============================================================================
    // ============= kernel store read fifo =======================================
    // ============================================================================
    always @(posedge clk ) begin
        if(reset)
            ker_write_read_dout <= 1'd0 ;
        else begin
            if( ker_write_busy && (ker_write_curr_state != KER_WRITE_IDLE) )begin
                if( ker_write_empty_n_din )
                    ker_write_read_dout <= 1'd1 ;
                else
                    ker_write_read_dout <= 1'd0 ;
            end
            else
                ker_write_read_dout <= 1'd0 ;
        end
    end

endmodule