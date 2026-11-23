import { safeAvatarInitial } from '../utils/AvatarUtils';
import { getTheme, KEY_IS_DARK } from '../utils/Theme';

/**
 * 首页版块卡片。支持“常用”置顶徽标及编辑排序模式下的置顶/上下移/置首操作。
 */
@Component
export struct ForumCard {
  @Prop name: string = '';
  @Prop info: string = '';
  @Prop todayPostNum: number = 0;
  @Prop avatarUrl: string = '';
  @Prop isPinned: boolean = false;
  @Prop editMode: boolean = false;
  @Prop canMoveUp: boolean = false;
  @Prop canMoveDown: boolean = false;
  onOpen: () => void = () => {
  };
  onTogglePin: () => void = () => {
  };
  onMoveUp: () => void = () => {
  };
  onMoveDown: () => void = () => {
  };
  onMoveTop: () => void = () => {
  };

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;
  @State avatarFailed: boolean = false;

  build() {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        if (this.avatarUrl.length > 0 && !this.avatarFailed) {
          Image(this.avatarUrl)
            .width(44)
            .height(44)
            .borderRadius(10)
            .objectFit(ImageFit.Cover)
            .onError(() => {
              this.avatarFailed = true;
            })
        } else {
          Text(safeAvatarInitial(this.name))
            .width(44)
            .height(44)
            .borderRadius(10)
            .backgroundColor(getTheme(this.isDark).accentBg)
            .fontColor(getTheme(this.isDark).accent)
            .fontSize(19)
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
        }

        Column({ space: 4 }) {
          Row({ space: 6 }) {
            Text(this.name)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(getTheme(this.isDark).textPrimary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            if (this.isPinned) {
              Text('常用')
                .fontSize(10)
                .fontColor(getTheme(this.isDark).accent)
                .backgroundColor(getTheme(this.isDark).accentBg)
                .borderRadius(4)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            }
            Text(`今日 ${this.todayPostNum}`)
              .fontSize(12)
              .fontColor(getTheme(this.isDark).accent)
          }
          .width('100%')

          if (this.info.length > 0) {
            Text(this.info)
              .fontSize(13)
              .fontColor(getTheme(this.isDark).textSecondary)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      if (this.editMode) {
        Row({ space: 8 }) {
          Button(this.isPinned ? '取消置顶' : '置顶常用')
            .fontSize(11)
            .height(28)
            .backgroundColor(
              this.isPinned ? getTheme(this.isDark).accentSolid : getTheme(this.isDark).accentBg
            )
            .fontColor(this.isPinned ? Color.White : getTheme(this.isDark).accent)
            .onClick(() => {
              this.onTogglePin();
            })

          Blank()

          Button('置首')
            .fontSize(11)
            .height(28)
            .backgroundColor(
              this.canMoveUp ? getTheme(this.isDark).surfaceMuted : getTheme(this.isDark).disabledBtnBg
            )
            .fontColor(
              this.canMoveUp ? getTheme(this.isDark).textPrimary : getTheme(this.isDark).disabledBtnText
            )
            .enabled(this.canMoveUp)
            .onClick(() => {
              this.onMoveTop();
            })

          Button('上移')
            .fontSize(11)
            .height(28)
            .backgroundColor(
              this.canMoveUp ? getTheme(this.isDark).surfaceMuted : getTheme(this.isDark).disabledBtnBg
            )
            .fontColor(
              this.canMoveUp ? getTheme(this.isDark).textPrimary : getTheme(this.isDark).disabledBtnText
            )
            .enabled(this.canMoveUp)
            .onClick(() => {
              this.onMoveUp();
            })

          Button('下移')
            .fontSize(11)
            .height(28)
            .backgroundColor(
              this.canMoveDown ? getTheme(this.isDark).surfaceMuted : getTheme(this.isDark).disabledBtnBg
            )
            .fontColor(
              this.canMoveDown ? getTheme(this.isDark).textPrimary : getTheme(this.isDark).disabledBtnText
            )
            .enabled(this.canMoveDown)
            .onClick(() => {
              this.onMoveDown();
            })
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(getTheme(this.isDark).cardBg)
    .borderRadius(12)
    .onClick(() => {
      if (!this.editMode) {
        this.onOpen();
      }
    })
  }
}
