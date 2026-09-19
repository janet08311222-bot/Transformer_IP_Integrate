// ============================================================================
//  FFN ADFP SRAM wrappers  (N16FFC memory-compiler macros, block-level) -- FILLED
// ----------------------------------------------------------------------------
//  Bridges the generic SRAM names the FFN RTL (ASIC branch) instantiates to the
//  real N16FFC macros in sram_dir. Matched by PORT TYPE + SIZE (NOT folder name;
//  sram_dir's SRAM_I is dual and SRAM_W is single -- opposite to FFN's need):
//     IF_SRAM  (1-port 512x64) -> TS1N16FFCLLULVTA512X64M8SWBSHO   (sram_dir/SRAM_W)
//     KER_SRAM (2-port 512x64) -> TSDN16FFCLLULVTA512X64M4WBSHO    (sram_dir/SRAM_I)
//     BIAS_SRAM(1-port 512x32) -> TS1N16FFCLLULVTA512X32M8SWBSHO   (sram_dir/BIAS_SRAM)
//     OT_SRAM  (1-port 512x64) -> TS1N16FFCLLULVTA4096X64M8SWBSHO  (sram_dir/OT_SRAM; use low 512)
//
//  Pin mapping:  CEN->CEB, WEN->WEB (both active-low). BWEB all-0 = write every bit.
//  BIST/margin port disabled (CEBM/WEBM=1, BIST=0); sleep off; RTSEL/WTSEL=2'b01;
//  PUDELAY left open (per lab reference). EMA (wrapper input) is unused by N16FFC.
//  If VCS flags one pin (e.g. RTSEL width), fix just that line.
// ============================================================================

`timescale 1ns/1ps

// ------------------------------------------------------------------ IF_SRAM
//  512 x 64 single-port
module FFN_IF_SRAM (
      output [63:0] Q, input CLK, input CEN, input WEN,
      input  [8:0]  A, input [63:0] D, input [2:0] EMA
);
    TS1N16FFCLLULVTA512X64M8SWBSHO u_mem (
        .CLK(CLK), .CEB(CEN), .WEB(WEN), .A(A), .D(D), .Q(Q),
        .BWEB({64{1'b0}}),
        .SLP(1'b0), .DSLP(1'b0), .SD(1'b0), .PUDELAY(),
        .CEBM(1'b1), .WEBM(1'b1), .AM(9'b0), .DM(64'b0), .BWEBM({64{1'b1}}),
        .BIST(1'b0), .RTSEL(2'b01), .WTSEL(2'b01)
    );
endmodule

// ------------------------------------------------------------------ BIAS_SRAM
//  512 x 32 single-port
module FFN_BIAS_SRAM (
      output [31:0] Q, input CLK, input CEN, input WEN,
      input  [8:0]  A, input [31:0] D, input [2:0] EMA
);
    TS1N16FFCLLULVTA512X32M8SWBSHO u_mem (
        .CLK(CLK), .CEB(CEN), .WEB(WEN), .A(A), .D(D), .Q(Q),
        .BWEB({32{1'b0}}),
        .SLP(1'b0), .DSLP(1'b0), .SD(1'b0), .PUDELAY(),
        .CEBM(1'b1), .WEBM(1'b1), .AM(9'b0), .DM(32'b0), .BWEBM({32{1'b1}}),
        .BIST(1'b0), .RTSEL(2'b01), .WTSEL(2'b01)
    );
endmodule

// ------------------------------------------------------------------ OT_SRAM
//  FFN needs 512 x 64; the available macro is 4096 x 64 -> zero-extend addr
module FFN_OT_SRAM (
      output [63:0] Q, input CLK, input CEN, input WEN,
      input  [8:0]  A, input [63:0] D, input [2:0] EMA
);
    TS1N16FFCLLULVTA4096X64M8SWBSHO u_mem (
        .CLK(CLK), .CEB(CEN), .WEB(WEN), .A({3'b000, A}), .D(D), .Q(Q),
        .BWEB({64{1'b0}}),
        .SLP(1'b0), .DSLP(1'b0), .SD(1'b0), .PUDELAY(),
        .CEBM(1'b1), .WEBM(1'b1), .AM(12'b0), .DM(64'b0), .BWEBM({64{1'b1}}),
        .BIST(1'b0), .RTSEL(2'b01), .WTSEL(2'b01)
    );
endmodule

// ------------------------------------------------------------------ KER_SRAM
//  512 x 64 dual-port : port A = write, port B = read
module FFN_KER_SRAM (
      input        CLKA, input CENA, input WENA, input [8:0] AA, input [63:0] DA,
      input        CLKB, input CENB, input WENB, input [8:0] AB, output [63:0] QB,
      input  [2:0] EMAA, input [2:0] EMAB
);
    TSDN16FFCLLULVTA512X64M4WBSHO u_mem (
        // port A -- write (QA unused)
        .CLKA(CLKA), .CEBA(CENA), .WEBA(WENA), .AA(AA), .DA(DA), .QA(),
        .BWEBA({64{1'b0}}),
        // port B -- read (DB tied off)
        .CLKB(CLKB), .CEBB(CENB), .WEBB(WENB), .AB(AB), .DB(64'b0), .QB(QB),
        .BWEBB({64{1'b1}}),
        // BIST / margin port A (disabled)
        .CEBMA(1'b1), .WEBMA(1'b1), .AMA(9'b0), .DMA(64'b0), .BWEBMA({64{1'b1}}),
        // BIST / margin port B (disabled)
        .CEBMB(1'b1), .WEBMB(1'b1), .AMB(9'b0), .DMB(64'b0), .BWEBMB({64{1'b1}}),
        // common
        .SD(1'b0), .SLP(1'b0), .DSLP(1'b0), .PUDELAY(), .BIST(1'b0),
        .CLKM(1'b0), .RTSEL(2'b01), .WTSEL(2'b01)
    );
endmodule
