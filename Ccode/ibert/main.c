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

    int i = 0;

    xil_printf("--- now start Transformer Operation ---\r\n");
    
    SA_q_gen(0, (u64*) &SA_layer1_bias_Q, (u8*) &SA_layer1_weight_Q, (u8*) &SA_layer1_input_token, (u8*) &SA_layer1_output_Q);
    SA_k_gen(0, (u64*) &SA_layer1_bias_K, (u8*) &SA_layer1_weight_K, (u8*) &SA_layer1_input_token, (u8*) &SA_layer1_output_K);
    SA_v_gen(0, (u64*) &SA_layer1_bias_V, (u8*) &SA_layer1_weight_V, (u8*) &SA_layer1_input_token, (u8*) &SA_layer1_output_V);

    SA_qkt_gen(0, (u64*) &SA_layer1_bias_QKT, (u8*) &SA_layer1_output_Q_gold, (u8*) &SA_layer1_output_K_gold, (u8*) &SA_layer1_output_QKT);
    
    ibert_softmax((u64*) &SOFTMAX_layer1_input, (u64*) &SOFTMAX_layer1_output);

    SA_SV( 0 , (u64*) &SA_layer1_bias_K , (u8*) &SA_layer1_output_Q_gold , (u8*) &SA_layer1_output_QKT_gold , (u8*) &SA_layer1_output_QKT   );

    SA_out( 0 , (u64*) &SA_layer1_bias_Q , (u8*) &SA_layer1_weight_Q , (u8*) &SA_layer1_input_token , (u8*) &SA_layer1_output_Q   );

    ibert_addnorm((u64*) &Pre_Norm_layer1_input_1, (u64*) &Pre_Norm_layer1_input_2,(u64*) &Pre_Norm_layer1_output);

    ibert_FFN_first_layer(FFN_layer1_input_1, FFN_layer1_weight_1, FFN_layer1_bias_1, FFN_layer1_output_1);

    ibert_FFN_second_layer(FFN_layer1_input_2, FFN_layer1_weight_2, FFN_layer1_bias_2, FFN_layer1_output_2);

    ibert_addnorm((u64*) &Post_Norm_layer1_input_1, (u64*) &Post_Norm_layer1_input_2,(u64*) &Post_Norm_layer1_output);

    xil_printf("--- layer 1 complete ---\r\n");
    
    SA_q_gen(0, (u64*) &SA_layer2_bias_Q, (u8*) &SA_layer2_weight_Q, (u8*) &SA_layer2_input_token, (u8*) &SA_layer2_output_Q);
    SA_k_gen(0, (u64*) &SA_layer2_bias_K, (u8*) &SA_layer2_weight_K, (u8*) &SA_layer2_input_token, (u8*) &SA_layer2_output_K);
    SA_v_gen(0, (u64*) &SA_layer2_bias_V, (u8*) &SA_layer2_weight_V, (u8*) &SA_layer2_input_token, (u8*) &SA_layer2_output_V);

    SA_qkt_gen(0, (u64*) &SA_layer2_bias_QKT, (u8*) &SA_layer2_output_Q_gold, (u8*) &SA_layer2_output_K_gold, (u8*) &SA_layer2_output_QKT);
    
    ibert_softmax((u64*) &SOFTMAX_layer2_input, (u64*) &SOFTMAX_layer2_output);

    SA_SV(0, (u64*) &SA_layer2_bias_V, (u8*) &SA_layer2_output_Q_gold, (u8*) &SA_layer2_output_QKT_gold, (u8*) &SA_layer2_output_QKT);

    SA_out(0, (u64*) &SA_layer2_bias_Q, (u8*) &SA_layer2_weight_Q, (u8*) &SA_layer2_input_token, (u8*) &SA_layer2_output_Q);

    ibert_addnorm((u64*) &Pre_Norm_layer2_input_1, (u64*) &Pre_Norm_layer2_input_2,(u64*) &Pre_Norm_layer2_output);

    ibert_FFN_first_layer(FFN_layer2_input_1, FFN_layer2_weight_1, FFN_layer2_bias_1, FFN_layer2_output_1);

    ibert_FFN_second_layer(FFN_layer2_input_2, FFN_layer2_weight_2, FFN_layer2_bias_2, FFN_layer2_output_2);

    ibert_addnorm((u64*) &Post_Norm_layer2_input_1, (u64*) &Post_Norm_layer2_input_2,(u64*) &Post_Norm_layer2_output);

    xil_printf("--- layer 2 complete ---\r\n");
    
    SA_q_gen(0, (u64*) &SA_layer3_bias_Q, (u8*) &SA_layer3_weight_Q, (u8*) &SA_layer3_input_token, (u8*) &SA_layer3_output_Q);
    SA_k_gen(0, (u64*) &SA_layer3_bias_K, (u8*) &SA_layer3_weight_K, (u8*) &SA_layer3_input_token, (u8*) &SA_layer3_output_K);
    SA_v_gen(0, (u64*) &SA_layer3_bias_V, (u8*) &SA_layer3_weight_V, (u8*) &SA_layer3_input_token, (u8*) &SA_layer3_output_V);

    SA_qkt_gen(0, (u64*) &SA_layer3_bias_QKT, (u8*) &SA_layer3_output_Q_gold, (u8*) &SA_layer3_output_K_gold, (u8*) &SA_layer3_output_QKT);
    
    ibert_softmax((u64*) &SOFTMAX_layer3_input, (u64*) &SOFTMAX_layer3_output);

    SA_SV(0, (u64*) &SA_layer3_bias_V, (u8*) &SA_layer3_output_Q_gold, (u8*) &SA_layer3_output_QKT_gold, (u8*) &SA_layer3_output_QKT);

    SA_out(0, (u64*) &SA_layer3_bias_Q, (u8*) &SA_layer3_weight_Q, (u8*) &SA_layer3_input_token, (u8*) &SA_layer3_output_Q);

    ibert_addnorm((u64*) &Pre_Norm_layer3_input_1, (u64*) &Pre_Norm_layer3_input_2,(u64*) &Pre_Norm_layer3_output);

    ibert_FFN_first_layer(FFN_layer3_input_1, FFN_layer3_weight_1, FFN_layer3_bias_1, FFN_layer3_output_1);

    ibert_FFN_second_layer(FFN_layer3_input_2, FFN_layer3_weight_2, FFN_layer3_bias_2, FFN_layer3_output_2);

    ibert_addnorm((u64*) &Post_Norm_layer3_input_1, (u64*) &Post_Norm_layer3_input_2,(u64*) &Post_Norm_layer3_output);

    xil_printf("--- layer 3 complete ---\r\n");
    
    SA_q_gen(0, (u64*) &SA_layer4_bias_Q, (u8*) &SA_layer4_weight_Q, (u8*) &SA_layer4_input_token, (u8*) &SA_layer4_output_Q);
    SA_k_gen(0, (u64*) &SA_layer4_bias_K, (u8*) &SA_layer4_weight_K, (u8*) &SA_layer4_input_token, (u8*) &SA_layer4_output_K);
    SA_v_gen(0, (u64*) &SA_layer4_bias_V, (u8*) &SA_layer4_weight_V, (u8*) &SA_layer4_input_token, (u8*) &SA_layer4_output_V);

    SA_qkt_gen(0, (u64*) &SA_layer4_bias_QKT, (u8*) &SA_layer4_output_Q_gold, (u8*) &SA_layer4_output_K_gold, (u8*) &SA_layer4_output_QKT);
    
    ibert_softmax((u64*) &SOFTMAX_layer4_input, (u64*) &SOFTMAX_layer4_output);

    SA_SV(0, (u64*) &SA_layer4_bias_V, (u8*) &SA_layer4_output_Q_gold, (u8*) &SA_layer4_output_QKT_gold, (u8*) &SA_layer4_output_QKT);

    SA_out(0, (u64*) &SA_layer4_bias_Q, (u8*) &SA_layer4_weight_Q, (u8*) &SA_layer4_input_token, (u8*) &SA_layer4_output_Q);

    ibert_addnorm((u64*) &Pre_Norm_layer4_input_1, (u64*) &Pre_Norm_layer4_input_2,(u64*) &Pre_Norm_layer4_output);

    ibert_FFN_first_layer(FFN_layer4_input_1, FFN_layer4_weight_1, FFN_layer4_bias_1, FFN_layer4_output_1);

    ibert_FFN_second_layer(FFN_layer4_input_2, FFN_layer4_weight_2, FFN_layer4_bias_2, FFN_layer4_output_2);

    ibert_addnorm((u64*) &Post_Norm_layer4_input_1, (u64*) &Post_Norm_layer4_input_2,(u64*) &Post_Norm_layer4_output);

    xil_printf("--- layer 4 complete ---\r\n");
    
    SA_q_gen(0, (u64*) &SA_layer5_bias_Q, (u8*) &SA_layer5_weight_Q, (u8*) &SA_layer5_input_token, (u8*) &SA_layer5_output_Q);
    SA_k_gen(0, (u64*) &SA_layer5_bias_K, (u8*) &SA_layer5_weight_K, (u8*) &SA_layer5_input_token, (u8*) &SA_layer5_output_K);
    SA_v_gen(0, (u64*) &SA_layer5_bias_V, (u8*) &SA_layer5_weight_V, (u8*) &SA_layer5_input_token, (u8*) &SA_layer5_output_V);

    SA_qkt_gen(0, (u64*) &SA_layer5_bias_QKT, (u8*) &SA_layer5_output_Q_gold, (u8*) &SA_layer5_output_K_gold, (u8*) &SA_layer5_output_QKT);
    
    ibert_softmax((u64*) &SOFTMAX_layer5_input, (u64*) &SOFTMAX_layer5_output);

    SA_SV(0, (u64*) &SA_layer5_bias_V, (u8*) &SA_layer5_output_Q_gold, (u8*) &SA_layer5_output_QKT_gold, (u8*) &SA_layer5_output_QKT);

    SA_out(0, (u64*) &SA_layer5_bias_Q, (u8*) &SA_layer5_weight_Q, (u8*) &SA_layer5_input_token, (u8*) &SA_layer5_output_Q);

    ibert_addnorm((u64*) &Pre_Norm_layer5_input_1, (u64*) &Pre_Norm_layer5_input_2,(u64*) &Pre_Norm_layer5_output);

    ibert_FFN_first_layer(FFN_layer5_input_1, FFN_layer5_weight_1, FFN_layer5_bias_1, FFN_layer5_output_1);

    ibert_FFN_second_layer(FFN_layer5_input_2, FFN_layer5_weight_2, FFN_layer5_bias_2, FFN_layer5_output_2);

    ibert_addnorm((u64*) &Post_Norm_layer5_input_1, (u64*) &Post_Norm_layer5_input_2,(u64*) &Post_Norm_layer5_output);

    xil_printf("--- layer 5 complete ---\r\n");
    
    SA_q_gen(0, (u64*) &SA_layer6_bias_Q, (u8*) &SA_layer6_weight_Q, (u8*) &SA_layer6_input_token, (u8*) &SA_layer6_output_Q);
    SA_k_gen(0, (u64*) &SA_layer6_bias_K, (u8*) &SA_layer6_weight_K, (u8*) &SA_layer6_input_token, (u8*) &SA_layer6_output_K);
    SA_v_gen(0, (u64*) &SA_layer6_bias_V, (u8*) &SA_layer6_weight_V, (u8*) &SA_layer6_input_token, (u8*) &SA_layer6_output_V);

    SA_qkt_gen(0, (u64*) &SA_layer6_bias_QKT, (u8*) &SA_layer6_output_Q_gold, (u8*) &SA_layer6_output_K_gold, (u8*) &SA_layer6_output_QKT);
    
    ibert_softmax((u64*) &SOFTMAX_layer6_input, (u64*) &SOFTMAX_layer6_output);

    SA_SV(0, (u64*) &SA_layer6_bias_V, (u8*) &SA_layer6_output_Q_gold, (u8*) &SA_layer6_output_QKT_gold, (u8*) &SA_layer6_output_QKT);

    SA_out(0, (u64*) &SA_layer6_bias_Q, (u8*) &SA_layer6_weight_Q, (u8*) &SA_layer6_input_token, (u8*) &SA_layer6_output_Q);

    ibert_addnorm((u64*) &Pre_Norm_layer6_input_1, (u64*) &Pre_Norm_layer6_input_2,(u64*) &Pre_Norm_layer6_output);

    ibert_FFN_first_layer(FFN_layer6_input_1, FFN_layer6_weight_1, FFN_layer6_bias_1, FFN_layer6_output_1);

    ibert_FFN_second_layer(FFN_layer6_input_2, FFN_layer6_weight_2, FFN_layer6_bias_2, FFN_layer6_output_2);

    ibert_addnorm((u64*) &Post_Norm_layer6_input_1, (u64*) &Post_Norm_layer6_input_2,(u64*) &Post_Norm_layer6_output);

    xil_printf("--- layer 6 complete ---\r\n");
    
    SA_q_gen(0, (u64*) &SA_layer7_bias_Q, (u8*) &SA_layer7_weight_Q, (u8*) &SA_layer7_input_token, (u8*) &SA_layer7_output_Q);
    SA_k_gen(0, (u64*) &SA_layer7_bias_K, (u8*) &SA_layer7_weight_K, (u8*) &SA_layer7_input_token, (u8*) &SA_layer7_output_K);
    SA_v_gen(0, (u64*) &SA_layer7_bias_V, (u8*) &SA_layer7_weight_V, (u8*) &SA_layer7_input_token, (u8*) &SA_layer7_output_V);

    SA_qkt_gen(0, (u64*) &SA_layer7_bias_QKT, (u8*) &SA_layer7_output_Q_gold, (u8*) &SA_layer7_output_K_gold, (u8*) &SA_layer7_output_QKT);
    
    ibert_softmax((u64*) &SOFTMAX_layer7_input, (u64*) &SOFTMAX_layer7_output);

    SA_SV(0, (u64*) &SA_layer7_bias_V, (u8*) &SA_layer7_output_Q_gold, (u8*) &SA_layer7_output_QKT_gold, (u8*) &SA_layer7_output_QKT);

    SA_out(0, (u64*) &SA_layer7_bias_Q, (u8*) &SA_layer7_weight_Q, (u8*) &SA_layer7_input_token, (u8*) &SA_layer7_output_Q);

    ibert_addnorm((u64*) &Pre_Norm_layer7_input_1, (u64*) &Pre_Norm_layer7_input_2,(u64*) &Pre_Norm_layer7_output);

    ibert_FFN_first_layer(FFN_layer7_input_1, FFN_layer7_weight_1, FFN_layer7_bias_1, FFN_layer7_output_1);

    ibert_FFN_second_layer(FFN_layer7_input_2, FFN_layer7_weight_2, FFN_layer7_bias_2, FFN_layer7_output_2);

    ibert_addnorm((u64*) &Post_Norm_layer7_input_1, (u64*) &Post_Norm_layer7_input_2,(u64*) &Post_Norm_layer7_output);

    xil_printf("--- layer 7 complete ---\r\n");
    
    SA_q_gen(0, (u64*) &SA_layer8_bias_Q, (u8*) &SA_layer8_weight_Q, (u8*) &SA_layer8_input_token, (u8*) &SA_layer8_output_Q);
    SA_k_gen(0, (u64*) &SA_layer8_bias_K, (u8*) &SA_layer8_weight_K, (u8*) &SA_layer8_input_token, (u8*) &SA_layer8_output_K);
    SA_v_gen(0, (u64*) &SA_layer8_bias_V, (u8*) &SA_layer8_weight_V, (u8*) &SA_layer8_input_token, (u8*) &SA_layer8_output_V);

    SA_qkt_gen(0, (u64*) &SA_layer8_bias_QKT, (u8*) &SA_layer8_output_Q_gold, (u8*) &SA_layer8_output_K_gold, (u8*) &SA_layer8_output_QKT);
    
    ibert_softmax((u64*) &SOFTMAX_layer8_input, (u64*) &SOFTMAX_layer8_output);

    SA_SV(0, (u64*) &SA_layer8_bias_V, (u8*) &SA_layer8_output_Q_gold, (u8*) &SA_layer8_output_QKT_gold, (u8*) &SA_layer8_output_QKT);

    SA_out(0, (u64*) &SA_layer8_bias_Q, (u8*) &SA_layer8_weight_Q, (u8*) &SA_layer8_input_token, (u8*) &SA_layer8_output_Q);

    ibert_addnorm((u64*) &Pre_Norm_layer8_input_1, (u64*) &Pre_Norm_layer8_input_2,(u64*) &Pre_Norm_layer8_output);

    ibert_FFN_first_layer(FFN_layer8_input_1, FFN_layer8_weight_1, FFN_layer8_bias_1, FFN_layer8_output_1);

    ibert_FFN_second_layer(FFN_layer8_input_2, FFN_layer8_weight_2, FFN_layer8_bias_2, FFN_layer8_output_2);

    ibert_addnorm((u64*) &Post_Norm_layer8_input_1, (u64*) &Post_Norm_layer8_input_2,(u64*) &Post_Norm_layer8_output);

    xil_printf("--- layer 8 complete ---\r\n");
    
    SA_q_gen(0, (u64*) &SA_layer9_bias_Q, (u8*) &SA_layer9_weight_Q, (u8*) &SA_layer9_input_token, (u8*) &SA_layer9_output_Q);
    SA_k_gen(0, (u64*) &SA_layer9_bias_K, (u8*) &SA_layer9_weight_K, (u8*) &SA_layer9_input_token, (u8*) &SA_layer9_output_K);
    SA_v_gen(0, (u64*) &SA_layer9_bias_V, (u8*) &SA_layer9_weight_V, (u8*) &SA_layer9_input_token, (u8*) &SA_layer9_output_V);

    SA_qkt_gen(0, (u64*) &SA_layer9_bias_QKT, (u8*) &SA_layer9_output_Q_gold, (u8*) &SA_layer9_output_K_gold, (u8*) &SA_layer9_output_QKT);
    
    ibert_softmax((u64*) &SOFTMAX_layer9_input, (u64*) &SOFTMAX_layer9_output);

    SA_SV(0, (u64*) &SA_layer9_bias_V, (u8*) &SA_layer9_output_Q_gold, (u8*) &SA_layer9_output_QKT_gold, (u8*) &SA_layer9_output_QKT);

    SA_out(0, (u64*) &SA_layer9_bias_Q, (u8*) &SA_layer9_weight_Q, (u8*) &SA_layer9_input_token, (u8*) &SA_layer9_output_Q);

    ibert_addnorm((u64*) &Pre_Norm_layer9_input_1, (u64*) &Pre_Norm_layer9_input_2,(u64*) &Pre_Norm_layer9_output);

    ibert_FFN_first_layer(FFN_layer9_input_1, FFN_layer9_weight_1, FFN_layer9_bias_1, FFN_layer9_output_1);

    ibert_FFN_second_layer(FFN_layer9_input_2, FFN_layer9_weight_2, FFN_layer9_bias_2, FFN_layer9_output_2);

    ibert_addnorm((u64*) &Post_Norm_layer9_input_1, (u64*) &Post_Norm_layer9_input_2,(u64*) &Post_Norm_layer9_output);

    xil_printf("--- layer 9 complete ---\r\n");
    
    SA_q_gen(0, (u64*) &SA_layer10_bias_Q, (u8*) &SA_layer10_weight_Q, (u8*) &SA_layer10_input_token, (u8*) &SA_layer10_output_Q);
    SA_k_gen(0, (u64*) &SA_layer10_bias_K, (u8*) &SA_layer10_weight_K, (u8*) &SA_layer10_input_token, (u8*) &SA_layer10_output_K);
    SA_v_gen(0, (u64*) &SA_layer10_bias_V, (u8*) &SA_layer10_weight_V, (u8*) &SA_layer10_input_token, (u8*) &SA_layer10_output_V);

    SA_qkt_gen(0, (u64*) &SA_layer10_bias_QKT, (u8*) &SA_layer10_output_Q_gold, (u8*) &SA_layer10_output_K_gold, (u8*) &SA_layer10_output_QKT);
    
    ibert_softmax((u64*) &SOFTMAX_layer10_input, (u64*) &SOFTMAX_layer10_output);

    SA_SV(0, (u64*) &SA_layer10_bias_V, (u8*) &SA_layer10_output_Q_gold, (u8*) &SA_layer10_output_QKT_gold, (u8*) &SA_layer10_output_QKT);

    SA_out(0, (u64*) &SA_layer10_bias_Q, (u8*) &SA_layer10_weight_Q, (u8*) &SA_layer10_input_token, (u8*) &SA_layer10_output_Q);

    ibert_addnorm((u64*) &Pre_Norm_layer10_input_1, (u64*) &Pre_Norm_layer10_input_2,(u64*) &Pre_Norm_layer10_output);

    ibert_FFN_first_layer(FFN_layer10_input_1, FFN_layer10_weight_1, FFN_layer10_bias_1, FFN_layer10_output_1);

    ibert_FFN_second_layer(FFN_layer10_input_2, FFN_layer10_weight_2, FFN_layer10_bias_2, FFN_layer10_output_2);

    ibert_addnorm((u64*) &Post_Norm_layer10_input_1, (u64*) &Post_Norm_layer10_input_2,(u64*) &Post_Norm_layer10_output);

    xil_printf("--- layer 10 complete ---\r\n");
    
    SA_q_gen(0, (u64*) &SA_layer11_bias_Q, (u8*) &SA_layer11_weight_Q, (u8*) &SA_layer11_input_token, (u8*) &SA_layer11_output_Q);
    SA_k_gen(0, (u64*) &SA_layer11_bias_K, (u8*) &SA_layer11_weight_K, (u8*) &SA_layer11_input_token, (u8*) &SA_layer11_output_K);
    SA_v_gen(0, (u64*) &SA_layer11_bias_V, (u8*) &SA_layer11_weight_V, (u8*) &SA_layer11_input_token, (u8*) &SA_layer11_output_V);

    SA_qkt_gen(0, (u64*) &SA_layer11_bias_QKT, (u8*) &SA_layer11_output_Q_gold, (u8*) &SA_layer11_output_K_gold, (u8*) &SA_layer11_output_QKT);
    
    ibert_softmax((u64*) &SOFTMAX_layer11_input, (u64*) &SOFTMAX_layer11_output);

    SA_SV(0, (u64*) &SA_layer11_bias_V, (u8*) &SA_layer11_output_Q_gold, (u8*) &SA_layer11_output_QKT_gold, (u8*) &SA_layer11_output_QKT);

    SA_out(0, (u64*) &SA_layer11_bias_Q, (u8*) &SA_layer11_weight_Q, (u8*) &SA_layer11_input_token, (u8*) &SA_layer11_output_Q);

    ibert_addnorm((u64*) &Pre_Norm_layer11_input_1, (u64*) &Pre_Norm_layer11_input_2,(u64*) &Pre_Norm_layer11_output);

    ibert_FFN_first_layer(FFN_layer11_input_1, FFN_layer11_weight_1, FFN_layer11_bias_1, FFN_layer11_output_1);

    ibert_FFN_second_layer(FFN_layer11_input_2, FFN_layer11_weight_2, FFN_layer11_bias_2, FFN_layer11_output_2);

    ibert_addnorm((u64*) &Post_Norm_layer11_input_1, (u64*) &Post_Norm_layer11_input_2,(u64*) &Post_Norm_layer11_output);

    xil_printf("--- layer 11 complete ---\r\n");
    
    SA_q_gen(0, (u64*) &SA_layer12_bias_Q, (u8*) &SA_layer12_weight_Q, (u8*) &SA_layer12_input_token, (u8*) &SA_layer12_output_Q);
    SA_k_gen(0, (u64*) &SA_layer12_bias_K, (u8*) &SA_layer12_weight_K, (u8*) &SA_layer12_input_token, (u8*) &SA_layer12_output_K);
    SA_v_gen(0, (u64*) &SA_layer12_bias_V, (u8*) &SA_layer12_weight_V, (u8*) &SA_layer12_input_token, (u8*) &SA_layer12_output_V);

    SA_qkt_gen(0, (u64*) &SA_layer12_bias_QKT, (u8*) &SA_layer12_output_Q_gold, (u8*) &SA_layer12_output_K_gold, (u8*) &SA_layer12_output_QKT);
    
    ibert_softmax((u64*) &SOFTMAX_layer12_input, (u64*) &SOFTMAX_layer12_output);

    SA_SV(0, (u64*) &SA_layer12_bias_V, (u8*) &SA_layer12_output_Q_gold, (u8*) &SA_layer12_output_QKT_gold, (u8*) &SA_layer12_output_QKT);

    SA_out(0, (u64*) &SA_layer12_bias_Q, (u8*) &SA_layer12_weight_Q, (u8*) &SA_layer12_input_token, (u8*) &SA_layer12_output_Q);

    ibert_addnorm((u64*) &Pre_Norm_layer12_input_1, (u64*) &Pre_Norm_layer12_input_2,(u64*) &Pre_Norm_layer12_output);

    ibert_FFN_first_layer(FFN_layer12_input_1, FFN_layer12_weight_1, FFN_layer12_bias_1, FFN_layer12_output_1);

    ibert_FFN_second_layer(FFN_layer12_input_2, FFN_layer12_weight_2, FFN_layer12_bias_2, FFN_layer12_output_2);

    ibert_addnorm((u64*) &Post_Norm_layer12_input_1, (u64*) &Post_Norm_layer12_input_2,(u64*) &Post_Norm_layer12_output);

    xil_printf("--- layer 12 complete ---\r\n");

    xil_printf("--- Transformer Operation Done ---\r\n");
}
