# 发布签名材料

本目录用于存放 HarmonyOS 发布签名材料，**不要提交到公开仓库**。

## 已生成

| 文件 | 用途 |
|---|---|
| `lkong.p12` | 密钥库，包含公私钥对，必须备份 |
| `lkong.csr` | 证书请求文件，用于在 AGC 申请发布证书 |
| `keystore-password.txt` | 密钥库密码，必须与 `.p12` 一起备份，不要发送给他人 |

## 下一步：在 AGC 申请发布证书和发布 Profile

前提：已经在 AGC 创建 HarmonyOS 应用，包名为 `com.nihaoa.lkong`。

1. 登录 AppGallery Connect。
2. 进入“证书、APP ID 和 Profile” → “证书” → “新增证书”。
3. 证书类型选择 **发布证书**。
4. 上传 `sign/lkong.csr`。
5. 提交后下载 `.cer`，重命名为 `lkong.cer`，放回本目录。
6. 进入“Profile” → “添加 Profile”。
7. 类型选择 **发布 Profile**。
8. 选择应用 `com.nihaoa.lkong` 和刚申请的发布证书。
9. 提交后下载 `.p7b`（实际文件名可能是 `lkongRelease.p7b`），放回本目录；签名时使用实际文件名。

完成后目录应包含：

```text
sign/
├─ lkong.p12
├─ lkong.csr
├─ lkong.cer
├─ lkongRelease.p7b
├─ keystore-password.txt
└─ README.md
```

## 已签名 APP

当前发布签名的 APP 包位于：

```text
build/outputs/default/lkong-harmony-default-signed.app
```

该包使用发布证书和发布 Profile 签名，可用于 AGC“仅测试”软件包上传。

## 安全要求

- `.p12`、`.cer`、`.p7b`、`keystore-password.txt` 都不要提交到 Git。
- `.p12` 或密码丢失后无法继续升级同一个应用，只能重新创建应用。
- 不要把密码、Cookie 或证书内容发送到聊天/公开渠道。
- `.p7b` 有有效期，过期后需要重新申请发布 Profile。