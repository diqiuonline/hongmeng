import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ApiError, ErrorKind, ThreadSummary } from '../model/Models';
import { LkongApi } from '../network/LkongApi';
import { CookieStore } from '../store/CookieStore';
import { DisplayPrefs } from '../store/DisplayPrefs';
import { StateView } from '../components/StateView';
import { ThreadRow } from '../components/ThreadRow';
import { formatTime } from '../utils/TimeUtils';
import { getTheme, KEY_IS_DARK } from '../utils/Theme';

interface ForumParams {
  fid: number;
  name: string;
}

/**
 * 版块页：登录后展示帖子列表。
 * 如果站点返回未登录错误，页面展示“去登录”，而不是把错误当成普通网络失败。
 */
@Entry
@Component
struct ForumPage {
  @State fid: number = 0;
  @State forumName: string = '';
  @State page: number = 1;
  @State threads: ThreadSummary[] = [];
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State needLogin: boolean = false;
  @State hasMore: boolean = true;
  @StorageProp(KEY_IS_DARK) isDark: boolean = false;

  aboutToAppear(): void {
    const raw = router.getParams();
    if (raw !== undefined && raw !== null) {
      const params = raw as ForumParams;
      this.fid = params.fid === undefined ? 0 : params.fid;
      this.forumName = params.name === undefined ? '' : params.name;
    }
    this.bootstrap();
  }

  onPageShow(): void {
    if (this.needLogin && CookieStore.getInstance().hasCookie()) {
      this.loadPage();
    }
  }

  private async bootstrap(): Promise<void> {
    const ctx = getContext(this) as common.Context;
    await CookieStore.getInstance().ensureInit(ctx);
    await DisplayPrefs.getInstance().ensureInit(ctx);
    await this.loadPage();
  }

  private async loadPage(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    this.needLogin = false;
    try {
      const data = await LkongApi.getInstance().getForumThreads(this.fid, this.page);
      this.threads = data.threads;
      if (data.forumName.length > 0) {
        this.forumName = data.forumName;
      }
      this.hasMore = data.threads.length > 0;
    } catch (error) {
      if (error instanceof ApiError && error.kind === ErrorKind.AUTH) {
        this.needLogin = true;
        this.errorMessage = error.message;
      } else if (error instanceof ApiError) {
        this.errorMessage = error.message;
      } else {
        this.errorMessage = '版块加载失败，请稍后重试。';
      }
    } finally {
      this.loading = false;
    }
  }

  private goLogin(): void {
    router.pushUrl({ url: 'pages/LoginPage' }).catch(() => {
    });
  }

  private openThread(thread: ThreadSummary): void {
    router.pushUrl({
      url: 'pages/ThreadPage',
      params: {
        tid: thread.tid,
        title: thread.title
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

  private previousPage(): void {
    if (this.page > 1) {
      this.page = this.page - 1;
      this.loadPage();
    }
  }

  private nextPage(): void {
    if (this.hasMore) {
      this.page = this.page + 1;
      this.loadPage();
    }
  }

  build() {
    Column() {
      Row() {
        Button('返回')
          .fontSize(12)
          .height(32)
          .backgroundColor(getTheme(this.isDark).accentBg)
          .fontColor(getTheme(this.isDark).accent)
          .margin({ right: 8 })
          .onClick(() => {
            router.back();
          })
        Text(this.forumName.length > 0 ? this.forumName : '版块')
          .fontSize(18)
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
            this.loadPage();
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
          Text('正在加载帖子...')
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
            message: '龙空版块需要登录后才能浏览，请先登录账号。',
            actionText: '去登录',
            onAction: () => {
              this.goLogin();
            }
          })
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
              this.loadPage();
            }
          })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.threads.length === 0) {
        Column() {
          StateView({
            title: '暂无帖子',
            message: '这个版块当前没有可显示的帖子。'
          })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.threads, (thread: ThreadSummary, index: number) => {
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
                  this.openThread(thread);
                },
                onAuthorClick: (uid: number, name: string) => {
                  this.openUserProfile(uid, name);
                }
              })
            }
          }, (thread: ThreadSummary, index: number) => `${this.page}_${thread.tid}_${index}`)
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
        .scrollBar(BarState.Auto)

        Row({ space: 12 }) {
          Button('上一页')
            .fontSize(13)
            .height(34)
            .backgroundColor(
              this.page > 1 ? getTheme(this.isDark).accentSolid : getTheme(this.isDark).disabledBtnBg
            )
            .fontColor(this.page > 1 ? Color.White : getTheme(this.isDark).disabledBtnText)
            .enabled(this.page > 1)
            .onClick(() => {
              this.previousPage();
            })
          Text(`第 ${this.page} 页`)
            .fontSize(13)
            .fontColor(getTheme(this.isDark).textSecondary)
          Button('下一页')
            .fontSize(13)
            .height(34)
            .backgroundColor(
              this.hasMore ? getTheme(this.isDark).accentSolid : getTheme(this.isDark).disabledBtnBg
            )
            .fontColor(this.hasMore ? Color.White : getTheme(this.isDark).disabledBtnText)
            .enabled(this.hasMore)
            .onClick(() => {
              this.nextPage();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding(12)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(getTheme(this.isDark).pageBg)
  }
}
