import { Markdown, MarkdownController } from '@luvi/lv-markdown-in';
import { copyTextToClipboard } from '../utils/ClipboardUtils';

@Component
export struct MarkdownView {
  @Prop rawText: string = '';
  @Prop @Watch('onConfigChanged') bodyFontSize: number = 15;
  @StorageProp('isDarkMode') @Watch('onConfigChanged') isDarkMode: boolean = false;
  onCitationClick: (citeIndex: number) => void = () => {};
  onLinkClick: (url: string) => void = () => {};
  onCopyNotice: (msg: string) => void = () => {};

  private controller: MarkdownController = new MarkdownController();

  aboutToAppear(): void {
    this.setupController();
  }

  onConfigChanged(): void {
    this.applyThemeAndSize();
  }

  private setupController(): void {
    this.controller
      .setThreadRenderEnable(true)
      .setSetextHeadingEnable(false)
      .setHtmlPreviewEnable(false)
      .setMermaidEnable(false)
      .setTextSelectionEnable(true)
      .setCodeBlockBorderRadius(10)
      .setQuoteBorderRadius(6)
      .setQuoteBorderWidth(3)
      .setHyperlinkUnderlineState(false)
      .setTextSelectionCopyListener((copied: string): void => {
        copyTextToClipboard(copied).then((ok: boolean) => {
          if (ok) {
            this.onCopyNotice('已复制选中文本');
          }
        });
      })
      .setCodeCopyListener((codeText: string): void => {
        copyTextToClipboard(codeText).then((ok: boolean) => {
          if (ok) {
            this.onCopyNotice('已复制代码块');
          }
        });
      })
      .setTableCopyClickListener((tableMd: string): void => {
        copyTextToClipboard(tableMd).then((ok: boolean) => {
          if (ok) {
            this.onCopyNotice('已复制表格');
          }
        });
      })
      .setHyperlinkClickListener((_title: string, src: string): boolean => {
        if (src.startsWith('ds-cite://')) {
          const idx = Number(src.substring('ds-cite://'.length));
          if (!isNaN(idx) && idx > 0) {
            this.onCitationClick(idx);
          }
          return true;
        }
        if (src.startsWith('http://') || src.startsWith('https://')) {
          this.onLinkClick(src);
          return true;
        }
        return false;
      });

    this.applyThemeAndSize();
  }

  private applyThemeAndSize(): void {
    const base = this.bodyFontSize;
    this.controller
      .setTextSize(base)
      .setTextLineHeight(base + 9)
      .setTitleSize([base + 8, base + 5, base + 3, base + 1, base, base - 1])
      .setTitleLineHeight([base + 16, base + 12, base + 10, base + 8, base + 7, base + 6])
      .setTextColor($r('app.color.text_primary'))
      .setTitleColor($r('app.color.text_primary'))
      .setInlineCodeColor($r('app.color.accent_primary'))
      .setInlineCodeBackgroundColor($r('app.color.bg_pill'))
      .setQuoteTextColor($r('app.color.text_secondary'))
      .setQuoteBorderColor($r('app.color.accent_primary'))
      .setQuoteBackgroundColor($r('app.color.bg_thinking'))
      .setHyperlinkTextColor($r('app.color.accent_primary'))
      .setTableBackgroundColor($r('app.color.bg_surface'))
      .setTableTitleBackgroundColor($r('app.color.bg_thinking'))
      .setTableTitleTextColor($r('app.color.text_primary'))
      .setTableInterleaveBackgroundColor($r('app.color.bg_page'))
      .setTableOuterBorderColor($r('app.color.border_color'))
      .setTableInnerBorderColor($r('app.color.border_color'))
      .setLineColor($r('app.color.border_color'))
      .setCodeBlockTheme(this.isDarkMode ? 'dark' : 'light')
      .setLatexMathTextSize(base + 3)
      .setLatexMathTextColor(this.isDarkMode ? 0xFFECEEF4 : 0xFF1A1D24);
    this.controller.setTableNormalTextColor($r('app.color.text_primary'));
    this.controller.setTableInterleaveTextColor($r('app.color.text_primary'));
  }

  build() {
    Column() {
      Markdown({
        controller: this.controller,
        text: formatCitationsForMarkdown(this.rawText)
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/**
 * 将 DeepSeek 的 [citation:N] 标记转换为可点击的 Markdown 链接 [[N]](ds-cite://N)，
 * 并跳过 ``` 代码围栏内部内容，防止示例代码被误改写。
 */
export function formatCitationsForMarkdown(raw: string): string {
  if (!raw.includes('[citation:')) {
    return raw;
  }
  const lines = raw.split('\n');
  let inFence = false;
  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trimStart();
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      inFence = !inFence;
      continue;
    }
    if (!inFence && lines[i].includes('[citation:')) {
      lines[i] = lines[i].replace(/\[citation:\s*(\d+)\]/gi, '[[$1]](ds-cite://$1)');
    }
  }
  return lines.join('\n');
}
