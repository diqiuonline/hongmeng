import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/**
 * 登录态只保存 Cookie 字符串，不保存账号、密码、验证码。
 * Cookie 等价于登录凭证，因此：
 * - 不写入日志；
 * - 不通过网络发送到 lkong.com 之外的域名；
 * - 用户可在设置页一键清除。
 */

const PREF_NAME = 'lkong_settings';
const KEY_COOKIE = 'session_cookie';

export class CookieStore {
  private static instance: CookieStore = new CookieStore();
  private prefs: preferences.Preferences | null = null;
  private cookie: string = '';

  static getInstance(): CookieStore {
    return CookieStore.instance;
  }

  async ensureInit(context: common.Context): Promise<void> {
    if (this.prefs !== null) {
      return;
    }
    try {
      this.prefs = await preferences.getPreferences(context, { name: PREF_NAME });
      const stored = await this.prefs.get(KEY_COOKIE, '');
      this.cookie = String(stored);
    } catch (error) {
      // 持久化不可用时仍允许本次会话在内存中工作。
      this.prefs = null;
    }
  }

  getCookie(): string {
    return this.cookie;
  }

  hasCookie(): boolean {
    return this.cookie.length > 0;
  }

  async setCookie(cookie: string): Promise<void> {
    this.cookie = normalizeCookie(cookie);
    if (this.prefs !== null) {
      try {
        await this.prefs.put(KEY_COOKIE, this.cookie);
        await this.prefs.flush();
      } catch (error) {
        // 内存中的登录态仍可用于本次会话，持久化失败不阻塞浏览。
      }
    }
  }

  async clearCookie(): Promise<void> {
    this.cookie = '';
    if (this.prefs !== null) {
      try {
        await this.prefs.put(KEY_COOKIE, '');
        await this.prefs.flush();
      } catch (error) {
        // 内存中已清除，持久化失败不阻塞用户操作。
      }
    }
  }

  maskSummary(): string {
    if (this.cookie.length === 0) {
      return '未登录';
    }
    return `已保存登录态（${this.cookie.length} 字符）`;
  }
}

/**
 * 兼容用户从浏览器直接复制 "Cookie: xxx" 的情况。
 * 不解析、不拆分 Cookie，原样交给站点，减少因字段变化导致的误判。
 */
function normalizeCookie(value: string): string {
  let cookie = value.trim();
  if (cookie.toLowerCase().startsWith('cookie:')) {
    cookie = cookie.substring(7).trim();
  }
  return cookie.replace(/\r\n/g, ' ').replace(/\n/g, ' ').trim();
}