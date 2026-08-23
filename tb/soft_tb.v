`timescale 1ns / 1ps
`define VIVA
`ifdef RTL
    `define CYCLE 10                       // 100MHz
`endif
`ifdef GATE
    `define CYCLE 10                       // 100MHz
    `define SDFFILE "../syn/DC_Results/softmax_top_syn.sdf"
`endif
`ifdef VIVA
    `define CYCLE 10
`endif

module tb_softmax_top;

// ===================== Parameters =====================
parameter TBITS = 64	;
parameter TBYTE = 8		;

localparam DATA_W           = 64;
localparam KEEP_W           = DATA_W/8;     // 8 for 64-bit
localparam BEATS_PER_GROUP  = 8;            // �A�쥻�C�հe 8 �� 64-bit
localparam OUTS_PER_GROUP   = 64;           // �A�쥻�C�մ��� 64 ����X

localparam SOFTMAX_HEAD     = 64'h8899aabbccddeeff ;

// ===================== Clk / Rst ======================
reg clk;
reg rstn;
always #(`CYCLE/2) clk = ~clk;

// ===================== AXI-Stream (to DUT) ============
reg                        S_AXIS_MM2S_TVALID;
wire                       S_AXIS_MM2S_TREADY;  // from DUT
reg  [DATA_W-1:0]          S_AXIS_MM2S_TDATA;
reg  [KEEP_W-1:0]          S_AXIS_MM2S_TKEEP;
reg                        S_AXIS_MM2S_TLAST;

// ===================== AXI-Stream (from DUT) ==========
wire                       M_AXIS_S2MM_TVALID;  // from DUT
reg                        M_AXIS_S2MM_TREADY;
wire [DATA_W-1:0]          M_AXIS_S2MM_TDATA;
wire [KEEP_W-1:0]          M_AXIS_S2MM_TKEEP;
wire                       M_AXIS_S2MM_TLAST;

// ===================== Memories =======================
// ��J�ɡG�C�� 8 ��B�C�� 64-bit�F��X golden�G�C�� 64 ��B�C�� 16-bit
reg  [DATA_W-1:0] input_mem     [0:4095];
reg  [15:0]       golden_output [0:4095];

// �έp�P����
integer total_group;
integer i;
integer group_id;
integer out_idx;
integer err_cnt;

// ===================== DUT ============================
// �A�쥻�� softmax_top �w���ѡA�o�̥� AXI-Stream �� topsoft
Transformer_top #(
        .TBITS(TBITS)
    ,	.TBYTE(TBYTE)
)dut(
    .clk                (   clk                 ),
    .resetn             (   rstn                ),
    .S_AXIS_MM2S_TVALID (   S_AXIS_MM2S_TVALID  ),
    .S_AXIS_MM2S_TREADY (   S_AXIS_MM2S_TREADY  ),
    .S_AXIS_MM2S_TDATA  (   S_AXIS_MM2S_TDATA   ),
    .S_AXIS_MM2S_TKEEP  (   S_AXIS_MM2S_TKEEP   ),
    .S_AXIS_MM2S_TLAST  (   S_AXIS_MM2S_TLAST   ),

    .M_AXIS_S2MM_TVALID (   M_AXIS_S2MM_TVALID  ),
    .M_AXIS_S2MM_TREADY (   M_AXIS_S2MM_TREADY  ),
    .M_AXIS_S2MM_TDATA  (   M_AXIS_S2MM_TDATA   ),
    .M_AXIS_S2MM_TKEEP  (   M_AXIS_S2MM_TKEEP   ),
    .M_AXIS_S2MM_TLAST  (   M_AXIS_S2MM_TLAST   )
);

// ===================== File Load ======================
initial begin
    //$readmemh("C:/Users/WCK/Documents/education/code_V0/DAT/rearrange.dat", input_mem);
    //$readmemh("C:/Users/WCK/Documents/education/code_V0/DAT/output.dat"   , golden_output);

    $readmemh("C:/Users/LCP/Desktop/Edu/pat/rearrange.dat", input_mem);
    $readmemh("C:/Users/LCP/Desktop/Edu/pat/output.dat"   , golden_output);

`ifdef GATE
    $sdf_annotate(`SDFFILE, dut);
`endif

    // �����`�ռơG�C�ը� 8 ��A�J�� x ����
    total_group = 0;
    while (input_mem[total_group*BEATS_PER_GROUP] !== {DATA_W{1'bx}} && total_group < 512)
        total_group = total_group + 1;

    $display("[TB] Loaded %0d groups (each group has %0d beats of %0d-bit).",
             total_group, BEATS_PER_GROUP, DATA_W);
end

// ===================== AXIS Send Task =================
task automatic axis_send_group(input integer gid);
    integer k;
begin
    //---- SOFTMAX HEAD ----
    wait(S_AXIS_MM2S_TREADY);
    @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= SOFTMAX_HEAD ;
    wait(S_AXIS_MM2S_TREADY);
    @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= SOFTMAX_HEAD ;	
    S_AXIS_MM2S_TLAST	= 1;	// last signal 
    wait(S_AXIS_MM2S_TREADY);
    @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;
    
    for (k = 0; k < BEATS_PER_GROUP; k = k + 1) begin

        wait(S_AXIS_MM2S_TREADY)
        @(posedge clk);
        S_AXIS_MM2S_TDATA  <= input_mem[gid*BEATS_PER_GROUP + k];
        S_AXIS_MM2S_TKEEP  <= {KEEP_W{1'b1}};     // �� 8 bytes �Ҧ���
        S_AXIS_MM2S_TLAST  <= (k == BEATS_PER_GROUP-1);
        S_AXIS_MM2S_TVALID <= 1'b1;

        //// wait handshake
        //while (!(S_AXIS_MM2S_TVALID && S_AXIS_MM2S_TREADY)) begin
        //    @(posedge clk);
        //end

        // �w�����ǰe�ө�A�U�@��w�]���� TVALID�]�ѤU�@��A���}�^
        //@(posedge clk);
        //S_AXIS_MM2S_TVALID <= 1'b0;
        //S_AXIS_MM2S_TLAST  <= 1'b0;
        if (k == (BEATS_PER_GROUP - 1)) begin
            @(posedge clk);
            S_AXIS_MM2S_TVALID <= 1'b0;
            S_AXIS_MM2S_TLAST  <= 1'b0;
        end
        // else begin
        //     S_AXIS_MM2S_TVALID <= S_AXIS_MM2S_TVALID;
        //     S_AXIS_MM2S_TLAST  <= S_AXIS_MM2S_TLAST;
        // end
    end

end
endtask

// ===================== AXIS Receive & Check ===========
task automatic axis_recv_and_check_group(input integer gid);
    reg [15:0] out16;
begin
    out_idx = 0;
    while (out_idx < OUTS_PER_GROUP) begin
        @(posedge clk);
        if (M_AXIS_S2MM_TVALID && M_AXIS_S2MM_TREADY) begin
            // ���] DUT �C���X 1 �� 16-bit ���G�b TDATA[15:0]
            // �Y�A�� DUT �C�秨�a�h���]�Ҧp 4 �� 16-bit=64-bit �@���X�ӡ^�A
            // �o�̭n�令�� 4 �����C
            out16 = M_AXIS_S2MM_TDATA[15:0];

            if (out16 !== golden_output[gid*OUTS_PER_GROUP + out_idx]) begin
                $display("[TB][MIS] G%0d idx%0d : got=%04h exp=%04h",
                         gid, out_idx, out16, golden_output[gid*OUTS_PER_GROUP + out_idx]);
                err_cnt = err_cnt + 1;
            end else begin
                // �i���ݭn���C��X�T���q
                //$display("[TB][OK ] G%0d idx%0d : %04h", gid, out_idx, out16);
            end
            out_idx = out_idx + 1;
        end
    end
end
endtask

// ===================== Main Stimulus ==================
`ifdef VIVA
initial begin
    // Dump�]�i���ݨD�O�d�^
    $dumpfile("softmax_axis.vcd");
    $dumpvars;

    clk = 1'b0;
    rstn = 1'b0;

    S_AXIS_MM2S_TVALID = 1'b0;
    S_AXIS_MM2S_TDATA  = {DATA_W{1'b0}};
    S_AXIS_MM2S_TKEEP  = {KEEP_W{1'b0}};
    S_AXIS_MM2S_TLAST  = 1'b0;

    M_AXIS_S2MM_TREADY = 1'b1;  // �û��i��

    err_cnt = 0;

    // Reset
    repeat (4) @(posedge clk);
    rstn = 1'b1;
    repeat (2) @(posedge clk);

    // �v�հe�J�P���
    for (group_id = 0; group_id < total_group; group_id = group_id + 1) begin
        $display("[TB] ===== Start Group %0d =====", group_id);
        axis_send_group(group_id);
        axis_recv_and_check_group(group_id);
        $display("[TB] ===== End   Group %0d =====", group_id);
    end

    $display("[TB] All %0d groups done. Total mismatches = %0d", total_group, err_cnt);
    repeat (5) @(posedge clk);
    $finish;
end
`endif

`ifdef RTL
initial begin
    $fsdbDumpfile("softmax_axis.fsdb");
    $fsdbDumpvars(0, "+mda", "+packedmda");
    $fsdbDumpMDA();

    clk = 1'b0;
    rstn = 1'b0;

    S_AXIS_MM2S_TVALID = 1'b0;
    S_AXIS_MM2S_TDATA  = {DATA_W{1'b0}};
    S_AXIS_MM2S_TKEEP  = {KEEP_W{1'b0}};
    S_AXIS_MM2S_TLAST  = 1'b0;

    M_AXIS_S2MM_TREADY = 1'b1;

    err_cnt = 0;

    repeat (4) @(posedge clk);
    rstn = 1'b1;
    repeat (2) @(posedge clk);

    for (group_id = 0; group_id < total_group; group_id = group_id + 1) begin
        $display("[TB] ===== Start Group %0d =====", group_id);
        axis_send_group(group_id);
        axis_recv_and_check_group(group_id);
        $display("[TB] ===== End   Group %0d =====", group_id);
    end

    $display("[TB] All %0d groups done. Total mismatches = %0d", total_group, err_cnt);
    repeat (5) @(posedge clk);
    $finish;
end
`endif

`ifdef GATE
initial begin
    $fsdbDumpfile("softmax_axis.fsdb");
    $fsdbDumpvars(0, "+mda", "+packedmda");
    $fsdbDumpMDA();

    clk = 1'b0;
    rstn = 1'b0;

    S_AXIS_MM2S_TVALID = 1'b0;
    S_AXIS_MM2S_TDATA  = {DATA_W{1'b0}};
    S_AXIS_MM2S_TKEEP  = {KEEP_W{1'b0}};
    S_AXIS_MM2S_TLAST  = 1'b0;

    M_AXIS_S2MM_TREADY = 1'b1;

    err_cnt = 0;

    repeat (6) @(posedge clk);
    rstn = 1'b1;
    repeat (2) @(posedge clk);

    for (group_id = 0; group_id < total_group; group_id = group_id + 1) begin
        $display("[TB] ===== Start Group %0d =====", group_id);
        axis_send_group(group_id);
        axis_recv_and_check_group(group_id);
        $display("[TB] ===== End   Group %0d =====", group_id);
    end

    $display("[TB] All %0d groups done. Total mismatches = %0d", total_group, err_cnt);
    repeat (10) @(posedge clk);
    $finish;
end
`endif

// ===================== Timeout ========================
parameter MAX_CYCLES = 1000000;
integer cycle_count = 0;
always @(posedge clk) begin
    cycle_count <= cycle_count + 1;
    if (cycle_count > MAX_CYCLES) begin
        $display("[TB] Simulation timeout after %0d cycles", MAX_CYCLES);
        $finish;
    end
end

endmodule