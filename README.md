# AX7010 AUDIO PRO：四麦定向拾音增强版

v1.1.0

面向 AX7010 / xc7z010clg400-1，Vivado / Vitis 2026.1。独立于已上板验证的 `../ax7010-audio-fourmic`，保留原版作为回退。当前语音滤波版已完成仿真、实现和上板控制／10 秒录音验证；用户已确认频带处理的噪声效果更好；另新增 PS 离线 AI 推理与录音试听工具。详细状态见 `build/verification.md`，源代码与产物哈希见 `build/manifest.json`。


## 2026-10-07 DOA GCC-PHAT 源码更新

默认 DOA 已由普通互相关升级为**实际参与延迟输出的 GCC-PHAT**。真实参数沿用 48828.125 Hz、50 mm 正方形、512 点；理论最大 TDOA 为 7.118 点，保留 ±8 搜索。新核依次处理四路 FFT、四条阵列边的 PHAT/IFFT，显示 FFT 独立运行，16 柱频谱功能不改动。

- PHAT 使用定点 max+0.5min 幅值近似、epsilon 与 14 周期串行除法；屏蔽 DC/极弱频谱，输出 Q14。
- 保留原去直流/带通、Q4 三点抛物线、四麦 atan2 坐标和中值/IIR 跟踪；DOA 在 band_valid 消费四路滤波结果。
- 修复双缓冲超时覆盖计算帧的问题；能量、峰高、旁瓣与峰均值比不足时 invalid，原始和跟踪方向保持。
- 十三项主回归全部通过（FOURMIC_TEST_PASS）；28 组算法测试、四档预处理链路、连续采样与故意超时保护通过；整数 0/±1/±3/±7 点正确，半采样、幅度差、噪声/反射通过；静音、低能量、纯直流和 11 组纯噪声均拒绝。Q4 是输出格点，接近最大延迟的 7.125 点混合输入实际估计 7.0 点，详见报告。
- DOA 模块综合资源 LUT 1707、FF 710、BRAM36 5、DSP 13；50 MHz 模块布局布线 WNS +7.234 ns；非静音计算约 2.38 ms，帧采集加计算约 12.86 ms。

完整 [A–G 架构、问题、修改、定点格式、逐组测试与资源报告](docs/doa_gcc_phat.md)。Vivado TCL 可执行 source scripts/test_doa_gcc.tcl，日志/CSV/DCP 在 build/doa_gcc；主回归已纳入新测试。原时域实现保留于 rtl/doa_time_domain.v，显式 GCC_PHAT=0 可回归。

**本次为 RTL 与独立 DOA 模块验证，尚未重新生成、发布或下载 bit/XSA/ELF（不用修改，似乎可以运行原来的），也未进行真实房间 GCC-PHAT 精度测试。**

**本次更新还加入了AGENTS.md文档，这是agent应该遵守的约定。同时新增了整个项目的逻辑梳理文件[PROJECT_LOGIC.md](C:/ax7010_audio_pro/ax7010-audio-pro/PROJECT_LOGIC.md)，这不应该是项目最后想要的，但是可以看一看。**

## 📚 项目文档

- [AGENTS.md](./AGENTS.md)
- [PROJECT_LOGIC.md](./PROJECT_LOGIC.md)

**下方的历史上板记录对应旧发布固件。**

## 新增功能

- 四通道独立 Q6 增益与相对幅度校准；有效方位检查、三点中值和可调 IIR 跟踪。
- 自动跟随、任意角度定向、锁定当前目标；原有分数延迟叠加波束、语音 EQ 和混响。
- 四路同步可切换语音带通：语音 150–6000 Hz、抗风 300–4000 Hz、窄带 300–3400 Hz；作用于方向估计和波束成形之前，使用复用乘法器，直接在 PL 实现。
- 平滑噪声门、可开关 AGC、音量与静音；麦克风增益和输出调理器的削顶提示。
- 720p HDMI：四路电平、原始方向和拾音目标、数字目标角度、模式状态、录音状态、16 柱频谱。
- 512 点硬件 FFT 用于显示，复用乘法器；16 个频率点约 95–6104 Hz，相对对数幅值，不是校准后的 dB 测量。显示 FFT 保持独立；2026-10-07 源码新增独立 DOA GCC-PHAT FFT/IFFT 核。仍没有窗函数或基于 FFT 的实时音频降噪。
- 保留 0.671 秒 BRAM 短录音；新增连续环形采集到 384 MiB DDR，双通道对比录音最大约 34 分 21.6 秒，JTAG 导出带 CRC 校验的 WAV，无需额外存储外设。

默认启用语音档滤波和方向平滑，噪声门阈值改为 32；噪声门、AGC、混响和静音默认关闭。原有四分之一音量保留，新增音量默认单位增益。噪声门用于停顿时压低背景声；当前实时链路由滤波和阵列波束处理；PS AI 离线录音处理见下文。

## 接线保持四麦版不变

四个 INMP441 固定成 **50 mm** 正方形，共地、共 SCK/WS，四路独立 SD，所有 L/R 接地。

```text
        FRONT 0°
     mic3 ---- mic2
      | 50 mm  |
     mic0 ---- mic1  RIGHT 90°
```

VDD 接 J11 Pin39/40 的 3.3V，GND/LR 接公共地 Pin1/37/38。

- 共用 SCK：J11 Pin5；WS：Pin6。
- mic0 SD：Pin3 / F17；mic1 SD：Pin4 / F16。
- mic2 SD：Pin8 / G19；mic3 SD：Pin9 / H18。
- PCM5102A：BCK=Pin5，LRCK=Pin6，DATA=Pin7，GND=公共地，供电沿用已验证接法。
- HDMI 接现有 SANC 显示器；输出 1280×720，实际刷新率略低于 60 Hz。实际音频采样率 48828.125 Hz。

## 后续硬件修改与配套产物规则（2026-10-07）

以后每次修改先核对：**AXI 地址、寄存器数量/定义、DMA、BRAM 接口、中断、时钟、PS-PL 接口、IP Block Design**。任一项变化，必须完整执行：

1. 更新硬件连接、参数/约束及对应 PS 软件，完成 RTL 编译和相关仿真。
2. 更新 Vivado 工程/IP，重建受影响 OOC 检查点，全工程综合、实现并通过 setup/hold 时序检查。
3. 生成新 **bit**，导出包含该 bit 的新 **XSA**。
4. 使用该 XSA 更新/重建 Vitis 平台和 BSP，生成配套新 **ELF**，不默认复用旧 ELF。
5. 核对三份产物一致性，更新本 README 的接口变化、验证、产物路径/版本和上板状态；失败时明确记录原因，不能用旧产物冒充本次构建。

对应现有脚本顺序：需要更新工程时运行 scripts/create_project.bat → scripts/build_bitstream.bat → scripts/create_vitis.bat。生成产物不等于已下载；下载/运行按当次任务授权执行。此规则同时保存在 [AGENTS.md](AGENTS.md)，供后续工程修改遵循。

本次 GCC-PHAT 修改检查：上述 PS/AXI 接口及 Block Design 均未变化；新增 DOA 内部 RAM 不改变 PS 可访问的录音 BRAM 接口，因此未触发接口变更后的 bit/XSA/ELF 重建。当前 GCC-PHAT 是已通过验证的源码版本，既有发布固件仍为旧算法；要在板上使用新算法，需要生成并下载新的匹配固件。

## 构建与下载

逐步运行，每步成功后再运行下一步；不要同时运行多个脚本。

1. `scripts/run_sim.bat`：十三项核心仿真（含 GCC-PHAT、三档滤波联合测试和连续录音环形缓存），再运行 `scripts/test_speech_band.bat`：四路滤波逐样本和频响检查。
2. `scripts/create_project.bat`：生成增强版 BD，包含自定义 AXI 控制器。
3. `scripts/build_bitstream.bat`：综合、实现、时序检查和 XSA 导出。
4. `scripts/create_vitis.bat`：生成匹配的 PS 裸机程序。
5. 开板、连接 JTAG 与串口，打开 COM6 115200/8N1，运行 `scripts/run_doa_uart.bat`。

`build_all.bat` 顺序完成前四步。已有匹配产物时只需第五步；断电后也要重新下载。PS 工程在无空格路径 `D:/ax7010-audio-pro-vitis`，最新版路径由该目录的 `last_workspace.txt` 记录。

检查日志成功标记：硬件 `FOURMIC_BUILD_PASS`，PS `DOA_UART_APP_PASS`，下载 `DOWNLOAD_PASS`。出现错误即停止，不能用旧 XSA 或 ELF 继续。硬件时序通过后才写入 `build/hardware_ready.txt`；PS 构建和下载会检查该标记与产物时间，避免误用失败构建的 bit。屏幕只有图形但无数字时，首先检查 PS 程序是否已启动。首次启动串口应有 `AX7010 AUDIO PRO BOOT` 和命令帮助。

## 串口操作：每条命令均需按回车

2026-10-04 修正版默认关闭周期状态日志，输入字符会回显。点击 Vitis 的 COM6 串口文本区，切换英文输入，输入命令后按回车；不要输入到 OUTPUT 或普通终端标签。

- `s`：输出一次方向和硬件寄存器状态。
- `log on`：开启每秒一次状态日志；输入命令期间暂停周期输出。
- `log off`：停止周期状态日志。板卡收到 Ctrl-C 字节也会清空未完成命令并停止日志。

屏幕和方位更新不依赖串口日志，默认安静不会停止采集或自动跟随。


- `a`：自动跟随并启用平滑；`l`：锁定当前有效拾音目标。
- `angle 45`：任意角度；`0`/`1`/`2`/`3`：前、右、后、左。
- `b` 波束，`e` EQ，`r` 混响，`q` 四分之一音量：切换。
- `n` 噪声门，`g` AGC，`u` 静音，`f` 方向平滑：切换。
- `vol 96`：音量 Q7，范围 0–128，128 为单位增益。
- `gate 32`：噪声门阈值（新版本默认 32），实际内部振幅为参数×256；范围 0–65535。
- `band off` / `band voice` / `band wind` / `band narrow`：关闭滤波／语音／抗风／窄带，明确设置而非切换；屏幕顶部显示 BAND 档位。
- `smooth 2`：平滑移位参数 1–7，越大跟随越慢。
- `gain 0 64`：mic0 增益 Q6，64 为单位增益，范围 0–192。
- `cal`：一秒预热、五秒幅度校准。建议阵列中心正前方至少一米处播放持续稳定声，避免移动。若输入太弱或电平表饱和，校准会拒绝结果并保持单位增益。只校正相对幅度，不校正相位；上电不保存。`resetcal` 恢复四路单位增益。
- `x` 清除削顶提示；`m` 麦克风，`t` 测试音，`p` 退回板上按键控制；`h` 帮助。

屏幕绿点为原始有效方向，灰点表示无效结果；黄框为实际波束目标，`BEAM DEG` 显示该目标角度。AGC 和门限需要结合自己的环境调试，先保持关闭，确认原版声音和方向再逐项开启。模式改变后串口返回 `CTRL/GAINS/OPTIONS`。

## 语音频段保留与抗风噪

每条命令按回车：

- `band voice`：150–6000 Hz，默认档，声音较自然，削弱低频轰鸣和高频嘶声。
- `band wind`：300–4000 Hz，适合低频风噪、空调轰鸣较强时，声音会偏薄。
- `band narrow`：300–3400 Hz，进一步压低高频噪声，听感接近电话语音。
- `band off`：只旁路新增滤波，原有去直流、波束、EQ 等设置仍生效，便于听同一声源的滤波前后差别。

新下载后自动跟随、波束和 EQ 保持原默认设置，混响、噪声门、AGC 默认关闭。建议先用默认 `band voice` 正常讲话，再输入 `band wind` 比较。清晰拾音时先保持 REVERB、GATE、AGC 熄灭；若 REVERB 已亮，输入一次 `r` 关闭。需要门限时先设置 `gate 32`，再确认 GATE 是否开启，避免轻声断续。

处理顺序：I2S → 去直流 → 四麦增益 → 四路相同带通 → 方向估计／波束 → EQ／混响 → 门限／AGC／音量 → DAC。使用二阶高通加四阶低通，边界频率是约 -3 dB 截止点，带外逐渐衰减，并非把指定频段之外所有样本置零。系数按实际 48828.125 Hz 设计，采用 Q16 系数、四位内部小数、三个二阶节与共享乘法器；四路同时提交结果，每帧最多 194 个 50 MHz 时钟，新增一个采样周期的固定流水线延迟。系数设计参照 [W3C Audio EQ Cookbook](https://www.w3.org/TR/audio-eq-cookbook/)。

RTL 正弦仿真中，抗风档对 50 Hz 衰减约 31.2 dB、10 kHz 衰减约 36.4 dB，1 kHz 基本保留。这是滤波器频响验证，不是房间实测 SNR 提升。语音频段内的风声、其他人声不能仅靠带通消除；麦克风被风吹到饱和后无法靠滤波恢复。切换档位会清空滤波历史，可能有短暂过渡，建议先选好档位再开始录音。录音期间禁止切换，设置写入 WAV 配套 JSON 的 options 字段（bits29:28=0/1/2/3）。

`s` 状态新增 `band`、`band_clip`、`band_overrun`；后两项应为 0，`x` 清除累积提示。CLIP 也包含滤波内部削顶。板上按键模式 `p` 使用语音档；输入任一 band 命令恢复 PS 参数控制。before 通道位于新增滤波之前，after 包含滤波和其他当前音效，所以保留原有 10/30/120 秒录音与试听流程。

## PS AI 实测与离线降噪（新增）

已将官方 [RNNoise v0.1.1](https://github.com/xiph/rnnoise/tree/v0.1.1) 经典轻量模型编译为 Cortex-A9 裸机程序并在 AX7010 上运行。87,503 个 8 位权重，推理使用浮点运算；选择该版本作为低算力基线，不把它描述为最新模型。上游代码和许可证保存在 third_party/rnnoise，固定提交 6cbfd53eb348a8d394e0757b4025c6ded34eb2b6。现有 PL 下载文件和生产版 ELF 保持配套。

2026-10-04 实测：使用 captures/compare_long01.wav 原始 mic0 通道，按实际采样率从 48828.125 Hz 转为 48000 Hz；输入固定增益 +24 dB、无输入削顶，导出后撤销增益以保留对比音量。30 秒语音加一帧收尾，共 3001 帧，在约 667 MHz 的 ARM0 上推理 8.144 秒。每个 10 ms 音频帧平均 2.714 ms、P95 2.727 ms、P99 2.731 ms、最大 4.991 ms；超 10 ms 为 0，非有限值和输出削顶为 0。相当于单核实时预算的 27.14%，不是包含所有系统任务的 CPU 占用测量。状态对象 18,492 字节；测试程序含 1 MiB 堆和 256 KiB 主栈等预留，静态地址占用约 1.47 MiB。

测量包含输入样本转换、完整 RNNoise、输出量化；不包含电脑重采样、JTAG 文件传输、未来 PL 回传及与长录音并发的开销。因此结论是“单路 AI 推理有实时余量”，还不是“实时 AI 耳机通路已完成”。当前耳机输出仍是 PL 语音滤波版。测量记录在 build/ai_eval/speech_a9_run2.json，已生成 captures/ps_ai_eval_20261004_before.wav 和 captures/ps_ai_eval_20261004_ai.wav；两份文件同为 48 kHz，去掉 RNNoise 固定的 480 点帧延迟，试听仍需判断弱语音、句尾和失真。没有干净参考，不能把变小的音量当作 SNR 提升。

首次生成或修改 AI 源码后，在 PowerShell 编译：

```powershell
& "C:/Users/BIN/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe" "C:/Users/BIN/Cursor Projects/ax7010-audio-pro/scripts/build_ai_eval.py"
```

保持板卡上电、连接 JTAG，关闭 COM6 和其他调试会话；先把需要保留的板上录音导出到电脑。本工具临时占用 PS 和 DDR，静音实时输出，完成或遇到可捕获错误后重载当前生产固件，恢复语音档默认设置；已有电脑 WAV 不改动，未导出的 DDR 录音会失效。若人为中断或断电，运行 scripts/run_doa_uart.bat 恢复。

对已有 30 秒录音执行（原文件旧 after 曾被噪声门截断，故本例选 before）：

```powershell
powershell -ExecutionPolicy Bypass -File "C:/Users/BIN/Cursor Projects/ax7010-audio-pro/scripts/ai_process_recording.ps1" -InputFile "C:/Users/BIN/Cursor Projects/ax7010-audio-pro/captures/compare_long01.wav" -Channel before -Seconds 30 -InputGainDb 24
```

脚本使用现有匹配 BSP，AI 推理在板上执行；电脑负责 64 抽头加窗 sinc 重采样和 JTAG 导入／导出。输入、输出均与板端 CRC 校验；结果默认保存到 captures/ai_时间_before.wav、_ai.wav 和 .json。这里的 before 指“本次 AI 的输入”，若选 -Channel after，它已经包含前级 PL 处理。默认选择 after，适合对新录的波束／滤波结果继续降噪；优先关掉 REVERB、GATE 和 AGC 再录。参数 Seconds 最多 120 秒，这是当前 AI 评估工具的限制，不影响原有 34 分钟录音容量。InputGainDb 默认 18，范围 -24..30；若输入过强，脚本在上板之前拒绝削顶，需降低该值。依赖当前附带 Python 中的 NumPy。

## 实时 PS AI 接入顺序

1. 建立 PL→PS→PL 音频返回通路，使用双缓冲或环形 FIFO，记录欠载、溢出和处理耗时。当前 AXI 控制器只有采集缓存，没有 PS 音频写回端口。7010 可优先评估精简 FIFO，AXI DMA 是后续提高吞吐和降低 CPU 搬运开销的选项。
2. 按音频帧调度 PS 任务，替换当前主循环固定 usleep(10000)；正确处理 48.828125 kHz 与模型 48 kHz 的双向流式重采样。帧超期时平滑退回 PL 输出，避免断续或爆音。
3. 推荐实时顺序：四麦滤波→DOA／波束→PS 单路 RNNoise→EQ／混响／输出调理→DAC。同样的 AI 不必分别跑四路。为模型输入设置可控增益，并保持绕过与 AI 通道延迟对齐。
4. 增加平滑的 AI 开关／降噪强度、人声活动概率显示，以及“DSP 前／DSP 后／AI 后”的同段录音对比。RNNoise 自带 VAD 概率，但不是说话人身份或关键词识别。
5. 实时全链路完成后再量化端到端延迟、录音并发、连续运行、风扇／键盘／风噪下的弱语音保留效果。保留纯 PL 模式作为可直接展示的基线。

现阶段从单路推理算力看，无需更换 AX7010；优先完成实时往返链路和可重复对照实验。功能目标不包括在板上训练模型、大型语音识别或大语言模型。

## 录音导出

**先关闭 Vitis 中 COM6 串口终端**，串口不能由两个程序同时打开。在 PowerShell 运行：

```powershell
powershell -ExecutionPolicy Bypass -File "C:/Users/BIN/Cursor Projects/ax7010-audio-pro/scripts/capture_audio.ps1" -Port COM6
```

脚本自动发送 `v` 录音、等待完成、发送 `d` 导出，保存到 `captures` 下的 WAV 和参数 JSON。建议在开始脚本前播放持续声。115200 串口导出约 11.4 秒，期间 PS 命令和数字角度更新暂停，PL 的采集、波束跟随和声音输出继续。

WAV 左通道为高通后的 mic0，右通道为处理后、四分之一衰减前的信号。二者有处理延迟和增益差异，直接比较幅度不能当作 SNR 提升；录音较短，也不能代替长时间稳定性测试。脚本按 48828 Hz 写 WAV，真实时钟为 48828.125 Hz。

不要在串口终端手动输入 `d`：它返回二进制音频，会显示乱码。手动 `v` 只录音并返回状态。

试听对比：先运行 capture_audio.ps1 保存 WAV，再运行以下命令，将示例路径替换为实际输出文件：

```powershell
powershell -ExecutionPolicy Bypass -File "C:/Users/BIN/Cursor Projects/ax7010-audio-pro/scripts/listen_capture.ps1" -InputFile "C:/Users/BIN/Cursor Projects/ax7010-audio-pro/captures/compare01.wav"
```

脚本生成同名 _before.wav 和 _after.wav 两个单声道文件，分别按回车试听，保留原始幅度。before 是去直流后的 mic0，after 是整个处理链的输出，包含当前语音滤波、波束、EQ、混响、AGC、门限和音量设置。短录音单次约 0.671 秒；连续长录音见下面 DDR 流程。串口导出耗时不等于录音时长。


## 连续长录音：DDR + JTAG 导出

本版硬件 ID 为 A7010404，需重新构建并下载配套 bit/XSA/ELF，不能只更换电脑脚本。PS 使用 AXI-Lite 读取 PL 连续环形缓存并写入 DDR；每次录音连续进行，不拼接多个短录音。溢出时返回 REC_ERROR 并拒绝导出，避免把缺样录音当作成功。384 MiB 录音区为 0x08000000..0x1FFFFFFF，程序、堆和栈由链接脚本限制在 0x07000000 以下；元数据位于 0x07FFF000。录音开始时暂停周期日志，录音期间禁止更改音效参数，设置在开始时快照保存。

串口命令（均按回车）：

- `rec 10`：连续录 10 秒；整数秒范围 1–2061，采样帧数按真实 48828.125 Hz 向下取整。
- `rec max`：录满 100663296 帧，约 2061.584 秒（34 分 21.6 秒）。
- `stop`：提前结束并保留已录数据；等到 `REC_READY` 再导出。
- `recinfo`：查看状态（0 无长录音、1 正在录、2 完成、3 错误）、已录帧数、目标长度、最大缓存积压、CRC 和 DDR 探测结果。

启动时 probe=1 表示覆盖整个录音地址区间的 64 点写入/读回探测通过，包含最高地址；这不是对全部 384 MiB 的逐字内存测试。环形缓存深度 32768 帧，maxlag 应低于该值。录音完成后缓存留在内存中，断电、重新下载或开始新录音会使旧记录失效。

推荐一键流程：先在 Vitis 设置方向和音效，关闭 COM6，保持板卡供电和 JTAG 连接，在 PowerShell 运行：

```powershell
powershell -ExecutionPolicy Bypass -File "C:/Users/BIN/Cursor Projects/ax7010-audio-pro/scripts/capture_long_audio.ps1" -Port COM6 -Seconds 10 -Output "C:/Users/BIN/Cursor Projects/ax7010-audio-pro/captures/compare10.wav"
```

把 `-Seconds 10` 改为 30、60、300 或最多 2061；也可用 `-Max` 替代 `-Seconds 10`，录满约 34 分 21.6 秒。脚本发送录音命令，等待完成，然后通过 JTAG 导出；在支持交互输入的 PowerShell 窗口按空格可提前停止。不要同时运行其他调试器或重新下载板卡。输出路径须为新文件名。主机比对板端 CRC，只有完整且校验一致的音频才写成 WAV。旧长录音版已上板验证 10 秒和 120 秒连续录音、提前停止及导出；当前语音滤波版连续回归 10 秒和提前停止，完整最大时长尚未实测。

也可在 Vitis 手动发送 `rec max`，需要时发送 `stop`，等到 REC_READY 后关闭 COM6，再单独导出：

```powershell
powershell -ExecutionPolicy Bypass -File "C:/Users/BIN/Cursor Projects/ax7010-audio-pro/scripts/export_long_audio.ps1" -Output "C:/Users/BIN/Cursor Projects/ax7010-audio-pro/captures/long01.wav"
```

JTAG 导出不重置板卡，也不向串口发送二进制数据。导出时间随文件大小和 JTAG 速度增加。导出后耳机接电脑，运行 listen_capture.ps1 -InputFile 对应 WAV，按回车分别听 before/after；脚本以分块方式拆分文件，不会一次加载全部长录音。原始幅度保留，两个通道仍有处理延迟和增益差异，不应把更响直接当作降噪改善。

## 噪声门导致语音断续时

如果 before 连续、after 出现整段零样本，先检查 GATE。旧版本 gate 256 是参数默认值，已造成轻声被切断；新版本默认值降为 32，GATE 仍默认关闭。建议先输入 `gate 32`（只改阈值，不切换 GATE 开关），再根据环境试 16、32、64：太高会吞轻声和句尾，太低则放行背景声。录音期间参数被锁定，需等录音完成或 stop 后调整。

为确定原因，可在屏幕 GATE 已亮时输入一次 `n` 关闭门，再录一段同位置、同音量语音；保持波束、EQ 和混响不变。若关闭门后语音恢复连续，优先调低门限，不要同时提高四路增益或打开 AGC。噪声门只在声音较弱时衰减输出，不是持续噪声中的语音分离算法。门限调整不能恢复旧文件中已经被置零的 after 样本；原始 before 文件保留，可继续试听。

## 显示器兼容性修正

2026-10-04 版本保留 1280×720 和原有像素时钟，改用同步起点坐标：每行按 SYNC→BACK→ACTIVE→FRONT 输出，场同步边沿与行同步起点对齐。已通过两帧完整仿真，核对 1650×750 总周期、1280×720 有效像素、40 像素行同步和 5 行场同步。已重新上板，用户确认 SANC 显示完整、循环移位消失。

如换屏后仍出现循环移位，重新插拔 HDMI 让显示器重识别，并检查显示器 FreeSync 是否关闭、画面比例是否设为全屏或 16:9；电脑桌面的分辨率设置不会修改 FPGA 发出的 HDMI 时序。请记录 OSD 识别的输入尺寸，正常应为 1280×720。

## 验证与比赛展示

先验证回车命令、四方向移动、锁定目标、静音恢复、音量、门限、录音完整性，再做真实环境角度误差、跟踪延迟、双声源定向抑制与端到端延迟测量。保留关闭增强项的对照样本。仿真通过不等于这些声学指标已经通过；不以占满 FPGA 资源作为成功标准。

寄存器起始地址 `0x43C00000`；增益 `+0x00`，配置 `+0x04`，显示 `+0x08`，命令 `+0x0C`，录音状态 `+0x10`，电平 `+0x14`，诊断 `+0x18`，方向 `+0x1C`，版本 `+0x20`，实际目标 `+0x24`，生产帧数 `+0x28`，已消费帧数 `+0x2C`，连续录音目标帧数 `+0x30`，录音窗口 `+0x20000..0x3FFFC`。采集满后保持缓存，直到下一次录音。
