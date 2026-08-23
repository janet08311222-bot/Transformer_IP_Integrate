// ============================================================================
// Designer : Yi_Yuan Chen
// Modify   : (Fixed for Dual-Port SRAM 2-Row Parallel Read Integration)
// Ver      : 2.3 (Removed Invalid Mask to ensure 3-Cycle Data Integrity)
// Func     : connect the sram and send data to pe
// ============================================================================

//`define FPGA_SRAM_SETTING
// `define	FPGA_ILA_CHK_SETTING

module ifsram_rw #(
		parameter 	TBITS = 64	
	,				TBYTE = 8	
	,	IFMAP_SRAM_ADDBITS = 11 	
	,	IFMAP_SRAM_DATA_WIDTH = 64	
	,	CNTSTP_WIDTH = 3			 
	,	IFWSTG0_CNTBITS = 5			
	,	IFWSTG1_CNTBITS = 3			
	,	DATAIN_CNT_BITS = 9			
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
	,	if_read_last		
	,	rdwd_done

	//========= Row 0 (Port B) =========
	,	dout_ifsr_0 ,	dout_ifsr_1 ,	dout_ifsr_2 ,	dout_ifsr_3 ,	dout_ifsr_4 ,	dout_ifsr_5 ,	dout_ifsr_6 ,	dout_ifsr_7	
	, 	ifr_valid_0 , 	ifr_valid_1 , 	ifr_valid_2 , 	ifr_valid_3 , 	ifr_valid_4 , 	ifr_valid_5 , 	ifr_valid_6 , 	ifr_valid_7 	
	,	ifr_final_0 , 	ifr_final_1 , 	ifr_final_2 , 	ifr_final_3 , 	ifr_final_4 , 	ifr_final_5 , 	ifr_final_6 , 	ifr_final_7 
 	
	//========= Row 1 (Port A) =========
    ,   dout_ifsr_r1_0, dout_ifsr_r1_1, dout_ifsr_r1_2, dout_ifsr_r1_3, dout_ifsr_r1_4, dout_ifsr_r1_5, dout_ifsr_r1_6, dout_ifsr_r1_7	
    ,   ifr_valid_r1_0, ifr_valid_r1_1, ifr_valid_r1_2, ifr_valid_r1_3, ifr_valid_r1_4, ifr_valid_r1_5, ifr_valid_r1_6, ifr_valid_r1_7 	
    ,   ifr_final_r1_0, ifr_final_r1_1, ifr_final_r1_2, ifr_final_r1_3, ifr_final_r1_4, ifr_final_r1_5, ifr_final_r1_6, ifr_final_r1_7
    
	//config input setting(ifsram_pd)
	,	cfg_atlchin		
	,	cfg_conv_switch			
	,	cfg_mast_state	
	,	cfg_pd_list_0	
	,	cfg_pd_list_1	
	,	cfg_pd_list_2	
	,	cfg_pd_list_3	
	,	cfg_pd_list_4	
	,	cfg_cnt_step_p1		
	,	cfg_cnt_step_p2		
	
	//config input setting(ifsram_w)
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
	output 	wire 				if_write_done		;
	output	wire				if_write_busy		;
	input	wire				if_write_start		;
	output	wire				if_write_en			;	
	
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

// config input setting
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

input	wire	[IFWSTG0_CNTBITS-1 :0]	cfg_stg0_nor_finum	;
input	wire	[IFWSTG0_CNTBITS-1 :0]	cfg_stg0_pdb0_finum	;
input	wire	[IFWSTG0_CNTBITS-1 :0]	cfg_stg0_pdb1_finum	;
input	wire	[IFWSTG1_CNTBITS-1 :0]	cfg_stg1_eb_col		;
input	wire	[DATAIN_CNT_BITS-1 :0]	cfg_dincnt_finum	;
input	wire	[3-1 :0]	cfg_rowcnt_finum	;

input	wire	[7:0]	cfg_ifr_window;
input   wire    [7:0]   cfg_ifr_kernel_repeat;
input   wire    [7:0] 	cfg_ift_total_window;

//----to PE signal (Row 0)
output	wire [TBITS-1 :0] dout_ifsr_0 ,dout_ifsr_1 ,dout_ifsr_2 ,dout_ifsr_3 ,dout_ifsr_4 ,dout_ifsr_5 ,dout_ifsr_6 ,dout_ifsr_7;
output	wire	ifr_valid_0 , ifr_valid_1 , ifr_valid_2 , ifr_valid_3 , ifr_valid_4 , ifr_valid_5 , ifr_valid_6 , ifr_valid_7	;
output	wire	ifr_final_0 , ifr_final_1 , ifr_final_2 , ifr_final_3 , ifr_final_4 , ifr_final_5 , ifr_final_6 , ifr_final_7	;

//----to PE signal (Row 1) 
output wire [TBITS-1 :0] dout_ifsr_r1_0, dout_ifsr_r1_1, dout_ifsr_r1_2, dout_ifsr_r1_3, dout_ifsr_r1_4, dout_ifsr_r1_5, dout_ifsr_r1_6, dout_ifsr_r1_7;
output wire ifr_valid_r1_0, ifr_valid_r1_1, ifr_valid_r1_2, ifr_valid_r1_3, ifr_valid_r1_4, ifr_valid_r1_5, ifr_valid_r1_6, ifr_valid_r1_7;
output wire ifr_final_r1_0, ifr_final_r1_1, ifr_final_r1_2, ifr_final_r1_3, ifr_final_r1_4, ifr_final_r1_5, ifr_final_r1_6, ifr_final_r1_7;

//--------- Wire / Reg ---------

//----- wirte if sram -----
	wire cen_write_ifsram_0 , cen_write_ifsram_1 , cen_write_ifsram_2 , cen_write_ifsram_3 , cen_write_ifsram_4 , cen_write_ifsram_5 , cen_write_ifsram_6 , cen_write_ifsram_7 ;
	wire wen_write_ifsram_0 , wen_write_ifsram_1 , wen_write_ifsram_2 , wen_write_ifsram_3 , wen_write_ifsram_4 , wen_write_ifsram_5 , wen_write_ifsram_6 , wen_write_ifsram_7 ;
	wire [TBITS-1:0]	data_write_ifsram_0 , data_write_ifsram_1 , data_write_ifsram_2 , data_write_ifsram_3 
					, data_write_ifsram_4 , data_write_ifsram_5 , data_write_ifsram_6 , data_write_ifsram_7;
	wire [IFMAP_SRAM_ADDBITS-1:0]	addr_write_ifsram_0 , addr_write_ifsram_1 , addr_write_ifsram_2 , addr_write_ifsram_3 
								, addr_write_ifsram_4 , addr_write_ifsram_5 , addr_write_ifsram_6 , addr_write_ifsram_7	;

//---- dout signal from SRAM ----
	// dout_sram_if / dy_dout_en0 : declared, never driven or read
	reg if_valid_0s0 , if_valid_0s1 , if_valid_0s2 , if_valid_0s3 , if_valid_0s4 , if_valid_0s5 , if_valid_0s6 , if_valid_0s7	;
	reg if_final_0s0 , if_final_0s1 , if_final_0s2 , if_final_0s3 , if_final_0s4 , if_final_0s5 , if_final_0s6 , if_final_0s7	;

//----- read if sram -----
	wire cen_read	;
	reg  cen_read1	, cen_read2	, cen_read3	, cen_read4	, cen_read5	, cen_read6	, cen_read7	;
	wire [IFMAP_SRAM_ADDBITS-1:0] addr_read_ifsram ;
	reg [IFMAP_SRAM_ADDBITS-1:0] addr_read_ifsram1 , addr_read_ifsram2 , addr_read_ifsram3 
			,	addr_read_ifsram4 , addr_read_ifsram5 , addr_read_ifsram6 , addr_read_ifsram7	;

	reg ifsram1b0_write	, ifsram2b0_write	, ifsram3b0_write	, ifsram4b0_write	, ifsram5b0_write	, ifsram6b0_write	, ifsram7b0_write	;
	reg ifsram1b0_read  , ifsram2b0_read	, ifsram3b0_read	, ifsram4b0_read	, ifsram5b0_read	, ifsram6b0_read	, ifsram7b0_read	;

	wire [1:0] ifr_row_number ;
	wire row_group_sel_w ;   // = ifsram_r's rd_row_parity (LSB of the row-slot currently read as 'row')
	wire wr_row_parity ;     // = ifsram_w's wr_row_parity (LSB of the row-slot currently being written)
	reg  row_group_sel1 , row_group_sel2 , row_group_sel3 , row_group_sel4 , row_group_sel5 , row_group_sel6 , row_group_sel7 ;
	wire en_ifr_over_toplength_b0 ;
	reg en_ifr_over_toplength_tmp0 , en_ifr_over_toplength_tmp1 , en_ifr_over_toplength_tmp2 ;
	reg en_ifr_over_toplength_b1 , en_ifr_over_toplength_b2 , en_ifr_over_toplength_b3 , en_ifr_over_toplength_b4 ;
	reg en_ifr_over_toplength_b5 , en_ifr_over_toplength_b6 , en_ifr_over_toplength_b7 ;
//
    wire cen_read_r1;
    reg  cen_read_r1_1, cen_read_r1_2, cen_read_r1_3, cen_read_r1_4, cen_read_r1_5, cen_read_r1_6, cen_read_r1_7;
    wire [IFMAP_SRAM_ADDBITS-1:0] addr_read_ifsram_r1;
    reg  [IFMAP_SRAM_ADDBITS-1:0] addr_read_ifsram_r1_1, addr_read_ifsram_r1_2, addr_read_ifsram_r1_3, addr_read_ifsram_r1_4, addr_read_ifsram_r1_5, addr_read_ifsram_r1_6, addr_read_ifsram_r1_7;
    

    wire [TBITS-1:0] din_mux_r1_0, din_mux_r1_1, din_mux_r1_2, din_mux_r1_3;
    wire [TBITS-1:0] din_mux_r1_4, din_mux_r1_5, din_mux_r1_6, din_mux_r1_7;
//----    actually cen wen signal declare    -----
//----    dual bank-group (A = even row-slot , B = odd row-slot) SRAM port signal declare    -----
	wire cenwA_0 , cenwA_1 , cenwA_2 , cenwA_3 , cenwA_4 , cenwA_5 , cenwA_6 , cenwA_7 ;
	wire cenwB_0 , cenwB_1 , cenwB_2 , cenwB_3 , cenwB_4 , cenwB_5 , cenwB_6 , cenwB_7 ;
	wire wenwA_0 , wenwA_1 , wenwA_2 , wenwA_3 , wenwA_4 , wenwA_5 , wenwA_6 , wenwA_7 ;
	wire wenwB_0 , wenwB_1 , wenwB_2 , wenwB_3 , wenwB_4 , wenwB_5 , wenwB_6 , wenwB_7 ;
	wire [IFMAP_SRAM_ADDBITS-1:0] addrwA_0 , addrwA_1 , addrwA_2 , addrwA_3 , addrwA_4 , addrwA_5 , addrwA_6 , addrwA_7 ;
	wire [IFMAP_SRAM_ADDBITS-1:0] addrwB_0 , addrwB_1 , addrwB_2 , addrwB_3 , addrwB_4 , addrwB_5 , addrwB_6 , addrwB_7 ;
	wire [TBITS-1:0] dinwA_0 , dinwA_1 , dinwA_2 , dinwA_3 , dinwA_4 , dinwA_5 , dinwA_6 , dinwA_7 ;
	wire [TBITS-1:0] dinwB_0 , dinwB_1 , dinwB_2 , dinwB_3 , dinwB_4 , dinwB_5 , dinwB_6 , dinwB_7 ;
	wire cenrA_0 , cenrA_1 , cenrA_2 , cenrA_3 , cenrA_4 , cenrA_5 , cenrA_6 , cenrA_7 ;
	wire cenrB_0 , cenrB_1 , cenrB_2 , cenrB_3 , cenrB_4 , cenrB_5 , cenrB_6 , cenrB_7 ;
	wire [IFMAP_SRAM_ADDBITS-1:0] addrrA_0 , addrrA_1 , addrrA_2 , addrrA_3 , addrrA_4 , addrrA_5 , addrrA_6 , addrrA_7 ;
	wire [IFMAP_SRAM_ADDBITS-1:0] addrrB_0 , addrrB_1 , addrrB_2 , addrrB_3 , addrrB_4 , addrrB_5 , addrrB_6 , addrrB_7 ;
	wire [TBITS-1:0] doutrA_0 , doutrA_1 , doutrA_2 , doutrA_3 , doutrA_4 , doutrA_5 , doutrA_6 , doutrA_7 ;
	wire [TBITS-1:0] doutrB_0 , doutrB_1 , doutrB_2 , doutrB_3 , doutrB_4 , doutrB_5 , doutrB_6 , doutrB_7 ;
	// active-low translated versions (for non-FPGA / FPGA_SRAM_SETTING branches)
	wire atlwA_cen_0 , atlwA_cen_1 , atlwA_cen_2 , atlwA_cen_3 , atlwA_cen_4 , atlwA_cen_5 , atlwA_cen_6 , atlwA_cen_7 ;
	wire atlwB_cen_0 , atlwB_cen_1 , atlwB_cen_2 , atlwB_cen_3 , atlwB_cen_4 , atlwB_cen_5 , atlwB_cen_6 , atlwB_cen_7 ;
	wire atlrA_cen_0 , atlrA_cen_1 , atlrA_cen_2 , atlrA_cen_3 , atlrA_cen_4 , atlrA_cen_5 , atlrA_cen_6 , atlrA_cen_7 ;
	wire atlrB_cen_0 , atlrB_cen_1 , atlrB_cen_2 , atlrB_cen_3 , atlrB_cen_4 , atlrB_cen_5 , atlrB_cen_6 , atlrB_cen_7 ;
	wire atl_wenA_0 , atl_wenA_1 , atl_wenA_2 , atl_wenA_3 , atl_wenA_4 , atl_wenA_5 , atl_wenA_6 , atl_wenA_7 ;
	wire atl_wenB_0 , atl_wenB_1 , atl_wenB_2 , atl_wenB_3 , atl_wenB_4 , atl_wenB_5 , atl_wenB_6 , atl_wenB_7 ;
	wire [  TBITS-1  :   0   ] 	 din_mux0, din_mux1, din_mux2, din_mux3, din_mux4, din_mux5, din_mux6, din_mux7;

//----    SRAM dout delay valid    -----
	reg dy_dout_valid_0 , dy_dout_valid_1 , dy_dout_valid_2 , dy_dout_valid_3 , dy_dout_valid_4 , dy_dout_valid_5 , dy_dout_valid_6 , dy_dout_valid_7	;

//----    padding signal declare    -----
	wire	if_pad_pdb0_cen , if_pad_pdb1_cen , if_pad_pdb6_cen , if_pad_pdb7_cen ;
	wire	if_pad_pdb0_wen , if_pad_pdb1_wen , if_pad_pdb6_wen , if_pad_pdb7_wen ;
	wire	[IFMAP_SRAM_ADDBITS-1:0] if_pad_pdb0_addr , if_pad_pdb1_addr , if_pad_pdb6_addr , if_pad_pdb7_addr ;
	// if_pad_pd_data : ifsram_pd's pd_data output, unread -- left open

////----    Config register    -----
	reg		[8-1:0]	rcfg_atlchin			;	
	reg		[3-1:0]	rcfg_conv_switch		;
	reg		[3-1:0]	rcfg_mast_state		;
	reg		[IFMAP_SRAM_ADDBITS-1:0]	rcfg_pd_list_0, rcfg_pd_list_1, rcfg_pd_list_2, rcfg_pd_list_3, rcfg_pd_list_4;
	reg		[CNTSTP_WIDTH-1:0]	rcfg_cnt_step_p1, rcfg_cnt_step_p2	;
	reg		[IFWSTG0_CNTBITS-1 :0]	rcfg_stg0_nor_finum, rcfg_stg0_pdb0_finum, rcfg_stg0_pdb1_finum	;
	reg		[IFWSTG1_CNTBITS-1 :0]	rcfg_stg1_eb_col		;
	reg		[DATAIN_CNT_BITS-1 :0]	rcfg_dincnt_finum		;
	reg		[3-1 :0]	rcfg_rowcnt_finum		;
	reg		[8-1:0]		rcfg_ifr_window	;
	reg     [7:0]		rcfg_ifr_kernel_repeat;
	reg  	[7:0]		rcfg_ift_total_window;

// ============================================================================
// ========		Config register		 ==========================================
// ============================================================================
always @(posedge clk ) begin
	if(reset)begin
		rcfg_mast_state	<= LEFT 	;	
		rcfg_atlchin		<= 8'd4		;	
		rcfg_conv_switch <= 3'd2		;
		rcfg_stg0_nor_finum	<=	5'd11	;
		rcfg_stg0_pdb0_finum	<=	5'd7	;	
		rcfg_stg0_pdb1_finum	<=	5'd7	;
		rcfg_stg1_eb_col		<=	5'd1	;	
		rcfg_dincnt_finum		<=	9'd67	;
		rcfg_rowcnt_finum		<=	3'd2	;	
		rcfg_ifr_window			<= 4		;   
		rcfg_ifr_kernel_repeat	<= 7;
		rcfg_ift_total_window 	<= 4;
	end
	else begin
		rcfg_mast_state			<= 	cfg_mast_state	;
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

always @(posedge clk ) begin
	if(reset)begin
		rcfg_pd_list_0	<= 9'd0			;
		rcfg_pd_list_1	<= 9'd24		;	
		rcfg_pd_list_2	<= 9'd48		;	
		rcfg_pd_list_3	<= 9'd0			;
		rcfg_pd_list_4	<= 9'd0			;	
		rcfg_cnt_step_p1	<= 3'd3;
		rcfg_cnt_step_p2	<= 3'd0;
	end
	else begin
		rcfg_pd_list_0	<= cfg_pd_list_0	;
		rcfg_pd_list_1	<= cfg_pd_list_1	;
		rcfg_pd_list_2	<= cfg_pd_list_2	;
		rcfg_pd_list_3	<= cfg_pd_list_3	;
		rcfg_pd_list_4	<= cfg_pd_list_4	;
		rcfg_cnt_step_p1	<= cfg_cnt_step_p1	;
		rcfg_cnt_step_p2	<= cfg_cnt_step_p2	;
	end
end

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
		dy0_ifsram0_read_1 <= 0; dy0_ifsram0_read_2 <= 0;
		dy0_ifsram0_read_3 <= 0; dy0_ifsram0_read_4 <= 0; dy0_ifsram0_read_5 <= 0; dy0_ifsram0_read_6 <= 0; dy0_ifsram0_read_7 <= 0;
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

assign en_ifr_over_toplength_b0 = ((ifr_row_number == 2) && (if_read_current_state == 1 || if_read_current_state == 6))? 1'd1 : 1'd0 ;

always @ (posedge clk)begin
	if(reset)begin
		en_ifr_over_toplength_tmp0 <= 0; en_ifr_over_toplength_tmp1 <= 0; en_ifr_over_toplength_tmp2 <= 0;		
		en_ifr_over_toplength_b1 <= 0; en_ifr_over_toplength_b2 <= 0;
		en_ifr_over_toplength_b3 <= 0; en_ifr_over_toplength_b4 <= 0;
		en_ifr_over_toplength_b5 <= 0; en_ifr_over_toplength_b6 <= 0; en_ifr_over_toplength_b7 <= 0;
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

// Row0(main)/Row1(secondary) output mux now selects between physical group A and
// group B read data based on which group currently holds the 'row' vs 'row+1' slot
// (row_group_sel==0 -> row is in group A, row+1 in group B, and vice versa).
	assign din_mux0    = (en_ifr_over_toplength_tmp2) ? 0 : (~row_group_sel_w) ? doutrA_0 : doutrB_0 ;
	assign din_mux1    = (en_ifr_over_toplength_b1) ? 0 : (~row_group_sel1) ? doutrA_1 : doutrB_1 ;
	assign din_mux2    = (en_ifr_over_toplength_b2) ? 0 : (~row_group_sel2) ? doutrA_2 : doutrB_2 ;
	assign din_mux3    = (en_ifr_over_toplength_b3) ? 0 : (~row_group_sel3) ? doutrA_3 : doutrB_3 ;
	assign din_mux4    = (en_ifr_over_toplength_b4) ? 0 : (~row_group_sel4) ? doutrA_4 : doutrB_4 ;
	assign din_mux5    = (en_ifr_over_toplength_b5) ? 0 : (~row_group_sel5) ? doutrA_5 : doutrB_5 ;
	assign din_mux6    = (en_ifr_over_toplength_b6) ? 0 : (~row_group_sel6) ? doutrA_6 : doutrB_6 ;
	assign din_mux7    = (en_ifr_over_toplength_b7) ? 0 : (~row_group_sel7) ? doutrA_7 : doutrB_7 ;
	assign din_mux_r1_0 = (en_ifr_over_toplength_b1) ? 0 : (~row_group_sel_w) ? doutrB_0 : doutrA_0 ;
	assign din_mux_r1_1 = (en_ifr_over_toplength_b2) ? 0 : (~row_group_sel1) ? doutrB_1 : doutrA_1 ;
	assign din_mux_r1_2 = (en_ifr_over_toplength_b3) ? 0 : (~row_group_sel2) ? doutrB_2 : doutrA_2 ;
	assign din_mux_r1_3 = (en_ifr_over_toplength_b4) ? 0 : (~row_group_sel3) ? doutrB_3 : doutrA_3 ;
	assign din_mux_r1_4 = (en_ifr_over_toplength_b5) ? 0 : (~row_group_sel4) ? doutrB_4 : doutrA_4 ;
	assign din_mux_r1_5 = (en_ifr_over_toplength_b6) ? 0 : (~row_group_sel5) ? doutrB_5 : doutrA_5 ;
	assign din_mux_r1_6 = (en_ifr_over_toplength_b7) ? 0 : (~row_group_sel6) ? doutrB_6 : doutrA_6 ;
	assign din_mux_r1_7 = (en_ifr_over_toplength_b7) ? 0 : (~row_group_sel7) ? doutrB_7 : doutrA_7 ;

// ============================================================================
// =========================    Control Signal   ==============================
// ============================================================================
always @(posedge clk ) begin if(reset) dy_dout_valid_0 <= 0; else begin if( ~cen_read ) dy_dout_valid_0 <= 1; else dy_dout_valid_0 <= 0; end end
always @(posedge clk ) begin if(reset) dy_dout_valid_1 <= 0; else begin if( ~cen_read1 ) dy_dout_valid_1 <= 1; else dy_dout_valid_1 <= 0; end end
always @(posedge clk ) begin if(reset) dy_dout_valid_2 <= 0; else begin if( ~cen_read2 ) dy_dout_valid_2 <= 1; else dy_dout_valid_2 <= 0; end end
always @(posedge clk ) begin if(reset) dy_dout_valid_3 <= 0; else begin if( ~cen_read3 ) dy_dout_valid_3 <= 1; else dy_dout_valid_3 <= 0; end end
always @(posedge clk ) begin if(reset) dy_dout_valid_4 <= 0; else begin if( ~cen_read4 ) dy_dout_valid_4 <= 1; else dy_dout_valid_4 <= 0; end end
always @(posedge clk ) begin if(reset) dy_dout_valid_5 <= 0; else begin if( ~cen_read5 ) dy_dout_valid_5 <= 1; else dy_dout_valid_5 <= 0; end end
always @(posedge clk ) begin if(reset) dy_dout_valid_6 <= 0; else begin if( ~cen_read6 ) dy_dout_valid_6 <= 1; else dy_dout_valid_6 <= 0; end end
always @(posedge clk ) begin if(reset) dy_dout_valid_7 <= 0; else begin if( ~cen_read7 ) dy_dout_valid_7 <= 1; else dy_dout_valid_7 <= 0; end end

if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux0(.data_valid	(dy_dout_valid_0),.dinsr_0(din_mux0)	,.dout (dout_ifsr_0)	,.ifsram0_read	(dy0_ifsram0_read_0)	);
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux1(.data_valid	(dy_dout_valid_1),.dinsr_0(din_mux1)	,.dout (dout_ifsr_1)	,.ifsram0_read	(dy0_ifsram0_read_1)	);
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux2(.data_valid	(dy_dout_valid_2),.dinsr_0(din_mux2)	,.dout (dout_ifsr_2)	,.ifsram0_read	(dy0_ifsram0_read_2)	);
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux3(.data_valid	(dy_dout_valid_3),.dinsr_0(din_mux3)	,.dout (dout_ifsr_3)	,.ifsram0_read	(dy0_ifsram0_read_3)	);
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux4(.data_valid	(dy_dout_valid_4),.dinsr_0(din_mux4)	,.dout (dout_ifsr_4)	,.ifsram0_read	(dy0_ifsram0_read_4)	);
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux5(.data_valid	(dy_dout_valid_5),.dinsr_0(din_mux5)	,.dout (dout_ifsr_5)	,.ifsram0_read	(dy0_ifsram0_read_5)	);
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux6(.data_valid	(dy_dout_valid_6),.dinsr_0(din_mux6)	,.dout (dout_ifsr_6)	,.ifsram0_read	(dy0_ifsram0_read_6)	);
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux7(.data_valid	(dy_dout_valid_7),.dinsr_0(din_mux7)	,.dout (dout_ifsr_7)	,.ifsram0_read	(dy0_ifsram0_read_7)	);

// Row 1 MUX 
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux_r1_0(.data_valid(dy_dout_valid_0),.dinsr_0(din_mux_r1_0),.dout (dout_ifsr_r1_0),.ifsram0_read(dy0_ifsram0_read_0));
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux_r1_1(.data_valid(dy_dout_valid_1),.dinsr_0(din_mux_r1_1),.dout (dout_ifsr_r1_1),.ifsram0_read(dy0_ifsram0_read_1));
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux_r1_2(.data_valid(dy_dout_valid_2),.dinsr_0(din_mux_r1_2),.dout (dout_ifsr_r1_2),.ifsram0_read(dy0_ifsram0_read_2));
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux_r1_3(.data_valid(dy_dout_valid_3),.dinsr_0(din_mux_r1_3),.dout (dout_ifsr_r1_3),.ifsram0_read(dy0_ifsram0_read_3));
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux_r1_4(.data_valid(dy_dout_valid_4),.dinsr_0(din_mux_r1_4),.dout (dout_ifsr_r1_4),.ifsram0_read(dy0_ifsram0_read_4));
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux_r1_5(.data_valid(dy_dout_valid_5),.dinsr_0(din_mux_r1_5),.dout (dout_ifsr_r1_5),.ifsram0_read(dy0_ifsram0_read_5));
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux_r1_6(.data_valid(dy_dout_valid_6),.dinsr_0(din_mux_r1_6),.dout (dout_ifsr_r1_6),.ifsram0_read(dy0_ifsram0_read_6));
if_dout_mux #( .DATA_WIDTH( TBITS) )id_mux_r1_7(.data_valid(dy_dout_valid_7),.dinsr_0(din_mux_r1_7),.dout (dout_ifsr_r1_7),.ifsram0_read(dy0_ifsram0_read_7));

//------------stage signal-------------------
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

	always @(posedge clk)begin
		if(reset)
			if_valid_0s0 <= 0;
		else if(~cen_read)
			if_valid_0s0 <= 1;
		else
			if_valid_0s0 <= 0;
	end

	always @(posedge clk)begin
		if(reset) begin
			if_valid_0s1 <= 0; if_valid_0s2 <= 0; if_valid_0s3 <= 0;
			if_valid_0s4 <= 0; if_valid_0s5 <= 0; if_valid_0s6 <= 0; if_valid_0s7 <= 0;
			
			if_final_0s1 <= 0; if_final_0s2 <= 0;
			if_final_0s3 <= 0; if_final_0s4 <= 0; if_final_0s5 <= 0; if_final_0s6 <= 0; if_final_0s7 <= 0;
		end
		else begin
			if_valid_0s1 <= if_valid_0s0;
			if_valid_0s2 <= if_valid_0s1; if_valid_0s3 <= if_valid_0s2; if_valid_0s4 <= if_valid_0s3;
			if_valid_0s5 <= if_valid_0s4; if_valid_0s6 <= if_valid_0s5; if_valid_0s7 <= if_valid_0s6;
			
			if_final_0s1 <= if_final_0s0; if_final_0s2 <= if_final_0s1; if_final_0s3 <= if_final_0s2; if_final_0s4 <= if_final_0s3;
			if_final_0s5 <= if_final_0s4; if_final_0s6 <= if_final_0s5;
			if_final_0s7 <= if_final_0s6;
		end
	end

    // Valid Final (Row 0)
	assign ifr_valid_0 = if_valid_0s0 ; assign ifr_valid_1 = if_valid_0s1 ; assign ifr_valid_2 = if_valid_0s2 ;
	assign ifr_valid_3 = if_valid_0s3 ;
	assign ifr_valid_4 = if_valid_0s4 ; assign ifr_valid_5 = if_valid_0s5 ; assign ifr_valid_6 = if_valid_0s6 ;
	assign ifr_valid_7 = if_valid_0s7 ;
	
    assign ifr_final_0 = if_final_0s0 ; assign ifr_final_1 = if_final_0s1 ; assign ifr_final_2 = if_final_0s2 ;
	assign ifr_final_3 = if_final_0s3 ;
	assign ifr_final_4 = if_final_0s4 ; assign ifr_final_5 = if_final_0s5 ; assign ifr_final_6 = if_final_0s6 ;
	assign ifr_final_7 = if_final_0s7 ;

	// ?i????I?jValid Final (Row 1) - ??????~?B?n?A?? 3-Cycle ???????????`?e?J PE
    assign ifr_valid_r1_0 = if_valid_0s0 ;
    assign ifr_valid_r1_1 = if_valid_0s1 ; 
    assign ifr_valid_r1_2 = if_valid_0s2 ; 
    assign ifr_valid_r1_3 = if_valid_0s3 ;
    assign ifr_valid_r1_4 = if_valid_0s4 ;
    assign ifr_valid_r1_5 = if_valid_0s5 ; 
    assign ifr_valid_r1_6 = if_valid_0s6 ; 
    assign ifr_valid_r1_7 = if_valid_0s7 ;
    
    assign ifr_final_r1_0 = if_final_0s0 ;
    assign ifr_final_r1_1 = if_final_0s1 ; 
    assign ifr_final_r1_2 = if_final_0s2 ; 
    assign ifr_final_r1_3 = if_final_0s3 ;
    assign ifr_final_r1_4 = if_final_0s4 ;
    assign ifr_final_r1_5 = if_final_0s5 ; 
    assign ifr_final_r1_6 = if_final_0s6 ; 
    assign ifr_final_r1_7 = if_final_0s7 ;

//------------sram signal control-----------------------
	always @(posedge clk) begin
		if (reset) begin
			addr_read_ifsram1 <= 0; addr_read_ifsram2 <= 0; addr_read_ifsram3 <= 0; addr_read_ifsram4 <= 0;
			addr_read_ifsram5 <= 0; addr_read_ifsram6 <= 0; addr_read_ifsram7 <= 0;
			
            addr_read_ifsram_r1_1 <= 0; addr_read_ifsram_r1_2 <= 0; addr_read_ifsram_r1_3 <= 0;
			addr_read_ifsram_r1_4 <= 0;
			addr_read_ifsram_r1_5 <= 0; addr_read_ifsram_r1_6 <= 0; addr_read_ifsram_r1_7 <= 0;
			
            cen_read1 <= 1; cen_read2 <= 1;
			cen_read3 <= 1; cen_read4 <= 1;
			cen_read5 <= 1; cen_read6 <= 1; cen_read7 <= 1;
			
            cen_read_r1_1 <= 1;
			cen_read_r1_2 <= 1; cen_read_r1_3 <= 1; cen_read_r1_4 <= 1;
			cen_read_r1_5 <= 1; cen_read_r1_6 <= 1; cen_read_r1_7 <= 1;

			ifsram1b0_read <= 0; ifsram2b0_read <= 0; ifsram3b0_read <= 0; ifsram4b0_read <= 0;
			ifsram5b0_read <= 0; ifsram6b0_read <= 0;
			ifsram7b0_read <= 0;
			row_group_sel1 <= 0; row_group_sel2 <= 0; row_group_sel3 <= 0; row_group_sel4 <= 0;
			row_group_sel5 <= 0; row_group_sel6 <= 0; row_group_sel7 <= 0;
		end
		else begin
			// Row 0 
			addr_read_ifsram1 <= addr_read_ifsram;  addr_read_ifsram2 <= addr_read_ifsram1; addr_read_ifsram3 <= addr_read_ifsram2;
			addr_read_ifsram4 <= addr_read_ifsram3;
			addr_read_ifsram5 <= addr_read_ifsram4; addr_read_ifsram6 <= addr_read_ifsram5;
			addr_read_ifsram7 <= addr_read_ifsram6;
			
            // Row 1 
			addr_read_ifsram_r1_1 <= addr_read_ifsram_r1;   addr_read_ifsram_r1_2 <= addr_read_ifsram_r1_1;
			addr_read_ifsram_r1_3 <= addr_read_ifsram_r1_2; addr_read_ifsram_r1_4 <= addr_read_ifsram_r1_3;
			addr_read_ifsram_r1_5 <= addr_read_ifsram_r1_4; addr_read_ifsram_r1_6 <= addr_read_ifsram_r1_5;
			addr_read_ifsram_r1_7 <= addr_read_ifsram_r1_6;

			// row_group_sel pipeline (mirrors addr_read_ifsram delay chain, per-bank)
			row_group_sel1 <= row_group_sel_w; row_group_sel2 <= row_group_sel1; row_group_sel3 <= row_group_sel2;
			row_group_sel4 <= row_group_sel3; row_group_sel5 <= row_group_sel4; row_group_sel6 <= row_group_sel5;
			row_group_sel7 <= row_group_sel6;

			// Row 0 
			cen_read1 <= cen_read;  cen_read2 <= cen_read1; cen_read3 <= cen_read2; cen_read4 <= cen_read3;
			cen_read5 <= cen_read4;
			cen_read6 <= cen_read5; cen_read7 <= cen_read6;
			
            // Row 1 
			cen_read_r1_1 <= cen_read_r1;   cen_read_r1_2 <= cen_read_r1_1; cen_read_r1_3 <= cen_read_r1_2;
			cen_read_r1_4 <= cen_read_r1_3; cen_read_r1_5 <= cen_read_r1_4; cen_read_r1_6 <= cen_read_r1_5;
			cen_read_r1_7 <= cen_read_r1_6;
			
			ifsram1b0_read <= if_read_busy; ifsram2b0_read <= ifsram1b0_read;
			ifsram3b0_read <= ifsram2b0_read;
			ifsram4b0_read <= ifsram3b0_read; ifsram5b0_read <= ifsram4b0_read; ifsram6b0_read <= ifsram5b0_read;
			ifsram7b0_read <= ifsram6b0_read;
		end
	end

	always @(*)begin
		ifsram1b0_write = if_write_busy;
		ifsram2b0_write = ifsram1b0_write; ifsram3b0_write = ifsram2b0_write;
		ifsram4b0_write = ifsram3b0_write; ifsram5b0_write = ifsram4b0_write; ifsram6b0_write = ifsram5b0_write;
		ifsram7b0_write = ifsram6b0_write;
	end

// ============================================================================
// =====================    SRAM signal assignment   ==========================
// ============================================================================
// ============  SRAM signal assignment (dual bank-group A/B)  ================
// ============================================================================
// Group A physically stores the even row-slot (row_group_sel==0), Group B the odd
// row-slot (row_group_sel==1). Port A of every physical SRAM is now used ONLY to
// write, and Port B ONLY to read -- there is no more sharing of a single physical
// port between the write path and the row+1 read path, so a write burst overlapping
// a read burst can no longer stall / drop reads.

	// ---- bank 0 ----
	assign cenwA_0  = (if_pad_busy) ? if_pad_pdb0_cen  : (if_write_busy && ~wr_row_parity) ? cen_write_ifsram_0 : 1'b1 ;
	assign cenwB_0  = (if_pad_busy) ? if_pad_pdb0_cen  : (if_write_busy &&  wr_row_parity) ? cen_write_ifsram_0 : 1'b1 ;
	assign wenwA_0  = (if_pad_busy) ? if_pad_pdb0_wen  : (if_write_busy && ~wr_row_parity) ? wen_write_ifsram_0 : 1'b1 ;
	assign wenwB_0  = (if_pad_busy) ? if_pad_pdb0_wen  : (if_write_busy &&  wr_row_parity) ? wen_write_ifsram_0 : 1'b1 ;
	assign addrwA_0 = (if_pad_busy) ? if_pad_pdb0_addr : addr_write_ifsram_0 ;
	assign addrwB_0 = (if_pad_busy) ? if_pad_pdb0_addr : addr_write_ifsram_0 ;
	assign dinwA_0  = (if_write_busy) ? data_write_ifsram_0 : 64'd0 ;
	assign dinwB_0  = (if_write_busy) ? data_write_ifsram_0 : 64'd0 ;

	assign cenrA_0  = (if_pad_busy) ? if_pad_pdb0_cen  : (if_read_busy) ? cen_read : 1'b1 ;
	assign cenrB_0  = (if_pad_busy) ? if_pad_pdb0_cen  : (if_read_busy) ? cen_read : 1'b1 ;
	assign addrrA_0 = (if_pad_busy) ? if_pad_pdb0_addr : (~row_group_sel_w) ? addr_read_ifsram : addr_read_ifsram_r1 ;
	assign addrrB_0 = (if_pad_busy) ? if_pad_pdb0_addr : (~row_group_sel_w) ? addr_read_ifsram_r1 : addr_read_ifsram ;

	// ---- bank 1 ----
	assign cenwA_1  = (if_pad_busy) ? if_pad_pdb1_cen  : (ifsram1b0_write && ~wr_row_parity) ? cen_write_ifsram_1 : 1'b1 ;
	assign cenwB_1  = (if_pad_busy) ? if_pad_pdb1_cen  : (ifsram1b0_write &&  wr_row_parity) ? cen_write_ifsram_1 : 1'b1 ;
	assign wenwA_1  = (if_pad_busy) ? if_pad_pdb1_wen  : (ifsram1b0_write && ~wr_row_parity) ? wen_write_ifsram_1 : 1'b1 ;
	assign wenwB_1  = (if_pad_busy) ? if_pad_pdb1_wen  : (ifsram1b0_write &&  wr_row_parity) ? wen_write_ifsram_1 : 1'b1 ;
	assign addrwA_1 = (if_pad_busy) ? if_pad_pdb1_addr : addr_write_ifsram_1 ;
	assign addrwB_1 = (if_pad_busy) ? if_pad_pdb1_addr : addr_write_ifsram_1 ;
	assign dinwA_1  = (ifsram1b0_write) ? data_write_ifsram_1 : 64'd0 ;
	assign dinwB_1  = (ifsram1b0_write) ? data_write_ifsram_1 : 64'd0 ;

	assign cenrA_1  = (if_pad_busy) ? if_pad_pdb1_cen  : (ifsram1b0_read) ? cen_read1 : 1'b1 ;
	assign cenrB_1  = (if_pad_busy) ? if_pad_pdb1_cen  : (ifsram1b0_read) ? cen_read1 : 1'b1 ;
	assign addrrA_1 = (if_pad_busy) ? if_pad_pdb1_addr : (~row_group_sel1) ? addr_read_ifsram1 : addr_read_ifsram_r1_1 ;
	assign addrrB_1 = (if_pad_busy) ? if_pad_pdb1_addr : (~row_group_sel1) ? addr_read_ifsram_r1_1 : addr_read_ifsram1 ;

	// ---- bank 2 ----
	assign cenwA_2  = (ifsram2b0_write && ~wr_row_parity) ? cen_write_ifsram_2 : 1'b1 ;
	assign cenwB_2  = (ifsram2b0_write &&  wr_row_parity) ? cen_write_ifsram_2 : 1'b1 ;
	assign wenwA_2  = (ifsram2b0_write && ~wr_row_parity) ? wen_write_ifsram_2 : 1'b1 ;
	assign wenwB_2  = (ifsram2b0_write &&  wr_row_parity) ? wen_write_ifsram_2 : 1'b1 ;
	assign addrwA_2 = addr_write_ifsram_2 ;
	assign addrwB_2 = addr_write_ifsram_2 ;
	assign dinwA_2  = (ifsram2b0_write) ? data_write_ifsram_2 : 64'd0 ;
	assign dinwB_2  = (ifsram2b0_write) ? data_write_ifsram_2 : 64'd0 ;

	assign cenrA_2  = (ifsram2b0_read) ? cen_read2 : 1'b1 ;
	assign cenrB_2  = (ifsram2b0_read) ? cen_read2 : 1'b1 ;
	assign addrrA_2 = (~row_group_sel2) ? addr_read_ifsram2 : addr_read_ifsram_r1_2 ;
	assign addrrB_2 = (~row_group_sel2) ? addr_read_ifsram_r1_2 : addr_read_ifsram2 ;

	// ---- bank 3 ----
	assign cenwA_3  = (ifsram3b0_write && ~wr_row_parity) ? cen_write_ifsram_3 : 1'b1 ;
	assign cenwB_3  = (ifsram3b0_write &&  wr_row_parity) ? cen_write_ifsram_3 : 1'b1 ;
	assign wenwA_3  = (ifsram3b0_write && ~wr_row_parity) ? wen_write_ifsram_3 : 1'b1 ;
	assign wenwB_3  = (ifsram3b0_write &&  wr_row_parity) ? wen_write_ifsram_3 : 1'b1 ;
	assign addrwA_3 = addr_write_ifsram_3 ;
	assign addrwB_3 = addr_write_ifsram_3 ;
	assign dinwA_3  = (ifsram3b0_write) ? data_write_ifsram_3 : 64'd0 ;
	assign dinwB_3  = (ifsram3b0_write) ? data_write_ifsram_3 : 64'd0 ;

	assign cenrA_3  = (ifsram3b0_read) ? cen_read3 : 1'b1 ;
	assign cenrB_3  = (ifsram3b0_read) ? cen_read3 : 1'b1 ;
	assign addrrA_3 = (~row_group_sel3) ? addr_read_ifsram3 : addr_read_ifsram_r1_3 ;
	assign addrrB_3 = (~row_group_sel3) ? addr_read_ifsram_r1_3 : addr_read_ifsram3 ;

	// ---- bank 4 ----
	assign cenwA_4  = (ifsram4b0_write && ~wr_row_parity) ? cen_write_ifsram_4 : 1'b1 ;
	assign cenwB_4  = (ifsram4b0_write &&  wr_row_parity) ? cen_write_ifsram_4 : 1'b1 ;
	assign wenwA_4  = (ifsram4b0_write && ~wr_row_parity) ? wen_write_ifsram_4 : 1'b1 ;
	assign wenwB_4  = (ifsram4b0_write &&  wr_row_parity) ? wen_write_ifsram_4 : 1'b1 ;
	assign addrwA_4 = addr_write_ifsram_4 ;
	assign addrwB_4 = addr_write_ifsram_4 ;
	assign dinwA_4  = (ifsram4b0_write) ? data_write_ifsram_4 : 64'd0 ;
	assign dinwB_4  = (ifsram4b0_write) ? data_write_ifsram_4 : 64'd0 ;

	assign cenrA_4  = (ifsram4b0_read) ? cen_read4 : 1'b1 ;
	assign cenrB_4  = (ifsram4b0_read) ? cen_read4 : 1'b1 ;
	assign addrrA_4 = (~row_group_sel4) ? addr_read_ifsram4 : addr_read_ifsram_r1_4 ;
	assign addrrB_4 = (~row_group_sel4) ? addr_read_ifsram_r1_4 : addr_read_ifsram4 ;

	// ---- bank 5 ----
	assign cenwA_5  = (ifsram5b0_write && ~wr_row_parity) ? cen_write_ifsram_5 : 1'b1 ;
	assign cenwB_5  = (ifsram5b0_write &&  wr_row_parity) ? cen_write_ifsram_5 : 1'b1 ;
	assign wenwA_5  = (ifsram5b0_write && ~wr_row_parity) ? wen_write_ifsram_5 : 1'b1 ;
	assign wenwB_5  = (ifsram5b0_write &&  wr_row_parity) ? wen_write_ifsram_5 : 1'b1 ;
	assign addrwA_5 = addr_write_ifsram_5 ;
	assign addrwB_5 = addr_write_ifsram_5 ;
	assign dinwA_5  = (ifsram5b0_write) ? data_write_ifsram_5 : 64'd0 ;
	assign dinwB_5  = (ifsram5b0_write) ? data_write_ifsram_5 : 64'd0 ;

	assign cenrA_5  = (ifsram5b0_read) ? cen_read5 : 1'b1 ;
	assign cenrB_5  = (ifsram5b0_read) ? cen_read5 : 1'b1 ;
	assign addrrA_5 = (~row_group_sel5) ? addr_read_ifsram5 : addr_read_ifsram_r1_5 ;
	assign addrrB_5 = (~row_group_sel5) ? addr_read_ifsram_r1_5 : addr_read_ifsram5 ;

	// ---- bank 6 ----
	assign cenwA_6  = (if_pad_busy) ? if_pad_pdb6_cen  : (ifsram6b0_write && ~wr_row_parity) ? cen_write_ifsram_6 : 1'b1 ;
	assign cenwB_6  = (if_pad_busy) ? if_pad_pdb6_cen  : (ifsram6b0_write &&  wr_row_parity) ? cen_write_ifsram_6 : 1'b1 ;
	assign wenwA_6  = (if_pad_busy) ? if_pad_pdb6_wen  : (ifsram6b0_write && ~wr_row_parity) ? wen_write_ifsram_6 : 1'b1 ;
	assign wenwB_6  = (if_pad_busy) ? if_pad_pdb6_wen  : (ifsram6b0_write &&  wr_row_parity) ? wen_write_ifsram_6 : 1'b1 ;
	assign addrwA_6 = (if_pad_busy) ? if_pad_pdb6_addr : addr_write_ifsram_6 ;
	assign addrwB_6 = (if_pad_busy) ? if_pad_pdb6_addr : addr_write_ifsram_6 ;
	assign dinwA_6  = (ifsram6b0_write) ? data_write_ifsram_6 : 64'd0 ;
	assign dinwB_6  = (ifsram6b0_write) ? data_write_ifsram_6 : 64'd0 ;

	assign cenrA_6  = (if_pad_busy) ? if_pad_pdb6_cen  : (ifsram6b0_read) ? cen_read6 : 1'b1 ;
	assign cenrB_6  = (if_pad_busy) ? if_pad_pdb6_cen  : (ifsram6b0_read) ? cen_read6 : 1'b1 ;
	assign addrrA_6 = (if_pad_busy) ? if_pad_pdb6_addr : (~row_group_sel6) ? addr_read_ifsram6 : addr_read_ifsram_r1_6 ;
	assign addrrB_6 = (if_pad_busy) ? if_pad_pdb6_addr : (~row_group_sel6) ? addr_read_ifsram_r1_6 : addr_read_ifsram6 ;

	// ---- bank 7 ----
	assign cenwA_7  = (if_pad_busy) ? if_pad_pdb7_cen  : (ifsram7b0_write && ~wr_row_parity) ? cen_write_ifsram_7 : 1'b1 ;
	assign cenwB_7  = (if_pad_busy) ? if_pad_pdb7_cen  : (ifsram7b0_write &&  wr_row_parity) ? cen_write_ifsram_7 : 1'b1 ;
	assign wenwA_7  = (if_pad_busy) ? if_pad_pdb7_wen  : (ifsram7b0_write && ~wr_row_parity) ? wen_write_ifsram_7 : 1'b1 ;
	assign wenwB_7  = (if_pad_busy) ? if_pad_pdb7_wen  : (ifsram7b0_write &&  wr_row_parity) ? wen_write_ifsram_7 : 1'b1 ;
	assign addrwA_7 = (if_pad_busy) ? if_pad_pdb7_addr : addr_write_ifsram_7 ;
	assign addrwB_7 = (if_pad_busy) ? if_pad_pdb7_addr : addr_write_ifsram_7 ;
	assign dinwA_7  = (ifsram7b0_write) ? data_write_ifsram_7 : 64'd0 ;
	assign dinwB_7  = (ifsram7b0_write) ? data_write_ifsram_7 : 64'd0 ;

	assign cenrA_7  = (if_pad_busy) ? if_pad_pdb7_cen  : (ifsram7b0_read) ? cen_read7 : 1'b1 ;
	assign cenrB_7  = (if_pad_busy) ? if_pad_pdb7_cen  : (ifsram7b0_read) ? cen_read7 : 1'b1 ;
	assign addrrA_7 = (if_pad_busy) ? if_pad_pdb7_addr : (~row_group_sel7) ? addr_read_ifsram7 : addr_read_ifsram_r1_7 ;
	assign addrrB_7 = (if_pad_busy) ? if_pad_pdb7_addr : (~row_group_sel7) ? addr_read_ifsram_r1_7 : addr_read_ifsram7 ;

// ============================================================================
// =========================    Instance Module   =============================
// ============================================================================

`ifdef FPGA_SRAM_SETTING
	assign atlwA_cen_0 = ~cenwA_0 ; assign atlwB_cen_0 = ~cenwB_0 ;
	assign atlrA_cen_0 = ~cenrA_0 ; assign atlrB_cen_0 = ~cenrB_0 ;
	assign atl_wenA_0  = ~wenwA_0 ; assign atl_wenB_0  = ~wenwB_0 ;
	assign atlwA_cen_1 = ~cenwA_1 ; assign atlwB_cen_1 = ~cenwB_1 ;
	assign atlrA_cen_1 = ~cenrA_1 ; assign atlrB_cen_1 = ~cenrB_1 ;
	assign atl_wenA_1  = ~wenwA_1 ; assign atl_wenB_1  = ~wenwB_1 ;
	assign atlwA_cen_2 = ~cenwA_2 ; assign atlwB_cen_2 = ~cenwB_2 ;
	assign atlrA_cen_2 = ~cenrA_2 ; assign atlrB_cen_2 = ~cenrB_2 ;
	assign atl_wenA_2  = ~wenwA_2 ; assign atl_wenB_2  = ~wenwB_2 ;
	assign atlwA_cen_3 = ~cenwA_3 ; assign atlwB_cen_3 = ~cenwB_3 ;
	assign atlrA_cen_3 = ~cenrA_3 ; assign atlrB_cen_3 = ~cenrB_3 ;
	assign atl_wenA_3  = ~wenwA_3 ; assign atl_wenB_3  = ~wenwB_3 ;
	assign atlwA_cen_4 = ~cenwA_4 ; assign atlwB_cen_4 = ~cenwB_4 ;
	assign atlrA_cen_4 = ~cenrA_4 ; assign atlrB_cen_4 = ~cenrB_4 ;
	assign atl_wenA_4  = ~wenwA_4 ; assign atl_wenB_4  = ~wenwB_4 ;
	assign atlwA_cen_5 = ~cenwA_5 ; assign atlwB_cen_5 = ~cenwB_5 ;
	assign atlrA_cen_5 = ~cenrA_5 ; assign atlrB_cen_5 = ~cenrB_5 ;
	assign atl_wenA_5  = ~wenwA_5 ; assign atl_wenB_5  = ~wenwB_5 ;
	assign atlwA_cen_6 = ~cenwA_6 ; assign atlwB_cen_6 = ~cenwB_6 ;
	assign atlrA_cen_6 = ~cenrA_6 ; assign atlrB_cen_6 = ~cenrB_6 ;
	assign atl_wenA_6  = ~wenwA_6 ; assign atl_wenB_6  = ~wenwB_6 ;
	assign atlwA_cen_7 = ~cenwA_7 ; assign atlwB_cen_7 = ~cenwB_7 ;
	assign atlrA_cen_7 = ~cenrA_7 ; assign atlrB_cen_7 = ~cenrB_7 ;
	assign atl_wenA_7  = ~wenwA_7 ; assign atl_wenB_7  = ~wenwB_7 ;
`else
	assign atlwA_cen_0 = cenwA_0 ; assign atlwB_cen_0 = cenwB_0 ;
	assign atlrA_cen_0 = cenrA_0 ; assign atlrB_cen_0 = cenrB_0 ;
	assign atl_wenA_0  = wenwA_0 ; assign atl_wenB_0  = wenwB_0 ;
	assign atlwA_cen_1 = cenwA_1 ; assign atlwB_cen_1 = cenwB_1 ;
	assign atlrA_cen_1 = cenrA_1 ; assign atlrB_cen_1 = cenrB_1 ;
	assign atl_wenA_1  = wenwA_1 ; assign atl_wenB_1  = wenwB_1 ;
	assign atlwA_cen_2 = cenwA_2 ; assign atlwB_cen_2 = cenwB_2 ;
	assign atlrA_cen_2 = cenrA_2 ; assign atlrB_cen_2 = cenrB_2 ;
	assign atl_wenA_2  = wenwA_2 ; assign atl_wenB_2  = wenwB_2 ;
	assign atlwA_cen_3 = cenwA_3 ; assign atlwB_cen_3 = cenwB_3 ;
	assign atlrA_cen_3 = cenrA_3 ; assign atlrB_cen_3 = cenrB_3 ;
	assign atl_wenA_3  = wenwA_3 ; assign atl_wenB_3  = wenwB_3 ;
	assign atlwA_cen_4 = cenwA_4 ; assign atlwB_cen_4 = cenwB_4 ;
	assign atlrA_cen_4 = cenrA_4 ; assign atlrB_cen_4 = cenrB_4 ;
	assign atl_wenA_4  = wenwA_4 ; assign atl_wenB_4  = wenwB_4 ;
	assign atlwA_cen_5 = cenwA_5 ; assign atlwB_cen_5 = cenwB_5 ;
	assign atlrA_cen_5 = cenrA_5 ; assign atlrB_cen_5 = cenrB_5 ;
	assign atl_wenA_5  = wenwA_5 ; assign atl_wenB_5  = wenwB_5 ;
	assign atlwA_cen_6 = cenwA_6 ; assign atlwB_cen_6 = cenwB_6 ;
	assign atlrA_cen_6 = cenrA_6 ; assign atlrB_cen_6 = cenrB_6 ;
	assign atl_wenA_6  = wenwA_6 ; assign atl_wenB_6  = wenwB_6 ;
	assign atlwA_cen_7 = cenwA_7 ; assign atlwB_cen_7 = cenwB_7 ;
	assign atlrA_cen_7 = cenrA_7 ; assign atlrB_cen_7 = cenrB_7 ;
	assign atl_wenA_7  = wenwA_7 ; assign atl_wenB_7  = wenwB_7 ;
`endif

`ifdef FPGA_SRAM_SETTING
	BRAM_IF if0bA( .clka(clk), .clkb(clk), .ena(atlwA_cen_0), .enb(atlrA_cen_0), .wea(atl_wenA_0), .addra(addrwA_0), .addrb(addrrA_0), .dina(dinwA_0), .douta(), .doutb(doutrA_0) );
	BRAM_IF if0bB( .clka(clk), .clkb(clk), .ena(atlwB_cen_0), .enb(atlrB_cen_0), .wea(atl_wenB_0), .addra(addrwB_0), .addrb(addrrB_0), .dina(dinwB_0), .douta(), .doutb(doutrB_0) );
	BRAM_IF if1bA( .clka(clk), .clkb(clk), .ena(atlwA_cen_1), .enb(atlrA_cen_1), .wea(atl_wenA_1), .addra(addrwA_1), .addrb(addrrA_1), .dina(dinwA_1), .douta(), .doutb(doutrA_1) );
	BRAM_IF if1bB( .clka(clk), .clkb(clk), .ena(atlwB_cen_1), .enb(atlrB_cen_1), .wea(atl_wenB_1), .addra(addrwB_1), .addrb(addrrB_1), .dina(dinwB_1), .douta(), .doutb(doutrB_1) );
	BRAM_IF if2bA( .clka(clk), .clkb(clk), .ena(atlwA_cen_2), .enb(atlrA_cen_2), .wea(atl_wenA_2), .addra(addrwA_2), .addrb(addrrA_2), .dina(dinwA_2), .douta(), .doutb(doutrA_2) );
	BRAM_IF if2bB( .clka(clk), .clkb(clk), .ena(atlwB_cen_2), .enb(atlrB_cen_2), .wea(atl_wenB_2), .addra(addrwB_2), .addrb(addrrB_2), .dina(dinwB_2), .douta(), .doutb(doutrB_2) );
	BRAM_IF if3bA( .clka(clk), .clkb(clk), .ena(atlwA_cen_3), .enb(atlrA_cen_3), .wea(atl_wenA_3), .addra(addrwA_3), .addrb(addrrA_3), .dina(dinwA_3), .douta(), .doutb(doutrA_3) );
	BRAM_IF if3bB( .clka(clk), .clkb(clk), .ena(atlwB_cen_3), .enb(atlrB_cen_3), .wea(atl_wenB_3), .addra(addrwB_3), .addrb(addrrB_3), .dina(dinwB_3), .douta(), .doutb(doutrB_3) );
	BRAM_IF if4bA( .clka(clk), .clkb(clk), .ena(atlwA_cen_4), .enb(atlrA_cen_4), .wea(atl_wenA_4), .addra(addrwA_4), .addrb(addrrA_4), .dina(dinwA_4), .douta(), .doutb(doutrA_4) );
	BRAM_IF if4bB( .clka(clk), .clkb(clk), .ena(atlwB_cen_4), .enb(atlrB_cen_4), .wea(atl_wenB_4), .addra(addrwB_4), .addrb(addrrB_4), .dina(dinwB_4), .douta(), .doutb(doutrB_4) );
	BRAM_IF if5bA( .clka(clk), .clkb(clk), .ena(atlwA_cen_5), .enb(atlrA_cen_5), .wea(atl_wenA_5), .addra(addrwA_5), .addrb(addrrA_5), .dina(dinwA_5), .douta(), .doutb(doutrA_5) );
	BRAM_IF if5bB( .clka(clk), .clkb(clk), .ena(atlwB_cen_5), .enb(atlrB_cen_5), .wea(atl_wenB_5), .addra(addrwB_5), .addrb(addrrB_5), .dina(dinwB_5), .douta(), .doutb(doutrB_5) );
	BRAM_IF if6bA( .clka(clk), .clkb(clk), .ena(atlwA_cen_6), .enb(atlrA_cen_6), .wea(atl_wenA_6), .addra(addrwA_6), .addrb(addrrA_6), .dina(dinwA_6), .douta(), .doutb(doutrA_6) );
	BRAM_IF if6bB( .clka(clk), .clkb(clk), .ena(atlwB_cen_6), .enb(atlrB_cen_6), .wea(atl_wenB_6), .addra(addrwB_6), .addrb(addrrB_6), .dina(dinwB_6), .douta(), .doutb(doutrB_6) );
	BRAM_IF if7bA( .clka(clk), .clkb(clk), .ena(atlwA_cen_7), .enb(atlrA_cen_7), .wea(atl_wenA_7), .addra(addrwA_7), .addrb(addrrA_7), .dina(dinwA_7), .douta(), .doutb(doutrA_7) );
	BRAM_IF if7bB( .clka(clk), .clkb(clk), .ena(atlwB_cen_7), .enb(atlrB_cen_7), .wea(atl_wenB_7), .addra(addrwB_7), .addrb(addrrB_7), .dina(dinwB_7), .douta(), .doutb(doutrB_7) );
`else
	IF_SRAM  if0bA(.QA(), .QB(doutrA_0), .CLKA(clk), .CENA(atlwA_cen_0), .WENA(atl_wenA_0), .AA(addrwA_0), .DA(dinwA_0), .CLKB(clk), .CENB(atlrA_cen_0), .WENB(1'd1), .AB(addrrA_0), .DB('d0), .EMAA(3'd0), .EMAB(3'd0));
	IF_SRAM  if0bB(.QA(), .QB(doutrB_0), .CLKA(clk), .CENA(atlwB_cen_0), .WENA(atl_wenB_0), .AA(addrwB_0), .DA(dinwB_0), .CLKB(clk), .CENB(atlrB_cen_0), .WENB(1'd1), .AB(addrrB_0), .DB('d0), .EMAA(3'd0), .EMAB(3'd0));
	IF_SRAM  if1bA(.QA(), .QB(doutrA_1), .CLKA(clk), .CENA(atlwA_cen_1), .WENA(atl_wenA_1), .AA(addrwA_1), .DA(dinwA_1), .CLKB(clk), .CENB(atlrA_cen_1), .WENB(1'd1), .AB(addrrA_1), .DB('d0), .EMAA(3'd0), .EMAB(3'd0));
	IF_SRAM  if1bB(.QA(), .QB(doutrB_1), .CLKA(clk), .CENA(atlwB_cen_1), .WENA(atl_wenB_1), .AA(addrwB_1), .DA(dinwB_1), .CLKB(clk), .CENB(atlrB_cen_1), .WENB(1'd1), .AB(addrrB_1), .DB('d0), .EMAA(3'd0), .EMAB(3'd0));
	IF_SRAM  if2bA(.QA(), .QB(doutrA_2), .CLKA(clk), .CENA(atlwA_cen_2), .WENA(atl_wenA_2), .AA(addrwA_2), .DA(dinwA_2), .CLKB(clk), .CENB(atlrA_cen_2), .WENB(1'd1), .AB(addrrA_2), .DB('d0), .EMAA(3'd0), .EMAB(3'd0));
	IF_SRAM  if2bB(.QA(), .QB(doutrB_2), .CLKA(clk), .CENA(atlwB_cen_2), .WENA(atl_wenB_2), .AA(addrwB_2), .DA(dinwB_2), .CLKB(clk), .CENB(atlrB_cen_2), .WENB(1'd1), .AB(addrrB_2), .DB('d0), .EMAA(3'd0), .EMAB(3'd0));
	IF_SRAM  if3bA(.QA(), .QB(doutrA_3), .CLKA(clk), .CENA(atlwA_cen_3), .WENA(atl_wenA_3), .AA(addrwA_3), .DA(dinwA_3), .CLKB(clk), .CENB(atlrA_cen_3), .WENB(1'd1), .AB(addrrA_3), .DB('d0), .EMAA(3'd0), .EMAB(3'd0));
	IF_SRAM  if3bB(.QA(), .QB(doutrB_3), .CLKA(clk), .CENA(atlwB_cen_3), .WENA(atl_wenB_3), .AA(addrwB_3), .DA(dinwB_3), .CLKB(clk), .CENB(atlrB_cen_3), .WENB(1'd1), .AB(addrrB_3), .DB('d0), .EMAA(3'd0), .EMAB(3'd0));
	IF_SRAM  if4bA(.QA(), .QB(doutrA_4), .CLKA(clk), .CENA(atlwA_cen_4), .WENA(atl_wenA_4), .AA(addrwA_4), .DA(dinwA_4), .CLKB(clk), .CENB(atlrA_cen_4), .WENB(1'd1), .AB(addrrA_4), .DB('d0), .EMAA(3'd0), .EMAB(3'd0));
	IF_SRAM  if4bB(.QA(), .QB(doutrB_4), .CLKA(clk), .CENA(atlwB_cen_4), .WENA(atl_wenB_4), .AA(addrwB_4), .DA(dinwB_4), .CLKB(clk), .CENB(atlrB_cen_4), .WENB(1'd1), .AB(addrrB_4), .DB('d0), .EMAA(3'd0), .EMAB(3'd0));
	IF_SRAM  if5bA(.QA(), .QB(doutrA_5), .CLKA(clk), .CENA(atlwA_cen_5), .WENA(atl_wenA_5), .AA(addrwA_5), .DA(dinwA_5), .CLKB(clk), .CENB(atlrA_cen_5), .WENB(1'd1), .AB(addrrA_5), .DB('d0), .EMAA(3'd0), .EMAB(3'd0));
	IF_SRAM  if5bB(.QA(), .QB(doutrB_5), .CLKA(clk), .CENA(atlwB_cen_5), .WENA(atl_wenB_5), .AA(addrwB_5), .DA(dinwB_5), .CLKB(clk), .CENB(atlrB_cen_5), .WENB(1'd1), .AB(addrrB_5), .DB('d0), .EMAA(3'd0), .EMAB(3'd0));
	IF_SRAM  if6bA(.QA(), .QB(doutrA_6), .CLKA(clk), .CENA(atlwA_cen_6), .WENA(atl_wenA_6), .AA(addrwA_6), .DA(dinwA_6), .CLKB(clk), .CENB(atlrA_cen_6), .WENB(1'd1), .AB(addrrA_6), .DB('d0), .EMAA(3'd0), .EMAB(3'd0));
	IF_SRAM  if6bB(.QA(), .QB(doutrB_6), .CLKA(clk), .CENA(atlwB_cen_6), .WENA(atl_wenB_6), .AA(addrwB_6), .DA(dinwB_6), .CLKB(clk), .CENB(atlrB_cen_6), .WENB(1'd1), .AB(addrrB_6), .DB('d0), .EMAA(3'd0), .EMAB(3'd0));
	IF_SRAM  if7bA(.QA(), .QB(doutrA_7), .CLKA(clk), .CENA(atlwA_cen_7), .WENA(atl_wenA_7), .AA(addrwA_7), .DA(dinwA_7), .CLKB(clk), .CENB(atlrA_cen_7), .WENB(1'd1), .AB(addrrA_7), .DB('d0), .EMAA(3'd0), .EMAB(3'd0));
	IF_SRAM  if7bB(.QA(), .QB(doutrB_7), .CLKA(clk), .CENA(atlwB_cen_7), .WENA(atl_wenB_7), .AA(addrwB_7), .DA(dinwB_7), .CLKB(clk), .CENB(atlrB_cen_7), .WENB(1'd1), .AB(addrrB_7), .DB('d0), .EMAA(3'd0), .EMAB(3'd0));
`endif


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
	,	.wr_row_parity	(	wr_row_parity		)
	
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
	
	,	.cen_reads_ifsram    (cen_read)
    ,	.cen_reads_ifsram_r1 (cen_read_r1) 
	
    ,	.addr_read_ifsram    (addr_read_ifsram)
	,	.addr_read_ifsram_r1 (addr_read_ifsram_r1) 
	
    ,	.current_state       (if_read_current_state)
	,	.row_finish 	     (row_finish)
	,	.dy2_conv_finish	 (dy2_conv_finish)
	
	//--------config input setting-----------
	,	.cfg_window				(	rcfg_ifr_window	)	
    ,	.cfg_atlchin			(	rcfg_atlchin		)		
	,	.cfg_kernel_repeat		(	rcfg_ifr_kernel_repeat	)
	,	.row_number				(	ifr_row_number	)
	,	.rd_row_parity			(	row_group_sel_w	)
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
	,	.pd_data		(						)
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

`ifdef FPGA_ILA_CHK_SETTING
	output wire [  IFMAP_SRAM_ADDBITS-1  :   0   ] ick_addrb_sram_if0b0		;
	assign ick_addrb_sram_if0b0 = addrrA_0	;  // post dual-bank rework: bank0 group-A read address
`endif 

endmodule