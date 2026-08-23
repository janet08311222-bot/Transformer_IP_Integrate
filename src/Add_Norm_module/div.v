module div#(
parameter TBITS=8,
parameter fixed=8,
parameter TOKEN=512

) (
    clk ,
    reset,
    in_valid,
    in_data,
    input_ready, 
    sqrt_variance,
    test_data,
    test_cnt,
    test_out,
    test_sqrt,
    div_valid,
    div_out_valid,
    div_final,
    div_out_last,
    div_out_data
);


localparam IDLE=3'b000;
localparam INPUT=3'b001;
localparam WAIT=3'b010;
localparam DIV=3'b011;
localparam STAY1=3'b100;
localparam FIN=3'b101;


input  clk        ;
input  reset      ;
input  in_valid   ;
input  div_valid  ;
input input_ready    ;
input   signed    [   TBITS      + fixed :   0     ]   in_data       ;
input   signed          [   TBITS   + fixed :   0     ]   sqrt_variance      ;
output  reg div_out_valid ;
output div_final     ;
output wire div_out_last;
output reg signed    [   TBITS    + fixed -1 :   0     ] div_out_data  ;

output wire [  TBITS  + fixed +  3 : 0]test_data;
output wire [ 9 : 0]test_cnt; 
output wire [   TBITS   + 3 :   0     ] test_sqrt;
output wire [   TBITS    + fixed -1 :   0     ] test_out;
wire   signed [   TBITS+3 :   0     ]  sqrt_fixed_var ;
reg div_out_valid1;
reg [8:0]cnt ;
integer i , j ,k;
reg signed [  TBITS  + fixed +  3 : 0] input_reg [ 0 : TOKEN-1 ] ;
reg signed [  TBITS  + fixed +  3 : 0] in_div_data         ;
reg signed[   TBITS   + 3 :   0     ]   sqrt_var_reg       ;
reg [ 2  : 0  ]   current_state    ,    next_state         ;
wire signed [  TBITS  + fixed +  3 :  0 ]   quotient       ;
wire signed [  TBITS  +   3        :  0 ]   remainder      ;
wire divide_by_0;

assign test_data=in_div_data;
assign test_cnt=j;
assign test_sqrt=sqrt_var_reg;
assign test_out=div_out_data;
assign sqrt_fixed_var=sqrt_variance [ TBITS - 1  + fixed : fixed-3];
assign div_final=(current_state==FIN)?   1 : 0;
assign div_out_last=(cnt==511)?1:0;
always@( posedge clk)begin
    if ( !reset )begin
    sqrt_var_reg <= 0 ;
    end
    else begin
    sqrt_var_reg<=sqrt_fixed_var;
    end
end


always@( posedge clk )begin
    if(  !reset ) begin
   	for(k=0;k<511;k=k+1)begin
    input_reg[k]<=0;
    end
    end
    else if  ( current_state==INPUT )begin
    input_reg[i] <= (in_data<<3) ;
    end
    else if(current_state==FIN)begin
           	for(k=0;k<511;k=k+1)begin
    input_reg[k]<=0;
    end
end
    else begin
        input_reg[i]<=input_reg[i];
    end
end

always@( posedge clk)begin
    if ( !reset )begin
    div_out_valid1 <= 0 ;
    end
    else begin
    div_out_valid1<=(current_state==DIV&&input_ready)?1:0;
    end
end

always@( posedge clk)begin
    if ( !reset )begin
    div_out_valid <= 0 ;
    end
    else begin
    div_out_valid<=div_out_valid1;
    end
end


always@( posedge clk)begin
    if ( !reset )begin
    in_div_data<=0;
    end
    else if (current_state==DIV&&input_ready)begin	
    in_div_data<=input_reg[j];
end
    else if(current_state==FIN)begin
        in_div_data<=0;
end
else begin
    in_div_data<=in_div_data;
end
end

always@( posedge clk)begin
    if ( !reset )begin
    cnt <= 0 ;
    end
    else begin
    cnt<=(current_state==FIN)?0:(div_out_valid)?cnt+1:cnt;
    end
end




always@( posedge clk)begin
    if ( !reset )begin
    div_out_data<=0  ;
    end
    else begin
    div_out_data<=in_div_data/sqrt_var_reg;
    end
end


always@( posedge clk )begin
    if(  !reset ) begin
    i <= 0;
end
    else begin
    i <= (i<TOKEN-1)? ( current_state==INPUT ) ? i+1 : 0 :0;
    end
end

always@( posedge clk )begin
    if(  !reset ) begin
    j <=0;
end
    else begin
    j <= (j<TOKEN-1)?( current_state == DIV )?(input_ready) ? j+1:j : 0:0 ;
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
    IDLE  :    next_state  = ( in_valid )? INPUT : IDLE  ;
    INPUT :    next_state  = ( i==TOKEN-1 )  ? WAIT  : INPUT ;
    WAIT  :    next_state  = (div_valid) ? DIV   : WAIT  ;
    DIV   :    next_state  = ( j==TOKEN-1)   ? STAY1   : DIV   ;
    STAY1  :    next_state  = FIN  ;
    FIN   :    next_state  = IDLE ;
    default:   next_state  = IDLE ;

    
    endcase 
end 

/*

DW_div #(
    .a_width(20),
    .b_width(12),
    .tc_mode(1) ,
    .rem_mode(1)
      )u_DW_div (
    .a(in_div_data),
    .b(sqrt_var_reg),
    .quotient(quotient),
    .remainder(remainder),
    .divide_by_0(divide_by_0)
    );
*/



endmodule

