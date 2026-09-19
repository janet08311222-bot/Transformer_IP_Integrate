// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2022.12.04
// Ver      : 1.0
// Func     : testbench for IF KE BI module read and write 
// 			whether it has last signal or not, it should work at HEAD detection.
// Log : --2023.04.08 need to program instrustion for DLA, then will run success
// Log : --2023.05.16 s2mm_tready should not always "1"
// Log : --2023.05.16 all data loading function fixed
// Log : --2023.06.22 Continuous transmission of a small amount of data, causing FIFO overflow and resulting in failure.

// ============================================================================

`define ROW_DELAY 20
`ifdef VCS
`define FSDB_DUMP                     // fsdb needs Verdi's PLI - only under VCS
`endif
`define EZ_S2MM_TREADY_SET
// `define CYC_LIMIT
// (VIVA / RTL / GATE are chosen in the "simulation mode" block below)
`define End_CYCLE 50000              // Modify cycle times once your design need more cycle times!
`define NI_DELAY  2		                // NONIDEAL delay latency
`define AFPOS_DELAY  0.5		        // after posedge NONIDEAL delay latency
`define FFN1
// `define FFN2
//  連續跑幾趟。>1 會在「不 reset DUT」的情況下重複送 head 指令 + 資料,
//  用來驗證 FSM 每趟都能正確收尾、下一趟不受前一趟殘留影響。
//  每趟結果都必須各自與 gold 相符 —— 也就等於趟與趟之間完全一致。
`ifdef FFN1
`define N_PASS 2
`else
`define N_PASS 1        // 多趟迴圈只實作在 FFN1 分支
`endif
// `define SOFTMAX                  // run the softmax path instead of FFN1/FFN2

//-- simulation mode --
//  VIVA : Vivado project flow (xsim launched deep inside vivado/build). Local
//         default: assumed whenever neither of the other two is given.
//  RTL  : VCS pre-sim on the school box      -> +define+RTL   (run from repo root)
//  GATE : VCS gate-level sim, DC netlist+SDF -> +define+GATE  (run from repo root)
//  Only ONE copy of the clock and pattern settings lives below; the three
//  modes used to each carry their own and drifted (stale CYCLE, wrong SDF
//  name, and an FFN1 gold that pre-dated i-GELU).
`ifndef RTL
`ifndef GATE
`define VIVA
`endif
`endif

//-- timescale / clock --
//  CYCLE is 10 in EVERY mode. The tb's sub-cycle delays (`CYCLE/2.5, NI_DELAY,
//  AFPOS_DELAY) were validated at 10, and for GATE it must also be >= the SDC
//  clock period (adfp/syn/CHIP.sdc) or the SDF run fails timing checks.
`ifdef GATE
    `timescale 1ns/1ps
    `define CYCLE 10
    `define SDFFILE "../syn/DC_Results/Transformer_top_syn.sdf"
`else
    `timescale 1ns/100ps
    `define CYCLE 10
`endif

//-- pattern path --
//  Vivado runs xsim from <build>/Transformer_IP.sim/sim_1/behav/xsim, so that
//  flow needs an absolute path (change it here if the repo moves). VCS is run
//  from pre_sim/ (the ADFP convention: everything is ../ from there).
`ifdef VIVA
    `define PAT_DIR "D:/Transformer_code/Transformer_IP_Integrate/pat/"
`else
    `define PAT_DIR "../pat/"
`endif

`ifdef FFN1
    //----input pattern ----
    `define IF_PAT      {`PAT_DIR, "input_token.dat"}
    `define KER_PAT     {`PAT_DIR, "FFN_W1.dat"}
    `define BIAS_PAT    {`PAT_DIR, "bias1.dat"}
    //----gold pattern ----
    //  FFN1 runs i-GELU (cfg_z3[0] = 1), so the gold is the i-GELU
    //  reference, not the plain-requant FFN1_out_original.dat.
    `define OF_GOLD     {`PAT_DIR, "FFN1_igelu_out.dat"}
`elsif FFN2
    //----input pattern ----
    `define IF_PAT      {`PAT_DIR, "FFN1_out_original.dat"}
    `define KER_PAT     {`PAT_DIR, "FFN_W2.dat"}
    `define BIAS_PAT    {`PAT_DIR, "bias2.dat"}
    //----gold pattern ----
    `define OF_GOLD     {`PAT_DIR, "FFN2_out.dat"}
`else
    `define IF_PAT      {`PAT_DIR, "input_token.dat"}
    `define KER_PAT     {`PAT_DIR, "FFN_W1.dat"}
    `define BIAS_PAT    {`PAT_DIR, "bias1.dat"}
    //----gold pattern ----
    `define OF_GOLD     {`PAT_DIR, "FFN1_igelu_out.dat"}
`endif

// =============================================================================
// ================				module start				====================
// =============================================================================
module Transformer_tb();
// =============================================================================
// =============	PATTERN parameter	========================
// =============================================================================
    localparam TB_PAT_COL	=	64	;
    localparam TB_PAT_ROW	=	64	;
// =============================================================================
// =============	testbench configurable parameter	========================
// =============================================================================
`ifdef FFN1
    localparam TB_RUN_COL   =   64   ;
    localparam TB_RUN_ROW   =   8    ;
    localparam TB_RUN_OTCOL =   2048 ;
`elsif FFN2
    localparam TB_RUN_COL   =   256  ;
    localparam TB_RUN_ROW   =   8    ;
    localparam TB_RUN_OTCOL =   512  ;
`else
    localparam TB_RUN_COL   =   64   ;
    localparam TB_RUN_ROW   =   8    ;
    localparam TB_RUN_OTCOL =   512  ;
`endif

`ifdef FFN1
    localparam MMOD_cfgin_quantize_m0_scale         = 32'h14841211 ;
    localparam MMOD_cfgin_quantize_index	        = 8'd20  ;
    localparam MMOD_cfgin_quantize_z_of_weightht    = 16'd27 ;
`elsif FFN2
    localparam MMOD_cfgin_quantize_m0_scale         = 32'h14841211 ;
    localparam MMOD_cfgin_quantize_index	        = 8'd20  ;
    localparam MMOD_cfgin_quantize_z_of_weightht    = 16'd27 ;
`else
    localparam MMOD_cfgin_quantize_m0_scale         = 32'h7D884464 ;
    localparam MMOD_cfgin_quantize_index	        = 8'd8  ;
    localparam MMOD_cfgin_quantize_z_of_weightht    = 16'd127 ;
`endif

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
localparam TB_KER_ROW = TB_RUN_COL      ;
localparam TB_KER_COL = TB_RUN_OTCOL    ;

localparam TB_RUN_KERSRAM_LENGTH = TB_KER_ROW*TB_KER_COL ;
localparam TB_RUN_BIAS_LENGTH    = TB_KER_COL            ;

localparam OT_NUM_FORCMP = TB_RUN_ROW * TB_RUN_OTCOL	;	
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------


//----	parameter controller (don't move )-------------------
parameter TBITS = 64	;
parameter TBYTE = 8		;
//------------------------------------------------------------------------------

// =============================================================================
// ================				instruction				====================
// =============================================================================
`ifdef FFN1
    localparam cfg_if_token_nums_sub1       =   3'd7   ;
    localparam cfg_if_totalsize_sub1        =   9'd511 ;
    localparam cfg_bias_once_load_size_sub1 =   9'd511 ;
    localparam cfg_ker_length_sub1          =   9'd63  ;
    localparam cfg_ker_readnums             =   3'd7   ;
    localparam cfg_ker_tile_readnums_sub1   =   2'd3   ;
    localparam cfg_ker_tile_size_sub1       =   6'd31  ;  // 16-way: 512ch/16 = 32 subtiles per tile (was 64)
`elsif FFN2
    localparam cfg_if_token_nums_sub1       =   3'd1    ;
    localparam cfg_if_totalsize_sub1        =   9'd511  ;
    localparam cfg_bias_once_load_size_sub1 =   9'd511  ;
    localparam cfg_ker_length_sub1          =   9'd255  ;
    localparam cfg_ker_readnums             =   3'd1    ;
    localparam cfg_ker_tile_readnums_sub1   =   2'd0    ;
    localparam cfg_ker_tile_size_sub1       =   6'd31   ;  // 16-way: 512ch/16 = 32 subtiles per tile (was 64)
`else
    localparam cfg_if_token_nums_sub1       =   3'd7    ;
    localparam cfg_if_totalsize_sub1        =   9'd511  ;
    localparam cfg_bias_once_load_size_sub1 =   9'd511  ;
    localparam cfg_ker_length_sub1          =   9'd63   ;
    localparam cfg_ker_readnums             =   3'd7    ;
    localparam cfg_ker_tile_readnums_sub1   =   2'd0    ;
    localparam cfg_ker_tile_size_sub1       =   6'd31   ;  // 16-way: 512ch/16 = 32 subtiles per tile (was 64)
`endif
// -----------------for output config----------------------
//  Output reshape. The FFN is 16-column (PEBLKCOL_NUM = 16), so a column
//  group now spans two 64-bit output words and the whole ct_gp/ct_col/ct_cha
//  walk is reshaped vs the 8-way baseline. cfg_ot_sft_col is a NEW field that
//  only exists in the 16-way FFN.
`ifdef FFN1
    localparam cfg_ot_rnd_finsub1	= 9'd511	;
    localparam cfg_ot_tgpfnsub1		= 9'd7		;   // 16-way: ct_gp = token 0..7
    localparam cfg_ot_tcolfnsub1	= 9'd31     ;   // 16-way: ct_col = tile 0..31
    localparam cfg_ot_tchafnsub1	= 9'd1	    ;   // 16-way: ct_cha = lo/hi word 0..1
    localparam cfg_ot_sft_gp		= 9'd2	    ;   // 16-way: token stride
    localparam cfg_ot_sft_colpra	= 9'd1		;   // 16-way: lo/hi-word stride
    localparam cfg_ot_sft_col		= 9'd16		;   // 16-way: tile stride (NEW field)
`elsif FFN2
    localparam cfg_ot_rnd_finsub1	= 9'd127	;
    localparam cfg_ot_tgpfnsub1		= 9'd1		;   // 16-way: ct_gp = token 0..1
    localparam cfg_ot_tcolfnsub1	= 9'd31     ;   // 16-way: ct_col = subtile 0..31
    localparam cfg_ot_tchafnsub1	= 9'd1	    ;   // 16-way: ct_cha = lo/hi word 0..1
    localparam cfg_ot_sft_gp		= 9'd2	    ;   // 16-way: token stride (= 2 rows)
    localparam cfg_ot_sft_colpra	= 9'd1		;   // 16-way: lo/hi-word stride
    localparam cfg_ot_sft_col		= 9'd4		;   // 16-way: subtile stride (2 tok x 2 rows)
`else
    localparam cfg_ot_rnd_finsub1	= 9'd511	;
    localparam cfg_ot_tgpfnsub1		= 9'd7		;
    localparam cfg_ot_tcolfnsub1	= 9'd31     ;
    localparam cfg_ot_tchafnsub1	= 9'd1	    ;
    localparam cfg_ot_sft_gp		= 9'd2	    ;
    localparam cfg_ot_sft_colpra	= 9'd1		;
    localparam cfg_ot_sft_col		= 9'd16		;
`endif
// -----------------for quantization config----------------------
localparam cfg_m0_scale         = MMOD_cfgin_quantize_m0_scale          ;
localparam cfg_index            = MMOD_cfgin_quantize_index	            ;
localparam cfg_z_of_weight      = MMOD_cfgin_quantize_z_of_weightht     ;
//  cfg_z3 bit0 doubles as cfg_gelu_en in the i-GELU FFN: the activation is
//  enabled per layer, so FFN1 runs i-GELU and FFN2 runs plain M0 requant.
`ifdef FFN1
localparam cfg_z3               = 8'd1  ;   // FFN1 -> i-GELU ON
`else
localparam cfg_z3               = 8'd0  ;   // FFN2 / SA -> i-GELU OFF
`endif
// -----------------------------------------------------------------------

localparam INST_HEAD = 64'hefef123abbeeff22 ;
localparam DATA_HEAD = 64'hefef6543dadaff11 ;
localparam SA_HEAD          = 64'h0011223344556677 ;
localparam SOFTMAX_HEAD     = 64'h8899aabbccddeeff ;
localparam NORM_HEAD        = 64'h7766554433221100 ;
localparam FFN_HEAD         = 64'hffeeddccbbaa9988 ;
localparam CFG_0 = 64'hffff000000000000 ;	//start signal
localparam CFG_1 = { cfg_m0_scale , cfg_index , cfg_z_of_weight , cfg_z3 };
localparam CFG_2 = { 52'd0 , cfg_if_token_nums_sub1 , cfg_if_totalsize_sub1 } ;
localparam CFG_3 = { 55'd0 , cfg_bias_once_load_size_sub1 } ;
localparam CFG_4 = { 47'd0 , cfg_ker_tile_readnums_sub1 , cfg_ker_tile_size_sub1 , cfg_ker_length_sub1 } ;
localparam CFG_14	= {cfg_ot_rnd_finsub1 , cfg_ot_tgpfnsub1 , cfg_ot_tcolfnsub1 ,37'd0}	;
localparam CFG_15	= {cfg_ot_tchafnsub1  , cfg_ot_sft_gp	 , cfg_ot_sft_colpra , cfg_ot_sft_col , 28'd0}	;

localparam CFG_5  = 64'd0 ;
localparam CFG_6  = 64'd0 ;
localparam CFG_7  = 64'd0 ;
localparam CFG_8  = 64'd0 ;
localparam CFG_9  = 64'd0 ;
localparam CFG_10 = 64'd0 ;
localparam CFG_11 = 64'd0 ;
localparam CFG_12 = 64'd0 ;
localparam CFG_13 = 64'd0 ;

// =============================================================================
// ================				necessary declare			====================
// =============================================================================

//---------- clk & reset declare-----------------
reg [31:0] cycle=0;
reg  clk;         
reg  reset;       
logic rstn = 1;

//---------- test pattern declare-----------------
logic tb_memread_done ;

reg [64-1:0] ifmap_data_temp    [0: TB_RUN_COL*TB_RUN_ROW-1 ]   ;
reg [64-1:0] ifmap_data 	    [0: TB_RUN_COL*TB_RUN_ROW-1 ]   ;
reg [32-1:0] ifmap_addr                                         ;

reg [64-1:0] ker_array_temp		[0:TB_RUN_KERSRAM_LENGTH]   ;
reg [64-1:0] ker_array		    [0:TB_RUN_KERSRAM_LENGTH]   ;
reg [32-1:0] ker_addr                                       ;

reg [64-1:0] bias_array	        [0:TB_RUN_BIAS_LENGTH]  ;
reg [32-1:0] bias_array_temp	[0:TB_RUN_BIAS_LENGTH]  ;
reg [32-1:0] bias_addr                                  ;

//---------- goldmap mem pattern declare-----------------
reg [32-1:0] tb_o_cnt ;
reg [32-1:0] tb_o_cnt1 ;
reg [32-1:0] tb_o_cnt2 ;
reg [32-1:0] ot_addr ;
reg [32-1:0] ot_token_sub1 ;
reg [32-1:0] err_ofmap;
reg [32-1:0] x_cnt;		// output words the DUT never drove (guards a false PASS)
integer pass_id = 0;		// which pass of `N_PASS is being driven.
							// MUST default to 0: only the FFN1 branch drives it, but the
							// capture below indexes with it in every mode, and an
							// uninitialised integer is X -> nothing gets stored.
integer jcp;				// per-pass mismatch counter
//  ot_addr is a REMAPPED gold index (it wraps within one pass, it is not a
//  running counter), and it only clears on reset. Across passes it would carry
//  the previous pass's position and scribble over it, so the stimulus pulses
//  pass_rst before each pass and the capture is offset by the pass number.
reg pass_rst = 1'b0;
localparam TB_GOLD_WORDS = TB_RUN_OTCOL ;	// output words ONE pass produces
reg [64-1:0] ofm_array [0 : OT_NUM_FORCMP] ;
reg [64-1:0] ofm_gold [ 0: OT_NUM_FORCMP ];
reg [64-1:0] ofm_gold_temp [ 0: OT_NUM_FORCMP ];

//---------- softmax mem pattern declare-----------------

localparam BEATS_PER_GROUP  = 8;
localparam OUTS_PER_GROUP   = 64;
localparam DATA_W           = 64;
localparam KEEP_W           = DATA_W/8;

reg  [DATA_W-1:0] input_mem     [0:4095];
reg  [63:0]       golden_output [0:4095];	// 64-bit: output.dat lines are 16 hex chars. VCS rejects a
												// too-wide entry ("Illegal entry") and stops loading; xsim
												// silently truncated. Widen the array, slice on compare.

integer total_group;
integer i;
integer group_id;
integer out_idx;
integer err_cnt;
integer gold_x_cnt;	// gold entries that are X (file not loaded / bad format)
integer out_x_cnt;	// DUT outputs that are X

//---------- design under test (DUT) output declare-----------------
reg dutot_done =0;		// DUT output done we can compare data with gold pattern
// DUT output error for compare block 
//--------------------------------------------

// =============================================================================
//----- DUT AXI I/O ----
logic               S_AXIS_MM2S_TVALID	;
logic               S_AXIS_MM2S_TREADY	;
logic [TBITS-1:0]   S_AXIS_MM2S_TDATA	;
logic [TBYTE-1:0]   S_AXIS_MM2S_TKEEP	;
logic               S_AXIS_MM2S_TLAST	;

logic               M_AXIS_S2MM_TVALID	;
logic               M_AXIS_S2MM_TREADY	;
logic [TBITS-1:0]   M_AXIS_S2MM_TDATA	;
logic [TBYTE-1:0]   M_AXIS_S2MM_TKEEP	;
logic [1-1:0]       M_AXIS_S2MM_TLAST	; 

//----- test flow flag ----
logic tst_fl_sent_ifmap 	= 0 ;
logic tst_fl_sent_kernel 	= 0 ;
logic tst_fl_sent_bias 		= 0 ;

integer i0, i1 ;

integer icp;

// ============================================================================
// ================			instance DUT		===============================
// ============================================================================
Transformer_top #(
        .TBITS(TBITS)
    ,	.TBYTE(TBYTE)
)tp001(	
        .clk	(	clk		)
    ,	.resetn	(	~reset	)

    ,	.S_AXIS_MM2S_TVALID	(	S_AXIS_MM2S_TVALID	)
    ,	.S_AXIS_MM2S_TREADY	(	S_AXIS_MM2S_TREADY	)
    ,	.S_AXIS_MM2S_TDATA	(	S_AXIS_MM2S_TDATA	)
    ,	.S_AXIS_MM2S_TKEEP	(	S_AXIS_MM2S_TKEEP	)
    ,	.S_AXIS_MM2S_TLAST	(	S_AXIS_MM2S_TLAST	)

    ,	.M_AXIS_S2MM_TVALID	(	M_AXIS_S2MM_TVALID	)
    ,	.M_AXIS_S2MM_TREADY	(	M_AXIS_S2MM_TREADY	)
    ,	.M_AXIS_S2MM_TDATA	(	M_AXIS_S2MM_TDATA	)
    ,	.M_AXIS_S2MM_TKEEP	(	M_AXIS_S2MM_TKEEP	)
    ,	.M_AXIS_S2MM_TLAST	(	M_AXIS_S2MM_TLAST	)
);

`ifdef GATE
    initial $sdf_annotate(`SDFFILE,tp001);	//  $sdf_annotate("sdf_file"[,module_instance][,"sdf_configfile"][,"sdf_logfile"][,"mtm_spec"][,"scale_factors"][,"scale_type"]);
`endif

// =============================================================================
// ================		clock generate & end cycle		========================
// =============================================================================
initial clk = 1;

always begin #(`CYCLE / 2) clk = ~clk; end
always@(*)begin
    rstn = ~reset;
end
    
always @(posedge clk) begin
    cycle <= cycle+1;
    `ifdef CYC_LIMIT
        if (cycle > `End_CYCLE) begin
            $display("********************************************************************");
            $display("**  Failed waiting Valid signal, Simulation STOP at cycle %d **",cycle);
            $display("**  If needed, You can increase End_CYCLE value in tp.v           **");
            $display("********************************************************************");
            $finish;
        end
    `endif 
end

// =============================================================================
// ================		fsdb dump +mda+packedmda		========================
// ================		Kernel data load readmemh		========================
// =============================================================================
`ifdef FSDB_DUMP
    initial begin
        `ifdef RTL
            $fsdbDumpfile("Transformer_RTL.fsdb",1000);
            $fsdbDumpvars(0,"+mda","+packedmda");		//++
            $fsdbDumpMDA();
        `elsif GATE
            $fsdbDumpfile("Transformer_SYN.fsdb");	
            $fsdbDumpvars();
        `else 
        `endif
    end
`endif

// =============================================================================
// ================		initial pattern and expected result		================
// =============================================================================
initial begin 
    wait(reset==1);
    tb_memread_done = 0; 
    //--------- pattern reading start -----------
    $readmemh(`IF_PAT 		,	ifmap_data_temp	    );
    $readmemh(`KER_PAT	    ,	ker_array_temp		);
    $readmemh(`BIAS_PAT	    ,	bias_array_temp		);
    $readmemh(`OF_GOLD	    ,	ofm_gold_temp	    );
    //--------- pattern reading end -----------
    #1;

    $readmemh({`PAT_DIR, "rearrange.dat"}, input_mem);
    $readmemh({`PAT_DIR, "output.dat"}   , golden_output);

    total_group = 0;
    while (input_mem[total_group*BEATS_PER_GROUP] !== {DATA_W{1'bx}} && total_group < 512)
        total_group = total_group + 1;

    $display("[TB] Loaded %0d groups (each group has %0d beats of %0d-bit).",
             total_group, BEATS_PER_GROUP, DATA_W);

    #1;

    tb_memread_done = 1;
end

// =============================================================================
// ================    softmax task    =========================================
// =============================================================================

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
        S_AXIS_MM2S_TKEEP  <= {KEEP_W{1'b1}};
        S_AXIS_MM2S_TLAST  <= (k == BEATS_PER_GROUP-1);
        S_AXIS_MM2S_TVALID <= 1'b1;

        if (k == (BEATS_PER_GROUP - 1)) begin
            @(posedge clk);
            S_AXIS_MM2S_TVALID <= 1'b0;
            S_AXIS_MM2S_TLAST  <= 1'b0;
        end
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
            out16 = M_AXIS_S2MM_TDATA[15:0];

            if (golden_output[gid*OUTS_PER_GROUP + out_idx][15:0] === 16'bx) gold_x_cnt = gold_x_cnt + 1;
            if (out16 === 16'bx) out_x_cnt = out_x_cnt + 1;
            if (out16 !== golden_output[gid*OUTS_PER_GROUP + out_idx][15:0]) begin
                $display("[TB][MIS] G%0d idx%0d : got=%04h exp=%04h",
                         gid, out_idx, out16, golden_output[gid*OUTS_PER_GROUP + out_idx]);
                err_cnt = err_cnt + 1;
            end
            out_idx = out_idx + 1;
        end
    end
end
endtask

// =============================================================================
// =======		testing control 	============================================
// =============================================================================

reg FFN_start;

initial begin
    `ifdef SOFTMAX
        FFN_start = 0;
        #1;
        reset = 0;
        S_AXIS_MM2S_TVALID = 0 ;
        #( `CYCLE*3 ) ;
        reset = 1;

        //-----------reset signal start ------------------
        S_AXIS_MM2S_TKEEP = 'hff;
        S_AXIS_MM2S_TLAST = 0 ;
        dutot_done =0 ;

        //-----------reset signal end ------------------
        #( `CYCLE*15 + `NI_DELAY ) ;
        reset = 0;
        #( `CYCLE*5 ) ;

        S_AXIS_MM2S_TVALID = 1'b0;
        S_AXIS_MM2S_TDATA  = {DATA_W{1'b0}};
        S_AXIS_MM2S_TKEEP  = {KEEP_W{1'b0}};
        S_AXIS_MM2S_TLAST  = 1'b0;

        M_AXIS_S2MM_TREADY = 1'b1;

        err_cnt = 0;
        gold_x_cnt = 0;
        out_x_cnt = 0;

        for (group_id = 0; group_id < total_group; group_id = group_id + 1) begin
            $display("[TB] ===== Start Group %0d =====", group_id);
            axis_send_group(group_id);
            axis_recv_and_check_group(group_id);
            $display("[TB] ===== End   Group %0d =====", group_id);
        end

        $display("[TB] All %0d groups done. Total mismatches = %0d", total_group, err_cnt);
        repeat (5) @(posedge clk);

        //----    verdict    -----
        //  The FFN compare block is `ifndef SOFTMAX, so this branch owns the
        //  verdict and the $finish in softmax mode.
        $display("====================================================================");
        $display(">>> softmax: %0d groups x 64 outputs = %0d words compared against gold",
                 total_group, total_group*64);
        $display(">>> gold entries that are X : %0d   DUT outputs that are X : %0d", gold_x_cnt, out_x_cnt);
        if( total_group == 0 )
            $display(">>> RESULT: FAIL  (no input groups loaded - check pat/rearrange.dat)");
        else if( gold_x_cnt != 0 )
            $display(">>> RESULT: FAIL  (gold not loaded: %0d X entries - check pat/output.dat path AND format: 4 hex chars per line)", gold_x_cnt);
        else if( out_x_cnt != 0 )
            $display(">>> RESULT: FAIL  (%0d DUT outputs are X)", out_x_cnt);
        else if( err_cnt == 0 )
            $display(">>> RESULT: PASS  (%0d/%0d bit-exact)", total_group*64, total_group*64);
        else
            $display(">>> RESULT: FAIL  (%0d/%0d mismatched)", err_cnt, total_group*64);
        $display(">>> CYCLES: %0d", cycle);
        $display("====================================================================");

        #( `CYCLE*100 ) ;
        $finish;
    `endif

    //---------- FFN1 testbench control ----
    `ifdef FFN1
        FFN_start = 1;
        #1;
        reset = 0;
        S_AXIS_MM2S_TVALID = 0 ;
        #( `CYCLE*3 ) ;
        reset = 1;
        ifmap_addr = 0 ;
        bias_addr = 0 ;
        ker_addr = 0 ;

        //-----------reset signal start ------------------
        S_AXIS_MM2S_TKEEP = 'hff;
        S_AXIS_MM2S_TLAST = 0 ;
        dutot_done =0 ;

        //-----------reset signal end ------------------
        #( `CYCLE*15 + `NI_DELAY ) ;
        reset = 0;
        #( `CYCLE*5 ) ;

        //  DUT is NOT reset between passes - that is the point of the test.
        for ( pass_id = 0 ; pass_id < `N_PASS ; pass_id = pass_id + 1 ) begin
        $display(">>> ---- PASS %0d start (cycle %0d) ----", pass_id, cycle);
        ifmap_addr = 0 ;
        bias_addr  = 0 ;
        ker_addr   = 0 ;
        //  clear the tb-side output remap so this pass writes its own slice
        @( posedge clk ); pass_rst = 1'b1 ;
        @( posedge clk ); pass_rst = 1'b0 ;

        //---- FFN HEAD ----
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
        S_AXIS_MM2S_TLAST	= 1;	// last signal 
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

        // //----- instruction head --------------
        // @( posedge clk );#0.8;
        //     S_AXIS_MM2S_TVALID = 1 ;
        //     S_AXIS_MM2S_TDATA	= INST_HEAD ;
        //     S_AXIS_MM2S_TLAST = 1 ;
        //     wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );#0.8;
        //     S_AXIS_MM2S_TLAST = 0 ;
        //     S_AXIS_MM2S_TVALID = 0 ;
        // #( `CYCLE*10);
        // @( posedge clk );#0.8;
        //     S_AXIS_MM2S_TVALID = 1 ;
        //     S_AXIS_MM2S_TDATA	= INST_HEAD ;
        //     S_AXIS_MM2S_TLAST = 1 ;
        //     wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );#0.8;
        //     S_AXIS_MM2S_TLAST = 0 ;
        //     S_AXIS_MM2S_TVALID = 0 ;
        // #( `CYCLE*30 ) ;

        //----- instruction head --------------
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= INST_HEAD ;
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= INST_HEAD ;	
        S_AXIS_MM2S_TLAST	= 1;	// last signal 
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

        // //---- FFN HEAD ----
        // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
        // wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
        // S_AXIS_MM2S_TLAST	= 1;	// last signal 
        // wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

        //----- instruction config--------------
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_0 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_1 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_2 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_3 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_4 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_5 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_6 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_7 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_8 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_9 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_10 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_11 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_12 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_13 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_14 ;
        // @( posedge clk );
        //     S_AXIS_MM2S_TVALID = 0 ;
        //     S_AXIS_MM2S_TDATA	= 64'd0 ;
        // #( `CYCLE*10);
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_15 ;
            S_AXIS_MM2S_TLAST = 1 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TLAST = 0 ;
            S_AXIS_MM2S_TVALID = 0 ;
        //----- instruction done --------------

        wait(tb_memread_done) ;
        #( `CYCLE*5 ) ;

        // //---- FFN HEAD ----
        // @( posedge clk );#0.8;
        //     S_AXIS_MM2S_TVALID = 1 ;
        //     S_AXIS_MM2S_TDATA	= FFN_HEAD ;
        //     S_AXIS_MM2S_TLAST = 0 ;
        //     wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );#0.8;
        //     S_AXIS_MM2S_TLAST = 0 ;
        //     S_AXIS_MM2S_TVALID = 0 ;
        // #( `CYCLE*10);
        // @( posedge clk );#0.8;
        //     S_AXIS_MM2S_TVALID = 1 ;
        //     S_AXIS_MM2S_TDATA	= FFN_HEAD ;
        //     S_AXIS_MM2S_TLAST = 1 ;
        //     wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );#0.8;
        //     S_AXIS_MM2S_TLAST = 0 ;
        //     S_AXIS_MM2S_TVALID = 0 ;
        // #( `CYCLE*30 ) ;

        // //---- FFN HEAD ----
        // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
        // wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
        // S_AXIS_MM2S_TLAST	= 1;	// last signal 
        // wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;
    
        //------------------------------------------------
        //---- first load -- sending input data ----
        //---- DATA HEAD ----
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;	
        S_AXIS_MM2S_TLAST	= 1;	// last signal 
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;
        //---- DATA HEAD end---------------------

        // //---- FFN HEAD ----
        // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
        // wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
        // S_AXIS_MM2S_TLAST	= 1;	// last signal 
        // wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

        //------------ now send input sram data -----
        for ( i0=0 ; i0<TB_RUN_COL*TB_RUN_ROW ; i0=i0+1 )begin
            @(posedge clk ); #( `CYCLE/2.5 );
            S_AXIS_MM2S_TVALID	=	1	;
            S_AXIS_MM2S_TDATA = ifmap_data_temp[ ifmap_addr ]	;
            ifmap_addr = ifmap_addr + 1 ;
            if( i0 == TB_RUN_COL*TB_RUN_ROW -1 )begin
                S_AXIS_MM2S_TLAST = 1; 
            end
            wait(S_AXIS_MM2S_TREADY);
        end
        @(posedge clk ) ; #( `CYCLE/2.5 );
        S_AXIS_MM2S_TVALID = 0 ;
        S_AXIS_MM2S_TLAST = 0 ;

        // //---- FFN HEAD ----
        // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
        // wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
        // S_AXIS_MM2S_TLAST	= 1;	// last signal 
        // wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

        // //------------------------------------------------
        // //---- first load -- sending bias data ----
        // //---- DATA HEAD ----
        // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;
        // wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;	
        // S_AXIS_MM2S_TLAST	= 1;	// last signal 
        // wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

        //---- DATA HEAD ----
        @( posedge clk );#0.8;
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= DATA_HEAD ;
            S_AXIS_MM2S_TLAST = 0 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );#0.8;
            S_AXIS_MM2S_TLAST = 0 ;
            S_AXIS_MM2S_TVALID = 0 ;
        #( `CYCLE*10);
        @( posedge clk );#0.8;
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= DATA_HEAD ;
            S_AXIS_MM2S_TLAST = 1 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );#0.8;
            S_AXIS_MM2S_TLAST = 0 ;
            S_AXIS_MM2S_TVALID = 0 ;
        #( `CYCLE*30 ) ;
        //---- DATA HEAD end---------------------

        // //---- FFN HEAD ----
        // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
        // wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
        // S_AXIS_MM2S_TLAST	= 1;	// last signal 
        // wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

        // //---- FFN HEAD ----
        // @( posedge clk );#0.8;
        //     S_AXIS_MM2S_TVALID = 1 ;
        //     S_AXIS_MM2S_TDATA	= FFN_HEAD ;
        //     S_AXIS_MM2S_TLAST = 0 ;
        //     wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );#0.8;
        //     S_AXIS_MM2S_TLAST = 0 ;
        //     S_AXIS_MM2S_TVALID = 0 ;
        // #( `CYCLE*10);
        // @( posedge clk );#0.8;
        //     S_AXIS_MM2S_TVALID = 1 ;
        //     S_AXIS_MM2S_TDATA	= FFN_HEAD ;
        //     S_AXIS_MM2S_TLAST = 1 ;
        //     wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );#0.8;
        //     S_AXIS_MM2S_TLAST = 0 ;
        //     S_AXIS_MM2S_TVALID = 0 ;
        // #( `CYCLE*30 ) ;

        //------------ now send bias sram data -----
        for ( i0=0 ; i0<TB_RUN_BIAS_LENGTH/4 ; i0=i0+1 )begin	   
            @(posedge clk );#( `CYCLE/2.5 );
            S_AXIS_MM2S_TVALID	=	1	;
            S_AXIS_MM2S_TDATA = bias_array_temp[ bias_addr ] 	;
            bias_addr = bias_addr + 1 ;
            if( i0 == TB_RUN_BIAS_LENGTH/4-1 )begin
                S_AXIS_MM2S_TLAST = 1;
            end
            wait(S_AXIS_MM2S_TREADY);
            if( i0 == TB_RUN_BIAS_LENGTH/4-7 )begin
                @( posedge clk );#( `CYCLE/2.5 );
                S_AXIS_MM2S_TVALID = 0 ;
                S_AXIS_MM2S_TDATA	= 'd0 ;
                #( `CYCLE*10);
            end
        end
        @(posedge clk ) ;#( `CYCLE/2.5 );
        S_AXIS_MM2S_TVALID = 0 ;
        S_AXIS_MM2S_TLAST = 0 ;

        // //---- FFN HEAD ----
        // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
        // wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
        // S_AXIS_MM2S_TLAST	= 1;	// last signal 
        // wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

        //------------------------------------------------
        //---- first load -- sending kernel data ----
        //---- DATA HEAD ----
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;	
        S_AXIS_MM2S_TLAST	= 1;	// last signal 
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;
        //---- DATA HEAD end---------------------

        // //---- FFN HEAD ----
        // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
        // wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
        // S_AXIS_MM2S_TLAST	= 1;	// last signal 
        // wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

        //------------ now send kernel sram data -----
        for ( i0=0 ; i0<TB_KER_ROW * 16 ; i0=i0+1 )begin	   // 16 = ker_col (PEBLKCOL_NUM, Phase 1b)
            @(posedge clk );#( `CYCLE/2.5 );
            S_AXIS_MM2S_TVALID	=	1	;
            S_AXIS_MM2S_TDATA = ker_array_temp[ ker_addr ] 	;
            ker_addr = ker_addr + 1 ;
            if( i0 == TB_KER_ROW * 16 - 1 )begin
                S_AXIS_MM2S_TLAST = 1;
            end
            wait(S_AXIS_MM2S_TREADY);
            if( i0 == TB_KER_ROW * 16 - 15 )begin
                @( posedge clk );#( `CYCLE/2.5 );
                S_AXIS_MM2S_TVALID = 0 ;
                S_AXIS_MM2S_TDATA	= 'd0 ;
                #( `CYCLE*10);
            end
        end
        @(posedge clk ) ;#( `CYCLE/2.5 );
            S_AXIS_MM2S_TVALID = 0 ;
            S_AXIS_MM2S_TLAST = 0 ;

        // ===========================================================================
        // =======		FFN base start     =======================
        // ===========================================================================
        for(i1=0; i1<3; i1=i1+1)begin

            // //---- FFN HEAD ----
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
            // S_AXIS_MM2S_TLAST	= 1;	// last signal 
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

            //------------ now send kernel sram data -----
            //---- DATA HEAD -----------------------
            i0 = 0 ;
            while ( i0< 2 ) begin
                @(posedge clk ); #( `CYCLE/2.5 );
                S_AXIS_MM2S_TVALID	=	1	;
                S_AXIS_MM2S_TDATA = DATA_HEAD ;
                if( i0 == 1  & S_AXIS_MM2S_TREADY )begin
                    S_AXIS_MM2S_TLAST = 1; 
                    i0=i0+1;
                end
                else if ( i0 == 1  & ~S_AXIS_MM2S_TREADY)begin
                    S_AXIS_MM2S_TLAST = 0; 
                    S_AXIS_MM2S_TVALID	=	0	;
                    i0=i0+0;
                end
                else begin
                    i0=i0+1;
                end
                wait(S_AXIS_MM2S_TREADY);
            end
            @( posedge clk ); #( `CYCLE/2.5 ); 	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;
	        //---- DATA HEAD end---------------------

            // //---- FFN HEAD ----
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
            // S_AXIS_MM2S_TLAST	= 1;	// last signal 
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

            for ( i0=0 ; i0<TB_KER_ROW * 512 ; i0=i0+1 )begin
                @(posedge clk ); #( `CYCLE/2.5 );
                S_AXIS_MM2S_TVALID	=	1	;
                S_AXIS_MM2S_TDATA = ker_array_temp[ ker_addr ]	;
                ker_addr = ker_addr + 1 ;
                if( i0 == TB_KER_ROW * 512 - 1 )begin
                    S_AXIS_MM2S_TLAST = 1; 
                end
                wait(S_AXIS_MM2S_TREADY);
            end
	        @(posedge clk);#( `CYCLE/2.5 );
	        S_AXIS_MM2S_TVALID = 0 ;
	        S_AXIS_MM2S_TLAST = 0 ;

            // //---- FFN HEAD ----
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
            // S_AXIS_MM2S_TLAST	= 1;	// last signal 
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

            //------------ now send bias sram data -----
            //---- DATA HEAD ----
            @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;
            wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;	
            S_AXIS_MM2S_TLAST	= 1;	// last signal 
            wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;
            //---- DATA HEAD end---------------------

            // //---- FFN HEAD ----
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
            // S_AXIS_MM2S_TLAST	= 1;	// last signal 
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

            for ( i0=0 ; i0<TB_RUN_BIAS_LENGTH/4 ; i0=i0+1 )begin	   
                @(posedge clk );#( `CYCLE/2.5 );
                S_AXIS_MM2S_TVALID	=	1	;
                S_AXIS_MM2S_TDATA = bias_array_temp[ bias_addr ] 	;
                bias_addr = bias_addr + 1 ;
                if( i0 == TB_RUN_BIAS_LENGTH/4-1 )begin
                    S_AXIS_MM2S_TLAST = 1;
                end
                wait(S_AXIS_MM2S_TREADY);
            end
            @(posedge clk ) ;#( `CYCLE/2.5 );
                S_AXIS_MM2S_TVALID = 0 ;
                S_AXIS_MM2S_TLAST = 0 ;
        end

        // //---- FFN HEAD ----
        // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
        // wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
        // S_AXIS_MM2S_TLAST	= 1;	// last signal 
        // wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

        //------------ now send kernel sram data -----
        //---- DATA HEAD ----
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;	
        S_AXIS_MM2S_TLAST	= 1;	// last signal 
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;
        //---- DATA HEAD end---------------------

        // //---- FFN HEAD ----
        // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
        // wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
        // S_AXIS_MM2S_TLAST	= 1;	// last signal 
        // wait(S_AXIS_MM2S_TREADY);
        // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

        for ( i0=0; i0<TB_KER_ROW * ( 512 - 16 ); i0=i0+1)begin  
            @(posedge clk );#( `CYCLE/2.5 );
            S_AXIS_MM2S_TVALID	=	1	;
            S_AXIS_MM2S_TDATA = ker_array_temp[ ker_addr ]	;
            ker_addr = ker_addr + 1 ;
            if( i0 == TB_KER_ROW * ( 512 - 16 ) - 1 )begin
                S_AXIS_MM2S_TLAST = 1; 
            end
            wait(S_AXIS_MM2S_TREADY);
        end
        @(posedge clk ) ;#( `CYCLE/2.5 );
            S_AXIS_MM2S_TVALID = 0 ;
            S_AXIS_MM2S_TLAST = 0 ;
		
        #( `CYCLE*2000) ;          // let this pass drain before starting the next
        $display(">>> ---- PASS %0d done  (cycle %0d, tb_o_cnt = %0d) ----", pass_id, cycle, tb_o_cnt);
        end

        dutot_done = 1 ;	// all passes done, compare now
    
    //---------- FFN2 testbench control ----
    `elsif FFN2
        FFN_start = 1;
        #1;
        reset = 0;
        S_AXIS_MM2S_TVALID = 0 ;
        #( `CYCLE*3 ) ;
        reset = 1;
        ifmap_addr = 0 ;

        //-----------reset signal start ------------------
        S_AXIS_MM2S_TKEEP = 'hff;
        S_AXIS_MM2S_TLAST = 0 ;
        dutot_done =0 ;

        //-----------reset signal end ------------------
        #( `CYCLE*15 + `NI_DELAY ) ;
        reset = 0;
        #( `CYCLE*5 ) ;

        for(i1=0; i1<4; i1=i1+1)begin
            bias_addr = 0 ;
            ker_addr = 0 ;

            // //---- FFN HEAD ----
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
            // S_AXIS_MM2S_TLAST	= 1;	// last signal 
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

            // //----- instruction head --------------
            // @( posedge clk );#0.8;
            //     S_AXIS_MM2S_TVALID = 1 ;
            //     S_AXIS_MM2S_TDATA	= INST_HEAD ;
            //     S_AXIS_MM2S_TLAST = 1 ;
            //     wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );#0.8;
            //     S_AXIS_MM2S_TLAST = 0 ;
            //     S_AXIS_MM2S_TVALID = 0 ;
            // #( `CYCLE*10);

            //---- FFN HEAD ----
            @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
            wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
            S_AXIS_MM2S_TLAST	= 1;	// last signal 
            wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

            // //----- instruction head --------------
            // @( posedge clk );#0.8;
            //     S_AXIS_MM2S_TVALID = 1 ;
            //     S_AXIS_MM2S_TDATA	= INST_HEAD ;
            //     S_AXIS_MM2S_TLAST = 1 ;
            //     wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );#0.8;
            //     S_AXIS_MM2S_TLAST = 0 ;
            //     S_AXIS_MM2S_TVALID = 0 ;
            // #( `CYCLE*30 ) ;

            //----- instruction head --------------
            @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= INST_HEAD ;
            wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= INST_HEAD ;	
            S_AXIS_MM2S_TLAST	= 1;	// last signal 
            wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

            // //---- FFN HEAD ----
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
            // S_AXIS_MM2S_TLAST	= 1;	// last signal 
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

            //----- instruction config--------------
            @( posedge clk );
                S_AXIS_MM2S_TVALID = 1 ;
                S_AXIS_MM2S_TDATA	= CFG_0 ;
                wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );
                S_AXIS_MM2S_TVALID = 1 ;
                S_AXIS_MM2S_TDATA	= CFG_1 ;
                wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );
                S_AXIS_MM2S_TVALID = 1 ;
                S_AXIS_MM2S_TDATA	= CFG_2 ;
                wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );
                S_AXIS_MM2S_TVALID = 1 ;
                S_AXIS_MM2S_TDATA	= CFG_3 ;
                wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );
                S_AXIS_MM2S_TVALID = 1 ;
                S_AXIS_MM2S_TDATA	= CFG_4 ;
                wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );
                S_AXIS_MM2S_TVALID = 1 ;
                S_AXIS_MM2S_TDATA	= CFG_5 ;
                wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );
                S_AXIS_MM2S_TVALID = 1 ;
                S_AXIS_MM2S_TDATA	= CFG_6 ;
                wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );
                S_AXIS_MM2S_TVALID = 1 ;
                S_AXIS_MM2S_TDATA	= CFG_7 ;
                wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );
                S_AXIS_MM2S_TVALID = 1 ;
                S_AXIS_MM2S_TDATA	= CFG_8 ;
                wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );
                S_AXIS_MM2S_TVALID = 1 ;
                S_AXIS_MM2S_TDATA	= CFG_9 ;
                wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );
                S_AXIS_MM2S_TVALID = 1 ;
                S_AXIS_MM2S_TDATA	= CFG_10 ;
                wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );
                S_AXIS_MM2S_TVALID = 1 ;
                S_AXIS_MM2S_TDATA	= CFG_11 ;
                wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );
                S_AXIS_MM2S_TVALID = 1 ;
                S_AXIS_MM2S_TDATA	= CFG_12 ;
                wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );
                S_AXIS_MM2S_TVALID = 1 ;
                S_AXIS_MM2S_TDATA	= CFG_13 ;
                wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );
                S_AXIS_MM2S_TVALID = 1 ;
                S_AXIS_MM2S_TDATA	= CFG_14 ;
                wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );
                S_AXIS_MM2S_TVALID = 1 ;
                S_AXIS_MM2S_TDATA	= CFG_15 ;
                S_AXIS_MM2S_TLAST = 1 ;
                wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );
                S_AXIS_MM2S_TLAST = 0 ;
                S_AXIS_MM2S_TVALID = 0 ;
            //----- instruction done --------------

            // //---- FFN HEAD ----
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
            // S_AXIS_MM2S_TLAST	= 1;	// last signal 
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

            //------------------------------------------------
            //---- first load -- sending input data ----
            //---- DATA HEAD ----
            @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;
            wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;	
            S_AXIS_MM2S_TLAST	= 1;	// last signal 
            wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;
            //---- DATA HEAD end---------------------

            // //---- FFN HEAD ----
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
            // S_AXIS_MM2S_TLAST	= 1;	// last signal 
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

            //------------ now send input sram  data -----
            for ( i0=0 ; i0<TB_RUN_COL*TB_RUN_ROW/4 ; i0=i0+1 )begin
                @(posedge clk ); #( `CYCLE/2.5 );
                S_AXIS_MM2S_TVALID	=	1	;
                S_AXIS_MM2S_TDATA = ifmap_data_temp[ ifmap_addr ]	;
                ifmap_addr = ifmap_addr + 1 ;
                if( i0 == TB_RUN_COL*TB_RUN_ROW/4 -1 )begin
                    S_AXIS_MM2S_TLAST = 1; 
                end
                wait(S_AXIS_MM2S_TREADY);
            end
            @(posedge clk ) ; #( `CYCLE/2.5 );
                S_AXIS_MM2S_TVALID = 0 ;
                S_AXIS_MM2S_TLAST = 0 ;

            // //---- FFN HEAD ----
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
            // S_AXIS_MM2S_TLAST	= 1;	// last signal 
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

            //------------------------------------------------
            //---- first load -- sending bias data ----
            //---- DATA HEAD ----
            @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;
            wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;	
            S_AXIS_MM2S_TLAST	= 1;	// last signal 
            wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;
            //---- DATA HEAD end---------------------

            // //---- FFN HEAD ----
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
            // S_AXIS_MM2S_TLAST	= 1;	// last signal 
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

            //------------ now send bias sram data -----
            for ( i0=0 ; i0<TB_RUN_BIAS_LENGTH ; i0=i0+1 )begin	   
                @(posedge clk );#( `CYCLE/2.5 );
                S_AXIS_MM2S_TVALID	=	1	;
                S_AXIS_MM2S_TDATA = bias_array_temp[ bias_addr ] 	;
                bias_addr = bias_addr + 1 ;
                if( i0 == TB_RUN_BIAS_LENGTH-1 )begin
                    S_AXIS_MM2S_TLAST = 1;
                end
                wait(S_AXIS_MM2S_TREADY);
            end
            @(posedge clk ) ; #( `CYCLE/2.5 );
                S_AXIS_MM2S_TVALID = 0 ;
                S_AXIS_MM2S_TLAST = 0 ;

            // //---- FFN HEAD ----
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
            // S_AXIS_MM2S_TLAST	= 1;	// last signal 
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

            //------------------------------------------------
            //---- first load -- sending kernel data ----
            //---- DATA HEAD ----
            @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;
            wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;	
            S_AXIS_MM2S_TLAST	= 1;	// last signal 
            wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;
            //---- DATA HEAD end---------------------

            // //---- FFN HEAD ----
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
            // S_AXIS_MM2S_TLAST	= 1;	// last signal 
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

            //------------ now send kernel sram data -----
            for ( i0=0 ; i0<TB_KER_ROW * 16 ; i0=i0+1 )begin	   // 16 = ker_col (PEBLKCOL_NUM, Phase 1b)
                @(posedge clk );#( `CYCLE/2.5 );
                S_AXIS_MM2S_TVALID	=	1	;
                S_AXIS_MM2S_TDATA = ker_array_temp[ ker_addr ] 	;
                ker_addr = ker_addr + 1 ;
                if( i0 == TB_KER_ROW * 16 - 1 )begin
                    S_AXIS_MM2S_TLAST = 1;
                end
                wait(S_AXIS_MM2S_TREADY);
            end
            @(posedge clk ) ; #( `CYCLE/2.5 );
                S_AXIS_MM2S_TVALID = 0 ;
                S_AXIS_MM2S_TLAST = 0 ;

            // ===========================================================================
            // =======		FFN base start 		======================
            // ===========================================================================
            //----- after first load data we going to send kernel data  --------------

            // //---- FFN HEAD ----
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
            // S_AXIS_MM2S_TLAST	= 1;	// last signal 
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

            //---- DATA HEAD -----------------------
            i0 = 0 ;
            while ( i0< 2 ) begin
                @(posedge clk ); #( `CYCLE/2.5 );
                S_AXIS_MM2S_TVALID	=	1	;
                S_AXIS_MM2S_TDATA = DATA_HEAD ;
                if( i0 == 1  & S_AXIS_MM2S_TREADY )begin
                    S_AXIS_MM2S_TLAST = 1; 
                    i0=i0+1;
                end
                else if ( i0 == 1  & ~S_AXIS_MM2S_TREADY)begin
                    S_AXIS_MM2S_TLAST = 0; 
                    S_AXIS_MM2S_TVALID	=	0	;
                    i0=i0+0;
                end
                else begin
                    i0=i0+1;
                end
                wait(S_AXIS_MM2S_TREADY);
            end
            @( posedge clk ); #( `CYCLE/2.5 ); 	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;
            //---- DATA HEAD end---------------------

            // //---- FFN HEAD ----
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
            // S_AXIS_MM2S_TLAST	= 1;	// last signal 
            // wait(S_AXIS_MM2S_TREADY);
            // @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

            for ( i0=0 ; i0<TB_KER_ROW * (512-16) ; i0=i0+1 )begin
                @(posedge clk ); #( `CYCLE/2.5 );
                S_AXIS_MM2S_TVALID	=	1	;
                S_AXIS_MM2S_TDATA = ker_array_temp[ ker_addr ]	;
                ker_addr = ker_addr + 1 ;
                if( i0 == TB_KER_ROW * (512-16) - 1 )begin
                    S_AXIS_MM2S_TLAST = 1; 
                end
                wait(S_AXIS_MM2S_TREADY);
            end
            @(posedge clk); #( `CYCLE/2.5 );
                S_AXIS_MM2S_TVALID = 0 ;
                S_AXIS_MM2S_TLAST = 0 ;
            //------------------------------------------------

            wait(ot_addr % 64 == 63) ;
            #( `CYCLE*100) ;

        end

    //---------- Q generation testbench control ----
    `elsif Q_Gen
        FFN_start = 1;
        #1;
        reset = 0;
        S_AXIS_MM2S_TVALID = 0 ;
        #( `CYCLE*3 ) ;
        reset = 1;
        ifmap_addr = 0 ;

        //-----------reset signal start ------------------
        S_AXIS_MM2S_TKEEP = 'hff;
        S_AXIS_MM2S_TLAST = 0 ;
        dutot_done =0 ;

        //-----------reset signal end ------------------
        #( `CYCLE*15 + `NI_DELAY ) ;
        reset = 0;
        #( `CYCLE*5 ) ;

        bias_addr = 0 ;
        ker_addr = 0 ;

        //---- FFN HEAD ----
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= FFN_HEAD ;	
        S_AXIS_MM2S_TLAST	= 1;	// last signal 
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

        //----- instruction head --------------
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= INST_HEAD ;
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= INST_HEAD ;	
        S_AXIS_MM2S_TLAST	= 1;	// last signal 
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

        //----- instruction config--------------
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_0 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_1 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_2 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_3 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_4 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_5 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_6 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_7 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_8 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_9 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_10 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_11 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_12 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_13 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_14 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= CFG_15 ;
            S_AXIS_MM2S_TLAST = 1 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TLAST = 0 ;
            S_AXIS_MM2S_TVALID = 0 ;
        //----- instruction done --------------

        //------------------------------------------------
        //---- first load -- sending input data ----
        //---- DATA HEAD ----
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;	
        S_AXIS_MM2S_TLAST	= 1;	// last signal 
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;
        //---- DATA HEAD end---------------------

        //------------ now send input sram  data -----
        for ( i0=0 ; i0<TB_RUN_COL*TB_RUN_ROW ; i0=i0+1 )begin
            @(posedge clk ); #( `CYCLE/2.5 );
            S_AXIS_MM2S_TVALID	=	1	;
            S_AXIS_MM2S_TDATA = ifmap_data_temp[ ifmap_addr ]	;
            ifmap_addr = ifmap_addr + 1 ;
            if( i0 == TB_RUN_COL*TB_RUN_ROW -1 )begin
                S_AXIS_MM2S_TLAST = 1; 
            end
            wait(S_AXIS_MM2S_TREADY);
        end
        @(posedge clk ) ; #( `CYCLE/2.5 );
            S_AXIS_MM2S_TVALID = 0 ;
            S_AXIS_MM2S_TLAST = 0 ;

        //------------------------------------------------
        //---- first load -- sending bias data ----
        //---- DATA HEAD ----
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;	
        S_AXIS_MM2S_TLAST	= 1;	// last signal 
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;
        //---- DATA HEAD end---------------------

        //------------ now send bias sram data -----
        for ( i0=0 ; i0<TB_RUN_BIAS_LENGTH ; i0=i0+1 )begin	   
            @(posedge clk );#( `CYCLE/2.5 );
            S_AXIS_MM2S_TVALID	=	1	;
            S_AXIS_MM2S_TDATA = bias_array_temp[ bias_addr ] 	;
            bias_addr = bias_addr + 1 ;
            if( i0 == TB_RUN_BIAS_LENGTH-1 )begin
                S_AXIS_MM2S_TLAST = 1;
            end
            wait(S_AXIS_MM2S_TREADY);
        end
        @(posedge clk ) ; #( `CYCLE/2.5 );
            S_AXIS_MM2S_TVALID = 0 ;
            S_AXIS_MM2S_TLAST = 0 ;

        //------------------------------------------------
        //---- first load -- sending kernel data ----
        //---- DATA HEAD ----
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= DATA_HEAD ;	
        S_AXIS_MM2S_TLAST	= 1;	// last signal 
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;
        //---- DATA HEAD end---------------------

        //------------ now send kernel sram data -----
        for ( i0=0 ; i0<TB_KER_ROW * 16 ; i0=i0+1 )begin	   // 16 = ker_col (PEBLKCOL_NUM, Phase 1b)
            @(posedge clk );#( `CYCLE/2.5 );
            S_AXIS_MM2S_TVALID	=	1	;
            S_AXIS_MM2S_TDATA = ker_array_temp[ ker_addr ] 	;
            ker_addr = ker_addr + 1 ;
            if( i0 == TB_KER_ROW * 16 - 1 )begin
                S_AXIS_MM2S_TLAST = 1;
            end
            wait(S_AXIS_MM2S_TREADY);
        end
        @(posedge clk ) ; #( `CYCLE/2.5 );
            S_AXIS_MM2S_TVALID = 0 ;
            S_AXIS_MM2S_TLAST = 0 ;

        //---- DATA HEAD -----------------------
        i0 = 0 ;
        while ( i0< 2 ) begin
            @(posedge clk ); #( `CYCLE/2.5 );
            S_AXIS_MM2S_TVALID	=	1	;
            S_AXIS_MM2S_TDATA = DATA_HEAD ;
            if( i0 == 1  & S_AXIS_MM2S_TREADY )begin
                S_AXIS_MM2S_TLAST = 1; 
                i0=i0+1;
            end
            else if ( i0 == 1  & ~S_AXIS_MM2S_TREADY)begin
                S_AXIS_MM2S_TLAST = 0; 
                S_AXIS_MM2S_TVALID	=	0	;
                i0=i0+0;
            end
            else begin
                i0=i0+1;
            end
            wait(S_AXIS_MM2S_TREADY);
        end
        @( posedge clk ); #( `CYCLE/2.5 ); 	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;
        //---- DATA HEAD end---------------------

        for ( i0=0 ; i0<TB_KER_ROW * (512-16) ; i0=i0+1 )begin
            @(posedge clk ); #( `CYCLE/2.5 );
            S_AXIS_MM2S_TVALID	=	1	;
            S_AXIS_MM2S_TDATA = ker_array_temp[ ker_addr ]	;
            ker_addr = ker_addr + 1 ;
            if( i0 == TB_KER_ROW * (512-16) - 1 )begin
                S_AXIS_MM2S_TLAST = 1; 
            end
            wait(S_AXIS_MM2S_TREADY);
        end
        @(posedge clk); #( `CYCLE/2.5 );
            S_AXIS_MM2S_TVALID = 0 ;
            S_AXIS_MM2S_TLAST = 0 ;
        //------------------------------------------------

        wait(ot_addr % 64 == 63) ;
        #( `CYCLE*100) ;

    `endif

	#( `CYCLE*4000) ;
    dutot_done = 1 ;	// output done now for compare 

end 


// =============================================================================
// ===============		Output feature counting		============================
// =============================================================================
initial begin

	`ifdef EZ_S2MM_TREADY_SET

    M_AXIS_S2MM_TREADY = 1'd0;
    wait( reset );
    M_AXIS_S2MM_TREADY = 1'd1;

    `else 

	M_AXIS_S2MM_TREADY = 1'd0;
	wait( reset );
	M_AXIS_S2MM_TREADY = 1'd1;

	wait( tb_o_cnt >20 );
    @(posedge clk); #0.01 ;
    M_AXIS_S2MM_TREADY = 1'd0;
    #( `CYCLE*2000 ) ;
    @(posedge clk); #0.01 ;
    M_AXIS_S2MM_TREADY = 1'd1;
    
	wait( tb_o_cnt >450 );
    @(posedge clk); #0.01 ;
    M_AXIS_S2MM_TREADY = 1'd0;
    #( `CYCLE*2000 ) ;
    @(posedge clk); #0.01 ;
    M_AXIS_S2MM_TREADY = 1'd1;

    wait( tb_o_cnt >502 );
	@(posedge clk); #0.01 ;
	M_AXIS_S2MM_TREADY = 1'd0;
	#( `CYCLE*500 ) ;
	@(posedge clk); #0.01 ;
	M_AXIS_S2MM_TREADY = 1'd1;

	wait( tb_o_cnt >508 );
	@(posedge clk); #0.01 ;
	M_AXIS_S2MM_TREADY = 1'd0;
	#( `CYCLE*200 ) ;
	@(posedge clk); #0.01 ;
	M_AXIS_S2MM_TREADY = 1'd1;

	`endif 

end

always @(posedge clk ) begin
    if(reset)
        tb_o_cnt <= 0 ;
    else if( M_AXIS_S2MM_TREADY && M_AXIS_S2MM_TVALID && FFN_start )
        tb_o_cnt <= tb_o_cnt +1  ;
end

`ifdef FFN1
    always @(posedge clk) begin
        if(reset || pass_rst) begin
            ot_token_sub1 <= 0 ;
            ot_addr <= 0 ;
        end
        else if(M_AXIS_S2MM_TREADY && M_AXIS_S2MM_TVALID && FFN_start) begin
            if(ot_addr % 64 == 63) begin
                if(ot_token_sub1 % 8 == 7) begin
                    case(ot_addr)
                        (ot_token_sub1 + 1) * 256 - 64 * 3 - 1 : ot_addr <= 64 ;
                        (ot_token_sub1 + 1) * 256 - 64 * 2 - 1 : ot_addr <= 128 ;
                        (ot_token_sub1 + 1) * 256 - 64 * 1 - 1 : ot_addr <= 192 ;
                    endcase
                    ot_token_sub1 <= 0 ;
                end
                else begin
                    ot_addr <= ot_addr + (256 - 63) ;
                    ot_token_sub1 <= ot_token_sub1 + 1 ;
                end
            end
            else
                ot_addr <= ot_addr + 1 ;
        end
    end
`else
    always @(posedge clk) begin
        if(reset || pass_rst) begin
            ot_addr <= 0 ;
        end
        else if(M_AXIS_S2MM_TREADY && M_AXIS_S2MM_TVALID && FFN_start) begin
            ot_addr <= ot_addr + 1 ;
        end
    end
`endif
always @(posedge clk) begin
    if( M_AXIS_S2MM_TREADY && M_AXIS_S2MM_TVALID && FFN_start )
        ofm_array [ pass_id*TB_GOLD_WORDS + ot_addr ] <= M_AXIS_S2MM_TDATA ;
end
// integer ans1 = 0;
// integer ans2 = 0;
// integer w_num1 = 0;
// integer w_num2 = 0;
// reg  [31:0]  addr1 ,  addr1_dly  ;
// always @(posedge clk) begin
    
//         addr1 <= tp001.if_top_inst.read_addr_if_sram_0;
//         addr1_dly <= addr1;
// end
// always @(posedge clk) begin
//     if(tp001.pe_top_inst.blkpe_r0.pe_col0.valid_in_dly0)begin
//         ans1 <=  (addr1_dly <= 255) ? ans1+1 : ans1 ;
//         w_num1 <= (ans1%256 == 255) ? w_num1 + 1 : w_num1;
//         w_num2 <= (ans2%256 == 255) ? w_num2 + 1 : w_num2;
//         ans2 <=  (addr1_dly > 255) ? ans2+1 : ans2 ;
//         if(addr1_dly <= 255 && (tp001.pe_top_inst.blkpe_r0.pe_col0.stage0_ker_0 != ker_array_temp[ans1+w_num1*256*7][63:56]) ) $display("WEIGHT_NUM = %d ,ans1_num = %d ,dout_ker_sram_0_t0 = %h, gold_ker_in = %h " , w_num1, ans1, tp001.pe_top_inst.blkpe_r0.pe_col0.stage0_ker_0, ker_array_temp[ans1+w_num1*256*7][63:56]);
//         else if(addr1_dly > 255 && (tp001.pe_top_inst.blkpe_r0.pe_col0.stage0_ker_0 != ker_array_temp[ans2+w_num2*256*7][63:56]) ) $display("WEIGHT_NUM = %d ,ans2_num = %d ,dout_ker_sram_0_t1 = %h, gold_ker_in = %h", w_num2, ans2, tp001.pe_top_inst.blkpe_r0.pe_col0.stage0_ker_0, ker_array_temp[ans2+w_num2*256*7][63:56]);
// end
// end
// integer ans_in1 = 0;
// integer ans_in2 = 0;
// integer in_num1 = 0;
// integer in_num2 = 0;
// always@(posedge clk) begin
//     if(tp001.pe_top_inst.blkpe_r0.pe_col0.valid_in_dly0)begin
//         ans_in1 <=  (addr1_dly <= 255) ? ans_in1+1 : 0 ;
//         in_num1 <= (ans_in1 == 255) ? in_num1 + 1 : in_num1;
//         in_num2 <= (ans_in2 == 255) ? in_num2 + 1 : in_num2;
//         ans_in2 <=  (addr1_dly > 255) ? ans_in2+1 : 0 ;
//         if(addr1_dly <= 255 && (tp001.pe_top_inst.blkpe_r0.pe_col0.stage0_input_0 != ifmap_data_temp[ans_in1][63:56]) ) $display("INPUT_NUM = %d ,ans_in1_num = %d ,stage0_ifmap_0_t0 = %h, gold_ifmap = %h " , in_num1, ans_in1, tp001.pe_top_inst.blkpe_r0.pe_col0.stage0_input_0, ifmap_data_temp[ans_in1][63:56]);
//         else if(addr1_dly > 255 && (tp001.pe_top_inst.blkpe_r0.pe_col0.stage0_input_0 != ifmap_data_temp[ans_in2+256][63:56]) ) $display("INPUT_NUM = %d ,ans_in2_num = %d ,stage0_ifmap_0_t1 = %h, gold_ifmap = %h", in_num2, ans_in2, tp001.pe_top_inst.blkpe_r0.pe_col0.stage0_input_0, ifmap_data_temp[ans_in2+256][63:56]);
//     end
// end
// =============================================================================
// ===============		compare data block		================================
// =============================================================================
    // initial begin
    //     #1;
    //     wait( reset ) ;
    //     #( `CYCLE*5 ) ;   
    //     wait( dutot_done ) ;	// wait DUT output data all done
        // err_ofmap = 0;
        // icp = 0;
        // for (icp = 0; icp<OT_NUM_FORCMP ; icp= icp+1 ) begin
        //     if(  ofm_array[icp] !== ofm_gold[icp] ) begin
        //         err_ofmap = err_ofmap +1 ;
        //         $display("** error : number => %d , error pattern => %16x , gold pattern => %16x        **",icp,ofm_array[icp],ofm_gold[icp]  );
        //     end
        // end

        // //----display the compare result on terminal ----
        // $display("********************************************************************");
        // $display("**  ---- the compare result -----                                 **");
        // $display("**  row_in=%3d ,ch_in= %3d ,col_out= %3d ,ch_out= %3d             **", TB_RUN_OTROW,TB_PAT_IFCH,TB_RUN_COL,TB_RUN_OTCH );
        // $display("**  number of output data = %3d . compare with %3d gold pattern   **", tb_o_cnt , OT_NUM_FORCMP);
        // $display("**  ofmap errors = %3d                                            **", err_ofmap );
        // $display("**    ------------------------------                              **");
        // $display("**  please check the error number ,Simulation STOP at cycle %d **",cycle);
        // $display("**  If needed, You can increase End_CYCLE value in tb.sv          **");
        // $display("********************************************************************");

        // $finish;

    // end
//--------------------------------------------------------------------------

// =============================================================================

// =============================================================================
// ===============		watchdog		========================================
// =============================================================================
//  The stimulus is back-pressured by the DUT, so a stall inside the design
//  hangs the whole simulation with no verdict. Force one instead.
//  FFN1 is ~1.37M ns; FFN2 reloads the kernel x4 so it needs a bigger budget.
    initial begin
        #( `CYCLE * 800000 ) ;
        if( !dutot_done ) begin
            $display("====================================================================");
            $display(">>> WATCHDOG: stream/DUT stalled; produced ot_addr=%0d output words.", ot_addr);
            $display(">>> WATCHDOG: streamed so far -> ker_addr=%0d (full=%0d), bias_addr=%0d, ifmap_addr=%0d",
                     ker_addr, TB_RUN_KERSRAM_LENGTH, bias_addr, ifmap_addr);
            $display(">>> WATCHDOG: FSM state=%0d mode=%0d | SA_busy=%b NORM_busy=%b FFN_busy=%b",
                     tp001.curr_state, tp001.mode, tp001.SA_busy, tp001.NORM_busy, tp001.FFN_busy);
            $display("====================================================================");
            dutot_done = 1 ;            // let the compare block run with what was produced
        end
    end

// =============================================================================
// ===============		compare data block		================================
// =============================================================================
//  FFN-only. In SOFTMAX mode the FFN path is never exercised, so tb_o_cnt is 0
//  and this block would print a misleading "DUT produced no output" FAIL right
//  after the softmax comparison has already reported its own verdict.
`ifndef SOFTMAX
    initial begin
        #1;
        wait( reset ) ;
        #( `CYCLE*5 ) ;
        wait( dutot_done ) ;	// wait DUT output data all done
        err_ofmap = 0;
        icp = 0;
        x_cnt  = 0;
        //  Compare exactly the words the DUT produced (tb_o_cnt), NOT
        //  OT_NUM_FORCMP. OT_NUM_FORCMP = TB_RUN_ROW * TB_RUN_OTCOL = 16384 for
        //  FFN1, but the gold file holds 2048 words, so indices past 2047 are X
        //  in BOTH arrays - and `!==` treats X vs X as equal, which silently
        //  turns 14336 uncompared slots into "matches" and inflates the verdict.
        //
        //  With `N_PASS > 1 the output words of every pass are appended, so the
        //  gold index wraps: pass p word n lands at ofm_array[p*TB_GOLD_WORDS+n]
        //  and must match ofm_gold_temp[n]. Every pass matching gold is the same
        //  statement as every pass matching every other pass.
        for (icp = 0; icp<tb_o_cnt ; icp= icp+1 ) begin
            if( ofm_array[icp] === 64'bx ) x_cnt = x_cnt + 1 ;
            if( ofm_array[icp] !== ofm_gold_temp[icp % TB_GOLD_WORDS] ) begin
                err_ofmap = err_ofmap +1 ;
                if(ofm_array[icp] !== 64'bx)
                    $display("** error   : pass %0d word %0d (idx %0d) => %16x , gold => %16x        **",
                             icp/TB_GOLD_WORDS, icp%TB_GOLD_WORDS, icp,
                             ofm_array[icp], ofm_gold_temp[icp % TB_GOLD_WORDS] );
            end
            // per-word "correct" lines suppressed: 2048 of them bury the verdict.
        end

        //----    per-pass breakdown    -----
        if( `N_PASS > 1 ) begin
            $display("====================================================================");
            for( pass_id = 0 ; pass_id < `N_PASS ; pass_id = pass_id + 1 ) begin
                jcp = 0 ;
                for( icp = pass_id*TB_GOLD_WORDS ;
                     icp < (pass_id+1)*TB_GOLD_WORDS && icp < tb_o_cnt ;
                     icp = icp + 1 )
                    if( ofm_array[icp] !== ofm_gold_temp[icp % TB_GOLD_WORDS] ) jcp = jcp + 1 ;
                $display(">>> PASS %0d : %0d / %0d words matched gold", pass_id,
                         TB_GOLD_WORDS - jcp, TB_GOLD_WORDS );
            end
        end

        //----    verdict    -----
        $display("====================================================================");
        $display(">>> DUT produced %0d output words over %0d pass(es); expected %0d",
                 tb_o_cnt, `N_PASS, `N_PASS * TB_GOLD_WORDS );
        $display(">>> undriven (all-X) output words : %0d", x_cnt);
        if( tb_o_cnt == 0 )
            $display(">>> RESULT: FAIL  (DUT produced no output at all)");
        else if( tb_o_cnt != `N_PASS * TB_GOLD_WORDS )
            $display(">>> RESULT: FAIL  (produced %0d words, expected %0d - a pass did not complete)",
                     tb_o_cnt, `N_PASS * TB_GOLD_WORDS );
        else if( x_cnt != 0 )
            $display(">>> RESULT: FAIL  (%0d mismatches, and %0d words were never driven)", err_ofmap, x_cnt);
        else if( err_ofmap != 0 )
            $display(">>> RESULT: FAIL  (%0d/%0d mismatched)", err_ofmap, tb_o_cnt);
        else
            $display(">>> RESULT: PASS  (%0d/%0d bit-exact)", tb_o_cnt, tb_o_cnt);
        $display(">>> CYCLES: %0d", cycle);
        $display("====================================================================");

        // //----display the compare result on terminal ----
        // $display("********************************************************************");
        // $display("**  ---- the compare result -----                                 **");
        // $display("**  row_in=%3d ,ch_in= %3d ,col_out= %3d ,ch_out= %3d             **", TB_RUN_OTROW,TB_PAT_IFCH,TB_RUN_COL,TB_RUN_OTCH );
        // $display("**  number of output data = %3d . compare with %3d gold pattern   **", tb_o_cnt , OT_NUM_FORCMP);
        // $display("**  ofmap errors = %3d                                            **", err_ofmap );
        // $display("**    ------------------------------                              **");
        // $display("**  please check the error number ,Simulation STOP at cycle %d **",cycle);
        // $display("**  If needed, You can increase End_CYCLE value in tb.sv          **");
        // $display("********************************************************************");
        
        #( `CYCLE*500 ) ;

        $finish;

    end
`endif  // !SOFTMAX
//--------------------------------------------------------------------------

// =============================================================================



endmodule

