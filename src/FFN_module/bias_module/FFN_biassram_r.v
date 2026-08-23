// ============================================================================
// Designer : Chao_Ping Liu
// Create   : 2025.07.05
// Ver      : 1.0
// Func     : bias sram read module
// ============================================================================
// Modified : 2026 -- parameterized fan-out (Phase 1a of PE-col scaling).
//   The single bias SRAM is read NUM_BANK words at a time and demuxed onto
//   NUM_BANK column outputs. The old fixed version read 8 words (stride 8,
//   address low 3 bits select the column); this is generalized to NUM_BANK
//   (stride NUM_BANK, low $clog2(NUM_BANK) bits) and the per-column outputs
//   are packed MSB-first into dout_bias_flat (index 0 in the top slot,
//   matching the old {dout_bias_sram_0,..,_7} concatenation). NUM_BANK=8 is
//   identical to the previous behavior.
// ============================================================================

module FFN_biassram_r #(
    parameter BIAS_SRAM_WORDS_BITS = 32
    ,   BIAS_SRAM_ADDR_BITS = 9
    ,   NUM_BANK = 8
)(
        clk
    ,   reset

    ,   dout_bias_sram

    ,   dout_bias_flat        // [NUM_BANK*WORDS_BITS-1:0] , column 0 in MSB slot

    ,   cen_bias_sram
    ,   addr_bias_sram

    ,   bias_read_start
    ,   bias_read_busy
    ,   bias_read_done

    ,   cfg_bias_readnums
);

    localparam BIDX_BITS = (NUM_BANK <= 1) ? 1 : $clog2(NUM_BANK) ;

    // ============================= I/O port Declare ===============================
    input wire clk   ;
    input wire reset ;

    input wire [BIAS_SRAM_WORDS_BITS-1:0]  dout_bias_sram ;

    output reg [NUM_BANK*BIAS_SRAM_WORDS_BITS-1:0] dout_bias_flat ;

    output reg                             cen_bias_sram  ;
    output reg [BIAS_SRAM_ADDR_BITS-1:0]   addr_bias_sram ;

    input wire                             bias_read_start        ;
    output reg                             bias_read_busy         ;
    output reg                             bias_read_done         ;

    input wire [2:0]                       cfg_bias_readnums      ; // the number of one bias should be read in once computation

    reg [2:0] bias_read_nums ;

    reg                         bias_valid ;
    reg [BIDX_BITS-1:0]         bias_addr  ;

    //---- Address counter Declare -----
    reg                             en_bias_addrct    ;
    wire [BIAS_SRAM_ADDR_BITS-1:0]  bias_addrct       ;
    reg  [BIAS_SRAM_ADDR_BITS-1:0]  bias_addrct_start ;
    wire [BIAS_SRAM_ADDR_BITS-1:0]  bias_addrct_final ;
    wire                            bias_addrct_last  ;

    //---- FSM Declare -----
    reg [1:0] bias_read_curr_state ;
    reg [1:0] bias_read_next_state ;
    localparam BIAS_READ_IDLE  = 2'b00;
    localparam BIAS_READ_BUSY  = 2'b01;
    localparam BIAS_READ_DONE  = 2'b10;

    always @(posedge clk) begin
        if(reset)
            bias_read_curr_state <= BIAS_READ_IDLE;
        else
            bias_read_curr_state <= bias_read_next_state;
    end
    always @(*) begin
        case(bias_read_curr_state)
            BIAS_READ_IDLE: bias_read_next_state = (bias_read_start) ? BIAS_READ_BUSY : BIAS_READ_IDLE;
            BIAS_READ_BUSY: bias_read_next_state = (en_bias_addrct && bias_addrct_last) ? BIAS_READ_DONE : BIAS_READ_BUSY;
            BIAS_READ_DONE: bias_read_next_state = BIAS_READ_IDLE;
            default: bias_read_next_state = BIAS_READ_IDLE;
        endcase
    end

    always @(*) begin
        bias_read_busy = (bias_read_curr_state != BIAS_READ_IDLE) ? 1'b1 : 1'b0 ;
        bias_read_done = (bias_read_curr_state == BIAS_READ_DONE) ? 1'b1 : 1'b0 ;
    end

    always @(posedge clk) begin
        if(reset) begin
            cen_bias_sram <= 1'b1;
            addr_bias_sram <= 'd0;
        end
        else begin
            cen_bias_sram <= (bias_read_curr_state == BIAS_READ_BUSY && en_bias_addrct) ? 1'b0 : 1'b1;
            addr_bias_sram <= (bias_read_curr_state == BIAS_READ_BUSY && en_bias_addrct) ? bias_addrct : 'd0;
        end
    end

    always @(posedge clk) begin
        if(reset) begin
            bias_valid <= 1'b0;
            bias_addr  <= 'd0;
        end
        else begin
            bias_valid <= ~cen_bias_sram ;
            bias_addr  <= addr_bias_sram[BIDX_BITS-1:0] ;
        end
    end

    // demux the serially-read words onto NUM_BANK column slots (MSB-first)
    integer di ;
    always @(posedge clk) begin
        if(reset) begin
            dout_bias_flat <= 'd0 ;
        end
        else if(bias_valid) begin
            for (di = 0; di < NUM_BANK; di = di + 1) begin
                if (bias_addr == di[BIDX_BITS-1:0])
                    dout_bias_flat[(NUM_BANK-di)*BIAS_SRAM_WORDS_BITS-1 -: BIAS_SRAM_WORDS_BITS] <= dout_bias_sram ;
            end
        end
    end

    always @(posedge clk) begin
        if(reset)
            bias_read_nums <= 'd0 ;
        else if(bias_read_nums == cfg_bias_readnums && bias_read_done)
            bias_read_nums <= 'd0 ;
        else if(bias_read_done)
            bias_read_nums <= bias_read_nums + 1 ;
    end

    always @(*) begin
        en_bias_addrct = (bias_read_curr_state == BIAS_READ_BUSY) ? 1'b1 : 1'b0 ;
    end

    always @(posedge clk) begin
        if(reset)
            bias_addrct_start <= 'd0 ;
        else if(bias_read_done)
            bias_addrct_start <= bias_addrct_start + NUM_BANK ;
    end
    assign bias_addrct_final = bias_addrct_start + (NUM_BANK-1) ;

    count_yi_v5 #(
            .BITS_OF_END_NUMBER (   BIAS_SRAM_ADDR_BITS   )
    )bias_count(
            .clk            (   clk     )
        ,   .reset          (   reset   )
        ,   .enable         (   en_bias_addrct     )

        ,   .start_number (   bias_addrct_start   )
        ,   .final_number (   bias_addrct_final   )
        ,   .last         (   bias_addrct_last    )
        ,   .total_q      (   bias_addrct         )
    );

endmodule
