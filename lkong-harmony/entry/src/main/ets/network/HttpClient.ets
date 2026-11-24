import { http } from '@kit.NetworkKit';
import { ApiError, ErrorKind } from '../model/Models';
import { CookieStore } from '../store/CookieStore';

/**
 * 单例 HTTP 客户端，服务 GraphQL API 与官方图床上传。
 *
 * 安全约束：
 * 1. postJson 只允许 https://api.lkong.com/api；uploadImage 只允许 https://images.lkong.com/upload；
 * 2. 请求之间至少间隔 800ms，避免短时间内高频访问；
 * 3. Cookie 只放在请求头里，不写入日志；
 * 4. 账号密码只用于登录请求的请求体，不写入本地存储。
 */

const API_URL = 'https://api.lkong.com/api';
const UPLOAD_URL = 'https://images.lkong.com/upload';
const MIN_INTERVAL_MS = 800;
const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 LkongHarmony/1.0';

export interface HttpJsonResponse {
  body: string;
  cookies: string;
  statusCode: number;
}

export class HttpClient {
  private static instance: HttpClient = new HttpClient();
  private lastRequestAt: number = 0;

  static getInstance(): HttpClient {
    return HttpClient.instance;
  }

  /**
   * GraphQL 请求统一走这里。密码只在 payload 中短暂存在，不落盘。
   *
   * 注意：HTTP 非 200 时也返回 body，交由 GraphqlClient 解析 GraphQL errors。
   * 例如未登录访问 ViewForumPage 会返回 HTTP 500 + {"errors":[...]}。
   */
  async postJson(url: string, payload: string): Promise<HttpJsonResponse> {
    this.assertAllowedApiUrl(url);
    await this.waitForSlot();

    const header = this.buildCommonHeader();
    header['Accept'] = '*/*';
    header['Content-Type'] = 'application/json';

    const request = http.createHttp();
    try {
      request.enableAutoCookie(true);
    } catch (error) {
      // 旧运行时可能不支持自动 Cookie；下面的 Set-Cookie 解析仍然有效。
    }

    try {
      const response = await request.request(url, {
        method: http.RequestMethod.POST,
        header: header,
        extraData: payload,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 20000,
        usingCache: false
      });

      /**
       * 龙空登录成功后通过 Set-Cookie 返回 EGG_SESS。
       * 部分 HarmonyOS 版本的 response.cookies 为空，因此这里再从响应头兜底提取。
       */
      let cookies = response.cookies;
      const setCookie = extractSetCookie(response.header);
      if (setCookie.length > 0) {
        cookies = cookies.length > 0 ? `${cookies}; ${setCookie}` : setCookie;
      }

      const result: HttpJsonResponse = {
        body: response.result as string,
        cookies: cookies,
        statusCode: response.responseCode as number
      };
      return result;
    } catch (error) {
      if (error instanceof ApiError) {
        throw error;
      }
      throw new ApiError(ErrorKind.NETWORK, '网络请求失败，请检查网络连接后重试。');
    } finally {
      request.destroy();
    }
  }

  async uploadImage(
    url: string,
    data: ArrayBuffer,
    fileName: string,
    contentType: string
  ): Promise<HttpJsonResponse> {
    this.assertAllowedUploadUrl(url);
    if (!CookieStore.getInstance().hasCookie()) {
      throw new ApiError(ErrorKind.AUTH, '请先登录后再上传图片。');
    }
    await this.waitForSlot();

    const header = this.buildCommonHeader();
    header['Accept'] = '*/*';
    header['Content-Type'] = 'multipart/form-data';

    const formPart: http.MultiFormData = {
      name: 'file',
      contentType: contentType,
      remoteFileName: fileName,
      data: data
    };
    const multiFormDataList: http.MultiFormData[] = [formPart];

    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.POST,
        header: header,
        multiFormDataList: multiFormDataList,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 45000,
        usingCache: false
      });

      const result: HttpJsonResponse = {
        body: response.result as string,
        cookies: '',
        statusCode: response.responseCode as number
      };
      return result;
    } catch (error) {
      if (error instanceof ApiError) {
        throw error;
      }
      throw new ApiError(ErrorKind.NETWORK, '图片上传失败，请检查网络连接后重试。');
    } finally {
      request.destroy();
    }
  }

  private buildCommonHeader(): Record<string, string> {
    const header: Record<string, string> = {
      'User-Agent': USER_AGENT,
      'Accept-Language': 'zh-CN,zh;q=0.9',
      'Referer': 'https://www.lkong.com/'
    };
    const cookie = CookieStore.getInstance().getCookie();
    if (cookie.length > 0) {
      header['Cookie'] = cookie;
    }
    return header;
  }

  private assertAllowedApiUrl(url: string): void {
    if (url !== API_URL) {
      throw new ApiError(ErrorKind.UNKNOWN, '接口请求域名不在白名单内。');
    }
  }

  private assertAllowedUploadUrl(url: string): void {
    if (url !== UPLOAD_URL) {
      throw new ApiError(ErrorKind.UNKNOWN, '上传地址不在白名单内。');
    }
  }

  /**
   * 简单串行节流：不并发、不批量抓取。
   */
  private async waitForSlot(): Promise<void> {
    const now = Date.now();
    const wait = MIN_INTERVAL_MS - (now - this.lastRequestAt);
    if (wait > 0) {
      await new Promise<void>((resolve) => {
        setTimeout(() => {
          resolve();
        }, wait);
      });
    }
    this.lastRequestAt = Date.now();
  }
}

/**
 * 从响应头中提取 Set-Cookie。Header key 大小写在不同实现中可能不同。
 */
function extractSetCookie(header: Object): string {
  try {
    const headers = header as Record<string, Object>;
    const keys = Object.keys(headers);
    for (const key of keys) {
      if (key.toLowerCase() === 'set-cookie') {
        return headerValueToString(headers[key]);
      }
    }
  } catch (error) {
    return '';
  }
  return '';
}

function headerValueToString(value: Object | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (Array.isArray(value)) {
    const values = value as string[];
    return values.join('; ');
  }
  return '';
}