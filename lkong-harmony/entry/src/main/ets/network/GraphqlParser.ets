import {
  Forum,
  LoginResult,
  PostItem,
  PunchInfo,
  ThreadDetail,
  ThreadPageData,
  ThreadSummary
} from '../model/Models';
import { asRecord, pickArray, pickBoolean, pickNumber, pickObject, pickString } from './JsonUtils';

/**
 * 纯 GraphQL 响应解析。
 * 字段名与 GraphqlQueries.ets 中声明的查询保持一致。
 */

export function parseLoginResult(data: Object): LoginResult {
  const root = asRecord(data);
  const login = pickObject(root, ['login']);
  const result: LoginResult = {
    uid: pickNumber(login, ['uid']),
    name: pickString(login, ['name']),
    twoWay: pickBoolean(login, ['twoWay']),
    serverTime: pickString(login, ['serverTime'])
  };
  return result;
}

/**
 * GetMe 的 commonNavbars 中 type=forum 的条目就是版块导航。
 */
export function parseGetMeForums(data: Object): Forum[] {
  const root = asRecord(data);
  const rawNavbars = pickArray(root, ['commonNavbars']);
  const forums: Forum[] = [];

  for (const rawNavbar of rawNavbars) {
    const record = asRecord(rawNavbar);
    if (pickString(record, ['type']) !== 'forum') {
      continue;
    }
    const fid = pickNumber(record, ['fid']);
    if (fid <= 0) {
      continue;
    }
    forums.push({
      fid: fid,
      name: pickString(record, ['name']),
      avatarUrl: '',
      todayPostNum: pickNumber(record, ['num']),
      info: ''
    });
  }
  return forums;
}

/**
 * ViewForumPage 的 threads，字段对应 threadComponent fragment。
 */
export function parseForumPageGraphql(data: Object): ThreadSummary[] {
  const root = asRecord(data);
  const rawThreads = pickArray(root, ['threads']);
  const threads: ThreadSummary[] = [];

  for (const rawThread of rawThreads) {
    const record = asRecord(rawThread);
    const author = pickObject(record, ['author']);
    threads.push({
      tid: pickNumber(record, ['tid']),
      title: pickString(record, ['title']),
      authorName: pickString(author, ['name']),
      authorId: pickNumber(author, ['uid']),
      replyCount: pickNumber(record, ['replies']),
      viewCount: pickNumber(record, ['views']),
      lastPostTime: pickString(record, ['lastpost', 'dateline']),
      isDigest: pickBoolean(record, ['digest']),
      isTop: pickBoolean(record, ['highlight'])
    });
  }
  return threads;
}

/**
 * ViewThread 返回 thread + posts。
 * 楼层作者与主题作者 uid 相同时标记为“作者”。
 */
export function parseThreadPageGraphql(data: Object, fallbackTid: number, page: number): ThreadPageData {
  const root = asRecord(data);
  const threadRecord = pickObject(root, ['thread']);
  const author = pickObject(threadRecord, ['author']);
  const forum = pickObject(threadRecord, ['forum']);
  const threadAuthorId = pickNumber(author, ['uid']);
  const threadId = pickNumber(threadRecord, ['tid']);

  const thread: ThreadDetail = {
    tid: threadId > 0 ? threadId : fallbackTid,
    title: pickString(threadRecord, ['title']),
    authorName: pickString(author, ['name']),
    authorId: threadAuthorId,
    postTime: pickString(threadRecord, ['dateline', 'lastpost']),
    replyCount: pickNumber(threadRecord, ['replies']),
    viewCount: pickNumber(threadRecord, ['views']),
    forumName: pickString(forum, ['name']),
    fid: pickNumber(threadRecord, ['fid'])
  };

  const rawPosts = pickArray(root, ['posts']);
  const posts: PostItem[] = [];
  for (const rawPost of rawPosts) {
    const record = asRecord(rawPost);
    const user = pickObject(record, ['user']);
    const postUserId = pickNumber(user, ['uid']);
    posts.push({
      pid: pickString(record, ['pid']),
      floor: pickString(record, ['lou']),
      authorName: pickString(user, ['name']),
      authorId: postUserId,
      postTime: pickString(record, ['dateline']),
      contentHtml: pickString(record, ['content']),
      subject: '',
      isAuthor: threadAuthorId > 0 && postUserId === threadAuthorId
    });
  }

  const result: ThreadPageData = {
    thread: thread,
    posts: posts,
    page: page
  };
  return result;
}

function parsePunchRecord(record: Record<string, Object>): PunchInfo {
  const info: PunchInfo = {
    uid: pickNumber(record, ['uid']),
    isPunch: pickBoolean(record, ['isPunch']),
    punchDay: pickNumber(record, ['punchday']),
    punchAllDay: pickNumber(record, ['punchallday']),
    punchHighestDay: pickNumber(record, ['punchhighestday'])
  };
  return info;
}

export function parseUserPunch(data: Object): PunchInfo {
  const root = asRecord(data);
  const punch = pickObject(root, ['userPunch']);
  return parsePunchRecord(punch);
}

export function parsePunchResult(data: Object): PunchInfo {
  const root = asRecord(data);
  const punch = pickObject(root, ['punch']);
  return parsePunchRecord(punch);
}