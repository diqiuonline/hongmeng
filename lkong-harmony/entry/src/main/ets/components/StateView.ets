import { getTheme, KEY_IS_DARK } from '../utils/Theme';

/**
 * 通用状态视图：加载失败、需要登录、空列表都复用它。
 */
@Component
export struct StateView {
  @Prop title: string = '';
  @Prop message: string = '';
  @Prop actionText: string = '';
  onAction: () => void = () => {
  };

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;

  build() {
    Column({ space: 12 }) {
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(getTheme(this.isDark).textPrimary)
      Text(this.message)
        .fontSize(14)
        .fontColor(getTheme(this.isDark).textSecondary)
        .textAlign(TextAlign.Center)
        .lineHeight(22)
      if (this.actionText.length > 0) {
        Button(this.actionText)
          .fontSize(14)
          .height(36)
          .backgroundColor(getTheme(this.isDark).accentSolid)
          .fontColor(Color.White)
          .onClick(() => {
            this.onAction();
          })
      }
    }
    .width('100%')
    .padding(24)
    .justifyContent(FlexAlign.Center)
  }
}
