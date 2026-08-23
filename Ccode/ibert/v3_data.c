/*
 * v3_data.c
 *
 *  Created on: 2019
 *      Author: cs
 */
#include "xsdps.h"
#include "ff.h"
#include "v3_data.h"
#include "stdio.h"

#include "xtime_l.h"

static FIL fil_bias;
static FIL fil_weights;
static FIL fil_input;
static FIL fil_ofmap;

static FATFS fatfs;

////////////////////////////////////////////////////////////////////////////

// layer 1
const static char SA_layer1_input_file[32]  = "SA_input_token_fpga.dat";
const static char SA_layer1_weight_Q_file[32]  = "SA_Wq_fpga.dat";
const static char SA_layer1_weight_K_file[32]  = "SA_Wk_fpga.dat";
const static char SA_layer1_weight_V_file[32]  = "SA_Wv_fpga.dat";
const static char SA_layer1_bias_file[32]  	= "SA_fake_bias_fpga.dat";
const static char SA_layer1_output_Q_file[32]	= "SA_Q_fpga.dat";
const static char SA_layer1_output_K_file[32]	= "SA_K_fpga.dat";
const static char SA_layer1_output_V_file[32]	= "SA_V_fpga.dat";
const static char SA_layer1_output_QKT_file[32]	= "SA_QKT_fpga.dat";

const static char SOFTMAX_layer1_input_file[32]  = "soft_in_fpga.dat";
const static char SOFTMAX_layer1_output_file[32] = "soft_out_fpga.dat";

const static char Pre_Norm_layer1_input_file_1[32] = "NORM_input_fpga.dat";
const static char Pre_Norm_layer1_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Pre_Norm_layer1_output_file[32] 	= "NORM_output_fpga.dat";

const static char FFN_layer1_input_file_1[32] 	= "FFN_layer1_input_fpga.dat";
const static char FFN_layer1_weight_file_1[32]	= "FFN_layer1_weight_fpga.dat";
const static char FFN_layer1_bias_file_1[32]  	= "FFN_layer1_bias_fpga.dat";
const static char FFN_layer1_output_file_1[32]	= "FFN_layer1_output_fpga.dat";
const static char FFN_layer1_input_file_2[32] 	= "FFN_layer2_input_fpga.dat";
const static char FFN_layer1_weight_file_2[32]	= "FFN_layer2_weight_fpga.dat";
const static char FFN_layer1_bias_file_2[32]  	= "FFN_layer2_bias_fpga.dat";
const static char FFN_layer1_output_file_2[32]	= "FFN_layer2_output_fpga.dat";

const static char Post_Norm_layer1_input_file_1[32] = "NORM_input_fpga.dat";
const static char Post_Norm_layer1_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Post_Norm_layer1_output_file[32]  = "NORM_output_fpga.dat";

// layer 2
const static char SA_layer2_input_file[32]  = "SA_input_token_fpga.dat";
const static char SA_layer2_weight_Q_file[32]  = "SA_Wq_fpga.dat";
const static char SA_layer2_weight_K_file[32]  = "SA_Wk_fpga.dat";
const static char SA_layer2_weight_V_file[32]  = "SA_Wv_fpga.dat";
const static char SA_layer2_bias_file[32]  	= "SA_fake_bias_fpga.dat";
const static char SA_layer2_output_Q_file[32]	= "SA_Q_fpga.dat";
const static char SA_layer2_output_K_file[32]	= "SA_K_fpga.dat";
const static char SA_layer2_output_V_file[32]	= "SA_V_fpga.dat";
const static char SA_layer2_output_QKT_file[32]	= "SA_QKT_fpga.dat";

const static char SOFTMAX_layer2_input_file[32]  = "soft_in_fpga.dat";
const static char SOFTMAX_layer2_output_file[32] = "soft_out_fpga.dat";

const static char Pre_Norm_layer2_input_file_1[32] = "NORM_input_fpga.dat";
const static char Pre_Norm_layer2_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Pre_Norm_layer2_output_file[32] 	= "NORM_output_fpga.dat";

const static char FFN_layer2_input_file_1[32] 	= "FFN_layer1_input_fpga.dat";
const static char FFN_layer2_weight_file_1[32]	= "FFN_layer1_weight_fpga.dat";
const static char FFN_layer2_bias_file_1[32]  	= "FFN_layer1_bias_fpga.dat";
const static char FFN_layer2_output_file_1[32]	= "FFN_layer1_output_fpga.dat";
const static char FFN_layer2_input_file_2[32] 	= "FFN_layer2_input_fpga.dat";
const static char FFN_layer2_weight_file_2[32]	= "FFN_layer2_weight_fpga.dat";
const static char FFN_layer2_bias_file_2[32]  	= "FFN_layer2_bias_fpga.dat";
const static char FFN_layer2_output_file_2[32]	= "FFN_layer2_output_fpga.dat";

const static char Post_Norm_layer2_input_file_1[32] = "NORM_input_fpga.dat";
const static char Post_Norm_layer2_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Post_Norm_layer2_output_file[32]  = "NORM_output_fpga.dat";

// layer 3
const static char SA_layer3_input_file[32]  = "SA_input_token_fpga.dat";
const static char SA_layer3_weight_Q_file[32]  = "SA_Wq_fpga.dat";
const static char SA_layer3_weight_K_file[32]  = "SA_Wk_fpga.dat";
const static char SA_layer3_weight_V_file[32]  = "SA_Wv_fpga.dat";
const static char SA_layer3_bias_file[32]  	= "SA_fake_bias_fpga.dat";
const static char SA_layer3_output_Q_file[32]	= "SA_Q_fpga.dat";
const static char SA_layer3_output_K_file[32]	= "SA_K_fpga.dat";
const static char SA_layer3_output_V_file[32]	= "SA_V_fpga.dat";
const static char SA_layer3_output_QKT_file[32]	= "SA_QKT_fpga.dat";

const static char SOFTMAX_layer3_input_file[32]  = "soft_in_fpga.dat";
const static char SOFTMAX_layer3_output_file[32] = "soft_out_fpga.dat";

const static char Pre_Norm_layer3_input_file_1[32] = "NORM_input_fpga.dat";
const static char Pre_Norm_layer3_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Pre_Norm_layer3_output_file[32] 	= "NORM_output_fpga.dat";

const static char FFN_layer3_input_file_1[32] 	= "FFN_layer1_input_fpga.dat";
const static char FFN_layer3_weight_file_1[32]	= "FFN_layer1_weight_fpga.dat";
const static char FFN_layer3_bias_file_1[32]  	= "FFN_layer1_bias_fpga.dat";
const static char FFN_layer3_output_file_1[32]	= "FFN_layer1_output_fpga.dat";
const static char FFN_layer3_input_file_2[32] 	= "FFN_layer2_input_fpga.dat";
const static char FFN_layer3_weight_file_2[32]	= "FFN_layer2_weight_fpga.dat";
const static char FFN_layer3_bias_file_2[32]  	= "FFN_layer2_bias_fpga.dat";
const static char FFN_layer3_output_file_2[32]	= "FFN_layer2_output_fpga.dat";

const static char Post_Norm_layer3_input_file_1[32] = "NORM_input_fpga.dat";
const static char Post_Norm_layer3_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Post_Norm_layer3_output_file[32]  = "NORM_output_fpga.dat";

// layer 4
const static char SA_layer4_input_file[32]  = "SA_input_token_fpga.dat";
const static char SA_layer4_weight_Q_file[32]  = "SA_Wq_fpga.dat";
const static char SA_layer4_weight_K_file[32]  = "SA_Wk_fpga.dat";
const static char SA_layer4_weight_V_file[32]  = "SA_Wv_fpga.dat";
const static char SA_layer4_bias_file[32]  	= "SA_fake_bias_fpga.dat";
const static char SA_layer4_output_Q_file[32]	= "SA_Q_fpga.dat";
const static char SA_layer4_output_K_file[32]	= "SA_K_fpga.dat";
const static char SA_layer4_output_V_file[32]	= "SA_V_fpga.dat";
const static char SA_layer4_output_QKT_file[32]	= "SA_QKT_fpga.dat";

const static char SOFTMAX_layer4_input_file[32]  = "soft_in_fpga.dat";
const static char SOFTMAX_layer4_output_file[32] = "soft_out_fpga.dat";

const static char Pre_Norm_layer4_input_file_1[32] = "NORM_input_fpga.dat";
const static char Pre_Norm_layer4_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Pre_Norm_layer4_output_file[32] 	= "NORM_output_fpga.dat";

const static char FFN_layer4_input_file_1[32] 	= "FFN_layer1_input_fpga.dat";
const static char FFN_layer4_weight_file_1[32]	= "FFN_layer1_weight_fpga.dat";
const static char FFN_layer4_bias_file_1[32]  	= "FFN_layer1_bias_fpga.dat";
const static char FFN_layer4_output_file_1[32]	= "FFN_layer1_output_fpga.dat";
const static char FFN_layer4_input_file_2[32] 	= "FFN_layer2_input_fpga.dat";
const static char FFN_layer4_weight_file_2[32]	= "FFN_layer2_weight_fpga.dat";
const static char FFN_layer4_bias_file_2[32]  	= "FFN_layer2_bias_fpga.dat";
const static char FFN_layer4_output_file_2[32]	= "FFN_layer2_output_fpga.dat";

const static char Post_Norm_layer4_input_file_1[32] = "NORM_input_fpga.dat";
const static char Post_Norm_layer4_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Post_Norm_layer4_output_file[32]  = "NORM_output_fpga.dat";

// layer 5
const static char SA_layer5_input_file[32]  = "SA_input_token_fpga.dat";
const static char SA_layer5_weight_Q_file[32]  = "SA_Wq_fpga.dat";
const static char SA_layer5_weight_K_file[32]  = "SA_Wk_fpga.dat";
const static char SA_layer5_weight_V_file[32]  = "SA_Wv_fpga.dat";
const static char SA_layer5_bias_file[32]  	= "SA_fake_bias_fpga.dat";
const static char SA_layer5_output_Q_file[32]	= "SA_Q_fpga.dat";
const static char SA_layer5_output_K_file[32]	= "SA_K_fpga.dat";
const static char SA_layer5_output_V_file[32]	= "SA_V_fpga.dat";
const static char SA_layer5_output_QKT_file[32]	= "SA_QKT_fpga.dat";

const static char SOFTMAX_layer5_input_file[32]  = "soft_in_fpga.dat";
const static char SOFTMAX_layer5_output_file[32] = "soft_out_fpga.dat";

const static char Pre_Norm_layer5_input_file_1[32] = "NORM_input_fpga.dat";
const static char Pre_Norm_layer5_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Pre_Norm_layer5_output_file[32] 	= "NORM_output_fpga.dat";

const static char FFN_layer5_input_file_1[32] 	= "FFN_layer1_input_fpga.dat";
const static char FFN_layer5_weight_file_1[32]	= "FFN_layer1_weight_fpga.dat";
const static char FFN_layer5_bias_file_1[32]  	= "FFN_layer1_bias_fpga.dat";
const static char FFN_layer5_output_file_1[32]	= "FFN_layer1_output_fpga.dat";
const static char FFN_layer5_input_file_2[32] 	= "FFN_layer2_input_fpga.dat";
const static char FFN_layer5_weight_file_2[32]	= "FFN_layer2_weight_fpga.dat";
const static char FFN_layer5_bias_file_2[32]  	= "FFN_layer2_bias_fpga.dat";
const static char FFN_layer5_output_file_2[32]	= "FFN_layer2_output_fpga.dat";

const static char Post_Norm_layer5_input_file_1[32] = "NORM_input_fpga.dat";
const static char Post_Norm_layer5_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Post_Norm_layer5_output_file[32]  = "NORM_output_fpga.dat";

// layer 6
const static char SA_layer6_input_file[32]  = "SA_input_token_fpga.dat";
const static char SA_layer6_weight_Q_file[32]  = "SA_Wq_fpga.dat";
const static char SA_layer6_weight_K_file[32]  = "SA_Wk_fpga.dat";
const static char SA_layer6_weight_V_file[32]  = "SA_Wv_fpga.dat";
const static char SA_layer6_bias_file[32]  	= "SA_fake_bias_fpga.dat";
const static char SA_layer6_output_Q_file[32]	= "SA_Q_fpga.dat";
const static char SA_layer6_output_K_file[32]	= "SA_K_fpga.dat";
const static char SA_layer6_output_V_file[32]	= "SA_V_fpga.dat";
const static char SA_layer6_output_QKT_file[32]	= "SA_QKT_fpga.dat";

const static char SOFTMAX_layer6_input_file[32]  = "soft_in_fpga.dat";
const static char SOFTMAX_layer6_output_file[32] = "soft_out_fpga.dat";

const static char Pre_Norm_layer6_input_file_1[32] = "NORM_input_fpga.dat";
const static char Pre_Norm_layer6_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Pre_Norm_layer6_output_file[32] 	= "NORM_output_fpga.dat";

const static char FFN_layer6_input_file_1[32] 	= "FFN_layer1_input_fpga.dat";
const static char FFN_layer6_weight_file_1[32]	= "FFN_layer1_weight_fpga.dat";
const static char FFN_layer6_bias_file_1[32]  	= "FFN_layer1_bias_fpga.dat";
const static char FFN_layer6_output_file_1[32]	= "FFN_layer1_output_fpga.dat";
const static char FFN_layer6_input_file_2[32] 	= "FFN_layer2_input_fpga.dat";
const static char FFN_layer6_weight_file_2[32]	= "FFN_layer2_weight_fpga.dat";
const static char FFN_layer6_bias_file_2[32]  	= "FFN_layer2_bias_fpga.dat";
const static char FFN_layer6_output_file_2[32]	= "FFN_layer2_output_fpga.dat";

const static char Post_Norm_layer6_input_file_1[32] = "NORM_input_fpga.dat";
const static char Post_Norm_layer6_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Post_Norm_layer6_output_file[32]  = "NORM_output_fpga.dat";

// layer 7
const static char SA_layer7_input_file[32]  = "SA_input_token_fpga.dat";
const static char SA_layer7_weight_Q_file[32]  = "SA_Wq_fpga.dat";
const static char SA_layer7_weight_K_file[32]  = "SA_Wk_fpga.dat";
const static char SA_layer7_weight_V_file[32]  = "SA_Wv_fpga.dat";
const static char SA_layer7_bias_file[32]  	= "SA_fake_bias_fpga.dat";
const static char SA_layer7_output_Q_file[32]	= "SA_Q_fpga.dat";
const static char SA_layer7_output_K_file[32]	= "SA_K_fpga.dat";
const static char SA_layer7_output_V_file[32]	= "SA_V_fpga.dat";
const static char SA_layer7_output_QKT_file[32]	= "SA_QKT_fpga.dat";

const static char SOFTMAX_layer7_input_file[32]  = "soft_in_fpga.dat";
const static char SOFTMAX_layer7_output_file[32] = "soft_out_fpga.dat";

const static char Pre_Norm_layer7_input_file_1[32] = "NORM_input_fpga.dat";
const static char Pre_Norm_layer7_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Pre_Norm_layer7_output_file[32] 	= "NORM_output_fpga.dat";

const static char FFN_layer7_input_file_1[32] 	= "FFN_layer1_input_fpga.dat";
const static char FFN_layer7_weight_file_1[32]	= "FFN_layer1_weight_fpga.dat";
const static char FFN_layer7_bias_file_1[32]  	= "FFN_layer1_bias_fpga.dat";
const static char FFN_layer7_output_file_1[32]	= "FFN_layer1_output_fpga.dat";
const static char FFN_layer7_input_file_2[32] 	= "FFN_layer2_input_fpga.dat";
const static char FFN_layer7_weight_file_2[32]	= "FFN_layer2_weight_fpga.dat";
const static char FFN_layer7_bias_file_2[32]  	= "FFN_layer2_bias_fpga.dat";
const static char FFN_layer7_output_file_2[32]	= "FFN_layer2_output_fpga.dat";

const static char Post_Norm_layer7_input_file_1[32] = "NORM_input_fpga.dat";
const static char Post_Norm_layer7_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Post_Norm_layer7_output_file[32]  = "NORM_output_fpga.dat";

// layer 8
const static char SA_layer8_input_file[32]  = "SA_input_token_fpga.dat";
const static char SA_layer8_weight_Q_file[32]  = "SA_Wq_fpga.dat";
const static char SA_layer8_weight_K_file[32]  = "SA_Wk_fpga.dat";
const static char SA_layer8_weight_V_file[32]  = "SA_Wv_fpga.dat";
const static char SA_layer8_bias_file[32]  	= "SA_fake_bias_fpga.dat";
const static char SA_layer8_output_Q_file[32]	= "SA_Q_fpga.dat";
const static char SA_layer8_output_K_file[32]	= "SA_K_fpga.dat";
const static char SA_layer8_output_V_file[32]	= "SA_V_fpga.dat";
const static char SA_layer8_output_QKT_file[32]	= "SA_QKT_fpga.dat";

const static char SOFTMAX_layer8_input_file[32]  = "soft_in_fpga.dat";
const static char SOFTMAX_layer8_output_file[32] = "soft_out_fpga.dat";

const static char Pre_Norm_layer8_input_file_1[32] = "NORM_input_fpga.dat";
const static char Pre_Norm_layer8_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Pre_Norm_layer8_output_file[32] 	= "NORM_output_fpga.dat";

const static char FFN_layer8_input_file_1[32] 	= "FFN_layer1_input_fpga.dat";
const static char FFN_layer8_weight_file_1[32]	= "FFN_layer1_weight_fpga.dat";
const static char FFN_layer8_bias_file_1[32]  	= "FFN_layer1_bias_fpga.dat";
const static char FFN_layer8_output_file_1[32]	= "FFN_layer1_output_fpga.dat";
const static char FFN_layer8_input_file_2[32] 	= "FFN_layer2_input_fpga.dat";
const static char FFN_layer8_weight_file_2[32]	= "FFN_layer2_weight_fpga.dat";
const static char FFN_layer8_bias_file_2[32]  	= "FFN_layer2_bias_fpga.dat";
const static char FFN_layer8_output_file_2[32]	= "FFN_layer2_output_fpga.dat";

const static char Post_Norm_layer8_input_file_1[32] = "NORM_input_fpga.dat";
const static char Post_Norm_layer8_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Post_Norm_layer8_output_file[32]  = "NORM_output_fpga.dat";

// layer 9
const static char SA_layer9_input_file[32]  = "SA_input_token_fpga.dat";
const static char SA_layer9_weight_Q_file[32]  = "SA_Wq_fpga.dat";
const static char SA_layer9_weight_K_file[32]  = "SA_Wk_fpga.dat";
const static char SA_layer9_weight_V_file[32]  = "SA_Wv_fpga.dat";
const static char SA_layer9_bias_file[32]  	= "SA_fake_bias_fpga.dat";
const static char SA_layer9_output_Q_file[32]	= "SA_Q_fpga.dat";
const static char SA_layer9_output_K_file[32]	= "SA_K_fpga.dat";
const static char SA_layer9_output_V_file[32]	= "SA_V_fpga.dat";
const static char SA_layer9_output_QKT_file[32]	= "SA_QKT_fpga.dat";

const static char SOFTMAX_layer9_input_file[32]  = "soft_in_fpga.dat";
const static char SOFTMAX_layer9_output_file[32] = "soft_out_fpga.dat";

const static char Pre_Norm_layer9_input_file_1[32] = "NORM_input_fpga.dat";
const static char Pre_Norm_layer9_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Pre_Norm_layer9_output_file[32] 	= "NORM_output_fpga.dat";

const static char FFN_layer9_input_file_1[32] 	= "FFN_layer1_input_fpga.dat";
const static char FFN_layer9_weight_file_1[32]	= "FFN_layer1_weight_fpga.dat";
const static char FFN_layer9_bias_file_1[32]  	= "FFN_layer1_bias_fpga.dat";
const static char FFN_layer9_output_file_1[32]	= "FFN_layer1_output_fpga.dat";
const static char FFN_layer9_input_file_2[32] 	= "FFN_layer2_input_fpga.dat";
const static char FFN_layer9_weight_file_2[32]	= "FFN_layer2_weight_fpga.dat";
const static char FFN_layer9_bias_file_2[32]  	= "FFN_layer2_bias_fpga.dat";
const static char FFN_layer9_output_file_2[32]	= "FFN_layer2_output_fpga.dat";

const static char Post_Norm_layer9_input_file_1[32] = "NORM_input_fpga.dat";
const static char Post_Norm_layer9_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Post_Norm_layer9_output_file[32]  = "NORM_output_fpga.dat";

// layer 10
const static char SA_layer10_input_file[32]  = "SA_input_token_fpga.dat";
const static char SA_layer10_weight_Q_file[32]  = "SA_Wq_fpga.dat";
const static char SA_layer10_weight_K_file[32]  = "SA_Wk_fpga.dat";
const static char SA_layer10_weight_V_file[32]  = "SA_Wv_fpga.dat";
const static char SA_layer10_bias_file[32]  	= "SA_fake_bias_fpga.dat";
const static char SA_layer10_output_Q_file[32]	= "SA_Q_fpga.dat";
const static char SA_layer10_output_K_file[32]	= "SA_K_fpga.dat";
const static char SA_layer10_output_V_file[32]	= "SA_V_fpga.dat";
const static char SA_layer10_output_QKT_file[32]	= "SA_QKT_fpga.dat";

const static char SOFTMAX_layer10_input_file[32]  = "soft_in_fpga.dat";
const static char SOFTMAX_layer10_output_file[32] = "soft_out_fpga.dat";

const static char Pre_Norm_layer10_input_file_1[32] = "NORM_input_fpga.dat";
const static char Pre_Norm_layer10_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Pre_Norm_layer10_output_file[32] 	= "NORM_output_fpga.dat";

const static char FFN_layer10_input_file_1[32] 	= "FFN_layer1_input_fpga.dat";
const static char FFN_layer10_weight_file_1[32]	= "FFN_layer1_weight_fpga.dat";
const static char FFN_layer10_bias_file_1[32]  	= "FFN_layer1_bias_fpga.dat";
const static char FFN_layer10_output_file_1[32]	= "FFN_layer1_output_fpga.dat";
const static char FFN_layer10_input_file_2[32] 	= "FFN_layer2_input_fpga.dat";
const static char FFN_layer10_weight_file_2[32]	= "FFN_layer2_weight_fpga.dat";
const static char FFN_layer10_bias_file_2[32]  	= "FFN_layer2_bias_fpga.dat";
const static char FFN_layer10_output_file_2[32]	= "FFN_layer2_output_fpga.dat";

const static char Post_Norm_layer10_input_file_1[32] = "NORM_input_fpga.dat";
const static char Post_Norm_layer10_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Post_Norm_layer10_output_file[32]  = "NORM_output_fpga.dat";

// layer 11
const static char SA_layer11_input_file[32]  = "SA_input_token_fpga.dat";
const static char SA_layer11_weight_Q_file[32]  = "SA_Wq_fpga.dat";
const static char SA_layer11_weight_K_file[32]  = "SA_Wk_fpga.dat";
const static char SA_layer11_weight_V_file[32]  = "SA_Wv_fpga.dat";
const static char SA_layer11_bias_file[32]  	= "SA_fake_bias_fpga.dat";
const static char SA_layer11_output_Q_file[32]	= "SA_Q_fpga.dat";
const static char SA_layer11_output_K_file[32]	= "SA_K_fpga.dat";
const static char SA_layer11_output_V_file[32]	= "SA_V_fpga.dat";
const static char SA_layer11_output_QKT_file[32]	= "SA_QKT_fpga.dat";

const static char SOFTMAX_layer11_input_file[32]  = "soft_in_fpga.dat";
const static char SOFTMAX_layer11_output_file[32] = "soft_out_fpga.dat";

const static char Pre_Norm_layer11_input_file_1[32] = "NORM_input_fpga.dat";
const static char Pre_Norm_layer11_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Pre_Norm_layer11_output_file[32] 	= "NORM_output_fpga.dat";

const static char FFN_layer11_input_file_1[32] 	= "FFN_layer1_input_fpga.dat";
const static char FFN_layer11_weight_file_1[32]	= "FFN_layer1_weight_fpga.dat";
const static char FFN_layer11_bias_file_1[32]  	= "FFN_layer1_bias_fpga.dat";
const static char FFN_layer11_output_file_1[32]	= "FFN_layer1_output_fpga.dat";
const static char FFN_layer11_input_file_2[32] 	= "FFN_layer2_input_fpga.dat";
const static char FFN_layer11_weight_file_2[32]	= "FFN_layer2_weight_fpga.dat";
const static char FFN_layer11_bias_file_2[32]  	= "FFN_layer2_bias_fpga.dat";
const static char FFN_layer11_output_file_2[32]	= "FFN_layer2_output_fpga.dat";

const static char Post_Norm_layer11_input_file_1[32] = "NORM_input_fpga.dat";
const static char Post_Norm_layer11_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Post_Norm_layer11_output_file[32]  = "NORM_output_fpga.dat";

// layer 12
const static char SA_layer12_input_file[32]  = "SA_input_token_fpga.dat";
const static char SA_layer12_weight_Q_file[32]  = "SA_Wq_fpga.dat";
const static char SA_layer12_weight_K_file[32]  = "SA_Wk_fpga.dat";
const static char SA_layer12_weight_V_file[32]  = "SA_Wv_fpga.dat";
const static char SA_layer12_bias_file[32]  	= "SA_fake_bias_fpga.dat";
const static char SA_layer12_output_Q_file[32]	= "SA_Q_fpga.dat";
const static char SA_layer12_output_K_file[32]	= "SA_K_fpga.dat";
const static char SA_layer12_output_V_file[32]	= "SA_V_fpga.dat";
const static char SA_layer12_output_QKT_file[32]	= "SA_QKT_fpga.dat";

const static char SOFTMAX_layer12_input_file[32]  = "soft_in_fpga.dat";
const static char SOFTMAX_layer12_output_file[32] = "soft_out_fpga.dat";

const static char Pre_Norm_layer12_input_file_1[32] = "NORM_input_fpga.dat";
const static char Pre_Norm_layer12_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Pre_Norm_layer12_output_file[32] 	= "NORM_output_fpga.dat";

const static char FFN_layer12_input_file_1[32] 	= "FFN_layer1_input_fpga.dat";
const static char FFN_layer12_weight_file_1[32]	= "FFN_layer1_weight_fpga.dat";
const static char FFN_layer12_bias_file_1[32]  	= "FFN_layer1_bias_fpga.dat";
const static char FFN_layer12_output_file_1[32]	= "FFN_layer1_output_fpga.dat";
const static char FFN_layer12_input_file_2[32] 	= "FFN_layer2_input_fpga.dat";
const static char FFN_layer12_weight_file_2[32]	= "FFN_layer2_weight_fpga.dat";
const static char FFN_layer12_bias_file_2[32]  	= "FFN_layer2_bias_fpga.dat";
const static char FFN_layer12_output_file_2[32]	= "FFN_layer2_output_fpga.dat";

const static char Post_Norm_layer12_input_file_1[32] = "NORM_input_fpga.dat";
const static char Post_Norm_layer12_input_file_2[32] = "NORM_input1_fpga.dat";
const static char Post_Norm_layer12_output_file[32]  = "NORM_output_fpga.dat";

const static char Weight_q[32]  = "SA_Wq_fpga.dat";
const static char Weight_k[32]  = "SA_Wk_fpga.dat";
const static char Weight_v[32]  = "SA_Wv_fpga.dat";
const static char IFm_token[32] = "SA_input_token_fpga.dat";
const static char gold_q[32]	= "SA_Q_fpga.dat";
const static char bias[32]		= "SA_fake_bias_fpga.dat";
const static char gold_k[32]	= "SA_K_fpga.dat";
const static char gold_v[32]	= "SA_V_fpga.dat";
const static char gold_qkt[32]	= "SA_QKT_fpga.dat";

static const char* SOFTMAX_input_file_1  = "soft_in_fpga.dat";    // 416 x 64-bit
static const char* SOFTMAX_output_file_1 = "soft_out_fpga.dat";   // 3328 x 64-bit

const static char NORM_input_file_1[32] = "NORM_input_fpga.dat";
const static char NORM_input_file_2[32] = "NORM_input1_fpga.dat";
const static char NORM_output_file[32] 	= "NORM_output_fpga.dat";

const static char Q_input_file[32] 	= "Q_input_fpga.dat";
const static char Q_weight_file[32]	= "Wq_fpga.dat";
const static char Q_bias_file[32]  	= "bias0.dat";
const static char Q_output_file[32]	= "Q_fpga.dat";

const static char FFN_input_file_1[32] 	= "FFN_layer1_input_fpga.dat";
const static char FFN_weight_file_1[32]	= "FFN_layer1_weight_fpga.dat";
const static char FFN_bias_file_1[32]  	= "FFN_layer1_bias_fpga.dat";
const static char FFN_output_file_1[32]	= "FFN_layer1_output_fpga.dat";

const static char FFN_input_file_2[32] 	= "FFN_layer2_input_fpga.dat";
const static char FFN_weight_file_2[32]	= "FFN_layer2_weight_fpga.dat";
const static char FFN_bias_file_2[32]  	= "FFN_layer2_bias_fpga.dat";
const static char FFN_output_file_2[32]	= "FFN_layer2_output_fpga.dat";

static inline int hexval(int c){
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

static inline int parse_hex16_to_u64(const char *s, u64 *out){
    u64 v = 0;
    for (int i = 0; i < 16; ++i){
        int h = hexval((int)s[i]);
        if (h < 0) return -1;
        v = (v << 4) | (u64)h;
    }
    *out = v;
    return 0;
}

static FRESULT read_stream_u64(FIL *fp, u64 *out, int count){
    FRESULT fr = f_lseek(fp, 0);
    if (fr) return fr;

    BYTE buf[1024];
    UINT n = 0;
    char hexbuf[16];
    int  hlen = 0, idx = 0;

    while (idx < count){
        fr = f_read(fp, buf, sizeof(buf), &n);
        if (fr) return fr;
        if (n == 0) break;

        for (UINT i = 0; i < n && idx < count; ++i){
            int hv = hexval((int)buf[i]);
            if (hv < 0) continue;
            hexbuf[hlen++] = (char)buf[i];
            if (hlen == 16){
                u64 v;
                if (parse_hex16_to_u64(hexbuf, &v) != 0) return FR_INVALID_OBJECT;
                out[idx++] = v;
                hlen = 0;
            }
        }
    }
    return (idx == count) ? FR_OK : FR_INT_ERR;
}

static int READ_U64_STREAM(const char *file_name, int word_count, u64 *outt){
    FIL f;
    FRESULT fr = f_open(&f, file_name, FA_READ);
    if (fr){
        // xil_printf("[OPEN] %s failed, fr=%d\r\n", file_name, (int)fr);
        return XST_FAILURE;
    }

    fr = read_stream_u64(&f, outt, word_count);
    f_close(&f);
    if (fr == FR_OK){
        // xil_printf("[OK] %s loaded (64b stream), words=%d\r\n", file_name, word_count);
        return XST_SUCCESS;
    }else{
        // xil_printf("[FAIL] %s parse error, fr=%d\r\n", file_name, (int)fr);
        return XST_FAILURE;
    }
}

int READ_BIAS(int bias_size, const char *file_name, u64 *out){
	FRESULT Res;
	UINT NumBytesRead;

	u8  temp[18];
	u8  temp1[9];
	u8  temp2[9];
	u64 temp3;
	u64 temp4;
	u8  temp5;

	Res = f_open(&fil_bias, file_name, FA_READ);
	if(Res){ return XST_FAILURE; }

	// Set pointer to beginning of file.
	Res = f_lseek(&fil_bias, 0);
	if(Res){ return XST_FAILURE; }

	// Read data from file.
	for(int i=0; i<bias_size; i++){
		Res = f_read(&fil_bias, (void*)temp, 8,  &NumBytesRead);
		if(Res){ return XST_FAILURE; }
		temp1[8] = '\0';
		temp2[8] = '\0';
		for(int j=0; j<8; j++){
			temp1[j] = temp[j];
		}
		for(int j=0; j<8; j++){
			temp2[j] = temp[j+8];
		}
		temp3 = (u64)strtol(temp1, NULL, 16);
		temp3 = temp3 & 0x00000000FFFFFFFF;
		temp4 = (u64)strtol(temp2, NULL, 16);
		temp4 = temp4 & 0x00000000FFFFFFFF;

		out[i] = (temp3 << 32) + temp4;
	}
	// Close file.
	Res = f_close(&fil_bias);
	if(Res){ return XST_FAILURE; }
}

int READ_INT8(int input_size,char** file_name, u8 * outt){
	FRESULT Res;
	UINT NumBytesRead;
	static FIL fil_weights;

	u8  temp1;
	u8	temp2;

	Res = f_open(&fil_weights,file_name, FA_READ);
	if(Res){ return XST_FAILURE; }

	Res = f_lseek(&fil_weights, 0);
	if(Res){ return XST_FAILURE; }

	for(int i=0; i<input_size; i++){
		Res = f_read(&fil_weights, (void*)temp1, 2,  &NumBytesRead);
		if(Res){ return XST_FAILURE; }
		temp2 = (u8)strtol(temp1, NULL, 16);
		outt[i] = temp2;
	}

	Res = f_close(&fil_weights);
	if(Res){ return XST_FAILURE; }
}

int READ_INT16(int input_size, const char *file_name, u16 *out)
{
    FRESULT Res;
    UINT NumBytesRead;
    char ch;
    char hexbuf[5];
    int  hex_pos = 0;
    int  idx = 0;

    Res = f_open(&fil_input, file_name, FA_READ);
    if (Res) return XST_FAILURE;

    Res = f_lseek(&fil_input, 0);
    if (Res) return XST_FAILURE;

    while (idx < input_size) {
        Res = f_read(&fil_input, &ch, 1, &NumBytesRead);
        if (Res) { f_close(&fil_input); return XST_FAILURE; }

        if (NumBytesRead == 0) {
            break;
        }

        if (!((ch >= '0' && ch <= '9') ||
              (ch >= 'a' && ch <= 'f') ||
              (ch >= 'A' && ch <= 'F'))) {
            continue;
        }

        hexbuf[hex_pos++] = ch;

        if (hex_pos == 4) {
            hexbuf[4] = '\0';
            out[idx++] = (u16)strtol(hexbuf, NULL, 16);
            hex_pos = 0;
        }
    }

    f_close(&fil_input);
    return (idx == input_size) ? XST_SUCCESS : XST_FAILURE;
}

int READ_INT64(int input_size, const char *file_name, u64 *out){
	FRESULT Res;
	UINT NumBytesRead;
	u8 temp[18];
	u8 temp1[9];
	u8 temp2[9];
	u64 temp3;
	u64 temp4;

	Res = f_open(&fil_input, file_name, FA_READ);
	if (Res) { return XST_FAILURE; }

	Res = f_lseek(&fil_input, 0);
	if (Res) { return XST_FAILURE; }

	for (int i = 0; i < input_size; i++)
	{
		Res = f_read(&fil_input, (void *)temp, 16, &NumBytesRead);
		if (Res) { return XST_FAILURE; }
		temp1[8] = '\0';
		temp2[8] = '\0';
		for (int j = 0; j < 8; j++)
		{
			temp1[j] = temp[j];
			temp2[j] = temp[j + 8];
		}
		temp3 = (u64)strtol((const char *)temp1, NULL, 16) & 0xFFFFFFFF;
		temp4 = (u64)strtol((const char *)temp2, NULL, 16) & 0xFFFFFFFF;
		out[i] = (temp3 << 32) + temp4;
	}
	Res = f_close(&fil_input);
	if (Res) { return XST_FAILURE; }
	return XST_SUCCESS;
}

int v3_data_init(){
	xil_printf("---------------- SD Card Reading ...... ----------------\r\n");

	FRESULT Res;
	UINT NumBytesRead;
	TCHAR *Path = "0:/";

	Res = f_mount(&fatfs, Path, 0);
    if(Res != FR_OK){ return XST_FAILURE; }

    Res = READ_INT8(64*512, &SA_layer1_input_file, &SA_layer1_input_token);
    if(Res){ return XST_FAILURE; }

    Res = READ_INT8(512*512, &SA_layer1_weight_Q_file, &SA_layer1_weight_Q);
    if(Res){ return XST_FAILURE; }
    Res = READ_INT8(512*512, &SA_layer1_weight_K_file, &SA_layer1_weight_K);
    if(Res){ return XST_FAILURE; }
    Res = READ_INT8(512*512, &SA_layer1_weight_V_file, &SA_layer1_weight_V);
    if(Res){ return XST_FAILURE; }

    Res = READ_BIAS(8*8, &SA_layer1_bias_file,(u64) &SA_layer1_bias_Q);
    if(Res){ return XST_FAILURE; }
    Res = READ_BIAS(8*8, &SA_layer1_bias_file,(u64) &SA_layer1_bias_K);
    if(Res){ return XST_FAILURE; }
    Res = READ_BIAS(8*8, &SA_layer1_bias_file,(u64) &SA_layer1_bias_V);
    if(Res){ return XST_FAILURE; }
    Res = READ_BIAS(8*8, &SA_layer1_bias_file,(u64) &SA_layer1_bias_QKT);
    if(Res){ return XST_FAILURE; }

    Res = READ_INT8(64*512, &SA_layer1_output_Q_file, &SA_layer1_output_Q_gold);
    if(Res){ return XST_FAILURE; }
    Res = READ_INT8(64*512, &SA_layer1_output_K_file, &SA_layer1_output_K_gold);
    if(Res){ return XST_FAILURE; }
    Res = READ_INT8(64*512, &SA_layer1_output_V_file, &SA_layer1_output_V_gold);
    if(Res){ return XST_FAILURE; }
    Res = READ_INT8(64*64, &SA_layer1_output_QKT_file, &SA_layer1_output_QKT_gold);
    if(Res){ return XST_FAILURE; }

    if (READ_U64_STREAM(SOFTMAX_layer1_input_file, 416, SOFTMAX_layer1_input) != XST_SUCCESS)
    return XST_FAILURE;
    if (READ_U64_STREAM(SOFTMAX_layer1_output_file, 3328, SOFTMAX_layer1_output_gold) != XST_SUCCESS)
    return XST_FAILURE;

	Res = READ_INT64(64, &Pre_Norm_layer1_input_file_1, &Pre_Norm_layer1_input_1);
	if(Res){ return XST_FAILURE; }
	Res = READ_INT64(64, &Pre_Norm_layer1_input_file_2, &Pre_Norm_layer1_input_2);
	if(Res){ return XST_FAILURE; }
	Res = READ_INT64(512, &Pre_Norm_layer1_output_file, &Pre_Norm_layer1_output_gold);
	if(Res){ return XST_FAILURE; }

	Res = READ_INT64(64*64, &FFN_layer1_input_file_1, &FFN_layer1_input_1);
	if(Res){ return XST_FAILURE; }
    Res = READ_INT64(64*2048, &FFN_layer1_weight_file_1, &FFN_layer1_weight_1);
    if(Res){ return XST_FAILURE; }
    Res = READ_INT64(2048, &FFN_layer1_bias_file_1, (u64) &FFN_layer1_bias_1);
    if(Res){ return XST_FAILURE; }
	Res = READ_INT64(64*256, &FFN_layer1_output_file_1, &FFN_layer1_output_1_gold);
    if(Res){ return XST_FAILURE; }

	Res = READ_INT64(64*256, &FFN_layer1_input_file_2, &FFN_layer1_input_2);
	if(Res){ return XST_FAILURE; }
	Res = READ_INT64(256*512, &FFN_layer1_weight_file_2, &FFN_layer1_weight_2);
	if(Res){ return XST_FAILURE; }
	Res = READ_INT64(512, &FFN_layer1_bias_file_2, (u64) &FFN_layer1_bias_2);
	if(Res){ return XST_FAILURE; }
	Res = READ_INT64(64*64, &FFN_layer1_output_file_2, &FFN_layer1_output_2_gold);
	if(Res){ return XST_FAILURE; }

    Res = READ_INT64(64, &Post_Norm_layer1_input_file_1, &Post_Norm_layer1_input_1);
	if(Res){ return XST_FAILURE; }
	Res = READ_INT64(64, &Post_Norm_layer1_input_file_2, &Post_Norm_layer1_input_2);
	if(Res){ return XST_FAILURE; }
	Res = READ_INT64(512, &Post_Norm_layer1_output_file, &Post_Norm_layer1_output_gold);
	if(Res){ return XST_FAILURE; }

    SA_layer2_input_token = SA_layer1_input_token;

    SA_layer2_weight_Q = SA_layer1_weight_Q;
    SA_layer2_weight_K = SA_layer1_weight_K;
    SA_layer2_weight_V = SA_layer1_weight_V;
    
    SA_layer2_bias_Q = SA_layer1_bias_Q;
    SA_layer2_bias_K = SA_layer1_bias_K;
    SA_layer2_bias_V = SA_layer1_bias_V;
    SA_layer2_bias_QKT = SA_layer1_bias_QKT;
    
    SA_layer2_output_Q_gold = SA_layer1_output_Q_gold;
    SA_layer2_output_K_gold = SA_layer1_output_K_gold;
    SA_layer2_output_V_gold = SA_layer1_output_V_gold;
    SA_layer2_output_QKT_gold = SA_layer1_output_QKT_gold;
    
    SOFTMAX_layer2_input = SOFTMAX_layer1_input;
    SOFTMAX_layer2_output_gold = SOFTMAX_layer1_output_gold;

    Pre_Norm_layer2_input_1 = Pre_Norm_layer1_input_1;
    Pre_Norm_layer2_input_2 = Pre_Norm_layer1_input_2;
    Pre_Norm_layer2_output_gold = Pre_Norm_layer1_output_gold;
    
    FFN_layer2_input_1 = FFN_layer1_input_1;
    FFN_layer2_weight_1 = FFN_layer1_weight_1;
    FFN_layer2_bias_1 = FFN_layer1_bias_1;
    FFN_layer2_output_1_gold = FFN_layer1_output_1_gold;
    FFN_layer2_input_2 = FFN_layer1_input_2;
    FFN_layer2_weight_2 = FFN_layer1_weight_2;
    FFN_layer2_bias_2 = FFN_layer1_bias_2;
    FFN_layer2_output_2_gold = FFN_layer1_output_2_gold;
    
    Post_Norm_layer2_input_1 = Post_Norm_layer1_input_1;
    Post_Norm_layer2_input_2 = Post_Norm_layer1_input_2;
    Post_Norm_layer2_output_gold = Post_Norm_layer1_output_gold;

    SA_layer3_input_token = SA_layer2_input_token;

    SA_layer3_weight_Q = SA_layer2_weight_Q;
    SA_layer3_weight_K = SA_layer2_weight_K;
    SA_layer3_weight_V = SA_layer2_weight_V;

    SA_layer3_bias_Q = SA_layer2_bias_Q;
    SA_layer3_bias_K = SA_layer2_bias_K;
    SA_layer3_bias_V = SA_layer2_bias_V;
    SA_layer3_bias_QKT = SA_layer2_bias_QKT;

    SA_layer3_output_Q_gold = SA_layer2_output_Q_gold;
    SA_layer3_output_K_gold = SA_layer2_output_K_gold;
    SA_layer3_output_V_gold = SA_layer2_output_V_gold;
    SA_layer3_output_QKT_gold = SA_layer2_output_QKT_gold;

    SOFTMAX_layer3_input = SOFTMAX_layer2_input;
    SOFTMAX_layer3_output_gold = SOFTMAX_layer2_output_gold;

    Pre_Norm_layer3_input_1 = Pre_Norm_layer2_input_1;
    Pre_Norm_layer3_input_2 = Pre_Norm_layer2_input_2;
    Pre_Norm_layer3_output_gold = Pre_Norm_layer2_output_gold;

    FFN_layer3_input_1 = FFN_layer2_input_1;
    FFN_layer3_weight_1 = FFN_layer2_weight_1;
    FFN_layer3_bias_1 = FFN_layer2_bias_1;
    FFN_layer3_output_1_gold = FFN_layer2_output_1_gold;

    FFN_layer3_input_2 = FFN_layer2_input_2;
    FFN_layer3_weight_2 = FFN_layer2_weight_2;
    FFN_layer3_bias_2 = FFN_layer2_bias_2;
    FFN_layer3_output_2_gold = FFN_layer2_output_2_gold;

    Post_Norm_layer3_input_1 = Post_Norm_layer2_input_1;
    Post_Norm_layer3_input_2 = Post_Norm_layer2_input_2;
    Post_Norm_layer3_output_gold = Post_Norm_layer2_output_gold;

    SA_layer4_input_token = SA_layer3_input_token;

    SA_layer4_weight_Q = SA_layer3_weight_Q;
    SA_layer4_weight_K = SA_layer3_weight_K;
    SA_layer4_weight_V = SA_layer3_weight_V;

    SA_layer4_bias_Q = SA_layer3_bias_Q;
    SA_layer4_bias_K = SA_layer3_bias_K;
    SA_layer4_bias_V = SA_layer3_bias_V;
    SA_layer4_bias_QKT = SA_layer3_bias_QKT;

    SA_layer4_output_Q_gold = SA_layer3_output_Q_gold;
    SA_layer4_output_K_gold = SA_layer3_output_K_gold;
    SA_layer4_output_V_gold = SA_layer3_output_V_gold;
    SA_layer4_output_QKT_gold = SA_layer3_output_QKT_gold;

    SOFTMAX_layer4_input = SOFTMAX_layer3_input;
    SOFTMAX_layer4_output_gold = SOFTMAX_layer3_output_gold;

    Pre_Norm_layer4_input_1 = Pre_Norm_layer3_input_1;
    Pre_Norm_layer4_input_2 = Pre_Norm_layer3_input_2;
    Pre_Norm_layer4_output_gold = Pre_Norm_layer3_output_gold;

    FFN_layer4_input_1 = FFN_layer3_input_1;
    FFN_layer4_weight_1 = FFN_layer3_weight_1;
    FFN_layer4_bias_1 = FFN_layer3_bias_1;
    FFN_layer4_output_1_gold = FFN_layer3_output_1_gold;

    FFN_layer4_input_2 = FFN_layer3_input_2;
    FFN_layer4_weight_2 = FFN_layer3_weight_2;
    FFN_layer4_bias_2 = FFN_layer3_bias_2;
    FFN_layer4_output_2_gold = FFN_layer3_output_2_gold;

    Post_Norm_layer4_input_1 = Post_Norm_layer3_input_1;
    Post_Norm_layer4_input_2 = Post_Norm_layer3_input_2;
    Post_Norm_layer4_output_gold = Post_Norm_layer3_output_gold;

    SA_layer5_input_token = SA_layer4_input_token;

    SA_layer5_weight_Q = SA_layer4_weight_Q;
    SA_layer5_weight_K = SA_layer4_weight_K;
    SA_layer5_weight_V = SA_layer4_weight_V;

    SA_layer5_bias_Q = SA_layer4_bias_Q;
    SA_layer5_bias_K = SA_layer4_bias_K;
    SA_layer5_bias_V = SA_layer4_bias_V;
    SA_layer5_bias_QKT = SA_layer4_bias_QKT;

    SA_layer5_output_Q_gold = SA_layer4_output_Q_gold;
    SA_layer5_output_K_gold = SA_layer4_output_K_gold;
    SA_layer5_output_V_gold = SA_layer4_output_V_gold;
    SA_layer5_output_QKT_gold = SA_layer4_output_QKT_gold;

    SOFTMAX_layer5_input = SOFTMAX_layer4_input;
    SOFTMAX_layer5_output_gold = SOFTMAX_layer4_output_gold;

    Pre_Norm_layer5_input_1 = Pre_Norm_layer4_input_1;
    Pre_Norm_layer5_input_2 = Pre_Norm_layer4_input_2;
    Pre_Norm_layer5_output_gold = Pre_Norm_layer4_output_gold;

    FFN_layer5_input_1 = FFN_layer4_input_1;
    FFN_layer5_weight_1 = FFN_layer4_weight_1;
    FFN_layer5_bias_1 = FFN_layer4_bias_1;
    FFN_layer5_output_1_gold = FFN_layer4_output_1_gold;

    FFN_layer5_input_2 = FFN_layer4_input_2;
    FFN_layer5_weight_2 = FFN_layer4_weight_2;
    FFN_layer5_bias_2 = FFN_layer4_bias_2;
    FFN_layer5_output_2_gold = FFN_layer4_output_2_gold;

    Post_Norm_layer5_input_1 = Post_Norm_layer4_input_1;
    Post_Norm_layer5_input_2 = Post_Norm_layer4_input_2;
    Post_Norm_layer5_output_gold = Post_Norm_layer4_output_gold;

    SA_layer6_input_token = SA_layer5_input_token;

    SA_layer6_weight_Q = SA_layer5_weight_Q;
    SA_layer6_weight_K = SA_layer5_weight_K;
    SA_layer6_weight_V = SA_layer5_weight_V;

    SA_layer6_bias_Q = SA_layer5_bias_Q;
    SA_layer6_bias_K = SA_layer5_bias_K;
    SA_layer6_bias_V = SA_layer5_bias_V;
    SA_layer6_bias_QKT = SA_layer5_bias_QKT;

    SA_layer6_output_Q_gold = SA_layer5_output_Q_gold;
    SA_layer6_output_K_gold = SA_layer5_output_K_gold;
    SA_layer6_output_V_gold = SA_layer5_output_V_gold;
    SA_layer6_output_QKT_gold = SA_layer5_output_QKT_gold;

    SOFTMAX_layer6_input = SOFTMAX_layer5_input;
    SOFTMAX_layer6_output_gold = SOFTMAX_layer5_output_gold;

    Pre_Norm_layer6_input_1 = Pre_Norm_layer5_input_1;
    Pre_Norm_layer6_input_2 = Pre_Norm_layer5_input_2;
    Pre_Norm_layer6_output_gold = Pre_Norm_layer5_output_gold;

    FFN_layer6_input_1 = FFN_layer5_input_1;
    FFN_layer6_weight_1 = FFN_layer5_weight_1;
    FFN_layer6_bias_1 = FFN_layer5_bias_1;
    FFN_layer6_output_1_gold = FFN_layer5_output_1_gold;

    FFN_layer6_input_2 = FFN_layer5_input_2;
    FFN_layer6_weight_2 = FFN_layer5_weight_2;
    FFN_layer6_bias_2 = FFN_layer5_bias_2;
    FFN_layer6_output_2_gold = FFN_layer5_output_2_gold;

    Post_Norm_layer6_input_1 = Post_Norm_layer5_input_1;
    Post_Norm_layer6_input_2 = Post_Norm_layer5_input_2;
    Post_Norm_layer6_output_gold = Post_Norm_layer5_output_gold;

    SA_layer7_input_token = SA_layer6_input_token;

    SA_layer7_weight_Q = SA_layer6_weight_Q;
    SA_layer7_weight_K = SA_layer6_weight_K;
    SA_layer7_weight_V = SA_layer6_weight_V;

    SA_layer7_bias_Q = SA_layer6_bias_Q;
    SA_layer7_bias_K = SA_layer6_bias_K;
    SA_layer7_bias_V = SA_layer6_bias_V;
    SA_layer7_bias_QKT = SA_layer6_bias_QKT;

    SA_layer7_output_Q_gold = SA_layer6_output_Q_gold;
    SA_layer7_output_K_gold = SA_layer6_output_K_gold;
    SA_layer7_output_V_gold = SA_layer6_output_V_gold;
    SA_layer7_output_QKT_gold = SA_layer6_output_QKT_gold;

    SOFTMAX_layer7_input = SOFTMAX_layer6_input;
    SOFTMAX_layer7_output_gold = SOFTMAX_layer6_output_gold;

    Pre_Norm_layer7_input_1 = Pre_Norm_layer6_input_1;
    Pre_Norm_layer7_input_2 = Pre_Norm_layer6_input_2;
    Pre_Norm_layer7_output_gold = Pre_Norm_layer6_output_gold;

    FFN_layer7_input_1 = FFN_layer6_input_1;
    FFN_layer7_weight_1 = FFN_layer6_weight_1;
    FFN_layer7_bias_1 = FFN_layer6_bias_1;
    FFN_layer7_output_1_gold = FFN_layer6_output_1_gold;

    FFN_layer7_input_2 = FFN_layer6_input_2;
    FFN_layer7_weight_2 = FFN_layer6_weight_2;
    FFN_layer7_bias_2 = FFN_layer6_bias_2;
    FFN_layer7_output_2_gold = FFN_layer6_output_2_gold;

    Post_Norm_layer7_input_1 = Post_Norm_layer6_input_1;
    Post_Norm_layer7_input_2 = Post_Norm_layer6_input_2;
    Post_Norm_layer7_output_gold = Post_Norm_layer6_output_gold;

    SA_layer8_input_token = SA_layer7_input_token;

    SA_layer8_weight_Q = SA_layer7_weight_Q;
    SA_layer8_weight_K = SA_layer7_weight_K;
    SA_layer8_weight_V = SA_layer7_weight_V;

    SA_layer8_bias_Q = SA_layer7_bias_Q;
    SA_layer8_bias_K = SA_layer7_bias_K;
    SA_layer8_bias_V = SA_layer7_bias_V;
    SA_layer8_bias_QKT = SA_layer7_bias_QKT;

    SA_layer8_output_Q_gold = SA_layer7_output_Q_gold;
    SA_layer8_output_K_gold = SA_layer7_output_K_gold;
    SA_layer8_output_V_gold = SA_layer7_output_V_gold;
    SA_layer8_output_QKT_gold = SA_layer7_output_QKT_gold;

    SOFTMAX_layer8_input = SOFTMAX_layer7_input;
    SOFTMAX_layer8_output_gold = SOFTMAX_layer7_output_gold;

    Pre_Norm_layer8_input_1 = Pre_Norm_layer7_input_1;
    Pre_Norm_layer8_input_2 = Pre_Norm_layer7_input_2;
    Pre_Norm_layer8_output_gold = Pre_Norm_layer7_output_gold;

    FFN_layer8_input_1 = FFN_layer7_input_1;
    FFN_layer8_weight_1 = FFN_layer7_weight_1;
    FFN_layer8_bias_1 = FFN_layer7_bias_1;
    FFN_layer8_output_1_gold = FFN_layer7_output_1_gold;

    FFN_layer8_input_2 = FFN_layer7_input_2;
    FFN_layer8_weight_2 = FFN_layer7_weight_2;
    FFN_layer8_bias_2 = FFN_layer7_bias_2;
    FFN_layer8_output_2_gold = FFN_layer7_output_2_gold;

    Post_Norm_layer8_input_1 = Post_Norm_layer7_input_1;
    Post_Norm_layer8_input_2 = Post_Norm_layer7_input_2;
    Post_Norm_layer8_output_gold = Post_Norm_layer7_output_gold;

    SA_layer9_input_token = SA_layer8_input_token;

    SA_layer9_weight_Q = SA_layer8_weight_Q;
    SA_layer9_weight_K = SA_layer8_weight_K;
    SA_layer9_weight_V = SA_layer8_weight_V;

    SA_layer9_bias_Q = SA_layer8_bias_Q;
    SA_layer9_bias_K = SA_layer8_bias_K;
    SA_layer9_bias_V = SA_layer8_bias_V;
    SA_layer9_bias_QKT = SA_layer8_bias_QKT;

    SA_layer9_output_Q_gold = SA_layer8_output_Q_gold;
    SA_layer9_output_K_gold = SA_layer8_output_K_gold;
    SA_layer9_output_V_gold = SA_layer8_output_V_gold;
    SA_layer9_output_QKT_gold = SA_layer8_output_QKT_gold;

    SOFTMAX_layer9_input = SOFTMAX_layer8_input;
    SOFTMAX_layer9_output_gold = SOFTMAX_layer8_output_gold;

    Pre_Norm_layer9_input_1 = Pre_Norm_layer8_input_1;
    Pre_Norm_layer9_input_2 = Pre_Norm_layer8_input_2;
    Pre_Norm_layer9_output_gold = Pre_Norm_layer8_output_gold;

    FFN_layer9_input_1 = FFN_layer8_input_1;
    FFN_layer9_weight_1 = FFN_layer8_weight_1;
    FFN_layer9_bias_1 = FFN_layer8_bias_1;
    FFN_layer9_output_1_gold = FFN_layer8_output_1_gold;

    FFN_layer9_input_2 = FFN_layer8_input_2;
    FFN_layer9_weight_2 = FFN_layer8_weight_2;
    FFN_layer9_bias_2 = FFN_layer8_bias_2;
    FFN_layer9_output_2_gold = FFN_layer8_output_2_gold;

    Post_Norm_layer9_input_1 = Post_Norm_layer8_input_1;
    Post_Norm_layer9_input_2 = Post_Norm_layer8_input_2;
    Post_Norm_layer9_output_gold = Post_Norm_layer8_output_gold;

    SA_layer10_input_token = SA_layer9_input_token;

    SA_layer10_weight_Q = SA_layer9_weight_Q;
    SA_layer10_weight_K = SA_layer9_weight_K;
    SA_layer10_weight_V = SA_layer9_weight_V;

    SA_layer10_bias_Q = SA_layer9_bias_Q;
    SA_layer10_bias_K = SA_layer9_bias_K;
    SA_layer10_bias_V = SA_layer9_bias_V;
    SA_layer10_bias_QKT = SA_layer9_bias_QKT;

    SA_layer10_output_Q_gold = SA_layer9_output_Q_gold;
    SA_layer10_output_K_gold = SA_layer9_output_K_gold;
    SA_layer10_output_V_gold = SA_layer9_output_V_gold;
    SA_layer10_output_QKT_gold = SA_layer9_output_QKT_gold;

    SOFTMAX_layer10_input = SOFTMAX_layer9_input;
    SOFTMAX_layer10_output_gold = SOFTMAX_layer9_output_gold;

    Pre_Norm_layer10_input_1 = Pre_Norm_layer9_input_1;
    Pre_Norm_layer10_input_2 = Pre_Norm_layer9_input_2;
    Pre_Norm_layer10_output_gold = Pre_Norm_layer9_output_gold;

    FFN_layer10_input_1 = FFN_layer9_input_1;
    FFN_layer10_weight_1 = FFN_layer9_weight_1;
    FFN_layer10_bias_1 = FFN_layer9_bias_1;
    FFN_layer10_output_1_gold = FFN_layer9_output_1_gold;

    FFN_layer10_input_2 = FFN_layer9_input_2;
    FFN_layer10_weight_2 = FFN_layer9_weight_2;
    FFN_layer10_bias_2 = FFN_layer9_bias_2;
    FFN_layer10_output_2_gold = FFN_layer9_output_2_gold;

    Post_Norm_layer10_input_1 = Post_Norm_layer9_input_1;
    Post_Norm_layer10_input_2 = Post_Norm_layer9_input_2;
    Post_Norm_layer10_output_gold = Post_Norm_layer9_output_gold;

    SA_layer11_input_token = SA_layer10_input_token;

    SA_layer11_weight_Q = SA_layer10_weight_Q;
    SA_layer11_weight_K = SA_layer10_weight_K;
    SA_layer11_weight_V = SA_layer10_weight_V;

    SA_layer11_bias_Q = SA_layer10_bias_Q;
    SA_layer11_bias_K = SA_layer10_bias_K;
    SA_layer11_bias_V = SA_layer10_bias_V;
    SA_layer11_bias_QKT = SA_layer10_bias_QKT;

    SA_layer11_output_Q_gold = SA_layer10_output_Q_gold;
    SA_layer11_output_K_gold = SA_layer10_output_K_gold;
    SA_layer11_output_V_gold = SA_layer10_output_V_gold;
    SA_layer11_output_QKT_gold = SA_layer10_output_QKT_gold;

    SOFTMAX_layer11_input = SOFTMAX_layer10_input;
    SOFTMAX_layer11_output_gold = SOFTMAX_layer10_output_gold;

    Pre_Norm_layer11_input_1 = Pre_Norm_layer10_input_1;
    Pre_Norm_layer11_input_2 = Pre_Norm_layer10_input_2;
    Pre_Norm_layer11_output_gold = Pre_Norm_layer10_output_gold;

    FFN_layer11_input_1 = FFN_layer10_input_1;
    FFN_layer11_weight_1 = FFN_layer10_weight_1;
    FFN_layer11_bias_1 = FFN_layer10_bias_1;
    FFN_layer11_output_1_gold = FFN_layer10_output_1_gold;

    FFN_layer11_input_2 = FFN_layer10_input_2;
    FFN_layer11_weight_2 = FFN_layer10_weight_2;
    FFN_layer11_bias_2 = FFN_layer10_bias_2;
    FFN_layer11_output_2_gold = FFN_layer10_output_2_gold;

    Post_Norm_layer11_input_1 = Post_Norm_layer10_input_1;
    Post_Norm_layer11_input_2 = Post_Norm_layer10_input_2;
    Post_Norm_layer11_output_gold = Post_Norm_layer10_output_gold;

    SA_layer12_input_token = SA_layer11_input_token;

    SA_layer12_weight_Q = SA_layer11_weight_Q;
    SA_layer12_weight_K = SA_layer11_weight_K;
    SA_layer12_weight_V = SA_layer11_weight_V;

    SA_layer12_bias_Q = SA_layer11_bias_Q;
    SA_layer12_bias_K = SA_layer11_bias_K;
    SA_layer12_bias_V = SA_layer11_bias_V;
    SA_layer12_bias_QKT = SA_layer11_bias_QKT;

    SA_layer12_output_Q_gold = SA_layer11_output_Q_gold;
    SA_layer12_output_K_gold = SA_layer11_output_K_gold;
    SA_layer12_output_V_gold = SA_layer11_output_V_gold;
    SA_layer12_output_QKT_gold = SA_layer11_output_QKT_gold;

    SOFTMAX_layer12_input = SOFTMAX_layer11_input;
    SOFTMAX_layer12_output_gold = SOFTMAX_layer11_output_gold;

    Pre_Norm_layer12_input_1 = Pre_Norm_layer11_input_1;
    Pre_Norm_layer12_input_2 = Pre_Norm_layer11_input_2;
    Pre_Norm_layer12_output_gold = Pre_Norm_layer11_output_gold;

    FFN_layer12_input_1 = FFN_layer11_input_1;
    FFN_layer12_weight_1 = FFN_layer11_weight_1;
    FFN_layer12_bias_1 = FFN_layer11_bias_1;
    FFN_layer12_output_1_gold = FFN_layer11_output_1_gold;

    FFN_layer12_input_2 = FFN_layer11_input_2;
    FFN_layer12_weight_2 = FFN_layer11_weight_2;
    FFN_layer12_bias_2 = FFN_layer11_bias_2;
    FFN_layer12_output_2_gold = FFN_layer11_output_2_gold;

    Post_Norm_layer12_input_1 = Post_Norm_layer11_input_1;
    Post_Norm_layer12_input_2 = Post_Norm_layer11_input_2;
    Post_Norm_layer12_output_gold = Post_Norm_layer11_output_gold;

	xil_printf("---------------- SD Card Reading Done ----------------\r\n");

	return XST_SUCCESS;
}