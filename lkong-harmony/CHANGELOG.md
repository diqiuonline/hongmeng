# 更新日志（Changelog）

本文档记录 `lkong-harmony`（龙空 HarmonyOS 客户端）各版本的变更历史及后续功能排期，格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

---

## 版本变更记录

### [1.2.0] - 2026-11-23

#### 新增（Added）
- **首页底部 4 TabBar 与今日热帖**：
  - 将 `Index.ets` 重构为底部 4 TabBar 结构（`版块` / `热帖` / `常用` / `我的`），完整适配深浅主题。
  - 新增 `ViewHotThreads` 查询（`threadsFragment(fid: 0, type: "hot")`，`ShortThread` 字段集），切换至「热帖」Tab 时懒加载今日热帖排行，支持点击进帖或跳转作者资料页。
  - 「我的」Tab 聚合当前用户资料入口、每日签到卡片、云端收藏夹、个人主页、综合搜索与设置入口。
- **版块常用置顶与自定义排序**：
  - 新增 `store/ForumOrderPrefs.ets`（`Preferences` 持久化 `pinned_fids` 与 `order_fids`），实现「置顶区 + 自定义排序区 + 服务端新增版块自动追加」的稳定合并排序。
  - 扩展 `ForumCard.ets` 与首页排序编辑模式，支持置顶常用/取消置顶、置首、上移、下移与恢复默认顺序，并在「常用」Tab 独立管理已置顶版块。
- **综合搜索**：
  - 新增 `pages/SearchPage.ets` 与 `utils/AvatarUtils.ets`，接入 `SearchThreads`（支持相关度/热度/最新排序、`<em>` 高亮渲染与 `searchAfter` 游标加载更多）、`SearchForums` 与 `SearchUsers`，并保存最近 10 条本地搜索历史。
- **纯云端收藏夹**：
  - 新增 `pages/FavoritesPage.ets`（分组列表及新建/编辑/删除管理）与 `pages/FavoriteDetailPage.ets`（分组明细分页浏览、取消收藏与原帖/作者跳转），全量直连龙空官方云端接口（`userFavoriteGroupList` / `userFavoriteGroup` / `userFavoriteList` / `myFavoriteGroupList` / `favoritePost` / `createFavoriteGroup` / `editFavoriteGroup` / `delFavoriteGroup`）。
  - `ThreadPage.ets` 新增「收藏主题」（利用 `thread.first` 主楼 `pid`）与单楼层「收藏」入口，支持弹窗勾选云端收藏夹及弹窗内直接新建分组并收藏。
- **个人资料页与全站作者联动**：
  - 新增 `pages/UserProfilePage.ets`，首屏通过 `ViewUserProfilePage` 合并拉取用户基础信息、等级徽章、认证信息、统计数据与第 1 页主题，支持「主题」分页浏览与「云端收藏夹」查看。
  - 打通首页热帖、版块帖子列表、帖子主楼与楼层（含引用楼层）、搜索结果与收藏明细中的作者点击跳转资料页入口。
- **引用楼层展示**：
  - `POST_LIST_FRAGMENT` 补充查询 `quote { pid status content author { uid name } }`，`PostCard.ets` 在楼层正文上方展示引用楼层卡片（兼容已删引用提示及超长引用默认 3 行折叠/展开切换）。

#### 变更（Changed）
- 统一版本编码规范为 7 位语义化格式 `M * 1000000 + m * 1000 + p`（`M_mmm_ppp`），将 `AppScope/app.json5` 升级至 `1.2.0`（`versionCode: 1002000`，确保严格大于真机已部署的 `1000002` 并与版本号对齐），同步更新 `AppConfig.APP_VERSION` 为 `'1.2.0'`。
- 在 `SettingsPage.ets` 清除登录态时同步清理 `LkongApi` 内存用户缓存；在 `ThreadRow.ets` 补充可选版块名称展示与作者跳转回调。
- 同步更新 `README.md` 实现范围、GraphQL 接口表、工程目录结构与测试清单。

---

### [1.1.0] - 2026-11-22（已内测发版，真机已部署 versionCode: 1000002）

#### 新增（Added）
- **只看作者与快速跳页**：
  - `LkongApi.getThreadDetail` 支持传入可选 `authorid` 参数筛选作者发言。
  - `ThreadPage.ets` 主楼卡片新增「只看作者 / 查看全部」切换按钮；点击底部页码弹出「快速跳页」弹窗，支持一键跳至首页、末页或输入页码直达（含页码合法性校验）。
- **富文本样式、代码块与链接复制**：
  - `Models.ets` 与 `ContentUtils.ets` 扩展解析 Slate 叶子属性与 TipTap `marks`，支持 `heading`、`code_block` 以及内联 `bold`、`italic`、`underline`、`strike`、`code` 和 `link`（含旧帖 HTML `<a href="...">`）。
  - `PostCard.ets` 为不同标记提供对应样式渲染；点击帖内链接弹出完整地址确认窗并支持通过 `@kit.BasicServicesKit` `pasteboard` 一键复制到剪贴板。
- **深色模式与阅读字号调节**：
  - 新增 `utils/Theme.ets`（集中式浅色/深色 `ThemePalette` 与 4 档字号常量 `13 / 15 / 17 / 19fp`）及 `store/DisplayPrefs.ets`（`Preferences` 持久化并同步至 `AppStorage`）。
  - `EntryAbility.ets` 启动加载主题配置并监听系统 `onConfigurationUpdate` 变化；`resources/dark/element/color.json` 启动底色调整为 `#121212`；全应用 5 个页面及 5 个组件完成深浅主题适配。
  - `SettingsPage.ets` 新增「显示与阅读」卡片（外观模式切换 + 字号档位 + 实时预览）；`ThreadPage.ets` 顶部新增「字号」快捷切换条。

#### 变更（Changed）
- 升级 `AppScope/app.json5` 至 `1.1.0`（`versionCode: 1000002`），同步更新 `AppConfig.APP_VERSION` 为 `'1.1.0'`。
- 为 `LoginPage.ets` 与 `SettingsPage.ets` 的 `promptAction.showToast` 调用统一补充异常捕获处理。
- 同步更新 `README.md` 实现范围、工程结构与测试清单，并按最新需求移除原规划中的本地浏览历史模块。

---

### [1.0.2] - 2026-11-21（已内测发版）

#### 新增（Added）
- **首页每日签到**：新增 `GetUserPunch` 查询与 `Punch` mutation（`GraphqlQueries.ets` / `GraphqlParser.ets` / `LkongApi.ets`），登录后在 `Index.ets` 顶部展示签到卡片，显示“今日已签 / 待签到”状态及连续、累计、最高签到天数，支持一键签到与加载失败重试。
- **楼层原生图文混排与大图预览**：
  - 在 `ContentUtils.ets` 新增 `parsePostBlocks`，支持解析龙空 Slate/TipTap JSON 与旧帖 HTML 中的段落、引用、分割线、有序/无序列表、行内动态表情（`https://image.lkong.com/bq/em{id}.gif`）与正文图片（`https://images.lkong.com/images/{imageKey}.jpg`）。
  - 新增 `PostImage.ets` 组件，支持原图宽高比自适应、小图防拉伸、加载占位、加载失败点击重试。
  - 更新 `PostCard.ets`，通过 `Text` 内 `Span` + `ImageSpan`（配合 `minLineHeight`）实现文字与行内表情混排。
  - 更新 `ThreadPage.ets`，点击正文图片可弹出全屏深色预览浮层，并支持系统返回键关闭预览。

#### 修复（Fixed）
- **帖子详情只显示 1 楼的严重缺陷**：真实接口中 `posts.pid` 为 UUID 字符串而非数字，原 `Models.ets` 与 `GraphqlParser.ets` 将其按数字解析导致所有楼层 `pid` 均变成 `0`，进而触发 ArkUI `ForEach` 键冲突；已将 `PostItem.pid` 改为 `string` 并优化 `ForEach` 唯一键生成策略。
- **部分多页帖子无法点击“下一页”**：龙空后台按固定每页 20 个楼层号区间分页，存在删楼的页返回条数会小于 20 条（例如 19 条），导致原 `posts.length >= 20` 校验误判为末页；已改为结合 `replyCount` 计算总页数 `第 x / y 页` 并正确判定翻页状态。
- **主楼与楼层排版问题**：主楼顶部信息拆分为“作者 + 时间”与“回复/查看/版块”两行，避免长用户名将时间挤出屏幕；修复 `PostCard` 短回复居中问题；修复 `Index.ets` 与 `LoginPage.ets` 中 `.width('100%')` 叠加水平 `margin` 导致的横向溢出。
- **文案与版本号不一致**：清理 `ForumPage.ets`、`ThreadPage.ets`、`SettingsPage.ets` 中残留的早期 WebView 登录和域名描述；将 `AppConfig.APP_VERSION` 对齐为 `1.0.1`。

#### 变更（Changed）
- 精简 `LkongApi.getThreadDetail` 传参（仅传 `{ tid, page }`），避免冗余空变量。
- 同步更新 `README.md` 与 `SettingsPage.ets` 的接口、图片/表情域名及安全约束说明。

---

### [1.0.1] - 2026-11-20

#### 新增（Added）
- **发布签名与打包自动化**：建立 `sign/` 发布证书与 Profile 目录及说明文档（`sign/README.md`），新增 `scripts/rebuild_and_sign.py` 用于一键构建 Release APP 并使用 `hap-sign-tool.jar` 完成发布签名，以适配 AppGallery Connect 内部测试分发流程。

#### 修复（Fixed）
- **登录会话提取兼容性**：在 `HttpClient.ets` 中补充从响应头 `Set-Cookie`（兼容不同大小写键名）兜底提取 `EGG_SESS`，解决部分 HarmonyOS 运行时下 `response.cookies` 为空的问题。

#### 变更（Changed）
- 将 `AppScope/app.json5` 版本升级至 `1.0.1`（`versionCode: 1000001`），用于 AGC 仅测试版本上传。

---

### [1.0.0] - 2026-11-20

#### 新增（Added）
- **工程初始化**：创建基于 ArkTS / Stage 模型（API 26，包名 `com.nihaoa.lkong`）的原生 HarmonyOS 工程骨架。
- **纯 GraphQL 网络与会话存储层**：
  - 实现 `HttpClient.ets`（白名单校验 `https://api.lkong.com/api`、串行 800ms 请求节流）、`GraphqlClient.ets`、`GraphqlQueries.ets`、`GraphqlParser.ets` 与 `LkongApi.ets`。
  - 实现 `CookieStore.ets`（基于 `Preferences` 仅持久化 `EGG_SESS`，不落盘密码）及 `TimeUtils.ets`、`ContentUtils.ets` 基础纯文本渲染。
- **基础浏览与登录页面（5 个页面）**：
  - `Index.ets`（首页版块列表 `GetMe` → `commonNavbars`）、`ForumPage.ets`（版块帖子分页 `ViewForumPage`）、`ThreadPage.ets`（帖子详情基础展示 `ViewThread`）、`LoginPage.ets`（账号密码 `Login` 登录）、`SettingsPage.ets`（登录态查看与一键清除）。

---

## 后续新增功能规划与排期（Roadmap）

> 注：排期按单人业余/集中推进节奏估算，自 **2026-11-22** 起滚动迭代，实际可根据真机体验反馈动态调整优先级。原本地参考代码目录 `lkongdroid` 已于 **2026-11-22** 删除，下文原标注参考 `lkongdroid` 的规划项后续直接以龙空官方 GraphQL 接口与官网行为为准。

### 总览时间表

| 迭代版本 | 计划周期 | 状态 / 核心主题 | 关键交付目标 |
|---|---|---|---|
| **v1.0.2** | 2026-11-21 | 已内测发版 | 首页每日签到、楼层图文混排、UUID `pid` 与删楼翻页修复 |
| **v1.1.0** | 2026-11-22 ~ 2026-11-24 | 已内测发版（已部署真机） | 只看作者、快速跳页、富文本样式与链接复制、深色模式与字号调节 |
| **v1.2.0** | 2026-11-23 | 代码已开发待真机验证 | 首页底部 4 TabBar（版块/热帖/常用/我的）、版块置顶与自定义排序、搜索、纯云端收藏夹、个人资料页、引用楼层展示 |
| **v1.3.0** | 2026-12-11 ~ 2026-12-20 | 论坛基础互动 | 回帖/引用回复、龙空表情选择器、发新帖与传图、站内消息通知 |
| **v1.4.0** | 2026-12-21 ~ 2026-12-31 | 看图增强与技术债清理 | 大图缩放/多图切换/保存相册、私信与 `twoWay` 调研、迁移废弃系统 API |

---

### 分阶段详细规划

#### 1. v1.2.0 — 发现与内容聚合（2026-11-23，代码已开发待真机验证）
- **首页底部 4 TabBar 聚合**：扩展首页为「版块 / 热帖 / 常用 / 我的」底部四栏结构（热帖对应官网 `threadsFragment(fid: 0, type: "hot")` 懒加载接口）。
- **版块常用置顶与自定义排序**：支持将版块置顶到「常用」区、置首/上移/下移与恢复默认顺序，并持久化到本地 `Preferences`。
- **综合搜索功能**：接入 `SearchThreads` / `SearchForums` / `SearchUsers`，支持帖子排序、关键词高亮、游标加载更多与最近搜索历史。
- **纯云端收藏夹**：全面接入龙空云端收藏分组管理、帖子/楼层弹窗收藏与分组明细分页浏览，不落盘本地假收藏数据。
- **用户资料页**：点击任意作者或本人入口查看基础信息、等级与统计、主题列表与云端收藏分组。
- **引用楼层展示**：在 `postListComponent` 接入 `quote` 字段，并在楼层正文前展示被引用楼层卡片（支持已删提示与长内容展开/收起）。

#### 2. v1.3.0 — 论坛基础互动能力（2026-12-11 ~ 2026-12-20）
- **回帖与引用回复**（原参考 `lkongdroid` `NewPostActivity`，目录已删除）：在 `ThreadPage` 底部增加快速回复入口，支持针对具体楼层回复与正文编辑。
- **龙空表情面板**：参照官网表情分类与原 `lkongdroid/assets/emoji` 布局（目录已删除，后续以官网表情分类与 `https://image.lkong.com/bq/em{id}.gif` 为准），支持在发帖/回帖编辑器中点选插入 `em{id}` 表情。
- **发新帖与图片上传**（原参考 `lkongdroid` `NewThreadActivity`，目录已删除）：调研龙空 GraphQL 图片上传签名流程并接入系统图库选图上传。
- **站内消息通知**（原参考 `lkongdroid` `notice`，目录已删除）：查看回复通知、`@提及` 与评分记录，并在首页显示未读提示。

#### 3. v1.4.0 — 看图增强与技术债清理（2026-12-21 ~ 2026-12-31）
- **看图体验升级**（原参考 `lkongdroid` `PhotoViewPagerActivity`，目录已删除）：全屏图片预览支持双指捏合缩放、左右滑动切换同帖多图、保存图片到系统相册。
- **私信与二次验证调研**：评估 GraphQL 私信列表/收发及 `twoWay` 二次验证账号登录流程的可行性。
- **HarmonyOS SDK 废弃 API 迁移**：将编译告警中提示的旧版 `router.pushUrl/back/getParams`、`getContext`、`promptAction.showToast` 逐步迁移至官方推荐的 `Navigation` 与 `this.getUIContext()` 接口，消除编译期警告。
