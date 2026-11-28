# 龙空 HarmonyOS 客户端

龙的天空论坛（`https://www.lkong.com/`）的 **HarmonyOS NEXT 原生第三方客户端**，基于 **ArkTS / Stage 模型 / API 26** 开发并全程通过官方 GraphQL API 交互，以 **GPL-3.0** 协议开源。项目全量代码均由 AI 协作生成（零手写代码）。

---

## 1. 功能特性

### 首页与导航交互
- **底部 4 Tab 原生左右滑动**：支持「版块 / 热帖 / 常用 / 我的」手势滑动切换与点击联动，排序编辑模式下自动锁定横向滑动防止误触。
- **版块管理**：未登录即可浏览版块导航，支持常用版块置顶、置首、上移、下移与恢复默认顺序（本地 `Preferences` 持久化）。
- **全站热帖与消息角标**：支持查看全站今日热门帖子排行；顶部与「我的」Tab 实时汇总未读通知与私信数量角标。

### 版块浏览与帖子阅读
- **版块多分类滑动切换**：版块页内置「全部 / 热门（今日热门）/ 最新 / 精华」4 个 Tab，支持点选与左右滑动切换、下拉刷新、分页浏览与发新帖。
- **原生图文混排**：支持 Slate / TipTap JSON 与旧帖 HTML 中的标题、加粗/斜体/下划线/删除线、代码块、引用块、分割线、列表、龙空动态表情与自适应图片。
- **帖子详情增强**：支持引用楼层折叠/展开、楼层龙币评分展示与评分提交、`pid` 楼层精准定位高亮、只看作者、快速跳页、快捷回顶，以及识别 `lkong.com` 站内链接直接应用内打开。
- **多图看图与免权限保存**：全屏多图看图器支持 `Swiper` 左右切换、双指捏合缩放、双击放大/复位与单指拖移，通过系统安全控件 `SaveButton` 免存储写权限保存原图与 GIF 至系统相册。

### 发帖、回帖与编辑
- **统一编辑页**：支持发新帖（标题限 26 字）、回复主题、引用楼层回复与编辑本人楼层，提供实时排版预览与仅本机自动暂存草稿。
- **官方表情与相册传图**：内置 154 个龙空官方动态表情（悠嘻猴、悠嘻猴2、洋葱头、洋葱头2），通过系统安全选图器 `PhotoViewPicker` 选图并压缩上传至官方图床（GIF 原图直传）。

### 每日自动签到
- 支持首页一键手动签到与连续/累计/最高签到天数展示。
- **每日自动签到（默认开启）**：已登录状态下启动应用或跨天切回前台时自动检测并完成当日签到，可在「设置」页随时开启或关闭。

### 个人主页、云端收藏夹、搜索与私信
- **个人主页**：支持查看本人与任意坛友资料，内置「主题 / 帖子（默认展开完整图文详情与看图）/ 精华 / 收藏夹」4 个 Tab 左右滑动切换、顶部统计数字快捷跳转、关注/取关与发私信；列表卡片点击可直达原帖高亮楼层。
- **纯云端收藏夹**：直连龙空云端收藏分组接口，支持分组增改删、帖子主楼与单楼层弹窗收藏/移出、以及分组明细分页浏览。
- **综合搜索**：支持帖子（相关度/热度/最新排序、关键词高亮与游标翻页）、版块与用户搜索，保存最近搜索历史。
- **消息通知与私信**：站内通知（回复/版务/系统公告）、`@我`、我的评分、新增粉丝（快捷回关）与私信会话 5 个 Tab 左右滑动切换；独立私信聊天页支持收发文本/图片私信与删除消息。

### 个性化与登录
- **显示设置**：支持浅色 / 深色 / 跟随系统外观模式与 4 档正文字号（小 / 标准 / 大 / 特大）实时切换。
- **账号登录**：支持账号密码登录与 `twoWay` 二次动态验证码登录。

---

## 2. 编译与真机部署

### 环境要求

- **DevEco Studio**（HarmonyOS NEXT API 26 SDK）
- **Node.js**（可使用 DevEco Studio 自带版本）
- **Python 3**（可选，用于运行低 CPU 限核构建脚本）

### 方式一：开启手机开发者模式通过 `hdc install` 安装（推荐）

#### 第 1 步：开启手机开发者模式与 USB 调试

1. 在 HarmonyOS 手机上打开 **设置 → 关于本机**，连续点击 **软件版本** 多次，直至提示已开启开发者模式。
2. 返回 **设置 → 系统 → 开发者选项**，打开 **USB 调试** 开关。
3. 使用数据线将手机连接至电脑，并在手机弹窗中点击 **信任此设备**。

#### 第 2 步：配置调试签名

1. 使用 DevEco Studio 打开 `lkong-harmony/` 工程目录。
2. 如需修改包名，可先编辑 `AppScope/app.json5` 中的 `bundleName`（默认为 `com.nihaoa.lkong`）。
3. 打开菜单 **File → Project Structure → Project → Signing Configs**，登录华为开发者账号并勾选 **Automatically generate signature** 自动生成调试签名配置，点击 **Apply / OK** 保存。

#### 第 3 步：构建并安装到真机

- **图形界面直装**：在 DevEco Studio 顶部设备栏选择已连接的真机，点击 **Run** 按钮即可自动编译、签名并安装。
- **命令行构建 + `hdc install`**：

```powershell
cd lkong-harmony

# 1. 构建应用（方式 A：DevEco 命令行）
devecocli build --product default --build-mode debug

# 1. 构建应用（方式 B：低占用限 4 核构建，避免编译期间卡顿桌面）
python scripts/build_low_cpu.py --mode debug --cores 4

# 2. 确认真机已被 hdc 识别
hdc list targets

# 3. 安装已签名的调试 HAP 包到真机（-r 覆盖安装）
hdc install -r entry/build/default/outputs/default/entry-default-signed.hap
```

> 如仅用于 DevEco 本地模拟器调试，可直接安装未签名产物 `entry/build/default/outputs/default/entry-default-unsigned.hap`。

### 方式二：免开发者模式（AGC 内部测试通道）

如不便在手机开启开发者模式，也可自行完成应用签名并构建 Release APP 包，通过华为 AppGallery Connect 内部测试（AppTest）通道安装到真机。

---

## 3. 工程结构与技术架构

```text
lkong-harmony/
├─ AppScope/
│  ├─ app.json5                       # 应用包名与版本信息（当前 1.5.0 / 1005000）
│  └─ resources/base/element/string.json
├─ entry/src/main/
│  ├─ module.json5                    # 权限声明（仅 ohos.permission.INTERNET）
│  └─ ets/
│     ├─ entryability/EntryAbility.ets
│     ├─ pages/
│     │  ├─ Index.ets                 # Navigation 根容器 + 首页 4 Tab 左右滑动 + 自动签到
│     │  ├─ ForumPage.ets             # 版块页（全部/热门/最新/精华左右滑动、分页、发帖）
│     │  ├─ ThreadPage.ets            # 帖子详情、楼层定位、引用、评分、编辑、收藏、跳页
│     │  ├─ ComposePage.ets           # 发帖/回帖/引用回复/楼层编辑、表情与图床上传
│     │  ├─ NotificationsPage.ets     # 站内消息中心（5 Tab 左右滑动）
│     │  ├─ MessageChatPage.ets       # 私信聊天页
│     │  ├─ SearchPage.ets            # 综合搜索（帖子/版块/用户）
│     │  ├─ FavoritesPage.ets         # 云端收藏夹分组管理
│     │  ├─ FavoriteDetailPage.ets    # 云端收藏夹明细
│     │  ├─ UserProfilePage.ets       # 个人主页（主题/帖子/精华/收藏夹左右滑动与详情展开）
│     │  ├─ LoginPage.ets             # 账号密码与二次验证登录
│     │  └─ SettingsPage.ets          # 外观/字号设置、自动签到开关与登录态管理
│     ├─ components/                  # 通用 UI 组件（PostCard / ImageViewerOverlay / EmotionPicker 等）
│     ├─ model/Models.ets             # 领域模型与错误类型
│     ├─ network/                     # GraphQL 请求、响应解析与 800ms 串行节流客户端
│     ├─ store/                       # Cookie、外观字号、草稿、版块排序与自动签到偏好存储
│     └─ utils/                       # 路由、图文混排解析、表情序列化、内链识别与图片工具
└─ scripts/                           # 低占用限核构建与 Release 签名脚本
```

### 站点 API 与域名边界

```text
GraphQL API:  https://api.lkong.com/api
图片上传接口: POST https://images.lkong.com/upload (multipart/form-data, 字段 file)
静态资源域名: https://images.lkong.com/ 、https://image.lkong.com/
```

客户端完整对接了 `Login`、`TwoWayLogin`、`GetMe`、`GetUserPunch`、`Punch`、`ViewHotThreads`、`ViewForumHotThreads`、`ViewForumPage`、`ViewThread`、`BasePost`、`EditPost`、`Reply`、`NewThread`、`Rate`、`FollowUser`、`GetNoticeCount`、`ViewNotices`、`ViewAtMe`、`ViewRateNotice`、`ViewFansNotice`、`ViewLastUsersMessages`、`ViewUserMessages`、`SendMessage`、`SendImageMessage`、`DelMessage`、`DelUserMessage`、`SearchThreads`、`SearchForums`、`SearchUsers`、`ViewUserProfilePage`、`ViewUserThreadsPage`、`ViewUserContentsPage` 以及云端收藏夹全套 GraphQL 操作。

---

## 4. 安全、权限与开源说明

- **最小权限**：仅声明 `ohos.permission.INTERNET` 网络权限；相册选图与图片保存分别调用系统 `PhotoViewPicker` 与 `SaveButton` 安全控件，不申请本地存储读写权限。
- **凭据安全**：不保存账号密码，密码仅进入登录 GraphQL 请求体；会话凭证 `EGG_SESS` 仅持久化在本地应用沙箱 `Preferences` 中，且支持在设置页一键清除；浏览与保存官方静态图片不携带登录 Cookie。
- **合规节流**：GraphQL 与上传请求采用 Promise 链式严格串行排队并保持至少 `800ms` 最小间隔，不实现任何验证码破解、人机绕过或批量抓取。
- **当前未覆盖范围**：暂未实现书评/书单浏览模块及账号密码/绑定信息修改页面。
- **免责声明与开源协议**：本应用为龙的天空论坛的非官方第三方开源客户端，与官方无隶属或授权关系，仅提供源码供技术学习与交流；本项目采用 **GNU General Public License v3.0 (GPL-3.0)** 协议开源，版本变更历史见 [CHANGELOG.md](CHANGELOG.md)。
