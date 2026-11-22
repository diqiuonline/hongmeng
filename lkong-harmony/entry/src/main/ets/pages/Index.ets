import { promptAction, router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ApiError, Forum, PunchInfo } from '../model/Models';
import { LkongApi } from '../network/LkongApi';
import { CookieStore } from '../store/CookieStore';
import { DisplayPrefs } from '../store/DisplayPrefs';
import { ForumCard } from '../components/ForumCard';
import { StateView } from '../components/StateView';
import { getTheme, KEY_IS_DARK } from '../utils/Theme';

/**
 * 首页：公开的版块列表。
 *
 * 未登录也可以查看版块；点击版块后如果站点要求登录，
 * ForumPage 会展示“需要登录”并提供账号登录入口。
 */
@Entry
@Component
struct Index {
  @State forums: Forum[] = [];
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State loggedIn: boolean = false;
  @State punchInfo: PunchInfo | null = null;
  @State punchLoading: boolean = false;
  @State punchSubmitting: boolean = false;
  @State punchError: string = '';
  @StorageProp(KEY_IS_DARK) isDark: boolean = false;

  aboutToAppear(): void {
    this.bootstrap();
  }

  onPageShow(): void {
    const nowLoggedIn = CookieStore.getInstance().hasCookie();
    if (!nowLoggedIn) {
      this.loggedIn = false;
      this.punchInfo = null;
      this.punchError = '';
      return;
    }
    const wasLoggedIn = this.loggedIn;
    this.loggedIn = true;
    if (!wasLoggedIn || (this.punchInfo === null && !this.punchLoading)) {
      this.loadPunchInfo();
    }
  }

  private async bootstrap(): Promise<void> {
    const ctx = getContext(this) as common.Context;
    await CookieStore.getInstance().ensureInit(ctx);
    await DisplayPrefs.getInstance().ensureInit(ctx);
    this.loggedIn = CookieStore.getInstance().hasCookie();
    await this.loadForums();
    if (this.loggedIn) {
      await this.loadPunchInfo();
    }
  }

  private async refreshAll(): Promise<void> {
    await this.loadForums();
    if (this.loggedIn) {
      await this.loadPunchInfo();
    }
  }

  private async loadPunchInfo(): Promise<void> {
    if (!CookieStore.getInstance().hasCookie()) {
      this.punchInfo = null;
      this.punchError = '';
      return;
    }
    this.punchLoading = true;
    this.punchError = '';
    try {
      this.punchInfo = await LkongApi.getInstance().getUserPunch();
    } catch (error) {
      if (error instanceof ApiError) {
        this.punchError = error.message;
      } else {
        this.punchError = '签到状态获取失败。';
      }
    } finally {
      this.punchLoading = false;
    }
  }

  private showMessage(message: string): void {
    try {
      promptAction.showToast({ message: message });
    } catch (error) {
      // 忽略页面退出等场景下的弹窗异常。
    }
  }

  private async doPunch(): Promise<void> {
    if (this.punchSubmitting || this.punchLoading) {
      return;
    }
    this.punchSubmitting = true;
    try {
      const result = await LkongApi.getInstance().punch();
      this.punchInfo = result;
      this.punchError = '';
      this.showMessage(`签到成功！已连续签到 ${result.punchDay} 天`);
    } catch (error) {
      const message = error instanceof ApiError ? error.message : '签到失败，请稍后重试。';
      this.showMessage(message);
    } finally {
      this.punchSubmitting = false;
    }
  }

  private punchSubtitle(): string {
    if (this.punchLoading && this.punchInfo === null) {
      return '正在获取签到状态...';
    }
    if (this.punchError.length > 0 && this.punchInfo === null) {
      return this.punchError;
    }
    if (this.punchInfo !== null) {
      return `连续 ${this.punchInfo.punchDay} 天 · 累计 ${this.punchInfo.punchAllDay} 天 · 最高 ${this.punchInfo.punchHighestDay} 天`;
    }
    return '点击右侧按钮完成今日签到';
  }

  private async loadForums(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    try {
      this.forums = await LkongApi.getInstance().getHomeForums();
    } catch (error) {
      if (error instanceof ApiError) {
        this.errorMessage = error.message;
      } else {
        this.errorMessage = '版块加载失败，请稍后重试。';
      }
    } finally {
      this.loading = false;
    }
  }

  private openLogin(): void {
    router.pushUrl({ url: 'pages/LoginPage' }).catch(() => {
    });
  }

  private openSettings(): void {
    router.pushUrl({ url: 'pages/SettingsPage' }).catch(() => {
    });
  }

  private openForum(forum: Forum): void {
    router.pushUrl({
      url: 'pages/ForumPage',
      params: {
        fid: forum.fid,
        name: forum.name
      }
    }).catch(() => {
    });
  }

  build() {
    Column() {
      Row() {
        Text('龙空客户端')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(getTheme(this.isDark).textPrimary)
        Blank()
        Button('刷新')
          .fontSize(12)
          .height(32)
          .backgroundColor(getTheme(this.isDark).accentBg)
          .fontColor(getTheme(this.isDark).accent)
          .margin({ right: 8 })
          .onClick(() => {
            this.refreshAll();
          })
        Button(this.loggedIn ? '设置' : '登录')
          .fontSize(12)
          .height(32)
          .backgroundColor(getTheme(this.isDark).accentSolid)
          .fontColor(Color.White)
          .onClick(() => {
            if (this.loggedIn) {
              this.openSettings();
            } else {
              this.openLogin();
            }
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      if (!this.loggedIn) {
        Column() {
          Row({ space: 8 }) {
            Text('当前未登录。版块列表可以直接浏览；帖子列表和详情需要登录。')
              .fontSize(12)
              .fontColor(getTheme(this.isDark).bannerText)
              .layoutWeight(1)
            Button('去登录')
              .fontSize(12)
              .height(30)
              .backgroundColor(getTheme(this.isDark).bannerBtnBg)
              .fontColor(getTheme(this.isDark).bannerText)
              .onClick(() => {
                this.openLogin();
              })
          }
          .width('100%')
          .padding(12)
          .backgroundColor(getTheme(this.isDark).bannerBg)
          .borderRadius(8)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })
      } else {
        Column() {
          Row({ space: 12 }) {
            Column({ space: 4 }) {
              Row({ space: 6 }) {
                Text('每日签到')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(getTheme(this.isDark).textPrimary)
                if (this.punchInfo !== null && this.punchInfo.isPunch) {
                  Text('今日已签')
                    .fontSize(11)
                    .fontColor(getTheme(this.isDark).successText)
                    .backgroundColor(getTheme(this.isDark).successBg)
                    .borderRadius(4)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                } else if (this.punchInfo !== null) {
                  Text('待签到')
                    .fontSize(11)
                    .fontColor(getTheme(this.isDark).bannerText)
                    .backgroundColor(getTheme(this.isDark).bannerBg)
                    .borderRadius(4)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                }
              }

              Text(this.punchSubtitle())
                .fontSize(12)
                .fontColor(getTheme(this.isDark).textSecondary)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            if (this.punchError.length > 0 && this.punchInfo === null) {
              Button('重试')
                .fontSize(12)
                .height(32)
                .backgroundColor(getTheme(this.isDark).accentBg)
                .fontColor(getTheme(this.isDark).accent)
                .onClick(() => {
                  this.loadPunchInfo();
                })
            } else if (this.punchInfo !== null && this.punchInfo.isPunch) {
              Button('已签到')
                .fontSize(12)
                .height(32)
                .backgroundColor(getTheme(this.isDark).successBg)
                .fontColor(getTheme(this.isDark).successText)
                .enabled(false)
            } else {
              Button(this.punchSubmitting ? '签到中...' : '签到')
                .fontSize(12)
                .height(32)
                .backgroundColor(
                  (!this.punchLoading && !this.punchSubmitting)
                    ? getTheme(this.isDark).accentSolid
                    : getTheme(this.isDark).disabledBtnBg
                )
                .fontColor(
                  (!this.punchLoading && !this.punchSubmitting)
                    ? Color.White
                    : getTheme(this.isDark).disabledBtnText
                )
                .enabled(!this.punchLoading && !this.punchSubmitting)
                .onClick(() => {
                  this.doPunch();
                })
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor(getTheme(this.isDark).cardBg)
          .borderRadius(12)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 10 })
      }

      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(getTheme(this.isDark).accent)
          Text('正在加载版块...')
            .fontSize(13)
            .fontColor(getTheme(this.isDark).textSecondary)
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.errorMessage.length > 0) {
        Column() {
          StateView({
            title: '加载失败',
            message: this.errorMessage,
            actionText: '重试',
            onAction: () => {
              this.loadForums();
            }
          })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.forums.length === 0) {
        Column() {
          StateView({
            title: '暂无版块',
            message: '当前没有获取到版块数据。'
          })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 12 }) {
          ForEach(this.forums, (forum: Forum) => {
            ListItem() {
              ForumCard({
                name: forum.name,
                info: forum.info,
                todayPostNum: forum.todayPostNum,
                avatarUrl: forum.avatarUrl,
                onOpen: () => {
                  this.openForum(forum);
                }
              })
            }
          }, (forum: Forum) => forum.fid.toString())
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 16 })
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(getTheme(this.isDark).pageBg)
  }
}
