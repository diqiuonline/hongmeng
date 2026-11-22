import { getTheme, KEY_IS_DARK } from '../utils/Theme';

/**
 * 帖子列表行。只展示浏览所需信息，点击进入原生详情页。
 */
@Component
export struct ThreadRow {
  @Prop title: string = '';
  @Prop authorName: string = '';
  @Prop replyCount: number = 0;
  @Prop viewCount: number = 0;
  @Prop lastPostTime: string = '';
  @Prop isDigest: boolean = false;
  @Prop isTop: boolean = false;
  onOpen: () => void = () => {
  };

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;

  build() {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        if (this.isTop) {
          Text('置顶')
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#E53935')
            .borderRadius(3)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
        }
        if (this.isDigest) {
          Text('精华')
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor('#FB8C00')
            .borderRadius(3)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
        }
        Text(this.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(getTheme(this.isDark).textPrimary)
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row({ space: 12 }) {
        Text(this.authorName)
          .fontSize(12)
          .fontColor(getTheme(this.isDark).textSecondary)
        Text(`回复 ${this.replyCount}`)
          .fontSize(12)
          .fontColor(getTheme(this.isDark).textMuted)
        Text(`查看 ${this.viewCount}`)
          .fontSize(12)
          .fontColor(getTheme(this.isDark).textMuted)
        Blank()
        Text(this.lastPostTime)
          .fontSize(12)
          .fontColor(getTheme(this.isDark).textMuted)
      }
      .width('100%')
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
