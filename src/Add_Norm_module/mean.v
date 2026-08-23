module mean#(
    parameter TBITS=8,
    parameter fixed=8,
    parameter TOKEN=512

) ( 
    clk ,
    reset,
    in_last,
    add_out_valid,
    in_data,
    mean,
    mean_out_valid
);

localparam IDLE=3'b000;
localparam MEAN=3'b001;
localparam FIN=3'b010;


input  clk        ;
input  reset      ;
input  in_last    ;
input  add_out_valid   ;
input      [  TBITS + fixed   :   0   ] in_data ;
output reg [  TBITS + fixed   :   0   ] mean    ;
output       mean_out_valid ;
reg          cnt_delay      ;
reg          start_count    ;
reg         [  TBITS + fixed + 8  :   0   ]   addtree     ;
reg         [  TBITS + fixed + 8  :   0   ]   meanreg1    ;
reg         [  TBITS + fixed + 8  :   0   ]   meanreg     ;
reg         [     3       :   0   ]   cnt, count  ;
reg         [     3       :   0   ]   current_state,next_state ;
reg         in_last_dly;
reg         in_last_dly1;
assign mean_out_valid=(current_state==FIN)?1:0;

always@( posedge clk )begin
    if(  !reset )begin
        start_count <= 0 ;
    end
    else begin
        start_count <= (current_state==FIN)?0:( cnt == 7 ) ?  1 : start_count  ;
    end
end

always @(posedge clk ) begin
    if(!reset)begin
    cnt_delay<=0;
	in_last_dly<=0;
	in_last_dly1<=0;
    end
    else begin
    cnt_delay <= ( current_state==MEAN ) ? 1 : 0 ;
	in_last_dly<=in_last;
	in_last_dly1<=in_last_dly;

    end
end

always@( posedge clk )begin
    if(  !reset )begin
         cnt   <= 0 ;
    end
    else if( cnt_delay )begin
         cnt   <= (  cnt <  7 )  ? cnt+1   :   0   ;
         count <= ( start_count )? ( count <  7 ) ? ( cnt == 7 ) ? count+1 : count :( cnt == 7 ) ? 0 : count : count ;
         end
         else begin
         cnt   <= 0;
         count <= 0;
         end
end


always@( posedge clk )begin
    if(  !reset )begin
         addtree <= 0;
    end
    else if( current_state==MEAN )begin
         addtree <= ( cnt < 7 ) ? ( addtree + in_data ) : in_data ;    
         end
         else begin
         addtree <= 0;
         end
    end


always@( posedge clk )begin
    if(  !reset )begin
         meanreg  <= 0 ;
         meanreg1 <= 0 ;
         mean     <= 0 ;
    end
    else if( current_state == MEAN )begin
         meanreg  <= ( count == 7 )? ( cnt == 7 )?   addtree >> 3 : meanreg : ( cnt == 7 )? meanreg + ( addtree >> 3 )  :   meanreg   ;
         meanreg1 <= ( count == 7 )? ( cnt == 0 )?   meanreg1  + ( meanreg >> 3 ) : meanreg1 :   meanreg1  ;
         end
         else if(current_state==FIN)begin
         mean     <= meanreg1 >> 3 ;
         end
         else begin
         mean     <= mean     ;
         meanreg  <= 0  ;
         meanreg1 <= 0 ;
         end
    end


always@(posedge clk)begin
    if( !reset )begin
        current_state <= IDLE;
    end
    else begin 
        current_state <= next_state;
    end
end

always@(*)begin
    case(current_state)
    IDLE:   next_state = ( add_out_valid ) ? MEAN : IDLE  ;
    MEAN:   next_state = ( in_last_dly1 )    ? FIN  : MEAN  ;
    FIN:    next_state = IDLE ;
    default:next_state = IDLE ;


    
    endcase 
end 







endmodule
