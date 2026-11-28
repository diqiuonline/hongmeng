import { pasteboard } from '@kit.BasicServicesKit';
import {
  ApiError,
  ErrorKind,
  FavoriteGroup,
  PostItem,
  ThreadImageItem,
  ThreadSummary,
  UserPostItem,
  UserProfile
} from '../model/Models';
import { LkongApi } from '../network/LkongApi';
import { CookieStore } from '../store/CookieStore';
import { DisplayPrefs } from '../store/DisplayPrefs';
import { ImageViewerOverlay } from '../components/ImageViewerOverlay';
import { PostCard } from '../components/PostCard';
import { StateView } from '../components/StateView';
import { ThreadRow } from '../components/ThreadRow';
import {
  AppNavigator,
  FavoriteDetailRouteParams,
  ForumRouteParams,
  MessageChatRouteParams,
  Routes,
  ThreadRouteParams,
  UserProfileRouteParams
} from '../utils/AppRouter';
import { safeAvatarInitial } from '../utils/AvatarUtils';
import { extractImagesFromPosts, renderPostSummary } from '../utils/ContentUtils';
import { LkongLinkKind, parseLkongUrl } from '../utils/LkongLinkUtils';
import { formatTime } from '../utils/TimeUtils';
import { getTheme, KEY_IS_DARK } from '../utils/Theme';
import { getHostContext, showToast } from '../utils/UiUtils';

const ITEMS_PER_PAGE: number = 20;

function postTypeLabel(typeName: string): string {
  if (typeName === 'MajorPost') {
    return '主贴';
  }
  if (typeName === 'MajorReply' || typeName === 'MinorPost') {
    return '回复';
  }
  if (typeName === 'MajorBookReview') {
    return '书评';
  }
  if (typeName === 'MajorBookReviewReply') {
    return '书评回复';
  }
  return '帖子';
}

@Component
struct UserPostCard {
  @Prop item: UserPostItem;
  @Prop authorName: string = '';
  onOpenThread: (item: UserPostItem) => void = () => {
  };
  onOpenImage: (item: UserPostItem, url: string) => void = () => {
  };
  onOpenLink: (url: string) => void = () => {
  };
  onOpenAuthor: (uid: number, name: string) => void = () => {
  };

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;
  @State expanded: boolean = true;

  build() {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Text(postTypeLabel(this.item.typeName))
          .fontSize(10)
          .fontColor(getTheme(this.isDark).accent)
          .backgroundColor(getTheme(this.isDark).accentBg)
          .borderRadius(4)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })

        if (this.item.forumName.length > 0) {
          Text(this.item.forumName)
            .fontSize(10)
            .fontColor(getTheme(this.isDark).textSecondary)
            .backgroundColor(getTheme(this.isDark).surfaceMuted)
            .borderRadius(4)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: 110 })
        }

        if (this.item.bookScore > 0) {
          Text(`评分 ${this.item.bookScore}`)
            .fontSize(10)
            .fontColor(getTheme(this.isDark).bannerText)
            .backgroundColor(getTheme(this.isDark).bannerBg)
            .borderRadius(4)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        }

        Blank()

        Text(formatTime(this.item.dateline))
          .fontSize(11)
          .fontColor(getTheme(this.isDark).textMuted)
      }
      .width('100%')

      Text(this.item.title)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(getTheme(this.isDark).textPrimary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (!this.expanded) {
        if (this.item.quoteContentHtml.length > 0) {
          Text(
            this.item.quoteAuthorName.length > 0
              ? `引用 @${this.item.quoteAuthorName}：${renderPostSummary(this.item.quoteContentHtml, 90)}`
              : `引用：${renderPostSummary(this.item.quoteContentHtml, 90)}`
          )
            .width('100%')
            .fontSize(12)
            .lineHeight(18)
            .fontColor(getTheme(this.isDark).textSecondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(getTheme(this.isDark).quoteBg)
            .border({ width: { left: 3 }, color: getTheme(this.isDark).quoteBorder })
            .borderRadius(6)
        }

        Text(renderPostSummary(this.item.contentHtml, 160))
          .width('100%')
          .fontSize(13)
          .lineHeight(20)
          .fontColor(getTheme(this.isDark).textSecondary)
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      } else {
        PostCard({
          pid: this.item.pid,
          floor: '',
          authorName: this.authorName,
          authorId: 0,
          postTime: formatTime(this.item.dateline),
          contentHtml: this.item.contentHtml,
          isAuthor: false,
          quotePid: this.item.quotePid,
          quoteStatus: '',
          quoteAuthorId: this.item.quoteAuthorId,
          quoteAuthorName: this.item.quoteAuthorName,
          quoteContentHtml: this.item.quoteContentHtml,
          canReply: false,
          canEdit: false,
          canRate: false,
          canFavorite: false,
          showHeader: false,
          embedded: true,
          onImageClick: (url: string) => {
            this.onOpenImage(this.item, url);
          },
          onLinkClick: (url: string) => {
            this.onOpenLink(url);
          },
          onAuthorClick: (uid: number, name: string) => {
            this.onOpenAuthor(uid, name);
          }
        })
      }

      Row({ space: 8 }) {
        Blank()

        Text(this.expanded ? '收起详情' : '展开详情')
          .fontSize(11)
          .fontColor(getTheme(this.isDark).accent)
          .backgroundColor(getTheme(this.isDark).accentBg)
          .borderRadius(4)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .onClick(() => {
            this.expanded = !this.expanded;
          })

        if (this.item.tid > 0) {
          Text('查看原帖 >')
            .fontSize(11)
            .fontColor(Color.White)
            .backgroundColor(getTheme(this.isDark).accentSolid)
            .borderRadius(4)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .onClick(() => {
              this.onOpenThread(this.item);
            })
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(getTheme(this.isDark).cardBg)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.onOpenThread(this.item);
    })
  }
}

/**
 * 个人资料页：支持查看本人与任意坛友的资料统计、主题 / 帖子（含全文详情展开与看图）/ 精华 / 云端收藏夹
 * 4 个 Tab 点选与左右滑动切换、关注/取关与发私信。
 */
@Component
export struct UserProfilePage {
  @State targetUid: number = 0;
  @State resolvedUid: number = 0;
  @State fallbackName: string = '';
  @State profile: UserProfile | null = null;
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State needLogin: boolean = false;
  @State avatarFailed: boolean = false;
  @State followSubmitting: boolean = false;

  @State activeSubTab: number = 0;

  @State threads: ThreadSummary[] = [];
  @State page: number = 1;
  @State hasMoreThreads: boolean = false;
  @State threadsLoading: boolean = false;
  @State threadsError: string = '';

  @State posts: UserPostItem[] = [];
  @State postsPage: number = 1;
  @State hasMorePosts: boolean = false;
  @State postsLoaded: boolean = false;
  @State postsLoading: boolean = false;
  @State postsError: string = '';

  @State digests: UserPostItem[] = [];
  @State digestsPage: number = 1;
  @State hasMoreDigests: boolean = false;
  @State digestsLoaded: boolean = false;
  @State digestsLoading: boolean = false;
  @State digestsError: string = '';

  @State favGroups: FavoriteGroup[] = [];
  @State favLoaded: boolean = false;
  @State favLoading: boolean = false;
  @State favError: string = '';

  @State showImageViewer: boolean = false;
  @State previewImages: ThreadImageItem[] = [];
  @State previewIndex: number = 0;
  @State activeLinkUrl: string = '';

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;
  private tabsController: TabsController = new TabsController();
  private outerScroller: Scroller = new Scroller();
  private readyHandled: boolean = false;
  private bootstrapped: boolean = false;

  private async bootstrap(): Promise<void> {
    const ctx = getHostContext(this.getUIContext());
    await CookieStore.getInstance().ensureInit(ctx);
    await DisplayPrefs.getInstance().ensureInit(ctx);
    this.bootstrapped = true;
    await this.loadProfile();
  }

  private async loadProfile(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    this.needLogin = false;
    this.threadsError = '';
    this.avatarFailed = false;
    this.postsLoaded = false;
    this.posts = [];
    this.postsPage = 1;
    this.hasMorePosts = false;
    this.postsError = '';
    this.digestsLoaded = false;
    this.digests = [];
    this.digestsPage = 1;
    this.hasMoreDigests = false;
    this.digestsError = '';
    this.favLoaded = false;
    this.favGroups = [];
    this.favError = '';

    try {
      const data = await LkongApi.getInstance().getUserProfilePage(this.targetUid, 1);
      this.profile = data.profile;
      this.resolvedUid = data.profile.uid;
      this.threads = data.threads;
      this.page = 1;
      this.hasMoreThreads = this.computeHasMore(data.threads.length, 1, data.profile.threads);
      if (this.activeSubTab === 1) {
        this.loadPostsPage(1, false);
      } else if (this.activeSubTab === 2) {
        this.loadPostsPage(1, true);
      } else if (this.activeSubTab === 3) {
        this.loadFavoriteGroups();
      }
    } catch (error) {
      if (error instanceof ApiError && error.kind === ErrorKind.AUTH) {
        this.needLogin = true;
        this.errorMessage = error.message;
      } else if (error instanceof ApiError) {
        this.errorMessage = error.message;
      } else {
        this.errorMessage = '用户资料加载失败，请稍后重试。';
      }
    } finally {
      this.loading = false;
    }
  }

  private computeHasMore(loadedCount: number, currentPage: number, totalCount: number): boolean {
    if (loadedCount === 0) {
      return false;
    }
    if (totalCount > 0) {
      return currentPage * ITEMS_PER_PAGE < totalCount || loadedCount >= ITEMS_PER_PAGE;
    }
    return loadedCount >= ITEMS_PER_PAGE;
  }

  private async loadThreadsPage(targetPage: number): Promise<void> {
    if (this.resolvedUid <= 0 || this.threadsLoading) {
      return;
    }
    this.threadsLoading = true;
    this.threadsError = '';
    try {
      const list = await LkongApi.getInstance().getUserThreads(this.resolvedUid, targetPage);
      this.page = targetPage;
      this.threads = list;
      const totalCount = this.profile !== null ? this.profile.threads : 0;
      this.hasMoreThreads = this.computeHasMore(list.length, targetPage, totalCount);
    } catch (error) {
      if (error instanceof ApiError && error.kind === ErrorKind.AUTH) {
        this.needLogin = true;
        this.errorMessage = error.message;
      } else if (error instanceof ApiError) {
        this.threadsError = error.message;
      } else {
        this.threadsError = '主题列表加载失败，请稍后重试。';
      }
    } finally {
      this.threadsLoading = false;
    }
  }

  private async loadPostsPage(targetPage: number, isDigest: boolean): Promise<void> {
    const busy = isDigest ? this.digestsLoading : this.postsLoading;
    if (this.resolvedUid <= 0 || busy) {
      return;
    }
    if (isDigest) {
      this.digestsLoading = true;
      this.digestsError = '';
    } else {
      this.postsLoading = true;
      this.postsError = '';
    }
    try {
      const list = await LkongApi.getInstance().getUserPosts(this.resolvedUid, targetPage, isDigest);
      if (isDigest) {
        this.digestsPage = targetPage;
        this.digests = list;
        this.digestsLoaded = true;
        const totalDigests = this.profile !== null ? this.profile.digests : 0;
        this.hasMoreDigests = this.computeHasMore(list.length, targetPage, totalDigests);
      } else {
        this.postsPage = targetPage;
        this.posts = list;
        this.postsLoaded = true;
        const totalPosts = this.profile !== null ? this.profile.posts : 0;
        this.hasMorePosts = this.computeHasMore(list.length, targetPage, totalPosts);
      }
    } catch (error) {
      if (error instanceof ApiError && error.kind === ErrorKind.AUTH) {
        this.needLogin = true;
        this.errorMessage = error.message;
      } else {
        const msg = error instanceof ApiError
          ? error.message
          : (isDigest ? '精华列表加载失败，请稍后重试。' : '帖子列表加载失败，请稍后重试。');
        if (isDigest) {
          this.digestsError = msg;
        } else {
          this.postsError = msg;
        }
      }
    } finally {
      if (isDigest) {
        this.digestsLoading = false;
      } else {
        this.postsLoading = false;
      }
    }
  }

  private async loadFavoriteGroups(): Promise<void> {
    if (this.resolvedUid <= 0 || this.favLoading) {
      return;
    }
    this.favLoading = true;
    this.favError = '';
    try {
      this.favGroups = await LkongApi.getInstance().getUserFavoriteGroups(this.resolvedUid);
      this.favLoaded = true;
    } catch (error) {
      if (error instanceof ApiError) {
        this.favError = error.message;
      } else {
        this.favError = '收藏夹加载失败，请稍后重试。';
      }
    } finally {
      this.favLoading = false;
    }
  }

  private applySubTabChange(index: number): void {
    if (index < 0 || index > 3) {
      return;
    }
    this.activeSubTab = index;
    if (this.resolvedUid <= 0) {
      return;
    }
    if (index === 1 && !this.postsLoaded && !this.postsLoading) {
      this.loadPostsPage(1, false);
    } else if (index === 2 && !this.digestsLoaded && !this.digestsLoading) {
      this.loadPostsPage(1, true);
    } else if (index === 3 && !this.favLoaded && !this.favLoading) {
      this.loadFavoriteGroups();
    }
  }

  private switchSubTab(index: number): void {
    this.applySubTabChange(index);
    this.tabsController.changeIndex(index);
  }

  private displayName(): string {
    if (this.profile !== null && this.profile.name.length > 0) {
      return this.profile.name;
    }
    if (this.fallbackName.length > 0) {
      return this.fallbackName;
    }
    return '个人资料';
  }

  private isSelf(): boolean {
    const me = LkongApi.getInstance().getCachedCurrentUser();
    return me !== null && me.uid > 0 && this.resolvedUid > 0 && me.uid === this.resolvedUid;
  }

  private goLogin(): void {
    AppNavigator.getInstance().push(Routes.LOGIN);
  }

  private openThread(tid: number, title: string, pid: string = ''): void {
    if (tid <= 0) {
      showToast(this.getUIContext(), '该条内容暂无可跳转的原帖');
      return;
    }
    const params: ThreadRouteParams = {
      tid: tid,
      title: title,
      pid: pid
    };
    AppNavigator.getInstance().push(Routes.THREAD, params);
  }

  private openOtherUserProfile(uid: number, name: string): void {
    if (uid <= 0 || uid === this.resolvedUid) {
      return;
    }
    const params: UserProfileRouteParams = {
      uid: uid,
      name: name
    };
    AppNavigator.getInstance().push(Routes.USER_PROFILE, params);
  }

  private openUserPostImageViewer(item: UserPostItem, clickedUrl: string): void {
    const tempPost: PostItem = {
      pid: item.pid,
      floor: '',
      authorName: this.displayName(),
      authorId: this.resolvedUid,
      postTime: item.dateline,
      contentHtml: item.contentHtml,
      subject: '',
      isAuthor: true,
      quote: null,
      rates: []
    };
    const images = extractImagesFromPosts([tempPost]);
    let idx = -1;
    for (let i = 0; i < images.length; i++) {
      if (images[i].url === clickedUrl) {
        idx = i;
        break;
      }
    }
    if (images.length === 0) {
      images.push({
        url: clickedUrl,
        pid: item.pid,
        floor: '',
        authorName: this.displayName()
      });
      idx = 0;
    }
    this.previewImages = images;
    this.previewIndex = idx >= 0 ? idx : 0;
    this.showImageViewer = true;
  }

  private async copyActiveLink(): Promise<void> {
    if (this.activeLinkUrl.length === 0) {
      return;
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.activeLinkUrl);
      await pasteboard.getSystemPasteboard().setData(data);
      showToast(this.getUIContext(), '链接已复制到剪贴板');
      this.activeLinkUrl = '';
    } catch (error) {
      showToast(this.getUIContext(), '复制失败，请稍后重试');
    }
  }

  private openActiveLkongLink(): void {
    const parsed = parseLkongUrl(this.activeLinkUrl);
    this.activeLinkUrl = '';
    if (parsed.kind === LkongLinkKind.THREAD) {
      const params: ThreadRouteParams = {
        tid: parsed.id,
        title: `帖子 #${parsed.id}`,
        pid: parsed.pid
      };
      AppNavigator.getInstance().push(Routes.THREAD, params);
    } else if (parsed.kind === LkongLinkKind.FORUM) {
      const params: ForumRouteParams = {
        fid: parsed.id,
        name: `版块 #${parsed.id}`
      };
      AppNavigator.getInstance().push(Routes.FORUM, params);
    } else if (parsed.kind === LkongLinkKind.USER) {
      const params: UserProfileRouteParams = {
        uid: parsed.id,
        name: ''
      };
      AppNavigator.getInstance().push(Routes.USER_PROFILE, params);
    }
  }

  private openFavoriteGroup(group: FavoriteGroup): void {
    const params: FavoriteDetailRouteParams = {
      groupId: group.id,
      title: group.title,
      isMine: this.isSelf()
    };
    AppNavigator.getInstance().push(Routes.FAVORITE_DETAIL, params);
  }

  private openMyFavoritesManager(): void {
    AppNavigator.getInstance().push(Routes.FAVORITES);
  }

  private openSettings(): void {
    AppNavigator.getInstance().push(Routes.SETTINGS);
  }

  private openMessageChat(): void {
    if (this.profile === null || this.profile.uid <= 0) {
      return;
    }
    if (!CookieStore.getInstance().hasCookie()) {
      showToast(this.getUIContext(), '请先登录后再发送私信');
      this.goLogin();
      return;
    }
    const params: MessageChatRouteParams = {
      uid: this.profile.uid,
      name: this.displayName(),
      avatarUrl: this.profile.avatarUrl
    };
    AppNavigator.getInstance().push(Routes.MESSAGE_CHAT, params);
  }

  private async toggleFollow(): Promise<void> {
    if (this.profile === null || this.profile.uid <= 0 || this.followSubmitting) {
      return;
    }
    if (!CookieStore.getInstance().hasCookie()) {
      showToast(this.getUIContext(), '请先登录后再关注');
      this.goLogin();
      return;
    }
    const current = this.profile;
    const nextFollow = !current.isFollow;
    this.followSubmitting = true;
    try {
      const ok = await LkongApi.getInstance().followUser(current.uid, nextFollow);
      if (ok) {
        const nextFollowers = nextFollow
          ? current.followers + 1
          : Math.max(0, current.followers - 1);
        this.profile = {
          uid: current.uid,
          name: current.name,
          avatarUrl: current.avatarUrl,
          dateline: current.dateline,
          points: current.points,
          gender: current.gender,
          status: current.status,
          adminLevel: current.adminLevel,
          isFollow: nextFollow,
          verifyInfo: current.verifyInfo,
          verifyType: current.verifyType,
          followings: current.followings,
          followers: nextFollowers,
          digests: current.digests,
          posts: current.posts,
          threads: current.threads,
          money: current.money,
          gems: current.gems,
          levelName: current.levelName,
          levelColor: current.levelColor,
          levelNum: current.levelNum
        };
        showToast(this.getUIContext(), nextFollow ? `已关注 ${this.displayName()}` : `已取消关注 ${this.displayName()}`);
      } else {
        showToast(this.getUIContext(), '操作未生效，请稍后重试');
      }
    } catch (error) {
      const msg = error instanceof ApiError ? error.message : '操作失败，请稍后重试。';
      showToast(this.getUIContext(), msg);
    } finally {
      this.followSubmitting = false;
    }
  }

  @Builder
  private renderStatCell(label: string, value: string, targetTab: number = -1) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(getTheme(this.isDark).textPrimary)
        .maxLines(1)
      Text(label)
        .fontSize(11)
        .fontColor(getTheme(this.isDark).textMuted)
    }
    .layoutWeight(1)
    .padding({ top: 6, bottom: 6 })
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      if (targetTab >= 0) {
        this.switchSubTab(targetTab);
      }
    })
  }

  @Builder
  private renderSubTabBtn(index: number, label: string) {
    Button(label)
      .fontSize(12)
      .height(34)
      .layoutWeight(1)
      .padding({ left: 4, right: 4 })
      .backgroundColor(
        this.activeSubTab === index
          ? getTheme(this.isDark).accentSolid
          : getTheme(this.isDark).cardBg
      )
      .fontColor(
        this.activeSubTab === index
          ? Color.White
          : getTheme(this.isDark).textPrimary
      )
      .onClick(() => {
        this.switchSubTab(index);
      })
  }

  @Builder
  private renderPaginationFooter(
    currentPage: number,
    hasMore: boolean,
    onPrev: () => void,
    onNext: () => void
  ) {
    Row({ space: 12 }) {
      Button('上一页')
        .fontSize(13)
        .height(34)
        .backgroundColor(
          currentPage > 1 ? getTheme(this.isDark).accentSolid : getTheme(this.isDark).disabledBtnBg
        )
        .fontColor(currentPage > 1 ? Color.White : getTheme(this.isDark).disabledBtnText)
        .enabled(currentPage > 1)
        .onClick(() => {
          onPrev();
        })
      Text(`第 ${currentPage} 页`)
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
          onNext();
        })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding(12)
  }

  @Builder
  private renderThreadsTab() {
    if (this.threadsLoading) {
      Column({ space: 8 }) {
        LoadingProgress()
          .width(32)
          .height(32)
          .color(getTheme(this.isDark).accent)
        Text('正在加载主题...')
          .fontSize(13)
          .fontColor(getTheme(this.isDark).textSecondary)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.threadsError.length > 0) {
      Column() {
        StateView({
          title: '主题加载失败',
          message: this.threadsError,
          actionText: '重试',
          onAction: () => {
            this.loadThreadsPage(this.page);
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.threads.length === 0) {
      Column() {
        StateView({
          title: '暂无主题',
          message: '该用户还没有公开发表的主题。'
        })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List({ space: 10 }) {
        ForEach(this.threads, (thread: ThreadSummary, index: number) => {
          ListItem() {
            ThreadRow({
              title: thread.title,
              authorName: thread.authorName.length > 0 ? thread.authorName : this.displayName(),
              authorId: 0,
              forumName: thread.forumName,
              replyCount: thread.replyCount,
              viewCount: thread.viewCount,
              lastPostTime: formatTime(thread.lastPostTime),
              isDigest: thread.isDigest,
              isTop: thread.isTop,
              onOpen: () => {
                this.openThread(thread.tid, thread.title);
              }
            })
          }
        }, (thread: ThreadSummary, index: number) =>
          `${this.isDark ? 'd' : 'l'}_ut_${this.page}_${thread.tid}_${index}`
        )
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 16, right: 16, bottom: 4 })
      .scrollBar(BarState.Auto)
      .nestedScroll({
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST
      })

      this.renderPaginationFooter(
        this.page,
        this.hasMoreThreads,
        () => {
          if (this.page > 1) {
            this.loadThreadsPage(this.page - 1);
          }
        },
        () => {
          if (this.hasMoreThreads) {
            this.loadThreadsPage(this.page + 1);
          }
        }
      )
    }
  }

  @Builder
  private renderUserPostsTab(isDigest: boolean) {
    if (isDigest ? this.digestsLoading : this.postsLoading) {
      Column({ space: 8 }) {
        LoadingProgress()
          .width(32)
          .height(32)
          .color(getTheme(this.isDark).accent)
        Text(isDigest ? '正在加载精华...' : '正在加载帖子...')
          .fontSize(13)
          .fontColor(getTheme(this.isDark).textSecondary)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if ((isDigest ? this.digestsError : this.postsError).length > 0) {
      Column() {
        StateView({
          title: isDigest ? '精华加载失败' : '帖子加载失败',
          message: isDigest ? this.digestsError : this.postsError,
          actionText: '重试',
          onAction: () => {
            this.loadPostsPage(isDigest ? this.digestsPage : this.postsPage, isDigest);
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if ((isDigest ? this.digests : this.posts).length === 0) {
      Column() {
        StateView({
          title: isDigest ? '暂无精华' : '暂无帖子',
          message: isDigest ? '该用户还没有公开的精华内容。' : '该用户还没有公开发表的帖子与回复。'
        })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List({ space: 10 }) {
        ForEach(isDigest ? this.digests : this.posts, (item: UserPostItem, index: number) => {
          ListItem() {
            UserPostCard({
              item: item,
              authorName: this.displayName(),
              onOpenThread: (target: UserPostItem) => {
                this.openThread(target.tid, target.title, target.pid);
              },
              onOpenImage: (target: UserPostItem, url: string) => {
                this.openUserPostImageViewer(target, url);
              },
              onOpenLink: (url: string) => {
                this.activeLinkUrl = url;
              },
              onOpenAuthor: (uid: number, name: string) => {
                this.openOtherUserProfile(uid, name);
              }
            })
          }
        }, (item: UserPostItem, index: number) =>
          `${this.isDark ? 'd' : 'l'}_${isDigest ? 'dg' : 'ps'}_${isDigest ? this.digestsPage : this.postsPage}_${item.pid}_${item.tid}_${index}`
        )
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 16, right: 16, bottom: 4 })
      .scrollBar(BarState.Auto)
      .nestedScroll({
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST
      })

      this.renderPaginationFooter(
        isDigest ? this.digestsPage : this.postsPage,
        isDigest ? this.hasMoreDigests : this.hasMorePosts,
        () => {
          const current = isDigest ? this.digestsPage : this.postsPage;
          if (current > 1) {
            this.loadPostsPage(current - 1, isDigest);
          }
        },
        () => {
          const hasMore = isDigest ? this.hasMoreDigests : this.hasMorePosts;
          const current = isDigest ? this.digestsPage : this.postsPage;
          if (hasMore) {
            this.loadPostsPage(current + 1, isDigest);
          }
        }
      )
    }
  }

  @Builder
  private renderFavoritesTab() {
    if (this.favLoading) {
      Column({ space: 8 }) {
        LoadingProgress()
          .width(32)
          .height(32)
          .color(getTheme(this.isDark).accent)
        Text('正在加载云端收藏夹...')
          .fontSize(13)
          .fontColor(getTheme(this.isDark).textSecondary)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.favError.length > 0) {
      Column() {
        StateView({
          title: '收藏夹加载失败',
          message: this.favError,
          actionText: '重试',
          onAction: () => {
            this.loadFavoriteGroups();
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.favGroups.length === 0) {
      Column() {
        StateView({
          title: '暂无收藏夹',
          message: this.isSelf() ? '你还没有创建云端收藏夹。' : '该用户没有公开的云端收藏夹。'
        })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List({ space: 10 }) {
        ForEach(this.favGroups, (group: FavoriteGroup) => {
          ListItem() {
            Column({ space: 6 }) {
              Row({ space: 8 }) {
                Text(group.title)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(getTheme(this.isDark).textPrimary)
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(group.isPublic ? '公开' : '私密')
                  .fontSize(11)
                  .fontColor(
                    group.isPublic ? getTheme(this.isDark).accent : getTheme(this.isDark).textSecondary
                  )
                  .backgroundColor(
                    group.isPublic ? getTheme(this.isDark).accentBg : getTheme(this.isDark).surfaceMuted
                  )
                  .borderRadius(4)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              }
              .width('100%')

              if (group.description.length > 0) {
                Text(group.description)
                  .fontSize(13)
                  .fontColor(getTheme(this.isDark).textSecondary)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }

              Text(`共 ${group.count} 条收藏`)
                .fontSize(12)
                .fontColor(getTheme(this.isDark).textMuted)
            }
            .width('100%')
            .padding(14)
            .backgroundColor(getTheme(this.isDark).cardBg)
            .borderRadius(12)
            .alignItems(HorizontalAlign.Start)
            .onClick(() => {
              this.openFavoriteGroup(group);
            })
          }
        }, (group: FavoriteGroup) =>
          `${this.isDark ? 'd' : 'l'}_ufav_${group.id}_${group.count}`
        )
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 16, right: 16, bottom: 16 })
      .scrollBar(BarState.Auto)
      .nestedScroll({
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST
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
            Text(this.displayName())
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(getTheme(this.isDark).textPrimary)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Button('刷新')
              .fontSize(12)
              .height(32)
              .backgroundColor(getTheme(this.isDark).accentBg)
              .fontColor(getTheme(this.isDark).accent)
              .onClick(() => {
                this.loadProfile();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })

          if (this.loading) {
            Column() {
              LoadingProgress()
                .width(40)
                .height(40)
                .color(getTheme(this.isDark).accent)
              Text('正在加载用户资料...')
                .fontSize(13)
                .fontColor(getTheme(this.isDark).textSecondary)
                .margin({ top: 8 })
            }
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else if (this.needLogin) {
            Column() {
              StateView({
                title: '需要登录',
                message: '查看用户资料和主页需要登录，请先登录账号。',
                actionText: '去登录',
                onAction: () => {
                  this.goLogin();
                }
              })
            }
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else if (this.errorMessage.length > 0 || this.profile === null) {
            Column() {
              StateView({
                title: '加载失败',
                message: this.errorMessage.length > 0 ? this.errorMessage : '未获取到用户资料。',
                actionText: '重试',
                onAction: () => {
                  this.loadProfile();
                }
              })
            }
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else {
            Scroll(this.outerScroller) {
              Column({ space: 10 }) {
                Column() {
                  Column({ space: 12 }) {
                    Row({ space: 12 }) {
                      if (this.profile.avatarUrl.length > 0 && !this.avatarFailed) {
                        Image(this.profile.avatarUrl)
                          .width(56)
                          .height(56)
                          .borderRadius(28)
                          .objectFit(ImageFit.Cover)
                          .onError(() => {
                            this.avatarFailed = true;
                          })
                      } else {
                        Text(safeAvatarInitial(this.displayName()))
                          .width(56)
                          .height(56)
                          .borderRadius(28)
                          .backgroundColor(getTheme(this.isDark).accentBg)
                          .fontColor(getTheme(this.isDark).accent)
                          .fontSize(24)
                          .fontWeight(FontWeight.Medium)
                          .textAlign(TextAlign.Center)
                      }

                      Column({ space: 4 }) {
                        Row({ space: 6 }) {
                          Text(this.displayName())
                            .fontSize(17)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(getTheme(this.isDark).textPrimary)
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                          if (this.profile.levelName.length > 0) {
                            Text(this.profile.levelName)
                              .fontSize(10)
                              .fontColor(getTheme(this.isDark).accent)
                              .backgroundColor(getTheme(this.isDark).accentBg)
                              .borderRadius(4)
                              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                          }
                        }

                        Text(`UID ${this.profile.uid}${this.profile.dateline.length > 0 ? ` · 注册于 ${formatTime(this.profile.dateline)}` : ''}`)
                          .fontSize(12)
                          .fontColor(getTheme(this.isDark).textSecondary)

                        if (this.profile.verifyInfo.length > 0) {
                          Text(this.profile.verifyInfo)
                            .fontSize(12)
                            .fontColor(getTheme(this.isDark).accent)
                            .maxLines(2)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                        }
                      }
                      .layoutWeight(1)
                      .alignItems(HorizontalAlign.Start)
                    }
                    .width('100%')

                    Divider().color(getTheme(this.isDark).divider).strokeWidth(1)

                    Row() {
                      this.renderStatCell('主题', `${this.profile.threads}`, 0)
                      this.renderStatCell('回复', `${this.profile.posts}`, 1)
                      this.renderStatCell('精华', `${this.profile.digests}`, 2)
                    }
                    .width('100%')

                    Row() {
                      this.renderStatCell('关注', `${this.profile.followings}`)
                      this.renderStatCell('粉丝', `${this.profile.followers}`)
                      this.renderStatCell('龙币 / 龙晶', `${this.profile.money} / ${this.profile.gems}`)
                    }
                    .width('100%')

                    if (this.isSelf()) {
                      Row({ space: 10 }) {
                        Button('管理云端收藏夹')
                          .fontSize(12)
                          .height(32)
                          .layoutWeight(1)
                          .backgroundColor(getTheme(this.isDark).accentBg)
                          .fontColor(getTheme(this.isDark).accent)
                          .onClick(() => {
                            this.openMyFavoritesManager();
                          })
                        Button('显示与设置')
                          .fontSize(12)
                          .height(32)
                          .layoutWeight(1)
                          .backgroundColor(getTheme(this.isDark).surfaceMuted)
                          .fontColor(getTheme(this.isDark).textPrimary)
                          .onClick(() => {
                            this.openSettings();
                          })
                      }
                      .width('100%')
                    } else {
                      Row({ space: 10 }) {
                        Button(
                          this.followSubmitting
                            ? '处理中...'
                            : (this.profile.isFollow ? '已关注' : '+ 关注')
                        )
                          .fontSize(12)
                          .height(32)
                          .layoutWeight(1)
                          .backgroundColor(
                            this.profile.isFollow
                              ? getTheme(this.isDark).surfaceMuted
                              : getTheme(this.isDark).accentSolid
                          )
                          .fontColor(
                            this.profile.isFollow
                              ? getTheme(this.isDark).textPrimary
                              : Color.White
                          )
                          .enabled(!this.followSubmitting)
                          .onClick(() => {
                            this.toggleFollow();
                          })
                        Button('发私信')
                          .fontSize(12)
                          .height(32)
                          .layoutWeight(1)
                          .backgroundColor(getTheme(this.isDark).accentBg)
                          .fontColor(getTheme(this.isDark).accent)
                          .onClick(() => {
                            this.openMessageChat();
                          })
                      }
                      .width('100%')
                    }
                  }
                  .width('100%')
                  .padding(14)
                  .backgroundColor(getTheme(this.isDark).cardBg)
                  .borderRadius(12)
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
                .padding({ left: 16, right: 16 })

                Column({ space: 10 }) {
                  Row({ space: 6 }) {
                    this.renderSubTabBtn(0, `主题 ${this.profile.threads}`)
                    this.renderSubTabBtn(1, `帖子 ${this.profile.posts}`)
                    this.renderSubTabBtn(2, `精华 ${this.profile.digests}`)
                    this.renderSubTabBtn(3, '收藏夹')
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16 })

                  Tabs({ barPosition: BarPosition.Start, index: 0, controller: this.tabsController }) {
                    TabContent() {
                      Column() {
                        this.renderThreadsTab()
                      }
                      .width('100%')
                      .height('100%')
                    }

                    TabContent() {
                      Column() {
                        this.renderUserPostsTab(false)
                      }
                      .width('100%')
                      .height('100%')
                    }

                    TabContent() {
                      Column() {
                        this.renderUserPostsTab(true)
                      }
                      .width('100%')
                      .height('100%')
                    }

                    TabContent() {
                      Column() {
                        this.renderFavoritesTab()
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
                    this.applySubTabChange(targetIndex);
                  })
                  .onChange((index: number) => {
                    this.applySubTabChange(index);
                  })
                }
                .width('100%')
                .height('100%')
              }
              .width('100%')
            }
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.None)
          }
        }
        .width('100%')
        .height('100%')
        .backgroundColor(getTheme(this.isDark).pageBg)

        if (this.activeLinkUrl.length > 0) {
          Column() {
            Column({ space: 12 }) {
              Text(
                parseLkongUrl(this.activeLinkUrl).kind !== LkongLinkKind.NONE
                  ? '龙空站内链接'
                  : '帖子链接'
              )
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(getTheme(this.isDark).textPrimary)
              Text(this.activeLinkUrl)
                .fontSize(13)
                .fontColor(getTheme(this.isDark).textSecondary)
                .lineHeight(20)
                .width('100%')
              Row({ space: 8 }) {
                Button('关闭')
                  .fontSize(13)
                  .height(36)
                  .layoutWeight(1)
                  .backgroundColor(getTheme(this.isDark).surfaceMuted)
                  .fontColor(getTheme(this.isDark).textSecondary)
                  .onClick(() => {
                    this.activeLinkUrl = '';
                  })
                Button('复制链接')
                  .fontSize(13)
                  .height(36)
                  .layoutWeight(1)
                  .backgroundColor(
                    parseLkongUrl(this.activeLinkUrl).kind !== LkongLinkKind.NONE
                      ? getTheme(this.isDark).accentBg
                      : getTheme(this.isDark).accentSolid
                  )
                  .fontColor(
                    parseLkongUrl(this.activeLinkUrl).kind !== LkongLinkKind.NONE
                      ? getTheme(this.isDark).accent
                      : Color.White
                  )
                  .onClick(() => {
                    this.copyActiveLink();
                  })
                if (parseLkongUrl(this.activeLinkUrl).kind !== LkongLinkKind.NONE) {
                  Button('应用内打开')
                    .fontSize(13)
                    .height(36)
                    .layoutWeight(1)
                    .backgroundColor(getTheme(this.isDark).accentSolid)
                    .fontColor(Color.White)
                    .onClick(() => {
                      this.openActiveLkongLink();
                    })
                }
              }
              .width('100%')
            }
            .width('86%')
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
            this.activeLinkUrl = '';
          })
        }

        if (this.showImageViewer) {
          ImageViewerOverlay({
            images: this.previewImages,
            initialIndex: this.previewIndex,
            onClose: () => {
              this.showImageViewer = false;
            }
          })
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      if (this.readyHandled) {
        return;
      }
      this.readyHandled = true;
      const params = ctx.pathInfo.param as UserProfileRouteParams | undefined | null;
      if (params !== undefined && params !== null) {
        this.targetUid = params.uid === undefined ? 0 : params.uid;
        this.fallbackName = params.name === undefined ? '' : params.name;
      }
      this.bootstrap();
    })
    .onShown(() => {
      if (!this.bootstrapped) {
        return;
      }
      if (this.needLogin && CookieStore.getInstance().hasCookie()) {
        this.loadProfile();
      }
    })
    .onBackPressed(() => {
      if (this.showImageViewer) {
        this.showImageViewer = false;
        return true;
      }
      if (this.activeLinkUrl.length > 0) {
        this.activeLinkUrl = '';
        return true;
      }
      return false;
    })
  }
}
