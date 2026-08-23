/******************************************************************************
*
* Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* Use of the Software is limited solely to applications:
* (a) running on a Xilinx device, or
* (b) that interact with a Xilinx device through a bus or interconnect.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
* OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in
* this Software without prior written authorization from Xilinx.
*
******************************************************************************/

/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */
#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "v3_data.h"
#include "cs_ip.h"
#include "axi_dma.h"=

int main()
{
    init_platform();
    print("AXI DMA Initial \n\r");

    Xil_DCacheDisable();

    AXI_DMA_Init();
    v3_data_init();

    // while(1)
    // {

    	xil_printf("--- now start Transformer Operation ---\r\n");

        SA_q_gen( 0 , (u64*) &B_q , (u8*) &W_q , (u8*) &if_token , (u8*) &of_q   );
        SA_k_gen( 0 , (u64*) &B_k , (u8*) &W_k , (u8*) &if_token , (u8*) &of_k   );
        SA_v_gen( 0 , (u64*) &B_v , (u8*) &W_v , (u8*) &if_token , (u8*) &of_v   );

        SA_qkt_gen( 0 , (u64*) &B_qkt , (u8*) &of_q_gold , (u8*) &of_k_gold , (u8*) &of_qkt   );
    
        ibert_softmax((u64*) &SOFTMAX_input_1, (u64*) &SOFTMAX_output_1);

        SA_SV( 0 , (u64*) &B_v , (u8*) &of_q_gold , (u8*) &of_qkt_gold , (u8*) &of_qkt   );

        SA_out( 0 , (u64*) &B_q , (u8*) &W_q , (u8*) &if_token , (u8*) &of_q   );

        ibert_addnorm((u64*) &NORM_input_1, (u64*) &NORM_input_2,(u64*) &NORM_output);

    	ibert_FFN_first_layer(FFN_input_1, FFN_weight_1, FFN_bias_1, FFN_output_1);

        ibert_FFN_second_layer(FFN_input_2, FFN_weight_2, FFN_bias_2, FFN_output_2);

        ibert_addnorm((u64*) &NORM_input_1, (u64*) &NORM_input_2,(u64*) &NORM_output);

    // }

}
