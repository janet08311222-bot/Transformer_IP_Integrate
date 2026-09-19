# Transformer_IP_Integrate

學長的 transformer（`FPGAcode_Integrate`）為底，把其中的 block 換成我們自己做的版本。

| Block | 來源 | 狀態 |
|---|---|---|
| FFN (`FFN_top`) | 我們的 i-GELU + 16-column 版 | 已換入，**兩層都 PASS**（FFN1 2048/2048、FFN2 512/512） |
| Self-Attention (`dla512_top`) | 我們的 2-row parallel 版 | 已換入，**模擬 PASS 4096/4096 bit-exact** |
| Softmax (`softmax_top`) | 我們的 LUT 版 | 已換入，**模擬 PASS 3328/3328 bit-exact** |
| Add&Norm (`addnormtop`) | 學長的 | 沿用，synthesis 乾淨 |

## 驗證狀態

整份 `Transformer_top` 在 `xc7z020clg484-1` 上 synthesis **0 error / 0 critical warning**（面積見下）。
Behavioural simulation 用**真的 IP**（不是 `sim/stubs_*.v`）：

| 模式 | 結果 |
|---|---|
| `` `define FFN1 `` | PASS，2048/2048 bit-exact，0 個未驅動，136,279 cycles |
| `` `define FFN2 `` | PASS，512/512 bit-exact，0 個未驅動，536,008 cycles（kernel 重載 4 次） |
| `` `define SOFTMAX `` | PASS，52 組 × 64 = 3328/3328 bit-exact，11,260 cycles |
| `` `define FFN1 `` + `` `N_PASS 2 `` | PASS，兩趟各 2048/2048 bit-exact，272,538 cycles |
| `fsm_check_tb` (`tb/new_tb_512MAC.sv`) | PASS，4096/4096 bit-exact，0 個未驅動，173,886 cycles |

**Add&Norm 從未被功能驗證** —— 它的測資（`NORM_output_fpga.dat` 等）是板子從 SD 卡讀的,
`Ccode/ibert/v3_data.c` 裡只有檔名沒有資料,這些檔案不在 repo 也不在開發機上。目前只確認:
synthesis 乾淨、reset 極性正確（`addnormtop` 內部是 `if (!reset)` 的 active-low,接 `resetn` 是對的）。
**`NORM_done = out_last` 的時機沒被驗證過** —— 這跟 SA 那個 `rdwd_done` 是完全相同的類別
（算得對但完成訊號時機錯,導致 FSM 卡死）,拿到測資前這個風險是留著的。

**多趟測試**：`tb/Transformer_tb.sv` 的 `` `N_PASS `` 設成 >1 時,會在**不重置 DUT** 的情況下連續送多趟
head 指令與資料,驗證 FSM 每趟都能正確收尾、下一趟不受前一趟殘留影響。這條路徑原本
完全沒被覆蓋（每個模式都只從 reset 跑一趟）,而 SA 那個 bug 正是「算得對但收不了尾」。
兩趟的 cycle 數只差 24（重新接 head 指令的開銷）。

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

## 拿去學校跑 ADFP：要複製哪些檔

DC / APR 的腳本學校機器上已經有（學長給的），這裡只交付**驗證過的設計檔**。整個 repo 複製過去最省事；
若要照原本的 `design/src` 版型放，需要的是這四個目錄：

| 目錄 | 內容 |
|---|---|
| `src/` | 全部 RTL（四個區塊 + top + FSM + 共用 leaf） |
| `adfp/sram/` | 兩份 N16FFC SRAM wrapper（見下方撞名說明） |
| `tb/` | `Transformer_tb.sv`（FFN1/FFN2/Softmax）、`new_tb_512MAC.sv`（SA） |
| `pat/` | 全部測資與 gold |

完整的 RTL 清單就是 `adfp/sim/vcode.f`（路徑相對 repo root）。**建議直接用它**，不要手改學長的 filelist。

### 跟學長原版 filelist 的差異

真正新增的檔（學長那份沒有，漏掉會 elaborate 失敗）：

```
src/FFN_module/compute_engine/FFN_i_gelu.v
src/FFN_module/compute_engine/FFN_quan2uint8_gelu.v
src/SOFTMAX_module/recip_lut.v
src/common_module/DW_mult_pipe_fpga.v
```

搬位置的檔（內容不變，但路徑從 `src/FFN_module/other_module/` 變成 `src/common_module/`）：
`count_yi_v3/v4/v5.v`、`INPUT_STREAM_if.v`、`OUTPUT_STREAM_if.v`、`yolo_rst_if.v`。

### 編譯選項（跟 FFN Phase 4 一樣）

```
+define+ASIC +define+RTL -timescale=1ns/1ps
```

- `ASIC`：四個區塊全部切到 ASIC 分支（N16 SRAM wrapper、DesignWare）
- `RTL`：tb 用 repo 相對的 `pat/` 路徑、CYCLE = 10。**不要再用 `VIVA`**，那是 Vivado 專案用的絕對路徑
- `-timescale`：RTL 是有些檔有 `` `timescale `` 有些沒有的混合體，沒給會被 VCS 擋

另外要一起編進去的外部模型：四顆 N16FFC macro（`TS1N…4096X64`、`TS1N…512X32`、`TS1N…512X64`、`TSDN…512X64`，跟 FFN Phase 4 同一組）
和三個 DesignWare（`DW02_mult_3_stage`、`DW_mult_pipe`、`DW_sqrt`，在 `$SYNOPSYS/dw/sim_ver`）。
`adfp/sim/run_vcs_presim.sh` 就是這整套指令，設好 `SRAM_DIR` 直接跑。

### SRAM wrapper 撞名（ASIC 那半）

兩份 wrapper 定義的 module 名原本**完全相同**（`IF_SRAM` / `KER_SRAM` / `BIAS_SRAM` / `OT_SRAM`）但幾何不同。
FFN 那份已改成 `FFN_IF_SRAM` 等，RTL 也是實例化這些名字。**兩份都要編，不能只用學長或 FFN 單一那份的 `sram.v`**：

- `adfp/sram/sa_sram_wrappers.v` → SA 用的 `*_SRAM`
- `adfp/sram/ffn_sram_wrappers.v` → FFN 用的 `FFN_*_SRAM`

DC 那邊 SRAM 的 `.db` 照 macro 名字列，四顆都要，跟 Phase 4 相同。

### 預期結果

pre-sim 應該跟 FPGA 和本機 stub 版**完全一樣**（不只數值，cycle 數也一樣）：

| tb | 模式 | 預期 |
|---|---|---|
| `Transformer_tb` | FFN1 | PASS 2048/2048（`N_PASS 2` 時 4096/4096，272,538 cycles） |
| `Transformer_tb` | FFN2 | PASS 512/512 |
| `Transformer_tb` | SOFTMAX | PASS 3328/3328 |
| `fsm_check_tb` | — | PASS 4096/4096（VCS 流程約 171,910 cycles） |

**cycle 數會依模擬環境分成兩群，不是 RTL 差異**：Vivado 專案流程（`vivado/run_sim.sh`）
跑出 SA 173,886 / Softmax 11,260；命令列 `-timescale 1ns/1ps` 流程（`adfp/sim/run_asic_sim.sh`、
VCS）跑出 SA 171,910 / Softmax 11,312。同一路徑換旗標就跟著變，ASIC 與 FPGA 在同一組旗標下
逐 cycle 相同。原因是 tb 用 `#0.01` 這種次 cycle 延遲驅動 TREADY，精度不同時落在不同 edge，
SA 那 1,976 的差就是一段 2000-cycle 反壓視窗被吞掉。**判定只看 bit-exact 和未驅動字數**，
cycle 數只在同一種流程內互比才有意義。
Add&Norm 沒有測資，pre-sim 只能確認它 elaborate 得過。
