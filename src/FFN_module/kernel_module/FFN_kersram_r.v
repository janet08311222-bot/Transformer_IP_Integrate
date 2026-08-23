// ============================================================================
// Designer : Chao_Ping Liu
// Create   : 2025.07.05
// Ver      : 1.0
// Func     : kernel sram read module
// ============================================================================
// Modified : 2026 -- parameterized bank count (Phase 1a of PE-col scaling).
//   The per-bank read-enable / address form a 1-cycle staggered shift chain
//   (bank b is read one cycle after bank b-1) feeding the systolic PE column
//   chain. The previous fixed 8-bank version is reproduced exactly here as a
//   generate over NUM_BANK; control FSM and counters are unchanged. cen/addr
//   are exposed as packed buses (bank 0 in the LSB slot) so the count scales
//   with a single parameter.
// ============================================================================

module FFN_kersram_r #(
    parameter KER_SRAM_WORDS_BITS = 64
    ,   KER_SRAM_ADDR_BITS = 9
    ,   NUM_BANK = 8
)(
        clk
    ,   reset

    ,   cen_ker_flat        // [NUM_BANK-1:0]              bank b -> bit b
    ,   addr_ker_flat       // [NUM_BANK*ADDR_BITS-1:0]    bank b -> slot b

    ,   ker_read_start
    ,   ker_read_busy
    ,   ker_read_done
    ,   ker_read_final
    ,   ker_read_tile_done

    ,   cfg_ker_length_sub1
    ,   cfg_ker_readnums
    ,   cfg_ker_tile_size_sub1
);

    // ============================= I/O port Declare ===============================
    input wire clk ;
    input wire reset ;

    output reg [NUM_BANK-1:0]                     cen_ker_flat  ;
    output reg [NUM_BANK*KER_SRAM_ADDR_BITS-1:0]  addr_ker_flat ;

    input wire                            ker_read_start        ;
    output reg                            ker_read_busy         ;
    output reg                            ker_read_done         ;
    output reg                            ker_read_final        ;
    output wire                           ker_read_tile_done    ;

    input wire [KER_SRAM_ADDR_BITS-1:0]   cfg_ker_length_sub1   ;
    input wire [2:0]                      cfg_ker_readnums      ;
    input wire [5:0]                      cfg_ker_tile_size_sub1 ;

    reg                       final_temp            ;

    wire                      one_ker_read_done     ;

    wire [2:0]                ker_read_nums         ;
    wire [5:0]                ker_cnt               ;

    //---- Address counter Declare -----
    reg                            en_ker_addrct    ;
    wire [KER_SRAM_ADDR_BITS-1:0]  ker_addrct       ;
    reg  [KER_SRAM_ADDR_BITS-1:0]  ker_addrct_start ;
    wire [KER_SRAM_ADDR_BITS-1:0]  ker_addrct_final ;
    wire                           ker_addrct_last  ;

    //---- FSM Declare -----
    reg [1:0] ker_read_curr_state ;
    reg [1:0] ker_read_next_state ;
    localparam KER_READ_IDLE  = 2'b00;
    localparam KER_READ_BUSY  = 2'b01;
    localparam KER_READ_DONE  = 2'b10;

    always @(posedge clk) begin
        if(reset)
            ker_read_curr_state <= KER_READ_IDLE;
        else
            ker_read_curr_state <= ker_read_next_state;
    end
    always @(*) begin
        case(ker_read_curr_state)
            KER_READ_IDLE: ker_read_next_state = (ker_read_start) ? KER_READ_BUSY : KER_READ_IDLE;
            KER_READ_BUSY: ker_read_next_state = (en_ker_addrct && ker_addrct_last && ker_read_nums == cfg_ker_readnums) ? KER_READ_DONE : KER_READ_BUSY;
            KER_READ_DONE: ker_read_next_state = KER_READ_IDLE;
            default: ker_read_next_state = KER_READ_IDLE;
        endcase
    end

    always @(*) begin
        ker_read_busy = (ker_read_curr_state != KER_READ_IDLE) ? 1'b1 : 1'b0;
        ker_read_done = (ker_read_curr_state == KER_READ_DONE) ? 1'b1 : 1'b0;
    end

    //==========================================================================
    //==== staggered read shift chain : bank b is delayed 1 cycle from b-1  =====
    //==========================================================================
    // bank 0 driven from the FSM/counter; banks 1..NUM_BANK-1 each register the
    // previous bank's cen/addr -- identical to the old hand-unrolled 8-bank code.
    reg [NUM_BANK-1:0]                    cen_chain  ;
    reg [KER_SRAM_ADDR_BITS-1:0]          addr_chain [0:NUM_BANK-1] ;

    integer ci ;
    always @(posedge clk) begin
        if(reset) begin
            cen_chain <= {NUM_BANK{1'b1}} ;
        end
        else begin
            cen_chain[0] <= (ker_read_curr_state == KER_READ_BUSY && en_ker_addrct) ? 1'b0 : 1'b1;
            for (ci = 1; ci < NUM_BANK; ci = ci + 1)
                cen_chain[ci] <= cen_chain[ci-1] ;
        end
    end
    always @(posedge clk) begin
        if(reset) begin
            for (ci = 0; ci < NUM_BANK; ci = ci + 1)
                addr_chain[ci] <= 'd0 ;
        end
        else begin
            addr_chain[0] <= (ker_read_curr_state == KER_READ_BUSY && en_ker_addrct) ? ker_addrct : 'd0 ;
            for (ci = 1; ci < NUM_BANK; ci = ci + 1)
                addr_chain[ci] <= addr_chain[ci-1] ;
        end
    end

    // pack chain -> output buses (bank b in slot b)
    integer pi ;
    always @(*) begin
        for (pi = 0; pi < NUM_BANK; pi = pi + 1) begin
            cen_ker_flat[pi]                              = cen_chain[pi] ;
            addr_ker_flat[pi*KER_SRAM_ADDR_BITS +: KER_SRAM_ADDR_BITS] = addr_chain[pi] ;
        end
    end

    always @(posedge clk) begin
        if(reset) begin
            final_temp <= 1'b0 ;
            ker_read_final <= 1'b0 ;
        end
        else begin
            final_temp <= ker_addrct_last ;
            ker_read_final <= final_temp ;
        end
    end

    count_yi_v4 #(
        .BITS_OF_END_NUMBER (   3   )
    )every_ker_read_nums_count(
            .clk            (   clk     )
        ,   .reset          (   reset   )
        ,   .enable         (   ker_addrct_last   )

        ,   .final_number (   cfg_ker_readnums    )
        ,   .last         (   one_ker_read_done   )
        ,   .total_q      (   ker_read_nums       )
    );

    count_yi_v4 #(
        .BITS_OF_END_NUMBER (   6   )
    )ker_number_count(
            .clk            (   clk     )
        ,   .reset          (   reset   )
        ,   .enable         (   one_ker_read_done     )

        ,   .final_number (   cfg_ker_tile_size_sub1   )
        ,   .last         (   ker_read_tile_done       )
        ,   .total_q      (   ker_cnt                  )
    );

    always @(*) begin
        en_ker_addrct = (ker_read_curr_state == KER_READ_BUSY) ? 1'b1 : 1'b0;
    end

    always @(posedge clk) begin
        if(reset)
            ker_addrct_start <= 'd0 ;
        else if(ker_read_nums == cfg_ker_readnums && ker_addrct_last)
            ker_addrct_start <= ker_addrct_start + cfg_ker_length_sub1 + 1 ;
    end
    assign ker_addrct_final = ker_addrct_start + cfg_ker_length_sub1 ;

    count_yi_v5 #(
            .BITS_OF_END_NUMBER (   KER_SRAM_ADDR_BITS   )
    )ker_read_addr_count(
            .clk            (   clk     )
        ,   .reset          (   reset   )
        ,   .enable         (   en_ker_addrct     )

        ,   .start_number (   ker_addrct_start   )
        ,   .final_number (   ker_addrct_final   )
        ,   .last         (   ker_addrct_last    )
        ,   .total_q      (   ker_addrct         )
    );

endmodule
