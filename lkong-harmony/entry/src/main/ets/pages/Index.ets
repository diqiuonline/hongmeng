import { ApiError, CurrentUser, ErrorKind, Forum, HotThread, NoticeCount, PunchInfo } from '../model/Models';
import { LkongApi } from '../network/LkongApi';
import { CookieStore } from '../store/CookieStore';
import { DisplayPrefs } from '../store/DisplayPrefs';
import { ForumOrderPrefs } from '../store/ForumOrderPrefs';
import { PunchPrefs } from '../store/PunchPrefs';
import { ForumCard } from '../components/ForumCard';
import { StateView } from '../components/StateView';
import { KEY_APP_FOREGROUND_SEQ, KEY_AUTO_PUNCH_ENABLED, KEY_NOTICE_COUNT_DIRTY } from '../utils/AppConfig';
import {
  AppNavigator,
  ForumRouteParams,
  Routes,
  ThreadRouteParams,
  UserProfileRouteParams
} from '../utils/AppRouter';
import { safeAvatarInitial } from '../utils/AvatarUtils';
import { formatNoticeUnreadBadge, getVisibleUnreadTotal } from '../utils/PostComposerUtils';
import { getTheme, KEY_IS_DARK } from '../utils/Theme';
import { formatClockTime, getLocalDateKey } from '../utils/TimeUtils';
import { getHostContext, showToast } from '../utils/UiUtils';
import { ComposePage } from './ComposePage';
import { FavoriteDetailPage } from './FavoriteDetailPage';
import { FavoritesPage } from './FavoritesPage';
import { ForumPage } from './ForumPage';
import { LoginPage } from './LoginPage';
import { MessageChatPage } from './MessageChatPage';
import { NotificationsPage } from './NotificationsPage';
import { SearchPage } from './SearchPage';
import { SettingsPage } from './SettingsPage';
import { ThreadPage } from './ThreadPage';
import { UserProfilePage } from './UserProfilePage';

/**
 * 首页与全应用 Navigation 根容器：底部 4 TabBar（版块 / 热帖 / 常用 / 我的），
 * 支持版块常用置顶与自定义排序、今日热帖、每日签到、下拉刷新、未读角标汇总（含私信）与功能聚合。
 */
@Entry
@Component
struct Index {
  @State activeTab: number = 0;
  @State currentUser: CurrentUser | null = null;
  @State rawForums: Forum[] = [];
  @State orderedForums: Forum[] = [];
  @State pinnedForums: Forum[] = [];
  @State loading: boolean = true;
  @State forumsRefreshing: boolean = false;
  @State errorMessage: string = '';
  @State loggedIn: boolean = false;
  @State forumEditMode: boolean = false;
  @State orderRevision: number = 0;

  @State punchInfo: PunchInfo | null = null;
  @State punchLoading: boolean = false;
  @State punchSubmitting: boolean = false;
  @State punchError: string = '';

  @State hotThreads: HotThread[] = [];
  @State hotLoaded: boolean = false;
  @State hotLoading: boolean = false;
  @State hotRefreshing: boolean = false;
  @State hotError: string = '';
  @State hotNeedLogin: boolean = false;

  @State avatarFailed: boolean = false;
  @State noticeCount: NoticeCount | null = null;

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;
  @StorageProp(KEY_AUTO_PUNCH_ENABLED) autoPunchEnabled: boolean = true;
  @StorageProp(KEY_APP_FOREGROUND_SEQ) @Watch('onAppForegroundChanged') appForegroundSeq: number = 0;
  private tabsController: TabsController = new TabsController();
  private bootstrapped: boolean = false;
  private lastNoticeFetchAt: number = 0;
  private lastPunchLoadedDate: string = '';
  private autoPunchAttemptedKey: string = '';

  onBackPress(): boolean {
    if (this.forumEditMode) {
      this.forumEditMode = false;
      return true;
    }
    return false;
  }

  aboutToAppear(): void {
    AppNavigator.getInstance().setOnReturnToRoot(() => {
      this.handleReturnToRoot();
    });
    this.bootstrap();
  }

  onPageShow(): void {
    this.handleReturnToRoot();
  }

  private handleReturnToRoot(): void {
    if (!this.bootstrapped) {
      return;
    }
    const nowLoggedIn = CookieStore.getInstance().hasCookie();
    if (!nowLoggedIn) {
      this.loggedIn = false;
      this.currentUser = null;
      this.punchInfo = null;
      this.punchError = '';
      this.lastPunchLoadedDate = '';
      this.autoPunchAttemptedKey = '';
      this.hotThreads = [];
      this.hotLoaded = false;
      this.hotError = '';
      this.hotNeedLogin = false;
      this.noticeCount = null;
      this.lastNoticeFetchAt = 0;
      return;
    }

    const wasLoggedIn = this.loggedIn;
    this.loggedIn = true;
    if (!wasLoggedIn) {
      this.avatarFailed = false;
      this.lastPunchLoadedDate = '';
      this.autoPunchAttemptedKey = '';
      this.loadForums();
      this.loadPunchInfo(true);
      this.loadNoticeCount();
      if (this.activeTab === 1) {
        this.loadHotThreads();
      }
      return;
    }

    const cached = LkongApi.getInstance().getCachedCurrentUser();
    if (cached !== null) {
      this.currentUser = cached;
    }
    this.checkDailyAutoPunch();
    const noticeDirty = AppStorage.get<boolean>(KEY_NOTICE_COUNT_DIRTY);
    if (noticeDirty === true || Date.now() - this.lastNoticeFetchAt > 30000) {
      AppStorage.setOrCreate(KEY_NOTICE_COUNT_DIRTY, false);
      this.loadNoticeCount();
    }
    if (this.activeTab === 1 && this.hotNeedLogin && !this.hotLoading) {
      this.loadHotThreads();
    }
  }

  private onAppForegroundChanged(): void {
    if (!this.bootstrapped || !CookieStore.getInstance().hasCookie()) {
      return;
    }
    this.loggedIn = true;
    this.checkDailyAutoPunch();
    if (Date.now() - this.lastNoticeFetchAt > 30000) {
      this.loadNoticeCount();
    }
  }

  private resolvePunchUid(fallbackInfo?: PunchInfo | null): number {
    if (this.currentUser !== null && this.currentUser.uid > 0) {
      return this.currentUser.uid;
    }
    if (fallbackInfo !== undefined && fallbackInfo !== null && fallbackInfo.uid > 0) {
      return fallbackInfo.uid;
    }
    if (this.punchInfo !== null && this.punchInfo.uid > 0) {
      return this.punchInfo.uid;
    }
    return 0;
  }

  private checkDailyAutoPunch(): void {
    if (!this.loggedIn || !CookieStore.getInstance().hasCookie()) {
      return;
    }
    const today = getLocalDateKey();
    if (this.punchInfo === null || this.lastPunchLoadedDate !== today) {
      if (!this.punchLoading) {
        this.loadPunchInfo(true);
      }
      return;
    }
    if (!this.punchInfo.isPunch && PunchPrefs.getInstance().isEnabled() && !this.punchSubmitting) {
      const uid = this.resolvePunchUid(this.punchInfo);
      const attemptKey = `${uid}_${today}`;
      if (this.autoPunchAttemptedKey !== attemptKey) {
        this.autoPunchAttemptedKey = attemptKey;
        this.doPunch(true);
      }
    }
  }

  private async bootstrap(): Promise<void> {
    const ctx = getHostContext(this.getUIContext());
    await CookieStore.getInstance().ensureInit(ctx);
    await DisplayPrefs.getInstance().ensureInit(ctx);
    await ForumOrderPrefs.getInstance().ensureInit(ctx);
    await PunchPrefs.getInstance().ensureInit(ctx);
    this.loggedIn = CookieStore.getInstance().hasCookie();
    this.bootstrapped = true;
    await this.loadForums();
    if (this.loggedIn) {
      await this.loadPunchInfo(true);
      this.loadNoticeCount();
    }
  }

  private rebuildForumLists(): void {
    const prefs = ForumOrderPrefs.getInstance();
    this.orderedForums = prefs.applyOrder(this.rawForums);
    this.pinnedForums = prefs.getPinnedForums(this.rawForums);
    this.orderRevision = this.orderRevision + 1;
  }

  private async refreshAll(fromPull: boolean = false): Promise<void> {
    if (this.activeTab === 1) {
      await this.loadHotThreads(fromPull);
      return;
    }
    await this.loadForums(fromPull);
    if (this.loggedIn) {
      await this.loadPunchInfo(true);
      this.loadNoticeCount();
    }
  }

  private async loadForums(fromPull: boolean = false): Promise<void> {
    if (!fromPull) {
      this.loading = true;
    }
    this.errorMessage = '';
    try {
      const home = await LkongApi.getInstance().getHomeData();
      this.rawForums = home.forums;
      this.currentUser = home.me.uid > 0 && this.loggedIn ? home.me : null;
      this.avatarFailed = false;
      this.rebuildForumLists();
    } catch (error) {
      if (error instanceof ApiError) {
        this.errorMessage = error.message;
      } else {
        this.errorMessage = '版块加载失败，请稍后重试。';
      }
    } finally {
      this.loading = false;
      this.forumsRefreshing = false;
    }
  }

  private async loadPunchInfo(allowAutoPunch: boolean = true): Promise<void> {
    if (!CookieStore.getInstance().hasCookie()) {
      this.punchInfo = null;
      this.punchError = '';
      this.lastPunchLoadedDate = '';
      return;
    }
    if (this.punchLoading) {
      return;
    }
    this.punchLoading = true;
    this.punchError = '';
    let loaded: PunchInfo | null = null;
    try {
      loaded = await LkongApi.getInstance().getUserPunch();
      this.punchInfo = loaded;
      this.lastPunchLoadedDate = getLocalDateKey();
    } catch (error) {
      if (error instanceof ApiError) {
        this.punchError = error.message;
      } else {
        this.punchError = '签到状态获取失败。';
      }
    } finally {
      this.punchLoading = false;
    }

    if (loaded === null || !CookieStore.getInstance().hasCookie()) {
      return;
    }
    const today = getLocalDateKey();
    const uid = this.resolvePunchUid(loaded);
    if (loaded.isPunch) {
      PunchPrefs.getInstance().recordPunched(uid, today);
      return;
    }
    if (allowAutoPunch && PunchPrefs.getInstance().isEnabled()) {
      const attemptKey = `${uid}_${today}`;
      if (this.autoPunchAttemptedKey !== attemptKey) {
        this.autoPunchAttemptedKey = attemptKey;
        await this.doPunch(true);
      }
    }
  }

  private async loadHotThreads(fromPull: boolean = false): Promise<void> {
    if (!fromPull) {
      this.hotLoading = true;
    }
    this.hotError = '';
    this.hotNeedLogin = false;
    try {
      this.hotThreads = await LkongApi.getInstance().getHotThreads();
      this.hotLoaded = true;
    } catch (error) {
      if (error instanceof ApiError && error.kind === ErrorKind.AUTH) {
        this.hotNeedLogin = true;
        this.hotError = error.message;
      } else if (error instanceof ApiError) {
        this.hotError = error.message;
      } else {
        this.hotError = '今日热帖加载失败，请稍后重试。';
      }
    } finally {
      this.hotLoading = false;
      this.hotRefreshing = false;
    }
  }

  private async loadNoticeCount(): Promise<void> {
    if (!CookieStore.getInstance().hasCookie()) {
      this.noticeCount = null;
      return;
    }
    try {
      this.noticeCount = await LkongApi.getInstance().getNoticeCount();
      this.lastNoticeFetchAt = Date.now();
    } catch (error) {
      // 未读数拉取失败不弹窗干扰首页浏览。
    }
  }

  private noticeEntrySubtitle(): string {
    const total = getVisibleUnreadTotal(this.noticeCount);
    if (this.noticeCount === null || total <= 0) {
      return '查看回复提醒、@我、评分、粉丝与私信';
    }
    return `未读 ${total} 条（通知 ${this.noticeCount.noticeCount} · @我 ${this.noticeCount.atmeCount} · 评分 ${this.noticeCount.rateCount} · 粉丝 ${this.noticeCount.fansCount} · 私信 ${this.noticeCount.pmCount}）`;
  }

  private async doPunch(isAuto: boolean = false): Promise<void> {
    if (this.punchSubmitting || this.punchLoading) {
      return;
    }
    this.punchSubmitting = true;
    const today = getLocalDateKey();
    try {
      const result = await LkongApi.getInstance().punch();
      this.punchInfo = result;
      this.punchError = '';
      this.lastPunchLoadedDate = today;
      const uid = this.resolvePunchUid(result);
      const note = isAuto
        ? `${today} ${formatClockTime()} 自动签到成功（连续 ${result.punchDay} 天）`
        : `${today} ${formatClockTime()} 手动签到成功（连续 ${result.punchDay} 天）`;
      await PunchPrefs.getInstance().recordPunched(uid, today, note);
      showToast(
        this.getUIContext(),
        isAuto
          ? `已自动签到！已连续签到 ${result.punchDay} 天`
          : `签到成功！已连续签到 ${result.punchDay} 天`
      );
    } catch (error) {
      const message = error instanceof ApiError ? error.message : '签到失败，请稍后重试。';
      if (isAuto) {
        await PunchPrefs.getInstance().recordAutoNote(`${today} ${formatClockTime()} 自动签到失败：${message}`);
        showToast(this.getUIContext(), '自动签到失败，可手动点击签到');
      } else {
        showToast(this.getUIContext(), message);
      }
    } finally {
      this.punchSubmitting = false;
    }
  }

  private punchSubtitle(): string {
    if (this.punchLoading && this.punchInfo === null) {
      return '正在获取签到状态...';
    }
    if (this.punchError.length > 0 && this.punchInfo === null) {
      return this.punchError;
    }
    if (this.punchInfo !== null) {
      return `连续 ${this.punchInfo.punchDay} 天 · 累计 ${this.punchInfo.punchAllDay} 天 · 最高 ${this.punchInfo.punchHighestDay} 天`;
    }
    return '点击右侧按钮完成今日签到';
  }

  private applyTabChange(index: number): void {
    if (index < 0 || index > 3 || this.activeTab === index) {
      return;
    }
    if (index !== 0 && index !== 2) {
      this.forumEditMode = false;
    }
    this.activeTab = index;
    if (index === 1 && !this.hotLoaded && !this.hotLoading) {
      this.loadHotThreads();
    }
  }

  private switchTab(index: number): void {
    this.applyTabChange(index);
    this.tabsController.changeIndex(index);
  }

  private async handleTogglePin(fid: number): Promise<void> {
    await ForumOrderPrefs.getInstance().togglePin(fid, this.rawForums);
    this.rebuildForumLists();
  }

  private async handleMoveForum(fid: number, direction: number, onlyPinnedScope: boolean): Promise<void> {
    await ForumOrderPrefs.getInstance().moveForum(fid, direction, this.rawForums, onlyPinnedScope);
    this.rebuildForumLists();
  }

  private async handleResetOrder(): Promise<void> {
    await ForumOrderPrefs.getInstance().resetOrder(false);
    this.rebuildForumLists();
    showToast(this.getUIContext(), '已恢复版块默认顺序（保留常用置顶）');
  }

  private canMoveUpInAllTab(index: number): boolean {
    const pinnedCount = this.pinnedForums.length;
    if (index < pinnedCount) {
      return index > 0;
    }
    return index > pinnedCount;
  }

  private canMoveDownInAllTab(index: number): boolean {
    const pinnedCount = this.pinnedForums.length;
    if (index < pinnedCount) {
      return index < pinnedCount - 1;
    }
    return index < this.orderedForums.length - 1;
  }

  private topTitle(): string {
    if (this.activeTab === 1) {
      return '今日热帖';
    }
    if (this.activeTab === 2) {
      return '常用版块';
    }
    if (this.activeTab === 3) {
      return '我的';
    }
    return '龙空客户端';
  }

  private openLogin(): void {
    AppNavigator.getInstance().push(Routes.LOGIN);
  }

  private openSettings(): void {
    AppNavigator.getInstance().push(Routes.SETTINGS);
  }

  private openSearch(): void {
    AppNavigator.getInstance().push(Routes.SEARCH);
  }

  private openFavorites(): void {
    AppNavigator.getInstance().push(Routes.FAVORITES);
  }

  private openNotifications(): void {
    AppNavigator.getInstance().push(Routes.NOTIFICATIONS);
  }

  private openUserProfile(uid: number, name: string): void {
    const params: UserProfileRouteParams = {
      uid: uid,
      name: name
    };
    AppNavigator.getInstance().push(Routes.USER_PROFILE, params);
  }

  private openForum(forum: Forum): void {
    const params: ForumRouteParams = {
      fid: forum.fid,
      name: forum.name
    };
    AppNavigator.getInstance().push(Routes.FORUM, params);
  }

  private openThread(tid: number, title: string): void {
    const params: ThreadRouteParams = {
      tid: tid,
      title: title
    };
    AppNavigator.getInstance().push(Routes.THREAD, params);
  }

  @Builder
  private pageBuilder(name: string, _param: Object) {
    if (name === Routes.LOGIN) {
      LoginPage()
    } else if (name === Routes.SETTINGS) {
      SettingsPage()
    } else if (name === Routes.SEARCH) {
      SearchPage()
    } else if (name === Routes.FAVORITES) {
      FavoritesPage()
    } else if (name === Routes.FAVORITE_DETAIL) {
      FavoriteDetailPage()
    } else if (name === Routes.FORUM) {
      ForumPage()
    } else if (name === Routes.THREAD) {
      ThreadPage()
    } else if (name === Routes.USER_PROFILE) {
      UserProfilePage()
    } else if (name === Routes.COMPOSE) {
      ComposePage()
    } else if (name === Routes.NOTIFICATIONS) {
      NotificationsPage()
    } else if (name === Routes.MESSAGE_CHAT) {
      MessageChatPage()
    }
  }

  @Builder
  private renderPunchOrBannerCard() {
    if (!this.loggedIn) {
      Row({ space: 8 }) {
        Text('当前未登录。版块列表可以直接浏览；热帖、帖子与收藏需要登录。')
          .fontSize(12)
          .fontColor(getTheme(this.isDark).bannerText)
          .layoutWeight(1)
        Button('去登录')
          .fontSize(12)
          .height(30)
          .backgroundColor(getTheme(this.isDark).bannerBtnBg)
          .fontColor(getTheme(this.isDark).bannerText)
          .onClick(() => {
            this.openLogin();
          })
      }
      .width('100%')
      .padding(12)
      .backgroundColor(getTheme(this.isDark).bannerBg)
      .borderRadius(8)
    } else {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Row({ space: 6 }) {
            Text('每日签到')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(getTheme(this.isDark).textPrimary)
            if (this.autoPunchEnabled) {
              Text('自动')
                .fontSize(10)
                .fontColor(getTheme(this.isDark).accent)
                .backgroundColor(getTheme(this.isDark).accentBg)
                .borderRadius(4)
                .padding({ left: 5, right: 5, top: 2, bottom: 2 })
                .onClick(() => {
                  this.openSettings();
                })
            }
            if (this.punchInfo !== null && this.punchInfo.isPunch) {
              Text('今日已签')
                .fontSize(11)
                .fontColor(getTheme(this.isDark).successText)
                .backgroundColor(getTheme(this.isDark).successBg)
                .borderRadius(4)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            } else if (this.punchInfo !== null) {
              Text('待签到')
                .fontSize(11)
                .fontColor(getTheme(this.isDark).bannerText)
                .backgroundColor(getTheme(this.isDark).bannerBg)
                .borderRadius(4)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            }
          }

          Text(this.punchSubtitle())
            .fontSize(12)
            .fontColor(getTheme(this.isDark).textSecondary)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.punchError.length > 0 && this.punchInfo === null) {
          Button('重试')
            .fontSize(12)
            .height(32)
            .backgroundColor(getTheme(this.isDark).accentBg)
            .fontColor(getTheme(this.isDark).accent)
            .onClick(() => {
              this.loadPunchInfo();
            })
        } else if (this.punchInfo !== null && this.punchInfo.isPunch) {
          Button('已签到')
            .fontSize(12)
            .height(32)
            .backgroundColor(getTheme(this.isDark).successBg)
            .fontColor(getTheme(this.isDark).successText)
            .enabled(false)
        } else {
          Button(this.punchSubmitting ? '签到中...' : '签到')
            .fontSize(12)
            .height(32)
            .backgroundColor(
              (!this.punchLoading && !this.punchSubmitting)
                ? getTheme(this.isDark).accentSolid
                : getTheme(this.isDark).disabledBtnBg
            )
            .fontColor(
              (!this.punchLoading && !this.punchSubmitting)
                ? Color.White
                : getTheme(this.isDark).disabledBtnText
            )
            .enabled(!this.punchLoading && !this.punchSubmitting)
            .onClick(() => {
              this.doPunch(false);
            })
        }
      }
      .width('100%')
      .padding(14)
      .backgroundColor(getTheme(this.isDark).cardBg)
      .borderRadius(12)
    }
  }

  @Builder
  private renderEditToolbar() {
    Column() {
      Row({ space: 8 }) {
        Text('编辑版块置顶与顺序')
          .fontSize(12)
          .fontColor(getTheme(this.isDark).textSecondary)
          .layoutWeight(1)
        Button('恢复默认')
          .fontSize(12)
          .height(28)
          .backgroundColor(getTheme(this.isDark).surfaceMuted)
          .fontColor(getTheme(this.isDark).textPrimary)
          .onClick(() => {
            this.handleResetOrder();
          })
        Button('完成')
          .fontSize(12)
          .height(28)
          .backgroundColor(getTheme(this.isDark).accentSolid)
          .fontColor(Color.White)
          .onClick(() => {
            this.forumEditMode = false;
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor(getTheme(this.isDark).cardBg)
      .borderRadius(10)
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 8 })
  }

  @Builder
  private renderAllForumsTab() {
    if (this.forumEditMode) {
      this.renderEditToolbar()
    }

    if (this.loading) {
      Column() {
        LoadingProgress()
          .width(40)
          .height(40)
          .color(getTheme(this.isDark).accent)
        Text('正在加载版块...')
          .fontSize(13)
          .fontColor(getTheme(this.isDark).textSecondary)
          .margin({ top: 8 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.errorMessage.length > 0) {
      Column() {
        StateView({
          title: '加载失败',
          message: this.errorMessage,
          actionText: '重试',
          onAction: () => {
            this.loadForums();
          }
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.orderedForums.length === 0) {
      Column() {
        StateView({
          title: '暂无版块',
          message: '当前没有获取到版块数据。'
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      Refresh({ refreshing: $$this.forumsRefreshing }) {
        List({ space: 12 }) {
          if (!this.forumEditMode) {
            ListItem() {
              this.renderPunchOrBannerCard()
            }
          }

          ForEach(this.orderedForums, (forum: Forum, index: number) => {
            ListItem() {
              ForumCard({
                name: forum.name,
                info: forum.info,
                todayPostNum: forum.todayPostNum,
                avatarUrl: forum.avatarUrl,
                isPinned: ForumOrderPrefs.getInstance().isPinned(forum.fid),
                editMode: this.forumEditMode,
                canMoveUp: this.canMoveUpInAllTab(index),
                canMoveDown: this.canMoveDownInAllTab(index),
                onOpen: () => {
                  this.openForum(forum);
                },
                onTogglePin: () => {
                  this.handleTogglePin(forum.fid);
                },
                onMoveTop: () => {
                  this.handleMoveForum(forum.fid, -2, false);
                },
                onMoveUp: () => {
                  this.handleMoveForum(forum.fid, -1, false);
                },
                onMoveDown: () => {
                  this.handleMoveForum(forum.fid, 1, false);
                }
              })
            }
          }, (forum: Forum, index: number) =>
            `${this.isDark ? 'd' : 'l'}_${this.forumEditMode ? 'e' : 'n'}_${this.orderRevision}_${index}_${forum.fid}`
          )
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16, bottom: 12 })
        .scrollBar(BarState.Auto)
      }
      .layoutWeight(1)
      .onRefreshing(() => {
        this.refreshAll(true);
      })
    }
  }

  @Builder
  private renderHotTab() {
    if (this.hotLoading) {
      Column() {
        LoadingProgress()
          .width(40)
          .height(40)
          .color(getTheme(this.isDark).accent)
        Text('正在加载今日热帖...')
          .fontSize(13)
          .fontColor(getTheme(this.isDark).textSecondary)
          .margin({ top: 8 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.hotNeedLogin) {
      Column() {
        StateView({
          title: '需要登录',
          message: '查看龙空今日热帖需要先登录账号。',
          actionText: '去登录',
          onAction: () => {
            this.openLogin();
          }
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.hotError.length > 0) {
      Column() {
        StateView({
          title: '加载失败',
          message: this.hotError,
          actionText: '重试',
          onAction: () => {
            this.loadHotThreads();
          }
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.hotThreads.length === 0) {
      Column() {
        StateView({
          title: '暂无热帖',
          message: '当前没有获取到今日热帖数据。',
          actionText: '刷新',
          onAction: () => {
            this.loadHotThreads();
          }
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      Refresh({ refreshing: $$this.hotRefreshing }) {
        List({ space: 10 }) {
          ForEach(this.hotThreads, (item: HotThread, index: number) => {
            ListItem() {
              Row({ space: 12 }) {
                Text(`${index + 1}`)
                  .width(28)
                  .height(28)
                  .borderRadius(6)
                  .textAlign(TextAlign.Center)
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .backgroundColor(
                    index < 3 ? getTheme(this.isDark).accentSolid : getTheme(this.isDark).surfaceMuted
                  )
                  .fontColor(
                    index < 3 ? Color.White : getTheme(this.isDark).textSecondary
                  )

                Column({ space: 6 }) {
                  Text(item.title)
                    .width('100%')
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(getTheme(this.isDark).textPrimary)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  if (item.authorName.length > 0) {
                    Text(`作者：${item.authorName}`)
                      .fontSize(12)
                      .fontColor(
                        item.authorId > 0 ? getTheme(this.isDark).accent : getTheme(this.isDark).textSecondary
                      )
                      .onClick(() => {
                        if (item.authorId > 0) {
                          this.openUserProfile(item.authorId, item.authorName);
                        }
                      })
                  }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding(14)
              .backgroundColor(getTheme(this.isDark).cardBg)
              .borderRadius(12)
              .alignItems(VerticalAlign.Top)
              .onClick(() => {
                this.openThread(item.tid, item.title);
              })
            }
          }, (item: HotThread, index: number) => `${this.isDark ? 'd' : 'l'}_hot_${item.tid}_${index}`)
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16, bottom: 12 })
        .scrollBar(BarState.Auto)
      }
      .layoutWeight(1)
      .onRefreshing(() => {
        this.loadHotThreads(true);
      })
    }
  }

  @Builder
  private renderPinnedTab() {
    if (this.forumEditMode) {
      this.renderEditToolbar()
    }

    if (this.loading) {
      Column() {
        LoadingProgress()
          .width(40)
          .height(40)
          .color(getTheme(this.isDark).accent)
        Text('正在加载常用版块...')
          .fontSize(13)
          .fontColor(getTheme(this.isDark).textSecondary)
          .margin({ top: 8 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.pinnedForums.length === 0) {
      Column() {
        StateView({
          title: '还没有常用版块',
          message: '在“版块”页面点击右上角“排序”，可以把常逛的版块置顶到这里。',
          actionText: '去挑选置顶版块',
          onAction: () => {
            this.switchTab(0);
            this.forumEditMode = true;
          }
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List({ space: 12 }) {
        ForEach(this.pinnedForums, (forum: Forum, index: number) => {
          ListItem() {
            ForumCard({
              name: forum.name,
              info: forum.info,
              todayPostNum: forum.todayPostNum,
              avatarUrl: forum.avatarUrl,
              isPinned: true,
              editMode: this.forumEditMode,
              canMoveUp: index > 0,
              canMoveDown: index < this.pinnedForums.length - 1,
              onOpen: () => {
                this.openForum(forum);
              },
              onTogglePin: () => {
                this.handleTogglePin(forum.fid);
              },
              onMoveTop: () => {
                this.handleMoveForum(forum.fid, -2, true);
              },
              onMoveUp: () => {
                this.handleMoveForum(forum.fid, -1, true);
              },
              onMoveDown: () => {
                this.handleMoveForum(forum.fid, 1, true);
              }
            })
          }
        }, (forum: Forum, index: number) =>
          `${this.isDark ? 'd' : 'l'}_pin_${this.forumEditMode ? 'e' : 'n'}_${this.orderRevision}_${index}_${forum.fid}`
        )
      }
      .layoutWeight(1)
      .padding({ left: 16, right: 16, bottom: 12 })
      .scrollBar(BarState.Auto)
    }
  }

  @Builder
  private renderMineEntryRow(title: string, subtitle: string, onTap: () => void) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(getTheme(this.isDark).textPrimary)
        Text(subtitle)
          .fontSize(12)
          .fontColor(getTheme(this.isDark).textSecondary)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('>')
        .fontSize(15)
        .fontColor(getTheme(this.isDark).textMuted)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(getTheme(this.isDark).cardBg)
    .borderRadius(12)
    .onClick(() => {
      onTap();
    })
  }

  @Builder
  private renderMineTab() {
    Scroll() {
      Column({ space: 12 }) {
        if (this.loggedIn) {
          Row({ space: 12 }) {
            if (this.currentUser !== null && this.currentUser.avatar.length > 0 && !this.avatarFailed) {
              Image(this.currentUser.avatar)
                .width(52)
                .height(52)
                .borderRadius(26)
                .objectFit(ImageFit.Cover)
                .onError(() => {
                  this.avatarFailed = true;
                })
            } else {
              Text(safeAvatarInitial(this.currentUser !== null ? this.currentUser.name : '我'))
                .width(52)
                .height(52)
                .borderRadius(26)
                .backgroundColor(getTheme(this.isDark).accentBg)
                .fontColor(getTheme(this.isDark).accent)
                .fontSize(22)
                .fontWeight(FontWeight.Medium)
                .textAlign(TextAlign.Center)
            }

            Column({ space: 4 }) {
              Text(
                this.currentUser !== null && this.currentUser.name.length > 0
                  ? this.currentUser.name
                  : '已登录用户'
              )
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(getTheme(this.isDark).textPrimary)
              Text(
                this.currentUser !== null && this.currentUser.uid > 0
                  ? `UID ${this.currentUser.uid} · 点击查看个人资料与主题`
                  : '点击查看个人资料与主题'
              )
                .fontSize(12)
                .fontColor(getTheme(this.isDark).textSecondary)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Text('资料 >')
              .fontSize(12)
              .fontColor(getTheme(this.isDark).accent)
          }
          .width('100%')
          .padding(14)
          .backgroundColor(getTheme(this.isDark).cardBg)
          .borderRadius(12)
          .onClick(() => {
            const uid = this.currentUser !== null ? this.currentUser.uid : 0;
            const name = this.currentUser !== null ? this.currentUser.name : '';
            this.openUserProfile(uid, name);
          })

          this.renderPunchOrBannerCard()

          this.renderMineEntryRow(
            '消息通知与私信',
            this.noticeEntrySubtitle(),
            () => {
              this.openNotifications();
            }
          )

          this.renderMineEntryRow(
            '我的云端收藏夹',
            '管理云端收藏分组、查看已收藏帖子与楼层',
            () => {
              this.openFavorites();
            }
          )

          this.renderMineEntryRow(
            '个人主页与帖子',
            '查看等级、积分统计、发表主题、回复帖子、精华与收藏夹',
            () => {
              const uid = this.currentUser !== null ? this.currentUser.uid : 0;
              const name = this.currentUser !== null ? this.currentUser.name : '';
              this.openUserProfile(uid, name);
            }
          )
        } else {
          Column({ space: 10 }) {
            Text('尚未登录龙空账号')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(getTheme(this.isDark).textPrimary)
            Text('登录后可使用每日签到、今日热帖、搜索、云端收藏夹、私信与个人主页。')
              .fontSize(12)
              .fontColor(getTheme(this.isDark).textSecondary)
              .lineHeight(18)
            Button('立即登录')
              .height(36)
              .width('100%')
              .backgroundColor(getTheme(this.isDark).accentSolid)
              .fontColor(Color.White)
              .onClick(() => {
                this.openLogin();
              })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(getTheme(this.isDark).cardBg)
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)
        }

        this.renderMineEntryRow(
          '综合搜索',
          '检索龙空帖子、版块与用户',
          () => {
            this.openSearch();
          }
        )

        this.renderMineEntryRow(
          '显示与设置',
          '切换深色/浅色主题、正文字号与登录态管理',
          () => {
            this.openSettings();
          }
        )
      }
      .padding({ left: 16, right: 16, bottom: 16 })
    }
    .layoutWeight(1)
  }

  @Builder
  private renderBottomTab(index: number, label: string, badgeCount: number = 0) {
    Column({ space: 4 }) {
      Divider()
        .width(24)
        .strokeWidth(3)
        .color(this.activeTab === index ? getTheme(this.isDark).accent : Color.Transparent)
      Row({ space: 3 }) {
        Text(label)
          .fontSize(13)
          .fontWeight(this.activeTab === index ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(
            this.activeTab === index
              ? getTheme(this.isDark).accent
              : getTheme(this.isDark).textSecondary
          )
        if (badgeCount > 0) {
          Text(formatNoticeUnreadBadge(badgeCount))
            .fontSize(9)
            .fontColor(Color.White)
            .backgroundColor(getTheme(this.isDark).badgeBg)
            .borderRadius(8)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
        }
      }
    }
    .layoutWeight(1)
    .height(54)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.switchTab(index);
    })
  }

  build() {
    Navigation(AppNavigator.getInstance().getStack()) {
      Column() {
        Row({ space: 8 }) {
          Text(this.topTitle())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(getTheme(this.isDark).textPrimary)
          Blank()
          if (this.loggedIn && this.activeTab !== 3) {
            Button(
              getVisibleUnreadTotal(this.noticeCount) > 0
                ? `消息 ${formatNoticeUnreadBadge(getVisibleUnreadTotal(this.noticeCount))}`
                : '消息'
            )
              .fontSize(12)
              .height(32)
              .backgroundColor(
                getVisibleUnreadTotal(this.noticeCount) > 0
                  ? getTheme(this.isDark).badgeBg
                  : getTheme(this.isDark).surfaceMuted
              )
              .fontColor(
                getVisibleUnreadTotal(this.noticeCount) > 0
                  ? Color.White
                  : getTheme(this.isDark).textPrimary
              )
              .onClick(() => {
                this.openNotifications();
              })
          }
          if (this.activeTab !== 3) {
            Button('搜索')
              .fontSize(12)
              .height(32)
              .backgroundColor(getTheme(this.isDark).surfaceMuted)
              .fontColor(getTheme(this.isDark).textPrimary)
              .onClick(() => {
                this.openSearch();
              })
          }
          if (this.activeTab === 0 || this.activeTab === 2) {
            Button(this.forumEditMode ? '完成' : '排序')
              .fontSize(12)
              .height(32)
              .backgroundColor(
                this.forumEditMode ? getTheme(this.isDark).accentSolid : getTheme(this.isDark).accentBg
              )
              .fontColor(this.forumEditMode ? Color.White : getTheme(this.isDark).accent)
              .onClick(() => {
                this.forumEditMode = !this.forumEditMode;
              })
          }
          if (this.activeTab === 0 || this.activeTab === 1) {
            Button('刷新')
              .fontSize(12)
              .height(32)
              .backgroundColor(getTheme(this.isDark).accentBg)
              .fontColor(getTheme(this.isDark).accent)
              .onClick(() => {
                this.refreshAll();
              })
          }
          if (this.activeTab === 3) {
            Button(this.loggedIn ? '设置' : '登录')
              .fontSize(12)
              .height(32)
              .backgroundColor(getTheme(this.isDark).accentSolid)
              .fontColor(Color.White)
              .onClick(() => {
                if (this.loggedIn) {
                  this.openSettings();
                } else {
                  this.openLogin();
                }
              })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })

        Tabs({ barPosition: BarPosition.End, index: 0, controller: this.tabsController }) {
          TabContent() {
            Column() {
              this.renderAllForumsTab()
            }
            .width('100%')
            .height('100%')
          }

          TabContent() {
            Column() {
              this.renderHotTab()
            }
            .width('100%')
            .height('100%')
          }

          TabContent() {
            Column() {
              this.renderPinnedTab()
            }
            .width('100%')
            .height('100%')
          }

          TabContent() {
            Column() {
              this.renderMineTab()
            }
            .width('100%')
            .height('100%')
          }
        }
        .barHeight(0)
        .scrollable(!this.forumEditMode)
        .animationDuration(220)
        .layoutWeight(1)
        .onAnimationStart((_index: number, targetIndex: number) => {
          this.applyTabChange(targetIndex);
        })
        .onChange((index: number) => {
          this.applyTabChange(index);
        })

        Divider()
          .color(getTheme(this.isDark).divider)
          .strokeWidth(1)

        Row() {
          this.renderBottomTab(0, '版块')
          this.renderBottomTab(1, '热帖')
          this.renderBottomTab(2, '常用')
          this.renderBottomTab(3, '我的', getVisibleUnreadTotal(this.noticeCount))
        }
        .width('100%')
        .backgroundColor(getTheme(this.isDark).tabBarBg)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(getTheme(this.isDark).pageBg)
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .hideToolBar(true)
    .navDestination(this.pageBuilder)
    .width('100%')
    .height('100%')
  }
}
