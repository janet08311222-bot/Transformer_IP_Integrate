// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2022.11.09
// Ver      : 2.0
// Func     : connect the sram and send data to pe
// 		2022.11.09 : deside sram signal for read or write and which sram buffer 
// 		2023.02.10 : join LWX coding the 512 MAC version, and write module need
//					to be rebuilded.
//		2023.09.21(Wen-Jia Yang) : fix input channel = 16,32,48,64 to run all 640 col
//   
// ============================================================================
//`define FPGA_SRAM_SETTING
// `define	FPGA_ILA_CHK_SETTING

module ifsram_rw #(
		parameter 	TBITS = 64	
	,				TBYTE = 8	
	,	IFMAP_SRAM_ADDBITS = 11 	
	,	IFMAP_SRAM_DATA_WIDTH = 64	
	,	CNTSTP_WIDTH = 3			 //config input setting
	,	IFWSTG0_CNTBITS = 5			//config input setting
	,	IFWSTG1_CNTBITS = 3			//config input setting
	,	DATAIN_CNT_BITS = 9			//config input setting
)(
		clk		
	,	reset	

	,	if_write_data_din			
	,	if_write_empty_n_din		
	,	if_write_read_dout			
	,	if_write_done 			
	,	if_write_busy 			
	,	if_write_start			
	,	if_write_en			
	,	if_read_done 			
	,	if_read_busy 			
	,	if_read_start			
	,	if_pad_done 	
	,	if_pad_busy 	
	,	if_pad_start	
	      	
	,	row_finish		
	, 	dy2_conv_finish					
	,	if_read_current_state	
	,	if_read_last		//for last row
	,	rdwd_done

	,	dout_ifsr_0 ,	dout_ifsr_1 ,	dout_ifsr_2 ,	dout_ifsr_3 ,	dout_ifsr_4 ,	dout_ifsr_5 ,	dout_ifsr_6 ,	dout_ifsr_7	
	, 	ifr_valid_0 , 	ifr_valid_1 , 	ifr_valid_2 , 	ifr_valid_3 , 	ifr_valid_4 , 	ifr_valid_5 , 	ifr_valid_6 , 	ifr_valid_7 	
	,	ifr_final_0 , 	ifr_final_1 , 	ifr_final_2 , 	ifr_final_3 , 	ifr_final_4 , 	ifr_final_5 , 	ifr_final_6 , 	ifr_final_7  	

	//config input setting(ifsram_pd)
	,	cfg_atlchin		
	,	cfg_conv_switch			
	,	cfg_mast_state	
	,	cfg_pd_list_0	
	,	cfg_pd_list_1	
	,	cfg_pd_list_2	
	,	cfg_pd_list_3	
	,	cfg_pd_list_4	
	,	cfg_cnt_step_p1		// 3x3 = 3'd3 , 5x5 = 3'd7 
	,	cfg_cnt_step_p2		// 3x3 = 3'd0 , 5x5 = 3'd3 

	//config input setting(ifsram_w)
	// ,	cfg_pdlf
	// ,	cfg_pdrg
	// ,	cfg_nor
	,	cfg_stg0_nor_finum
	,	cfg_stg0_pdb0_finum
	,	cfg_stg0_pdb1_finum
	,	cfg_stg1_eb_col	
	,	cfg_dincnt_finum	
	,	cfg_rowcnt_finum	

	//config input setting(ifsram_r)
	,	cfg_ifr_window	
	,   cfg_ifr_kernel_repeat
	,   cfg_ift_total_window



	`ifdef FPGA_ILA_CHK_SETTING
	,	ick_addrb_sram_if0b0	
	`endif 
);





//----------------------------------------------------------------------------
//---------------		Parameter		--------------------------------------
//----------------------------------------------------------------------------
// localparam IFMAP_SRAM_ADDBITS = 11 ;
// localparam IFMAP_SRAM_DATA_WIDTH = 64;
// localparam CNTSTP_WIDTH = 3		; //config input setting
// localparam IFWSTG0_CNTBITS = 5	;//config input setting
// localparam IFWSTG1_CNTBITS = 3	;//config input setting
// localparam DATAIN_CNT_BITS = 9	;//config input setting



//--------		Config master state		-----------
	localparam LEFT 	= 3'd1;
	localparam NORMAL 	= 3'd2;
	localparam RIGH 	= 3'd3;

	localparam [2:0] 
		IDLE          = 3'd0,
		UP_PADDING    = 3'd1,
		ROW_ADDR_012  = 3'd2,   
		ROW_ADDR_123  = 3'd3, 
		ROW_ADDR_230  = 3'd4,
		ROW_ADDR_301  = 3'd5,
		DOWN_PADDING  = 3'd6;

//----------------------------------------------------------------------------
//---------------		I/O			------------------------------------------
//----------------------------------------------------------------------------
	input	wire 				clk		;
	input	wire 				reset	;
	
	//fifo
	input	wire [TBITS-1: 0 ]	if_write_data_din		;
	input	wire 				if_write_empty_n_din		;
	output	wire 				if_write_read_dout		;
	
	
	//if sram read & write
	output 	wire 				if_write_done		;	// make the next state change
	output	wire				if_write_busy		;	// when catch start signal make busy signal  "ON"
	input	wire				if_write_start		;	// control from get_ins 
	output	wire				if_write_en			;	// only write_en ="1", if_write can take data from fifo
	
	output	wire	   			if_read_done 		;
	output	wire				if_read_busy 		;
	input   wire				if_read_start		;
	
	output	wire 				if_pad_done 		;
	output	wire				if_pad_busy 		;
	input   wire				if_pad_start		;
	
	
	
	
	// control signal
	output wire row_finish;
	output wire dy2_conv_finish;
	input wire [2:0] if_read_current_state;
	input wire if_read_last;
	input wire rdwd_done;

// config input setting(ifsram_pd)
input	wire	[8-1:0]	cfg_atlchin			;	
input	wire	[3-1:0]	cfg_conv_switch		;	
input	wire	[3-1:0]	cfg_mast_state		;
input	wire	[IFMAP_SRAM_ADDBITS-1:0]	cfg_pd_list_0		;
input	wire	[IFMAP_SRAM_ADDBITS-1:0]	cfg_pd_list_1		;
input	wire	[IFMAP_SRAM_ADDBITS-1:0]	cfg_pd_list_2		;
input	wire	[IFMAP_SRAM_ADDBITS-1:0]	cfg_pd_list_3		;
input	wire	[IFMAP_SRAM_ADDBITS-1:0]	cfg_pd_list_4		;
input	wire	[CNTSTP_WIDTH-1:0]	cfg_cnt_step_p1		;
input	wire	[CNTSTP_WIDTH-1:0]	cfg_cnt_step_p2		;
// config input setting(ifsram_w)
// input	wire 	[6-1:0]		cfg_pdlf	;
// input	wire 	[6-1:0]		cfg_pdrg	;
// input	wire 	[6-1:0]		cfg_nor		;
input	wire	[IFWSTG0_CNTBITS-1 :0]	cfg_stg0_nor_finum	;
input	wire	[IFWSTG0_CNTBITS-1 :0]	cfg_stg0_pdb0_finum	;
input	wire	[IFWSTG0_CNTBITS-1 :0]	cfg_stg0_pdb1_finum	;
input	wire	[IFWSTG1_CNTBITS-1 :0]	cfg_stg1_eb_col		;
input	wire	[DATAIN_CNT_BITS-1 :0]	cfg_dincnt_finum	;
input	wire	[3-1 :0]	cfg_rowcnt_finum	;
// config input setting(ifsram_r)
input	wire	[7:0]	cfg_ifr_window;
input   wire    [7:0]   cfg_ifr_kernel_repeat;
input   wire    [7:0] 	cfg_ift_total_window;


//----to PE signal
output	wire [TBITS-1 :0] dout_ifsr_0 ,dout_ifsr_1 ,dout_ifsr_2 ,dout_ifsr_3 ,dout_ifsr_4 ,dout_ifsr_5 ,dout_ifsr_6 ,dout_ifsr_7;
output	wire	ifr_valid_0 , ifr_valid_1 , ifr_valid_2 , ifr_valid_3 , ifr_valid_4 , ifr_valid_5 , ifr_valid_6 , ifr_valid_7	;
output	wire	ifr_final_0 , ifr_final_1 , ifr_final_2 , ifr_final_3 , ifr_final_4 , ifr_final_5 , ifr_final_6 , ifr_final_7	;

// ============================================================================
// =============================	Declare		===============================
// ============================================================================
//-----------------------------------------------------------------------------
//----- wirte if sram -----
	wire cen_write_ifsram_0 , cen_write_ifsram_1 , cen_write_ifsram_2 , cen_write_ifsram_3 , cen_write_ifsram_4 , cen_write_ifsram_5 , cen_write_ifsram_6 , cen_write_ifsram_7 ;
	wire wen_write_ifsram_0 , wen_write_ifsram_1 , wen_write_ifsram_2 , wen_write_ifsram_3 , wen_write_ifsram_4 , wen_write_ifsram_5 , wen_write_ifsram_6 , wen_write_ifsram_7 ;
	wire [TBITS-1:0]	data_write_ifsram_0 , data_write_ifsram_1 , data_write_ifsram_2 , data_write_ifsram_3 
					, data_write_ifsram_4 , data_write_ifsram_5 , data_write_ifsram_6 , data_write_ifsram_7;
	wire [IFMAP_SRAM_ADDBITS-1:0]	addr_write_ifsram_0 , addr_write_ifsram_1 , addr_write_ifsram_2 , addr_write_ifsram_3 
								, addr_write_ifsram_4 , addr_write_ifsram_5 , addr_write_ifsram_6 , addr_write_ifsram_7	;
//-----------------------------------------------------------------------------

//---- dout signal from SRAM ----
	reg  [TBITS-1:0] dout_sram_if;
	reg dy_dout_en0;

	reg if_valid_0s0 , if_valid_0s1 , if_valid_0s2 , if_valid_0s3 , if_valid_0s4 , if_valid_0s5 , if_valid_0s6 , if_valid_0s7	;
	reg if_final_0s0 , if_final_0s1 , if_final_0s2 , if_final_0s3 , if_final_0s4 , if_final_0s5 , if_final_0s6 , if_final_0s7	;
//-----------------------------------------------------------------------------
//----- read if sram -----
	wire cen_read	;
	reg  cen_read1	, cen_read2	, cen_read3	, cen_read4	, cen_read5	, cen_read6	, cen_read7	;

	wire [IFMAP_SRAM_ADDBITS-1:0] addr_read_ifsram ;
	reg [IFMAP_SRAM_ADDBITS-1:0] addr_read_ifsram1 , addr_read_ifsram2 , addr_read_ifsram3 
			,	addr_read_ifsram4 , addr_read_ifsram5 , addr_read_ifsram6 , addr_read_ifsram7	;

	reg ifsram1b0_write	;
	reg ifsram2b0_write	;
	reg ifsram3b0_write	;
	reg ifsram4b0_write	;
	reg ifsram5b0_write	;
	reg ifsram6b0_write	;
	reg ifsram7b0_write	;

	reg ifsram1b0_read  ;
	reg ifsram2b0_read	;
	reg ifsram3b0_read	;
	reg ifsram4b0_read	;
	reg ifsram5b0_read	;
	reg ifsram6b0_read	;
	reg ifsram7b0_read	;
	wire [1:0] ifr_row_number ;

	wire en_ifr_over_toplength_b0 ;
	reg en_ifr_over_toplength_tmp0 ;
	reg en_ifr_over_toplength_tmp1 ;
	reg en_ifr_over_toplength_tmp2 ;
	reg en_ifr_over_toplength_b1 ;
	reg en_ifr_over_toplength_b2 ;
	reg en_ifr_over_toplength_b3 ;
	reg en_ifr_over_toplength_b4 ;
	reg en_ifr_over_toplength_b5 ;
	reg en_ifr_over_toplength_b6 ;
	reg en_ifr_over_toplength_b7 ;
	
//-----------------------------------------------------------------------------
//----    actually cen wen signal declare    -----
// for actually connection between FPGA and CBDK
	wire atla_cen_if0b0 , atla_cen_if1b0 , atla_cen_if2b0 , atla_cen_if3b0 ;
	wire atla_cen_if4b0 , atla_cen_if5b0 , atla_cen_if6b0 , atla_cen_if7b0 ;
	wire atlb_cen_if0b0 , atlb_cen_if1b0 , atlb_cen_if2b0 , atlb_cen_if3b0 ;
	wire atlb_cen_if4b0 , atlb_cen_if5b0 , atlb_cen_if6b0 , atlb_cen_if7b0 ;
	wire atl_wen_if0b0 , atl_wen_if1b0 , atl_wen_if2b0 , atl_wen_if3b0 ;
	wire atl_wen_if4b0 , atl_wen_if5b0 , atl_wen_if6b0 , atl_wen_if7b0 ;

//---- SRAM Port signal declare	----

	
	wire cena_if0b0 ;
	wire cena_if1b0 ;
	wire cena_if2b0 ;
	wire cena_if3b0 ;
	wire cena_if4b0 ;
	wire cena_if5b0 ;
	wire cena_if6b0 ;
	wire cena_if7b0 ;
	
	wire cenb_if0b0 ;
	wire cenb_if1b0 ;
	wire cenb_if2b0 ;
	wire cenb_if3b0 ;
	wire cenb_if4b0 ;
	wire cenb_if5b0 ;
	wire cenb_if6b0 ;
	wire cenb_if7b0 ;

	wire wen_if0b0 ;
	wire wen_if1b0 ;
	wire wen_if2b0 ;
	wire wen_if3b0 ;
	wire wen_if4b0 ;
	wire wen_if5b0 ;
	wire wen_if6b0 ;
	wire wen_if7b0 ;

	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addr_sram_if0b0	;
	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addr_sram_if1b0	;
	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addr_sram_if2b0	;
	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addr_sram_if3b0	;
	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addr_sram_if4b0	;
	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addr_sram_if5b0	;
	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addr_sram_if6b0	;
	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addr_sram_if7b0	;

	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addra_sram_if0b0	;
	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addra_sram_if1b0	;
	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addra_sram_if2b0	;
	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addra_sram_if3b0	;
	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addra_sram_if4b0	;
	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addra_sram_if5b0	;
	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addra_sram_if6b0	;
	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addra_sram_if7b0	;

	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addrb_sram_if0b0	;
	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addrb_sram_if1b0	;
	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addrb_sram_if2b0	;
	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addrb_sram_if3b0	;
	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addrb_sram_if4b0	;
	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addrb_sram_if5b0	;
	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addrb_sram_if6b0	;
	wire [  IFMAP_SRAM_ADDBITS-1  :   0   ]   addrb_sram_if7b0	;

	wire [  TBITS-1  :   0   ]   din_sram_if0b0	;
	wire [  TBITS-1  :   0   ]   din_sram_if1b0	;
	wire [  TBITS-1  :   0   ]   din_sram_if2b0	;
	wire [  TBITS-1  :   0   ]   din_sram_if3b0	;
	wire [  TBITS-1  :   0   ]   din_sram_if4b0	;
	wire [  TBITS-1  :   0   ]   din_sram_if5b0	;
	wire [  TBITS-1  :   0   ]   din_sram_if6b0	;
	wire [  TBITS-1  :   0   ]   din_sram_if7b0	;

	wire [  TBITS-1  :   0   ]   dout_sram_if0b0	;
	wire [  TBITS-1  :   0   ]   dout_sram_if1b0	;
	wire [  TBITS-1  :   0   ]   dout_sram_if2b0	;
	wire [  TBITS-1  :   0   ]   dout_sram_if3b0	;
	wire [  TBITS-1  :   0   ]   dout_sram_if4b0	;
	wire [  TBITS-1  :   0   ]   dout_sram_if5b0	;
	wire [  TBITS-1  :   0   ]   dout_sram_if6b0	;
	wire [  TBITS-1  :   0   ]   dout_sram_if7b0	;

	wire [  TBITS-1  :   0   ] 	din_mux0	;
	wire [  TBITS-1  :   0   ] 	din_mux1	;
	wire [  TBITS-1  :   0   ] 	din_mux2	;
	wire [  TBITS-1  :   0   ] 	din_mux3	;
	wire [  TBITS-1  :   0   ] 	din_mux4	;
	wire [  TBITS-1  :   0   ] 	din_mux5	;
	wire [  TBITS-1  :   0   ] 	din_mux6	;
	wire [  TBITS-1  :   0   ] 	din_mux7	;


	//----    SRAM dout delay valid    -----
	reg dy_dout_valid_0	;
	reg dy_dout_valid_1	;
	reg dy_dout_valid_2	;
	reg dy_dout_valid_3	;
	reg dy_dout_valid_4	;
	reg dy_dout_valid_5	;
	reg dy_dout_valid_6	;
	reg dy_dout_valid_7	;
//-----------------------------------------------------------------------------

//----    padding signal declare    -----
	wire	if_pad_pdb0_cen ;
	wire	if_pad_pdb1_cen ;
	wire	if_pad_pdb6_cen ;
	wire	if_pad_pdb7_cen ;

	wire	if_pad_pdb0_wen ;
	wire	if_pad_pdb1_wen ;
	wire	if_pad_pdb6_wen ;
	wire	if_pad_pdb7_wen ;

	wire	[IFMAP_SRAM_ADDBITS-1:0] if_pad_pdb0_addr ;
	wire	[IFMAP_SRAM_ADDBITS-1:0] if_pad_pdb1_addr ;
	wire	[IFMAP_SRAM_ADDBITS-1:0] if_pad_pdb6_addr ;
	wire	[IFMAP_SRAM_ADDBITS-1:0] if_pad_pdb7_addr ;

	wire	[TBITS-1:0] if_pad_pd_data ;
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------


////----    Config register    -----
	reg		[8-1:0]	rcfg_atlchin			;	
	reg		[3-1:0]	rcfg_conv_switch		;	
	reg		[3-1:0]	rcfg_mast_state		;
	reg		[IFMAP_SRAM_ADDBITS-1:0]	rcfg_pd_list_0		;
	reg		[IFMAP_SRAM_ADDBITS-1:0]	rcfg_pd_list_1		;
	reg		[IFMAP_SRAM_ADDBITS-1:0]	rcfg_pd_list_2		;
	reg		[IFMAP_SRAM_ADDBITS-1:0]	rcfg_pd_list_3		;
	reg		[IFMAP_SRAM_ADDBITS-1:0]	rcfg_pd_list_4		;
	reg		[CNTSTP_WIDTH-1:0]	rcfg_cnt_step_p1		;
	reg		[CNTSTP_WIDTH-1:0]	rcfg_cnt_step_p2	;

	// reg		[6-1:0]		rcfg_pdlf	;
	// reg		[6-1:0]		rcfg_pdrg	;
	// reg		[6-1:0]		rcfg_nor		;
	reg		[IFWSTG0_CNTBITS-1 :0]	rcfg_stg0_nor_finum	;
	reg		[IFWSTG0_CNTBITS-1 :0]	rcfg_stg0_pdb0_finum	;
	reg		[IFWSTG0_CNTBITS-1 :0]	rcfg_stg0_pdb1_finum	;
	reg		[IFWSTG1_CNTBITS-1 :0]	rcfg_stg1_eb_col		;
	reg		[DATAIN_CNT_BITS-1 :0]	rcfg_dincnt_finum		;
	reg		[3-1 :0]	rcfg_rowcnt_finum		;

	reg		[8-1:0]		rcfg_ifr_window	;
	reg     [7:0]		rcfg_ifr_kernel_repeat;
	reg  	[7:0]		rcfg_ift_total_window;
//-----------------------------------------------------------------------------


// ============================================================================
// ========		Config register		 ==========================================
// ============================================================================
always @(posedge clk ) begin
	if(reset)begin
		rcfg_mast_state	<= LEFT 	;	//NORMAL LEFT RIGH 	
		// rcfg_pdlf		<= 6'd8 	;
		// rcfg_pdrg		<= 6'd8 	;
		// rcfg_nor			<= 6'd12 	;
		rcfg_atlchin		<= 8'd4		;	// ch64->8 ch32->4 ... = ch_in/8
		rcfg_conv_switch <= 3'd2		;	// 3x3 = 3'd2 , 5x5 = 3'd3 

		//(for counter, don'd use subtract)
		rcfg_stg0_nor_finum	<=	5'd11	;	// 3x3 pad=1 needed (for counter, don'd use subtract)
		rcfg_stg0_pdb0_finum	<=	5'd7	;	// 3x3 pad=1 needed, pdb0_finum	= (3-1)*atl_ch_in -1 = 2*4-1 = 7 , 5x5 pd=2 pdb0_finum =(5-2)*atl_ch_in -1,(for counter, don'd use subtract)
		rcfg_stg0_pdb1_finum	<=	5'd7	;	// 5x5 pad=2 needed (for counter, don'd use subtract)
		rcfg_stg1_eb_col		<=	5'd1	;	// how many col for each buffer, every buffer column = run_col -1 (for counter, don'd use subtract)
		rcfg_dincnt_finum		<=	9'd67	;	// din count final number
		rcfg_rowcnt_finum		<=	3'd2	;	// din count final number
		rcfg_ifr_window			<= 4		;   // din window number for each buffer
		rcfg_ifr_kernel_repeat	<= 7;       //kernel nember-1
		rcfg_ift_total_window 	<= 4;
	end
	else begin
		rcfg_mast_state			<= 	cfg_mast_state	;
		// rcfg_pdlf				<= 	cfg_pdlf			;
		// rcfg_pdrg				<= 	cfg_pdrg			;
		// rcfg_nor				<= 	cfg_nor			;
		rcfg_atlchin			<= 	cfg_atlchin		;
		rcfg_conv_switch 		<= 	cfg_conv_switch	;	
		rcfg_stg0_nor_finum		<=	cfg_stg0_nor_finum	;
		rcfg_stg0_pdb0_finum	<=	cfg_stg0_pdb0_finum	;
		rcfg_stg0_pdb1_finum	<=	cfg_stg0_pdb1_finum	;
		rcfg_stg1_eb_col		<=	cfg_stg1_eb_col		;
		rcfg_dincnt_finum		<=	cfg_dincnt_finum		;
		rcfg_rowcnt_finum		<=	cfg_rowcnt_finum		;
		rcfg_ifr_window			<=  cfg_ifr_window;
		rcfg_ifr_kernel_repeat	<=  cfg_ifr_kernel_repeat;
		rcfg_ift_total_window 	<= 	cfg_ift_total_window;
	end
end

/*
`ifdef LEFT_3CP
	localparam PD_LIST_0 = 9'd0		;
	localparam PD_LIST_1 = 9'd24	;
	localparam PD_LIST_2 = 9'd48	;
	localparam PD_LIST_3 = 9'd0		;
	localparam PD_LIST_4 = 9'd0		;
`elsif LEFT_5CP
	localparam PD_LIST_0 = 9'd0		;
	localparam PD_LIST_1 = 9'd20	;
	localparam PD_LIST_2 = 9'd40	;
	localparam PD_LIST_3 = 9'd60		;
	localparam PD_LIST_4 = 9'd80		;
`elsif RIGH_3CP
	localparam PD_LIST_0 = 9'd44	;
	localparam PD_LIST_1 = 9'd56	;
	localparam PD_LIST_2 = 9'd68	;
	localparam PD_LIST_3 = 9'd0		;
	localparam PD_LIST_4 = 9'd0		;
`elsif RIGH_5CP
	localparam PD_LIST_0 = 9'd112		;
	localparam PD_LIST_1 = 9'd132		;
	localparam PD_LIST_2 = 9'd152		;
	localparam PD_LIST_3 = 9'd172		;
	localparam PD_LIST_4 = 9'd192		;
`endif 
*/

always @(posedge clk ) begin
	if(reset)begin
		//----    padding list for shifting    -----
		rcfg_pd_list_0	<= 9'd0			;	// use c_code compute PD_LIST_0
		rcfg_pd_list_1	<= 9'd24		;	// use c_code compute PD_LIST_1
		rcfg_pd_list_2	<= 9'd48		;	// use c_code compute PD_LIST_2
		rcfg_pd_list_3	<= 9'd0			;	// use c_code compute PD_LIST_3
		rcfg_pd_list_4	<= 9'd0			;	// use c_code compute PD_LIST_4
		rcfg_cnt_step_p1	<= 3'd3;		// 3x3 = 3'd3 , 5x5 = 3'd7 
		rcfg_cnt_step_p2	<= 3'd0;		// 3x3 = 3'd0 , 5x5 = 3'd3 
	end
	else begin
		//----    padding list for shifting which reference LEFT RIGHT    -----
		rcfg_pd_list_0	<= cfg_pd_list_0	;
		rcfg_pd_list_1	<= cfg_pd_list_1	;
		rcfg_pd_list_2	<= cfg_pd_list_2	;
		rcfg_pd_list_3	<= cfg_pd_list_3	;
		rcfg_pd_list_4	<= cfg_pd_list_4	;
		rcfg_cnt_step_p1	<= cfg_cnt_step_p1	;
		rcfg_cnt_step_p2	<= cfg_cnt_step_p2	;
	end
end

// always @(posedge clk ) begin
// 	if(reset)begin
// 		`ifdef LEFT_3CP
// 			cfg_cnt_step_p1	<= 3'd3	;		// atl_ch_in*1 -1 =3
// 			cfg_cnt_step_p2	<= 3'd0	;		
// 			cfg_mast_state	<= LEFT 	;	//NORMAL LEFT RIGH 	
// 			cfg_conv_switch <= 3'd2		;	// 3x3 = 3'd2 , 5x5 = 3'd3 
// 		`elsif LEFT_5CP
// 			cfg_cnt_step_p1	<= 3'd7	;		// atl_ch_in*2 -1 =7
// 			cfg_cnt_step_p2	<= 3'd3	;		// atl_ch_in -1	=3
// 			cfg_mast_state	<= LEFT 	;	//NORMAL LEFT RIGH 	
// 			cfg_conv_switch <= 3'd3		;	// 3x3 = 3'd2 , 5x5 = 3'd3 
// 		`elsif RIGH_3CP
// 			cfg_cnt_step_p1	<= 3'd3	;		
// 			cfg_cnt_step_p2	<= 3'd0	;		
// 			cfg_mast_state	<= RIGH 	;	//NORMAL LEFT RIGH 	
// 			cfg_conv_switch <= 3'd2		;	// 3x3 = 3'd2 , 5x5 = 3'd3 
// 		`elsif RIGH_5CP
// 			cfg_cnt_step_p1	<= 3'd7	;		
// 			cfg_cnt_step_p2	<= 3'd3	;	
// 			cfg_mast_state	<= RIGH 	;	//NORMAL LEFT RIGH 	
// 			cfg_conv_switch <= 3'd3		;	// 3x3 = 3'd2 , 5x5 = 3'd3 
// 		`endif 

// 	end
// 	else begin
// 		cfg_cnt_step_p1	<= cfg_cnt_step_p1	;
// 		cfg_cnt_step_p2	<= cfg_cnt_step_p2	;
// 		cfg_mast_state	<= cfg_mast_state	;	//NORMAL LEFT RIGH 	
// 		cfg_conv_switch <= cfg_conv_switch 	;	// 3x3 = 3'd2 , 5x5 = 3'd3 
// 	end
// end
//----------------------------------------------------------------------------
reg dy0_ifsram0_read_0, dy0_ifsram0_read_1, dy0_ifsram0_read_2, dy0_ifsram0_read_3, dy0_ifsram0_read_4, dy0_ifsram0_read_5, dy0_ifsram0_read_6, dy0_ifsram0_read_7;

always @ (posedge clk)begin
	if(reset)
		dy0_ifsram0_read_0 <= 0;
	else 
		dy0_ifsram0_read_0 <= if_read_busy;
end

always @ (posedge clk)begin
	if(reset)begin
		dy0_ifsram0_read_1 <= 0;
		dy0_ifsram0_read_2 <= 0;
		dy0_ifsram0_read_3 <= 0;
		dy0_ifsram0_read_4 <= 0;
		dy0_ifsram0_read_5 <= 0;
		dy0_ifsram0_read_6 <= 0;
		dy0_ifsram0_read_7 <= 0;
	end
	else begin
		dy0_ifsram0_read_1 <= dy0_ifsram0_read_0;
		dy0_ifsram0_read_2 <= dy0_ifsram0_read_1;
		dy0_ifsram0_read_3 <= dy0_ifsram0_read_2;
		dy0_ifsram0_read_4 <= dy0_ifsram0_read_3;
		dy0_ifsram0_read_5 <= dy0_ifsram0_read_4;
		dy0_ifsram0_read_6 <= dy0_ifsram0_read_5;
		dy0_ifsram0_read_7 <= dy0_ifsram0_read_6;
	end	
end

assign en_ifr_over_toplength_b0 = ((ifr_row_number == 2) && (if_read_current_state == 1 || if_read_current_state == 6))? 1'd1 : 1'd0 ;  //(ifr_row_number == 2) 20250711

always @ (posedge clk)begin
	if(reset)begin
		en_ifr_over_toplength_tmp0 <= 0;
		en_ifr_over_toplength_tmp1 <= 0;
		en_ifr_over_toplength_tmp2 <= 0;		
		en_ifr_over_toplength_b1 <= 0;
		en_ifr_over_toplength_b2 <= 0;
		en_ifr_over_toplength_b3 <= 0;
		en_ifr_over_toplength_b4 <= 0;
		en_ifr_over_toplength_b5 <= 0;
		en_ifr_over_toplength_b6 <= 0;
		en_ifr_over_toplength_b7 <= 0;
	end
	else begin
		en_ifr_over_toplength_tmp0 <= en_ifr_over_toplength_b0	;
		en_ifr_over_toplength_tmp1 <= en_ifr_over_toplength_tmp0	;
		en_ifr_over_toplength_tmp2 <= en_ifr_over_toplength_tmp1	;
		en_ifr_over_toplength_b1 <= en_ifr_over_toplength_tmp2	;
		en_ifr_over_toplength_b2 <= en_ifr_over_toplength_b1;
		en_ifr_over_toplength_b3 <= en_ifr_over_toplength_b2;
		en_ifr_over_toplength_b4 <= en_ifr_over_toplength_b3;
		en_ifr_over_toplength_b5 <= en_ifr_over_toplength_b4;
		en_ifr_over_toplength_b6 <= en_ifr_over_toplength_b5;
		en_ifr_over_toplength_b7 <= en_ifr_over_toplength_b6;
	end	
end

assign 	   din_mux0 = (en_ifr_over_toplength_tmp2) ? 0 : dout_sram_if0b0	;
assign 	   din_mux1 = (en_ifr_over_toplength_b1) ? 0 : dout_sram_if1b0	;
assign 	   din_mux2 = (en_ifr_over_toplength_b2) ? 0 : dout_sram_if2b0	;
assign 	   din_mux3 = (en_ifr_over_toplength_b3) ? 0 : dout_sram_if3b0	;
assign 	   din_mux4 = (en_ifr_over_toplength_b4) ? 0 : dout_sram_if4b0	;
assign 	   din_mux5 = (en_ifr_over_toplength_b5) ? 0 : dout_sram_if5b0	;
assign 	   din_mux6 = (en_ifr_over_toplength_b6) ? 0 : dout_sram_if6b0	;
assign 	   din_mux7 = (en_ifr_over_toplength_b7) ? 0 : dout_sram_if7b0	;
	
// ============================================================================
// =========================    Control Signal   ==============================
// ============================================================================
	//----------------dout signal-----------------
	

	always@(*)begin
		if(if_valid_0s0)begin
			if(dy0_ifsram0_read_0)
				dout_sram_if = dout_sram_if0b0;
			else
				dout_sram_if = 0;
		end
		else
			dout_sram_if = 0;
	end

always @(posedge clk ) begin
	if(reset) dy_dout_valid_0 <= 0; 
	else begin
		if( ~cen_read ) dy_dout_valid_0 <= 1; else dy_dout_valid_0 <= 0; 
	end
end
always @(posedge clk ) begin
	if(reset) dy_dout_valid_1 <= 0; 
	else begin
		if( ~cen_read1 ) dy_dout_valid_1 <= 1; else dy_dout_valid_1 <= 0; 
	end
end
always @(posedge clk ) begin
	if(reset) dy_dout_valid_2 <= 0; 
	else begin
		if( ~cen_read2 ) dy_dout_valid_2 <= 1; else dy_dout_valid_2 <= 0; 
	end
end
always @(posedge clk ) begin
	if(reset) dy_dout_valid_3 <= 0; 
	else begin
		if( ~cen_read3 ) dy_dout_valid_3 <= 1; else dy_dout_valid_3 <= 0; 
	end
end
always @(posedge clk ) begin
	if(reset) dy_dout_valid_4 <= 0; 
	else begin
		if( ~cen_read4 ) dy_dout_valid_4 <= 1; else dy_dout_valid_4 <= 0; 
	end
end
always @(posedge clk ) begin
	if(reset) dy_dout_valid_5 <= 0; 
	else begin
		if( ~cen_read5 ) dy_dout_valid_5 <= 1; else dy_dout_valid_5 <= 0; 
	end
end
always @(posedge clk ) begin
	if(reset) dy_dout_valid_6 <= 0; 
	else begin
		if( ~cen_read6 ) dy_dout_valid_6 <= 1; else dy_dout_valid_6 <= 0; 
	end
end
always @(posedge clk ) begin
	if(reset) dy_dout_valid_7 <= 0; 
	else begin
		if( ~cen_read7 ) dy_dout_valid_7 <= 1; else dy_dout_valid_7 <= 0; 
	end
end


if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux0(.data_valid	(dy_dout_valid_0),.dinsr_0(din_mux0)	,.dout (dout_ifsr_0)	,.ifsram0_read	(dy0_ifsram0_read_0)	);
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux1(.data_valid	(dy_dout_valid_1),.dinsr_0(din_mux1)	,.dout (dout_ifsr_1)	,.ifsram0_read	(dy0_ifsram0_read_1)	);
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux2(.data_valid	(dy_dout_valid_2),.dinsr_0(din_mux2)	,.dout (dout_ifsr_2)	,.ifsram0_read	(dy0_ifsram0_read_2)	);
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux3(.data_valid	(dy_dout_valid_3),.dinsr_0(din_mux3)	,.dout (dout_ifsr_3)	,.ifsram0_read	(dy0_ifsram0_read_3)	);
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux4(.data_valid	(dy_dout_valid_4),.dinsr_0(din_mux4)	,.dout (dout_ifsr_4)	,.ifsram0_read	(dy0_ifsram0_read_4)	);
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux5(.data_valid	(dy_dout_valid_5),.dinsr_0(din_mux5)	,.dout (dout_ifsr_5)	,.ifsram0_read	(dy0_ifsram0_read_5)	);
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux6(.data_valid	(dy_dout_valid_6),.dinsr_0(din_mux6)	,.dout (dout_ifsr_6)	,.ifsram0_read	(dy0_ifsram0_read_6)	);
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux7(.data_valid	(dy_dout_valid_7),.dinsr_0(din_mux7)	,.dout (dout_ifsr_7)	,.ifsram0_read	(dy0_ifsram0_read_7)	);

// assign dout_ifsr_0	= (dy_dout_valid_0 ) ? (ifsram0_read)? dout_sram_if0b0 : (ifsram1_read)? dout_sram_if0b1 : 0	:0		:0		;
// assign dout_ifsr_1	= (dy_dout_valid_1 ) ? (ifsram0_read)? dout_sram_if1b0 : (ifsram1_read)? dout_sram_if1b1 : 0	:0		:0		;
// assign dout_ifsr_2	= (dy_dout_valid_2 ) ? (ifsram0_read)? dout_sram_if2b0 : (ifsram1_read)? dout_sram_if2b1 : 0	:0		:0		;
// assign dout_ifsr_3	= (dy_dout_valid_3 ) ? (ifsram0_read)? dout_sram_if3b0 : (ifsram1_read)? dout_sram_if3b1 : 0	:0		:0		;
// assign dout_ifsr_4	= (dy_dout_valid_4 ) ? (ifsram0_read)? dout_sram_if4b0 : (ifsram1_read)? dout_sram_if4b1 : 0	:0		:0		;
// assign dout_ifsr_5	= (dy_dout_valid_5 ) ? (ifsram0_read)? dout_sram_if5b0 : (ifsram1_read)? dout_sram_if5b1 : 0	:0		:0		;
// assign dout_ifsr_6	= (dy_dout_valid_6 ) ? (ifsram0_read)? dout_sram_if6b0 : (ifsram1_read)? dout_sram_if6b1 : 0	:0		:0		;
// assign dout_ifsr_7	= (dy_dout_valid_7 ) ? (ifsram0_read)? dout_sram_if7b0 : (ifsram1_read)? dout_sram_if7b1 : 0	:0		:0		;
//-----------------------------------------------------------------------------


	//------------stage signal-------------------
	// always @(*)begin 
	// 	if_final_0s0 = row_finish;
	// end
	reg dy_if_final_0s0_0;
	reg dy_if_final_0s0_1;

	always @( posedge clk ) begin
        if(reset)begin
            dy_if_final_0s0_0 <= 0;
			dy_if_final_0s0_1 <= 0;
            if_final_0s0 <= 0;
        end
        else begin
            dy_if_final_0s0_0 <= row_finish;
			dy_if_final_0s0_1 <= dy_if_final_0s0_0;
            if_final_0s0 <= dy_if_final_0s0_1;
        end   
    end
	// reg [5:0]final_number;
	// always @(posedge clk)begin
	// 	if(reset)
	// 		final_number <= 0;
	// 	else if(!if_valid_0s0)
	// 		final_number <= 0;
	// 	else if(if_final_0s0)
	// 		final_number <= final_number + 1;
	// 	else
	// 		final_number <= final_number;
	// end

	always @(posedge clk)begin
		if(reset)
			if_valid_0s0 <= 0;
		// else if(if_final_0s0 && final_number == rcfg_ift_total_window - 1)
		// 	if_valid_0s0 <= 0;
		else if(~cen_read)
			if_valid_0s0 <= 1;
		else
			if_valid_0s0 <= 0;
	end
/*
	always @(posedge clk)begin
		if_valid_0s1 <= if_valid_0s0;
		if_valid_0s2 <= if_valid_0s1;
		if_valid_0s3 <= if_valid_0s2;
		if_valid_0s4 <= if_valid_0s3;
		if_valid_0s5 <= if_valid_0s4;
		if_valid_0s6 <= if_valid_0s5;
		if_valid_0s7 <= if_valid_0s6;

		if_final_0s1 <= if_final_0s0;
		if_final_0s2 <= if_final_0s1;
		if_final_0s3 <= if_final_0s2;
		if_final_0s4 <= if_final_0s3;
		if_final_0s5 <= if_final_0s4;
		if_final_0s6 <= if_final_0s5;
		if_final_0s7 <= if_final_0s6;
	end
*/
	always @(posedge clk)begin
		if(reset) begin
			if_valid_0s1 <= 0;
			if_valid_0s2 <= 0;
			if_valid_0s3 <= 0;
			if_valid_0s4 <= 0;
			if_valid_0s5 <= 0;
			if_valid_0s6 <= 0;
			if_valid_0s7 <= 0;

			if_final_0s1 <= 0;
			if_final_0s2 <= 0;
			if_final_0s3 <= 0;
			if_final_0s4 <= 0;
			if_final_0s5 <= 0;
			if_final_0s6 <= 0;
			if_final_0s7 <= 0;
		end
		else begin
			if_valid_0s1 <= if_valid_0s0;
			if_valid_0s2 <= if_valid_0s1;
			if_valid_0s3 <= if_valid_0s2;
			if_valid_0s4 <= if_valid_0s3;
			if_valid_0s5 <= if_valid_0s4;
			if_valid_0s6 <= if_valid_0s5;
			if_valid_0s7 <= if_valid_0s6;

			if_final_0s1 <= if_final_0s0;
			if_final_0s2 <= if_final_0s1;
			if_final_0s3 <= if_final_0s2;
			if_final_0s4 <= if_final_0s3;
			if_final_0s5 <= if_final_0s4;
			if_final_0s6 <= if_final_0s5;
			if_final_0s7 <= if_final_0s6;
		end
	end

	assign ifr_valid_0 = if_valid_0s0 ;
	assign ifr_valid_1 = if_valid_0s1 ;
	assign ifr_valid_2 = if_valid_0s2 ;
	assign ifr_valid_3 = if_valid_0s3 ;
	assign ifr_valid_4 = if_valid_0s4 ;
	assign ifr_valid_5 = if_valid_0s5 ;
	assign ifr_valid_6 = if_valid_0s6 ;
	assign ifr_valid_7 = if_valid_0s7 ;

	assign ifr_final_0 = if_final_0s0 ;
	assign ifr_final_1 = if_final_0s1 ;
	assign ifr_final_2 = if_final_0s2 ;
	assign ifr_final_3 = if_final_0s3 ;
	assign ifr_final_4 = if_final_0s4 ;
	assign ifr_final_5 = if_final_0s5 ;
	assign ifr_final_6 = if_final_0s6 ;
	assign ifr_final_7 = if_final_0s7 ;
	//------------sram signal control-----------------------
	always @(posedge clk)begin
		addr_read_ifsram1 <= addr_read_ifsram;
		addr_read_ifsram2 <= addr_read_ifsram1;
		addr_read_ifsram3 <= addr_read_ifsram2;
		addr_read_ifsram4 <= addr_read_ifsram3;
		addr_read_ifsram5 <= addr_read_ifsram4;
		addr_read_ifsram6 <= addr_read_ifsram5;
		addr_read_ifsram7 <= addr_read_ifsram6;

		cen_read1 <= cen_read;
		cen_read2 <= cen_read1;
		cen_read3 <= cen_read2;
		cen_read4 <= cen_read3;
		cen_read5 <= cen_read4;
		cen_read6 <= cen_read5;
		cen_read7 <= cen_read6;

		// ifsram1b0_write <= ifsram0_write;
		// ifsram2b0_write <= ifsram1b0_write;
		// ifsram3b0_write <= ifsram2b0_write;
		// ifsram4b0_write <= ifsram3b0_write;
		// ifsram5b0_write <= ifsram4b0_write;
		// ifsram6b0_write <= ifsram5b0_write;
		// ifsram7b0_write <= ifsram6b0_write;

		// ifsram1b1_write <= ifsram1_write;
		// ifsram2b1_write <= ifsram1b1_write;
		// ifsram3b1_write <= ifsram2b1_write;
		// ifsram4b1_write <= ifsram3b1_write;
		// ifsram5b1_write <= ifsram4b1_write;
		// ifsram6b1_write <= ifsram5b1_write;
		// ifsram7b1_write <= ifsram6b1_write;
		
		ifsram1b0_read <= if_read_busy;
		ifsram2b0_read <= ifsram1b0_read;
		ifsram3b0_read <= ifsram2b0_read;
		ifsram4b0_read <= ifsram3b0_read;
		ifsram5b0_read <= ifsram4b0_read;
		ifsram6b0_read <= ifsram5b0_read;
		ifsram7b0_read <= ifsram6b0_read;

	end
	always @(*)begin
		ifsram1b0_write = if_write_busy;
		ifsram2b0_write = ifsram1b0_write;
		ifsram3b0_write = ifsram2b0_write;
		ifsram4b0_write = ifsram3b0_write;
		ifsram5b0_write = ifsram4b0_write;
		ifsram6b0_write = ifsram5b0_write;
		ifsram7b0_write = ifsram6b0_write;

	end


// ============================================================================
// =====================    SRAM signal assignment   ==========================
// ============================================================================
//--------sram 0--------
	assign cena_if0b0			= (if_pad_busy)?	if_pad_pdb0_cen		:	(if_write_busy) ? cen_write_ifsram_0  : 1     ;	// else condition is for read signal
	assign cenb_if0b0			= (if_pad_busy)?	if_pad_pdb0_cen		:	(if_read_busy) ? cen_read  : 1     ;	// else condition is for read signal
	assign wen_if0b0			= (if_pad_busy)?	if_pad_pdb0_wen		:	(if_write_busy) ? wen_write_ifsram_0  :	1	                				  	    ;	// else condition is for read signal
	assign addra_sram_if0b0		= (if_pad_busy)?	if_pad_pdb0_addr	:	(if_write_busy) ? addr_write_ifsram_0 : 0 ;	
	assign addrb_sram_if0b0		= (if_pad_busy)?	if_pad_pdb0_addr	:	(if_read_busy) ? addr_read_ifsram : 0 ;
	assign din_sram_if0b0		= (if_write_busy) ? data_write_ifsram_0 :	64'd0	                                    ;
                
	
	//--------sram 1--------
	assign cena_if1b0			= (if_pad_busy)?	if_pad_pdb1_cen		:	(ifsram1b0_write) ? cen_write_ifsram_1  : 1     ;	// else condition is for read signal 
	assign cenb_if1b0			= (if_pad_busy)?	if_pad_pdb1_cen		:	(ifsram1b0_read) ? cen_read1  : 1     ;	// else condition is for read signal 
	assign wen_if1b0			= (if_pad_busy)?	if_pad_pdb1_wen		:	(ifsram1b0_write) ? wen_write_ifsram_1  :	1	                				  	    ;	// else condition is for read signal 
	assign addra_sram_if1b0		= (if_pad_busy)?	if_pad_pdb1_addr	:	(ifsram1b0_write) ? addr_write_ifsram_1 : 0 ;	// else condition is for read signal 
	assign addrb_sram_if1b0		= (if_pad_busy)?	if_pad_pdb1_addr	:	(ifsram1b0_read) ? addr_read_ifsram1	: 0 ;	// else condition is for read signal 
	assign din_sram_if1b0		= (ifsram1b0_write) ? data_write_ifsram_1 :	0	                                    ; 

	//--------sram 2--------
	assign cena_if2b0			= (ifsram2b0_write) ? cen_write_ifsram_2  :	 1     ;	// else condition is for read signal
	assign cenb_if2b0			= (ifsram2b0_read) ? cen_read2  : 1     ;	// else condition is for read signal 
	assign wen_if2b0			= (ifsram2b0_write) ? wen_write_ifsram_2  :	1	                				  	    ;	// else condition is for read signal 
	assign addra_sram_if2b0		= (ifsram2b0_write) ? addr_write_ifsram_2 :	0 ;	// else condition is for read signal
	assign addrb_sram_if2b0		= (ifsram2b0_read) ? addr_read_ifsram2	  : 0 ;	// else condition is for read signal 	
	assign din_sram_if2b0		= (ifsram2b0_write) ? data_write_ifsram_2 :	0	                                    ; 
                        

	//--------sram 3--------
	assign cena_if3b0			= (ifsram3b0_write) ? cen_write_ifsram_3  :	 1     ;	// else condition is for read signal
	assign cenb_if3b0			= (ifsram3b0_read) ? cen_read3  : 1     ;	// else condition is for read signal 	
	assign wen_if3b0			= (ifsram3b0_write) ? wen_write_ifsram_3  :	1	                				  	    ;	// else condition is for read signal 
	assign addra_sram_if3b0		= (ifsram3b0_write) ? addr_write_ifsram_3 : 0 ;	// else condition is for read signal 
	assign addrb_sram_if3b0		= (ifsram3b0_read) ? addr_read_ifsram3	  : 0 ;	// else condition is for read signal 
	assign din_sram_if3b0		= (ifsram3b0_write) ? data_write_ifsram_3 :	0	                                    ; 

	//--------sram 4--------
	assign cena_if4b0			= (ifsram4b0_write) ? cen_write_ifsram_4  :	 1     ;	// else condition is for read signal 
	assign cenb_if4b0			= (ifsram4b0_read) ? cen_read4  : 1     ;	// else condition is for read signal 
	assign wen_if4b0			= (ifsram4b0_write) ? wen_write_ifsram_4  :	1	                				  	    ;	// else condition is for read signal 
	assign addra_sram_if4b0		= (ifsram4b0_write) ? addr_write_ifsram_4 : 0 ;	// else condition is for read signal
	assign addrb_sram_if4b0		= (ifsram4b0_read) ? addr_read_ifsram4    : 0 ;	// else condition is for read signal 	
	assign din_sram_if4b0		= (ifsram4b0_write) ? data_write_ifsram_4 :	0	                                    ; 

	//--------sram 5--------
	assign cena_if5b0			= (ifsram5b0_write) ? cen_write_ifsram_5  :	 1     ;	// else condition is for read signal 
	assign cenb_if5b0			= (ifsram5b0_read) ? cen_read5  : 1     ;	// else condition is for read signal 
	assign wen_if5b0			= (ifsram5b0_write) ? wen_write_ifsram_5  :	1	                				  	    ;	// else condition is for read signal 
	assign addra_sram_if5b0		= (ifsram5b0_write) ? addr_write_ifsram_5 : 0 ;	// else condition is for read signal 
	assign addrb_sram_if5b0		= (ifsram5b0_read) ? addr_read_ifsram5	  : 0 ;	// else condition is for read signal 
	assign din_sram_if5b0		= (ifsram5b0_write) ? data_write_ifsram_5 :	0	                                    ; 
                                 

	//--------sram 6--------
	assign cena_if6b0			= (if_pad_busy)?	if_pad_pdb6_cen		:	(ifsram6b0_write) ? cen_write_ifsram_6  : 1     ;	// else condition is for read signal 
	assign cenb_if6b0			= (if_pad_busy)?	if_pad_pdb6_cen		:	(ifsram6b0_read) ? cen_read6  : 1     ;	// else condition is for read signal 
	assign wen_if6b0			= (if_pad_busy)?	if_pad_pdb6_wen		:	(ifsram6b0_write) ? wen_write_ifsram_6  :	1	                				  	    ;	// else condition is for read signal 
	assign addra_sram_if6b0		= (if_pad_busy)?	if_pad_pdb6_addr	:	(ifsram6b0_write) ? addr_write_ifsram_6 :  0 ;	// else condition is for read signal 
	assign addrb_sram_if6b0		= (if_pad_busy)?	if_pad_pdb6_addr	:   (ifsram6b0_read) ? addr_read_ifsram6	:  0 ;	// else condition is for read signal 
	assign din_sram_if6b0		= (ifsram6b0_write) ? data_write_ifsram_6 :	0	                                    ; 
         

	//--------sram 7--------
	assign cena_if7b0			= (if_pad_busy)?	if_pad_pdb7_cen		:	(ifsram7b0_write) ? cen_write_ifsram_7  : 1     ;	// else condition is for read signal 
	assign cenb_if7b0			= (if_pad_busy)?	if_pad_pdb7_cen		:	(ifsram7b0_read) ? cen_read7  : 1     ;	// else condition is for read signal 
	assign wen_if7b0			= (if_pad_busy)?	if_pad_pdb7_wen		:	(ifsram7b0_write) ? wen_write_ifsram_7  :	1	                				  	    ;	// else condition is for read signal 
	assign addra_sram_if7b0		= (if_pad_busy)?	if_pad_pdb7_addr	:	(ifsram7b0_write) ? addr_write_ifsram_7 : 0 ;	// else condition is for read signal 
	assign addrb_sram_if7b0		= (if_pad_busy)?	if_pad_pdb7_addr	:	(ifsram7b0_read) ? addr_read_ifsram7	: 0 ;	// else condition is for read signal 
	assign din_sram_if7b0		= (ifsram7b0_write) ? data_write_ifsram_7 :	0	                                    ; 





// ============================================================================
// =========================    Instance Module   =============================
// ============================================================================
//----    standard CBDK type    -----
	// IF_SRAM if0b0 (
	// 	.Q		(	dout_sram_if0b0		),	// output data
	// 	.CLK	(	clk					),	//
	// 	.CEN	(	cen_if0b0			),	// Chip Enable (active low)
	// 	.WEN	(	wen_if0b0			),	// Write Enable (active low)
	// 	.A		(	addr_sram_if0b0		),	// Addresses (A[0] = LSB)
	// 	.D		(	din_sram_if0b0		),	// Data Inputs (D[0] = LSB)
	// 	.EMA	(	3'b0				)	// Extra Margin Adjustment (EMA[0] = LSB)
	// );
	// IF_SRAM if0b1 (
	// 	.Q		(	dout_sram_if0b1		),	// output data
	// 	.CLK	(	clk					),	//
	// 	.CEN	(	cen_if0b1			),	// Chip Enable (active low)
	// 	.WEN	(	wen_if0b1			),	// Write Enable (active low)
	// 	.A		(	addr_sram_if0b1		),	// Addresses (A[0] = LSB)
	// 	.D		(	din_sram_if0b1		),	// Data Inputs (D[0] = LSB)
	// 	.EMA	(	3'b0				)	// Extra Margin Adjustment (EMA[0] = LSB)
	// );
//-----------------------------------------------------------------------------


//==============================================================================
//========    SRAM instance and assignment    ========
//==============================================================================
`ifdef FPGA_SRAM_SETTING	
	assign atla_cen_if0b0 = ~cena_if0b0 ;
	assign atla_cen_if1b0 = ~cena_if1b0 ;
	assign atla_cen_if2b0 = ~cena_if2b0 ;
	assign atla_cen_if3b0 = ~cena_if3b0 ;
	assign atla_cen_if4b0 = ~cena_if4b0 ;
	assign atla_cen_if5b0 = ~cena_if5b0 ;
	assign atla_cen_if6b0 = ~cena_if6b0 ;
	assign atla_cen_if7b0 = ~cena_if7b0 ;
	
	assign atlb_cen_if0b0 = ~cenb_if0b0 ;
	assign atlb_cen_if1b0 = ~cenb_if1b0 ;
	assign atlb_cen_if2b0 = ~cenb_if2b0 ;
	assign atlb_cen_if3b0 = ~cenb_if3b0 ;
	assign atlb_cen_if4b0 = ~cenb_if4b0 ;
	assign atlb_cen_if5b0 = ~cenb_if5b0 ;
	assign atlb_cen_if6b0 = ~cenb_if6b0 ;
	assign atlb_cen_if7b0 = ~cenb_if7b0 ;

	assign atl_wen_if0b0 = ~wen_if0b0 ;
	assign atl_wen_if1b0 = ~wen_if1b0 ;
	assign atl_wen_if2b0 = ~wen_if2b0 ;
	assign atl_wen_if3b0 = ~wen_if3b0 ;
	assign atl_wen_if4b0 = ~wen_if4b0 ;
	assign atl_wen_if5b0 = ~wen_if5b0 ;
	assign atl_wen_if6b0 = ~wen_if6b0 ;
	assign atl_wen_if7b0 = ~wen_if7b0 ;
`else 
	assign atla_cen_if0b0 = cena_if0b0 ;
	assign atla_cen_if1b0 = cena_if1b0 ;
	assign atla_cen_if2b0 = cena_if2b0 ;
	assign atla_cen_if3b0 = cena_if3b0 ;
	assign atla_cen_if4b0 = cena_if4b0 ;
	assign atla_cen_if5b0 = cena_if5b0 ;
	assign atla_cen_if6b0 = cena_if6b0 ;
	assign atla_cen_if7b0 = cena_if7b0 ;
	
	assign atlb_cen_if0b0 = cenb_if0b0 ;
	assign atlb_cen_if1b0 = cenb_if1b0 ;
	assign atlb_cen_if2b0 = cenb_if2b0 ;
	assign atlb_cen_if3b0 = cenb_if3b0 ;
	assign atlb_cen_if4b0 = cenb_if4b0 ;
	assign atlb_cen_if5b0 = cenb_if5b0 ;
	assign atlb_cen_if6b0 = cenb_if6b0 ;
	assign atlb_cen_if7b0 = cenb_if7b0 ;

	assign atl_wen_if0b0 = wen_if0b0 ;
	assign atl_wen_if1b0 = wen_if1b0 ;
	assign atl_wen_if2b0 = wen_if2b0 ;
	assign atl_wen_if3b0 = wen_if3b0 ;
	assign atl_wen_if4b0 = wen_if4b0 ;
	assign atl_wen_if5b0 = wen_if5b0 ;
	assign atl_wen_if6b0 = wen_if6b0 ;
	assign atl_wen_if7b0 = wen_if7b0 ;
`endif 

// IF_SRAM if9b0 (.CLK( clk ), .CEN( atl_cen_if0b0 ), .WEN( atl_wen_if0b0 ), .A( addr_sram_if0b0 ), .D( din_sram_if0b0 ), .EMA( 3'b0 ));

`ifdef FPGA_SRAM_SETTING
	//----generated by ifsm_inst.py------ 
	//----instance FPGA SRAM start------ 
	BRAM_IF		if0b0( .clka( clk ) , .clkb( clk), .ena( atla_cen_if0b0 ), .enb( atlb_cen_if0b0 ), .wea( atl_wen_if0b0 ), .addra( addra_sram_if0b0 ), .addrb( addrb_sram_if0b0 ), .dina( din_sram_if0b0 ), .doutb( dout_sram_if0b0 ));
	BRAM_IF		if1b0( .clka( clk ) , .clkb( clk), .ena( atla_cen_if1b0 ), .enb( atlb_cen_if1b0 ), .wea( atl_wen_if1b0 ), .addra( addra_sram_if1b0 ), .addrb( addrb_sram_if1b0 ), .dina( din_sram_if1b0 ), .doutb( dout_sram_if1b0 ));
	BRAM_IF		if2b0( .clka( clk ) , .clkb( clk), .ena( atla_cen_if2b0 ), .enb( atlb_cen_if2b0 ), .wea( atl_wen_if2b0 ), .addra( addra_sram_if2b0 ), .addrb( addrb_sram_if2b0 ), .dina( din_sram_if2b0 ), .doutb( dout_sram_if2b0 ));
	BRAM_IF		if3b0( .clka( clk ) , .clkb( clk), .ena( atla_cen_if3b0 ), .enb( atlb_cen_if3b0 ), .wea( atl_wen_if3b0 ), .addra( addra_sram_if3b0 ), .addrb( addrb_sram_if3b0 ), .dina( din_sram_if3b0 ), .doutb( dout_sram_if3b0 ));
	BRAM_IF		if4b0( .clka( clk ) , .clkb( clk), .ena( atla_cen_if4b0 ), .enb( atlb_cen_if4b0 ), .wea( atl_wen_if4b0 ), .addra( addra_sram_if4b0 ), .addrb( addrb_sram_if4b0 ), .dina( din_sram_if4b0 ), .doutb( dout_sram_if4b0 ));
	BRAM_IF		if5b0( .clka( clk ) , .clkb( clk), .ena( atla_cen_if5b0 ), .enb( atlb_cen_if5b0 ), .wea( atl_wen_if5b0 ), .addra( addra_sram_if5b0 ), .addrb( addrb_sram_if5b0 ), .dina( din_sram_if5b0 ), .doutb( dout_sram_if5b0 ));
	BRAM_IF		if6b0( .clka( clk ) , .clkb( clk), .ena( atla_cen_if6b0 ), .enb( atlb_cen_if6b0 ), .wea( atl_wen_if6b0 ), .addra( addra_sram_if6b0 ), .addrb( addrb_sram_if6b0 ), .dina( din_sram_if6b0 ), .doutb( dout_sram_if6b0 ));
	BRAM_IF		if7b0( .clka( clk ) , .clkb( clk), .ena( atla_cen_if7b0 ), .enb( atlb_cen_if7b0 ), .wea( atl_wen_if7b0 ), .addra( addra_sram_if7b0 ), .addrb( addrb_sram_if7b0 ), .dina( din_sram_if7b0 ), .doutb( dout_sram_if7b0 ));
	//----instance FPGA SRAM end------ 
`else 
	/*
	//----instance CBDK SRAM start------ 
	IF_SRAM if0b0 (.Q( dout_sram_if0b0 ), .CLK( clk ), .CEN( atl_cen_if0b0 ), .WEN( atl_wen_if0b0 ), .A( addr_sram_if0b0 ), .D( din_sram_if0b0 ), .EMA( 3'b0 ));
	IF_SRAM if0b1 (.Q( dout_sram_if0b1 ), .CLK( clk ), .CEN( atl_cen_if0b1 ), .WEN( atl_wen_if0b1 ), .A( addr_sram_if0b1 ), .D( din_sram_if0b1 ), .EMA( 3'b0 ));
	IF_SRAM if1b0 (.Q( dout_sram_if1b0 ), .CLK( clk ), .CEN( atl_cen_if1b0 ), .WEN( atl_wen_if1b0 ), .A( addr_sram_if1b0 ), .D( din_sram_if1b0 ), .EMA( 3'b0 ));
	IF_SRAM if1b1 (.Q( dout_sram_if1b1 ), .CLK( clk ), .CEN( atl_cen_if1b1 ), .WEN( atl_wen_if1b1 ), .A( addr_sram_if1b1 ), .D( din_sram_if1b1 ), .EMA( 3'b0 ));
	IF_SRAM if2b0 (.Q( dout_sram_if2b0 ), .CLK( clk ), .CEN( atl_cen_if2b0 ), .WEN( atl_wen_if2b0 ), .A( addr_sram_if2b0 ), .D( din_sram_if2b0 ), .EMA( 3'b0 ));
	IF_SRAM if2b1 (.Q( dout_sram_if2b1 ), .CLK( clk ), .CEN( atl_cen_if2b1 ), .WEN( atl_wen_if2b1 ), .A( addr_sram_if2b1 ), .D( din_sram_if2b1 ), .EMA( 3'b0 ));
	IF_SRAM if3b0 (.Q( dout_sram_if3b0 ), .CLK( clk ), .CEN( atl_cen_if3b0 ), .WEN( atl_wen_if3b0 ), .A( addr_sram_if3b0 ), .D( din_sram_if3b0 ), .EMA( 3'b0 ));
	IF_SRAM if3b1 (.Q( dout_sram_if3b1 ), .CLK( clk ), .CEN( atl_cen_if3b1 ), .WEN( atl_wen_if3b1 ), .A( addr_sram_if3b1 ), .D( din_sram_if3b1 ), .EMA( 3'b0 ));
	IF_SRAM if4b0 (.Q( dout_sram_if4b0 ), .CLK( clk ), .CEN( atl_cen_if4b0 ), .WEN( atl_wen_if4b0 ), .A( addr_sram_if4b0 ), .D( din_sram_if4b0 ), .EMA( 3'b0 ));
	IF_SRAM if4b1 (.Q( dout_sram_if4b1 ), .CLK( clk ), .CEN( atl_cen_if4b1 ), .WEN( atl_wen_if4b1 ), .A( addr_sram_if4b1 ), .D( din_sram_if4b1 ), .EMA( 3'b0 ));
	IF_SRAM if5b0 (.Q( dout_sram_if5b0 ), .CLK( clk ), .CEN( atl_cen_if5b0 ), .WEN( atl_wen_if5b0 ), .A( addr_sram_if5b0 ), .D( din_sram_if5b0 ), .EMA( 3'b0 ));
	IF_SRAM if5b1 (.Q( dout_sram_if5b1 ), .CLK( clk ), .CEN( atl_cen_if5b1 ), .WEN( atl_wen_if5b1 ), .A( addr_sram_if5b1 ), .D( din_sram_if5b1 ), .EMA( 3'b0 ));
	IF_SRAM if6b0 (.Q( dout_sram_if6b0 ), .CLK( clk ), .CEN( atl_cen_if6b0 ), .WEN( atl_wen_if6b0 ), .A( addr_sram_if6b0 ), .D( din_sram_if6b0 ), .EMA( 3'b0 ));
	IF_SRAM if6b1 (.Q( dout_sram_if6b1 ), .CLK( clk ), .CEN( atl_cen_if6b1 ), .WEN( atl_wen_if6b1 ), .A( addr_sram_if6b1 ), .D( din_sram_if6b1 ), .EMA( 3'b0 ));
	IF_SRAM if7b0 (.Q( dout_sram_if7b0 ), .CLK( clk ), .CEN( atl_cen_if7b0 ), .WEN( atl_wen_if7b0 ), .A( addr_sram_if7b0 ), .D( din_sram_if7b0 ), .EMA( 3'b0 ));
	IF_SRAM if7b1 (.Q( dout_sram_if7b1 ), .CLK( clk ), .CEN( atl_cen_if7b1 ), .WEN( atl_wen_if7b1 ), .A( addr_sram_if7b1 ), .D( din_sram_if7b1 ), .EMA( 3'b0 ));
	//----instance CBDK SRAM end------ 
	*/
	IF_SRAM  if0b0(.QB	(	dout_sram_if0b0	),	.CLKA(	clk	),	.CENA	(	atla_cen_if0b0	),	.WENA	(	atl_wen_if0b0	),	.AA		(	addra_sram_if0b0	),	.DA		(	din_sram_if0b0	),	.CLKB	(	clk	),	.CENB	(	atlb_cen_if0b0	),	.WENB	(	1'd1	),	.AB		(	addrb_sram_if0b0	),	.DB		(	'd0	),	.EMAA	(	3'd0	),	.EMAB	(	3'd0	));
	IF_SRAM  if1b0(.QB	(	dout_sram_if1b0	),	.CLKA(	clk	),	.CENA	(	atla_cen_if1b0	),	.WENA	(	atl_wen_if1b0	),	.AA		(	addra_sram_if1b0	),	.DA		(	din_sram_if1b0	),	.CLKB	(	clk	),	.CENB	(	atlb_cen_if1b0	),	.WENB	(	1'd1	),	.AB		(	addrb_sram_if1b0	),	.DB		(	'd0	),	.EMAA	(	3'd0	),	.EMAB	(	3'd0	));
	IF_SRAM  if2b0(.QB	(	dout_sram_if2b0	),	.CLKA(	clk	),	.CENA	(	atla_cen_if2b0	),	.WENA	(	atl_wen_if2b0	),	.AA		(	addra_sram_if2b0	),	.DA		(	din_sram_if2b0	),	.CLKB	(	clk	),	.CENB	(	atlb_cen_if2b0	),	.WENB	(	1'd1	),	.AB		(	addrb_sram_if2b0	),	.DB		(	'd0	),	.EMAA	(	3'd0	),	.EMAB	(	3'd0	));
	IF_SRAM  if3b0(.QB	(	dout_sram_if3b0	),	.CLKA(	clk	),	.CENA	(	atla_cen_if3b0	),	.WENA	(	atl_wen_if3b0	),	.AA		(	addra_sram_if3b0	),	.DA		(	din_sram_if3b0	),	.CLKB	(	clk	),	.CENB	(	atlb_cen_if3b0	),	.WENB	(	1'd1	),	.AB		(	addrb_sram_if3b0	),	.DB		(	'd0	),	.EMAA	(	3'd0	),	.EMAB	(	3'd0	));
	IF_SRAM  if4b0(.QB	(	dout_sram_if4b0	),	.CLKA(	clk	),	.CENA	(	atla_cen_if4b0	),	.WENA	(	atl_wen_if4b0	),	.AA		(	addra_sram_if4b0	),	.DA		(	din_sram_if4b0	),	.CLKB	(	clk	),	.CENB	(	atlb_cen_if4b0	),	.WENB	(	1'd1	),	.AB		(	addrb_sram_if4b0	),	.DB		(	'd0	),	.EMAA	(	3'd0	),	.EMAB	(	3'd0	));
	IF_SRAM  if5b0(.QB	(	dout_sram_if5b0	),	.CLKA(	clk	),	.CENA	(	atla_cen_if5b0	),	.WENA	(	atl_wen_if5b0	),	.AA		(	addra_sram_if5b0	),	.DA		(	din_sram_if5b0	),	.CLKB	(	clk	),	.CENB	(	atlb_cen_if5b0	),	.WENB	(	1'd1	),	.AB		(	addrb_sram_if5b0	),	.DB		(	'd0	),	.EMAA	(	3'd0	),	.EMAB	(	3'd0	));
	IF_SRAM  if6b0(.QB	(	dout_sram_if6b0	),	.CLKA(	clk	),	.CENA	(	atla_cen_if6b0	),	.WENA	(	atl_wen_if6b0	),	.AA		(	addra_sram_if6b0	),	.DA		(	din_sram_if6b0	),	.CLKB	(	clk	),	.CENB	(	atlb_cen_if6b0	),	.WENB	(	1'd1	),	.AB		(	addrb_sram_if6b0	),	.DB		(	'd0	),	.EMAA	(	3'd0	),	.EMAB	(	3'd0	));
	IF_SRAM  if7b0(.QB	(	dout_sram_if7b0	),	.CLKA(	clk	),	.CENA	(	atla_cen_if7b0	),	.WENA	(	atl_wen_if7b0	),	.AA		(	addra_sram_if7b0	),	.DA		(	din_sram_if7b0	),	.CLKB	(	clk	),	.CENB	(	atlb_cen_if7b0	),	.WENB	(	1'd1	),	.AB		(	addrb_sram_if7b0	),	.DB		(	'd0	),	.EMAA	(	3'd0	),	.EMAB	(	3'd0	));

`endif 



// //-------------------------if sram0------------------------
// 	IF_SRAM if0b0 (
// 		.Q		(	dout_sram_if0b0		),	// output data
// 		.CLK	(	clk					),	//
// 		.CEN	(	cen_if0b0			),	// Chip Enable (active low)
// 		.WEN	(	wen_if0b0			),	// Write Enable (active low)
// 		.A		(	addr_sram_if0b0		),	// Addresses (A[0] = LSB)
// 		.D		(	din_sram_if0b0		),	// Data Inputs (D[0] = LSB)
// 		.EMA	(	3'b0				)	// Extra Margin Adjustment (EMA[0] = LSB)
// 	);
// 	IF_SRAM if0b1 (
// 		.Q		(	dout_sram_if0b1		),	// output data
// 		.CLK	(	clk					),	//
// 		.CEN	(	cen_if0b1			),	// Chip Enable (active low)
// 		.WEN	(	wen_if0b1			),	// Write Enable (active low)
// 		.A		(	addr_sram_if0b1		),	// Addresses (A[0] = LSB)
// 		.D		(	din_sram_if0b1		),	// Data Inputs (D[0] = LSB)
// 		.EMA	(	3'b0				)	// Extra Margin Adjustment (EMA[0] = LSB)
// 	);
// 	//-------------------------if sram1------------------------
// 	IF_SRAM if1b0 (
// 		.Q		(	dout_sram_if1b0		),	// output data
// 		.CLK	(	clk					),	//
// 		.CEN	(	cen_if1b0			),	// Chip Enable (active low)
// 		.WEN	(	wen_if1b0			),	// Write Enable (active low)
// 		.A		(	addr_sram_if1b0		),	// Addresses (A[0] = LSB)
// 		.D		(	din_sram_if1b0		),	// Data Inputs (D[0] = LSB)
// 		.EMA	(	3'b0				)	// Extra Margin Adjustment (EMA[0] = LSB)
// 	);
// 	IF_SRAM if1b1 (
// 		.Q		(	dout_sram_if1b1		),	// output data
// 		.CLK	(	clk					),	//
// 		.CEN	(	cen_if1b1			),	// Chip Enable (active low)
// 		.WEN	(	wen_if1b1			),	// Write Enable (active low)
// 		.A		(	addr_sram_if1b1		),	// Addresses (A[0] = LSB)
// 		.D		(	din_sram_if1b1		),	// Data Inputs (D[0] = LSB)
// 		.EMA	(	3'b0				)	// Extra Margin Adjustment (EMA[0] = LSB)
// 	);
// 	//-------------------------if sram2------------------------
// 	IF_SRAM if2b0 (
// 		.Q		(	dout_sram_if2b0		),	// output data
// 		.CLK	(	clk					),	//
// 		.CEN	(	cen_if2b0			),	// Chip Enable (active low)
// 		.WEN	(	wen_if2b0			),	// Write Enable (active low)
// 		.A		(	addr_sram_if2b0		),	// Addresses (A[0] = LSB)
// 		.D		(	din_sram_if2b0		),	// Data Inputs (D[0] = LSB)
// 		.EMA	(	3'b0				)	// Extra Margin Adjustment (EMA[0] = LSB)
// 	);
// 	IF_SRAM if2b1 (
// 		.Q		(	dout_sram_if2b1		),	// output data
// 		.CLK	(	clk					),	//
// 		.CEN	(	cen_if2b1			),	// Chip Enable (active low)
// 		.WEN	(	wen_if2b1			),	// Write Enable (active low)
// 		.A		(	addr_sram_if2b1		),	// Addresses (A[0] = LSB)
// 		.D		(	din_sram_if2b1		),	// Data Inputs (D[0] = LSB)
// 		.EMA	(	3'b0				)	// Extra Margin Adjustment (EMA[0] = LSB)
// 	);
// 	//-------------------------if sram3------------------------
// 	IF_SRAM if3b0 (
// 		.Q		(	dout_sram_if3b0		),	// output data
// 		.CLK	(	clk					),	//
// 		.CEN	(	cen_if3b0			),	// Chip Enable (active low)
// 		.WEN	(	wen_if3b0			),	// Write Enable (active low)
// 		.A		(	addr_sram_if3b0		),	// Addresses (A[0] = LSB)
// 		.D		(	din_sram_if3b0		),	// Data Inputs (D[0] = LSB)
// 		.EMA	(	3'b0				)	// Extra Margin Adjustment (EMA[0] = LSB)
// 	);
// 	IF_SRAM if3b1 (
// 		.Q		(	dout_sram_if3b1		),	// output data
// 		.CLK	(	clk					),	//
// 		.CEN	(	cen_if3b1			),	// Chip Enable (active low)
// 		.WEN	(	wen_if3b1			),	// Write Enable (active low)
// 		.A		(	addr_sram_if3b1		),	// Addresses (A[0] = LSB)
// 		.D		(	din_sram_if3b1		),	// Data Inputs (D[0] = LSB)
// 		.EMA	(	3'b0				)	// Extra Margin Adjustment (EMA[0] = LSB)
// 	);
// 	//-------------------------if sram4------------------------
// 	IF_SRAM if4b0 (
// 		.Q		(	dout_sram_if4b0		),	// output data
// 		.CLK	(	clk					),	//
// 		.CEN	(	cen_if4b0			),	// Chip Enable (active low)
// 		.WEN	(	wen_if4b0			),	// Write Enable (active low)
// 		.A		(	addr_sram_if4b0		),	// Addresses (A[0] = LSB)
// 		.D		(	din_sram_if4b0		),	// Data Inputs (D[0] = LSB)
// 		.EMA	(	3'b0				)	// Extra Margin Adjustment (EMA[0] = LSB)
// 	);
// 	IF_SRAM if4b1 (
// 		.Q		(	dout_sram_if4b1		),	// output data
// 		.CLK	(	clk					),	//
// 		.CEN	(	cen_if4b1			),	// Chip Enable (active low)
// 		.WEN	(	wen_if4b1			),	// Write Enable (active low)
// 		.A		(	addr_sram_if4b1		),	// Addresses (A[0] = LSB)
// 		.D		(	din_sram_if4b1		),	// Data Inputs (D[0] = LSB)
// 		.EMA	(	3'b0				)	// Extra Margin Adjustment (EMA[0] = LSB)
// 	);
// 	//-------------------------if sram5------------------------
// 	IF_SRAM if5b0 (
// 		.Q		(	dout_sram_if5b0		),	// output data
// 		.CLK	(	clk					),	//
// 		.CEN	(	cen_if5b0			),	// Chip Enable (active low)
// 		.WEN	(	wen_if5b0			),	// Write Enable (active low)
// 		.A		(	addr_sram_if5b0		),	// Addresses (A[0] = LSB)
// 		.D		(	din_sram_if5b0		),	// Data Inputs (D[0] = LSB)
// 		.EMA	(	3'b0				)	// Extra Margin Adjustment (EMA[0] = LSB)
// 	);
// 	IF_SRAM if5b1 (
// 		.Q		(	dout_sram_if5b1		),	// output data
// 		.CLK	(	clk					),	//
// 		.CEN	(	cen_if5b1			),	// Chip Enable (active low)
// 		.WEN	(	wen_if5b1			),	// Write Enable (active low)
// 		.A		(	addr_sram_if5b1		),	// Addresses (A[0] = LSB)
// 		.D		(	din_sram_if5b1		),	// Data Inputs (D[0] = LSB)
// 		.EMA	(	3'b0				)	// Extra Margin Adjustment (EMA[0] = LSB)
// 	);
// 	//-------------------------if sram6------------------------
// 	IF_SRAM if6b0 (
// 		.Q		(	dout_sram_if6b0		),	// output data
// 		.CLK	(	clk					),	//
// 		.CEN	(	cen_if6b0			),	// Chip Enable (active low)
// 		.WEN	(	wen_if6b0			),	// Write Enable (active low)
// 		.A		(	addr_sram_if6b0		),	// Addresses (A[0] = LSB)
// 		.D		(	din_sram_if6b0		),	// Data Inputs (D[0] = LSB)
// 		.EMA	(	3'b0				)	// Extra Margin Adjustment (EMA[0] = LSB)
// 	);
// 	IF_SRAM if6b1 (
// 		.Q		(	dout_sram_if6b1		),	// output data
// 		.CLK	(	clk					),	//
// 		.CEN	(	cen_if6b1			),	// Chip Enable (active low)
// 		.WEN	(	wen_if6b1			),	// Write Enable (active low)
// 		.A		(	addr_sram_if6b1		),	// Addresses (A[0] = LSB)
// 		.D		(	din_sram_if6b1		),	// Data Inputs (D[0] = LSB)
// 		.EMA	(	3'b0				)	// Extra Margin Adjustment (EMA[0] = LSB)
// 	);
// 	//-------------------------if sram7------------------------
// 	IF_SRAM if7b0 (
// 		.Q		(	dout_sram_if7b0		),	// output data
// 		.CLK	(	clk					),	//
// 		.CEN	(	cen_if7b0			),	// Chip Enable (active low)
// 		.WEN	(	wen_if7b0			),	// Write Enable (active low)
// 		.A		(	addr_sram_if7b0		),	// Addresses (A[0] = LSB)
// 		.D		(	din_sram_if7b0		),	// Data Inputs (D[0] = LSB)
// 		.EMA	(	3'b0				)	// Extra Margin Adjustment (EMA[0] = LSB)
// 	);
// 	IF_SRAM if7b1 (
// 		.Q		(	dout_sram_if7b1		),	// output data
// 		.CLK	(	clk					),	//
// 		.CEN	(	cen_if7b1			),	// Chip Enable (active low)
// 		.WEN	(	wen_if7b1			),	// Write Enable (active low)
// 		.A		(	addr_sram_if7b1		),	// Addresses (A[0] = LSB)
// 		.D		(	din_sram_if7b1		),	// Data Inputs (D[0] = LSB)
// 		.EMA	(	3'b0				)	// Extra Margin Adjustment (EMA[0] = LSB)
// 	);



//--------------------------------------------------
//------	if sram write module instance	--------
//--------------------------------------------------
ifsram_w  #(
	.TBITS ( 64 )
	,	.TBYTE ( 8  )
	,	.IFMAP_SRAM_ADDBITS ( IFMAP_SRAM_ADDBITS  )
	,	.IFMAP_SRAM_DATA_WIDTH ( 64  )
	,	.DATAIN_CNT_BITS ( DATAIN_CNT_BITS  )
	,	.IFWSTG0_CNTBITS ( IFWSTG0_CNTBITS  )
	,	.IFWSTG1_CNTBITS ( IFWSTG1_CNTBITS  )
)if_write00(
	.clk		(	clk	)
	,	.reset		(	reset	)

	,	.ifstore_data_din		(	if_write_data_din			)
	,	.ifstore_empty_n_din	(	if_write_empty_n_din		)
	,	.ifstore_read_dout		(	if_write_read_dout			)
	,	.if_read_last			(	if_read_last				)
	,	.rdwd_done				(	rdwd_done					)

	,	.if_write_done	(	if_write_done	)
	,	.if_write_busy 	(	if_write_busy	)
	,	.if_write_start	(	if_write_start	)
	,	.if_write_en	(	if_write_en		)

	,	.dout_wrb0_cen	(	cen_write_ifsram_0	)
	,	.dout_wrb1_cen	(	cen_write_ifsram_1	)
	,	.dout_wrb2_cen	(	cen_write_ifsram_2	)
	,	.dout_wrb3_cen	(	cen_write_ifsram_3	)
	,	.dout_wrb4_cen	(	cen_write_ifsram_4	)
	,	.dout_wrb5_cen	(	cen_write_ifsram_5	)
	,	.dout_wrb6_cen	(	cen_write_ifsram_6	)
	,	.dout_wrb7_cen	(	cen_write_ifsram_7	)

	,	.dout_wrb0_wen	(	wen_write_ifsram_0	)
	,	.dout_wrb1_wen	(	wen_write_ifsram_1	)
	,	.dout_wrb2_wen	(	wen_write_ifsram_2	)
	,	.dout_wrb3_wen	(	wen_write_ifsram_3	)
	,	.dout_wrb4_wen	(	wen_write_ifsram_4	)
	,	.dout_wrb5_wen	(	wen_write_ifsram_5	)
	,	.dout_wrb6_wen	(	wen_write_ifsram_6	)
	,	.dout_wrb7_wen	(	wen_write_ifsram_7	)

	,	.dout_wrb0_addr	(	addr_write_ifsram_0	)
	,	.dout_wrb1_addr	(	addr_write_ifsram_1	)
	,	.dout_wrb2_addr	(	addr_write_ifsram_2	)
	,	.dout_wrb3_addr	(	addr_write_ifsram_3	)
	,	.dout_wrb4_addr	(	addr_write_ifsram_4	)
	,	.dout_wrb5_addr	(	addr_write_ifsram_5	)
	,	.dout_wrb6_addr	(	addr_write_ifsram_6	)
	,	.dout_wrb7_addr	(	addr_write_ifsram_7	)

	,	.dout_wrb0_data	(	data_write_ifsram_0	)
	,	.dout_wrb1_data	(	data_write_ifsram_1	)
	,	.dout_wrb2_data	(	data_write_ifsram_2	)
	,	.dout_wrb3_data	(	data_write_ifsram_3	)
	,	.dout_wrb4_data	(	data_write_ifsram_4	)
	,	.dout_wrb5_data	(	data_write_ifsram_5	)
	,	.dout_wrb6_data	(	data_write_ifsram_6	)
	,	.dout_wrb7_data	(	data_write_ifsram_7	)

	//config input setting
	,	.cfg_atlchin			(	rcfg_atlchin			)
	,	.cfg_conv_switch		(	rcfg_conv_switch		)
	,	.cfg_mast_state			(	rcfg_mast_state			)
	// ,	.cfg_pdlf				(	rcfg_pdlf				)
	// ,	.cfg_pdrg				(	rcfg_pdrg				)
	// ,	.cfg_nor				(	rcfg_nor				)
	,	.cfg_stg0_nor_finum		(	rcfg_stg0_nor_finum		)
	,	.cfg_stg0_pdb0_finum	(	rcfg_stg0_pdb0_finum	)
	,	.cfg_stg0_pdb1_finum	(	rcfg_stg0_pdb1_finum	)
	,	.cfg_stg1_eb_col		(	rcfg_stg1_eb_col		)
	,	.cfg_dincnt_finum		(	rcfg_dincnt_finum		)
	,	.cfg_rowcnt_finum		(	rcfg_rowcnt_finum		)

);

//--------------------------------------------------
//------	if sram read module instance	--------
//--------------------------------------------------

ifsram_r #(
		.TBITS ( 64 )
	,	.TBYTE ( 8  )
	,	.IFMAP_SRAM_ADDBITS ( IFMAP_SRAM_ADDBITS  )
) if_read00 (
		.clk		       (clk)
	,	.reset		       (reset)

	,	.if_read_start     (if_read_start)
	,	.if_read_busy      (if_read_busy)
	,	.if_read_done      (if_read_done)

	,	.cen_reads_ifsram  (cen_read)
	,	.addr_read_ifsram  (addr_read_ifsram)
	,	.current_state     (if_read_current_state)
	// ,	.valid_0 ( ifr_valid_0 )	,	.final_0 ( ifr_final_0 )
	// ,	.valid_1 ( ifr_valid_1 )	,	.final_1 ( ifr_final_1 )
	// ,	.valid_2 ( ifr_valid_2 )	,	.final_2 ( ifr_final_2 )
	// ,	.valid_3 ( ifr_valid_3 )	,	.final_3 ( ifr_final_3 )
	// ,	.valid_4 ( ifr_valid_4 )	,	.final_4 ( ifr_final_4 )
	// ,	.valid_5 ( ifr_valid_5 )	,	.final_5 ( ifr_final_5 )
	// ,	.valid_6 ( ifr_valid_6 )	,	.final_6 ( ifr_final_6 )
	// ,	.valid_7 ( ifr_valid_7 )	,	.final_7 ( ifr_final_7 )

	,	.row_finish 	   (row_finish)
	,	.dy2_conv_finish	   (dy2_conv_finish)

	//--------config input setting-----------
	,	.cfg_window				(	rcfg_ifr_window	)	//4
    ,	.cfg_atlchin			(	rcfg_atlchin		)		// 32/8 = 4
	,	.cfg_kernel_repeat		(	rcfg_ifr_kernel_repeat	)

	,	.row_number				(	ifr_row_number	)

);

ifsram_pd #(
	.TBITS (	64	)
	,	.TBYTE (	8	)
	,	.IFMAP_SRAM_ADDBITS 	(	IFMAP_SRAM_ADDBITS		)
	,	.IFMAP_SRAM_DATA_WIDTH	(	IFMAP_SRAM_DATA_WIDTH	)
)if_pad00(
 	.clk	(	clk	)
	,	.reset		(	reset	)
	
	,	.if_pad_done 	(	if_pad_done 	)	
	,	.if_pad_busy 	(	if_pad_busy 	)	
	,	.if_pad_start	(	if_pad_start	)	

	,	.pdb0_cen		(	if_pad_pdb0_cen		)
	,	.pdb0_wen		(	if_pad_pdb0_wen		)
	,	.pdb0_addr		(	if_pad_pdb0_addr	)
	,	.pdb1_cen		(	if_pad_pdb1_cen		)
	,	.pdb1_wen		(	if_pad_pdb1_wen		)
	,	.pdb1_addr		(	if_pad_pdb1_addr	)
	,	.pdb6_cen		(	if_pad_pdb6_cen		)
	,	.pdb6_wen		(	if_pad_pdb6_wen		)
	,	.pdb6_addr		(	if_pad_pdb6_addr	)
	,	.pdb7_cen		(	if_pad_pdb7_cen		)
	,	.pdb7_wen		(	if_pad_pdb7_wen		)
	,	.pdb7_addr		(	if_pad_pdb7_addr	)
	,	.pd_data		(	if_pad_pd_data		)

	//config input setting
	,	.cfg_atlchin		(	rcfg_atlchin		) 
	,	.cfg_conv_switch	(	rcfg_conv_switch	)
	,	.cfg_mast_state		(	rcfg_mast_state		)
	,	.cfg_pd_list_0		(	rcfg_pd_list_0		)
	,	.cfg_pd_list_1		(	rcfg_pd_list_1		)
	,	.cfg_pd_list_2		(	rcfg_pd_list_2		)
	,	.cfg_pd_list_3		(	rcfg_pd_list_3		)
	,	.cfg_pd_list_4		(	rcfg_pd_list_4		)
	,	.cfg_cnt_step_p1	(	rcfg_cnt_step_p1	)
	,	.cfg_cnt_step_p2	(	rcfg_cnt_step_p2	)

);
/*
	reg [2:0] if_read_current_state_1if_read_current_state_1;
	reg [3:0] next_state;
	//assign if_read_current_state_1 =(if_read_current_state==1 && cena_if0b0) ? 1 : (~if_read_current_state_1 && cena_if0b0) ? 1 : 0 ;
	reg [10:0] addra_cnt , addrb_cnt;
	always @(posedge clk)
		if (reset)	
			addra_cnt <= 0;
		else if (addra_cnt<addr_write_ifsram_0)
			addra_cnt <= addr_write_ifsram_0;
		else addra_cnt <= addra_cnt;
	always @(posedge clk)
		if (reset)	
			addrb_cnt <= 0;
		else if (addrb_cnt<addr_read_ifsram)
			addrb_cnt <= addr_read_ifsram;
		else addrb_cnt <= addrb_cnt;


	always @(posedge clk ) begin
		if(reset) 
			if_read_current_state_1 <= 2'd0;
		else 
			if_read_current_state_1 <= next_state;
	end
	
	always @(*)  begin
		if (reset)
			next_state <= 0 ;
		else if (addra_cnt >= addrb_cnt)
			next_state <= if_read_current_state;
		else if (addra_cnt < addrb_cnt)	
			next_state <= 3'd0;
		else next_state <= if_read_current_state;
		end
		*/
//	assign if_read_current_state_1 = (addra_cnt >= (addrb_cnt)) ? if_read_current_state : 3'd6 ;
//    assign if_read_current_state_1 = (addra_cnt >= addrb_cnt) ? if_read_current_state : (addra_cnt < addrb_cnt) ?  3'd6 : if_read_current_state_1;



`ifdef FPGA_ILA_CHK_SETTING
	output wire [  IFMAP_SRAM_ADDBITS-1  :   0   ] ick_addrb_sram_if0b0		;
	assign ick_addrb_sram_if0b0 = addrb_sram_if0b0	;
`endif 
endmodule





