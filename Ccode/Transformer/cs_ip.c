/*
 * cs_ip.c
 *
 *      Author: cs
 */

/***************************** Include Files *********************************/

#include "xaxidma.h"
#include "xaxidma_hw.h"
#include "xparameters.h"
#include "xil_exception.h"
#include "xdebug.h"
#include "xstatus.h"
#include "xscugic.h"
#include "cs_ip.h"
#include "axi_dma.h"
#include "sleep.h"

#include "v3_data.h"
#include "math.h"

#include "xtime_l.h"
/***************************** Main Function *********************************/

static XAxiDma DmaInstance;

void SA_q_gen( int cov_layer_number , u64* bias, u8* weights , u8*input_map , u8*output_map  ){

	u8* ifmap_dma_addr ;
	u8* ofmap_dma_addr ;

	int ix   ;
	XTime start, end;
	u32 time_used;
	XTime_GetTime(&start);
	u64 INST_HEAD[2] 	= {	0x22ffeebb3a12efef,
							0x22ffeebb3a12efef};
	u64 DATA_HEAD[2] 	= {	0x11ffdada4365efef,
							0x11ffdada4365efef};

	u64 SA_HEAD[2] =  {0x0011223344556677,
					   0x0011223344556677};

	u64 CFG[16]		 = 	{
//										0x22ffeebb3a12efef,
//										0x22ffeebb3a12efef,
										0x000000000000ffff,
										0x007f00086444887d,
										0x0000000000020020,
										0x0000000000010140,
										0x0003000000000000,
										0x00003f3f3f000000,
										0x0000000000003f00,
										0x0000000000000201,
										0x000000400000003f,
										0x0000000000000000,
										0x0000000000000040,
										0x0000000000000040,
										0x000000000000ff0f,
										0x00000000ff010800,
										0x000000000000f003,
										0x000000100000f003

					 	};

	int TB_RUN_ROW 		= 64	;
	int TB_CH_IN 		= 512	  ;
	int TB_RUN_COL 		= 1	;
	int TB_KER_NUMBER 	= 512		;
	int TB_CFG_NUMBER	= 16	;
	int cfg_address 			;

	ix =0  ;

	ifmap_dma_addr = input_map ;
	ofmap_dma_addr = output_map ;

	XAxiDma_Reset(&DmaInstance);

	// xil_printf("==== Start DMA Transfer ====\r\n");
	XTime_GetTime(&start);

	//----- SA HEAD -----------------
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&SA_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&SA_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }

	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&INST_HEAD) , 2 * 8);
	AXI_DMA_Transfer    ((UINTPTR)(&INST_HEAD) , 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	//----- instruction --------------

	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&CFG) , 8*TB_CFG_NUMBER );
	AXI_DMA_Transfer    ((UINTPTR)(&CFG) , 8*TB_CFG_NUMBER , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	//Data head
	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD) , 2*8 );
	AXI_DMA_Transfer    ((UINTPTR)(&DATA_HEAD) , 2*8 , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)( weights ) , TB_CH_IN*TB_KER_NUMBER );
	AXI_DMA_Transfer    ((UINTPTR)( weights ) , TB_CH_IN*TB_KER_NUMBER  , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);
	// xil_printf("==== total kernel  send done ====\r\n");
	//----- Bias --------------
	//Data head
	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD) , 2*8 );
	AXI_DMA_Transfer    ((UINTPTR)(&DATA_HEAD) , 2*8 , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(bias) , TB_KER_NUMBER*8 );
	AXI_DMA_Transfer    ((UINTPTR)(bias) , TB_KER_NUMBER*8  , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);
	// xil_printf("==== total bias send done ====\r\n");


	//-------------------------------------------------------------------
	//-----  IFmap 15row  & OFmap 15row--------------

	ifmap_dma_addr = input_map   ;
	//Data head
	AXI_DMA_TxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD) , 2*8 );
	AXI_DMA_Transfer    ((UINTPTR)(&DATA_HEAD) , 2*8 , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;

	Xil_DCacheFlushRange(	(UINTPTR)(	ifmap_dma_addr )  , TB_RUN_ROW*TB_RUN_COL*TB_CH_IN	);		// all ifm 32ch
	AXI_DMA_Transfer(	 	(UINTPTR)(	ifmap_dma_addr )  , TB_RUN_ROW*TB_RUN_COL*TB_CH_IN 	, XAXIDMA_DMA_TO_DEVICE);
	AXI_DMA_RxDone=0;

	for( ix =0 ; ix<TB_RUN_ROW ; ix=ix+1 ){	//64 row
		AXI_DMA_Transfer(		(UINTPTR)(	ofmap_dma_addr )  , TB_RUN_COL*TB_KER_NUMBER	, XAXIDMA_DEVICE_TO_DMA); // one row ofm 16ch
		while (!AXI_DMA_RxDone  )  {	/* NOP */	}
		Xil_DCacheInvalidateRange((UINTPTR)(ofmap_dma_addr), (TB_RUN_COL*TB_KER_NUMBER) + 32);
		AXI_DMA_RxDone=0;
		ofmap_dma_addr = ofmap_dma_addr + TB_RUN_COL*TB_KER_NUMBER ;	// next row address
	}

	while (!AXI_DMA_TxDone ) {	/* NOP */}	// check IFmap all done
	usleep(5);
	// xil_printf("==== total ifm send done ====\r\n");
	AXI_DMA_RxDone=0;
	ix =0  ;

	//-------------------------------------------------------------------

	XTime_GetTime(&end);
	time_used = ((end-start)*1000000)/(COUNTS_PER_SECOND);
	xil_printf("--------------------------------\r\n");
	xil_printf("end Q_Generation \r\n");
	xil_printf(" %d us\r\n", time_used);
	xil_printf("--------------------------------\r\n");

}

void SA_k_gen( int cov_layer_number , u64* bias, u8* weights , u8*input_map , u8*output_map  ){

	u8* ifmap_dma_addr ;
	u8* ofmap_dma_addr ;

	int ix   ;
	XTime start, end;
	u32 time_used;
	XTime_GetTime(&start);
	u64 INST_HEAD[2] 	= {	0x22ffeebb3a12efef,
							0x22ffeebb3a12efef};
	u64 DATA_HEAD[2] 	= {	0x11ffdada4365efef,
							0x11ffdada4365efef};

	u64 SA_HEAD[2] =  {0x0011223344556677,
					   0x0011223344556677};
//	u64 CFG[18];

	u64 CFG[18]		 = 	{				0x22ffeebb3a12efef,
										0x22ffeebb3a12efef,
										0x000000000000ffff,
										0x007f00086444887d,
										0x0000000000020020,
										0x0000000000010140,
										0x0003000000000000,
										0x00003f3f3f000000,
										0x0000000000003f00,
										0x0000000000000201,
										0x000000400000003f,
										0x0000000000000000,
										0x0000000000000040,
										0x0000000000000040,
										0x000000000000ff0f,
										0x00000000ff010800,
										0x000000000000f003,
										0x000000100000f003

					 	};

	int TB_RUN_ROW 		= 64	;
	int TB_CH_IN 		= 512	  ;
	int TB_RUN_COL 		= 1	;
	int TB_KER_NUMBER 	= 512		;
	int TB_CFG_NUMBER	= 18	;
	int cfg_address 			;

	ix =0  ;

	ifmap_dma_addr = input_map ;
	ofmap_dma_addr = output_map ;

	XAxiDma_Reset(&DmaInstance);

	// xil_printf("==== Start DMA Transfer ====\r\n");
	XTime_GetTime(&start);

	//----- SA HEAD -----------------
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&SA_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&SA_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }

	//----- instruction --------------
	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&CFG) , 8*TB_CFG_NUMBER );
	AXI_DMA_Transfer    ((UINTPTR)(&CFG) , 8*TB_CFG_NUMBER , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	//Data head
	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD) , 2*8 );
	AXI_DMA_Transfer    ((UINTPTR)(&DATA_HEAD) , 2*8 , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)( weights ) , TB_CH_IN*TB_KER_NUMBER );
	AXI_DMA_Transfer    ((UINTPTR)( weights ) , TB_CH_IN*TB_KER_NUMBER  , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);
	// xil_printf("==== total kernel  send done ====\r\n");
	//----- Bias --------------
	//Data head
	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD) , 2*8 );
	AXI_DMA_Transfer    ((UINTPTR)(&DATA_HEAD) , 2*8 , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(bias) , TB_KER_NUMBER*8 );
	AXI_DMA_Transfer    ((UINTPTR)(bias) , TB_KER_NUMBER*8  , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);
	// xil_printf("==== total bias send done ====\r\n");

	//-------------------------------------------------------------------
	//-----  IFmap 15row  & OFmap 15row--------------

	ifmap_dma_addr = input_map   ;
	//Data head
	AXI_DMA_TxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD) , 2*8 );
	AXI_DMA_Transfer    ((UINTPTR)(&DATA_HEAD) , 2*8 , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;

	Xil_DCacheFlushRange(	(UINTPTR)(	ifmap_dma_addr )  , TB_RUN_ROW*TB_RUN_COL*TB_CH_IN	);		// all ifm 32ch
	AXI_DMA_Transfer(	 	(UINTPTR)(	ifmap_dma_addr )  , TB_RUN_ROW*TB_RUN_COL*TB_CH_IN 	, XAXIDMA_DMA_TO_DEVICE);
	AXI_DMA_RxDone=0;

	for( ix =0 ; ix<TB_RUN_ROW ; ix=ix+1 ){	//64 row
		AXI_DMA_Transfer(		(UINTPTR)(	ofmap_dma_addr )  , TB_RUN_COL*TB_KER_NUMBER	, XAXIDMA_DEVICE_TO_DMA); // one row ofm 16ch
		while (!AXI_DMA_RxDone  )  {	/* NOP */	}
		Xil_DCacheInvalidateRange((UINTPTR)(ofmap_dma_addr), (TB_RUN_COL*TB_KER_NUMBER) + 32);
		AXI_DMA_RxDone=0;
		ofmap_dma_addr = ofmap_dma_addr + TB_RUN_COL*TB_KER_NUMBER ;	// next row address
	}

	while (!AXI_DMA_TxDone ) {	/* NOP */}	// check IFmap all done
	usleep(5);
	// xil_printf("==== total ifm send done ====\r\n");
	AXI_DMA_RxDone=0;
	ix =0  ;

	//-------------------------------------------------------------------

	XTime_GetTime(&end);
	time_used = ((end-start)*1000000)/(COUNTS_PER_SECOND);
	xil_printf("--------------------------------\r\n");
	xil_printf("end K_Generation \r\n");
	xil_printf(" %d us\r\n", time_used);
	xil_printf("--------------------------------\r\n");

}

void SA_v_gen( int cov_layer_number , u64* bias, u8* weights , u8*input_map , u8*output_map  ){

	u8* ifmap_dma_addr ;
	u8* ofmap_dma_addr ;

	int ix   ;
	XTime start, end;
	u32 time_used;
	XTime_GetTime(&start);
	u64 INST_HEAD[2] 	= {	0x22ffeebb3a12efef,
							0x22ffeebb3a12efef};
	u64 DATA_HEAD[2] 	= {	0x11ffdada4365efef,
							0x11ffdada4365efef};

	u64 SA_HEAD[2] =  {0x0011223344556677,
					   0x0011223344556677};
//	u64 CFG[18];

	u64 CFG[18]		 = 	{				0x22ffeebb3a12efef,
										0x22ffeebb3a12efef,
										0x000000000000ffff,
										0x007f00086444887d,
										0x0000000000020020,
										0x0000000000010140,
										0x0003000000000000,
										0x00003f3f3f000000,
										0x0000000000003f00,
										0x0000000000000201,
										0x000000400000003f,
										0x0000000000000000,
										0x0000000000000040,
										0x0000000000000040,
										0x000000000000ff0f,
										0x00000000ff010800,
										0x000000000000f003,
										0x000000100000f003

					 	};

	int TB_RUN_ROW 		= 64	;
	int TB_CH_IN 		= 512	  ;
	int TB_RUN_COL 		= 1	;
	int TB_KER_NUMBER 	= 512		;
	int TB_CFG_NUMBER	= 18	;
	int cfg_address 			;

	ix =0  ;

	ifmap_dma_addr = input_map ;
	ofmap_dma_addr = output_map ;

	XAxiDma_Reset(&DmaInstance);

	// xil_printf("==== Start DMA Transfer ====\r\n");
	XTime_GetTime(&start);

	//----- SA HEAD -----------------
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&SA_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&SA_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }

	//----- instruction --------------
	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&CFG) , 8*TB_CFG_NUMBER );
	AXI_DMA_Transfer    ((UINTPTR)(&CFG) , 8*TB_CFG_NUMBER , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	//Data head
	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD) , 2*8 );
	AXI_DMA_Transfer    ((UINTPTR)(&DATA_HEAD) , 2*8 , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)( weights ) , TB_CH_IN*TB_KER_NUMBER );
	AXI_DMA_Transfer    ((UINTPTR)( weights ) , TB_CH_IN*TB_KER_NUMBER  , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);
	// xil_printf("==== total kernel  send done ====\r\n");
	//----- Bias --------------
	//Data head
	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD) , 2*8 );
	AXI_DMA_Transfer    ((UINTPTR)(&DATA_HEAD) , 2*8 , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(bias) , TB_KER_NUMBER*8 );
	AXI_DMA_Transfer    ((UINTPTR)(bias) , TB_KER_NUMBER*8  , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);
	// xil_printf("==== total bias send done ====\r\n");

	//-------------------------------------------------------------------
	//-----  IFmap 15row  & OFmap 15row--------------

	ifmap_dma_addr = input_map   ;
	//Data head
	AXI_DMA_TxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD) , 2*8 );
	AXI_DMA_Transfer    ((UINTPTR)(&DATA_HEAD) , 2*8 , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;

	Xil_DCacheFlushRange(	(UINTPTR)(	ifmap_dma_addr )  , TB_RUN_ROW*TB_RUN_COL*TB_CH_IN	);		// all ifm 32ch
	AXI_DMA_Transfer(	 	(UINTPTR)(	ifmap_dma_addr )  , TB_RUN_ROW*TB_RUN_COL*TB_CH_IN 	, XAXIDMA_DMA_TO_DEVICE);
	AXI_DMA_RxDone=0;

	for( ix =0 ; ix<TB_RUN_ROW ; ix=ix+1 ){	//64 row
		AXI_DMA_Transfer(		(UINTPTR)(	ofmap_dma_addr )  , TB_RUN_COL*TB_KER_NUMBER	, XAXIDMA_DEVICE_TO_DMA); // one row ofm 16ch
		while (!AXI_DMA_RxDone  )  {	/* NOP */	}
		Xil_DCacheInvalidateRange((UINTPTR)(ofmap_dma_addr), (TB_RUN_COL*TB_KER_NUMBER) + 32);
		AXI_DMA_RxDone=0;
		ofmap_dma_addr = ofmap_dma_addr + TB_RUN_COL*TB_KER_NUMBER ;	// next row address
	}

	while (!AXI_DMA_TxDone ) {	/* NOP */}	// check IFmap all done
	usleep(5);
	// xil_printf("==== total ifm send done ====\r\n");
	AXI_DMA_RxDone=0;
	ix =0  ;

	//-------------------------------------------------------------------

	XTime_GetTime(&end);
	time_used = ((end-start)*1000000)/(COUNTS_PER_SECOND);
	xil_printf("--------------------------------\r\n");
	xil_printf("end V_Generation \r\n");
	xil_printf(" %d us\r\n", time_used);
	xil_printf("--------------------------------\r\n");

}

void SA_qkt_gen( int cov_layer_number , u64* bias, u8* weights , u8*input_map , u8*output_map  ){

	u8* ifmap_dma_addr ;
	u8* ofmap_dma_addr ;

	int ix   ;
	XTime startqkt, endqkt;
	u32 time_usedqkt;
	u64 INST_HEAD[2] 	= {	0x22ffeebb3a12efef,
							0x22ffeebb3a12efef};
	u64 DATA_HEAD[2] 	= {	0x11ffdada4365efef,
							0x11ffdada4365efef};

	u64 SA_HEAD[2] =  {0x0011223344556677,
					   0x0011223344556677};
//	u64 CFG[18];

	u64 CFG[18]		 = 	{				0x22ffeebb3a12efef,
										0x22ffeebb3a12efef,
										0x000000000000ffff,
										0x001d000611128001,
										0x0000000000020020,
										0x0000000000010140,
										0x0003000000000000,
										0x00003f3f3f000000,
										0x0000000000003f00,
										0x0000000000000201,
										0x0000004000000007,
										0x0000000000000000,
										0x0000000000000040,
										0x0000000000000040,
										0x000000000000ff01,
										0x000000003f000800,
										0x0000000000007000 ,
										0x0000001000007000

					 	};

	int TB_RUN_ROW 		= 64	;
	int TB_CH_IN 		= 512	  ;
	int TB_RUN_COL 		= 1	;
	int TB_KER_NUMBER 	= 64		;
	int TB_CFG_NUMBER	= 18	;
	int cfg_address 			;

	ix =0  ;

	ifmap_dma_addr = input_map ;
	ofmap_dma_addr = output_map ;

	XAxiDma_Reset(&DmaInstance);

	// xil_printf("==== Start DMA Transfer ====\r\n");
	XTime_GetTime(&startqkt);

	//----- SA HEAD -----------------
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&SA_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&SA_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }

	//----- instruction --------------

	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&CFG) , 8*TB_CFG_NUMBER );
	AXI_DMA_Transfer    ((UINTPTR)(&CFG) , 8*TB_CFG_NUMBER , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	//Data head
	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD) , 2*8 );
	AXI_DMA_Transfer    ((UINTPTR)(&DATA_HEAD) , 2*8 , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)( weights ) , TB_CH_IN*TB_KER_NUMBER );
	AXI_DMA_Transfer    ((UINTPTR)( weights ) , TB_CH_IN*TB_KER_NUMBER  , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);
	// xil_printf("==== total kernel  send done ====\r\n");
	//----- Bias --------------
	//Data head
	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD) , 2*8 );
	AXI_DMA_Transfer    ((UINTPTR)(&DATA_HEAD) , 2*8 , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(bias) , TB_KER_NUMBER*8 );
	AXI_DMA_Transfer    ((UINTPTR)(bias) , TB_KER_NUMBER*8  , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);
	// xil_printf("==== total bias send done ====\r\n");

	//-------------------------------------------------------------------
	//-----  IFmap 15row  & OFmap 15row--------------

	ifmap_dma_addr = input_map   ;
	//Data head
	AXI_DMA_TxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD) , 2*8 );
	AXI_DMA_Transfer    ((UINTPTR)(&DATA_HEAD) , 2*8 , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;

	Xil_DCacheFlushRange(	(UINTPTR)(	ifmap_dma_addr )  , TB_RUN_ROW*TB_RUN_COL*TB_CH_IN	);		// all ifm 32ch
	AXI_DMA_Transfer(	 	(UINTPTR)(	ifmap_dma_addr )  , TB_RUN_ROW*TB_RUN_COL*TB_CH_IN 	, XAXIDMA_DMA_TO_DEVICE);
	AXI_DMA_RxDone=0;

	for( ix =0 ; ix<TB_RUN_ROW ; ix=ix+1 ){	//64 row
		AXI_DMA_Transfer(		(UINTPTR)(	ofmap_dma_addr )  , TB_RUN_COL*TB_KER_NUMBER	, XAXIDMA_DEVICE_TO_DMA); // one row ofm 16ch
		while (!AXI_DMA_RxDone  )  {	/* NOP */	}
		Xil_DCacheInvalidateRange((UINTPTR)(ofmap_dma_addr), (TB_RUN_COL*TB_KER_NUMBER) + 32);
		AXI_DMA_RxDone=0;
		ofmap_dma_addr = ofmap_dma_addr + TB_RUN_COL*TB_KER_NUMBER ;	// next row address
	}

	while (!AXI_DMA_TxDone ) {	/* NOP */}	// check IFmap all done
	usleep(500);
	// xil_printf("==== total ifm send done ====\r\n");
	AXI_DMA_RxDone=0;
	ix =0  ;

	//-------------------------------------------------------------------

	XTime_GetTime(&endqkt);
	time_usedqkt = ((endqkt-startqkt)*1000000)/(COUNTS_PER_SECOND);
	xil_printf("--------------------------------\r\n");
	xil_printf("end Q*Kt \r\n");
	xil_printf(" %d us\r\n", time_usedqkt);
	xil_printf("--------------------------------\r\n");

}

void SA_SV( int cov_layer_number , u64* bias, u8* weights , u8*input_map , u8*output_map  ){

	u8* ifmap_dma_addr ;
	u8* ofmap_dma_addr ;

	int ix   ;
	XTime start, end;
	u32 time_used;
	XTime_GetTime(&start);
	u64 INST_HEAD[2] 	= {	0x22ffeebb3a12efef,
							0x22ffeebb3a12efef};
	u64 DATA_HEAD[2] 	= {	0x11ffdada4365efef,
							0x11ffdada4365efef};

	u64 SA_HEAD[2] =  {0x0011223344556677,
					   0x0011223344556677};
//	u64 CFG[18];

	u64 CFG[18]		 = 	{				0x22ffeebb3a12efef,
										0x22ffeebb3a12efef,
										0x000000000000ffff,
										0x001d000611128001,
										0x0000000000020008,
										0x0000000000010120,
										0x0003000000000000,
										0x00001f1f1f000000,
										0x0000000000001f00,
										0x0000000000000201,
										0x000000200000000f,
										0x0000000000000000,
										0x0000000000000020,
										0x0000000000000020,
										0x000000000000ff01,
										0x000000007f000800,
										0x000000000000f000,
										0x000000100000f000

					 	};

	int TB_RUN_ROW 		= 16	;
	int TB_CH_IN 		= 256	  ;
	int TB_RUN_COL 		= 1	;
	int TB_KER_NUMBER 	= 128		;
	int TB_CFG_NUMBER	= 18	;
	int cfg_address 			;

	ix =0  ;

	ifmap_dma_addr = input_map ;
	ofmap_dma_addr = output_map ;

	XAxiDma_Reset(&DmaInstance);

	// xil_printf("==== Start DMA Transfer ====\r\n");
	XTime_GetTime(&start);

	//----- SA HEAD -----------------
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&SA_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&SA_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }

	//----- instruction --------------
	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&CFG) , 8*TB_CFG_NUMBER );
	AXI_DMA_Transfer    ((UINTPTR)(&CFG) , 8*TB_CFG_NUMBER , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	//Data head
	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD) , 2*8 );
	AXI_DMA_Transfer    ((UINTPTR)(&DATA_HEAD) , 2*8 , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)( weights ) , TB_CH_IN*TB_KER_NUMBER );
	AXI_DMA_Transfer    ((UINTPTR)( weights ) , TB_CH_IN*TB_KER_NUMBER  , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);
	// xil_printf("==== total kernel  send done ====\r\n");
	//----- Bias --------------
	//Data head
	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD) , 2*8 );
	AXI_DMA_Transfer    ((UINTPTR)(&DATA_HEAD) , 2*8 , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(bias) , TB_KER_NUMBER*8 );
	AXI_DMA_Transfer    ((UINTPTR)(bias) , TB_KER_NUMBER*8  , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);
	// xil_printf("==== total bias send done ====\r\n");

	//-------------------------------------------------------------------
	//-----  IFmap 15row  & OFmap 15row--------------

	ifmap_dma_addr = input_map   ;
	//Data head
	AXI_DMA_TxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD) , 2*8 );
	AXI_DMA_Transfer    ((UINTPTR)(&DATA_HEAD) , 2*8 , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;

	Xil_DCacheFlushRange(	(UINTPTR)(	ifmap_dma_addr )  , TB_RUN_ROW*TB_RUN_COL*TB_CH_IN	);		// all ifm 32ch
	AXI_DMA_Transfer(	 	(UINTPTR)(	ifmap_dma_addr )  , TB_RUN_ROW*TB_RUN_COL*TB_CH_IN 	, XAXIDMA_DMA_TO_DEVICE);
	AXI_DMA_RxDone=0;

	for( ix =0 ; ix<TB_RUN_ROW ; ix=ix+1 ){	//64 row
		AXI_DMA_Transfer(		(UINTPTR)(	ofmap_dma_addr )  , TB_RUN_COL*TB_KER_NUMBER	, XAXIDMA_DEVICE_TO_DMA); // one row ofm 16ch
		while (!AXI_DMA_RxDone  )  {	/* NOP */	}
		Xil_DCacheInvalidateRange((UINTPTR)(ofmap_dma_addr), (TB_RUN_COL*TB_KER_NUMBER) + 32);
		AXI_DMA_RxDone=0;
		ofmap_dma_addr = ofmap_dma_addr + TB_RUN_COL*TB_KER_NUMBER ;	// next row address
	}

	while (!AXI_DMA_TxDone ) {	/* NOP */}	// check IFmap all done
	usleep(5);
	// xil_printf("==== total ifm send done ====\r\n");
	AXI_DMA_RxDone=0;
	ix =0  ;

	//-------------------------------------------------------------------

	XTime_GetTime(&end);
	time_used = ((end-start)*1000000)/(COUNTS_PER_SECOND);
	xil_printf("--------------------------------\r\n");
	xil_printf("end S*V \r\n");
	xil_printf(" %d us\r\n", time_used);
	xil_printf("--------------------------------\r\n");

}

void SA_out( int cov_layer_number , u64* bias, u8* weights , u8*input_map , u8*output_map  ){

	u8* ifmap_dma_addr ;
	u8* ofmap_dma_addr ;

	int ix   ;
	XTime start, end;
	u32 time_used;
	XTime_GetTime(&start);
	u64 INST_HEAD[2] 	= {	0x22ffeebb3a12efef,
							0x22ffeebb3a12efef};
	u64 DATA_HEAD[2] 	= {	0x11ffdada4365efef,
							0x11ffdada4365efef};

	u64 SA_HEAD[2] =  {0x0011223344556677,
					   0x0011223344556677};

	u64 CFG[18]		 = 	{				0x22ffeebb3a12efef,
										0x22ffeebb3a12efef,
										0x000000000000ffff,
										0x007f00086444887d,
										0x0000000000020020,
										0x0000000000010140,
										0x0003000000000000,
										0x00003f3f3f000000,
										0x0000000000003f00,
										0x0000000000000201,
										0x000000400000003f,
										0x0000000000000000,
										0x0000000000000040,
										0x0000000000000040,
										0x000000000000ff0f,
										0x00000000ff010800,
										0x000000000000f003,
										0x000000100000f003

					 	};

	int TB_RUN_ROW 		= 64	;
	int TB_CH_IN 		= 512	  ;
	int TB_RUN_COL 		= 1	;
	int TB_KER_NUMBER 	= 512		;
	int TB_CFG_NUMBER	= 18	;
	int cfg_address 			;

	ix =0  ;

	ifmap_dma_addr = input_map ;
	ofmap_dma_addr = output_map ;

	XAxiDma_Reset(&DmaInstance);

	// xil_printf("==== Start DMA Transfer ====\r\n");
	XTime_GetTime(&start);

	//----- SA HEAD -----------------
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&SA_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&SA_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }

	//----- instruction --------------
	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&CFG) , 8*TB_CFG_NUMBER );
	AXI_DMA_Transfer    ((UINTPTR)(&CFG) , 8*TB_CFG_NUMBER , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	//Data head
	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD) , 2*8 );
	AXI_DMA_Transfer    ((UINTPTR)(&DATA_HEAD) , 2*8 , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)( weights ) , TB_CH_IN*TB_KER_NUMBER );
	AXI_DMA_Transfer    ((UINTPTR)( weights ) , TB_CH_IN*TB_KER_NUMBER  , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);
	// xil_printf("==== total kernel  send done ====\r\n");
	//----- Bias --------------
	//Data head
	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD) , 2*8 );
	AXI_DMA_Transfer    ((UINTPTR)(&DATA_HEAD) , 2*8 , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(bias) , TB_KER_NUMBER*8 );
	AXI_DMA_Transfer    ((UINTPTR)(bias) , TB_KER_NUMBER*8  , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);
	// xil_printf("==== total bias send done ====\r\n");


	//-------------------------------------------------------------------
	//-----  IFmap 15row  & OFmap 15row--------------

	ifmap_dma_addr = input_map   ;
	AXI_DMA_TxDone=0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD) , 2*8 );
	AXI_DMA_Transfer    ((UINTPTR)(&DATA_HEAD) , 2*8 , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone ) {	/* NOP */}
	usleep(5);

	AXI_DMA_TxDone=0;
	AXI_DMA_RxDone=0;

	Xil_DCacheFlushRange(	(UINTPTR)(	ifmap_dma_addr )  , TB_RUN_ROW*TB_RUN_COL*TB_CH_IN	);
	AXI_DMA_Transfer(	 	(UINTPTR)(	ifmap_dma_addr )  , TB_RUN_ROW*TB_RUN_COL*TB_CH_IN 	, XAXIDMA_DMA_TO_DEVICE);
	AXI_DMA_RxDone=0;

	for( ix =0 ; ix<TB_RUN_ROW ; ix=ix+1 ){
		AXI_DMA_Transfer(		(UINTPTR)(	ofmap_dma_addr )  , TB_RUN_COL*TB_KER_NUMBER	, XAXIDMA_DEVICE_TO_DMA);
		while (!AXI_DMA_RxDone  )  {	/* NOP */	}
		Xil_DCacheInvalidateRange((UINTPTR)(ofmap_dma_addr), (TB_RUN_COL*TB_KER_NUMBER) + 32);
		AXI_DMA_RxDone=0;
		ofmap_dma_addr = ofmap_dma_addr + TB_RUN_COL*TB_KER_NUMBER ;
	}

	while (!AXI_DMA_TxDone ) { /* NOP */ }
	usleep(5);
	// xil_printf("==== total ifm send done ====\r\n");
	AXI_DMA_RxDone=0;
	ix =0  ;

	XTime_GetTime(&end);
	time_used = ((end-start)*1000000)/(COUNTS_PER_SECOND);
	xil_printf("--------------------------------\r\n");
	xil_printf("end Self_attention out \r\n");
	xil_printf(" %d us\r\n", time_used);
	xil_printf("--------------------------------\r\n");

}

void FFN_first_layer(u64 *input, u64 *weight, u64 *bias, u64 *output)
{
	u64 *input_addr;
	u64 *weight_addr;
	u64 *bias_addr;
	u64 *output_addr;

	int ix;
	XTime start, end;
	u32 time_used;
	// u64 INST_HEAD[2] = {0x22ffeebb3a12efef,
	// 					0x22ffeebb3a12efef};
	u64 INST_HEAD[2] = {0xefef123abbeeff22,
						0xefef123abbeeff22};
	// u64 DATA_HEAD[2] = {0x11ffdada4365efef,
	// 					0x11ffdada4365efef};
	u64 DATA_HEAD[2] = {0xefef6543dadaff11,
						0xefef6543dadaff11};

	u64 FFN_HEAD[2] = {0xffeeddccbbaa9988,
					   0xffeeddccbbaa9988};

	u64 CFG[16] = {
		0xffff000000000000,
		0x1484121114001b00,
		0x0000000000000fff,
		0x00000000000001ff,
		0x000000000001fe3f,
		0x0000000000000000,
		0x0000000000000000,
		0x0000000000000000,
		0x0000000000000000,
		0x0000000000000000,
		0x0000000000000000,
		0x0000000000000000,
		0x0000000000000000,
		0x0000000000000000,
		0xff8000e000000000,
		0x1f80010000000000};

	int TB_RUN_INROW	= 8		;
	int TB_RUN_INCOL	= 64	;
	int TB_RUN_WCOL		= 2048	;
	int TB_RUN_OTCOL	= 256	;
	int TB_CFG_NUMBER	= 16	;

	ix = 0;

	input_addr = input;
	weight_addr = weight;
	bias_addr = bias;
	output_addr = output;

//	xil_printf("==== Start DMA Transfer ====\r\n");
//	XTime_GetTime(&start);

	//----- FFN HEAD -----------------
	// xil_printf("---- Start FFN Head Transfer ----\r\n");
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&FFN_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&FFN_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
	// xil_printf("---- end FFN Head Transfer ----\r\n");

	//----- instruction --------------
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&INST_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&INST_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);

	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&CFG), TB_CFG_NUMBER * 8);
	AXI_DMA_Transfer((UINTPTR)(&CFG), TB_CFG_NUMBER * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);

	//-------------------------------------------------------------------
	//-----  IF  ------------

	// Data head
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&DATA_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);

	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(input_addr), TB_RUN_INROW * TB_RUN_INCOL * 8);
	AXI_DMA_Transfer((UINTPTR)(input_addr), TB_RUN_INROW * TB_RUN_INCOL * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);

	//-------------------------------------------------------------------
	//-----  BIAS  ------------

	// Data head
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&DATA_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);

	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(bias_addr), TB_RUN_WCOL / 4 * 8);
	AXI_DMA_Transfer((UINTPTR)(bias_addr), TB_RUN_WCOL / 4 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);
	
	bias_addr = bias_addr + (TB_RUN_WCOL / 4) ;

	//-------------------------------------------------------------------
	//-----  WEIGHT  ------------

	// Data head
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&DATA_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);

	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(weight_addr), TB_RUN_INCOL * (TB_RUN_WCOL / 4 + 8) * 8);
	AXI_DMA_Transfer((UINTPTR)(weight_addr), TB_RUN_INCOL * (TB_RUN_WCOL / 4 + 8) * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);

	weight_addr = weight_addr + TB_RUN_INCOL * (TB_RUN_WCOL / 4 + 8) ;

	//-------------------------------------------------------------------
	//-----  BIAS  ------------

	// Data head
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&DATA_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);

	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(bias_addr), TB_RUN_WCOL / 4 * 8);
	AXI_DMA_Transfer((UINTPTR)(bias_addr), TB_RUN_WCOL / 4 * 8, XAXIDMA_DMA_TO_DEVICE);

	for (ix = 0; ix < TB_RUN_INROW; ix = ix + 1)
	{
		AXI_DMA_Transfer((UINTPTR)(output_addr), TB_RUN_OTCOL / 4 * 8, XAXIDMA_DEVICE_TO_DMA);
		while (!AXI_DMA_RxDone){ /* NOP */ }
		Xil_DCacheInvalidateRange((UINTPTR)(output_addr), TB_RUN_OTCOL / 4 * 8);
		AXI_DMA_RxDone = 0;
		output_addr = output_addr + TB_RUN_OTCOL; // next row address
	}

	output_addr = output + (TB_RUN_OTCOL / 4) ;

	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);

	bias_addr = bias_addr + (TB_RUN_WCOL / 4) ;

	//-------------------------------------------------------------------
	//-----  WEIGHT  ------------

	// Data head
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&DATA_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);

	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(weight_addr), TB_RUN_INCOL * TB_RUN_WCOL / 4 * 8);
	AXI_DMA_Transfer((UINTPTR)(weight_addr), TB_RUN_INCOL * TB_RUN_WCOL / 4 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);

	weight_addr = weight_addr + TB_RUN_INCOL * TB_RUN_WCOL / 4 ;

	//-------------------------------------------------------------------
	//-----  BIAS  ------------

	// Data head
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&DATA_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);

	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(bias_addr), TB_RUN_WCOL / 4 * 8);
	AXI_DMA_Transfer((UINTPTR)(bias_addr), TB_RUN_WCOL / 4 * 8, XAXIDMA_DMA_TO_DEVICE);

	for (ix = 0; ix < TB_RUN_INROW; ix = ix + 1)
	{
		AXI_DMA_Transfer((UINTPTR)(output_addr), TB_RUN_OTCOL / 4 * 8, XAXIDMA_DEVICE_TO_DMA);
		while (!AXI_DMA_RxDone){ /* NOP */ }
		Xil_DCacheInvalidateRange((UINTPTR)(output_addr), TB_RUN_OTCOL / 4 * 8);
		AXI_DMA_RxDone = 0;
		output_addr = output_addr + TB_RUN_OTCOL ; // next row address
	}

	output_addr = output + (TB_RUN_OTCOL / 4) * 2 ;

	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);

	bias_addr = bias_addr + (TB_RUN_WCOL / 4) ;

	//-------------------------------------------------------------------
	//-----  WEIGHT  ------------

	// Data head
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&DATA_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);

	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(weight_addr), TB_RUN_INCOL * TB_RUN_WCOL / 4 * 8);
	AXI_DMA_Transfer((UINTPTR)(weight_addr), TB_RUN_INCOL * TB_RUN_WCOL / 4 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);

	weight_addr = weight_addr + TB_RUN_INCOL * TB_RUN_WCOL / 4 ;

	//-------------------------------------------------------------------
	//-----  BIAS  ------------

	// Data head
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&DATA_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);

	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(bias_addr), TB_RUN_WCOL / 4 * 8);
	AXI_DMA_Transfer((UINTPTR)(bias_addr), TB_RUN_WCOL / 4 * 8, XAXIDMA_DMA_TO_DEVICE);

	for (ix = 0; ix < TB_RUN_INROW; ix = ix + 1)
	{
		AXI_DMA_Transfer((UINTPTR)(output_addr), TB_RUN_OTCOL / 4 * 8, XAXIDMA_DEVICE_TO_DMA);
		while (!AXI_DMA_RxDone){ /* NOP */ }
		Xil_DCacheInvalidateRange((UINTPTR)(output_addr), TB_RUN_OTCOL / 4 * 8);
		AXI_DMA_RxDone = 0;
		output_addr = output_addr + TB_RUN_OTCOL ; // next row address
	}

	output_addr = output + (TB_RUN_OTCOL / 4) * 3 ;

	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);

	bias_addr = bias_addr + (TB_RUN_WCOL / 4) ;

	//-------------------------------------------------------------------
	//-----  WEIGHT  ------------

	// Data head
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&DATA_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);

	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(weight_addr), TB_RUN_INCOL * (TB_RUN_WCOL / 4 - 8) * 8);
	AXI_DMA_Transfer((UINTPTR)(weight_addr), TB_RUN_INCOL * (TB_RUN_WCOL / 4 - 8) * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);

	weight_addr = weight_addr + TB_RUN_INCOL * (TB_RUN_WCOL / 4 - 8) ;

	for (ix = 0; ix < TB_RUN_INROW; ix = ix + 1)
	{
		AXI_DMA_Transfer((UINTPTR)(output_addr), TB_RUN_OTCOL / 4 * 8, XAXIDMA_DEVICE_TO_DMA);
		while (!AXI_DMA_RxDone){ /* NOP */ }
//		usleep(5);
		Xil_DCacheInvalidateRange((UINTPTR)(output_addr), TB_RUN_OTCOL / 4 * 8);
		AXI_DMA_RxDone = 0;
		output_addr = output_addr + TB_RUN_OTCOL ; // next row address
	}

//	usleep(5);

	// XTime_GetTime(&end);

	//-------------------------------------------------------------------

	// time_used = ((end - start) * 1000000) / (COUNTS_PER_SECOND);
	// xil_printf("--------------------------------\r\n");
	// xil_printf("end FFN first layer \r\n");
	// xil_printf(" %d us\r\n", time_used);
	// xil_printf("--------------------------------\r\n");
}

void FFN_second_layer(u64 *input, u64 *weight, u64 *bias, u64 *output)
{
	u64 *input_addr;
	u64 *weight_addr;
	u64 *bias_addr;
	u64 *output_addr;

	int ix;
	XTime start, end;
	u32 time_used;
	// u64 INST_HEAD[2] = {0x22ffeebb3a12efef,
	// 					0x22ffeebb3a12efef};
	u64 INST_HEAD[2] = {0xefef123abbeeff22,
						0xefef123abbeeff22};
	// u64 DATA_HEAD[2] = {0x11ffdada4365efef,
	// 					0x11ffdada4365efef};
	u64 DATA_HEAD[2] = {0xefef6543dadaff11,
						0xefef6543dadaff11};
	u64 FFN_HEAD[2] = {0xffeeddccbbaa9988,
					   0xffeeddccbbaa9988};

	u64 CFG[16] = {
		0xffff000000000000,
		0x1484121114001b00,
		0x00000000000003ff,
		0x00000000000001ff,
		0x0000000000007eff,
		0x0000000000000000,
		0x0000000000000000,
		0x0000000000000000,
		0x0000000000000000,
		0x0000000000000000,
		0x0000000000000000,
		0x0000000000000000,
		0x0000000000000000,
		0x0000000000000000,
		0x3f80002000000000,
		0x1f80004000000000};

	int TB_RUN_INROW	= 2		;
	int TB_RUN_INCOL	= 256	;
	int TB_RUN_WCOL		= 512	;
	int TB_RUN_OTCOL	= 64	;
	int TB_CFG_NUMBER	= 16	;

	input_addr = input;
	weight_addr = weight;
	bias_addr = bias;
	output_addr = output;

//	xil_printf("==== Start DMA Transfer ====\r\n");
//	XTime_GetTime(&start);

	//----- FFN HEAD -----------------
	// xil_printf("---- Start FFN Head Transfer ----\r\n");
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&FFN_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&FFN_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
	// xil_printf("---- end FFN Head Transfer ----\r\n");

	//----- instruction --------------
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&INST_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&INST_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
	// usleep(5);

	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&CFG), TB_CFG_NUMBER * 8);
	AXI_DMA_Transfer((UINTPTR)(&CFG), TB_CFG_NUMBER * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
	// usleep(5);

	//-------------------------------------------------------------------
	//-----  IF  ------------

	// Data head
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&DATA_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
	// usleep(5);

	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(input_addr), TB_RUN_INROW * TB_RUN_INCOL * 8);
	AXI_DMA_Transfer((UINTPTR)(input_addr), TB_RUN_INROW * TB_RUN_INCOL * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
	// usleep(5);

	//-------------------------------------------------------------------
	//-----  BIAS  ------------

	// Data head
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&DATA_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
	// usleep(5);

	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(bias_addr), TB_RUN_WCOL * 8);
	AXI_DMA_Transfer((UINTPTR)(bias_addr), TB_RUN_WCOL * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
	// usleep(5);

	//-------------------------------------------------------------------
	//-----  WEIGHT  ------------

	// Data head
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&DATA_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
	// usleep(5);

	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(weight_addr), TB_RUN_INCOL * TB_RUN_WCOL * 8);
	AXI_DMA_Transfer((UINTPTR)(weight_addr), TB_RUN_INCOL * TB_RUN_WCOL * 8, XAXIDMA_DMA_TO_DEVICE);
//	usleep(5);

	while (!AXI_DMA_TxDone){ /* NOP */ }
	// usleep(5);
	AXI_DMA_RxDone = 0;

	for (ix = 0; ix < TB_RUN_INROW; ix = ix + 1)
	{
		// usleep(5);
		AXI_DMA_Transfer((UINTPTR)(output_addr), TB_RUN_OTCOL * 8, XAXIDMA_DEVICE_TO_DMA);
		while (!AXI_DMA_RxDone){ /* NOP */ }
		Xil_DCacheInvalidateRange((UINTPTR)(output_addr), TB_RUN_OTCOL * 8);
		AXI_DMA_RxDone = 0;
		output_addr = output_addr + TB_RUN_OTCOL ; // next row address
	}

//	AXI_DMA_Transfer((UINTPTR)(output_addr), TB_RUN_INROW * TB_RUN_OTCOL * 8, XAXIDMA_DEVICE_TO_DMA);
//	while (!AXI_DMA_RxDone){ /* NOP */ }
//	Xil_DCacheInvalidateRange((UINTPTR)(output_addr), TB_RUN_INROW * TB_RUN_OTCOL * 8);

//	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);

	// XTime_GetTime(&end);

	//-------------------------------------------------------------------

	// time_used = ((end - start) * 1000000) / (COUNTS_PER_SECOND);
	// xil_printf("--------------------------------\r\n");
	// xil_printf("end FFN second layer \r\n");
	// xil_printf(" %d us\r\n", time_used);
	// xil_printf("--------------------------------\r\n");
}

void K_generation(u64 *input, u64 *weight, u64 *bias, u64 *output)
{
	u64 *input_addr;
	u64 *weight_addr;
	u64 *bias_addr;
	u64 *output_addr;

	int ix;
	XTime start, end;
	u32 time_used;
	// u64 INST_HEAD[2] = {0x22ffeebb3a12efef,
	// 					0x22ffeebb3a12efef};
	u64 INST_HEAD[2] = {0xefef123abbeeff22,
						0xefef123abbeeff22};
	// u64 DATA_HEAD[2] = {0x11ffdada4365efef,
	// 					0x11ffdada4365efef};
	u64 DATA_HEAD[2] = {0xefef6543dadaff11,
						0xefef6543dadaff11};
	u64 FFN_HEAD[2] = {0xffeeddccbbaa9988,
					   0xffeeddccbbaa9988};

	u64 CFG[16] = {
		0xffff000000000000,
		0x7d88446408007f00,
		0x0000000000000fff,
		0x00000000000001ff,
		0x0000000000007e3f,
		0x0000000000000000,
		0x0000000000000000,
		0x0000000000000000,
		0x0000000000000000,
		0x0000000000000000,
		0x0000000000000000,
		0x0000000000000000,
		0x0000000000000000,
		0x0000000000000000,
		0xff8000e000000000,
		0x1f80010000000000
	};

	int TB_RUN_INROW	= 8		;
	int TB_RUN_INCOL	= 64	;
	int TB_RUN_WCOL		= 512	;
	int TB_RUN_OTCOL	= 64	;
	int TB_CFG_NUMBER	= 16	;

	input_addr = input;
	weight_addr = weight;
	bias_addr = bias;
	output_addr = output;

//	xil_printf("==== Start DMA Transfer ====\r\n");
//	XTime_GetTime(&start);

	//----- FFN HEAD -----------------
	// xil_printf("---- Start FFN Head Transfer ----\r\n");
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&FFN_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&FFN_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
	// xil_printf("---- end FFN Head Transfer ----\r\n");

	//----- instruction --------------
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&INST_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&INST_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
	// usleep(5);

	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&CFG), TB_CFG_NUMBER * 8);
	AXI_DMA_Transfer((UINTPTR)(&CFG), TB_CFG_NUMBER * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
	// usleep(5);

	//-------------------------------------------------------------------
	//-----  IF  ------------

	// Data head
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&DATA_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
	// usleep(5);

	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(input_addr), TB_RUN_INROW * TB_RUN_INCOL * 8);
	AXI_DMA_Transfer((UINTPTR)(input_addr), TB_RUN_INROW * TB_RUN_INCOL * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
	// usleep(5);

	//-------------------------------------------------------------------
	//-----  BIAS  ------------

	// Data head
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&DATA_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
	// usleep(5);

	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(bias_addr), TB_RUN_WCOL * 8);
	AXI_DMA_Transfer((UINTPTR)(bias_addr), TB_RUN_WCOL * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
	// usleep(5);

	//-------------------------------------------------------------------
	//-----  WEIGHT  ------------

	// Data head
	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&DATA_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&DATA_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
	// usleep(5);

	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(weight_addr), TB_RUN_INCOL * TB_RUN_WCOL * 8);
	AXI_DMA_Transfer((UINTPTR)(weight_addr), TB_RUN_INCOL * TB_RUN_WCOL * 8, XAXIDMA_DMA_TO_DEVICE);
//	usleep(5);

	while (!AXI_DMA_TxDone){ /* NOP */ }
	// usleep(5);
	AXI_DMA_RxDone = 0;

	for (ix = 0; ix < TB_RUN_INROW; ix = ix + 1)
	{
		// usleep(5);
		AXI_DMA_Transfer((UINTPTR)(output_addr), TB_RUN_OTCOL * 8, XAXIDMA_DEVICE_TO_DMA);
		while (!AXI_DMA_RxDone){ /* NOP */ }
		Xil_DCacheInvalidateRange((UINTPTR)(output_addr), TB_RUN_OTCOL * 8);
		AXI_DMA_RxDone = 0;
		output_addr = output_addr + TB_RUN_OTCOL ; // next row address
	}

//	AXI_DMA_Transfer((UINTPTR)(output_addr), TB_RUN_INROW * TB_RUN_OTCOL * 8, XAXIDMA_DEVICE_TO_DMA);
//	while (!AXI_DMA_RxDone){ /* NOP */ }
//	Xil_DCacheInvalidateRange((UINTPTR)(output_addr), TB_RUN_INROW * TB_RUN_OTCOL * 8);

//	while (!AXI_DMA_TxDone){ /* NOP */ }
//	usleep(5);

	// XTime_GetTime(&end);

	//-------------------------------------------------------------------

	// time_used = ((end - start) * 1000000) / (COUNTS_PER_SECOND);
	// xil_printf("--------------------------------\r\n");
	// xil_printf("end FFN second layer \r\n");
	// xil_printf(" %d us\r\n", time_used);
	// xil_printf("--------------------------------\r\n");
}

void ibert_FFN_first_layer(u64 *input, u64 *weight, u64 *bias, u64 *output)
{
	u64 *input_addr;
	u64 *weight_addr;
	u64 *bias_addr;
	u64 *output_addr;

	int ix;
	XTime start, end;
	u32 time_used;

	input_addr = input;
	weight_addr = weight;
	bias_addr = bias;
	output_addr = output;

	// test reset
	XAxiDma_Reset(&DmaInstance);

	XTime_GetTime(&start);

	for(ix=0; ix<8; ix=ix+1){

		FFN_first_layer(input_addr, weight_addr, bias_addr, output_addr);
		input_addr = input_addr + 8 * 64 ;
		output_addr = output_addr + 8 * 256 ;

//		xil_printf("---- %d ----\r\n", ix+1);

		// FFN_first_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 8 * 64 ;
		// output_addr = output_addr + 8 * 256 ;

		// FFN_first_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 8 * 64 ;
		// output_addr = output_addr + 8 * 256 ;

		// FFN_first_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 8 * 64 ;
		// output_addr = output_addr + 8 * 256 ;

		// FFN_first_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 8 * 64 ;
		// output_addr = output_addr + 8 * 256 ;

		// FFN_first_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 8 * 64 ;
		// output_addr = output_addr + 8 * 256 ;

		// FFN_first_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 8 * 64 ;
		// output_addr = output_addr + 8 * 256 ;

		// FFN_first_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 8 * 64 ;
		// output_addr = output_addr + 8 * 256 ;

	}

	XTime_GetTime(&end);

	time_used = ((end - start) * 1000000) / (COUNTS_PER_SECOND);
	xil_printf("--------------------------------\r\n");
	xil_printf("end FFN first layer \r\n");
	xil_printf(" %d us\r\n", time_used);
	xil_printf("--------------------------------\r\n");
}

void ibert_FFN_second_layer(u64 *input, u64 *weight, u64 *bias, u64 *output)
{
	u64 *input_addr;
	u64 *weight_addr;
	u64 *bias_addr;
	u64 *output_addr;

	int ix;
	XTime start, end;
	u32 time_used;

	input_addr = input;
	weight_addr = weight;
	bias_addr = bias;
	output_addr = output;

	XAxiDma_Reset(&DmaInstance);

	XTime_GetTime(&start);

	for(ix=0; ix<4; ix=ix+1){
		// 1
		FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		input_addr = input_addr + 2 * 256 ;
		output_addr = output_addr + 2 * 64 ;
		// 2
		FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		input_addr = input_addr + 2 * 256 ;
		output_addr = output_addr + 2 * 64 ;
		// 3
		FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		input_addr = input_addr + 2 * 256 ;
		output_addr = output_addr + 2 * 64 ;
		// 4
		FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		input_addr = input_addr + 2 * 256 ;
		output_addr = output_addr + 2 * 64 ;
		// 5
		FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		input_addr = input_addr + 2 * 256 ;
		output_addr = output_addr + 2 * 64 ;
		// 6
		FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		input_addr = input_addr + 2 * 256 ;
		output_addr = output_addr + 2 * 64 ;
		// 7
		FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		input_addr = input_addr + 2 * 256 ;
		output_addr = output_addr + 2 * 64 ;
		// 8
		FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		input_addr = input_addr + 2 * 256 ;
		output_addr = output_addr + 2 * 64 ;
		// // 9
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 10
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 11
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 12
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 13
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 14
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 15
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 16
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 17
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 18
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 19
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 20
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 21
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 22
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 23
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 24
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 25
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 26
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 27
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 28
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 29
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 30
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 31
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;
		// // 32
		// FFN_second_layer(input_addr, weight_addr, bias_addr, output_addr);
		// input_addr = input_addr + 2 * 256 ;
		// output_addr = output_addr + 2 * 64 ;

	}

	XTime_GetTime(&end);

	time_used = ((end - start) * 1000000) / (COUNTS_PER_SECOND);
	xil_printf("--------------------------------\r\n");
	xil_printf("end FFN second layer \r\n");
	xil_printf(" %d us\r\n", time_used);
	xil_printf("--------------------------------\r\n");
}

#define INPUT_WORDS_64   8                  // 416 x u64
#define OUTPUT_WORDS_64  64                 // 3328 x u64
#define INPUT_BYTES      (INPUT_WORDS_64  * 8)
#define OUTPUT_BYTES     (OUTPUT_WORDS_64 * 8)

void softmax(u64 *input, u64 *output)
{
    u64 	*input_addr  = input;
    u64     *output_addr = output;

	u64 SOFTMAX_HEAD[2] = {0x8899aabbccddeeff,
					   	   0x8899aabbccddeeff};

    // XTime start, end;
    // u32   time_used;

	int ix;

	// XAxiDma_Reset(&DmaInstance);

    // xil_printf("==== Start DMA Transfer ====\r\n");
    // XTime_GetTime(&start);

    for(ix = 0; ix < 8; ix = ix + 1)
    {

		AXI_DMA_TxDone = 0;
		Xil_DCacheFlushRange((UINTPTR)(&SOFTMAX_HEAD), 2 * 8);
		AXI_DMA_Transfer((UINTPTR)(&SOFTMAX_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
		while (!AXI_DMA_TxDone){ /* NOP */ }

		AXI_DMA_TxDone = 0;
		Xil_DCacheFlushRange((UINTPTR)input_addr, INPUT_BYTES);
		AXI_DMA_Transfer((UINTPTR)input_addr, INPUT_BYTES, XAXIDMA_DMA_TO_DEVICE);

		AXI_DMA_RxDone = 0;
		AXI_DMA_Transfer((UINTPTR)output_addr, OUTPUT_BYTES, XAXIDMA_DEVICE_TO_DMA);
		while (!AXI_DMA_RxDone) { /* NOP */ }
		Xil_DCacheInvalidateRange((UINTPTR)output_addr, OUTPUT_BYTES);

		input_addr = input_addr + 8;
		output_addr = output_addr + 64;

		while (!AXI_DMA_TxDone){ /* NOP */ }

		// xil_printf("iterartion = %d \r\n", ix);

    }

//    AXI_DMA_RxDone = 0;
//    AXI_DMA_Transfer((UINTPTR)output_addr, OUTPUT_BYTES, XAXIDMA_DEVICE_TO_DMA);
//    while (!AXI_DMA_RxDone) { /* NOP */ }
//    Xil_DCacheInvalidateRange((UINTPTR)output_addr, OUTPUT_BYTES);
//
//    output_addr = output_addr + 64;
//
//    AXI_DMA_RxDone = 0;
//    AXI_DMA_Transfer((UINTPTR)output_addr, OUTPUT_BYTES, XAXIDMA_DEVICE_TO_DMA);
//    while (!AXI_DMA_RxDone) { /* NOP */ }
//    Xil_DCacheInvalidateRange((UINTPTR)output_addr, OUTPUT_BYTES);
//
//    output_addr = output_addr + 64;
//
//    AXI_DMA_RxDone = 0;
//    AXI_DMA_Transfer((UINTPTR)output_addr, OUTPUT_BYTES, XAXIDMA_DEVICE_TO_DMA);
//    while (!AXI_DMA_RxDone) { /* NOP */ }
//    Xil_DCacheInvalidateRange((UINTPTR)output_addr, OUTPUT_BYTES);
//
//    output_addr = output_addr + 64;
//
//    AXI_DMA_RxDone = 0;
//    AXI_DMA_Transfer((UINTPTR)output_addr, OUTPUT_BYTES, XAXIDMA_DEVICE_TO_DMA);
//    while (!AXI_DMA_RxDone) { /* NOP */ }
//    Xil_DCacheInvalidateRange((UINTPTR)output_addr, OUTPUT_BYTES);
//
//    output_addr = output_addr + 64;
//
//    AXI_DMA_RxDone = 0;
//    AXI_DMA_Transfer((UINTPTR)output_addr, OUTPUT_BYTES, XAXIDMA_DEVICE_TO_DMA);
//    while (!AXI_DMA_RxDone) { /* NOP */ }
//    Xil_DCacheInvalidateRange((UINTPTR)output_addr, OUTPUT_BYTES);
//
//    output_addr = output_addr + 64;
//
//    AXI_DMA_RxDone = 0;
//    AXI_DMA_Transfer((UINTPTR)output_addr, OUTPUT_BYTES, XAXIDMA_DEVICE_TO_DMA);
//    while (!AXI_DMA_RxDone) { /* NOP */ }
//    Xil_DCacheInvalidateRange((UINTPTR)output_addr, OUTPUT_BYTES);
//
//    output_addr = output_addr + 64;
//
//    AXI_DMA_RxDone = 0;
//    AXI_DMA_Transfer((UINTPTR)output_addr, OUTPUT_BYTES, XAXIDMA_DEVICE_TO_DMA);
//    while (!AXI_DMA_RxDone) { /* NOP */ }
//    Xil_DCacheInvalidateRange((UINTPTR)output_addr, OUTPUT_BYTES);
//
//	while (!AXI_DMA_TxDone) { /* NOP */ }

    // XTime_GetTime(&end);

    // time_used = (u32)(((end - start) * 1000000) / (COUNTS_PER_SECOND));
    // xil_printf("--------------------------------\r\n");
    // xil_printf("end softmax \r\n");
    // xil_printf(" %u us\r\n", time_used);
    // xil_printf("--------------------------------\r\n");
}

void ibert_softmax(u64 *input, u64 *output)
{
	u64 *input_addr;
	u64 *output_addr;

	int ix;
	XTime start, end;
	u32 time_used;

	input_addr = input;
	output_addr = output;

	XAxiDma_Reset(&DmaInstance);

	XTime_GetTime(&start);

	for(ix=0; ix<8; ix=ix+1){

		softmax(input_addr, output_addr);

	}

	XTime_GetTime(&end);

	time_used = ((end - start) * 1000000) / (COUNTS_PER_SECOND);
    xil_printf("--------------------------------\r\n");
    xil_printf("end softmax \r\n");
    xil_printf(" %u us\r\n", time_used);
    xil_printf("--------------------------------\r\n");
}

void COMP_ARRAY_DATA(u64 *array01_base, int comp_length, u64 *array02_base) {
	u32 i = 0;
	u32 error = 0;
	u32 out_number = 0;

	u32 a1_high ;
	u32 a1_low  ;
	u32 a2_high ;
	u32 a2_low  ;

	xil_printf("--------------------------------\r\n");

	for (i = 0; i < comp_length; i = i + 1) {
		u64 a1 = *(array01_base + i);
		u64 a2 = *(array02_base + i);
		out_number += 1;

		if (a1 != a2) {
			error += 1;

			a1_high = (u32)(a1 >> 32);
			a1_low = (u32)(a1 & 0xFFFFFFFF);
			a2_high = (u32)(a2 >> 32);
			a2_low = (u32)(a2 & 0xFFFFFFFF);

			xil_printf("FAIL at %d: ref = %08x%08x, tgt = %08x%08x\r\n", i, a1_high, a1_low, a2_high, a2_low);
		}
		else {
			out_number += 1;

			a1_high = (u32)(a1 >> 32);
			a1_low = (u32)(a1 & 0xFFFFFFFF);
			a2_high = (u32)(a2 >> 32);
			a2_low = (u32)(a2 & 0xFFFFFFFF);

//			xil_printf("SUCCESS at %d: ref = %08x%08x, tgt = %08x%08x\r\n", i, a1_high, a1_low, a2_high, a2_low);
		}
	}

	xil_printf("array_compare end\r\n");

	if (error == 0) {
		xil_printf("array_compare result pass!\r\n");
		xil_printf("output number = %d\r\n", out_number);
	}
	else {
		xil_printf("array_compare error = %d\r\n", error);
		// xil_printf("array_compare result pass!\r\n");
		xil_printf("output number = %d\r\n", out_number);
	}

	xil_printf("--------------------------------\r\n");
}

void SA_COMP_ARRAY_DATA(	 u8* array01_base , int comp_length , u8* array02_base  	){
	u32 i =0;
	u32 error =0 ;
	u32 out_number = 0;
	xil_printf("--------------------------------\r\n");
	for( i=0 ; i< comp_length ; i=i+1){
		if( *(array01_base + i) != *(array02_base + i)	){
			error = error +1;
		}
	}
	xil_printf("array_compare end \r\n");
	if( error == 0){
		xil_printf("array_compare result pass! \r\n");
		xil_printf("output number = %d result all pass\r\n", out_number);
	}else {
		xil_printf("array_compare error = %d \r\n", error);
	}
	xil_printf("--------------------------------\r\n");
}

void addnorm_layer(u64 *input, u64  *input1 , u64 *output)
{
	u64 *input_addr;
	u64 *input_addr1;
	u64 *output_addr;

	int ix;
	// XTime start, end;
	// u32 time_used;

	u64 NORM_HEAD[2] = {0x7766554433221100,
					    0x7766554433221100};

	int TB_RUN_INROW	= 8		;
	int TB_RUN_INCOL	= 64	;
	int TB_RUN_WCOL		= 2048	;
	int TB_RUN_OTCOL	= 256	;
	int TB_CFG_NUMBER	= 16	;

	ix = 0;

	input_addr = input;
	input_addr1 = input1;
	output_addr = output;

	// xil_printf("==== Start DMA Transfer ====\r\n");
	// XTime_GetTime(&start);

	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(&NORM_HEAD), 2 * 8);
	AXI_DMA_Transfer((UINTPTR)(&NORM_HEAD), 2 * 8, XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }

	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(input_addr), TB_RUN_INROW * TB_RUN_INCOL );
	AXI_DMA_Transfer((UINTPTR)(input_addr), TB_RUN_INROW * TB_RUN_INCOL , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
	usleep(5);

	// xil_printf("input_buf addr = 0x%08X\r\n", (unsigned)input_addr);
	for (int i=0; i<8; ++i)
	    // xil_printf("%02X ", ((u8*)input_addr)[i]);
	// xil_printf("\r\n");

	AXI_DMA_TxDone = 0;
	Xil_DCacheFlushRange((UINTPTR)(input_addr1), TB_RUN_INROW * TB_RUN_INCOL );
	AXI_DMA_Transfer((UINTPTR)(input_addr1), TB_RUN_INROW * TB_RUN_INCOL , XAXIDMA_DMA_TO_DEVICE);
	while (!AXI_DMA_TxDone){ /* NOP */ }
	usleep(5);

	Xil_DCacheInvalidateRange((UINTPTR)output_addr, 512 * 8);
	AXI_DMA_Transfer((UINTPTR)output_addr, 512 * 8, XAXIDMA_DEVICE_TO_DMA);
	while (!AXI_DMA_RxDone){ /* NOP */ }
	AXI_DMA_RxDone = 0;

	Xil_DCacheInvalidateRange((UINTPTR)output_addr, 512 * 8);
	for (int i = 0; i < 16; i++) {
	    // xil_printf("out[%3d] = 0x%04X\r\n", i, output_addr[i]);
	}

	// XTime_GetTime(&end);

	//-------------------------------------------------------------------

	// time_used = ((end - start) * 1000000) / (COUNTS_PER_SECOND);
	// xil_printf("--------------------------------\r\n");
	// xil_printf("end adddnorm  layer \r\n");
	// xil_printf(" %d us\r\n", time_used);
	// xil_printf("--------------------------------\r\n");
}

void ibert_addnorm(u64 *input, u64 *input1, u64 *output)
{
	u64 *input_addr;
	u64 *input_addr1;
	u64 *output_addr;

	int ix;
	XTime start, end;
	u32 time_used;

	input_addr = input;
	input_addr1 = input1;
	output_addr = output;

	XAxiDma_Reset(&DmaInstance);

	XTime_GetTime(&start);

	for(ix=0; ix<64; ix=ix+1){

		addnorm_layer(input_addr, input_addr1, output_addr);

	}

	XTime_GetTime(&end);

	time_used = ((end - start) * 1000000) / (COUNTS_PER_SECOND);
    xil_printf("--------------------------------\r\n");
    xil_printf("end addnorm \r\n");
    xil_printf(" %u us\r\n", time_used);
    xil_printf("--------------------------------\r\n");
}

void NORM_COMP_ARRAY_DATA(u16 *array01_base, int comp_length, u16 *array02_base) {
	u16 i = 0;
	u16 error = 0;
	u16 out_number = 0;

	xil_printf("--------------------------------\r\n");

	for (i = 0; i < comp_length; i = i + 1) {
		u64 a1 = *(array01_base + i);
		u64 a2 = *(array02_base + i);
		out_number += 1;

		if (a1 != a2) {
			error += 1;
			//xil_printf("FAIL at %d: ref = %04x, tgt = %04x\r\n", i, a1,a2);
		}
		else {
			out_number += 1;
		//	xil_printf("SUCCESS at %d: ref = %04x, tgt = %04x\r\n", i, a1,a2);
		}
	}

	xil_printf("array_compare end\r\n");

	if (error == 0) {
		xil_printf("array_compare result pass!\r\n");
		xil_printf("output number = %d\r\n", out_number);
	}
	else {
		xil_printf("array_compare error = %d\r\n", error);
		// xil_printf("array_compare result pass!\r\n");
		xil_printf("output number = %d\r\n", out_number);
	}

	xil_printf("--------------------------------\r\n");
}
