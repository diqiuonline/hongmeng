import { common } from '@kit.AbilityKit';
import { PickedLocalFile, UploadedAttachment } from '../model/ChatModels';
import {
  pickImageFromCamera,
  pickImagesFromGallery,
  pickLocalDocuments
} from './AttachmentPicker';

@Component
export struct ChatInputBar {
  @Link promptText: string;
  @Link thinkingEnabled: boolean;
  @Link searchEnabled: boolean;
  @Prop isStreaming: boolean = false;
  @Prop isEditing: boolean = false;
  @Prop pendingAttachments: UploadedAttachment[] = [];
  @State showAttachSheet: boolean = false;

  onSend: () => void = () => {};
  onStop: () => void = () => {};
  onCancelEdit: () => void = () => {};
  onFilesPicked: (files: PickedLocalFile[]) => void = () => {};
  onRemoveAttachment: (index: number) => void = () => {};
  onRetryAttachment: (index: number) => void = () => {};

  private getHostContext(): common.Context {
    return this.getUIContext().getHostContext() as common.Context;
  }

  private hasUploadingAttachments(): boolean {
    for (const item of this.pendingAttachments) {
      if (item.status === 'uploading' || item.status === 'parsing') {
        return true;
      }
    }
    return false;
  }

  private canSend(): boolean {
    if (this.isStreaming || this.hasUploadingAttachments()) {
      return false;
    }
    if (this.promptText.trim().length > 0) {
      return true;
    }
    for (const item of this.pendingAttachments) {
      if (item.status === 'ready') {
        return true;
      }
    }
    return false;
  }

  @Builder
  private AttachMenuSheetBuilder() {
    Column({ space: 12 }) {
      Text('添加附件或图片（OCR 识别）')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Row({ space: 12 }) {
        Column({ space: 8 }) {
          Text('📷')
            .fontSize(26)
          Text('拍照识图')
            .fontSize(13)
            .fontColor($r('app.color.text_primary'))
        }
        .layoutWeight(1)
        .padding({ top: 16, bottom: 16 })
        .backgroundColor($r('app.color.bg_surface'))
        .borderRadius(14)
        .border({ width: 1, color: $r('app.color.border_color') })
        .onClick(async () => {
          this.showAttachSheet = false;
          const picked = await pickImageFromCamera(this.getHostContext());
          if (picked !== null) {
            this.onFilesPicked([picked]);
          }
        })

        Column({ space: 8 }) {
          Text('🖼')
            .fontSize(26)
          Text('相册图片')
            .fontSize(13)
            .fontColor($r('app.color.text_primary'))
        }
        .layoutWeight(1)
        .padding({ top: 16, bottom: 16 })
        .backgroundColor($r('app.color.bg_surface'))
        .borderRadius(14)
        .border({ width: 1, color: $r('app.color.border_color') })
        .onClick(async () => {
          this.showAttachSheet = false;
          const list = await pickImagesFromGallery(this.getHostContext(), 5);
          if (list.length > 0) {
            this.onFilesPicked(list);
          }
        })

        Column({ space: 8 }) {
          Text('📄')
            .fontSize(26)
          Text('本地文档')
            .fontSize(13)
            .fontColor($r('app.color.text_primary'))
        }
        .layoutWeight(1)
        .padding({ top: 16, bottom: 16 })
        .backgroundColor($r('app.color.bg_surface'))
        .borderRadius(14)
        .border({ width: 1, color: $r('app.color.border_color') })
        .onClick(async () => {
          this.showAttachSheet = false;
          const list = await pickLocalDocuments(this.getHostContext(), 5);
          if (list.length > 0) {
            this.onFilesPicked(list);
          }
        })
      }
      .width('100%')

      Text('支持常见图片（拍照/相册 OCR）以及 PDF、Word、TXT、Markdown、代码文件')
        .fontSize(12)
        .fontColor($r('app.color.text_muted'))
        .width('100%')
    }
    .padding(16)
    .width('100%')
    .backgroundColor($r('app.color.bg_page'))
  }

  private attachmentStatusLabel(item: UploadedAttachment): string {
    if (item.status === 'uploading') {
      return '上传中...';
    }
    if (item.status === 'parsing') {
      return '解析识别中...';
    }
    if (item.status === 'error') {
      return '失败 · 点重试';
    }
    const kb = Math.max(1, Math.round(item.fileSize / 1024));
    return `${kb} KB · 已就绪`;
  }

  build() {
    Column({ space: 8 }) {
      if (this.isEditing) {
        Row({ space: 8 }) {
          Text('正在编辑历史提问，发送后将生成新分支')
            .fontSize(12)
            .fontColor($r('app.color.accent_primary'))
            .layoutWeight(1)
          Text('取消')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .onClick(() => {
              this.onCancelEdit();
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor($r('app.color.bg_pill_active'))
        .borderRadius(10)
      }


      if (this.pendingAttachments.length > 0) {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.pendingAttachments, (item: UploadedAttachment, index: number) => {
              Row({ space: 8 }) {
                if (item.status === 'uploading' || item.status === 'parsing') {
                  LoadingProgress()
                    .width(16)
                    .height(16)
                    .color($r('app.color.accent_primary'))
                } else {
                  Text(item.isImage ? '🖼' : '📄')
                    .fontSize(16)
                }

                Column({ space: 2 }) {
                  Text(item.fileName)
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .constraintSize({ maxWidth: 140 })

                  Text(this.attachmentStatusLabel(item))
                    .fontSize(11)
                    .fontColor(item.status === 'error' ? $r('app.color.danger_color') : $r('app.color.text_muted'))
                }
                .alignItems(HorizontalAlign.Start)
                .onClick(() => {
                  if (item.status === 'error') {
                    this.onRetryAttachment(index);
                  }
                })

                Text('✕')
                  .fontSize(13)
                  .fontColor($r('app.color.text_muted'))
                  .padding({ left: 4, right: 4, top: 4, bottom: 4 })
                  .onClick(() => {
                    this.onRemoveAttachment(index);
                  })
              }
              .padding({ left: 10, right: 8, top: 8, bottom: 8 })
              .backgroundColor($r('app.color.bg_surface'))
              .borderRadius(12)
              .border({
                width: 1,
                color: item.status === 'error' ? $r('app.color.danger_color') : $r('app.color.border_color')
              })
            }, (item: UploadedAttachment, index: number) => `${index}_${item.localUri}_${item.status}`)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      }

      Column({ space: 8 }) {
        TextArea({
          placeholder: '给 DeepSeek 发送消息',
          text: this.promptText
        })
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_muted'))
          .backgroundColor(Color.Transparent)
          .constraintSize({ minHeight: 40, maxHeight: 130 })
          .padding({ left: 4, right: 4, top: 4, bottom: 2 })
          .onChange((value: string) => {
            this.promptText = value;
          })

        Row({ space: 8 }) {
          Row({ space: 4 }) {
            Text('⚛')
              .fontSize(13)
              .fontColor(this.thinkingEnabled ? $r('app.color.accent_primary') : $r('app.color.text_secondary'))
            Text('深度思考')
              .fontSize(12)
              .fontWeight(this.thinkingEnabled ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.thinkingEnabled ? $r('app.color.accent_primary') : $r('app.color.text_secondary'))
          }
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(this.thinkingEnabled ? $r('app.color.bg_pill_active') : $r('app.color.bg_pill'))
          .borderRadius(16)
          .border({
            width: 1,
            color: this.thinkingEnabled ? $r('app.color.accent_primary') : $r('app.color.border_color')
          })
          .onClick(() => {
            this.thinkingEnabled = !this.thinkingEnabled;
          })

          Row({ space: 4 }) {
            Text('🌐')
              .fontSize(12)
            Text('智能搜索')
              .fontSize(12)
              .fontWeight(this.searchEnabled ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.searchEnabled ? $r('app.color.accent_primary') : $r('app.color.text_secondary'))
          }
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(this.searchEnabled ? $r('app.color.bg_pill_active') : $r('app.color.bg_pill'))
          .borderRadius(16)
          .border({
            width: 1,
            color: this.searchEnabled ? $r('app.color.accent_primary') : $r('app.color.border_color')
          })
          .onClick(() => {
            this.searchEnabled = !this.searchEnabled;
          })

          Blank()


          Button('＋')
            .fontSize(18)
            .width(34)
            .height(34)
            .padding(0)
            .backgroundColor($r('app.color.bg_pill'))
            .fontColor($r('app.color.text_primary'))
            .borderRadius(17)
            .onClick(() => {
              this.showAttachSheet = true;
            })
            .bindSheet($$this.showAttachSheet, this.AttachMenuSheetBuilder(), {
              height: 230,
              dragBar: true,
              showClose: false
            })

          if (this.isStreaming) {
            Button('■')
              .fontSize(13)
              .width(34)
              .height(34)
              .padding(0)
              .backgroundColor($r('app.color.accent_primary'))
              .fontColor(Color.White)
              .borderRadius(17)
              .onClick(() => {
                this.onStop();
              })
          } else {
            Button('↑')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .width(34)
              .height(34)
              .padding(0)
              .backgroundColor(this.canSend() ? $r('app.color.accent_primary') : $r('app.color.bg_pill'))
              .fontColor(this.canSend() ? Color.White : $r('app.color.text_muted'))
              .enabled(this.canSend())
              .borderRadius(17)
              .onClick(() => {
                this.onSend();
              })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 10 })
      .backgroundColor($r('app.color.bg_input'))
      .borderRadius(20)
      .border({ width: 1, color: $r('app.color.border_color') })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 6, bottom: 10 })
    .backgroundColor($r('app.color.bg_page'))
  }
}
