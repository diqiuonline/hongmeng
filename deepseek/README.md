# AI 对话助手（`com.nihaoa.aichat`）

基于 HarmonyOS NEXT（API 26 / Stage 模型 / ArkTS）开发的原生第三方 AI 对话客户端，直连第三方 AI 对话服务网页端（`https://chat.deepseek.com/api/v0/*`），不使用付费 API Key。应用由个人开发者独立开发，**仅用于本人学习与日常使用，不对外分发、不公开上架**。

当前版本：**1.0.0（versionCode 1000000）**。

---

## 1. 架构与技术栈

采用 **原生 ArkUI + 直连网页端协议 + 嵌入式 ArkWeb 登录/应急兜底**：

- **原生界面与交互**：手机端抽屉侧边栏 / 平板与折叠屏双栏自适应布局、浅色与深色双套主题、阅读字号切换。
- **网页端协议直连**：
  - `AuthStore` 持久化网页端 `userToken`（Bearer Token）与会话 Cookie；
  - `PowSolver` + `PowKeccak` 实现纯 ArkTS 32-bit split `Keccak-f[1600]` 与 **`DeepSeekHashV1`**（跳过 round 0，仅执行 rounds 1~23），通过 `@kit.ArkTS` `taskpool` 多线程并行求解 `X-Ds-Pow-Response`；
  - `DeepSeekHttp` 基于 `@kit.NetworkKit` `http.requestInStream` + `util.TextDecoder` 实现 UTF-8 分片流式接收，严格校验 `https://chat.deepseek.com` 域名白名单；
  - `SsePatchParser` 实现网页端 JSON-Patch（`p` / `o` / `v` 状态树增量、`APPEND`/`SET`/`BATCH`、隐式路径延续、`ready`/`title`/`close` 事件）与 `THINK` / `SEARCH` / `RESPONSE` 分片解析；
  - `MessageTreeUtils` 还原 `messageId` / `parentId` 多分支消息树（编辑提问与重新生成切换 `< 1/2 >`）。
- **Markdown 与公式渲染**：通过 OHPM 引入 `@luvi/lv-markdown-in`（`^3.4.7`），支持流式 Markdown、表格、代码块高亮与一键复制、LaTeX 数学公式、文本划词复制及 `[citation:N]` 联网引用角标点击。
- **多媒体**：拍照（`@kit.CameraKit` `cameraPicker`）、相册（`PhotoViewPicker`）、本地文档（`DocumentViewPicker`）上传及 OCR 状态轮询。以上均使用系统 Picker，无需额外声明相机或媒体权限。
- **网页登录与风控兜底**：内置 `ArkWeb` 网页登录页（支持手机号验证码、微信、密码登录及人机校验）和应急网页版，同步 `localStorage.userToken` 与 Cookie 至原生客户端。
- **权限**：仅申请 `ohos.permission.INTERNET`。**不包含语音输入、麦克风、相机、位置等敏感权限**。

---

## 2. 网页端接口清单（`https://chat.deepseek.com/api/v0`）

| 接口 | 用途 |
|---|---|
| `GET /users/current` | 获取当前用户信息与校验凭证 |
| `POST /users/login` | 账号密码直登 |
| `GET /chat_session/fetch_page` | 分页拉取历史会话（按今天 / 7 天内 / 30 天内 / 年月分组） |
| `POST /chat_session/create` | 创建新会话（使用 `agent: "chat"`，兼容嵌套响应与旧版参数回退） |
| `POST /chat_session/update_title` | 重命名会话 |
| `POST /chat_session/delete` / `delete_all_sessions` | 删除单条或清空全部云端会话 |
| `GET /chat/history_messages` | 拉取会话消息树与历史分片 |
| `POST /chat/create_pow_challenge` | 获取 `DeepSeekHashV1` PoW 挑战 |
| `POST /chat/completion` | 流式对话（自动跟随当前默认模型，携带 `thinking_enabled` / `search_enabled` / `ref_file_ids` / `parent_message_id` / `client_stream_id` / `preempt`） |
| `POST /chat/regenerate` | 基于指定 `message_id` 重新生成流式回复（新分支） |
| `POST /chat/stop_stream` | 中断正在生成的流 |
| `POST /file/upload_file` + `GET /file/fetch_files` | 上传图片/文档并轮询 OCR 解析结果 |
| `POST /share/create` | 生成分享链接 |
| `POST /chat/message_feedback` | 提交点赞 / 点踩反馈 |

---

## 3. 工程结构

```text
deepseek/
├─ AppScope/
│  ├─ app.json5                        # bundleName: com.nihaoa.aichat, 1.0.0 / 1000000
│  └─ resources/
├─ entry/
│  ├─ oh-package.json5                 # @luvi/lv-markdown-in
│  └─ src/main/
│     ├─ module.json5                  # 仅 INTERNET 权限
│     └─ ets/
│        ├─ entryability/EntryAbility.ets
│        ├─ entrybackupability/EntryBackupAbility.ets
│        ├─ pages/
│        │  ├─ Index.ets               # 抽屉/双栏主对话界面
│        │  ├─ LoginPage.ets           # ArkWeb 登录 + 账号密码登录
│        │  ├─ SettingsPage.ets        # 外观、字号、默认偏好、数据与安全声明
│        │  └─ WebFallbackPage.ets     # 应急网页版 / 引用外链阅读 / 凭证同步
│        ├─ components/
│        │  ├─ SessionDrawer.ets       # 会话搜索、时间分组、重命名/删除
│        │  ├─ ChatInputBar.ets        # 深度思考/联网开关、附件、发送/停止
│        │  ├─ MessageBubble.ets       # 气泡、分支切换、操作栏
│        │  ├─ ThinkingCard.ets        # 深度思考折叠卡片
│        │  ├─ SearchResultSheet.ets   # 联网搜索来源胶囊与半模态列表
│        │  ├─ MarkdownView.ets        # @luvi/lv-markdown-in 封装与引用角标处理
│        │  ├─ AttachmentPicker.ets    # 拍照 / 相册 / 文档选择器
│        │  └─ StateView.ets           # 通用状态视图
│        ├─ model/
│        │  ├─ ApiErrors.ets           # 错误枚举与映射
│        │  └─ ChatModels.ets          # 会话、消息树、分片、附件、PoW 模型
│        ├─ network/
│        │  ├─ DeepSeekApi.ets         # 网页端全部业务接口封装
│        │  ├─ DeepSeekHttp.ets        # 域名白名单、multipart 上传、requestInStream
│        │  ├─ PowKeccak.ets           # 32-bit split Keccak-f[1600]
│        │  ├─ PowSolver.ets           # DeepSeekHashV1 + taskpool 并行求解
│        │  ├─ SsePatchParser.ets      # SSE + JSON-Patch 状态机
│        │  └─ JsonUtils.ets           # ArkTS 严格类型安全 JSON 工具
│        ├─ store/
│        │  ├─ AuthStore.ets           # Preferences 持久化 Token / Cookie
│        │  └─ SettingsStore.ets       # 主题、字号、默认开关持久化
│        └─ utils/
│           ├─ AppConfig.ets
│           ├─ ClipboardUtils.ets
│           ├─ MessageTreeUtils.ets
│           └─ TimeUtils.ets
├─ scripts/
│  └─ rebuild_and_sign.py              # Release 构建与发布签名脚本
├─ sign/
│  └─ README.md                        # AGC 发布证书与内测流程
├─ build-profile.json5                 # API 26、仅打包 arm64-v8a
└─ hvigorfile.ts
```

---

## 4. 构建、签名与内测

### 4.1 依赖安装与构建

环境要求：DevEco Studio（API 26 SDK）、OHPM、Node.js。

```bash
# 1. 安装 OHPM 依赖
cd entry
ohpm install

# 2. 构建 Debug HAP（仅 arm64 真机；模拟器需临时移除 x86_64 排除配置）
cd ..
devecocli build --product default --build-mode debug

# 3. 构建 Release APP
devecocli build --product default --build-mode release
```

### 4.2 包体积与 ABI

- `build-profile.json5` 的产品级 `buildOption.nativeLib.filter.excludes` 已排除 `**/x86_64/**`，Release 包只包含 `arm64-v8a`；
- 当前下载包约 **6.2 MB**，HAP 解压约 **18.2 MB**；
- 体积主要来自 `@luvi/lv-markdown-in` 依赖的 LaTeX / 代码高亮原生库（`liblatex.so`、`libcangjie-*`、`libc++_shared.so` 等），业务字节码仅约 1 MB；
- 如需在 x86_64 模拟器调试，临时移除 `nativeLib.filter.excludes` 中的 `**/x86_64/**` 后重新构建。

### 4.3 不开启开发者模式的真机部署（AGC 仅测试）

1. 在 AppGallery Connect 创建 HarmonyOS 应用，包名 **`com.nihaoa.aichat`**（创建后不可修改），应用名称 `AI 对话助手`；
2. 复用现有发布证书 `sign/deepseek.cer` / `deepseek.p12`，为新应用申请**新的发布 Profile**，下载后命名为 `sign/aichatRelease.p7b`（详见 [sign/README.md](sign/README.md)）；
3. 运行签名脚本：

   ```bash
   python scripts/rebuild_and_sign.py
   ```

   输出：`build/outputs/default/deepseek-default-signed.app`；
4. 在 AGC 上传应用图标 `sign/agc-icon-216.png`，隐私声明中**只声明网络权限，不要勾选麦克风**；
5. 上传签名包，发布范围选“仅测试”，测试群组只添加开发者本人；
6. 手机端通过 AppTest / 应用市场“我的 → 应用测试”接受邀请安装；
7. 内测包自安装起 **90 天有效**，到期前递增 `versionCode` 重新构建上传；同一 versionCode 不可重复上传。

---

## 5. 安全与合规声明

- `userToken` 与 `Cookie` 等同于账号登录凭证，仅存储于本机 `Preferences` 沙箱，不写入日志，不发送到 `chat.deepseek.com` 以外任何服务器。
- 不实现任何验证码破解、人机绕过或批量抓取；若遇风控验证，客户端引导用户在网页组件中自行完成校验后同步凭证。
- 应用名称、图标均为中性设计，不使用第三方商标；本项目为非官方第三方客户端，仅限个人学习与本地测试，请勿公开分发或上架。
- 敏感操作（删除会话、清空会话、清除登录态）均有二次确认。

---

## 6. 测试清单

- [ ] **登录与同步**：在 `LoginPage` 通过网页登录（手机号验证码 / 微信 / 密码）成功，自动提取 `userToken` 与 Cookie，返回首页拉取历史会话与当前用户信息。
- [ ] **时间分组与管理**：侧边栏按“今天 / 7 天内 / 30 天内 / 年月”分组展示，支持关键词搜索、上拉分页、重命名与删除对话。
- [ ] **PoW 与流式对话**：开启/关闭“深度思考”与“智能搜索”发送消息，成功求解 `DeepSeekHashV1` 并流式展示思考计时、思考内容、搜索来源胶囊与 Markdown / 代码块 / LaTeX 公式。
- [ ] **流式控制与分支切换**：生成中点击停止按钮成功中断；点击“重新生成”与“编辑历史提问”产生新分支，支持 `< 1/2 >` 切换分支。
- [ ] **联网引用**：点击“已搜索到 N 个网页”弹出参考来源抽屉；点击正文 `[N]` 引用角标可直接打开对应网页来源。
- [ ] **附件 OCR**：通过拍照、相册选图、本地文档上传文件并等待 OCR 解析完成，附带 `ref_file_ids` 提问。
- [ ] **分享、反馈与设置**：支持点赞/点踩、生成分享链接、系统深色模式/字号切换、应急网页版与清除登录态。
- [ ] **权限检查**：首次启动及全流程不出现麦克风、相机、位置等敏感权限弹窗；应用信息中仅有网络权限。

---

## 7. 版本记录

- **1.0.0（1000000）**：新应用基线，包名 `com.nihaoa.aichat`；移除语音输入与麦克风权限；Release 仅打包 `arm64-v8a`；更换为中性图标。