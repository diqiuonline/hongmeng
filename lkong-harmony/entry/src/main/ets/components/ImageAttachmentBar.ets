import { uploadedImageUrl } from '../utils/PostComposerUtils';
import { getTheme, KEY_IS_DARK } from '../utils/Theme';

export interface AttachmentItem {
  localId: string;
  localUri: string;
  status: string;
  errorText: string;
  key: string;
  width: number;
  height: number;
}

/**
 * 发帖/回帖图片附件条：展示缩略图、上传进度、失败重试与删除。
 */
@Component
export struct ImageAttachmentBar {
  @Prop items: AttachmentItem[] = [];
  onRetry: (localId: string) => void = () => {
  };
  onRemove: (localId: string) => void = () => {
  };

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;

  private previewSrc(item: AttachmentItem): string {
    if (item.localUri.length > 0) {
      return item.localUri;
    }
    if (item.key.length > 0) {
      return uploadedImageUrl(item.key);
    }
    return '';
  }

  build() {
    if (this.items.length > 0) {
      Column({ space: 6 }) {
        Row() {
          Text(`图片附件 (${this.items.length}/9)`)
            .fontSize(12)
            .fontColor(getTheme(this.isDark).textSecondary)
          Blank()
          Text('发送后图片附在正文末尾')
            .fontSize(11)
            .fontColor(getTheme(this.isDark).textMuted)
        }
        .width('100%')

        Scroll() {
          Row({ space: 10 }) {
            ForEach(this.items, (item: AttachmentItem) => {
              Stack({ alignContent: Alignment.TopEnd }) {
                Stack({ alignContent: Alignment.Center }) {
                  if (this.previewSrc(item).length > 0) {
                    Image(this.previewSrc(item))
                      .width(76)
                      .height(76)
                      .borderRadius(8)
                      .objectFit(ImageFit.Cover)
                  } else {
                    Column()
                      .width(76)
                      .height(76)
                      .borderRadius(8)
                      .backgroundColor(getTheme(this.isDark).surfaceMuted)
                  }

                  if (item.status === 'uploading') {
                    Column({ space: 4 }) {
                      LoadingProgress()
                        .width(24)
                        .height(24)
                        .color(Color.White)
                      Text('上传中')
                        .fontSize(10)
                        .fontColor(Color.White)
                    }
                    .width(76)
                    .height(76)
                    .borderRadius(8)
                    .backgroundColor('#80000000')
                    .justifyContent(FlexAlign.Center)
                  } else if (item.status === 'error') {
                    Column({ space: 2 }) {
                      Text('失败')
                        .fontSize(11)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Color.White)
                      Text('点此重试')
                        .fontSize(10)
                        .fontColor('#FFD56B')
                    }
                    .width(76)
                    .height(76)
                    .borderRadius(8)
                    .backgroundColor('#99000000')
                    .justifyContent(FlexAlign.Center)
                    .onClick(() => {
                      this.onRetry(item.localId);
                    })
                  }
                }
                .width(76)
                .height(76)

                Text('×')
                  .width(20)
                  .height(20)
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
                  .textAlign(TextAlign.Center)
                  .backgroundColor('#B3000000')
                  .borderRadius(10)
                  .margin({ top: 3, right: 3 })
                  .onClick(() => {
                    this.onRemove(item.localId);
                  })
              }
              .width(76)
              .height(76)
            }, (item: AttachmentItem) =>
              `${this.isDark ? 'd' : 'l'}_${item.localId}_${item.status}_${item.key}`
            )
          }
          .padding({ top: 2, bottom: 2 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      }
      .width('100%')
      .padding(12)
      .backgroundColor(getTheme(this.isDark).cardBg)
      .borderRadius(12)
      .alignItems(HorizontalAlign.Start)
    }
  }
}
