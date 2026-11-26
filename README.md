# AwemeEnhance

[English](README.en.md) · 原创代码 [MIT](LICENSE)

**开发中 / 实验性；不是已经验收的抖音增强版。** 目标为抖音 41.2.0、41.3.0，iOS 15+、arm64。未取得目标 IPA 与真机证据时，不宣称任何目标版本完全兼容。不分发抖音、账号数据、签名材料或第三方闭源插件。

## 当前实现边界

| 模块 | 已编写的实际实现 | 仍需完成 / 验证 |
|---|---|---|
| 广告 / 直播 / 关键词过滤 | 推荐列表过滤、类型检查、保留非推荐上下文 | 目标数据接口和误过滤真机测试 |
| 最高画质 | 调整宿主候选码率优先顺序，保留所有降级候选 | 宿主是否采用排序、设备解码支持和实际清晰度；不保证强制最高 |
| 倍速 | 0.25–3.0 配置持久化，ABI 匹配后拦截一个播放器栈 | 多播放器架构覆盖、视频切换实测 |
| 导航栏 / 按钮 | 独立顶部、底部、标签按钮、透明度选项及视图状态恢复 | 41.x Swift UI 覆盖、布局及冲突实测；不支持任意重排 |
| 进度条 | 显示宿主原生滑块，保留其原始拖动处理 | seek 委托、短视频/直播区分及拖动实测 |
| 无水印保存 | 主动选择自有本地原片后导出相册，不改写权限或水印 | **尚未接入可验证权限的抖音原片接口，应用内无水印保存未完成** |
| 火花 | 原生多好友配置、自定义文本/表情与时间、明确授权、本地提醒、每日防重、60秒准备冷却、准备/手动确认记录 | **自动发送未实现**；无普通个人好友受支持的私信发送授权依据；不抓取火花状态 |
| 设置中心 | 原生分组列表、动态字体、深色模式、日志、版本、恢复默认、配置导入导出 | 编译、交互和真机 UI 验证 |

所有功能默认关闭。目标私有适配器还要求单独开启“实验适配器”并重启；未知版本、缺失类/方法、ABI 不匹配、已知插件冲突均停用对应路径。ABI 存在不等于功能可用。不要将这些候选适配器视作九大功能已完成。

进入设置：应用内双指长按 1 秒。日志只含固定模块、事件码、时间，最多200项且仅内存；不记录异常正文、账号、聊天、Token 或 Cookie。火花草稿是你主动填写的本地数据，不是采集的聊天；不上传、不进配置导出和通知正文，数据目录排除备份。

## 免费标准 Runner 构建

仓库 Actions 中的 **Build / Test / Security / Release / Build IPA / Update Dependencies** 均有 `Run workflow` 入口。

- Test / Security：`ubuntu-latest`；不假定它有 iOS SDK。
- Build：`macos-latest`，使用该机 Xcode 的 iOS SDK及锁定提交的 Theos。只使用 GitHub 标准 Runner，不购买证书、不使用付费 API 或第三方构建平台。
- 原创插件产物：`AwemeEnhance.dylib`、`AwemeEnhance.deb`、`SHA256SUMS.txt`、构建元数据与 Changelog。公开 Artifact 保留3天，不缓存私有 IPA。
- Release：匹配 `VERSION` 的 `vX.Y.Z` 标签触发编译、检查及原创插件预发布；未通过真机验收前不标稳定版。
- Dependabot 与上游工作流只生成待审查 PR，不自动合并或更换运行时代码。

Runner 是否可用、Actions 配额与存储免费政策由 GitHub 决定；本项目不启用计费。私有云对象存储可能另计请求、流量、容量费用，所以**默认不调用 AWS**，零外部费用路径是本地集成。

### 本地编译插件（需要 macOS / Xcode）

```bash
export THEOS="$HOME/theos"
bash scripts/bootstrap-theos.sh
bash scripts/build.sh
```

## 完整未签名 IPA 构建入口

先从通过 Build 的原创插件产物取得 dylib，核对 SHA256。仅使用你合法取得且有权修改的 IPA。工具不下载未知来源 IPA，不解密 FairPlay，不处理账号登录或规避平台验证。

```bash
python tools/ipa.py --ipa "/private/path/source.ipa" \
  --version 41.3.0 --dylib "/private/path/AwemeEnhance.dylib" \
  --output "private/output/AwemeEnhance_41.3.0.ipa" \
  --expected-sha256 "源文件独立确认的64位SHA256" \
  --acknowledge-modification-rights
```

Windows / macOS / Linux 均可运行这个 Python 标准库打包工具，但 dylib 的编译需要 Apple SDK。输入和输出可为绝对路径。源文件不被改写。

工具执行 ZIP 路径、重名、软链接、膨胀限制、CRC、Bundle ID、精确版本、Mach-O 架构/子类型、加密标记、嵌入依赖和头部空间检查；原创插入加载命令，剥离失效签名并重新封装，再次验证输出 CRC 与 SHA256。拒绝加密 IPA、依赖缺失、重复注入、架构缺失或不足的加载命令空间，不自动“修复”未知二进制。结构检查不证明来源授权、无恶意代码或可安装。

### 授权私有存储

`tools/private_storage.py` 支持用户现有 AWS CLI 凭证链 / OIDC 下的指定 `s3://bucket/key`。不枚举账户存储，不创建云资源；要求存储桶四项公共访问阻止全部已开启。凭证与 URI 不写入源码/公开日志。

**Build IPA**：在仓库创建受保护的 `private-ipa` Environment，按 [私有构建说明](docs/PRIVATE_BUILD.md)配置 OIDC 最小权限及 Secret。在 Run workflow 中填写版本、源 SHA256、修改权确认；只有另行明确授权现有 S3 潜在费用时才会访问 AWS。完整 IPA、报告、校验只回传私有桶，从不进入公开 Artifacts / Releases。尚未配置或授权时不运行云操作，仍可使用本地免费路径。

## 测试及文档

```bash
python -m unittest discover -s Tests -v
python tools/audit.py
python tools/environment.py --require-ios
```

测试使用明确标注的**不可运行合成 Mach-O fixture**，不是抖音功能验收。没有真机测试就不会记录为功能通过。

- [源码审查与第三方取舍](docs/RESEARCH.md)
- [第三方声明](docs/THIRD_PARTY_NOTICES.md)
- [兼容性矩阵](docs/COMPATIBILITY.md)
- [开发架构](docs/DEVELOPMENT.md)
- [测试报告](docs/TEST_REPORT.md)
- [签名安装条件](docs/SIGNING.md)
- [路线图](docs/ROADMAP.md)

## 安全边界

不收集账号/聊天/认证信息，无广告、遥测、远程配置和动态下载代码；不解除下载限制、付费权限或平台验证。不保证第三方应用账号安全或永不崩溃，不捕获底层内存破坏/信号后强行继续运行。请先在测试设备离线验证，避免同时注入其他增强插件。