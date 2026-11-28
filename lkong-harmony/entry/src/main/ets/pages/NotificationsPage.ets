import {
  ApiError,
  AtMeItem,
  ErrorKind,
  FanNoticeItem,
  NoticeCount,
  NoticeItem,
  NoticeReplyUser,
  PmConversationItem,
  RateNoticeItem
} from '../model/Models';
import { LkongApi } from '../network/LkongApi';
import { CookieStore } from '../store/CookieStore';
import { DisplayPrefs } from '../store/DisplayPrefs';
import { StateView } from '../components/StateView';
import { safeAvatarInitial } from '../utils/AvatarUtils';
import { renderPostSummary } from '../utils/ContentUtils';
import { KEY_NOTICE_COUNT_DIRTY, KEY_PM_LIST_DIRTY } from '../utils/AppConfig';
import {
  AppNavigator,
  MessageChatRouteParams,
  Routes,
  ThreadRouteParams,
  UserProfileRouteParams
} from '../utils/AppRouter';
import { formatNoticeUnreadBadge } from '../utils/PostComposerUtils';
import { formatTime } from '../utils/TimeUtils';
import { getTheme, KEY_IS_DARK } from '../utils/Theme';
import { getHostContext, showToast } from '../utils/UiUtils';

/**
 * 站内消息通知中心：通知（回复/版务/系统公告）、@我、我的评分、新增粉丝（支持回关）与站内私信会话列表。
 */
@Component
export struct NotificationsPage {
  @State activeTab: number = 0;
  @State noticeCount: NoticeCount | null = null;

  @State notices: NoticeItem[] = [];
  @State noticesLoaded: boolean = false;
  @State noticesLoading: boolean = false;
  @State noticesRefreshing: boolean = false;
  @State noticesLoadingMore: boolean = false;
  @State noticesHasMore: boolean = false;
  @State noticesNextDate: string = '';
  @State noticesError: string = '';
  @State noticesNeedLogin: boolean = false;

  @State atMes: AtMeItem[] = [];
  @State atMesLoaded: boolean = false;
  @State atMesLoading: boolean = false;
  @State atMesRefreshing: boolean = false;
  @State atMesLoadingMore: boolean = false;
  @State atMesHasMore: boolean = false;
  @State atMesNextDate: string = '';
  @State atMesError: string = '';
  @State atMesNeedLogin: boolean = false;

  @State rateNotices: RateNoticeItem[] = [];
  @State rateLoaded: boolean = false;
  @State rateLoading: boolean = false;
  @State rateRefreshing: boolean = false;
  @State rateLoadingMore: boolean = false;
  @State rateHasMore: boolean = false;
  @State rateNextDate: string = '';
  @State rateError: string = '';
  @State rateNeedLogin: boolean = false;

  @State fansNotices: FanNoticeItem[] = [];
  @State fansLoaded: boolean = false;
  @State fansLoading: boolean = false;
  @State fansRefreshing: boolean = false;
  @State fansLoadingMore: boolean = false;
  @State fansHasMore: boolean = false;
  @State fansNextDate: string = '';
  @State fansError: string = '';
  @State fansNeedLogin: boolean = false;
  @State followingUid: number = 0;

  @State pmConversations: PmConversationItem[] = [];
  @State pmLoaded: boolean = false;
  @State pmLoading: boolean = false;
  @State pmRefreshing: boolean = false;
  @State pmLoadingMore: boolean = false;
  @State pmHasMore: boolean = false;
  @State pmNextDate: string = '';
  @State pmError: string = '';
  @State pmNeedLogin: boolean = false;
  @State deletePmTarget: PmConversationItem | null = null;
  @State deletingPm: boolean = false;

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;
  private tabsController: TabsController = new TabsController();
  private bootstrapped: boolean = false;

  aboutToAppear(): void {
    this.bootstrap();
  }

  private async bootstrap(): Promise<void> {
    const ctx = getHostContext(this.getUIContext());
    await CookieStore.getInstance().ensureInit(ctx);
    await DisplayPrefs.getInstance().ensureInit(ctx);
    this.bootstrapped = true;
    await this.loadCounts();
    await this.loadNotices(false);
  }

  private async loadCounts(): Promise<void> {
    if (!CookieStore.getInstance().hasCookie()) {
      this.noticeCount = null;
      return;
    }
    try {
      this.noticeCount = await LkongApi.getInstance().getNoticeCount();
      AppStorage.setOrCreate(KEY_NOTICE_COUNT_DIRTY, true);
    } catch (error) {
      // 角标拉取失败不阻塞消息列表展示。
    }
  }

  private tabUnreadCount(tabIndex: number): number {
    if (this.noticeCount === null) {
      return 0;
    }
    if (tabIndex === 0) {
      return this.noticeCount.noticeCount;
    }
    if (tabIndex === 1) {
      return this.noticeCount.atmeCount;
    }
    if (tabIndex === 2) {
      return this.noticeCount.rateCount;
    }
    if (tabIndex === 3) {
      return this.noticeCount.fansCount;
    }
    return this.noticeCount.pmCount;
  }

  private tabTitle(tabIndex: number, label: string): string {
    const count = this.tabUnreadCount(tabIndex);
    if (count > 0) {
      return `${label} ${formatNoticeUnreadBadge(count)}`;
    }
    return label;
  }

  private currentNeedLogin(): boolean {
    if (this.activeTab === 0) {
      return this.noticesNeedLogin;
    }
    if (this.activeTab === 1) {
      return this.atMesNeedLogin;
    }
    if (this.activeTab === 2) {
      return this.rateNeedLogin;
    }
    if (this.activeTab === 3) {
      return this.fansNeedLogin;
    }
    return this.pmNeedLogin;
  }

  private applyTabChange(index: number): void {
    if (index < 0 || index > 4) {
      return;
    }
    this.activeTab = index;
    if (index === 0 && !this.noticesLoaded && !this.noticesLoading) {
      this.loadNotices(false);
    } else if (index === 1 && !this.atMesLoaded && !this.atMesLoading) {
      this.loadAtMes(false);
    } else if (index === 2 && !this.rateLoaded && !this.rateLoading) {
      this.loadRateNotices(false);
    } else if (index === 3 && !this.fansLoaded && !this.fansLoading) {
      this.loadFansNotices(false);
    } else if (index === 4 && !this.pmLoaded && !this.pmLoading) {
      this.loadPmConversations(false);
    }
  }

  private switchTab(index: number): void {
    this.applyTabChange(index);
    this.tabsController.changeIndex(index);
  }

  private refreshCurrentTab(fromPull: boolean = false): void {
    this.loadCounts();
    if (this.activeTab === 0) {
      this.loadNotices(false, fromPull);
    } else if (this.activeTab === 1) {
      this.loadAtMes(false, fromPull);
    } else if (this.activeTab === 2) {
      this.loadRateNotices(false, fromPull);
    } else if (this.activeTab === 3) {
      this.loadFansNotices(false, fromPull);
    } else {
      this.loadPmConversations(false, fromPull);
    }
  }

  private async loadNotices(loadMore: boolean, fromPull: boolean = false): Promise<void> {
    if (loadMore) {
      if (this.noticesLoadingMore || !this.noticesHasMore || this.noticesNextDate.length === 0) {
        return;
      }
      this.noticesLoadingMore = true;
    } else {
      if (!fromPull) {
        this.noticesLoading = true;
      }
      this.noticesError = '';
      this.noticesNeedLogin = false;
    }

    try {
      const res = await LkongApi.getInstance().getNotices(loadMore ? this.noticesNextDate : '');
      if (loadMore) {
        const merged: NoticeItem[] = [];
        for (const item of this.notices) {
          merged.push(item);
        }
        for (const item of res.items) {
          merged.push(item);
        }
        this.notices = merged;
      } else {
        this.notices = res.items;
        this.noticesLoaded = true;
        this.loadCounts();
      }
      this.noticesHasMore = res.hasMore;
      this.noticesNextDate = res.nextDate;
    } catch (error) {
      if (error instanceof ApiError && error.kind === ErrorKind.AUTH) {
        this.noticesNeedLogin = true;
        this.noticesError = error.message;
      } else if (!loadMore) {
        this.noticesError = error instanceof ApiError ? error.message : '站内通知加载失败，请重试。';
      }
    } finally {
      this.noticesLoading = false;
      this.noticesRefreshing = false;
      this.noticesLoadingMore = false;
    }
  }

  private async loadAtMes(loadMore: boolean, fromPull: boolean = false): Promise<void> {
    if (loadMore) {
      if (this.atMesLoadingMore || !this.atMesHasMore || this.atMesNextDate.length === 0) {
        return;
      }
      this.atMesLoadingMore = true;
    } else {
      if (!fromPull) {
        this.atMesLoading = true;
      }
      this.atMesError = '';
      this.atMesNeedLogin = false;
    }

    try {
      const res = await LkongApi.getInstance().getAtMe(loadMore ? this.atMesNextDate : '');
      if (loadMore) {
        const merged: AtMeItem[] = [];
        for (const item of this.atMes) {
          merged.push(item);
        }
        for (const item of res.items) {
          merged.push(item);
        }
        this.atMes = merged;
      } else {
        this.atMes = res.items;
        this.atMesLoaded = true;
        this.loadCounts();
      }
      this.atMesHasMore = res.hasMore;
      this.atMesNextDate = res.nextDate;
    } catch (error) {
      if (error instanceof ApiError && error.kind === ErrorKind.AUTH) {
        this.atMesNeedLogin = true;
        this.atMesError = error.message;
      } else if (!loadMore) {
        this.atMesError = error instanceof ApiError ? error.message : '@我列表加载失败，请重试。';
      }
    } finally {
      this.atMesLoading = false;
      this.atMesRefreshing = false;
      this.atMesLoadingMore = false;
    }
  }

  private async loadRateNotices(loadMore: boolean, fromPull: boolean = false): Promise<void> {
    if (loadMore) {
      if (this.rateLoadingMore || !this.rateHasMore || this.rateNextDate.length === 0) {
        return;
      }
      this.rateLoadingMore = true;
    } else {
      if (!fromPull) {
        this.rateLoading = true;
      }
      this.rateError = '';
      this.rateNeedLogin = false;
    }

    try {
      const res = await LkongApi.getInstance().getRateNotices(loadMore ? this.rateNextDate : '');
      if (loadMore) {
        const merged: RateNoticeItem[] = [];
        for (const item of this.rateNotices) {
          merged.push(item);
        }
        for (const item of res.items) {
          merged.push(item);
        }
        this.rateNotices = merged;
      } else {
        this.rateNotices = res.items;
        this.rateLoaded = true;
        this.loadCounts();
      }
      this.rateHasMore = res.hasMore;
      this.rateNextDate = res.nextDate;
    } catch (error) {
      if (error instanceof ApiError && error.kind === ErrorKind.AUTH) {
        this.rateNeedLogin = true;
        this.rateError = error.message;
      } else if (!loadMore) {
        this.rateError = error instanceof ApiError ? error.message : '评分通知加载失败，请重试。';
      }
    } finally {
      this.rateLoading = false;
      this.rateRefreshing = false;
      this.rateLoadingMore = false;
    }
  }

  private async loadFansNotices(loadMore: boolean, fromPull: boolean = false): Promise<void> {
    if (loadMore) {
      if (this.fansLoadingMore || !this.fansHasMore || this.fansNextDate.length === 0) {
        return;
      }
      this.fansLoadingMore = true;
    } else {
      if (!fromPull) {
        this.fansLoading = true;
      }
      this.fansError = '';
      this.fansNeedLogin = false;
    }

    try {
      const res = await LkongApi.getInstance().getFansNotices(loadMore ? this.fansNextDate : '');
      if (loadMore) {
        const merged: FanNoticeItem[] = [];
        for (const item of this.fansNotices) {
          merged.push(item);
        }
        for (const item of res.items) {
          merged.push(item);
        }
        this.fansNotices = merged;
      } else {
        this.fansNotices = res.items;
        this.fansLoaded = true;
        this.loadCounts();
      }
      this.fansHasMore = res.hasMore;
      this.fansNextDate = res.nextDate;
    } catch (error) {
      if (error instanceof ApiError && error.kind === ErrorKind.AUTH) {
        this.fansNeedLogin = true;
        this.fansError = error.message;
      } else if (!loadMore) {
        this.fansError = error instanceof ApiError ? error.message : '粉丝列表加载失败，请重试。';
      }
    } finally {
      this.fansLoading = false;
      this.fansRefreshing = false;
      this.fansLoadingMore = false;
    }
  }

  private async loadPmConversations(loadMore: boolean, fromPull: boolean = false): Promise<void> {
    if (loadMore) {
      if (this.pmLoadingMore || !this.pmHasMore || this.pmNextDate.length === 0) {
        return;
      }
      this.pmLoadingMore = true;
    } else {
      if (!fromPull) {
        this.pmLoading = true;
      }
      this.pmError = '';
      this.pmNeedLogin = false;
    }

    try {
      const res = await LkongApi.getInstance().getPmConversations(loadMore ? this.pmNextDate : '');
      if (loadMore) {
        const seen = new Set<number>();
        const merged: PmConversationItem[] = [];
        for (const item of this.pmConversations) {
          merged.push(item);
          seen.add(item.uid);
        }
        for (const item of res.items) {
          if (!seen.has(item.uid)) {
            merged.push(item);
            seen.add(item.uid);
          }
        }
        this.pmConversations = merged;
      } else {
        this.pmConversations = res.items;
        this.pmLoaded = true;
        this.loadCounts();
      }
      this.pmHasMore = res.hasMore && res.nextDate.length > 0;
      this.pmNextDate = res.nextDate;
    } catch (error) {
      if (error instanceof ApiError && error.kind === ErrorKind.AUTH) {
        this.pmNeedLogin = true;
        this.pmError = error.message;
      } else if (!loadMore) {
        this.pmError = error instanceof ApiError ? error.message : '私信会话列表加载失败，请重试。';
      }
    } finally {
      this.pmLoading = false;
      this.pmRefreshing = false;
      this.pmLoadingMore = false;
    }
  }

  private async toggleFanFollow(fan: FanNoticeItem): Promise<void> {
    if (fan.uid <= 0 || this.followingUid !== 0) {
      return;
    }
    const nextFollow = !fan.isFollow;
    this.followingUid = fan.uid;
    try {
      const ok = await LkongApi.getInstance().followUser(fan.uid, nextFollow);
      if (ok) {
        const nextList: FanNoticeItem[] = [];
        for (const item of this.fansNotices) {
          if (item.uid === fan.uid) {
            nextList.push({
              uid: item.uid,
              name: item.name,
              avatarUrl: item.avatarUrl,
              isFollow: nextFollow,
              verifyInfo: item.verifyInfo,
              verifyType: item.verifyType
            });
          } else {
            nextList.push(item);
          }
        }
        this.fansNotices = nextList;
        showToast(this.getUIContext(), nextFollow ? `已关注 ${fan.name}` : `已取消关注 ${fan.name}`);
      } else {
        showToast(this.getUIContext(), '操作未生效，请重试');
      }
    } catch (error) {
      const msg = error instanceof ApiError ? error.message : '操作失败，请稍后重试。';
      showToast(this.getUIContext(), msg);
    } finally {
      this.followingUid = 0;
    }
  }

  private async confirmDeletePmConversation(): Promise<void> {
    if (this.deletePmTarget === null || this.deletingPm) {
      return;
    }
    const target = this.deletePmTarget;
    this.deletingPm = true;
    try {
      const ok = await LkongApi.getInstance().deletePmConversation(target.uid);
      if (ok) {
        const remaining: PmConversationItem[] = [];
        for (const item of this.pmConversations) {
          if (item.uid !== target.uid) {
            remaining.push(item);
          }
        }
        this.pmConversations = remaining;
        this.deletePmTarget = null;
        this.loadCounts();
        showToast(this.getUIContext(), '会话已删除');
      } else {
        showToast(this.getUIContext(), '删除未生效，请重试');
      }
    } catch (error) {
      const msg = error instanceof ApiError ? error.message : '删除失败，请稍后重试。';
      showToast(this.getUIContext(), msg);
    } finally {
      this.deletingPm = false;
    }
  }

  private goLogin(): void {
    AppNavigator.getInstance().push(Routes.LOGIN);
  }

  private openThread(tid: number, title: string, pid: string): void {
    if (tid <= 0) {
      return;
    }
    const params: ThreadRouteParams = {
      tid: tid,
      title: title,
      pid: pid
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

  private openPmChat(item: PmConversationItem): void {
    const params: MessageChatRouteParams = {
      uid: item.uid,
      name: item.name,
      avatarUrl: item.avatarUrl
    };
    AppNavigator.getInstance().push(Routes.MESSAGE_CHAT, params);
  }

  @Builder
  private renderTabBtn(index: number, label: string) {
    Button(this.tabTitle(index, label))
      .fontSize(11)
      .height(32)
      .padding({ left: 6, right: 6 })
      .layoutWeight(1)
      .backgroundColor(
        this.activeTab === index ? getTheme(this.isDark).accentSolid : getTheme(this.isDark).surfaceMuted
      )
      .fontColor(this.activeTab === index ? Color.White : getTheme(this.isDark).textPrimary)
      .onClick(() => {
        this.switchTab(index);
      })
  }

  @Builder
  private renderLoading(text: string) {
    Column() {
      LoadingProgress()
        .width(38)
        .height(38)
        .color(getTheme(this.isDark).accent)
      Text(text)
        .fontSize(13)
        .fontColor(getTheme(this.isDark).textSecondary)
        .margin({ top: 8 })
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private renderNeedLogin() {
    Column() {
      StateView({
        title: '需要登录',
        message: '查看站内消息通知需要先登录龙空账号。',
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
  private renderLoadMoreFooter(hasMore: boolean, loadingMore: boolean, onLoadMore: () => void) {
    ListItem() {
      Column() {
        if (hasMore) {
          Button(loadingMore ? '加载中...' : '加载更多')
            .fontSize(13)
            .height(36)
            .width('100%')
            .backgroundColor(getTheme(this.isDark).cardBg)
            .fontColor(getTheme(this.isDark).accent)
            .enabled(!loadingMore)
            .onClick(() => {
              onLoadMore();
            })
        } else {
          Text('已经到底了')
            .fontSize(12)
            .fontColor(getTheme(this.isDark).textMuted)
            .padding({ top: 8, bottom: 8 })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  private renderNoticesTab() {
    if (this.noticesLoading) {
      this.renderLoading('正在加载站内通知...')
    } else if (this.noticesNeedLogin) {
      this.renderNeedLogin()
    } else if (this.noticesError.length > 0) {
      Column() {
        StateView({
          title: '加载失败',
          message: this.noticesError,
          actionText: '重试',
          onAction: () => {
            this.loadNotices(false);
          }
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.notices.length === 0) {
      Column() {
        StateView({
          title: '暂无通知',
          message: '当前没有回复提醒或系统通知。'
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      Refresh({ refreshing: $$this.noticesRefreshing }) {
        List({ space: 10 }) {
          ForEach(this.notices, (item: NoticeItem, index: number) => {
            ListItem() {
              Column({ space: 6 }) {
                Text(item.summary)
                  .width('100%')
                  .fontSize(14)
                  .fontColor(getTheme(this.isDark).textPrimary)
                  .lineHeight(20)

                if (item.title.length > 0) {
                  Text(item.title)
                    .width('100%')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(getTheme(this.isDark).accent)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }

                if (item.replyUsers.length > 0) {
                  Row({ space: 6 }) {
                    ForEach(item.replyUsers.slice(0, 3), (ru: NoticeReplyUser) => {
                      Text(`@${ru.name}`)
                        .fontSize(11)
                        .fontColor(getTheme(this.isDark).accent)
                        .backgroundColor(getTheme(this.isDark).accentBg)
                        .borderRadius(4)
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .onClick(() => {
                          if (item.tid > 0 && ru.pid.length > 0) {
                            this.openThread(item.tid, item.title, ru.pid);
                          } else {
                            this.openUserProfile(ru.uid, ru.name);
                          }
                        })
                    }, (ru: NoticeReplyUser) => `${this.isDark ? 'd' : 'l'}_${item.id}_${ru.uid}_${ru.pid}`)
                  }
                  .width('100%')
                }

                if (item.dateline.length > 0) {
                  Text(formatTime(item.dateline))
                    .fontSize(11)
                    .fontColor(getTheme(this.isDark).textMuted)
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor(getTheme(this.isDark).cardBg)
              .borderRadius(12)
              .alignItems(HorizontalAlign.Start)
              .onClick(() => {
                if (item.tid > 0) {
                  this.openThread(item.tid, item.title, item.pid);
                }
              })
            }
          }, (item: NoticeItem, index: number) => `${this.isDark ? 'd' : 'l'}_n_${item.id}_${index}`)

          this.renderLoadMoreFooter(this.noticesHasMore, this.noticesLoadingMore, () => {
            this.loadNotices(true);
          })
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16, bottom: 12 })
        .scrollBar(BarState.Auto)
      }
      .layoutWeight(1)
      .onRefreshing(() => {
        this.loadNotices(false, true);
      })
    }
  }

  @Builder
  private renderAtMeTab() {
    if (this.atMesLoading) {
      this.renderLoading('正在加载 @我 记录...')
    } else if (this.atMesNeedLogin) {
      this.renderNeedLogin()
    } else if (this.atMesError.length > 0) {
      Column() {
        StateView({
          title: '加载失败',
          message: this.atMesError,
          actionText: '重试',
          onAction: () => {
            this.loadAtMes(false);
          }
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.atMes.length === 0) {
      Column() {
        StateView({
          title: '暂无 @我',
          message: '还没有收到提及你的帖子。'
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      Refresh({ refreshing: $$this.atMesRefreshing }) {
        List({ space: 10 }) {
          ForEach(this.atMes, (item: AtMeItem, index: number) => {
            ListItem() {
              Column({ space: 6 }) {
                Row({ space: 8 }) {
                  Text(item.authorName.length > 0 ? item.authorName : '匿名用户')
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(
                      item.authorId > 0 ? getTheme(this.isDark).accent : getTheme(this.isDark).textPrimary
                    )
                    .onClick(() => {
                      this.openUserProfile(item.authorId, item.authorName);
                    })
                  if (item.forumName.length > 0) {
                    Text(item.forumName)
                      .fontSize(11)
                      .fontColor(getTheme(this.isDark).textSecondary)
                      .backgroundColor(getTheme(this.isDark).surfaceMuted)
                      .borderRadius(4)
                      .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                  }
                  Blank()
                  Text(formatTime(item.dateline))
                    .fontSize(11)
                    .fontColor(getTheme(this.isDark).textMuted)
                }
                .width('100%')

                if (item.title.length > 0) {
                  Text(item.title)
                    .width('100%')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(getTheme(this.isDark).textPrimary)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }

                if (item.contentHtml.length > 0) {
                  Text(renderPostSummary(item.contentHtml, 120))
                    .width('100%')
                    .fontSize(13)
                    .lineHeight(19)
                    .fontColor(getTheme(this.isDark).textSecondary)
                    .maxLines(3)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor(getTheme(this.isDark).cardBg)
              .borderRadius(12)
              .alignItems(HorizontalAlign.Start)
              .onClick(() => {
                this.openThread(item.tid, item.title, item.pid);
              })
            }
          }, (item: AtMeItem, index: number) => `${this.isDark ? 'd' : 'l'}_at_${item.pid}_${index}`)

          this.renderLoadMoreFooter(this.atMesHasMore, this.atMesLoadingMore, () => {
            this.loadAtMes(true);
          })
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16, bottom: 12 })
        .scrollBar(BarState.Auto)
      }
      .layoutWeight(1)
      .onRefreshing(() => {
        this.loadAtMes(false, true);
      })
    }
  }

  @Builder
  private renderRateTab() {
    if (this.rateLoading) {
      this.renderLoading('正在加载评分通知...')
    } else if (this.rateNeedLogin) {
      this.renderNeedLogin()
    } else if (this.rateError.length > 0) {
      Column() {
        StateView({
          title: '加载失败',
          message: this.rateError,
          actionText: '重试',
          onAction: () => {
            this.loadRateNotices(false);
          }
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.rateNotices.length === 0) {
      Column() {
        StateView({
          title: '暂无评分通知',
          message: '还没有收到过楼层龙币评分。'
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      Refresh({ refreshing: $$this.rateRefreshing }) {
        List({ space: 10 }) {
          ForEach(this.rateNotices, (item: RateNoticeItem, index: number) => {
            ListItem() {
              Column({ space: 6 }) {
                Row({ space: 8 }) {
                  Text(item.userName.length > 0 ? item.userName : '坛友')
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(
                      item.userId > 0 ? getTheme(this.isDark).accent : getTheme(this.isDark).textPrimary
                    )
                    .onClick(() => {
                      this.openUserProfile(item.userId, item.userName);
                    })
                  Text('给你评分')
                    .fontSize(13)
                    .fontColor(getTheme(this.isDark).textSecondary)
                  Text(`${item.num > 0 ? '+' : ''}${item.num} 龙币`)
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(
                      item.num >= 0 ? getTheme(this.isDark).successText : getTheme(this.isDark).dangerText
                    )
                    .backgroundColor(
                      item.num >= 0 ? getTheme(this.isDark).successBg : getTheme(this.isDark).dangerBg
                    )
                    .borderRadius(4)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  Blank()
                  Text(formatTime(item.dateline))
                    .fontSize(11)
                    .fontColor(getTheme(this.isDark).textMuted)
                }
                .width('100%')

                if (item.title.length > 0) {
                  Text(item.title)
                    .width('100%')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(getTheme(this.isDark).textPrimary)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor(getTheme(this.isDark).cardBg)
              .borderRadius(12)
              .alignItems(HorizontalAlign.Start)
              .onClick(() => {
                this.openThread(item.tid, item.title, item.pid);
              })
            }
          }, (item: RateNoticeItem, index: number) =>
            `${this.isDark ? 'd' : 'l'}_r_${item.rid}_${item.pid}_${index}`
          )

          this.renderLoadMoreFooter(this.rateHasMore, this.rateLoadingMore, () => {
            this.loadRateNotices(true);
          })
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16, bottom: 12 })
        .scrollBar(BarState.Auto)
      }
      .layoutWeight(1)
      .onRefreshing(() => {
        this.loadRateNotices(false, true);
      })
    }
  }

  @Builder
  private renderFansTab() {
    if (this.fansLoading) {
      this.renderLoading('正在加载粉丝通知...')
    } else if (this.fansNeedLogin) {
      this.renderNeedLogin()
    } else if (this.fansError.length > 0) {
      Column() {
        StateView({
          title: '加载失败',
          message: this.fansError,
          actionText: '重试',
          onAction: () => {
            this.loadFansNotices(false);
          }
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.fansNotices.length === 0) {
      Column() {
        StateView({
          title: '暂无新增粉丝',
          message: '当前还没有新的关注者。'
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      Refresh({ refreshing: $$this.fansRefreshing }) {
        List({ space: 10 }) {
          ForEach(this.fansNotices, (item: FanNoticeItem, index: number) => {
            ListItem() {
              Row({ space: 10 }) {
                if (item.avatarUrl.length > 0) {
                  Image(item.avatarUrl)
                    .width(42)
                    .height(42)
                    .borderRadius(21)
                    .objectFit(ImageFit.Cover)
                } else {
                  Text(safeAvatarInitial(item.name))
                    .width(42)
                    .height(42)
                    .borderRadius(21)
                    .backgroundColor(getTheme(this.isDark).accentBg)
                    .fontColor(getTheme(this.isDark).accent)
                    .fontSize(17)
                    .fontWeight(FontWeight.Medium)
                    .textAlign(TextAlign.Center)
                }

                Column({ space: 3 }) {
                  Text(item.name)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(getTheme(this.isDark).textPrimary)
                  if (item.verifyInfo.length > 0) {
                    Text(item.verifyInfo)
                      .fontSize(12)
                      .fontColor(getTheme(this.isDark).accent)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  } else {
                    Text(item.isFollow ? '已互相关注' : '关注了你')
                      .fontSize(12)
                      .fontColor(getTheme(this.isDark).textSecondary)
                  }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Button(
                  this.followingUid === item.uid
                    ? '处理中'
                    : (item.isFollow ? '已关注' : '回关')
                )
                  .fontSize(11)
                  .height(28)
                  .backgroundColor(
                    item.isFollow ? getTheme(this.isDark).surfaceMuted : getTheme(this.isDark).accentSolid
                  )
                  .fontColor(item.isFollow ? getTheme(this.isDark).textPrimary : Color.White)
                  .enabled(this.followingUid === 0)
                  .onClick(() => {
                    this.toggleFanFollow(item);
                  })
              }
              .width('100%')
              .padding(14)
              .backgroundColor(getTheme(this.isDark).cardBg)
              .borderRadius(12)
              .onClick(() => {
                this.openUserProfile(item.uid, item.name);
              })
            }
          }, (item: FanNoticeItem, index: number) =>
            `${this.isDark ? 'd' : 'l'}_fan_${item.uid}_${item.isFollow ? '1' : '0'}_${this.followingUid}_${index}`
          )

          this.renderLoadMoreFooter(this.fansHasMore, this.fansLoadingMore, () => {
            this.loadFansNotices(true);
          })
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16, bottom: 12 })
        .scrollBar(BarState.Auto)
      }
      .layoutWeight(1)
      .onRefreshing(() => {
        this.loadFansNotices(false, true);
      })
    }
  }

  @Builder
  private renderPmTab() {
    if (this.pmLoading) {
      this.renderLoading('正在加载私信会话...')
    } else if (this.pmNeedLogin) {
      this.renderNeedLogin()
    } else if (this.pmError.length > 0) {
      Column() {
        StateView({
          title: '加载失败',
          message: this.pmError,
          actionText: '重试',
          onAction: () => {
            this.loadPmConversations(false);
          }
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.pmConversations.length === 0) {
      Column() {
        StateView({
          title: '暂无私信会话',
          message: '可以从任意坛友的个人主页点击「发私信」发起对话。'
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      Refresh({ refreshing: $$this.pmRefreshing }) {
        List({ space: 10 }) {
          ForEach(this.pmConversations, (item: PmConversationItem, index: number) => {
            ListItem() {
              Row({ space: 10 }) {
                if (item.avatarUrl.length > 0) {
                  Image(item.avatarUrl)
                    .width(44)
                    .height(44)
                    .borderRadius(22)
                    .objectFit(ImageFit.Cover)
                } else {
                  Text(safeAvatarInitial(item.name))
                    .width(44)
                    .height(44)
                    .borderRadius(22)
                    .backgroundColor(getTheme(this.isDark).accentBg)
                    .fontColor(getTheme(this.isDark).accent)
                    .fontSize(17)
                    .fontWeight(FontWeight.Medium)
                    .textAlign(TextAlign.Center)
                }

                Column({ space: 4 }) {
                  Row({ space: 6 }) {
                    Text(item.name.length > 0 ? item.name : `用户 #${item.uid}`)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(getTheme(this.isDark).textPrimary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)

                    if (item.newCount > 0) {
                      Text(formatNoticeUnreadBadge(item.newCount))
                        .fontSize(10)
                        .fontColor(Color.White)
                        .backgroundColor(getTheme(this.isDark).badgeBg)
                        .borderRadius(8)
                        .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                    }

                    if (item.lastTime.length > 0) {
                      Text(formatTime(item.lastTime))
                        .fontSize(11)
                        .fontColor(getTheme(this.isDark).textMuted)
                    }
                  }
                  .width('100%')

                  Row({ space: 8 }) {
                    Text(item.content.length > 0 ? renderPostSummary(item.content, 60) : '（图片/无内容）')
                      .fontSize(13)
                      .fontColor(getTheme(this.isDark).textSecondary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)

                    Button('删除')
                      .fontSize(11)
                      .height(24)
                      .backgroundColor(getTheme(this.isDark).dangerBg)
                      .fontColor(getTheme(this.isDark).dangerText)
                      .onClick(() => {
                        this.deletePmTarget = item;
                      })
                  }
                  .width('100%')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding(14)
              .backgroundColor(getTheme(this.isDark).cardBg)
              .borderRadius(12)
              .onClick(() => {
                this.openPmChat(item);
              })
            }
          }, (item: PmConversationItem, index: number) =>
            `${this.isDark ? 'd' : 'l'}_pmc_${item.uid}_${item.newCount}_${item.lastTime}_${index}`
          )

          this.renderLoadMoreFooter(this.pmHasMore, this.pmLoadingMore, () => {
            this.loadPmConversations(true);
          })
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16, bottom: 12 })
        .scrollBar(BarState.Auto)
      }
      .layoutWeight(1)
      .onRefreshing(() => {
        this.loadPmConversations(false, true);
      })
    }
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          Row({ space: 8 }) {
            Button('返回')
              .fontSize(12)
              .height(32)
              .backgroundColor(getTheme(this.isDark).accentBg)
              .fontColor(getTheme(this.isDark).accent)
              .onClick(() => {
                AppNavigator.getInstance().pop();
              })
            Text('消息通知')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(getTheme(this.isDark).textPrimary)
              .layoutWeight(1)
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
          .padding({ left: 16, right: 16, top: 12, bottom: 10 })

          Row({ space: 5 }) {
            this.renderTabBtn(0, '通知')
            this.renderTabBtn(1, '@我')
            this.renderTabBtn(2, '评分')
            this.renderTabBtn(3, '粉丝')
            this.renderTabBtn(4, '私信')
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 10 })

          Tabs({ barPosition: BarPosition.Start, index: 0, controller: this.tabsController }) {
            TabContent() {
              Column() {
                this.renderNoticesTab()
              }
              .width('100%')
              .height('100%')
            }

            TabContent() {
              Column() {
                this.renderAtMeTab()
              }
              .width('100%')
              .height('100%')
            }

            TabContent() {
              Column() {
                this.renderRateTab()
              }
              .width('100%')
              .height('100%')
            }

            TabContent() {
              Column() {
                this.renderFansTab()
              }
              .width('100%')
              .height('100%')
            }

            TabContent() {
              Column() {
                this.renderPmTab()
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

        if (this.deletePmTarget !== null) {
          Column() {
            Column({ space: 12 }) {
              Text('删除私信会话')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(getTheme(this.isDark).textPrimary)
              Text(`确认删除与「${this.deletePmTarget.name}」的私信会话记录吗？`)
                .fontSize(13)
                .fontColor(getTheme(this.isDark).textSecondary)
                .lineHeight(20)

              Row({ space: 10 }) {
                Button('取消')
                  .fontSize(13)
                  .height(36)
                  .layoutWeight(1)
                  .backgroundColor(getTheme(this.isDark).surfaceMuted)
                  .fontColor(getTheme(this.isDark).textSecondary)
                  .onClick(() => {
                    this.deletePmTarget = null;
                  })
                Button(this.deletingPm ? '删除中...' : '确认删除')
                  .fontSize(13)
                  .height(36)
                  .layoutWeight(1)
                  .backgroundColor(getTheme(this.isDark).dangerBg)
                  .fontColor(getTheme(this.isDark).dangerText)
                  .enabled(!this.deletingPm)
                  .onClick(() => {
                    this.confirmDeletePmConversation();
                  })
              }
              .width('100%')
            }
            .width('84%')
            .padding(16)
            .backgroundColor(getTheme(this.isDark).cardBg)
            .borderRadius(14)
            .alignItems(HorizontalAlign.Start)
            .onClick(() => {
            })
          }
          .width('100%')
          .height('100%')
          .backgroundColor('#80000000')
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.deletePmTarget = null;
          })
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .onShown(() => {
      if (!this.bootstrapped || !CookieStore.getInstance().hasCookie()) {
        return;
      }
      const pmDirty = AppStorage.get<boolean>(KEY_PM_LIST_DIRTY);
      if (pmDirty === true) {
        AppStorage.setOrCreate(KEY_PM_LIST_DIRTY, false);
        this.loadCounts();
        if (this.activeTab === 4 || this.pmLoaded) {
          this.loadPmConversations(false);
        }
        return;
      }
      if (this.currentNeedLogin()) {
        this.refreshCurrentTab();
      }
    })
    .onBackPressed(() => {
      if (this.deletePmTarget !== null) {
        this.deletePmTarget = null;
        return true;
      }
      return false;
    })
  }
}
