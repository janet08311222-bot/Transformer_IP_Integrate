// ============================================================================
// Designer : Chao_Ping Liu
// Create   : 2025.06.26
// Ver      : 1.0
// Func     : FFN top module 
//  	----parameter reset active low -- https://youtu.be/KyQuVydW1n8
//  	----high fanout pin fixed by DC synthesis, do not code buffer.
//  	----get_ins module : distinguish data or instruction for this time.
//  	----signal port naming : should not use common port name for every top module port naming.
//  	----output signal tips : should not use output signal for flow controlling like "busy".
// Log		: 
// ============================================================================
//----    define for testing    -----
// `define FPGA_SRAM_SETTING
`define FPGA_ILA_CHK_SETTING

module Transformer_top #(
        parameter TBITS = 64
    ,   parameter TBYTE = 8
)(
        clk
    ,   resetn
	,	S_AXIS_MM2S_TVALID	
	,	S_AXIS_MM2S_TREADY	
	,	S_AXIS_MM2S_TDATA	
	,	S_AXIS_MM2S_TKEEP	
	,	S_AXIS_MM2S_TLAST	

	,	M_AXIS_S2MM_TVALID	
	,	M_AXIS_S2MM_TREADY	
	,	M_AXIS_S2MM_TDATA	
	,	M_AXIS_S2MM_TKEEP	
	,	M_AXIS_S2MM_TLAST	

`ifdef FPGA_ILA_CHK_SETTING

    ,   SA_busy
    ,   SOFTMAX_busy
    ,   NORM_busy
    ,   FFN_busy

`endif

);

    // ============================= I/O port Declare ===============================
    
    input wire clk	;
    input wire resetn	;

    input  wire 			S_AXIS_MM2S_TVALID	;
    output wire 			S_AXIS_MM2S_TREADY	;
    input  wire [TBITS-1:0]	S_AXIS_MM2S_TDATA	;
    input  wire [TBYTE-1:0]	S_AXIS_MM2S_TKEEP	;
    input  wire 			S_AXIS_MM2S_TLAST	;

    output wire             M_AXIS_S2MM_TVALID	;
    input  wire             M_AXIS_S2MM_TREADY	;
    output wire [TBITS-1:0] M_AXIS_S2MM_TDATA	;
    output wire [TBYTE-1:0] M_AXIS_S2MM_TKEEP	;
    output wire [1-1:0]     M_AXIS_S2MM_TLAST	;
    
    //-----------------------------------------------------------------------------
    //----    FPGA ILA Check I/O    -----
    `ifdef FPGA_ILA_CHK_SETTING

        output  SA_busy        ;
        output  SOFTMAX_busy   ;
        output  NORM_busy      ;
        output  FFN_busy       ;

    `endif
    //-----------------------------------------------------------------------------

    wire    reset ;
    assign  reset = ~resetn ;

    //-- input fifo signal --
    wire [TBITS-1: 0 ]	isif_data_dout			;
    wire 				isif_last_dout			;
    wire 				isif_empty_n			;
    wire [TBYTE-1: 0 ]	isif_strb_dout			;
    wire 				isif_user_dout			;
    wire 				isif_read				;
    //-- output fifo signal --
    wire 				osif_full_n				;
    wire 				osif_write			    ;
    wire [TBITS-1: 0 ]	osif_data_din			;
    wire 				osif_last_din			;
    wire [TBYTE-1: 0 ]	osif_strb_din			;
    wire 				osif_user_din			;

    //-- FSM signal --
    wire [ 3-1 : 0 ] curr_state     ;
    wire [   1 : 0 ] mode           ;
    wire 			 isif_read_FSM	;

    wire 				SA_start		;
    wire 				SOFTMAX_start	;
    wire 				NORM_start		;
    wire 				FFN_start		;

    wire 				SA_busy        ;
    wire 				SOFTMAX_busy   ;
    wire                NORM_busy      ;
    wire 				FFN_busy	   ;

    wire                SA_done        ;
    wire                SOFTMAX_done   ;
    wire                NORM_done      ;
    wire 				FFN_done	   ;

    //-- SA input fifo signal --
    wire [TBITS-1: 0 ]	SA_isif_data_dout			;
    wire 				SA_isif_last_dout			;
    wire 				SA_isif_empty_n			    ;
    wire [TBYTE-1: 0 ]	SA_isif_strb_dout			;
    wire 				SA_isif_user_dout			;
    wire 				SA_isif_read				;
    //-- SA output fifo signal --
    wire 				SA_osif_full_n				;
    wire 				SA_osif_write				;
    wire [TBITS-1: 0 ]	SA_osif_data_din		    ;
    wire 				SA_osif_last_din		    ;
    wire [TBYTE-1: 0 ]	SA_osif_strb_din			;
    wire 				SA_osif_user_din			;

    //-- SOFTMAX input fifo signal --
    wire [TBITS-1: 0 ]	SOFTMAX_isif_data_dout		;
    wire 				SOFTMAX_isif_last_dout		;
    wire 				SOFTMAX_isif_empty_n		;
    wire [TBYTE-1: 0 ]	SOFTMAX_isif_strb_dout		;
    wire 				SOFTMAX_isif_user_dout		;
    wire 				SOFTMAX_isif_read			;
    //-- SOFTMAX output fifo signal --
    wire 				SOFTMAX_osif_full_n			;
    wire 				SOFTMAX_osif_write			;
    wire [TBITS-1: 0 ]	SOFTMAX_osif_data_din		;
    wire 				SOFTMAX_osif_last_din		;
    wire [TBYTE-1: 0 ]	SOFTMAX_osif_strb_din		;
    wire 				SOFTMAX_osif_user_din		;

    //-- NORM input fifo signal --
    wire [TBITS-1: 0 ]	NORM_isif_data_dout			;
    wire 				NORM_isif_last_dout			;
    wire 				NORM_isif_empty_n			;
    wire [TBYTE-1: 0 ]	NORM_isif_strb_dout			;
    wire 				NORM_isif_user_dout			;
    wire 				NORM_isif_read				;
    //-- NORM output fifo signal --
    wire 				NORM_osif_full_n			;
    wire 				NORM_osif_write				;
    wire [TBITS-1: 0 ]	NORM_osif_data_din		    ;
    wire 				NORM_osif_last_din		    ;
    wire [TBYTE-1: 0 ]	NORM_osif_strb_din			;
    wire 				NORM_osif_user_din			;

    //-- FFN input fifo signal --
    wire [TBITS-1: 0 ]	FFN_isif_data_dout			;
    wire 				FFN_isif_last_dout			;
    wire 				FFN_isif_empty_n			;
    wire [TBYTE-1: 0 ]	FFN_isif_strb_dout			;
    wire 				FFN_isif_user_dout			;
    wire 				FFN_isif_read				;
    //-- FFN output fifo signal --
    wire 				FFN_osif_full_n				;
    wire 				FFN_ot2fifo_write			;
    wire [TBITS-1: 0 ]	FFN_ot2fifo_data			;
    wire 				FFN_ot2fifo_last			;
    wire [TBYTE-1: 0 ]	FFN_osif_strb_din			;
    wire 				FFN_osif_user_din			;

	localparam SA       = 3'd4 ;
	localparam SOFTMAX  = 3'd5 ;
	localparam NORM     = 3'd6 ;
    localparam FFN      = 3'd7 ;

    localparam MODE_SA      = 2'd0 ;
    localparam MODE_SOFTMAX = 2'd1 ;
    localparam MODE_NORM    = 2'd2 ;
    localparam MODE_FFN     = 2'd3 ;

    //-- fifo signal assign --
    assign  isif_read = (curr_state == SA)      ? SA_isif_read :
                        (curr_state == SOFTMAX) ? SOFTMAX_isif_read :
                        (curr_state == NORM)    ? NORM_isif_read :
                        (curr_state == FFN)     ? FFN_isif_read :
                                                  isif_read_FSM ;

    assign  osif_data_din = (mode == MODE_SA)       ? SA_osif_data_din :
                            (mode == MODE_SOFTMAX)  ? SOFTMAX_osif_data_din :
                            (mode == MODE_NORM)     ? NORM_osif_data_din :
                            (mode == MODE_FFN)      ? FFN_ot2fifo_data :
                                                      'd0 ;
    assign  osif_last_din = (mode == MODE_SA)       ? SA_osif_last_din :
                            (mode == MODE_SOFTMAX)  ? SOFTMAX_osif_last_din :
                            (mode == MODE_NORM)     ? NORM_osif_last_din :
                            (mode == MODE_FFN)      ? FFN_ot2fifo_last :
                                                      'd0 ;
    assign  osif_write    = (mode == MODE_SA)       ? SA_osif_write :
                            (mode == MODE_SOFTMAX)  ? SOFTMAX_osif_write :
                            (mode == MODE_NORM)     ? NORM_osif_write :
                            (mode == MODE_FFN)      ? FFN_ot2fifo_write :
                                                      'd0 ;

    //-- Transformer top SA assign --
    assign SA_isif_data_dout = (SA_busy) ? isif_data_dout : 'd0 ;
    assign SA_isif_last_dout = (SA_busy) ? isif_last_dout : 'd0 ;
    assign SA_isif_empty_n   = (SA_busy) ? isif_empty_n   : 'd0 ;
    assign SA_isif_strb_dout = (SA_busy) ? isif_strb_dout : 'd0 ;
    assign SA_isif_user_dout = (SA_busy) ? isif_user_dout : 'd0 ;

    assign SA_osif_full_n    = (mode == MODE_SA) ? osif_full_n : 'd1 ;

    //-- Transformer top SOFTMAX assign --
    assign SOFTMAX_isif_data_dout = (SOFTMAX_busy) ? isif_data_dout : 'd0 ;
    assign SOFTMAX_isif_last_dout = (SOFTMAX_busy) ? isif_last_dout : 'd0 ;
    assign SOFTMAX_isif_empty_n   = (SOFTMAX_busy) ? isif_empty_n   : 'd0 ;
    assign SOFTMAX_isif_strb_dout = (SOFTMAX_busy) ? isif_strb_dout : 'd0 ;
    assign SOFTMAX_isif_user_dout = (SOFTMAX_busy) ? isif_user_dout : 'd0 ;

    assign SOFTMAX_osif_full_n    = (mode == MODE_SOFTMAX) ? osif_full_n : 'd1 ;

    //-- Transformer top NORM assign --
    assign NORM_isif_data_dout = (NORM_busy) ? isif_data_dout : 'd0 ;
    assign NORM_isif_last_dout = (NORM_busy) ? isif_last_dout : 'd0 ;
    assign NORM_isif_empty_n   = (NORM_busy) ? isif_empty_n   : 'd0 ;
    assign NORM_isif_strb_dout = (NORM_busy) ? isif_strb_dout : 'd0 ;
    assign NORM_isif_user_dout = (NORM_busy) ? isif_user_dout : 'd0 ;

    assign NORM_osif_full_n    = (mode == MODE_NORM) ? osif_full_n : 'd1 ;
    
    //-- Transformer top FFN assign --
    assign  FFN_isif_data_dout  = (FFN_busy) ? isif_data_dout  : 'd0    ;
    assign  FFN_isif_last_dout  = (FFN_busy) ? isif_last_dout  : 'd0     ;
    assign  FFN_isif_empty_n    = (FFN_busy) ? isif_empty_n    : 'd0     ;
    assign  FFN_isif_strb_dout  = (FFN_busy) ? isif_strb_dout  : 'd0     ;
    assign  FFN_isif_user_dout  = (FFN_busy) ? isif_user_dout  : 'd0     ;

    assign  FFN_osif_full_n     = (mode == MODE_FFN) ? osif_full_n     : 'd1     ;
 
    // ===========================================================================
    // =======		instance 	==================================================
    // ===========================================================================

	INPUT_STREAM_if	#(
			.TBITS	(	TBITS	)
		,	.TBYTE	(	TBYTE	)
	)axififo_in(
		// AXI4-Stream singals
			.ACLK       (	clk		)
		,	.ARESETN    (	resetn	)
		,	.TVALID     (	S_AXIS_MM2S_TVALID	)
		,	.TREADY     (	S_AXIS_MM2S_TREADY	)
		,	.TDATA      (	S_AXIS_MM2S_TDATA	)
		,	.TKEEP      (	S_AXIS_MM2S_TKEEP	)
		,	.TLAST      (	S_AXIS_MM2S_TLAST	)
		// ,	.TUSER      (   1'b0                )

		// User signals
		,	.isif_data_dout         (	isif_data_dout		)
		,	.isif_strb_dout         (	isif_strb_dout		)
		,	.isif_last_dout         (	isif_last_dout		)
		,	.isif_user_dout         (	isif_user_dout		)
		,	.isif_empty_n           (	isif_empty_n		)
		,	.isif_read				(	isif_read			)
	);

    Transformer_FSM  #(
            .TBITS  (   TBITS   )
        ,   .TBYTE  (   TBYTE   )
    ) Transformer_FSM_inst (
            .clk     (   clk     )
        ,	.reset   (   reset   )

        ,	.fifo_data_din       (   isif_data_dout      )
        ,	.fifo_strb_din       (   isif_strb_dout      )
        ,	.fifo_last_din       (   isif_last_dout      )
        ,	.fifo_user_din       (   isif_user_dout      )
        ,	.fifo_empty_n_din    (   isif_empty_n        )
        ,	.fifo_read_dout      (   isif_read_FSM       )

        ,   .fifo_read_din       (   isif_read           )

        ,	.SA_busy             (   SA_busy             )
        ,	.SOFTMAX_busy        (   SOFTMAX_busy        )
        ,	.NORM_busy           (   NORM_busy           )
        ,	.FFN_busy            (   FFN_busy            )

        ,   .SA_done            (   SA_done            )
        ,   .SOFTMAX_done       (   SOFTMAX_done       )
        ,   .NORM_done          (   NORM_done          )
        ,   .FFN_done           (   FFN_done           )

        ,   .curr_state          (   curr_state          )
        ,   .mode                (   mode                )
    );

    dla512_top #(
		.TBITS  (   TBITS	) 
	,	.TBYTE  (   TBYTE	)
    ) SA_top_inst (
            .clk        (   clk     )
        ,	.resetn	    (   resetn  )

        ,   .rdwd_done  (   SA_done   )

        ,	.M_AXIS_S2MM_TREADY (   M_AXIS_S2MM_TREADY    )

        ,	.isif_data_dout (   SA_isif_data_dout   )
        ,	.isif_strb_dout	(   SA_isif_strb_dout   )
        ,	.isif_last_dout	(   SA_isif_last_dout   )
        ,	.isif_user_dout	(   SA_isif_user_dout   )
        ,	.isif_empty_n	(   SA_isif_empty_n     )
        ,	.isif_read      (   SA_isif_read        )
        
        ,	.osif_data_din  (   SA_osif_data_din    )
        ,	.osif_last_din  (   SA_osif_last_din    )
        ,	.osif_write     (   SA_osif_write       )
        ,	.osif_full_n    (   SA_osif_full_n      )
    );
    
   addnormtop #(
        .TBITS  ( 8 )
    ) dut_addnorm (
        .clk				(	clk          )
    ,   .reset				(	resetn       )

    ,   .NORM_done          (	NORM_done    )

    ,   .input_ready		(	M_AXIS_S2MM_TREADY    )
    ,   .in_valid			(	NORM_isif_empty_n     )
    ,   .in_last			(	NORM_isif_last_dout   )
    ,   .in_data            (	NORM_isif_data_dout   )

    ,   .output_ready		(	NORM_isif_read        )
    ,   .out_data			(	NORM_osif_data_din    )
	,	.out_last   		(   NORM_osif_last_din    )
    ,   .out_valid			(	NORM_osif_write       )
    );		 


    softmax_top softmax_top_inst (
            .clk    (   clk     )
        ,   .rst    (   reset   )

        ,   .softmax_done   (   SOFTMAX_done        )

        ,	.SOFT_INPUT	    (    SOFTMAX_isif_data_dout    )
        ,	.valid_in	    (    SOFTMAX_isif_empty_n      )
        ,	.hw_ready	    (    SOFTMAX_isif_read         )
        ,	.out_ready	    (    SOFTMAX_osif_full_n      )
        ,	.valid_out		(    SOFTMAX_osif_write       )
        ,	.SOFT_OUT	    (    SOFTMAX_osif_data_din    )
        ,	.osif_last_din	(    SOFTMAX_osif_last_din    )
    );

    FFN_top #(
            .TBITS  (   TBITS   )
        ,   .TBYTE  (   TBYTE   )
    ) FFN_top_inst (
            .clk     (   clk     )
        ,   .resetn  (   resetn  )

        ,   .FFN_done    (   FFN_done    )

        ,   .M_AXIS_S2MM_TREADY    (   M_AXIS_S2MM_TREADY    )

        ,	.isif_data_dout	(    FFN_isif_data_dout    )
        ,	.isif_last_dout	(    FFN_isif_last_dout    )
        ,	.isif_empty_n	(    FFN_isif_empty_n      )
        ,	.isif_strb_dout	(    FFN_isif_strb_dout    )
        ,	.isif_user_dout (    FFN_isif_user_dout    )
        ,	.isif_read	    (    FFN_isif_read         )

        ,	.osif_full_n	(    FFN_osif_full_n       )
        ,	.ot2fifo_write	(    FFN_ot2fifo_write     )
        ,	.ot2fifo_data	(    FFN_ot2fifo_data      )
        ,	.ot2fifo_last	(    FFN_ot2fifo_last      )
        ,	.osif_strb_din	(    FFN_osif_strb_din     )
        ,	.osif_user_din	(    FFN_osif_user_din     )

    );

	OUTPUT_STREAM_if #(
			.TBITS  (   TBITS   ) 
		,	.TBYTE  (   TBYTE   )
	)axififo_out(
			.ACLK       (   clk 	) 
		,	.ARESETN    (   resetn  ) 
		,	.TVALID     (   M_AXIS_S2MM_TVALID  ) 
		,	.TREADY     (   M_AXIS_S2MM_TREADY  ) 
		,	.TDATA      (   M_AXIS_S2MM_TDATA   ) 
		,	.TKEEP      (   M_AXIS_S2MM_TKEEP   ) 
		,	.TLAST      (   M_AXIS_S2MM_TLAST   )     
		// ,   .TUSER      (                       )

		,	.osif_data_din  (   osif_data_din   ) 
		,	.osif_strb_din  (   8'hff           ) 
		,	.osif_last_din  (   osif_last_din   ) 
		,	.osif_user_din  (   1'b0            ) 
		,	.osif_full_n    (   osif_full_n     ) 
		,	.osif_write     (   osif_write      ) 
	);

endmodule