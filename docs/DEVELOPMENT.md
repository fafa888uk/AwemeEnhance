# 开发说明

## 分层

- `Sources/Core`：不可变默认配置、验证/导入导出、纯C策略、运行时ABI/版本/实现来源探测、固定事件日志。
- `Sources/Modules`：推荐过滤、候选画质排序、倍速、定向视图状态、授权本地原片导出。
- `Sources/Spark`：保护文件存储、独立好友任务、每日准备防重、全局准备冷却、前台调度和本地日历通知。不发送网络消息。
- `Sources/Settings`：统一原生设置及用户手动预览确认。没有后台或隐藏入口远控。
- `Sources/Tweak.xm`：唯一Hook安装点；只对明确类/方法挂钩，宿主调用执行一次。
- `tools`：独立可测试的Mach-O/IPA、安全检查、私有交付、发布白名单及上游更新工具。

新版本必须添加来源/二进制证据、签名检查及目标测试；不得用模糊扫描后自动执行未知方法。当前只有两版精确版本门控，不假装已逆向41.3.0二进制。运行时存在性用于发现变化并安全禁用，不用于盲目生成适配。

## 配置与隐私

配置单独suite、不覆盖官方用户偏好；非法类型/范围、未知键拒绝。火花授权不可导入；普通设置导出不含好友、草稿、记录。火花文件在应用私有Application Support目录，原子写入、系统数据保护、排除备份。非越狱攻击者/账号隔离/端到端加密不是此保护机制的能力；越狱设备和其他同进程插件仍可能读应用数据。

存储失败停止准备新消息，避免把内存状态当成已持久化成功。prepared先落盘，再给本机临时剪贴板写草稿；manual-confirmed必须用户主动确认，且不是平台送达回执。不会为了“验证发送”读取聊天历史。

## 构建与测试

Theos使用internal Logos generator，不依赖MobileSubstrate动态库以便单dylib集成。rootless deb与独立dylib同时生成。构建只使用Xcode SDK；不在Linux Runner使用来历不明iOS SDK。测试分：

1. Python结构/安全/存储边界测试，合成fixture不能作为真IPA。
2. C策略断言测试，可在Ubuntu/macOS运行。
3. macOS Foundation配置与日志测试；iPhone SDK静态分析所有Objective-C源文件。
4. Theos/Logos实际编译、dylib架构/签名、产物白名单/SHA256。
5. 目标合法IPA集成与签名、真机功能测试（当前待资料）。

运行 `python tools/environment.py --require-ios` 无SDK时必须返回失败，不输出假二进制。发布metadata始终标明device_validated=false，未经设备证据不得改稳定版。

## 更新与冲突

Known-conflict库和异常模块仅作保守禁用；不覆盖他人Hook、不开全局线程/信号防崩。界面修改可在下一次布局恢复，无需枚举全应用视图树。一次性初始化限制重复Hook，前台一分钟timer在后台停用；本地通知让系统负责提醒而非伪装永久后台服务。

Dependabot管理固定Action SHA，Theos上游检查生成draft PR。没有自动合并和自动发布上游新二进制。研究引用与运行时依赖分开；许可证不明的一律不纳入。
