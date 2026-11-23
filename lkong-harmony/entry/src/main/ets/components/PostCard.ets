import { LengthMetrics } from '@kit.ArkUI';
import { BlockKind, InlineKind, PostBlock, PostInline } from '../model/Models';
import { parsePostBlocks, renderPostContent } from '../utils/ContentUtils';
import {
  FontSizePreset,
  getTheme,
  KEY_FONT_SIZE,
  KEY_IS_DARK,
  ThemePalette
} from '../utils/Theme';
import { PostImage } from './PostImage';

/**
 * 楼层卡片。支持富文本、行内表情、自适应图片、引用楼层展示、点击作者进资料页与单楼层收藏。
 */
@Component
export struct PostCard {
  @Prop pid: string = '';
  @Prop floor: string = '';
  @Prop authorName: string = '';
  @Prop authorId: number = 0;
  @Prop postTime: string = '';
  @Prop @Watch('onContentChange') contentHtml: string = '';
  @Prop isAuthor: boolean = false;
  @Prop quotePid: string = '';
  @Prop quoteStatus: string = '';
  @Prop quoteAuthorId: number = 0;
  @Prop quoteAuthorName: string = '';
  @Prop @Watch('onQuoteChange') quoteContentHtml: string = '';
  onImageClick: (url: string) => void = () => {
  };
  onLinkClick: (url: string) => void = () => {
  };
  onAuthorClick: (uid: number, name: string) => void = () => {
  };
  onFavoriteClick: (pid: string, floor: string) => void = () => {
  };

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;
  @StorageProp(KEY_FONT_SIZE) bodyFontSize: number = FontSizePreset.STANDARD;
  @State blocks: PostBlock[] = [];
  @State quotePlainText: string = '';
  @State quoteExpanded: boolean = false;

  aboutToAppear(): void {
    this.refreshBlocks();
    this.refreshQuote();
  }

  onContentChange(): void {
    this.refreshBlocks();
  }

  onQuoteChange(): void {
    this.refreshQuote();
  }

  private refreshBlocks(): void {
    this.blocks = parsePostBlocks(this.contentHtml);
  }

  private refreshQuote(): void {
    this.quoteExpanded = false;
    if (this.quoteContentHtml.length === 0) {
      this.quotePlainText = '';
      return;
    }
    this.quotePlainText = renderPostContent(this.quoteContentHtml).trim();
  }

  private hasQuote(): boolean {
    return this.quotePid.length > 0 || this.quoteStatus.length > 0 || this.quoteContentHtml.length > 0;
  }

  private canToggleQuoteExpand(): boolean {
    return this.quotePlainText.length > 72 || this.quotePlainText.includes('\n');
  }

  private resolveDecoration(inline: PostInline): TextDecorationType {
    if (inline.href.length > 0 || inline.underline) {
      return TextDecorationType.Underline;
    }
    if (inline.strike) {
      return TextDecorationType.LineThrough;
    }
    return TextDecorationType.None;
  }

  @Builder
  private renderRichText(
    block: PostBlock,
    textColor: string,
    theme: ThemePalette,
    isHeading: boolean,
    isCodeBlock: boolean
  ) {
    Text() {
      ForEach(block.inlines, (inline: PostInline, iIdx: number) => {
        if (inline.kind === InlineKind.EMOTION && inline.url.length > 0) {
          ImageSpan(inline.url)
            .width(Math.round(this.bodyFontSize * 2.0))
            .height(Math.round(this.bodyFontSize * 2.0))
            .objectFit(ImageFit.Contain)
            .verticalAlign(ImageSpanAlignment.CENTER)
            .margin({ left: 2, right: 2 })
        } else {
          Span(inline.text)
            .fontSize(
              isHeading
                ? this.bodyFontSize + 2
                : (isCodeBlock || inline.code ? Math.max(12, this.bodyFontSize - 1) : this.bodyFontSize)
            )
            .fontColor(
              inline.href.length > 0
                ? theme.accent
                : (inline.code && !isCodeBlock ? theme.codeText : textColor)
            )
            .fontWeight((isHeading || inline.bold) ? FontWeight.Bold : FontWeight.Normal)
            .fontStyle(inline.italic ? FontStyle.Italic : FontStyle.Normal)
            .fontFamily((isCodeBlock || inline.code) ? 'monospace' : 'HarmonyOS Sans')
            .decoration({
              type: this.resolveDecoration(inline),
              color: inline.href.length > 0 ? theme.accent : textColor
            })
            .textBackgroundStyle({
              color: (inline.code && !isCodeBlock) ? theme.codeBg : Color.Transparent,
              radius: 4
            })
            .onClick(() => {
              if (inline.href.length > 0) {
                this.onLinkClick(inline.href);
              }
            })
        }
      }, (inline: PostInline, iIdx: number) =>
        `${this.isDark ? 'd' : 'l'}_${this.bodyFontSize}_${iIdx}_${inline.kind}_${inline.url}_${inline.href}_${inline.bold}_${inline.italic}_${inline.text.length}`
      )
    }
    .width('100%')
    .minLineHeight(LengthMetrics.vp(Math.round(this.bodyFontSize * 1.55)))
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(this.floor.length > 0 ? `${this.floor} 楼` : '楼主')
          .fontSize(12)
          .fontColor(getTheme(this.isDark).accent)
        Text(this.authorName.length > 0 ? this.authorName : '匿名用户')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(
            this.authorId > 0 ? getTheme(this.isDark).accent : getTheme(this.isDark).textPrimary
          )
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .onClick(() => {
            if (this.authorId > 0) {
              this.onAuthorClick(this.authorId, this.authorName);
            }
          })
        if (this.isAuthor) {
          Text('作者')
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor(getTheme(this.isDark).accentSolid)
            .borderRadius(3)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
        }
        Text(this.postTime)
          .fontSize(12)
          .fontColor(getTheme(this.isDark).textMuted)
        if (this.pid.length > 0) {
          Text('收藏')
            .fontSize(11)
            .fontColor(getTheme(this.isDark).accent)
            .backgroundColor(getTheme(this.isDark).accentBg)
            .borderRadius(4)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .onClick(() => {
              this.onFavoriteClick(this.pid, this.floor);
            })
        }
      }
      .width('100%')

      if (this.hasQuote()) {
        Column({ space: 4 }) {
          if (this.quoteStatus === 'removed') {
            Text('该引用楼层已被删除')
              .fontSize(Math.max(12, this.bodyFontSize - 2))
              .fontStyle(FontStyle.Italic)
              .fontColor(getTheme(this.isDark).textMuted)
          } else {
            Row({ space: 6 }) {
              Text(
                this.quoteAuthorName.length > 0
                  ? `回复 @${this.quoteAuthorName}`
                  : '引用楼层'
              )
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(
                  this.quoteAuthorId > 0
                    ? getTheme(this.isDark).accent
                    : getTheme(this.isDark).textSecondary
                )
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
                .onClick(() => {
                  if (this.quoteAuthorId > 0) {
                    this.onAuthorClick(this.quoteAuthorId, this.quoteAuthorName);
                  }
                })
            }
            .width('100%')

            Text(this.quotePlainText.length > 0 ? this.quotePlainText : '（无引用文本内容）')
              .width('100%')
              .fontSize(Math.max(12, this.bodyFontSize - 2))
              .lineHeight(Math.round(Math.max(12, this.bodyFontSize - 2) * 1.45))
              .fontColor(getTheme(this.isDark).textSecondary)
              .maxLines(this.quoteExpanded ? 100 : 3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            if (this.canToggleQuoteExpand()) {
              Text(this.quoteExpanded ? '收起引用' : '展开引用')
                .fontSize(11)
                .fontColor(getTheme(this.isDark).accent)
                .onClick(() => {
                  this.quoteExpanded = !this.quoteExpanded;
                })
            }
          }
        }
        .width('100%')
        .padding({ left: 10, right: 10, top: 8, bottom: 8 })
        .backgroundColor(getTheme(this.isDark).quoteBg)
        .border({ width: { left: 3 }, color: getTheme(this.isDark).quoteBorder })
        .borderRadius(6)
        .alignItems(HorizontalAlign.Start)
      }

      Column({ space: 8 }) {
        ForEach(this.blocks, (block: PostBlock, bIdx: number) => {
          if (block.kind === BlockKind.IMAGE) {
            PostImage({
              url: block.imageUrl,
              altText: block.imageAlt,
              initialWidth: block.imageWidth,
              initialHeight: block.imageHeight,
              onPreview: (url: string) => {
                this.onImageClick(url);
              }
            })
          } else if (block.kind === BlockKind.DIVIDER) {
            Divider()
              .color(getTheme(this.isDark).divider)
              .strokeWidth(1)
          } else if (block.kind === BlockKind.HEADING) {
            this.renderRichText(
              block,
              getTheme(this.isDark).textPrimary,
              getTheme(this.isDark),
              true,
              false
            )
          } else if (block.kind === BlockKind.CODE_BLOCK) {
            Column() {
              this.renderRichText(
                block,
                getTheme(this.isDark).textPrimary,
                getTheme(this.isDark),
                false,
                true
              )
            }
            .width('100%')
            .padding(10)
            .backgroundColor(getTheme(this.isDark).codeBlockBg)
            .border({ width: 1, color: getTheme(this.isDark).divider })
            .borderRadius(6)
            .alignItems(HorizontalAlign.Start)
          } else if (block.kind === BlockKind.QUOTE) {
            Column() {
              this.renderRichText(
                block,
                getTheme(this.isDark).textSecondary,
                getTheme(this.isDark),
                false,
                false
              )
            }
            .width('100%')
            .padding({ left: 10, top: 4, bottom: 4, right: 8 })
            .backgroundColor(getTheme(this.isDark).quoteBg)
            .border({ width: { left: 3 }, color: getTheme(this.isDark).quoteBorder })
            .borderRadius(4)
            .alignItems(HorizontalAlign.Start)
          } else {
            this.renderRichText(
              block,
              getTheme(this.isDark).textPrimary,
              getTheme(this.isDark),
              false,
              false
            )
          }
        }, (block: PostBlock, bIdx: number) =>
          block.kind === BlockKind.IMAGE
            ? `${bIdx}_img_${block.imageUrl}`
            : `${this.isDark ? 'd' : 'l'}_${this.bodyFontSize}_${bIdx}_${block.kind}_${block.inlines.length}`
        )
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(getTheme(this.isDark).cardBg)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }
}
