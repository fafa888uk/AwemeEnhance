# 功能与构建测试报告

日期：2026-11-27（Asia/Shanghai）。该报告区分源码、合成fixture、CI与真机，不将提醒或编译冒充功能完成。

## 已执行

| 检查 | 环境 | 实际结果 |
|---|---|---|
| Python unittest | 本机Windows，Python3.12.14 | 初始34项，新增NUL路径和未支持Mach-O拒绝用例后36项通过 |
| 完整打包管线 | 自制不可运行合成Mach-O / ZIP fixture | 通过注入、去签名、重封装、CRC及SHA256回归；**不是抖音IPA** |
| Archive安全边界 | 同上 | 路径穿越、大小写冲突、软链接、重复注入、错误版本/应用、加密、架构、依赖、哈希/覆盖等拒绝用例通过 |
| S3私有与费用门控 | mock，不访问AWS | 5项通过；未授权费用时零云调用 |
| 公开文件安全约束与Python解析 | 本机 | 通过；这不是完整漏洞/恶意软件扫描 |
| YAML语法、标准Runner与固定Action引用 | PyYAML6.0.3 dev-only | 通过 |
| 工作流上下文/表达式检查 | actionlint1.7.7，官方发布校验SHA256后本机运行 | 修复Build IPA的无效job-level runner上下文后通过 |
| Ubuntu Actions Test | [run 45856576167](https://github.com/fafa888uk/AwemeEnhance/actions/runs/45856576167) / commit `189dd6c7` | Python34项及原生C策略断言通过 |
| Security / CodeQL | [run 45856576283](https://github.com/fafa888uk/AwemeEnhance/actions/runs/45856576283) / 同commit | 两个job成功；OSV未匹配到锁定Theos与dev-only PyYAML的已知条目，不代表依赖没有漏洞 |

## 编译与IPA真实状态

- 本机无make、clang、Theos、Xcode或iOS SDK；`tools/environment.py --require-ios`实际返回失败，未生成假dylib。
- [macOS Build](https://github.com/fafa888uk/AwemeEnhance/actions/runs/45857910167) 已在标准 `macos-latest`（macOS26 arm64 / Xcode26.6）实际执行。Python/C/Foundation配置测试通过，静态分析发现一个JSON空值检查警告并已修复；Theos编译遇到通知completion捕获center的ARC循环警告升级错误，已修复并重跑。**尚未取得完整编译成功证据，不标通过。** 最新状态以Actions页面和后续记录为准。
- 初版Build IPA工作流在GitHub校验阶段失败，已查明job-level环境不能引用runner上下文，改为step写入GITHUB_ENV，并增加actionlint防回归。
- 未提供合法可修改的目标IPA；本机常见下载目录未找到对应抖音文件。未下载未知来源IPA。
- 未调用S3或创建任何云资源，私有存储尚未配置验证。
- **未生成真实 `AwemeEnhance_41.3.0.ipa`，未进行签名或真机测试。**

## 九大功能验收

广告/直播过滤、候选画质、倍速、导航/按钮、滑块显示均有源码候选适配，但目标运行时、语义、交互、性能及组合冲突仍待真机。应用内授权原片无水印保存接口未完成；自动发信及服务端结果验证未实现。设置中心、提醒、草稿、配置、导出相册尚待iOS编译及设备测试。详见兼容矩阵，不得以本报告的34项工具测试宣称这些功能通过。

## 已修复的问题

1. Windows生成ZIP测试时会规范化反斜杠，修改fixture以测试真实恶意成员名称，而不是误把规范化后的名称当漏洞。
2. 输出文件竞争失败路径不得删除其他进程创建的文件；只清理本工具成功独占创建的输出。
3. 画质排序改为单一最佳候选前移，避免“未知条目返回相等”的非传递比较器，保留全部降级相对顺序。
4. 默认配置改为一次性不可变字典，减少每次视频/视图Hook重复构建开销。
5. Build IPA先校验SHA输入再取凭据；只有默认分支、明确修改权及独立费用授权才能访问私有存储。

6. macOS实际编译修复NSCAssert宏参数中的字典逗号；通知completion改为访问系统单例而非强捕获center；配置导入增加JSON对象非空类型检查。
7. 增加NUL路径和未支持Mach-O格式的fail-closed用例；CI shellcheck要求明确声明外部私有输出URI，已修复。

以上均为实际代码/检查记录，不是系统安全认证。
