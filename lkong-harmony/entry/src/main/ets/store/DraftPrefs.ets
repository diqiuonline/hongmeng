import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { LocalDraft, UploadedImage } from '../model/Models';
import { asRecord, pickArray, pickNumber, pickString } from '../network/JsonUtils';

const PREF_NAME = 'lkong_local_drafts';

/**
 * 仅本机保存的发帖/回帖草稿缓存（Preferences）。
 * 不向服务端发送 UpdateDraft，避免占用 800ms 串行请求节流队列或与网页端互相覆盖。
 */
export class DraftPrefs {
  private static instance: DraftPrefs = new DraftPrefs();
  private prefs: preferences.Preferences | null = null;
  private initialized: boolean = false;

  static getInstance(): DraftPrefs {
    return DraftPrefs.instance;
  }

  static buildNewThreadDraftKey(fid: number): string {
    return `new_${fid}`;
  }

  static buildReplyDraftKey(tid: number, pid: string): string {
    return pid.length > 0 ? `reply_${tid}_${pid}` : `reply_${tid}`;
  }

  async ensureInit(context: common.Context): Promise<void> {
    if (this.initialized) {
      return;
    }
    try {
      this.prefs = await preferences.getPreferences(context, { name: PREF_NAME });
    } catch (error) {
      this.prefs = null;
    }
    this.initialized = true;
  }

  async getDraft(key: string): Promise<LocalDraft | null> {
    if (this.prefs === null || key.length === 0) {
      return null;
    }
    try {
      const raw = String(await this.prefs.get(key, ''));
      if (raw.length === 0) {
        return null;
      }
      const parsed = JSON.parse(raw) as Object;
      const record = asRecord(parsed);
      const title = pickString(record, ['title']);
      const content = pickString(record, ['content']);
      const updatedAt = pickNumber(record, ['updatedAt']);
      const rawImages = pickArray(record, ['images']);
      const images: UploadedImage[] = [];
      for (const rawImg of rawImages) {
        if (rawImg === null || rawImg === undefined || typeof rawImg !== 'object') {
          continue;
        }
        const imgRec = asRecord(rawImg);
        const imgKey = pickString(imgRec, ['key']);
        if (imgKey.length === 0) {
          continue;
        }
        images.push({
          key: imgKey,
          width: pickNumber(imgRec, ['width']),
          height: pickNumber(imgRec, ['height'])
        });
      }
      if (title.trim().length === 0 && content.trim().length === 0 && images.length === 0) {
        return null;
      }
      const draft: LocalDraft = {
        title: title,
        content: content,
        images: images,
        updatedAt: updatedAt
      };
      return draft;
    } catch (error) {
      return null;
    }
  }

  async saveDraft(key: string, draft: LocalDraft): Promise<void> {
    if (this.prefs === null || key.length === 0) {
      return;
    }
    if (draft.title.trim().length === 0 && draft.content.trim().length === 0 && draft.images.length === 0) {
      await this.clearDraft(key);
      return;
    }
    try {
      await this.prefs.put(key, JSON.stringify(draft));
      await this.prefs.flush();
    } catch (error) {
      // 忽略本地草稿写入异常，不影响正常编辑。
    }
  }

  async clearDraft(key: string): Promise<void> {
    if (this.prefs === null || key.length === 0) {
      return;
    }
    try {
      await this.prefs.delete(key);
      await this.prefs.flush();
    } catch (error) {
      // 忽略本地草稿删除异常。
    }
  }
}
