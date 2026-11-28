# 发布签名材料

本目录用于存放 HarmonyOS 发布签名材料，**不要提交到公开仓库**。

当前应用：**AI 对话助手**，包名 **`com.nihaoa.aichat`**，版本 `1.2.0 / 1002000`。

## 当前文件清单

```text
sign/
├─ deepseek.p12              # 发布密钥库（沿用，别名 deepseek_key）
├─ deepseek.csr              # 证书请求文件（沿用）
├─ deepseek.cer              # 发布证书（沿用，有效期至 2029-11-21）
├─ aichatRelease.p7b         # 新包名的发布 Profile（当前使用）
├─ deepseekRelease.p7b       # 旧包名 com.nihaoa.deepseek 的 Profile（已弃用，可备份留存）
├─ keystore-password.txt     # 密钥库密码（仅本地留存）
├─ agc-icon-216.png          # AGC 应用图标（216×216）
└─ README.md
```

## 新应用申请发布 Profile

发布证书是账号级的，可以复用；**发布 Profile 与应用包名绑定，必须为新包名单独申请**。

1. 在 AppGallery Connect 创建 HarmonyOS 应用，包名 `com.nihaoa.aichat`；
2. 进入 “证书、APP ID 和 Profile” → “Profile” → “添加 Profile”；
3. 类型选择 **发布 Profile**，应用选择 `com.nihaoa.aichat`，证书选择现有的 `deepseek-release`；
4. 受限权限（ACL）不勾选（应用仅使用普通权限 `ohos.permission.INTERNET`）；
5. 提交后下载 `.p7b`，重命名为 **`aichatRelease.p7b`** 放回本目录。

> AGC 下载的文件默认名可能类似 `AI 对话助手Release.p7b`，请按上面的名字重命名，签名脚本依赖该文件名。

## 打包并签名

> 发版前确认 `build-profile.json5` 已恢复 `**/x86_64/**` 排除，签名包只含 `arm64-v8a`；否则会打入模拟器用的 x86_64 原生库，体积翻倍。

在工程根目录执行：

```bash
python scripts/rebuild_and_sign.py --cores 4
```

脚本会先执行 Release 构建，再使用本目录的材料签名，输出：

```text
build/outputs/default/deepseek-default-signed.app
```

该包用于 AGC“仅测试”内部测试分发通道上传。如果只想签名、不想重新构建，可以直接对已有的
`build/outputs/default/deepseek-default-unsigned.app` 调用 `hap-sign-tool.jar sign-app`。

## 安全要求

- `.p12`、`.cer`、`.p7b`、`keystore-password.txt` 都不要提交到 Git。
- `.p12` 或密码丢失后无法继续升级同一应用，只能重新创建应用。
- 不要把密码、Token、Cookie 或证书内容发送到聊天或公开渠道。
- `.p7b` 有有效期，过期后需要重新申请发布 Profile。
- 旧应用 `com.nihaoa.deepseek` 已弃用，其 Profile 不再使用，但证书材料继续保留复用。