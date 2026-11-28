import {
  AtMeItem,
  AtMeListResult,
  CurrentUser,
  EditablePostData,
  FanNoticeItem,
  FanNoticeListResult,
  FavoriteEntry,
  FavoriteGroup,
  FavoriteGroupDetailData,
  FavoriteGroupOption,
  Forum,
  HomeData,
  HotThread,
  LoginResult,
  NoticeCount,
  NoticeItem,
  NoticeListResult,
  NoticeReplyUser,
  PmConversationItem,
  PmConversationListResult,
  PmMessageItem,
  PmMessageListResult,
  PostItem,
  PostQuote,
  PostRateItem,
  PunchInfo,
  RateNoticeItem,
  RateNoticeListResult,
  SearchForumItem,
  SearchThreadItem,
  SearchThreadsResult,
  SearchUserItem,
  ThreadDetail,
  ThreadPageData,
  ThreadSummary,
  UserPostItem,
  UserProfile,
  UserProfilePageData
} from '../model/Models';
import { buildForumAvatarUrl, buildUserAvatarUrl, stripHighlightTags } from '../utils/AvatarUtils';
import { renderPostSummary } from '../utils/ContentUtils';
import { formatModifyActionText } from '../utils/PostComposerUtils';
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
    twoWay: pickString(login, ['twoWay']),
    serverTime: pickString(login, ['serverTime'])
  };
  return result;
}

export function parseTwoWayLoginResult(data: Object): LoginResult {
  const root = asRecord(data);
  const login = pickObject(root, ['twoWaylogin']);
  const result: LoginResult = {
    uid: pickNumber(login, ['uid']),
    name: pickString(login, ['name']),
    twoWay: '',
    serverTime: ''
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
    if (rawNavbar === null || rawNavbar === undefined || typeof rawNavbar !== 'object') {
      continue;
    }
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

export function parseHomeData(data: Object): HomeData {
  const root = asRecord(data);
  const meRecord = pickObject(root, ['me']);
  const uid = pickNumber(meRecord, ['uid']);
  const rawAvatar = pickString(meRecord, ['avatar']);
  const me: CurrentUser = {
    uid: uid,
    name: pickString(meRecord, ['name']),
    avatar: buildUserAvatarUrl(uid, rawAvatar)
  };
  const home: HomeData = {
    me: me,
    forums: parseGetMeForums(data)
  };
  return home;
}

function parseThreadArray(rawThreads: Object[]): ThreadSummary[] {
  const threads: ThreadSummary[] = [];

  for (const rawThread of rawThreads) {
    if (rawThread === null || rawThread === undefined || typeof rawThread !== 'object') {
      continue;
    }
    const record = asRecord(rawThread);
    const tid = pickNumber(record, ['tid']);
    if (tid <= 0) {
      continue;
    }
    const author = pickObject(record, ['author']);
    const forum = pickObject(record, ['forum']);
    threads.push({
      tid: tid,
      title: pickString(record, ['title']),
      authorName: pickString(author, ['name']),
      authorId: pickNumber(author, ['uid']),
      replyCount: pickNumber(record, ['replies']),
      viewCount: pickNumber(record, ['views']),
      lastPostTime: pickString(record, ['lastpost', 'dateline']),
      isDigest: pickBoolean(record, ['digest']),
      isTop: pickBoolean(record, ['highlight']),
      forumName: pickString(forum, ['name']),
      fid: pickNumber(record, ['fid'])
    });
  }
  return threads;
}

/**
 * ViewForumPage 的 threads，字段对应 threadComponent fragment。
 */
export function parseForumPageGraphql(data: Object): ThreadSummary[] {
  const root = asRecord(data);
  const rawThreads = pickArray(root, ['threads']);
  return parseThreadArray(rawThreads);
}

function parsePostRateRecord(record: Record<string, Object>): PostRateItem | null {
  const num = pickNumber(record, ['num']);
  const userObj = pickObject(record, ['user']);
  const userId = pickNumber(userObj, ['uid']);
  const userName = pickString(userObj, ['name']);
  const id = pickString(record, ['id']);
  if (num === 0 && userId <= 0 && userName.length === 0) {
    return null;
  }
  const item: PostRateItem = {
    id: id,
    pid: pickString(record, ['pid']),
    num: num,
    reason: pickString(record, ['reason']),
    dateline: pickString(record, ['dateline']),
    userId: userId,
    userName: userName,
    userAvatarUrl: buildUserAvatarUrl(userId, pickString(userObj, ['avatar']))
  };
  return item;
}

function parsePostRates(rawRates: Object[]): PostRateItem[] {
  const rates: PostRateItem[] = [];
  for (const rawRate of rawRates) {
    if (rawRate === null || rawRate === undefined || typeof rawRate !== 'object') {
      continue;
    }
    const parsed = parsePostRateRecord(asRecord(rawRate));
    if (parsed !== null) {
      rates.push(parsed);
    }
  }
  rates.sort((a: PostRateItem, b: PostRateItem) => {
    const ta = Number(a.dateline);
    const tb = Number(b.dateline);
    if (!isNaN(ta) && !isNaN(tb)) {
      return tb - ta;
    }
    return b.dateline.localeCompare(a.dateline);
  });
  return rates;
}

function parsePostItemRecord(record: Record<string, Object>, threadAuthorId: number): PostItem {
  const user = pickObject(record, ['user']);
  const postUserId = pickNumber(user, ['uid']);
  const quoteObj = pickObject(record, ['quote']);
  const quotePid = pickString(quoteObj, ['pid']);
  const quoteStatus = pickString(quoteObj, ['status']);
  const quoteContent = pickString(quoteObj, ['content']);
  const quoteAuthor = pickObject(quoteObj, ['author']);
  let quote: PostQuote | null = null;
  if (quotePid.length > 0 || quoteStatus.length > 0 || quoteContent.length > 0) {
    quote = {
      pid: quotePid,
      status: quoteStatus,
      authorId: pickNumber(quoteAuthor, ['uid']),
      authorName: pickString(quoteAuthor, ['name']),
      contentHtml: quoteContent
    };
  }

  const item: PostItem = {
    pid: pickString(record, ['pid']),
    floor: pickString(record, ['lou']),
    authorName: pickString(user, ['name']),
    authorId: postUserId,
    postTime: pickString(record, ['dateline']),
    contentHtml: pickString(record, ['content']),
    subject: '',
    isAuthor: threadAuthorId > 0 && postUserId === threadAuthorId,
    quote: quote,
    rates: parsePostRates(pickArray(record, ['rate']))
  };
  return item;
}

/**
 * ViewThread 返回 thread + posts（含 quote 引用楼层与 rate 评分列表）。
 * 楼层作者与主题作者 uid 相同时标记为“作者”。
 */
export function parseThreadPageGraphql(data: Object, fallbackTid: number, page: number): ThreadPageData {
  const root = asRecord(data);
  const threadRecord = pickObject(root, ['thread']);
  const author = pickObject(threadRecord, ['author']);
  const forum = pickObject(threadRecord, ['forum']);
  const threadAuthorId = pickNumber(author, ['uid']);
  const threadId = pickNumber(threadRecord, ['tid']);
  let firstPid = pickString(threadRecord, ['first']);
  const resolvedPage = pickNumber(threadRecord, ['page']);

  const rawPosts = pickArray(root, ['posts']);
  const posts: PostItem[] = [];
  for (const rawPost of rawPosts) {
    if (rawPost === null || rawPost === undefined || typeof rawPost !== 'object') {
      continue;
    }
    posts.push(parsePostItemRecord(asRecord(rawPost), threadAuthorId));
  }

  if (firstPid.length === 0 && (resolvedPage === 1 || page === 1) && posts.length > 0) {
    firstPid = posts[0].pid;
  }

  const thread: ThreadDetail = {
    tid: threadId > 0 ? threadId : fallbackTid,
    title: pickString(threadRecord, ['title']),
    authorName: pickString(author, ['name']),
    authorId: threadAuthorId,
    postTime: pickString(threadRecord, ['dateline', 'lastpost']),
    replyCount: pickNumber(threadRecord, ['replies']),
    viewCount: pickNumber(threadRecord, ['views']),
    forumName: pickString(forum, ['name']),
    fid: pickNumber(threadRecord, ['fid']),
    firstPid: firstPid,
    isLocked: pickBoolean(threadRecord, ['lock']),
    resolvedPage: resolvedPage > 0 ? resolvedPage : page
  };

  const result: ThreadPageData = {
    thread: thread,
    posts: posts,
    page: thread.resolvedPage
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

export function parseHotThreads(data: Object): HotThread[] {
  const root = asRecord(data);
  const rawHots = pickArray(root, ['hots']);
  const hots: HotThread[] = [];

  for (const rawHot of rawHots) {
    if (rawHot === null || rawHot === undefined || typeof rawHot !== 'object') {
      continue;
    }
    const record = asRecord(rawHot);
    const tid = pickNumber(record, ['tid']);
    if (tid <= 0) {
      continue;
    }
    hots.push({
      tid: tid,
      title: pickString(record, ['title']),
      authorName: pickString(record, ['author']),
      authorId: pickNumber(record, ['authorid'])
    });
  }
  return hots;
}

export function parseSearchThreads(data: Object): SearchThreadsResult {
  const root = asRecord(data);
  const box = pickObject(root, ['searchThreads']);
  const rawThreads = pickArray(box, ['threads']);
  const items: SearchThreadItem[] = [];

  for (const rawThread of rawThreads) {
    if (rawThread === null || rawThread === undefined || typeof rawThread !== 'object') {
      continue;
    }
    const record = asRecord(rawThread);
    const tid = pickNumber(record, ['tid']);
    if (tid <= 0) {
      continue;
    }
    const forum = pickObject(record, ['forum']);
    const author = pickObject(record, ['author']);
    const rawTitle = pickString(record, ['title']);
    items.push({
      tid: tid,
      rawTitle: rawTitle,
      plainTitle: stripHighlightTags(rawTitle),
      fid: pickNumber(forum, ['fid']),
      forumName: pickString(forum, ['name']),
      authorId: pickNumber(author, ['uid']),
      authorName: pickString(author, ['name']),
      dateline: pickString(record, ['dateline']),
      replyCount: pickNumber(record, ['replies']),
      viewCount: pickNumber(record, ['views'])
    });
  }

  const result: SearchThreadsResult = {
    threads: items,
    searchAfter: pickString(box, ['searchAfter']),
    hasMore: pickBoolean(box, ['hasMore'])
  };
  return result;
}

export function parseSearchForums(data: Object): SearchForumItem[] {
  const root = asRecord(data);
  const rawForums = pickArray(root, ['searchForums']);
  const items: SearchForumItem[] = [];

  for (const rawForum of rawForums) {
    if (rawForum === null || rawForum === undefined || typeof rawForum !== 'object') {
      continue;
    }
    const record = asRecord(rawForum);
    const fid = pickNumber(record, ['fid']);
    if (fid <= 0) {
      continue;
    }
    items.push({
      fid: fid,
      name: pickString(record, ['name']),
      avatarUrl: buildForumAvatarUrl(fid, pickString(record, ['avatar'])),
      followers: pickNumber(record, ['followers']),
      threads: pickNumber(record, ['threads']),
      isFollow: pickBoolean(record, ['isFollow'])
    });
  }
  return items;
}

export function parseSearchUsers(data: Object): SearchUserItem[] {
  const root = asRecord(data);
  const rawUsers = pickArray(root, ['searchUsers']);
  const items: SearchUserItem[] = [];

  for (const rawUser of rawUsers) {
    if (rawUser === null || rawUser === undefined || typeof rawUser !== 'object') {
      continue;
    }
    const record = asRecord(rawUser);
    const uid = pickNumber(record, ['uid']);
    if (uid <= 0) {
      continue;
    }
    const verify = pickObject(record, ['verify']);
    items.push({
      uid: uid,
      name: pickString(record, ['name']),
      avatarUrl: buildUserAvatarUrl(uid, pickString(record, ['avatar'])),
      followers: pickNumber(record, ['followers']),
      isFollow: pickBoolean(record, ['isFollow']),
      verifyInfo: pickString(verify, ['info']),
      verifyType: pickString(verify, ['type'])
    });
  }
  return items;
}

export function parseUserProfilePage(data: Object, fallbackUid: number, page: number): UserProfilePageData {
  const root = asRecord(data);
  const userObj = pickObject(root, ['user']);
  const countObj = pickObject(root, ['userCount']);
  const verifyObj = pickObject(userObj, ['verify']);
  const levelObj = pickObject(countObj, ['level']);
  const parsedUid = pickNumber(userObj, ['uid']);
  const uid = parsedUid > 0 ? parsedUid : fallbackUid;

  const profile: UserProfile = {
    uid: uid,
    name: pickString(userObj, ['name']),
    avatarUrl: buildUserAvatarUrl(uid, pickString(userObj, ['avatar'])),
    dateline: pickString(userObj, ['dateline']),
    points: pickNumber(userObj, ['points']),
    gender: pickNumber(userObj, ['gender']),
    status: pickNumber(userObj, ['status']),
    adminLevel: pickNumber(userObj, ['adminLevel']),
    isFollow: pickBoolean(userObj, ['isFollow']),
    verifyInfo: pickString(verifyObj, ['info', 'vertyInfo']),
    verifyType: pickString(verifyObj, ['type']),
    followings: pickNumber(countObj, ['followings']),
    followers: pickNumber(countObj, ['followers']),
    digests: pickNumber(countObj, ['digests']),
    posts: pickNumber(countObj, ['posts']),
    threads: pickNumber(countObj, ['threads']),
    money: pickNumber(countObj, ['money']),
    gems: pickNumber(countObj, ['gems']),
    levelName: pickString(levelObj, ['name']),
    levelColor: pickString(levelObj, ['color']),
    levelNum: pickNumber(levelObj, ['num'])
  };

  if (profile.verifyInfo.length === 0) {
    profile.verifyInfo = pickString(countObj, ['vertyInfo']);
  }

  const rawThreads = pickArray(root, ['content']);
  const threads = parseThreadArray(rawThreads);
  const result: UserProfilePageData = {
    profile: profile,
    threads: threads,
    page: page
  };
  return result;
}

export function parseUserThreads(data: Object): ThreadSummary[] {
  const root = asRecord(data);
  const rawThreads = pickArray(root, ['content']);
  return parseThreadArray(rawThreads);
}

export function parseUserPosts(data: Object): UserPostItem[] {
  const root = asRecord(data);
  const rawItems = pickArray(root, ['content']);
  const items: UserPostItem[] = [];

  for (const rawItem of rawItems) {
    if (rawItem === null || rawItem === undefined || typeof rawItem !== 'object') {
      continue;
    }
    const record = asRecord(rawItem);
    const pid = pickString(record, ['pid']);
    const contentHtml = pickString(record, ['content']);
    const authorObj = pickObject(record, ['author']);
    const threadObj = pickObject(record, ['thread']);
    const quoteObj = pickObject(record, ['quote']);
    const quoteAuthor = pickObject(quoteObj, ['author']);
    const bookObj = pickObject(record, ['book']);
    const tid = pickNumber(threadObj, ['tid']);
    if (pid.length === 0 && tid <= 0 && contentHtml.length === 0) {
      continue;
    }

    const bookTitle = pickString(bookObj, ['title']);
    let title = pickString(threadObj, ['title']);
    if (title.length === 0 && bookTitle.length > 0) {
      title = `书评：《${bookTitle}》`;
    }
    if (title.length === 0 && tid > 0) {
      title = `帖子 #${tid}`;
    }
    if (title.length === 0) {
      title = '用户帖子';
    }

    let authorId = pickNumber(authorObj, ['uid']);
    if (authorId <= 0) {
      authorId = pickNumber(record, ['authorid']);
    }

    items.push({
      pid: pid,
      tid: tid,
      title: title,
      forumName: pickString(threadObj, ['forumName']),
      fid: pickNumber(threadObj, ['fid']),
      authorId: authorId,
      authorName: pickString(authorObj, ['name']),
      dateline: pickString(record, ['dateline']),
      contentHtml: contentHtml,
      typeName: pickString(record, ['__typename']),
      quotePid: pickString(quoteObj, ['pid']),
      quoteAuthorId: pickNumber(quoteAuthor, ['uid']),
      quoteAuthorName: pickString(quoteAuthor, ['name']),
      quoteContentHtml: pickString(quoteObj, ['content']),
      bookBid: pickNumber(bookObj, ['bid']),
      bookTitle: bookTitle,
      bookScore: pickNumber(record, ['score'])
    });
  }
  return items;
}

function parseFavoriteGroupRecord(record: Record<string, Object>): FavoriteGroup {
  const group: FavoriteGroup = {
    id: pickNumber(record, ['id']),
    title: pickString(record, ['title']),
    count: pickNumber(record, ['count']),
    uid: pickNumber(record, ['uid']),
    isPublic: pickBoolean(record, ['isPublic']),
    description: pickString(record, ['description']),
    dateline: pickString(record, ['dateline'])
  };
  return group;
}

export function parseFavoriteGroups(data: Object): FavoriteGroup[] {
  const root = asRecord(data);
  const rawGroups = pickArray(root, ['content', 'collections', 'userFavoriteGroupList']);
  const groups: FavoriteGroup[] = [];

  for (const rawGroup of rawGroups) {
    if (rawGroup === null || rawGroup === undefined || typeof rawGroup !== 'object') {
      continue;
    }
    const group = parseFavoriteGroupRecord(asRecord(rawGroup));
    if (group.id > 0) {
      groups.push(group);
    }
  }
  return groups;
}

export function parseFavoriteGroupDetail(data: Object, page: number): FavoriteGroupDetailData {
  const root = asRecord(data);
  const collectionObj = pickObject(root, ['collection']);
  const group = parseFavoriteGroupRecord(collectionObj);

  const rawComments = pickArray(root, ['comments', 'userFavoriteList']);
  const items: FavoriteEntry[] = [];

  for (const rawItem of rawComments) {
    if (rawItem === null || rawItem === undefined || typeof rawItem !== 'object') {
      continue;
    }
    const record = asRecord(rawItem);
    const pid = pickString(record, ['pid']);
    const authorObj = pickObject(record, ['author']);
    const threadObj = pickObject(record, ['thread']);
    const bookObj = pickObject(record, ['book']);
    const tid = pickNumber(threadObj, ['tid']);
    const bookTitle = pickString(bookObj, ['title']);

    let title = pickString(threadObj, ['title']);
    if (title.length === 0 && bookTitle.length > 0) {
      title = `书评：《${bookTitle}》`;
    }
    if (title.length === 0 && tid > 0) {
      title = `帖子 #${tid}`;
    }
    if (title.length === 0) {
      title = '已收藏内容';
    }

    let authorId = pickNumber(authorObj, ['uid']);
    if (authorId <= 0) {
      authorId = pickNumber(record, ['authorid']);
    }

    items.push({
      pid: pid,
      tid: tid,
      title: title,
      forumName: pickString(threadObj, ['forumName']),
      fid: pickNumber(threadObj, ['fid']),
      authorId: authorId,
      authorName: pickString(authorObj, ['name']),
      dateline: pickString(record, ['dateline']),
      contentHtml: pickString(record, ['content']),
      typeName: pickString(record, ['__typename'])
    });
  }

  const detail: FavoriteGroupDetailData = {
    group: group,
    items: items,
    page: page
  };
  return detail;
}

export function parseFavoriteGroupOptions(data: Object): FavoriteGroupOption[] {
  const root = asRecord(data);
  const rawList = pickArray(root, ['myFavoriteGroupList']);
  const options: FavoriteGroupOption[] = [];

  for (const rawItem of rawList) {
    if (rawItem === null || rawItem === undefined || typeof rawItem !== 'object') {
      continue;
    }
    const record = asRecord(rawItem);
    const id = pickNumber(record, ['id']);
    if (id <= 0) {
      continue;
    }
    options.push({
      id: id,
      title: pickString(record, ['title']),
      isPublic: pickBoolean(record, ['isPublic']),
      hasFavorited: pickBoolean(record, ['hasFavorited'])
    });
  }
  return options;
}

export function parseCreatedFavoriteGroup(data: Object): FavoriteGroupOption {
  const root = asRecord(data);
  const created = pickObject(root, ['createFavoriteGroup']);
  const option: FavoriteGroupOption = {
    id: pickNumber(created, ['id']),
    title: pickString(created, ['title']),
    isPublic: pickBoolean(created, ['isPublic']),
    hasFavorited: false
  };
  return option;
}

export function parseMutationOk(data: Object, fieldName: string): boolean {
  const root = asRecord(data);
  const box = pickObject(root, [fieldName]);
  return pickBoolean(box, ['ok']);
}

export function parseReplyPost(data: Object): PostItem {
  const root = asRecord(data);
  const replyObj = pickObject(root, ['replyThread']);
  return parsePostItemRecord(replyObj, 0);
}

export function parseNewThreadTid(data: Object): number {
  const root = asRecord(data);
  const box = pickObject(root, ['postThread']);
  return pickNumber(box, ['tid']);
}

export function parseRateResult(data: Object): PostRateItem {
  const root = asRecord(data);
  const box = pickObject(root, ['rate']);
  const parsed = parsePostRateRecord(box);
  if (parsed !== null) {
    return parsed;
  }
  const fallback: PostRateItem = {
    id: pickString(box, ['id']),
    pid: pickString(box, ['pid']),
    num: pickNumber(box, ['num']),
    reason: pickString(box, ['reason']),
    dateline: pickString(box, ['dateline']),
    userId: 0,
    userName: '',
    userAvatarUrl: ''
  };
  return fallback;
}

export function parseNoticeCount(data: Object): NoticeCount {
  const root = asRecord(data);
  const box = pickObject(root, ['noticeCount']);
  const count: NoticeCount = {
    noticeCount: pickNumber(box, ['noticeCount']),
    fansCount: pickNumber(box, ['fansCount']),
    rateCount: pickNumber(box, ['rateCount']),
    atmeCount: pickNumber(box, ['atmeCount']),
    pmCount: pickNumber(box, ['pmCount'])
  };
  return count;
}

function parseJsonObjectSafe(raw: string): Record<string, Object> {
  if (raw.length === 0) {
    return {};
  }
  try {
    const parsed = JSON.parse(raw) as Object;
    return asRecord(parsed);
  } catch (error) {
    return {};
  }
}

export function parseNoticeList(data: Object): NoticeListResult {
  const root = asRecord(data);
  const box = pickObject(root, ['notice']);
  const rawList = pickArray(box, ['data', 'notices']);
  const items: NoticeItem[] = [];

  for (const rawItem of rawList) {
    if (rawItem === null || rawItem === undefined || typeof rawItem !== 'object') {
      continue;
    }
    const record = asRecord(rawItem);
    const id = pickString(record, ['id']);
    const action = pickString(record, ['action']);
    const dateline = pickString(record, ['dateline']);
    const contentRaw = pickString(record, ['content']);
    const contentObj = parseJsonObjectSafe(contentRaw);

    let tid = pickNumber(contentObj, ['tid']);
    let pid = '';
    let title = pickString(contentObj, ['title']);
    let summary = '';
    let actorId = pickNumber(record, ['authorid']);
    let actorName = pickString(record, ['author']);
    const replyUsers: NoticeReplyUser[] = [];

    if (action === 'replyThread') {
      const rawUsers = pickArray(contentObj, ['user']);
      const names: string[] = [];
      for (const rawUser of rawUsers) {
        if (rawUser === null || rawUser === undefined || typeof rawUser !== 'object') {
          continue;
        }
        const userRec = asRecord(rawUser);
        const uid = pickNumber(userRec, ['uid']);
        const name = pickString(userRec, ['name']);
        const replyPid = pickString(userRec, ['pid']);
        replyUsers.push({
          uid: uid,
          name: name,
          pid: replyPid
        });
        if (name.length > 0) {
          names.push(name);
        }
        if (pid.length === 0 && replyPid.length > 0) {
          pid = replyPid;
        }
        if (actorId <= 0 && uid > 0) {
          actorId = uid;
          actorName = name;
        }
      }
      summary = names.length > 0 ? `${names.join('、')} 等人回复了你的帖子` : '有人回复了你的帖子';
    } else if (action === 'modifyThread' || action === 'modifyPost') {
      const opKey = pickString(contentObj, ['key']);
      const argsObj = pickObject(contentObj, ['args']);
      if (action === 'modifyPost') {
        pid = pickString(argsObj, ['pid']);
      }
      const actionText = formatModifyActionText(opKey, argsObj);
      summary = action === 'modifyThread' ? `你的主题被${actionText}了` : `你的帖子被${actionText}了`;
    } else if (action === 'note') {
      const noteValue = contentObj['note'];
      if (typeof noteValue === 'string') {
        summary = renderPostSummary(noteValue, 160);
      } else if (noteValue !== undefined && noteValue !== null) {
        summary = renderPostSummary(JSON.stringify(noteValue), 160);
      }
      if (summary.length === 0) {
        summary = contentRaw.length > 0 ? renderPostSummary(contentRaw, 160) : '系统通知';
      }
    } else {
      summary = title.length > 0 ? title : '收到一条新通知';
    }

    items.push({
      id: id.length > 0 ? id : `${action}_${dateline}_${items.length}`,
      action: action,
      dateline: dateline,
      tid: tid,
      pid: pid,
      title: title,
      summary: summary,
      actorId: actorId,
      actorName: actorName,
      replyUsers: replyUsers
    });
  }

  const result: NoticeListResult = {
    items: items,
    hasMore: pickBoolean(box, ['hasMore']),
    nextDate: pickString(box, ['nextDate'])
  };
  return result;
}

export function parseAtMeList(data: Object): AtMeListResult {
  const root = asRecord(data);
  const box = pickObject(root, ['atme']);
  const rawList = pickArray(box, ['data', 'posts']);
  const items: AtMeItem[] = [];

  for (const rawItem of rawList) {
    if (rawItem === null || rawItem === undefined || typeof rawItem !== 'object') {
      continue;
    }
    const record = asRecord(rawItem);
    const authorObj = pickObject(record, ['author']);
    const threadObj = pickObject(record, ['thread']);
    const bookObj = pickObject(record, ['book']);
    const tid = pickNumber(threadObj, ['tid']);
    const bookTitle = pickString(bookObj, ['title']);

    let title = pickString(threadObj, ['title']);
    if (title.length === 0 && bookTitle.length > 0) {
      title = `书评：《${bookTitle}》`;
    }
    if (title.length === 0 && tid > 0) {
      title = `帖子 #${tid}`;
    }

    let authorId = pickNumber(authorObj, ['uid']);
    if (authorId <= 0) {
      authorId = pickNumber(record, ['authorid']);
    }

    items.push({
      pid: pickString(record, ['pid']),
      tid: tid,
      title: title,
      forumName: pickString(threadObj, ['forumName']),
      fid: pickNumber(threadObj, ['fid']),
      authorId: authorId,
      authorName: pickString(authorObj, ['name']),
      authorAvatarUrl: buildUserAvatarUrl(authorId, pickString(authorObj, ['avatar'])),
      dateline: pickString(record, ['dateline']),
      contentHtml: pickString(record, ['content']),
      typeName: pickString(record, ['__typename'])
    });
  }

  const result: AtMeListResult = {
    items: items,
    hasMore: pickBoolean(box, ['hasMore']),
    nextDate: pickString(box, ['nextDate'])
  };
  return result;
}

export function parseRateNoticeList(data: Object): RateNoticeListResult {
  const root = asRecord(data);
  const box = pickObject(root, ['rateNotice']);
  const rawList = pickArray(box, ['data', 'rates']);
  const items: RateNoticeItem[] = [];

  for (const rawItem of rawList) {
    if (rawItem === null || rawItem === undefined || typeof rawItem !== 'object') {
      continue;
    }
    const record = asRecord(rawItem);
    const userObj = pickObject(record, ['user']);
    let userId = pickNumber(userObj, ['uid']);
    if (userId <= 0) {
      userId = pickNumber(record, ['uid']);
    }
    items.push({
      rid: pickString(record, ['rid']),
      tid: pickNumber(record, ['tid']),
      pid: pickString(record, ['pid']),
      title: pickString(record, ['title']),
      num: pickNumber(record, ['num']),
      userId: userId,
      userName: pickString(userObj, ['name']),
      dateline: pickString(record, ['dateline'])
    });
  }

  const result: RateNoticeListResult = {
    items: items,
    hasMore: pickBoolean(box, ['hasMore']),
    nextDate: pickString(box, ['nextDate'])
  };
  return result;
}

export function parseFansNoticeList(data: Object): FanNoticeListResult {
  const root = asRecord(data);
  const box = pickObject(root, ['fansNotice']);
  const rawList = pickArray(box, ['data', 'users']);
  const items: FanNoticeItem[] = [];

  for (const rawItem of rawList) {
    if (rawItem === null || rawItem === undefined || typeof rawItem !== 'object') {
      continue;
    }
    const record = asRecord(rawItem);
    const uid = pickNumber(record, ['uid']);
    if (uid <= 0) {
      continue;
    }
    const verify = pickObject(record, ['verify']);
    items.push({
      uid: uid,
      name: pickString(record, ['name']),
      avatarUrl: buildUserAvatarUrl(uid, pickString(record, ['avatar'])),
      isFollow: pickBoolean(record, ['isFollow']),
      verifyInfo: pickString(verify, ['info']),
      verifyType: pickString(verify, ['type'])
    });
  }

  const result: FanNoticeListResult = {
    items: items,
    hasMore: pickBoolean(box, ['hasMore']),
    nextDate: pickString(box, ['nextDate'])
  };
  return result;
}

export function parseEditablePost(
  data: Object,
  fallbackTid: number,
  fallbackPid: string
): EditablePostData {
  const root = asRecord(data);
  const threadObj = pickObject(root, ['thread']);
  const postObj = pickObject(root, ['post']);
  const pid = pickString(postObj, ['pid']);
  const result: EditablePostData = {
    tid: fallbackTid,
    pid: pid.length > 0 ? pid : fallbackPid,
    title: pickString(threadObj, ['title']),
    firstPid: pickString(threadObj, ['first']),
    content: pickString(postObj, ['content']),
    authorId: pickNumber(postObj, ['authorid']),
    isLocked: pickBoolean(postObj, ['lock'])
  };
  return result;
}

export function parsePmConversationList(data: Object): PmConversationListResult {
  const root = asRecord(data);
  const box = pickObject(root, ['lastUsersMessages']);
  const rawList = pickArray(box, ['data', 'messages']);
  const items: PmConversationItem[] = [];

  for (const rawItem of rawList) {
    if (rawItem === null || rawItem === undefined || typeof rawItem !== 'object') {
      continue;
    }
    const record = asRecord(rawItem);
    const userObj = pickObject(record, ['user']);
    const uid = pickNumber(userObj, ['uid']);
    if (uid <= 0) {
      continue;
    }
    items.push({
      uid: uid,
      name: pickString(userObj, ['name']),
      avatarUrl: buildUserAvatarUrl(uid, pickString(userObj, ['avatar'])),
      lastTime: pickString(record, ['lastTime']),
      newCount: pickNumber(record, ['newCount']),
      content: pickString(record, ['content'])
    });
  }

  const result: PmConversationListResult = {
    items: items,
    hasMore: pickBoolean(box, ['hasMore']),
    nextDate: pickString(box, ['nextDate'])
  };
  return result;
}

function parsePmMessageRecord(record: Record<string, Object>): PmMessageItem {
  const item: PmMessageItem = {
    id: pickString(record, ['id']),
    uid: pickNumber(record, ['uid']),
    content: pickString(record, ['content']),
    dateline: pickString(record, ['dateline'])
  };
  return item;
}

export function parsePmMessageList(data: Object): PmMessageListResult {
  const root = asRecord(data);
  const box = pickObject(root, ['userMessages']);
  const rawList = pickArray(box, ['data', 'messages']);
  const items: PmMessageItem[] = [];

  for (const rawItem of rawList) {
    if (rawItem === null || rawItem === undefined || typeof rawItem !== 'object') {
      continue;
    }
    const parsed = parsePmMessageRecord(asRecord(rawItem));
    if (parsed.id.length > 0 || parsed.content.length > 0) {
      items.push(parsed);
    }
  }

  const result: PmMessageListResult = {
    items: items,
    hasMore: pickBoolean(box, ['hasMore']),
    nextDate: pickString(box, ['nextDate'])
  };
  return result;
}

export function parseSinglePmMessage(data: Object, fieldName: string): PmMessageItem {
  const root = asRecord(data);
  const record = pickObject(root, [fieldName]);
  return parsePmMessageRecord(record);
}
