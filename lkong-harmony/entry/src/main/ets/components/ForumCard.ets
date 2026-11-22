import { getTheme, KEY_IS_DARK } from '../utils/Theme';

/**
 * 首页版块卡片。头像加载失败时保留首字母占位，不阻塞整页。
 */
@Component
export struct ForumCard {
  @Prop name: string = '';
  @Prop info: string = '';
  @Prop todayPostNum: number = 0;
  @Prop avatarUrl: string = '';
  onOpen: () => void = () => {
  };

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;

  build() {
    Row({ space: 12 }) {
      if (this.avatarUrl.length > 0) {
        Image(this.avatarUrl)
          .width(48)
          .height(48)
          .borderRadius(10)
          .objectFit(ImageFit.Cover)
      } else {
        Text(this.name.substring(0, 1))
          .width(48)
          .height(48)
          .borderRadius(10)
          .backgroundColor(getTheme(this.isDark).accentBg)
          .fontColor(getTheme(this.isDark).accent)
          .fontSize(20)
          .textAlign(TextAlign.Center)
      }

      Column({ space: 4 }) {
        Row() {
          Text(this.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(getTheme(this.isDark).textPrimary)
            .layoutWeight(1)
          Text(`今日 ${this.todayPostNum}`)
            .fontSize(12)
            .fontColor(getTheme(this.isDark).accent)
        }
        .width('100%')

        Text(this.info)
          .fontSize(13)
          .fontColor(getTheme(this.isDark).textSecondary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(getTheme(this.isDark).cardBg)
    .borderRadius(12)
    .onClick(() => {
      this.onOpen();
    })
  }
}
