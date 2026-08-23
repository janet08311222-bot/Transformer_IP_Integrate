// ============================================================================
// Designer : Chao_Ping Liu
// Create   : 2025.07.01
// Ver      : 1.0
// Func     : input sram write module
// ============================================================================

module FFN_ifsram_w #(
	parameter IF_SRAM_WORDS_BITS = 64 
    ,   IF_SRAM_ADDR_BITS = 9
)(
	    clk
    ,   reset

	,   if_write_data_din
	,   if_write_empty_n_din
	,   if_write_read_dout

	,   cen_if_sram_0
    ,   wen_if_sram_0
    ,   addr_if_sram_0
    ,   din_if_sram_0

	,   if_write_start
	,   if_write_busy
	,   if_write_done
	,   if_write_en

	,   cfg_if_totalsize_sub1
);

    // ============================= I/O port Declare ===============================
    input wire clk ;
	input wire reset ;
	
	input wire [IF_SRAM_WORDS_BITS-1:0] if_write_data_din		;
	input wire				            if_write_empty_n_din	;
	output reg				            if_write_read_dout		;

    output reg                          cen_if_sram_0  ;
    output reg                          wen_if_sram_0  ;
    output reg [IF_SRAM_ADDR_BITS-1:0]  addr_if_sram_0 ;
    output reg [IF_SRAM_WORDS_BITS-1:0] din_if_sram_0  ;

	input wire 		if_write_start		;
	output reg 		if_write_busy 		;
	output reg 		if_write_done 		;
	output reg 		if_write_en 		;

    input wire [IF_SRAM_ADDR_BITS-1:0]  cfg_if_totalsize_sub1   ;

    //---- Address counter Declare -----
    reg                             en_if_addrct_0  ;
    wire [IF_SRAM_ADDR_BITS-1:0]    addrct_0        ;
    wire [IF_SRAM_ADDR_BITS-1:0]    addrct_final    ;
    wire                            addrct_last     ;

    //----    FSM Declare    -----
    reg [1:0] if_write_curr_state ;
    reg [1:0] if_write_next_state ;
    localparam IF_WRITE_IDLE	= 2'd0;
    localparam IF_WRITE_I0 	    = 2'd1;
    localparam IF_WRITE_DONE	= 2'd2;

    always @(posedge clk) begin
        if(reset)
            if_write_curr_state <= IF_WRITE_IDLE ;
        else
            if_write_curr_state <= if_write_next_state ;
    end
    always @(*) begin
        case(if_write_curr_state) 
            IF_WRITE_IDLE	: if_write_next_state = ( if_write_start ) ? IF_WRITE_I0 : IF_WRITE_IDLE ;
            IF_WRITE_I0 	: if_write_next_state = ( en_if_addrct_0 & addrct_last ) ? IF_WRITE_DONE : IF_WRITE_I0 ;
            IF_WRITE_DONE	: if_write_next_state = IF_WRITE_IDLE ;
            default         : if_write_next_state = IF_WRITE_IDLE ;
        endcase
    end

    always @(*) begin
        if_write_busy = (if_write_curr_state != IF_WRITE_IDLE) ? 1'd1 : 1'd0;
        if_write_done = (if_write_curr_state == IF_WRITE_DONE) ? 1'd1 : 1'd0;
        if_write_en   = (if_write_curr_state == IF_WRITE_I0) ? 1'd1 : 1'd0;
    end

    always @(*) begin
		cen_if_sram_0  = ( (if_write_curr_state == IF_WRITE_I0) && en_if_addrct_0 ) ? 1'd0 : 1'd1 ;
		wen_if_sram_0  = cen_if_sram_0 ;
		addr_if_sram_0 = (if_write_curr_state == IF_WRITE_I0) ? addrct_0 : 'd0 ;
		din_if_sram_0  = if_write_data_din ;
	end

    assign addrct_final = cfg_if_totalsize_sub1 ;

    always@( * )begin
        en_if_addrct_0 = if_write_empty_n_din & if_write_read_dout ;
    end

    count_yi_v4 #(
            .BITS_OF_END_NUMBER (	IF_SRAM_ADDR_BITS	)
    )if_count(
            .clk		    (   clk     )
        ,	.reset 	 		(	reset	)
        ,	.enable	 		(	en_if_addrct_0	)

        ,	.final_number	(	addrct_final	)
        ,	.last			(	addrct_last	)
        ,	.total_q		(	addrct_0	)
    );

    // ============================================================================
    // ============= input store read fifo ========================================
    // ============================================================================
    always @(posedge clk ) begin
        if(reset)
            if_write_read_dout <= 1'd0 ;
        else begin
            if( if_write_busy && (if_write_curr_state != IF_WRITE_IDLE) )begin
                if( if_write_empty_n_din )
                    if_write_read_dout <= 1'd1 ;
                else
                    if_write_read_dout <= 1'd0 ;
            end
            else
                if_write_read_dout <= 1'd0 ;
        end
    end

endmodule