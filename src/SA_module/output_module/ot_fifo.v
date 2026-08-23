

// ============================================================================
// Designer : Yi_Yuan Chen
// Create   : 2022.12.27
// Ver      : 1.0
// Func     : Quantization module output data fifo, avoid ot_module breaking
// ============================================================================
module ot_fifo (
	clk			,
	reset		,

	valid_in 	,
	data_in		,

	// error		,	// we loss output data cause something wrong


	empty_n		,
	read		,
	data_out	

);
//------------------------Parameter----------------------
localparam    
	DATA_BITS  = 64	,
    DEPTH_BITS = 12	;
localparam
    DEPTH = 1 << DEPTH_BITS;
//------------------------Local signal-------------------
reg                   empty		;
reg                   full		;
reg  [DEPTH_BITS-1:0] index		;
reg  [DATA_BITS-1:0]  mem[0:DEPTH-1];

//------------------------I/O----------------------------

input	wire 						clk			;
input	wire 						reset		;
input	wire 						valid_in 	;
input	wire 	[ DATA_BITS-1: 0 ]	data_in		;

output	wire 						empty_n		;
input	wire 						read		;
output	wire 	[ DATA_BITS-1: 0 ]	data_out	;

//  'error' (full & valid_in) was computed but never used, and the port that
//  once exported it is commented out in the header -- dropped.

//-----------------------------------------------------------------------------
wire write ;


//------------------------Body---------------------------
assign empty_n = ~empty		;
//  'full_n' had no declaration and no port (implicit wire) and nothing read it
assign data_out    = mem[index]	;
//-----------------------------------------------------------------------------

assign write = valid_in ;

//index
always @(posedge clk ) begin
	if(reset)
		index <= { DEPTH_BITS{1'd1} };
	else if(	empty & write	)	// when mem are empty, data coming with write = "1" index should +1 .
		index <=  index + 1'd1	;

	else if(	~empty & write	)
		index <= ( read ) ?		index	:	index + 1'd1	;

	else if(	~empty & ~write )
		index <= ( read ) ?		index - 1'd1	:	index 	;

	else 
		index <= index ;	// for (empty & ~write)
end

//empty
always @( posedge clk ) begin
	if (reset)
		empty <= 1'd1 ;
	else if ( empty & write  ) //FIXED BUG! FWS
        empty <= 1'b0;
    else if (~empty & ~write & read & (index==1'b0))
        empty <= 1'b1;
	else 
		empty <= empty ;
end

// full
always @(posedge clk ) begin
    if (reset)
        full <= 1'b0;
    else if (full & read & ~write)
        full <= 1'b0;
    else if (~full & ~read & write & (index==DEPTH-2'd2))
        full <= 1'b1;
	else 
		full <= full;
end

always @(posedge clk ) begin
	mem[0] <= ( ~full & write ) ? data_in : mem[0] ;
end

// mem[1] to mem[DEPTH-1]
genvar i;
generate
    for (i = 1; i < DEPTH; i = i + 1) begin : gen_fifo_reg
        always @(posedge clk) begin
            if (~full & write) mem[i] <= mem[i-1];
        end
    end
endgenerate



endmodule