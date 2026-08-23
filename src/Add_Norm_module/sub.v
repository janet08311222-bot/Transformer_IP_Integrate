module sub #(
    parameter TBITS=8   ,
    parameter fixed=8   ,
    parameter TOKEN=512 
)  (
    clk ,
    reset,
    add_out_valid,
    in_data,
    in_last,
    mean ,
    sub_valid,
    sub_out_valid,
    sub_out_data,
    sub_final
);
input clk   ;
input reset ;
input add_out_valid  ;
input sub_valid ;
input in_last   ;
input      [ TBITS + fixed : 0 ] mean ;
input      [ TBITS + fixed : 0 ] in_data ;
output reg signed [ TBITS + fixed : 0 ] sub_out_data ;
reg signed [ TBITS + fixed : 0 ] sub_data ;
output reg sub_out_valid;
wire sub_out_valid1;
output wire sub_final;

localparam IDLE=3'b000;
localparam INPUT=3'b001;
localparam WAIT=3'b010;
localparam SUB=3'b011;
localparam STAY1=3'b100;
localparam FIN=3'b101;


reg   in_last_dly;
integer i , j ,k;
reg [ TBITS + fixed : 0] input_reg [ 0 : TOKEN-1 ] ;
reg [ 2  : 0  ] current_state,next_state ;
assign sub_final=(current_state==FIN)?1:0;
assign sub_out_valid1=(current_state==SUB)?1:0;


always @(posedge clk ) begin
    if(!reset)begin

	in_last_dly<=0;
    end
    else begin

	in_last_dly<=in_last;
    end
end
always@( posedge clk)begin
    if ( !reset )begin
    sub_out_valid <= 0 ;
    end
    else begin
    sub_out_valid<=sub_out_valid1;
    end
end
always@( posedge clk )begin
    if(  !reset ) begin
    i <= 0;
end
    else begin
    i <= (i<511)? ( current_state==INPUT ) ? i+1 : 0 :0;
    end
end

always@( posedge clk )begin
    if(  !reset ) begin
    j <=0;
end
    else begin
    j <= (j<511)?( current_state == SUB ) ? j+1 : 0:0 ;
    end
end





always@( posedge clk )begin
    if(  !reset ) begin
   	for(k=0;k<511;k=k+1)begin
    input_reg[k]<=0;
    end
    end
    else if ( current_state==INPUT ) begin
    input_reg[i] <=  in_data  ;
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
    sub_data <= 0 ;
    end
    else begin
    sub_data <= (current_state==FIN)?0:( current_state == SUB )? input_reg[j] - mean : sub_data ;
    end
end


always@( posedge clk)begin
    if ( !reset )begin
    sub_out_data <= 0 ;
    end
    else begin
    sub_out_data <=  sub_data ;
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
    IDLE  :    next_state  = ( add_out_valid )? INPUT : IDLE  ;
    INPUT :    next_state  = ( i==511 )  ?  WAIT  : INPUT ;
    WAIT  :    next_state  = (sub_valid)?SUB: WAIT  ;
    SUB   :    next_state  = ( j==511) ? STAY1:SUB  ;
    STAY1 :   next_state = FIN   ;
    FIN   :    next_state  = IDLE ;
    default:   next_state  = IDLE ;

    
    endcase 
end 


endmodule

