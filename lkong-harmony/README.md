# 龙空 HarmonyOS 客户端

龙的天空论坛（https://www.lkong.com/）的非官方 HarmonyOS 原生第三方客户端，仅用于个人学习与本地测试，不对外分发。

## 1. 当前实现范围

客户端只使用龙空官方 GraphQL API 与官方静态图片/表情/头像域名：

- 首页底部 4 TabBar（版块 / 热帖 / 常用 / 我的）：
  - **版块**：`GetMe` → `commonNavbars`（未登录可看）+ 常用置顶与自定义排序（置顶常用、置首、上移、下移、恢复默认顺序，本地 `Preferences` 持久化）
  - **热帖**：`ViewHotThreads` → `threadsFragment(fid: 0, type: "hot")`（切入时懒加载）
  - **常用**：独立展示已置顶的常用版块，支持直接管理排序与取消置顶
  - **我的**：聚合个人主页入口、每日签到卡片、站内消息通知（含未读数角标）、我的云端收藏夹、综合搜索与显示设置
- 每日签到：登录后展示签到卡片，`GetUserPunch` 查询签到状态与连续/累计/最高天数，`Punch` 执行当日签到
- 综合搜索：`SearchThreads`（相关度/热度/最新排序、`<em>` 高亮渲染、`searchAfter` 游标加载更多）、`SearchForums`、`SearchUsers` 与最近 10 条本地搜索历史
- 纯云端收藏夹：
  - 帖子详情页主楼（`thread.first`）与各楼层支持一键弹出「选择云端收藏夹」浮层，支持勾选加入/移出及弹窗内直接新建分组
  - 独立云端收藏夹分组列表（新建 / 编辑名称与可见性 / 删除分组）与分组明细页（分页浏览、取消收藏、直达原帖与目标楼层、作者）
- 用户资料页：`ViewUserProfilePage`（合并拉取资料、等级、统计数据与第 1 页主题）与 `ViewUserThreadsPage`（主题分页）、云端收藏分组查看，全应用点击作者均可直达
- 版块帖子列表：`ViewForumPage` + `threadComponent`（支持分页、发新帖入口与作者点击）
- 帖子详情与互动：`ViewThread` + `threadComponent` + `postListComponent`
  - 按 20 楼区间计算总页数与翻页状态（兼容删楼导致的单页不足 20 条情况）
  - 支持通过 `pid` 精确定位楼层页码、自动滚动居中并高亮边框
  - 支持楼层引用块 `quote` 展示（兼容已删引用提示及长引用 3 行折叠/展开切换）
  - 支持楼层评分展示（`rate` 列表汇总龙币与明细）及弹出评分窗进行龙币评分（`Rate` mutation）
  - 支持回复主题与任意楼层引用回复（统一跳转 `ComposePage`，锁帖自动拦截）
  - 支持“只看作者 / 查看全部”筛选（传入 `$authorid`）以及点击页码弹出“快速跳页”（首页 / 末页 / 指定页码直达）
  - 原生图文混排渲染：支持 Slate/TipTap JSON 与旧帖 HTML 中的标题（含 `heading-one/two/three`）、段落、加粗/斜体/下划线/删除线/行内代码、代码块、可点击链接（弹窗查看与一键复制）、引用（含 `block-quote`）、分割线、列表、行内表情（`ImageSpan`）与正文图片（`PostImage` 自适应比例、失败重试、点击全屏预览）
- 发新帖、回帖与传图（`ComposePage`）：
  - 发新帖（标题限 26 字）与回帖/引用回复共用独立编辑页，支持一键实时预览
  - 龙空官方表情面板：收录悠嘻猴、悠嘻猴2、洋葱头、洋葱头2 共 154 个动态表情
  - 系统相册安全选图（`PhotoViewPicker`，免存储权限），超大图自动等比压缩（GIF 保持原图直传），直传 `https://images.lkong.com/upload`
  - 仅本机自动暂存草稿（`DraftPrefs`），发布成功后自动清理
- 站内消息通知（`NotificationsPage`）：
  - 接入 `GetNoticeCount` 首页未读红点角标（汇总通知 / `@我` / 评分 / 粉丝）
  - 支持站内通知（回复提醒、19 种版务操作、系统公告）、`@我`、我的评分、新增粉丝 4 个分类游标分页与直达原帖楼层
- 显示与阅读偏好：支持深色 / 浅色 / 跟随系统外观切换以及 4 档正文字号（小/标准/大/特大）持久化与实时切换
- 登录：账号密码 `Login` mutation

已删除：

- HTML 页面解析抓取；
- 官方网页登录 WebView；
- 手动导入 Cookie；
- 所有 HTML 兜底逻辑。

## 2. 站点 API 与资源规则

```text
GraphQL endpoint: https://api.lkong.com/api
图片上传接口: POST https://images.lkong.com/upload (multipart/form-data, 字段 file)
请求体: { operationName, variables, query }
登录态: Set-Cookie 中的 EGG_SESS
正文图片: https://images.lkong.com/images/{imageKey}.jpg（或节点 url/src）
行内表情: https://image.lkong.com/bq/em{id}.gif
用户头像: https://image.lkong.com/avatar/{uid}/{avatar}
版块头像: https://image.lkong.com/forumavatar/{fid}/{avatar}
```

使用的 GraphQL 操作：

| 操作 | 用途 |
|---|---|
| `Login` mutation | 账号密码登录，返回 `uid/name/twoWay/serverTime`，响应头 `Set-Cookie` 返回 `EGG_SESS` |
| `GetMe` query | 当前登录用户 `me { uid name avatar }`、`commonNavbars` 版块导航 |
| `GetUserPunch` query | 查询当前登录账号签到状态（`isPunch/punchday/punchallday/punchhighestday`） |
| `Punch` mutation | 执行今日签到，返回最新签到统计 |
| `ViewHotThreads` query | 首页今日热帖列表（`threadsFragment(fid: 0, type: "hot")`） |
| `ViewForumPage` query | 版块帖子分页 |
| `ViewThread` query | 帖子详情（含主楼 `first`、`lock` 锁帖、`$pid` 页码定位）、楼层内容、`quote` 引用与 `rate` 评分 |
| `Reply` mutation | 回帖与带 `$pid` 引用回复（`replyThread`），返回新楼层结构 |
| `NewThread` mutation | 版块发新帖（`postThread`），返回新主题 `tid` |
| `Rate` mutation | 楼层龙币评分（`rate`），返回新评分记录 |
| `GetNoticeCount` query | 查询未读消息数（`noticeCount/atmeCount/rateCount/fansCount/pmCount`） |
| `ViewNotices` / `ViewAtMe` / `ViewRateNotice` / `ViewFansNotice` query | 站内通知、`@我`、评分通知、新增粉丝游标分页查询 |
| `SearchThreads` / `SearchForums` / `SearchUsers` query | 综合搜索帖子（含排序与 `searchAfter` 分页）、版块、用户 |
| `ViewUserProfilePage` / `ViewUserThreadsPage` query | 用户资料统计与用户发布主题分页 |
| `ViewUserFavoriteGroups` / `ViewFavoriteGroup` / `MyFavoriteGroupList` query | 云端收藏夹分组列表、分组明细分页、帖子收藏归属查询 |
| `FavoritePost` / `CreateFavoriteGroup` / `EditFavoriteGroup` / `DelFavoriteGroup` mutation | 云端收藏/取消收藏及收藏分组增改删管理 |
| `threadComponent` fragment | 主题摘要 |
| `postListComponent` fragment | 楼层内容、引用结构与评分记录 |

实测校验结果：

- **未登录状态**：
  - `GetMe`：HTTP 200，`me.uid = 0`，`commonNavbars` 仍返回版块导航；
  - `ViewForumPage` / `GetUserPunch` / `ViewHotThreads` / 搜索 / 用户资料 / 收藏夹：返回 HTTP 500 + GraphQL `"你需要登录才能继续浏览"`；
- **已登录状态（携带 `EGG_SESS`）**：
  - `Login` 响应头正常返回 `Set-Cookie: EGG_SESS=...`；
  - `ViewForumPage`、`ViewThread`、`GetUserPunch` 均返回 HTTP 200；
  - `posts.pid` 为 UUID 字符串（非数字），`posts` 按固定每页 20 个楼层号区间分页（若某页存在删楼，实际返回条数可能小于 20）；
  - 正文 `content` 主要为 Slate JSON 数组，包含 `paragraph`、`emotion`（`id`）、`image`（`imageKey`）等节点；
  - 图片、表情与头像资源直连 `images.lkong.com` / `image.lkong.com` 返回 HTTP 200（无需携带 Cookie）。

## 3. 工程结构

```text
lkong-harmony/
├─ AppScope/
│  ├─ app.json5
│  └─ resources/base/element/string.json
├─ entry/
│  ├─ src/main/
│  │  ├─ module.json5                 # ohos.permission.INTERNET
│  │  ├─ ets/
│  │  │  ├─ entryability/EntryAbility.ets
│  │  │  ├─ entrybackupability/EntryBackupAbility.ets
│  │  │  ├─ pages/
│  │  │  │  ├─ Index.ets              # 底部 4 TabBar（版块/热帖/常用/我的）+ 签到、未读红点与版块排序
│  │  │  │  ├─ ForumPage.ets          # 版块帖子列表与发帖入口
│  │  │  │  ├─ ThreadPage.ets         # 帖子详情、pid定位、引用楼层、评分弹窗、云端收藏、只看作者、跳页与预览
│  │  │  │  ├─ ComposePage.ets        # 统一发新帖/回帖/引用回复页（表情面板、相册传图、预览、本地草稿）
│  │  │  │  ├─ NotificationsPage.ets  # 站内消息通知中心（通知/@我/评分/粉丝）
│  │  │  │  ├─ SearchPage.ets         # 综合搜索（帖子/版块/用户 + 排序 + 搜索历史）
│  │  │  │  ├─ FavoritesPage.ets      # 云端收藏夹分组列表与管理
│  │  │  │  ├─ FavoriteDetailPage.ets # 云端收藏夹分组明细与取消收藏
│  │  │  │  ├─ UserProfilePage.ets    # 用户资料页、主题列表与云端收藏分组
│  │  │  │  ├─ LoginPage.ets          # 账号密码登录
│  │  │  │  └─ SettingsPage.ets       # 显示阅读偏好、登录态与安全说明
│  │  │  ├─ components/
│  │  │  │  ├─ ForumCard.ets          # 版块卡片（常用徽标、编辑排序按钮）
│  │  │  │  ├─ ThreadRow.ets          # 帖子摘要行（支持版块标签与作者跳转）
│  │  │  │  ├─ PostCard.ets           # 楼层卡片（引用楼层、评分展示、富文本/表情/图片、回复/评分/收藏）
│  │  │  │  ├─ PostImage.ets          # 帖子图片块（比例自适应、失败重试、点击预览）
│  │  │  │  ├─ EmotionPicker.ets      # 龙空官方 4 分组表情选择器
│  │  │  │  ├─ ImageAttachmentBar.ets # 发帖/回帖图片附件状态与重试条
│  │  │  │  └─ StateView.ets          # 通用状态视图
│  │  │  ├─ model/Models.ets          # 领域模型、富文本块模型、通知与评分模型、错误分类
│  │  │  ├─ network/
│  │  │  │  ├─ HttpClient.ets         # GraphQL POST 与图床上传、Cookie、800ms 节流
│  │  │  │  ├─ GraphqlClient.ets      # GraphQL 请求与错误映射
│  │  │  │  ├─ GraphqlQueries.ets     # GraphQL 文档
│  │  │  │  ├─ GraphqlParser.ets      # GraphQL 响应解析
│  │  │  │  ├─ LkongApi.ets           # 数据入口与当前登录用户缓存
│  │  │  │  └─ JsonUtils.ets
│  │  │  ├─ store/
│  │  │  │  ├─ CookieStore.ets        # 会话 Cookie 存储
│  │  │  │  ├─ DisplayPrefs.ets       # 主题模式与正文字号持久化
│  │  │  │  ├─ DraftPrefs.ets         # 仅本机保存的发帖/回帖草稿缓存
│  │  │  │  └─ ForumOrderPrefs.ets    # 版块常用置顶、自定义排序与最近搜索历史
│  │  │  └─ utils/
│  │  │     ├─ AppConfig.ets          # 应用版本常量（M_mmm_ppp 对齐 app.json5）与跨页刷新键
│  │  │     ├─ AvatarUtils.ets        # 头像 URL 拼装与搜索 <em> 高亮解析
│  │  │     ├─ ContentUtils.ets       # Slate JSON / HTML 结构化块与摘要解析
│  │  │     ├─ ImageUploadUtils.ets   # 系统安全相册选图、压缩与直传封装
│  │  │     ├─ PostComposerUtils.ets  # 官网表情表、Slate JSON 序列化与版务通知文案映射
│  │  │     ├─ Theme.ets              # 浅色/深色集中式调色板与字号常量
│  │  │     └─ TimeUtils.ets
│  │  └─ resources/
│  ├─ build-profile.json5
│  └─ oh-package.json5
├─ scripts/
│  ├─ build_low_cpu.py                # 限核（默认 4 核）+ 低优先级编译脚本
│  └─ rebuild_and_sign.py             # Release APP 低占用构建与发布签名脚本
├─ sign/                              # 发布签名材料（不入库）
├─ build-profile.json5
├─ hvigorfile.ts
└─ oh-package.json5
```

## 4. 构建

环境要求：

- DevEco Studio（当前工程 API 26）；
- 可用 HarmonyOS SDK；
- Node.js（DevEco 自带即可）。

命令行构建（推荐低占用模式：默认限制最多 4 核心 + 最低优先级，关闭并行与守护进程，避免编译期间卡顿其他工作）：

```bash
cd lkong-harmony
# Debug 构建（默认 4 核、low 优先级）
python scripts/build_low_cpu.py --mode debug --cores 4

# Release 构建（或使用 python scripts/rebuild_and_sign.py 一键构建并签名）
python scripts/build_low_cpu.py --mode release --cores 4
```

也可按需调整 `--cores 2` 或 `--priority below_normal`。如需直接使用原始全速命令行构建：

```bash
cd lkong-harmony
devecocli build --product default --build-mode debug
```

产物：

```text
entry/build/default/outputs/default/entry-default-unsigned.hap
build/outputs/default/lkong-harmony-default-unsigned.app
```

Release 构建：

```bash
devecocli build --product default --build-mode release
```

## 5. 签名与真机部署

### 5.1 模拟器

未签名 HAP 可直接用于模拟器调试。

### 5.2 真机

你的约束是不开启开发者模式，因此不使用“调试签名 + hdc install”的方式，而是走 AppGallery 内部测试通道：

1. 个人实名认证的华为开发者账号；
2. 创建 HarmonyOS 应用，包名保持 `com.nihaoa.lkong`；
3. 申请发布证书 `.cer` 和发布 Profile `.p7b`；
4. 在 DevEco Studio 中配置 `signingConfigs`，构建 **APP 包**；
5. 在 AGC 上传 APP 包，使用场景选择“仅测试”；
6. 创建内部测试群组，只添加本人（或本人控制的第二个华为账号）；
7. 创建邀请测试版本，只勾选内部群组，点击“保存”（仅内部群组免审）；
8. 在手机 AppTest 客户端中接受邀请并安装。

注意：

- 测试版本安装后最多可用 90 天，到期前需要递增 `versionCode` 并重新发布测试版本。
- 版本号编码规范（自 v1.2.0 起统一）：`versionCode = M * 1000000 + m * 1000 + p`（例如 `1.2.0` → `1002000`），与 `versionName` 保持一一对应且严格高于已发版 `1.1.0` 的 `1000002`。

## 6. 登录方式

只保留账号密码 GraphQL 登录：

1. 在登录页输入邮箱/手机号和密码；
2. 客户端调用 `https://api.lkong.com/api` 的 `Login` mutation；
3. 登录成功后从响应 `Set-Cookie` 提取 `EGG_SESS`；
4. 密码不保存，登录页状态在请求结束后清空。

限制：

- 如果账号返回 `twoWay: true`（需要二次验证），当前客户端暂不支持；
- 如果登录成功但没有拿到 `EGG_SESS`，会提示稍后重试；
- 登录失败时直接显示 GraphQL 返回的错误信息，例如“账号不存在或密码错误”。

## 7. 安全提醒

- `EGG_SESS` 等 Cookie 等同于登录凭证，请勿分享给他人。
- 如果 Cookie 或密码曾在聊天、截图、日志或公开渠道中出现，建议立即修改密码并重新登录。
- 客户端不保存账号密码；密码只进入本次 GraphQL 请求体。
- 客户端 GraphQL 接口请求（及 `EGG_SESS` Cookie）只发往 `https://api.lkong.com/api`，图片上传请求（携带会话 Cookie）只发往 `https://images.lkong.com/upload`；帖子图片、行内表情与头像浏览按需从 `images.lkong.com` / `image.lkong.com` 加载（不携带登录 Cookie）。
- GraphQL 请求串行，最小间隔 800ms；不进行批量抓取。
- 不实现登录绕过、权限绕过、验证码破解或暴力破解。
- 本应用为非官方第三方客户端，仅用于个人学习与本地测试，不对外分发。

## 8. 测试清单

- [ ] 未登录启动，首页“版块”能显示 GraphQL `GetMe` 返回的版块列表，且不展示签到卡片；切换至“热帖”提示“去登录”。
- [ ] 未登录点击版块，显示“需要登录”而不是笼统的网络错误。
- [ ] 账号密码登录成功后，首页展示每日签到卡片与“我的”用户信息，点击“热帖”能加载今日热帖并跳转帖子或作者主页。
- [ ] 在首页“版块 / 常用”点击“排序”，能置顶常用版块、在置顶区/普通区内置首/上移/下移、恢复默认，且重启应用后排序与置顶保持不变。
- [ ] 未签到账号点击“签到”按钮可完成签到，状态切换为“今日已签 / 已签到”且天数实时更新。
- [ ] 登录失败时能显示 GraphQL 返回的错误信息。
- [ ] 综合搜索页支持切换“帖子 / 版块 / 用户”，帖子支持相关度/热度/最新排序、`<em>` 关键词高亮与“加载更多”，并保留最近搜索历史。
- [ ] 帖子详情页主楼「收藏主题」与楼层「收藏」可弹出云端收藏夹列表，支持新建分组、加入/移出收藏，在“我的 → 云端收藏夹”及分组明细页可完整同步查看、编辑、取消收藏与删除分组。
- [ ] 帖子详情页存在引用楼层的回复能正确渲染引用框，支持长引用展开/收起及已删除引用的降级提示。
- [ ] 点击首页“我的”或帖子/列表/搜索中的任意作者昵称能进入个人资料页，正常展示统计数据、主题分页列表与公开收藏夹。
- [ ] 存在删楼的帖子（如第 1 页不足 20 条但总回复跨页）仍可正常点击“下一页”翻页，末页自动禁用“下一页”。
- [ ] 帖子正文中的行内动态表情、图片、富文本样式及链接复制弹窗均正常显示，点击图片可进入全屏预览并关闭。
- [ ] 在帖子详情页切换“只看作者 / 查看全部”以及点击底部页码使用“首页 / 末页 / 输入页码跳转”，列表和页码状态正确更新。
- [ ] 在设置页切换“跟随系统 / 浅色 / 深色”和 4 档字号（或在详情页点“字号”），所有页面立即生效且重启后保持不变。
- [ ] 登录态失效或清除登录态后，页面提示“去登录”且隐藏用户缓存，重新登录后恢复。
- [ ] 断网时显示网络错误，点击“重试”可恢复；`twoWay` 账号提示当前客户端暂不支持。
- [ ] 在版块页点击「发帖」能进入 `ComposePage`，校验 26 字标题上限，支持插入 4 组官方表情、系统相册选图压缩上传、实时预览并成功发布跳转新帖；未发送内容在本机草稿中自动暂存。
- [ ] 在帖子详情页点击底部「回复」或楼层卡片「回复」能进入回帖/引用回复，发布后自动刷新并滚动高亮新楼层；锁帖状态自动禁用回复。
- [ ] 在帖子详情页楼层卡片能查看已有龙币评分列表，点击「评分」可提交龙币与理由并实时刷新该楼层评分展示。
- [ ] 登录后首页「我的」Tab 与顶部「消息」显示未读数量角标，进入 `NotificationsPage` 可切换查看「通知 / @我 / 评分 / 粉丝」及加载更多，点击条目能直接跳转并定位高亮到目标楼层。

## 9. 已知限制

- 当前已覆盖浏览、聚合、搜索、云端收藏与核心发帖/回帖/传图/评分/站内通知互动；暂未实现私信收发、主题编辑、书评与多图滑动看图增强。
- `twoWay` 二次验证暂不支持。
- v1.3.0 新增功能已完成代码开发与编译构建，仍需在目标模拟器/真机上进一步全流程回归验证（包含真机相册选图上传、发帖/回帖与评分实测）。
- 内部测试版本安装后 90 天过期，到期前需按 `M * 1000000 + m * 1000 + p` 递增 `versionCode` 并重新构建签名上传。
- 第三方客户端仅限个人使用，请勿公开分发，也不要使用官方商标/图标对外宣传。

## 10. 更新日志与版本规划

版本历史变更记录与后续功能排期见 [CHANGELOG.md](CHANGELOG.md)。
