// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2022.09.21
// Ver      : 2.0
// Func     : to get output result from each PE in ROW_n. and should be serial
// 		sent to quantization module.
// 		0921: new act sum pallel to serial each PE
// ============================================================================
// Modified : 2026 -- parameterized for NUM_PE columns (Phase 0 of PE-col scaling)
//   The systolic PE chain guarantees at most one column asserts its valid in
//   any given cycle (results emerge one cycle apart), so the previous one-hot
//   case-mux is replaced by an OR-reduce over all columns. This is bit-exact
//   to the old 8-way version for every reachable (one-hot / all-zero) input,
//   and now scales to any NUM_PE with a single parameter.
// ============================================================================


module FFN_getpe_result #(
	parameter INV_BITS  = 1 ,		// input valid bits
	parameter OUTQ_BITS = 32,		// output bits for quantization
	parameter NUM_PE    = 8			// number of PE columns to serialize
) (
		clk
	,	reset
	,	pe_result_flat		// {valid, mac[OUTQ_BITS-1:0]} per PE, PE0 in LSB slot
	,	pe_actsum_flat		// actsum[OUTQ_BITS-1:0] per PE,        PE0 in LSB slot
	,	valid_out
	,	serial_result
	,	serial_actresult
);

	localparam RES_BITS = OUTQ_BITS + INV_BITS ;

	//==============================================================================
	//========    I/O port declare    ========
	//==============================================================================

	input wire							clk 			;
	input wire							reset 			;
	input wire	[ NUM_PE*RES_BITS  - 1 : 0 ]	pe_result_flat	;
	input wire	[ NUM_PE*OUTQ_BITS - 1 : 0 ]	pe_actsum_flat	;

	output reg							valid_out 			;
	output reg	[ OUTQ_BITS - 1: 0 ]	serial_result		;
	output reg	[ OUTQ_BITS - 1: 0 ]	serial_actresult	;

	//-----------------------------------------------------------------------------
	//----    declare    -----
	integer i ;
	reg						any_valid 		;
	reg signed [ OUTQ_BITS-1 : 0 ]	data_choose 	;
	reg signed [ OUTQ_BITS-1 : 0 ]	actsum_choose 	;

	//-----------------------------------------------------------------------------
	//----    one-hot select via OR-reduce (chain guarantees <=1 valid/cycle)  ----
	always@(*)begin
		any_valid     = 1'b0 ;
		data_choose   = {OUTQ_BITS{1'b0}} ;
		actsum_choose = {OUTQ_BITS{1'b0}} ;
		for( i = 0 ; i < NUM_PE ; i = i + 1 )begin
			if( pe_result_flat[ i*RES_BITS + OUTQ_BITS ] )begin	// this PE's valid bit
				data_choose   = data_choose   | pe_result_flat[ i*RES_BITS  +: OUTQ_BITS ] ;
				actsum_choose = actsum_choose | pe_actsum_flat[ i*OUTQ_BITS +: OUTQ_BITS ] ;
				any_valid     = 1'b1 ;
			end
		end
	end

	always@( posedge clk )begin
		if(reset)begin
			serial_result    <= {OUTQ_BITS{1'b0}} ;
			serial_actresult <= {OUTQ_BITS{1'b0}} ;
			valid_out        <= 1'b0 ;
		end
		else begin
			if( any_valid )begin
				serial_result    <= data_choose ;
				serial_actresult <= actsum_choose ;
				valid_out        <= 1'b1 ;
			end
			else begin
				serial_result    <= {OUTQ_BITS{1'b0}} ;
				serial_actresult <= {OUTQ_BITS{1'b0}} ;
				valid_out        <= 1'b0 ;
			end
		end
	end

endmodule
