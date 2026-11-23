import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Forum } from '../model/Models';

const PREF_NAME = 'lkong_forum_prefs';
const KEY_PINNED_FIDS = 'pinned_fids';
const KEY_ORDER_FIDS = 'order_fids';
const KEY_SEARCH_HISTORY = 'search_history';
const MAX_SEARCH_HISTORY = 10;

/**
 * 版块常用置顶、自定义排序与最近搜索历史本地持久化。
 */
export class ForumOrderPrefs {
  private static instance: ForumOrderPrefs = new ForumOrderPrefs();
  private prefs: preferences.Preferences | null = null;
  private initialized: boolean = false;
  private pinnedFids: number[] = [];
  private orderFids: number[] = [];
  private searchHistory: string[] = [];

  static getInstance(): ForumOrderPrefs {
    return ForumOrderPrefs.instance;
  }

  async ensureInit(context: common.Context): Promise<void> {
    if (this.initialized) {
      return;
    }
    try {
      this.prefs = await preferences.getPreferences(context, { name: PREF_NAME });
      const rawPinned = String(await this.prefs.get(KEY_PINNED_FIDS, '[]'));
      const rawOrder = String(await this.prefs.get(KEY_ORDER_FIDS, '[]'));
      const rawHistory = String(await this.prefs.get(KEY_SEARCH_HISTORY, '[]'));
      this.pinnedFids = parseNumberArray(rawPinned);
      this.orderFids = parseNumberArray(rawOrder);
      this.searchHistory = parseStringArray(rawHistory);
    } catch (error) {
      this.prefs = null;
    }
    this.initialized = true;
  }

  getPinnedFids(): number[] {
    const copy: number[] = [];
    for (const fid of this.pinnedFids) {
      copy.push(fid);
    }
    return copy;
  }

  getOrderFids(): number[] {
    const copy: number[] = [];
    for (const fid of this.orderFids) {
      copy.push(fid);
    }
    return copy;
  }

  isPinned(fid: number): boolean {
    for (const item of this.pinnedFids) {
      if (item === fid) {
        return true;
      }
    }
    return false;
  }

  applyOrder(forums: Forum[]): Forum[] {
    const forumMap = new Map<number, Forum>();
    for (const forum of forums) {
      forumMap.set(forum.fid, forum);
    }

    const result: Forum[] = [];
    const added = new Set<number>();

    // 1. 已置顶版块排在最前面
    for (const fid of this.pinnedFids) {
      const target = forumMap.get(fid);
      if (target !== undefined && !added.has(fid)) {
        result.push(target);
        added.add(fid);
      }
    }

    // 2. 自定义排序区（仅非置顶且仍存在的版块）
    for (const fid of this.orderFids) {
      const target = forumMap.get(fid);
      if (target !== undefined && !added.has(fid)) {
        result.push(target);
        added.add(fid);
      }
    }

    // 3. 服务端新增版块按默认顺序追加到末尾
    for (const forum of forums) {
      if (!added.has(forum.fid)) {
        result.push(forum);
        added.add(forum.fid);
      }
    }

    return result;
  }

  getPinnedForums(forums: Forum[]): Forum[] {
    const ordered = this.applyOrder(forums);
    const result: Forum[] = [];
    for (const forum of ordered) {
      if (this.isPinned(forum.fid)) {
        result.push(forum);
      }
    }
    return result;
  }

  async togglePin(fid: number, allForums: Forum[]): Promise<void> {
    const ordered = this.applyOrder(allForums);
    const nextPinned: number[] = [];
    const currentlyPinned = this.isPinned(fid);

    if (currentlyPinned) {
      for (const item of this.pinnedFids) {
        if (item !== fid) {
          nextPinned.push(item);
        }
      }
      // 取消置顶后保留在自定义顺序的普通区靠前位置，便于用户感知
      const nextOrder: number[] = [];
      for (const item of nextPinned) {
        nextOrder.push(item);
      }
      nextOrder.push(fid);
      for (const forum of ordered) {
        if (forum.fid !== fid && !containsNumber(nextPinned, forum.fid)) {
          nextOrder.push(forum.fid);
        }
      }
      this.pinnedFids = nextPinned;
      this.orderFids = nextOrder;
    } else {
      for (const forum of ordered) {
        if (this.isPinned(forum.fid)) {
          nextPinned.push(forum.fid);
        }
      }
      nextPinned.push(fid);
      this.pinnedFids = nextPinned;
    }

    await this.saveForumOrder();
  }

  /**
   * direction: -1 上移, 1 下移, -2 移至所在分组首位
   */
  async moveForum(
    fid: number,
    direction: number,
    allForums: Forum[],
    onlyPinnedScope: boolean
  ): Promise<void> {
    const ordered = this.applyOrder(allForums);
    const pinnedList: number[] = [];
    const unpinnedList: number[] = [];

    for (const forum of ordered) {
      if (this.isPinned(forum.fid)) {
        pinnedList.push(forum.fid);
      } else {
        unpinnedList.push(forum.fid);
      }
    }

    if (onlyPinnedScope || this.isPinned(fid)) {
      if (reorderNumberList(pinnedList, fid, direction)) {
        this.pinnedFids = pinnedList;
        await this.saveForumOrder();
      }
      return;
    }

    if (reorderNumberList(unpinnedList, fid, direction)) {
      const mergedOrder: number[] = [];
      for (const item of pinnedList) {
        mergedOrder.push(item);
      }
      for (const item of unpinnedList) {
        mergedOrder.push(item);
      }
      this.orderFids = mergedOrder;
      await this.saveForumOrder();
    }
  }

  async resetOrder(clearPinned: boolean = false): Promise<void> {
    this.orderFids = [];
    if (clearPinned) {
      this.pinnedFids = [];
    }
    await this.saveForumOrder();
  }

  getSearchHistory(): string[] {
    const copy: string[] = [];
    for (const item of this.searchHistory) {
      copy.push(item);
    }
    return copy;
  }

  async addSearchHistory(keyword: string): Promise<void> {
    const trimmed = keyword.trim();
    if (trimmed.length === 0) {
      return;
    }
    const next: string[] = [trimmed];
    for (const item of this.searchHistory) {
      if (item !== trimmed && next.length < MAX_SEARCH_HISTORY) {
        next.push(item);
      }
    }
    this.searchHistory = next;
    await this.saveSearchHistory();
  }

  async clearSearchHistory(): Promise<void> {
    this.searchHistory = [];
    await this.saveSearchHistory();
  }

  private async saveForumOrder(): Promise<void> {
    if (this.prefs === null) {
      return;
    }
    try {
      await this.prefs.put(KEY_PINNED_FIDS, JSON.stringify(this.pinnedFids));
      await this.prefs.put(KEY_ORDER_FIDS, JSON.stringify(this.orderFids));
      await this.prefs.flush();
    } catch (error) {
      // 持久化失败不影响当前内存态生效。
    }
  }

  private async saveSearchHistory(): Promise<void> {
    if (this.prefs === null) {
      return;
    }
    try {
      await this.prefs.put(KEY_SEARCH_HISTORY, JSON.stringify(this.searchHistory));
      await this.prefs.flush();
    } catch (error) {
      // 持久化失败不影响当前内存态生效。
    }
  }
}

function containsNumber(list: number[], target: number): boolean {
  for (const item of list) {
    if (item === target) {
      return true;
    }
  }
  return false;
}

function reorderNumberList(list: number[], target: number, direction: number): boolean {
  let index = -1;
  for (let i = 0; i < list.length; i++) {
    if (list[i] === target) {
      index = i;
      break;
    }
  }
  if (index < 0) {
    return false;
  }
  if (direction === -2) {
    if (index === 0) {
      return false;
    }
    list.splice(index, 1);
    list.unshift(target);
    return true;
  }
  if (direction === -1) {
    if (index <= 0) {
      return false;
    }
    const prev = list[index - 1];
    list[index - 1] = list[index];
    list[index] = prev;
    return true;
  }
  if (direction === 1) {
    if (index >= list.length - 1) {
      return false;
    }
    const next = list[index + 1];
    list[index + 1] = list[index];
    list[index] = next;
    return true;
  }
  return false;
}

function parseNumberArray(raw: string): number[] {
  const result: number[] = [];
  const seen = new Set<number>();
  try {
    const parsed = JSON.parse(raw) as Object;
    if (!Array.isArray(parsed)) {
      return result;
    }
    const list = parsed as Object[];
    for (const item of list) {
      if (typeof item === 'number' && isFinite(item) && item > 0 && !seen.has(item)) {
        result.push(item);
        seen.add(item);
      }
    }
  } catch (error) {
    return [];
  }
  return result;
}

function parseStringArray(raw: string): string[] {
  const result: string[] = [];
  const seen = new Set<string>();
  try {
    const parsed = JSON.parse(raw) as Object;
    if (!Array.isArray(parsed)) {
      return result;
    }
    const list = parsed as Object[];
    for (const item of list) {
      if (typeof item === 'string') {
        const trimmed = item.trim();
        if (trimmed.length > 0 && !seen.has(trimmed) && result.length < MAX_SEARCH_HISTORY) {
          result.push(trimmed);
          seen.add(trimmed);
        }
      }
    }
  } catch (error) {
    return [];
  }
  return result;
}
