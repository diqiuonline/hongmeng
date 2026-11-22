import { getTheme, KEY_IS_DARK } from '../utils/Theme';

/**
 * 帖子正文图片块：保留原图纵横比、提供占位/加载失败点击重试，并支持点击全屏预览。
 */
@Component
export struct PostImage {
  @Prop @Watch('onUrlChange') url: string = '';
  @Prop altText: string = '';
  @Prop initialWidth: number = 0;
  @Prop initialHeight: number = 0;
  onPreview: (url: string) => void = () => {
  };

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;
  @State aspectRatioValue: number = 0;
  @State naturalWidth: number = 0;
  @State loaded: boolean = false;
  @State failed: boolean = false;
  @State retryTick: number = 0;

  aboutToAppear(): void {
    this.initDimensions();
  }

  onUrlChange(): void {
    this.loaded = false;
    this.failed = false;
    this.retryTick = 0;
    this.initDimensions();
  }

  private initDimensions(): void {
    if (this.initialWidth > 0 && this.initialHeight > 0) {
      this.naturalWidth = this.initialWidth;
      this.aspectRatioValue = clampRatio(this.initialWidth / this.initialHeight);
    } else {
      this.naturalWidth = 0;
      this.aspectRatioValue = 0;
    }
  }

  private buildSourceUrl(): string {
    if (this.retryTick === 0) {
      return this.url;
    }
    return this.url.includes('?') ? `${this.url}&_r=${this.retryTick}` : `${this.url}?_r=${this.retryTick}`;
  }

  private computeWidth(): Length {
    if (this.naturalWidth > 0 && this.naturalWidth < 260 && this.aspectRatioValue > 0) {
      return Math.max(64, Math.round(this.naturalWidth * 0.65));
    }
    return '100%';
  }

  private computeAspectRatio(): number {
    return this.aspectRatioValue > 0 ? this.aspectRatioValue : 1.6;
  }

  build() {
    if (this.failed) {
      Column({ space: 4 }) {
        Text(this.altText.length > 0 ? `图片加载失败（${this.altText}），点击重试` : '图片加载失败，点击重试')
          .fontSize(12)
          .fontColor(getTheme(this.isDark).textSecondary)
      }
      .width('100%')
      .padding(12)
      .backgroundColor(getTheme(this.isDark).surfaceMuted)
      .border({ width: 1, color: getTheme(this.isDark).divider })
      .borderRadius(8)
      .onClick(() => {
        this.failed = false;
        this.loaded = false;
        this.retryTick = this.retryTick + 1;
      })
    } else {
      Image(this.buildSourceUrl())
        .width(this.computeWidth())
        .aspectRatio(this.computeAspectRatio())
        .objectFit(ImageFit.Contain)
        .borderRadius(8)
        .backgroundColor(this.loaded ? Color.Transparent : getTheme(this.isDark).surfaceMuted)
        .onComplete((event) => {
          if (event !== undefined && event.width > 0 && event.height > 0) {
            this.naturalWidth = event.width;
            this.aspectRatioValue = clampRatio(event.width / event.height);
            this.loaded = true;
          }
        })
        .onError(() => {
          this.failed = true;
        })
        .onClick(() => {
          this.onPreview(this.url);
        })
    }
  }
}

function clampRatio(ratio: number): number {
  if (!isFinite(ratio) || ratio <= 0) {
    return 1.6;
  }
  if (ratio < 0.3) {
    return 0.3;
  }
  if (ratio > 4.0) {
    return 4.0;
  }
  return ratio;
}
