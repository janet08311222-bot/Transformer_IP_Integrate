// ============================================================================
// Designer : Wei-Xuan Luo
// Modify   : (Fixed for Dual-Port SRAM Parallel Read - Restored 3-Cycle Timing)
// Ver      : 3.2 (Fix: for the 1x1 / self-attention config (cfg_atlchin>1) the
//                 3x3 window counter row_number must stay at 0 and row_finish
//                 must fire on every col sweep.  Ver 3.1 let row_number run
//                 0/1/2 in the ROW_ADDR states, so the ifmap side issued 3x
//                 more reads per kernel than kersram_r supplied; ifr_final and
//                 ksr_final then never coincided, pe_final stopped firing and
//                 the design produced almost no output.)
// Func     : input feature sram read module (Dual Row Output Parallel)
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
    //=============for sram ============
    ,   cen_reads_ifsram	
    ,   cen_reads_ifsram_r1    
    ,   addr_read_ifsram
    ,   addr_read_ifsram_r1    
    ,   current_state		
    ,   row_finish	
    ,   dy2_conv_finish
    //=========cfg input signal
    ,   cfg_window			
    ,   cfg_atlchin		 
    ,   cfg_kernel_repeat
    //===== for ch 8
    ,   row_number
    ,   rd_row_parity
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
    output wire                         cen_reads_ifsram_r1 ;
    output reg [IFMAP_SRAM_ADDBITS-1:0] addr_read_ifsram	;
    output reg [IFMAP_SRAM_ADDBITS-1:0] addr_read_ifsram_r1 ;
    input  wire [2:0]                   current_state		;
    output reg                          row_finish	        ;
    output reg                          dy2_conv_finish     ;
    input  wire [7:0]		            cfg_window			;
    input  wire [8-1:0]		            cfg_atlchin		    ;
    input  wire [7:0]                   cfg_kernel_repeat   ;
    output reg [1:0]                    row_number;
    output wire                         rd_row_parity       ;

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

    reg [1:0] next_state;   
    reg [1:0] c_state;
    wire done_flag;
    reg cen0;
    reg [5:0] row;
    reg [5:0] row_r1; 
    
    reg [5:0] col_oft ;
    wire [7:0] ch;
    reg [6:0] current_window;
    reg col_finish;
    reg [IFMAP_SRAM_ADDBITS-1:0] addr;
    wire local_done_flag;
    // dropped: col_oft_last / row_index / addrtt / enable_col_oft (never referenced)
    //          ch_last (counter .last tap, unread -- left open)

    reg [IFMAP_SRAM_ADDBITS-1:0] row_offset;
    reg [IFMAP_SRAM_ADDBITS-1:0] row_offset_r1;
    reg [IFMAP_SRAM_ADDBITS-1:0] col_offset;
    reg [7:0] ch_offset;
    reg col_oft_start;

    wire enable_ch ;
    wire [8-1:0] fn_count ;
    reg [IFMAP_SRAM_ADDBITS-1:0] addr_r1;

    assign rd_row_parity = row[0];

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

    assign done_flag = (current_state >= 1 && current_state <= 6)? (dy2_conv_finish)? 1 : 0 : 0;
    assign local_done_flag = (current_state >= 1 && current_state <= 6)? (conv_finish)? 1 : 0 : 0;

//============  sram control  =========
    assign cen_reads_ifsram    = ~dy_cen0_1;
    assign cen_reads_ifsram_r1 = ~dy_cen0_1;

    always @ (*) begin
        addr_read_ifsram    = (dy_cen0_1) ? addr    : 0; 
        addr_read_ifsram_r1 = (dy_cen0_1) ? addr_r1 : 0;
    end
    
    always @ (posedge clk) begin
        if(reset) begin
            addr    <= 0;
            addr_r1 <= 0;
        end
        else begin
            addr    <= row_offset    + col_offset + ch_offset;
            addr_r1 <= row_offset_r1 + col_offset + ch_offset; 
        end
    end

    always @ (*) begin
        if (row == 6'd3) 
            row_r1 = 6'd0;
        else 
            row_r1 = row + 6'd1;
    end

    // row offset 
    always @ (posedge clk) begin
        if(reset) begin
            row_offset    <= 0;
            row_offset_r1 <= 0;
        end
        else if(c_state == 1) begin
            row_offset    <= row * cfg_window * cfg_atlchin;
            row_offset_r1 <= row_r1 * cfg_window * cfg_atlchin;
        end
        else if(c_state == 0) begin
            row_offset    <= 0;
            row_offset_r1 <= 0;
        end
        else begin    
            row_offset    <= row_offset;
            row_offset_r1 <= row_offset_r1;
        end
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

//********* channel control  ************** 
count_yi_v4 #(
        .BITS_OF_END_NUMBER (	8	)
    )ifr_ch(
        .clk		( clk )
        ,	.reset 	 		(	reset	)
        ,	.enable	 		(	enable_ch	)
	    ,	.final_number	(	fn_count	)
	    ,	.last			(			)
        ,	.total_q		(	ch	)
    );
    assign fn_count = cfg_atlchin-1 ;
    assign enable_ch = ((cfg_atlchin > 1) && cen0) ? 1'd1 : 1'd0 ;

//********* window control  **************
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

//********* col control  ************** 
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
        if(col_oft == 0 && ch == (cfg_atlchin-1)) 
            col_finish = 1;
        else
            col_finish = 0;
    end

//********* row control  **************
always @ (posedge clk) begin
    if(reset)
        row_number <= 0;
    else if(col_finish) begin
        if(cfg_atlchin > 1) begin
            // 1x1 (self-attention) configuration : every col sweep already IS a
            // whole row, so the 3x3 window counter must stay at 0.  One ifmap row
            // per kernel -- which is exactly what kersram_r feeds
            // (cfg_normal_length = atl_ch).  Letting it run 0/1/2 here made the
            // ifmap side issue 3x more reads than the kernel side, so
            // pe_final = ksr_final & ifr_final never lined up and the PE stopped
            // producing results.
            row_number <= 0;
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
            if(row_number == 0) row = 0;
            else if(row_number == 1) row = 1;
            else row = 0;
        end
        else if(current_state == ROW_ADDR_012)begin
            if(row_number == 0) row = 0;
            else if(row_number == 1) row = 1;
            else row = 2;
        end
        else if(current_state == ROW_ADDR_123)begin
            if(row_number == 0) row = 1;
            else if(row_number == 1) row = 2;
            else row = 3;
        end
        else if(current_state == ROW_ADDR_230)begin
            if(row_number == 0) row = 2;
            else if(row_number == 1) row = 3;
            else row = 0;
        end
        else if(current_state == ROW_ADDR_301)begin
            if(row_number == 0) row = 3;
            else if(row_number == 1) row = 0;
            else row = 1;
        end
        else if(current_state == DOWN_PADDING)begin   
            if(cfg_kernel_repeat%2) row = 1;
            else row = 0;
        end
        else begin
            row = 0;
        end
    end

always @ (*) begin
        if(col_finish)begin
            if(current_state == UP_PADDING || current_state == DOWN_PADDING) begin
                if(cfg_atlchin > 1) begin
                    if(row_number == 1) begin
                        row_finish = 1;
                    end
                    else if (ch == (cfg_atlchin-1))begin  
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
            else if(current_state >= ROW_ADDR_012 && current_state <= ROW_ADDR_301) begin
                if(cfg_atlchin > 1) begin
                    // 1x1 : one col sweep == one row, finish every sweep
                    row_finish = 1;
                end
                else if(row_number == 2) begin
                    row_finish = 1;
                end
                else begin
                    row_finish = 0;
                end
            end
            else
                row_finish = 0;
        end
        else
            row_finish = 0;
    end

endmodule