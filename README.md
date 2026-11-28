# HarmonyOS NEXT 原生客户端合集

本仓库（`diqiuonline/hongmeng`）收录基于 **HarmonyOS NEXT（API 26 / Stage 模型 / ArkTS）** 开发的个人原生第三方客户端项目，采用 **GNU General Public License v3.0 (GPL-3.0)** 协议开源。

---

## 1. 项目一览

| 目录 | 应用名称 | 包名（`bundleName`） | 当前版本 | 简介 | 文档 |
|---|---|---|---|---|---|
| `lkong-harmony/` | 龙空 HarmonyOS 客户端 | `com.nihaoa.lkong` | `1.5.0`（`1005000`） | 龙的天空论坛非官方原生客户端，基于官方 GraphQL API 实现首页/版块/主页/通知全站多 Tab 左右滑动、版块排序与今日热门、每日自动签到、综合搜索、云端收藏夹、富文本/动态表情/图片渲染与保存、发帖/回帖/编辑/传图、龙币评分、个人帖子详情与站内私信 | [详细文档](./lkong-harmony/README.md) · [更新日志](./lkong-harmony/CHANGELOG.md) |
| `deepseek/` | AI 对话助手 | `com.nihaoa.aichat` | `1.0.0`（`1000000`） | 原生第三方 AI 对话客户端，直连网页端协议，支持纯 ArkTS + `taskpool` 并行求解 `DeepSeekHashV1` PoW、流式 SSE JSON-Patch 解析、多分支消息树、Markdown / 代码块 / LaTeX 公式渲染及图片/文档 OCR 上传 | [详细文档](./deepseek/README.md) |

---

## 2. 目录结构

```text
hongmeng/
├─ deepseek/          # AI 对话助手（com.nihaoa.aichat）
├─ lkong-harmony/     # 龙空 HarmonyOS 客户端（com.nihaoa.lkong）
├─ AGENTS.md          # 工作区低 CPU 限核构建规范
├─ LICENSE            # GNU General Public License v3.0
└─ README.md
```

---

## 3. 环境要求与构建指南

### 3.1 基础环境

- **DevEco Studio**（HarmonyOS NEXT API 26 SDK）
- **OHPM**（OpenHarmony Package Manager）
- **Node.js**（可使用 DevEco Studio 自带版本）
- **Python 3**（用于执行低占用构建与签名脚本）

### 3.2 低优先级限核构建

为避免编译期间占满全部 CPU 核心，本工作区默认采用 **低优先级 + 4 核心限制** 的构建方式（详见 [AGENTS.md](./AGENTS.md)）：

#### 龙空 HarmonyOS 客户端（`lkong-harmony/`）

```powershell
cd lkong-harmony
# Debug 构建（默认 4 核、低优先级）
python scripts/build_low_cpu.py --mode debug --cores 4

# Release 构建并发布签名
python scripts/rebuild_and_sign.py --cores 4
```

#### AI 对话助手（`deepseek/`）

```powershell
cd deepseek/entry
ohpm install
```

`deepseek/` 的 ABI 架构过滤、发布签名与详细构建说明请参考 [deepseek/README.md](./deepseek/README.md)，低 CPU 限核构建方式请遵循 [AGENTS.md](./AGENTS.md)。

> [!NOTE]
> 本仓库不包含任何签名材料。调试真机建议直接开启手机开发者模式配合 DevEco Studio 调试签名与 `hdc install` 安装（见各子项目 README）；若需免开发者模式安装，也可自行签名后通过 AppGallery Connect 内部测试（AppTest）通道安装。

---

## 4. 免责与合规声明

- 本仓库中的所有应用均为**非官方第三方客户端**，与 DeepSeek、龙的天空（`lkong.com`）官方没有任何隶属、授权或合作关系，亦不主张任何第三方商标权。
- 本仓库仅分享源码以供 HarmonyOS NEXT / ArkTS 技术学习与交流参考，**不提供预编译安装包**。
- 登录凭证（如 `userToken`、`Cookie`、`EGG_SESS`）仅保存在本地应用沙箱 `Preferences` 中；客户端不实现任何验证码破解、人机验证绕过或批量抓取功能。
- 任何人获取、编译或运行本仓库代码时，须自行遵守目标服务平台的使用条款及相关法律法规，并自行承担使用风险。

---

## 5. 开源协议

Copyright (C) 2026 diqiuonline

本项目整体采用 **GNU General Public License v3.0 (GPL-3.0)** 协议开源，完整协议文本见 [LICENSE](./LICENSE)：

- 你可以自由地使用、学习、修改和再分发本项目的源代码或衍生作品；
- 如果你分发经过修改的版本或基于本项目构建的衍生程序，**必须同样以 GPL-3.0 协议开源并公开对应源码**，且保留原作者版权与协议声明；
- 本软件按“现状（AS IS）”提供，不附带任何明示或暗示的担保，作者不对使用过程中产生的任何直接或间接损失承担责任。

### 第三方开源依赖致谢

子项目引入的第三方开源库（包括但不限于 `@luvi/lv-markdown-in`、`@cangjie-tpc/formula_hybrid`、`@cangjie-tpc/prism_hybrid` 等）均各自遵循其原协议（`MIT` / `Apache-2.0`，均与 `GPL-3.0` 兼容）。
