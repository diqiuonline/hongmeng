import { ApiError, ErrorKind, HotThread, ThreadSummary } from '../model/Models';
import { LkongApi } from '../network/LkongApi';
import { CookieStore } from '../store/CookieStore';
import { DisplayPrefs } from '../store/DisplayPrefs';
import { StateView } from '../components/StateView';
import { ThreadRow } from '../components/ThreadRow';
import { KEY_FORUM_REFRESH_FID } from '../utils/AppConfig';
import {
  AppNavigator,
  ComposeRouteParams,
  ForumRouteParams,
  Routes,
  ThreadRouteParams,
  UserProfileRouteParams
} from '../utils/AppRouter';
import { formatTime } from '../utils/TimeUtils';
import { getTheme, KEY_IS_DARK } from '../utils/Theme';
import { getHostContext, showToast } from '../utils/UiUtils';

interface ForumFilterOption {
  index: number;
  value: string;
  label: string;
}

const FORUM_FILTERS: ForumFilterOption[] = [
  { index: 0, value: '', label: '全部' },
  { index: 1, value: 'hot', label: '热门' },
  { index: 2, value: 'new', label: '最新' },
  { index: 3, value: 'digest', label: '精华' }
];

/**
 * 版块页：支持 全部 / 热门（今日热门）/ 最新 / 精华 4 个 Tab 点选与左右滑动切换、下拉刷新、分页与发新帖入口。
 */
@Component
export struct ForumPage {
  @State fid: number = 0;
  @State forumName: string = '';
  @State activeTab: number = 0;

  @State allThreads: ThreadSummary[] = [];
  @State allPage: number = 1;
  @State allHasMore: boolean = true;
  @State allLoaded: boolean = false;
  @State allLoading: boolean = true;
  @State allRefreshing: boolean = false;
  @State allError: string = '';
  @State allNeedLogin: boolean = false;

  @State digestThreads: ThreadSummary[] = [];
  @State digestPage: number = 1;
  @State digestHasMore: boolean = true;
  @State digestLoaded: boolean = false;
  @State digestLoading: boolean = false;
  @State digestRefreshing: boolean = false;
  @State digestError: string = '';
  @State digestNeedLogin: boolean = false;

  @State newThreads: ThreadSummary[] = [];
  @State newPage: number = 1;
  @State newHasMore: boolean = true;
  @State newLoaded: boolean = false;
  @State newLoading: boolean = false;
  @State newRefreshing: boolean = false;
  @State newError: string = '';
  @State newNeedLogin: boolean = false;

  @State hotThreads: HotThread[] = [];
  @State hotLoaded: boolean = false;
  @State hotLoading: boolean = false;
  @State hotRefreshing: boolean = false;
  @State hotError: string = '';
  @State hotNeedLogin: boolean = false;

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;

  private tabsController: TabsController = new TabsController();
  private readyHandled: boolean = false;
  private bootstrapped: boolean = false;
  private allFetching: boolean = false;
  private digestFetching: boolean = false;
  private newFetching: boolean = false;
  private hotFetching: boolean = false;

  private async bootstrap(): Promise<void> {
    const ctx = getHostContext(this.getUIContext());
    await CookieStore.getInstance().ensureInit(ctx);
    await DisplayPrefs.getInstance().ensureInit(ctx);
    this.bootstrapped = true;
    await this.loadThreadTab(0, 1);
  }

  private actionForTab(tabIndex: number): string {
    if (tabIndex === 2) {
      return 'new';
    }
    if (tabIndex === 3) {
      return 'digest';
    }
    return '';
  }

  private isThreadTabFetching(tabIndex: number): boolean {
    if (tabIndex === 0) {
      return this.allFetching;
    }
    if (tabIndex === 2) {
      return this.newFetching;
    }
    return this.digestFetching;
  }

  private setThreadTabFetching(tabIndex: number, fetching: boolean): void {
    if (tabIndex === 0) {
      this.allFetching = fetching;
    } else if (tabIndex === 2) {
      this.newFetching = fetching;
    } else {
      this.digestFetching = fetching;
    }
  }

  private beginThreadTabLoad(tabIndex: number, fromRefresh: boolean): void {
    if (tabIndex === 0) {
      if (!fromRefresh) {
        this.allLoading = true;
      }
      this.allError = '';
      this.allNeedLogin = false;
    } else if (tabIndex === 2) {
      if (!fromRefresh) {
        this.newLoading = true;
      }
      this.newError = '';
      this.newNeedLogin = false;
    } else {
      if (!fromRefresh) {
        this.digestLoading = true;
      }
      this.digestError = '';
      this.digestNeedLogin = false;
    }
  }

  private applyThreadTabSuccess(tabIndex: number, page: number, threads: ThreadSummary[]): void {
    const hasMore = threads.length > 0;
    if (tabIndex === 0) {
      this.allPage = page;
      this.allThreads = threads;
      this.allHasMore = hasMore;
      this.allLoaded = true;
    } else if (tabIndex === 2) {
      this.newPage = page;
      this.newThreads = threads;
      this.newHasMore = hasMore;
      this.newLoaded = true;
    } else {
      this.digestPage = page;
      this.digestThreads = threads;
      this.digestHasMore = hasMore;
      this.digestLoaded = true;
    }
  }

  private applyThreadTabError(tabIndex: number, needLogin: boolean, message: string): void {
    if (tabIndex === 0) {
      this.allNeedLogin = needLogin;
      this.allError = message;
    } else if (tabIndex === 2) {
      this.newNeedLogin = needLogin;
      this.newError = message;
    } else {
      this.digestNeedLogin = needLogin;
      this.digestError = message;
    }
  }

  private finishThreadTabLoad(tabIndex: number): void {
    this.setThreadTabFetching(tabIndex, false);
    if (tabIndex === 0) {
      this.allLoading = false;
      this.allRefreshing = false;
    } else if (tabIndex === 2) {
      this.newLoading = false;
      this.newRefreshing = false;
    } else {
      this.digestLoading = false;
      this.digestRefreshing = false;
    }
  }

  private async loadThreadTab(tabIndex: number, targetPage: number, fromRefresh: boolean = false): Promise<void> {
    if (this.isThreadTabFetching(tabIndex)) {
      if (fromRefresh) {
        this.finishThreadTabLoad(tabIndex);
      }
      return;
    }
    const safePage = targetPage < 1 ? 1 : targetPage;
    this.setThreadTabFetching(tabIndex, true);
    this.beginThreadTabLoad(tabIndex, fromRefresh);
    try {
      const data = await LkongApi.getInstance().getForumThreads(
        this.fid,
        safePage,
        this.actionForTab(tabIndex)
      );
      if (data.forumName.length > 0) {
        this.forumName = data.forumName;
      }
      this.applyThreadTabSuccess(tabIndex, safePage, data.threads);
    } catch (error) {
      if (error instanceof ApiError && error.kind === ErrorKind.AUTH) {
        this.applyThreadTabError(tabIndex, true, error.message);
      } else if (error instanceof ApiError) {
        this.applyThreadTabError(tabIndex, false, error.message);
      } else {
        this.applyThreadTabError(tabIndex, false, '版块加载失败，请稍后重试。');
      }
    } finally {
      this.finishThreadTabLoad(tabIndex);
    }
  }

  private async loadHotThreads(fromRefresh: boolean = false): Promise<void> {
    if (this.hotFetching) {
      if (fromRefresh) {
        this.hotRefreshing = false;
      }
      return;
    }
    this.hotFetching = true;
    if (!fromRefresh) {
      this.hotLoading = true;
    }
    this.hotError = '';
    this.hotNeedLogin = false;
    try {
      this.hotThreads = await LkongApi.getInstance().getForumHotThreads(this.fid);
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
      this.hotFetching = false;
      this.hotLoading = false;
      this.hotRefreshing = false;
    }
  }

  private applyTabChange(index: number): void {
    if (index < 0 || index > 3) {
      return;
    }
    if (this.activeTab !== index) {
      this.activeTab = index;
    }
    if (index === 0 && !this.allLoaded && !this.allFetching) {
      this.loadThreadTab(0, this.allPage);
    } else if (index === 1 && !this.hotLoaded && !this.hotFetching) {
      this.loadHotThreads();
    } else if (index === 2 && !this.newLoaded && !this.newFetching) {
      this.loadThreadTab(2, this.newPage);
    } else if (index === 3 && !this.digestLoaded && !this.digestFetching) {
      this.loadThreadTab(3, this.digestPage);
    }
  }

  private switchTab(index: number): void {
    this.applyTabChange(index);
    this.tabsController.changeIndex(index);
  }

  private pageForTab(tabIndex: number): number {
    if (tabIndex === 2) {
      return this.newPage;
    }
    if (tabIndex === 3) {
      return this.digestPage;
    }
    return this.allPage;
  }

  private currentNeedLogin(): boolean {
    if (this.activeTab === 0) {
      return this.allNeedLogin;
    }
    if (this.activeTab === 1) {
      return this.hotNeedLogin;
    }
    if (this.activeTab === 2) {
      return this.newNeedLogin;
    }
    return this.digestNeedLogin;
  }

  private refreshCurrentTab(fromRefresh: boolean = false): void {
    if (this.activeTab === 1) {
      this.loadHotThreads(fromRefresh);
      return;
    }
    this.loadThreadTab(this.activeTab, this.pageForTab(this.activeTab), fromRefresh);
  }

  private previousPage(tabIndex: number): void {
    const current = this.pageForTab(tabIndex);
    if (current > 1 && !this.isThreadTabFetching(tabIndex)) {
      this.loadThreadTab(tabIndex, current - 1);
    }
  }

  private nextPage(tabIndex: number, hasMore: boolean): void {
    if (hasMore && !this.isThreadTabFetching(tabIndex)) {
      this.loadThreadTab(tabIndex, this.pageForTab(tabIndex) + 1);
    }
  }

  private goLogin(): void {
    AppNavigator.getInstance().push(Routes.LOGIN);
  }

  private openComposeNewThread(): void {
    if (!CookieStore.getInstance().hasCookie()) {
      showToast(this.getUIContext(), '请先登录后再发帖');
      this.goLogin();
      return;
    }
    const params: ComposeRouteParams = {
      mode: 'new',
      fid: this.fid,
      forumName: this.forumName
    };
    AppNavigator.getInstance().push(Routes.COMPOSE, params);
  }

  private openThread(tid: number, title: string): void {
    const params: ThreadRouteParams = {
      tid: tid,
      title: title
    };
    AppNavigator.getInstance().push(Routes.THREAD, params);
  }

  private openUserProfile(uid: number, name: string): void {
    if (uid <= 0) {
      return;
    }
    const params: UserProfileRouteParams = {
      uid: uid,
      name: name
    };
    AppNavigator.getInstance().push(Routes.USER_PROFILE, params);
  }

  @Builder
  private renderLoadingView(label: string) {
    Column() {
      LoadingProgress()
        .width(40)
        .height(40)
        .color(getTheme(this.isDark).accent)
      Text(label)
        .fontSize(13)
        .fontColor(getTheme(this.isDark).textSecondary)
        .margin({ top: 8 })
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private renderNeedLoginView() {
    Column() {
      StateView({
        title: '需要登录',
        message: '龙空版块需要登录后才能浏览，请先登录账号。',
        actionText: '去登录',
        onAction: () => {
          this.goLogin();
        }
      })
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private renderErrorView(message: string, onRetry: () => void) {
    Column() {
      StateView({
        title: '加载失败',
        message: message,
        actionText: '重试',
        onAction: () => {
          onRetry();
        }
      })
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private renderThreadListBody(tabIndex: number, threads: ThreadSummary[]) {
    List({ space: 10 }) {
      ForEach(threads, (thread: ThreadSummary, index: number) => {
        ListItem() {
          ThreadRow({
            title: thread.title,
            authorName: thread.authorName,
            authorId: thread.authorId,
            replyCount: thread.replyCount,
            viewCount: thread.viewCount,
            lastPostTime: formatTime(thread.lastPostTime),
            isDigest: thread.isDigest,
            isTop: thread.isTop,
            onOpen: () => {
              this.openThread(thread.tid, thread.title);
            },
            onAuthorClick: (uid: number, name: string) => {
              this.openUserProfile(uid, name);
            }
          })
        }
      }, (thread: ThreadSummary, index: number) =>
        `${this.isDark ? 'd' : 'l'}_${tabIndex}_${this.pageForTab(tabIndex)}_${thread.tid}_${index}`
      )
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
    .scrollBar(BarState.Auto)
  }

  @Builder
  private renderPaginationBar(tabIndex: number, page: number, hasMore: boolean) {
    Row({ space: 12 }) {
      Button('上一页')
        .fontSize(13)
        .height(34)
        .backgroundColor(
          page > 1 ? getTheme(this.isDark).accentSolid : getTheme(this.isDark).disabledBtnBg
        )
        .fontColor(page > 1 ? Color.White : getTheme(this.isDark).disabledBtnText)
        .enabled(page > 1)
        .onClick(() => {
          this.previousPage(tabIndex);
        })
      Text(`第 ${page} 页`)
        .fontSize(13)
        .fontColor(getTheme(this.isDark).textSecondary)
      Button('下一页')
        .fontSize(13)
        .height(34)
        .backgroundColor(
          hasMore ? getTheme(this.isDark).accentSolid : getTheme(this.isDark).disabledBtnBg
        )
        .fontColor(hasMore ? Color.White : getTheme(this.isDark).disabledBtnText)
        .enabled(hasMore)
        .onClick(() => {
          this.nextPage(tabIndex, hasMore);
        })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding(12)
  }

  @Builder
  private renderAllTab() {
    if (this.allLoading) {
      this.renderLoadingView('正在加载帖子...')
    } else if (this.allNeedLogin) {
      this.renderNeedLoginView()
    } else if (this.allError.length > 0) {
      this.renderErrorView(this.allError, () => {
        this.loadThreadTab(0, this.allPage);
      })
    } else if (this.allThreads.length === 0) {
      Column() {
        StateView({
          title: '暂无帖子',
          message: '这个版块当前筛选下没有可显示的帖子。'
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      Refresh({ refreshing: $$this.allRefreshing }) {
        this.renderThreadListBody(0, this.allThreads)
      }
      .layoutWeight(1)
      .onRefreshing(() => {
        this.loadThreadTab(0, this.allPage, true);
      })

      this.renderPaginationBar(0, this.allPage, this.allHasMore)
    }
  }

  @Builder
  private renderDigestTab() {
    if (this.digestLoading) {
      this.renderLoadingView('正在加载精华帖子...')
    } else if (this.digestNeedLogin) {
      this.renderNeedLoginView()
    } else if (this.digestError.length > 0) {
      this.renderErrorView(this.digestError, () => {
        this.loadThreadTab(3, this.digestPage);
      })
    } else if (this.digestThreads.length === 0) {
      Column() {
        StateView({
          title: '暂无精华帖子',
          message: '这个版块精华分类下没有可显示的帖子。'
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      Refresh({ refreshing: $$this.digestRefreshing }) {
        this.renderThreadListBody(3, this.digestThreads)
      }
      .layoutWeight(1)
      .onRefreshing(() => {
        this.loadThreadTab(3, this.digestPage, true);
      })

      this.renderPaginationBar(3, this.digestPage, this.digestHasMore)
    }
  }

  @Builder
  private renderNewTab() {
    if (this.newLoading) {
      this.renderLoadingView('正在加载最新帖子...')
    } else if (this.newNeedLogin) {
      this.renderNeedLoginView()
    } else if (this.newError.length > 0) {
      this.renderErrorView(this.newError, () => {
        this.loadThreadTab(2, this.newPage);
      })
    } else if (this.newThreads.length === 0) {
      Column() {
        StateView({
          title: '暂无最新帖子',
          message: '这个版块最新分类下没有可显示的帖子。'
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      Refresh({ refreshing: $$this.newRefreshing }) {
        this.renderThreadListBody(2, this.newThreads)
      }
      .layoutWeight(1)
      .onRefreshing(() => {
        this.loadThreadTab(2, this.newPage, true);
      })

      this.renderPaginationBar(2, this.newPage, this.newHasMore)
    }
  }

  @Builder
  private renderHotTab() {
    if (this.hotLoading) {
      this.renderLoadingView('正在加载版块今日热门...')
    } else if (this.hotNeedLogin) {
      this.renderNeedLoginView()
    } else if (this.hotError.length > 0) {
      this.renderErrorView(this.hotError, () => {
        this.loadHotThreads();
      })
    } else if (this.hotThreads.length === 0) {
      Column() {
        StateView({
          title: '今日暂无热门帖子',
          message: '当前版块今天还没有进入今日热门的帖子。',
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
          }, (item: HotThread, index: number) =>
            `${this.isDark ? 'd' : 'l'}_fhot_${this.fid}_${item.tid}_${index}`
          )
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

  build() {
    NavDestination() {
      Column() {
        Row() {
          Button('返回')
            .fontSize(12)
            .height(32)
            .backgroundColor(getTheme(this.isDark).accentBg)
            .fontColor(getTheme(this.isDark).accent)
            .margin({ right: 8 })
            .onClick(() => {
              AppNavigator.getInstance().pop();
            })
          Text(this.forumName.length > 0 ? this.forumName : '版块')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(getTheme(this.isDark).textPrimary)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Button('发帖')
            .fontSize(12)
            .height(32)
            .backgroundColor(getTheme(this.isDark).accentSolid)
            .fontColor(Color.White)
            .margin({ right: 6 })
            .onClick(() => {
              this.openComposeNewThread();
            })
          Button('刷新')
            .fontSize(12)
            .height(32)
            .backgroundColor(getTheme(this.isDark).accentBg)
            .fontColor(getTheme(this.isDark).accent)
            .onClick(() => {
              this.refreshCurrentTab();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })

        Row({ space: 8 }) {
          ForEach(FORUM_FILTERS, (opt: ForumFilterOption) => {
            Button(opt.label)
              .fontSize(12)
              .height(28)
              .layoutWeight(1)
              .backgroundColor(
                this.activeTab === opt.index
                  ? getTheme(this.isDark).accentSolid
                  : getTheme(this.isDark).surfaceMuted
              )
              .fontColor(
                this.activeTab === opt.index
                  ? Color.White
                  : getTheme(this.isDark).textPrimary
              )
              .onClick(() => {
                this.switchTab(opt.index);
              })
          }, (opt: ForumFilterOption) => `${this.isDark ? 'd' : 'l'}_ff_${this.activeTab}_${opt.index}`)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 10 })

        Tabs({ barPosition: BarPosition.Start, index: 0, controller: this.tabsController }) {
          TabContent() {
            Column() {
              this.renderAllTab()
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
              this.renderNewTab()
            }
            .width('100%')
            .height('100%')
          }

          TabContent() {
            Column() {
              this.renderDigestTab()
            }
            .width('100%')
            .height('100%')
          }
        }
        .barHeight(0)
        .scrollable(true)
        .animationDuration(220)
        .layoutWeight(1)
        .onAnimationStart((_index: number, targetIndex: number) => {
          this.applyTabChange(targetIndex);
        })
        .onChange((index: number) => {
          this.applyTabChange(index);
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(getTheme(this.isDark).pageBg)
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      if (this.readyHandled) {
        return;
      }
      this.readyHandled = true;
      const params = ctx.pathInfo.param as ForumRouteParams | undefined | null;
      if (params !== undefined && params !== null) {
        this.fid = params.fid === undefined ? 0 : params.fid;
        this.forumName = params.name === undefined ? '' : params.name;
      }
      this.bootstrap();
    })
    .onShown(() => {
      if (!this.bootstrapped) {
        return;
      }
      const refreshFid = AppStorage.get<number>(KEY_FORUM_REFRESH_FID);
      if (refreshFid !== undefined && refreshFid === this.fid && this.fid > 0) {
        AppStorage.setOrCreate(KEY_FORUM_REFRESH_FID, 0);
        this.allPage = 1;
        this.digestPage = 1;
        this.newPage = 1;
        this.allLoaded = false;
        this.digestLoaded = false;
        this.newLoaded = false;
        this.hotLoaded = false;
        if (this.activeTab === 1) {
          this.loadHotThreads();
        } else {
          this.loadThreadTab(this.activeTab, 1);
        }
        return;
      }
      if (this.currentNeedLogin() && CookieStore.getInstance().hasCookie()) {
        this.refreshCurrentTab();
      }
    })
  }
}
