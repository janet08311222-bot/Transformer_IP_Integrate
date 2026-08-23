/*
 * v3_data.h
 *
 *  Created on: 2019
 *      Author: cs
 */
#include <stdint.h>
#include <stddef.h>

#include "xil_types.h"

typedef uint64_t u64;
typedef uint8_t u8;

//int READ_BIAS(int bias_size, char **file_name, u64 *out);
int READ_INT64(int input_size, const char *file_name, u64 *out);

//int READ_INT64(int input_size, char* file_name, u64* outt);
//int READ_BIAS(int bias_size, char* file_name, u64* out);

int v3_data_init();

#define W_QKV 262144
#define B_QKV 512
#define IF_TOKEN 32768
#define OF_QKV 32768
#define OF_QKT 4096

#define INPUT_TOKEN_SIZE 64*64
#define WEIGHT_Q_SIZE    64*512
#define BIAS_Q_SIZE      512
#define OUTPUT_Q_SIZE    64*64

#define NORM_IN_1 64
#define NORM_IN_2 64
#define NORM_OUT  512

#define FFN_IN_1  64*64
#define FFN_W_1   64*2048
#define FFN_B_1   2048
#define FFN_OUT_1 64*256

#define FFN_IN_2  64*256
#define FFN_W_2   256*512
#define FFN_B_2   512
#define FFN_OUT_2 64*64

// layer 1
u8  SA_layer1_input_token[IF_TOKEN];
u8  SA_layer1_weight_Q[W_QKV];
u8  SA_layer1_weight_K[W_QKV];
u8  SA_layer1_weight_V[W_QKV];
u64 SA_layer1_bias_Q[B_QKV];
u64 SA_layer1_bias_K[B_QKV];
u64 SA_layer1_bias_V[B_QKV];
u64 SA_layer1_bias_QKT[B_QKV];
u8  SA_layer1_output_Q[OF_QKV];
u8  SA_layer1_output_K[OF_QKV];
u8  SA_layer1_output_V[OF_QKV];
u8  SA_layer1_output_QKT[OF_QKT];
u8  SA_layer1_output_Q_gold[OF_QKV];
u8  SA_layer1_output_K_gold[OF_QKV];
u8  SA_layer1_output_V_gold[OF_QKV];
u8  SA_layer1_output_QKT_gold[OF_QKT];

u64 SOFTMAX_layer1_input[416];
u64 SOFTMAX_layer1_output[3328];
u64 SOFTMAX_layer1_output_gold[3328];

u64 Pre_Norm_layer1_input_1[NORM_IN_1];
u64 Pre_Norm_layer1_input_2[NORM_IN_2];
u64 Pre_Norm_layer1_output[NORM_OUT];
u64 Pre_Norm_layer1_output_gold[NORM_OUT];

u64 FFN_layer1_input_1[FFN_IN_1];
u64 FFN_layer1_weight_1[FFN_W_1];
u64 FFN_layer1_bias_1[FFN_B_1];
u64 FFN_layer1_output_1[FFN_OUT_1];
u64 FFN_layer1_output_1_gold[FFN_OUT_1];
u64 FFN_layer1_input_2[FFN_IN_2];
u64 FFN_layer1_weight_2[FFN_W_2];
u64 FFN_layer1_bias_2[FFN_B_2];
u64 FFN_layer1_output_2[FFN_OUT_2];
u64 FFN_layer1_output_2_gold[FFN_OUT_2];

u64 Post_Norm_layer1_input_1[NORM_IN_1];
u64 Post_Norm_layer1_input_2[NORM_IN_2];
u64 Post_Norm_layer1_output[NORM_OUT];
u64 Post_Norm_layer1_output_gold[NORM_OUT];

// layer 2
u8  *SA_layer2_input_token;
u8  *SA_layer2_weight_Q;
u8  *SA_layer2_weight_K;
u8  *SA_layer2_weight_V;
u64 *SA_layer2_bias_Q;
u64 *SA_layer2_bias_K;
u64 *SA_layer2_bias_V;
u64 *SA_layer2_bias_QKT;
u8   SA_layer2_output_Q[OF_QKV];
u8   SA_layer2_output_K[OF_QKV];
u8   SA_layer2_output_V[OF_QKV];
u8   SA_layer2_output_QKT[OF_QKT];
u8  *SA_layer2_output_Q_gold;
u8  *SA_layer2_output_K_gold;
u8  *SA_layer2_output_V_gold;
u8  *SA_layer2_output_QKT_gold;

u64 *SOFTMAX_layer2_input;
u64  SOFTMAX_layer2_output[3328];
u64 *SOFTMAX_layer2_output_gold;

u64 *Pre_Norm_layer2_input_1;
u64 *Pre_Norm_layer2_input_2;
u64  Pre_Norm_layer2_output[NORM_OUT];
u64 *Pre_Norm_layer2_output_gold;

u64 *FFN_layer2_input_1;
u64 *FFN_layer2_weight_1;
u64 *FFN_layer2_bias_1;
u64  FFN_layer2_output_1[FFN_OUT_1];
u64 *FFN_layer2_output_1_gold;
u64 *FFN_layer2_input_2;
u64 *FFN_layer2_weight_2;
u64 *FFN_layer2_bias_2;
u64  FFN_layer2_output_2[FFN_OUT_2];
u64 *FFN_layer2_output_2_gold;
    
u64 *Post_Norm_layer2_input_1;
u64 *Post_Norm_layer2_input_2;
u64  Post_Norm_layer2_output[NORM_OUT];
u64 *Post_Norm_layer2_output_gold;

// layer 3
u8  *SA_layer3_input_token;
u8  *SA_layer3_weight_Q;
u8  *SA_layer3_weight_K;
u8  *SA_layer3_weight_V;
u64 *SA_layer3_bias_Q;
u64 *SA_layer3_bias_K;
u64 *SA_layer3_bias_V;
u64 *SA_layer3_bias_QKT;
u8   SA_layer3_output_Q[OF_QKV];
u8   SA_layer3_output_K[OF_QKV];
u8   SA_layer3_output_V[OF_QKV];
u8   SA_layer3_output_QKT[OF_QKT];
u8  *SA_layer3_output_Q_gold;
u8  *SA_layer3_output_K_gold;
u8  *SA_layer3_output_V_gold;
u8  *SA_layer3_output_QKT_gold;

u64 *SOFTMAX_layer3_input;
u64  SOFTMAX_layer3_output[3328];
u64 *SOFTMAX_layer3_output_gold;

u64 *Pre_Norm_layer3_input_1;
u64 *Pre_Norm_layer3_input_2;
u64  Pre_Norm_layer3_output[NORM_OUT];
u64 *Pre_Norm_layer3_output_gold;

u64 *FFN_layer3_input_1;
u64 *FFN_layer3_weight_1;
u64 *FFN_layer3_bias_1;
u64  FFN_layer3_output_1[FFN_OUT_1];
u64 *FFN_layer3_output_1_gold;
u64 *FFN_layer3_input_2;
u64 *FFN_layer3_weight_2;
u64 *FFN_layer3_bias_2;
u64  FFN_layer3_output_2[FFN_OUT_2];
u64 *FFN_layer3_output_2_gold;
    
u64 *Post_Norm_layer3_input_1;
u64 *Post_Norm_layer3_input_2;
u64  Post_Norm_layer3_output[NORM_OUT];
u64 *Post_Norm_layer3_output_gold;

// layer 4
u8  *SA_layer4_input_token;
u8  *SA_layer4_weight_Q;
u8  *SA_layer4_weight_K;
u8  *SA_layer4_weight_V;
u64 *SA_layer4_bias_Q;
u64 *SA_layer4_bias_K;
u64 *SA_layer4_bias_V;
u64 *SA_layer4_bias_QKT;
u8   SA_layer4_output_Q[OF_QKV];
u8   SA_layer4_output_K[OF_QKV];
u8   SA_layer4_output_V[OF_QKV];
u8   SA_layer4_output_QKT[OF_QKT];
u8  *SA_layer4_output_Q_gold;
u8  *SA_layer4_output_K_gold;
u8  *SA_layer4_output_V_gold;
u8  *SA_layer4_output_QKT_gold;

u64 *SOFTMAX_layer4_input;
u64  SOFTMAX_layer4_output[3328];
u64 *SOFTMAX_layer4_output_gold;

u64 *Pre_Norm_layer4_input_1;
u64 *Pre_Norm_layer4_input_2;
u64  Pre_Norm_layer4_output[NORM_OUT];
u64 *Pre_Norm_layer4_output_gold;

u64 *FFN_layer4_input_1;
u64 *FFN_layer4_weight_1;
u64 *FFN_layer4_bias_1;
u64  FFN_layer4_output_1[FFN_OUT_1];
u64 *FFN_layer4_output_1_gold;
u64 *FFN_layer4_input_2;
u64 *FFN_layer4_weight_2;
u64 *FFN_layer4_bias_2;
u64  FFN_layer4_output_2[FFN_OUT_2];
u64 *FFN_layer4_output_2_gold;
    
u64 *Post_Norm_layer4_input_1;
u64 *Post_Norm_layer4_input_2;
u64  Post_Norm_layer4_output[NORM_OUT];
u64 *Post_Norm_layer4_output_gold;

// layer 5
u8  *SA_layer5_input_token;
u8  *SA_layer5_weight_Q;
u8  *SA_layer5_weight_K;
u8  *SA_layer5_weight_V;
u64 *SA_layer5_bias_Q;
u64 *SA_layer5_bias_K;
u64 *SA_layer5_bias_V;
u64 *SA_layer5_bias_QKT;
u8   SA_layer5_output_Q[OF_QKV];
u8   SA_layer5_output_K[OF_QKV];
u8   SA_layer5_output_V[OF_QKV];
u8   SA_layer5_output_QKT[OF_QKT];
u8  *SA_layer5_output_Q_gold;
u8  *SA_layer5_output_K_gold;
u8  *SA_layer5_output_V_gold;
u8  *SA_layer5_output_QKT_gold;

u64 *SOFTMAX_layer5_input;
u64  SOFTMAX_layer5_output[3328];
u64 *SOFTMAX_layer5_output_gold;

u64 *Pre_Norm_layer5_input_1;
u64 *Pre_Norm_layer5_input_2;
u64  Pre_Norm_layer5_output[NORM_OUT];
u64 *Pre_Norm_layer5_output_gold;

u64 *FFN_layer5_input_1;
u64 *FFN_layer5_weight_1;
u64 *FFN_layer5_bias_1;
u64  FFN_layer5_output_1[FFN_OUT_1];
u64 *FFN_layer5_output_1_gold;
u64 *FFN_layer5_input_2;
u64 *FFN_layer5_weight_2;
u64 *FFN_layer5_bias_2;
u64  FFN_layer5_output_2[FFN_OUT_2];
u64 *FFN_layer5_output_2_gold;
    
u64 *Post_Norm_layer5_input_1;
u64 *Post_Norm_layer5_input_2;
u64  Post_Norm_layer5_output[NORM_OUT];
u64 *Post_Norm_layer5_output_gold;

// layer 6
u8  *SA_layer6_input_token;
u8  *SA_layer6_weight_Q;
u8  *SA_layer6_weight_K;
u8  *SA_layer6_weight_V;
u64 *SA_layer6_bias_Q;
u64 *SA_layer6_bias_K;
u64 *SA_layer6_bias_V;
u64 *SA_layer6_bias_QKT;
u8   SA_layer6_output_Q[OF_QKV];
u8   SA_layer6_output_K[OF_QKV];
u8   SA_layer6_output_V[OF_QKV];
u8   SA_layer6_output_QKT[OF_QKT];
u8  *SA_layer6_output_Q_gold;
u8  *SA_layer6_output_K_gold;
u8  *SA_layer6_output_V_gold;
u8  *SA_layer6_output_QKT_gold;

u64 *SOFTMAX_layer6_input;
u64  SOFTMAX_layer6_output[3328];
u64 *SOFTMAX_layer6_output_gold;

u64 *Pre_Norm_layer6_input_1;
u64 *Pre_Norm_layer6_input_2;
u64  Pre_Norm_layer6_output[NORM_OUT];
u64 *Pre_Norm_layer6_output_gold;

u64 *FFN_layer6_input_1;
u64 *FFN_layer6_weight_1;
u64 *FFN_layer6_bias_1;
u64  FFN_layer6_output_1[FFN_OUT_1];
u64 *FFN_layer6_output_1_gold;
u64 *FFN_layer6_input_2;
u64 *FFN_layer6_weight_2;
u64 *FFN_layer6_bias_2;
u64  FFN_layer6_output_2[FFN_OUT_2];
u64 *FFN_layer6_output_2_gold;
    
u64 *Post_Norm_layer6_input_1;
u64 *Post_Norm_layer6_input_2;
u64  Post_Norm_layer6_output[NORM_OUT];
u64 *Post_Norm_layer6_output_gold;

// layer 7
u8  *SA_layer7_input_token;
u8  *SA_layer7_weight_Q;
u8  *SA_layer7_weight_K;
u8  *SA_layer7_weight_V;
u64 *SA_layer7_bias_Q;
u64 *SA_layer7_bias_K;
u64 *SA_layer7_bias_V;
u64 *SA_layer7_bias_QKT;
u8   SA_layer7_output_Q[OF_QKV];
u8   SA_layer7_output_K[OF_QKV];
u8   SA_layer7_output_V[OF_QKV];
u8   SA_layer7_output_QKT[OF_QKT];
u8  *SA_layer7_output_Q_gold;
u8  *SA_layer7_output_K_gold;
u8  *SA_layer7_output_V_gold;
u8  *SA_layer7_output_QKT_gold;

u64 *SOFTMAX_layer7_input;
u64  SOFTMAX_layer7_output[3328];
u64 *SOFTMAX_layer7_output_gold;

u64 *Pre_Norm_layer7_input_1;
u64 *Pre_Norm_layer7_input_2;
u64  Pre_Norm_layer7_output[NORM_OUT];
u64 *Pre_Norm_layer7_output_gold;

u64 *FFN_layer7_input_1;
u64 *FFN_layer7_weight_1;
u64 *FFN_layer7_bias_1;
u64  FFN_layer7_output_1[FFN_OUT_1];
u64 *FFN_layer7_output_1_gold;
u64 *FFN_layer7_input_2;
u64 *FFN_layer7_weight_2;
u64 *FFN_layer7_bias_2;
u64  FFN_layer7_output_2[FFN_OUT_2];
u64 *FFN_layer7_output_2_gold;
    
u64 *Post_Norm_layer7_input_1;
u64 *Post_Norm_layer7_input_2;
u64  Post_Norm_layer7_output[NORM_OUT];
u64 *Post_Norm_layer7_output_gold;

// layer 8
u8  *SA_layer8_input_token;
u8  *SA_layer8_weight_Q;
u8  *SA_layer8_weight_K;
u8  *SA_layer8_weight_V;
u64 *SA_layer8_bias_Q;
u64 *SA_layer8_bias_K;
u64 *SA_layer8_bias_V;
u64 *SA_layer8_bias_QKT;
u8   SA_layer8_output_Q[OF_QKV];
u8   SA_layer8_output_K[OF_QKV];
u8   SA_layer8_output_V[OF_QKV];
u8   SA_layer8_output_QKT[OF_QKT];
u8  *SA_layer8_output_Q_gold;
u8  *SA_layer8_output_K_gold;
u8  *SA_layer8_output_V_gold;
u8  *SA_layer8_output_QKT_gold;

u64 *SOFTMAX_layer8_input;
u64  SOFTMAX_layer8_output[3328];
u64 *SOFTMAX_layer8_output_gold;

u64 *Pre_Norm_layer8_input_1;
u64 *Pre_Norm_layer8_input_2;
u64  Pre_Norm_layer8_output[NORM_OUT];
u64 *Pre_Norm_layer8_output_gold;

u64 *FFN_layer8_input_1;
u64 *FFN_layer8_weight_1;
u64 *FFN_layer8_bias_1;
u64  FFN_layer8_output_1[FFN_OUT_1];
u64 *FFN_layer8_output_1_gold;
u64 *FFN_layer8_input_2;
u64 *FFN_layer8_weight_2;
u64 *FFN_layer8_bias_2;
u64  FFN_layer8_output_2[FFN_OUT_2];
u64 *FFN_layer8_output_2_gold;
    
u64 *Post_Norm_layer8_input_1;
u64 *Post_Norm_layer8_input_2;
u64  Post_Norm_layer8_output[NORM_OUT];
u64 *Post_Norm_layer8_output_gold;

// layer 9
u8  *SA_layer9_input_token;
u8  *SA_layer9_weight_Q;
u8  *SA_layer9_weight_K;
u8  *SA_layer9_weight_V;
u64 *SA_layer9_bias_Q;
u64 *SA_layer9_bias_K;
u64 *SA_layer9_bias_V;
u64 *SA_layer9_bias_QKT;
u8   SA_layer9_output_Q[OF_QKV];
u8   SA_layer9_output_K[OF_QKV];
u8   SA_layer9_output_V[OF_QKV];
u8   SA_layer9_output_QKT[OF_QKT];
u8  *SA_layer9_output_Q_gold;
u8  *SA_layer9_output_K_gold;
u8  *SA_layer9_output_V_gold;
u8  *SA_layer9_output_QKT_gold;

u64 *SOFTMAX_layer9_input;
u64  SOFTMAX_layer9_output[3328];
u64 *SOFTMAX_layer9_output_gold;

u64 *Pre_Norm_layer9_input_1;
u64 *Pre_Norm_layer9_input_2;
u64  Pre_Norm_layer9_output[NORM_OUT];
u64 *Pre_Norm_layer9_output_gold;

u64 *FFN_layer9_input_1;
u64 *FFN_layer9_weight_1;
u64 *FFN_layer9_bias_1;
u64  FFN_layer9_output_1[FFN_OUT_1];
u64 *FFN_layer9_output_1_gold;
u64 *FFN_layer9_input_2;
u64 *FFN_layer9_weight_2;
u64 *FFN_layer9_bias_2;
u64  FFN_layer9_output_2[FFN_OUT_2];
u64 *FFN_layer9_output_2_gold;
    
u64 *Post_Norm_layer9_input_1;
u64 *Post_Norm_layer9_input_2;
u64  Post_Norm_layer9_output[NORM_OUT];
u64 *Post_Norm_layer9_output_gold;

// layer 10
u8  *SA_layer10_input_token;
u8  *SA_layer10_weight_Q;
u8  *SA_layer10_weight_K;
u8  *SA_layer10_weight_V;
u64 *SA_layer10_bias_Q;
u64 *SA_layer10_bias_K;
u64 *SA_layer10_bias_V;
u64 *SA_layer10_bias_QKT;
u8   SA_layer10_output_Q[OF_QKV];
u8   SA_layer10_output_K[OF_QKV];
u8   SA_layer10_output_V[OF_QKV];
u8   SA_layer10_output_QKT[OF_QKT];
u8  *SA_layer10_output_Q_gold;
u8  *SA_layer10_output_K_gold;
u8  *SA_layer10_output_V_gold;
u8  *SA_layer10_output_QKT_gold;

u64 *SOFTMAX_layer10_input;
u64  SOFTMAX_layer10_output[3328];
u64 *SOFTMAX_layer10_output_gold;

u64 *Pre_Norm_layer10_input_1;
u64 *Pre_Norm_layer10_input_2;
u64  Pre_Norm_layer10_output[NORM_OUT];
u64 *Pre_Norm_layer10_output_gold;

u64 *FFN_layer10_input_1;
u64 *FFN_layer10_weight_1;
u64 *FFN_layer10_bias_1;
u64  FFN_layer10_output_1[FFN_OUT_1];
u64 *FFN_layer10_output_1_gold;
u64 *FFN_layer10_input_2;
u64 *FFN_layer10_weight_2;
u64 *FFN_layer10_bias_2;
u64  FFN_layer10_output_2[FFN_OUT_2];
u64 *FFN_layer10_output_2_gold;
    
u64 *Post_Norm_layer10_input_1;
u64 *Post_Norm_layer10_input_2;
u64  Post_Norm_layer10_output[NORM_OUT];
u64 *Post_Norm_layer10_output_gold;

// layer 11
u8  *SA_layer11_input_token;
u8  *SA_layer11_weight_Q;
u8  *SA_layer11_weight_K;
u8  *SA_layer11_weight_V;
u64 *SA_layer11_bias_Q;
u64 *SA_layer11_bias_K;
u64 *SA_layer11_bias_V;
u64 *SA_layer11_bias_QKT;
u8   SA_layer11_output_Q[OF_QKV];
u8   SA_layer11_output_K[OF_QKV];
u8   SA_layer11_output_V[OF_QKV];
u8   SA_layer11_output_QKT[OF_QKT];
u8  *SA_layer11_output_Q_gold;
u8  *SA_layer11_output_K_gold;
u8  *SA_layer11_output_V_gold;
u8  *SA_layer11_output_QKT_gold;

u64 *SOFTMAX_layer11_input;
u64  SOFTMAX_layer11_output[3328];
u64 *SOFTMAX_layer11_output_gold;

u64 *Pre_Norm_layer11_input_1;
u64 *Pre_Norm_layer11_input_2;
u64  Pre_Norm_layer11_output[NORM_OUT];
u64 *Pre_Norm_layer11_output_gold;

u64 *FFN_layer11_input_1;
u64 *FFN_layer11_weight_1;
u64 *FFN_layer11_bias_1;
u64  FFN_layer11_output_1[FFN_OUT_1];
u64 *FFN_layer11_output_1_gold;
u64 *FFN_layer11_input_2;
u64 *FFN_layer11_weight_2;
u64 *FFN_layer11_bias_2;
u64  FFN_layer11_output_2[FFN_OUT_2];
u64 *FFN_layer11_output_2_gold;
    
u64 *Post_Norm_layer11_input_1;
u64 *Post_Norm_layer11_input_2;
u64  Post_Norm_layer11_output[NORM_OUT];
u64 *Post_Norm_layer11_output_gold;

// layer 12
u8  *SA_layer12_input_token;
u8  *SA_layer12_weight_Q;
u8  *SA_layer12_weight_K;
u8  *SA_layer12_weight_V;
u64 *SA_layer12_bias_Q;
u64 *SA_layer12_bias_K;
u64 *SA_layer12_bias_V;
u64 *SA_layer12_bias_QKT;
u8   SA_layer12_output_Q[OF_QKV];
u8   SA_layer12_output_K[OF_QKV];
u8   SA_layer12_output_V[OF_QKV];
u8   SA_layer12_output_QKT[OF_QKT];
u8  *SA_layer12_output_Q_gold;
u8  *SA_layer12_output_K_gold;
u8  *SA_layer12_output_V_gold;
u8  *SA_layer12_output_QKT_gold;

u64 *SOFTMAX_layer12_input;
u64  SOFTMAX_layer12_output[3328];
u64 *SOFTMAX_layer12_output_gold;

u64 *Pre_Norm_layer12_input_1;
u64 *Pre_Norm_layer12_input_2;
u64  Pre_Norm_layer12_output[NORM_OUT];
u64 *Pre_Norm_layer12_output_gold;

u64 *FFN_layer12_input_1;
u64 *FFN_layer12_weight_1;
u64 *FFN_layer12_bias_1;
u64  FFN_layer12_output_1[FFN_OUT_1];
u64 *FFN_layer12_output_1_gold;
u64 *FFN_layer12_input_2;
u64 *FFN_layer12_weight_2;
u64 *FFN_layer12_bias_2;
u64  FFN_layer12_output_2[FFN_OUT_2];
u64 *FFN_layer12_output_2_gold;
    
u64 *Post_Norm_layer12_input_1;
u64 *Post_Norm_layer12_input_2;
u64  Post_Norm_layer12_output[NORM_OUT];
u64 *Post_Norm_layer12_output_gold;
