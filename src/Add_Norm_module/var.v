module variance#(
parameter TBITS=8 ,
parameter fixed=8 ,
parameter TOKEN=512
)
( 
    clk ,
    reset,
    in_valid,
    in_last,
    in_data,
    variance,
    var_out_valid,
    var_final
);

localparam IDLE=3'b000;
localparam VAR=3'b001;
localparam FIN=3'b010;


input  clk        ;
input  reset      ;
input  in_last    ;
input  in_valid   ; 
input  signed   [  TBITS     +     fixed          :   0   ] in_data ;
output reg      [  TBITS + TBITS + fixed + fixed  :   0   ] variance    ;
output    reg   var_out_valid;
output       var_final    ;
reg          cnt_delay    ;
reg          start_count  ;
wire        [  TBITS + TBITS + fixed + fixed  +  1     :   0   ]   in_data_sq  ;
reg         [  TBITS + TBITS + fixed + fixed  +  9     :   0   ]   addtree     ;
reg         [  TBITS + TBITS + fixed + fixed  +  9     :   0   ]   varreg1     ;
reg         [  TBITS + TBITS + fixed + fixed  +  9     :   0   ]   varreg      ;
reg         [     3       :   0   ]   cnt, count  ;
reg         [     3       :   0   ]   current_state,next_state ;
reg         in_last_dly,in_last_dly1;


assign in_data_sq=in_data*in_data;

assign var_final=var_out_valid;

always@( posedge clk )begin
    if(  !reset )begin
            var_out_valid <= 0 ;
    end
    else begin
	var_out_valid<=(current_state==FIN)?1:0;
    end
end

always@( posedge clk )begin
    if(  !reset )begin
            start_count <= 0 ;
    end
    else begin
        start_count <=(current_state==FIN)?0: ( cnt == 7 ) ?  1 : start_count  ;
    end
end

always @(posedge clk ) begin
    if(!reset)begin
    cnt_delay<=0;
    in_last_dly<=0;
	in_last_dly1<=0;
    end
    else begin
    cnt_delay <= ( current_state == VAR ) ? 1 : 0 ;
    in_last_dly<=in_last;
    in_last_dly1<=in_last_dly;

    end
end

always@( posedge clk )begin
    if(  !reset )begin
         cnt <= 0;
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
    else if( current_state==VAR )begin
         addtree <= ( cnt < 7 ) ? ( addtree + in_data_sq ) : in_data_sq ;    
         end
         else begin
         addtree <= 0;
         end
    end


always@( posedge clk )begin
    if(  !reset )begin
         varreg  <= 0 ;
         varreg1 <= 0 ;
         variance     <= 0 ;
    end
    else if( current_state == VAR )begin
         varreg  <= ( count == 7 )? ( cnt == 7 )?   addtree >> 3 : varreg : ( cnt == 7 )? varreg + ( addtree >> 3 )  :   varreg   ;
         varreg1 <= ( count == 7 )? ( cnt == 0 )?   varreg1  + ( varreg >> 3 ) : varreg1 :   varreg1  ;
         end
         else if(current_state==FIN)begin
         variance     <= varreg1 >> 3 ;
         end
         else begin
         variance <= variance     ;
         varreg  <= 0  ;
         varreg1 <= 0 ;
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
    IDLE:   next_state = ( in_valid ) ? VAR : IDLE  ;
    VAR:   next_state = ( in_last_dly1 )    ? FIN  : VAR  ;
    FIN:    next_state = IDLE ;
    default:next_state = IDLE ;


    
    endcase 
end 







endmodule











