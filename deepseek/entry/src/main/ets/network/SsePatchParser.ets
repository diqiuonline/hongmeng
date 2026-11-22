import { MessageFragment, MessageStatus, SearchSource } from '../model/ChatModels';
import {
  asArray,
  asRecord,
  pickArray,
  pickBoolean,
  pickNumber,
  pickObject,
  pickString
} from './JsonUtils';

export interface SseStreamSnapshot {
  requestMessageId: number;
  responseMessageId: number;
  sessionTitle: string;
  fragments: MessageFragment[];
  status: MessageStatus;
  accumulatedTokenUsage: number;
  errorMessage: string;
}

export interface SsePatchCallbacks {
  onReady?: (requestMessageId: number, responseMessageId: number) => void;
  onTitle?: (title: string) => void;
  onUpdate: (snapshot: SseStreamSnapshot) => void;
  onFinish: (snapshot: SseStreamSnapshot) => void;
  onError: (message: string) => void;
}

/**
 * 解析 DeepSeek 网页端 SSE 流及 JSON-Patch (p/o/v) 状态树增量协议。
 */
export class SsePatchParser {
  private lineBuffer: string = '';
  private currentEvent: string = '';
  private dataLines: string[] = [];

  private requestMessageId: number = 0;
  private responseMessageId: number = 0;
  private sessionTitle: string = '';
  private fragments: MessageFragment[] = [];
  private status: MessageStatus = 'WIP';
  private accumulatedTokenUsage: number = 0;
  private errorMessage: string = '';
  private finished: boolean = false;

  private lastPath: string = '';
  private lastOp: string = 'APPEND';
  private callbacks: SsePatchCallbacks;

  constructor(callbacks: SsePatchCallbacks) {
    this.callbacks = callbacks;
  }

  feedChunk(textChunk: string): void {
    if (textChunk.length === 0) {
      return;
    }
    const normalized = textChunk.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
    this.lineBuffer += normalized;

    while (true) {
      const nlIdx = this.lineBuffer.indexOf('\n');
      if (nlIdx < 0) {
        break;
      }
      const line = this.lineBuffer.substring(0, nlIdx);
      this.lineBuffer = this.lineBuffer.substring(nlIdx + 1);
      this.processLine(line);
    }
  }

  flush(): void {
    if (this.lineBuffer.length > 0) {
      this.processLine(this.lineBuffer);
      this.lineBuffer = '';
    }
    this.dispatchBufferedEvent();
    if (!this.finished) {
      this.finished = true;
      if (this.status === 'WIP') {
        this.status = 'FINISHED';
      }
      this.callbacks.onFinish(this.buildSnapshot());
    }
  }

  getSnapshot(): SseStreamSnapshot {
    return this.buildSnapshot();
  }

  private processLine(line: string): void {
    if (line.length === 0) {
      this.dispatchBufferedEvent();
      return;
    }
    if (line.startsWith(':')) {
      return;
    }
    if (line.startsWith('event:')) {
      this.currentEvent = line.substring(6).trim();
      return;
    }
    if (line.startsWith('data:')) {
      const value = line.substring(5).trimStart();
      this.dataLines.push(value);
      return;
    }
  }

  private dispatchBufferedEvent(): void {
    if (this.dataLines.length === 0) {
      this.currentEvent = '';
      return;
    }

    const eventName = this.currentEvent;
    const rawData = this.dataLines.join('\n').trim();
    this.currentEvent = '';
    this.dataLines = [];

    if (rawData.length === 0) {
      return;
    }

    if (rawData === '[DONE]') {
      this.markFinished();
      return;
    }

    let parsedObj: Object;
    try {
      parsedObj = JSON.parse(rawData) as Object;
    } catch (err) {
      return;
    }

    const rec = asRecord(parsedObj);

    if (eventName === 'ready') {
      const reqId = pickNumber(rec, ['request_message_id']);
      const respId = pickNumber(rec, ['response_message_id']);
      if (reqId > 0) {
        this.requestMessageId = reqId;
      }
      if (respId > 0) {
        this.responseMessageId = respId;
      }
      if (this.callbacks.onReady !== undefined) {
        this.callbacks.onReady(this.requestMessageId, this.responseMessageId);
      }
      this.callbacks.onUpdate(this.buildSnapshot());
      return;
    }

    if (eventName === 'title') {
      const content = pickString(rec, ['content', 'title']);
      if (content.length > 0) {
        this.sessionTitle = content;
        if (this.callbacks.onTitle !== undefined) {
          this.callbacks.onTitle(content);
        }
      }
      return;
    }

    if (eventName === 'finish' || eventName === 'close') {
      this.markFinished();
      return;
    }

    if (eventName === 'update_session') {
      return;
    }

    if (eventName === 'error') {
      const msg = pickString(rec, ['message', 'msg', 'error_msg', 'biz_msg']);
      this.errorMessage = msg.length > 0 ? msg : '流式响应出现错误。';
      this.status = 'ERROR';
      this.callbacks.onError(this.errorMessage);
      return;
    }

    // 兼容 OpenAI 风格兜底（部分镜像或错误结构）
    const choices = pickArray(rec, ['choices']);
    if (choices.length > 0) {
      this.applyOpenAiFallback(choices);
      this.callbacks.onUpdate(this.buildSnapshot());
      return;
    }

    // 检查业务错误载荷
    const errMsg = pickString(rec, ['error_msg', 'biz_msg']);
    const errCode = pickNumber(rec, ['code', 'biz_code']);
    if (errCode !== 0 && errMsg.length > 0 && rec['v'] === undefined && rec['p'] === undefined) {
      this.errorMessage = errMsg;
      this.status = 'ERROR';
      this.callbacks.onError(errMsg);
      return;
    }

    this.applyPatchObject(rec);
    this.callbacks.onUpdate(this.buildSnapshot());
  }

  private applyPatchObject(rec: Record<string, Object>): void {
    const hasPath = typeof rec['p'] === 'string';
    const hasOp = typeof rec['o'] === 'string';

    let path = hasPath ? String(rec['p']) : this.lastPath;
    let op = hasOp ? String(rec['o']).toUpperCase() : this.lastOp;
    const val = rec['v'];

    if (op === 'BATCH' && Array.isArray(val)) {
      const items = asArray(val);
      for (const item of items) {
        const sub = asRecord(item);
        this.applyPatchObject(sub);
      }
      return;
    }

    if (hasPath) {
      this.lastPath = path;
    }
    if (hasOp) {
      this.lastOp = op;
    }

    if (val === undefined) {
      return;
    }

    // 初始全量包：{ v: { response: { message_id, fragments, status ... } } }
    if (!hasPath && val !== null && typeof val === 'object' && !Array.isArray(val)) {
      const valRec = asRecord(val);
      const responseObj = pickObject(valRec, ['response']);
      const respKeys = Object.keys(responseObj);
      if (respKeys.length > 0) {
        this.applyInitialResponse(responseObj);
        return;
      }
      if (valRec['fragments'] !== undefined || valRec['message_id'] !== undefined) {
        this.applyInitialResponse(valRec);
        return;
      }
    }

    if (path === 'response' && val !== null && typeof val === 'object' && !Array.isArray(val)) {
      this.applyInitialResponse(asRecord(val));
      return;
    }

    if (path === 'response/fragments') {
      if (op === 'SET') {
        this.fragments = parseFragmentList(val);
        return;
      }
      if (typeof val === 'string') {
        // 防御性兼容：若延续帧省略 p 落在 response/fragments 上但实际为字符串增量
        this.appendTextToLastFragment(val);
        return;
      }
      const appended = parseFragmentList(val);
      for (const frag of appended) {
        this.fragments.push(frag);
      }
      return;
    }

    if (path === 'response/status') {
      const statusStr = typeof val === 'string' ? val.toUpperCase() : '';
      if (statusStr === 'FINISHED' || statusStr === 'WIP' || statusStr === 'INCOMPLETE' || statusStr === 'ERROR') {
        this.status = statusStr as MessageStatus;
      }
      return;
    }

    if (path === 'response/accumulated_token_usage') {
      if (typeof val === 'number') {
        this.accumulatedTokenUsage = val;
      }
      return;
    }

    if (path === 'response/thinking_content') {
      this.applyLegacyText('THINK', op, typeof val === 'string' ? val : '');
      return;
    }

    if (path === 'response/content') {
      this.applyLegacyText('RESPONSE', op, typeof val === 'string' ? val : '');
      return;
    }

    // 匹配 response/fragments/<idx>/<field>
    if (path.startsWith('response/fragments/')) {
      const rest = path.substring('response/fragments/'.length);
      const slashIdx = rest.indexOf('/');
      if (slashIdx > 0) {
        const idxToken = rest.substring(0, slashIdx);
        const field = rest.substring(slashIdx + 1);
        const targetIdx = this.resolveFragmentIndex(idxToken);
        if (targetIdx >= 0 && targetIdx < this.fragments.length) {
          this.applyFragmentFieldPatch(this.fragments[targetIdx], field, op, val);
        }
      }
    }
  }

  private applyInitialResponse(resp: Record<string, Object>): void {
    const msgId = pickNumber(resp, ['message_id']);
    if (msgId > 0) {
      this.responseMessageId = msgId;
    }
    const statusStr = pickString(resp, ['status']).toUpperCase();
    if (statusStr === 'FINISHED' || statusStr === 'WIP' || statusStr === 'INCOMPLETE' || statusStr === 'ERROR') {
      this.status = statusStr as MessageStatus;
    }
    const tokenUsage = pickNumber(resp, ['accumulated_token_usage']);
    if (tokenUsage > 0) {
      this.accumulatedTokenUsage = tokenUsage;
    }
    const rawFragments = pickArray(resp, ['fragments']);
    if (rawFragments.length > 0) {
      this.fragments = parseFragmentList(rawFragments);
    } else {
      const thinkStr = pickString(resp, ['thinking_content']);
      const contentStr = pickString(resp, ['content']);
      if (thinkStr.length > 0) {
        this.applyLegacyText('THINK', 'SET', thinkStr);
      }
      if (contentStr.length > 0) {
        this.applyLegacyText('RESPONSE', 'SET', contentStr);
      }
    }
  }

  private resolveFragmentIndex(idxToken: string): number {
    if (this.fragments.length === 0) {
      return -1;
    }
    if (idxToken === '-1') {
      return this.fragments.length - 1;
    }
    const parsed = Number(idxToken);
    if (isNaN(parsed)) {
      return -1;
    }
    const intIdx = Math.floor(parsed);
    if (intIdx < 0) {
      const resolved = this.fragments.length + intIdx;
      return resolved >= 0 ? resolved : -1;
    }
    return intIdx;
  }

  private applyFragmentFieldPatch(
    frag: MessageFragment,
    field: string,
    op: string,
    val: Object
  ): void {
    if (field === 'content') {
      const text = typeof val === 'string' ? val : String(val);
      if (op === 'SET') {
        frag.content = text;
      } else {
        frag.content += text;
      }
      return;
    }

    if (field === 'elapsed_secs') {
      if (typeof val === 'number') {
        frag.elapsedSecs = val;
      }
      return;
    }

    if (field === 'finished') {
      if (typeof val === 'boolean') {
        frag.finished = val;
      }
      return;
    }

    if (field === 'results' || field === 'search_results') {
      const parsed = parseSearchResults(val);
      if (op === 'SET') {
        frag.results = parsed;
      } else {
        for (const item of parsed) {
          frag.results.push(item);
        }
      }
      return;
    }

    if (field === 'queries') {
      const parsedQueries = parseQueryList(val);
      if (op === 'SET') {
        frag.queries = parsedQueries;
      } else {
        for (const q of parsedQueries) {
          frag.queries.push(q);
        }
      }
      return;
    }
  }

  private appendTextToLastFragment(text: string): void {
    if (this.fragments.length === 0) {
      this.fragments.push({
        type: 'RESPONSE',
        content: text,
        elapsedSecs: 0,
        queries: [],
        results: [],
        finished: false
      });
      return;
    }
    this.fragments[this.fragments.length - 1].content += text;
  }

  private applyLegacyText(fragType: string, op: string, text: string): void {
    let target: MessageFragment | null = null;
    for (let i = this.fragments.length - 1; i >= 0; i--) {
      if (this.fragments[i].type === fragType) {
        target = this.fragments[i];
        break;
      }
    }
    if (target === null) {
      target = {
        type: fragType,
        content: '',
        elapsedSecs: 0,
        queries: [],
        results: [],
        finished: false
      };
      this.fragments.push(target);
    }
    if (op === 'SET') {
      target.content = text;
    } else {
      target.content += text;
    }
  }

  private applyOpenAiFallback(choices: Object[]): void {
    const first = asRecord(choices[0]);
    const delta = pickObject(first, ['delta']);
    const reasoning = pickString(delta, ['reasoning_content']);
    const content = pickString(delta, ['content']);
    if (reasoning.length > 0) {
      this.applyLegacyText('THINK', 'APPEND', reasoning);
    }
    if (content.length > 0) {
      this.applyLegacyText('RESPONSE', 'APPEND', content);
    }
  }

  private markFinished(): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    if (this.status === 'WIP') {
      this.status = 'FINISHED';
    }
    this.callbacks.onFinish(this.buildSnapshot());
  }

  private buildSnapshot(): SseStreamSnapshot {
    const copiedFragments: MessageFragment[] = [];
    for (const frag of this.fragments) {
      copiedFragments.push({
        type: frag.type,
        content: frag.content,
        elapsedSecs: frag.elapsedSecs,
        queries: [...frag.queries],
        results: [...frag.results],
        finished: frag.finished
      });
    }
    return {
      requestMessageId: this.requestMessageId,
      responseMessageId: this.responseMessageId,
      sessionTitle: this.sessionTitle,
      fragments: copiedFragments,
      status: this.status,
      accumulatedTokenUsage: this.accumulatedTokenUsage,
      errorMessage: this.errorMessage
    };
  }
}

export function parseFragmentList(raw: Object): MessageFragment[] {
  const list = Array.isArray(raw) ? asArray(raw) : [raw];
  const out: MessageFragment[] = [];
  for (const item of list) {
    if (item === null || item === undefined || typeof item !== 'object') {
      continue;
    }
    const rec = asRecord(item);
    const type = pickString(rec, ['type']).toUpperCase();
    const content = pickString(rec, ['content']);
    const elapsedSecs = pickNumber(rec, ['elapsed_secs', 'elapsedSecs']);
    const finished = pickBoolean(rec, ['finished']);
    const queries = parseQueryList(rec['queries']);
    let results = parseSearchResults(rec['results']);
    if (results.length === 0) {
      results = parseSearchResults(rec['search_results']);
    }
    out.push({
      type: type.length > 0 ? type : 'RESPONSE',
      content: content,
      elapsedSecs: elapsedSecs,
      queries: queries,
      results: results,
      finished: finished
    });
  }
  return out;
}

export function parseSearchResults(raw: Object | undefined): SearchSource[] {
  if (raw === undefined || raw === null) {
    return [];
  }
  const arr = Array.isArray(raw) ? asArray(raw) : [raw];
  const out: SearchSource[] = [];
  for (let i = 0; i < arr.length; i++) {
    const item = arr[i];
    if (item === null || item === undefined || typeof item !== 'object') {
      continue;
    }
    const rec = asRecord(item);
    const url = pickString(rec, ['url', 'link']);
    const title = pickString(rec, ['title', 'name']);
    const snippet = pickString(rec, ['snippet', 'summary', 'content']);
    const siteName = pickString(rec, ['site_name', 'siteName', 'source']);
    const citeIndex = pickNumber(rec, ['cite_index', 'citeIndex', 'index']);
    const publishedAt = pickNumber(rec, ['published_at', 'publishedAt']);
    if (url.length === 0 && title.length === 0) {
      continue;
    }
    out.push({
      url: url,
      title: title.length > 0 ? title : url,
      snippet: snippet,
      siteName: siteName.length > 0 ? siteName : extractHost(url),
      citeIndex: citeIndex > 0 ? citeIndex : i + 1,
      publishedAt: publishedAt
    });
  }
  return out;
}

function parseQueryList(raw: Object | undefined): string[] {
  if (raw === undefined || raw === null) {
    return [];
  }
  const arr = Array.isArray(raw) ? asArray(raw) : [raw];
  const out: string[] = [];
  for (const item of arr) {
    if (typeof item === 'string' && item.trim().length > 0) {
      out.push(item.trim());
    } else if (item !== null && typeof item === 'object') {
      const rec = asRecord(item);
      const q = pickString(rec, ['query', 'keyword', 'content']);
      if (q.length > 0) {
        out.push(q);
      }
    }
  }
  return out;
}

function extractHost(url: string): string {
  const match = /^https?:\/\/([^/:?#]+)/i.exec(url);
  if (match && match.length > 1) {
    return match[1];
  }
  return '';
}
