// ============================================================================
//  CHIP.v -- pad-ring wrapper for Transformer_top (full-chip ADFP deliverable)
//
//  Reconstructed from the senior's ~/2026_SOC_ADFP/design/src/CHIP.v, whose
//  inner block (tfcnn_top) has exactly Transformer_top's port list. On the
//  school box the ONE change to his file is:
//        tfcnn_top  tfcnn_top_1(      ->      Transformer_top  Transformer_top_1(
//
//  Pad-side names follow his:  V/R/D/L = TVALID / TREADY / TDATA / TLAST,
//  _in = MM2S (into the chip), _out = S2MM (out of the chip), AC = clock,
//  ARESET = active-low reset. TKEEP has no pads (16 pins saved); nothing
//  below the top ever reads it.
//
//  Pad cells: N16ADFP_StdIO PDCDG_V (top/bottom) and PDCDG_H (left/right).
//      input  pad: .OEN(1'b1) .IE(1'b1) .I(1'b0)  .PAD(pin)  .C(core)
//      output pad: .OEN(1'b0) .IE(1'b0) .I(core)  .PAD(pin)  .C()
//  136 signal pads, 34 per side:
//      top    (V): AC, ARESET, D_in[0:31]
//      left   (H): D_in[32:63], V_in, L_in
//      bottom (V): D_out[0:33]
//      right  (H): R_in, D_out[34:63], L_out, V_out, R_out
//
//  POWER / GROUND / CORNER pads are NOT reproduced here - take them from the
//  senior's file (PVDD1CDGM_*, PVDD2CDGM_*, PVSS*, corner cells). This copy is
//  for the repo record and for local pad-stub simulation; the school build
//  uses his file with the one-line swap above.
// ============================================================================
module CHIP(
        V_in    ,
        R_in    ,
        D_in    ,
        L_in    ,
        V_out   ,
        R_out   ,
        D_out   ,
        L_out   ,
        AC      ,
        ARESET
);

parameter TBITS_64BITS  = 64 ,
          TBYTES_8BITS  = 8  ;

//--------------- input & output ---------------//
    input                       V_in    ;
    input                       R_in    ;   // s2mm TREADY, from outside
    input  [TBITS_64BITS-1:0]   D_in    ;
    input                       L_in    ;
    output                      V_out   ;
    output                      R_out   ;   // mm2s TREADY, to outside
    output [TBITS_64BITS-1:0]   D_out   ;
    output                      L_out   ;
    input                       AC      ;
    input                       ARESET  ;

//--------------- core-side wires ---------------//
    wire                        i_V     ;
    wire                        i_R     ;
    wire   [TBITS_64BITS-1:0]   i_D     ;
    wire                        i_L     ;
    wire                        o_R     ;
    wire                        o_V     ;
    wire   [TBITS_64BITS-1:0]   o_D     ;
    wire                        o_L     ;
    wire                        i_clk   ;
    wire                        i_reset ;
//----------------------------------------------//

    Transformer_top  Transformer_top_1(
            .clk                (   i_clk   )
        ,   .resetn             (   i_reset )

        ,   .S_AXIS_MM2S_TVALID (   i_V     )
        ,   .S_AXIS_MM2S_TREADY (   o_R     )
        ,   .S_AXIS_MM2S_TDATA  (   i_D     )
        ,   .S_AXIS_MM2S_TKEEP  (   8'hff   )   // no pad; all bytes valid
        ,   .S_AXIS_MM2S_TLAST  (   i_L     )

        ,   .M_AXIS_S2MM_TVALID (   o_V     )
        ,   .M_AXIS_S2MM_TREADY (   i_R     )
        ,   .M_AXIS_S2MM_TDATA  (   o_D     )
        ,   .M_AXIS_S2MM_TKEEP  (           )   // no pad
        ,   .M_AXIS_S2MM_TLAST  (   o_L     )
    );

//top
    PDCDG_V ipad_ACLK   (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (AC),     .C(i_clk))   ;
    PDCDG_V ipad_ARESET (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (ARESET), .C(i_reset)) ;
    PDCDG_V ipad_D0     (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[0]), .C(i_D[0])) ;
    PDCDG_V ipad_D1     (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[1]), .C(i_D[1])) ;
    PDCDG_V ipad_D2     (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[2]), .C(i_D[2])) ;
    PDCDG_V ipad_D3     (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[3]), .C(i_D[3])) ;
    PDCDG_V ipad_D4     (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[4]), .C(i_D[4])) ;
    PDCDG_V ipad_D5     (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[5]), .C(i_D[5])) ;
    PDCDG_V ipad_D6     (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[6]), .C(i_D[6])) ;
    PDCDG_V ipad_D7     (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[7]), .C(i_D[7])) ;
    PDCDG_V ipad_D8     (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[8]), .C(i_D[8])) ;
    PDCDG_V ipad_D9     (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[9]), .C(i_D[9])) ;
    PDCDG_V ipad_D10    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[10]), .C(i_D[10])) ;
    PDCDG_V ipad_D11    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[11]), .C(i_D[11])) ;
    PDCDG_V ipad_D12    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[12]), .C(i_D[12])) ;
    PDCDG_V ipad_D13    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[13]), .C(i_D[13])) ;
    PDCDG_V ipad_D14    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[14]), .C(i_D[14])) ;
    PDCDG_V ipad_D15    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[15]), .C(i_D[15])) ;
    PDCDG_V ipad_D16    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[16]), .C(i_D[16])) ;
    PDCDG_V ipad_D17    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[17]), .C(i_D[17])) ;
    PDCDG_V ipad_D18    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[18]), .C(i_D[18])) ;
    PDCDG_V ipad_D19    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[19]), .C(i_D[19])) ;
    PDCDG_V ipad_D20    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[20]), .C(i_D[20])) ;
    PDCDG_V ipad_D21    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[21]), .C(i_D[21])) ;
    PDCDG_V ipad_D22    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[22]), .C(i_D[22])) ;
    PDCDG_V ipad_D23    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[23]), .C(i_D[23])) ;
    PDCDG_V ipad_D24    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[24]), .C(i_D[24])) ;
    PDCDG_V ipad_D25    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[25]), .C(i_D[25])) ;
    PDCDG_V ipad_D26    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[26]), .C(i_D[26])) ;
    PDCDG_V ipad_D27    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[27]), .C(i_D[27])) ;
    PDCDG_V ipad_D28    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[28]), .C(i_D[28])) ;
    PDCDG_V ipad_D29    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[29]), .C(i_D[29])) ;
    PDCDG_V ipad_D30    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[30]), .C(i_D[30])) ;
    PDCDG_V ipad_D31    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[31]), .C(i_D[31])) ;

//Left
    PDCDG_H ipad_D32    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[32]), .C(i_D[32])) ;
    PDCDG_H ipad_D33    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[33]), .C(i_D[33])) ;
    PDCDG_H ipad_D34    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[34]), .C(i_D[34])) ;
    PDCDG_H ipad_D35    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[35]), .C(i_D[35])) ;
    PDCDG_H ipad_D36    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[36]), .C(i_D[36])) ;
    PDCDG_H ipad_D37    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[37]), .C(i_D[37])) ;
    PDCDG_H ipad_D38    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[38]), .C(i_D[38])) ;
    PDCDG_H ipad_D39    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[39]), .C(i_D[39])) ;
    PDCDG_H ipad_D40    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[40]), .C(i_D[40])) ;
    PDCDG_H ipad_D41    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[41]), .C(i_D[41])) ;
    PDCDG_H ipad_D42    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[42]), .C(i_D[42])) ;
    PDCDG_H ipad_D43    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[43]), .C(i_D[43])) ;
    PDCDG_H ipad_D44    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[44]), .C(i_D[44])) ;
    PDCDG_H ipad_D45    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[45]), .C(i_D[45])) ;
    PDCDG_H ipad_D46    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[46]), .C(i_D[46])) ;
    PDCDG_H ipad_D47    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[47]), .C(i_D[47])) ;
    PDCDG_H ipad_D48    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[48]), .C(i_D[48])) ;
    PDCDG_H ipad_D49    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[49]), .C(i_D[49])) ;
    PDCDG_H ipad_D50    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[50]), .C(i_D[50])) ;
    PDCDG_H ipad_D51    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[51]), .C(i_D[51])) ;
    PDCDG_H ipad_D52    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[52]), .C(i_D[52])) ;
    PDCDG_H ipad_D53    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[53]), .C(i_D[53])) ;
    PDCDG_H ipad_D54    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[54]), .C(i_D[54])) ;
    PDCDG_H ipad_D55    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[55]), .C(i_D[55])) ;
    PDCDG_H ipad_D56    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[56]), .C(i_D[56])) ;
    PDCDG_H ipad_D57    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[57]), .C(i_D[57])) ;
    PDCDG_H ipad_D58    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[58]), .C(i_D[58])) ;
    PDCDG_H ipad_D59    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[59]), .C(i_D[59])) ;
    PDCDG_H ipad_D60    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[60]), .C(i_D[60])) ;
    PDCDG_H ipad_D61    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[61]), .C(i_D[61])) ;
    PDCDG_H ipad_D62    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[62]), .C(i_D[62])) ;
    PDCDG_H ipad_D63    (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (D_in[63]), .C(i_D[63])) ;
    PDCDG_H ipad_MM2S_TVALID (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (V_in), .C(i_V)) ;
    PDCDG_H ipad_MM2S_TLAST  (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (L_in), .C(i_L)) ;

//Bottom
    PDCDG_V opad_D0     (.OEN (1'b0), .IE (1'b0), .I (o_D[0]), .PAD (D_out[0]), .C()) ;
    PDCDG_V opad_D1     (.OEN (1'b0), .IE (1'b0), .I (o_D[1]), .PAD (D_out[1]), .C()) ;
    PDCDG_V opad_D2     (.OEN (1'b0), .IE (1'b0), .I (o_D[2]), .PAD (D_out[2]), .C()) ;
    PDCDG_V opad_D3     (.OEN (1'b0), .IE (1'b0), .I (o_D[3]), .PAD (D_out[3]), .C()) ;
    PDCDG_V opad_D4     (.OEN (1'b0), .IE (1'b0), .I (o_D[4]), .PAD (D_out[4]), .C()) ;
    PDCDG_V opad_D5     (.OEN (1'b0), .IE (1'b0), .I (o_D[5]), .PAD (D_out[5]), .C()) ;
    PDCDG_V opad_D6     (.OEN (1'b0), .IE (1'b0), .I (o_D[6]), .PAD (D_out[6]), .C()) ;
    PDCDG_V opad_D7     (.OEN (1'b0), .IE (1'b0), .I (o_D[7]), .PAD (D_out[7]), .C()) ;
    PDCDG_V opad_D8     (.OEN (1'b0), .IE (1'b0), .I (o_D[8]), .PAD (D_out[8]), .C()) ;
    PDCDG_V opad_D9     (.OEN (1'b0), .IE (1'b0), .I (o_D[9]), .PAD (D_out[9]), .C()) ;
    PDCDG_V opad_D10    (.OEN (1'b0), .IE (1'b0), .I (o_D[10]), .PAD (D_out[10]), .C()) ;
    PDCDG_V opad_D11    (.OEN (1'b0), .IE (1'b0), .I (o_D[11]), .PAD (D_out[11]), .C()) ;
    PDCDG_V opad_D12    (.OEN (1'b0), .IE (1'b0), .I (o_D[12]), .PAD (D_out[12]), .C()) ;
    PDCDG_V opad_D13    (.OEN (1'b0), .IE (1'b0), .I (o_D[13]), .PAD (D_out[13]), .C()) ;
    PDCDG_V opad_D14    (.OEN (1'b0), .IE (1'b0), .I (o_D[14]), .PAD (D_out[14]), .C()) ;
    PDCDG_V opad_D15    (.OEN (1'b0), .IE (1'b0), .I (o_D[15]), .PAD (D_out[15]), .C()) ;
    PDCDG_V opad_D16    (.OEN (1'b0), .IE (1'b0), .I (o_D[16]), .PAD (D_out[16]), .C()) ;
    PDCDG_V opad_D17    (.OEN (1'b0), .IE (1'b0), .I (o_D[17]), .PAD (D_out[17]), .C()) ;
    PDCDG_V opad_D18    (.OEN (1'b0), .IE (1'b0), .I (o_D[18]), .PAD (D_out[18]), .C()) ;
    PDCDG_V opad_D19    (.OEN (1'b0), .IE (1'b0), .I (o_D[19]), .PAD (D_out[19]), .C()) ;
    PDCDG_V opad_D20    (.OEN (1'b0), .IE (1'b0), .I (o_D[20]), .PAD (D_out[20]), .C()) ;
    PDCDG_V opad_D21    (.OEN (1'b0), .IE (1'b0), .I (o_D[21]), .PAD (D_out[21]), .C()) ;
    PDCDG_V opad_D22    (.OEN (1'b0), .IE (1'b0), .I (o_D[22]), .PAD (D_out[22]), .C()) ;
    PDCDG_V opad_D23    (.OEN (1'b0), .IE (1'b0), .I (o_D[23]), .PAD (D_out[23]), .C()) ;
    PDCDG_V opad_D24    (.OEN (1'b0), .IE (1'b0), .I (o_D[24]), .PAD (D_out[24]), .C()) ;
    PDCDG_V opad_D25    (.OEN (1'b0), .IE (1'b0), .I (o_D[25]), .PAD (D_out[25]), .C()) ;
    PDCDG_V opad_D26    (.OEN (1'b0), .IE (1'b0), .I (o_D[26]), .PAD (D_out[26]), .C()) ;
    PDCDG_V opad_D27    (.OEN (1'b0), .IE (1'b0), .I (o_D[27]), .PAD (D_out[27]), .C()) ;
    PDCDG_V opad_D28    (.OEN (1'b0), .IE (1'b0), .I (o_D[28]), .PAD (D_out[28]), .C()) ;
    PDCDG_V opad_D29    (.OEN (1'b0), .IE (1'b0), .I (o_D[29]), .PAD (D_out[29]), .C()) ;
    PDCDG_V opad_D30    (.OEN (1'b0), .IE (1'b0), .I (o_D[30]), .PAD (D_out[30]), .C()) ;
    PDCDG_V opad_D31    (.OEN (1'b0), .IE (1'b0), .I (o_D[31]), .PAD (D_out[31]), .C()) ;
    PDCDG_V opad_D32    (.OEN (1'b0), .IE (1'b0), .I (o_D[32]), .PAD (D_out[32]), .C()) ;
    PDCDG_V opad_D33    (.OEN (1'b0), .IE (1'b0), .I (o_D[33]), .PAD (D_out[33]), .C()) ;

//Right
    PDCDG_H ipad_S2MM_TREADY (.OEN (1'b1), .IE (1'b1), .I (1'b0), .PAD (R_in), .C(i_R)) ;
    PDCDG_H opad_D34    (.OEN (1'b0), .IE (1'b0), .I (o_D[34]), .PAD (D_out[34]), .C()) ;
    PDCDG_H opad_D35    (.OEN (1'b0), .IE (1'b0), .I (o_D[35]), .PAD (D_out[35]), .C()) ;
    PDCDG_H opad_D36    (.OEN (1'b0), .IE (1'b0), .I (o_D[36]), .PAD (D_out[36]), .C()) ;
    PDCDG_H opad_D37    (.OEN (1'b0), .IE (1'b0), .I (o_D[37]), .PAD (D_out[37]), .C()) ;
    PDCDG_H opad_D38    (.OEN (1'b0), .IE (1'b0), .I (o_D[38]), .PAD (D_out[38]), .C()) ;
    PDCDG_H opad_D39    (.OEN (1'b0), .IE (1'b0), .I (o_D[39]), .PAD (D_out[39]), .C()) ;
    PDCDG_H opad_D40    (.OEN (1'b0), .IE (1'b0), .I (o_D[40]), .PAD (D_out[40]), .C()) ;
    PDCDG_H opad_D41    (.OEN (1'b0), .IE (1'b0), .I (o_D[41]), .PAD (D_out[41]), .C()) ;
    PDCDG_H opad_D42    (.OEN (1'b0), .IE (1'b0), .I (o_D[42]), .PAD (D_out[42]), .C()) ;
    PDCDG_H opad_D43    (.OEN (1'b0), .IE (1'b0), .I (o_D[43]), .PAD (D_out[43]), .C()) ;
    PDCDG_H opad_D44    (.OEN (1'b0), .IE (1'b0), .I (o_D[44]), .PAD (D_out[44]), .C()) ;
    PDCDG_H opad_D45    (.OEN (1'b0), .IE (1'b0), .I (o_D[45]), .PAD (D_out[45]), .C()) ;
    PDCDG_H opad_D46    (.OEN (1'b0), .IE (1'b0), .I (o_D[46]), .PAD (D_out[46]), .C()) ;
    PDCDG_H opad_D47    (.OEN (1'b0), .IE (1'b0), .I (o_D[47]), .PAD (D_out[47]), .C()) ;
    PDCDG_H opad_D48    (.OEN (1'b0), .IE (1'b0), .I (o_D[48]), .PAD (D_out[48]), .C()) ;
    PDCDG_H opad_D49    (.OEN (1'b0), .IE (1'b0), .I (o_D[49]), .PAD (D_out[49]), .C()) ;
    PDCDG_H opad_D50    (.OEN (1'b0), .IE (1'b0), .I (o_D[50]), .PAD (D_out[50]), .C()) ;
    PDCDG_H opad_D51    (.OEN (1'b0), .IE (1'b0), .I (o_D[51]), .PAD (D_out[51]), .C()) ;
    PDCDG_H opad_D52    (.OEN (1'b0), .IE (1'b0), .I (o_D[52]), .PAD (D_out[52]), .C()) ;
    PDCDG_H opad_D53    (.OEN (1'b0), .IE (1'b0), .I (o_D[53]), .PAD (D_out[53]), .C()) ;
    PDCDG_H opad_D54    (.OEN (1'b0), .IE (1'b0), .I (o_D[54]), .PAD (D_out[54]), .C()) ;
    PDCDG_H opad_D55    (.OEN (1'b0), .IE (1'b0), .I (o_D[55]), .PAD (D_out[55]), .C()) ;
    PDCDG_H opad_D56    (.OEN (1'b0), .IE (1'b0), .I (o_D[56]), .PAD (D_out[56]), .C()) ;
    PDCDG_H opad_D57    (.OEN (1'b0), .IE (1'b0), .I (o_D[57]), .PAD (D_out[57]), .C()) ;
    PDCDG_H opad_D58    (.OEN (1'b0), .IE (1'b0), .I (o_D[58]), .PAD (D_out[58]), .C()) ;
    PDCDG_H opad_D59    (.OEN (1'b0), .IE (1'b0), .I (o_D[59]), .PAD (D_out[59]), .C()) ;
    PDCDG_H opad_D60    (.OEN (1'b0), .IE (1'b0), .I (o_D[60]), .PAD (D_out[60]), .C()) ;
    PDCDG_H opad_D61    (.OEN (1'b0), .IE (1'b0), .I (o_D[61]), .PAD (D_out[61]), .C()) ;
    PDCDG_H opad_D62    (.OEN (1'b0), .IE (1'b0), .I (o_D[62]), .PAD (D_out[62]), .C()) ;
    PDCDG_H opad_D63    (.OEN (1'b0), .IE (1'b0), .I (o_D[63]), .PAD (D_out[63]), .C()) ;
    PDCDG_H opad_S2MM_TLAST  (.OEN (1'b0), .IE (1'b0), .I (o_L), .PAD (L_out), .C()) ;
    PDCDG_H opad_S2MM_TVALID (.OEN (1'b0), .IE (1'b0), .I (o_V), .PAD (V_out), .C()) ;
    PDCDG_H opad_MM2S_TREADY (.OEN (1'b0), .IE (1'b0), .I (o_R), .PAD (R_out), .C()) ;

//  power / ground / corner pads: see header - copy from the senior's CHIP.v

endmodule
