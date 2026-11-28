import { ApiError, ThreadImageItem } from '../model/Models';
import { saveImageUrlToGallery } from '../utils/ImageSaveUtils';
import { getHostContext, showToast } from '../utils/UiUtils';

/**
 * 全屏多图看图器：支持 Swiper 左右切图、双指捏合缩放、双击放大/复位、放大拖移与 SaveButton 免权限保存相册。
 */
@Component
export struct ImageViewerOverlay {
  @Prop images: ThreadImageItem[] = [];
  @Prop @Watch('onInitialIndexChange') initialIndex: number = 0;
  onClose: () => void = () => {
  };

  @State currentIndex: number = 0;
  @State scaleValue: number = 1;
  @State pinchBaseScale: number = 1;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @State panBaseX: number = 0;
  @State panBaseY: number = 0;
  @State saving: boolean = false;
  @State showControls: boolean = true;

  private swiperController: SwiperController = new SwiperController();

  aboutToAppear(): void {
    this.syncInitialIndex();
  }

  onInitialIndexChange(): void {
    this.syncInitialIndex();
  }

  private syncInitialIndex(): void {
    if (this.images.length === 0) {
      this.currentIndex = 0;
    } else {
      const clamped = Math.max(0, Math.min(this.initialIndex, this.images.length - 1));
      this.currentIndex = clamped;
    }
    this.resetTransform();
    this.showControls = true;
  }

  private resetTransform(): void {
    this.scaleValue = 1;
    this.pinchBaseScale = 1;
    this.offsetX = 0;
    this.offsetY = 0;
    this.panBaseX = 0;
    this.panBaseY = 0;
  }

  private clampScale(value: number): number {
    if (!isFinite(value) || value < 1) {
      return 1;
    }
    if (value > 4) {
      return 4;
    }
    return value;
  }

  private clampOffset(value: number, scale: number): number {
    const limit = Math.max(0, (scale - 1) * 260);
    if (value < -limit) {
      return -limit;
    }
    if (value > limit) {
      return limit;
    }
    return value;
  }

  private currentMetaLabel(): string {
    if (this.images.length === 0 || this.currentIndex < 0 || this.currentIndex >= this.images.length) {
      return '';
    }
    const current = this.images[this.currentIndex];
    const parts: string[] = [`${this.currentIndex + 1} / ${this.images.length}`];
    if (current.floor.length > 0) {
      parts.push(current.floor);
    }
    if (current.authorName.length > 0) {
      parts.push(`@${current.authorName}`);
    }
    return parts.join(' · ');
  }

  private async saveCurrentImage(): Promise<void> {
    if (this.saving) {
      return;
    }
    if (this.images.length === 0 || this.currentIndex < 0 || this.currentIndex >= this.images.length) {
      return;
    }
    const targetUrl = this.images[this.currentIndex].url;
    if (targetUrl.length === 0) {
      return;
    }
    this.saving = true;
    try {
      await saveImageUrlToGallery(getHostContext(this.getUIContext()), targetUrl);
      showToast(this.getUIContext(), '已保存到系统相册');
    } catch (error) {
      const message = error instanceof ApiError ? error.message : '保存失败，请稍后重试。';
      showToast(this.getUIContext(), message);
    } finally {
      this.saving = false;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Swiper(this.swiperController) {
        ForEach(this.images, (item: ThreadImageItem, idx: number) => {
          Stack({ alignContent: Alignment.Center }) {
            Image(item.url)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
              .scale(
                idx === this.currentIndex
                  ? { x: this.scaleValue, y: this.scaleValue }
                  : { x: 1, y: 1 }
              )
              .translate(
                idx === this.currentIndex
                  ? { x: this.offsetX, y: this.offsetY }
                  : { x: 0, y: 0 }
              )
              .gesture(
                GestureGroup(
                  GestureMode.Exclusive,
                  TapGesture({ count: 2 })
                    .onAction(() => {
                      if (this.scaleValue > 1.05) {
                        this.resetTransform();
                      } else {
                        this.scaleValue = 2.5;
                        this.pinchBaseScale = 2.5;
                        this.offsetX = 0;
                        this.offsetY = 0;
                      }
                    }),
                  TapGesture({ count: 1 })
                    .onAction(() => {
                      if (this.scaleValue <= 1.05) {
                        this.onClose();
                      } else {
                        this.showControls = !this.showControls;
                      }
                    }),
                  PinchGesture({ fingers: 2 })
                    .onActionStart(() => {
                      this.pinchBaseScale = this.scaleValue;
                    })
                    .onActionUpdate((event: GestureEvent) => {
                      const nextScale = this.clampScale(this.pinchBaseScale * event.scale);
                      this.scaleValue = nextScale;
                      this.offsetX = this.clampOffset(this.offsetX, nextScale);
                      this.offsetY = this.clampOffset(this.offsetY, nextScale);
                    })
                    .onActionEnd(() => {
                      if (this.scaleValue < 1.05) {
                        this.resetTransform();
                      } else {
                        this.pinchBaseScale = this.scaleValue;
                      }
                    }),
                  PanGesture({ fingers: 1 })
                    .onActionStart(() => {
                      this.panBaseX = this.offsetX;
                      this.panBaseY = this.offsetY;
                    })
                    .onActionUpdate((event: GestureEvent) => {
                      if (this.scaleValue <= 1.05) {
                        return;
                      }
                      this.offsetX = this.clampOffset(this.panBaseX + event.offsetX, this.scaleValue);
                      this.offsetY = this.clampOffset(this.panBaseY + event.offsetY, this.scaleValue);
                    })
                )
              )
          }
          .width('100%')
          .height('100%')
          .padding({ left: 8, right: 8 })
        }, (item: ThreadImageItem, idx: number) => `${idx}_${item.pid}_${item.url}`)
      }
      .width('100%')
      .height('100%')
      .index(this.currentIndex)
      .loop(false)
      .indicator(false)
      .disableSwipe(this.scaleValue > 1.05)
      .onChange((idx: number) => {
        this.currentIndex = idx;
        this.resetTransform();
      })

      if (this.showControls) {
        Column() {
          Row({ space: 8 }) {
            Text(this.currentMetaLabel())
              .fontSize(13)
              .fontColor(Color.White)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            if (this.scaleValue > 1.05) {
              Button('复位')
                .fontSize(12)
                .height(30)
                .backgroundColor('#33FFFFFF')
                .fontColor(Color.White)
                .onClick(() => {
                  this.resetTransform();
                })
            }

            Button('关闭')
              .fontSize(12)
              .height(30)
              .backgroundColor('#33FFFFFF')
              .fontColor(Color.White)
              .onClick(() => {
                this.onClose();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 12 })
          .backgroundColor('#66000000')

          Blank()

          Row({ space: 12 }) {
            Text(this.saving ? '正在保存...' : '双指捏合/双击可缩放，左右滑切换')
              .fontSize(11)
              .fontColor('#CCFFFFFF')
              .layoutWeight(1)

            SaveButton({
              icon: SaveIconStyle.FULL_FILLED,
              text: SaveDescription.SAVE_IMAGE,
              buttonType: ButtonType.Capsule
            })
              .fontSize(13)
              .fontColor(Color.White)
              .iconColor(Color.White)
              .backgroundColor('#1A73E8')
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {
                if (result === SaveButtonOnClickResult.SUCCESS) {
                  this.saveCurrentImage();
                } else {
                  showToast(this.getUIContext(), '未获得相册保存授权，请重试');
                }
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 18 })
          .backgroundColor('#66000000')
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F0000000')
  }
}
