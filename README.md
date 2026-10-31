# digital photo frame 3.0

## 2026-10-26 音频可视化优化（3.0）

基于 2.0（XGA 1024×768，已移除 LED/SEG），参考 `嵌入式大赛FPGA安路赛道一/音频可视化实现说明等2项文件` 中已板测的底部对称波形，优化音频可视化：

- VISUAL 新增第 4 档 **WAVE**：屏幕底部白色对称波形（80 槽、cos² 包络、圆头柱、蓝色渐变），像素与参考 v0.27 逐点一致。
- 波形高度改为 **对数刻度**（每格 1.5 dB，−42～−1.2 dBFS），安静段落也有起伏；可用参数 `WAVE_LOG_SCALE=0` 恢复参考的线性刻度。
- 频谱改用 (L+R)/2；MUTE 时可视化按无声显示；只运行当前选中的分析模块。
- 渲染改为 7 拍流水线，显示总延迟仍为 17 拍。

操作：拨码 `0101`（MUSIC 页），K3 选 `VISUAL`，K4 循环 `OFF/BARS/RADIAL/WAVE`。详细说明、验证结果见 [docs/AUDIO_VISUAL_3.0.md](docs/AUDIO_VISUAL_3.0.md)。本次构建与时序结果见下方“3.0 构建结果”。

### 3.0 构建结果（2026-10-27 时序收敛）

10-26 18:09 的构建 SWNS −0.025 ns 未通过：关键路径在 100 MHz `sd_card_clk`，起点为 SD 复位同步器 `rs/pipe[2]`（扇出 1052），终点为 FAT32 扇区映射状态机 CE。原因是两处 RAM 写使能里重复使用了异步复位 `!rst`，综合时该项被并入状态机使能逻辑。已删除这两处多余条件（`SD/fat32_sector_map.v` 目录项缓存、`SD/sd_card_bmp.v` 扇区表），复位期间 `state` 已异步回到 IDLE、`found_count` 已清零，功能不变。修改前文件与报告备份在 `build/before_timing_align_3.0`。

`tools/build.ps1`（种子 6）从源码完整重新综合、布局布线：**SWNS +0.152 ns、HWNS +0.011 ns，STNS/HTNS 均为 0**，Period Check WNS +6.586 ns。下载文件 `build/demo.bit`，SHA256 `359574AEDBF0EE019EA3104B63AA34F3C634E001B744A01C01BE89C1854B667E`，记录见 `build/bitstream_build.json`。fat_cache、fat121、cache、fit_fat122、progressive、slideshow、slideshow_fault 仿真重跑通过。尚未上板验证。

以下 2.0 的记录保留为历史，其中提到的下载文件和签核 JSON 在 3.0 目录中已删除，需按本版本重新生成。

## 2026-10-24 移除 LED / SEG

已移除数码管状态显示、扫描和译码模块，以及顶层 16 个 SEG 输出和对应引脚约束；当前设计没有独立 LED 驱动。清理了仅用于数码管的状态、错误码和缓存掩码连线，显示信息由 HDMI OSD 提供。照片、音频、频谱、按键和拨码逻辑保留。

当前工程入口为 `TD_project/timing_verified.al`。修改前源码、工程配置、时序报告和下载文件备份在 `build/before_remove_led_seg`。本次构建结果见 `docs/BUILD_STATUS.md` 的最新记录；下文均为历史记录。

## 翻页提示音更新

翻页提示音改为同时叠加 G5＋B5，目标 784 Hz＋988 Hz（音乐上为大三度）。标称 48 kHz 采样率下，16 位 DDS 实际频率约 783.69 Hz＋988.04 Hz；保持约 100 ms，两个声部各为原单音的一半幅度，叠加峰值保持原值。背景音乐混合、总静音、切图提示音独立开关保持支持。新增 `test_chime_g5_b5.do` 并重跑 `test_122.do`，频率、采样使能、时长、立体声混音和饱和检查通过。最新硬件构建以 `build/project_manager_signoff.json` 记录为准；下文 11:08 的结果为修改前历史记录。

## 11:08 原生工程重建复核

最新截图对应的 `demo_Runs/phy_1/demo.prj` 仅含 place effort=high，缺少其余优化参数，最终 SWNS −0.132 ns、HWNS +0.004 ns；该结果没有通过。旧 TD 窗口 10:04 打开，磁盘工程参数 10:28 更新，后续 10:48 导出的运行配置仍是旧参数，不能把之前脚本通过等同于当前窗口已更新。

为避开旧窗口配置，新增 **`TD_project/timing_verified.al`**，使用 TD 原生工程管理器 `launch_runs syn_1`、`launch_runs phy_1` 完整重新综合及布局布线，未修改安装目录或生成的 `.prj`。11:08 完成：**SWNS +0.042 ns、HWNS +0.003 ns，STNS/HTNS 均为 0**；运行日志确认五项目标参数全部生效。请打开这个新入口查看运行结果。

本次下载文件：**`TD_project/timing_verified_Runs/phy_1/timing_verified.bit`**。报告：`build/project_manager_timing.rpt`；校验记录：`build/project_manager_signoff.json`。原 `build/demo.bit` 及其签核记录保留，两个文件来自不同构建，不混用哈希。源码未变，重新核对 75 个源码文件和 24 组已有回归日志；裕量很小，尚未上板验证。

手动模式采用 **4 张 VGA 预览＋1 张 XGA 高清**；轮播模式动态复用内存，采用两个 XGA 高清槽交替显示和加载。SD/FAT32、PCM、OSD、按键拨码、单张对比度/缩放/冷暖度和音频频谱功能均保留。

## 工程状态

- 工程文件：`TD_project/demo.al`
- 器件：EG4S20BG256
- 输出时序：1024×768，1344×806，总像素时钟约 65 MHz，TMDS 约 325 MHz
- 图片缓存：VGA 0～3 从字地址 0、307200、614400、921600 开始；高清区从字地址 1228800 开始，786432 字；总占用 8060928 字节（7.6875 MiB），剩余 320 KiB。
- 行缓存：双行 BRAM，后台读取与视频输出交替工作；XGA 读出保持 RGB888，每像素使用一个 32 位字。
- 行为：切图先显示对应 VGA 预览；高清区只在旧读请求排空、写入完成并在帧边界确认后切换。过期高清结果和失败结果不会覆盖当前显示。

## 已验证

ModelSim 回归已通过：

- `PROGRESSIVE_PREVIEW_HD_OWNERSHIP_DRAIN_STALE_FAILURE_PASS`
- `FOUR_VGA_TWO_XGA_TRANSIENT_VGA_FULL_FRAME_WRITE_BOUNDS_PASS`
- `XGA_READER_36_FRAMES_RGB888_BANDWIDTH_PASS`
- `XGA_BMP_FULL_PIXELS_LANDSCAPE_PORTRAIT_PASS`
- `XGA_1344_806_1024_768_AXIS_SOF_EOL_PASS`
- 24 组回归日志检查通过，涵盖 FAT32、PCM、按键、频谱、参数和 HDMI 串行复位；记录见 `build/verified_tests20.json`。

## 当前限制

视频效果采用流水线，RGB/HS/VS/DE 对齐延迟为 17 个像素时钟。SD 逻辑保持 100 MHz，SDRAM 控制器和存储器共用约 83.34 MHz 的同一物理时钟，XGA 输出约 65.003 MHz。2026-10-20 修复后的完整布局布线已通过快、慢工艺角检查：SWNS +0.042 ns、HWNS +0.003 ns，STNS/HTNS 均为 0。裕量较小，仍需原板验证。详见 [交付状态](docs/BUILD_STATUS.md)。

**普通 GUI 编译现已支持 SDRAM 接口配置。** 延时和驱动设置已写入 `user_source/constraints_source/pin.adc`，使用 `U3/sdram.端口名` 的原生约束，随综合结果传递到布局布线；主工程保存了高强度布局、种子 6、保持时间修复等参数。

GUI 中请先关闭旧工程（若提示保存旧配置，选“不保存”），重新打开 `TD_project/demo.al`，Reset `syn_1` 和 `phy_1`，从 Syn Opt 开始重新编译，再执行 Phy Opt 到 Bitgen。**只重跑旧综合网表的 Phy Opt 不会补上新增约束。** 核对最终 SWNS/HWNS 均非负后，使用本次 `TD_project/demo_Runs/phy_1/demo.bit`；截图所示 09:32 的旧文件仍为未通过结果，不能使用。

也可双击根目录 `build_project.cmd`（不要同时运行两次编译），或运行 `powershell -NoProfile -ExecutionPolicy Bypass -File tools/build.ps1`。此入口从源码综合、检查 SDRAM I/O 配置、布局布线并修复保持时间，通过严格时序门槛后生成 **`build/demo.bit`**。工具默认路径为 `E:\TD_Engineer\bin\run.exe`，可用 `-TdExecutable` 指定。

`build/build_status.txt` 必须同时包含 `CONSTRAINED_TIMING_PASS` 和 `PROJECT20_XGA_BUILD_PASS`；完整重编译成功时，`build/bitstream_build.json` 记录日志和下载文件 SHA256。最终时序报告为 `build/timing_summary.rpt`。

轮播可选 3/8/15 秒；下一张 XGA 未完成时保留当前画面，完成后在帧边界切换。进入轮播时可以保留当前 VGA，之后只切到完整高清图。实际间隔可能因 SD 读取延长，3 秒完成需要原板测量。停止轮播保留当前高清，只预加载前后两张 VGA；切回 VGA 后再恢复其余预览。

操作方法、SD 格式和验证方式见 [工程说明](docs/PROGRESSIVE_XGA.md)。`tools/verify.ps1` 重新运行回归；`-CheckExisting` 只检查已有日志。原工程与早期版本未覆盖；本工程只读 SD，不把照片参数写回卡中。
