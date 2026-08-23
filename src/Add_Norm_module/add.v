module add#(
    parameter TBITS=8,
    parameter fixed=8,
    parameter TOKEN=512
    )(
    clk ,
    reset,
    in_last,
    in_data,
    add_valid,
    in_valid,
    out_data,
    add_out_valid,
    isif_read,
    add_final
);

localparam IDLE=3'b000;
localparam INPUT =3'b001;
localparam ADD=3'b010;
localparam FIN=3'b011;



input        clk         ;
input        reset       ;
input  wire  in_last     ;
input  wire  in_valid    ;
input  wire  add_valid   ;
output wire  add_final   ;
output wire add_out_valid;
output wire isif_read    ;
input  wire [  64 - 1        :   0   ]  in_data      ;
output wire [  TBITS + fixed    :   0   ]   out_data    ;
reg         [  TBITS + fixed    :   0   ]   add_result  ;
reg         [        3          :   0   ]   current_state,next_state ;
reg         in_valid_dly;
reg         [  TBITS  + 1       :   0   ]   cnt         ;
reg         [  TBITS  + 1       :   0   ]   cnt1         ;
reg         [  2   :  0  ]number ;
reg         [  64 - 1 : 0 ]   inreg    [ 0 : (TOKEN>>3) - 1 ];
reg         [  64 - 1 : 0 ]   inreg1   [ 0 : (TOKEN>>3) - 1 ];
wire        [  64 - 1 : 0 ] old_data,new_data;
integer  i,j;
  
/*
reg         [  TBITS - 1  :   0   ]   new_in_data_delay ;
reg         [  TBITS - 1  :   0   ]   old_in_data_delay ;

*/
assign add_out_valid=( current_state==ADD )?1:0;
assign old_data = inreg[cnt1];
assign new_data = inreg1[cnt1];
assign out_data  =    add_result      ;
assign add_final =  ( current_state==FIN )? 1 : 0 ;
assign isif_read =  ( cnt <= 127 ) ? 1 : 0 ;
/////////////input         
always @(posedge clk )begin
    if(!reset)begin
        for(i=0;i< 64;i=i+1)begin
            inreg[i]<=0;
            inreg1[i]<=0;
        end
    end
    else  if (current_state==INPUT&&in_valid)begin
    inreg[cnt]<=(cnt<=63) ? in_data : inreg[cnt];
    inreg1[cnt-64]<=(cnt>63)? in_data : inreg[cnt-64];
    end
    else if (current_state==FIN)begin
               for(i=0;i< 64;i=i+1)begin
            inreg[i]<=0;
            inreg1[i]<=0;
        end
    end


end



always@( posedge clk )begin
    if(  !reset )begin
         cnt <= 0 ;

    end
    else if( in_valid ) begin
         cnt<=  cnt+1'b1;
    end
    else if(current_state==FIN)begin
        cnt<=0;
end
end
 always@( posedge clk )begin
    if(  !reset )begin
         cnt1 <= 0 ;
    end
    else begin
         cnt1<= (current_state==FIN)?0:( number==7 )? cnt1+1 : cnt1 ;
    end
end
 
 always@( posedge clk )begin
    if(  !reset )begin
         number<=0;
    end
    else begin
number<=(current_state==FIN)?0:( current_state==ADD )?number+1 :number;

    end
end

/*
always@( posedge clk )begin
    if(  !reset )begin
         new_in_data_delay <= 0;
         old_in_data_delay <= 0;
    end
    else begin
         new_in_data_delay <= new_in_data_wire;
         old_in_data_delay <= old_in_data_wire;
    end
end
*/
always@(posedge clk)begin
    if(  !reset ) in_valid_dly <= 0;
    else in_valid_dly<=in_valid;
end

always@(posedge clk)begin
    if(  !reset ) add_result <= 0;
    else  if(current_state==ADD)begin
        case (number)
        0:add_result[TBITS+fixed:TBITS]<=old_data[63:56]+new_data[63:56];
        1:add_result[TBITS+fixed:TBITS]<=old_data[55:48]+new_data[55:48];
        2:add_result[TBITS+fixed:TBITS]<=old_data[47:40]+new_data[47:40];
        3:add_result[TBITS+fixed:TBITS]<=old_data[39:32]+new_data[39:32];
        4:add_result[TBITS+fixed:TBITS]<=old_data[31:24]+new_data[31:24];
        5:add_result[TBITS+fixed:TBITS]<=old_data[23:16]+new_data[23:16];
        6:add_result[TBITS+fixed:TBITS]<=old_data[15:8]+new_data[15:8];
        7:add_result[TBITS+fixed:TBITS]<=old_data[7:0]+new_data[7:0];
        endcase
    end
    else begin
        add_result<=(current_state==FIN)?0:add_result;
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
    IDLE:   next_state = ( add_valid )? INPUT:IDLE;
    INPUT:  next_state = ( cnt==127  )? ADD : INPUT;
    ADD:    next_state = ( cnt1==63 &&number==7)  ? FIN:ADD;
    FIN:    next_state = IDLE ;
    default:next_state = IDLE ;

    
    endcase 
end 








endmodule

