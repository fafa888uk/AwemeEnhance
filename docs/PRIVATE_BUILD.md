# 完整 IPA 的私有构建与交付

## 无外部存储费用路径（首选）

1. 使用本仓库公开 Build 的原创 `AwemeEnhance.dylib`，核对 `SHA256SUMS.txt`。
2. 提供你有修改权限的原始41.3.0 IPA本地绝对路径；先独立计算/核对其SHA256。无需经聊天上传635.7 MB文件。
3. 运行 README 的 `python tools/ipa.py ...` 命令。也可先加 `--inspect-only` 检查输入。
4. 输出位于你指定的新路径：`AwemeEnhance_41.3.0.ipa`、`AwemeEnhance_41.3.0.report.json`、`SHA256SUMS.txt`。均应留在 `private/` 或仓库外。
5. 工具不代签名、不操作Apple账户；下一步由你签名与真机测试。

Windows PowerShell 示例（先用已通过CI且核对过的dylib）：

```powershell
$source = 'D:\Private\Douyin_41.3.0.ipa'
$digest = (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash.ToLowerInvariant()
python tools/ipa.py --ipa $source --version 41.3.0 `
  --dylib 'D:\Private\AwemeEnhance.dylib' `
  --output 'private\output\AwemeEnhance_41.3.0.ipa' `
  --expected-sha256 $digest --acknowledge-modification-rights
```

此处即时计算的hash用于检测后续读写变化，不独立证明文件来自官方；来源真实性仍需你保留获得授权的证据或可信校验来源。工具不会以文件名推断版本。

## 用户现有私有 S3（可选，并非默认零费用）

S3请求/流量/存储可能产生费用。当前任务未启用任何云资源或付费服务。未选中独立费用授权输入时，**Build IPA 的云作业会被跳过**。若必须完全无云费用，始终使用上面的本地路径，不点击此授权。

使用前由用户在已有账户完成配置；本项目不自动创建桶、IAM角色或收费资源：

- 存储桶四项公共访问阻止全部开启，输出不对外分享；建议短生命周期自动删除完整IPA。
- OIDC信任仅允许 `repo:fafa888uk/AwemeEnhance:environment:private-ipa`，不要允许任意分支或其他仓库。
- 建立 GitHub Environment `private-ipa`，限制默认分支，配置需要审查者的批准；使用可配置此保护的账户，不规避GitHub保护限制。
- Secrets：`AWS_ROLE_TO_ASSUME`、`SOURCE_IPA_S3_URI`、`OUTPUT_IPA_S3_URI`（完整对象URI，不是预签名URL）。Variable：`AWS_REGION`。
- 角色只允许读取具体输入对象、向具体输出前缀写入、读取这两个桶的PublicAccessBlock配置；不授予ListAllMyBuckets、删除、建桶或改策略权限。
- 原文件SHA256独立保留，并在 Run workflow 填写。

IAM策略示意（替换占位；不是已部署策略）：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect":"Allow","Action":"s3:GetBucketPublicAccessBlock","Resource":["arn:aws:s3:::YOUR-INPUT-BUCKET","arn:aws:s3:::YOUR-OUTPUT-BUCKET"]},
    {"Effect":"Allow","Action":"s3:GetObject","Resource":"arn:aws:s3:::YOUR-INPUT-BUCKET/authorized/source.ipa"},
    {"Effect":"Allow","Action":["s3:PutObject","s3:AbortMultipartUpload"],"Resource":"arn:aws:s3:::YOUR-OUTPUT-BUCKET/private-builds/*"}
  ]
}
```

若组织有KMS策略或账户级额外限制，必须由用户授权管理员配置，工具不会扩大权限。输出使用SSE AES256；需强制KMS的桶当前不适用这个入口，应改造并审查后使用。

### Run workflow

选择 **Build IPA** → 默认分支 → `41.3.0` → 源SHA256 → 修改权限确认 → 如你允许存储可能费用才勾选费用授权。作业先重建并测试原创模块，再通过OIDC读取指定输入、核查哈希和版本、集成并私有上传完整IPA与报告和校验。没有public upload-artifact、cache、release步骤；临时IPA总在作业末清除。公开日志只输出结构性检查，不打印URI、私钥或应用内容。

对象key由用户显式指定；请使用每次构建独立输出key。现有工具会按该key上传，S3对象版本化/覆盖策略由桶策略决定，不能把它当成自动备份。传输使用你现有账户权限，不替你授权第三方内容分发。

## 输入不满足条件时

- 加密IPA：停止；不解密、不修补加密标志。
- 版本/Bundle ID/架构不符：停止；不修改版本号冒充41.3.0。
- 含未知依赖、ABI冲突或头部空间不足：停止并在私有报告中分析；不下载未知库、不强制重定位。
- 原文件完整性或来源存疑：不进行安全背书，仅hash不等于无恶意。
- 未签名的完整IPA不是“可直接安装成品”，必须按签名说明完成下一步。
