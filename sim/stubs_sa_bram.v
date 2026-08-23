// ============================================================================
// Behavioural stand-ins for the Xilinx Block-Memory-Generator IPs used when
// `FPGA_SRAM_SETTING is defined.  1-clock read latency, byte-wide `wea`,
// active-high `ena`, exactly like the "no output register" BMG configuration.
// ============================================================================
`timescale 1ns/100ps

// True dual port: the real blk_mem_gen core always exposes web/dinb, so the
// stub does too (they are tied off at the instantiation in SA if_top).
module BRAM_IF (
	input  wire        clka ,
	input  wire        clkb ,
	input  wire        ena  ,
	input  wire        enb  ,
	input  wire        wea  ,
	input  wire        web  ,
	input  wire [9:0]  addra,
	input  wire [9:0]  addrb,
	input  wire [63:0] dina ,
	input  wire [63:0] dinb ,
	output reg  [63:0] douta,
	output reg  [63:0] doutb
);
	reg [63:0] mem [0:1023];
	integer ii;
	initial begin
		for (ii = 0; ii < 1024; ii = ii + 1) mem[ii] = 64'd0;
		douta = 64'd0; doutb = 64'd0;
	end
	always @(posedge clka) begin
		if (ena) begin
			if (wea) mem[addra] <= dina;
			douta <= mem[addra];
		end
	end
	always @(posedge clkb) begin
		if (enb) begin
			if (web) mem[addrb] <= dinb;
			doutb <= mem[addrb];
		end
	end
endmodule

module BRAM_KER (
	input  wire        clka ,
	input  wire        ena  ,
	input  wire        wea  ,
	input  wire [11:0] addra,
	input  wire [63:0] dina ,
	output reg  [63:0] douta
);
	reg [63:0] mem [0:4095];
	integer ii;
	initial begin
		for (ii = 0; ii < 4096; ii = ii + 1) mem[ii] = 64'd0;
		douta = 64'd0;
	end
	always @(posedge clka) begin
		if (ena) begin
			if (wea) mem[addra] <= dina;
			douta <= mem[addra];
		end
	end
endmodule

module BRAM_BIAS (
	input  wire        clka ,
	input  wire        ena  ,
	input  wire        wea  ,
	input  wire [8:0]  addra,
	input  wire [31:0] dina ,
	output reg  [31:0] douta
);
	reg [31:0] mem [0:511];
	integer ii;
	initial begin
		for (ii = 0; ii < 512; ii = ii + 1) mem[ii] = 32'd0;
		douta = 32'd0;
	end
	always @(posedge clka) begin
		if (ena) begin
			if (wea) mem[addra] <= dina;
			douta <= mem[addra];
		end
	end
endmodule

module BRAM_OT (
	input  wire        clka ,
	input  wire        ena  ,
	input  wire        wea  ,
	input  wire [11:0] addra,
	input  wire [63:0] dina ,
	output reg  [63:0] douta
);
	reg [63:0] mem [0:4095];
	integer ii;
	initial begin
		for (ii = 0; ii < 4096; ii = ii + 1) mem[ii] = 64'd0;
		douta = 64'd0;
	end
	always @(posedge clka) begin
		if (ena) begin
			if (wea) mem[addra] <= dina;
			douta <= mem[addra];
		end
	end
endmodule
