import { ChatSession, SessionGroup, UserProfile } from '../model/ChatModels';
import { groupSessionsByTime } from '../utils/TimeUtils';

@Component
export struct SessionDrawer {
  @Prop sessions: ChatSession[] = [];
  @Prop currentSessionId: string = '';
  @Prop hasMore: boolean = false;
  @Prop loadingSessions: boolean = false;
  @Prop loggedIn: boolean = false;
  @Prop userProfile: UserProfile | null = null;
  @State searchKeyword: string = '';
  @State renameTarget: ChatSession | null = null;
  @State renameDraft: string = '';
  @State deleteTarget: ChatSession | null = null;

  onSelectSession: (session: ChatSession) => void = () => {};
  onNewChat: () => void = () => {};
  onLoadMore: () => void = () => {};
  onRefresh: () => void = () => {};
  onRenameSession: (sessionId: string, newTitle: string) => void = () => {};
  onDeleteSession: (sessionId: string) => void = () => {};
  onOpenLogin: () => void = () => {};
  onOpenSettings: () => void = () => {};

  private filteredGroups(): SessionGroup[] {
    const keyword = this.searchKeyword.trim().toLowerCase();
    const list = keyword.length === 0
      ? this.sessions
      : this.sessions.filter((s: ChatSession) => s.title.toLowerCase().includes(keyword));
    return groupSessionsByTime(list);
  }

  private userDisplayName(): string {
    if (!this.loggedIn) {
      return '未登录 · 点击登录';
    }
    if (this.userProfile !== null && this.userProfile.name.length > 0) {
      return this.userProfile.name;
    }
    return 'DeepSeek 用户';
  }

  private userSubLabel(): string {
    if (!this.loggedIn) {
      return '登录后同步全部历史对话';
    }
    if (this.userProfile !== null) {
      if (this.userProfile.email.length > 0) {
        return this.userProfile.email;
      }
      if (this.userProfile.mobileNumber.length > 0) {
        return this.userProfile.mobileNumber;
      }
    }
    return '网页端会话已连接';
  }

  @Builder
  private SessionItemMenuBuilder(session: ChatSession) {
    Menu() {
      MenuItem({ content: '重命名' })
        .onClick(() => {
          this.renameTarget = session;
          this.renameDraft = session.title;
        })
      MenuItem({ content: '删除对话' })
        .contentFontColor($r('app.color.danger_color'))
        .onClick(() => {
          this.deleteTarget = session;
        })
    }
  }

  build() {
    Stack() {
      Column() {
        Row({ space: 8 }) {
          Text('DeepSeek')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)

          Button('＋ 新对话')
            .fontSize(12)
            .height(32)
            .padding({ left: 12, right: 12 })
            .backgroundColor($r('app.color.bg_pill_active'))
            .fontColor($r('app.color.accent_primary'))
            .borderRadius(16)
            .onClick(() => {
              this.onNewChat();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 10 })

        Column() {
          TextInput({ placeholder: '搜索历史对话...', text: this.searchKeyword })
            .fontSize(13)
            .height(36)
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_muted'))
            .backgroundColor($r('app.color.bg_input'))
            .borderRadius(18)
            .padding({ left: 14, right: 14 })
            .onChange((val: string) => {
              this.searchKeyword = val;
            })
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 10 })

        if (!this.loggedIn) {
          Column({ space: 10 }) {
            Text('登录后可同步网页端与安卓端历史对话记录')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
            Button('立即登录')
              .fontSize(13)
              .height(34)
              .padding({ left: 20, right: 20 })
              .backgroundColor($r('app.color.accent_primary'))
              .fontColor(Color.White)
              .borderRadius(17)
              .onClick(() => {
                this.onOpenLogin();
              })
          }
          .layoutWeight(1)
          .width('100%')
          .padding(20)
          .justifyContent(FlexAlign.Center)
        } else if (this.loadingSessions && this.sessions.length === 0) {
          Column({ space: 8 }) {
            LoadingProgress()
              .width(32)
              .height(32)
              .color($r('app.color.accent_primary'))
            Text('正在加载历史会话...')
              .fontSize(12)
              .fontColor($r('app.color.text_muted'))
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.filteredGroups().length === 0) {
          Column({ space: 8 }) {
            Text(this.searchKeyword.trim().length > 0 ? '没有匹配的对话' : '暂无历史对话')
              .fontSize(13)
              .fontColor($r('app.color.text_muted'))
            if (this.searchKeyword.trim().length === 0) {
              Button('刷新列表')
                .fontSize(12)
                .height(30)
                .backgroundColor($r('app.color.bg_pill'))
                .fontColor($r('app.color.text_secondary'))
                .onClick(() => {
                  this.onRefresh();
                })
            }
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 4 }) {
            ForEach(this.filteredGroups(), (group: SessionGroup) => {
              ListItem() {
                Column({ space: 4 }) {
                  Text(group.label)
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_muted'))
                    .padding({ left: 10, top: 8, bottom: 4 })
                    .width('100%')

                  ForEach(group.sessions, (session: ChatSession) => {
                    Row({ space: 6 }) {
                      Text(session.title)
                        .fontSize(14)
                        .fontWeight(
                          session.id === this.currentSessionId ? FontWeight.Medium : FontWeight.Normal
                        )
                        .fontColor(
                          session.id === this.currentSessionId
                            ? $r('app.color.accent_primary')
                            : $r('app.color.text_primary')
                        )
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)

                      Text('⋯')
                        .fontSize(16)
                        .fontColor($r('app.color.text_muted'))
                        .padding({ left: 6, right: 6, top: 4, bottom: 4 })
                        .bindMenu(this.SessionItemMenuBuilder(session))
                    }
                    .width('100%')
                    .padding({ left: 10, right: 6, top: 9, bottom: 9 })
                    .backgroundColor(
                      session.id === this.currentSessionId
                        ? $r('app.color.bg_pill_active')
                        : Color.Transparent
                    )
                    .borderRadius(10)
                    .onClick(() => {
                      this.onSelectSession(session);
                    })
                  }, (session: ChatSession) => `${session.id}_${session.title}_${session.updatedAt}`)
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
            }, (group: SessionGroup) => `${group.label}_${group.sessions.length}`)

            if (this.hasMore) {
              ListItem() {
                Row() {
                  if (this.loadingSessions) {
                    LoadingProgress()
                      .width(20)
                      .height(20)
                      .color($r('app.color.accent_primary'))
                  } else {
                    Text('加载更多')
                      .fontSize(12)
                      .fontColor($r('app.color.accent_primary'))
                      .onClick(() => {
                        this.onLoadMore();
                      })
                  }
                }
                .width('100%')
                .padding(12)
                .justifyContent(FlexAlign.Center)
              }
            }
          }
          .layoutWeight(1)
          .padding({ left: 10, right: 10, bottom: 8 })
          .scrollBar(BarState.Auto)
          .onReachEnd(() => {
            if (this.hasMore && !this.loadingSessions && this.searchKeyword.trim().length === 0) {
              this.onLoadMore();
            }
          })
        }

        Divider()
          .color($r('app.color.border_color'))

        Row({ space: 10 }) {
          Stack() {
            Circle({ width: 34, height: 34 })
              .fill(this.loggedIn ? $r('app.color.accent_primary') : $r('app.color.bg_pill'))
            Text(this.loggedIn ? this.userDisplayName().substring(0, 1).toUpperCase() : '?')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.loggedIn ? Color.White : $r('app.color.text_secondary'))
          }

          Column({ space: 2 }) {
            Text(this.userDisplayName())
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.userSubLabel())
              .fontSize(11)
              .fontColor($r('app.color.text_muted'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .onClick(() => {
            if (this.loggedIn) {
              this.onOpenSettings();
            } else {
              this.onOpenLogin();
            }
          })

          Button('⚙')
            .fontSize(16)
            .width(34)
            .height(34)
            .padding(0)
            .backgroundColor($r('app.color.bg_pill'))
            .fontColor($r('app.color.text_primary'))
            .borderRadius(17)
            .onClick(() => {
              this.onOpenSettings();
            })
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 10, bottom: 14 })
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_surface'))

      if (this.renameTarget !== null) {
        Column() {
          Column({ space: 12 }) {
            Text('重命名对话')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            TextInput({ text: this.renameDraft, placeholder: '输入新标题' })
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.bg_input'))
              .borderRadius(10)
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .onChange((val: string) => {
                this.renameDraft = val;
              })
            Row({ space: 10 }) {
              Button('取消')
                .fontSize(13)
                .layoutWeight(1)
                .backgroundColor($r('app.color.bg_pill'))
                .fontColor($r('app.color.text_primary'))
                .onClick(() => {
                  this.renameTarget = null;
                })
              Button('确认')
                .fontSize(13)
                .layoutWeight(1)
                .backgroundColor($r('app.color.accent_primary'))
                .fontColor(Color.White)
                .onClick(() => {
                  const target = this.renameTarget;
                  const title = this.renameDraft.trim();
                  this.renameTarget = null;
                  if (target !== null && title.length > 0) {
                    this.onRenameSession(target.id, title);
                  }
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

      if (this.deleteTarget !== null) {
        Column() {
          Column({ space: 12 }) {
            Text('删除对话')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text(`确认删除“${this.deleteTarget.title}”？删除后不可恢复。`)
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
            Row({ space: 10 }) {
              Button('取消')
                .fontSize(13)
                .layoutWeight(1)
                .backgroundColor($r('app.color.bg_pill'))
                .fontColor($r('app.color.text_primary'))
                .onClick(() => {
                  this.deleteTarget = null;
                })
              Button('删除')
                .fontSize(13)
                .layoutWeight(1)
                .backgroundColor($r('app.color.danger_color'))
                .fontColor(Color.White)
                .onClick(() => {
                  const target = this.deleteTarget;
                  this.deleteTarget = null;
                  if (target !== null) {
                    this.onDeleteSession(target.id);
                  }
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
