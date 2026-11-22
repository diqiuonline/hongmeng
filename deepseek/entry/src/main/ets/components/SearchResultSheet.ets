import { SearchSource } from '../model/ChatModels';

@Component
export struct SearchResultBar {
  @Prop queries: string[] = [];
  @Prop results: SearchSource[] = [];
  @Prop isSearching: boolean = false;
  @State showSheet: boolean = false;
  onOpenSource: (url: string, title: string) => void = () => {};

  @Builder
  private SourcesSheetBuilder() {
    Column() {
      Row() {
        Text(`联网搜索参考来源（${this.results.length}）`)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('关闭')
          .fontSize(14)
          .fontColor($r('app.color.accent_primary'))
          .padding({ left: 12, top: 6, bottom: 6 })
          .onClick(() => {
            this.showSheet = false;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 10 })

      if (this.queries.length > 0) {
        Row({ space: 6 }) {
          Text('关键词:')
            .fontSize(12)
            .fontColor($r('app.color.text_muted'))
          Text(this.queries.join(' · '))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 10 })
      }

      List({ space: 10 }) {
        ForEach(this.results, (item: SearchSource, idx: number) => {
          ListItem() {
            Column({ space: 4 }) {
              Row({ space: 6 }) {
                Text(`${item.citeIndex > 0 ? item.citeIndex : idx + 1}`)
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.accent_primary'))
                  .backgroundColor($r('app.color.bg_pill_active'))
                  .borderRadius(10)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })

                Text(item.siteName.length > 0 ? item.siteName : '网页来源')
                  .fontSize(12)
                  .fontColor($r('app.color.text_muted'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
              }
              .width('100%')

              Text(item.title)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              if (item.snippet.length > 0) {
                Text(item.snippet)
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(3)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .lineHeight(18)
              }
            }
            .width('100%')
            .padding(12)
            .backgroundColor($r('app.color.bg_surface'))
            .borderRadius(10)
            .border({ width: 1, color: $r('app.color.border_color') })
            .alignItems(HorizontalAlign.Start)
            .onClick(() => {
              if (item.url.length > 0) {
                this.showSheet = false;
                this.onOpenSource(item.url, item.title);
              }
            })
          }
        }, (item: SearchSource, idx: number) => `${idx}_${item.url}`)
      }
      .layoutWeight(1)
      .padding({ left: 16, right: 16, bottom: 16 })
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }

  private pillLabel(): string {
    if (this.isSearching && this.results.length === 0) {
      if (this.queries.length > 0) {
        return `正在搜索：${this.queries[0]}`;
      }
      return '正在联网搜索...';
    }
    if (this.results.length > 0) {
      return `已搜索到 ${this.results.length} 个网页 ›`;
    }
    return `已联网搜索（${this.queries.join('、')}）`;
  }

  build() {
    Row({ space: 6 }) {
      if (this.isSearching && this.results.length === 0) {
        LoadingProgress()
          .width(13)
          .height(13)
          .color($r('app.color.accent_primary'))
      } else {
        Text('🌐')
          .fontSize(12)
      }

      Text(this.pillLabel())
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .padding({ left: 10, right: 12, top: 6, bottom: 6 })
    .backgroundColor($r('app.color.bg_pill'))
    .borderRadius(14)
    .onClick(() => {
      if (this.results.length > 0) {
        this.showSheet = true;
      }
    })
    .bindSheet($$this.showSheet, this.SourcesSheetBuilder(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      showClose: false
    })
  }
}
