// ============================================================================
// Func : GELU-enabled requantize path (Phase 3b). Drop-in alternative to
//        FFN_quan2uint8 for the FFN layer that needs I-BERT i-GELU.
//        Computes the same bfm0 = serial32 - act_sum*z_of_weight, then routes
//        it through FFN_i_gelu (i-GELU + uint8 requantize) instead of the M0 path.
//        Bit-exact to tools/ffn_igelu_ref.c (gold tools/FFN1_igelu_out.dat).
//
//        Same port subset as FFN_quan2uint8 (m0_scale/index unused here — the
//        GELU output requant uses m0g inside FFN_i_gelu), so it drops into the
//        FFN_pe_array instantiation under `ifdef IGELU`.
// ============================================================================
module FFN_quan2uint8_gelu(
        clk
    ,   reset
    ,   z_of_weight
    ,   valid_in
    ,   serial32_in     // MAC + bias
    ,   act_sum_in      // input-feature sum
    ,   q_out
    ,   valid_out
);
    input               clk, reset, valid_in;
    input  signed [31:0] serial32_in;
    input         [31:0] act_sum_in;
    input         [15:0] z_of_weight;
    output        [7:0]  q_out;
    output               valid_out;

    // ---- i-GELU constants for the b-2 self-consistent reference (S = 2^-12).
    //      TODO(Phase 3b->CFG): route these from config_param like m0_scale so a
    //      real I-BERT model's scale can be loaded post-layout (b-1) w/o RTL edit.
    localparam signed [15:0] IG_B_INT     = -16'sd10248;
    localparam signed [31:0] IG_C_INT     = -32'sd116185707;
    localparam signed [15:0] IG_SHIFT_INT = -16'sd7092;
    localparam        [17:0] IG_M0G       =  18'd1178;
    localparam               IG_RSIGN     =  1'b1;

    // ---- bfm0 = serial32 - act_sum * z_of_weight  (matches FFN_quan2uint8 / C ref) ----
    reg signed [31:0] s32_d;
    reg        [47:0] az;
    reg               v1;
    always @(posedge clk) begin
        s32_d <= serial32_in;
        az    <= act_sum_in * z_of_weight;
        v1    <= reset ? 1'b0 : valid_in;
    end

    reg signed [31:0] bfm0;
    reg               v2;
    always @(posedge clk) begin
        bfm0 <= s32_d - $signed(az[31:0]);
        v2   <= reset ? 1'b0 : v1;
    end

    FFN_i_gelu igelu_inst(
            .clk(clk), .reset(reset)
        ,   .valid_in(v2)
        ,   .bfm0(bfm0)
        ,   .b_int(IG_B_INT), .c_int(IG_C_INT), .shift_int(IG_SHIFT_INT)
        ,   .m0g(IG_M0G), .rsign(IG_RSIGN)
        ,   .valid_out(valid_out)
        ,   .q_out(q_out)
    );

endmodule
