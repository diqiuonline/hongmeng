/**
 * 领域模型与统一错误类型。
 * 这里只保留浏览和登录所需的最小字段，避免把站点内部结构直接泄漏到 UI 层。
 */

export interface Forum {
  fid: number;
  name: string;
  avatarUrl: string;
  todayPostNum: number;
  info: string;
}

export interface ThreadSummary {
  tid: number;
  title: string;
  authorName: string;
  authorId: number;
  replyCount: number;
  viewCount: number;
  lastPostTime: string;
  isDigest: boolean;
  isTop: boolean;
  forumName: string;
  fid: number;
}

export interface ThreadDetail {
  tid: number;
  title: string;
  authorName: string;
  authorId: number;
  postTime: string;
  replyCount: number;
  viewCount: number;
  forumName: string;
  fid: number;
  firstPid: string;
}

export interface PostQuote {
  pid: string;
  status: string;
  authorId: number;
  authorName: string;
  contentHtml: string;
}

export interface PostItem {
  pid: string;
  floor: string;
  authorName: string;
  authorId: number;
  postTime: string;
  contentHtml: string;
  subject: string;
  isAuthor: boolean;
  quote: PostQuote | null;
}

export interface CurrentUser {
  uid: number;
  name: string;
  avatar: string;
}

export interface HomeData {
  me: CurrentUser;
  forums: Forum[];
}

export interface HotThread {
  tid: number;
  title: string;
  authorName: string;
  authorId: number;
}

export interface HighlightSegment {
  text: string;
  highlight: boolean;
}

export interface SearchThreadItem {
  tid: number;
  rawTitle: string;
  plainTitle: string;
  fid: number;
  forumName: string;
  authorId: number;
  authorName: string;
  dateline: string;
  replyCount: number;
  viewCount: number;
}

export interface SearchThreadsResult {
  threads: SearchThreadItem[];
  searchAfter: string;
  hasMore: boolean;
}

export interface SearchForumItem {
  fid: number;
  name: string;
  avatarUrl: string;
  followers: number;
  threads: number;
  isFollow: boolean;
}

export interface SearchUserItem {
  uid: number;
  name: string;
  avatarUrl: string;
  followers: number;
  isFollow: boolean;
  verifyInfo: string;
  verifyType: string;
}

export interface UserProfile {
  uid: number;
  name: string;
  avatarUrl: string;
  dateline: string;
  points: number;
  gender: number;
  status: number;
  adminLevel: number;
  isFollow: boolean;
  verifyInfo: string;
  verifyType: string;
  followings: number;
  followers: number;
  digests: number;
  posts: number;
  threads: number;
  money: number;
  gems: number;
  levelName: string;
  levelColor: string;
  levelNum: number;
}

export interface UserProfilePageData {
  profile: UserProfile;
  threads: ThreadSummary[];
  page: number;
}

export interface FavoriteGroup {
  id: number;
  title: string;
  count: number;
  uid: number;
  isPublic: boolean;
  description: string;
  dateline: string;
}

export interface FavoriteGroupOption {
  id: number;
  title: string;
  isPublic: boolean;
  hasFavorited: boolean;
}

export interface FavoriteEntry {
  pid: string;
  tid: number;
  title: string;
  forumName: string;
  fid: number;
  authorId: number;
  authorName: string;
  dateline: string;
  contentHtml: string;
  typeName: string;
}

export interface FavoriteGroupDetailData {
  group: FavoriteGroup;
  items: FavoriteEntry[];
  page: number;
}

export interface ForumPageData {
  forumName: string;
  threads: ThreadSummary[];
  page: number;
}

export interface ThreadPageData {
  thread: ThreadDetail;
  posts: PostItem[];
  page: number;
}

export interface LoginResult {
  uid: number;
  name: string;
  twoWay: boolean;
  serverTime: string;
}

export interface PunchInfo {
  uid: number;
  isPunch: boolean;
  punchDay: number;
  punchAllDay: number;
  punchHighestDay: number;
}

export class InlineKind {
  static readonly TEXT: string = 'text';
  static readonly EMOTION: string = 'emotion';
}

export interface PostInline {
  kind: string;
  text: string;
  url: string;
  href: string;
  bold: boolean;
  italic: boolean;
  underline: boolean;
  strike: boolean;
  code: boolean;
}

export class BlockKind {
  static readonly PARAGRAPH: string = 'paragraph';
  static readonly HEADING: string = 'heading';
  static readonly QUOTE: string = 'quote';
  static readonly CODE_BLOCK: string = 'code_block';
  static readonly IMAGE: string = 'image';
  static readonly DIVIDER: string = 'divider';
}

export interface PostBlock {
  kind: string;
  inlines: PostInline[];
  imageUrl: string;
  imageAlt: string;
  imageWidth: number;
  imageHeight: number;
}

/**
 * 统一错误分类，页面根据 kind 决定展示“去登录”“重试”还是“站点结构变化”。
 */
export class ErrorKind {
  static readonly NETWORK: string = 'NETWORK';
  static readonly AUTH: string = 'AUTH';
  static readonly HTTP: string = 'HTTP';
  static readonly PARSE: string = 'PARSE';
  static readonly UNKNOWN: string = 'UNKNOWN';
}

export class ApiError extends Error {
  kind: string;
  statusCode: number;

  constructor(kind: string, message: string, statusCode: number = 0) {
    super(message);
    this.name = 'ApiError';
    this.kind = kind;
    this.statusCode = statusCode;
  }
}