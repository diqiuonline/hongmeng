import {
  ApiError,
  ErrorKind,
  Forum,
  ForumPageData,
  LoginResult,
  PunchInfo,
  ThreadPageData
} from '../model/Models';
import { CookieStore } from '../store/CookieStore';
import { GraphqlClient } from './GraphqlClient';
import {
  GET_ME_QUERY,
  GET_USER_PUNCH_QUERY,
  LOGIN_MUTATION,
  PUNCH_MUTATION,
  VIEW_FORUM_PAGE_QUERY,
  VIEW_THREAD_QUERY
} from './GraphqlQueries';
import {
  parseForumPageGraphql,
  parseGetMeForums,
  parseLoginResult,
  parsePunchResult,
  parseThreadPageGraphql,
  parseUserPunch
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

/**
 * 龙空数据入口，全部通过 GraphQL 获取。
 *
 * - Login：账号密码登录
 * - GetMe：首页版块导航
 * - ViewForumPage：版块帖子列表
 * - ViewThread：帖子详情与楼层
 */
export class LkongApi {
  private static instance: LkongApi = new LkongApi();

  static getInstance(): LkongApi {
    return LkongApi.instance;
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
    return login;
  }

  /**
   * GetMe 在未登录时也能返回 commonNavbars，因此首页版块不依赖登录。
   */
  async getHomeForums(): Promise<Forum[]> {
    const emptyVariables: Record<string, Object> = {};
    const result = await GraphqlClient.getInstance().request(
      'GetMe',
      emptyVariables,
      GET_ME_QUERY,
      false
    );
    return parseGetMeForums(result.data);
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