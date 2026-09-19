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
`define FSDB_DUMP                     // for fsdb dump show waveform  
//`define EZ_S2MM_TREADY_SET
`define CYC_LIMIT
// (VIVA / RTL / GATE are chosen in the "simulation mode" block below)
`define End_CYCLE 500000              // Modify cycle times once your design need more cycle times!
`define NI_DELAY  2		                // NONIDEAL delay latency
`define AFPOS_DELAY  0.5		        // after posedge NONIDEAL delay latency



//-- simulation mode --
//  VIVA : Vivado project flow (xsim launched deep inside vivado/build). Local
//         default: assumed whenever neither of the other two is given.
//  RTL  : VCS pre-sim on the school box      -> +define+RTL   (run from repo root)
//  GATE : VCS gate-level sim, DC netlist+SDF -> +define+GATE  (run from repo root)
//  One copy of the settings below. The three modes used to each carry their
//  own and had drifted apart: RTL pointed at Wv/V (the V projection) while
//  the verified run is Wq/Q, GATE had the bias file commented out, CYCLE was
//  5 in two of them, and the SDF name was the standalone block's.
`ifndef RTL
`ifndef GATE
`define VIVA
`endif
`endif

//-- timescale / clock --
//  CYCLE is 10 in EVERY mode: the tb's sub-cycle delays were validated at 10,
//  and for GATE it must be >= the SDC clock period (adfp/syn/CHIP.sdc).
`ifdef GATE
    `timescale 1ns/1ps
    `define CYCLE 10
    `define SDFFILE "adfp/syn/DC_Results/Transformer_top_syn.sdf"
`else
    `timescale 1ns/100ps
    `define CYCLE 10
`endif

//-- pattern path --
//  Vivado runs xsim from <build>/Transformer_IP.sim/sim_1/behav/xsim, so that
//  flow needs an absolute path (change it here if the repo moves). VCS and
//  the command-line xvlog flows are run from the repo root.
`ifdef VIVA
    `define PAT_DIR "D:/Transformer_code/Transformer_IP_Integrate/pat/"
`else
    `define PAT_DIR "pat/"
`endif
    //----input pattern ----   (the verified set: Q projection, 4096/4096)
    `define IF_WPAT     {`PAT_DIR, "input_token.dat"}
    `define KER_WPAT    {`PAT_DIR, "Wq.dat"}
    `define BIAS_WPAT   {`PAT_DIR, "fake_bias.dat"}
    //----gold pattern ----
    `define OF_GOLD     {`PAT_DIR, "Q.dat"}

`define ENDIAN_SWAP(x) {x[7:0], x[15:8], x[23:16], x[31:24], x[39:32], x[47:40], x[55:48], x[63:56]}
// =============================================================================
// ================				module start				====================
// =============================================================================

module fsm_check_tb();
localparam ANN_TST = 64'h281c020048160000;
// =============================================================================
// =============	PATTERN parameter	========================
// =============================================================================
        localparam TB_PAT_IFCH	=   512	;	// input feature map channel
        localparam TB_PAT_OFCH	=	512	;
        localparam TB_PAT_COL	=	1	;
        localparam TB_PAT_ROW	=	64	;
// =============================================================================
// =============	testbench configurable parameter	========================
// =============================================================================
localparam TB_RUN_OTCH	=	512    ;
localparam TB_RUN_OTROW =   64    ;    //Incrementing in multiples of 16?
localparam TB_RUN_COL   =   1    ;	//Incrementing in multiples of 8
// ??��??????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
// ??��????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
// ???  The following parameters need to be manually modified.       ???
// ???  Please adjust them according to different input channels.    ???
// ??��????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
// for in_ch = 8
// localparam MMOD_cfg_stg0_nor_finum 		=8'd2	;	//8bits // 3x3 pad=1 needed normal final number = 3*atl_ch_in -1 = 3-1 (for counter, don't use subtract)
// localparam MMOD_cfg_stg0_pdb0_finum 	=8'd1	;	//8bits // 3x3 pad=1 needed, pdb0_finum	= (3-1)*atl_ch_in -1 = 2*4-1 = 7 , 5x5 pd=2 pdb0_finum =(5-2)*atl_ch_in -1,(for counter, don'd use subtract)
// localparam MMOD_cfg_stg0_pdb1_finum 	=8'd1	;	//8bits // 5x5 pad=2 needed (for counter, don'd use subtract)
// localparam MMOD_cfgin_top_starter	= { 8'd3 ,8'd0 ,8'd0 ,8'd0 ,8'd0 } ;
// localparam MMOD_cfgin_toppad_length	= { 8'd6 ,8'd0 ,8'd0 ,8'd0 ,8'd0 } ;
// localparam MMOD_cfgin_botpad_length	= { 8'd6 ,8'd0 ,8'd0 ,8'd0 ,8'd0 } ;
// localparam MMOD_cfgin_cnt_step_p1	= 8'd0;
// for in_ch = 16
// localparam MMOD_cfg_stg0_nor_finum 		=8'd5	;	//8bits // 3x3 pad=1 needed normal final number = 3*atl_ch_in -1 = 6-1 (for counter, don't use subtract)
// localparam MMOD_cfg_stg0_pdb0_finum 	=8'd3	;	//8bits // 3x3 pad=1 needed, pdb0_finum	= (3-1)*atl_ch_in -1 = 2*4-1 = 7 , 5x5 pd=2 pdb0_finum =(5-2)*atl_ch_in -1,(for counter, don'd use subtract)
// localparam MMOD_cfg_stg0_pdb1_finum 	=8'd3	;	//8bits // 5x5 pad=2 needed (for counter, don'd use subtract)
// localparam MMOD_cfgin_top_starter	= { 8'd6 ,8'd0 ,8'd0 ,8'd0 ,8'd0 } ;
// localparam MMOD_cfgin_toppad_length	= { 8'd12 ,8'd0 ,8'd0 ,8'd0 ,8'd0 } ;
// localparam MMOD_cfgin_botpad_length	= { 8'd12 ,8'd0 ,8'd0 ,8'd0 ,8'd0 } ;
// localparam MMOD_cfgin_cnt_step_p1	= 8'd1;
// for in_ch = 24
// localparam MMOD_cfg_stg0_nor_finum 		=8'd8	;	//8bits // 3x3 pad=1 needed normal final number = 3*atl_ch_in -1 = 9-1 (for counter, don't use subtract)
// localparam MMOD_cfg_stg0_pdb0_finum 	=8'd5	;	//8bits // 3x3 pad=1 needed, pdb0_finum	= (3-1)*atl_ch_in -1 = 2*4-1 = 7 , 5x5 pd=2 pdb0_finum =(5-2)*atl_ch_in -1,(for counter, don'd use subtract)
// localparam MMOD_cfg_stg0_pdb1_finum 	=8'd5	;	//8bits // 5x5 pad=2 needed (for counter, don'd use subtract)
// localparam MMOD_cfgin_top_starter	= { 8'd9 ,8'd0 ,8'd0 ,8'd0 ,8'd0 } ;
// localparam MMOD_cfgin_toppad_length	= { 8'd18 ,8'd0 ,8'd0 ,8'd0 ,8'd0 } ;
// localparam MMOD_cfgin_botpad_length	= { 8'd18 ,8'd0 ,8'd0 ,8'd0 ,8'd0 } ;
// localparam MMOD_cfgin_cnt_step_p1	= 8'd2;
// for in_ch = 32
localparam MMOD_cfg_stg0_nor_finum 		=8'd63	;	//8bits // 3x3 pad=1 needed normal final number = 3*atl_ch_in -1 = 11 (for counter, don't use subtract)
localparam MMOD_cfg_stg0_pdb0_finum 	=8'd63	;	//8bits // 3x3 pad=1 needed, pdb0_finum	= (3-1)*atl_ch_in -1 = 2*4-1 = 7 , 5x5 pd=2 pdb0_finum =(5-2)*atl_ch_in -1,(for counter, don'd use subtract)
localparam MMOD_cfg_stg0_pdb1_finum 	=8'd63	;	//8bits // 5x5 pad=2 needed (for counter, don'd use subtract)
localparam MMOD_cfgin_top_starter	= { 8'd0 ,8'd0 ,8'd0 ,8'd0 ,8'd0 } ;
localparam MMOD_cfgin_toppad_length	= { 8'd64 ,8'd0 ,8'd0 ,8'd0 ,8'd0 } ;
localparam MMOD_cfgin_botpad_length	= { 8'd64 ,8'd0 ,8'd0 ,8'd0 ,8'd0 } ;
localparam MMOD_cfgin_cnt_step_p1	= 8'd3;
// for in_ch = 48
// localparam MMOD_cfg_stg0_nor_finum 		=8'd17	;	//8bits // 3x3 pad=1 needed normal final number = 3*atl_ch_in -1 = 17 (for counter, don't use subtract)
// localparam MMOD_cfg_stg0_pdb0_finum 	=8'd11	;	//8bits // 3x3 pad=1 needed, pdb0_finum	= (3-1)*atl_ch_in -1 = 2*6-1 = 11 , 5x5 pd=2 pdb0_finum =(5-2)*atl_ch_in -1,(for counter, don'd use subtract)
// localparam MMOD_cfg_stg0_pdb1_finum 	=8'd11	;	//8bits // 5x5 pad=2 needed (for counter, don'd use subtract)
// localparam MMOD_cfgin_top_starter	= { 8'd18 ,8'd0 ,8'd0 ,8'd0 ,8'd0 } ;
// localparam MMOD_cfgin_toppad_length	= { 8'd36 ,8'd0 ,8'd0 ,8'd0 ,8'd0 } ;
// localparam MMOD_cfgin_botpad_length	= { 8'd36 ,8'd0 ,8'd0 ,8'd0 ,8'd0 } ;
// localparam MMOD_cfgin_cnt_step_p1	= 8'd5;
// for in_ch = 64
// localparam MMOD_cfg_stg0_nor_finum 	=8'd23	;	//8bits // 3x3 pad=1 needed normal final number = 3*atl_ch_in -1 = 3-1 (for counter, don't use subtract)
// localparam MMOD_cfg_stg0_pdb0_finum 	=8'd15	;	//8bits // 3x3 pad=1 needed, pdb0_finum	= (3-1)*atl_ch_in -1 = 2*4-1 = 7 , 5x5 pd=2 pdb0_finum =(5-2)*atl_ch_in -1,(for counter, don'd use subtract)
// localparam MMOD_cfg_stg0_pdb1_finum 	=8'd15	;	//8bits // 5x5 pad=2 needed (for counter, don'd use subtract)
// localparam MMOD_cfgin_top_starter	= { 8'd24 ,8'd0 ,8'd0 ,8'd0 ,8'd0 } ;
// localparam MMOD_cfgin_toppad_length	= { 8'd48 ,8'd0 ,8'd0 ,8'd0 ,8'd0 } ;
// localparam MMOD_cfgin_botpad_length	= { 8'd48 ,8'd0 ,8'd0 ,8'd0 ,8'd0 } ;
// localparam MMOD_cfgin_cnt_step_p1	= 8'd7;
// ??��????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
// ???  The following parameters need to be manually modified.       ???
// ???  Please adjust them according to layer quantize parameter     ???
// ??��????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
// for in_ch = 8 layer 0 conv   
// localparam MMOD_cfgin_quantize_m0_scale         = 32'h6F4782CA ;
// localparam MMOD_cfgin_quantize_index	        = 8'd8  ;
// localparam MMOD_cfgin_quantize_z_of_weightht    = 16'd106 ;
// for in_ch = 8 layer 1 conv   
// localparam MMOD_cfgin_quantize_m0_scale         = 32'h5FD74610 ;
// localparam MMOD_cfgin_quantize_index	        = 8'd8  ;
// localparam MMOD_cfgin_quantize_z_of_weightht    = 16'd106 ;
// for in_ch = 8 layer 17 conv   
// localparam MMOD_cfgin_quantize_m0_scale         = 32'h46E23410 ;
// localparam MMOD_cfgin_quantize_index	        = 8'd5  ;
// localparam MMOD_cfgin_quantize_z_of_weightht    = 16'd188 ;
// for in_ch = 8 layer 2 conv   
// localparam MMOD_cfgin_quantize_m0_scale         = 32'h601FADE9 ;
// localparam MMOD_cfgin_quantize_index	        = 8'd8  ;
// localparam MMOD_cfgin_quantize_z_of_weightht    = 16'd102 ;
// for in_ch = 8 layer 8 conv   
// localparam MMOD_cfgin_quantize_m0_scale         = 32'h5F10D11A ;
// localparam MMOD_cfgin_quantize_index	        = 8'd8  ;
// localparam MMOD_cfgin_quantize_z_of_weightht    = 16'd102 ;
// for in_ch = 16 layer 4 conv   
// localparam MMOD_cfgin_quantize_m0_scale         = 32'h430C468C ;
// localparam MMOD_cfgin_quantize_index	        = 8'd8  ;
// localparam MMOD_cfgin_quantize_z_of_weightht    = 16'd107 ;
// for in_ch = 16 layer 10 conv   
// localparam MMOD_cfgin_quantize_m0_scale         = 32'h44EAE350 ;
// localparam MMOD_cfgin_quantize_index	        = 8'd8  ;
// localparam MMOD_cfgin_quantize_z_of_weightht    = 16'd107 ;
// for in_ch = 24 layer 6 conv   
// localparam MMOD_cfgin_quantize_m0_scale         = 32'h64B38726 ;
// localparam MMOD_cfgin_quantize_index	        = 8'd9  ;
// localparam MMOD_cfgin_quantize_z_of_weightht    = 16'd121 ;
// for in_ch = 24 layer 12 conv   
// localparam MMOD_cfgin_quantize_m0_scale         = 32'h608ABC53 ;
// localparam MMOD_cfgin_quantize_index	        = 8'd9  ;
// localparam MMOD_cfgin_quantize_z_of_weightht    = 16'd121 ;
// for in_ch = 32 layer 15 conv   
// localparam MMOD_cfgin_quantize_m0_scale         = 32'h7D884464 ;
// localparam MMOD_cfgin_quantize_index	        = 8'd8  ;
// localparam MMOD_cfgin_quantize_z_of_weightht    = 16'd127 ;
// for in_ch = 16 layer 16 conv   
// localparam MMOD_cfgin_quantize_m0_scale         = 32'h49C5AD0C ;
// localparam MMOD_cfgin_quantize_index	        = 8'd8  ;
// localparam MMOD_cfgin_quantize_z_of_weightht    = 16'd152 ;
// for Q_Generation   
 localparam MMOD_cfgin_quantize_m0_scale         = 32'h7D884464 ;
 localparam MMOD_cfgin_quantize_index	        = 8'd8  ;
 localparam MMOD_cfgin_quantize_z_of_weightht    = 16'd127 ;
// for Q_Generation   
// localparam MMOD_cfgin_quantize_m0_scale         = 32'h7D884464 ;
// localparam MMOD_cfgin_quantize_index	        = 8'd8  ;
// localparam MMOD_cfgin_quantize_z_of_weightht    = 16'd127 ;
// for V_Generation   
//localparam MMOD_cfgin_quantize_m0_scale         = 32'h01101211 ;
//localparam MMOD_cfgin_quantize_index	        = 8'd6  ;
//localparam MMOD_cfgin_quantize_z_of_weightht    = 16'd29 ;
// ??��????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
localparam TB_RUN_BIAS_LENGTH = TB_RUN_OTCH ;
localparam TB_KER_NUMBER = TB_RUN_OTCH;

localparam ARCH_IFBUF_NUM = 8 ;
localparam OT_NUM_FORCMP = TB_RUN_COL*TB_RUN_OTCH/8 * TB_RUN_OTROW	;	
localparam OF_ARRAY_SIZE =  TB_PAT_ROW*TB_PAT_COL*TB_PAT_OFCH/8	;// 480row*640col*32ch/8


localparam ATL_TB_RUN_OTCH = TB_RUN_OTCH/8 ;
localparam ATL_TB_PAT_OFCH = TB_PAT_OFCH/8 ;

logic [64-1:0]	ediag = 0;// endian assignment
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------


//----	parameter controller (don't move )-------------------
    parameter TBITS = 64	;
    parameter TBYTE = 8		;

localparam ATL_CH = TB_PAT_IFCH/8  ; // actually channel address
localparam ATL_RUN_COL_P2 = TB_RUN_COL  ;	// left : TB_RUN_COL+1  , normal:  TB_RUN_COL+2 , right :  TB_RUN_COL+1
localparam ATL_1_ROWIFWPAT_LENGTH = (ATL_RUN_COL_P2)*ATL_CH -1   ; // actually ifmap pattern length , +2 is for 3x3 compute
localparam ATL_ONERND_OTLENGTH = 63; //20250715 TB_RUN_BIAS_LENGTH*TB_RUN_COL/8-1;
localparam ATL_KER_NUMBER_SUB1 = TB_KER_NUMBER/8 - 1;
localparam ATL_BIAS_NUMBER_SUB1 = TB_RUN_BIAS_LENGTH-1;  //20250715 TB_RUN_BIAS_LENGTH-1; //20251123 0;
localparam TB_RUN_KERSRAM_LENGTH = TB_KER_NUMBER/8*ATL_CH ;	// how many 64bits data in each KER_buffer
localparam TB_RUN_KERSRAM_LENGTH_1 = TB_KER_NUMBER*ATL_CH ;	// new
localparam ATL_KERSRAM_LENGTH = TB_RUN_KERSRAM_LENGTH-1 ;

localparam KNR_NOR_LENGTH = ATL_CH; // 20250714  9*ATL_CH;
localparam PD_LST1 = TB_RUN_COL/ARCH_IFBUF_NUM  *  3*ATL_CH		;
localparam PD_LST2 = PD_LST1* 2		;
localparam PD_LST3 = PD_LST1* 3		;

localparam IFR_WINDOWS = (TB_RUN_COL<8) ? 1 : TB_RUN_COL / ARCH_IFBUF_NUM ;  //20250710 LYC for 1 blkpe64
localparam IFR_WINDOWS_SUB1 = IFR_WINDOWS-1 ;

localparam OTFR_COLFIN_SUB1 = TB_RUN_COL-1 ;
localparam OTFR_CHFIN_SUB1 = 63; // 20250715 TB_RUN_BIAS_LENGTH/8 -1 ; //20250810 1row output
localparam OTFR_COL_JMP = TB_RUN_COL ;
//------------------------------------------------------------------------------
localparam IFWPAT_LENGTH = TB_RUN_OTROW*(ATL_RUN_COL_P2)*ATL_CH    ; // actually ifmap pattern length , +2 is for 3x3 compute

// =============================================================================
// ================				instruction				====================
// =============================================================================
// -----------------for fsm & sche config----------------------
localparam cfg_base_number  =   8'd2;
localparam cfg_total_row    =   TB_RUN_OTROW[8-:9];
// -----------------------------------------------------------------------
// -----------------for if_pd config----------------------
localparam cfg_atlchin 		=   ATL_CH[7-:8]	;	//8bits		ch64->8 ch32->4 ... = ch_in/8
localparam cfg_conv_switch 	=   8'd1	;	//8bits		3x3 = 3'd2 , 5x5 = 3'd3  //20250712
localparam cfg_mast_state 	=   8'd1	;	//8bits		NORMAL 	= 2'd1 , LEFT 	= 2'd2 , RIGH 	= 2'd3
localparam cfg_pd_list_0 	=   16'd0	;	//16bits	every row in sram 1st or 2nd col need to padding
localparam cfg_pd_list_1 	=	16'd0	;   //PD_LST1[(16-1)-: 16 ]	;	//16bits	so pd list give address for every row start address
localparam cfg_pd_list_2 	=	16'd0	;   //PD_LST2[(16-1)-: 16 ]	;	//16bits	
localparam cfg_pd_list_3 	=   16'd0	;   //PD_LST3[(16-1)-: 16 ]	;	//16bits	
localparam cfg_pd_list_4 	=   16'd0	;	//16bits	
localparam cfg_cnt_step_p1 	=   MMOD_cfgin_cnt_step_p1	;	//8bits		atl_ch_in -1 = 3 -- for 3x3 padding 1	, atl_ch_in*2 -1 = 7 -- for 5x5 padding 2
localparam cfg_cnt_step_p2 	=   8'd0	;	//8bits		set 0 for 3x3 padding 1 				, atl_ch_in*1 -1 = 3 -- for 5x5 padding 1
// -----------------------------------------------------------------------
// -----------------for if_w config----------------------
localparam cfg_pdlf				=8'd0	;	//8bits // no used
localparam cfg_pdrg				=8'd0	;	//8bits // no used
localparam cfg_nor				=8'd0	;	//8bits // no used
localparam cfg_stg0_nor_finum 	=MMOD_cfg_stg0_nor_finum 	;	//8bits // 3x3 pad=1 needed normal final number = 3*atl_ch_in -1 = 11 (for counter, don't use subtract)
localparam cfg_stg0_pdb0_finum 	= MMOD_cfg_stg0_pdb0_finum 	;	//8bits // 3x3 pad=1 needed, pdb0_finum	= (3-1)*atl_ch_in -1 = 2*4-1 = 7 , 5x5 pd=2 pdb0_finum =(5-2)*atl_ch_in -1,(for counter, don'd use subtract)
localparam cfg_stg0_pdb1_finum 	= MMOD_cfg_stg0_pdb1_finum 	;	//8bits // 5x5 pad=2 needed (for counter, don'd use subtract)
localparam cfg_stg1_eb_col 		=IFR_WINDOWS_SUB1[ 7-:8];	//8bits // how many col for each buffer, every buffer column = run_col -1 (for counter, don'd use subtract)
localparam cfg_dincnt_finum 	=ATL_1_ROWIFWPAT_LENGTH[(16-1) -:16]	;	//16bits // for if data counter final number, 18col*32ch/8*3
localparam cfg_rowcnt_finum 	=8'd0	;	//8bits // for if data row counter final number 3x3 = 2 , 5x5=4
// -----------------------------------------------------------------------
// -----------------for if_r & if_t config----------------------
localparam cfg_ifr_window		= IFR_WINDOWS[ 7-:8]	;//8bits	// col_out= 16 , 16/8PE_row = 2 windows
localparam cfg_ifr_repeat_ker	= 8'd2	;	//don't care
localparam cfg_ift_total_window = cfg_ifr_window*cfg_ifr_repeat_ker	;//don't care
// -----------------------------------------------------------------------
// -----------------for kernel_r config----------------------
localparam cfg_kernum_sub1		= ATL_KER_NUMBER_SUB1[ 7 -: 8 ] ; 
localparam cfg_colout_sub1		= IFR_WINDOWS_SUB1   [ 15-:16 ] ;
localparam cfg_normal_length	= KNR_NOR_LENGTH[ (16-1) -:16 ] ;
localparam cfgin_top_starter 	= MMOD_cfgin_top_starter	;
localparam cfgin_toppad_length	= MMOD_cfgin_toppad_length	;
localparam cfgin_botpad_length	= MMOD_cfgin_botpad_length	;
// -----------------------------------------------------------------------
// -----------------for kernel_w config----------------------
localparam cfg_kerw_buflength	= ATL_KERSRAM_LENGTH[15 -: 16];
// -----------------for bias_r_w config----------------------
localparam cfg_bir_rg_prep		= 16'd8 ;	//The number of bias registers to be prepared is determined by the quantity of kernel SRAMs.
localparam cfg_biw_lengthsub1	= ATL_BIAS_NUMBER_SUB1[ 15 -: 16 ] ;
// -----------------for output config  ----------------------------------
localparam cfg_ot_rnd_finsub1	= ATL_ONERND_OTLENGTH[11 -: 12 ]	;	//13bits   output channel=16 output_col=640, 16*640/8-1=1279 //HYR YWJ
localparam cfg_ot_tgpfnsub1		= 12'd0		;                           //13bits    
localparam cfg_ot_tcolfnsub1	= OTFR_COLFIN_SUB1	[ 11-:12]	;       //13bits    640-1   //HYR YWJ
localparam cfg_ot_tchafnsub1	= OTFR_CHFIN_SUB1	[ 11-:12]	;	    //13bits    output channel=16 , 16/8-1=1    //HYR YWJ
localparam cfg_ot_sft_gp		= 12'd0	;                               //13bits    
localparam cfg_ot_sft_colpra	= OTFR_COL_JMP	[11-:12]		;	    //13bits    jump out of all output col   640       //HYR YWJ
// -----------------for quantization config----------------------
localparam cfg_m0_scale         = MMOD_cfgin_quantize_m0_scale          ;
localparam cfg_index            = MMOD_cfgin_quantize_index	            ;
localparam cfg_z_of_weight      = MMOD_cfgin_quantize_z_of_weightht     ;
localparam cfg_z3               = 8'd0  ;
// -----------------------------------------------------------------------

localparam SA_HEAD          = 64'h0011223344556677 ;
localparam SOFTMAX_HEAD     = 64'h8899aabbccddeeff ;
localparam NORM_HEAD        = 64'h7766554433221100 ;
localparam FFN_HEAD         = 64'hffeeddccbbaa9988 ;

localparam INST_HEAD = 64'hefef123abbeeff22 ;
localparam DATA_HEAD = 64'hefef6543dadaff11 ;
localparam CFG_0 = 64'hffff000000000000 ;	//start signal
localparam CFG_1 = { cfg_m0_scale , cfg_index , cfg_z_of_weight , cfg_z3 };
localparam CFG_2 = { cfg_total_row , 7'd0 , cfg_base_number	,40'd0	 };
localparam CFG_3 = { cfg_atlchin 		,cfg_conv_switch	,cfg_mast_state	,cfg_pd_list_0		,cfg_pd_list_1			,8'd0	 }; //8
localparam CFG_4 = { cfg_pd_list_2		,cfg_pd_list_3		,cfg_pd_list_4	,cfg_cnt_step_p1	,cfg_cnt_step_p2	};
localparam CFG_5 = { cfg_pdlf			,cfg_pdrg			,cfg_nor		,cfg_stg0_nor_finum	,cfg_stg0_pdb0_finum	,cfg_stg0_pdb1_finum	,cfg_stg1_eb_col , 8'd0 };
localparam CFG_6 = { cfg_dincnt_finum	,cfg_rowcnt_finum	, 40'd0 };
localparam CFG_7 = { cfg_ifr_window	, cfg_ift_total_window	, 48'd0 };
localparam CFG_8	= { cfg_kernum_sub1 , cfg_colout_sub1 , cfg_normal_length ,24'd0};
localparam CFG_9	= { cfgin_top_starter 	, 24'd0}	;
localparam CFG_10	= { cfgin_toppad_length , 24'd0}	;
localparam CFG_11	= { cfgin_botpad_length , 24'd0}	;
localparam CFG_12	= { cfg_kerw_buflength	, 48'd0}	;
localparam CFG_13	= { cfg_bir_rg_prep		, cfg_biw_lengthsub1 , 32'd0  }	;
localparam CFG_14	= {cfg_ot_rnd_finsub1 , cfg_ot_tgpfnsub1 , cfg_ot_tcolfnsub1 ,28'd0}	;   //HYR 12/12/12 28
localparam CFG_15	= {cfg_ot_tchafnsub1  , cfg_ot_sft_gp	 , cfg_ot_sft_colpra ,28'd0}	;   //YWJ 13/13/13 25 //HYR 12/12/12 28



localparam TS_INST_HEAD = `ENDIAN_SWAP( INST_HEAD );
localparam TS_DATA_HEAD = `ENDIAN_SWAP( DATA_HEAD );
localparam TS_CFG_0 	= `ENDIAN_SWAP( CFG_0 	 );
localparam TS_CFG_1 	= `ENDIAN_SWAP( CFG_1 	 );
localparam TS_CFG_2 	= `ENDIAN_SWAP( CFG_2 	 );
localparam TS_CFG_3 	= `ENDIAN_SWAP( CFG_3 	 );
localparam TS_CFG_4 	= `ENDIAN_SWAP( CFG_4 	 );
localparam TS_CFG_5 	= `ENDIAN_SWAP( CFG_5 	 );
localparam TS_CFG_6 	= `ENDIAN_SWAP( CFG_6 	 );
localparam TS_CFG_7 	= `ENDIAN_SWAP( CFG_7 	 );
localparam TS_CFG_8		= `ENDIAN_SWAP( CFG_8	 );
localparam TS_CFG_9		= `ENDIAN_SWAP( CFG_9	 );
localparam TS_CFG_10	= `ENDIAN_SWAP( CFG_10	 );
localparam TS_CFG_11	= `ENDIAN_SWAP( CFG_11	 );
localparam TS_CFG_12	= `ENDIAN_SWAP( CFG_12	 );
localparam TS_CFG_13	= `ENDIAN_SWAP( CFG_13	 );
localparam TS_CFG_14	= `ENDIAN_SWAP( CFG_14	 );
localparam TS_CFG_15	= `ENDIAN_SWAP( CFG_15	 );


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
    reg [64-1:0] ifw_array 		[0: TB_PAT_COL*TB_PAT_ROW*TB_PAT_IFCH/4-1 ];
    reg [64-1:0] ifmap_w_data 		[0: IFWPAT_LENGTH-1 ];


    // reg [64-1:0] kerw_array		    [0:511];           //DMA_KER_TEST
    reg [64-1:0] kerw_array		    [0:TB_RUN_KERSRAM_LENGTH_1];              //DMA_KER_TEST // 3*3*ker_num*ker_ch/8
    reg [64-1:0] kerw_array_0		[0:511];
    reg [64-1:0] kerw_array_1		[0:511];
    reg [64-1:0] kerw_array_2		[0:511];
    reg [64-1:0] kerw_array_3		[0:511];
    reg [64-1:0] kerw_array_4		[0:511];
    reg [64-1:0] kerw_array_5		[0:511];
    reg [64-1:0] kerw_array_6		[0:511];
    reg [64-1:0] kerw_array_7		[0:511];
    
    // reg [64-1:0] kerw_array_temp		[0:511];     //DMA_KER_TEST
    reg [64-1:0] kerw_array_temp		[0:TB_RUN_KERSRAM_LENGTH_1];     //DMA_KER_TEST
    reg [64-1:0] kerw_array_0_temp		[0:511];
    reg [64-1:0] kerw_array_1_temp		[0:511];
    reg [64-1:0] kerw_array_2_temp		[0:511];
    reg [64-1:0] kerw_array_3_temp		[0:511];
    reg [64-1:0] kerw_array_4_temp		[0:511];
    reg [64-1:0] kerw_array_5_temp		[0:511];
    reg [64-1:0] kerw_array_6_temp		[0:511];
    reg [64-1:0] kerw_array_7_temp		[0:511];

    reg [64-1:0] biasw_array	[0:512];
    reg [32-1:0] biasw_array_temp	[0:512];
    reg [64-1:0] ifmap_w_data_temp 		[0: IFWPAT_LENGTH-1 ];
    //---------- goldmap mem pattern declare-----------------

    reg [32-1:0] tb_o_cnt ;
    reg [32-1:0] err_ofmap;
    reg [32-1:0] x_cnt;		// output words the DUT never drove (guards a false PASS)
    reg [64-1:0] ofm_array [0 : OF_ARRAY_SIZE-1] ;
    reg [64-1:0] ofm_gold [ 0: OF_ARRAY_SIZE-1 ];
    reg [64-1:0] ofm_gold_temp [ 0: OF_ARRAY_SIZE-1 ];
    reg [64-1:0] origin_pat_ofmap [ 0: OF_ARRAY_SIZE-1 ];


    //---------- design under test (DUT) output declare-----------------
    reg dutot_done =0;		// DUT output done we can compare data with gold pattern
    // DUT output error for compare block 

    //--------------------------------------------

    


// =============================================================================
//----- DUT AXI I/O ----
    logic S_AXIS_MM2S_TVALID	;
    logic S_AXIS_MM2S_TREADY	;
    logic [TBITS-1:0]S_AXIS_MM2S_TDATA	;
    logic [TBYTE-1:0]S_AXIS_MM2S_TKEEP	;
    logic S_AXIS_MM2S_TLAST	;

    logic            M_AXIS_S2MM_TVALID	;
    logic            M_AXIS_S2MM_TREADY	;
    logic[TBITS-1:0] M_AXIS_S2MM_TDATA	;
    logic[TBYTE-1:0] M_AXIS_S2MM_TKEEP	;
    logic[1-1:0]     M_AXIS_S2MM_TLAST	;	// EOL   

//----- test flow flag ----
logic tst_fl_sent_ifmap 	= 0 ;
logic tst_fl_sent_kernel 	= 0 ;
logic tst_fl_sent_bias 		= 0 ;

integer ix0 , ix1 , ix2 ;	// deal with ifmap length
integer  iix , i1 , i0 ;	// deal with sending data

integer icp;
integer i;
// =============================================================================
// ================		python generate declare			========================
// =============================================================================
//----gen by pre_pe.py ----declare tb top PE connection wire start------ 
// wire p_valid_0 ,p_valid_1 ,p_valid_2 ,p_valid_3 ,p_valid_4 ,p_valid_5 ,p_valid_6 ,p_valid_7 ; 
// wire p_final_0 ,p_final_1 ,p_final_2 ,p_final_3 ,p_final_4 ,p_final_5 ,p_final_6 ,p_final_7 ; 
// wire [64-1:0] p_if_0 ,p_if_1 ,p_if_2 ,p_if_3 ,p_if_4 ,p_if_5 ,p_if_6 ,p_if_7 ; 
// wire [64-1:0] p_ke_0 ,p_ke_1 ,p_ke_2 ,p_ke_3 ,p_ke_4 ,p_ke_5 ,p_ke_6 ,p_ke_7 ; 
// wire [32-1:0] p_bi_0 ,p_bi_1 ,p_bi_2 ,p_bi_3 ,p_bi_4 ,p_bi_5 ,p_bi_6 ,p_bi_7 ; 
//----declare tb top PE connection wire end------ 


// ============================================================================
// ================			instance DUT		===============================
// ============================================================================

    
    
    Transformer_top	#(
            .TBITS(TBITS)
        ,	.TBYTE(TBYTE)
    )
    tp001(	.clk	(	clk		)
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

    
        // //----tb top instance start------ 
        // ,	.valid_to_pe_0 ( p_valid_0 ),	.final_to_pe_0 ( p_final_0 ),	.dout_if_0 ( p_if_0 ),	.dout_ke_0 ( p_ke_0 ),	.dout_bi_0 ( p_bi_0 )//-- PE block -0-
        // ,	.valid_to_pe_1 ( p_valid_1 ),	.final_to_pe_1 ( p_final_1 ),	.dout_if_1 ( p_if_1 ),	.dout_ke_1 ( p_ke_1 ),	.dout_bi_1 ( p_bi_1 )//-- PE block -1-
        // ,	.valid_to_pe_2 ( p_valid_2 ),	.final_to_pe_2 ( p_final_2 ),	.dout_if_2 ( p_if_2 ),	.dout_ke_2 ( p_ke_2 ),	.dout_bi_2 ( p_bi_2 )//-- PE block -2-
        // ,	.valid_to_pe_3 ( p_valid_3 ),	.final_to_pe_3 ( p_final_3 ),	.dout_if_3 ( p_if_3 ),	.dout_ke_3 ( p_ke_3 ),	.dout_bi_3 ( p_bi_3 )//-- PE block -3-
        // ,	.valid_to_pe_4 ( p_valid_4 ),	.final_to_pe_4 ( p_final_4 ),	.dout_if_4 ( p_if_4 ),	.dout_ke_4 ( p_ke_4 ),	.dout_bi_4 ( p_bi_4 )//-- PE block -4-
        // ,	.valid_to_pe_5 ( p_valid_5 ),	.final_to_pe_5 ( p_final_5 ),	.dout_if_5 ( p_if_5 ),	.dout_ke_5 ( p_ke_5 ),	.dout_bi_5 ( p_bi_5 )//-- PE block -5-
        // ,	.valid_to_pe_6 ( p_valid_6 ),	.final_to_pe_6 ( p_final_6 ),	.dout_if_6 ( p_if_6 ),	.dout_ke_6 ( p_ke_6 ),	.dout_bi_6 ( p_bi_6 )//-- PE block -6-
        // ,	.valid_to_pe_7 ( p_valid_7 ),	.final_to_pe_7 ( p_final_7 ),	.dout_if_7 ( p_if_7 ),	.dout_ke_7 ( p_ke_7 ),	.dout_bi_7 ( p_bi_7 )//-- PE block -7-
        // //----tb top instance end------ 


);





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

// =============================================================
// =============================================================================
// ================		fsdb dump +mda+packedmda		========================
// ================		Kernel data load readmemh		========================
// =============================================================================
    `ifdef FSDB_DUMP
        initial begin
   	        `ifdef RTL
   	            // wait( tst_fl_sent_bias );
                $fsdbDumpfile("tb_sim000.fsdb",1000);
                $fsdbDumpvars(0,"+mda","+packedmda");		//++
                $fsdbDumpMDA();
            `elsif GATE
                $sdf_annotate(`SDFFILE,tp001);	//  $sdf_annotate("sdf_file"[,module_instance][,"sdf_configfile"][,"sdf_logfile"][,"mtm_spec"][,"scale_factors"][,"scale_type"]);
                $fsdbDumpfile("Transformer_SA_SYN.fsdb");	
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

        $readmemh(`IF_WPAT 		,	ifw_array 		        );

        $readmemh(`KER_WPAT	    ,	kerw_array_temp		    );      //DMA_KER_TEST

        $readmemh(`BIAS_WPAT	,	biasw_array_temp		);
        $readmemh(`OF_GOLD	    ,	origin_pat_ofmap		);

        for (ix0 = 0; ix0 < TB_RUN_OTROW ; ix0 = ix0 +1	) begin		// 3row index
            for ( ix1 = 0 ; ix1 < ATL_RUN_COL_P2*ATL_CH ; ix1 = ix1 +1 ) begin	//each row pattern length
                ifmap_w_data_temp [ ix0*ATL_RUN_COL_P2*ATL_CH   + ix1 ]= ifw_array[ ix0*TB_PAT_COL*ATL_CH   + ix1  ]	;
                // ifmap_w_data [ ix0*ATL_RUN_COL_P2*ATL_CH   + ix1 +1 ]= ifw_array[ ix0*208*ATL_CH   + ix1  ]	;
                
            end
            // $display("** ix0_index = %10d        **", ix0 );
            // $display("** ix1_index = %10d        **", ix1 );
            // $display("** ix0_index*ATL_RUN_COL_P2*ATL_CH = %10d        **", ix0*ATL_RUN_COL_P2*ATL_CH );
        end	

        for (ix0 = 0; ix0 < TB_RUN_OTROW ; ix0 = ix0 +1	) begin	
            for ( ix1 = 0 ; ix1 < TB_RUN_COL ; ix1 = ix1 +1 ) begin	
                for ( ix2 = 0 ; ix2 < ATL_TB_RUN_OTCH ; ix2 = ix2 +1 ) begin	
                ofm_gold_temp [ ix0*TB_RUN_COL*ATL_TB_RUN_OTCH + ix1*ATL_TB_RUN_OTCH   + ix2 ]= origin_pat_ofmap[ ix0*TB_PAT_COL*ATL_TB_PAT_OFCH + ix1*ATL_TB_PAT_OFCH + ix2  ]	;
                end
            end
        end

        
        for(i=0; i<TB_RUN_KERSRAM_LENGTH; i=i+1)begin
            ediag = kerw_array_0_temp[i];
            kerw_array_0[i] = {	ediag[ 7 :  0], ediag[15 :  8],ediag[23 : 16],ediag[31 : 24],ediag[39 : 32],ediag[47 : 40],ediag[55 : 48],ediag[63 : 56]	};
            ediag = kerw_array_1_temp[i];
            kerw_array_1[i] = {	ediag[ 7 :  0], ediag[15 :  8],ediag[23 : 16],ediag[31 : 24],ediag[39 : 32],ediag[47 : 40],ediag[55 : 48],ediag[63 : 56]	};
            ediag = kerw_array_2_temp[i];
            kerw_array_2[i] = {	ediag[ 7 :  0], ediag[15 :  8],ediag[23 : 16],ediag[31 : 24],ediag[39 : 32],ediag[47 : 40],ediag[55 : 48],ediag[63 : 56]	};
            ediag = kerw_array_3_temp[i];
            kerw_array_3[i] = {	ediag[ 7 :  0], ediag[15 :  8],ediag[23 : 16],ediag[31 : 24],ediag[39 : 32],ediag[47 : 40],ediag[55 : 48],ediag[63 : 56]	};
            ediag = kerw_array_4_temp[i];
            kerw_array_4[i] = {	ediag[ 7 :  0], ediag[15 :  8],ediag[23 : 16],ediag[31 : 24],ediag[39 : 32],ediag[47 : 40],ediag[55 : 48],ediag[63 : 56]	};
            ediag = kerw_array_5_temp[i];
            kerw_array_5[i] = {	ediag[ 7 :  0], ediag[15 :  8],ediag[23 : 16],ediag[31 : 24],ediag[39 : 32],ediag[47 : 40],ediag[55 : 48],ediag[63 : 56]	};
            ediag = kerw_array_6_temp[i];
            kerw_array_6[i] = {	ediag[ 7 :  0], ediag[15 :  8],ediag[23 : 16],ediag[31 : 24],ediag[39 : 32],ediag[47 : 40],ediag[55 : 48],ediag[63 : 56]	};
            ediag = kerw_array_7_temp[i];
            kerw_array_7[i] = {	ediag[ 7 :  0], ediag[15 :  8],ediag[23 : 16],ediag[31 : 24],ediag[39 : 32],ediag[47 : 40],ediag[55 : 48],ediag[63 : 56]	};
        end  

        for(i=0; i<TB_RUN_KERSRAM_LENGTH_1; i=i+1)begin
            ediag = kerw_array_temp[i];     //DMA_KER_TESTA
            kerw_array[i] = {	ediag[ 7 :  0], ediag[15 :  8],ediag[23 : 16],ediag[31 : 24],ediag[39 : 32],ediag[47 : 40],ediag[55 : 48],ediag[63 : 56]	};
        end

        for(i=0; i<IFWPAT_LENGTH; i=i+1)begin
            ediag = ifmap_w_data_temp[i];
            ifmap_w_data[i] = {	ediag[ 7 :  0], ediag[15 :  8],ediag[23 : 16],ediag[31 : 24],ediag[39 : 32],ediag[47 : 40],ediag[55 : 48],ediag[63 : 56]	};
        end

        for(i=0; i<OT_NUM_FORCMP; i=i+1)begin
            ediag = ofm_gold_temp[i];
            ofm_gold[i] = {	ediag[ 7 :  0], ediag[15 :  8],ediag[23 : 16],ediag[31 : 24],ediag[39 : 32],ediag[47 : 40],ediag[55 : 48],ediag[63 : 56]	};
        end
        for(i=0; i<512; i=i+1)begin
            ediag = {32'd0 , biasw_array_temp[i]};
            biasw_array[i] = ediag ;
            // biasw_array[i] = `ENDIAN_SWAP( ediag );
        end
        //--------- pattern reading end -----------
        // $display("** ifmap[0] = %16x        **", ifmap_w_data[0] );
        // $display("** ifmap[68] = %16x        **", ifmap_w_data[68] );
        // $display("** ifmap[68*2] = %16x        **", ifmap_w_data[68*2] );
        // $display("** ifmap[68*2+1] = %16x        **", ifmap_w_data[68*2+1] );
        // $display("** ifmap[68*2+2] = %16x        **", ifmap_w_data[68*2+2] );
        // $display("** ifmap[68*2+3] = %16x        **", ifmap_w_data[68*2+3] );
        // $display("** ifmap[68*2+4] = %16x        **", ifmap_w_data[68*2+4] );
        // $display("** ifmap[68*2+5] = %16x        **", ifmap_w_data[68*2+5] );
        // $display("** ifmap[68*2+6] = %16x        **", ifmap_w_data[68*2+6] );
        // $display("** ifmap[68*2+7] = %16x        **", ifmap_w_data[68*2+7] );
        // $display("** ifmap[68*3-1] = %16x        **", ifmap_w_data[68*3-1] );
        // $display("** ifw_array[2*208*ATL_CH+67] = %16x        **", ifw_array[2*208*ATL_CH  +67] );

        $display("** param TS_INST_HEAD  = %16x        **", TS_INST_HEAD );
        $display("** param TS_DATA_HEAD  = %16x        **", TS_DATA_HEAD  );
        $display("** param TS_CFG_0		= %16x        **", TS_CFG_0 	 );
        $display("** param TS_CFG_1		= %16x        **", TS_CFG_1 	 );
        $display("** param TS_CFG_2		= %16x        **", TS_CFG_2 	 );
        $display("** param TS_CFG_3		= %16x        **", TS_CFG_3 	 );
        $display("** param TS_CFG_4		= %16x        **", TS_CFG_4 	 );
        $display("** param TS_CFG_5		= %16x        **", TS_CFG_5 	 );
        $display("** param TS_CFG_6		= %16x        **", TS_CFG_6 	 );
        $display("** param TS_CFG_7		= %16x        **", TS_CFG_7 	 );
        $display("** param TS_CFG_8		= %16x        **", TS_CFG_8		 );
        $display("** param TS_CFG_9		= %16x        **", TS_CFG_9		 );
        $display("** param TS_CFG_10	= %16x        **", TS_CFG_10	 );
        $display("** param TS_CFG_11	= %16x        **", TS_CFG_11	 );
        $display("** param TS_CFG_12	= %16x        **", TS_CFG_12	 );
        $display("** param TS_CFG_13	= %16x        **", TS_CFG_13	 );
        $display("** param TS_CFG_14	= %16x        **", TS_CFG_14	 );
        $display("** param TS_CFG_15	= %16x        **", TS_CFG_15	 );        
        $display("** param  INST_HEAD = %16x        **", 	INST_HEAD );
        $display("** param  DATA_HEAD  = %16x        **", 	DATA_HEAD  );
        $display("** param  CFG_0 	 = %16x        **", 	CFG_0 	 );
        $display("** param  CFG_1 	 = %16x        **", 	CFG_1 	 );
        $display("** param  CFG_2 	 = %16x        **", 	CFG_2 	 );
        $display("** param  CFG_3 	 = %16x        **", 	CFG_3 	 );
        $display("** param  CFG_4 	 = %16x        **", 	CFG_4 	 );
        $display("** param  CFG_5 	 = %16x        **", 	CFG_5 	 );
        $display("** param  CFG_6 	 = %16x        **", 	CFG_6 	 );
        $display("** param  CFG_7 	 = %16x        **", 	CFG_7 	 );
        $display("** param  CFG_8		 = %16x        **", CFG_8		 );
        $display("** param  CFG_9		 = %16x        **", CFG_9		 );
        $display("** param  CFG_10	 = %16x        **", 	CFG_10	 );
        $display("** param  CFG_11	 = %16x        **", 	CFG_11	 );
        $display("** param  CFG_12	 = %16x        **", 	CFG_12	 );
        $display("** param  CFG_13	 = %16x        **", 	CFG_13	 );
        $display("** param  CFG_14	 = %16x        **", 	CFG_14	 );
        $display("** param  CFG_15	 = %16x        **", 	CFG_15	 );
        $display("** tr 64'h281c020048160000	 = %16x        **", 	`ENDIAN_SWAP(ANN_TST)	 );
        $printtimescale;
        #1;
        tb_memread_done = 1;

    end







// =============================================================================
// =======		testing control 	============================================
// =============================================================================

    //start test gi circuit
    initial begin
        #1;
        S_AXIS_MM2S_TVALID = 0 ;
        reset = 0;
        #( `CYCLE*3 ) ;
        reset = 1;
        //-----------reset signal start ------------------
        S_AXIS_MM2S_TKEEP = 'hff;
        S_AXIS_MM2S_TLAST = 0 ;
        dutot_done =0 ;	
    
        //-----------reset signal end ------------------
        #( `CYCLE*4 + `NI_DELAY ) ;
        reset = 0;
        #( `CYCLE*5 ) ;

        //---- SA HEAD ----
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= SA_HEAD ;
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= SA_HEAD ;	
        S_AXIS_MM2S_TLAST	= 1;	// last signal 
        wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

        //----- instruction --------------
        // for( iix = 0 ; iix <1 ; iix=iix+1 )begin
        // 	@( posedge clk );
        // 	S_AXIS_MM2S_TVALID = 1 ;
        // 	S_AXIS_MM2S_TDATA	= TS_INST_HEAD ;
        // 	wait(S_AXIS_MM2S_TREADY);
        // end

        @( posedge clk );#1;
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= TS_INST_HEAD ;
            S_AXIS_MM2S_TLAST = 1 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );#1;
            S_AXIS_MM2S_TLAST = 0 ;
            S_AXIS_MM2S_TVALID = 0 ;

        #( `CYCLE*10);
        @( posedge clk );#1;
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= TS_INST_HEAD ;
            S_AXIS_MM2S_TLAST = 1 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );#1;
            S_AXIS_MM2S_TLAST = 0 ;
            S_AXIS_MM2S_TVALID = 0 ;


        #( `CYCLE*30 ) ;
        //----- instruction config--------------
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= TS_CFG_0 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= TS_CFG_1 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 0 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= TS_CFG_2 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= TS_CFG_3 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= TS_CFG_4 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= TS_CFG_5 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= TS_CFG_6 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= TS_CFG_7 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= TS_CFG_8 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= TS_CFG_9 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= TS_CFG_10 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= TS_CFG_11 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= TS_CFG_12 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= TS_CFG_13 ;
            wait(S_AXIS_MM2S_TREADY);

        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= TS_CFG_14 ;
            wait(S_AXIS_MM2S_TREADY);

        @( posedge clk );
            S_AXIS_MM2S_TVALID = 1 ;
            S_AXIS_MM2S_TDATA	= TS_CFG_15 ;
            S_AXIS_MM2S_TLAST = 1 ;
            wait(S_AXIS_MM2S_TREADY);
        @( posedge clk );
            S_AXIS_MM2S_TLAST = 0 ;
            S_AXIS_MM2S_TVALID = 0 ;
            iix = 0 ;

        //----- instruction --------------

        wait(tb_memread_done) ;
        #( `CYCLE*5 ) ;
        


        tst_fl_sent_kernel 	= 1 ;
        i1=0 ;

        //------------------------------------------------
        //---- first load -- sending kernel data ----
        //------------ now send kernel sram  data -----
            //---- DATA HEAD ----
            @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= TS_DATA_HEAD ;
            wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= TS_DATA_HEAD ;	
            S_AXIS_MM2S_TLAST	= 1;	// last signal 
            wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;
            $display("TB_RUN_KERSRAM_LENGTH_1 = %d " , TB_RUN_KERSRAM_LENGTH_1);
            //---- DATA HEAD end---------------------
            for ( i1=0 ; i1<TB_RUN_KERSRAM_LENGTH_1 ; i1=i1+1 )begin	// each kernel sram need 288 address data
                @(posedge clk ); #( `CYCLE/2 );
                S_AXIS_MM2S_TVALID	=	1	;
                S_AXIS_MM2S_TDATA = kerw_array[ i1  ]	;
                //$display("** ker count	 = %d        **", 	i1	);
                if( i1 == TB_RUN_KERSRAM_LENGTH_1 -1 )begin
                    S_AXIS_MM2S_TLAST = 1; 
                end
                wait(S_AXIS_MM2S_TREADY);
            end
            @(posedge clk ) ; #( `CYCLE/2 );
                S_AXIS_MM2S_TVALID = 0 ;
                S_AXIS_MM2S_TLAST = 0 ;
                i1=0 ;
        
        tst_fl_sent_kernel 	= 0 ;

        
        //------------------------------------------------
        //---- first load -- sending bias data ----
        //------------ now send bias sram data -----
        tst_fl_sent_bias = 1 ;
            //---- DATA HEAD ----
            @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= TS_DATA_HEAD ;
            wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= TS_DATA_HEAD ;	
            S_AXIS_MM2S_TLAST	= 1;	// last signal 
            wait(S_AXIS_MM2S_TREADY);
            @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;
            $display("TB_RUN_BIAS_LENGTH = %d " , TB_RUN_BIAS_LENGTH);
            //---- DATA HEAD end---------------------
            for ( i1=0 ; i1<TB_RUN_BIAS_LENGTH ; i1=i1+1 )begin	
                
                @(posedge clk );#( `CYCLE/2 );
                S_AXIS_MM2S_TVALID	=	1	;
                S_AXIS_MM2S_TDATA = biasw_array[ i1  ] 	;
                $display("** bias count	 = %d        **", 	i1	);
                $display("** bias data	 = %h        **", 	S_AXIS_MM2S_TDATA	);
                if( i1 == TB_RUN_BIAS_LENGTH-1 )begin
                    S_AXIS_MM2S_TLAST = 1; 
                end
                wait(S_AXIS_MM2S_TREADY);
            end
            @(posedge clk ) ;#( `CYCLE/2 );
                S_AXIS_MM2S_TVALID = 0 ;
                S_AXIS_MM2S_TLAST = 0 ;
                i1=0 ;
        tst_fl_sent_bias = 0 ;
        //------------------------------------------------
        



        // ===========================================================================
        // =======		input feature map start sending		==========================	
        // ===========================================================================
        //----- after first load data we going to send ifmap data  --------------
        tst_fl_sent_ifmap 	= 1 ;
        i0 = 0 ;
        


			//---- DATA HEAD -----------------------
			while ( i0< 2 ) begin
				
				@(posedge clk ); #( `CYCLE/2 );
				S_AXIS_MM2S_TVALID	=	1	;
				S_AXIS_MM2S_TDATA = TS_DATA_HEAD ;
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

			@( posedge clk ); #( `CYCLE/2 ); 	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;
			i0 = 0 ;
			//---- DATA HEAD end---------------------

        for ( i1=0 ; i1<TB_RUN_OTROW ; i1=i1+1 )begin	// 3row data
			while ( i0< ATL_RUN_COL_P2*ATL_CH ) begin
				
				@(posedge clk ); #( `CYCLE/2 );
				S_AXIS_MM2S_TVALID	=	1	;
				S_AXIS_MM2S_TDATA = ifmap_w_data[ i0 + i1*ATL_RUN_COL_P2*ATL_CH ]	;
				if( ( i0 == ATL_RUN_COL_P2*ATL_CH - 1  ) && ( i1 == TB_RUN_OTROW - 1  ) )begin
					S_AXIS_MM2S_TLAST = 1; 
				end
				i0=i0+1;
                wait(S_AXIS_MM2S_TREADY);
			end

			@(posedge clk); #( `CYCLE/2 );
				S_AXIS_MM2S_TVALID = 0 ;
				S_AXIS_MM2S_TLAST = 0 ;
				i0 = 0 ;
		end
		tst_fl_sent_ifmap 	= 0 ;
//--------------------------------------------------------------------
		#( `CYCLE*`ROW_DELAY) ;
		// #( `CYCLE*2000) ;
        

		


        #( `CYCLE*5 ) ;

		wait( tb_o_cnt > ((TB_RUN_OTCH*TB_RUN_COL*TB_RUN_OTROW)/8 -1 ) );
		#( `CYCLE*50 ) ;
        @(posedge clk); #1;
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
    if(reset)begin
        tb_o_cnt <= 0 ;
    end
    else begin
        if( M_AXIS_S2MM_TREADY && M_AXIS_S2MM_TVALID )begin
            tb_o_cnt <= tb_o_cnt +1  ;
            $display("tb_o_cnt",tb_o_cnt);
            ofm_array [tb_o_cnt]<= M_AXIS_S2MM_TDATA ;
        end
        else begin
            tb_o_cnt <= tb_o_cnt ;
        end
    end
end


// =============================================================================
// ===============		compare data block		================================
// =============================================================================
    initial begin
        #1;
        wait( reset ) ;
        #( `CYCLE*5 ) ;   
        wait( dutot_done ) ;	// wait DUT output data all done
        err_ofmap = 0;
        icp = 0;
        x_cnt = 0;
        //  OT_NUM_FORCMP = TB_RUN_COL * TB_RUN_OTCH/8 * TB_RUN_OTROW = 4096, exactly
        //  the number of words in Q.dat, so every slot really is compared. x_cnt
        //  still guards the X-vs-X case: `!==` treats X as equal to X, so an output
        //  the DUT never drove would otherwise be counted as a match.
        for (icp = 0; icp<OT_NUM_FORCMP ; icp= icp+1 ) begin
            if( ofm_array[icp] === 64'bx ) x_cnt = x_cnt + 1 ;
            if(  ofm_array[icp] !== ofm_gold[icp] ) begin
                err_ofmap = err_ofmap +1 ;
                $display("** error : number => %d , error pattern => %16x , gold pattern => %16x        **",icp,ofm_array[icp],ofm_gold[icp]  );
            end
        end

        //----display the compare result on terminal ----
        $display("********************************************************************");
        $display("**  ---- the compare result -----                                 **");
        $display("**  row_in=%3d ,ch_in= %3d ,col_out= %3d ,ch_out= %3d             **", TB_RUN_OTROW,TB_PAT_IFCH,TB_RUN_COL,TB_RUN_OTCH );
        $display("**  number of output data = %3d . compare with %3d gold pattern   **", tb_o_cnt , OT_NUM_FORCMP);
        $display("**  ofmap errors = %3d                                            **", err_ofmap );
        $display("**    ------------------------------                              **");
        $display("**  please check the error number ,Simulation STOP at cycle %d **",cycle);
        $display("**  If needed, You can increase End_CYCLE value in tb.sv          **");
        $display("********************************************************************");

        //----    verdict    -----
        $display("====================================================================");
        $display(">>> SA: DUT produced %0d output words; compared %0d against gold", tb_o_cnt, OT_NUM_FORCMP);
        $display(">>> undriven (all-X) output words : %0d", x_cnt);
        if( err_ofmap == 0 && x_cnt == 0 && tb_o_cnt > 0 )
            $display(">>> RESULT: PASS  (%0d/%0d bit-exact)", OT_NUM_FORCMP, OT_NUM_FORCMP);
        else if( tb_o_cnt == 0 )
            $display(">>> RESULT: FAIL  (DUT produced no output at all)");
        else if( x_cnt != 0 )
            $display(">>> RESULT: FAIL  (%0d mismatches, and %0d words were never driven)", err_ofmap, x_cnt);
        else
            $display(">>> RESULT: FAIL  (%0d/%0d mismatched)", err_ofmap, OT_NUM_FORCMP);
        $display(">>> CYCLES: %0d", cycle);
        $display("====================================================================");



        // $display("** output array [ 0 ] = %16x        **", ofm_array[0] );
        // $display("** output array [ 1 ] = %16x        **", ofm_array[1] );
        // $display("** output array [ 2 ] = %16x        **", ofm_array[2] );
        // $display("** output array g [ 0 ] = %16x        **", ofm_gold[0] );
        // $display("** output array g [ 1 ] = %16x        **", ofm_gold[1] );
        // $display("** output array g [ 2 ] = %16x        **", ofm_gold[2] );
        $finish;


    end
//--------------------------------------------------------------------------

// =============================================================================



endmodule

