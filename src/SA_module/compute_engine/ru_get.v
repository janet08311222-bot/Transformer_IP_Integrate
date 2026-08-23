// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2022.09.21
// Ver      : 2.0
// Func     : to get output result from each PE in ROW_n. and should be serial
// 		sent to quantization module.
// 		0921: new act sum pallel to serial each PE
// ============================================================================


module getpe_result #(
	parameter INV_BITS = 1 ,		// input valid bits
	parameter OUTQ_BITS = 32		// output bits for quantization
) (
	clk			
	,	reset				
	,	pe0_result 			
	,	pe1_result 			
	,	pe2_result 			
	,	pe3_result 			
	,	pe4_result 			
	,	pe5_result 			
	,	pe6_result 			
	,	pe7_result 			
	,	pe0_actsum 			
	,	pe1_actsum 			
	,	pe2_actsum 			
	,	pe3_actsum 			
	,	pe4_actsum 			
	,	pe5_actsum 			
	,	pe6_actsum 			
	,	pe7_actsum 			
	,	valid_out 			
	,	serial_result 		
	,	serial_actresult 	
);

//==============================================================================
//========    I/O port declare    ========
//==============================================================================

input wire			clk 		;
input wire			reset 		;
input wire	[ OUTQ_BITS + INV_BITS - 1 : 0 ]		pe0_result 		;
input wire	[ OUTQ_BITS + INV_BITS - 1 : 0 ]		pe1_result 		;
input wire	[ OUTQ_BITS + INV_BITS - 1 : 0 ]		pe2_result 		;
input wire	[ OUTQ_BITS + INV_BITS - 1 : 0 ]		pe3_result 		;
input wire	[ OUTQ_BITS + INV_BITS - 1 : 0 ]		pe4_result 		;
input wire	[ OUTQ_BITS + INV_BITS - 1 : 0 ]		pe5_result 		;
input wire	[ OUTQ_BITS + INV_BITS - 1 : 0 ]		pe6_result 		;
input wire	[ OUTQ_BITS + INV_BITS - 1 : 0 ]		pe7_result 		;
input wire	[ OUTQ_BITS - 1 : 0 ]		pe0_actsum 		;
input wire	[ OUTQ_BITS - 1 : 0 ]		pe1_actsum 		;
input wire	[ OUTQ_BITS - 1 : 0 ]		pe2_actsum 		;
input wire	[ OUTQ_BITS - 1 : 0 ]		pe3_actsum 		;
input wire	[ OUTQ_BITS - 1 : 0 ]		pe4_actsum 		;
input wire	[ OUTQ_BITS - 1 : 0 ]		pe5_actsum 		;
input wire	[ OUTQ_BITS - 1 : 0 ]		pe6_actsum 		;
input wire	[ OUTQ_BITS - 1 : 0 ]		pe7_actsum 		;

output reg						valid_out 		;
output reg	[ OUTQ_BITS - 1: 0 ]			serial_result		;
output reg	[ OUTQ_BITS - 1: 0 ]			serial_actresult		;

//-----------------------------------------------------------------------------
//----    declare    -----
wire [ 7:0 ] valid_in ;
reg signed [ 31 : 0 ] data_choose ;
reg signed [ 31 : 0 ] actsum_choose ;

//-----------------------------------------------------------------------------


assign valid_in = { 
	pe0_result[ OUTQ_BITS + INV_BITS-1  -: 1 ],
	pe1_result[ OUTQ_BITS + INV_BITS-1  -: 1 ],
	pe2_result[ OUTQ_BITS + INV_BITS-1  -: 1 ],
	pe3_result[ OUTQ_BITS + INV_BITS-1  -: 1 ],
	pe4_result[ OUTQ_BITS + INV_BITS-1  -: 1 ],
	pe5_result[ OUTQ_BITS + INV_BITS-1  -: 1 ],
	pe6_result[ OUTQ_BITS + INV_BITS-1  -: 1 ],
	pe7_result[ OUTQ_BITS + INV_BITS-1  -: 1 ]
	}	;


always@(*)begin
	case (valid_in)
		8'b1000_0000: data_choose = { pe0_result[ OUTQ_BITS -1  -: 32 ]};
		8'b0100_0000: data_choose = { pe1_result[ OUTQ_BITS -1  -: 32 ]};
		8'b0010_0000: data_choose = { pe2_result[ OUTQ_BITS -1  -: 32 ]};
		8'b0001_0000: data_choose = { pe3_result[ OUTQ_BITS -1  -: 32 ]};
		8'b0000_1000: data_choose = { pe4_result[ OUTQ_BITS -1  -: 32 ]};
		8'b0000_0100: data_choose = { pe5_result[ OUTQ_BITS -1  -: 32 ]};
		8'b0000_0010: data_choose = { pe6_result[ OUTQ_BITS -1  -: 32 ]};
		8'b0000_0001: data_choose = { pe7_result[ OUTQ_BITS -1  -: 32 ]};
		default: data_choose = 32'd0 ;
	endcase
end

always@(*)begin
	case (valid_in)
		8'b1000_0000: actsum_choose = pe0_actsum;
		8'b0100_0000: actsum_choose = pe1_actsum;
		8'b0010_0000: actsum_choose = pe2_actsum;
		8'b0001_0000: actsum_choose = pe3_actsum;
		8'b0000_1000: actsum_choose = pe4_actsum;
		8'b0000_0100: actsum_choose = pe5_actsum;
		8'b0000_0010: actsum_choose = pe6_actsum;
		8'b0000_0001: actsum_choose = pe7_actsum;
		default: actsum_choose = 32'd0 ;
	endcase
end

always@( posedge clk )begin
	if(reset)begin
		serial_result <= 32'd0 ;
		serial_actresult <= 32'd0 ;
		valid_out <= 0;
	end
	else begin
		if(  valid_in != 8'd0 )begin
			serial_result <= data_choose ;
			serial_actresult <= actsum_choose ;
			valid_out <= 1;
		end
		else begin
			serial_result <= 32'd0;
			serial_actresult <= 32'd0;
			valid_out <= 0;
		end
	end
end





endmodule