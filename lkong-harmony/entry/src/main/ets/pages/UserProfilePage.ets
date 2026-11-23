import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ApiError, ErrorKind, FavoriteGroup, ThreadSummary, UserProfile } from '../model/Models';
import { LkongApi } from '../network/LkongApi';
import { CookieStore } from '../store/CookieStore';
import { DisplayPrefs } from '../store/DisplayPrefs';
import { StateView } from '../components/StateView';
import { ThreadRow } from '../components/ThreadRow';
import { safeAvatarInitial } from '../utils/AvatarUtils';
import { formatTime } from '../utils/TimeUtils';
import { getTheme, KEY_IS_DARK } from '../utils/Theme';

const THREADS_PER_PAGE: number = 20;

interface UserProfileParams {
  uid?: number;
  name?: string;
}

/**
 * 个人资料页：支持查看本人与任意坛友的资料统计、Ta 的主题列表（分页）与云端收藏夹分组。
 */
@Entry
@Component
struct UserProfilePage {
  @State targetUid: number = 0;
  @State resolvedUid: number = 0;
  @State fallbackName: string = '';
  @State profile: UserProfile | null = null;
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State needLogin: boolean = false;
  @State avatarFailed: boolean = false;

  @State activeSubTab: number = 0;
  @State threads: ThreadSummary[] = [];
  @State page: number = 1;
  @State hasMoreThreads: boolean = false;
  @State threadsLoading: boolean = false;
  @State threadsError: string = '';

  @State favGroups: FavoriteGroup[] = [];
  @State favLoaded: boolean = false;
  @State favLoading: boolean = false;
  @State favError: string = '';

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;

  aboutToAppear(): void {
    const raw = router.getParams();
    if (raw !== undefined && raw !== null) {
      const params = raw as UserProfileParams;
      this.targetUid = params.uid === undefined ? 0 : params.uid;
      this.fallbackName = params.name === undefined ? '' : params.name;
    }
    this.bootstrap();
  }

  onPageShow(): void {
    if (this.needLogin && CookieStore.getInstance().hasCookie()) {
      this.loadProfile();
    }
  }

  private async bootstrap(): Promise<void> {
    const ctx = getContext(this) as common.Context;
    await CookieStore.getInstance().ensureInit(ctx);
    await DisplayPrefs.getInstance().ensureInit(ctx);
    await this.loadProfile();
  }

  private async loadProfile(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    this.needLogin = false;
    this.threadsError = '';
    this.avatarFailed = false;
    this.favLoaded = false;
    this.favGroups = [];
    this.favError = '';

    try {
      const data = await LkongApi.getInstance().getUserProfilePage(this.targetUid, 1);
      this.profile = data.profile;
      this.resolvedUid = data.profile.uid;
      this.threads = data.threads;
      this.page = 1;
      this.hasMoreThreads = this.computeHasMoreThreads(data.threads.length, 1, data.profile.threads);
      if (this.activeSubTab === 1) {
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

  private computeHasMoreThreads(loadedCount: number, currentPage: number, totalCount: number): boolean {
    if (loadedCount === 0) {
      return false;
    }
    if (totalCount > 0) {
      return currentPage * THREADS_PER_PAGE < totalCount || loadedCount >= THREADS_PER_PAGE;
    }
    return loadedCount >= THREADS_PER_PAGE;
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
      this.hasMoreThreads = this.computeHasMoreThreads(list.length, targetPage, totalCount);
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

  private switchSubTab(index: number): void {
    if (this.activeSubTab === index) {
      return;
    }
    this.activeSubTab = index;
    if (index === 1 && !this.favLoaded && !this.favLoading && this.resolvedUid > 0) {
      this.loadFavoriteGroups();
    }
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

  private openFavoriteGroup(group: FavoriteGroup): void {
    router.pushUrl({
      url: 'pages/FavoriteDetailPage',
      params: {
        groupId: group.id,
        title: group.title,
        isMine: this.isSelf()
      }
    }).catch(() => {
    });
  }

  private openMyFavoritesManager(): void {
    router.pushUrl({ url: 'pages/FavoritesPage' }).catch(() => {
    });
  }

  private openSettings(): void {
    router.pushUrl({ url: 'pages/SettingsPage' }).catch(() => {
    });
  }

  @Builder
  private renderStatCell(label: string, value: string) {
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
        Column() {
          List({ space: 10 }) {
            ListItem() {
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
                  this.renderStatCell('主题', `${this.profile.threads}`)
                  this.renderStatCell('回复', `${this.profile.posts}`)
                  this.renderStatCell('精华', `${this.profile.digests}`)
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
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor(getTheme(this.isDark).cardBg)
              .borderRadius(12)
              .alignItems(HorizontalAlign.Start)
            }

            ListItem() {
              Row({ space: 8 }) {
                Button(`主题 (${this.profile.threads})`)
                  .fontSize(13)
                  .height(34)
                  .layoutWeight(1)
                  .backgroundColor(
                    this.activeSubTab === 0
                      ? getTheme(this.isDark).accentSolid
                      : getTheme(this.isDark).cardBg
                  )
                  .fontColor(
                    this.activeSubTab === 0
                      ? Color.White
                      : getTheme(this.isDark).textPrimary
                  )
                  .onClick(() => {
                    this.switchSubTab(0);
                  })

                Button('云端收藏夹')
                  .fontSize(13)
                  .height(34)
                  .layoutWeight(1)
                  .backgroundColor(
                    this.activeSubTab === 1
                      ? getTheme(this.isDark).accentSolid
                      : getTheme(this.isDark).cardBg
                  )
                  .fontColor(
                    this.activeSubTab === 1
                      ? Color.White
                      : getTheme(this.isDark).textPrimary
                  )
                  .onClick(() => {
                    this.switchSubTab(1);
                  })
              }
              .width('100%')
            }

            if (this.activeSubTab === 0) {
              if (this.threadsLoading) {
                ListItem() {
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
                  .padding(24)
                  .justifyContent(FlexAlign.Center)
                }
              } else if (this.threadsError.length > 0) {
                ListItem() {
                  StateView({
                    title: '主题加载失败',
                    message: this.threadsError,
                    actionText: '重试',
                    onAction: () => {
                      this.loadThreadsPage(this.page);
                    }
                  })
                }
              } else if (this.threads.length === 0) {
                ListItem() {
                  StateView({
                    title: '暂无主题',
                    message: '该用户还没有公开发表的主题。'
                  })
                }
              } else {
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
                        this.openThread(thread);
                      }
                    })
                  }
                }, (thread: ThreadSummary, index: number) =>
                  `${this.isDark ? 'd' : 'l'}_ut_${this.page}_${thread.tid}_${index}`
                )
              }
            } else {
              if (this.favLoading) {
                ListItem() {
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
                  .padding(24)
                  .justifyContent(FlexAlign.Center)
                }
              } else if (this.favError.length > 0) {
                ListItem() {
                  StateView({
                    title: '收藏夹加载失败',
                    message: this.favError,
                    actionText: '重试',
                    onAction: () => {
                      this.loadFavoriteGroups();
                    }
                  })
                }
              } else if (this.favGroups.length === 0) {
                ListItem() {
                  StateView({
                    title: '暂无收藏夹',
                    message: this.isSelf() ? '你还没有创建云端收藏夹。' : '该用户没有公开的云端收藏夹。'
                  })
                }
              } else {
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
            }
          }
          .layoutWeight(1)
          .padding({ left: 16, right: 16, bottom: this.activeSubTab === 0 ? 4 : 16 })
          .scrollBar(BarState.Auto)

          if (this.activeSubTab === 0 && !this.threadsLoading && this.threadsError.length === 0) {
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
                  if (this.page > 1) {
                    this.loadThreadsPage(this.page - 1);
                  }
                })
              Text(`第 ${this.page} 页`)
                .fontSize(13)
                .fontColor(getTheme(this.isDark).textSecondary)
              Button('下一页')
                .fontSize(13)
                .height(34)
                .backgroundColor(
                  this.hasMoreThreads ? getTheme(this.isDark).accentSolid : getTheme(this.isDark).disabledBtnBg
                )
                .fontColor(this.hasMoreThreads ? Color.White : getTheme(this.isDark).disabledBtnText)
                .enabled(this.hasMoreThreads)
                .onClick(() => {
                  if (this.hasMoreThreads) {
                    this.loadThreadsPage(this.page + 1);
                  }
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding(12)
          }
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(getTheme(this.isDark).pageBg)
  }
}
