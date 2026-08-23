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

// u8  if_token[IF_TOKEN] __attribute__ ((aligned (64)));
// u8  W_q[W_QKV] __attribute__ ((aligned (64)));
// u8  W_k[W_QKV] __attribute__ ((aligned (64)));
// u8  W_v[W_QKV] __attribute__ ((aligned (64)));
// u64 B_q[B_QKV];
// u64 B_k[B_QKV];
// u64 B_v[B_QKV];
// u64 B_qkt[B_QKV];
// u8  of_q[OF_QKV] __attribute__ ((aligned (64)));
// u8  of_k[OF_QKV] __attribute__ ((aligned (64)));
// u8  of_v[OF_QKV] __attribute__ ((aligned (64)));
// u8  of_qkt[OF_QKT] __attribute__ ((aligned (64)));
// u8  of_q_gold[OF_QKV] __attribute__ ((aligned (64)));
// u8  of_k_gold[OF_QKV] __attribute__ ((aligned (64)));
// u8  of_v_gold[OF_QKV] __attribute__ ((aligned (64)));
// u8  of_qkt_gold[OF_QKT] __attribute__ ((aligned (64)));

u8  if_token[IF_TOKEN];
u8  W_q[W_QKV];
u8  W_k[W_QKV];
u8  W_v[W_QKV];
u64 B_q[B_QKV];
u64 B_k[B_QKV];
u64 B_v[B_QKV];
u64 B_qkt[B_QKV];
u8  of_q[OF_QKV];
u8  of_k[OF_QKV];
u8  of_v[OF_QKV];
u8  of_qkt[OF_QKT];
u8  of_q_gold[OF_QKV];
u8  of_k_gold[OF_QKV];
u8  of_v_gold[OF_QKV];
u8  of_qkt_gold[OF_QKT];

// #if defined(__GNUC__)
// __attribute__((aligned(64)))
// #endif
u64 SOFTMAX_input_1[416];

// #if defined(__GNUC__)
// __attribute__((aligned(64)))
// #endif
u64 SOFTMAX_output_1[3328];

// #if defined(__GNUC__)
// __attribute__((aligned(64)))
// #endif
u64 SOFTMAX_output_1_gold[3328];

u64 Input_Q[INPUT_TOKEN_SIZE];
u64 Weight_Q[WEIGHT_Q_SIZE];
u64 Bias_Q[BIAS_Q_SIZE];
u64 output_Q[OUTPUT_Q_SIZE];
u64 output_Q_gold[OUTPUT_Q_SIZE];

extern u64 SOFTMAX_input_1[416];
extern u64 SOFTMAX_output_1_gold[3328];
extern u64 SOFTMAX_output_1[3328];

u64 NORM_input_1[NORM_IN_1];
u64 NORM_input_2[NORM_IN_2];
u64 NORM_output[NORM_OUT];
u64 NORM_output_gold[NORM_OUT];

u64 FFN_input_1[FFN_IN_1];
u64 FFN_weight_1[FFN_W_1];
u64 FFN_bias_1[FFN_B_1];
u64 FFN_output_1[FFN_OUT_1];
u64 FFN_output_1_gold[FFN_OUT_1];

u64 FFN_input_2[FFN_IN_2];
u64 FFN_weight_2[FFN_W_2];
u64 FFN_bias_2[FFN_B_2];
u64 FFN_output_2[FFN_OUT_2];
u64 FFN_output_2_gold[FFN_OUT_2];
