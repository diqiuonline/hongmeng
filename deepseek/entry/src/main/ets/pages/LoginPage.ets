import { common } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { ApiError } from '../model/ApiErrors';
import { DeepSeekApi } from '../network/DeepSeekApi';
import { AuthStore, extractTokenFromLocalStorageRaw } from '../store/AuthStore';
import { AppConfig } from '../utils/AppConfig';

@Entry
@Component
struct LoginPage {
  @State activeTab: number = 0;
  @State webLoading: boolean = true;
  @State syncingAuth: boolean = false;
  @State account: string = '';
  @State password: string = '';
  @State submitting: boolean = false;
  @State errorMessage: string = '';
  @StorageProp('isDarkMode') isDarkMode: boolean = false;

  private webController: webview.WebviewController = new webview.WebviewController();
  private pollTimerId: number = -1;
  private hasFinishedLogin: boolean = false;

  aboutToAppear(): void {
    this.ensureInit();
    this.startWebAuthPolling();
  }

  aboutToDisappear(): void {
    this.stopWebAuthPolling();
  }

  private async ensureInit(): Promise<void> {
    const ctx = this.getUIContext().getHostContext() as common.Context;
    await AuthStore.getInstance().ensureInit(ctx);
  }

  private showToast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg });
    } catch (err) {
      // 忽略页面关闭时的弹窗异常。
    }
  }

  private goBack(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (err) {
      // 忽略。
    }
  }

  private startWebAuthPolling(): void {
    this.stopWebAuthPolling();
    this.pollTimerId = setInterval(() => {
      if (this.activeTab === 0 && !this.syncingAuth && !this.hasFinishedLogin) {
        this.tryExtractAuthFromWeb(false);
      }
    }, 1800);
  }

  private stopWebAuthPolling(): void {
    if (this.pollTimerId !== -1) {
      clearInterval(this.pollTimerId);
      this.pollTimerId = -1;
    }
  }

  private tryExtractAuthFromWeb(manualTrigger: boolean): void {
    if (this.syncingAuth || this.hasFinishedLogin) {
      return;
    }
    try {
      this.webController.runJavaScript(
        "localStorage.getItem('userToken') || ''",
        (err, result: string) => {
          if (err) {
            if (manualTrigger) {
              this.showToast('页面尚未就绪，请稍后再试');
            }
            return;
          }
          const token = extractTokenFromLocalStorageRaw(result);
          let cookies = '';
          try {
            cookies = webview.WebCookieManager.fetchCookieSync(AppConfig.BASE_URL);
          } catch (cookieErr) {
            cookies = '';
          }

          if (token.length === 0) {
            if (manualTrigger) {
              this.showToast('暂未检测到登录凭证，请先完成页面登录');
            }
            return;
          }

          this.finishWebLogin(token, cookies, manualTrigger);
        }
      );
    } catch (err) {
      if (manualTrigger) {
        this.showToast('正在加载登录页面，请稍候');
      }
    }
  }

  private async finishWebLogin(token: string, cookies: string, manualTrigger: boolean): Promise<void> {
    if (this.syncingAuth || this.hasFinishedLogin) {
      return;
    }
    this.syncingAuth = true;
    this.errorMessage = '';
    try {
      await AuthStore.getInstance().setAuth(token, cookies);
      await DeepSeekApi.getInstance().getCurrentUser();
      this.hasFinishedLogin = true;
      this.stopWebAuthPolling();
      this.showToast('登录成功，已同步网页端账号');
      this.goBack();
    } catch (error) {
      if (manualTrigger) {
        this.errorMessage = error instanceof ApiError
          ? error.message
          : '凭证验证失败，请在页面内确认登录完成后重试。';
      }
    } finally {
      this.syncingAuth = false;
    }
  }

  private async submitPasswordLogin(): Promise<void> {
    if (this.submitting) {
      return;
    }
    if (this.account.trim().length === 0 || this.password.length === 0) {
      this.errorMessage = '请输入邮箱/手机号和密码。';
      return;
    }
    this.submitting = true;
    this.errorMessage = '';
    try {
      await DeepSeekApi.getInstance().loginWithPassword(this.account, this.password);
      this.hasFinishedLogin = true;
      this.stopWebAuthPolling();
      this.showToast('登录成功');
      this.goBack();
    } catch (error) {
      if (error instanceof ApiError) {
        this.errorMessage = error.message;
      } else {
        this.errorMessage = '登录失败，建议使用网页登录。';
      }
    } finally {
      this.password = '';
      this.submitting = false;
    }
  }

  build() {
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

        Text('登录 DeepSeek')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        if (this.activeTab === 0) {
          Button(this.syncingAuth ? '同步中...' : '同步登录态')
            .fontSize(12)
            .height(32)
            .backgroundColor($r('app.color.accent_primary'))
            .fontColor(Color.White)
            .enabled(!this.syncingAuth)
            .onClick(() => {
              this.tryExtractAuthFromWeb(true);
            })
        }
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor($r('app.color.bg_surface'))

      Row({ space: 8 }) {
        Button('网页登录（推荐）')
          .fontSize(13)
          .height(34)
          .layoutWeight(1)
          .backgroundColor(this.activeTab === 0 ? $r('app.color.bg_pill_active') : $r('app.color.bg_pill'))
          .fontColor(this.activeTab === 0 ? $r('app.color.accent_primary') : $r('app.color.text_secondary'))
          .onClick(() => {
            this.activeTab = 0;
            this.errorMessage = '';
          })

        Button('账号密码登录')
          .fontSize(13)
          .height(34)
          .layoutWeight(1)
          .backgroundColor(this.activeTab === 1 ? $r('app.color.bg_pill_active') : $r('app.color.bg_pill'))
          .fontColor(this.activeTab === 1 ? $r('app.color.accent_primary') : $r('app.color.text_secondary'))
          .onClick(() => {
            this.activeTab = 1;
            this.errorMessage = '';
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor($r('app.color.bg_page'))

      if (this.errorMessage.length > 0) {
        Row() {
          Text(this.errorMessage)
            .fontSize(12)
            .fontColor($r('app.color.danger_color'))
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 6 })
      }

      if (this.activeTab === 0) {
        Stack() {
          Web({ src: AppConfig.SIGN_IN_URL, controller: this.webController })
            .javaScriptAccess(true)
            .domStorageAccess(true)
            .fileAccess(true)
            .databaseAccess(true)
            .darkMode(this.isDarkMode ? WebDarkMode.On : WebDarkMode.Off)
            .width('100%')
            .height('100%')
            .onPageBegin(() => {
              this.webLoading = true;
            })
            .onPageEnd(() => {
              this.webLoading = false;
              this.tryExtractAuthFromWeb(false);
            })

          if (this.webLoading) {
            Column({ space: 8 }) {
              LoadingProgress()
                .width(36)
                .height(36)
                .color($r('app.color.accent_primary'))
              Text('正在加载登录页...')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
            }
            .padding(16)
            .backgroundColor($r('app.color.bg_elevated'))
            .borderRadius(12)
          }
        }
        .layoutWeight(1)
        .width('100%')

        Row() {
          Text('支持手机号验证码、微信或账号密码登录。登录成功后会自动同步，也可点击右上角“同步登录态”。')
            .fontSize(11)
            .fontColor($r('app.color.text_muted'))
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 8, bottom: 10 })
        .backgroundColor($r('app.color.bg_surface'))
      } else {
        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 12 }) {
              Text('直连网页登录接口')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))

              Text('账号密码仅用于本次登录请求，不在本地保存密码。若账号需短信验证码或人机校验，请使用左侧“网页登录”。')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .lineHeight(18)

              TextInput({ placeholder: '邮箱或手机号', text: this.account })
                .fontSize(15)
                .height(44)
                .fontColor($r('app.color.text_primary'))
                .backgroundColor($r('app.color.bg_input'))
                .borderRadius(10)
                .padding({ left: 12, right: 12 })
                .onChange((val: string) => {
                  this.account = val;
                })

              TextInput({ placeholder: '密码', text: this.password })
                .type(InputType.Password)
                .fontSize(15)
                .height(44)
                .fontColor($r('app.color.text_primary'))
                .backgroundColor($r('app.color.bg_input'))
                .borderRadius(10)
                .padding({ left: 12, right: 12 })
                .onChange((val: string) => {
                  this.password = val;
                })

              Button(this.submitting ? '登录中...' : '登录')
                .fontSize(15)
                .height(44)
                .width('100%')
                .backgroundColor($r('app.color.accent_primary'))
                .fontColor(Color.White)
                .borderRadius(22)
                .enabled(!this.submitting)
                .onClick(() => {
                  this.submitPasswordLogin();
                })
            }
            .width('100%')
            .padding(18)
            .backgroundColor($r('app.color.bg_surface'))
            .borderRadius(16)
            .border({ width: 1, color: $r('app.color.border_color') })
            .alignItems(HorizontalAlign.Start)
          }
          .padding(16)
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
