import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import {
  ApiError,
  AtMeItem,
  ErrorKind,
  FanNoticeItem,
  NoticeCount,
  NoticeItem,
  NoticeReplyUser,
  RateNoticeItem
} from '../model/Models';
import { LkongApi } from '../network/LkongApi';
import { CookieStore } from '../store/CookieStore';
import { DisplayPrefs } from '../store/DisplayPrefs';
import { StateView } from '../components/StateView';
import { safeAvatarInitial } from '../utils/AvatarUtils';
import { renderPostSummary } from '../utils/ContentUtils';
import { KEY_NOTICE_COUNT_DIRTY } from '../utils/AppConfig';
import { formatNoticeUnreadBadge } from '../utils/PostComposerUtils';
import { formatTime } from '../utils/TimeUtils';
import { getTheme, KEY_IS_DARK } from '../utils/Theme';

/**
 * 站内消息通知中心：通知（回复/版务/系统公告）、@我、我的评分、新增粉丝。
 */
@Entry
@Component
struct NotificationsPage {
  @State activeTab: number = 0;
  @State noticeCount: NoticeCount | null = null;

  @State notices: NoticeItem[] = [];
  @State noticesLoaded: boolean = false;
  @State noticesLoading: boolean = false;
  @State noticesLoadingMore: boolean = false;
  @State noticesHasMore: boolean = false;
  @State noticesNextDate: string = '';
  @State noticesError: string = '';
  @State noticesNeedLogin: boolean = false;

  @State atMes: AtMeItem[] = [];
  @State atMesLoaded: boolean = false;
  @State atMesLoading: boolean = false;
  @State atMesLoadingMore: boolean = false;
  @State atMesHasMore: boolean = false;
  @State atMesNextDate: string = '';
  @State atMesError: string = '';
  @State atMesNeedLogin: boolean = false;

  @State rateNotices: RateNoticeItem[] = [];
  @State rateLoaded: boolean = false;
  @State rateLoading: boolean = false;
  @State rateLoadingMore: boolean = false;
  @State rateHasMore: boolean = false;
  @State rateNextDate: string = '';
  @State rateError: string = '';
  @State rateNeedLogin: boolean = false;

  @State fansNotices: FanNoticeItem[] = [];
  @State fansLoaded: boolean = false;
  @State fansLoading: boolean = false;
  @State fansLoadingMore: boolean = false;
  @State fansHasMore: boolean = false;
  @State fansNextDate: string = '';
  @State fansError: string = '';
  @State fansNeedLogin: boolean = false;

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;
  private bootstrapped: boolean = false;

  aboutToAppear(): void {
    this.bootstrap();
  }

  onPageShow(): void {
    if (!this.bootstrapped || !CookieStore.getInstance().hasCookie()) {
      return;
    }
    if (this.currentNeedLogin()) {
      this.refreshCurrentTab();
    }
  }

  private async bootstrap(): Promise<void> {
    const ctx = getContext(this) as common.Context;
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
    return this.noticeCount.fansCount;
  }

  private tabTitle(tabIndex: number, label: string): string {
    const count = this.tabUnreadCount(tabIndex);
    if (count > 0) {
      return `${label} (${formatNoticeUnreadBadge(count)})`;
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
    return this.fansNeedLogin;
  }

  private switchTab(index: number): void {
    if (this.activeTab === index) {
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
    }
  }

  private refreshCurrentTab(): void {
    this.loadCounts();
    if (this.activeTab === 0) {
      this.loadNotices(false);
    } else if (this.activeTab === 1) {
      this.loadAtMes(false);
    } else if (this.activeTab === 2) {
      this.loadRateNotices(false);
    } else {
      this.loadFansNotices(false);
    }
  }

  private async loadNotices(loadMore: boolean): Promise<void> {
    if (loadMore) {
      if (this.noticesLoadingMore || !this.noticesHasMore || this.noticesNextDate.length === 0) {
        return;
      }
      this.noticesLoadingMore = true;
    } else {
      this.noticesLoading = true;
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
      this.noticesLoadingMore = false;
    }
  }

  private async loadAtMes(loadMore: boolean): Promise<void> {
    if (loadMore) {
      if (this.atMesLoadingMore || !this.atMesHasMore || this.atMesNextDate.length === 0) {
        return;
      }
      this.atMesLoadingMore = true;
    } else {
      this.atMesLoading = true;
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
      this.atMesLoadingMore = false;
    }
  }

  private async loadRateNotices(loadMore: boolean): Promise<void> {
    if (loadMore) {
      if (this.rateLoadingMore || !this.rateHasMore || this.rateNextDate.length === 0) {
        return;
      }
      this.rateLoadingMore = true;
    } else {
      this.rateLoading = true;
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
      this.rateLoadingMore = false;
    }
  }

  private async loadFansNotices(loadMore: boolean): Promise<void> {
    if (loadMore) {
      if (this.fansLoadingMore || !this.fansHasMore || this.fansNextDate.length === 0) {
        return;
      }
      this.fansLoadingMore = true;
    } else {
      this.fansLoading = true;
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
      this.fansLoadingMore = false;
    }
  }

  private goLogin(): void {
    router.pushUrl({ url: 'pages/LoginPage' }).catch(() => {
    });
  }

  private openThread(tid: number, title: string, pid: string): void {
    if (tid <= 0) {
      return;
    }
    router.pushUrl({
      url: 'pages/ThreadPage',
      params: {
        tid: tid,
        title: title,
        pid: pid
      }
    }).catch(() => {
    });
  }

  private openUserProfile(uid: number, name: string): void {
    if (uid <= 0) {
      return;
    }
    router.pushUrl({
      url: 'pages/UserProfilePage',
      params: {
        uid: uid,
        name: name
      }
    }).catch(() => {
    });
  }

  @Builder
  private renderTabBtn(index: number, label: string) {
    Button(this.tabTitle(index, label))
      .fontSize(12)
      .height(32)
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
      .layoutWeight(1)
      .padding({ left: 16, right: 16, bottom: 12 })
      .scrollBar(BarState.Auto)
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
      .layoutWeight(1)
      .padding({ left: 16, right: 16, bottom: 12 })
      .scrollBar(BarState.Auto)
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
      .layoutWeight(1)
      .padding({ left: 16, right: 16, bottom: 12 })
      .scrollBar(BarState.Auto)
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
      List({ space: 10 }) {
        ForEach(this.fansNotices, (item: FanNoticeItem, index: number) => {
          ListItem() {
            Row({ space: 12 }) {
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
                  Text(item.isFollow ? '已互相关注 · 点击查看资料' : '关注了你 · 点击查看资料')
                    .fontSize(12)
                    .fontColor(getTheme(this.isDark).textSecondary)
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Text('主页 >')
                .fontSize(12)
                .fontColor(getTheme(this.isDark).accent)
            }
            .width('100%')
            .padding(14)
            .backgroundColor(getTheme(this.isDark).cardBg)
            .borderRadius(12)
            .onClick(() => {
              this.openUserProfile(item.uid, item.name);
            })
          }
        }, (item: FanNoticeItem, index: number) => `${this.isDark ? 'd' : 'l'}_fan_${item.uid}_${index}`)

        this.renderLoadMoreFooter(this.fansHasMore, this.fansLoadingMore, () => {
          this.loadFansNotices(true);
        })
      }
      .layoutWeight(1)
      .padding({ left: 16, right: 16, bottom: 12 })
      .scrollBar(BarState.Auto)
    }
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Button('返回')
          .fontSize(12)
          .height(32)
          .backgroundColor(getTheme(this.isDark).accentBg)
          .fontColor(getTheme(this.isDark).accent)
          .onClick(() => {
            router.back();
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

      Row({ space: 6 }) {
        this.renderTabBtn(0, '通知')
        this.renderTabBtn(1, '@我')
        this.renderTabBtn(2, '评分')
        this.renderTabBtn(3, '粉丝')
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 10 })

      if (this.noticeCount !== null && this.noticeCount.pmCount > 0) {
        Column() {
          Text(`另有 ${this.noticeCount.pmCount} 条私信未读（私信收发功能计划在 v1.4.0 支持）`)
            .fontSize(12)
            .fontColor(getTheme(this.isDark).bannerText)
            .width('100%')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor(getTheme(this.isDark).bannerBg)
            .borderRadius(8)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })
      }

      if (this.activeTab === 0) {
        this.renderNoticesTab()
      } else if (this.activeTab === 1) {
        this.renderAtMeTab()
      } else if (this.activeTab === 2) {
        this.renderRateTab()
      } else {
        this.renderFansTab()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(getTheme(this.isDark).pageBg)
  }
}
