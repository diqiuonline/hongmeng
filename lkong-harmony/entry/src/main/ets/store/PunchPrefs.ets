import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { KEY_AUTO_PUNCH_ENABLED, KEY_AUTO_PUNCH_LAST_NOTE } from '../utils/AppConfig';

const PREF_NAME = 'lkong_punch';
const KEY_ENABLED = 'auto_punch_enabled';
const KEY_LAST_PUNCH_DATE = 'last_punch_date';
const KEY_LAST_PUNCH_UID = 'last_punch_uid';
const KEY_LAST_AUTO_NOTE = 'last_auto_note';

/**
 * 每日自动签到偏好与最近签到状态持久化（Preferences + AppStorage）。
 */
export class PunchPrefs {
  private static instance: PunchPrefs = new PunchPrefs();
  private prefs: preferences.Preferences | null = null;
  private initialized: boolean = false;
  private autoPunchEnabled: boolean = true;
  private lastPunchDate: string = '';
  private lastPunchUid: number = 0;
  private lastAutoNote: string = '';

  private constructor() {
    this.syncAppStorage();
  }

  static getInstance(): PunchPrefs {
    return PunchPrefs.instance;
  }

  async ensureInit(context: common.Context): Promise<void> {
    if (this.initialized) {
      this.syncAppStorage();
      return;
    }

    try {
      this.prefs = await preferences.getPreferences(context, { name: PREF_NAME });
      const rawEnabled = await this.prefs.get(KEY_ENABLED, true);
      if (typeof rawEnabled === 'boolean') {
        this.autoPunchEnabled = rawEnabled;
      } else {
        this.autoPunchEnabled = String(rawEnabled) !== 'false';
      }
      this.lastPunchDate = String(await this.prefs.get(KEY_LAST_PUNCH_DATE, ''));
      const rawUid = Number(await this.prefs.get(KEY_LAST_PUNCH_UID, 0));
      this.lastPunchUid = isNaN(rawUid) ? 0 : rawUid;
      this.lastAutoNote = String(await this.prefs.get(KEY_LAST_AUTO_NOTE, ''));
    } catch (error) {
      this.prefs = null;
    }

    this.initialized = true;
    this.syncAppStorage();
  }

  isEnabled(): boolean {
    return this.autoPunchEnabled;
  }

  async setEnabled(enabled: boolean): Promise<void> {
    this.autoPunchEnabled = enabled;
    this.syncAppStorage();

    if (this.prefs !== null) {
      try {
        await this.prefs.put(KEY_ENABLED, enabled);
        await this.prefs.flush();
      } catch (error) {
        // 内存中已生效，持久化失败不阻塞开关切换。
      }
    }
  }

  getLastPunchDate(): string {
    return this.lastPunchDate;
  }

  getLastPunchUid(): number {
    return this.lastPunchUid;
  }

  getLastAutoNote(): string {
    return this.lastAutoNote;
  }

  isPunchedTodayForUid(uid: number, today: string): boolean {
    if (this.lastPunchDate !== today || today.length === 0) {
      return false;
    }
    if (uid > 0 && this.lastPunchUid > 0 && this.lastPunchUid !== uid) {
      return false;
    }
    return true;
  }

  async recordPunched(uid: number, today: string, note?: string): Promise<void> {
    this.lastPunchDate = today;
    if (uid > 0) {
      this.lastPunchUid = uid;
    }
    if (note !== undefined) {
      this.lastAutoNote = note;
    }
    this.syncAppStorage();

    if (this.prefs !== null) {
      try {
        await this.prefs.put(KEY_LAST_PUNCH_DATE, this.lastPunchDate);
        await this.prefs.put(KEY_LAST_PUNCH_UID, this.lastPunchUid);
        if (note !== undefined) {
          await this.prefs.put(KEY_LAST_AUTO_NOTE, this.lastAutoNote);
        }
        await this.prefs.flush();
      } catch (error) {
        // 忽略本地记录写入异常。
      }
    }
  }

  async recordAutoNote(note: string): Promise<void> {
    this.lastAutoNote = note;
    this.syncAppStorage();

    if (this.prefs !== null) {
      try {
        await this.prefs.put(KEY_LAST_AUTO_NOTE, this.lastAutoNote);
        await this.prefs.flush();
      } catch (error) {
        // 忽略本地记录写入异常。
      }
    }
  }

  async clearRuntimeState(): Promise<void> {
    this.lastPunchDate = '';
    this.lastPunchUid = 0;
    this.lastAutoNote = '';
    this.syncAppStorage();

    if (this.prefs !== null) {
      try {
        await this.prefs.put(KEY_LAST_PUNCH_DATE, '');
        await this.prefs.put(KEY_LAST_PUNCH_UID, 0);
        await this.prefs.put(KEY_LAST_AUTO_NOTE, '');
        await this.prefs.flush();
      } catch (error) {
        // 忽略退出登录清理异常。
      }
    }
  }

  private syncAppStorage(): void {
    AppStorage.setOrCreate(KEY_AUTO_PUNCH_ENABLED, this.autoPunchEnabled);
    AppStorage.setOrCreate(KEY_AUTO_PUNCH_LAST_NOTE, this.lastAutoNote);
  }
}
