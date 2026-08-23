// -----------------------------------------------------------------------------
// Module Name  : FFN_biassram_w
// File         : FFN_biassram_w.v
// Author       : Chao-Ping Liu
// Create Date  : 2024.07.03
// Version      : 1.0
// Description  : Bias SRAM write module
// -----------------------------------------------------------------------------

module FFN_biassram_w #(
    parameter TBITS = 64
    ,   BIAS_SRAM_ADDR_BITS = 9
    ,   BIAS_SRAM_DATA_WIDTH = 32
)(
        clk
    ,   reset

    ,   bias_write_data_din
    ,   bias_write_empty_n_din
    ,   bias_write_read_dout

    ,   cen_bias_sram
    ,   wen_bias_sram
    ,   addr_bias_sram
    ,   din_bias_sram

    ,   bias_write_start
    ,   bias_write_busy
    ,   bias_write_done
    ,   bias_write_en

    ,   cfg_bias_once_load_size_sub1

);

    // ============================= I/O port Declare ===============================
    input wire clk ;
    input wire reset ;

    input wire [TBITS-1:0]                  bias_write_data_din     ;
    input wire                              bias_write_empty_n_din  ;
    output reg                              bias_write_read_dout    ;

    output reg                              cen_bias_sram           ;
    output reg                              wen_bias_sram           ;
    output reg [BIAS_SRAM_ADDR_BITS-1:0]    addr_bias_sram          ;
    output reg [BIAS_SRAM_DATA_WIDTH-1:0]   din_bias_sram           ;

    input wire                              bias_write_start        ;
    output reg                              bias_write_busy         ;
    output reg                              bias_write_done         ;
    output reg                              bias_write_en           ;

    input wire [BIAS_SRAM_ADDR_BITS-1:0]    cfg_bias_once_load_size_sub1     ;

    //---- Address counter Declare -----
    reg                             en_bias_addrct  ;
    wire [BIAS_SRAM_ADDR_BITS-1:0]  addrct          ;
    wire [BIAS_SRAM_ADDR_BITS-1:0]  addrct_final    ;
    wire                            addrct_last     ;

    //---- FSM Declare -----
    reg [1:0] bias_write_curr_state ;
    reg [1:0] bias_write_next_state ;
    localparam BIAS_WRITE_IDLE  = 2'd0;
    localparam BIAS_WRITE_BUSY  = 2'd1;
    localparam BIAS_WRITE_DONE  = 2'd2;

    always @(posedge clk) begin
        if (reset) begin
            bias_write_curr_state <= BIAS_WRITE_IDLE;
        end else begin
            bias_write_curr_state <= bias_write_next_state;
        end
    end
    always @(*) begin
        case(bias_write_curr_state)
            BIAS_WRITE_IDLE: bias_write_next_state = (bias_write_start) ? BIAS_WRITE_BUSY : BIAS_WRITE_IDLE;
            BIAS_WRITE_BUSY: bias_write_next_state = (en_bias_addrct && addrct_last) ? BIAS_WRITE_DONE : BIAS_WRITE_BUSY;
            BIAS_WRITE_DONE: bias_write_next_state = BIAS_WRITE_IDLE;
            default: bias_write_next_state = BIAS_WRITE_IDLE;
        endcase
    end

    always @(*) begin
        bias_write_busy = (bias_write_curr_state != BIAS_WRITE_IDLE) ? 1'b1 : 1'b0;
        bias_write_done = (bias_write_curr_state == BIAS_WRITE_DONE) ? 1'b1 : 1'b0;
        bias_write_en   = (bias_write_curr_state == BIAS_WRITE_BUSY) ? 1'b1 : 1'b0;
    end

    always @(*) begin
        cen_bias_sram = ((bias_write_curr_state == BIAS_WRITE_BUSY) && en_bias_addrct) ? 1'b0 : 1'b1;
        wen_bias_sram = cen_bias_sram;
        addr_bias_sram = (bias_write_curr_state == BIAS_WRITE_BUSY) ? addrct : 'd0;
        din_bias_sram = bias_write_data_din[BIAS_SRAM_DATA_WIDTH-1:0];
    end

    assign addrct_final = cfg_bias_once_load_size_sub1;

    always@( * )begin
        en_bias_addrct = bias_write_empty_n_din & bias_write_read_dout;
    end

    count_yi_v4 #(
            .BITS_OF_END_NUMBER (   BIAS_SRAM_ADDR_BITS   )
    )bias_count(
            .clk            (   clk     )
        ,   .reset          (   reset   )
        ,   .enable         (   en_bias_addrct     )

        ,   .final_number (   addrct_final   )
        ,   .last         (   addrct_last    )
        ,   .total_q      (   addrct         )
    );

    // ============================================================================
    // ============= bias store read fifo ========================================
    // ============================================================================
    always @(posedge clk ) begin
        if(reset)
            bias_write_read_dout <= 1'd0 ;
        else begin
            if( bias_write_busy && (bias_write_curr_state != BIAS_WRITE_IDLE) )begin
                if( bias_write_empty_n_din )
                    bias_write_read_dout <= 1'd1 ;
                else
                    bias_write_read_dout <= 1'd0 ;
            end
            else
                bias_write_read_dout <= 1'd0 ;
        end
    end

endmodule