import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { ApiError, ErrorKind } from '../model/ApiErrors';
import { AuthStore } from '../store/AuthStore';
import { AppConfig } from '../utils/AppConfig';
import { asRecord, pickNumber, pickObject, pickString } from './JsonUtils';

export interface HttpResponseResult {
  statusCode: number;
  body: string;
  setCookie: string;
}

export interface SseStreamCallbacks {
  onChunk: (textChunk: string) => void;
  onComplete: () => void;
  onError: (error: ApiError) => void;
}

export interface StreamHandle {
  abort: () => void;
}

export class DeepSeekHttp {
  private static instance: DeepSeekHttp = new DeepSeekHttp();

  static getInstance(): DeepSeekHttp {
    return DeepSeekHttp.instance;
  }

  async getJson(path: string): Promise<HttpResponseResult> {
    return this.requestJson(http.RequestMethod.GET, path, undefined, undefined);
  }

  async postJson(
    path: string,
    bodyObj: Object | undefined,
    extraHeaders?: Record<string, string>
  ): Promise<HttpResponseResult> {
    return this.requestJson(http.RequestMethod.POST, path, bodyObj, extraHeaders);
  }

  async uploadMultipartFile(
    path: string,
    fileBytes: Uint8Array,
    fileName: string,
    mimeType: string,
    extraHeaders?: Record<string, string>
  ): Promise<HttpResponseResult> {
    const url = this.buildAllowedUrl(path);
    const boundary = `----DeepSeekHarmonyBoundary${Date.now()}${Math.floor(Math.random() * 10000)}`;
    const safeName = fileName.replace(/"/g, '_').replace(/\r/g, '').replace(/\n/g, '');
    const resolvedMime = mimeType.length > 0 ? mimeType : 'application/octet-stream';

    const prefixStr =
      `--${boundary}\r\n` +
      `Content-Disposition: form-data; name="file"; filename="${safeName}"\r\n` +
      `Content-Type: ${resolvedMime}\r\n\r\n`;
    const suffixStr = `\r\n--${boundary}--\r\n`;

    const encoder = util.TextEncoder.create('utf-8');
    const prefixBytes = encoder.encodeInto(prefixStr);
    const suffixBytes = encoder.encodeInto(suffixStr);

    const totalLen = prefixBytes.length + fileBytes.length + suffixBytes.length;
    const bodyBuffer = new ArrayBuffer(totalLen);
    const bodyView = new Uint8Array(bodyBuffer);
    bodyView.set(prefixBytes, 0);
    bodyView.set(fileBytes, prefixBytes.length);
    bodyView.set(suffixBytes, prefixBytes.length + fileBytes.length);

    const header = this.buildBaseHeaders();
    header['Accept'] = 'application/json';
    header['Content-Type'] = `multipart/form-data; boundary=${boundary}`;
    header['x-file-size'] = String(fileBytes.length);
    if (extraHeaders !== undefined) {
      const keys = Object.keys(extraHeaders);
      for (const k of keys) {
        header[k] = extraHeaders[k];
      }
    }

    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.POST,
        header: header,
        extraData: bodyBuffer,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 60000,
        usingCache: false
      });

      const setCookie = extractSetCookie(response.header);
      if (setCookie.length > 0) {
        await AuthStore.getInstance().mergeSetCookie(setCookie);
      }

      return {
        statusCode: response.responseCode as number,
        body: typeof response.result === 'string' ? response.result : String(response.result),
        setCookie: setCookie
      };
    } catch (error) {
      if (error instanceof ApiError) {
        throw error;
      }
      throw new ApiError(ErrorKind.NETWORK, '文件上传网络请求失败，请检查网络连接后重试。');
    } finally {
      request.destroy();
    }
  }

  streamSse(
    path: string,
    bodyObj: Object,
    extraHeaders: Record<string, string>,
    callbacks: SseStreamCallbacks
  ): StreamHandle {
    const url = this.buildAllowedUrl(path);
    const header = this.buildBaseHeaders();
    header['Accept'] = 'text/event-stream';
    header['Content-Type'] = 'application/json';
    header['Cache-Control'] = 'no-cache';

    const extraKeys = Object.keys(extraHeaders);
    for (const key of extraKeys) {
      header[key] = extraHeaders[key];
    }

    const request = http.createHttp();
    const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });

    let aborted = false;
    let settled = false;
    let headerStatus = 0;
    let isNonSseBody = false;
    let cfMitigated = false;
    let nonSseBuffer = '';
    let dataEndFired = false;
    let requestResolved = false;

    const cleanup = (): void => {
      try {
        request.off('headersReceive');
        request.off('dataReceive');
        request.off('dataEnd');
        request.destroy();
      } catch (err) {
        // 忽略清理异常。
      }
    };

    const finishOrFailIfReady = (): void => {
      if (settled || aborted) {
        return;
      }
      if (!dataEndFired && !requestResolved) {
        return;
      }

      if (cfMitigated || headerStatus === 403 || looksLikeHtmlChallenge(nonSseBuffer)) {
        settled = true;
        cleanup();
        callbacks.onError(
          new ApiError(
            ErrorKind.RISK_CONTROL,
            '触发安全验证，请在网页验证窗口完成验证后继续。',
            headerStatus || 403
          )
        );
        return;
      }

      if (headerStatus === 401) {
        settled = true;
        cleanup();
        callbacks.onError(new ApiError(ErrorKind.UNAUTHORIZED, '登录状态已失效，请重新登录。', 401));
        return;
      }

      if (headerStatus === 429) {
        settled = true;
        cleanup();
        callbacks.onError(new ApiError(ErrorKind.RATE_LIMIT, '请求过于频繁，请稍后再试。', 429));
        return;
      }

      if (headerStatus >= 400 || (isNonSseBody && nonSseBuffer.trim().length > 0)) {
        const parsedErr = tryBuildApiErrorFromBody(nonSseBuffer, headerStatus);
        if (parsedErr !== null) {
          settled = true;
          cleanup();
          callbacks.onError(parsedErr);
          return;
        }
        if (headerStatus >= 400) {
          settled = true;
          cleanup();
          callbacks.onError(
            new ApiError(ErrorKind.SERVER, `服务器返回错误状态 (${headerStatus})。`, headerStatus)
          );
          return;
        }
      }

      if (dataEndFired) {
        settled = true;
        cleanup();
        callbacks.onComplete();
      }
    };

    request.on('headersReceive', (headerObj: Object) => {
      if (aborted) {
        return;
      }
      const headers = asRecord(headerObj);
      const keys = Object.keys(headers);
      for (const k of keys) {
        const lower = k.toLowerCase();
        const val = headerValueToString(headers[k]);
        if (lower === 'set-cookie' && val.length > 0) {
          AuthStore.getInstance().mergeSetCookie(val);
        } else if (lower === 'cf-mitigated' && val.toLowerCase().includes('challenge')) {
          cfMitigated = true;
        } else if (lower === 'content-type') {
          const ct = val.toLowerCase();
          if (ct.includes('text/html') || ct.includes('application/json')) {
            isNonSseBody = true;
          }
        }
      }
    });

    request.on('dataReceive', (data: ArrayBuffer) => {
      if (aborted || settled) {
        return;
      }
      const uint8 = new Uint8Array(data);
      const decoded = decoder.decodeToString(uint8, { stream: true });
      if (decoded.length === 0) {
        return;
      }
      if (isNonSseBody || (nonSseBuffer.length === 0 && looksLikeJsonOrHtmlPrefix(decoded))) {
        isNonSseBody = true;
        nonSseBuffer += decoded;
        return;
      }
      callbacks.onChunk(decoded);
    });

    request.on('dataEnd', () => {
      if (aborted || settled) {
        return;
      }
      const tail = decoder.decodeToString(new Uint8Array(0), { stream: false });
      if (tail.length > 0) {
        if (isNonSseBody) {
          nonSseBuffer += tail;
        } else {
          callbacks.onChunk(tail);
        }
      }
      dataEndFired = true;
      finishOrFailIfReady();
    });

    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: header,
      extraData: JSON.stringify(bodyObj),
      connectTimeout: 20000,
      readTimeout: 120000,
      usingCache: false
    };

    request.requestInStream(url, options).then((responseCode: number) => {
      requestResolved = true;
      headerStatus = responseCode;
      finishOrFailIfReady();
    }).catch((err: BusinessError) => {
      if (aborted || settled) {
        return;
      }
      settled = true;
      cleanup();
      const msg = err && err.message ? err.message : '流式连接中断，请检查网络后重试。';
      callbacks.onError(new ApiError(ErrorKind.NETWORK, msg));
    });

    return {
      abort: (): void => {
        if (aborted) {
          return;
        }
        aborted = true;
        settled = true;
        cleanup();
      }
    };
  }

  private async requestJson(
    method: http.RequestMethod,
    path: string,
    bodyObj: Object | undefined,
    extraHeaders?: Record<string, string>
  ): Promise<HttpResponseResult> {
    const url = this.buildAllowedUrl(path);
    const header = this.buildBaseHeaders();
    header['Accept'] = 'application/json';
    if (method === http.RequestMethod.POST) {
      header['Content-Type'] = 'application/json';
    }
    if (extraHeaders !== undefined) {
      const keys = Object.keys(extraHeaders);
      for (const k of keys) {
        header[k] = extraHeaders[k];
      }
    }

    const request = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: method,
        header: header,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000,
        usingCache: false
      };
      if (bodyObj !== undefined) {
        options.extraData = JSON.stringify(bodyObj);
      }

      const response = await request.request(url, options);
      const setCookie = extractSetCookie(response.header);
      if (setCookie.length > 0) {
        await AuthStore.getInstance().mergeSetCookie(setCookie);
      }

      return {
        statusCode: response.responseCode as number,
        body: typeof response.result === 'string' ? response.result : String(response.result),
        setCookie: setCookie
      };
    } catch (error) {
      if (error instanceof ApiError) {
        throw error;
      }
      throw new ApiError(ErrorKind.NETWORK, '网络请求失败，请检查网络连接后重试。');
    } finally {
      request.destroy();
    }
  }

  private buildBaseHeaders(): Record<string, string> {
    const header: Record<string, string> = {
      'User-Agent': AppConfig.USER_AGENT,
      'Accept-Language': 'zh-CN,zh;q=0.9',
      'Origin': AppConfig.BASE_URL,
      'Referer': `${AppConfig.BASE_URL}/`,
      'x-client-platform': AppConfig.CLIENT_PLATFORM,
      'x-client-version': AppConfig.CLIENT_VERSION,
      'x-app-version': AppConfig.APP_HEADER_VERSION,
      'x-client-locale': 'zh_CN'
    };

    const token = AuthStore.getInstance().getToken();
    if (token.length > 0) {
      header['Authorization'] = `Bearer ${token}`;
    }
    const cookie = AuthStore.getInstance().getCookie();
    if (cookie.length > 0) {
      header['Cookie'] = cookie;
    }
    return header;
  }

  private buildAllowedUrl(path: string): string {
    if (!path.startsWith('/')) {
      throw new ApiError(ErrorKind.UNKNOWN, '非法接口路径。');
    }
    const fullUrl = `${AppConfig.BASE_URL}${path}`;
    if (!fullUrl.startsWith(`${AppConfig.BASE_URL}/`)) {
      throw new ApiError(ErrorKind.UNKNOWN, '接口域名不在白名单内。');
    }
    return fullUrl;
  }
}

export function unwrapBizData(result: HttpResponseResult): Record<string, Object> {
  if (result.statusCode === 401) {
    throw new ApiError(ErrorKind.UNAUTHORIZED, '登录状态已失效，请重新登录。', 401);
  }
  if (result.statusCode === 403 || looksLikeHtmlChallenge(result.body)) {
    throw new ApiError(
      ErrorKind.RISK_CONTROL,
      '触发安全验证，请在网页验证窗口完成验证后重试。',
      result.statusCode || 403
    );
  }
  if (result.statusCode === 429) {
    throw new ApiError(ErrorKind.RATE_LIMIT, '请求过于频繁，请稍后再试。', 429);
  }

  let parsed: Object;
  try {
    parsed = JSON.parse(result.body) as Object;
  } catch (err) {
    if (result.statusCode >= 500) {
      throw new ApiError(ErrorKind.SERVER, `DeepSeek 服务暂不可用 (${result.statusCode})。`, result.statusCode);
    }
    throw new ApiError(ErrorKind.SERVER, '服务器响应解析失败，请稍后重试。', result.statusCode);
  }

  const root = asRecord(parsed);
  const topCode = pickNumber(root, ['code']);
  const topMsg = pickString(root, ['msg', 'message']);

  if (topCode !== 0) {
    throw mapErrorFromCodeAndMsg(result.statusCode, topCode, topMsg);
  }

  const data = pickObject(root, ['data']);
  const dataKeys = Object.keys(data);
  if (dataKeys.length === 0) {
    if (result.statusCode >= 400) {
      throw mapErrorFromCodeAndMsg(result.statusCode, topCode, topMsg);
    }
    return root;
  }

  const bizCode = pickNumber(data, ['biz_code']);
  const bizMsg = pickString(data, ['biz_msg']);
  if (bizCode !== 0) {
    throw mapErrorFromCodeAndMsg(result.statusCode, bizCode, bizMsg.length > 0 ? bizMsg : topMsg);
  }

  const bizData = pickObject(data, ['biz_data']);
  if (Object.keys(bizData).length > 0) {
    return bizData;
  }
  return data;
}

function tryBuildApiErrorFromBody(body: string, statusCode: number): ApiError | null {
  const trimmed = body.trim();
  if (trimmed.length === 0) {
    return null;
  }
  if (looksLikeHtmlChallenge(trimmed)) {
    return new ApiError(
      ErrorKind.RISK_CONTROL,
      '触发安全验证，请在网页验证窗口完成验证后重试。',
      statusCode || 403
    );
  }
  try {
    const root = asRecord(JSON.parse(trimmed) as Object);
    const data = pickObject(root, ['data']);
    const bizCode = pickNumber(data, ['biz_code']);
    const bizMsg = pickString(data, ['biz_msg']);
    const topCode = pickNumber(root, ['code']);
    const topMsg = pickString(root, ['msg', 'message', 'detail']);
    const code = bizCode !== 0 ? bizCode : topCode;
    const msg = bizMsg.length > 0 ? bizMsg : topMsg;
    if (code !== 0 || msg.length > 0 || statusCode >= 400) {
      return mapErrorFromCodeAndMsg(statusCode, code, msg);
    }
  } catch (err) {
    // 非 JSON 忽略。
  }
  return null;
}

function mapErrorFromCodeAndMsg(httpStatus: number, bizCode: number, msg: string): ApiError {
  const lower = msg.toLowerCase();
  if (
    httpStatus === 401 ||
    bizCode === 401 ||
    bizCode === 10002 ||
    bizCode === 10003 ||
    lower.includes('unauthorized') ||
    lower.includes('token') ||
    lower.includes('登录')
  ) {
    return new ApiError(
      ErrorKind.UNAUTHORIZED,
      msg.length > 0 ? msg : '登录状态已失效，请重新登录。',
      httpStatus,
      bizCode
    );
  }
  if (
    httpStatus === 403 ||
    lower.includes('challenge') ||
    lower.includes('pow') ||
    lower.includes('captcha') ||
    lower.includes('风控') ||
    lower.includes('验证')
  ) {
    return new ApiError(
      ErrorKind.RISK_CONTROL,
      msg.length > 0 ? msg : '触发安全校验，请尝试在网页验证后重试。',
      httpStatus,
      bizCode
    );
  }
  if (httpStatus === 429 || lower.includes('too many') || lower.includes('rate') || lower.includes('频繁')) {
    return new ApiError(
      ErrorKind.RATE_LIMIT,
      msg.length > 0 ? msg : '请求过于频繁，请稍后再试。',
      httpStatus,
      bizCode
    );
  }
  return new ApiError(
    ErrorKind.SERVER,
    msg.length > 0 ? msg : `请求失败 (${bizCode || httpStatus})`,
    httpStatus,
    bizCode
  );
}

function looksLikeHtmlChallenge(body: string): boolean {
  const lower = body.trim().toLowerCase();
  if (lower.startsWith('<!doctype html') || lower.startsWith('<html')) {
    return true;
  }
  return lower.includes('cf-browser-verification') || lower.includes('just a moment');
}

function looksLikeJsonOrHtmlPrefix(chunk: string): boolean {
  const trimmed = chunk.trimStart();
  if (trimmed.startsWith('<!') || trimmed.startsWith('<html')) {
    return true;
  }
  // 注意正常 SSE 以 "data:" / "event:" / ":" 开头；纯 JSON 错误响应直接以 "{" 开头
  return trimmed.startsWith('{');
}

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
