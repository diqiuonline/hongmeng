import { ChatMessage, MessageFeedback, UploadedAttachment } from '../model/ChatModels';
import { copyTextToClipboard } from '../utils/ClipboardUtils';
import { MarkdownView } from './MarkdownView';
import { SearchResultBar } from './SearchResultSheet';
import { ThinkingCard } from './ThinkingCard';

@Component
export struct MessageBubble {
  @ObjectLink message: ChatMessage;
  @StorageProp('bodyFontSize') bodyFontSize: number = 15;

  onCopyNotice: (msg: string) => void = () => {};
  onEditUserMessage: (msg: ChatMessage) => void = () => {};
  onRegenerate: (msg: ChatMessage) => void = () => {};
  onFeedback: (msg: ChatMessage, feedback: MessageFeedback) => void = () => {};
  onShareMessage: (msg: ChatMessage) => void = () => {};
  onSwitchBranch: (parentId: number | null, targetMessageId: number) => void = () => {};
  onOpenSourceUrl: (url: string, title: string) => void = () => {};
  onStreamingHeightChange: () => void = () => {};

  private lastObservedHeight: number = 0;

  private switchRelative(delta: number): void {
    const ids = this.message.branchInfo.siblingIds;
    if (ids.length <= 1) {
      return;
    }
    const nextPos = this.message.branchInfo.currentIndex - 1 + delta;
    if (nextPos >= 0 && nextPos < ids.length) {
      this.onSwitchBranch(this.message.parentId, ids[nextPos]);
    }
  }

  private handleCitationClick(citeIndex: number): void {
    const results = this.message.searchResults;
    for (const item of results) {
      if (item.citeIndex === citeIndex && item.url.length > 0) {
        this.onOpenSourceUrl(item.url, item.title);
        return;
      }
    }
    const fallbackIdx = citeIndex - 1;
    if (fallbackIdx >= 0 && fallbackIdx < results.length && results[fallbackIdx].url.length > 0) {
      this.onOpenSourceUrl(results[fallbackIdx].url, results[fallbackIdx].title);
      return;
    }
    this.onCopyNotice(`参考来源 [${citeIndex}]`);
  }

  @Builder
  private BranchSwitcherBuilder() {
    if (this.message.branchInfo.totalCount > 1) {
      Row({ space: 4 }) {
        Text('‹')
          .fontSize(15)
          .fontColor(
            this.message.branchInfo.currentIndex > 1 ? $r('app.color.text_primary') : $r('app.color.text_muted')
          )
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .onClick(() => {
            if (this.message.branchInfo.currentIndex > 1) {
              this.switchRelative(-1);
            }
          })

        Text(`${this.message.branchInfo.currentIndex}/${this.message.branchInfo.totalCount}`)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))

        Text('›')
          .fontSize(15)
          .fontColor(
            this.message.branchInfo.currentIndex < this.message.branchInfo.totalCount
              ? $r('app.color.text_primary')
              : $r('app.color.text_muted')
          )
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .onClick(() => {
            if (this.message.branchInfo.currentIndex < this.message.branchInfo.totalCount) {
              this.switchRelative(1);
            }
          })
      }
      .padding({ left: 2, right: 2 })
      .backgroundColor($r('app.color.bg_pill'))
      .borderRadius(12)
    }
  }

  @Builder
  private FileChipsBuilder(files: UploadedAttachment[]) {
    if (files.length > 0) {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.End }) {
        ForEach(files, (file: UploadedAttachment, idx: number) => {
          Row({ space: 6 }) {
            Text(file.isImage ? '🖼' : '📄')
              .fontSize(13)
            Text(file.fileName)
              .fontSize(12)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: 180 })
          }
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .margin({ left: 6, bottom: 6 })
          .backgroundColor($r('app.color.bg_surface'))
          .borderRadius(10)
          .border({ width: 1, color: $r('app.color.border_color') })
        }, (file: UploadedAttachment, idx: number) => `${idx}_${file.id}_${file.fileName}`)
      }
    }
  }

  build() {
    if (this.message.role === 'USER') {
      Column({ space: 6 }) {
        this.FileChipsBuilder(this.message.files);

        if (this.message.content.length > 0) {
          Column() {
            Text(this.message.content)
              .fontSize(this.bodyFontSize)
              .lineHeight(this.bodyFontSize + 7)
              .fontColor($r('app.color.text_primary'))
              .copyOption(CopyOptions.LocalDevice)
          }
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .backgroundColor($r('app.color.bg_user_bubble'))
          .borderRadius({ topLeft: 16, topRight: 4, bottomLeft: 16, bottomRight: 16 })
          .constraintSize({ maxWidth: '86%' })
        }

        Row({ space: 12 }) {
          this.BranchSwitcherBuilder();

          Text('复制')
            .fontSize(12)
            .fontColor($r('app.color.text_muted'))
            .padding({ top: 2, bottom: 2, left: 4, right: 4 })
            .onClick(() => {
              copyTextToClipboard(this.message.content).then((ok: boolean) => {
                if (ok) {
                  this.onCopyNotice('已复制提问内容');
                }
              });
            })

          Text('编辑')
            .fontSize(12)
            .fontColor($r('app.color.text_muted'))
            .padding({ top: 2, bottom: 2, left: 4, right: 4 })
            .onClick(() => {
              this.onEditUserMessage(this.message);
            })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.End)
    } else {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Stack() {
            Circle({ width: 22, height: 22 })
              .fill($r('app.color.accent_primary'))
            Text('D')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }

          Text('DeepSeek')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))

          if (this.message.isActiveStream) {
            LoadingProgress()
              .width(14)
              .height(14)
              .color($r('app.color.accent_primary'))
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.message.hasSearch || this.message.searchQueries.length > 0 || this.message.searchResults.length > 0) {
          SearchResultBar({
            queries: this.message.searchQueries,
            results: this.message.searchResults,
            isSearching: this.message.isActiveStream && this.message.searchResults.length === 0 &&
              this.message.content.length === 0,
            onOpenSource: (url: string, title: string): void => {
              this.onOpenSourceUrl(url, title);
            }
          })
        }

        if (this.message.thinkingContent.length > 0 ||
          (this.message.isActiveStream && this.message.content.length === 0 && this.message.thinkingElapsedSecs > 0)) {
          ThinkingCard({
            thinkingContent: this.message.thinkingContent,
            elapsedSecs: this.message.thinkingElapsedSecs,
            isThinkingActive: this.message.isActiveStream && this.message.content.length === 0,
            bodyFontSize: this.bodyFontSize
          })
        }

        if (this.message.content.length > 0) {
          MarkdownView({
            rawText: this.message.content,
            bodyFontSize: this.bodyFontSize,
            onCitationClick: (citeIdx: number): void => {
              this.handleCitationClick(citeIdx);
            },
            onLinkClick: (url: string): void => {
              this.onOpenSourceUrl(url, '网页链接');
            },
            onCopyNotice: (msg: string): void => {
              this.onCopyNotice(msg);
            }
          })
        } else if (
          this.message.isActiveStream &&
          this.message.thinkingContent.length === 0 &&
          !(this.message.hasSearch && this.message.searchResults.length === 0)
        ) {
          Row({ space: 6 }) {
            LoadingProgress()
              .width(16)
              .height(16)
              .color($r('app.color.accent_primary'))
            Text(this.message.stageText.length > 0 ? this.message.stageText : '正在思考与组织回复...')
              .fontSize(13)
              .fontColor($r('app.color.text_muted'))
          }
          .padding({ top: 4, bottom: 4 })
        }

        if (this.message.status === 'INCOMPLETE') {
          Text('已停止生成')
            .fontSize(11)
            .fontColor($r('app.color.text_muted'))
        } else if (this.message.status === 'ERROR') {
          Text('生成过程中断，可点击“重新生成”重试')
            .fontSize(12)
            .fontColor($r('app.color.danger_color'))
        }

        if (!this.message.isActiveStream) {
          Row({ space: 10 }) {
            this.BranchSwitcherBuilder();

            Text('复制')
              .fontSize(12)
              .fontColor($r('app.color.text_muted'))
              .padding({ left: 6, right: 6, top: 4, bottom: 4 })
              .onClick(() => {
                copyTextToClipboard(this.message.content).then((ok: boolean) => {
                  if (ok) {
                    this.onCopyNotice('已复制回答全文');
                  }
                });
              })

            Text('重新生成')
              .fontSize(12)
              .fontColor($r('app.color.text_muted'))
              .padding({ left: 6, right: 6, top: 4, bottom: 4 })
              .onClick(() => {
                this.onRegenerate(this.message);
              })

            Text(this.message.feedback === 'like' ? '👍 已赞' : '👍')
              .fontSize(12)
              .fontColor(
                this.message.feedback === 'like' ? $r('app.color.accent_primary') : $r('app.color.text_muted')
              )
              .padding({ left: 6, right: 6, top: 4, bottom: 4 })
              .onClick(() => {
                const next: MessageFeedback = this.message.feedback === 'like' ? 'none' : 'like';
                this.onFeedback(this.message, next);
              })

            Text(this.message.feedback === 'dislike' ? '👎' : '👎')
              .fontSize(12)
              .fontColor(
                this.message.feedback === 'dislike' ? $r('app.color.danger_color') : $r('app.color.text_muted')
              )
              .padding({ left: 6, right: 6, top: 4, bottom: 4 })
              .onClick(() => {
                const next: MessageFeedback = this.message.feedback === 'dislike' ? 'none' : 'dislike';
                this.onFeedback(this.message, next);
              })

            Text('分享')
              .fontSize(12)
              .fontColor($r('app.color.text_muted'))
              .padding({ left: 6, right: 6, top: 4, bottom: 4 })
              .onClick(() => {
                this.onShareMessage(this.message);
              })
          }
          .width('100%')
          .padding({ top: 2 })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .onAreaChange((_oldArea, newArea) => {
        const nextHeight = Number(newArea.height);
        if (!isNaN(nextHeight)) {
          if (this.message.isActiveStream && nextHeight > this.lastObservedHeight + 1) {
            this.lastObservedHeight = nextHeight;
            this.onStreamingHeightChange();
          } else {
            this.lastObservedHeight = nextHeight;
          }
        }
      })
    }
  }
}
