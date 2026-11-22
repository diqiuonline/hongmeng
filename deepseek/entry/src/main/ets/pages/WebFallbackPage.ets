import { common } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { pickLocalDocuments } from '../components/AttachmentPicker';
import { AuthStore, extractTokenFromLocalStorageRaw } from '../store/AuthStore';
import { AppConfig } from '../utils/AppConfig';

interface WebFallbackParams {
  url?: string;
  title?: string;
  syncAuthOnExit?: boolean;
}

@Entry
@Component
struct WebFallbackPage {
  @State targetUrl: string = AppConfig.BASE_URL;
  @State pageTitle: string = '网页版';
  @State syncAuthOnExit: boolean = true;
  @State webLoading: boolean = true;
  @StorageProp('isDarkMode') isDarkMode: boolean = false;

  private webController: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    try {
      const rawParams = this.getUIContext().getRouter().getParams() as WebFallbackParams | undefined;
      if (rawParams !== undefined) {
        if (rawParams.url !== undefined && rawParams.url.length > 0) {
          this.targetUrl = rawParams.url;
        }
        if (rawParams.title !== undefined && rawParams.title.length > 0) {
          this.pageTitle = rawParams.title;
        }
        if (rawParams.syncAuthOnExit !== undefined) {
          this.syncAuthOnExit = rawParams.syncAuthOnExit;
        }
      }
    } catch (err) {
      // 使用默认参数。
    }
  }

  private showToast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg });
    } catch (err) {
      // 忽略。
    }
  }

  private syncAndBack(): void {
    const isDeepSeek = this.targetUrl.startsWith(AppConfig.BASE_URL);
    if (!isDeepSeek || !this.syncAuthOnExit) {
      this.goBack();
      return;
    }

    try {
      this.webController.runJavaScript(
        "localStorage.getItem('userToken') || ''",
        async (err, result: string) => {
          const token = !err ? extractTokenFromLocalStorageRaw(result) : '';
          let cookies = '';
          try {
            cookies = webview.WebCookieManager.fetchCookieSync(AppConfig.BASE_URL);
          } catch (cookieErr) {
            cookies = '';
          }
          if (token.length > 0 || cookies.length > 0) {
            await AuthStore.getInstance().setAuth(token, cookies);
            this.showToast('已同步最新网页会话');
          }
          this.goBack();
        }
      );
    } catch (err) {
      this.goBack();
    }
  }

  private goBack(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (err) {
      // 忽略。
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
            if (this.syncAuthOnExit && this.targetUrl.startsWith(AppConfig.BASE_URL)) {
              this.syncAndBack();
            } else {
              this.goBack();
            }
          })

        Text(this.pageTitle)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        if (this.targetUrl.startsWith(AppConfig.BASE_URL)) {
          Button('同步凭证')
            .fontSize(12)
            .height(32)
            .backgroundColor($r('app.color.accent_primary'))
            .fontColor(Color.White)
            .onClick(() => {
              this.syncAndBack();
            })
        } else {
          Button('刷新')
            .fontSize(12)
            .height(32)
            .backgroundColor($r('app.color.bg_pill'))
            .fontColor($r('app.color.text_primary'))
            .onClick(() => {
              try {
                this.webController.refresh();
              } catch (err) {
                // 忽略。
              }
            })
        }
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor($r('app.color.bg_surface'))

      Stack() {
        Web({ src: this.targetUrl, controller: this.webController })
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
          })
          .onShowFileSelector((event: OnShowFileSelectorEvent): boolean => {
            const ctx = this.getUIContext().getHostContext() as common.Context;
            pickLocalDocuments(ctx, 5).then((picked) => {
              const uris: string[] = [];
              for (const item of picked) {
                uris.push(item.localUri);
              }
              event.result.handleFileList(uris);
            });
            return true;
          })

        if (this.webLoading) {
          LoadingProgress()
            .width(34)
            .height(34)
            .color($r('app.color.accent_primary'))
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
