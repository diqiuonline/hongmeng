import { LengthMetrics } from '@kit.ArkUI';
import { BlockKind, InlineKind, PostBlock, PostInline } from '../model/Models';
import { parsePostBlocks } from '../utils/ContentUtils';
import {
  FontSizePreset,
  getTheme,
  KEY_FONT_SIZE,
  KEY_IS_DARK,
  ThemePalette
} from '../utils/Theme';
import { PostImage } from './PostImage';

/**
 * 楼层卡片。将帖子 JSON/HTML 拆分为标题、段落、引用、代码块、分割线与图片块，
 * 文本、样式与行内表情使用 Text + Span/ImageSpan 混排，图片使用独立 Image 组件。
 */
@Component
export struct PostCard {
  @Prop floor: string = '';
  @Prop authorName: string = '';
  @Prop postTime: string = '';
  @Prop @Watch('onContentChange') contentHtml: string = '';
  @Prop isAuthor: boolean = false;
  onImageClick: (url: string) => void = () => {
  };
  onLinkClick: (url: string) => void = () => {
  };

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;
  @StorageProp(KEY_FONT_SIZE) bodyFontSize: number = FontSizePreset.STANDARD;
  @State blocks: PostBlock[] = [];

  aboutToAppear(): void {
    this.refreshBlocks();
  }

  onContentChange(): void {
    this.refreshBlocks();
  }

  private refreshBlocks(): void {
    this.blocks = parsePostBlocks(this.contentHtml);
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
          .fontColor(getTheme(this.isDark).textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
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
      }
      .width('100%')

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
