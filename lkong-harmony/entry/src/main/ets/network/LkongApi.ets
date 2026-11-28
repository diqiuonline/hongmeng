import {
  ApiError,
  AtMeListResult,
  CurrentUser,
  EditablePostData,
  ErrorKind,
  FanNoticeListResult,
  FavoriteGroup,
  FavoriteGroupDetailData,
  FavoriteGroupOption,
  Forum,
  ForumPageData,
  HomeData,
  HotThread,
  LoginResult,
  NoticeCount,
  NoticeListResult,
  PmConversationListResult,
  PmMessageItem,
  PmMessageListResult,
  PostItem,
  PostRateItem,
  PunchInfo,
  RateNoticeListResult,
  SearchForumItem,
  SearchThreadsResult,
  SearchUserItem,
  ThreadPageData,
  ThreadSummary,
  UploadedImage,
  UserPostItem,
  UserProfilePageData
} from '../model/Models';
import { CookieStore } from '../store/CookieStore';
import { AppConfig } from '../utils/AppConfig';
import { GraphqlClient } from './GraphqlClient';
import { HttpClient } from './HttpClient';
import { asRecord, pickNumber, pickString } from './JsonUtils';
import {
  BASE_POST_QUERY,
  CREATE_FAVORITE_GROUP_MUTATION,
  DEL_FAVORITE_GROUP_MUTATION,
  DEL_MESSAGE_MUTATION,
  DEL_USER_MESSAGE_MUTATION,
  EDIT_FAVORITE_GROUP_MUTATION,
  EDIT_POST_MUTATION,
  FAVORITE_POST_MUTATION,
  FOLLOW_USER_MUTATION,
  GET_ME_QUERY,
  GET_NOTICE_COUNT_QUERY,
  GET_USER_PUNCH_QUERY,
  LOGIN_MUTATION,
  MY_FAVORITE_GROUP_LIST_QUERY,
  NEW_THREAD_MUTATION,
  PUNCH_MUTATION,
  RATE_POST_MUTATION,
  REPLY_THREAD_MUTATION,
  SEARCH_FORUMS_QUERY,
  SEARCH_THREADS_QUERY,
  SEARCH_USERS_QUERY,
  SEND_IMAGE_MESSAGE_MUTATION,
  SEND_MESSAGE_MUTATION,
  TWO_WAY_LOGIN_MUTATION,
  VIEW_ATME_QUERY,
  VIEW_FANS_NOTICE_QUERY,
  VIEW_FAVORITE_GROUP_DETAIL_QUERY,
  VIEW_FORUM_HOT_THREADS_QUERY,
  VIEW_FORUM_PAGE_QUERY,
  VIEW_HOT_THREADS_QUERY,
  VIEW_LAST_USERS_MESSAGES_QUERY,
  VIEW_NOTICES_QUERY,
  VIEW_RATE_NOTICE_QUERY,
  VIEW_THREAD_QUERY,
  VIEW_USER_FAVORITE_GROUPS_QUERY,
  VIEW_USER_MESSAGES_QUERY,
  VIEW_USER_POSTS_PAGE_QUERY,
  VIEW_USER_PROFILE_PAGE_QUERY,
  VIEW_USER_THREADS_PAGE_QUERY
} from './GraphqlQueries';
import {
  parseAtMeList,
  parseCreatedFavoriteGroup,
  parseEditablePost,
  parseFansNoticeList,
  parseFavoriteGroupDetail,
  parseFavoriteGroupOptions,
  parseFavoriteGroups,
  parseForumPageGraphql,
  parseHomeData,
  parseHotThreads,
  parseLoginResult,
  parseMutationOk,
  parseNewThreadTid,
  parseNoticeCount,
  parseNoticeList,
  parsePmConversationList,
  parsePmMessageList,
  parsePunchResult,
  parseRateNoticeList,
  parseRateResult,
  parseReplyPost,
  parseSearchForums,
  parseSearchThreads,
  parseSearchUsers,
  parseSinglePmMessage,
  parseThreadPageGraphql,
  parseTwoWayLoginResult,
  parseUserPosts,
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

interface ForumIdVariables {
  fid: number;
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

interface ThreadPidVariables {
  tid: number;
  pid: string;
}

interface ThreadPidAuthorVariables {
  tid: number;
  pid: string;
  authorid: number;
}

interface ReplyThreadVariables {
  tid: number;
  content: string;
}

interface ReplyQuoteVariables {
  tid: number;
  content: string;
  pid: string;
}

interface NewThreadVariables {
  fid: number;
  title: string;
  content: string;
}

interface RatePostVariables {
  tid: number;
  pid: string;
  num: number;
  reason: string;
}

interface DateCursorVariables {
  date: string;
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

interface UserPostsPageVariables {
  uid: number;
  isDigest: boolean;
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

interface TwoWayLoginVariables {
  twoWay: string;
  code: string;
  serverTime: string;
}

interface BasePostVariables {
  tid: number;
  pid: string;
}

interface EditPostVariables {
  tid: number;
  pid: string;
  content: string;
}

interface EditPrimaryPostVariables {
  tid: number;
  pid: string;
  content: string;
  title: string;
}

interface FollowUserVariables {
  uid: number;
  follow: boolean;
}

interface PmConversationDeleteVariables {
  toUid: number;
}

interface PmMessagesVariables {
  uid: number;
  date?: string;
}

interface SendMessageVariables {
  uid: number;
  content: string;
}

interface SendImageMessageVariables {
  uid: number;
  imageKey: string;
}

interface DeleteMessageVariables {
  uid: number;
  id: string;
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
   * 如果账号启用了二次验证（twoWay 非空），返回 token 与 serverTime 由登录页完成第二步验证。
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
    if (login.twoWay.length > 0) {
      return login;
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

  async twoWayLogin(twoWay: string, code: string, serverTime: string): Promise<LoginResult> {
    const variables: TwoWayLoginVariables = {
      twoWay: twoWay,
      code: code,
      serverTime: serverTime
    };

    const result = await GraphqlClient.getInstance().request(
      'TwoWayLogin',
      variables,
      TWO_WAY_LOGIN_MUTATION,
      false
    );

    const login = parseTwoWayLoginResult(result.data);
    const cookie = extractEggSession(result.cookies);
    if (cookie.length === 0) {
      throw new ApiError(ErrorKind.AUTH, '二次验证成功但未获取到会话 Cookie，请稍后重试。');
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

  async getForumHotThreads(fid: number): Promise<HotThread[]> {
    const variables: ForumIdVariables = {
      fid: fid
    };
    const result = await GraphqlClient.getInstance().request(
      'ViewForumHotThreads',
      variables,
      VIEW_FORUM_HOT_THREADS_QUERY,
      true
    );
    return parseHotThreads(result.data);
  }

  async getForumThreads(fid: number, page: number, action: string = ''): Promise<ForumPageData> {
    const safePage = page < 1 ? 1 : page;
    const forumVariables: ForumPageVariables = {
      fid: fid,
      page: safePage,
      action: action
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

  async getThreadDetail(
    tid: number,
    page: number,
    authorId: number = 0,
    targetPid: string = ''
  ): Promise<ThreadPageData> {
    const safePage = page < 1 ? 1 : page;
    let threadVariables: Object;
    if (targetPid.length > 0 && authorId > 0) {
      const pidAuthorVars: ThreadPidAuthorVariables = {
        tid: tid,
        pid: targetPid,
        authorid: authorId
      };
      threadVariables = pidAuthorVars;
    } else if (targetPid.length > 0) {
      const pidVars: ThreadPidVariables = {
        tid: tid,
        pid: targetPid
      };
      threadVariables = pidVars;
    } else if (authorId > 0) {
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

  async getUserPosts(uid: number, page: number, isDigest: boolean = false): Promise<UserPostItem[]> {
    const safePage = page < 1 ? 1 : page;
    let targetUid = uid;
    if (targetUid <= 0) {
      const me = await this.ensureCurrentUser();
      targetUid = me.uid;
    }
    const variables: UserPostsPageVariables = {
      uid: targetUid,
      isDigest: isDigest,
      page: safePage
    };
    const result = await GraphqlClient.getInstance().request(
      'ViewUserContentsPage',
      variables,
      VIEW_USER_POSTS_PAGE_QUERY,
      true
    );
    return parseUserPosts(result.data);
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

  async replyThread(tid: number, contentJson: string, quotePid: string = ''): Promise<PostItem> {
    let variables: Object;
    if (quotePid.length > 0) {
      const quoteVars: ReplyQuoteVariables = {
        tid: tid,
        content: contentJson,
        pid: quotePid
      };
      variables = quoteVars;
    } else {
      const baseVars: ReplyThreadVariables = {
        tid: tid,
        content: contentJson
      };
      variables = baseVars;
    }
    const result = await GraphqlClient.getInstance().request(
      'Reply',
      variables,
      REPLY_THREAD_MUTATION,
      true
    );
    const post = parseReplyPost(result.data);
    if (post.pid.length === 0) {
      throw new ApiError(ErrorKind.PARSE, '回帖结果解析失败，请刷新帖子确认是否已发送。');
    }
    return post;
  }

  async createThread(fid: number, title: string, contentJson: string): Promise<number> {
    const variables: NewThreadVariables = {
      fid: fid,
      title: title,
      content: contentJson
    };
    const result = await GraphqlClient.getInstance().request(
      'NewThread',
      variables,
      NEW_THREAD_MUTATION,
      true
    );
    const tid = parseNewThreadTid(result.data);
    if (tid <= 0) {
      throw new ApiError(ErrorKind.PARSE, '发帖结果未返回有效主题 ID，请返回版块刷新查看。');
    }
    return tid;
  }

  async ratePost(tid: number, pid: string, num: number, reason: string): Promise<PostRateItem> {
    const variables: RatePostVariables = {
      tid: tid,
      pid: pid,
      num: num,
      reason: reason
    };
    const result = await GraphqlClient.getInstance().request(
      'Rate',
      variables,
      RATE_POST_MUTATION,
      true
    );
    return parseRateResult(result.data);
  }

  async uploadImageBytes(data: ArrayBuffer, fileName: string, contentType: string): Promise<UploadedImage> {
    const response = await HttpClient.getInstance().uploadImage(
      AppConfig.UPLOAD_URL,
      data,
      fileName,
      contentType
    );
    let parsed: Record<string, Object> = {};
    try {
      parsed = asRecord(JSON.parse(response.body) as Object);
    } catch (error) {
      if (response.statusCode !== 200) {
        throw new ApiError(ErrorKind.HTTP, `图片上传失败（HTTP ${response.statusCode}）`, response.statusCode);
      }
      throw new ApiError(ErrorKind.PARSE, '图片上传返回数据无法解析。');
    }

    const errMsg = pickString(parsed, ['error']);
    if (errMsg.length > 0) {
      const normalized = errMsg.toLowerCase();
      if (normalized.includes('not login') || errMsg.includes('登录')) {
        throw new ApiError(ErrorKind.AUTH, '登录态已失效，请重新登录后再上传图片。');
      }
      throw new ApiError(ErrorKind.HTTP, errMsg);
    }

    const key = pickString(parsed, ['key']);
    if (key.length === 0) {
      throw new ApiError(ErrorKind.PARSE, '图床未返回有效图片 key。');
    }
    const uploaded: UploadedImage = {
      key: key,
      width: pickNumber(parsed, ['width']),
      height: pickNumber(parsed, ['height'])
    };
    return uploaded;
  }

  async getNoticeCount(): Promise<NoticeCount> {
    const emptyVariables: Record<string, Object> = {};
    const result = await GraphqlClient.getInstance().request(
      'GetNoticeCount',
      emptyVariables,
      GET_NOTICE_COUNT_QUERY,
      true
    );
    return parseNoticeCount(result.data);
  }

  private buildDateVariables(date: string): Object {
    if (date.length > 0) {
      const cursorVars: DateCursorVariables = {
        date: date
      };
      return cursorVars;
    }
    const emptyVars: Record<string, Object> = {};
    return emptyVars;
  }

  async getNotices(date: string = ''): Promise<NoticeListResult> {
    const result = await GraphqlClient.getInstance().request(
      'ViewNotices',
      this.buildDateVariables(date),
      VIEW_NOTICES_QUERY,
      true
    );
    return parseNoticeList(result.data);
  }

  async getAtMe(date: string = ''): Promise<AtMeListResult> {
    const result = await GraphqlClient.getInstance().request(
      'ViewAtMe',
      this.buildDateVariables(date),
      VIEW_ATME_QUERY,
      true
    );
    return parseAtMeList(result.data);
  }

  async getRateNotices(date: string = ''): Promise<RateNoticeListResult> {
    const result = await GraphqlClient.getInstance().request(
      'ViewRateNotice',
      this.buildDateVariables(date),
      VIEW_RATE_NOTICE_QUERY,
      true
    );
    return parseRateNoticeList(result.data);
  }

  async getFansNotices(date: string = ''): Promise<FanNoticeListResult> {
    const result = await GraphqlClient.getInstance().request(
      'ViewFansNotice',
      this.buildDateVariables(date),
      VIEW_FANS_NOTICE_QUERY,
      true
    );
    return parseFansNoticeList(result.data);
  }

  async getPostForEdit(tid: number, pid: string): Promise<EditablePostData> {
    const variables: BasePostVariables = {
      tid: tid,
      pid: pid
    };
    const result = await GraphqlClient.getInstance().request(
      'BasePost',
      variables,
      BASE_POST_QUERY,
      true
    );
    return parseEditablePost(result.data, tid, pid);
  }

  async editPost(tid: number, pid: string, contentJson: string, title?: string): Promise<boolean> {
    let variables: Object;
    if (title !== undefined && title.length > 0) {
      const primaryVars: EditPrimaryPostVariables = {
        tid: tid,
        pid: pid,
        content: contentJson,
        title: title
      };
      variables = primaryVars;
    } else {
      const replyVars: EditPostVariables = {
        tid: tid,
        pid: pid,
        content: contentJson
      };
      variables = replyVars;
    }
    const result = await GraphqlClient.getInstance().request(
      'EditPost',
      variables,
      EDIT_POST_MUTATION,
      true
    );
    return parseMutationOk(result.data, 'editPost');
  }

  async followUser(uid: number, follow: boolean): Promise<boolean> {
    const variables: FollowUserVariables = {
      uid: uid,
      follow: follow
    };
    const result = await GraphqlClient.getInstance().request(
      'FollowUser',
      variables,
      FOLLOW_USER_MUTATION,
      true
    );
    return parseMutationOk(result.data, 'followUser');
  }

  async getPmConversations(date: string = ''): Promise<PmConversationListResult> {
    const result = await GraphqlClient.getInstance().request(
      'ViewLastUsersMessages',
      this.buildDateVariables(date),
      VIEW_LAST_USERS_MESSAGES_QUERY,
      true
    );
    return parsePmConversationList(result.data);
  }

  async deletePmConversation(toUid: number): Promise<boolean> {
    const variables: PmConversationDeleteVariables = {
      toUid: toUid
    };
    const result = await GraphqlClient.getInstance().request(
      'DelUserMessage',
      variables,
      DEL_USER_MESSAGE_MUTATION,
      true
    );
    return parseMutationOk(result.data, 'delUserMessage');
  }

  async getPmMessages(uid: number, date: string = ''): Promise<PmMessageListResult> {
    const variables: PmMessagesVariables = date.length > 0
      ? { uid: uid, date: date }
      : { uid: uid };
    const result = await GraphqlClient.getInstance().request(
      'ViewUserMessages',
      variables,
      VIEW_USER_MESSAGES_QUERY,
      true
    );
    return parsePmMessageList(result.data);
  }

  async sendPmText(uid: number, content: string): Promise<PmMessageItem> {
    const variables: SendMessageVariables = {
      uid: uid,
      content: content
    };
    const result = await GraphqlClient.getInstance().request(
      'SendMessage',
      variables,
      SEND_MESSAGE_MUTATION,
      true
    );
    return parseSinglePmMessage(result.data, 'sendMessage');
  }

  async sendPmImage(uid: number, imageKey: string): Promise<PmMessageItem> {
    const variables: SendImageMessageVariables = {
      uid: uid,
      imageKey: imageKey
    };
    const result = await GraphqlClient.getInstance().request(
      'SendImageMessage',
      variables,
      SEND_IMAGE_MESSAGE_MUTATION,
      true
    );
    return parseSinglePmMessage(result.data, 'sendImageMessage');
  }

  async deletePmMessage(uid: number, messageId: string): Promise<boolean> {
    const variables: DeleteMessageVariables = {
      uid: uid,
      id: messageId
    };
    const result = await GraphqlClient.getInstance().request(
      'DelMessage',
      variables,
      DEL_MESSAGE_MUTATION,
      true
    );
    return parseMutationOk(result.data, 'delMessage');
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
