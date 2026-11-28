import { ApiError, ErrorKind, FavoriteGroup } from '../model/Models';
import { LkongApi } from '../network/LkongApi';
import { CookieStore } from '../store/CookieStore';
import { DisplayPrefs } from '../store/DisplayPrefs';
import { StateView } from '../components/StateView';
import { AppNavigator, FavoriteDetailRouteParams, Routes } from '../utils/AppRouter';
import { formatTime } from '../utils/TimeUtils';
import { getTheme, KEY_IS_DARK } from '../utils/Theme';
import { getHostContext, showToast } from '../utils/UiUtils';

/**
 * 纯云端收藏夹分组列表与管理页（新建、编辑、删除分组）。
 */
@Component
export struct FavoritesPage {
  @State groups: FavoriteGroup[] = [];
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State needLogin: boolean = false;

  @State showGroupModal: boolean = false;
  @State editingGroupId: number = 0;
  @State formTitle: string = '';
  @State formDesc: string = '';
  @State formPublic: boolean = true;
  @State submitting: boolean = false;

  @State deleteTarget: FavoriteGroup | null = null;
  @State deleting: boolean = false;

  @StorageProp(KEY_IS_DARK) isDark: boolean = false;
  private hasLoadedOnce: boolean = false;

  aboutToAppear(): void {
    this.bootstrap();
  }

  private async bootstrap(): Promise<void> {
    const ctx = getHostContext(this.getUIContext());
    await CookieStore.getInstance().ensureInit(ctx);
    await DisplayPrefs.getInstance().ensureInit(ctx);
    await this.loadGroups();
    this.hasLoadedOnce = true;
  }

  private async loadGroups(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    this.needLogin = false;
    try {
      this.groups = await LkongApi.getInstance().getUserFavoriteGroups(0);
    } catch (error) {
      if (error instanceof ApiError && error.kind === ErrorKind.AUTH) {
        this.needLogin = true;
        this.errorMessage = error.message;
      } else if (error instanceof ApiError) {
        this.errorMessage = error.message;
      } else {
        this.errorMessage = '云端收藏夹加载失败，请稍后重试。';
      }
    } finally {
      this.loading = false;
    }
  }

  private goLogin(): void {
    AppNavigator.getInstance().push(Routes.LOGIN);
  }

  private openDetail(group: FavoriteGroup): void {
    const params: FavoriteDetailRouteParams = {
      groupId: group.id,
      title: group.title,
      isMine: true
    };
    AppNavigator.getInstance().push(Routes.FAVORITE_DETAIL, params);
  }

  private openCreateModal(): void {
    if (!CookieStore.getInstance().hasCookie()) {
      showToast(this.getUIContext(), '请先登录');
      this.goLogin();
      return;
    }
    this.editingGroupId = 0;
    this.formTitle = '';
    this.formDesc = '';
    this.formPublic = true;
    this.showGroupModal = true;
  }

  private openEditModal(group: FavoriteGroup): void {
    this.editingGroupId = group.id;
    this.formTitle = group.title;
    this.formDesc = group.description;
    this.formPublic = group.isPublic;
    this.showGroupModal = true;
  }

  private async submitGroupForm(): Promise<void> {
    const title = this.formTitle.trim();
    if (title.length === 0) {
      showToast(this.getUIContext(), '请输入收藏夹名称');
      return;
    }
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    try {
      if (this.editingGroupId === 0) {
        await LkongApi.getInstance().createFavoriteGroup(title, this.formDesc.trim(), this.formPublic);
        showToast(this.getUIContext(), '收藏夹已创建');
      } else {
        await LkongApi.getInstance().editFavoriteGroup(
          this.editingGroupId,
          title,
          this.formDesc.trim(),
          this.formPublic
        );
        showToast(this.getUIContext(), '收藏夹已更新');
      }
      this.showGroupModal = false;
      await this.loadGroups();
    } catch (error) {
      const message = error instanceof ApiError ? error.message : '操作失败，请稍后重试。';
      showToast(this.getUIContext(), message);
    } finally {
      this.submitting = false;
    }
  }

  private async confirmDeleteGroup(): Promise<void> {
    if (this.deleteTarget === null || this.deleting) {
      return;
    }
    this.deleting = true;
    const targetId = this.deleteTarget.id;
    try {
      await LkongApi.getInstance().deleteFavoriteGroup(targetId);
      this.deleteTarget = null;
      showToast(this.getUIContext(), '收藏夹已删除');
      await this.loadGroups();
    } catch (error) {
      const message = error instanceof ApiError ? error.message : '删除失败，请稍后重试。';
      showToast(this.getUIContext(), message);
    } finally {
      this.deleting = false;
    }
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          Row({ space: 8 }) {
            Button('返回')
              .fontSize(12)
              .height(32)
              .backgroundColor(getTheme(this.isDark).accentBg)
              .fontColor(getTheme(this.isDark).accent)
              .onClick(() => {
                AppNavigator.getInstance().pop();
              })
          Text('云端收藏夹')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(getTheme(this.isDark).textPrimary)
            .layoutWeight(1)
          Button('新建')
            .fontSize(12)
            .height(32)
            .backgroundColor(getTheme(this.isDark).accentSolid)
            .fontColor(Color.White)
            .onClick(() => {
              this.openCreateModal();
            })
          Button('刷新')
            .fontSize(12)
            .height(32)
            .backgroundColor(getTheme(this.isDark).accentBg)
            .fontColor(getTheme(this.isDark).accent)
            .onClick(() => {
              this.loadGroups();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })

        if (this.loading) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
              .color(getTheme(this.isDark).accent)
            Text('正在加载云端收藏夹...')
              .fontSize(13)
              .fontColor(getTheme(this.isDark).textSecondary)
              .margin({ top: 8 })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.needLogin) {
          Column() {
            StateView({
              title: '需要登录',
              message: '查看和管理云端收藏夹需要先登录龙空账号。',
              actionText: '去登录',
              onAction: () => {
                this.goLogin();
              }
            })
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
                this.loadGroups();
              }
            })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.groups.length === 0) {
          Column() {
            StateView({
              title: '暂无云端收藏夹',
              message: '点击右上角“新建”创建一个收藏夹，或在帖子详情页收藏时直接创建。',
              actionText: '新建收藏夹',
              onAction: () => {
                this.openCreateModal();
              }
            })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 10 }) {
            ForEach(this.groups, (group: FavoriteGroup) => {
              ListItem() {
                Column({ space: 8 }) {
                  Row({ space: 8 }) {
                    Text(group.title)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(getTheme(this.isDark).textPrimary)
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(group.isPublic ? '公开' : '私密')
                      .fontSize(11)
                      .fontColor(group.isPublic ? getTheme(this.isDark).accent : getTheme(this.isDark).textSecondary)
                      .backgroundColor(
                        group.isPublic ? getTheme(this.isDark).accentBg : getTheme(this.isDark).surfaceMuted
                      )
                      .borderRadius(4)
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  }
                  .width('100%')

                  if (group.description.length > 0) {
                    Text(group.description)
                      .fontSize(13)
                      .fontColor(getTheme(this.isDark).textSecondary)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }

                  Row({ space: 8 }) {
                    Text(`共 ${group.count} 条`)
                      .fontSize(12)
                      .fontColor(getTheme(this.isDark).textMuted)
                    if (group.dateline.length > 0) {
                      Text(formatTime(group.dateline))
                        .fontSize(12)
                        .fontColor(getTheme(this.isDark).textMuted)
                    }
                    Blank()
                    Button('编辑')
                      .fontSize(11)
                      .height(26)
                      .backgroundColor(getTheme(this.isDark).surfaceMuted)
                      .fontColor(getTheme(this.isDark).textPrimary)
                      .onClick(() => {
                        this.openEditModal(group);
                      })
                    Button('删除')
                      .fontSize(11)
                      .height(26)
                      .backgroundColor(getTheme(this.isDark).dangerBg)
                      .fontColor(getTheme(this.isDark).dangerText)
                      .onClick(() => {
                        this.deleteTarget = group;
                      })
                  }
                  .width('100%')
                }
                .width('100%')
                .padding(14)
                .backgroundColor(getTheme(this.isDark).cardBg)
                .borderRadius(12)
                .alignItems(HorizontalAlign.Start)
                .onClick(() => {
                  this.openDetail(group);
                })
              }
            }, (group: FavoriteGroup) =>
              `${this.isDark ? 'd' : 'l'}_${group.id}_${group.count}_${group.title}_${group.isPublic}`
            )
          }
          .layoutWeight(1)
          .padding({ left: 16, right: 16, bottom: 16 })
          .scrollBar(BarState.Auto)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(getTheme(this.isDark).pageBg)

      if (this.showGroupModal) {
        Column() {
          Column({ space: 12 }) {
            Text(this.editingGroupId === 0 ? '新建云端收藏夹' : '编辑收藏夹')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(getTheme(this.isDark).textPrimary)

            TextInput({
              placeholder: '收藏夹名称（必填）',
              text: this.formTitle
            })
              .height(40)
              .fontSize(14)
              .fontColor(getTheme(this.isDark).textPrimary)
              .placeholderColor(getTheme(this.isDark).textMuted)
              .backgroundColor(getTheme(this.isDark).inputBg)
              .onChange((value: string) => {
                this.formTitle = value;
              })

            TextInput({
              placeholder: '简介（选填）',
              text: this.formDesc
            })
              .height(40)
              .fontSize(14)
              .fontColor(getTheme(this.isDark).textPrimary)
              .placeholderColor(getTheme(this.isDark).textMuted)
              .backgroundColor(getTheme(this.isDark).inputBg)
              .onChange((value: string) => {
                this.formDesc = value;
              })

            Row({ space: 8 }) {
              Text('可见性：')
                .fontSize(13)
                .fontColor(getTheme(this.isDark).textSecondary)
              Button('公开')
                .fontSize(12)
                .height(30)
                .backgroundColor(
                  this.formPublic ? getTheme(this.isDark).accentSolid : getTheme(this.isDark).surfaceMuted
                )
                .fontColor(this.formPublic ? Color.White : getTheme(this.isDark).textPrimary)
                .onClick(() => {
                  this.formPublic = true;
                })
              Button('私密')
                .fontSize(12)
                .height(30)
                .backgroundColor(
                  !this.formPublic ? getTheme(this.isDark).accentSolid : getTheme(this.isDark).surfaceMuted
                )
                .fontColor(!this.formPublic ? Color.White : getTheme(this.isDark).textPrimary)
                .onClick(() => {
                  this.formPublic = false;
                })
            }
            .width('100%')

            Row({ space: 10 }) {
              Button('取消')
                .fontSize(13)
                .height(36)
                .layoutWeight(1)
                .backgroundColor(getTheme(this.isDark).surfaceMuted)
                .fontColor(getTheme(this.isDark).textSecondary)
                .onClick(() => {
                  this.showGroupModal = false;
                })
              Button(this.submitting ? '提交中...' : '保存')
                .fontSize(13)
                .height(36)
                .layoutWeight(1)
                .backgroundColor(
                  this.submitting ? getTheme(this.isDark).disabledBtnBg : getTheme(this.isDark).accentSolid
                )
                .fontColor(this.submitting ? getTheme(this.isDark).disabledBtnText : Color.White)
                .enabled(!this.submitting)
                .onClick(() => {
                  this.submitGroupForm();
                })
            }
            .width('100%')
          }
          .width('86%')
          .padding(16)
          .backgroundColor(getTheme(this.isDark).cardBg)
          .borderRadius(14)
          .alignItems(HorizontalAlign.Start)
          .onClick(() => {
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showGroupModal = false;
        })
      }

      if (this.deleteTarget !== null) {
        Column() {
          Column({ space: 12 }) {
            Text('删除收藏夹')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(getTheme(this.isDark).textPrimary)
            Text(`确认删除云端收藏夹「${this.deleteTarget.title}」吗？该操作不可撤销。`)
              .fontSize(13)
              .fontColor(getTheme(this.isDark).textSecondary)
              .lineHeight(20)

            Row({ space: 10 }) {
              Button('取消')
                .fontSize(13)
                .height(36)
                .layoutWeight(1)
                .backgroundColor(getTheme(this.isDark).surfaceMuted)
                .fontColor(getTheme(this.isDark).textSecondary)
                .onClick(() => {
                  this.deleteTarget = null;
                })
              Button(this.deleting ? '删除中...' : '确认删除')
                .fontSize(13)
                .height(36)
                .layoutWeight(1)
                .backgroundColor(getTheme(this.isDark).dangerBg)
                .fontColor(getTheme(this.isDark).dangerText)
                .enabled(!this.deleting)
                .onClick(() => {
                  this.confirmDeleteGroup();
                })
            }
            .width('100%')
          }
          .width('86%')
          .padding(16)
          .backgroundColor(getTheme(this.isDark).cardBg)
          .borderRadius(14)
          .alignItems(HorizontalAlign.Start)
          .onClick(() => {
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.deleteTarget = null;
        })
      }
    }
    .width('100%')
    .height('100%')
    }
    .hideTitleBar(true)
    .onShown(() => {
      if (this.hasLoadedOnce && CookieStore.getInstance().hasCookie() && !this.loading) {
        this.loadGroups();
      }
    })
    .onBackPressed(() => {
      if (this.deleteTarget !== null) {
        this.deleteTarget = null;
        return true;
      }
      if (this.showGroupModal) {
        this.showGroupModal = false;
        return true;
      }
      return false;
    })
  }
}
