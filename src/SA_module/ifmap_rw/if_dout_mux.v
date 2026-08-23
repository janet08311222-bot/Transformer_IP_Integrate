

module if_dout_mux #(
	parameter DATA_WIDTH = 64 
)(
    data_valid,     // SRAM 讀出的資料是否有效（上一 cycle 有送出讀地址）
    ifsram0_read,   // 這個 SRAM buffer 正在被讀取中
    dinsr_0,        // SRAM 輸出的 64-bit 原始資料
    dout            // 輸出給 PE 的資料	
);
	
input wire	data_valid		;
input wire	ifsram0_read	;
input wire 	[DATA_WIDTH-1 : 0 ]	dinsr_0	;
output	reg 	[DATA_WIDTH-1 : 0 ]	dout 		;

	always @(*) begin
		if (data_valid && ifsram0_read)
			dout = dinsr_0;   // 兩個條件都滿足才輸出真實資料
		else
			dout = 0;         // 否則輸出 0（等效 padding zero）
	end



endmodule