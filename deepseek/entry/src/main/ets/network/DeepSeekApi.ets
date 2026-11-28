import { fileIo } from '@kit.CoreFileKit';
import { ApiError, ErrorKind } from '../model/ApiErrors';
import {
  ChatMessage,
  ChatSession,
  CompletionParams,
  MessageFeedback,
  MessageFragment,
  MessageRole,
  MessageStatus,
  PowChallenge,
  SearchSource,
  SessionPage,
  UploadedAttachment,
  UserProfile
} from '../model/ChatModels';
import { AuthStore } from '../store/AuthStore';
import { AppConfig } from '../utils/AppConfig';
import { DeepSeekHttp, StreamHandle, unwrapBizData } from './DeepSeekHttp';
import {
  asRecord,
  pickArray,
  pickBoolean,
  pickNullableNumber,
  pickNumber,
  pickObject,
  pickString
} from './JsonUtils';
import { PowSolver } from './PowSolver';
import { parseFragmentList, parseSearchResults, SsePatchCallbacks, SsePatchParser } from './SsePatchParser';

const MAX_UPLOAD_BYTES = 50 * 1024 * 1024;

export interface UploadProgressStage {
  stage: 'reading' | 'pow' | 'uploading' | 'parsing';
}

export class DeepSeekApi {
  private static instance: DeepSeekApi = new DeepSeekApi();

  static getInstance(): DeepSeekApi {
    return DeepSeekApi.instance;
  }

  async getCurrentUser(): Promise<UserProfile> {
    const res = await DeepSeekHttp.getInstance().getJson('/api/v0/users/current');
    const bizData = unwrapBizData(res);
    const userObj = Object.keys(pickObject(bizData, ['user'])).length > 0
      ? pickObject(bizData, ['user'])
      : bizData;

    const token = pickString(userObj, ['token']);
    if (token.length > 0) {
      await AuthStore.getInstance().setAuth(token, '');
    }

    const email = pickString(userObj, ['email']);
    const mobile = pickString(userObj, ['mobile_number', 'mobile']);
    const nick = pickString(userObj, ['name', 'nickname']);
    const displayName = nick.length > 0 ? nick : (email.length > 0 ? email : mobile);

    const profile: UserProfile = {
      id: pickString(userObj, ['id', 'user_id']),
      email: email,
      mobileNumber: mobile,
      name: displayName.length > 0 ? displayName : 'DeepSeek 用户',
      avatarUrl: pickString(userObj, ['avatar_url', 'avatar']),
      hasToken: AuthStore.getInstance().hasAuth()
    };

    await AuthStore.getInstance().setUserProfile(profile);
    return profile;
  }

  async loginWithPassword(account: string, password: string): Promise<UserProfile> {
    const trimmed = account.trim();
    if (trimmed.length === 0 || password.length === 0) {
      throw new ApiError(ErrorKind.UNKNOWN, '请输入账号和密码。');
    }

    const body: Record<string, Object> = {
      'password': password,
      'device_id': AuthStore.getInstance().getDeviceId(),
      'os': 'web'
    };

    if (trimmed.includes('@')) {
      body['email'] = trimmed;
    } else {
      body['mobile'] = trimmed;
      body['area_code'] = '+86';
    }

    const res = await DeepSeekHttp.getInstance().postJson('/api/v0/users/login', body);
    const bizData = unwrapBizData(res);
    const userObj = Object.keys(pickObject(bizData, ['user'])).length > 0
      ? pickObject(bizData, ['user'])
      : bizData;

    const token = pickString(userObj, ['token', 'access_token']);
    if (token.length === 0 && !AuthStore.getInstance().hasAuth()) {
      throw new ApiError(ErrorKind.UNAUTHORIZED, '登录未返回有效令牌，建议使用“网页登录”。');
    }

    await AuthStore.getInstance().setAuth(token, res.setCookie);
    return await this.getCurrentUser();
  }

  async fetchSessions(count: number = 50, beforeCursor: string = ''): Promise<SessionPage> {
    let path = `/api/v0/chat_session/fetch_page?lte_cursor.pinned=false&count=${count}`;
    if (beforeCursor.length > 0) {
      path += `&lte_cursor.updated_at=${encodeURIComponent(beforeCursor)}`;
    }
    const res = await DeepSeekHttp.getInstance().getJson(path);
    const bizData = unwrapBizData(res);

    const rawSessions = pickArray(bizData, ['chat_sessions', 'sessions']);
    const sessions: ChatSession[] = [];
    for (const item of rawSessions) {
      const rec = asRecord(item);
      const id = pickString(rec, ['id', 'chat_session_id']);
      if (id.length === 0) {
        continue;
      }
      const title = pickString(rec, ['title']);
      sessions.push({
        id: id,
        title: title.length > 0 ? title : '新对话',
        updatedAt: pickNumber(rec, ['updated_at']),
        insertedAt: pickNumber(rec, ['inserted_at']),
        pinned: pickBoolean(rec, ['pinned'])
      });
    }

    const hasMore = pickBoolean(bizData, ['has_more']);
    let nextCursor = '';
    if (sessions.length > 0) {
      const last = sessions[sessions.length - 1];
      if (last.updatedAt > 0) {
        nextCursor = String(last.updatedAt);
      }
    }

    return {
      sessions: sessions,
      hasMore: hasMore,
      nextCursor: nextCursor
    };
  }

  async createSession(): Promise<ChatSession> {
    const primaryBody: Record<string, Object> = {
      'agent': 'chat'
    };
    let lastStatus = 0;
    let lastKeys = '';

    try {
      const res = await DeepSeekHttp.getInstance().postJson('/api/v0/chat_session/create', primaryBody);
      lastStatus = res.statusCode;
      const bizData = unwrapBizData(res);
      lastKeys = Object.keys(bizData).join(',');
      const parsed = parseCreatedSessionFromBizData(bizData);
      if (parsed !== null) {
        return parsed;
      }
    } catch (error) {
      if (
        error instanceof ApiError &&
        (error.kind === ErrorKind.UNAUTHORIZED ||
          error.kind === ErrorKind.RISK_CONTROL ||
          error.kind === ErrorKind.RATE_LIMIT ||
          error.kind === ErrorKind.NETWORK)
      ) {
        throw error;
      }
    }

    const legacyBody: Record<string, Object | null> = {
      'character_id': null
    };
    const fallbackRes = await DeepSeekHttp.getInstance().postJson('/api/v0/chat_session/create', legacyBody);
    lastStatus = fallbackRes.statusCode;
    const fallbackBizData = unwrapBizData(fallbackRes);
    lastKeys = Object.keys(fallbackBizData).join(',');
    const fallbackParsed = parseCreatedSessionFromBizData(fallbackBizData);
    if (fallbackParsed !== null) {
      return fallbackParsed;
    }

    const keysDesc = lastKeys.length > 0 ? lastKeys : '空';
    throw new ApiError(
      ErrorKind.SERVER,
      `创建对话失败：未返回会话 ID（HTTP ${lastStatus}，返回字段: ${keysDesc}）。`
    );
  }

  async updateSessionTitle(sessionId: string, title: string): Promise<void> {
    const body: Record<string, Object> = {
      'chat_session_id': sessionId,
      'title': title
    };
    const res = await DeepSeekHttp.getInstance().postJson('/api/v0/chat_session/update_title', body);
    unwrapBizData(res);
  }

  async deleteSession(sessionId: string): Promise<void> {
    const body: Record<string, Object> = {
      'chat_session_id': sessionId
    };
    const res = await DeepSeekHttp.getInstance().postJson('/api/v0/chat_session/delete', body);
    unwrapBizData(res);
  }

  async deleteAllSessions(): Promise<void> {
    const emptyBody: Record<string, Object> = {};
    const res = await DeepSeekHttp.getInstance().postJson('/api/v0/chat_session/delete_all_sessions', emptyBody);
    unwrapBizData(res);
  }

  async getHistoryMessages(sessionId: string): Promise<ChatMessage[]> {
    const path = `/api/v0/chat/history_messages?chat_session_id=${encodeURIComponent(sessionId)}`;
    const res = await DeepSeekHttp.getInstance().getJson(path);
    const bizData = unwrapBizData(res);

    let rawMsgs = pickArray(bizData, ['chat_messages', 'messages']);
    if (rawMsgs.length === 0) {
      const nestedSession = pickObject(bizData, ['chat_session', 'session']);
      rawMsgs = pickArray(nestedSession, ['chat_messages', 'messages']);
    }
    const messages: ChatMessage[] = [];
    for (const item of rawMsgs) {
      const rec = asRecord(item);
      const msg = parseHistoryMessage(rec);
      if (msg !== null) {
        messages.push(msg);
      }
    }
    return messages;
  }

  async createPowChallenge(targetPath: string): Promise<PowChallenge> {
    const body: Record<string, Object> = {
      'target_path': targetPath
    };
    const res = await DeepSeekHttp.getInstance().postJson('/api/v0/chat/create_pow_challenge', body);
    const bizData = unwrapBizData(res);
    const challengeObj = Object.keys(pickObject(bizData, ['challenge'])).length > 0
      ? pickObject(bizData, ['challenge'])
      : bizData;

    const algorithm = pickString(challengeObj, ['algorithm']);
    const challenge = pickString(challengeObj, ['challenge']);
    const salt = pickString(challengeObj, ['salt']);
    const difficulty = pickNumber(challengeObj, ['difficulty']);
    const expireAt = pickNumber(challengeObj, ['expire_at']);
    const signature = pickString(challengeObj, ['signature']);

    if (algorithm.length === 0 || challenge.length === 0 || salt.length === 0) {
      throw new ApiError(ErrorKind.POW_FAILED, '获取安全校验挑战失败，请稍后重试。');
    }

    return {
      algorithm: algorithm,
      challenge: challenge,
      salt: salt,
      difficulty: difficulty > 0 ? difficulty : 144000,
      expireAt: expireAt,
      signature: signature,
      targetPath: targetPath
    };
  }

  async startCompletionStream(
    params: CompletionParams,
    callbacks: SsePatchCallbacks,
    onStreamError: (error: ApiError) => void,
    preFetchedChallenge?: PowChallenge,
    onStage?: (stage: 'pow' | 'connecting') => void
  ): Promise<StreamHandle> {
    const payload: Record<string, Object | null> = {
      'chat_session_id': params.sessionId,
      'parent_message_id': params.parentMessageId,
      'prompt': params.prompt,
      'ref_file_ids': params.refFileIds,
      'thinking_enabled': params.thinkingEnabled,
      'search_enabled': params.searchEnabled,
      'preempt': false,
      'client_stream_id': generateClientStreamId()
    };
    return this.openPowSseStream(
      '/api/v0/chat/completion',
      payload,
      callbacks,
      onStreamError,
      preFetchedChallenge,
      onStage
    );
  }

  async startRegenerateStream(
    sessionId: string,
    messageId: number,
    thinkingEnabled: boolean,
    searchEnabled: boolean,
    callbacks: SsePatchCallbacks,
    onStreamError: (error: ApiError) => void,
    preFetchedChallenge?: PowChallenge,
    onStage?: (stage: 'pow' | 'connecting') => void
  ): Promise<StreamHandle> {
    const payload: Record<string, Object> = {
      'chat_session_id': sessionId,
      'message_id': messageId,
      'thinking_enabled': thinkingEnabled,
      'search_enabled': searchEnabled,
      'preempt': false,
      'client_stream_id': generateClientStreamId()
    };
    return this.openPowSseStream(
      '/api/v0/chat/regenerate',
      payload,
      callbacks,
      onStreamError,
      preFetchedChallenge,
      onStage
    );
  }

  private async openPowSseStream(
    targetPath: string,
    payload: Object,
    callbacks: SsePatchCallbacks,
    onStreamError: (error: ApiError) => void,
    preFetchedChallenge?: PowChallenge,
    onStage?: (stage: 'pow' | 'connecting') => void
  ): Promise<StreamHandle> {
    if (onStage !== undefined) {
      onStage('pow');
    }
    const challenge = preFetchedChallenge !== undefined
      ? preFetchedChallenge
      : await this.createPowChallenge(targetPath);
    const powHeader = await PowSolver.solve(challenge);
    if (onStage !== undefined) {
      onStage('connecting');
    }

    const extraHeaders: Record<string, string> = {
      'X-Ds-Pow-Response': powHeader
    };

    const parser = new SsePatchParser(callbacks);
    return DeepSeekHttp.getInstance().streamSse(targetPath, payload, extraHeaders, {
      onChunk: (chunk: string): void => {
        parser.feedChunk(chunk);
      },
      onComplete: (): void => {
        parser.flush();
      },
      onError: (err: ApiError): void => {
        onStreamError(err);
      }
    });
  }

  async stopStream(sessionId: string, messageId: number): Promise<void> {
    if (sessionId.length === 0 || messageId <= 0) {
      return;
    }
    const body: Record<string, Object> = {
      'chat_session_id': sessionId,
      'message_id': messageId
    };
    try {
      const res = await DeepSeekHttp.getInstance().postJson('/api/v0/chat/stop_stream', body);
      unwrapBizData(res);
    } catch (error) {
      // 停止流可能与服务端自然结束竞态，忽略即可。
    }
  }

  async uploadFileFromUri(
    localUri: string,
    fileName: string,
    mimeType: string,
    isImage: boolean,
    onStage?: (stage: 'reading' | 'pow' | 'uploading' | 'parsing') => void
  ): Promise<UploadedAttachment> {
    if (onStage !== undefined) {
      onStage('reading');
    }
    const fileBytes = readUriBytes(localUri);
    if (fileBytes.length === 0) {
      throw new ApiError(ErrorKind.UNKNOWN, '无法读取所选文件内容。');
    }
    if (fileBytes.length > MAX_UPLOAD_BYTES) {
      throw new ApiError(ErrorKind.UNKNOWN, '单个文件大小超过 50MB 限制。');
    }

    if (onStage !== undefined) {
      onStage('pow');
    }
    const targetPath = '/api/v0/file/upload_file';
    const challenge = await this.createPowChallenge(targetPath);
    const powHeader = await PowSolver.solve(challenge);

    if (onStage !== undefined) {
      onStage('uploading');
    }
    const extraHeaders: Record<string, string> = {
      'X-Ds-Pow-Response': powHeader
    };
    const res = await DeepSeekHttp.getInstance().uploadMultipartFile(
      targetPath,
      fileBytes,
      fileName,
      mimeType,
      extraHeaders
    );
    const bizData = unwrapBizData(res);
    const fileId = pickString(bizData, ['id', 'file_id']);
    if (fileId.length === 0) {
      throw new ApiError(ErrorKind.SERVER, '文件上传成功但未返回文件 ID。');
    }

    const initialStatus = pickString(bizData, ['status']).toUpperCase();
    if (initialStatus === 'SUCCESS') {
      return {
        id: fileId,
        fileName: fileName,
        fileSize: fileBytes.length,
        mimeType: mimeType,
        localUri: localUri,
        isImage: isImage,
        status: 'ready',
        errorMessage: ''
      };
    }

    if (onStage !== undefined) {
      onStage('parsing');
    }
    const finalStatus = await this.pollFileReady(fileId);
    if (finalStatus !== 'SUCCESS') {
      throw new ApiError(ErrorKind.SERVER, '文件解析失败，请更换文件或重新上传。');
    }

    return {
      id: fileId,
      fileName: fileName,
      fileSize: fileBytes.length,
      mimeType: mimeType,
      localUri: localUri,
      isImage: isImage,
      status: 'ready',
      errorMessage: ''
    };
  }

  async createShareLink(sessionId: string, messageIds: number[]): Promise<string> {
    const body: Record<string, Object> = {
      'chat_session_id': sessionId,
      'message_ids': messageIds
    };
    const res = await DeepSeekHttp.getInstance().postJson('/api/v0/share/create', body);
    const bizData = unwrapBizData(res);
    const directUrl = pickString(bizData, ['url', 'share_url']);
    if (directUrl.length > 0) {
      return directUrl;
    }
    const shareId = pickString(bizData, ['share_id', 'id']);
    if (shareId.length === 0) {
      throw new ApiError(ErrorKind.SERVER, '生成分享链接失败。');
    }
    return `${AppConfig.BASE_URL}/share/${shareId}`;
  }

  async submitFeedback(sessionId: string, messageId: number, feedback: MessageFeedback): Promise<void> {
    const body: Record<string, Object> = {
      'chat_session_id': sessionId,
      'message_id': messageId,
      'feedback': feedback === 'none' ? 'cancel' : feedback
    };
    const res = await DeepSeekHttp.getInstance().postJson('/api/v0/chat/message_feedback', body);
    unwrapBizData(res);
  }

  private async pollFileReady(fileId: string): Promise<string> {
    const maxAttempts = 30;
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      await delayMs(1200);
      const path = `/api/v0/file/fetch_files?file_ids=${encodeURIComponent(fileId)}`;
      const res = await DeepSeekHttp.getInstance().getJson(path);
      const bizData = unwrapBizData(res);
      const files = pickArray(bizData, ['files']);
      if (files.length > 0) {
        const first = asRecord(files[0]);
        const status = pickString(first, ['status']).toUpperCase();
        if (status === 'SUCCESS') {
          return 'SUCCESS';
        }
        if (status === 'FAILED' || status === 'ERROR') {
          return 'FAILED';
        }
      }
    }
    return 'FAILED';
  }
}

function parseHistoryMessage(rec: Record<string, Object>): ChatMessage | null {
  const messageId = pickNumber(rec, ['message_id', 'id']);
  if (messageId <= 0) {
    return null;
  }
  const parentId = pickNullableNumber(rec, ['parent_id', 'parent_message_id']);
  const rawRole = pickString(rec, ['role']).toUpperCase();
  const role: MessageRole = rawRole === 'USER' ? 'USER' : 'ASSISTANT';

  let thinkingContent = pickString(rec, ['thinking_content']);
  let thinkingElapsedSecs = pickNumber(rec, ['thinking_elapsed_secs']);
  let content = pickString(rec, ['content']);
  let searchQueries: string[] = [];
  let searchResults: SearchSource[] = [];

  const rawFragments = pickArray(rec, ['fragments']);
  if (rawFragments.length > 0) {
    const parsedFragments: MessageFragment[] = parseFragmentList(rawFragments);
    const contentParts: string[] = [];
    const thinkParts: string[] = [];
    for (const frag of parsedFragments) {
      if (frag.type === 'THINK') {
        if (frag.content.length > 0) {
          thinkParts.push(frag.content);
        }
        if (frag.elapsedSecs > 0) {
          thinkingElapsedSecs = frag.elapsedSecs;
        }
      } else if (frag.type === 'SEARCH') {
        for (const q of frag.queries) {
          searchQueries.push(q);
        }
        for (const r of frag.results) {
          searchResults.push(r);
        }
      } else {
        if (frag.content.length > 0) {
          contentParts.push(frag.content);
        }
      }
    }
    if (thinkParts.length > 0) {
      thinkingContent = thinkParts.join('\n');
    }
    if (contentParts.length > 0) {
      content = contentParts.join('\n');
    }
  }

  if (searchResults.length === 0) {
    searchResults = parseSearchResults(rec['search_results']);
  }

  const rawFiles = pickArray(rec, ['files']);
  const files: UploadedAttachment[] = [];
  for (const fItem of rawFiles) {
    const fRec = asRecord(fItem);
    const fid = pickString(fRec, ['id', 'file_id']);
    const fname = pickString(fRec, ['file_name', 'name']);
    const fsize = pickNumber(fRec, ['file_size', 'size']);
    const fmime = pickString(fRec, ['mime_type', 'content_type']);
    const lowerName = fname.toLowerCase();
    const isImg = fmime.startsWith('image/') ||
      lowerName.endsWith('.png') ||
      lowerName.endsWith('.jpg') ||
      lowerName.endsWith('.jpeg') ||
      lowerName.endsWith('.webp');
    if (fid.length > 0 || fname.length > 0) {
      files.push({
        id: fid,
        fileName: fname.length > 0 ? fname : '附件',
        fileSize: fsize,
        mimeType: fmime,
        localUri: '',
        isImage: isImg,
        status: 'ready',
        errorMessage: ''
      });
    }
  }

  const rawStatus = pickString(rec, ['status']).toUpperCase();
  let status: MessageStatus = 'FINISHED';
  if (rawStatus === 'WIP' || rawStatus === 'INCOMPLETE' || rawStatus === 'ERROR' || rawStatus === 'FINISHED') {
    status = rawStatus as MessageStatus;
  }

  const rawFeedback = pickString(rec, ['feedback']).toLowerCase();
  let feedback: MessageFeedback = 'none';
  if (rawFeedback === 'like') {
    feedback = 'like';
  } else if (rawFeedback === 'dislike') {
    feedback = 'dislike';
  }

  return new ChatMessage({
    messageId: messageId,
    parentId: parentId,
    role: role,
    content: content,
    thinkingContent: thinkingContent,
    thinkingElapsedSecs: thinkingElapsedSecs,
    searchQueries: searchQueries,
    searchResults: searchResults,
    files: files,
    status: status,
    insertedAt: pickNumber(rec, ['inserted_at']),
    feedback: feedback,
    accumulatedTokenUsage: pickNumber(rec, ['accumulated_token_usage'])
  });
}

function readUriBytes(uri: string): Uint8Array {
  let file: fileIo.File | null = null;
  try {
    file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    const stat = fileIo.statSync(file.fd);
    const size = stat.size;
    if (size <= 0) {
      return new Uint8Array(0);
    }
    const buf = new ArrayBuffer(size);
    const readBytes = fileIo.readSync(file.fd, buf);
    if (readBytes <= 0) {
      return new Uint8Array(0);
    }
    if (readBytes === size) {
      return new Uint8Array(buf);
    }
    return new Uint8Array(buf.slice(0, readBytes));
  } catch (err) {
    throw new ApiError(ErrorKind.UNKNOWN, '读取本地文件失败，请确认文件权限后重试。');
  } finally {
    if (file !== null) {
      try {
        fileIo.closeSync(file);
      } catch (closeErr) {
        // 忽略关闭异常。
      }
    }
  }
}

function delayMs(ms: number): Promise<void> {
  return new Promise<void>((resolve) => {
    setTimeout(() => {
      resolve();
    }, ms);
  });
}

export function parseCreatedSessionFromBizData(bizData: Record<string, Object>): ChatSession | null {
  const candidates: Record<string, Object>[] = [];
  const nestedChatSession = pickObject(bizData, ['chat_session']);
  if (Object.keys(nestedChatSession).length > 0) {
    candidates.push(nestedChatSession);
  }
  const nestedSession = pickObject(bizData, ['session']);
  if (Object.keys(nestedSession).length > 0) {
    candidates.push(nestedSession);
  }
  const nestedData = pickObject(bizData, ['data']);
  if (Object.keys(nestedData).length > 0) {
    candidates.push(nestedData);
  }
  candidates.push(bizData);

  for (const rec of candidates) {
    const id = pickString(rec, ['id', 'chat_session_id', 'session_id']);
    if (id.length > 0) {
      const nowSec = Math.floor(Date.now() / 1000);
      const rawTitle = pickString(rec, ['title']);
      return {
        id: id,
        title: rawTitle.length > 0 ? rawTitle : '新对话',
        updatedAt: pickNumber(rec, ['updated_at']) || nowSec,
        insertedAt: pickNumber(rec, ['inserted_at']) || nowSec,
        pinned: pickBoolean(rec, ['pinned'])
      };
    }
  }
  return null;
}

function generateClientStreamId(): string {
  const now = new Date();
  const yyyy = String(now.getFullYear());
  const mm = String(now.getMonth() + 1).padStart(2, '0');
  const dd = String(now.getDate()).padStart(2, '0');
  const hex = '0123456789abcdef';
  let suffix = '';
  for (let i = 0; i < 16; i++) {
    suffix += hex.charAt(Math.floor(Math.random() * 16));
  }
  return `${yyyy}${mm}${dd}-${suffix}`;
}
