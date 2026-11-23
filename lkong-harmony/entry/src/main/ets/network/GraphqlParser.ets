import {
  CurrentUser,
  FavoriteEntry,
  FavoriteGroup,
  FavoriteGroupDetailData,
  FavoriteGroupOption,
  Forum,
  HomeData,
  HotThread,
  LoginResult,
  PostItem,
  PostQuote,
  PunchInfo,
  SearchForumItem,
  SearchThreadItem,
  SearchThreadsResult,
  SearchUserItem,
  ThreadDetail,
  ThreadPageData,
  ThreadSummary,
  UserProfile,
  UserProfilePageData
} from '../model/Models';
import { buildForumAvatarUrl, buildUserAvatarUrl, stripHighlightTags } from '../utils/AvatarUtils';
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

/**
 * ViewThread 返回 thread + posts（含 quote 引用楼层）。
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

  const rawPosts = pickArray(root, ['posts']);
  const posts: PostItem[] = [];
  for (const rawPost of rawPosts) {
    if (rawPost === null || rawPost === undefined || typeof rawPost !== 'object') {
      continue;
    }
    const record = asRecord(rawPost);
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

    posts.push({
      pid: pickString(record, ['pid']),
      floor: pickString(record, ['lou']),
      authorName: pickString(user, ['name']),
      authorId: postUserId,
      postTime: pickString(record, ['dateline']),
      contentHtml: pickString(record, ['content']),
      subject: '',
      isAuthor: threadAuthorId > 0 && postUserId === threadAuthorId,
      quote: quote
    });
  }

  if (firstPid.length === 0 && page === 1 && posts.length > 0) {
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
    firstPid: firstPid
  };

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
