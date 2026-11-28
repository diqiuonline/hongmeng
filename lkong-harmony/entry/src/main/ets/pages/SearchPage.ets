import { LengthMetrics } from '@kit.ArkUI';
import {
  ApiError,
  ErrorKind,
  HighlightSegment,
  SearchForumItem,
  SearchThreadItem,
  SearchUserItem
} from '../model/Models';
import { LkongApi } from '../network/LkongApi';
import { CookieStore } from '../store/CookieStore';
import { DisplayPrefs } from '../store/DisplayPrefs';
import { ForumOrderPrefs } from '../store/ForumOrderPrefs';
import { StateView } from '../components/StateView';
import {
  AppNavigator,
  ForumRouteParams,
  Routes,
  ThreadRouteParams,
  UserProfileRouteParams
} from '../utils/AppRouter';
import { safeAvatarInitial, splitHighlightText } from '../utils/AvatarUtils';
import { formatTime } from '../utils/TimeUtils';
import { getTheme, KEY_IS_DARK } from '../utils/Theme';
import { getHostContext, showToast } from '../utils/UiUtils';

class SearchTabType {
  static readonly THREAD: string = 'thread';
  static readonly FORUM: string = 'forum';
  static readonly USER: string = 'user';
}

interface SortOption {
  value: string;
  label: string;
}

const SORT_OPTIONS: SortOption[] = [
  { value: '', label: '相关度' },
  { value: 'hot', label: '热度' },
  { value: 'time', label: '最新' }
];

@Component
struct SearchAvatar {
  @Prop avatarUrl: string = '';
  @Prop labelName: string = '';
  @Prop isCircle: boolean = false;
  @StorageProp(KEY_IS_DARK) isDark: boolean = false;
  @State failed: boolean = false;

  build() {
    if (this.avatarUrl.length > 0 && !this.failed) {
      Image(this.avatarUrl)
        .width(42)
        .height(42)
        .borderRadius(this.isCircle ? 21 : 10)
        .objectFit(ImageFit.Cover)
        .onError(() => {
          this.failed = true;
        })
    } else {
      Text(safeAvatarInitial(this.labelName))
        .width(42)
        .height(42)
        .borderRadius(this.isCircle ? 21 : 10)
        .backgroundColor(getTheme(this.isDark).accentBg)
        .fontColor(getTheme(this.isDark).accent)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
    }
  }
}

/**
 * 综合搜索页：支持搜索帖子（含排序与游标加载更多）、版块与用户，并保留最近搜索历史。
 */
@Component
export struct SearchPage {
  @State keyword: string = '';
  @State submittedKeyword: string = '';
  @State searchType: string = SearchTabType.THREAD;
  @State sort: string = '';
  @State loading: boolean = false;
  @State loadingMore: boolean = false;
  @State errorMessage: string = '';
  @State needLogin: boolean = false;
  @State hasSearched: boolean = false;
  @State threadResults: SearchThreadItem[] = [];
  @State searchAfter: string = '';
  @State hasMore: boolean = false;
  @State forumResults: SearchForumItem[] = [];
  @State userResults: SearchUserItem[] = [];
  @State history: string[] = [];

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;
  private bootstrapped: boolean = false;

  aboutToAppear(): void {
    this.bootstrap();
  }

  private async bootstrap(): Promise<void> {
    const ctx = getHostContext(this.getUIContext());
    await CookieStore.getInstance().ensureInit(ctx);
    await DisplayPrefs.getInstance().ensureInit(ctx);
    await ForumOrderPrefs.getInstance().ensureInit(ctx);
    this.history = ForumOrderPrefs.getInstance().getSearchHistory();
    this.bootstrapped = true;
  }

  private switchSearchType(nextType: string): void {
    if (this.searchType === nextType) {
      return;
    }
    this.searchType = nextType;
    if (this.submittedKeyword.length > 0) {
      this.executeSearch(this.submittedKeyword);
    }
  }

  private switchSort(nextSort: string): void {
    if (this.sort === nextSort) {
      return;
    }
    this.sort = nextSort;
    if (this.searchType === SearchTabType.THREAD && this.submittedKeyword.length > 0) {
      this.executeSearch(this.submittedKeyword);
    }
  }

  private submitKeyword(): void {
    const trimmed = this.keyword.trim();
    if (trimmed.length === 0) {
      showToast(this.getUIContext(), '请输入搜索关键词');
      return;
    }
    this.executeSearch(trimmed);
  }

  private async executeSearch(rawKeyword: string): Promise<void> {
    const text = rawKeyword.trim();
    if (text.length === 0) {
      return;
    }
    this.keyword = text;
    this.submittedKeyword = text;
    this.hasSearched = true;
    this.loading = true;
    this.loadingMore = false;
    this.errorMessage = '';
    this.needLogin = false;

    await ForumOrderPrefs.getInstance().addSearchHistory(text);
    this.history = ForumOrderPrefs.getInstance().getSearchHistory();

    try {
      if (this.searchType === SearchTabType.THREAD) {
        const res = await LkongApi.getInstance().searchThreads(text, this.sort, '');
        this.threadResults = res.threads;
        this.searchAfter = res.searchAfter;
        this.hasMore = res.hasMore && res.searchAfter.length > 0;
      } else if (this.searchType === SearchTabType.FORUM) {
        this.forumResults = await LkongApi.getInstance().searchForums(text);
      } else {
        this.userResults = await LkongApi.getInstance().searchUsers(text);
      }
    } catch (error) {
      if (error instanceof ApiError && error.kind === ErrorKind.AUTH) {
        this.needLogin = true;
        this.errorMessage = error.message;
      } else if (error instanceof ApiError) {
        this.errorMessage = error.message;
      } else {
        this.errorMessage = '搜索失败，请稍后重试。';
      }
    } finally {
      this.loading = false;
    }
  }

  private async loadMoreThreads(): Promise<void> {
    if (this.loading || this.loadingMore || !this.hasMore || this.searchAfter.length === 0) {
      return;
    }
    this.loadingMore = true;
    try {
      const res = await LkongApi.getInstance().searchThreads(
        this.submittedKeyword,
        this.sort,
        this.searchAfter
      );
      const seen = new Set<number>();
      const merged: SearchThreadItem[] = [];
      for (const item of this.threadResults) {
        merged.push(item);
        seen.add(item.tid);
      }
      for (const item of res.threads) {
        if (!seen.has(item.tid)) {
          merged.push(item);
          seen.add(item.tid);
        }
      }
      this.threadResults = merged;
      this.searchAfter = res.searchAfter;
      this.hasMore = res.hasMore && res.searchAfter.length > 0;
    } catch (error) {
      const message = error instanceof ApiError ? error.message : '加载更多失败，请稍后重试。';
      showToast(this.getUIContext(), message);
    } finally {
      this.loadingMore = false;
    }
  }

  private async clearHistory(): Promise<void> {
    await ForumOrderPrefs.getInstance().clearSearchHistory();
    this.history = [];
  }

  private goLogin(): void {
    AppNavigator.getInstance().push(Routes.LOGIN);
  }

  private openThread(tid: number, title: string): void {
    const params: ThreadRouteParams = {
      tid: tid,
      title: title
    };
    AppNavigator.getInstance().push(Routes.THREAD, params);
  }

  private openForum(fid: number, name: string): void {
    const params: ForumRouteParams = {
      fid: fid,
      name: name
    };
    AppNavigator.getInstance().push(Routes.FORUM, params);
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

  private isResultEmpty(): boolean {
    if (this.searchType === SearchTabType.THREAD) {
      return this.threadResults.length === 0;
    }
    if (this.searchType === SearchTabType.FORUM) {
      return this.forumResults.length === 0;
    }
    return this.userResults.length === 0;
  }

  @Builder
  private renderTypeButton(typeKey: string, label: string) {
    Button(label)
      .fontSize(13)
      .height(32)
      .layoutWeight(1)
      .backgroundColor(
        this.searchType === typeKey
          ? getTheme(this.isDark).accentSolid
          : getTheme(this.isDark).surfaceMuted
      )
      .fontColor(
        this.searchType === typeKey
          ? Color.White
          : getTheme(this.isDark).textPrimary
      )
      .onClick(() => {
        this.switchSearchType(typeKey);
      })
  }

  build() {
    NavDestination() {
      Column() {
        Row({ space: 8 }) {
          Button('返回')
            .fontSize(12)
            .height(34)
            .backgroundColor(getTheme(this.isDark).accentBg)
            .fontColor(getTheme(this.isDark).accent)
            .onClick(() => {
              AppNavigator.getInstance().pop();
            })

        TextInput({
          placeholder: '搜索帖子、版块或用户',
          text: this.keyword
        })
          .height(36)
          .fontSize(14)
          .fontColor(getTheme(this.isDark).textPrimary)
          .placeholderColor(getTheme(this.isDark).textMuted)
          .backgroundColor(getTheme(this.isDark).inputBg)
          .enterKeyType(EnterKeyType.Search)
          .layoutWeight(1)
          .onChange((value: string) => {
            this.keyword = value;
            if (value.trim().length === 0) {
              this.hasSearched = false;
              this.errorMessage = '';
              this.needLogin = false;
            }
          })
          .onSubmit(() => {
            this.submitKeyword();
          })

        Button('搜索')
          .fontSize(12)
          .height(34)
          .backgroundColor(getTheme(this.isDark).accentSolid)
          .fontColor(Color.White)
          .onClick(() => {
            this.submitKeyword();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      Row({ space: 8 }) {
        this.renderTypeButton(SearchTabType.THREAD, '帖子')
        this.renderTypeButton(SearchTabType.FORUM, '版块')
        this.renderTypeButton(SearchTabType.USER, '用户')
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      if (this.searchType === SearchTabType.THREAD) {
        Row({ space: 8 }) {
          Text('排序：')
            .fontSize(12)
            .fontColor(getTheme(this.isDark).textSecondary)
          ForEach(SORT_OPTIONS, (opt: SortOption) => {
            Button(opt.label)
              .fontSize(12)
              .height(28)
              .backgroundColor(
                this.sort === opt.value
                  ? getTheme(this.isDark).accentBg
                  : getTheme(this.isDark).surfaceMuted
              )
              .fontColor(
                this.sort === opt.value
                  ? getTheme(this.isDark).accent
                  : getTheme(this.isDark).textSecondary
              )
              .onClick(() => {
                this.switchSort(opt.value);
              })
          }, (opt: SortOption) => `${this.isDark ? 'd' : 'l'}_${this.sort}_${opt.value}`)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })
      }

      if (!this.hasSearched) {
        Scroll() {
          Column({ space: 12 }) {
            Column({ space: 10 }) {
              Row() {
                Text('最近搜索')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(getTheme(this.isDark).textPrimary)
                Blank()
                if (this.history.length > 0) {
                  Text('清空')
                    .fontSize(12)
                    .fontColor(getTheme(this.isDark).accent)
                    .onClick(() => {
                      this.clearHistory();
                    })
                }
              }
              .width('100%')

              if (this.history.length === 0) {
                Text('输入关键词开始检索龙空帖子、版块或坛友。')
                  .fontSize(13)
                  .fontColor(getTheme(this.isDark).textMuted)
              } else {
                Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
                  ForEach(this.history, (item: string) => {
                    Button(item)
                      .fontSize(12)
                      .height(30)
                      .backgroundColor(getTheme(this.isDark).surfaceMuted)
                      .fontColor(getTheme(this.isDark).textPrimary)
                      .onClick(() => {
                        this.executeSearch(item);
                      })
                  }, (item: string) => `${this.isDark ? 'd' : 'l'}_hist_${item}`)
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
          .padding({ left: 16, right: 16, top: 4, bottom: 16 })
        }
        .layoutWeight(1)
      } else if (this.loading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(getTheme(this.isDark).accent)
          Text('正在搜索...')
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
            message: '龙空搜索功能需要登录后使用，请先登录账号。',
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
            title: '搜索失败',
            message: this.errorMessage,
            actionText: '重试',
            onAction: () => {
              this.executeSearch(this.submittedKeyword);
            }
          })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.isResultEmpty()) {
        Column() {
          StateView({
            title: '未找到相关内容',
            message: `没有找到与「${this.submittedKeyword}」匹配的记录，换个关键词试试。`
          })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.searchType === SearchTabType.THREAD) {
        List({ space: 10 }) {
          ForEach(this.threadResults, (item: SearchThreadItem) => {
            ListItem() {
              Column({ space: 6 }) {
                Text() {
                  ForEach(splitHighlightText(item.rawTitle), (seg: HighlightSegment, sIdx: number) => {
                    Span(seg.text)
                      .fontSize(15)
                      .fontWeight(seg.highlight ? FontWeight.Bold : FontWeight.Medium)
                      .fontColor(
                        seg.highlight
                          ? getTheme(this.isDark).highlightText
                          : getTheme(this.isDark).textPrimary
                      )
                  }, (seg: HighlightSegment, sIdx: number) =>
                    `${this.isDark ? 'd' : 'l'}_${item.tid}_${sIdx}_${seg.highlight ? 'h' : 'n'}_${seg.text.length}`
                  )
                }
                .width('100%')
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

                Row({ space: 8 }) {
                  if (item.authorName.length > 0) {
                    Text(item.authorName)
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
                  }
                  if (item.forumName.length > 0) {
                    Text(item.forumName)
                      .fontSize(11)
                      .fontColor(getTheme(this.isDark).textSecondary)
                      .backgroundColor(getTheme(this.isDark).surfaceMuted)
                      .borderRadius(4)
                      .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .constraintSize({ maxWidth: 90 })
                  }
                  Text(`回 ${item.replyCount}`)
                    .fontSize(12)
                    .fontColor(getTheme(this.isDark).textMuted)
                  Text(`阅 ${item.viewCount}`)
                    .fontSize(12)
                    .fontColor(getTheme(this.isDark).textMuted)
                  Blank()
                  Text(formatTime(item.dateline))
                    .fontSize(12)
                    .fontColor(getTheme(this.isDark).textMuted)
                }
                .width('100%')
              }
              .width('100%')
              .padding(14)
              .backgroundColor(getTheme(this.isDark).cardBg)
              .borderRadius(12)
              .alignItems(HorizontalAlign.Start)
              .onClick(() => {
                this.openThread(item.tid, item.plainTitle);
              })
            }
          }, (item: SearchThreadItem) => `${this.isDark ? 'd' : 'l'}_st_${item.tid}`)

          if (this.hasMore) {
            ListItem() {
              Row() {
                Button(this.loadingMore ? '正在加载更多...' : '加载更多')
                  .fontSize(13)
                  .height(36)
                  .width('100%')
                  .backgroundColor(getTheme(this.isDark).accentBg)
                  .fontColor(getTheme(this.isDark).accent)
                  .enabled(!this.loadingMore)
                  .onClick(() => {
                    this.loadMoreThreads();
                  })
              }
              .width('100%')
              .padding({ top: 4, bottom: 12 })
            }
          }
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 16 })
        .scrollBar(BarState.Auto)
      } else if (this.searchType === SearchTabType.FORUM) {
        List({ space: 10 }) {
          ForEach(this.forumResults, (forum: SearchForumItem) => {
            ListItem() {
              Row({ space: 12 }) {
                SearchAvatar({
                  avatarUrl: forum.avatarUrl,
                  labelName: forum.name,
                  isCircle: false
                })
                Column({ space: 4 }) {
                  Text(forum.name)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(getTheme(this.isDark).textPrimary)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`关注 ${forum.followers} · 主题 ${forum.threads}`)
                    .fontSize(12)
                    .fontColor(getTheme(this.isDark).textSecondary)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding(14)
              .backgroundColor(getTheme(this.isDark).cardBg)
              .borderRadius(12)
              .onClick(() => {
                this.openForum(forum.fid, forum.name);
              })
            }
          }, (forum: SearchForumItem) => `${this.isDark ? 'd' : 'l'}_sf_${forum.fid}`)
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 16 })
        .scrollBar(BarState.Auto)
      } else {
        List({ space: 10 }) {
          ForEach(this.userResults, (user: SearchUserItem) => {
            ListItem() {
              Row({ space: 12 }) {
                SearchAvatar({
                  avatarUrl: user.avatarUrl,
                  labelName: user.name,
                  isCircle: true
                })
                Column({ space: 4 }) {
                  Row({ space: 6 }) {
                    Text(user.name)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(getTheme(this.isDark).textPrimary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (user.verifyInfo.length > 0) {
                      Text(user.verifyInfo)
                        .fontSize(10)
                        .fontColor(getTheme(this.isDark).accent)
                        .backgroundColor(getTheme(this.isDark).accentBg)
                        .borderRadius(4)
                        .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                        .maxLines(1)
                    }
                  }
                  Text(`UID ${user.uid} · 粉丝 ${user.followers}`)
                    .fontSize(12)
                    .fontColor(getTheme(this.isDark).textSecondary)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding(14)
              .backgroundColor(getTheme(this.isDark).cardBg)
              .borderRadius(12)
              .onClick(() => {
                this.openUserProfile(user.uid, user.name);
              })
            }
          }, (user: SearchUserItem) => `${this.isDark ? 'd' : 'l'}_su_${user.uid}`)
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 16 })
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(getTheme(this.isDark).pageBg)
    }
    .hideTitleBar(true)
    .onShown(() => {
      if (!this.bootstrapped) {
        return;
      }
      if (this.needLogin && CookieStore.getInstance().hasCookie() && this.submittedKeyword.length > 0) {
        this.executeSearch(this.submittedKeyword);
      }
    })
  }
}
