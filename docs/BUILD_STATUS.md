# 2.0 时序修复与验证状态

## 2026-10-24：LED / SEG 移除及优化（当前交付）

已删除 `status_seven_segment.v`、`SD/seg_scan.v`、`SD/seg_decoder.v`，移除顶层 16 个 SEG 输出、16 条引脚约束和两个工程入口中的模块引用。当前工程没有独立 LED 驱动。清理仅服务于数码管的状态码、FAT 状态、缓存掩码、音乐错误码和废弃字幕输出连线，使综合器可裁剪不再使用的诊断逻辑；HDMI OSD 状态显示保留。

完整重新综合后，打包 LUT 从 9104 降为 8866（减少 238，约 2.6%），打包 SEQ 从 4391 降为 4333（减少 58）。最终物理 Slice 从 8640 降为 8537，占用率从 88.16% 降为 87.11%；RAM 50、DSP 13。不同指标不能直接等同于器件标称 LUT 总量。

原种子 6 的本次实现建立时序为 −0.194 ns，未通过，未作为交付版本。改用布局种子 7，保持原有时钟、分辨率、SDRAM 约束和保持时间修复参数，重新运行原生 `phy_1` 后通过：**SWNS +0.104 ns、HWNS +0.003 ns，STNS/HTNS 均为 0**，Period Check WNS +6.586 ns；Slow/Fast 均检查 Max/Min。该种子已保存到工程及 `build/verify_project_manager.tcl`。

- 当前工程：`TD_project/timing_verified.al`。请关闭旧窗口后重新打开此入口。
- 当前下载文件：`TD_project/timing_verified_Runs/phy_1/timing_verified.bit`。
- SHA256：`FDF353784FD1C11EA00133CB056A4DC690C2EC22EE66FB267A8DC6E9E06630CC`。
- 最终报告：`build/project_manager_timing.rpt`；文件签核：`build/project_manager_signoff.json`。
- 构建日志：`project_manager_verify.log`（重新综合及首次实现）、`no_seg_retry.log`（种子 7 最终实现）。
- 恢复备份：`build/before_remove_led_seg`，包含修改前源码、工程、报告和已通过的旧 bit。

本次重新运行 progressive、xga_write、frame_ui、temperature、slideshow、slideshow_fault 及移除数码管后的单张参数/帧边界提交测试，全部通过；其余回归复核已有日志，24 组日志校验通过。检查最终实现网表无 SEG 信号，52 条 SDRAM 物理 I/O 设置保留。源码清单现为 72 个文件、工程注册 63 项。旧 UI 测试中的数码管实例和对应断言已移除，OSD、缩放、音乐和按键断言保留。

尚未上板验证，时序裕量仍较小。下文、`build/demo.bit` 和旧 `demo.al` 的运行结果均为历史记录，不能用于确认本次无 SEG 版本。重建当前交付版本使用 `E:\TD_Engineer\bin\td_commands_prompt.exe build/verify_project_manager.tcl`，完成后运行同一工具的 `build/collect_project_manager.tcl`，再运行 `python tools/audit.py` 和 `python tools/record_native_run.py` 检查。

## 最新翻页双音构建（11:48）

`audio_mix122.v` 的翻页提示音已从单音改为 G5＋B5 同时叠加，标称 48 kHz 采样率对应约 783.69 Hz＋988.04 Hz，持续 4800 个采样（约 100 ms）。每个声部峰值 375000，合计不超过原来的 750000；背景音乐混合、静音、首张静音及实际提交时触发机制保留。G5 与 B5 音程为大三度，按用户指定音名和频率实现。

新增双音频率/采样使能/时长仿真通过，并重新运行音频立体声混合、静音和饱和仿真通过；原 24 项未重新全跑，复核已有日志哈希。源码清单已更新；审计入口改为实际交付的 `timing_verified.al`，旧 `demo.al` 配置未覆盖。

从源码重新运行 TD 原生综合、布局布线后，最终 SWNS **+0.105 ns**、HWNS **+0.004 ns**，STNS/HTNS 均为 0。以本次最终数据库导出的 `build/project_manager_timing.rpt` 和 `build/project_manager_signoff.json` 为准。下载文件仍位于 `TD_project/timing_verified_Runs/phy_1/timing_verified.bit`，现为新版双音文件；修改前的该 bit 和签核记录保存到 `build/before_g5_b5`。下文及 `build/demo.bit` 对应历史构建，不能用于确认新提示音。尚未上板验证。

## 最新原生工程复核（11:08）

最新用户截图 SWNS −0.132 ns、HWNS +0.004 ns 对应的 GUI 运行确实没有通过。核对其自动生成 `.prj` 和 `run.log`：仅应用 place effort=high，缺少 fix_hold=high、post_clock_route_opt=on、seed=6、hold_fix_iteration=20。TD 窗口进程在 10:04 打开，磁盘主工程在 10:28 更新，但 10:48 的 GUI 运行仍使用旧参数。下文先前“GUI 可以通过”的结论应以重新加载正确参数为前提，不能代表该旧窗口实际运行已通过。

新增独立入口 `TD_project/timing_verified.al`，使用 `td_commands_prompt.exe build/verify_project_manager.tcl`，由原生工程管理器调用 `launch_runs syn_1`、`launch_runs phy_1`，两步都运行安装目录中的默认流程。没有手改自动生成的 `.prj`、没有物理 I/O 脚本钩子、没有更改时钟或 HDL。运行生成的 `.prj`、日志均确认参数传递正确。

11:08 最终结果：SWNS +0.042 ns、STNS 0、HWNS +0.003 ns、HTNS 0、Period Check WNS +6.586 ns；快慢角 Max/Min 均检查。最终网表回读确认 52 条 SDRAM 物理输出延时及驱动设置；75 个源码文件与原清单一致，24 个已有回归日志哈希复核通过。

- 工程入口：`TD_project/timing_verified.al`（打开新入口，避免旧工程内存配置）。
- 下载文件：`TD_project/timing_verified_Runs/phy_1/timing_verified.bit`。
- SHA256：`9365B07B8DC177F3C61F4E186A21EA514AA56048CA61BD70CEFEF4282DDF78E6`。
- 最终数据库报告：`build/project_manager_timing.rpt`。
- 构建及文件校验记录：`build/project_manager_signoff.json`。
- 工程管理器日志：`project_manager_verify.log`；具体布局布线日志：`TD_project/timing_verified_Runs/phy_1/run.log`。

这是原生工程流程通过的复核证据，尚未通过 UI 点击重跑及原板运行验证；建立、保持裕量都较小。原 `build/demo.bit` 和原签核文件保留，仍对应下文 10:34 构建。

日期：2026-10-20。器件：EG4S20BG256，HDMI XGA 1024×768 输出。保留手动 4 张 VGA 预览＋当前 XGA、轮播双 XGA、停止轮播双预览恢复、PCM、频谱和各项按键参数功能。

## 修复内容

- SDRAM 控制器和存储器统一使用 PLL C1 的同一物理时钟树（约 83.34 MHz），取消重复 C2 输出；SD 逻辑仍为 100 MHz，视频仍约 65.003 MHz。
- 52 条 SDRAM 数据/地址/命令输出启用物理固定延时 OUTDEL=3、DRIVE=4；时钟输出 DRIVE=16。此次进一步将配置写入原生 `pin.adc`，必须使用 `U3/sdram.端口名`，配置随综合网表传到正常 GUI 布局布线，不依赖临时 pad 实例编号。已回读最终布局布线网表，确认 52 条输出及 1 条时钟均正确配置。
- 图片/音频 FAT32 状态机使用显式单热解码，轮播到期比较提前寄存，缩短组合使能路径。
- SD/存储器 FIFO 跨域按异步时钟组处理；SDRAM 的实际读写路径继续计时。没有通过屏蔽 SDRAM 路径、降低 XGA 分辨率或放宽时钟周期来通过检查。
- 布局布线后修复保持时间，并以最终快、慢工艺角报告作为生成 bit 的门槛。

## 时序结果

用户截图中的 09:32 GUI 结果 HWNS −0.241 ns，原因是旧约束没有向 GUI 流程传递 SDRAM 输出延时。本次添加原生 ADC 并保存主工程参数后，先用未修改的 TD `DefaultFlow.tcl` 验证综合和布局布线（`default_gui_verify.log`），再用 TD 从主工程导出的默认完整脚本重新验证（`main_native_default.log`，10:34 完成）。两次均通过建立和保持检查，后一次使用主工程可保存的 GUI 参数。没有使用 `configure_sdram_io.tcl` 钩子，也未改动 TD 安装目录。

最终报告：`build/timing_summary.rpt`，从后一次最终路由数据库重新导出，报告收集日志为 `native_report_collection.log`；对应最终实现网表为 `build/native_main_implemented.v`。

| 指标 | 结果 |
|---|---:|
| SWNS（最差建立裕量） | +0.042 ns |
| STNS（建立违规总量） | 0.000 ns |
| HWNS（最差保持裕量） | +0.003 ns |
| HTNS（保持违规总量） | 0.000 ns |
| Period Check WNS | +6.586 ns |
| 工艺角 | Slow/Fast，均检查 Max/Min |
| STA coverage | 99.98% |

这表示当前静态时序检查通过；裕量较小，不能代替原板温升、持续显示、快速切图、SD 读速与音频验证。板级 SD/HDMI 外围工作情况仍需实测。

## 重新编译与下载

交付下载文件为 **`build/demo.bit`**，来自此次通过的主工程默认完整流程。SHA256：`DC10969E459A1CB5C8131D55B963F3984C520D13B4177F88CB86A60E5DADB966`。`build/bitstream_build.json`、`build/timing_signoff.json` 记录此次报告、日志和校验值；上次交付文件保存在 `build/before_native_gui_signoff`。

GUI 重新编译步骤：

1. 关闭旧工程；若提示保存旧配置，选择“不保存”，防止内存中的旧配置覆盖修复文件。
2. 重新打开 `TD_project/demo.al`，Reset `syn_1` 和 `phy_1`，从 Syn Opt 开始完整重新综合。
3. 运行 Phy Opt 到 Bitgen，确认最终 SWNS/HWNS 均非负，STNS/HTNS 均为 0。不能只看“bitgen complete”。
4. 本次 GUI 成功后可下载 `TD_project/demo_Runs/phy_1/demo.bit`。原界面中的 09:32 结果不会因命令行复核自动刷新；该旧文件和 `best_result` 仍不代表此次通过结果。

主工程参数为 place effort=high、seed=6、fix_hold=high、post_clock_route_opt=on，route hold_fix_iteration=20。TD 的主工程 GUI 校验不接受 route effort=high，当前主工程保留默认 normal；10:34 的最终签核使用的就是这套保存后重新加载的参数。

也可以关闭其他编译任务后双击根目录 `build_project.cmd`。脚本从源码执行综合、接口回读配置、布局布线、保持修复和严格时序门槛；`build/build_status.txt` 必须同时包含 `CONSTRAINED_TIMING_PASS`、`PROJECT20_XGA_BUILD_PASS`，才接受本次生成的 `build/demo.bit`。

也可运行：`powershell -NoProfile -ExecutionPolicy Bypass -File tools/build.ps1`。更换 TD 路径时增加 `-TdExecutable '完整路径'`。

**不要仅重跑旧综合网表的 Phy Opt。** 新增 ADC 在综合阶段读入，必须先重新综合。普通 GUI 现在可以通过原生约束自动应用配置，无需修改软件全局脚本。

## 功能验证

此前从源码运行的 24 组 ModelSim 用例全部通过（2026-10-20 上午）；本次仅修改物理 ADC、工程/构建配置和说明，没有修改 HDL，沿用这 24 组回归并重新核对全部日志哈希。通过记录见 `build/verified_tests20.json`。覆盖完整帧缩放、图片适配、流水线与同步信号对齐、SDRAM 实际控制器、FAT32、PCM 循环、按键、轮播和双高清缓存所有权。

`python tools/audit.py` 已通过：75 个源码文件、66 个工程引用；静态缓存布局未越过 8 MiB。源码哈希见 `docs/source_sha256.json`。

3/8/15 秒是轮播目标间隔；下一张高清未完成时保留当前画面，实际间隔可能延长。3 秒每张必为高清尚无原板保证。工程只读 SD，不将参数写回卡中。

最终交付校验：`build/timing_signoff.json`，包含时序数值、24 组回归记录引用、源码清单哈希和下载文件哈希。已核对源码与日志未在验证后变化；尚未上板实测。
