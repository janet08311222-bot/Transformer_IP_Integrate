// ============================================================================
// Designer : Chao_Ping Liu
// Create   : 2025.07.06
// Ver      : 1.0
// Func     : output sram write module
// ============================================================================

module FFN_otsram_w #(
    parameter OT_SRAM_WORDS_BITS = 64 
    ,   OT_SRAM_ADDR_BITS = 9
)(
        clk
    ,   reset

    ,   ot_write_data_din
    ,   ot_write_empty_n_din
    ,   ot_write_read_dout
    ,   ot_write_last

    ,   cen_ot_sram
    ,   wen_ot_sram
    ,   addr_ot_sram
    ,   din_ot_sram
    
    ,   cfg_ot_rnd_finsub1
) ;

    //==============================================================================    
	//========    I/O Port declare    ==============================================
	//==============================================================================
    input  wire   clk     ;
    input  wire   reset   ;

    input  wire   [OT_SRAM_WORDS_BITS-1:0]    ot_write_data_din       ;
    input  wire                               ot_write_empty_n_din    ;
    output wire                               ot_write_read_dout      ;
    output wire                               ot_write_last           ;

    output wire                               cen_ot_sram     ;
    output wire                               wen_ot_sram     ;
    output wire   [OT_SRAM_ADDR_BITS-1:0]     addr_ot_sram    ;
    output wire   [OT_SRAM_WORDS_BITS-1:0]    din_ot_sram     ;

    input  wire   [OT_SRAM_ADDR_BITS-1:0]     cfg_ot_rnd_finsub1  ;

    //---- Address counter Declare -----
    wire cnt_addr_en ;
    wire cnt_addr_last ;
    wire [ OT_SRAM_ADDR_BITS-1 : 0 ]		cnt_addr_finnumsub1		;		
    wire [ OT_SRAM_ADDR_BITS-1 : 0 ]		cnt_addr		;		

    reg valid_in ;
    reg [OT_SRAM_WORDS_BITS-1:0] data_in ;

    reg read ;

    assign ot_write_read_dout = read ;

    assign cen_ot_sram = ~valid_in ;
    assign wen_ot_sram = ~valid_in ;
    assign din_ot_sram = ( valid_in )? data_in : 64'd0 ;
    assign addr_ot_sram = cnt_addr ;

    assign ot_write_last = ( !valid_in ) ? 1'd0 : (cnt_addr == cnt_addr_finnumsub1) ? 1'd1 : 1'd0 ;

    always @(posedge clk ) begin
        if( reset )
            read <= 1'd0 ;
        else 
            read <= ot_write_empty_n_din ;
    end

    always @(posedge clk ) begin
        valid_in <= ot_write_empty_n_din & read ;
        data_in <= ot_write_data_din ;
    end

    assign cnt_addr_en = valid_in ;
    assign cnt_addr_finnumsub1 = cfg_ot_rnd_finsub1 ;

    count_yi_v4 #(
        .BITS_OF_END_NUMBER (	OT_SRAM_ADDR_BITS	)
    )b0_ct00(
            .clk			( 	clk 				)
        ,	.reset 	 		(	reset				)
        ,	.enable	 		(	cnt_addr_en			)

        ,	.final_number	(	cnt_addr_finnumsub1	)
        ,	.last			(	cnt_addr_last		)
        ,	.total_q		(	cnt_addr			)
    );

endmodule