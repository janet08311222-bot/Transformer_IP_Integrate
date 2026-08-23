# Transformer_IP_Integrate

學長的 transformer（`FPGAcode_Integrate`）為底，把其中的 block 換成我們自己做的版本。

| Block | 來源 | 狀態 |
|---|---|---|
| Self-Attention (`dla512_top`) | 我們的 2-row parallel 版 | 已換入 |
| FFN (`FFN_top`) | 我們的 i-GELU + 16-column 版 | 已換入 |
| Softmax (`softmax_top`) | 學長的 | 待換 |
| Add&Norm (`addnormtop`) | 學長的 | 沿用 |

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
tb/Transformer_tb.sv     Transformer 層 testbench（FFN1 / FFN2 / SOFTMAX 三種模式）
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

Behavioural simulation：

```bash
vivado -mode batch -source vivado/run_sim.tcl
```

要換跑 FFN1 / FFN2，改 `tb/Transformer_tb.sv` 開頭的 `` `define FFN1 ``。
FFN1 的 gold 是 `pat/FFN1_igelu_out.dat`（i-GELU 開啟），不是 `FFN1_out_original.dat`。
測資路徑由 tb 開頭的 `` `PAT_DIR `` 決定，repo 搬家時改那一行就好。

### 純命令列快速檢查

不想開專案時，可以用 `sim/` 的 filelist 做 elaboration，抓接腳/寬度錯誤：

```bash
xvlog -f sim/transformer.f && xelab Transformer_top
```

`sim/stubs_*.v` 是 IP 的替身，**只能用來 elaborate**。它們是照 RTL 寫的，所以抓不到 RTL 與真實 IP 之間的差異（實際上就漏抓過兩個，見 git log），而且 latency 跟真 IP 不同，不能拿來跑 functional sim。真的要跑模擬請走 Vivado 專案。

## FFN 是 16-column，config 跟 8-way 不一樣

換 FFN 版本時 testbench 的 config 也要跟著換，否則結果一定不對：

- `cfg_ker_tile_size_sub1` = 31（512ch / 16 = 32 subtiles/tile）
- output reshape 的 `cfg_ot_tgpfnsub1` / `tcolfnsub1` / `tchafnsub1` / `sft_gp` / `sft_colpra` 全部重算
- `CFG_15` 多一個欄位 `cfg_ot_sft_col`（8-way 沒有）
- `cfg_z3[0]` 就是 `cfg_gelu_en`：FFN1 開 i-GELU，FFN2 關
- kernel 餵資料的迴圈是 16 欄不是 8 欄
