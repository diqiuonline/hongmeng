import { getTheme, KEY_IS_DARK } from '../utils/Theme';

/**
 * 帖子列表行。只展示浏览所需信息，支持点击作者进入资料页。
 */
@Component
export struct ThreadRow {
  @Prop title: string = '';
  @Prop authorName: string = '';
  @Prop authorId: number = 0;
  @Prop forumName: string = '';
  @Prop replyCount: number = 0;
  @Prop viewCount: number = 0;
  @Prop lastPostTime: string = '';
  @Prop isDigest: boolean = false;
  @Prop isTop: boolean = false;
  onOpen: () => void = () => {
  };
  onAuthorClick: (uid: number, name: string) => void = () => {
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

      Row({ space: 8 }) {
        Text(this.authorName.length > 0 ? this.authorName : '匿名用户')
          .fontSize(12)
          .fontColor(
            this.authorId > 0 ? getTheme(this.isDark).accent : getTheme(this.isDark).textSecondary
          )
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: 110 })
          .onClick(() => {
            if (this.authorId > 0) {
              this.onAuthorClick(this.authorId, this.authorName);
            }
          })
        if (this.forumName.length > 0) {
          Text(this.forumName)
            .fontSize(11)
            .fontColor(getTheme(this.isDark).textSecondary)
            .backgroundColor(getTheme(this.isDark).surfaceMuted)
            .borderRadius(4)
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: 90 })
        }
        Text(`回 ${this.replyCount}`)
          .fontSize(12)
          .fontColor(getTheme(this.isDark).textMuted)
        Text(`阅 ${this.viewCount}`)
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
