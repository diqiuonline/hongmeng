import { ApiError } from '../model/Models';
import { LkongApi } from '../network/LkongApi';
import { CookieStore } from '../store/CookieStore';
import { DisplayPrefs } from '../store/DisplayPrefs';
import { AppNavigator } from '../utils/AppRouter';
import { getTheme, KEY_IS_DARK } from '../utils/Theme';
import { getHostContext, showToast } from '../utils/UiUtils';

/**
 * 登录页：支持账号密码登录与 twoWay 二次验证码登录。
 *
 * 密码只用于本次 Login mutation 请求体，不写入本地存储；
 * 登录成功后只保存会话 Cookie（EGG_SESS）。
 */
@Component
export struct LoginPage {
  @State email: string = '';
  @State password: string = '';
  @State twoWayToken: string = '';
  @State twoWayServerTime: string = '';
  @State twoWayCode: string = '';
  @State loading: boolean = false;
  @StorageProp(KEY_IS_DARK) isDark: boolean = false;

  aboutToAppear(): void {
    DisplayPrefs.getInstance().ensureInit(getHostContext(this.getUIContext())).catch(() => {
    });
  }

  private async doLogin(): Promise<void> {
    if (this.email.trim().length === 0 || this.password.length === 0) {
      showToast(this.getUIContext(), '请输入邮箱/手机号和密码。');
      return;
    }

    this.loading = true;
    try {
      await CookieStore.getInstance().ensureInit(getHostContext(this.getUIContext()));
      const result = await LkongApi.getInstance().login(this.email.trim(), this.password);
      if (result.twoWay.length > 0) {
        this.twoWayToken = result.twoWay;
        this.twoWayServerTime = result.serverTime;
        this.twoWayCode = '';
        showToast(this.getUIContext(), '请输入二次验证码完成登录');
        return;
      }
      showToast(this.getUIContext(), `登录成功：${result.name}`);
      AppNavigator.getInstance().pop();
    } catch (error) {
      const message = error instanceof ApiError ? error.message : '登录失败，请稍后重试。';
      showToast(this.getUIContext(), message);
    } finally {
      // 不把密码保留在页面状态中。
      this.password = '';
      this.loading = false;
    }
  }

  private async doTwoWayLogin(): Promise<void> {
    const code = this.twoWayCode.trim();
    if (code.length === 0) {
      showToast(this.getUIContext(), '请输入动态验证码。');
      return;
    }
    this.loading = true;
    try {
      await CookieStore.getInstance().ensureInit(getHostContext(this.getUIContext()));
      const result = await LkongApi.getInstance().twoWayLogin(
        this.twoWayToken,
        code,
        this.twoWayServerTime
      );
      showToast(this.getUIContext(), `登录成功：${result.name}`);
      AppNavigator.getInstance().pop();
    } catch (error) {
      const message = error instanceof ApiError ? error.message : '二次验证失败，请核对验证码后重试。';
      showToast(this.getUIContext(), message);
    } finally {
      this.loading = false;
    }
  }

  private resetTwoWay(): void {
    this.twoWayToken = '';
    this.twoWayServerTime = '';
    this.twoWayCode = '';
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Button('返回')
            .fontSize(12)
            .height(32)
            .backgroundColor(getTheme(this.isDark).accentBg)
            .fontColor(getTheme(this.isDark).accent)
            .margin({ right: 8 })
            .onClick(() => {
              AppNavigator.getInstance().pop();
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
          if (this.twoWayToken.length > 0) {
            Column({ space: 12 }) {
              Text('二次验证（2FA）')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(getTheme(this.isDark).textPrimary)

              Text('该账号已开启二次验证，请输入验证器中的动态验证码。')
                .fontSize(12)
                .fontColor(getTheme(this.isDark).textSecondary)
                .lineHeight(18)

              TextInput({
                placeholder: '动态验证码',
                text: this.twoWayCode
              })
                .height(42)
                .fontSize(14)
                .fontColor(getTheme(this.isDark).textPrimary)
                .placeholderColor(getTheme(this.isDark).textMuted)
                .backgroundColor(getTheme(this.isDark).inputBg)
                .onChange((value: string) => {
                  this.twoWayCode = value;
                })
                .onSubmit(() => {
                  this.doTwoWayLogin();
                })

              Button(this.loading ? '验证中...' : '验证并登录')
                .height(40)
                .width('100%')
                .backgroundColor(
                  this.loading ? getTheme(this.isDark).disabledBtnBg : getTheme(this.isDark).accentSolid
                )
                .fontColor(this.loading ? getTheme(this.isDark).disabledBtnText : Color.White)
                .enabled(!this.loading)
                .onClick(() => {
                  this.doTwoWayLogin();
                })

              Button('返回账号密码登录')
                .height(36)
                .width('100%')
                .backgroundColor(getTheme(this.isDark).surfaceMuted)
                .fontColor(getTheme(this.isDark).textSecondary)
                .enabled(!this.loading)
                .onClick(() => {
                  this.resetTwoWay();
                })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(getTheme(this.isDark).cardBg)
            .borderRadius(12)
            .alignItems(HorizontalAlign.Start)
          } else {
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
                .onSubmit(() => {
                  this.doLogin();
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
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(getTheme(this.isDark).pageBg)
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      if (this.twoWayToken.length > 0) {
        this.resetTwoWay();
        return true;
      }
      return false;
    })
  }
}
