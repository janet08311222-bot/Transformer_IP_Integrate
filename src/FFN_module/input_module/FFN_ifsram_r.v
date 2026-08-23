// ============================================================================
// Designer : Chao_Ping Liu
// Create   : 2025.07.05
// Ver      : 1.0
// Func     : input sram read module
// ============================================================================

module FFN_ifsram_r #(
    parameter IF_SRAM_WORDS_BITS = 64 
    ,   IF_SRAM_ADDR_BITS = 9
)(
        clk
    ,   reset

    ,   cen_if_sram_0
    ,   addr_if_sram_0

    ,   if_read_start
    ,   if_read_busy
    ,   if_read_done

    ,   if_read_valid

    ,   cfg_if_totalsize_sub1
);

    // ============================= I/O port Declare ===============================
    input wire clk ;
    input wire reset ;

    output reg                            cen_if_sram_0 ;
    output reg [IF_SRAM_ADDR_BITS-1:0]   addr_if_sram_0 ;

    input wire                            if_read_start        ;
    output reg                            if_read_busy         ;
    output reg                            if_read_done         ;

    output reg                            if_read_valid        ;

    input wire [IF_SRAM_ADDR_BITS-1:0]  cfg_if_totalsize_sub1 ;

    reg                             valid_temp ;

    //---- Address counter Declare -----
    reg                             en_if_addrct    ;
    wire [IF_SRAM_ADDR_BITS-1:0]    addrct          ;
    wire [IF_SRAM_ADDR_BITS-1:0]    addrct_final    ;
    wire                            addrct_last     ;

    //----    FSM Declare    -----
    reg [1:0] if_read_curr_state ;
    reg [1:0] if_read_next_state ;
    localparam IF_READ_IDLE  = 2'b00;
    localparam IF_READ_BUSY  = 2'b01;
    localparam IF_READ_DONE  = 2'b10;

    always @(posedge clk) begin
        if(reset)
            if_read_curr_state <= IF_READ_IDLE;
        else
            if_read_curr_state <= if_read_next_state;
    end
    always @(*) begin
        case(if_read_curr_state)
            IF_READ_IDLE: if_read_next_state = (if_read_start) ? IF_READ_BUSY : IF_READ_IDLE;
            IF_READ_BUSY: if_read_next_state = (en_if_addrct && addrct_last) ? IF_READ_DONE : IF_READ_BUSY;
            IF_READ_DONE: if_read_next_state = IF_READ_IDLE;
            default: if_read_next_state = IF_READ_IDLE;
        endcase
    end

    always @(*) begin
        if_read_busy = (if_read_curr_state != IF_READ_IDLE) ? 1'b1 : 1'b0;
        if_read_done = (if_read_curr_state == IF_READ_DONE) ? 1'b1 : 1'b0;
    end

    always @(posedge clk) begin
        if(reset) begin
            cen_if_sram_0 <= 1'b1 ;
            addr_if_sram_0 <= 'd0 ;
        end
        else begin
            cen_if_sram_0 <= (if_read_curr_state == IF_READ_BUSY && en_if_addrct) ? 1'b0 : 1'b1 ;
            addr_if_sram_0 <= (if_read_curr_state == IF_READ_BUSY && en_if_addrct) ? addrct : 'd0 ;
        end
    end
    always @(posedge clk) begin
        if(reset) begin
            valid_temp <= 1'b0 ;
            if_read_valid <= 1'b0 ;
        end
        else begin
            valid_temp <= en_if_addrct ;
            if_read_valid <= valid_temp ;
        end
    end

    always @(*) begin
        en_if_addrct = (if_read_curr_state == IF_READ_BUSY) ? 1'b1 : 1'b0 ;
    end

    assign addrct_final = cfg_if_totalsize_sub1 ;

    count_yi_v4 #(
            .BITS_OF_END_NUMBER (   IF_SRAM_ADDR_BITS   )
    )if_count(
            .clk            (   clk     )
        ,   .reset          (   reset   )
        ,   .enable         (   en_if_addrct     )

        ,   .final_number (   addrct_final   )
        ,   .last         (   addrct_last    )
        ,   .total_q      (   addrct         )
    );

endmodule