import { promptAction, router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { CookieStore } from '../store/CookieStore';
import { DisplayPrefs } from '../store/DisplayPrefs';
import { LkongApi } from '../network/LkongApi';
import { AppConfig } from '../utils/AppConfig';
import {
  FontSizePreset,
  fontSizeLabel,
  getTheme,
  KEY_FONT_SIZE,
  KEY_IS_DARK,
  KEY_THEME_MODE,
  ThemeMode,
  themeModeLabel
} from '../utils/Theme';

const THEME_OPTIONS: string[] = [ThemeMode.SYSTEM, ThemeMode.LIGHT, ThemeMode.DARK];
const FONT_OPTIONS: number[] = [
  FontSizePreset.SMALL,
  FontSizePreset.STANDARD,
  FontSizePreset.LARGE,
  FontSizePreset.XLARGE
];

/**
 * 设置页集中展示显示阅读偏好、登录态、清除入口和访问约束，
 * 让“本机保存 Cookie”这件事对用户是可见、可撤销的。
 */
@Entry
@Component
struct SettingsPage {
  @State cookieSummary: string = '未登录';
  @StorageProp(KEY_IS_DARK) isDark: boolean = false;
  @StorageProp(KEY_THEME_MODE) themeMode: string = ThemeMode.SYSTEM;
  @StorageProp(KEY_FONT_SIZE) bodyFontSize: number = FontSizePreset.STANDARD;

  aboutToAppear(): void {
    this.init();
  }

  private showToast(message: string): void {
    try {
      promptAction.showToast({ message: message });
    } catch (error) {
      // 忽略页面退出等场景下的弹窗异常。
    }
  }

  private async init(): Promise<void> {
    const ctx = getContext(this) as common.Context;
    await CookieStore.getInstance().ensureInit(ctx);
    await DisplayPrefs.getInstance().ensureInit(ctx);
    this.cookieSummary = CookieStore.getInstance().maskSummary();
  }

  private async clearCookie(): Promise<void> {
    await CookieStore.getInstance().ensureInit(getContext(this) as common.Context);
    await CookieStore.getInstance().clearCookie();
    LkongApi.getInstance().clearCurrentUser();
    this.cookieSummary = CookieStore.getInstance().maskSummary();
    this.showToast('登录态已清除');
  }

  build() {
    Column() {
      Row() {
        Button('返回')
          .fontSize(12)
          .height(32)
          .backgroundColor(getTheme(this.isDark).accentBg)
          .fontColor(getTheme(this.isDark).accent)
          .margin({ right: 8 })
          .onClick(() => {
            router.back();
          })
        Text('设置')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(getTheme(this.isDark).textPrimary)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 10 }) {
            Text('显示与阅读')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(getTheme(this.isDark).textPrimary)

            Text('外观模式')
              .fontSize(12)
              .fontColor(getTheme(this.isDark).textSecondary)
            Row({ space: 8 }) {
              ForEach(THEME_OPTIONS, (mode: string) => {
                Button(themeModeLabel(mode))
                  .fontSize(12)
                  .height(32)
                  .layoutWeight(1)
                  .backgroundColor(
                    this.themeMode === mode
                      ? getTheme(this.isDark).accentSolid
                      : getTheme(this.isDark).surfaceMuted
                  )
                  .fontColor(
                    this.themeMode === mode
                      ? Color.White
                      : getTheme(this.isDark).textPrimary
                  )
                  .onClick(() => {
                    DisplayPrefs.getInstance().setThemeMode(getContext(this) as common.Context, mode);
                  })
              }, (mode: string) => `${this.isDark ? 'd' : 'l'}_${this.themeMode}_${mode}`)
            }
            .width('100%')

            Text(`正文字号（当前：${fontSizeLabel(this.bodyFontSize)} ${this.bodyFontSize}fp）`)
              .fontSize(12)
              .fontColor(getTheme(this.isDark).textSecondary)
              .margin({ top: 4 })
            Row({ space: 8 }) {
              ForEach(FONT_OPTIONS, (size: number) => {
                Button(fontSizeLabel(size))
                  .fontSize(12)
                  .height(32)
                  .layoutWeight(1)
                  .backgroundColor(
                    this.bodyFontSize === size
                      ? getTheme(this.isDark).accentSolid
                      : getTheme(this.isDark).surfaceMuted
                  )
                  .fontColor(
                    this.bodyFontSize === size
                      ? Color.White
                      : getTheme(this.isDark).textPrimary
                  )
                  .onClick(() => {
                    DisplayPrefs.getInstance().setFontSize(size);
                  })
              }, (size: number) => `${this.isDark ? 'd' : 'l'}_${this.bodyFontSize}_${size}`)
            }
            .width('100%')

            Column({ space: 4 }) {
              Text('正文效果预览')
                .fontSize(11)
                .fontColor(getTheme(this.isDark).textMuted)
              Text('在龙的天空看帖，深浅外观与字号会立即应用到所有楼层正文。')
                .fontSize(this.bodyFontSize)
                .lineHeight(Math.round(this.bodyFontSize * 1.5))
                .fontColor(getTheme(this.isDark).textPrimary)
            }
            .width('100%')
            .padding(10)
            .backgroundColor(getTheme(this.isDark).surfaceMuted)
            .borderRadius(8)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding(14)
          .backgroundColor(getTheme(this.isDark).cardBg)
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            Text('登录状态')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(getTheme(this.isDark).textPrimary)
            Text(this.cookieSummary)
              .fontSize(13)
              .fontColor(getTheme(this.isDark).textSecondary)
            Button('清除登录态')
              .fontSize(13)
              .height(34)
              .backgroundColor(getTheme(this.isDark).dangerBg)
              .fontColor(getTheme(this.isDark).dangerText)
              .onClick(() => {
                this.clearCookie();
              })
            Text(AppConfig.COOKIE_NOTICE)
              .fontSize(11)
              .fontColor(getTheme(this.isDark).textMuted)
              .lineHeight(17)
          }
          .width('100%')
          .padding(14)
          .backgroundColor(getTheme(this.isDark).cardBg)
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            Text('关于')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(getTheme(this.isDark).textPrimary)
            Text(`应用：${AppConfig.APP_NAME}`)
              .fontSize(13)
              .fontColor(getTheme(this.isDark).textSecondary)
            Text(`版本：${AppConfig.APP_VERSION}`)
              .fontSize(13)
              .fontColor(getTheme(this.isDark).textSecondary)
            Text(`数据来源：${AppConfig.API_URL}`)
              .fontSize(13)
              .fontColor(getTheme(this.isDark).textSecondary)
            Text(AppConfig.DISCLAIMER)
              .fontSize(12)
              .fontColor(getTheme(this.isDark).textMuted)
              .lineHeight(18)
          }
          .width('100%')
          .padding(14)
          .backgroundColor(getTheme(this.isDark).cardBg)
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            Text('安全与访问约束')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(getTheme(this.isDark).textPrimary)
            Text('• 不保存账号密码，密码仅用于本次登录请求。')
              .fontSize(12)
              .fontColor(getTheme(this.isDark).textSecondary)
            Text('• Cookie 仅保存在本机，GraphQL 请求发往 api.lkong.com，图片上传发往 images.lkong.com/upload（浏览图片与表情不携带 Cookie）。')
              .fontSize(12)
              .fontColor(getTheme(this.isDark).textSecondary)
            Text('• 请求串行并保持至少 800ms 间隔，不进行批量抓取。')
              .fontSize(12)
              .fontColor(getTheme(this.isDark).textSecondary)
            Text('• 只读取当前登录会话可见的页面数据，不绕过登录或权限校验。')
              .fontSize(12)
              .fontColor(getTheme(this.isDark).textSecondary)
          }
          .width('100%')
          .padding(14)
          .backgroundColor(getTheme(this.isDark).cardBg)
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)
        }
        .padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(getTheme(this.isDark).pageBg)
  }
}
