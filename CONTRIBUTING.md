# 团队协作（第一版 v1.0.0）

- main 保存可复现的版本；每项改动从 main 建立 feature/ 或 fix/ 分支，经 Pull Request 审查后合并。
- PR 说明改动、仿真结果、时序结果及是否完成上板测试；未上板的修改明确标注。
- 首次构建遵循 README。脚本默认工具路径 D:/AMDDesignTools/2026.1，Vitis 工作区 D:/ax7010-audio-pro-vitis，串口 COM6；请按团队电脑实际情况调整。
- build/release 提供当前配套 bit、ELF、XSA 与 PS 初始化脚本；原构建下载脚本仍要求本机构建工作区和时序通过标记，不能直接把发布文件当成本机构建产物。
- build/manifest.json 与 verification.md 保存此前验证记录；本次 GitHub 上传未重跑硬件测试。manifest 的路径及源码哈希对应原始快照，上传新增的协作文档不在该清单中。
- RNNoise 为离线 PS 评估，实时 AI 耳机链路尚未完成；保留 third_party/rnnoise/COPYING 和 UPSTREAM.json。
- 不提交现场录音、缓存、日志、账号凭证或完整 Vivado/Vitis 工作区。README 中 captures 的样例录音未随公开仓库发布，需自行采集。
- 项目自有代码尚未指定开源许可证；上游 RNNoise 遵循其 COPYING。
