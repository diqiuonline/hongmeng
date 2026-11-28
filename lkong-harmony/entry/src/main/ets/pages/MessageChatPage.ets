import { LengthMetrics } from '@kit.ArkUI';
import {
  ApiError,
  BlockKind,
  ErrorKind,
  InlineKind,
  PmMessageItem,
  PostBlock,
  PostInline,
  ThreadImageItem
} from '../model/Models';
import { LkongApi } from '../network/LkongApi';
import { CookieStore } from '../store/CookieStore';
import { DisplayPrefs } from '../store/DisplayPrefs';
import { StateView } from '../components/StateView';
import { PostImage } from '../components/PostImage';
import { ImageViewerOverlay } from '../components/ImageViewerOverlay';
import { KEY_NOTICE_COUNT_DIRTY, KEY_PM_LIST_DIRTY } from '../utils/AppConfig';
import { AppNavigator, MessageChatRouteParams, Routes, UserProfileRouteParams } from '../utils/AppRouter';
import { safeAvatarInitial } from '../utils/AvatarUtils';
import { parsePostBlocks } from '../utils/ContentUtils';
import { pickImageUris, prepareAndUploadImage } from '../utils/ImageUploadUtils';
import { formatTime } from '../utils/TimeUtils';
import { getTheme, KEY_IS_DARK } from '../utils/Theme';
import { getHostContext, showToast } from '../utils/UiUtils';

/**
 * 站内私信聊天页：支持游标加载历史消息、收发文本与图片私信、删除单条消息以及图片全屏查看保存。
 */
@Component
export struct MessageChatPage {
  @State targetUid: number = 0;
  @State targetName: string = '';
  @State targetAvatarUrl: string = '';
  @State myUid: number = 0;
  @State messages: PmMessageItem[] = [];
  @State hasMore: boolean = false;
  @State nextDate: string = '';
  @State loading: boolean = true;
  @State loadingOlder: boolean = false;
  @State sending: boolean = false;
  @State uploadingImage: boolean = false;
  @State errorMessage: string = '';
  @State needLogin: boolean = false;
  @State draftText: string = '';
  @State deleteTarget: PmMessageItem | null = null;
  @State deleting: boolean = false;

  @State showImageViewer: boolean = false;
  @State viewerImages: ThreadImageItem[] = [];
  @State viewerIndex: number = 0;

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;
  private scroller: Scroller = new Scroller();
  private readyHandled: boolean = false;
  private bootstrapped: boolean = false;

  private async bootstrap(): Promise<void> {
    const ctx = getHostContext(this.getUIContext());
    await CookieStore.getInstance().ensureInit(ctx);
    await DisplayPrefs.getInstance().ensureInit(ctx);
    this.bootstrapped = true;
    await this.loadLatest(true);
  }

  private async resolveMyUid(): Promise<number> {
    const cached = LkongApi.getInstance().getCachedCurrentUser();
    if (cached !== null && cached.uid > 0) {
      return cached.uid;
    }
    try {
      const me = await LkongApi.getInstance().ensureCurrentUser();
      return me.uid;
    } catch (error) {
      return 0;
    }
  }

  private sortAscending(items: PmMessageItem[]): PmMessageItem[] {
    const copy: PmMessageItem[] = [];
    for (const item of items) {
      copy.push(item);
    }
    copy.sort((a: PmMessageItem, b: PmMessageItem) => {
      const ta = Number(a.dateline);
      const tb = Number(b.dateline);
      if (!isNaN(ta) && !isNaN(tb) && ta !== tb) {
        return ta - tb;
      }
      return a.dateline.localeCompare(b.dateline);
    });
    return copy;
  }

  private async loadLatest(scrollToBottom: boolean): Promise<void> {
    if (this.targetUid <= 0) {
      this.loading = false;
      this.errorMessage = '无效的对话用户 ID。';
      return;
    }
    this.loading = true;
    this.errorMessage = '';
    this.needLogin = false;
    try {
      if (this.myUid <= 0) {
        this.myUid = await this.resolveMyUid();
      }
      const res = await LkongApi.getInstance().getPmMessages(this.targetUid, '');
      this.messages = this.sortAscending(res.items);
      this.hasMore = res.hasMore && res.nextDate.length > 0;
      this.nextDate = res.nextDate;
      AppStorage.setOrCreate(KEY_NOTICE_COUNT_DIRTY, true);
      AppStorage.setOrCreate(KEY_PM_LIST_DIRTY, true);
      if (scrollToBottom && this.messages.length > 0) {
        this.scrollToLatest();
      }
    } catch (error) {
      if (error instanceof ApiError && error.kind === ErrorKind.AUTH) {
        this.needLogin = true;
        this.errorMessage = error.message;
      } else if (error instanceof ApiError) {
        this.errorMessage = error.message;
      } else {
        this.errorMessage = '私信记录加载失败，请稍后重试。';
      }
    } finally {
      this.loading = false;
    }
  }

  private async loadOlder(): Promise<void> {
    if (this.loading || this.loadingOlder || !this.hasMore || this.nextDate.length === 0) {
      return;
    }
    this.loadingOlder = true;
    try {
      const res = await LkongApi.getInstance().getPmMessages(this.targetUid, this.nextDate);
      const seen = new Set<string>();
      const combined: PmMessageItem[] = [];
      for (const item of res.items) {
        if (item.id.length > 0 && seen.has(item.id)) {
          continue;
        }
        if (item.id.length > 0) {
          seen.add(item.id);
        }
        combined.push(item);
      }
      for (const item of this.messages) {
        if (item.id.length > 0 && seen.has(item.id)) {
          continue;
        }
        if (item.id.length > 0) {
          seen.add(item.id);
        }
        combined.push(item);
      }
      this.messages = this.sortAscending(combined);
      this.hasMore = res.hasMore && res.nextDate.length > 0;
      this.nextDate = res.nextDate;
    } catch (error) {
      const msg = error instanceof ApiError ? error.message : '加载更早消息失败。';
      showToast(this.getUIContext(), msg);
    } finally {
      this.loadingOlder = false;
    }
  }

  private scrollToLatest(): void {
    const targetIdx = Math.max(0, this.messages.length);
    setTimeout(() => {
      try {
        this.scroller.scrollToIndex(targetIdx, false, ScrollAlign.END);
      } catch (error) {
        // 忽略列表未挂载时的滚动异常。
      }
    }, 60);
  }

  private async sendText(): Promise<void> {
    if (this.sending || this.uploadingImage) {
      return;
    }
    if (!CookieStore.getInstance().hasCookie()) {
      showToast(this.getUIContext(), '请先登录后再发送私信');
      AppNavigator.getInstance().push(Routes.LOGIN);
      return;
    }
    const trimmed = this.draftText.trim();
    if (trimmed.length === 0) {
      showToast(this.getUIContext(), '请输入私信内容');
      return;
    }
    this.sending = true;
    try {
      if (this.myUid <= 0) {
        this.myUid = await this.resolveMyUid();
      }
      const created = await LkongApi.getInstance().sendPmText(this.targetUid, trimmed);
      this.draftText = '';
      this.appendMessage(created);
      AppStorage.setOrCreate(KEY_PM_LIST_DIRTY, true);
      AppStorage.setOrCreate(KEY_NOTICE_COUNT_DIRTY, true);
    } catch (error) {
      const msg = error instanceof ApiError ? error.message : '发送失败，请稍后重试。';
      showToast(this.getUIContext(), msg);
    } finally {
      this.sending = false;
    }
  }

  private async sendImage(): Promise<void> {
    if (this.sending || this.uploadingImage) {
      return;
    }
    if (!CookieStore.getInstance().hasCookie()) {
      showToast(this.getUIContext(), '请先登录后再发送图片私信');
      AppNavigator.getInstance().push(Routes.LOGIN);
      return;
    }
    try {
      const uris = await pickImageUris(1);
      if (uris.length === 0) {
        return;
      }
      this.uploadingImage = true;
      if (this.myUid <= 0) {
        this.myUid = await this.resolveMyUid();
      }
      const uploaded = await prepareAndUploadImage(uris[0]);
      const created = await LkongApi.getInstance().sendPmImage(this.targetUid, uploaded.key);
      this.appendMessage(created);
      AppStorage.setOrCreate(KEY_PM_LIST_DIRTY, true);
      AppStorage.setOrCreate(KEY_NOTICE_COUNT_DIRTY, true);
    } catch (error) {
      const msg = error instanceof ApiError ? error.message : '图片发送失败，请稍后重试。';
      showToast(this.getUIContext(), msg);
    } finally {
      this.uploadingImage = false;
    }
  }

  private appendMessage(created: PmMessageItem): void {
    const nextList: PmMessageItem[] = [];
    for (const item of this.messages) {
      nextList.push(item);
    }
    nextList.push({
      id: created.id,
      uid: created.uid > 0 ? created.uid : this.myUid,
      content: created.content,
      dateline: created.dateline
    });
    this.messages = nextList;
    this.scrollToLatest();
  }

  private async confirmDeleteMessage(): Promise<void> {
    if (this.deleteTarget === null || this.deleting) {
      return;
    }
    const target = this.deleteTarget;
    if (target.id.length === 0) {
      this.deleteTarget = null;
      return;
    }
    this.deleting = true;
    try {
      const ok = await LkongApi.getInstance().deletePmMessage(this.targetUid, target.id);
      if (ok) {
        const remaining: PmMessageItem[] = [];
        for (const item of this.messages) {
          if (item.id !== target.id) {
            remaining.push(item);
          }
        }
        this.messages = remaining;
        this.deleteTarget = null;
        AppStorage.setOrCreate(KEY_PM_LIST_DIRTY, true);
        showToast(this.getUIContext(), '消息已删除');
      } else {
        showToast(this.getUIContext(), '删除未生效，请重试');
      }
    } catch (error) {
      const msg = error instanceof ApiError ? error.message : '删除失败，请稍后重试。';
      showToast(this.getUIContext(), msg);
    } finally {
      this.deleting = false;
    }
  }

  private openUserProfile(): void {
    if (this.targetUid <= 0) {
      return;
    }
    const params: UserProfileRouteParams = {
      uid: this.targetUid,
      name: this.targetName
    };
    AppNavigator.getInstance().push(Routes.USER_PROFILE, params);
  }

  private openImageViewer(clickedUrl: string): void {
    const allImages: ThreadImageItem[] = [];
    let matchedIndex = -1;
    for (const msg of this.messages) {
      const blocks = parsePostBlocks(msg.content);
      const senderLabel = msg.uid === this.myUid ? '我' : (this.targetName.length > 0 ? this.targetName : '对方');
      for (const blk of blocks) {
        if (blk.kind === BlockKind.IMAGE && blk.imageUrl.length > 0) {
          if (matchedIndex < 0 && blk.imageUrl === clickedUrl) {
            matchedIndex = allImages.length;
          }
          allImages.push({
            url: blk.imageUrl,
            pid: msg.id,
            floor: '私信',
            authorName: senderLabel
          });
        }
      }
    }
    if (allImages.length === 0) {
      allImages.push({
        url: clickedUrl,
        pid: '',
        floor: '私信',
        authorName: this.targetName
      });
      matchedIndex = 0;
    }
    this.viewerImages = allImages;
    this.viewerIndex = matchedIndex >= 0 ? matchedIndex : 0;
    this.showImageViewer = true;
  }

  private isSelfMessage(msg: PmMessageItem): boolean {
    if (this.myUid > 0) {
      return msg.uid === this.myUid;
    }
    return msg.uid !== this.targetUid;
  }

  @Builder
  private renderMessageContent(rawContent: string, isSelf: boolean) {
    Column({ space: 6 }) {
      ForEach(parsePostBlocks(rawContent), (blk: PostBlock, bIdx: number) => {
        if (blk.kind === BlockKind.IMAGE && blk.imageUrl.length > 0) {
          PostImage({
            url: blk.imageUrl,
            altText: blk.imageAlt,
            initialWidth: blk.imageWidth,
            initialHeight: blk.imageHeight,
            onPreview: (url: string) => {
              this.openImageViewer(url);
            }
          })
        } else {
          Text() {
            ForEach(blk.inlines, (inline: PostInline, iIdx: number) => {
              if (inline.kind === InlineKind.EMOTION && inline.url.length > 0) {
                ImageSpan(inline.url)
                  .width(24)
                  .height(24)
                  .objectFit(ImageFit.Contain)
                  .verticalAlign(ImageSpanAlignment.CENTER)
                  .margin({ left: 2, right: 2 })
              } else {
                Span(inline.text)
                  .fontSize(14)
                  .fontColor(isSelf ? Color.White : getTheme(this.isDark).textPrimary)
              }
            }, (inline: PostInline, iIdx: number) =>
              `${this.isDark ? 'd' : 'l'}_${isSelf ? 's' : 'o'}_${iIdx}_${inline.kind}_${inline.text.length}`
            )
          }
          .minLineHeight(LengthMetrics.vp(20))
        }
      }, (blk: PostBlock, bIdx: number) =>
        `${this.isDark ? 'd' : 'l'}_${isSelf ? 's' : 'o'}_${bIdx}_${blk.kind}_${blk.imageUrl}`
      )
    }
    .alignItems(HorizontalAlign.Start)
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
            Text(this.targetName.length > 0 ? this.targetName : `用户 #${this.targetUid}`)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(getTheme(this.isDark).textPrimary)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .onClick(() => {
                this.openUserProfile();
              })
            Button('主页')
              .fontSize(12)
              .height(32)
              .backgroundColor(getTheme(this.isDark).surfaceMuted)
              .fontColor(getTheme(this.isDark).textPrimary)
              .onClick(() => {
                this.openUserProfile();
              })
            Button('刷新')
              .fontSize(12)
              .height(32)
              .backgroundColor(getTheme(this.isDark).accentBg)
              .fontColor(getTheme(this.isDark).accent)
              .onClick(() => {
                this.loadLatest(true);
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 10 })

          if (this.loading) {
            Column() {
              LoadingProgress()
                .width(40)
                .height(40)
                .color(getTheme(this.isDark).accent)
              Text('正在加载私信...')
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
                message: '查看和发送站内私信需要先登录龙空账号。',
                actionText: '去登录',
                onAction: () => {
                  AppNavigator.getInstance().push(Routes.LOGIN);
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
                  this.loadLatest(true);
                }
              })
            }
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else {
            List({ space: 12, scroller: this.scroller }) {
              if (this.hasMore) {
                ListItem() {
                  Row() {
                    Button(this.loadingOlder ? '加载中...' : '加载更早消息')
                      .fontSize(12)
                      .height(30)
                      .backgroundColor(getTheme(this.isDark).cardBg)
                      .fontColor(getTheme(this.isDark).accent)
                      .enabled(!this.loadingOlder)
                      .onClick(() => {
                        this.loadOlder();
                      })
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.Center)
                }
              }

              if (this.messages.length === 0) {
                ListItem() {
                  StateView({
                    title: '暂无私信记录',
                    message: '在下方输入文字或发送图片，开始与对方对话。'
                  })
                }
              }

              ForEach(this.messages, (msg: PmMessageItem, index: number) => {
                ListItem() {
                  Column({ space: 4 }) {
                    Row({ space: 8 }) {
                      if (!this.isSelfMessage(msg)) {
                        if (this.targetAvatarUrl.length > 0) {
                          Image(this.targetAvatarUrl)
                            .width(34)
                            .height(34)
                            .borderRadius(17)
                            .objectFit(ImageFit.Cover)
                            .onClick(() => {
                              this.openUserProfile();
                            })
                        } else {
                          Text(safeAvatarInitial(this.targetName))
                            .width(34)
                            .height(34)
                            .borderRadius(17)
                            .backgroundColor(getTheme(this.isDark).accentBg)
                            .fontColor(getTheme(this.isDark).accent)
                            .fontSize(14)
                            .fontWeight(FontWeight.Medium)
                            .textAlign(TextAlign.Center)
                            .onClick(() => {
                              this.openUserProfile();
                            })
                        }
                      } else {
                        Blank()
                      }

                      Column({ space: 4 }) {
                        Column() {
                          this.renderMessageContent(msg.content, this.isSelfMessage(msg))
                        }
                        .padding({ left: 12, right: 12, top: 9, bottom: 9 })
                        .backgroundColor(
                          this.isSelfMessage(msg)
                            ? getTheme(this.isDark).accentSolid
                            : getTheme(this.isDark).cardBg
                        )
                        .borderRadius(12)
                        .constraintSize({ maxWidth: '72%' })

                        Row({ space: 8 }) {
                          if (msg.dateline.length > 0) {
                            Text(formatTime(msg.dateline))
                              .fontSize(10)
                              .fontColor(getTheme(this.isDark).textMuted)
                          }
                          if (msg.id.length > 0) {
                            Text('删除')
                              .fontSize(10)
                              .fontColor(getTheme(this.isDark).dangerText)
                              .onClick(() => {
                                this.deleteTarget = msg;
                              })
                          }
                        }
                      }
                      .alignItems(this.isSelfMessage(msg) ? HorizontalAlign.End : HorizontalAlign.Start)

                      if (!this.isSelfMessage(msg)) {
                        Blank()
                      }
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Top)
                  }
                  .width('100%')
                }
              }, (msg: PmMessageItem, index: number) =>
                `${this.isDark ? 'd' : 'l'}_pm_${msg.id}_${index}`
              )
            }
            .layoutWeight(1)
            .padding({ left: 14, right: 14, top: 6, bottom: 12 })
            .scrollBar(BarState.Auto)
          }

          Row({ space: 8 }) {
            Button(this.uploadingImage ? '传图...' : '图片')
              .fontSize(12)
              .height(38)
              .backgroundColor(getTheme(this.isDark).accentBg)
              .fontColor(getTheme(this.isDark).accent)
              .enabled(!this.uploadingImage && !this.sending)
              .onClick(() => {
                this.sendImage();
              })

            TextInput({
              placeholder: '输入私信内容...',
              text: this.draftText
            })
              .height(38)
              .fontSize(14)
              .fontColor(getTheme(this.isDark).textPrimary)
              .placeholderColor(getTheme(this.isDark).textMuted)
              .backgroundColor(getTheme(this.isDark).inputBg)
              .layoutWeight(1)
              .onChange((val: string) => {
                this.draftText = val;
              })
              .onSubmit(() => {
                this.sendText();
              })

            Button(this.sending ? '发送中' : '发送')
              .fontSize(12)
              .height(38)
              .backgroundColor(
                (this.sending || this.uploadingImage)
                  ? getTheme(this.isDark).disabledBtnBg
                  : getTheme(this.isDark).accentSolid
              )
              .fontColor(
                (this.sending || this.uploadingImage)
                  ? getTheme(this.isDark).disabledBtnText
                  : Color.White
              )
              .enabled(!this.sending && !this.uploadingImage)
              .onClick(() => {
                this.sendText();
              })
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 8, bottom: 12 })
          .backgroundColor(getTheme(this.isDark).tabBarBg)
        }
        .width('100%')
        .height('100%')
        .backgroundColor(getTheme(this.isDark).pageBg)

        if (this.deleteTarget !== null) {
          Column() {
            Column({ space: 12 }) {
              Text('删除私信')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(getTheme(this.isDark).textPrimary)
              Text('确认删除这条私信记录吗？')
                .fontSize(13)
                .fontColor(getTheme(this.isDark).textSecondary)
              Row({ space: 10 }) {
                Button('取消')
                  .fontSize(13)
                  .height(36)
                  .layoutWeight(1)
                  .backgroundColor(getTheme(this.isDark).surfaceMuted)
                  .fontColor(getTheme(this.isDark).textSecondary)
                  .onClick(() => {
                    this.deleteTarget = null;
                  })
                Button(this.deleting ? '删除中...' : '确认删除')
                  .fontSize(13)
                  .height(36)
                  .layoutWeight(1)
                  .backgroundColor(getTheme(this.isDark).dangerBg)
                  .fontColor(getTheme(this.isDark).dangerText)
                  .enabled(!this.deleting)
                  .onClick(() => {
                    this.confirmDeleteMessage();
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
            this.deleteTarget = null;
          })
        }

        if (this.showImageViewer) {
          ImageViewerOverlay({
            images: this.viewerImages,
            initialIndex: this.viewerIndex,
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
      const params = ctx.pathInfo.param as MessageChatRouteParams | undefined | null;
      if (params !== undefined && params !== null) {
        this.targetUid = params.uid === undefined ? 0 : params.uid;
        this.targetName = params.name === undefined ? '' : params.name;
        this.targetAvatarUrl = params.avatarUrl === undefined ? '' : params.avatarUrl;
      }
      this.bootstrap();
    })
    .onShown(() => {
      if (!this.bootstrapped) {
        return;
      }
      if (this.needLogin && CookieStore.getInstance().hasCookie()) {
        this.loadLatest(true);
      }
    })
    .onBackPressed(() => {
      if (this.showImageViewer) {
        this.showImageViewer = false;
        return true;
      }
      if (this.deleteTarget !== null) {
        this.deleteTarget = null;
        return true;
      }
      return false;
    })
  }
}
