import { ChatSession, SessionGroup } from '../model/ChatModels';

/**
 * 将时间戳统一归一化为毫秒。DeepSeek 接口通常返回秒级浮点/整数时间戳。
 */
export function normalizeTimestampMs(ts: number): number {
  if (ts <= 0) {
    return 0;
  }
  if (ts < 100000000000) {
    return Math.floor(ts * 1000);
  }
  return Math.floor(ts);
}

export function groupSessionsByTime(sessions: ChatSession[]): SessionGroup[] {
  const now = new Date();
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const ms7Days = startOfToday - 6 * 24 * 60 * 60 * 1000;
  const ms30Days = startOfToday - 29 * 24 * 60 * 60 * 1000;

  const sorted = [...sessions].sort((a: ChatSession, b: ChatSession) => {
    if (a.pinned !== b.pinned) {
      return a.pinned ? -1 : 1;
    }
    return normalizeTimestampMs(b.updatedAt) - normalizeTimestampMs(a.updatedAt);
  });

  const pinnedList: ChatSession[] = [];
  const todayList: ChatSession[] = [];
  const weekList: ChatSession[] = [];
  const monthList: ChatSession[] = [];
  const monthlyMap: Map<string, ChatSession[]> = new Map<string, ChatSession[]>();
  const monthlyOrder: string[] = [];

  for (const session of sorted) {
    if (session.pinned) {
      pinnedList.push(session);
      continue;
    }
    const tsMs = normalizeTimestampMs(session.updatedAt > 0 ? session.updatedAt : session.insertedAt);
    if (tsMs >= startOfToday) {
      todayList.push(session);
    } else if (tsMs >= ms7Days) {
      weekList.push(session);
    } else if (tsMs >= ms30Days) {
      monthList.push(session);
    } else {
      const date = tsMs > 0 ? new Date(tsMs) : now;
      const monthStr = String(date.getMonth() + 1).padStart(2, '0');
      const label = `${date.getFullYear()} 年 ${monthStr} 月`;
      const existing = monthlyMap.get(label);
      if (existing !== undefined) {
        existing.push(session);
      } else {
        monthlyMap.set(label, [session]);
        monthlyOrder.push(label);
      }
    }
  }

  const groups: SessionGroup[] = [];
  if (pinnedList.length > 0) {
    groups.push({ label: '置顶', sessions: pinnedList });
  }
  if (todayList.length > 0) {
    groups.push({ label: '今天', sessions: todayList });
  }
  if (weekList.length > 0) {
    groups.push({ label: '7 天内', sessions: weekList });
  }
  if (monthList.length > 0) {
    groups.push({ label: '30 天内', sessions: monthList });
  }
  for (const label of monthlyOrder) {
    const items = monthlyMap.get(label);
    if (items !== undefined && items.length > 0) {
      groups.push({ label: label, sessions: items });
    }
  }
  return groups;
}

export function formatRelativeTime(ts: number): string {
  const tsMs = normalizeTimestampMs(ts);
  if (tsMs <= 0) {
    return '';
  }
  const diffSec = Math.floor((Date.now() - tsMs) / 1000);
  if (diffSec < 60) {
    return '刚刚';
  }
  if (diffSec < 3600) {
    return `${Math.floor(diffSec / 60)} 分钟前`;
  }
  const date = new Date(tsMs);
  const now = new Date();
  const hh = String(date.getHours()).padStart(2, '0');
  const mm = String(date.getMinutes()).padStart(2, '0');
  if (
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate()
  ) {
    return `${hh}:${mm}`;
  }
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${month}-${day} ${hh}:${mm}`;
}
