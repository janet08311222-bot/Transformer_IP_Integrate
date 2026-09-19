`timescale 1ns/1ps
// ============================================================================
//  N16FFC SRAM macro behavioural stubs - LOCAL ELABORATION / SIM ONLY.
//
//  The four TSMC N16FFC macros the two SRAM wrapper files instantiate. On the
//  school box the real models come from the PDK's sram_dir and this file is
//  NOT compiled; here they let the +define+ASIC path elaborate and run under
//  xsim so wiring and guard errors are caught before going to school.
//
//  Three are copied from the SA 2-row package (sim_xsim/n16_macro_stubs.v).
//  TS1N16FFCLLULVTA512X64M8SWBSHO is FFN's 512x64 single-port and was not in
//  that package; it is the 512X32 one widened to 64.
//
//  Behaviour: active-low CEB/WEB, synchronous read (Q one cycle after A),
//  write-through on the same port. BWEB / BIST / margin pins are ignored.
// ============================================================================

module TSDN16FFCLLULVTA512X64M4WBSHO (
	input         CLKA, input CEBA, input WEBA, input [8:0] AA, input [63:0] DA,
	output reg [63:0] QA, input [63:0] BWEBA,
	input         CLKB, input CEBB, input WEBB, input [8:0] AB, input [63:0] DB,
	output reg [63:0] QB, input [63:0] BWEBB,
	input CEBMA, input WEBMA, input [8:0] AMA, input [63:0] DMA, input [63:0] BWEBMA,
	input CEBMB, input WEBMB, input [8:0] AMB, input [63:0] DMB, input [63:0] BWEBMB,
	input SD, input SLP, input DSLP, output PUDELAY, input BIST,
	input CLKM, input [1:0] RTSEL, input [1:0] WTSEL
);
	reg [63:0] mem [0:511];
	integer ii;
	initial begin
		for (ii = 0; ii < 512; ii = ii + 1) mem[ii] = 64'd0;
		QA = 64'd0; QB = 64'd0;
	end
	assign PUDELAY = 1'b0;
	always @(posedge CLKA) begin
		if (!CEBA) begin
			if (!WEBA) mem[AA] <= DA;
			QA <= mem[AA];
		end
	end
	always @(posedge CLKB) begin
		if (!CEBB) begin
			if (!WEBB) mem[AB] <= DB;
			QB <= mem[AB];
		end
	end
endmodule

module TS1N16FFCLLULVTA4096X64M8SWBSHO (
	input CLK, input CEB, input WEB, input [11:0] A, input [63:0] D,
	output reg [63:0] Q, input [63:0] BWEB,
	input SLP, input DSLP, input SD, output PUDELAY,
	input CEBM, input WEBM, input [11:0] AM, input [63:0] DM, input [63:0] BWEBM,
	input BIST, input [1:0] RTSEL, input [1:0] WTSEL
);
	reg [63:0] mem [0:4095];
	integer ii;
	initial begin
		for (ii = 0; ii < 4096; ii = ii + 1) mem[ii] = 64'd0;
		Q = 64'd0;
	end
	assign PUDELAY = 1'b0;
	always @(posedge CLK) begin
		if (!CEB) begin
			if (!WEB) mem[A] <= D;
			Q <= mem[A];
		end
	end
endmodule

module TS1N16FFCLLULVTA512X32M8SWBSHO (
	input CLK, input CEB, input WEB, input [8:0] A, input [31:0] D,
	output reg [31:0] Q, input [31:0] BWEB,
	input SLP, input DSLP, input SD, output PUDELAY,
	input CEBM, input WEBM, input [8:0] AM, input [31:0] DM, input [31:0] BWEBM,
	input BIST, input [1:0] RTSEL, input [1:0] WTSEL
);
	reg [31:0] mem [0:511];
	integer ii;
	initial begin
		for (ii = 0; ii < 512; ii = ii + 1) mem[ii] = 32'd0;
		Q = 32'd0;
	end
	assign PUDELAY = 1'b0;
	always @(posedge CLK) begin
		if (!CEB) begin
			if (!WEB) mem[A] <= D;
			Q <= mem[A];
		end
	end
endmodule

// ---- FFN 512x64 single-port (derived from the 512X32 stub above) ----
module TS1N16FFCLLULVTA512X64M8SWBSHO (
	input CLK, input CEB, input WEB, input [8:0] A, input [63:0] D,
	output reg [63:0] Q, input [63:0] BWEB,
	input SLP, input DSLP, input SD, output PUDELAY,
	input CEBM, input WEBM, input [8:0] AM, input [63:0] DM, input [63:0] BWEBM,
	input BIST, input [1:0] RTSEL, input [1:0] WTSEL
);
	reg [63:0] mem [0:511];
	integer ii;
	initial begin
		for (ii = 0; ii < 512; ii = ii + 1) mem[ii] = 64'd0;
		Q = 64'd0;
	end
	assign PUDELAY = 1'b0;
	always @(posedge CLK) begin
		if (!CEB) begin
			if (!WEB) mem[A] <= D;
			Q <= mem[A];
		end
	end
endmodule
