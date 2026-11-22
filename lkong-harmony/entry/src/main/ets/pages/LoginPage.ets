import { promptAction, router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ApiError } from '../model/Models';
import { LkongApi } from '../network/LkongApi';
import { CookieStore } from '../store/CookieStore';
import { DisplayPrefs } from '../store/DisplayPrefs';
import { getTheme, KEY_IS_DARK } from '../utils/Theme';

/**
 * 登录页只保留账号密码 GraphQL 登录。
 *
 * 密码只用于本次 Login mutation 请求体，不写入本地存储；
 * 登录成功后只保存会话 Cookie（EGG_SESS）。
 */
@Entry
@Component
struct LoginPage {
  @State email: string = '';
  @State password: string = '';
  @State loading: boolean = false;
  @StorageProp(KEY_IS_DARK) isDark: boolean = false;

  aboutToAppear(): void {
    DisplayPrefs.getInstance().ensureInit(getContext(this) as common.Context).catch(() => {
    });
  }

  private showToast(message: string): void {
    try {
      promptAction.showToast({ message: message });
    } catch (error) {
      // 忽略页面退出等场景下的弹窗异常。
    }
  }

  private async doLogin(): Promise<void> {
    if (this.email.trim().length === 0 || this.password.length === 0) {
      this.showToast('请输入邮箱/手机号和密码。');
      return;
    }

    this.loading = true;
    try {
      await CookieStore.getInstance().ensureInit(getContext(this) as common.Context);
      const result = await LkongApi.getInstance().login(this.email.trim(), this.password);
      this.showToast(`登录成功：${result.name}`);
      router.back();
    } catch (error) {
      const message = error instanceof ApiError ? error.message : '登录失败，请稍后重试。';
      this.showToast(message);
    } finally {
      // 不把密码保留在页面状态中。
      this.password = '';
      this.loading = false;
    }
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
        Text('登录龙空')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(getTheme(this.isDark).textPrimary)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Column() {
        Column({ space: 12 }) {
          Text('账号密码登录')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(getTheme(this.isDark).textPrimary)

          TextInput({
            placeholder: '邮箱或手机号',
            text: this.email
          })
            .height(42)
            .fontSize(14)
            .fontColor(getTheme(this.isDark).textPrimary)
            .placeholderColor(getTheme(this.isDark).textMuted)
            .backgroundColor(getTheme(this.isDark).inputBg)
            .onChange((value: string) => {
              this.email = value;
            })

          TextInput({
            placeholder: '密码',
            text: this.password
          })
            .type(InputType.Password)
            .height(42)
            .fontSize(14)
            .fontColor(getTheme(this.isDark).textPrimary)
            .placeholderColor(getTheme(this.isDark).textMuted)
            .backgroundColor(getTheme(this.isDark).inputBg)
            .onChange((value: string) => {
              this.password = value;
            })

          Button(this.loading ? '登录中...' : '登录')
            .height(40)
            .width('100%')
            .backgroundColor(
              this.loading ? getTheme(this.isDark).disabledBtnBg : getTheme(this.isDark).accentSolid
            )
            .fontColor(this.loading ? getTheme(this.isDark).disabledBtnText : Color.White)
            .enabled(!this.loading)
            .onClick(() => {
              this.doLogin();
            })

          Text('密码只用于本次登录请求，客户端不保存。登录态以 Cookie 形式保存在本机，可在设置页清除。')
            .fontSize(11)
            .fontColor(getTheme(this.isDark).textMuted)
            .lineHeight(17)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(getTheme(this.isDark).cardBg)
        .borderRadius(12)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(getTheme(this.isDark).pageBg)
  }
}
