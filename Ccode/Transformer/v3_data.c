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

    Res = READ_INT8(64*512, &IFm_token, &if_token);
    if(Res){ return XST_FAILURE; }

    Res = READ_INT8(512*512, &Weight_q, &W_q);
    if(Res){ return XST_FAILURE; }
    Res = READ_INT8(512*512, &Weight_k, &W_k);
    if(Res){ return XST_FAILURE; }
    Res = READ_INT8(512*512, &Weight_v, &W_v);
    if(Res){ return XST_FAILURE; }

    Res = READ_BIAS(8*8, &bias,(u64) &B_q);
    if(Res){ return XST_FAILURE; }
    Res = READ_BIAS(8*8, &bias,(u64) &B_k);
    if(Res){ return XST_FAILURE; }
    Res = READ_BIAS(8*8, &bias,(u64) &B_v);
    if(Res){ return XST_FAILURE; }
    Res = READ_BIAS(8*8, &bias,(u64) &B_qkt);
    if(Res){ return XST_FAILURE; }

    Res = READ_INT8(64*512, &gold_q, &of_q_gold);
    if(Res){ return XST_FAILURE; }
    Res = READ_INT8(64*512, &gold_k, &of_k_gold);
    if(Res){ return XST_FAILURE; }
    Res = READ_INT8(64*512, &gold_v, &of_v_gold);
    if(Res){ return XST_FAILURE; }
    Res = READ_INT8(64*64, &gold_qkt, &of_qkt_gold);
    if(Res){ return XST_FAILURE; }

    if (READ_U64_STREAM(SOFTMAX_input_file_1, 416, SOFTMAX_input_1) != XST_SUCCESS)
    return XST_FAILURE;
    if (READ_U64_STREAM(SOFTMAX_output_file_1, 3328, SOFTMAX_output_1_gold) != XST_SUCCESS)
    return XST_FAILURE;

	Res = READ_INT64(64*64, &Q_input_file, &Input_Q);
	if(Res){ return XST_FAILURE; }
    Res = READ_INT64(64*2048, &Q_weight_file, &Weight_Q);
    if(Res){ return XST_FAILURE; }
    Res = READ_INT64(2048, &Q_bias_file, (u64) &Bias_Q);
    if(Res){ return XST_FAILURE; }
	Res = READ_INT64(64*256, &Q_output_file, &output_Q_gold);
    if(Res){ return XST_FAILURE; }

	Res = READ_INT64(64, &NORM_input_file_1, &NORM_input_1);
	if(Res){ return XST_FAILURE; }
	Res = READ_INT64(64, &NORM_input_file_2, &NORM_input_2);
	if(Res){ return XST_FAILURE; }
	Res = READ_INT64(512, &NORM_output_file, &NORM_output_gold);
	if(Res){ return XST_FAILURE; }

	Res = READ_INT64(64*64, &FFN_input_file_1, &FFN_input_1);
	if(Res){ return XST_FAILURE; }
    Res = READ_INT64(64*2048, &FFN_weight_file_1, &FFN_weight_1);
    if(Res){ return XST_FAILURE; }
    Res = READ_INT64(2048, &FFN_bias_file_1, (u64) &FFN_bias_1);
    if(Res){ return XST_FAILURE; }
	Res = READ_INT64(64*256, &FFN_output_file_1, &FFN_output_1_gold);
    if(Res){ return XST_FAILURE; }
	// Res = READ_INT64(8*64, (char*)input_file_1, input_1);
	// if(Res){ return XST_FAILURE; }
    // Res = READ_INT64(64*2048, (char*)weight_file_1, weight_1);
    // if(Res){ return XST_FAILURE; }
    // Res = READ_BIAS(2048, (char*)bias_file_1, bias_1);
    // if(Res){ return XST_FAILURE; }
	// Res = READ_INT64(8*256, (char*)output_file_1, output_1_gold);
    // if(Res){ return XST_FAILURE; }

	Res = READ_INT64(64*256, &FFN_input_file_2, &FFN_input_2);
	if(Res){ return XST_FAILURE; }
	Res = READ_INT64(256*512, &FFN_weight_file_2, &FFN_weight_2);
	if(Res){ return XST_FAILURE; }
	Res = READ_INT64(512, &FFN_bias_file_2, (u64) &FFN_bias_2);
	if(Res){ return XST_FAILURE; }
	Res = READ_INT64(64*64, &FFN_output_file_2, &FFN_output_2_gold);
	if(Res){ return XST_FAILURE; }
	// Res = READ_INT64(2*256, (char*)input_file_2, input_2);
	// if(Res){ return XST_FAILURE; }
	// Res = READ_INT64(256*512, (char*)weight_file_2, weight_2);
	// if(Res){ return XST_FAILURE; }
	// Res = READ_BIAS(512, (char*)bias_file_2, bias_2);
	// if(Res){ return XST_FAILURE; }
	// Res = READ_INT64(2*64, (char*)output_file_2, output_2_gold);
	// if(Res){ return XST_FAILURE; }

	xil_printf("---------------- SD Card Reading Done ----------------\r\n");

	return XST_SUCCESS;
}

