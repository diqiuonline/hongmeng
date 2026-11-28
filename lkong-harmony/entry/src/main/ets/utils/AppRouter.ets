export class Routes {
  static readonly LOGIN: string = 'LoginPage';
  static readonly SETTINGS: string = 'SettingsPage';
  static readonly SEARCH: string = 'SearchPage';
  static readonly FAVORITES: string = 'FavoritesPage';
  static readonly FAVORITE_DETAIL: string = 'FavoriteDetailPage';
  static readonly FORUM: string = 'ForumPage';
  static readonly THREAD: string = 'ThreadPage';
  static readonly USER_PROFILE: string = 'UserProfilePage';
  static readonly COMPOSE: string = 'ComposePage';
  static readonly NOTIFICATIONS: string = 'NotificationsPage';
  static readonly MESSAGE_CHAT: string = 'MessageChatPage';
}

export interface ForumRouteParams {
  fid: number;
  name: string;
}

export interface ThreadRouteParams {
  tid: number;
  title: string;
  pid?: string;
}

export interface UserProfileRouteParams {
  uid?: number;
  name?: string;
}

export interface FavoriteDetailRouteParams {
  groupId: number;
  title?: string;
  isMine?: boolean;
}

export interface ComposeRouteParams {
  mode?: string;
  fid?: number;
  forumName?: string;
  tid?: number;
  threadTitle?: string;
  quotePid?: string;
  quoteFloor?: string;
  quoteAuthorName?: string;
  quoteSummary?: string;
  editPid?: string;
  isPrimaryPost?: boolean;
}

export interface MessageChatRouteParams {
  uid: number;
  name?: string;
  avatarUrl?: string;
}

/**
 * 集中式 Navigation 路由栈管理器，替代已废弃的 @kit.ArkUI router 模块。
 */
export class AppNavigator {
  private static instance: AppNavigator = new AppNavigator();
  private stack: NavPathStack = new NavPathStack();
  private onReturnToRootCallback: () => void = () => {
  };

  private constructor() {
    this.stack.setInterception({
      didShow: (
        _from: NavDestinationContext | NavBar,
        to: NavDestinationContext | NavBar,
        _operation: NavigationOperation,
        _isAnimated: boolean
      ) => {
        if (to === 'navBar') {
          this.onReturnToRootCallback();
        }
      }
    });
  }

  static getInstance(): AppNavigator {
    return AppNavigator.instance;
  }

  getStack(): NavPathStack {
    return this.stack;
  }

  setOnReturnToRoot(callback: () => void): void {
    this.onReturnToRootCallback = callback;
  }

  push(name: string, param?: Object): void {
    this.stack.pushPathByName(name, param === undefined ? null : param, true);
  }

  replace(name: string, param?: Object): void {
    this.stack.replacePathByName(name, param === undefined ? null : param, true);
  }

  pop(): void {
    this.stack.pop(true);
  }
}
