`timescale 1ns/1ps

module tb_top_addnorm;

  parameter TBITS = 64;
  parameter TBYTE = 8;
  parameter TOKEN = 64;
`define SDFFILE    "/home/CB113_lyk/LYK/Add&norm_AXI/syn/DC_Results/top_addnorm_syn.sdf"

`ifdef SDF
    initial $sdf_annotate(`SDFFILE,dut);
`endif
  // AXI Stream (input to DUT)
  reg                    clk;
  reg                    reset;
  reg                    S_AXIS_MM2S_TVALID;
  wire                   S_AXIS_MM2S_TREADY;
  reg  [TBITS-1:0]     S_AXIS_MM2S_TDATA;

  reg                    S_AXIS_MM2S_TLAST;

  // AXI Stream (output from DUT) ?? ?�� DUT 沒�?�輸?��?��，可??��?�段?�� `ifdef ??�起�?
  wire                   M_AXIS_S2MM_TVALID;
  reg                    M_AXIS_S2MM_TREADY;
  wire [16-1:0]            M_AXIS_S2MM_TDATA;
  wire                   M_AXIS_S2MM_TLAST;
 wire      [2-1:0]              M_AXIS_S2MM_TKEEP;
  // patterns
  reg [TBITS-1:0] old_data_mem [0:TOKEN-1];
  reg [TBITS-1:0] new_data_mem [0:TOKEN-1];
  reg [63:0]      golden_mem   [0:512-1];

  localparam SA_HEAD          = 64'h0011223344556677 ;
  localparam SOFTMAX_HEAD     = 64'h8899aabbccddeeff ;
  localparam NORM_HEAD        = 64'h7766554433221100 ;
  localparam FFN_HEAD         = 64'hffeeddccbbaa9988 ;

  integer i, out_idx, error_count;

  // clock
  initial clk = 0;
  always #5 clk = ~clk;

  // DUT
  Transformer_top #(
    .TBITS(TBITS),
    .TBYTE(TBYTE)
  ) dut (
    .clk(clk),
    .resetn(reset),

    .S_AXIS_MM2S_TVALID(S_AXIS_MM2S_TVALID),
    .S_AXIS_MM2S_TREADY(S_AXIS_MM2S_TREADY),
    .S_AXIS_MM2S_TDATA (S_AXIS_MM2S_TDATA),

    .S_AXIS_MM2S_TLAST (S_AXIS_MM2S_TLAST)


     , .M_AXIS_S2MM_TVALID(M_AXIS_S2MM_TVALID)
     , .M_AXIS_S2MM_TREADY(M_AXIS_S2MM_TREADY)
     , .M_AXIS_S2MM_TDATA (M_AXIS_S2MM_TDATA)
     , .M_AXIS_S2MM_TKEEP (M_AXIS_S2MM_TKEEP)
     , .M_AXIS_S2MM_TLAST (M_AXIS_S2MM_TLAST)
  );

  // 驗�?��?��??
  initial begin
   /* $fsdbDumpfile("addnorm.fsdb");
    $fsdbDumpvars(0, "+mda", "+packedmda");
    $fsdbDumpMDA();
*/
    // �? pattern（建議改?��對路徑避??��?��?�環境�?��?��?��??
    $readmemh("C:/Users/LCP/Desktop/Edu/pat/old_input.dat", old_data_mem);
    $readmemh("C:/Users/LCP/Desktop/Edu/pat/new_input.dat", new_data_mem);
    $readmemh("C:/Users/LCP/Desktop/Edu/pat/golden4.dat"   , golden_mem);

    // ??��??
    reset = 0;
    S_AXIS_MM2S_TVALID = 0;
    S_AXIS_MM2S_TDATA  = 0;

    S_AXIS_MM2S_TLAST  = 0;

    M_AXIS_S2MM_TREADY = 1;   // 讓�?�游永�?? ready（若已�??上�??
    out_idx = 0;
    error_count = 0;

    // ??�放 reset
    repeat (4) @(posedge clk);
    reset = 1;
    repeat (2)@(posedge clk);

    // 等�?? DUT �???? ready（避??��???��?�就?��住�??
    //---- NORM HEAD ----
    wait(S_AXIS_MM2S_TREADY);
    @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= NORM_HEAD ;
    wait(S_AXIS_MM2S_TREADY);
    @( posedge clk );	S_AXIS_MM2S_TVALID = 1 ;	S_AXIS_MM2S_TDATA	= NORM_HEAD ;	
    S_AXIS_MM2S_TLAST	= 1;	// last signal 
    wait(S_AXIS_MM2S_TREADY);
    @( posedge clk );	S_AXIS_MM2S_TLAST = 0 ;		S_AXIS_MM2S_TVALID = 0 ;

    repeat (4) @(posedge clk);

    // ?��輸�?��?��?�正確�?? AXIS ?��??��?��?��??
    for (i = 0; i < TOKEN; i = i + 1) begin
      wait(S_AXIS_MM2S_TREADY)
        @(posedge clk);
        S_AXIS_MM2S_TVALID <= 1'b1;
        S_AXIS_MM2S_TDATA  <= new_data_mem[i];
        S_AXIS_MM2S_TLAST  <= (i == TOKEN-1);
 	      if (i == (TOKEN - 1)) begin
          @(posedge clk);
          S_AXIS_MM2S_TVALID <= 1'b0;
          S_AXIS_MM2S_TLAST  <= 1'b0;
        end
    end
    @(posedge clk);
    @(posedge clk);
    for (i = 0; i < TOKEN; i = i + 1) begin
      wait(S_AXIS_MM2S_TREADY)
      @(posedge clk);
      S_AXIS_MM2S_TVALID <= 1'b1;
      S_AXIS_MM2S_TDATA  <= old_data_mem[i];
      S_AXIS_MM2S_TLAST  <= (i == TOKEN-1);
 	    if (i == (TOKEN - 1)) begin
        @(posedge clk);
        S_AXIS_MM2S_TVALID <= 1'b0;
        S_AXIS_MM2S_TLAST  <= 1'b0;
      end
    end

    // 等�?�輸?��（若??�輸?���?
    repeat (10000) @(posedge clk);

    if (error_count == 0)
      $display("??? All outputs match golden (or no mismatches detected).");
    else
      $display("??? %0d mismatches found.", error_count);

        
    $finish;
  end
always @(posedge clk) begin
    if (out_idx==50)begin

	M_AXIS_S2MM_TREADY=0;
repeat (20) @(posedge clk);
M_AXIS_S2MM_TREADY=1;
end
else begin
M_AXIS_S2MM_TREADY=1;
end
end
always @(posedge clk) begin
    if (M_AXIS_S2MM_TVALID) begin
        if (M_AXIS_S2MM_TDATA === golden_mem[out_idx]) begin
            $display(" Correct  @ %0d: DUT = %03d (0x%04x), GOLDEN = %03d (0x%04x)", 
                     out_idx, M_AXIS_S2MM_TDATA, M_AXIS_S2MM_TDATA, golden_mem[out_idx], golden_mem[out_idx]);
        end else begin
            $display(" Mismatch @ %0d: DUT = %03d (0x%04x), GOLDEN = %03d (0x%04x)", 
                     out_idx, M_AXIS_S2MM_TDATA, M_AXIS_S2MM_TDATA, golden_mem[out_idx], golden_mem[out_idx]);
            error_count = error_count + 1;
        end
if(out_idx==50)begin
        out_idx = out_idx ;
repeat (20) @(posedge clk);
out_idx = out_idx + 1;
end
else begin 
out_idx = out_idx + 1;
end
    end
end

  // ??? ?�� DUT ??�輸?��?��，�?��?��?�段??��?��??
  /*
  always @(posedge clk) begin
    if (!reset && M_AXIS_S2MM_TVALID && M_AXIS_S2MM_TREADY) begin
      if (M_AXIS_S2MM_TDATA !== golden_mem[out_idx]) begin
        $display("Mismatch @%0d: DUT=%h, GOLDEN=%h", out_idx, M_AXIS_S2MM_TDATA, golden_mem[out_idx]);
        error_count = error_count + 1;
      end
      out_idx = out_idx + 1;
    end
  end
  */

endmodule
