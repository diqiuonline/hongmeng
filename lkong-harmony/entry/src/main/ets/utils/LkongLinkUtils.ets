export class LkongLinkKind {
  static readonly NONE: string = 'none';
  static readonly THREAD: string = 'thread';
  static readonly FORUM: string = 'forum';
  static readonly USER: string = 'user';
}

export interface ParsedLkongLink {
  kind: string;
  id: number;
  pid: string;
}

/**
 * 识别龙空站内链接（帖子、版块、用户主页），支持直达应用内对应页面。
 */
export function parseLkongUrl(rawUrl: string): ParsedLkongLink {
  const empty: ParsedLkongLink = {
    kind: LkongLinkKind.NONE,
    id: 0,
    pid: ''
  };
  const trimmed = rawUrl.trim();
  if (trimmed.length === 0) {
    return empty;
  }

  const hostMatch = /^https?:\/\/((?:www\.|m\.)?lkong\.com)(\/[^#\s]*)?(#.*)?$/i.exec(trimmed);
  if (hostMatch === null) {
    return empty;
  }
  const pathWithQuery = hostMatch[2] !== undefined ? hostMatch[2] : '';
  const hashPart = hostMatch[3] !== undefined ? hostMatch[3] : '';

  const qIndex = pathWithQuery.indexOf('?');
  const pathOnly = qIndex >= 0 ? pathWithQuery.slice(0, qIndex) : pathWithQuery;
  const queryPart = qIndex >= 0 ? pathWithQuery.slice(qIndex + 1) : '';

  const threadMatch = /^\/thread\/(\d+)(?:\/|$)/i.exec(pathOnly);
  if (threadMatch !== null) {
    const tid = Number(threadMatch[1]);
    if (!isNaN(tid) && tid > 0) {
      return {
        kind: LkongLinkKind.THREAD,
        id: tid,
        pid: extractPidParam(queryPart, hashPart)
      };
    }
  }

  const forumMatch = /^\/forum\/(\d+)(?:\/|$)/i.exec(pathOnly);
  if (forumMatch !== null) {
    const fid = Number(forumMatch[1]);
    if (!isNaN(fid) && fid > 0) {
      return {
        kind: LkongLinkKind.FORUM,
        id: fid,
        pid: ''
      };
    }
  }

  const userMatch = /^\/user\/(\d+)(?:\/|$)/i.exec(pathOnly);
  if (userMatch !== null) {
    const uid = Number(userMatch[1]);
    if (!isNaN(uid) && uid > 0) {
      return {
        kind: LkongLinkKind.USER,
        id: uid,
        pid: ''
      };
    }
  }

  return empty;
}

function extractPidParam(queryPart: string, hashPart: string): string {
  const queryMatch = /(?:^|&)pid=([^&#]+)/i.exec(queryPart);
  if (queryMatch !== null && queryMatch[1].length > 0) {
    try {
      return decodeURIComponent(queryMatch[1]);
    } catch (error) {
      return queryMatch[1];
    }
  }
  const hashMatch = /pid=([^&#]+)/i.exec(hashPart);
  if (hashMatch !== null && hashMatch[1].length > 0) {
    try {
      return decodeURIComponent(hashMatch[1]);
    } catch (error) {
      return hashMatch[1];
    }
  }
  return '';
}
