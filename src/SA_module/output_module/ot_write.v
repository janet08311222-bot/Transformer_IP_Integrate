// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2022.12.15
// Ver      : 1.0
// Func     : output write sram module
//		last signal means last data has been write in ot_sram .
// Log------
//		2023.04.14-- test total output column = 16 ch_out=64 ,so output data has 
//			16*64/8=128 entries, 
// ============================================================================

module ot_write #(
	parameter SRAM_DATA_BITS = 64	
	,	SRAM_ADDR_BITS = 12  //HYR
)
(
		clk			
	,	reset			
	
	,	data_in				
	,	fifo_empty_n		
	,	fifo_read 			

	,	last				

	,	addr_otsr			
	,	cen_otsr			
	,	wen_otsr			
	,	data_for_sram		

	,	cfg_ot_rnd_finsub1		
);
	
//==============================================================================
//========    Input/Output    ========
//==============================================================================

	input clk		;
	input reset		;

	input [ SRAM_DATA_BITS-1 : 0 ]		data_in		;
	input	fifo_empty_n 	;
	output	fifo_read 	;


	output wire last ;

	output cen_otsr	;
	output wen_otsr	;
	output [ SRAM_ADDR_BITS-1 : 0 ]		addr_otsr		;
	output [ SRAM_DATA_BITS-1 : 0 ]		data_for_sram	;

	//----    config    -----
	input wire [ SRAM_ADDR_BITS-1 : 0 ]		cfg_ot_rnd_finsub1 ;
//-----------------------------------------------------------------------------




wire cnt_addr_en ;
wire cnt_addr_last ;
wire [ SRAM_ADDR_BITS-1 : 0 ]		cnt_addr_finnumsub1		;		
wire [ SRAM_ADDR_BITS-1 : 0 ]		cnt_addr		;		



reg [ SRAM_ADDR_BITS-1 : 0 ]		cnt_addr2		;		
	

reg valid_in_dly0 ;
reg [SRAM_DATA_BITS-1:0] data_in_dly0 ;


reg read ;


assign fifo_read = read ;


assign cen_otsr = ~valid_in_dly0 ;
assign wen_otsr = ~valid_in_dly0 ;
assign data_for_sram = ( valid_in_dly0 )? data_in_dly0 : 64'd0 ;
assign addr_otsr = cnt_addr ;

assign last = (  !valid_in_dly0 )? 1'd0 : 
				(cnt_addr == cnt_addr_finnumsub1) ? 1'd1 : 1'd0 ;


always @(posedge clk ) begin
	if( reset )
		read <= 1'd0 ;
	else 
		read <= fifo_empty_n ;
end

always @(posedge clk ) begin
	valid_in_dly0 <= fifo_empty_n & read ;
	data_in_dly0 <= data_in ;
end



assign cnt_addr_en = valid_in_dly0 ;
assign cnt_addr_finnumsub1 = cfg_ot_rnd_finsub1 ;

count_yi_v4 #(
    .BITS_OF_END_NUMBER (	SRAM_ADDR_BITS		)
)b0_ct00(
    	.clk			( 	clk 				)
    ,	.reset 	 		(	reset				)
    ,	.enable	 		(	cnt_addr_en			)

	,	.final_number	(	cnt_addr_finnumsub1	)
	,	.last			(	cnt_addr_last		)
    ,	.total_q		(	cnt_addr			)
);


//---- counter type1  cnt_addr < ADDR_FINAL-1--------------
// always @(posedge clk ) begin
// 	if( reset )begin
// 		cnt_addr <= 10'd0 ;
// 	end 
// 	else begin
// 		if( valid_in_dly0 )begin
// 			if( cnt_addr < ADDR_FINAL-1 )begin
// 				cnt_addr <= cnt_addr + 1 ;
// 			end
// 			else begin
// 				cnt_addr <= 10'd0 ;
// 			end
// 		end
// 		else begin
// 			cnt_addr <= cnt_addr ;
// 		end
// 	end
// end

//---- counter type2   cnt_addr >= ADDR_FINAL-1--------------
// always @(posedge clk ) begin
// 	if( reset )begin
// 		cnt_addr2 <= 10'd0 ;
// 	end 
// 	else begin
// 		if( valid_in_dly0 )begin
// 			if( cnt_addr2 >= ADDR_FINAL-1 )begin
// 				cnt_addr2 <= 10'd0  ;
// 			end
// 			else begin
// 				cnt_addr2 <= cnt_addr2 +1 ;
// 			end
// 		end
// 		else begin
// 			cnt_addr2 <= cnt_addr2 ;
// 		end
// 	end
// end




endmodule