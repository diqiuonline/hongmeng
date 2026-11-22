import { common } from '@kit.AbilityKit';
import { ApiError } from '../model/ApiErrors';
import { FontSizeLevel, ThemeMode, UserProfile } from '../model/ChatModels';
import { DeepSeekApi } from '../network/DeepSeekApi';
import { AuthStore } from '../store/AuthStore';
import { SettingsStore } from '../store/SettingsStore';
import { AppConfig } from '../utils/AppConfig';

@Entry
@Component
struct SettingsPage {
  @State loggedIn: boolean = false;
  @State userProfile: UserProfile | null = null;
  @State authSummary: string = '未登录';
  @State themeMode: ThemeMode = 'system';
  @State fontSizeLevel: FontSizeLevel = 'standard';
  @State defaultThinking: boolean = true;
  @State defaultSearch: boolean = false;
  @State autoCollapseThinking: boolean = false;
  @State confirmClearAll: boolean = false;
  @State clearingAll: boolean = false;

  aboutToAppear(): void {
    this.syncState();
  }

  onPageShow(): void {
    this.syncState();
  }

  private async syncState(): Promise<void> {
    const ctx = this.getUIContext().getHostContext() as common.Context;
    await AuthStore.getInstance().ensureInit(ctx);
    await SettingsStore.getInstance().ensureInit(ctx);

    this.loggedIn = AuthStore.getInstance().hasAuth();
    this.userProfile = AuthStore.getInstance().getUserProfile();
    this.authSummary = AuthStore.getInstance().maskSummary();
    this.themeMode = SettingsStore.getInstance().getThemeMode();
    this.fontSizeLevel = SettingsStore.getInstance().getFontSizeLevel();
    this.defaultThinking = SettingsStore.getInstance().getDefaultThinking();
    this.defaultSearch = SettingsStore.getInstance().getDefaultSearch();
    this.autoCollapseThinking = SettingsStore.getInstance().getAutoCollapseThinking();
  }

  private showToast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg });
    } catch (err) {
      // 忽略。
    }
  }

  private goBack(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (err) {
      // 忽略。
    }
  }

  private openLogin(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' }).catch(() => {
    });
  }

  private openWebFallback(): void {
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/WebFallbackPage',
      params: {
        url: AppConfig.BASE_URL,
        title: 'DeepSeek 网页版（应急模式）',
        syncAuthOnExit: true
      }
    }).catch(() => {
    });
  }

  private async handleLogout(): Promise<void> {
    await AuthStore.getInstance().clearAuth();
    AppStorage.setOrCreate('needSessionReload', true);
    await this.syncState();
    this.showToast('已清除本地登录态');
  }

  private async handleClearAllSessions(): Promise<void> {
    if (this.clearingAll) {
      return;
    }
    this.clearingAll = true;
    try {
      await DeepSeekApi.getInstance().deleteAllSessions();
      AppStorage.setOrCreate('needSessionReload', true);
      this.showToast('已清空全部云端历史对话');
    } catch (error) {
      const msg = error instanceof ApiError ? error.message : '清空失败，请稍后重试。';
      this.showToast(msg);
    } finally {
      this.clearingAll = false;
      this.confirmClearAll = false;
    }
  }

  build() {
    Stack() {
      Column() {
        Row({ space: 8 }) {
          Button('‹ 返回')
            .fontSize(13)
            .height(32)
            .backgroundColor($r('app.color.bg_pill'))
            .fontColor($r('app.color.text_primary'))
            .onClick(() => {
              this.goBack();
            })

          Text('设置与账号')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .backgroundColor($r('app.color.bg_surface'))

        Scroll() {
          Column({ space: 14 }) {
            // 账号卡片
            Column({ space: 10 }) {
              Text('账号与网页会话')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))

              Row({ space: 10 }) {
                Column({ space: 4 }) {
                  Text(
                    this.loggedIn && this.userProfile !== null
                      ? this.userProfile.name
                      : (this.loggedIn ? '已登录 DeepSeek' : '未登录')
                  )
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))

                  Text(this.authSummary)
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                if (this.loggedIn) {
                  Button('退出登录')
                    .fontSize(12)
                    .height(32)
                    .backgroundColor($r('app.color.bg_pill'))
                    .fontColor($r('app.color.danger_color'))
                    .onClick(() => {
                      this.handleLogout();
                    })
                } else {
                  Button('去登录')
                    .fontSize(12)
                    .height(32)
                    .backgroundColor($r('app.color.accent_primary'))
                    .fontColor(Color.White)
                    .onClick(() => {
                      this.openLogin();
                    })
                }
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.bg_surface'))
            .borderRadius(14)
            .alignItems(HorizontalAlign.Start)

            // 外观与字号
            Column({ space: 12 }) {
              Text('外观与阅读')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))

              Text('深色模式')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))

              Row({ space: 8 }) {
                Button('跟随系统')
                  .fontSize(12)
                  .height(32)
                  .layoutWeight(1)
                  .backgroundColor(this.themeMode === 'system' ? $r('app.color.bg_pill_active') : $r('app.color.bg_pill'))
                  .fontColor(this.themeMode === 'system' ? $r('app.color.accent_primary') : $r('app.color.text_primary'))
                  .onClick(async () => {
                    const ctx = this.getUIContext().getHostContext() as common.Context;
                    await SettingsStore.getInstance().setThemeMode('system', ctx);
                    this.themeMode = 'system';
                  })

                Button('浅色')
                  .fontSize(12)
                  .height(32)
                  .layoutWeight(1)
                  .backgroundColor(this.themeMode === 'light' ? $r('app.color.bg_pill_active') : $r('app.color.bg_pill'))
                  .fontColor(this.themeMode === 'light' ? $r('app.color.accent_primary') : $r('app.color.text_primary'))
                  .onClick(async () => {
                    const ctx = this.getUIContext().getHostContext() as common.Context;
                    await SettingsStore.getInstance().setThemeMode('light', ctx);
                    this.themeMode = 'light';
                  })

                Button('深色')
                  .fontSize(12)
                  .height(32)
                  .layoutWeight(1)
                  .backgroundColor(this.themeMode === 'dark' ? $r('app.color.bg_pill_active') : $r('app.color.bg_pill'))
                  .fontColor(this.themeMode === 'dark' ? $r('app.color.accent_primary') : $r('app.color.text_primary'))
                  .onClick(async () => {
                    const ctx = this.getUIContext().getHostContext() as common.Context;
                    await SettingsStore.getInstance().setThemeMode('dark', ctx);
                    this.themeMode = 'dark';
                  })
              }
              .width('100%')

              Text('对话字号')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))

              Row({ space: 8 }) {
                Button('标准 (15fp)')
                  .fontSize(12)
                  .height(32)
                  .layoutWeight(1)
                  .backgroundColor(this.fontSizeLevel === 'standard' ? $r('app.color.bg_pill_active') : $r('app.color.bg_pill'))
                  .fontColor(this.fontSizeLevel === 'standard' ? $r('app.color.accent_primary') : $r('app.color.text_primary'))
                  .onClick(async () => {
                    await SettingsStore.getInstance().setFontSizeLevel('standard');
                    this.fontSizeLevel = 'standard';
                  })

                Button('较大 (17fp)')
                  .fontSize(12)
                  .height(32)
                  .layoutWeight(1)
                  .backgroundColor(this.fontSizeLevel === 'large' ? $r('app.color.bg_pill_active') : $r('app.color.bg_pill'))
                  .fontColor(this.fontSizeLevel === 'large' ? $r('app.color.accent_primary') : $r('app.color.text_primary'))
                  .onClick(async () => {
                    await SettingsStore.getInstance().setFontSizeLevel('large');
                    this.fontSizeLevel = 'large';
                  })

                Button('大号 (19fp)')
                  .fontSize(12)
                  .height(32)
                  .layoutWeight(1)
                  .backgroundColor(this.fontSizeLevel === 'xlarge' ? $r('app.color.bg_pill_active') : $r('app.color.bg_pill'))
                  .fontColor(this.fontSizeLevel === 'xlarge' ? $r('app.color.accent_primary') : $r('app.color.text_primary'))
                  .onClick(async () => {
                    await SettingsStore.getInstance().setFontSizeLevel('xlarge');
                    this.fontSizeLevel = 'xlarge';
                  })
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.bg_surface'))
            .borderRadius(14)
            .alignItems(HorizontalAlign.Start)

            // 对话默认偏好
            Column({ space: 10 }) {
              Text('对话默认设置')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))

              Row() {
                Text('当前模型')
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Text('跟随网页端默认模型（不写死模型 ID）')
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')

              Row() {
                Text('新对话默认开启深度思考')
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.defaultThinking })
                  .onChange(async (isOn: boolean) => {
                    this.defaultThinking = isOn;
                    await SettingsStore.getInstance().setDefaultThinking(isOn);
                  })
              }
              .width('100%')

              Row() {
                Text('新对话默认开启智能搜索')
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.defaultSearch })
                  .onChange(async (isOn: boolean) => {
                    this.defaultSearch = isOn;
                    await SettingsStore.getInstance().setDefaultSearch(isOn);
                  })
              }
              .width('100%')

              Row() {
                Text('历史消息默认折叠深度思考过程')
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.autoCollapseThinking })
                  .onChange(async (isOn: boolean) => {
                    this.autoCollapseThinking = isOn;
                    await SettingsStore.getInstance().setAutoCollapseThinking(isOn);
                  })
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.bg_surface'))
            .borderRadius(14)
            .alignItems(HorizontalAlign.Start)

            // 数据与应急兜底
            Column({ space: 10 }) {
              Text('数据与应急模式')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))

              Button('打开网页版（应急模式 / 安全验证）')
                .fontSize(13)
                .height(38)
                .width('100%')
                .backgroundColor($r('app.color.bg_pill_active'))
                .fontColor($r('app.color.accent_primary'))
                .onClick(() => {
                  this.openWebFallback();
                })

              if (this.loggedIn) {
                Button('清空全部云端历史对话')
                  .fontSize(13)
                  .height(38)
                  .width('100%')
                  .backgroundColor($r('app.color.bg_pill'))
                  .fontColor($r('app.color.danger_color'))
                  .onClick(() => {
                    this.confirmClearAll = true;
                  })
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.bg_surface'))
            .borderRadius(14)
            .alignItems(HorizontalAlign.Start)

            // 免责与安全声明
            Column({ space: 6 }) {
              Text(`${AppConfig.APP_NAME} v${AppConfig.APP_VERSION}`)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              Text(AppConfig.DISCLAIMER)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .lineHeight(18)
              Text(AppConfig.SECURITY_NOTICE)
                .fontSize(12)
                .fontColor($r('app.color.text_muted'))
                .lineHeight(18)
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.bg_surface'))
            .borderRadius(14)
            .alignItems(HorizontalAlign.Start)
          }
          .padding(16)
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))

      if (this.confirmClearAll) {
        Column() {
          Column({ space: 12 }) {
            Text('清空全部对话')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text('此操作将删除当前账号在 DeepSeek 云端的所有历史对话，无法撤销。确认继续吗？')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .lineHeight(19)
            Row({ space: 10 }) {
              Button('取消')
                .fontSize(13)
                .layoutWeight(1)
                .backgroundColor($r('app.color.bg_pill'))
                .fontColor($r('app.color.text_primary'))
                .onClick(() => {
                  this.confirmClearAll = false;
                })
              Button(this.clearingAll ? '清空中...' : '确认清空')
                .fontSize(13)
                .layoutWeight(1)
                .backgroundColor($r('app.color.danger_color'))
                .fontColor(Color.White)
                .enabled(!this.clearingAll)
                .onClick(() => {
                  this.handleClearAllSessions();
                })
            }
          }
          .padding(18)
          .width('86%')
          .backgroundColor($r('app.color.bg_elevated'))
          .borderRadius(16)
          .border({ width: 1, color: $r('app.color.border_color') })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }
}
