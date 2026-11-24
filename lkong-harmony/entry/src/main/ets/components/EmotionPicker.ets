import { EMOTION_GROUPS, EmotionGroup, emotionImageUrl } from '../utils/PostComposerUtils';
import { getTheme, KEY_IS_DARK } from '../utils/Theme';

/**
 * 龙空官方表情面板：完整收录官网 4 大表情分组，点选插入 [em{id}]。
 */
@Component
export struct EmotionPicker {
  @Prop activeGroupIndex: number = 0;
  onSelect: (id: number) => void = () => {
  };
  onBackspace: () => void = () => {
  };

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;
  @State selectedIndex: number = 0;

  aboutToAppear(): void {
    if (this.activeGroupIndex >= 0 && this.activeGroupIndex < EMOTION_GROUPS.length) {
      this.selectedIndex = this.activeGroupIndex;
    }
  }

  private currentGroup(): EmotionGroup {
    if (this.selectedIndex >= 0 && this.selectedIndex < EMOTION_GROUPS.length) {
      return EMOTION_GROUPS[this.selectedIndex];
    }
    return EMOTION_GROUPS[0];
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        ForEach(EMOTION_GROUPS, (group: EmotionGroup, index: number) => {
          Button(group.title)
            .fontSize(11)
            .height(28)
            .padding({ left: 10, right: 10 })
            .backgroundColor(
              this.selectedIndex === index
                ? getTheme(this.isDark).accentSolid
                : getTheme(this.isDark).surfaceMuted
            )
            .fontColor(
              this.selectedIndex === index
                ? Color.White
                : getTheme(this.isDark).textSecondary
            )
            .onClick(() => {
              this.selectedIndex = index;
            })
        }, (group: EmotionGroup, index: number) =>
          `${this.isDark ? 'd' : 'l'}_eg_${index}_${this.selectedIndex === index ? '1' : '0'}_${group.name}`
        )

        Blank()

        Button('退格')
          .fontSize(11)
          .height(28)
          .padding({ left: 10, right: 10 })
          .backgroundColor(getTheme(this.isDark).surfaceMuted)
          .fontColor(getTheme(this.isDark).textPrimary)
          .onClick(() => {
            this.onBackspace();
          })
      }
      .width('100%')

      Grid() {
        ForEach(this.currentGroup().ids, (id: number) => {
          GridItem() {
            Column() {
              Image(emotionImageUrl(id))
                .width(36)
                .height(36)
                .objectFit(ImageFit.Contain)
            }
            .width('100%')
            .height(44)
            .justifyContent(FlexAlign.Center)
            .borderRadius(6)
            .backgroundColor(getTheme(this.isDark).surfaceMuted)
            .onClick(() => {
              this.onSelect(id);
            })
          }
        }, (id: number) => `${this.isDark ? 'd' : 'l'}_em_${this.selectedIndex}_${id}`)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
      .columnsGap(6)
      .rowsGap(6)
      .width('100%')
      .height(190)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .padding(10)
    .backgroundColor(getTheme(this.isDark).cardBg)
    .borderRadius(12)
  }
}
