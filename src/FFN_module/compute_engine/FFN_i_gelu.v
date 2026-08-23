// ============================================================================
// Designer : (Phase 3) I-BERT integer GELU
// Func     : Integer i-GELU activation for the FFN datapath.
//            Sits between the FFN dense result (bfm0 = MAC+bias - actsum*z_w,
//            i.e. FFN_quan2uint8's `bfm0`) and the uint8 output requantize.
//            Mirrors I-BERT IntGELU (kssteven418/I-BERT, fairseq quant_modules.py):
//                GELU(x) = x * 1/2 * (1 + erf(x/sqrt2)),
//                erf approximated by 2nd-order poly: sign*((|x|+b)^2 + c).
//            Bit-exact to tools/ffn_igelu_ref.c (golden: FFN1_igelu_out.dat).
//
//   Pipeline (one major op per stage; arithmetic >> everywhere, signed):
//     S1  xq   = bfm0 >>> P            (P=16 -> xq is exactly int16)
//     S2  ab   = |xq| ; clamp ab to (-b_int)
//     S3  t    = ab + b_int            (<=0)
//     S4  sq   = t*t                   (mult #1)
//     S5  inner= sq + c_int ; y = sign? -inner : inner
//     S6  sig  = y >>> N (N=14) ; g = sig + shift_int
//     S7  out  = xq * g                (mult #2)        <- i-GELU integer output
//     S8  oi2  = rsign? -out : out ; prod = oi2 * m0g   (mult #3, requantize)
//     S9  q    = prod >>> SHG ; saturate to uint8 [0,255]
//
//   Constants (CFG inputs, computed offline from the dense-output scale S):
//     b_int = floor(b / (S/sqrt2)),  b=-1.769
//     c_int = floor((1/a) / (S/sqrt2)^2),  a=-0.2888
//     shift_int = floor(1 / (S/sqrt2)^2 * a * 2^N)
//     m0g, rsign, SHG : output requantize (S_out_gelu)
//   For S = 2^-12 (b2 self-consistent ref):
//     b_int=-10248  c_int=-116185707  shift_int=-7092  m0g=1178 rsign=1 SHG=31
//   Keep these as INPUTS (not hardcoded) so a real I-BERT model's scale can be
//   loaded post-layout without changing the RTL.
//
//   ASIC/FPGA neutral: plain synthesizable RTL, no vendor primitives/attrs.
// ============================================================================

module FFN_i_gelu #(
    parameter IN_BITS   = 32,   // bfm0 width (signed)
    parameter P_SHIFT   = 16,   // pre-shift: xq = bfm0 >>> P_SHIFT
    parameter XQ_BITS   = 16,   // xq width after the shift (IN_BITS-P_SHIFT)
    parameter N_SHIFT   = 14,   // i-GELU internal shift (I-BERT n)
    parameter ACC_BITS  = 32,   // sq / inner / out width (>= ~2^29 -> 32 ok)
    parameter M0_BITS   = 18,   // requantize multiplier width
    parameter SHG       = 31    // requantize shift
)(
        clk
    ,   reset
    ,   valid_in
    ,   bfm0            // signed [IN_BITS-1:0]  dense output (post zero-point)
    // ---- CFG constants (programmable) ----
    ,   b_int           // signed [XQ_BITS-1:0]   (-10248)
    ,   c_int           // signed [ACC_BITS-1:0]  (-116185707)
    ,   shift_int       // signed [XQ_BITS-1:0]   (-7092)
    ,   m0g             // unsigned [M0_BITS-1:0] (1178)
    ,   rsign           // 1: negate before requant (out scale < 0)
    // ---- output ----
    ,   valid_out
    ,   q_out           // [7:0] uint8
);
    input                          clk, reset, valid_in;
    input  signed [IN_BITS-1:0]    bfm0;
    input  signed [XQ_BITS-1:0]    b_int;
    input  signed [ACC_BITS-1:0]   c_int;
    input  signed [XQ_BITS-1:0]    shift_int;
    input         [M0_BITS-1:0]    m0g;
    input                          rsign;
    output reg                     valid_out;
    output reg    [7:0]            q_out;

    // ---- valid pipeline: q_out has 9-cycle latency (8 vld regs + 1 valid_out reg) ----
    reg [7:0] vld;
    always @(posedge clk) begin
        if(reset) vld <= 8'd0;
        else      vld <= {vld[6:0], valid_in};
    end
    always @(posedge clk) valid_out <= reset ? 1'b0 : vld[7];

    // ===================== S1 : xq = bfm0 >>> P =====================
    // bfm0 is IN_BITS signed; >>> P_SHIFT yields exactly XQ_BITS signed.
    reg signed [XQ_BITS-1:0] s1_xq;
    reg                      s1_sign;
    always @(posedge clk) begin
        s1_xq   <= bfm0 >>> P_SHIFT;
        s1_sign <= bfm0[IN_BITS-1];          // sign(xq) == sign(bfm0)
    end

    // ===================== S2 : |xq| then clamp to -b_int =====================
    // -b_int is positive (b_int < 0). abs(xq) can reach 2^(XQ_BITS-1) -> +1 bit.
    reg signed [XQ_BITS-1:0] s2_xq;
    reg                      s2_sign;
    reg        [XQ_BITS:0]   s2_abc;          // clamped |xq|, unsigned (<= -b_int)
    wire       [XQ_BITS:0]   s1_abs  = s1_sign ? (~{1'b0,s1_xq} + 1'b1) : {1'b0,s1_xq};
    wire       [XQ_BITS:0]   s1_negb = (~{b_int[XQ_BITS-1],b_int} + 1'b1); // -b_int
    always @(posedge clk) begin
        s2_xq   <= s1_xq;
        s2_sign <= s1_sign;
        s2_abc  <= (s1_abs > s1_negb) ? s1_negb : s1_abs;
    end

    // ===================== S3 : t = abc + b_int (<= 0) =====================
    reg signed [XQ_BITS-1:0] s3_xq;
    reg                      s3_sign;
    reg signed [XQ_BITS:0]   s3_t;
    always @(posedge clk) begin
        s3_xq   <= s2_xq;
        s3_sign <= s2_sign;
        s3_t    <= $signed({1'b0,s2_abc}) + b_int;
    end

    // ===================== S4 : sq = t*t (mult #1) =====================
    reg signed [XQ_BITS-1:0] s4_xq;
    reg                      s4_sign;
    reg signed [ACC_BITS-1:0] s4_sq;
    always @(posedge clk) begin
        s4_xq   <= s3_xq;
        s4_sign <= s3_sign;
        s4_sq   <= s3_t * s3_t;              // >=0, up to ~2^27
    end

    // ===================== S5 : inner = sq + c_int ; y = sign? -inner:inner ====
    reg signed [XQ_BITS-1:0] s5_xq;
    reg signed [ACC_BITS-1:0] s5_y;
    wire signed [ACC_BITS-1:0] s4_inner = s4_sq + c_int;
    always @(posedge clk) begin
        s5_xq <= s4_xq;
        s5_y  <= s4_sign ? -s4_inner : s4_inner;
    end

    // ===================== S6 : sig = y >>> N ; g = sig + shift_int ============
    reg signed [XQ_BITS-1:0] s6_xq;
    reg signed [ACC_BITS-1:0] s6_g;
    always @(posedge clk) begin
        s6_xq <= s5_xq;
        s6_g  <= (s5_y >>> N_SHIFT) + shift_int;
    end

    // ===================== S7 : out = xq * g (mult #2) ========================
    reg signed [ACC_BITS-1:0] s7_out;        // i-GELU integer output
    always @(posedge clk) begin
        s7_out <= s6_xq * s6_g;
    end

    // ===================== S8 : oi2 = rsign?-out:out ; prod = oi2*m0g (mult #3) =
    reg signed [ACC_BITS+M0_BITS-1:0] s8_prod;
    wire signed [ACC_BITS-1:0] s7_oi2 = rsign ? -s7_out : s7_out;
    always @(posedge clk) begin
        s8_prod <= s7_oi2 * $signed({1'b0, m0g});
    end

    // ===================== S9 : q = prod >>> SHG ; saturate uint8 =============
    wire signed [ACC_BITS+M0_BITS-1-SHG:0] s8_q = s8_prod >>> SHG;
    always @(posedge clk) begin
        if(reset) q_out <= 8'd0;
        else if(s8_q > 255) q_out <= 8'd255;
        else if(s8_q < 0)   q_out <= 8'd0;
        else                q_out <= s8_q[7:0];
    end

endmodule
