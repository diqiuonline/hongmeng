import {
  ApiError,
  CurrentUser,
  ErrorKind,
  FavoriteGroup,
  FavoriteGroupDetailData,
  FavoriteGroupOption,
  Forum,
  ForumPageData,
  HomeData,
  HotThread,
  LoginResult,
  PunchInfo,
  SearchForumItem,
  SearchThreadsResult,
  SearchUserItem,
  ThreadPageData,
  ThreadSummary,
  UserProfilePageData
} from '../model/Models';
import { CookieStore } from '../store/CookieStore';
import { GraphqlClient } from './GraphqlClient';
import {
  CREATE_FAVORITE_GROUP_MUTATION,
  DEL_FAVORITE_GROUP_MUTATION,
  EDIT_FAVORITE_GROUP_MUTATION,
  FAVORITE_POST_MUTATION,
  GET_ME_QUERY,
  GET_USER_PUNCH_QUERY,
  LOGIN_MUTATION,
  MY_FAVORITE_GROUP_LIST_QUERY,
  PUNCH_MUTATION,
  SEARCH_FORUMS_QUERY,
  SEARCH_THREADS_QUERY,
  SEARCH_USERS_QUERY,
  VIEW_FAVORITE_GROUP_DETAIL_QUERY,
  VIEW_FORUM_PAGE_QUERY,
  VIEW_HOT_THREADS_QUERY,
  VIEW_THREAD_QUERY,
  VIEW_USER_FAVORITE_GROUPS_QUERY,
  VIEW_USER_PROFILE_PAGE_QUERY,
  VIEW_USER_THREADS_PAGE_QUERY
} from './GraphqlQueries';
import {
  parseCreatedFavoriteGroup,
  parseFavoriteGroupDetail,
  parseFavoriteGroupOptions,
  parseFavoriteGroups,
  parseForumPageGraphql,
  parseHomeData,
  parseHotThreads,
  parseLoginResult,
  parseMutationOk,
  parsePunchResult,
  parseSearchForums,
  parseSearchThreads,
  parseSearchUsers,
  parseThreadPageGraphql,
  parseUserProfilePage,
  parseUserPunch,
  parseUserThreads
} from './GraphqlParser';

interface LoginVariables {
  email: string;
  password: string;
}

interface ForumPageVariables {
  fid: number;
  page: number;
  action: string;
}

interface ThreadVariables {
  tid: number;
  page: number;
}

interface ThreadAuthorVariables {
  tid: number;
  page: number;
  authorid: number;
}

interface SearchThreadsVariables {
  text: string;
  sort: string;
}

interface SearchThreadsCursorVariables {
  text: string;
  sort: string;
  searchAfter: string;
}

interface SearchKeywordVariables {
  text: string;
}

interface UserProfilePageVariables {
  uid: number;
  page: number;
}

interface UserUidVariables {
  uid: number;
}

interface FavoriteGroupDetailVariables {
  groupid: number;
  page: number;
}

interface MyFavoriteGroupListVariables {
  tid: number;
  pid: string;
}

interface FavoritePostVariables {
  groupid: number;
  pid: string;
  tid: number;
  undo: boolean;
}

interface CreateFavoriteGroupVariables {
  title: string;
  description: string;
  isPublic: boolean;
}

interface EditFavoriteGroupVariables {
  groupid: number;
  title: string;
  description: string;
  isPublic: boolean;
}

interface DelFavoriteGroupVariables {
  groupid: number;
}

/**
 * 龙空数据入口，全部通过官方 GraphQL 获取。
 */
export class LkongApi {
  private static instance: LkongApi = new LkongApi();
  private currentUser: CurrentUser | null = null;

  static getInstance(): LkongApi {
    return LkongApi.instance;
  }

  getCachedCurrentUser(): CurrentUser | null {
    return this.currentUser;
  }

  clearCurrentUser(): void {
    this.currentUser = null;
  }

  /**
   * 账号密码登录。密码只进入本次 GraphQL 请求体，不写入本地存储。
   * 如果账号启用了二次验证（twoWay），当前客户端暂不支持。
   */
  async login(email: string, password: string): Promise<LoginResult> {
    const loginVariables: LoginVariables = {
      email: email,
      password: password
    };

    const result = await GraphqlClient.getInstance().request(
      'Login',
      loginVariables,
      LOGIN_MUTATION,
      false
    );

    const login = parseLoginResult(result.data);
    if (login.twoWay) {
      throw new ApiError(ErrorKind.AUTH, '该账号需要二次验证，当前客户端暂不支持。');
    }

    const cookie = extractEggSession(result.cookies);
    if (cookie.length === 0) {
      throw new ApiError(ErrorKind.AUTH, '登录成功但未获取到会话 Cookie，请稍后重试。');
    }

    await CookieStore.getInstance().setCookie(cookie);
    if (login.uid > 0) {
      this.currentUser = {
        uid: login.uid,
        name: login.name,
        avatar: ''
      };
    }
    return login;
  }

  /**
   * GetMe 在未登录时也能返回 commonNavbars；登录后同时返回当前用户信息 me。
   */
  async getHomeData(): Promise<HomeData> {
    const emptyVariables: Record<string, Object> = {};
    const result = await GraphqlClient.getInstance().request(
      'GetMe',
      emptyVariables,
      GET_ME_QUERY,
      false
    );
    const home = parseHomeData(result.data);
    if (home.me.uid > 0 && CookieStore.getInstance().hasCookie()) {
      this.currentUser = home.me;
    } else {
      this.currentUser = null;
    }
    return home;
  }

  async getHomeForums(): Promise<Forum[]> {
    const home = await this.getHomeData();
    return home.forums;
  }

  async ensureCurrentUser(): Promise<CurrentUser> {
    if (!CookieStore.getInstance().hasCookie()) {
      throw new ApiError(ErrorKind.AUTH, '请先登录。');
    }
    if (this.currentUser !== null && this.currentUser.uid > 0) {
      return this.currentUser;
    }
    const home = await this.getHomeData();
    if (home.me.uid <= 0) {
      throw new ApiError(ErrorKind.AUTH, '登录态已失效，请重新登录。');
    }
    return home.me;
  }

  async getUserPunch(): Promise<PunchInfo> {
    const emptyVariables: Record<string, Object> = {};
    const result = await GraphqlClient.getInstance().request(
      'GetUserPunch',
      emptyVariables,
      GET_USER_PUNCH_QUERY,
      true
    );
    return parseUserPunch(result.data);
  }

  async punch(): Promise<PunchInfo> {
    const emptyVariables: Record<string, Object> = {};
    const result = await GraphqlClient.getInstance().request(
      'Punch',
      emptyVariables,
      PUNCH_MUTATION,
      true
    );
    return parsePunchResult(result.data);
  }

  async getHotThreads(): Promise<HotThread[]> {
    const emptyVariables: Record<string, Object> = {};
    const result = await GraphqlClient.getInstance().request(
      'ViewHotThreads',
      emptyVariables,
      VIEW_HOT_THREADS_QUERY,
      true
    );
    return parseHotThreads(result.data);
  }

  async getForumThreads(fid: number, page: number): Promise<ForumPageData> {
    const safePage = page < 1 ? 1 : page;
    const forumVariables: ForumPageVariables = {
      fid: fid,
      page: safePage,
      action: ''
    };
    const result = await GraphqlClient.getInstance().request(
      'ViewForumPage',
      forumVariables,
      VIEW_FORUM_PAGE_QUERY,
      true
    );
    const threads = parseForumPageGraphql(result.data);
    const pageData: ForumPageData = {
      forumName: '',
      threads: threads,
      page: safePage
    };
    return pageData;
  }

  async getThreadDetail(tid: number, page: number, authorId: number = 0): Promise<ThreadPageData> {
    const safePage = page < 1 ? 1 : page;
    let threadVariables: Object;
    if (authorId > 0) {
      const authorVars: ThreadAuthorVariables = {
        tid: tid,
        page: safePage,
        authorid: authorId
      };
      threadVariables = authorVars;
    } else {
      const baseVars: ThreadVariables = {
        tid: tid,
        page: safePage
      };
      threadVariables = baseVars;
    }
    const result = await GraphqlClient.getInstance().request(
      'ViewThread',
      threadVariables,
      VIEW_THREAD_QUERY,
      true
    );
    return parseThreadPageGraphql(result.data, tid, safePage);
  }

  async searchThreads(text: string, sort: string, searchAfter: string = ''): Promise<SearchThreadsResult> {
    let variables: Object;
    if (searchAfter.length > 0) {
      const cursorVars: SearchThreadsCursorVariables = {
        text: text,
        sort: sort,
        searchAfter: searchAfter
      };
      variables = cursorVars;
    } else {
      const baseVars: SearchThreadsVariables = {
        text: text,
        sort: sort
      };
      variables = baseVars;
    }
    const result = await GraphqlClient.getInstance().request(
      'SearchThreads',
      variables,
      SEARCH_THREADS_QUERY,
      true
    );
    return parseSearchThreads(result.data);
  }

  async searchForums(text: string): Promise<SearchForumItem[]> {
    const variables: SearchKeywordVariables = {
      text: text
    };
    const result = await GraphqlClient.getInstance().request(
      'SearchForums',
      variables,
      SEARCH_FORUMS_QUERY,
      true
    );
    return parseSearchForums(result.data);
  }

  async searchUsers(text: string): Promise<SearchUserItem[]> {
    const variables: SearchKeywordVariables = {
      text: text
    };
    const result = await GraphqlClient.getInstance().request(
      'SearchUsers',
      variables,
      SEARCH_USERS_QUERY,
      true
    );
    return parseSearchUsers(result.data);
  }

  async getUserProfilePage(uid: number, page: number = 1): Promise<UserProfilePageData> {
    const safePage = page < 1 ? 1 : page;
    let targetUid = uid;
    if (targetUid <= 0) {
      const me = await this.ensureCurrentUser();
      targetUid = me.uid;
    }
    const variables: UserProfilePageVariables = {
      uid: targetUid,
      page: safePage
    };
    const result = await GraphqlClient.getInstance().request(
      'ViewUserProfilePage',
      variables,
      VIEW_USER_PROFILE_PAGE_QUERY,
      true
    );
    return parseUserProfilePage(result.data, targetUid, safePage);
  }

  async getUserThreads(uid: number, page: number): Promise<ThreadSummary[]> {
    const safePage = page < 1 ? 1 : page;
    let targetUid = uid;
    if (targetUid <= 0) {
      const me = await this.ensureCurrentUser();
      targetUid = me.uid;
    }
    const variables: UserProfilePageVariables = {
      uid: targetUid,
      page: safePage
    };
    const result = await GraphqlClient.getInstance().request(
      'ViewUserThreadsPage',
      variables,
      VIEW_USER_THREADS_PAGE_QUERY,
      true
    );
    return parseUserThreads(result.data);
  }

  async getUserFavoriteGroups(uid: number): Promise<FavoriteGroup[]> {
    let targetUid = uid;
    if (targetUid <= 0) {
      const me = await this.ensureCurrentUser();
      targetUid = me.uid;
    }
    const variables: UserUidVariables = {
      uid: targetUid
    };
    const result = await GraphqlClient.getInstance().request(
      'ViewUserFavoriteGroups',
      variables,
      VIEW_USER_FAVORITE_GROUPS_QUERY,
      true
    );
    return parseFavoriteGroups(result.data);
  }

  async getFavoriteGroupDetail(groupId: number, page: number): Promise<FavoriteGroupDetailData> {
    const safePage = page < 1 ? 1 : page;
    const variables: FavoriteGroupDetailVariables = {
      groupid: groupId,
      page: safePage
    };
    const result = await GraphqlClient.getInstance().request(
      'ViewFavoriteGroup',
      variables,
      VIEW_FAVORITE_GROUP_DETAIL_QUERY,
      true
    );
    return parseFavoriteGroupDetail(result.data, safePage);
  }

  async getMyFavoriteGroupList(tid: number, pid: string): Promise<FavoriteGroupOption[]> {
    const variables: MyFavoriteGroupListVariables = {
      tid: tid,
      pid: pid
    };
    const result = await GraphqlClient.getInstance().request(
      'MyFavoriteGroupList',
      variables,
      MY_FAVORITE_GROUP_LIST_QUERY,
      true
    );
    return parseFavoriteGroupOptions(result.data);
  }

  async favoritePost(groupId: number, tid: number, pid: string, undo: boolean): Promise<boolean> {
    const variables: FavoritePostVariables = {
      groupid: groupId,
      pid: pid,
      tid: tid,
      undo: undo
    };
    const result = await GraphqlClient.getInstance().request(
      'FavoritePost',
      variables,
      FAVORITE_POST_MUTATION,
      true
    );
    return parseMutationOk(result.data, 'favoritePost');
  }

  async createFavoriteGroup(title: string, description: string, isPublic: boolean): Promise<FavoriteGroupOption> {
    const variables: CreateFavoriteGroupVariables = {
      title: title,
      description: description,
      isPublic: isPublic
    };
    const result = await GraphqlClient.getInstance().request(
      'CreateFavoriteGroup',
      variables,
      CREATE_FAVORITE_GROUP_MUTATION,
      true
    );
    return parseCreatedFavoriteGroup(result.data);
  }

  async editFavoriteGroup(
    groupId: number,
    title: string,
    description: string,
    isPublic: boolean
  ): Promise<boolean> {
    const variables: EditFavoriteGroupVariables = {
      groupid: groupId,
      title: title,
      description: description,
      isPublic: isPublic
    };
    const result = await GraphqlClient.getInstance().request(
      'EditFavoriteGroup',
      variables,
      EDIT_FAVORITE_GROUP_MUTATION,
      true
    );
    return parseMutationOk(result.data, 'editFavoriteGroup');
  }

  async deleteFavoriteGroup(groupId: number): Promise<boolean> {
    const variables: DelFavoriteGroupVariables = {
      groupid: groupId
    };
    const result = await GraphqlClient.getInstance().request(
      'DelFavoriteGroup',
      variables,
      DEL_FAVORITE_GROUP_MUTATION,
      true
    );
    return parseMutationOk(result.data, 'delFavoriteGroup');
  }
}

/**
 * 登录响应的 Set-Cookie 中包含 EGG_SESS。
 * 只提取这个会话 Cookie，不保存账号、密码或其他无关字段。
 */
function extractEggSession(cookies: string): string {
  const match = /EGG_SESS=([^;,\s]+)/.exec(cookies);
  if (match === null) {
    return '';
  }
  return `EGG_SESS=${match[1]}`;
}
