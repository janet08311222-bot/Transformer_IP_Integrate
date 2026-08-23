// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2023.04.18
// Ver      : 1.0
// Func     : PE row output sequencial 8 bit * 8cycles output package to 64bit *1 cycle
// ============================================================================
module pe_qz_pkg #(
	parameter TBITS = 64 
	,	TBYTE = 8
)(
	clk			
	,	reset	
	,	data8_din
	,	valid8_din 
	,	data64_dout
	,	valid64_dout
	
);

//==============================================================================
//========    Input/Output    ========
//==============================================================================

	input wire clk		;
	input wire reset	;
	input wire [TBYTE-1:0]	data8_din		;
	input wire 				valid8_din 		;
		output reg [TBITS-1:0]	data64_dout		;
	output wire				valid64_dout	;

//==============================================================================
//========    input data counter    ========
//==============================================================================

reg [4-1:0] cnt;
reg [TBITS-1:0] pkg_reg;

wire cnt7_last ;
reg cnt7_last_cly0 ;
// assign valid64_dout = (cnt7_last_cly0) ? (flag&&~pe_out_vaild) ? 0 : 1 : 0  ;
assign valid64_dout = (cnt7_last_cly0) ? 1 : 0  ;	//YWJ
assign cnt7_last = ( cnt >= 4'd7)? 1'd1 : 1'd0 ;


always @(posedge clk) begin
	if(reset)
		cnt7_last_cly0 <= 0 ;
	else
		cnt7_last_cly0 <= cnt7_last ;
end


always @(posedge clk ) begin
	if(reset )begin
		cnt <= 4'd0 ;
	end
	else begin
		if( valid8_din )begin
			if( cnt >= 4'd7 )begin
				cnt <= 0 ;
			end
			else begin
				cnt <= cnt +1 ;
			end
		end
		else begin
			cnt <= cnt ;
		end
	end
end
	
always @(posedge clk) begin
	if( reset )begin
		pkg_reg <= 0 ;
	end
	else begin
		if( valid8_din)begin
			case (cnt)
				4'd0: pkg_reg [63   	-: TBYTE] <= data8_din ;
				4'd1: pkg_reg [(63 -8) 	-: TBYTE] <= data8_din ;
				4'd2: pkg_reg [(63 -16)	-: TBYTE] <= data8_din ;
				4'd3: pkg_reg [(63 -24)	-: TBYTE] <= data8_din ;
				4'd4: pkg_reg [(63 -32)	-: TBYTE] <= data8_din ;
				4'd5: pkg_reg [(63 -40)	-: TBYTE] <= data8_din ;
				4'd6: pkg_reg [(63 -48)	-: TBYTE] <= data8_din ;
				4'd7: pkg_reg [(63 -56)	-: TBYTE] <= data8_din ;
				default: pkg_reg <= pkg_reg ;
			endcase
		end
		else begin
			pkg_reg <= pkg_reg ;
		end	
	end
end

always @(*) begin
	if( valid64_dout )begin
		data64_dout = pkg_reg ;
	end
	else begin
		data64_dout = 0 ;
	end
end

endmodule


