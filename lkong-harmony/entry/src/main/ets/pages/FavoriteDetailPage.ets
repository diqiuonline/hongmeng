import { ApiError, ErrorKind, FavoriteEntry, FavoriteGroup } from '../model/Models';
import { LkongApi } from '../network/LkongApi';
import { CookieStore } from '../store/CookieStore';
import { DisplayPrefs } from '../store/DisplayPrefs';
import { StateView } from '../components/StateView';
import {
  AppNavigator,
  FavoriteDetailRouteParams,
  Routes,
  ThreadRouteParams,
  UserProfileRouteParams
} from '../utils/AppRouter';
import { renderPostSummary } from '../utils/ContentUtils';
import { formatTime } from '../utils/TimeUtils';
import { getTheme, KEY_IS_DARK } from '../utils/Theme';
import { getHostContext, showToast } from '../utils/UiUtils';

const ITEMS_PER_PAGE: number = 20;

/**
 * 云端收藏夹分组明细页：分页浏览收藏条目，支持直达帖子/作者以及在本人收藏夹内取消收藏。
 */
@Component
export struct FavoriteDetailPage {
  @State groupId: number = 0;
  @State fallbackTitle: string = '';
  @State isMineParam: boolean = false;
  @State group: FavoriteGroup | null = null;
  @State items: FavoriteEntry[] = [];
  @State page: number = 1;
  @State totalPages: number = 1;
  @State hasMore: boolean = false;
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State needLogin: boolean = false;
  @State removingPid: string = '';

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;
  private readyHandled: boolean = false;
  private bootstrapped: boolean = false;

  private async bootstrap(): Promise<void> {
    const ctx = getHostContext(this.getUIContext());
    await CookieStore.getInstance().ensureInit(ctx);
    await DisplayPrefs.getInstance().ensureInit(ctx);
    this.bootstrapped = true;
    await this.loadDetail();
  }

  private async loadDetail(): Promise<void> {
    if (this.groupId <= 0) {
      this.loading = false;
      this.errorMessage = '无效的收藏夹分组 ID。';
      return;
    }
    this.loading = true;
    this.errorMessage = '';
    this.needLogin = false;
    try {
      const data = await LkongApi.getInstance().getFavoriteGroupDetail(this.groupId, this.page);
      this.group = data.group;
      this.items = data.items;
      if (data.group.count > 0) {
        const pages = Math.max(1, Math.ceil(data.group.count / ITEMS_PER_PAGE));
        this.totalPages = Math.max(pages, this.page);
        this.hasMore = this.page < pages && data.items.length > 0;
      } else {
        this.totalPages = this.page;
        this.hasMore = data.items.length >= ITEMS_PER_PAGE;
      }
    } catch (error) {
      if (error instanceof ApiError && error.kind === ErrorKind.AUTH) {
        this.needLogin = true;
        this.errorMessage = error.message;
      } else if (error instanceof ApiError) {
        this.errorMessage = error.message;
      } else {
        this.errorMessage = '加载收藏夹内容失败，请稍后重试。';
      }
    } finally {
      this.loading = false;
    }
  }

  private displayTitle(): string {
    if (this.group !== null && this.group.title.length > 0) {
      return this.group.title;
    }
    if (this.fallbackTitle.length > 0) {
      return this.fallbackTitle;
    }
    return '收藏夹';
  }

  private isOwnGroup(): boolean {
    if (this.isMineParam) {
      return true;
    }
    const me = LkongApi.getInstance().getCachedCurrentUser();
    if (me !== null && me.uid > 0 && this.group !== null && this.group.uid === me.uid) {
      return true;
    }
    return false;
  }

  private async removeFavorite(item: FavoriteEntry): Promise<void> {
    if (this.removingPid.length > 0 || item.pid.length === 0 || item.tid <= 0) {
      return;
    }
    this.removingPid = item.pid;
    try {
      const ok = await LkongApi.getInstance().favoritePost(this.groupId, item.tid, item.pid, true);
      if (ok) {
        const remaining: FavoriteEntry[] = [];
        for (const entry of this.items) {
          if (entry.pid !== item.pid) {
            remaining.push(entry);
          }
        }
        this.items = remaining;
        if (this.group !== null && this.group.count > 0) {
          this.group = {
            id: this.group.id,
            title: this.group.title,
            count: this.group.count - 1,
            uid: this.group.uid,
            isPublic: this.group.isPublic,
            description: this.group.description,
            dateline: this.group.dateline
          };
        }
        showToast(this.getUIContext(), '已取消收藏');
      } else {
        showToast(this.getUIContext(), '取消收藏未生效，请重试');
      }
    } catch (error) {
      const message = error instanceof ApiError ? error.message : '取消收藏失败，请稍后重试。';
      showToast(this.getUIContext(), message);
    } finally {
      this.removingPid = '';
    }
  }

  private goLogin(): void {
    AppNavigator.getInstance().push(Routes.LOGIN);
  }

  private openThread(item: FavoriteEntry): void {
    if (item.tid <= 0) {
      showToast(this.getUIContext(), '该条收藏暂无可跳转的主题');
      return;
    }
    const params: ThreadRouteParams = {
      tid: item.tid,
      title: item.title,
      pid: item.pid
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

  private previousPage(): void {
    if (this.page > 1) {
      this.page = this.page - 1;
      this.loadDetail();
    }
  }

  private nextPage(): void {
    if (this.hasMore) {
      this.page = this.page + 1;
      this.loadDetail();
    }
  }

  build() {
    NavDestination() {
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
        Text(this.displayTitle())
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
            this.loadDetail();
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
          Text('正在加载收藏内容...')
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
            message: '查看云端收藏夹详情需要登录，请先登录账号。',
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
              this.loadDetail();
            }
          })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          if (this.group !== null) {
            ListItem() {
              Column({ space: 6 }) {
                Row({ space: 8 }) {
                  Text(this.displayTitle())
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(getTheme(this.isDark).textPrimary)
                    .layoutWeight(1)
                  Text(this.group.isPublic ? '公开' : '私密')
                    .fontSize(11)
                    .fontColor(
                      this.group.isPublic ? getTheme(this.isDark).accent : getTheme(this.isDark).textSecondary
                    )
                    .backgroundColor(
                      this.group.isPublic ? getTheme(this.isDark).accentBg : getTheme(this.isDark).surfaceMuted
                    )
                    .borderRadius(4)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                }
                .width('100%')

                if (this.group.description.length > 0) {
                  Text(this.group.description)
                    .fontSize(13)
                    .fontColor(getTheme(this.isDark).textSecondary)
                }

                Text(`共 ${this.group.count} 条收藏`)
                  .fontSize(12)
                  .fontColor(getTheme(this.isDark).textMuted)
              }
              .width('100%')
              .padding(14)
              .backgroundColor(getTheme(this.isDark).cardBg)
              .borderRadius(12)
              .alignItems(HorizontalAlign.Start)
            }
          }

          if (this.items.length === 0) {
            ListItem() {
              StateView({
                title: '暂无收藏内容',
                message: '这个云端收藏夹当前页没有内容。'
              })
            }
          }

          ForEach(this.items, (item: FavoriteEntry, index: number) => {
            ListItem() {
              Column({ space: 6 }) {
                Text(item.title)
                  .width('100%')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(getTheme(this.isDark).textPrimary)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                if (item.contentHtml.length > 0) {
                  Text(renderPostSummary(item.contentHtml, 120))
                    .width('100%')
                    .fontSize(13)
                    .lineHeight(19)
                    .fontColor(getTheme(this.isDark).textSecondary)
                    .maxLines(3)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }

                Row({ space: 8 }) {
                  Text(item.authorName.length > 0 ? item.authorName : '匿名用户')
                    .fontSize(12)
                    .fontColor(
                      item.authorId > 0 ? getTheme(this.isDark).accent : getTheme(this.isDark).textSecondary
                    )
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .constraintSize({ maxWidth: 110 })
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

                  Text(formatTime(item.dateline))
                    .fontSize(12)
                    .fontColor(getTheme(this.isDark).textMuted)

                  Blank()

                  if (this.isOwnGroup() && item.pid.length > 0 && item.tid > 0) {
                    Button(this.removingPid === item.pid ? '移出中' : '取消收藏')
                      .fontSize(11)
                      .height(26)
                      .backgroundColor(getTheme(this.isDark).dangerBg)
                      .fontColor(getTheme(this.isDark).dangerText)
                      .enabled(this.removingPid.length === 0)
                      .onClick(() => {
                        this.removeFavorite(item);
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
                this.openThread(item);
              })
            }
          }, (item: FavoriteEntry, index: number) =>
            `${this.isDark ? 'd' : 'l'}_${this.page}_${item.pid}_${index}_${this.removingPid}`
          )
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
          Text(`第 ${this.page} / ${this.totalPages} 页`)
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
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      if (this.readyHandled) {
        return;
      }
      this.readyHandled = true;
      const params = ctx.pathInfo.param as FavoriteDetailRouteParams | undefined | null;
      if (params !== undefined && params !== null) {
        this.groupId = params.groupId === undefined ? 0 : params.groupId;
        this.fallbackTitle = params.title === undefined ? '' : params.title;
        this.isMineParam = params.isMine === undefined ? false : params.isMine;
      }
      this.bootstrap();
    })
    .onShown(() => {
      if (!this.bootstrapped) {
        return;
      }
      if (this.needLogin && CookieStore.getInstance().hasCookie()) {
        this.loadDetail();
      }
    })
  }
}
