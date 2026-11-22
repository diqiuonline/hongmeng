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