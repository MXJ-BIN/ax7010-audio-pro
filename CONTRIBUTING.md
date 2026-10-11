# 贡献指南

欢迎为 AX7010 AUDIO PRO 提交问题报告、文档改进、测试和代码修改。参与前请阅读 [README.md](README.md)、[AGENTS.md](AGENTS.md) 和 [PROJECT_LOGIC.md](PROJECT_LOGIC.md)。

## 开发环境

- 硬件目标：AX7010，器件 `xc7z010clg400-1`。
- 硬件和软件工具：Vivado / Vitis 2026.1。
- 脚本环境：Windows、PowerShell 或 CMD；部分音频测试和处理工具需要 Python 与 NumPy。
- 运行前检查 `scripts` 中的工具安装路径、Python 路径和 Vitis 工作区路径是否符合本机环境；Vitis 工作区使用无空格路径。

## 提交问题

请说明预期行为、实际行为、复现步骤、工具版本及相关日志。涉及板卡问题时，补充接线、串口设置、使用的 bit/XSA/ELF 版本和是否已上板验证。提交日志前移除个人信息；音频样本仅在有权分享时提供。

## 修改和提交

1. 为一项明确的修改创建分支，保持提交范围集中。
2. 遵循现有代码风格，补充与修改相关的测试和说明。
3. 按下面的要求完成验证，记录通过和失败的检查。
4. 提交 Pull Request，说明问题、修改后的行为、验证结果及已知限制。涉及接口或固件时，列出接口变化、配套产物路径和版本、时序与资源结果，以及下载和上板状态。

不要将源码仿真通过描述为固件已更新，也不要将生成产物描述为已完成上板验证。

## 构建与验证

在项目根目录的 PowerShell 中逐步执行，每步成功后再继续，不要同时运行多个构建脚本：

```powershell
.\scripts\run_sim.bat
.\scripts\test_speech_band.bat
.\scripts\create_project.bat
.\scripts\build_bitstream.bat
.\scripts\create_vitis.bat
```

配置好本机路径后，也可以执行 `.\scripts\build_all.bat`，按顺序完成上述流程。按修改范围补充 FFT、视频、采集等模块的相关测试。仅修改文档时检查内容和链接即可。

完整流程的成功标记包括 `BUILD_ALL_PASS`；硬件和软件分别检查 `FOURMIC_BUILD_PASS`、`DOA_UART_APP_PASS`。失败时停止并记录原因，不使用旧产物替代失败的新构建。

### 硬件接口变化

每次代码修改必须核对 AXI 地址与地址映射、寄存器数量和定义、DMA、BRAM 接口、中断、时钟、PS-PL 接口及 IP Block Design。任一项变化时，按照 [AGENTS.md](AGENTS.md) 完成：

1. 同步更新 RTL、IP/Block Design、地址映射、约束和 PS 软件，检查接口一致性。
2. 完成受影响模块的 RTL 编译/elaboration 和相关 testbench。
3. 更新 Vivado 工程与 IP，清除受影响的旧 OOC 检查点，完成全工程综合、实现及 setup/hold 时序检查。
4. 时序通过后生成新 bit，导出包含该 bit 的新 XSA。
5. 使用新 XSA 重建 Vitis 平台、BSP 和配套 ELF，即使 PS 源码未改也不默认复用旧 ELF。
6. 核对 bit/XSA/ELF 一致性，记录产物路径、构建结果、时序、资源和必要的哈希。
7. 更新 README，准确说明接口变化、验证结果、产物版本及上板状态。

仅修改内部算法且接口未变时，明确记录接口检查结论。内部新增 RAM 不等同于修改 PS/AXI 可访问的 BRAM 接口；要使 RTL 修改在板上生效，仍须生成并下载对应固件。

### 下载与板卡验证

构建与下载是独立操作。执行板卡下载前确认本次任务允许该操作，连接 JTAG、打开正确串口，配置为 115200、8N1、无流控，再执行：

```powershell
.\scripts\run_doa_uart.bat
```

检查 `DOWNLOAD_PASS` 和串口启动信息。需要保留的板上录音应先导出；复位或运行临时 AI 评估程序可能使未导出的 DDR 录音失效。

## 文件与许可证

不提交 `build/`、`captures/`、工具缓存和临时日志等生成文件；遵循 [.gitignore](.gitignore)。请保留第三方代码的来源、版权声明及许可证。

项目原创内容使用 [MIT License](LICENSE)。提交贡献即表示你有权提供这些内容，并同意原创贡献按项目 MIT 许可证分发。`third_party/` 中的依赖保留各自的许可证；例如 RNNoise 的许可见 [COPYING](third_party/rnnoise/COPYING)。
