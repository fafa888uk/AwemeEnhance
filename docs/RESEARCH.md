# 开源研究与源码审查记录

核查日期：2026-11-26 至 2026-11-27（Asia/Shanghai）。证据层级：实时 GitHub API + 固定 SHA 原始文件高于搜索缓存；README 声明低于实测。未执行上游私信脚本、未登录账号、未导入凭据、未安装闭源插件。范围有限，**没有对任何上游做“无恶意代码”认证**。

## DYYY

原始仓库 [huami1314/DYYY](https://github.com/huami1314/DYYY)，包 control 的 Homepage 与作者相符。固定 SHA、许可见 [第三方声明](THIRD_PARTY_NOTICES.md)。实时固定版本 README 宣称适配41.2.0；搜索缓存曾显示36.5.0，已以实时内容为准。上游适配声明不自动成为本项目的验证结果。

读取 `DYYY.xm`、`AwemeHeaders.h`、`DYYYConstants.h`、README、LICENSE、Makefile。源码充分但单体 Hook 较多；含远程配置、下载解析等本项目不采用的能力。Issue/PR API 当日返回一个开放 PR #48，内容不足以提供兼容保证。未发现可用于本项目的41.3.0真机验收证据。没有将其源码整个打包入本项目。

### 接口研究证据（非已验证的二进制 ABI）

[固定源码](https://github.com/huami1314/DYYY/blob/9f356609cfe66a47a9c03388dfe2e5b64f9e0726/DYYY.xm)：

- 约4988–5190行：`AWEHotListDataController` 的 `transferAwemeListIfNeededWithArray:isInitFetch:`，及模型的 `referString` / `isAds` / `cellRoom`。
- 约468–557行：`AWEVideoModel.bitrateModels`、码率对象的 `bitrate` 和 `playAddr`。本项目不裁剪降级列表、不篡改原片地址。
- 约7770–7870行：多个播放器控制器的 `setVideoControllerPlaybackRate:`。本项目仅给首个存在且ABI匹配的栈安装适配；其他栈不宣称覆盖。
- `AWEFeedTopBarContainer`、`AWENormalModeTabBar`、`AWEFeedVideoButton`、`AWEFeedProgressSlider` 是界面候选类；Swift迁移可能绕过这些路径。

本项目原创代码选择列表过滤而不是让模型初始化返回 nil，避免主动破坏宿主模型的生命周期。不会复制上游远程配置、下载解析、账号或聊天修改。

## DouYinPlus

[xiaoleGun/DouYinPlus](https://github.com/xiaoleGun/DouYinPlus) 固定版本可访问，源码模块、构建清单及设置资源完整性线索存在。仓库声称 iOS15+，Liquid Glass 相关要求 iOS26 SDK。与另一同名网页脚本 `isxlan0/DouYinPlus` 不同，不能混淆为同一官方项目。许可证实际为 MIT + Commons Clause；调试构建包含 FLEX/Capstone，发布版裁剪它们。为避免带入许可、调试组件、远程能力和宽泛 Hook，不集成。没有核实本项目目标两版的设备兼容或全部Issue/PR历史。

## 新提供的火花项目

### cong120/douyin-auto-fire

实时 API 固定 `a517c41d…`，最后推送2026-09-08。读取 `app/config.py`、`models.py`、`history.py`、`main.py`、`sender.py`、`browser.py`、`douyin.py`、隐私工具、工作流及多项测试。存在较完整测试目录。其任务与发送历史区分预留未知状态、完成状态，历史损坏会停止而非清空；这些通用工程原则被本项目**原创重新实现**，不是复制其 Python。

这是依赖 Cookie / storage state 的 Python + Playwright 网页自动化，不是平台授权的 iOS 普通好友私信 SDK。浏览器发送结果仍依赖页面和服务行为，不满足无需凭据采集的原生插件直接集成。不会上传其认证态、消息或Trace，不调用其通知服务。

### UoUoio/DouYinSparkFlow 与其他同名分支

提供的 URL 当日直接打开和 GitHub API 均404；搜索缓存还有68提交、Playwright网页实现的旧页面。不能据旧索引声称原仓库仍可下载或已审查完整。

另定位 [2061360308/DouYinSparkFlow](https://github.com/2061360308/DouYinSparkFlow)，固定 `81f3daa0…`，最后推送2026-11-04。读取 LICENSE、依赖清单、`core/browser.py`、`core/tasks.py`、`core/douyin_im.py`、`core/session_store.py`、`app/scheduler/core.py`。有调度状态、会话验证和发送后不确定状态处理，优点是意识到“超时不等于未送达”，不能盲目重试。当前实现包含 cloakbrowser / humanize 相关能力，且处理登录态与网页消息，不符合本项目“不反风控、不采集凭证、原生直接集成”的边界，不采用。仓库有测试但未在本环境执行其私信流程；提交活跃不证明稳定。没有核实 UoUoio 与此仓库的直接分叉关系。

另发现 `halfwaystudent/douyin-sparkflow` 采用 PolyForm Noncommercial，不与上述 MIT 项目混同，不集成。

### Xiaowu-0916/douyin-spark

固定 `02f84850…`，最后推送2026-08-20；读取 LICENSE、`app.py`、`core/config.py`、`core/runtime.py`、`core/scheduler.py`、`core/automation.py`、`extract_cookie.py`。Python/FastAPI/Playwright，含好友配置、定时、网页回执启发式、失败补发；单提交历史，持续维护与目标iOS兼容无法证实。其自身README提醒平台自动化风险。不会复制随机化、凭证导出、网页发送与自动补发路径。网页“输入框清空”不能作为本项目的权威投递成功证据。

### AutoMessagePlugin / com.xuegao.automessage

搜索名称、包标识、中英文描述、GitHub原始库/历史/分支，并扩展GitLab/Gitee检索。发现第三方分发目录标注Xuegao、Huayuarc/YouRepo与1.0-2版本，转发记录还提到1.0-4/1.2-1，但未取得作者可核验原始源码与许可；这些不能认定为已审查的历史开源版本。另一个同名AutoMessagePlugin是Java项目，与iOS无关。不能因为二进制公开下载就称开源或授权。因此未下载、未反编译未知插件、未集成。AwemeNoAds 名称也没有定位到足以确认作者和许可的原始iOS仓库；不编造仓库链接。

## 平台受支持消息能力

[抖音企业私信文档](https://open.douyin.com/platform/resource/docs/openapi/enterprise-open-ability/message-management-enterprise/message-to-user/) 要求企业号、申请scope和用户授权；不能套用于普通个人好友自动续火花，也不收集Token接入。原生 `im.share` 等分享能力不等于任意好友定时文本发送。平台私信限制和安全提示优先；本地60秒冷却只是准备消息的保守限制，不是虚构的平台官方额度。

据现有证据，原生自动发送、火花读取及平台回执验证均**未实现**。采用用户允许的降级路线：UserNotifications日历提醒、明确授权、本地自选好友草稿、发送前手动核对好友及官方聊天操作。只记录prepared/manual-confirmed，绝不伪装服务器送达。

## 其他免费实现的筛选

- `PoomSmart/YouTube-X`：MIT / Objective-C Hook，属于YouTube而非抖音，不作为目标接口来源或功能兼容证据。
- `tyilo/insert_dylib`：可作为Mach-O工具研究；本项目用原创受限解析/头部填充实现，不复制源码、不下载其未知编译产物。
- [Apple UserNotifications](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger)：支持本地日历提醒，不承诺后台执行任意消息发送；不接管宿主通知delegate。
- 官方 UIKit / Photos / Foundation 用于设置、原片导出和存储，避免第三方原生设置依赖。

## 结论与后续审查

当前未找到能同时提供可信作者、许可合适、支持41.2/41.3、无需凭据与安全绕过、可直接编入IPA的原生自动消息源码。选择原创单dylib模块化实现，不堆叠他人二进制。所有未审查到的Issue/PR、崩溃记录、代码路径均为未知，而不是默认无风险。新增代码复用须保留完整原许可，更新依赖锁与逐文件审查记录，经CI和真机再合入。
