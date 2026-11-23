import { HighlightSegment } from '../model/Models';

const USER_AVATAR_BASE = 'https://image.lkong.com/avatar/';
const FORUM_AVATAR_BASE = 'https://image.lkong.com/forumavatar/';

/**
 * 构建龙空用户头像与版块头像 URL，并处理搜索结果的 <em> 高亮标签。
 */

export function buildUserAvatarUrl(uid: number, avatar: string): string {
  const trimmed = avatar.trim();
  if (trimmed.length === 0) {
    return '';
  }
  if (trimmed.startsWith('https://') || trimmed.startsWith('http://')) {
    return trimmed;
  }
  if (trimmed.startsWith('//')) {
    return `https:${trimmed}`;
  }
  if (uid <= 0) {
    return '';
  }
  return `${USER_AVATAR_BASE}${uid}/${trimmed}`;
}

export function buildForumAvatarUrl(fid: number, avatar: string): string {
  const trimmed = avatar.trim();
  if (trimmed.length === 0) {
    return '';
  }
  if (trimmed.startsWith('https://') || trimmed.startsWith('http://')) {
    return trimmed;
  }
  if (trimmed.startsWith('//')) {
    return `https:${trimmed}`;
  }
  if (fid <= 0) {
    return '';
  }
  return `${FORUM_AVATAR_BASE}${fid}/${trimmed}`;
}

export function safeAvatarInitial(name: string): string {
  const trimmed = name.trim();
  if (trimmed.length === 0) {
    return '龙';
  }
  return trimmed.substring(0, 1);
}

export function decodeHtmlEntities(text: string): string {
  if (text.length === 0) {
    return '';
  }
  let result = text;
  result = result.replace(/&nbsp;/g, ' ');
  result = result.replace(/&lt;/g, '<');
  result = result.replace(/&gt;/g, '>');
  result = result.replace(/&quot;/g, '"');
  result = result.replace(/&#39;/g, "'");
  result = result.replace(/&amp;/g, '&');
  return result;
}

export function splitHighlightText(raw: string): HighlightSegment[] {
  const segments: HighlightSegment[] = [];
  if (raw.length === 0) {
    return segments;
  }

  const regex = /<em>([\s\S]*?)<\/em>/gi;
  let lastIndex = 0;
  let match: RegExpExecArray | null = regex.exec(raw);

  while (match !== null) {
    if (match.index > lastIndex) {
      const normalText = decodeHtmlEntities(raw.slice(lastIndex, match.index).replace(/<[^>]+>/g, ''));
      if (normalText.length > 0) {
        segments.push({ text: normalText, highlight: false });
      }
    }
    const emText = decodeHtmlEntities(match[1].replace(/<[^>]+>/g, ''));
    if (emText.length > 0) {
      segments.push({ text: emText, highlight: true });
    }
    lastIndex = match.index + match[0].length;
    match = regex.exec(raw);
  }

  if (lastIndex < raw.length) {
    const tailText = decodeHtmlEntities(raw.slice(lastIndex).replace(/<[^>]+>/g, ''));
    if (tailText.length > 0) {
      segments.push({ text: tailText, highlight: false });
    }
  }

  if (segments.length === 0) {
    const plain = stripHighlightTags(raw);
    if (plain.length > 0) {
      segments.push({ text: plain, highlight: false });
    }
  }
  return segments;
}

export function stripHighlightTags(raw: string): string {
  if (raw.length === 0) {
    return '';
  }
  return decodeHtmlEntities(raw.replace(/<\/?em>/gi, '').replace(/<[^>]+>/g, '')).trim();
}
