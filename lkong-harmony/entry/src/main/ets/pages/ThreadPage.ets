import { promptAction, router } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { ApiError, ErrorKind, PostItem } from '../model/Models';
import { LkongApi } from '../network/LkongApi';
import { CookieStore } from '../store/CookieStore';
import { DisplayPrefs } from '../store/DisplayPrefs';
import { StateView } from '../components/StateView';
import { PostCard } from '../components/PostCard';
import { formatTime } from '../utils/TimeUtils';
import {
  FontSizePreset,
  fontSizeLabel,
  getTheme,
  KEY_FONT_SIZE,
  KEY_IS_DARK
} from '../utils/Theme';

const POSTS_PER_PAGE: number = 20;
const FONT_PRESETS: number[] = [
  FontSizePreset.SMALL,
  FontSizePreset.STANDARD,
  FontSizePreset.LARGE,
  FontSizePreset.XLARGE
];

interface ThreadParams {
  tid: number;
  title: string;
}

/**
 * 帖子详情页：原生列表展示楼层，支持只看作者、快速跳页、字号快捷调节、富文本与图片预览。
 * 不做 HTML 注入，也不需要在 List 中嵌套大量 Web 组件。
 */
@Entry
@Component
struct ThreadPage {
  @State tid: number = 0;
  @State fallbackTitle: string = '';
  @State apiTitle: string = '';
  @State authorName: string = '';
  @State authorId: number = 0;
  @State postTime: string = '';
  @State replyCount: number = 0;
  @State viewCount: number = 0;
  @State forumName: string = '';
  @State page: number = 1;
  @State posts: PostItem[] = [];
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State needLogin: boolean = false;
  @State hasMore: boolean = true;
  @State totalPages: number = 1;
  @State onlyAuthor: boolean = false;
  @State showFontBar: boolean = false;
  @State showJumpModal: boolean = false;
  @State jumpInput: string = '';
  @State previewImageUrl: string = '';
  @State activeLinkUrl: string = '';

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;
  @StorageProp(KEY_FONT_SIZE) bodyFontSize: number = FontSizePreset.STANDARD;

  onBackPress(): boolean {
    if (this.previewImageUrl.length > 0) {
      this.previewImageUrl = '';
      return true;
    }
    if (this.activeLinkUrl.length > 0) {
      this.activeLinkUrl = '';
      return true;
    }
    if (this.showJumpModal) {
      this.showJumpModal = false;
      return true;
    }
    if (this.showFontBar) {
      this.showFontBar = false;
      return true;
    }
    return false;
  }

  aboutToAppear(): void {
    const raw = router.getParams();
    if (raw !== undefined && raw !== null) {
      const params = raw as ThreadParams;
      this.tid = params.tid === undefined ? 0 : params.tid;
      this.fallbackTitle = params.title === undefined ? '' : params.title;
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

  private showToast(message: string): void {
    try {
      promptAction.showToast({ message: message });
    } catch (error) {
      // 忽略页面退出等场景下的弹窗异常。
    }
  }

  private async loadPage(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    this.needLogin = false;
    try {
      const filterAuthorId = this.onlyAuthor && this.authorId > 0 ? this.authorId : 0;
      const data = await LkongApi.getInstance().getThreadDetail(this.tid, this.page, filterAuthorId);
      this.apiTitle = data.thread.title;
      this.authorName = data.thread.authorName;
      if (data.thread.authorId > 0) {
        this.authorId = data.thread.authorId;
      }
      this.postTime = data.thread.postTime;
      this.replyCount = data.thread.replyCount;
      this.viewCount = data.thread.viewCount;
      this.forumName = data.thread.forumName;
      this.posts = data.posts;
      if (this.onlyAuthor) {
        this.hasMore = data.posts.length >= POSTS_PER_PAGE;
        this.totalPages = this.hasMore ? this.page + 1 : this.page;
      } else {
        const estimatedTotalPages = Math.max(1, Math.ceil((data.thread.replyCount + 1) / POSTS_PER_PAGE));
        this.totalPages = Math.max(estimatedTotalPages, this.page);
        if (data.thread.replyCount > 0) {
          this.hasMore = this.page < estimatedTotalPages;
        } else {
          this.hasMore = data.posts.length >= POSTS_PER_PAGE;
        }
      }
    } catch (error) {
      if (error instanceof ApiError && error.kind === ErrorKind.AUTH) {
        this.needLogin = true;
        this.errorMessage = error.message;
      } else if (error instanceof ApiError) {
        this.errorMessage = error.message;
      } else {
        this.errorMessage = '帖子加载失败，请稍后重试。';
      }
    } finally {
      this.loading = false;
    }
  }

  private displayTitle(): string {
    if (this.apiTitle.length > 0) {
      return this.apiTitle;
    }
    return this.fallbackTitle;
  }

  private goLogin(): void {
    router.pushUrl({ url: 'pages/LoginPage' }).catch(() => {
    });
  }

  private toggleOnlyAuthor(): void {
    if (this.loading || this.authorId <= 0) {
      return;
    }
    this.onlyAuthor = !this.onlyAuthor;
    this.page = 1;
    this.loadPage();
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

  private jumpToPage(target: number): void {
    this.showJumpModal = false;
    if (target < 1 || (!this.onlyAuthor && target > this.totalPages)) {
      return;
    }
    if (target !== this.page) {
      this.page = target;
      this.loadPage();
    }
  }

  private submitJumpInput(): void {
    const trimmed = this.jumpInput.trim();
    const parsed = Number(trimmed);
    if (!/^\d+$/.test(trimmed) || isNaN(parsed) || parsed < 1 || (!this.onlyAuthor && parsed > this.totalPages)) {
      this.showToast(this.onlyAuthor ? '请输入大于 0 的页码' : `请输入 1 到 ${this.totalPages} 之间的页码`);
      return;
    }
    this.jumpToPage(parsed);
  }

  private async copyActiveLink(): Promise<void> {
    if (this.activeLinkUrl.length === 0) {
      return;
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.activeLinkUrl);
      await pasteboard.getSystemPasteboard().setData(data);
      this.showToast('链接已复制到剪贴板');
      this.activeLinkUrl = '';
    } catch (error) {
      this.showToast('复制失败，请稍后重试');
    }
  }

  build() {
    Stack() {
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
          Text(this.displayTitle().length > 0 ? this.displayTitle() : '帖子')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(getTheme(this.isDark).textPrimary)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Button('字号')
            .fontSize(12)
            .height(32)
            .backgroundColor(this.showFontBar ? getTheme(this.isDark).accentSolid : getTheme(this.isDark).accentBg)
            .fontColor(this.showFontBar ? Color.White : getTheme(this.isDark).accent)
            .onClick(() => {
              this.showFontBar = !this.showFontBar;
            })
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

        if (this.showFontBar) {
          Column() {
            Row({ space: 8 }) {
              Text('正文字号')
                .fontSize(12)
                .fontColor(getTheme(this.isDark).textSecondary)
              Blank()
              ForEach(FONT_PRESETS, (preset: number) => {
                Button(`${fontSizeLabel(preset)}`)
                  .fontSize(12)
                  .height(28)
                  .backgroundColor(
                    this.bodyFontSize === preset
                      ? getTheme(this.isDark).accentSolid
                      : getTheme(this.isDark).surfaceMuted
                  )
                  .fontColor(
                    this.bodyFontSize === preset
                      ? Color.White
                      : getTheme(this.isDark).textPrimary
                  )
                  .onClick(() => {
                    DisplayPrefs.getInstance().setFontSize(preset);
                  })
              }, (preset: number) => `${this.isDark ? 'd' : 'l'}_${this.bodyFontSize}_${preset}`)
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor(getTheme(this.isDark).cardBg)
            .borderRadius(10)
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })
        }

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
              message: '查看帖子需要登录，请先登录账号。',
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
        } else {
          List({ space: 10 }) {
            ListItem() {
              Column({ space: 6 }) {
                Text(this.displayTitle())
                  .width('100%')
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(getTheme(this.isDark).textPrimary)
                Row({ space: 8 }) {
                  Text(this.authorName.length > 0 ? this.authorName : '匿名用户')
                    .fontSize(12)
                    .fontColor(getTheme(this.isDark).textSecondary)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(formatTime(this.postTime))
                    .fontSize(12)
                    .fontColor(getTheme(this.isDark).textMuted)
                }
                .width('100%')

                Row({ space: 10 }) {
                  Text(`回复 ${this.replyCount}`)
                    .fontSize(12)
                    .fontColor(getTheme(this.isDark).textMuted)
                  Text(`查看 ${this.viewCount}`)
                    .fontSize(12)
                    .fontColor(getTheme(this.isDark).textMuted)
                  if (this.forumName.length > 0) {
                    Text(this.forumName)
                      .fontSize(12)
                      .fontColor(getTheme(this.isDark).textMuted)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  Blank()
                  if (this.authorId > 0) {
                    Button(this.onlyAuthor ? '查看全部' : '只看作者')
                      .fontSize(11)
                      .height(26)
                      .padding({ left: 10, right: 10 })
                      .backgroundColor(
                        this.onlyAuthor ? getTheme(this.isDark).accentSolid : getTheme(this.isDark).accentBg
                      )
                      .fontColor(this.onlyAuthor ? Color.White : getTheme(this.isDark).accent)
                      .onClick(() => {
                        this.toggleOnlyAuthor();
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
            }

            if (this.posts.length === 0) {
              ListItem() {
                StateView({
                  title: '暂无楼层',
                  message: this.onlyAuthor ? '作者当前页没有可显示的发言。' : '当前页没有可显示的楼层内容。'
                })
              }
            }

            ForEach(this.posts, (post: PostItem, index: number) => {
              ListItem() {
                PostCard({
                  floor: post.floor,
                  authorName: post.authorName,
                  postTime: formatTime(post.postTime),
                  contentHtml: post.contentHtml,
                  isAuthor: post.isAuthor,
                  onImageClick: (url: string) => {
                    this.previewImageUrl = url;
                  },
                  onLinkClick: (url: string) => {
                    this.activeLinkUrl = url;
                  }
                })
              }
            }, (post: PostItem, index: number) =>
              post.pid.length > 0
                ? `${this.onlyAuthor ? 'a' : 'all'}_${this.page}_${post.pid}`
                : `${this.onlyAuthor ? 'a' : 'all'}_${this.page}_${post.floor}_${index}`
            )
          }
          .layoutWeight(1)
          .padding({ left: 16, right: 16 })
          .scrollBar(BarState.Auto)

          Row({ space: 10 }) {
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
            Button(this.onlyAuthor ? `仅看作者 · 第 ${this.page} 页 ▾` : `第 ${this.page} / ${this.totalPages} 页 ▾`)
              .fontSize(13)
              .height(34)
              .backgroundColor(getTheme(this.isDark).cardBg)
              .fontColor(getTheme(this.isDark).textPrimary)
              .onClick(() => {
                this.jumpInput = '';
                this.showJumpModal = true;
              })
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

      if (this.showJumpModal) {
        Column() {
          Column({ space: 12 }) {
            Text('快速跳页')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(getTheme(this.isDark).textPrimary)
            Text(
              this.onlyAuthor
                ? `当前仅看作者第 ${this.page} 页`
                : `当前第 ${this.page} 页，共 ${this.totalPages} 页`
            )
              .fontSize(12)
              .fontColor(getTheme(this.isDark).textSecondary)

            Row({ space: 8 }) {
              Button('首页')
                .fontSize(13)
                .height(34)
                .layoutWeight(1)
                .backgroundColor(getTheme(this.isDark).accentBg)
                .fontColor(getTheme(this.isDark).accent)
                .onClick(() => {
                  this.jumpToPage(1);
                })
              if (!this.onlyAuthor && this.totalPages > 1) {
                Button(`末页 (${this.totalPages})`)
                  .fontSize(13)
                  .height(34)
                  .layoutWeight(1)
                  .backgroundColor(getTheme(this.isDark).accentBg)
                  .fontColor(getTheme(this.isDark).accent)
                  .onClick(() => {
                    this.jumpToPage(this.totalPages);
                  })
              }
            }
            .width('100%')

            Row({ space: 8 }) {
              TextInput({
                placeholder: this.onlyAuthor ? '输入目标页码' : `1 - ${this.totalPages}`,
                text: this.jumpInput
              })
                .type(InputType.Number)
                .height(38)
                .fontSize(14)
                .fontColor(getTheme(this.isDark).textPrimary)
                .placeholderColor(getTheme(this.isDark).textMuted)
                .backgroundColor(getTheme(this.isDark).inputBg)
                .layoutWeight(1)
                .onChange((value: string) => {
                  this.jumpInput = value;
                })
                .onSubmit(() => {
                  this.submitJumpInput();
                })
              Button('跳转')
                .fontSize(13)
                .height(38)
                .backgroundColor(getTheme(this.isDark).accentSolid)
                .fontColor(Color.White)
                .onClick(() => {
                  this.submitJumpInput();
                })
            }
            .width('100%')

            Button('取消')
              .fontSize(13)
              .height(34)
              .width('100%')
              .backgroundColor(getTheme(this.isDark).surfaceMuted)
              .fontColor(getTheme(this.isDark).textSecondary)
              .onClick(() => {
                this.showJumpModal = false;
              })
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
          this.showJumpModal = false;
        })
      }

      if (this.activeLinkUrl.length > 0) {
        Column() {
          Column({ space: 12 }) {
            Text('帖子链接')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(getTheme(this.isDark).textPrimary)
            Text(this.activeLinkUrl)
              .fontSize(13)
              .fontColor(getTheme(this.isDark).textSecondary)
              .lineHeight(20)
              .width('100%')
            Row({ space: 10 }) {
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
                .backgroundColor(getTheme(this.isDark).accentSolid)
                .fontColor(Color.White)
                .onClick(() => {
                  this.copyActiveLink();
                })
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

      if (this.previewImageUrl.length > 0) {
        Column() {
          Row() {
            Blank()
            Button('关闭')
              .fontSize(13)
              .height(32)
              .backgroundColor('#33FFFFFF')
              .fontColor(Color.White)
              .onClick(() => {
                this.previewImageUrl = '';
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 8 })

          Image(this.previewImageUrl)
            .width('100%')
            .layoutWeight(1)
            .objectFit(ImageFit.Contain)
            .padding({ left: 12, right: 12, bottom: 24 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#E6000000')
        .onClick(() => {
          this.previewImageUrl = '';
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
