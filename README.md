# Transformer_IP_Integrate

學長的 transformer（`FPGAcode_Integrate`）為底，把其中的 block 換成我們自己做的版本。

| Block | 來源 | 狀態 |
|---|---|---|
| Self-Attention (`dla512_top`) | 我們的 2-row parallel 版 | 已換入，**模擬 PASS 4096/4096 bit-exact** |
| FFN (`FFN_top`) | 我們的 i-GELU + 16-column 版 | 已換入，**FFN1 模擬 PASS 2048/2048 bit-exact** |
| Softmax (`softmax_top`) | 我們的 LUT 版 | 已換入，**模擬 PASS 3328/3328 bit-exact** |
| Add&Norm (`addnormtop`) | 學長的 | 沿用，synthesis 乾淨 |

## 驗證狀態

整份 `Transformer_top` 在 `xc7z020clg484-1` 上 synthesis **0 error / 0 critical warning**（面積見下）。
Behavioural simulation 用**真的 IP**（不是 `sim/stubs_*.v`）：

| 模式 | 結果 |
|---|---|
| `` `define FFN1 `` | PASS，2048/2048 bit-exact，0 個未驅動，136,279 cycles |
| `` `define SOFTMAX `` | PASS，52 組 × 64 = 3328/3328 bit-exact，11,260 cycles |
| `fsm_check_tb` (`tb/new_tb_512MAC.sv`) | PASS，4096/4096 bit-exact，0 個未驅動，173,886 cycles |

softmax 那個 PASS 順帶驗證了 `src/common_module/DW_mult_pipe_fpga.v`：gold 是作者用真的
DesignWare `DW_mult_pipe` 產生的，3328 筆全對代表這個 FPGA 替代品的 latency 與
stall/signed 語意正確。

## 目錄

```
src/
  Transformer_top.v      頂層：AXI-Stream fifo + 四個 block 的 mux
  Transformer_FSM.v      依 head instruction 決定這次跑哪個 block
  SA_module/             module 用原名（ifsram_r / pe_top / ot_top …）
  FFN_module/            module 一律 FFN_ 前綴（FFN_ifsram_r / FFN_pe_top …）
  SOFTMAX_module/
  Add_Norm_module/
  common_module/         SA 與 FFN 共用的 leaf，只有一份
tb/Transformer_tb.sv     FFN1 / FFN2 / SOFTMAX 的 testbench
tb/new_tb_512MAC.sv      Self-Attention 的 testbench（top = fsm_check_tb）
pat/                     測資與 gold pattern
vivado/                  專案產生 / synthesis / simulation 腳本
sim/                     純命令列 elaboration 用的 filelist 與 IP stub
```

## 兩條命名規則（改東西前務必看）

**1. FFN 的 module 全部要有 `FFN_` 前綴。** SA 和 FFN 是同一份 DLA 架構長出來的，`ifsram_r`、`get_ins`、`schedule_ctrl`、`pe_top`、`ot_top`… 兩邊名字完全一樣。SA 保留原名，FFN 加前綴。共用的 leaf（`count_yi_v3/4/5`、`yolo_rst_if`、`INPUT/OUTPUT_STREAM_if`）放 `src/common_module`，兩邊共用同一份。

**2. 記憶體也會撞名，而且幾何不同。**

| | SA | FFN |
|---|---|---|
| IF | `BRAM_IF` 1024×64 true dual-port ×16 | `FFN_BRAM_IF` 512×64 single-port ×1 |
| KER | `BRAM_KER` 4096×64 single-port ×8 | `FFN_BRAM_KER` 512×64 simple dual-port ×16 |
| BIAS | `BRAM_BIAS` 512×32 ×1 | `FFN_BRAM_BIAS` 512×32 ×1 |
| OT | `BRAM_OT` 4096×64 ×4 | `FFN_BRAM_OT` 512×64 ×1 |

ASIC path 同理：SA 用 `IF_SRAM`/`KER_SRAM`/`BIAS_SRAM`/`OT_SRAM`，FFN 用 `FFN_IF_SRAM`/…。

## Block 接腳約定

每個 block top **不接 AXI-Stream**，只接 fifo 級訊號；`INPUT_STREAM_if` / `OUTPUT_STREAM_if` 各一份在 `Transformer_top`。

- 進來：`isif_data_dout` / `isif_last_dout` / `isif_empty_n` / `isif_strb_dout` / `isif_user_dout` → 回 `isif_read`
- 出去：`osif_full_n` 進來，`osif_write` / `osif_data_din`（FFN 叫 `ot2fifo_*`）/ `osif_last_din` 出去
- 另外要輸出一根 done 給 `Transformer_FSM`：FFN 是 `FFN_done`，SA 是 `rdwd_done`（接到 `SA_done`）
- `M_AXIS_S2MM_TREADY` 仍要當 input 傳進 block，給輸出模組做 back-pressure

## 跑法

建專案（含產生全部 11 顆 IP）：

```bash
vivado -mode batch -source vivado/create_project.tcl
```

Synthesis：

```bash
vivado -mode batch -source vivado/run_synth.tcl
```

Behavioural simulation（**兩步**，原因見下）：

```bash
vivado -mode batch -source vivado/gen_sim_scripts.tcl
```

```bash
bash vivado/run_sim.sh
```

要換跑 FFN1 / FFN2 / SOFTMAX，改 `tb/Transformer_tb.sv` 開頭的 `` `define FFN1 ``（三個只留一個沒被註解）。

跑 Self-Attention 要指定 testbench：

```bash
vivado -mode batch -source vivado/gen_sim_scripts.tcl -tclargs fsm_check_tb
```

```bash
bash vivado/run_sim.sh fsm_check_tb
```

FFN1 的 gold 是 `pat/FFN1_igelu_out.dat`（i-GELU 開啟），不是 `FFN1_out_original.dat`。
測資路徑由 tb 開頭的 `` `PAT_DIR `` 決定，repo 搬家時改那一行就好。

### 為什麼模擬要分兩步

`launch_simulation` 會 spawn `compile.bat` 當子程序，而這台機器上只要 Vivado 自己的 stdout 是 pipe（也就是任何從腳本驅動的情況），這個 spawn 就會失敗：

```
ERROR: [Common 17-180] Spawn failed: Broken pipe
```

`-log`、`Out-Null`、`Start-Process -RedirectStandardOutput` 都擋不掉。所以改成先讓 Vivado 產出 xsim 腳本（`-scripts_only`），再自己跑 `xvlog` / `xvhdl` / `xelab` / `xsim`。做的事完全一樣。從 GUI 開專案跑則沒有這個問題。

`run_sim.sh` 裡 **`xvhdl` 那步不能省** —— `mult_gen` 和 `cordic` 的模擬模型是 VHDL 不是 Verilog，跳過的話 `MULT_2/3_STAGE_*` 和 `DW_sqrt` 在 elaborate 會找不到。

### 純命令列快速檢查

不想開專案時，可以用 `sim/` 的 filelist 做 elaboration，抓接腳/寬度錯誤：

```bash
xvlog -f sim/transformer.f && xelab Transformer_top
```

`sim/stubs_*.v` 是 IP 的替身，**只能用來 elaborate**。它們是照 RTL 寫的，所以抓不到 RTL 與真實 IP 之間的差異（實際上就漏抓過兩個，見 git log），而且 latency 跟真 IP 不同，不能拿來跑 functional sim。真的要跑模擬請走 Vivado 專案。

## 面積：塞不進 xc7z020（已知，非 blocker）

整合後在 `xc7z020clg484-1` 上 synthesis **0 error**，但放不下：

| 資源 | 用量 | 裝置 | 佔比 |
|---|---|---|---|
| Slice LUT | 80,838 | 53,200 | **152%** |
| Block RAM | 141 | 140 | **101%** |
| Slice Register | 58,575 | 106,400 | 55% |
| DSP | 86 | 220 | 39% |

各 block 的 LUT：SA 32,655 / FFN 19,134 / Add&Norm 16,924 / Softmax 5,609。
沒被動過的 Add&Norm + Softmax 就佔了裝置 42%。

**這份不上板，FPGA 只是功能驗證用，真正目標是 ADFP**，所以不打算為此縮減設計。
真要上板才需要換更大的 part 或砍規模。另外專案目前沒有 XDC，timing 是 unconstrained。

## FFN 是 16-column，config 跟 8-way 不一樣

換 FFN 版本時 testbench 的 config 也要跟著換，否則結果一定不對：

- `cfg_ker_tile_size_sub1` = 31（512ch / 16 = 32 subtiles/tile）
- output reshape 的 `cfg_ot_tgpfnsub1` / `tcolfnsub1` / `tchafnsub1` / `sft_gp` / `sft_colpra` 全部重算
- `CFG_15` 多一個欄位 `cfg_ot_sft_col`（8-way 沒有）
- `cfg_z3[0]` 就是 `cfg_gelu_en`：FFN1 開 i-GELU，FFN2 關
- kernel 餵資料的迴圈是 16 欄不是 8 欄
