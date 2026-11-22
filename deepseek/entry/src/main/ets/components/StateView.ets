@Component
export struct StateView {
  @Prop title: string = '';
  @Prop message: string = '';
  @Prop actionText: string = '';
  @Prop secondaryActionText: string = '';
  onAction: () => void = () => {};
  onSecondaryAction: () => void = () => {};

  build() {
    Column({ space: 12 }) {
      Text(this.title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)

      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
          .lineHeight(20)
      }

      if (this.actionText.length > 0 || this.secondaryActionText.length > 0) {
        Row({ space: 10 }) {
          if (this.actionText.length > 0) {
            Button(this.actionText)
              .fontSize(13)
              .height(36)
              .padding({ left: 18, right: 18 })
              .backgroundColor($r('app.color.accent_primary'))
              .fontColor(Color.White)
              .borderRadius(18)
              .onClick(() => {
                this.onAction();
              })
          }
          if (this.secondaryActionText.length > 0) {
            Button(this.secondaryActionText)
              .fontSize(13)
              .height(36)
              .padding({ left: 18, right: 18 })
              .backgroundColor($r('app.color.bg_pill'))
              .fontColor($r('app.color.text_primary'))
              .borderRadius(18)
              .onClick(() => {
                this.onSecondaryAction();
              })
          }
        }
        .margin({ top: 4 })
      }
    }
    .padding(24)
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
