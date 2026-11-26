# Contributing / 贡献

请从 `codex/` 分支提交PR，遵循现有Objective-C/Logos模块边界，保持默认关闭和显式授权。附来源、完整许可证、测试命令和实际结果；没有真机测试就写待验证。不要提交第三方IPA/二进制、账号/聊天/凭据或未经授权的SDK。

Python测试用 `python -m unittest discover -s Tests -v`，仓库安全检查用 `python tools/audit.py`。构建和静态分析依照 `scripts/build.sh`。CI成功不是目标应用验收；新增版本需更新兼容矩阵与真机证据。禁止将提醒/剪贴板准备描述为自动发送或平台投递成功。
