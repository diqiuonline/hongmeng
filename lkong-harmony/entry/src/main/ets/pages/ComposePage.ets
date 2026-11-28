import { ApiError, ErrorKind, ThreadImageItem, UploadedImage } from '../model/Models';
import { LkongApi } from '../network/LkongApi';
import { CookieStore } from '../store/CookieStore';
import { DraftPrefs } from '../store/DraftPrefs';
import { DisplayPrefs } from '../store/DisplayPrefs';
import { EmotionPicker } from '../components/EmotionPicker';
import { AttachmentItem, ImageAttachmentBar } from '../components/ImageAttachmentBar';
import { ImageViewerOverlay } from '../components/ImageViewerOverlay';
import { PostCard } from '../components/PostCard';
import { StateView } from '../components/StateView';
import { extractImagesFromContent } from '../utils/ContentUtils';
import { pickImageUris, prepareAndUploadImage } from '../utils/ImageUploadUtils';
import {
  buildPostContentJson,
  formatEmotionToken,
  hasPublishableContent,
  parseEditablePostContent,
  removeLastTokenOrChar
} from '../utils/PostComposerUtils';
import {
  KEY_FORUM_REFRESH_FID,
  KEY_THREAD_REFRESH_LOU,
  KEY_THREAD_REFRESH_PID,
  KEY_THREAD_REFRESH_SEQ,
  KEY_THREAD_REFRESH_TID
} from '../utils/AppConfig';
import { AppNavigator, ComposeRouteParams, Routes, ThreadRouteParams } from '../utils/AppRouter';
import { getTheme, KEY_IS_DARK } from '../utils/Theme';
import { getHostContext, showToast } from '../utils/UiUtils';

const MAX_TITLE_LENGTH: number = 26;
const MAX_ATTACHMENTS: number = 9;

/**
 * 统一发布与编辑页：支持发新帖（mode='new'）、回复/引用回复（mode='reply'）与编辑自己的主楼/楼层（mode='edit'）。
 * 支持官方表情面板、系统相册选图压缩上传、实时预览看图与仅本机自动草稿缓存。
 */
@Component
export struct ComposePage {
  @State mode: string = 'reply';
  @State fid: number = 0;
  @State forumName: string = '';
  @State tid: number = 0;
  @State threadTitle: string = '';
  @State quotePid: string = '';
  @State quoteFloor: string = '';
  @State quoteAuthorName: string = '';
  @State quoteSummary: string = '';
  @State editPid: string = '';
  @State isPrimaryPost: boolean = false;

  @State loadingEdit: boolean = false;
  @State editLoadError: string = '';
  @State editLocked: boolean = false;

  @State titleText: string = '';
  @State contentText: string = '';
  @State attachments: AttachmentItem[] = [];
  @State showEmotionPicker: boolean = false;
  @State previewMode: boolean = false;
  @State previewJson: string = '';
  @State submitting: boolean = false;
  @State draftRestored: boolean = false;

  @State showImageViewer: boolean = false;
  @State viewerImages: ThreadImageItem[] = [];
  @State viewerIndex: number = 0;

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;

  private draftKey: string = '';
  private draftInitialized: boolean = false;
  private draftTimerId: number = -1;
  private uploadRunning: boolean = false;
  private submitted: boolean = false;
  private attachmentSeq: number = 0;
  private readyHandled: boolean = false;
  private bootstrapped: boolean = false;

  aboutToDisappear(): void {
    if (this.draftTimerId >= 0) {
      clearTimeout(this.draftTimerId);
      this.draftTimerId = -1;
    }
    if (this.draftInitialized && !this.submitted && this.mode !== 'edit') {
      this.saveDraftNow();
    }
  }

  private async bootstrap(): Promise<void> {
    const ctx = getHostContext(this.getUIContext());
    await CookieStore.getInstance().ensureInit(ctx);
    await DisplayPrefs.getInstance().ensureInit(ctx);
    await DraftPrefs.getInstance().ensureInit(ctx);
    this.bootstrapped = true;

    if (this.mode === 'edit') {
      await this.loadPostForEdit();
      return;
    }

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
      showToast(this.getUIContext(), '已恢复上次未发送的本地草稿');
    }
    this.draftInitialized = true;
  }

  private async loadPostForEdit(): Promise<void> {
    if (this.tid <= 0 || this.editPid.length === 0) {
      this.editLoadError = '无效的编辑帖子参数。';
      return;
    }
    this.loadingEdit = true;
    this.editLoadError = '';
    try {
      const post = await LkongApi.getInstance().getPostForEdit(this.tid, this.editPid);
      if (post.firstPid.length > 0) {
        this.isPrimaryPost = post.firstPid === this.editPid;
      }
      this.editLocked = post.isLocked;
      if (this.isPrimaryPost) {
        this.titleText = post.title.length > 0 ? post.title : this.threadTitle;
      }
      const parsed = parseEditablePostContent(post.content);
      this.contentText = parsed.text;
      const loadedItems: AttachmentItem[] = [];
      for (const img of parsed.images) {
        this.attachmentSeq = this.attachmentSeq + 1;
        loadedItems.push({
          localId: `edit_${this.attachmentSeq}`,
          localUri: '',
          status: 'done',
          errorText: '',
          key: img.key,
          width: img.width,
          height: img.height
        });
      }
      this.attachments = loadedItems;
      if (post.isLocked) {
        showToast(this.getUIContext(), '该楼层已被锁定，禁止编辑');
      }
    } catch (error) {
      this.editLoadError = error instanceof ApiError ? error.message : '加载原帖内容失败，请重试。';
    } finally {
      this.loadingEdit = false;
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
    if (this.mode === 'edit' || !this.draftInitialized || this.submitted) {
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
    if (this.mode === 'edit' || !this.draftInitialized || this.submitted || this.draftKey.length === 0) {
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
    showToast(this.getUIContext(), '已清空草稿');
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
      showToast(this.getUIContext(), '请先登录后再上传图片');
      AppNavigator.getInstance().push(Routes.LOGIN);
      return;
    }
    const remaining = MAX_ATTACHMENTS - this.attachments.length;
    if (remaining <= 0) {
      showToast(this.getUIContext(), `最多只能添加 ${MAX_ATTACHMENTS} 张图片`);
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
      showToast(this.getUIContext(), '打开相册失败，请稍后重试');
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
          showToast(this.getUIContext(), errMsg);
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

  private openPreviewImage(url: string): void {
    const images = extractImagesFromContent(this.previewJson, '预览', '我', '');
    let idx = 0;
    for (let i = 0; i < images.length; i++) {
      if (images[i].url === url) {
        idx = i;
        break;
      }
    }
    if (images.length === 0) {
      images.push({
        url: url,
        pid: '',
        floor: '预览',
        authorName: '我'
      });
    }
    this.viewerImages = images;
    this.viewerIndex = idx;
    this.showImageViewer = true;
  }

  private pageTitle(): string {
    if (this.mode === 'new') {
      return '发表新主题';
    }
    if (this.mode === 'edit') {
      return this.isPrimaryPost ? '编辑主楼主题' : '编辑回复';
    }
    if (this.quotePid.length > 0) {
      return this.quoteFloor.length > 0 ? `引用回复 ${this.quoteFloor} 楼` : '引用回复';
    }
    return '回复主题';
  }

  private needsTitleField(): boolean {
    return this.mode === 'new' || (this.mode === 'edit' && this.isPrimaryPost);
  }

  private notifyThreadRefresh(pid: string, lou: number): void {
    const prevSeq = AppStorage.get<number>(KEY_THREAD_REFRESH_SEQ);
    const nextSeq = (prevSeq === undefined ? 0 : prevSeq) + 1;
    AppStorage.setOrCreate(KEY_THREAD_REFRESH_TID, this.tid);
    AppStorage.setOrCreate(KEY_THREAD_REFRESH_PID, pid);
    AppStorage.setOrCreate(KEY_THREAD_REFRESH_LOU, lou);
    AppStorage.setOrCreate(KEY_THREAD_REFRESH_SEQ, nextSeq);
  }

  private async submit(): Promise<void> {
    if (this.submitting || this.loadingEdit) {
      return;
    }
    if (!CookieStore.getInstance().hasCookie()) {
      showToast(this.getUIContext(), '请先登录后再发表');
      AppNavigator.getInstance().push(Routes.LOGIN);
      return;
    }
    if (this.mode === 'edit' && this.editLocked) {
      showToast(this.getUIContext(), '该楼层已被锁定，无法保存编辑');
      return;
    }
    if (this.hasUploadingImages()) {
      showToast(this.getUIContext(), '图片仍在上传中，请稍候');
      return;
    }
    if (this.hasFailedImages()) {
      showToast(this.getUIContext(), '存在上传失败的图片，请重试或移除后再发布');
      return;
    }

    const trimmedTitle = this.titleText.trim();
    if (this.needsTitleField()) {
      if (this.mode === 'new' && this.fid <= 0) {
        showToast(this.getUIContext(), '无效的版块 ID');
        return;
      }
      if (trimmedTitle.length === 0) {
        showToast(this.getUIContext(), '请输入主题标题');
        return;
      }
      if (trimmedTitle.length > MAX_TITLE_LENGTH) {
        showToast(this.getUIContext(), `主题标题不能超过 ${MAX_TITLE_LENGTH} 字`);
        return;
      }
    }
    if (this.mode !== 'new' && this.tid <= 0) {
      showToast(this.getUIContext(), '无效的主题 ID');
      return;
    }

    const images = this.collectUploadedImages();
    if (!hasPublishableContent(this.contentText, images)) {
      showToast(this.getUIContext(), '请输入正文内容或添加图片');
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
        showToast(this.getUIContext(), '发帖成功');
        const nextParams: ThreadRouteParams = {
          tid: newTid,
          title: trimmedTitle
        };
        AppNavigator.getInstance().replace(Routes.THREAD, nextParams);
      } else if (this.mode === 'edit') {
        const ok = await LkongApi.getInstance().editPost(
          this.tid,
          this.editPid,
          contentJson,
          this.isPrimaryPost ? trimmedTitle : undefined
        );
        if (!ok) {
          showToast(this.getUIContext(), '编辑保存未生效，请稍后重试');
          return;
        }
        this.submitted = true;
        this.notifyThreadRefresh(this.editPid, 0);
        showToast(this.getUIContext(), '已保存修改');
        AppNavigator.getInstance().pop();
      } else {
        const replyPost = await LkongApi.getInstance().replyThread(this.tid, contentJson, this.quotePid);
        this.submitted = true;
        await DraftPrefs.getInstance().clearDraft(this.draftKey);
        const parsedLou = Number(replyPost.floor);
        this.notifyThreadRefresh(replyPost.pid, isNaN(parsedLou) ? 0 : parsedLou);
        showToast(this.getUIContext(), '回复成功');
        AppNavigator.getInstance().pop();
      }
    } catch (error) {
      if (error instanceof ApiError && error.kind === ErrorKind.AUTH) {
        showToast(this.getUIContext(), error.message);
        AppNavigator.getInstance().push(Routes.LOGIN);
      } else {
        const message = error instanceof ApiError ? error.message : '发送失败，请稍后重试。';
        showToast(this.getUIContext(), message);
      }
    } finally {
      this.submitting = false;
    }
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          Row({ space: 8 }) {
            Button('取消')
              .fontSize(12)
              .height(32)
              .backgroundColor(getTheme(this.isDark).surfaceMuted)
              .fontColor(getTheme(this.isDark).textPrimary)
              .onClick(() => {
                AppNavigator.getInstance().pop();
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
              .enabled(!this.loadingEdit && this.editLoadError.length === 0)
              .onClick(() => {
                this.togglePreview();
              })

            Button(this.submitting ? '提交中...' : (this.mode === 'edit' ? '保存' : '发表'))
              .fontSize(12)
              .height(32)
              .backgroundColor(
                (this.submitting || this.loadingEdit || this.editLocked || this.editLoadError.length > 0)
                  ? getTheme(this.isDark).disabledBtnBg
                  : getTheme(this.isDark).accentSolid
              )
              .fontColor(
                (this.submitting || this.loadingEdit || this.editLocked || this.editLoadError.length > 0)
                  ? getTheme(this.isDark).disabledBtnText
                  : Color.White
              )
              .enabled(!this.submitting && !this.loadingEdit && !this.editLocked && this.editLoadError.length === 0)
              .onClick(() => {
                this.submit();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 10 })

          if (this.loadingEdit) {
            Column() {
              LoadingProgress()
                .width(40)
                .height(40)
                .color(getTheme(this.isDark).accent)
              Text('正在加载原帖内容...')
                .fontSize(13)
                .fontColor(getTheme(this.isDark).textSecondary)
                .margin({ top: 8 })
            }
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else if (this.editLoadError.length > 0) {
            Column() {
              StateView({
                title: '加载失败',
                message: this.editLoadError,
                actionText: '重试',
                onAction: () => {
                  this.loadPostForEdit();
                }
              })
            }
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else if (this.previewMode) {
            Scroll() {
              Column({ space: 12 }) {
                if (this.needsTitleField()) {
                  Column({ space: 4 }) {
                    Text(this.titleText.trim().length > 0 ? this.titleText.trim() : '（未填写标题）')
                      .fontSize(17)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(getTheme(this.isDark).textPrimary)
                    if (this.mode === 'new' && this.forumName.length > 0) {
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
                  floor: this.needsTitleField() ? '' : '预览',
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
                  canEdit: false,
                  canRate: false,
                  canFavorite: false,
                  onImageClick: (url: string) => {
                    this.openPreviewImage(url);
                  }
                })
              }
              .padding({ left: 16, right: 16, bottom: 16 })
            }
            .layoutWeight(1)
          } else {
            Scroll() {
              Column({ space: 10 }) {
                if (this.needsTitleField()) {
                  Column({ space: 8 }) {
                    Row() {
                      Text(
                        this.mode === 'edit'
                          ? '修改主题标题'
                          : (this.forumName.length > 0 ? `发表至：${this.forumName}` : `版块 #${this.fid}`)
                      )
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
                    if (this.mode === 'edit') {
                      Text('正在编辑已有回复，提交后将立即更新楼层正文')
                        .fontSize(12)
                        .fontColor(getTheme(this.isDark).accent)
                    } else if (this.quotePid.length > 0) {
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
                    placeholder: this.mode === 'edit'
                      ? '修改正文内容…（可插入龙空表情或图片）'
                      : '输入正文内容…（可插入龙空表情或上传图片，仅本机暂存草稿）',
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

                  if (this.mode !== 'edit' && (this.draftRestored || this.hasAnyDraftContent())) {
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
      const params = ctx.pathInfo.param as ComposeRouteParams | undefined | null;
      if (params !== undefined && params !== null) {
        if (params.mode === 'new') {
          this.mode = 'new';
        } else if (params.mode === 'edit') {
          this.mode = 'edit';
        } else {
          this.mode = 'reply';
        }
        this.fid = params.fid === undefined ? 0 : params.fid;
        this.forumName = params.forumName === undefined ? '' : params.forumName;
        this.tid = params.tid === undefined ? 0 : params.tid;
        this.threadTitle = params.threadTitle === undefined ? '' : params.threadTitle;
        this.quotePid = params.quotePid === undefined ? '' : params.quotePid;
        this.quoteFloor = params.quoteFloor === undefined ? '' : params.quoteFloor;
        this.quoteAuthorName = params.quoteAuthorName === undefined ? '' : params.quoteAuthorName;
        this.quoteSummary = params.quoteSummary === undefined ? '' : params.quoteSummary;
        this.editPid = params.editPid === undefined ? '' : params.editPid;
        this.isPrimaryPost = params.isPrimaryPost === undefined ? false : params.isPrimaryPost;
      }
      if (this.mode === 'new') {
        this.draftKey = DraftPrefs.buildNewThreadDraftKey(this.fid);
      } else if (this.mode === 'reply') {
        this.draftKey = DraftPrefs.buildReplyDraftKey(this.tid, this.quotePid);
      } else {
        this.draftKey = '';
      }
      this.bootstrap();
    })
    .onShown(() => {
      if (!this.bootstrapped) {
        return;
      }
      if (this.mode === 'edit' && this.editLoadError.length > 0 && CookieStore.getInstance().hasCookie()) {
        this.loadPostForEdit();
      }
    })
    .onBackPressed(() => {
      if (this.showImageViewer) {
        this.showImageViewer = false;
        return true;
      }
      if (this.showEmotionPicker) {
        this.showEmotionPicker = false;
        return true;
      }
      if (this.previewMode) {
        this.previewMode = false;
        return true;
      }
      return false;
    })
  }
}
