/*
 * cs_ip.h
 *
 *      Author: cs
 */
#include "v3_data.h"
#include "xil_types.h"
#ifndef SRC_CS_IP_H_
#define SRC_CS_IP_H_

void K_generation(u64 *input, u64 *weight, u64 *bias, u64 *output);
void FFN_first_layer(u64 *input, u64 *weight, u64 *bias, u64 *output);
void FFN_second_layer(u64 *input, u64 *weight, u64 *bias, u64 *output);
void ibert_FFN_first_layer(u64 *input, u64 *weight, u64 *bias, u64 *output);
void ibert_FFN_second_layer(u64 *input, u64 *weight, u64 *bias, u64 *output);
// void softmax(const u64 *input, u64 *output);
void softmax(u64 *input, u64 *output);
void addnorm_layer(u64 *input, u64  *input1 , u64 *output);
void COMP_ARRAY_DATA(u64 *array01_base, int comp_length, u64 *array02_base);
void SA_q_gen( int cov_layer_number , u64* bias, u8* weights , u8*input_map , u8*output_map  );
void SA_k_gen( int cov_layer_number , u64* bias, u8* weights , u8*input_map , u8*output_map  );
void SA_v_gen( int cov_layer_number , u64* bias, u8* weights , u8*input_map , u8*output_map  );
void SA_qkt_gen( int cov_layer_number , u64* bias, u8* weights , u8*input_map , u8*output_map  );
void SA_out( int cov_layer_number , u64* bias, u8* weights , u8*input_map , u8*output_map  );
void SA_SV( int cov_layer_number , u64* bias, u8* weights , u8*input_map , u8*output_map  );

int v3_data_init();

#endif /* SRC_CS_IP_H_ */
