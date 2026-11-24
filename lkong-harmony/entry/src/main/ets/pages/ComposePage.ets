import { promptAction, router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ApiError, ErrorKind, UploadedImage } from '../model/Models';
import { LkongApi } from '../network/LkongApi';
import { CookieStore } from '../store/CookieStore';
import { DraftPrefs } from '../store/DraftPrefs';
import { DisplayPrefs } from '../store/DisplayPrefs';
import { EmotionPicker } from '../components/EmotionPicker';
import { AttachmentItem, ImageAttachmentBar } from '../components/ImageAttachmentBar';
import { PostCard } from '../components/PostCard';
import { pickImageUris, prepareAndUploadImage } from '../utils/ImageUploadUtils';
import {
  buildPostContentJson,
  formatEmotionToken,
  hasPublishableContent,
  removeLastTokenOrChar
} from '../utils/PostComposerUtils';
import {
  KEY_FORUM_REFRESH_FID,
  KEY_THREAD_REFRESH_LOU,
  KEY_THREAD_REFRESH_PID,
  KEY_THREAD_REFRESH_SEQ,
  KEY_THREAD_REFRESH_TID
} from '../utils/AppConfig';
import { getTheme, KEY_IS_DARK } from '../utils/Theme';

const MAX_TITLE_LENGTH: number = 26;
const MAX_ATTACHMENTS: number = 9;

interface ComposeParams {
  mode?: string;
  fid?: number;
  forumName?: string;
  tid?: number;
  threadTitle?: string;
  quotePid?: string;
  quoteFloor?: string;
  quoteAuthorName?: string;
  quoteSummary?: string;
}

/**
 * 统一发布页：支持发新帖（mode='new'）、回复主题与引用回复楼层（mode='reply'）。
 * 支持官方表情面板、系统相册选图压缩上传、实时预览与仅本机自动草稿缓存。
 */
@Entry
@Component
struct ComposePage {
  @State mode: string = 'reply';
  @State fid: number = 0;
  @State forumName: string = '';
  @State tid: number = 0;
  @State threadTitle: string = '';
  @State quotePid: string = '';
  @State quoteFloor: string = '';
  @State quoteAuthorName: string = '';
  @State quoteSummary: string = '';

  @State titleText: string = '';
  @State contentText: string = '';
  @State attachments: AttachmentItem[] = [];
  @State showEmotionPicker: boolean = false;
  @State previewMode: boolean = false;
  @State previewJson: string = '';
  @State submitting: boolean = false;
  @State draftRestored: boolean = false;

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;

  private draftKey: string = '';
  private draftInitialized: boolean = false;
  private draftTimerId: number = -1;
  private uploadRunning: boolean = false;
  private submitted: boolean = false;
  private attachmentSeq: number = 0;

  onBackPress(): boolean {
    if (this.showEmotionPicker) {
      this.showEmotionPicker = false;
      return true;
    }
    if (this.previewMode) {
      this.previewMode = false;
      return true;
    }
    return false;
  }

  aboutToAppear(): void {
    const raw = router.getParams();
    if (raw !== undefined && raw !== null) {
      const params = raw as ComposeParams;
      this.mode = params.mode === 'new' ? 'new' : 'reply';
      this.fid = params.fid === undefined ? 0 : params.fid;
      this.forumName = params.forumName === undefined ? '' : params.forumName;
      this.tid = params.tid === undefined ? 0 : params.tid;
      this.threadTitle = params.threadTitle === undefined ? '' : params.threadTitle;
      this.quotePid = params.quotePid === undefined ? '' : params.quotePid;
      this.quoteFloor = params.quoteFloor === undefined ? '' : params.quoteFloor;
      this.quoteAuthorName = params.quoteAuthorName === undefined ? '' : params.quoteAuthorName;
      this.quoteSummary = params.quoteSummary === undefined ? '' : params.quoteSummary;
    }
    this.draftKey = this.mode === 'new'
      ? DraftPrefs.buildNewThreadDraftKey(this.fid)
      : DraftPrefs.buildReplyDraftKey(this.tid, this.quotePid);
    this.bootstrap();
  }

  aboutToDisappear(): void {
    if (this.draftTimerId >= 0) {
      clearTimeout(this.draftTimerId);
      this.draftTimerId = -1;
    }
    if (this.draftInitialized && !this.submitted) {
      this.saveDraftNow();
    }
  }

  private async bootstrap(): Promise<void> {
    const ctx = getContext(this) as common.Context;
    await CookieStore.getInstance().ensureInit(ctx);
    await DisplayPrefs.getInstance().ensureInit(ctx);
    await DraftPrefs.getInstance().ensureInit(ctx);
    const saved = await DraftPrefs.getInstance().getDraft(this.draftKey);
    if (saved !== null) {
      this.titleText = this.mode === 'new' ? saved.title : '';
      this.contentText = saved.content;
      const restoredItems: AttachmentItem[] = [];
      for (const img of saved.images) {
        this.attachmentSeq = this.attachmentSeq + 1;
        restoredItems.push({
          localId: `draft_${this.attachmentSeq}`,
          localUri: '',
          status: 'done',
          errorText: '',
          key: img.key,
          width: img.width,
          height: img.height
        });
      }
      this.attachments = restoredItems;
      this.draftRestored = true;
      this.showToast('已恢复上次未发送的本地草稿');
    }
    this.draftInitialized = true;
  }

  private showToast(message: string): void {
    try {
      promptAction.showToast({ message: message });
    } catch (error) {
      // 忽略页面退出等场景下的弹窗异常。
    }
  }

  private collectUploadedImages(): UploadedImage[] {
    const images: UploadedImage[] = [];
    for (const item of this.attachments) {
      if (item.status === 'done' && item.key.length > 0) {
        images.push({
          key: item.key,
          width: item.width,
          height: item.height
        });
      }
    }
    return images;
  }

  private scheduleDraftSave(): void {
    if (!this.draftInitialized || this.submitted) {
      return;
    }
    if (this.draftTimerId >= 0) {
      clearTimeout(this.draftTimerId);
    }
    this.draftTimerId = setTimeout(() => {
      this.draftTimerId = -1;
      this.saveDraftNow();
    }, 500);
  }

  private saveDraftNow(): void {
    if (!this.draftInitialized || this.submitted || this.draftKey.length === 0) {
      return;
    }
    DraftPrefs.getInstance().saveDraft(this.draftKey, {
      title: this.mode === 'new' ? this.titleText : '',
      content: this.contentText,
      images: this.collectUploadedImages(),
      updatedAt: Date.now()
    });
  }

  private async clearLocalDraft(): Promise<void> {
    this.titleText = '';
    this.contentText = '';
    this.attachments = [];
    this.draftRestored = false;
    this.previewJson = '';
    await DraftPrefs.getInstance().clearDraft(this.draftKey);
    this.showToast('已清空草稿');
  }

  private hasAnyDraftContent(): boolean {
    return this.titleText.trim().length > 0 || this.contentText.trim().length > 0 || this.attachments.length > 0;
  }

  private hasUploadingImages(): boolean {
    for (const item of this.attachments) {
      if (item.status === 'uploading') {
        return true;
      }
    }
    return false;
  }

  private hasFailedImages(): boolean {
    for (const item of this.attachments) {
      if (item.status === 'error') {
        return true;
      }
    }
    return false;
  }

  private async pickImages(): Promise<void> {
    if (!CookieStore.getInstance().hasCookie()) {
      this.showToast('请先登录后再上传图片');
      router.pushUrl({ url: 'pages/LoginPage' }).catch(() => {
      });
      return;
    }
    const remaining = MAX_ATTACHMENTS - this.attachments.length;
    if (remaining <= 0) {
      this.showToast(`最多只能添加 ${MAX_ATTACHMENTS} 张图片`);
      return;
    }
    try {
      const uris = await pickImageUris(remaining);
      if (uris.length === 0) {
        return;
      }
      const nextList: AttachmentItem[] = [];
      for (const existing of this.attachments) {
        nextList.push(existing);
      }
      for (const uri of uris) {
        if (nextList.length >= MAX_ATTACHMENTS) {
          break;
        }
        this.attachmentSeq = this.attachmentSeq + 1;
        nextList.push({
          localId: `img_${this.attachmentSeq}`,
          localUri: uri,
          status: 'uploading',
          errorText: '',
          key: '',
          width: 0,
          height: 0
        });
      }
      this.attachments = nextList;
      this.processUploadQueue();
    } catch (error) {
      this.showToast('打开相册失败，请稍后重试');
    }
  }

  private updateAttachmentItem(updated: AttachmentItem): void {
    const nextList: AttachmentItem[] = [];
    for (const item of this.attachments) {
      if (item.localId === updated.localId) {
        nextList.push(updated);
      } else {
        nextList.push(item);
      }
    }
    this.attachments = nextList;
  }

  private retryAttachment(localId: string): void {
    for (const item of this.attachments) {
      if (item.localId === localId && item.localUri.length > 0) {
        this.updateAttachmentItem({
          localId: item.localId,
          localUri: item.localUri,
          status: 'uploading',
          errorText: '',
          key: '',
          width: 0,
          height: 0
        });
        this.processUploadQueue();
        break;
      }
    }
  }

  private removeAttachment(localId: string): void {
    const nextList: AttachmentItem[] = [];
    for (const item of this.attachments) {
      if (item.localId !== localId) {
        nextList.push(item);
      }
    }
    this.attachments = nextList;
    this.scheduleDraftSave();
  }

  private findNextUploading(): AttachmentItem | null {
    for (const item of this.attachments) {
      if (item.status === 'uploading') {
        return item;
      }
    }
    return null;
  }

  private async processUploadQueue(): Promise<void> {
    if (this.uploadRunning) {
      return;
    }
    this.uploadRunning = true;
    try {
      while (true) {
        const target = this.findNextUploading();
        if (target === null) {
          break;
        }
        try {
          const uploaded = await prepareAndUploadImage(target.localUri);
          this.updateAttachmentItem({
            localId: target.localId,
            localUri: target.localUri,
            status: 'done',
            errorText: '',
            key: uploaded.key,
            width: uploaded.width,
            height: uploaded.height
          });
          this.scheduleDraftSave();
        } catch (error) {
          const errMsg = error instanceof ApiError ? error.message : '上传失败';
          this.updateAttachmentItem({
            localId: target.localId,
            localUri: target.localUri,
            status: 'error',
            errorText: errMsg,
            key: '',
            width: 0,
            height: 0
          });
          this.showToast(errMsg);
          if (error instanceof ApiError && error.kind === ErrorKind.AUTH) {
            break;
          }
        }
      }
    } finally {
      this.uploadRunning = false;
    }
  }

  private togglePreview(): void {
    if (!this.previewMode) {
      this.previewJson = buildPostContentJson(this.contentText, this.collectUploadedImages());
      this.showEmotionPicker = false;
      this.previewMode = true;
    } else {
      this.previewMode = false;
    }
  }

  private pageTitle(): string {
    if (this.mode === 'new') {
      return '发表新主题';
    }
    if (this.quotePid.length > 0) {
      return this.quoteFloor.length > 0 ? `引用回复 ${this.quoteFloor} 楼` : '引用回复';
    }
    return '回复主题';
  }

  private async submit(): Promise<void> {
    if (this.submitting) {
      return;
    }
    if (!CookieStore.getInstance().hasCookie()) {
      this.showToast('请先登录后再发表');
      router.pushUrl({ url: 'pages/LoginPage' }).catch(() => {
      });
      return;
    }
    if (this.hasUploadingImages()) {
      this.showToast('图片仍在上传中，请稍候');
      return;
    }
    if (this.hasFailedImages()) {
      this.showToast('存在上传失败的图片，请重试或移除后再发布');
      return;
    }

    const trimmedTitle = this.titleText.trim();
    if (this.mode === 'new') {
      if (this.fid <= 0) {
        this.showToast('无效的版块 ID');
        return;
      }
      if (trimmedTitle.length === 0) {
        this.showToast('请输入主题标题');
        return;
      }
      if (trimmedTitle.length > MAX_TITLE_LENGTH) {
        this.showToast(`主题标题不能超过 ${MAX_TITLE_LENGTH} 字`);
        return;
      }
    } else if (this.tid <= 0) {
      this.showToast('无效的主题 ID');
      return;
    }

    const images = this.collectUploadedImages();
    if (!hasPublishableContent(this.contentText, images)) {
      this.showToast('请输入正文内容或添加图片');
      return;
    }

    const contentJson = buildPostContentJson(this.contentText, images);
    this.submitting = true;
    try {
      if (this.mode === 'new') {
        const newTid = await LkongApi.getInstance().createThread(this.fid, trimmedTitle, contentJson);
        this.submitted = true;
        await DraftPrefs.getInstance().clearDraft(this.draftKey);
        AppStorage.setOrCreate(KEY_FORUM_REFRESH_FID, this.fid);
        this.showToast('发帖成功');
        router.replaceUrl({
          url: 'pages/ThreadPage',
          params: {
            tid: newTid,
            title: trimmedTitle
          }
        }).catch(() => {
        });
      } else {
        const replyPost = await LkongApi.getInstance().replyThread(this.tid, contentJson, this.quotePid);
        this.submitted = true;
        await DraftPrefs.getInstance().clearDraft(this.draftKey);
        const prevSeq = AppStorage.get<number>(KEY_THREAD_REFRESH_SEQ);
        const nextSeq = (prevSeq === undefined ? 0 : prevSeq) + 1;
        AppStorage.setOrCreate(KEY_THREAD_REFRESH_TID, this.tid);
        AppStorage.setOrCreate(KEY_THREAD_REFRESH_PID, replyPost.pid);
        const parsedLou = Number(replyPost.floor);
        AppStorage.setOrCreate(KEY_THREAD_REFRESH_LOU, isNaN(parsedLou) ? 0 : parsedLou);
        AppStorage.setOrCreate(KEY_THREAD_REFRESH_SEQ, nextSeq);
        this.showToast('回复成功');
        router.back();
      }
    } catch (error) {
      if (error instanceof ApiError && error.kind === ErrorKind.AUTH) {
        this.showToast(error.message);
        router.pushUrl({ url: 'pages/LoginPage' }).catch(() => {
        });
      } else {
        const message = error instanceof ApiError ? error.message : '发送失败，请稍后重试。';
        this.showToast(message);
      }
    } finally {
      this.submitting = false;
    }
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Button('取消')
          .fontSize(12)
          .height(32)
          .backgroundColor(getTheme(this.isDark).surfaceMuted)
          .fontColor(getTheme(this.isDark).textPrimary)
          .onClick(() => {
            router.back();
          })

        Text(this.pageTitle())
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(getTheme(this.isDark).textPrimary)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Button(this.previewMode ? '继续编辑' : '预览')
          .fontSize(12)
          .height(32)
          .backgroundColor(
            this.previewMode ? getTheme(this.isDark).accentSolid : getTheme(this.isDark).accentBg
          )
          .fontColor(this.previewMode ? Color.White : getTheme(this.isDark).accent)
          .onClick(() => {
            this.togglePreview();
          })

        Button(this.submitting ? '发送中...' : '发表')
          .fontSize(12)
          .height(32)
          .backgroundColor(
            this.submitting ? getTheme(this.isDark).disabledBtnBg : getTheme(this.isDark).accentSolid
          )
          .fontColor(this.submitting ? getTheme(this.isDark).disabledBtnText : Color.White)
          .enabled(!this.submitting)
          .onClick(() => {
            this.submit();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 10 })

      if (this.previewMode) {
        Scroll() {
          Column({ space: 12 }) {
            if (this.mode === 'new') {
              Column({ space: 4 }) {
                Text(this.titleText.trim().length > 0 ? this.titleText.trim() : '（未填写标题）')
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(getTheme(this.isDark).textPrimary)
                if (this.forumName.length > 0) {
                  Text(`发表至：${this.forumName}`)
                    .fontSize(12)
                    .fontColor(getTheme(this.isDark).textSecondary)
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor(getTheme(this.isDark).cardBg)
              .borderRadius(12)
              .alignItems(HorizontalAlign.Start)
            }

            PostCard({
              pid: '',
              floor: this.mode === 'new' ? '' : '预览',
              authorName: '效果预览',
              authorId: 0,
              postTime: '刚刚',
              contentHtml: this.previewJson,
              isAuthor: false,
              quotePid: this.quotePid,
              quoteStatus: '',
              quoteAuthorId: 0,
              quoteAuthorName: this.quoteAuthorName,
              quoteContentHtml: this.quoteSummary,
              canReply: false,
              canRate: false,
              canFavorite: false
            })
          }
          .padding({ left: 16, right: 16, bottom: 16 })
        }
        .layoutWeight(1)
      } else {
        Scroll() {
          Column({ space: 10 }) {
            if (this.mode === 'new') {
              Column({ space: 8 }) {
                Row() {
                  Text(this.forumName.length > 0 ? `发表至：${this.forumName}` : `版块 #${this.fid}`)
                    .fontSize(12)
                    .fontColor(getTheme(this.isDark).textSecondary)
                  Blank()
                  Text(`${this.titleText.length}/${MAX_TITLE_LENGTH}`)
                    .fontSize(12)
                    .fontColor(
                      this.titleText.length > MAX_TITLE_LENGTH
                        ? getTheme(this.isDark).dangerText
                        : getTheme(this.isDark).textMuted
                    )
                }
                .width('100%')

                TextInput({
                  placeholder: `在此输入主题（${MAX_TITLE_LENGTH} 字内）`,
                  text: this.titleText
                })
                  .height(42)
                  .fontSize(15)
                  .maxLength(MAX_TITLE_LENGTH)
                  .fontColor(getTheme(this.isDark).textPrimary)
                  .placeholderColor(getTheme(this.isDark).textMuted)
                  .backgroundColor(getTheme(this.isDark).inputBg)
                  .onChange((val: string) => {
                    this.titleText = val;
                    this.scheduleDraftSave();
                  })
              }
              .width('100%')
              .padding(12)
              .backgroundColor(getTheme(this.isDark).cardBg)
              .borderRadius(12)
              .alignItems(HorizontalAlign.Start)
            } else {
              Column({ space: 6 }) {
                if (this.threadTitle.length > 0) {
                  Text(this.threadTitle)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(getTheme(this.isDark).textPrimary)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                if (this.quotePid.length > 0) {
                  Column({ space: 3 }) {
                    Text(
                      this.quoteAuthorName.length > 0
                        ? `引用 ${this.quoteFloor.length > 0 ? `${this.quoteFloor} 楼 ` : ''}@${this.quoteAuthorName}`
                        : '引用回复楼层'
                    )
                      .fontSize(12)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(getTheme(this.isDark).accent)
                    if (this.quoteSummary.length > 0) {
                      Text(this.quoteSummary)
                        .fontSize(12)
                        .fontColor(getTheme(this.isDark).textSecondary)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                  }
                  .width('100%')
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .backgroundColor(getTheme(this.isDark).quoteBg)
                  .border({ width: { left: 3 }, color: getTheme(this.isDark).quoteBorder })
                  .borderRadius(6)
                  .alignItems(HorizontalAlign.Start)
                }
              }
              .width('100%')
              .padding(12)
              .backgroundColor(getTheme(this.isDark).cardBg)
              .borderRadius(12)
              .alignItems(HorizontalAlign.Start)
            }

            Column({ space: 6 }) {
              TextArea({
                placeholder: '输入正文内容…（可插入龙空表情或上传图片，仅本机暂存草稿）',
                text: this.contentText
              })
                .width('100%')
                .height(this.showEmotionPicker ? 160 : 240)
                .fontSize(15)
                .fontColor(getTheme(this.isDark).textPrimary)
                .placeholderColor(getTheme(this.isDark).textMuted)
                .backgroundColor(getTheme(this.isDark).inputBg)
                .onChange((val: string) => {
                  this.contentText = val;
                  this.scheduleDraftSave();
                })

              if (this.draftRestored || this.hasAnyDraftContent()) {
                Row({ space: 8 }) {
                  Text('本机自动暂存草稿')
                    .fontSize(11)
                    .fontColor(getTheme(this.isDark).textMuted)
                  Blank()
                  if (this.hasAnyDraftContent()) {
                    Text('清空草稿')
                      .fontSize(11)
                      .fontColor(getTheme(this.isDark).dangerText)
                      .onClick(() => {
                        this.clearLocalDraft();
                      })
                  }
                }
                .width('100%')
              }
            }
            .width('100%')
            .padding(12)
            .backgroundColor(getTheme(this.isDark).cardBg)
            .borderRadius(12)

            ImageAttachmentBar({
              items: this.attachments,
              onRetry: (localId: string) => {
                this.retryAttachment(localId);
              },
              onRemove: (localId: string) => {
                this.removeAttachment(localId);
              }
            })
          }
          .padding({ left: 16, right: 16, bottom: 12 })
        }
        .layoutWeight(1)

        Column({ space: 8 }) {
          Row({ space: 10 }) {
            Button(this.showEmotionPicker ? '收起表情' : '表情')
              .fontSize(12)
              .height(32)
              .backgroundColor(
                this.showEmotionPicker ? getTheme(this.isDark).accentSolid : getTheme(this.isDark).accentBg
              )
              .fontColor(this.showEmotionPicker ? Color.White : getTheme(this.isDark).accent)
              .onClick(() => {
                this.showEmotionPicker = !this.showEmotionPicker;
              })

            Button(`图片 (${this.attachments.length}/${MAX_ATTACHMENTS})`)
              .fontSize(12)
              .height(32)
              .backgroundColor(getTheme(this.isDark).accentBg)
              .fontColor(getTheme(this.isDark).accent)
              .enabled(this.attachments.length < MAX_ATTACHMENTS)
              .onClick(() => {
                this.pickImages();
              })

            Blank()

            Text('点击预览可看表情效果')
              .fontSize(11)
              .fontColor(getTheme(this.isDark).textMuted)
          }
          .width('100%')

          if (this.showEmotionPicker) {
            EmotionPicker({
              onSelect: (id: number) => {
                this.contentText = `${this.contentText}${formatEmotionToken(id)}`;
                this.scheduleDraftSave();
              },
              onBackspace: () => {
                this.contentText = removeLastTokenOrChar(this.contentText);
                this.scheduleDraftSave();
              }
            })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 12 })
        .backgroundColor(getTheme(this.isDark).tabBarBg)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(getTheme(this.isDark).pageBg)
  }
}
