// ============================================================================
// Designer : Wei-Xuan Luo
// Create   : 2022.11.17
// Ver      : 1.0
// Func     : input feature sram read module
// Log  (Wen-Jia Yang) :--2023.09.08  fix input col >32 
// ============================================================================



module ifsram_r #(
        parameter TBITS = 64 
    ,   parameter TBYTE = 8
	,   parameter IFMAP_SRAM_ADDBITS = 11 	
)(
        clk	
    ,   reset	

    //=========for sche=============   
    ,   if_read_start		
    ,   if_read_busy		
    ,   if_read_done		

    // ,   valid_0		,   final_0   //----signal for SRAM_0---------
    // ,   valid_1		,   final_1   //----signal for SRAM_1---------
    // ,   valid_2		,   final_2   //----signal for SRAM_2---------
    // ,   valid_3		,   final_3   //----signal for SRAM_3---------
    // ,   valid_4		,   final_4   //----signal for SRAM_4---------
    // ,   valid_5		,   final_5   //----signal for SRAM_5---------
    // ,   valid_6		,   final_6   //----signal for SRAM_6---------
    // ,   valid_7		,   final_7   //----signal for SRAM_7---------

    //=============for sram ============
    ,   cen_reads_ifsram	
    ,   addr_read_ifsram		
    ,   current_state		
    ,   row_finish	
    ,   dy2_conv_finish
    //=========cfg input signal
    ,   cfg_window			
    ,   cfg_atlchin		 // 32/8 = 4
    ,   cfg_kernel_repeat
    //===== for ch 8
    ,   row_number

    
);

//----------------------------------------------------------------------------
//---------------		I/O	Declare		--------------------------------------
//----------------------------------------------------------------------------

    input wire                          clk	                ;
    input wire                          reset               ;
    input wire                          if_read_start       ;		
    output reg                          if_read_busy	    ;	
    output reg                          if_read_done	    ;

    output wire                         cen_reads_ifsram    ;	
    output reg [IFMAP_SRAM_ADDBITS-1:0] addr_read_ifsram	;	
    input  wire [2:0]                   current_state		;
    output reg                          row_finish	        ;
    output reg                          dy2_conv_finish     ;

    //=====cfg input signal
    input  wire [7:0]		cfg_window			;
    input  wire [8-1:0]		cfg_atlchin		    ;   // 32/8 = 4
    input  wire [7:0]       cfg_kernel_repeat   ;


//============   parameter  ===================
    // parameter WINDOW = 4;
    // parameter CH  = 4; // 32/8 = 4
	localparam [2:0] 
		IDLE          = 3'd0,
		UP_PADDING    = 3'd1,
		ROW_ADDR_012  = 3'd2,   
		ROW_ADDR_123  = 3'd3, 
		ROW_ADDR_230  = 3'd4,
		ROW_ADDR_301  = 3'd5,
		DOWN_PADDING  = 3'd6;
    localparam [1:0] 
        IR_IDLE = 2'd0,
        IR_READ = 2'd1;

//============  reg & wire ============
    reg [1:0] next_state;   
    reg [1:0] c_state;
    wire done_flag;
    reg cen0;
    reg [5:0] row;
    reg [5:0] col_oft ;
    wire  col_oft_last ;
    // reg [2:0] ch;
    wire [7:0] ch;   //YWJ
    wire  ch_last; 
    reg [6:0] current_window; 
    output  reg [1:0] row_number;
    reg col_finish;
    reg [IFMAP_SRAM_ADDBITS-1:0] addr;    
	wire local_done_flag;
	reg row_index;

    reg [IFMAP_SRAM_ADDBITS-1:0] row_offset;  
    reg [10:0] col_offset;
    reg [7:0] ch_offset;
    wire [10:0]addrtt; 

    reg col_oft_start;      //YWJ
    wire enable_col_oft ;
    wire enable_ch ;   

    wire [8-1:0] fn_count ; //HYR

//=========== busy & done control ===========
    always @(posedge clk ) begin
        if(reset) 
            c_state <= 2'd0;
        else 
            c_state <= next_state;
    end

    always @(*) begin
        case (c_state)
            IR_IDLE: next_state = (if_read_start) ? IR_READ : IR_IDLE ;
            IR_READ: next_state = (local_done_flag)  ? IR_IDLE : IR_READ ;
            default: next_state = IR_IDLE ;
        endcase	
    end
    reg read_busy;
    reg dy0_read_busy;

    always @( * ) begin
        read_busy = ( c_state == IR_READ) ? 1'd1 : 1'd0 ;
    end
    always @( posedge clk ) begin
        if(reset)begin
            dy0_read_busy <= 0;
            if_read_busy <= 0;
        end
        else begin
            dy0_read_busy <= read_busy;
            if_read_busy <= dy0_read_busy;
        end 
    end


    always @( * ) begin
        cen0 = ( c_state == IR_READ) ? 1'd1 : 1'd0 ;
    end
    wire conv_finish;
    reg dy_cen0_0;
    reg dy_cen0_1;
    reg dy0_window_finish;
    reg dy1_window_finish;
    reg dy2_window_finish;
    always @( posedge clk ) begin
        if(reset)begin
            dy_cen0_0 <= 0;
            dy_cen0_1 <= 0;
        end
        else begin
            dy_cen0_0 <= cen0;
            dy_cen0_1 <= dy_cen0_0;
        end   
    end

    always @ (*)begin
        if(done_flag) 
            if_read_done = 1;
        else
            if_read_done = 0;
    end

    reg window_finish;
    reg dy0_conv_finish;
    reg dy1_conv_finish;
    //reg dy2_conv_finish;
   
    
    // always @ (*)begin 
    //     if(dy2_conv_finish)begin
    //         if(current_state == UP_PADDING || current_state == DOWN_PADDING)
    //             done_flag <= 1;
    //         else if(current_state >= ROW_ADDR_012 && current_state <= ROW_ADDR_301)
    //             done_flag <= 1;
    //         else
    //             done_flag <= done_flag;
    //     end
    //     else
    //         done_flag <= 0;
    // end

    assign done_flag = (current_state >= 1 && current_state <= 6)? (dy2_conv_finish)? 1 : 0 : 0;

    
    // always @ (*)begin 
    //     if(conv_finish)begin
    //         if(current_state == UP_PADDING || current_state == DOWN_PADDING)
    //             local_done_flag <= 1;
    //         else if(current_state >= ROW_ADDR_012 && current_state <= ROW_ADDR_301)
    //             local_done_flag <= 1;
    //         else
    //             local_done_flag <= local_done_flag;
    //     end
    //     else
    //         local_done_flag <= 0;
    // end


    assign local_done_flag = (current_state >= 1 && current_state <= 6)? (conv_finish)? 1 : 0 : 0;

//============  sram control  =========
    assign cen_reads_ifsram = ~dy_cen0_1;


    always @ (*) begin
        addr_read_ifsram = (dy_cen0_1) ? addr : 0;
    end
    
    always @ (posedge clk) begin
        if(reset) begin
            addr <= 0;
        end
        else begin
            addr <= row_offset + col_offset + ch_offset;
        end
    end
    // assign addrtt = row*cfg_window*3*cfg_atlchin + (current_window*3 + col_oft)*cfg_atlchin + ch;
    //row offset
    always @ (posedge clk) begin
        if(reset)
            row_offset <= 0;
        // else if(c_state == 1)
        //     row_offset <= row*cfg_window*3*cfg_atlchin;
        else if(c_state == 1)
            row_offset <= row*cfg_window*cfg_atlchin;  //20251016
        else if(c_state == 0)
            row_offset <= 0;
        else    
            row_offset <= row_offset;
    end
    //col_offset
    always @ (posedge clk) begin
        if(reset)
            col_offset <= 0;
        else if(c_state == 1)
            col_offset <= (current_window*3 + col_oft)*cfg_atlchin;
        else if(c_state == 0)
            col_offset <= 0;
        else    
            col_offset <= col_offset;
    end
    //channel offset
    always @ (posedge clk) begin
        if(reset)
            ch_offset <= 0;
        else if(c_state == 1)
            ch_offset <= ch;
        else if(c_state == 0)
            ch_offset <= 0;
        else    
            ch_offset <= ch_offset;
    end   
//---------  index control  --------
//*********  repeat control  **************  

    reg [7:0] repeat_window;

    always @ (posedge clk) begin
        if(reset)
            repeat_window <= 0;
        else if(conv_finish)
            repeat_window <= 0;
        else if(c_state == IR_READ && window_finish)
            repeat_window <= repeat_window + 1;
        else 
            repeat_window <= repeat_window;
    end

    assign conv_finish = (window_finish && repeat_window == cfg_kernel_repeat) ? 1 : 0;

    always @ (posedge clk) begin
        if(reset)begin
            dy0_conv_finish <= 0;
            dy1_conv_finish <= 0;
            dy2_conv_finish <= 0;
        end
        else begin
            dy0_conv_finish <= conv_finish;
            dy1_conv_finish <= dy0_conv_finish;
            dy2_conv_finish <= dy1_conv_finish;
        end
    end



//*********  channel control  **************  
    count_yi_v4 #(
        .BITS_OF_END_NUMBER (	8	)
    )ifr_ch(
        .clk		( clk )
        ,	.reset 	 		(	reset	)
        ,	.enable	 		(	enable_ch	)

	    ,	.final_number	(	fn_count	)
	    ,	.last			(	ch_last	)
        ,	.total_q		(	ch	)
    );

    assign fn_count = cfg_atlchin-1 ;// final number value for counter
    assign enable_ch = ((cfg_atlchin > 1) && cen0) ? 1'd1 : 1'd0 ;

    // always @ (posedge clk) begin
    //     if(reset)
    //         ch <= 0;
    //     else if(ch == (cfg_atlchin-1))
    //         ch <= 0;
    //     else if (cen0)
    //         ch <= ch + 3'd1;
    //     else 
    //         ch <= ch;
    // end


//*********  window control  **************    
    always @ (posedge clk) begin
        if(reset)
            current_window <= 0;
        else if(current_window == cfg_window-1 && row_finish)
            current_window <= 0;
        else if(c_state == IR_READ && row_finish)
            current_window <= current_window + 1; 
        else    
            current_window <= current_window;
    end

    always @ (*) begin
        if(row_finish && current_window == cfg_window-1)
            window_finish = 1;
        else    
            window_finish = 0;
    end

    //assign window_finish = (row_finish && current_window == cfg_window-1) ? 1'd1 : 1'd0 ;
    
    always @ (posedge clk) begin
        if(reset)begin
            dy0_window_finish <= 0;
            dy1_window_finish <= 0;
            dy2_window_finish <= 0;
        end
        else begin
            dy0_window_finish <= window_finish;
            dy1_window_finish <= dy0_window_finish;
            dy2_window_finish <= dy1_window_finish;
        end
    end


//*********  col control  **************  
    always @ (posedge clk) begin
        if(reset) begin
            col_oft_start <= 0;
        end
        else if(conv_finish) begin
            col_oft_start <= 0;
        end
        else if(if_read_start) begin
            col_oft_start <= 1;
        end
        else begin
            col_oft_start <= col_oft_start;
        end
    end

    // count_yi_v4 #(
    //     .BITS_OF_END_NUMBER (	6	)
    // )ifr_col_oft(
    //     .clk		( clk )
    //     ,	.reset 	 		(	reset	)
    //     ,	.enable	 		(	enable_col_oft	)

	//     ,	.final_number	(	2	)
	//     ,	.last			(	col_oft_last	)
    //     ,	.total_q		(	col_oft	)
    // );

    // assign enable_col_oft = (col_oft_start && (ch == (cfg_atlchin-1))) ? 1'd1 : 1'd0 ;
    // assign col_finish = (col_oft_last && ch == (cfg_atlchin-1)) ? 1'd1 : 1'd0 ;


    always @ (posedge clk) begin
        if(reset) begin
            col_oft <= 0;
        end
        else if(col_finish) begin
            col_oft <= 0;
        end
        else if (col_oft_start) begin
            if(ch == (cfg_atlchin-1)) begin
                col_oft <= col_oft + 1;
            end
            else begin
                col_oft <= col_oft;
            end
        end
        else begin
            col_oft <= col_oft;
        end
    end

    always @ (*) begin
        if(col_oft == 0 && ch == (cfg_atlchin-1)) //20250711 col_oft 2 to 0 
            col_finish = 1;
        else
            col_finish = 0;
    end

//*********  row control  **************  
    always @ (posedge clk ) begin
        if(reset)
            row_number <= 0;
        else if(col_finish)begin
            if(cfg_atlchin > 1) begin
                if((current_state == UP_PADDING || current_state == DOWN_PADDING) && row_number == 0) //row_number == 1 20250711
                    row_number <= 0;
                else if((current_state >= ROW_ADDR_012 && current_state <= ROW_ADDR_301) && row_number == 0) //row_number == 2 20250711
                    row_number <= 0;
                else
                    row_number <= row_number + 1;
            end
            else begin
                if((current_state == UP_PADDING || current_state == DOWN_PADDING) && row_number == 2)
                    row_number <= 0;
                else if((current_state >= ROW_ADDR_012 && current_state <= ROW_ADDR_301) && row_number == 2)
                    row_number <= 0;
                else
                    row_number <= row_number + 1;
            end
        end
        else
            row_number <= row_number;
    end

    always @ (*) begin
        if(current_state == UP_PADDING)begin
            if(row_number == 0) 
                row = 0;
            else if(row_number == 1)
                row = 1; 
            else
                row = 0;                    //avoiding latch
        end
        else if(current_state == ROW_ADDR_012)begin
            if(row_number == 0) 
                row = 1;
            else if(row_number == 1)
                row = 1;
            else if(row_number == 2)
                row = 2;
            else
                row = 1;     //20251016 LYC
            // else
            //     row = 0;    
        end
        else if(current_state == ROW_ADDR_123)begin
            if(row_number == 0) 
                row = 1;
            else if(row_number == 1)
                row = 2;
            else if(row_number == 2)
                row = 3;
            else
                row = 0;   
        end
        else if(current_state == ROW_ADDR_230)begin
            if(row_number == 0) 
                row = 2;
            else if(row_number == 1)
                row = 3;
            else if(row_number == 2)
                row = 0;
            else
                row = 0;   
        end
        else if(current_state == ROW_ADDR_301)begin
            if(row_number == 0) 
                row = 3;
            else if(row_number == 1)
                row = 0;
            else if(row_number == 2)
                row = 1;
            else
                row = 0;   
        end
        else if(current_state == DOWN_PADDING)begin     //YWJ
            // if(row_number == 0) 
            //     row = 2;        
            // else if(row_number == 1)
            //     row = 3;
            // else
            //     row = 0;                    //avoiding latch
            if(cfg_kernel_repeat%2) 
                row = 1;        
            else
                row = 0;                    //avoiding latch
        end
        else begin
            row = 0;                    //avoiding latch
        end
    end

    always @ (*) begin
        if(col_finish)begin
            if(current_state == UP_PADDING || current_state == DOWN_PADDING) begin
                if(cfg_atlchin > 1) begin
                    if(row_number == 1) begin
                        row_finish = 1;
                    end
                    else if (ch == (cfg_atlchin-1))begin  //20250714 for 1*1
                        row_finish = 1;
                    end
                    else begin
                        row_finish = 0;
                    end
                end
                else begin
                    if(row_number == 2) begin
                        row_finish = 1;
                    end
                    else begin
                        row_finish = 0;
                    end
                end
            end  
            else if((current_state >= ROW_ADDR_012 && current_state <= ROW_ADDR_301) && row_number == 2)
                row_finish = 1;
            //20251016     
            else if((current_state >= ROW_ADDR_012 && current_state <= ROW_ADDR_301) && row_number == 0) begin
                if(cfg_atlchin > 1) begin
                    if(row_number == 1) begin
                        row_finish = 1;
                    end
                    else if (ch == (cfg_atlchin-1))begin  //20250714 for 1*1
                        row_finish = 1;
                    end
                    else begin
                        row_finish = 0;
                    end
                end
                else begin
                    if(row_number == 2) begin
                        row_finish = 1;
                    end
                    else begin
                        row_finish = 0;
                    end
                end
            end
            //20251016  
            else
                row_finish = 0;
        end
        else 
            row_finish = 0;
    end
//

endmodule
