// ============================================================================
// Designer : Chao_Ping Liu
// Create   : 2025.07.03
// Ver      : 1.0
// Func     : kernel sram write module
// ============================================================================
// Modified : 2026 -- parameterized bank count (Phase 1a of PE-col scaling).
//   The original fixed FSM walked states KER0..KER7, filling one bank at a
//   time from the input stream. That is reproduced here as {IDLE, BUSY, DONE}
//   plus a bank-index counter 0..NUM_BANK-1 (BUSY && bank_idx==b is exactly
//   the old state KERb), so the sequence and all per-bank control are
//   identical while scaling with one parameter. cen/wen/addr/din are exposed
//   as packed buses (bank b in slot b). Address/tile counters are unchanged.
// ============================================================================

module FFN_kersram_w #(
    parameter KER_SRAM_WORDS_BITS = 64
    ,   KER_SRAM_ADDR_BITS = 9
    ,   NUM_BANK = 8
)(
        clk
    ,   reset

    ,   ker_write_data_din
    ,   ker_write_empty_n_din
    ,   ker_write_read_dout

    ,   cen_ker_flat        // [NUM_BANK-1:0]
    ,   wen_ker_flat        // [NUM_BANK-1:0]
    ,   addr_ker_flat       // [NUM_BANK*ADDR_BITS-1:0]
    ,   din_ker_flat        // [NUM_BANK*WORDS_BITS-1:0]

    ,   mast_curr_state

    ,   ker_write_start
    ,   ker_write_busy
    ,   ker_write_done
    ,   ker_write_en
    ,   ker_write_last
    ,   ker_write_tile_done

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

    localparam BIDX_BITS = (NUM_BANK <= 1) ? 1 : $clog2(NUM_BANK) ;

    // ============================= I/O port Declare ===============================
    input wire clk ;
    input wire reset ;

    input wire [KER_SRAM_WORDS_BITS-1:0]  ker_write_data_din     ;
    input wire                            ker_write_empty_n_din  ;
    output reg                            ker_write_read_dout    ;

    output reg [NUM_BANK-1:0]                       cen_ker_flat  ;
    output reg [NUM_BANK-1:0]                       wen_ker_flat  ;
    output reg [NUM_BANK*KER_SRAM_ADDR_BITS-1:0]    addr_ker_flat ;
    output reg [NUM_BANK*KER_SRAM_WORDS_BITS-1:0]   din_ker_flat  ;

    input wire [MAST_FSM_BITS-1:0]        mast_curr_state ;

    input wire                            ker_write_start        ;
    output reg                            ker_write_busy         ;
    output reg                            ker_write_done         ;
    output reg                            ker_write_en           ;
    output wire                           ker_write_last         ;
    output wire                           ker_write_tile_done    ;  // pulses when one tile's kernel chunk fully written (gates bias write in 16-way)

    input wire [KER_SRAM_ADDR_BITS-1:0]   cfg_ker_length_sub1    ;
    input wire [1:0]                      cfg_ker_tile_readnums_sub1 ;
    input wire [5:0]                      cfg_ker_tile_size_sub1 ;

    wire [5:0]                            ker_cnt               ;
    wire [1:0]                            ker_write_tile_nums   ;

    //---- Address counter Declare -----
    reg                            en_ker_addrct    ;
    wire [KER_SRAM_ADDR_BITS-1:0]  ker_addrct       ;
    reg  [KER_SRAM_ADDR_BITS-1:0]  ker_addrct_start ;
    wire [KER_SRAM_ADDR_BITS-1:0]  ker_addrct_final ;
    wire                           ker_addrct_last  ;

    //----    FSM Declare (IDLE/BUSY/DONE + bank index)    -----
    reg [1:0] ker_write_curr_state ;
    reg [1:0] ker_write_next_state ;
    localparam KER_WRITE_IDLE = 2'd0 ;
    localparam KER_WRITE_BUSY = 2'd1 ;
    localparam KER_WRITE_DONE = 2'd2 ;

    reg  [BIDX_BITS-1:0] bank_idx ;
    wire                 last_bank   = (bank_idx == NUM_BANK-1) ;
    wire                 bank_advance = (en_ker_addrct && ker_addrct_last) ;

    always @(posedge clk) begin
        if (reset)
            ker_write_curr_state <= KER_WRITE_IDLE ;
        else
            ker_write_curr_state <= ker_write_next_state ;
    end
    always @(*) begin
        case(ker_write_curr_state)
            KER_WRITE_IDLE: ker_write_next_state = (ker_write_start) ? KER_WRITE_BUSY : KER_WRITE_IDLE;
            KER_WRITE_BUSY: ker_write_next_state = (bank_advance && last_bank) ? KER_WRITE_DONE : KER_WRITE_BUSY;
            KER_WRITE_DONE: ker_write_next_state = KER_WRITE_IDLE;
            default: ker_write_next_state = KER_WRITE_IDLE;
        endcase
    end

    // bank index : 0 on entry, +1 each time the current bank finishes its sweep
    always @(posedge clk) begin
        if (reset)
            bank_idx <= 'd0 ;
        else if (ker_write_curr_state == KER_WRITE_IDLE)
            bank_idx <= 'd0 ;
        else if (ker_write_curr_state == KER_WRITE_BUSY && bank_advance && !last_bank)
            bank_idx <= bank_idx + 1'b1 ;
    end

    always @(*) begin
        ker_write_busy = (ker_write_curr_state != KER_WRITE_IDLE) ? 1'b1 : 1'b0;
        ker_write_done = (ker_write_curr_state == KER_WRITE_DONE) ? 1'b1 : 1'b0;
        ker_write_en   = (ker_write_curr_state == KER_WRITE_BUSY) ? 1'b1 : 1'b0;
    end

    //==========================================================================
    //====   per-bank write control : bank b active when BUSY & bank_idx==b  ====
    //==========================================================================
    integer wb ;
    always @(posedge clk) begin
        if(reset) begin
            cen_ker_flat  <= {NUM_BANK{1'b1}} ;
            wen_ker_flat  <= {NUM_BANK{1'b1}} ;
            addr_ker_flat <= 'd0 ;
            din_ker_flat  <= 'd0 ;
        end
        else begin
            for (wb = 0; wb < NUM_BANK; wb = wb + 1) begin
                cen_ker_flat[wb] <= (ker_write_curr_state == KER_WRITE_BUSY && bank_idx == wb[BIDX_BITS-1:0] && en_ker_addrct) ? 1'b0 : 1'b1 ;
                wen_ker_flat[wb] <= (ker_write_curr_state == KER_WRITE_BUSY && bank_idx == wb[BIDX_BITS-1:0] && en_ker_addrct) ? 1'b0 : 1'b1 ;
                addr_ker_flat[wb*KER_SRAM_ADDR_BITS  +: KER_SRAM_ADDR_BITS]  <= (en_ker_addrct && ker_write_curr_state == KER_WRITE_BUSY && bank_idx == wb[BIDX_BITS-1:0]) ? ker_addrct : 'd0 ;
                din_ker_flat[wb*KER_SRAM_WORDS_BITS +: KER_SRAM_WORDS_BITS] <= (ker_write_curr_state == KER_WRITE_BUSY && bank_idx == wb[BIDX_BITS-1:0]) ? ker_write_data_din : 'd0 ;
            end
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
