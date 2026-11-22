import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { UserProfile } from '../model/ChatModels';
import { asRecord, pickString } from '../network/JsonUtils';

const PREF_NAME = 'deepseek_auth';
const KEY_USER_TOKEN = 'user_token';
const KEY_COOKIE = 'session_cookie';
const KEY_DEVICE_ID = 'device_id';
const KEY_USER_PROFILE = 'user_profile';

/**
 * 凭证存储：仅保存在本机沙箱 Preferences，不写入日志，不发送至 chat.deepseek.com 以外域名。
 */
export class AuthStore {
  private static instance: AuthStore = new AuthStore();
  private prefs: preferences.Preferences | null = null;
  private userToken: string = '';
  private cookie: string = '';
  private deviceId: string = '';
  private userProfile: UserProfile | null = null;

  static getInstance(): AuthStore {
    return AuthStore.instance;
  }

  async ensureInit(context: common.Context): Promise<void> {
    if (this.prefs !== null) {
      return;
    }
    try {
      this.prefs = await preferences.getPreferences(context, { name: PREF_NAME });
      const storedToken = await this.prefs.get(KEY_USER_TOKEN, '');
      const storedCookie = await this.prefs.get(KEY_COOKIE, '');
      const storedDeviceId = await this.prefs.get(KEY_DEVICE_ID, '');
      const storedProfile = await this.prefs.get(KEY_USER_PROFILE, '');

      this.userToken = extractTokenFromLocalStorageRaw(String(storedToken));
      this.cookie = normalizeCookie(String(storedCookie));
      this.deviceId = String(storedDeviceId);
      if (this.deviceId.length === 0) {
        this.deviceId = generateRandomDeviceId();
        await this.prefs.put(KEY_DEVICE_ID, this.deviceId);
        await this.prefs.flush();
      }

      const profileJson = String(storedProfile);
      if (profileJson.length > 0) {
        try {
          const parsed = JSON.parse(profileJson) as Object;
          const rec = asRecord(parsed);
          const id = pickString(rec, ['id']);
          const email = pickString(rec, ['email']);
          const mobileNumber = pickString(rec, ['mobileNumber']);
          const name = pickString(rec, ['name']);
          const avatarUrl = pickString(rec, ['avatarUrl']);
          if (id.length > 0 || email.length > 0 || mobileNumber.length > 0 || name.length > 0) {
            this.userProfile = {
              id: id,
              email: email,
              mobileNumber: mobileNumber,
              name: name,
              avatarUrl: avatarUrl,
              hasToken: this.userToken.length > 0
            };
          }
        } catch (parseErr) {
          this.userProfile = null;
        }
      }
    } catch (error) {
      this.prefs = null;
      if (this.deviceId.length === 0) {
        this.deviceId = generateRandomDeviceId();
      }
    }
  }

  getToken(): string {
    return this.userToken;
  }

  getCookie(): string {
    return this.cookie;
  }

  getDeviceId(): string {
    if (this.deviceId.length === 0) {
      this.deviceId = generateRandomDeviceId();
    }
    return this.deviceId;
  }

  getUserProfile(): UserProfile | null {
    return this.userProfile;
  }

  hasAuth(): boolean {
    return this.userToken.length > 0 || this.cookie.length > 0;
  }

  hasToken(): boolean {
    return this.userToken.length > 0;
  }

  async setAuth(token: string, cookie: string): Promise<void> {
    const cleanToken = extractTokenFromLocalStorageRaw(token);
    if (cleanToken.length > 0) {
      this.userToken = cleanToken;
    }
    const cleanCookie = normalizeCookie(cookie);
    if (cleanCookie.length > 0) {
      this.cookie = mergeCookies(this.cookie, cleanCookie);
    }
    if (this.prefs !== null) {
      try {
        await this.prefs.put(KEY_USER_TOKEN, this.userToken);
        await this.prefs.put(KEY_COOKIE, this.cookie);
        await this.prefs.flush();
      } catch (error) {
        // 内存中已更新，持久化异常不阻塞本次会话。
      }
    }
  }

  async mergeSetCookie(cookieHeader: string): Promise<void> {
    const cleanCookie = normalizeCookie(cookieHeader);
    if (cleanCookie.length === 0) {
      return;
    }
    this.cookie = mergeCookies(this.cookie, cleanCookie);
    if (this.prefs !== null) {
      try {
        await this.prefs.put(KEY_COOKIE, this.cookie);
        await this.prefs.flush();
      } catch (error) {
        // 忽略存储失败。
      }
    }
  }

  async setUserProfile(profile: UserProfile | null): Promise<void> {
    this.userProfile = profile;
    if (this.prefs !== null) {
      try {
        const serialized = profile !== null ? JSON.stringify(profile) : '';
        await this.prefs.put(KEY_USER_PROFILE, serialized);
        await this.prefs.flush();
      } catch (error) {
        // 忽略存储失败。
      }
    }
  }

  async clearAuth(): Promise<void> {
    this.userToken = '';
    this.cookie = '';
    this.userProfile = null;
    if (this.prefs !== null) {
      try {
        await this.prefs.put(KEY_USER_TOKEN, '');
        await this.prefs.put(KEY_COOKIE, '');
        await this.prefs.put(KEY_USER_PROFILE, '');
        await this.prefs.flush();
      } catch (error) {
        // 内存中已清除。
      }
    }
    try {
      webview.WebCookieManager.clearAllCookiesSync();
    } catch (error) {
      // WebView 未初始化时忽略。
    }
  }

  maskSummary(): string {
    if (!this.hasAuth()) {
      return '未登录';
    }
    if (this.userToken.length > 0) {
      return `已授权（Token ${this.userToken.length} 字符）`;
    }
    return `已保存 Cookie（${this.cookie.length} 字符）`;
  }
}

/**
 * DeepSeek 网页端 localStorage.getItem('userToken') 常见返回形式为：
 * "{\"value\":\"<jwt>\",\"__version\":\"0\"}"，且 ArkWeb runJavaScript 会再包裹一层 JSON 字符串引号。
 * 此函数递归解包直到提取出最内层真实 token 字符串。
 */
export function extractTokenFromLocalStorageRaw(raw: string): string {
  let current = raw.trim();
  if (current.length === 0 || current === 'null' || current === 'undefined' || current === '""') {
    return '';
  }

  for (let depth = 0; depth < 4; depth++) {
    if (current.startsWith('"') && current.endsWith('"')) {
      try {
        const unquoted = JSON.parse(current) as Object;
        if (typeof unquoted === 'string') {
          current = unquoted.trim();
          continue;
        }
        if (unquoted !== null && typeof unquoted === 'object') {
          const rec = asRecord(unquoted);
          const inner = pickString(rec, ['value', 'token', 'access_token']);
          if (inner.length > 0) {
            return inner.trim();
          }
          return '';
        }
      } catch (err) {
        break;
      }
    } else if (current.startsWith('{') && current.endsWith('}')) {
      try {
        const obj = JSON.parse(current) as Object;
        if (obj !== null && typeof obj === 'object') {
          const rec = asRecord(obj);
          const inner = pickString(rec, ['value', 'token', 'access_token']);
          if (inner.length > 0) {
            return inner.trim();
          }
          return '';
        }
      } catch (err) {
        break;
      }
    } else {
      break;
    }
  }

  if (current === 'null' || current === 'undefined') {
    return '';
  }
  return current;
}

function normalizeCookie(value: string): string {
  let cookie = value.trim();
  if (cookie.toLowerCase().startsWith('cookie:')) {
    cookie = cookie.substring(7).trim();
  }
  return cookie.replace(/\r\n/g, ' ').replace(/\n/g, ' ').trim();
}

function mergeCookies(existing: string, incoming: string): string {
  const map: Map<string, string> = new Map<string, string>();
  const feed = (raw: string): void => {
    const parts = raw.split(';');
    for (const part of parts) {
      const trimmed = part.trim();
      if (trimmed.length === 0) {
        continue;
      }
      const eqIdx = trimmed.indexOf('=');
      if (eqIdx <= 0) {
        continue;
      }
      const name = trimmed.substring(0, eqIdx).trim();
      const lower = name.toLowerCase();
      if (
        lower === 'path' ||
        lower === 'domain' ||
        lower === 'expires' ||
        lower === 'max-age' ||
        lower === 'samesite' ||
        lower === 'secure' ||
        lower === 'httponly'
      ) {
        continue;
      }
      const val = trimmed.substring(eqIdx + 1).trim();
      map.set(name, val);
    }
  };
  feed(existing);
  feed(incoming);
  const out: string[] = [];
  map.forEach((val: string, key: string) => {
    out.push(`${key}=${val}`);
  });
  return out.join('; ');
}

function generateRandomDeviceId(): string {
  const hexChars = '0123456789abcdef';
  let result = '';
  for (let i = 0; i < 32; i++) {
    const idx = Math.floor(Math.random() * 16);
    result += hexChars.charAt(idx);
  }
  return result;
}
