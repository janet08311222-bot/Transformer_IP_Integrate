module addnormtop #(
    parameter TBITS=8,
    parameter fixed=8,
    parameter TOKEN=512
)
 (
    clk ,
    reset,

     NORM_done ,

    input_ready,
    in_valid,
    in_last,
    in_data,
    output_ready,
    out_data,
    out_last,
    out_valid

);
localparam IDLE=3'b000;
localparam START=3'b001;
localparam ADD=3'b010;
localparam SUB=3'b011;
localparam VAR=3'b100;
localparam DIV=3'b101;
localparam FIN=3'b110;


//////   I/O port declare ///////////
input           clk       ;
input           reset     ;
input   wire    input_ready ;
input   wire    in_valid  ;
input   wire    in_last   ;
input   wire   [ 64 - 1 :  0  ]   in_data   ;
output  wire    output_ready ; 
output  wire  signed  [ TBITS + fixed - 1 : 0 ] out_data    ;
output  wire    out_valid ;
output  wire    out_last  ;

output  wire    NORM_done ;

/////////////output signal////////


/////////////add signal
wire    add_valid    ;
wire    add_final    ;
wire   [  TBITS + fixed  :  0  ] add_out_data  ;
wire   add_out_valid ;

///////////mean signal
wire   [  TBITS + fixed  :  0  ] mean          ;

wire   mean_out_valid ;

////////////sub signal
wire       sub_out_valid;
wire signed [ TBITS + fixed : 0 ] sub_out_data;
wire       sub_final ;
//////////var signal
wire    var_valid ;
wire    [  TBITS + TBITS + fixed + fixed :   0   ] variance;
wire    var_out_valid;
wire    [  TBITS  +fixed :   0   ] sqrt_variance ;
wire    var_final ;

/////////div signal

wire    div_valid     ; 
wire    div_out_valid ;
wire signed [ TBITS + fixed -1 : 0 ] div_out_data ;
wire    div_final ;
wire    sub_valid ;
wire    out_done  ;
wire    div_out_last ;
reg     [3:0] current_state;
reg     [3:0] next_state;

 assign  add_valid = ( current_state == ADD   )?  1 : 0 ;
assign div_valid=(sqrt_variance>0) ? 1 : 0 ;
 assign out_valid=div_out_valid;
 assign out_last=div_out_last ;
 assign out_data=div_out_data ;

 assign NORM_done = out_last ;
     
     /////////////////instance//////////////////////////
add add1(

     .clk            (    clk            )
  ,  .reset          (    reset          )
  ,  .in_last        (    in_last        )
  ,  .in_data        (    in_data        )  
  ,  .add_valid      (    add_valid      )
  ,  .in_valid       (    in_valid       )
  ,  .out_data       (    add_out_data   )
  ,  .add_out_valid  (    add_out_valid  )
  ,  .isif_read      (    output_ready   )
  ,  .add_final      (    add_final      )

); 


mean mean1(
     .clk            (    clk            )
  ,  .reset          (    reset          )
  ,  .in_last        (    add_final      )
  ,  .add_out_valid  (    add_out_valid  )
  ,  .in_data        (    add_out_data   )
  ,  .mean           (    mean           )
  ,  .mean_out_valid (    mean_out_valid )
); 

sub sub1(
     .clk            (    clk             )
  ,  .reset          (    reset           )
  ,  .add_out_valid  (    add_out_valid   )
  ,  .in_data        (    add_out_data    )
  ,  .in_last        (    add_final       )
  ,  .mean           (    mean            )
  ,  .sub_valid      (    mean_out_valid  )
  ,  .sub_out_valid  (    sub_out_valid   )
  ,  .sub_out_data   (    sub_out_data    )
  ,  .sub_final      (    sub_final       )

);

variance variance1(
     .clk            (    clk             )
  ,  .reset          (    reset           )
  ,  .in_valid       (    sub_out_valid   )
  ,  .in_last        (    sub_final       )
  ,  .in_data        (    sub_out_data    )
  ,  .variance       (    variance        )
  ,  .var_out_valid  (    var_out_valid   )
  ,  .var_final      (    var_final       )

);


div div1(
     .clk            (    clk             )
  ,  .reset          (    reset           )
  ,  .in_valid       (    sub_out_valid   )
  ,  .in_data        (    sub_out_data    )
  ,  .input_ready    (    input_ready	  )
  ,  .sqrt_variance  (    sqrt_variance   )
  ,  .div_valid      (    div_valid       )
  ,  .div_out_valid  (    div_out_valid   )
  ,  .div_final      (    div_final       )
  ,  .div_out_last   (    div_out_last    )
  ,  .div_out_data   (    div_out_data    )

); 

  DW_sqrt  u_sqrt(
      .aclk(clk)
     , .s_axis_cartesian_tdata(variance)
    , .m_axis_dout_tdata(sqrt_variance)
  );


always@(posedge clk)begin
    if ( !reset ) begin
         current_state<=IDLE;
    end
    else begin 
         current_state<=next_state;
    end
end

always@(*)begin
    case ( current_state )
    IDLE :  next_state=START; 
    START: next_state=ADD;
    ADD  :  next_state = ( add_final    )      ?   SUB : ADD   ; 
    SUB  :  next_state = ( sub_final    )      ?   VAR : SUB   ;
    VAR  :  next_state = ( var_final    )      ?   DIV : VAR   ;
    DIV  :  next_state = ( div_final    )      ?   FIN : DIV   ;
    FIN  :  next_state = IDLE ;
    default:next_state = IDLE ;   
    endcase   
end




endmodule

