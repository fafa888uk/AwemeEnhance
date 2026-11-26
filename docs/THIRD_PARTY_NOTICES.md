# 第三方声明与依赖清单

本次未复制或编入第三方增强插件源码、资源或二进制。原创运行时代码采用根目录 MIT，不代表抖音或其他项目的许可。方法名/类名研究不等于拥有目标应用版权或分发授权。

## 仅研究，未集成

| 项目 / 作者 | 审查版本 | 许可记录与取舍 |
|---|---|---|
| [DYYY / huami1314](https://github.com/huami1314/DYYY) | `9f356609cfe66a47a9c03388dfe2e5b64f9e0726` | LICENSE 为 MIT，Copyright 2024 huami；README 另有非商业/24小时说明，保守起见不整段移植。仅记录接口证据。 |
| [DouYinPlus / xiaoleGun](https://github.com/xiaoleGun/DouYinPlus) | `9913ccd9a61545afbade4193b4e682573b4f7c06` | MIT + Commons Clause，新增/修改部分有额外限制；不是纯 MIT。不并入原创 MIT 代码。 |
| [douyin-auto-fire / cong120](https://github.com/cong120/douyin-auto-fire) | `a517c41d89b4db6763affd47a82ea43052198916` | MIT；Python/Playwright 与登录态管理，非 iOS 原生插件；不导入其凭据、发送及浏览器逻辑。 |
| [douyin-spark / Xiaowu-0916](https://github.com/Xiaowu-0916/douyin-spark) | `02f8485013a95c1b2ae884920b2f14889b273926` | MIT；Python/FastAPI/Playwright；不移植自动发送或随机化流程。 |
| [DouYinSparkFlow / 2061360308](https://github.com/2061360308/DouYinSparkFlow) | `81f3daa0d3f2d5d947dfbae3f6cebc2f6d657ca8` | LICENSE 为 MIT，但 README 存在额外用途声明；浏览器及 humanize 依赖不符合本项目路线，不集成。 |
| [DouYinSparkFlow / UoUoio](https://github.com/UoUoio/DouYinSparkFlow) | 当日 GitHub API/直接页面返回404；搜索仍有旧索引 | 原仓库当前可访问性、许可和分叉链未完全核实，不集成、不假定与另一仓库同一作者。 |
| AutoMessagePlugin / com.xuegao.automessage | 未核实 | 只发现插件分发线索，未取得可核验的作者原始源码及许可证，禁止引入。 |

## 构建与测试工具（不捆绑进运行时）

- [Theos](https://github.com/theos/theos)：锁定提交见 dependencies.lock.json；包含不同许可证的子组件，遵循其 [LICENSE.md](https://github.com/theos/theos/blob/master/LICENSE.md) 及固定子模块的各自声明。不重新许可这些工具。
- Xcode / Apple SDK：仅使用标准 macOS Runner 自带 SDK，不上传或镜像 SDK。
- [PyYAML](https://github.com/yaml/pyyaml)：MIT，dev-only，版本及 SHA256 锁在 requirements-dev.txt；不属于插件运行时。
- [actionlint](https://github.com/rhysd/actionlint)：MIT，CI 使用固定 Go module 版本。
- GitHub Actions 官方 actions/checkout、setup-python、upload-artifact；github/codeql-action；aws-actions/configure-aws-credentials：固定到提交，分别遵循其仓库许可证；均非插件内嵌代码。Dependabot 仅提议更新。
- AWS CLI：仅可选私有 I/O 工具，由用户已有环境或私有构建 Runner 提供；不捆绑、不创建云资源。

未来如复制第三方文件，必须在提交前增加 `licenses/<项目>/` 的**完整原始许可证和作者声明**、来源及固定提交，逐文件标注修改。不得只写一句致谢替代许可证，不得将附加限制移除后标成 MIT。
