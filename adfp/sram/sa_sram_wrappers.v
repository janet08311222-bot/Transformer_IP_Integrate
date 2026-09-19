// ============================================================================
//  SA (self-attention) ADFP SRAM wrappers  (N16FFC memory-compiler macros)
//  Replaces the Xilinx BRAM_* IPs used under `FPGA_SRAM_SETTING.
//
//  Instantiated by (the `else / ASIC branch of each block) :
//    IF_SRAM    x16  ifmap_rw/if_top.v      if0bA/if0bB .. if7bA/if7bB
//    KER_SRAM   x8   kernel_rw/ker_top.v    ker_0 .. ker_7
//    BIAS_SRAM  x1   bias_rw/bias_top.v     bias_0
//    OT_SRAM    x4   output_module/ot_top.v otbf_0, otbf_1, otbf_r1_0, otbf_r1_1
//
//  Sizes (from top_pto.v localparams) :
//    IF_SRAM   : 1024x64 dual-port  built from 2x TSDN16FFCLLULVTA512X64M4WBSHO
//                (IFMAP_SRAM_ADDBITS = 10, IFMAP_SRAM_DATA_WIDTH = 64)
//    KER_SRAM  : 4096x64 single-port  TS1N16FFCLLULVTA4096X64M8SWBSHO
//                (KER_ADDR_CNT_BITS = 12)
//    BIAS_SRAM :  512x32 single-port  TS1N16FFCLLULVTA512X32M8SWBSHO
//                (BIAS_ADDR_BITS = 9, BIAS_WORD_LENGTH = 32)
//    OT_SRAM   : 4096x64 single-port  TS1N16FFCLLULVTA4096X64M8SWBSHO
//                (OTSRAM_ADDR_BITS = 12)
//
//  Difference vs the FFN sram1.v : the SA if_top.v connects .QA() on every
//  IF_SRAM instance, so IF_SRAM here declares a QA output.  Everything else is
//  the same set of macros at the same depths.
// ============================================================================

`timescale 1ns/1ps

// ---------------------------------------------------------------- IF_SRAM ---
//  1024 x 64 dual-port : port A = write, port B = read.
//  Constructed by stitching TWO 512x64 macros together.
module IF_SRAM (
	output [63:0] QA,
	output [63:0] QB,
	input         CLKA, input CENA, input WENA, input [9:0] AA, input [63:0] DA,
	input         CLKB, input CENB, input WENB, input [9:0] AB, input [63:0] DB,
	input  [2:0]  EMAA, input [2:0] EMAB
);

	// --- Address Decoding for Write Port (Port A) ---
	// CENA is active-low.
	// AA[9] == 0 -> write to lower 512 (u_mem_0)
	// AA[9] == 1 -> write to upper 512 (u_mem_1)
	wire CENA_0 = CENA |  AA[9];
	wire CENA_1 = CENA | ~AA[9];

	// --- Address Decoding for Read Port (Port B) ---
	wire CENB_0 = CENB |  AB[9];
	wire CENB_1 = CENB | ~AB[9];

	wire [63:0] QA_0, QA_1;
	wire [63:0] QB_0, QB_1;

	// Lower 512 Words (Address 0 ~ 511)
	TSDN16FFCLLULVTA512X64M4WBSHO u_mem_0 (
		.CLKA(CLKA), .CEBA(CENA_0), .WEBA(WENA), .AA(AA[8:0]), .DA(DA), .QA(QA_0),
		.BWEBA({64{1'b0}}),
		.CLKB(CLKB), .CEBB(CENB_0), .WEBB(WENB), .AB(AB[8:0]), .DB(DB), .QB(QB_0),
		.BWEBB({64{1'b1}}),
		.CEBMA(1'b1), .WEBMA(1'b1), .AMA(9'b0), .DMA(64'b0), .BWEBMA({64{1'b1}}),
		.CEBMB(1'b1), .WEBMB(1'b1), .AMB(9'b0), .DMB(64'b0), .BWEBMB({64{1'b1}}),
		.SD(1'b0), .SLP(1'b0), .DSLP(1'b0), .PUDELAY(), .BIST(1'b0),
		.CLKM(1'b0), .RTSEL(2'b01), .WTSEL(2'b01)
	);

	// Upper 512 Words (Address 512 ~ 1023)
	TSDN16FFCLLULVTA512X64M4WBSHO u_mem_1 (
		.CLKA(CLKA), .CEBA(CENA_1), .WEBA(WENA), .AA(AA[8:0]), .DA(DA), .QA(QA_1),
		.BWEBA({64{1'b0}}),
		.CLKB(CLKB), .CEBB(CENB_1), .WEBB(WENB), .AB(AB[8:0]), .DB(DB), .QB(QB_1),
		.BWEBB({64{1'b1}}),
		.CEBMA(1'b1), .WEBMA(1'b1), .AMA(9'b0), .DMA(64'b0), .BWEBMA({64{1'b1}}),
		.CEBMB(1'b1), .WEBMB(1'b1), .AMB(9'b0), .DMB(64'b0), .BWEBMB({64{1'b1}}),
		.SD(1'b0), .SLP(1'b0), .DSLP(1'b0), .PUDELAY(), .BIST(1'b0),
		.CLKM(1'b0), .RTSEL(2'b01), .WTSEL(2'b01)
	);

	// --- Output MUX logic ---
	// SRAM reads take 1 cycle.  We MUST register the MSB of the address
	// to properly select the output MUX in the next clock cycle when data is valid.
	reg ab9_reg;
	always @(posedge CLKB) begin
		if (!CENB) begin
			ab9_reg <= AB[9];
		end
	end
	assign QB = ab9_reg ? QB_1 : QB_0;

	// Port A is write-only in this design (if_top.v leaves .QA() open), so this
	// path is optimised away.  Kept correct rather than tied off so the wrapper
	// stays reusable.
	reg aa9_reg;
	always @(posedge CLKA) begin
		if (!CENA) begin
			aa9_reg <= AA[9];
		end
	end
	assign QA = aa9_reg ? QA_1 : QA_0;

endmodule

// --------------------------------------------------------------- KER_SRAM ---
//  4096 x 64 single-port (same macro as OT_SRAM)
module KER_SRAM (
	output [63:0] Q, input CLK, input CEN, input WEN,
	input [11:0]  A, input [63:0] D, input [2:0] EMA
);
	TS1N16FFCLLULVTA4096X64M8SWBSHO u_mem (
		.CLK(CLK), .CEB(CEN), .WEB(WEN), .A(A), .D(D), .Q(Q),
		.BWEB({64{1'b0}}),
		.SLP(1'b0), .DSLP(1'b0), .SD(1'b0), .PUDELAY(),
		.CEBM(1'b1), .WEBM(1'b1), .AM(12'b0), .DM(64'b0), .BWEBM({64{1'b1}}),
		.BIST(1'b0), .RTSEL(2'b01), .WTSEL(2'b01)
	);
endmodule

// -------------------------------------------------------------- BIAS_SRAM ---
//  512 x 32 single-port
module BIAS_SRAM (
	output [31:0] Q, input CLK, input CEN, input WEN,
	input [8:0]   A, input [31:0] D, input [2:0] EMA
);
	TS1N16FFCLLULVTA512X32M8SWBSHO u_mem (
		.CLK(CLK), .CEB(CEN), .WEB(WEN), .A(A), .D(D), .Q(Q),
		.BWEB({32{1'b0}}),
		.SLP(1'b0), .DSLP(1'b0), .SD(1'b0), .PUDELAY(),
		.CEBM(1'b1), .WEBM(1'b1), .AM(9'b0), .DM(32'b0), .BWEBM({32{1'b1}}),
		.BIST(1'b0), .RTSEL(2'b01), .WTSEL(2'b01)
	);
endmodule

// ---------------------------------------------------------------- OT_SRAM ---
//  4096 x 64 single-port.  Only the low 64 addresses are actually used
//  (cfg_ot_rnd_finsub1 = 63), but the address bus is 12-bit.
module OT_SRAM (
	output [63:0] Q, input CLK, input CEN, input WEN,
	input [11:0]  A, input [63:0] D, input [2:0] EMA
);
	TS1N16FFCLLULVTA4096X64M8SWBSHO u_mem (
		.CLK(CLK), .CEB(CEN), .WEB(WEN), .A(A), .D(D), .Q(Q),
		.BWEB({64{1'b0}}),
		.SLP(1'b0), .DSLP(1'b0), .SD(1'b0), .PUDELAY(),
		.CEBM(1'b1), .WEBM(1'b1), .AM(12'b0), .DM(64'b0), .BWEBM({64{1'b1}}),
		.BIST(1'b0), .RTSEL(2'b01), .WTSEL(2'b01)
	);
endmodule
