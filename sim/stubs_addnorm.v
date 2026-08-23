// ============================================================================
//  Elaboration-only stub for the square-root IP used by Add_Norm_module.
//
//  Despite the name, DW_sqrt is a *Vivado* IP core (CORDIC configured as
//  square-root: aclk / s_axis_cartesian_tdata / m_axis_dout_tdata), generated
//  inside the senior's Vivado project. It is not in the RTL sources, so
//  command-line elaboration needs a stand-in.
//
//  WARNING: this stub is for ELABORATION / connectivity checking only. Its
//  latency does NOT match the real CORDIC core, so functional simulation of
//  Add&Norm requires the generated IP (run from the Vivado project instead).
//
//  Widths follow addnormtop's parameters TBITS=8, fixed=8:
//      variance      [TBITS+TBITS+fixed+fixed : 0] = [32:0]
//      sqrt_variance [TBITS+fixed             : 0] = [16:0]  (padded to 24 on the bus)
// ============================================================================

module DW_sqrt (
    input  wire        aclk,
    input  wire        s_axis_cartesian_tvalid,
    input  wire [39:0] s_axis_cartesian_tdata,
    output wire        m_axis_dout_tvalid,
    output reg  [23:0] m_axis_dout_tdata
);
    assign m_axis_dout_tvalid = 1'b1;

    integer i;
    reg [32:0] rem, root, val;
    always @(posedge aclk) begin
        val  = s_axis_cartesian_tdata[32:0];
        rem  = 0;
        root = 0;
        for (i = 0; i < 17; i = i + 1) begin
            root = root << 1;
            rem  = (rem << 2) | ((val >> 31) & 2'b11);
            val  = val << 2;
            if (rem > root) begin
                rem  = rem - (root | 1);
                root = root | 2;
            end
        end
        m_axis_dout_tdata <= {7'd0, root[17:1]};
    end
endmodule
