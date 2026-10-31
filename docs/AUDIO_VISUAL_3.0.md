# 3.0 音频可视化说明

基线：`ANLU_Project/digital photo frame2.0`（XGA 1024×768，2026-10-24 移除 LED/SEG 后的版本）。
参考：`嵌入式大赛FPGA安路赛道一/音频可视化实现说明等2项文件`（demo_v_1_0_0 v0.26/v0.27 底部对称波形，已板测）。

## 1. 改了什么

| 项 | 2.0 | 3.0 |
|---|---|---|
| VISUAL 模式 | OFF / BARS / RADIAL | OFF / BARS / RADIAL / **WAVE** |
| 波形 | 无 | 参考工程底部白色对称波形：80 槽、cos² 包络、圆头柱、蓝色渐变 |
| 高度刻度 | — | **对数刻度**，每格 1.5 dB，−42 dBFS 起 1 格，−1.2 dBFS 满格 28（参考为线性，−7.2 dBFS 饱和，−20 dBFS 只有 6 格） |
| 频谱输入 | 只取左声道 | (L+R)/2，左右声道不同的 SD 音乐也完整显示 |
| 静音 | 静音时频谱仍随音乐跳动 | 静音（MUTE ON）时可视化按无声处理：频谱回落，波形落到一排小圆点 |
| 运算功耗 | 频谱 DFT 在 BARS/RADIAL/OFF 下一直运行 | 只运行当前模式需要的分析；未选中的模块清零并停止 |
| 翻页提示音 | — | 不参与可视化（取混音前的音乐 PCM） |

操作：拨码 MUSIC 页（`dip=0101`），K3 选到 `VISUAL`，K4 依次切换 `OFF → BARS → RADIAL → WAVE → OFF`；K3+K4 恢复 OFF。OSD 显示 `VISUAL: WAVE`。和 BARS/RADIAL 一样，需要 `MUSIC` 打开才显示。

## 2. 结构

```
selected_music_left/right (24 bit, 48 kHz, video_clk)
        │  display_enhance: MUTE → 0
        ├─► (L+R)/2 ─► audio_spectrum (BARS / RADIAL，原 16 段 DFT，未改)
        └─► audio_wave_levels (WAVE)
              每 32 个样本取 max(|L|,|R|) 峰值 → 对数量化 0..28 → 64 槽历史环
              每帧 frame_start 复制最新 40 条到显示 RAM，快升，每帧最多降 3 格
                     │ bar_index → bar_height
              audio_wave_overlay (7 拍流水线，与 spectrum_renderer_pipeline 相同)
                     │
        visual_mode==3 ? wave : spectrum ─► text_layers (OSD) ─► HDMI
```

- 新文件：`user_source/hdl_source/audio_wave.v`（`audio_wave_levels`、`audio_wave_overlay`），已加入 `demo.al`、`timing_verified.al`、`rtl_check.al`。
- 修改：`display_enhance.v`（接入、门控、静音、立体声）、`top_tf_hdmi_audio.v`（多接一根右声道）、`display_controls4.v`（VISUAL 四档循环）、`text_layers.v`（`WAVE` 字样）。
- 显示总延迟仍为 17 个像素时钟，HS/VS/DE 对齐不变。
- 参数：`display_enhance` 的 `AUDIO_WAVE=0` 完全去掉波形（WAVE 档等同 OFF 渲染）；`WAVE_LOG_SCALE=0` 恢复参考工程的线性刻度。

## 3. 几何（与参考 v0.27 完全一致）

坐标沿用 2.0 叠加层的 640×480 映射（`x*5/8`），在 1024×768 输出中放大 1.6 倍：

- 波形带 y=448..479（输出第 717..767 行，屏幕最底部约 51 行），中线在 463/464 之间，上下对称。
- 每 8 px 一个槽，共 80 槽；中间两槽是最新的峰值，向两边依次变旧，左右镜像。
- 包络权重 `round(2+14·cos²(π·e/80))`，半高 `⌊h·w/32⌋+1`（1..15），柱头一行只点亮 2 px，形成圆头；静音时每槽留 2×2 小点。
- 带内非柱像素混入蓝色 `3c82f0`，系数 k = 4..14（25%～88%），由上向下加深。带外像素不变。
- BARS 面板在 y=400..464、RADIAL 在右下圆环，与 WAVE 互斥显示，不会重叠。

## 4. 对数刻度

`level = clamp(4·⌊log2 p⌋ + 次两位尾数 − 31, 0, 28)`，用最高位位置和其后两位查表，无乘法器：

| 峰值 dBFS | −40 | −30 | −20 | −10 | −3 |
|---|---|---|---|---|---|
| 参考线性刻度 | 0 | 2 | 6 | 20 | 28 |
| 3.0 对数刻度 | 2 | 9 | 15 | 22 | 26 |

说话和安静段落可以看到起伏，响的段落不再整排顶满。

## 5. 时序改善

参考实现是两拍、组合路径较长（PCM 绝对值→峰值→量化→写 RAM；高度×权重→比较→混色）。3.0 中：

- PCM 绝对值、峰值比较、量化写入各占一拍；
- 渲染拆成 7 拍：槽位/行列 → 取高度与 3 组 8×4 位混色乘法 → 高度×权重与减加 → 圆头判定 → 选择输出；
- 去掉了参考工程为 TD 保持时间加的 `AL_MAP_LUT1` 手工延迟单元（历史 RAM 地址直接寄存）。

## 6. 验证

| 测试 | 内容 | 结果 |
|---|---|---|
| `test_wave_overlay3.do` | 与未修改的 v0.27 `audio_ring_overlay` 逐像素比较（静音、低、中、满、溢出、交错高度、随机背景、关闭） | 2,163,845 像素一致，延迟 7 拍 |
| `test_wave_levels3.do` | `LOG_SCALE=0` 时与 v0.27 `audio_ring_levels` 逐帧比较 320 帧 12,800 条；对数刻度 0..32768 全部输入单调且误差 <1.5 格；关闭即清零、重开不残留；静音每帧最多降 3 格直至 0 | 通过 |
| `test_wave_display3.do` | `display_enhance` 在 1344×806 XGA 时序下：17 拍对齐、只改波形带、静音落为小点、OFF/音乐关不改画面、重开恢复 | 通过 |
| `test_frame_ui.do` | 增加 WAVE 档、回绕到 OFF、OSD 显示 `WAVE` | 通过 |
| `test_osd_pipeline.do`、`test_render_pipeline.do`、`test_video_alignment.do` | 原有回归 | 见 BUILD_STATUS / README 最新记录 |

两个变异测试（改动圆头列范围、改动下降步长）均被对应测试发现失败，证明测试有效。

参考 RTL 原样复制在 `build/reference_v027/`，仅作为仿真黄金模型。

预览：`python tools/wave_preview.py ../BGM.PCM ../Pictures/output_bmp/1_680x480.bmp --seconds 12.5 --out docs/preview/wave`，生成 `docs/preview/wave_{log,linear}_{640,xga_bottom}.png`。该脚本按 RTL 的位级规则建模，帧快照时刻为近似值。

## 7. 未完成 / 需要上板确认

- 未上板。需要在原板上看：WAVE 档显示、响度变化、静音小点、切换模式、翻页和轮播时是否正常。
- 波形在 1024×768 中按 1.6 倍最近邻放大，柱宽为 6/7 px 交替，属于 2.0 叠加层的既有映射方式。

## 8. 2026-10-28：径向频谱抗锯齿、宋体 OSD

### 径向频谱（RADIAL）

原实现在 640×480 叠加坐标中画圆环，再按 1.6 倍最近邻放大到 XGA，且扇区按 tan=k/6 划分（宽度 9.5°～5.2° 不等）、内外弧与缝隙都是 1 位硬判决，所以边缘呈台阶、参差不齐。现改为：

- **XGA 原生坐标绘制**：`display_enhance` 额外送入与 `fx_x0/fx_y0` 同拍的 XGA 坐标 `xga_x0/xga_y0`；圆心 (884,628)，内半径 45，外半径 `54 + 3h/8`（54～90 px），与原几何的 1.6 倍一致。
- **等角扇区**：48 格 × 7.5°，八分区内 5 条辐条 `s_k = minor·cos(7.5k) − major·sin(7.5k)`（1/256 px 定点，常数乘法）。
- **有向距离抗锯齿**：外弧 `d=(R²−r²)/2R`、内弧同理（比较 `4(R²−r²) ≥ (k−4)R`，k=1..8，无除法）；扇区缝隙取到最近辐条的垂直距离，缝宽 1.5 px。覆盖率 = 三者最小值，1/8 像素精度，按 alpha 与照片混合。
- **平滑径向渐变** `25 8d b8 → 86 e9 f4`，取代原来三圈色阶。
- 仍为 7 拍流水线，显示总延迟 17 拍不变；BARS 几何、颜色逐像素不变。
- 修复 `sine` 查找表两处错误（`7'd50` 误为 56；`7'd74` 误写成重复的 `7'd56`，使索引 74 无值），恢复与 2.0 一致的 DFT 结果。
- 删除未使用的组合参考渲染（`PIPELINED_RENDER=0`）及无用的 panel/peak 半径逻辑。

预览：`docs/preview/radial_before_after.png`（左 3.0，右现版本，RTL 仿真输出）。

### OSD 宋体

- 字库改为 **宋体 24×24**（`simsun.ttc`，hinting 单色光栅化，不再缩放/阈值化），OSD 改在 XGA 原生坐标 1:1 绘制，不再 1.6 倍放大，笔画宽度一致。单元格 24 px，从 (24,18) 开始；面板 x≥12、y≥12。
- 数字与 `+ - % :` 也使用宋体半角字形（居中于 24 px 单元），取消 5×7 方块字。
- 字库 70 字 × 24 行 × 24 位，放在 **BRAM32K**（`EG_LOGIC_BRAM IMPLEMENT="32K"`，初始化文件 `font24_rows.mif`），不占已用到 61/64 的 BRAM9K；ModelSim 用等价数组读 `font24_rows.mem`。
- 修复：拨码 0 页按 K3+K4 改播放速度时，速度提示框原本没有文字，现在显示 `速度: x速`。
- 生成：`python tools/generate_chinese_font.py`（同时写 SD 卡资源 `FONT24.BIN/FONT24.MEM/FONTMAP.TXT/FONTINFO.TXT`，删除旧 `FONT16.*`）。

预览：`docs/preview/osd_xga_page{4,6,7}.png`（RTL 仿真输出）。

### 验证

| 测试 | 内容 |
|---|---|
| `test_render_pipeline.do` + `check_radial.py` | OFF/BARS 与 3.0 渲染器（`build/reference_v30`）逐像素一致；RADIAL 3 帧 XGA，环外不变，环框内 109,443 像素与独立 Python 模型逐位一致；关音乐/消隐/OFF 不改画面 |
| `test_osd_pipeline.do` | 9 页 XGA：面板外不变、面板内只有 1/4 暗化或白/黄字；探测字形与字库逐位一致 |
| `test_frame_ui.do` | 改为中文 OSD 与 24 px 网格（原测试仍按早期英文 OSD 判断） |
| `test_wave_display3.do` | 阈值随“去掉波形带蓝色底色”的既有改动更新：只允许白色像素变化 |
| `test_spectrum_levels3.do` | sine 表修复后与 2.0 恢复一致 |

### 时序与面积

- OSD 字符选择改为两级流水：第 1 拍寄存面板/单元位置以及各数值的十进制位，像素路径上不再有除法器（原组合路径 22 级、−4.7 ns）。显示延迟仍为 3 拍。
- 径向外弧覆盖率用每段的 `65536/R` 倒数乘法代替 8 个变量比较；每段 `R²` 与倒数在 16 拍内轮流写入分布式 RAM（高度只在消隐期变化）。与精确边距相比，31,968 个边界样本中 56 个相差 1/8 覆盖率。
- 未优化前切片利用率超过 90%，TD 会跳过保持时间修复（各种子均 HWNS −0.020 ns）；优化后回到 89.5%。

`build/build_simsun_radial_aa.tcl`（与 `build.tcl` 相同流程、种子 6，打开 `timing_verified.al`，输出到 `build/simsun_radial_aa/`）：**SWNS +0.123 ns、HWNS +0.011 ns，STNS/HTNS 均为 0**，Period Check WNS +6.586 ns。LUT 15110（77.1%）、BRAM9K 61/64、BRAM32K 2/16、DSP 22/29。下载文件 `build/simsun_radial_aa/demo.bit`，SHA256 `CB374E8202AFA1192410A93F511E282AE92DB9155F1EB9DAF9C85A255D30AC07`。尚未上板验证。

修改前文件备份在 `build/before_simsun_radial_aa/`。
