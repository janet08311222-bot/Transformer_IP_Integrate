//================================================================================================
//====================  counter module  ==============================
//  Developer: YI
//  description : enable for count , disable for stall
//      reset for initial . every cycle count 1 .
//      count end number is defined start and final number.
//      last = "1" when total_q == final number  (without -1) during enable.
//================================================================================================

// count_yi_v5 #(
//     .BITS_OF_END_NUMBER (	)
// )ins_name(
//     .clk		( clk )
//     ,	.reset 	 		(	reset	)
//     ,	.enable	 		(		)
// 	,	.start_number	(		)
// 	,	.final_number	(		)
// 	,	.last			(		)
//     ,	.total_q			(		)
// );

//================================================================================================
`timescale 1ns/100ps
module count_yi_v5 #(
    parameter BITS_OF_END_NUMBER = 10
)(
    clk		
    ,	reset 	 
    ,	enable	 
	,	start_number
	,	final_number
	,	last
    ,	total_q	
);

input 	clk ;
input 	reset ;
input 	enable ;

input		[   BITS_OF_END_NUMBER -1 : 0] 	start_number ;
input		[   BITS_OF_END_NUMBER -1 : 0] 	final_number ;
output		[   BITS_OF_END_NUMBER -1 : 0]  total_q 		;
output  									last 		;

reg		[   BITS_OF_END_NUMBER -1 : 0]  cnt_q 		;


wire final_iscome ;
assign total_q = start_number + cnt_q ;
assign last = ( enable & final_iscome )? 1'd1 : 1'd0 ;

assign final_iscome = (total_q >= final_number) ? 1'd1 : 1'd0 ;
always@( posedge clk or posedge reset )begin
    if ( reset )begin
        cnt_q<= 'd0; 
    end else begin
		if ( enable )begin
			if( total_q >= final_number )begin
				cnt_q<= 'd0 ;
			end 
			else begin
				cnt_q<= cnt_q + 'd1 ;
			end
		end 
		else begin
			cnt_q <= cnt_q ;
			end

    end
end 

endmodule