//================================================================================================
//====================  counter module  ==============================
//  Developer: YI
//  description : enable for count , disable for stall
//      reset for initial . every cycle count 1 .
//      count end number is defined by final_number .
//================================================================================================
`timescale 1ns/100ps
module count_yi_v3 #(
    parameter BITS_OF_END_NUMBER = 20
)(
    clk,
    reset , 
    enable , 
	final_number,
    cnt_q	
);
input 	clk ;
input 	reset ;
input 	enable ;
input		[   BITS_OF_END_NUMBER -1 : 0] 	final_number ;
output reg	[   BITS_OF_END_NUMBER -1 : 0]  cnt_q ;

always@( posedge clk or posedge reset )begin
    if ( reset )begin
        cnt_q<= 'd0; 
    end else begin
		if ( enable )begin
			if( cnt_q >= final_number-1 )begin
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