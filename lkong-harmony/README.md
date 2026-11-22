# 龙空 HarmonyOS 客户端

龙的天空论坛（https://www.lkong.com/）的非官方 HarmonyOS 原生第三方客户端，仅用于个人学习与本地测试，不对外分发。

## 1. 当前实现范围

客户端只使用龙空官方 GraphQL API 与官方静态图片/表情域名：

- 首页版块：`GetMe` → `commonNavbars`（未登录可看）
- 每日签到：登录后首页展示签到卡片，`GetUserPunch` 查询签到状态与连续/累计/最高天数，`Punch` 执行当日签到
- 版块帖子列表：`ViewForumPage` + `threadComponent`（支持分页）
- 帖子详情与楼层：`ViewThread` + `threadComponent` + `postListComponent`
  - 按 20 楼区间计算总页数与翻页状态（兼容删楼导致的单页不足 20 条情况）
  - 支持“只看作者 / 查看全部”筛选（传入 `$authorid`）以及点击页码弹出“快速跳页”（首页 / 末页 / 指定页码直达）
  - 原生图文混排渲染：支持 Slate/TipTap JSON 与旧帖 HTML 中的标题、段落、加粗/斜体/下划线/删除线/行内代码、代码块、可点击链接（弹窗查看与一键复制）、引用、分割线、列表、行内表情（`ImageSpan`）与正文图片（`PostImage` 自适应比例、失败重试、点击全屏预览）
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
请求体: { operationName, variables, query }
登录态: Set-Cookie 中的 EGG_SESS
正文图片: https://images.lkong.com/images/{imageKey}.jpg（或节点 url/src）
行内表情: https://image.lkong.com/bq/em{id}.gif
```

使用的 GraphQL 操作：

| 操作 | 用途 |
|---|---|
| `Login` mutation | 账号密码登录，返回 `uid/name/twoWay/serverTime`，响应头 `Set-Cookie` 返回 `EGG_SESS` |
| `GetMe` query | 当前用户、`commonNavbars` 版块导航 |
| `GetUserPunch` query | 查询当前登录账号签到状态（`isPunch/punchday/punchallday/punchhighestday`） |
| `Punch` mutation | 执行今日签到，返回最新签到统计 |
| `ViewForumPage` query | 版块帖子分页 |
| `ViewThread` query | 帖子详情、楼层 |
| `threadComponent` fragment | 主题摘要 |
| `postListComponent` fragment | 楼层内容 |

实测校验结果：

- **未登录状态**：
  - `GetMe`：HTTP 200，`me.uid = 0`，`commonNavbars` 仍返回版块导航；
  - `ViewForumPage` / `GetUserPunch`：HTTP 500，GraphQL `errors[0].message = "你需要登录才能继续浏览"`；
- **已登录状态（携带 `EGG_SESS`）**：
  - `Login` 响应头正常返回 `Set-Cookie: EGG_SESS=...`；
  - `ViewForumPage`、`ViewThread`、`GetUserPunch` 均返回 HTTP 200；
  - `posts.pid` 为 UUID 字符串（非数字），`posts` 按固定每页 20 个楼层号区间分页（若某页存在删楼，实际返回条数可能小于 20）；
  - 正文 `content` 主要为 Slate JSON 数组，包含 `paragraph`、`emotion`（`id`）、`image`（`imageKey`）等节点；
  - 图片与表情资源直连 `images.lkong.com` / `image.lkong.com` 返回 HTTP 200（无需携带 Cookie）。

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
│  │  │  │  ├─ Index.ets              # 首页版块 + 每日签到卡片
│  │  │  │  ├─ ForumPage.ets          # 版块帖子列表
│  │  │  │  ├─ ThreadPage.ets         # 帖子详情、只看作者、跳页、字号与图片/链接弹窗
│  │  │  │  ├─ LoginPage.ets          # 账号密码登录
│  │  │  │  └─ SettingsPage.ets       # 显示阅读偏好、登录态与安全说明
│  │  │  ├─ components/
│  │  │  │  ├─ ForumCard.ets          # 版块卡片
│  │  │  │  ├─ ThreadRow.ets          # 帖子摘要行
│  │  │  │  ├─ PostCard.ets           # 楼层卡片（富文本样式/链接/表情/图片）
│  │  │  │  ├─ PostImage.ets          # 帖子图片块（比例自适应、失败重试、点击预览）
│  │  │  │  └─ StateView.ets          # 通用状态视图
│  │  │  ├─ model/Models.ets          # 领域模型、富文本块模型、错误分类
│  │  │  ├─ network/
│  │  │  │  ├─ HttpClient.ets         # GraphQL POST、Cookie、800ms 节流
│  │  │  │  ├─ GraphqlClient.ets      # GraphQL 请求与错误映射
│  │  │  │  ├─ GraphqlQueries.ets     # GraphQL 文档
│  │  │  │  ├─ GraphqlParser.ets      # GraphQL 响应解析
│  │  │  │  ├─ LkongApi.ets           # 数据入口
│  │  │  │  └─ JsonUtils.ets
│  │  │  ├─ store/
│  │  │  │  ├─ CookieStore.ets        # 会话 Cookie 存储
│  │  │  │  └─ DisplayPrefs.ets       # 主题模式与正文字号持久化
│  │  │  └─ utils/
│  │  │     ├─ AppConfig.ets
│  │  │     ├─ ContentUtils.ets       # Slate JSON / HTML 结构化块解析
│  │  │     ├─ Theme.ets              # 浅色/深色集中式调色板与字号常量
│  │  │     └─ TimeUtils.ets
│  │  └─ resources/
│  ├─ build-profile.json5
│  └─ oh-package.json5
├─ scripts/
│  └─ rebuild_and_sign.py             # Release APP 构建与发布签名脚本
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

命令行构建：

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

注意：测试版本安装后最多可用 90 天，到期前需要递增 `versionCode` 并重新发布测试版本。

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
- 客户端 GraphQL 接口请求（及 `EGG_SESS` Cookie）只发往 `https://api.lkong.com/api`；帖子图片和行内表情按需从 `images.lkong.com` / `image.lkong.com` 加载（不携带登录 Cookie）。
- GraphQL 请求串行，最小间隔 800ms；不进行批量抓取。
- 不实现登录绕过、权限绕过、验证码破解或暴力破解。
- 本应用为非官方第三方客户端，仅用于个人学习与本地测试，不对外分发。

## 8. 测试清单

- [ ] 未登录启动，首页能显示 GraphQL `GetMe` 返回的版块列表，且不展示签到卡片。
- [ ] 未登录点击版块，显示“需要登录”而不是笼统的网络错误。
- [ ] 账号密码登录成功后，首页/版块页能加载登录后的数据，并在首页显示每日签到卡片。
- [ ] 未签到账号点击首页“签到”按钮可完成签到，状态切换为“今日已签 / 已签到”且天数实时更新。
- [ ] 登录失败时能显示 GraphQL 返回的错误信息。
- [ ] 版块列表点击后能进入帖子详情并完整显示当页全部楼层。
- [ ] 存在删楼的帖子（如第 1 页不足 20 条但总回复跨页）仍可正常点击“下一页”翻页，末页自动禁用“下一页”。
- [ ] 帖子正文中的行内动态表情与图片能正常显示，点击图片可进入全屏预览并关闭；图片加载失败支持点击重试。
- [ ] 在帖子详情页切换“只看作者 / 查看全部”以及点击底部页码使用“首页 / 末页 / 输入页码跳转”，列表和页码状态正确更新。
- [ ] 帖子正文中的加粗/斜体/代码/代码块及可点击链接渲染正常，点击链接可弹窗查看完整 URL 并一键复制。
- [ ] 在设置页切换“跟随系统 / 浅色 / 深色”和 4 档字号（或在详情页点“字号”），所有页面立即生效且重启后保持不变。
- [ ] 登录态失效时，页面提示“去登录”，重新登录后能恢复。
- [ ] 设置页能清除登录态，清除后版块页重新提示登录、首页隐藏签到卡片。
- [ ] 断网时显示网络错误，点击“重试”可恢复。
- [ ] GraphQL 返回错误时能显示服务器 message，不崩溃。
- [ ] `twoWay` 账号会提示当前客户端暂不支持。

## 9. 已知限制

- 当前定位为浏览与签到客户端，暂未实现发帖、回帖、评分、搜索、收藏与私信功能。
- `twoWay` 二次验证暂不支持。
- 图片、行内表情、每日签到与删楼翻页修复已完成代码构建，部分交互仍需在目标模拟器/真机上进一步全流程回归。
- 内部测试版本安装后 90 天过期，到期前需递增 `versionCode` 并重新构建签名上传。
- 第三方客户端仅限个人使用，请勿公开分发，也不要使用官方商标/图标对外宣传。

## 10. 更新日志与版本规划

版本历史变更记录与后续功能排期见 [CHANGELOG.md](CHANGELOG.md)。