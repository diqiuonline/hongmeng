import { SettingsStore } from '../store/SettingsStore';

@Component
export struct ThinkingCard {
  @Prop thinkingContent: string = '';
  @Prop elapsedSecs: number = 0;
  @Prop isThinkingActive: boolean = false;
  @Prop bodyFontSize: number = 15;
  @State expanded: boolean = true;

  aboutToAppear(): void {
    if (!this.isThinkingActive && SettingsStore.getInstance().getAutoCollapseThinking()) {
      this.expanded = false;
    }
  }

  private headerLabel(): string {
    if (this.isThinkingActive) {
      if (this.elapsedSecs > 0) {
        return `深度思考中 (${Math.floor(this.elapsedSecs)}s)...`;
      }
      return '深度思考中...';
    }
    if (this.elapsedSecs > 0) {
      const rounded = Math.max(1, Math.round(this.elapsedSecs));
      return `已深度思考（用时 ${rounded} 秒）`;
    }
    return '已深度思考';
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        if (this.isThinkingActive) {
          LoadingProgress()
            .width(14)
            .height(14)
            .color($r('app.color.accent_primary'))
        } else {
          Text('✦')
            .fontSize(12)
            .fontColor($r('app.color.accent_primary'))
        }

        Text(this.headerLabel())
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))

        Blank()

        Text(this.expanded ? '收起 ▲' : '展开 ▼')
          .fontSize(12)
          .fontColor($r('app.color.text_muted'))
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 8, bottom: 8 })
      .backgroundColor($r('app.color.bg_thinking'))
      .borderRadius(10)
      .onClick(() => {
        this.expanded = !this.expanded;
      })

      if (this.expanded && this.thinkingContent.length > 0) {
        Row() {
          Column()
            .width(2)
            .backgroundColor($r('app.color.border_color'))
            .margin({ right: 10, top: 2, bottom: 2 })
            .alignSelf(ItemAlign.Stretch)

          Text(this.thinkingContent)
            .fontSize(Math.max(13, this.bodyFontSize - 1))
            .lineHeight(Math.max(20, this.bodyFontSize + 6))
            .fontColor($r('app.color.text_secondary'))
            .copyOption(CopyOptions.LocalDevice)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 6, right: 4, top: 8, bottom: 4 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
