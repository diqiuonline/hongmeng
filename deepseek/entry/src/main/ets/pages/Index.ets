import { common } from '@kit.AbilityKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';
import { ChatInputBar } from '../components/ChatInputBar';
import { MessageBubble } from '../components/MessageBubble';
import { SessionDrawer } from '../components/SessionDrawer';
import { StateView } from '../components/StateView';
import { ApiError, ErrorKind } from '../model/ApiErrors';
import {
  BranchInfo,
  ChatMessage,
  ChatSession,
  MessageFeedback,
  PickedLocalFile,
  PowChallenge,
  SearchSource,
  UploadedAttachment,
  UserProfile
} from '../model/ChatModels';
import { DeepSeekApi } from '../network/DeepSeekApi';
import { StreamHandle } from '../network/DeepSeekHttp';
import { SsePatchCallbacks, SseStreamSnapshot } from '../network/SsePatchParser';
import { AuthStore } from '../store/AuthStore';
import { SettingsStore } from '../store/SettingsStore';
import { AppConfig } from '../utils/AppConfig';
import { copyTextToClipboard } from '../utils/ClipboardUtils';
import { buildActivePath, getBranchInfo, parentKey } from '../utils/MessageTreeUtils';


function isSameBranchInfo(a: BranchInfo, b: BranchInfo): boolean {
  if (a.currentIndex !== b.currentIndex || a.totalCount !== b.totalCount) {
    return false;
  }
  if (a.siblingIds.length !== b.siblingIds.length) {
    return false;
  }
  for (let i = 0; i < a.siblingIds.length; i++) {
    if (a.siblingIds[i] !== b.siblingIds[i]) {
      return false;
    }
  }
  return true;
}

function areStringArraysEqual(a: string[], b: string[]): boolean {
  if (a.length !== b.length) {
    return false;
  }
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) {
      return false;
    }
  }
  return true;
}

function areSearchResultsEqual(a: SearchSource[], b: SearchSource[]): boolean {
  if (a.length !== b.length) {
    return false;
  }
  for (let i = 0; i < a.length; i++) {
    if (
      a[i].url !== b[i].url ||
      a[i].title !== b[i].title ||
      a[i].snippet !== b[i].snippet ||
      a[i].citeIndex !== b[i].citeIndex
    ) {
      return false;
    }
  }
  return true;
}

@Entry
@Component
struct Index {
  @State loggedIn: boolean = false;
  @State userProfile: UserProfile | null = null;
  @State isWideScreen: boolean = false;
  @State drawerOpen: boolean = false;

  @State sessions: ChatSession[] = [];
  @State hasMoreSessions: boolean = false;
  @State nextSessionCursor: string = '';
  @State loadingSessions: boolean = false;
  @State sessionsError: string = '';

  @State currentSessionId: string = '';
  @State currentSessionTitle: string = '新对话';
  @State loadingMessages: boolean = false;
  @State messagesError: string = '';

  private allMessages: ChatMessage[] = [];
  @State displayMessages: ChatMessage[] = [];

  @State promptText: string = '';
  @State thinkingEnabled: boolean = true;
  @State searchEnabled: boolean = true;
  @State pendingAttachments: UploadedAttachment[] = [];
  @State editingUserMessage: ChatMessage | null = null;

  @State isStreaming: boolean = false;
  private streamingMessageId: number = 0;
  @State userScrolledUp: boolean = false;
  @State riskControlBanner: string = '';

  private branchSelection: Map<string, number> = new Map<string, number>();
  private activeStreamHandle: StreamHandle | null = null;
  private listScroller: Scroller = new Scroller();
  private throttleTimerId: number = -1;
  private scrollTimerId: number = -1;
  private pendingSnapshot: SseStreamSnapshot | null = null;
  private activeTempUserId: number = -1001;
  private activeTempAssistantId: number = -1002;
  private activeParentId: number | null = null;
  private activeStreamingMessage: ChatMessage | null = null;
  private lastScrollFromUser: boolean = false;
  private streamRequestSeq: number = 0;

  aboutToAppear(): void {
    this.bootstrap();
  }

  aboutToDisappear(): void {
    this.clearThrottleTimer();
    this.clearScrollTimer();
    if (this.activeStreamHandle !== null) {
      this.activeStreamHandle.abort();
      this.activeStreamHandle = null;
    }

  }

  onPageShow(): void {
    AppStorage.setOrCreate('bodyFontSize', SettingsStore.getInstance().getBodyFontSize());
    const nowLoggedIn = AuthStore.getInstance().hasAuth();
    const needReload = AppStorage.get<boolean>('needSessionReload') === true;
    if (needReload) {
      AppStorage.setOrCreate('needSessionReload', false);
    }

    if (!nowLoggedIn) {
      this.loggedIn = false;
      this.userProfile = null;
      this.sessions = [];
      this.resetCurrentChat();
      return;
    }

    const wasLoggedIn = this.loggedIn;
    this.loggedIn = true;
    this.userProfile = AuthStore.getInstance().getUserProfile();
    if (!wasLoggedIn || needReload) {
      this.riskControlBanner = '';
      this.loadInitialSessions();
      this.refreshCurrentUser();
    }
  }

  private async bootstrap(): Promise<void> {
    const ctx = this.getUIContext().getHostContext() as common.Context;
    await SettingsStore.getInstance().ensureInit(ctx);
    await AuthStore.getInstance().ensureInit(ctx);

    AppStorage.setOrCreate('bodyFontSize', SettingsStore.getInstance().getBodyFontSize());
    this.thinkingEnabled = SettingsStore.getInstance().getDefaultThinking();
    this.searchEnabled = SettingsStore.getInstance().getDefaultSearch();
    this.loggedIn = AuthStore.getInstance().hasAuth();
    this.userProfile = AuthStore.getInstance().getUserProfile();

    if (this.loggedIn) {
      await this.loadInitialSessions();
      this.refreshCurrentUser();
    }
  }

  private showToast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg });
    } catch (err) {
      // 忽略异常。
    }
  }

  private openLogin(): void {
    this.drawerOpen = false;
    this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' }).catch(() => {
    });
  }

  private openSettings(): void {
    this.drawerOpen = false;
    this.getUIContext().getRouter().pushUrl({ url: 'pages/SettingsPage' }).catch(() => {
    });
  }

  private openWebPage(url: string, title: string, syncAuthOnExit: boolean): void {
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/WebFallbackPage',
      params: {
        url: url,
        title: title,
        syncAuthOnExit: syncAuthOnExit
      }
    }).catch(() => {
    });
  }

  private async refreshCurrentUser(): Promise<void> {
    try {
      const profile = await DeepSeekApi.getInstance().getCurrentUser();
      this.userProfile = profile;
    } catch (error) {
      if (error instanceof ApiError && error.kind === ErrorKind.UNAUTHORIZED) {
        await AuthStore.getInstance().clearAuth();
        this.loggedIn = false;
        this.userProfile = null;
      }
    }
  }

  private async loadInitialSessions(): Promise<void> {
    if (this.loadingSessions) {
      return;
    }
    this.loadingSessions = true;
    this.sessionsError = '';
    try {
      const page = await DeepSeekApi.getInstance().fetchSessions(50, '');
      this.sessions = page.sessions;
      this.hasMoreSessions = page.hasMore;
      this.nextSessionCursor = page.nextCursor;
    } catch (error) {
      this.handleApiError(error, '历史对话加载失败');
      if (error instanceof ApiError) {
        this.sessionsError = error.message;
      }
    } finally {
      this.loadingSessions = false;
    }
  }

  private async loadMoreSessions(): Promise<void> {
    if (this.loadingSessions || !this.hasMoreSessions) {
      return;
    }
    this.loadingSessions = true;
    try {
      const page = await DeepSeekApi.getInstance().fetchSessions(50, this.nextSessionCursor);
      const seen: Set<string> = new Set<string>();
      for (const s of this.sessions) {
        seen.add(s.id);
      }
      const merged = [...this.sessions];
      for (const s of page.sessions) {
        if (!seen.has(s.id)) {
          seen.add(s.id);
          merged.push(s);
        }
      }
      this.sessions = merged;
      this.hasMoreSessions = page.hasMore;
      this.nextSessionCursor = page.nextCursor;
    } catch (error) {
      this.handleApiError(error, '加载更多会话失败');
    } finally {
      this.loadingSessions = false;
    }
  }

  private async selectSession(session: ChatSession): Promise<void> {
    if (this.isStreaming) {
      this.stopActiveStream();
    } else {
      this.streamRequestSeq++;
    }
    this.drawerOpen = false;
    this.currentSessionId = session.id;
    this.currentSessionTitle = session.title;
    this.editingUserMessage = null;
    this.pendingAttachments = [];
    this.branchSelection = new Map<string, number>();
    this.messagesError = '';
    this.userScrolledUp = false;
    this.lastScrollFromUser = false;
    await this.loadMessagesForSession(session.id);
  }

  private async loadMessagesForSession(sessionId: string): Promise<void> {
    this.loadingMessages = true;
    this.messagesError = '';
    try {
      const list = await DeepSeekApi.getInstance().getHistoryMessages(sessionId);
      if (this.currentSessionId !== sessionId) {
        return;
      }
      this.allMessages = list;
      this.rebuildDisplayMessages();
      this.scrollToBottomSoon(30);
    } catch (error) {
      this.handleApiError(error, '对话内容加载失败');
      if (error instanceof ApiError) {
        this.messagesError = error.message;
      } else {
        this.messagesError = '对话内容加载失败，请重试。';
      }
    } finally {
      this.loadingMessages = false;
    }
  }

  private resetCurrentChat(): void {
    if (this.isStreaming) {
      this.stopActiveStream();
    } else {
      this.streamRequestSeq++;
    }
    this.clearScrollTimer();
    this.currentSessionId = '';
    this.currentSessionTitle = '新对话';
    this.allMessages = [];
    this.displayMessages = [];
    this.branchSelection = new Map<string, number>();
    this.editingUserMessage = null;
    this.pendingAttachments = [];
    this.messagesError = '';
    this.userScrolledUp = false;
    this.lastScrollFromUser = false;
    this.activeStreamingMessage = null;
    this.thinkingEnabled = SettingsStore.getInstance().getDefaultThinking();
    this.searchEnabled = SettingsStore.getInstance().getDefaultSearch();
    this.drawerOpen = false;
  }

  private rebuildDisplayMessages(): void {
    const path = buildActivePath(this.allMessages, this.branchSelection);
    this.syncBranchInfosFor(path);
    this.displayMessages = path;
  }

  private syncBranchInfosFor(list: ChatMessage[]): void {
    for (const msg of list) {
      const nextInfo = getBranchInfo(this.allMessages, msg);
      if (!isSameBranchInfo(msg.branchInfo, nextInfo)) {
        msg.branchInfo = nextInfo;
      }
    }
  }

  private async handleRenameSession(sessionId: string, newTitle: string): Promise<void> {
    try {
      await DeepSeekApi.getInstance().updateSessionTitle(sessionId, newTitle);
      this.sessions = this.sessions.map((s: ChatSession): ChatSession => {
        if (s.id === sessionId) {
          return {
            id: s.id,
            title: newTitle,
            updatedAt: s.updatedAt,
            insertedAt: s.insertedAt,
            pinned: s.pinned
          };
        }
        return s;
      });
      if (this.currentSessionId === sessionId) {
        this.currentSessionTitle = newTitle;
      }
      this.showToast('已重命名');
    } catch (error) {
      this.handleApiError(error, '重命名失败');
    }
  }

  private async handleDeleteSession(sessionId: string): Promise<void> {
    try {
      await DeepSeekApi.getInstance().deleteSession(sessionId);
      this.sessions = this.sessions.filter((s: ChatSession) => s.id !== sessionId);
      if (this.currentSessionId === sessionId) {
        this.resetCurrentChat();
      }
      this.showToast('已删除对话');
    } catch (error) {
      this.handleApiError(error, '删除失败');
    }
  }

  private async handleFilesPicked(picked: PickedLocalFile[]): Promise<void> {
    if (!this.loggedIn) {
      this.showToast('请先登录 DeepSeek 账号');
      this.openLogin();
      return;
    }
    const baseIndex = this.pendingAttachments.length;
    const newItems: UploadedAttachment[] = [];
    for (const file of picked) {
      newItems.push({
        id: '',
        fileName: file.fileName,
        fileSize: 0,
        mimeType: file.mimeType,
        localUri: file.localUri,
        isImage: file.isImage,
        status: 'uploading',
        errorMessage: ''
      });
    }
    this.pendingAttachments = [...this.pendingAttachments, ...newItems];

    for (let i = 0; i < newItems.length; i++) {
      this.uploadSingleAttachment(baseIndex + i);
    }
  }

  private async uploadSingleAttachment(index: number): Promise<void> {
    if (index < 0 || index >= this.pendingAttachments.length) {
      return;
    }
    const item = this.pendingAttachments[index];
    this.updateAttachmentAt(index, {
      id: item.id,
      fileName: item.fileName,
      fileSize: item.fileSize,
      mimeType: item.mimeType,
      localUri: item.localUri,
      isImage: item.isImage,
      status: 'uploading',
      errorMessage: ''
    });

    try {
      const uploaded = await DeepSeekApi.getInstance().uploadFileFromUri(
        item.localUri,
        item.fileName,
        item.mimeType,
        item.isImage,
        (stage) => {
          if (stage === 'parsing') {
            const cur = this.pendingAttachments[index];
            if (cur !== undefined && cur.localUri === item.localUri) {
              this.updateAttachmentAt(index, {
                id: cur.id,
                fileName: cur.fileName,
                fileSize: cur.fileSize,
                mimeType: cur.mimeType,
                localUri: cur.localUri,
                isImage: cur.isImage,
                status: 'parsing',
                errorMessage: ''
              });
            }
          }
        }
      );
      const current = this.pendingAttachments[index];
      if (current !== undefined && current.localUri === item.localUri) {
        this.updateAttachmentAt(index, uploaded);
      }
    } catch (error) {
      const msg = error instanceof ApiError ? error.message : '上传失败';
      this.handleApiError(error, msg);
      const current = this.pendingAttachments[index];
      if (current !== undefined && current.localUri === item.localUri) {
        this.updateAttachmentAt(index, {
          id: '',
          fileName: current.fileName,
          fileSize: current.fileSize,
          mimeType: current.mimeType,
          localUri: current.localUri,
          isImage: current.isImage,
          status: 'error',
          errorMessage: msg
        });
      }
    }
  }

  private updateAttachmentAt(index: number, nextItem: UploadedAttachment): void {
    const nextList = [...this.pendingAttachments];
    if (index >= 0 && index < nextList.length) {
      nextList[index] = nextItem;
      this.pendingAttachments = nextList;
    }
  }

  private removeAttachmentAt(index: number): void {
    const nextList: UploadedAttachment[] = [];
    for (let i = 0; i < this.pendingAttachments.length; i++) {
      if (i !== index) {
        nextList.push(this.pendingAttachments[i]);
      }
    }
    this.pendingAttachments = nextList;
  }


  private async sendMessage(): Promise<void> {
    if (!this.loggedIn) {
      this.showToast('请先登录 DeepSeek 账号');
      this.openLogin();
      return;
    }
    if (this.isStreaming) {
      return;
    }

    const trimmedPrompt = this.promptText.trim();
    const readyAttachments: UploadedAttachment[] = [];
    const refFileIds: string[] = [];
    for (const att of this.pendingAttachments) {
      if (att.status === 'ready' && att.id.length > 0) {
        readyAttachments.push(att);
        refFileIds.push(att.id);
      }
    }

    if (trimmedPrompt.length === 0 && refFileIds.length === 0) {
      return;
    }


    this.riskControlBanner = '';
    const editingTarget = this.editingUserMessage;
    let parentId: number | null = null;
    if (editingTarget !== null) {
      parentId = editingTarget.parentId;
    } else if (this.displayMessages.length > 0) {
      parentId = this.displayMessages[this.displayMessages.length - 1].messageId;
    }

    const promptToSend = trimmedPrompt.length > 0 ? trimmedPrompt : '请分析附件内容';
    this.promptText = '';
    this.pendingAttachments = [];
    this.editingUserMessage = null;
    this.userScrolledUp = false;

    let preFetchedChallenge: PowChallenge | undefined = undefined;
    try {
      if (this.currentSessionId.length === 0) {
        const challengePromise: Promise<PowChallenge | undefined> = DeepSeekApi.getInstance()
          .createPowChallenge('/api/v0/chat/completion')
          .catch((): PowChallenge | undefined => undefined);
        const created = await DeepSeekApi.getInstance().createSession();
        this.currentSessionId = created.id;
        this.currentSessionTitle = created.title;
        this.sessions = [created, ...this.sessions];
        preFetchedChallenge = await challengePromise;
      }
    } catch (error) {
      this.promptText = promptToSend;
      this.pendingAttachments = readyAttachments;
      this.handleApiError(error, '创建对话失败');
      return;
    }

    const tempUserId = -Date.now();
    const tempAssistantId = tempUserId - 1;
    this.activeTempUserId = tempUserId;
    this.activeTempAssistantId = tempAssistantId;
    this.activeParentId = parentId;

    const tempUserMsg = new ChatMessage({
      messageId: tempUserId,
      parentId: parentId,
      role: 'USER',
      content: promptToSend,
      thinkingContent: '',
      thinkingElapsedSecs: 0,
      searchQueries: [],
      searchResults: [],
      files: readyAttachments,
      status: 'FINISHED',
      insertedAt: Math.floor(Date.now() / 1000),
      feedback: 'none',
      accumulatedTokenUsage: 0
    });

    const tempAssistantMsg = new ChatMessage({
      messageId: tempAssistantId,
      parentId: tempUserId,
      role: 'ASSISTANT',
      content: '',
      thinkingContent: '',
      thinkingElapsedSecs: 0,
      searchQueries: [],
      searchResults: [],
      files: [],
      status: 'WIP',
      insertedAt: Math.floor(Date.now() / 1000),
      feedback: 'none',
      accumulatedTokenUsage: 0,
      isActiveStream: true,
      stageText: '正在安全校验...'
    });

    this.activeStreamingMessage = tempAssistantMsg;
    this.lastScrollFromUser = false;
    this.branchSelection.set(parentKey(parentId), tempUserId);
    this.branchSelection.set(parentKey(tempUserId), tempAssistantId);
    this.allMessages = [...this.allMessages, tempUserMsg, tempAssistantMsg];
    this.rebuildDisplayMessages();
    this.scrollToBottomSoon(30);

    await this.launchStream(
      this.currentSessionId,
      parentId,
      promptToSend,
      refFileIds,
      tempUserId,
      tempAssistantId,
      false,
      preFetchedChallenge
    );
  }

  private async regenerateAssistantMessage(assistantMsg: ChatMessage): Promise<void> {
    if (!this.loggedIn || this.isStreaming || this.currentSessionId.length === 0) {
      return;
    }
    const parentUserId = assistantMsg.parentId;
    let userMsg: ChatMessage | null = null;
    if (parentUserId !== null) {
      for (const m of this.allMessages) {
        if (m.messageId === parentUserId) {
          userMsg = m;
          break;
        }
      }
    }
    if (userMsg === null || userMsg.messageId <= 0) {
      this.showToast('未找到已同步的提问消息，无法重新生成');
      return;
    }

    const refFileIds: string[] = [];
    for (const f of userMsg.files) {
      if (f.id.length > 0) {
        refFileIds.push(f.id);
      }
    }

    const tempAssistantId = -Date.now();
    this.activeTempUserId = userMsg.messageId;
    this.activeTempAssistantId = tempAssistantId;
    this.activeParentId = userMsg.parentId;

    const tempAssistantMsg = new ChatMessage({
      messageId: tempAssistantId,
      parentId: userMsg.messageId,
      role: 'ASSISTANT',
      content: '',
      thinkingContent: '',
      thinkingElapsedSecs: 0,
      searchQueries: [],
      searchResults: [],
      files: [],
      status: 'WIP',
      insertedAt: Math.floor(Date.now() / 1000),
      feedback: 'none',
      accumulatedTokenUsage: 0,
      isActiveStream: true,
      stageText: '正在安全校验...'
    });

    this.activeStreamingMessage = tempAssistantMsg;
    this.lastScrollFromUser = false;
    this.branchSelection.set(parentKey(userMsg.messageId), tempAssistantId);
    this.allMessages = [...this.allMessages, tempAssistantMsg];
    this.rebuildDisplayMessages();
    this.userScrolledUp = false;
    this.scrollToBottomSoon(30);

    await this.launchStream(
      this.currentSessionId,
      userMsg.messageId,
      userMsg.content,
      refFileIds,
      userMsg.messageId,
      tempAssistantId,
      true,
      undefined
    );
  }

  private async launchStream(
    sessionId: string,
    parentMessageId: number | null,
    prompt: string,
    refFileIds: string[],
    trackedUserId: number,
    trackedAssistantId: number,
    isRegenerate: boolean,
    preFetchedChallenge?: PowChallenge
  ): Promise<void> {
    const reqSeq = ++this.streamRequestSeq;
    this.isStreaming = true;
    this.streamingMessageId = trackedAssistantId;
    this.pendingSnapshot = null;

    let currentUserId = trackedUserId;
    let currentAssistantId = trackedAssistantId;

    try {
      const streamCallbacks: SsePatchCallbacks = {
        onReady: (reqId: number, respId: number): void => {
          if (reqSeq !== this.streamRequestSeq) {
            return;
          }
          const nextUserId = (!isRegenerate && reqId > 0) ? reqId : currentUserId;
          const nextAssistantId = respId > 0 ? respId : currentAssistantId;

          if (!isRegenerate && reqId > 0 && reqId !== currentUserId) {
            this.branchSelection.set(parentKey(this.activeParentId), nextUserId);
          }
          if (nextAssistantId !== currentAssistantId || nextUserId !== currentUserId) {
            this.branchSelection.set(parentKey(nextUserId), nextAssistantId);
          }

          if (!isRegenerate && nextUserId !== currentUserId) {
            const userMsg = this.findMessageById(currentUserId);
            if (userMsg !== null) {
              userMsg.messageId = nextUserId;
            }
          }
          const assistantMsg = this.findMessageById(currentAssistantId);
          if (assistantMsg !== null) {
            assistantMsg.messageId = nextAssistantId;
            assistantMsg.parentId = nextUserId;
            this.activeStreamingMessage = assistantMsg;
          }

          currentUserId = nextUserId;
          currentAssistantId = nextAssistantId;
          this.streamingMessageId = currentAssistantId;
          this.activeTempUserId = currentUserId;
          this.activeTempAssistantId = currentAssistantId;
          this.syncBranchInfosFor(this.displayMessages);
        },
        onTitle: (title: string): void => {
          if (reqSeq !== this.streamRequestSeq) {
            return;
          }
          if (this.currentSessionId === sessionId) {
            this.currentSessionTitle = title;
          }
          this.sessions = this.sessions.map((s: ChatSession): ChatSession => {
            if (s.id === sessionId) {
              return {
                id: s.id,
                title: title,
                updatedAt: Math.floor(Date.now() / 1000),
                insertedAt: s.insertedAt,
                pinned: s.pinned
              };
            }
            return s;
          });
        },
        onUpdate: (snapshot: SseStreamSnapshot): void => {
          if (reqSeq !== this.streamRequestSeq) {
            return;
          }
          const activeTarget = this.resolveStreamingTarget(currentAssistantId);
          const waitingFirstOutput =
            activeTarget !== null &&
            activeTarget.thinkingContent.length === 0 &&
            activeTarget.content.length === 0;
          if (waitingFirstOutput) {
            this.clearThrottleTimer();
            this.pendingSnapshot = null;
            this.applySnapshotToAssistant(currentAssistantId, snapshot, false);
            return;
          }
          this.pendingSnapshot = snapshot;
          if (this.throttleTimerId === -1) {
            this.throttleTimerId = setTimeout(() => {
              this.throttleTimerId = -1;
              if (reqSeq !== this.streamRequestSeq) {
                this.pendingSnapshot = null;
                return;
              }
              const snap = this.pendingSnapshot;
              this.pendingSnapshot = null;
              if (snap !== null) {
                this.applySnapshotToAssistant(currentAssistantId, snap, false);
              }
            }, 100);
          }
        },
        onFinish: (snapshot: SseStreamSnapshot): void => {
          if (reqSeq !== this.streamRequestSeq) {
            return;
          }
          this.clearThrottleTimer();
          this.pendingSnapshot = null;
          this.applySnapshotToAssistant(currentAssistantId, snapshot, true);
          this.isStreaming = false;
          this.activeStreamHandle = null;
          this.activeStreamingMessage = null;
          this.touchSessionUpdatedAt(sessionId);
        },
        onError: (errMsg: string): void => {
          if (reqSeq !== this.streamRequestSeq) {
            return;
          }
          this.clearThrottleTimer();
          this.pendingSnapshot = null;
          this.isStreaming = false;
          this.activeStreamHandle = null;
          this.markAssistantError(currentAssistantId, errMsg);
          this.activeStreamingMessage = null;
          this.showToast(errMsg);
        }
      };

      const onStreamError = (apiErr: ApiError): void => {
        if (reqSeq !== this.streamRequestSeq) {
          return;
        }
        this.clearThrottleTimer();
        this.pendingSnapshot = null;
        this.isStreaming = false;
        this.activeStreamHandle = null;
        this.markAssistantError(currentAssistantId, apiErr.message);
        this.activeStreamingMessage = null;
        this.handleApiError(apiErr, '生成回复失败');
      };

      const onStage = (stage: 'pow' | 'connecting'): void => {
        if (reqSeq !== this.streamRequestSeq) {
          return;
        }
        const target = this.resolveStreamingTarget(currentAssistantId);
        if (target !== null) {
          target.stageText = stage === 'pow' ? '正在安全校验...' : '正在连接 DeepSeek...';
        }
      };

      const handle = isRegenerate
        ? await DeepSeekApi.getInstance().startRegenerateStream(
          sessionId,
          trackedUserId,
          this.thinkingEnabled,
          this.searchEnabled,
          streamCallbacks,
          onStreamError,
          preFetchedChallenge,
          onStage
        )
        : await DeepSeekApi.getInstance().startCompletionStream(
          {
            sessionId: sessionId,
            parentMessageId: parentMessageId,
            prompt: prompt,
            refFileIds: refFileIds,
            thinkingEnabled: this.thinkingEnabled,
            searchEnabled: this.searchEnabled
          },
          streamCallbacks,
          onStreamError,
          preFetchedChallenge,
          onStage
        );

      if (reqSeq !== this.streamRequestSeq) {
        handle.abort();
        return;
      }
      this.activeStreamHandle = handle;
    } catch (error) {
      if (reqSeq !== this.streamRequestSeq) {
        return;
      }
      this.clearThrottleTimer();
      this.pendingSnapshot = null;
      this.isStreaming = false;
      this.activeStreamHandle = null;
      const errMsg = error instanceof ApiError ? error.message : '发起对话失败，请稍后重试。';
      this.markAssistantError(currentAssistantId, errMsg);
      this.activeStreamingMessage = null;
      this.handleApiError(error, '发起对话失败');
    }
  }

  private resolveStreamingTarget(assistantId: number): ChatMessage | null {
    if (
      this.activeStreamingMessage !== null &&
      (this.activeStreamingMessage.messageId === assistantId ||
        this.activeStreamingMessage.messageId === this.streamingMessageId ||
        this.activeStreamingMessage.messageId === this.activeTempAssistantId)
    ) {
      return this.activeStreamingMessage;
    }
    return this.findMessageById(assistantId);
  }

  private findMessageById(messageId: number): ChatMessage | null {
    if (
      this.activeStreamingMessage !== null &&
      this.activeStreamingMessage.messageId === messageId
    ) {
      return this.activeStreamingMessage;
    }
    for (const m of this.allMessages) {
      if (m.messageId === messageId) {
        return m;
      }
    }
    return null;
  }

  private applySnapshotToAssistant(
    assistantId: number,
    snapshot: SseStreamSnapshot,
    isFinal: boolean
  ): void {
    let targetId = assistantId;
    if (snapshot.responseMessageId > 0 && snapshot.responseMessageId !== assistantId) {
      targetId = snapshot.responseMessageId;
      this.streamingMessageId = targetId;
    }

    let target: ChatMessage | null = null;
    if (
      this.activeStreamingMessage !== null &&
      (this.activeStreamingMessage.messageId === assistantId ||
        this.activeStreamingMessage.messageId === targetId ||
        this.activeStreamingMessage.messageId === this.streamingMessageId)
    ) {
      target = this.activeStreamingMessage;
    } else {
      target = this.findMessageById(targetId) ?? this.findMessageById(assistantId);
    }
    if (target === null) {
      return;
    }

    let thinkingText = '';
    let thinkingElapsed = 0;
    let hasThink = false;
    let hasSearch = false;
    const contentParts: string[] = [];
    const queries: string[] = [];
    const results: SearchSource[] = [];

    for (const frag of snapshot.fragments) {
      if (frag.type === 'THINK') {
        hasThink = true;
        if (frag.content.length > 0) {
          thinkingText += (thinkingText.length > 0 ? '\n' : '') + frag.content;
        }
        if (frag.elapsedSecs > 0) {
          thinkingElapsed = frag.elapsedSecs;
        }
      } else if (frag.type === 'SEARCH') {
        hasSearch = true;
        for (const q of frag.queries) {
          queries.push(q);
        }
        for (const r of frag.results) {
          results.push(r);
        }
      } else {
        if (frag.content.length > 0) {
          contentParts.push(frag.content);
        }
      }
    }

    const finalContent = contentParts.join('\n');
    const finalStatus = isFinal
      ? (snapshot.status === 'WIP' ? 'FINISHED' : snapshot.status)
      : snapshot.status;

    if (snapshot.responseMessageId > 0 && snapshot.responseMessageId !== target.messageId) {
      target.messageId = targetId;
      this.streamingMessageId = targetId;
      this.branchSelection.set(parentKey(target.parentId), targetId);
      this.syncBranchInfosFor(this.displayMessages);
    }

    let nextStageText = '';
    if (!isFinal && thinkingText.length === 0 && finalContent.length === 0) {
      if (hasSearch && results.length === 0) {
        nextStageText = '正在联网搜索...';
      } else if (hasThink) {
        nextStageText = '正在深度思考...';
      } else {
        nextStageText = target.stageText.length > 0 ? target.stageText : '正在思考与组织回复...';
      }
    }

    if (target.hasSearch !== hasSearch) {
      target.hasSearch = hasSearch;
    }
    if (target.stageText !== nextStageText) {
      target.stageText = nextStageText;
    }
    if (target.content !== finalContent) {
      target.content = finalContent;
    }
    if (target.thinkingContent !== thinkingText) {
      target.thinkingContent = thinkingText;
    }
    if (target.thinkingElapsedSecs !== thinkingElapsed) {
      target.thinkingElapsedSecs = thinkingElapsed;
    }
    if (!areStringArraysEqual(target.searchQueries, queries)) {
      target.searchQueries = queries;
    }
    if (!areSearchResultsEqual(target.searchResults, results)) {
      target.searchResults = results;
    }
    if (target.status !== finalStatus) {
      target.status = finalStatus;
    }
    if (target.accumulatedTokenUsage !== snapshot.accumulatedTokenUsage) {
      target.accumulatedTokenUsage = snapshot.accumulatedTokenUsage;
    }
    if (isFinal && target.isActiveStream) {
      target.isActiveStream = false;
    }

    if (isFinal && !this.userScrolledUp) {
      this.scrollToBottomSoon(30);
    }
  }

  private markAssistantError(assistantId: number, _errMsg: string): void {
    const target = this.resolveStreamingTarget(assistantId);
    if (target !== null) {
      if (target.status === 'WIP') {
        target.status = target.content.length > 0 ? 'INCOMPLETE' : 'ERROR';
      }
      target.stageText = '';
      target.isActiveStream = false;
    }
  }

  private stopActiveStream(): void {
    this.streamRequestSeq++;
    this.clearThrottleTimer();
    this.pendingSnapshot = null;
    if (this.activeStreamHandle !== null) {
      this.activeStreamHandle.abort();
      this.activeStreamHandle = null;
    }
    const sessionId = this.currentSessionId;
    const msgId = this.streamingMessageId;
    this.isStreaming = false;

    const target = this.resolveStreamingTarget(msgId);
    if (target !== null) {
      if (target.status === 'WIP') {
        target.status = 'INCOMPLETE';
      }
      target.stageText = '';
      target.isActiveStream = false;
    }
    this.activeStreamingMessage = null;

    if (sessionId.length > 0 && msgId > 0) {
      DeepSeekApi.getInstance().stopStream(sessionId, msgId);
    }
  }

  private async handleFeedback(msg: ChatMessage, nextFeedback: MessageFeedback): Promise<void> {
    if (this.currentSessionId.length === 0 || msg.messageId <= 0) {
      return;
    }
    msg.feedback = nextFeedback;

    try {
      await DeepSeekApi.getInstance().submitFeedback(this.currentSessionId, msg.messageId, nextFeedback);
    } catch (error) {
      this.showToast('反馈提交失败');
    }
  }

  private async handleShareMessage(msg: ChatMessage): Promise<void> {
    if (this.currentSessionId.length === 0 || msg.messageId <= 0) {
      await copyTextToClipboard(msg.content);
      this.showToast('已复制回答内容');
      return;
    }

    const ids: number[] = [];
    if (msg.parentId !== null && msg.parentId > 0) {
      ids.push(msg.parentId);
    }
    ids.push(msg.messageId);

    try {
      const shareUrl = await DeepSeekApi.getInstance().createShareLink(this.currentSessionId, ids);
      await copyTextToClipboard(shareUrl);
      this.showToast('已复制分享链接');

      try {
        const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
        const sharedData = new systemShare.SharedData({
          utd: uniformTypeDescriptor.UniformDataType.HYPERLINK,
          content: shareUrl,
          title: this.currentSessionTitle
        });
        const controller = new systemShare.ShareController(sharedData);
        await controller.show(ctx, {
          previewMode: systemShare.SharePreviewMode.DEFAULT,
          selectionMode: systemShare.SelectionMode.SINGLE
        });
      } catch (shareErr) {
        // 模拟器或无分享面板时已复制到剪贴板，静默降级。
      }
    } catch (error) {
      await copyTextToClipboard(msg.content);
      this.showToast('创建分享链接失败，已复制回答文本');
    }
  }

  private handleSwitchBranch(parentId: number | null, targetMessageId: number): void {
    this.branchSelection.set(parentKey(parentId), targetMessageId);
    this.rebuildDisplayMessages();
  }

  private handleApiError(error: Error | Object, fallbackMsg: string): void {
    if (error instanceof ApiError) {
      if (error.kind === ErrorKind.UNAUTHORIZED) {
        this.showToast('登录已过期，请重新登录');
        return;
      }
      if (error.kind === ErrorKind.RISK_CONTROL) {
        this.riskControlBanner = error.message;
        this.showToast('需要完成安全验证');
        return;
      }
      this.showToast(error.message);
      return;
    }
    this.showToast(fallbackMsg);
  }

  private touchSessionUpdatedAt(sessionId: string): void {
    const nowSec = Math.floor(Date.now() / 1000);
    this.sessions = this.sessions.map((s: ChatSession): ChatSession => {
      if (s.id === sessionId) {
        return {
          id: s.id,
          title: s.title,
          updatedAt: nowSec,
          insertedAt: s.insertedAt,
          pinned: s.pinned
        };
      }
      return s;
    });
  }

  private clearThrottleTimer(): void {
    if (this.throttleTimerId !== -1) {
      clearTimeout(this.throttleTimerId);
      this.throttleTimerId = -1;
    }
  }

  private clearScrollTimer(): void {
    if (this.scrollTimerId !== -1) {
      clearTimeout(this.scrollTimerId);
      this.scrollTimerId = -1;
    }
  }

  private scrollToBottomSoon(delayMs: number = 16): void {
    if (this.scrollTimerId !== -1) {
      return;
    }
    this.scrollTimerId = setTimeout(() => {
      this.scrollTimerId = -1;
      if (this.userScrolledUp) {
        return;
      }
      try {
        this.listScroller.scrollEdge(Edge.Bottom);
      } catch (err) {
        // 忽略。
      }
    }, delayMs);
  }

  private getTimeGreeting(): string {
    const hour = new Date().getHours();
    if (hour < 11) {
      return '早上好，我能帮什么忙吗？';
    }
    if (hour < 14) {
      return '中午好，我能帮什么忙吗？';
    }
    if (hour < 18) {
      return '下午好，我能帮什么忙吗？';
    }
    return '晚上好，我能帮什么忙吗？';
  }

  @Builder
  private WelcomeViewBuilder() {
    Column({ space: 18 }) {
      Column({ space: 10 }) {
        Stack() {
          Circle({ width: 54, height: 54 })
            .fill($r('app.color.accent_primary'))
          Text('D')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }

        Text(this.getTimeGreeting())
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)

        Text(
          this.loggedIn
            ? '自动同步网页端当前默认模型，支持深度思考、智能搜索、拍照/文档识别'
            : '请先登录 DeepSeek 账号，即可同步历史对话并使用全部功能'
        )
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
          .lineHeight(19)

        if (!this.loggedIn) {
          Button('立即登录 DeepSeek')
            .fontSize(14)
            .height(38)
            .padding({ left: 22, right: 22 })
            .backgroundColor($r('app.color.accent_primary'))
            .fontColor(Color.White)
            .borderRadius(19)
            .margin({ top: 4 })
            .onClick(() => {
              this.openLogin();
            })
        }
      }
      .padding({ left: 24, right: 24 })
      .alignItems(HorizontalAlign.Center)
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private ChatWorkspaceBuilder() {
    Column() {
      // 顶栏
      Row({ space: 8 }) {
        if (!this.isWideScreen) {
          Button('☰')
            .fontSize(17)
            .width(36)
            .height(36)
            .padding(0)
            .backgroundColor($r('app.color.bg_pill'))
            .fontColor($r('app.color.text_primary'))
            .borderRadius(18)
            .onClick(() => {
              this.drawerOpen = !this.drawerOpen;
            })
        }

        Text(this.currentSessionTitle)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .textAlign(this.isWideScreen ? TextAlign.Start : TextAlign.Center)

        Button('＋')
          .fontSize(18)
          .width(36)
          .height(36)
          .padding(0)
          .backgroundColor($r('app.color.bg_pill'))
          .fontColor($r('app.color.text_primary'))
          .borderRadius(18)
          .onClick(() => {
            this.resetCurrentChat();
          })

        if (!this.loggedIn) {
          Button('登录')
            .fontSize(12)
            .height(32)
            .padding({ left: 12, right: 12 })
            .backgroundColor($r('app.color.accent_primary'))
            .fontColor(Color.White)
            .borderRadius(16)
            .onClick(() => {
              this.openLogin();
            })
        } else {
          Button('⚙')
            .fontSize(15)
            .width(34)
            .height(34)
            .padding(0)
            .backgroundColor($r('app.color.bg_pill'))
            .fontColor($r('app.color.text_primary'))
            .borderRadius(17)
            .onClick(() => {
              this.openSettings();
            })
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor($r('app.color.bg_surface'))

      if (this.riskControlBanner.length > 0) {
        Row({ space: 8 }) {
          Text(this.riskControlBanner)
            .fontSize(12)
            .fontColor($r('app.color.danger_color'))
            .layoutWeight(1)
          Button('去网页验证')
            .fontSize(12)
            .height(28)
            .padding({ left: 10, right: 10 })
            .backgroundColor($r('app.color.accent_primary'))
            .fontColor(Color.White)
            .borderRadius(14)
            .onClick(() => {
              this.openWebPage(AppConfig.BASE_URL, '安全验证（完成后点击同步凭证）', true);
            })
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .backgroundColor($r('app.color.bg_pill_active'))
      }

      // 主消息区域
      if (this.loadingMessages) {
        Column({ space: 10 }) {
          LoadingProgress()
            .width(36)
            .height(36)
            .color($r('app.color.accent_primary'))
          Text('正在加载历史消息...')
            .fontSize(13)
            .fontColor($r('app.color.text_muted'))
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.messagesError.length > 0 && this.displayMessages.length === 0) {
        Column() {
          StateView({
            title: '加载对话失败',
            message: this.messagesError,
            actionText: '重试',
            secondaryActionText: '应急网页版',
            onAction: () => {
              if (this.currentSessionId.length > 0) {
                this.loadMessagesForSession(this.currentSessionId);
              }
            },
            onSecondaryAction: () => {
              this.openWebPage(AppConfig.BASE_URL, 'DeepSeek 网页版', true);
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.displayMessages.length === 0) {
        this.WelcomeViewBuilder();
      } else {
        Stack({ alignContent: Alignment.Bottom }) {
          List({ space: 18, scroller: this.listScroller }) {
            ForEach(this.displayMessages, (msg: ChatMessage) => {
              ListItem() {
                MessageBubble({
                  message: msg,
                  onCopyNotice: (notice: string): void => {
                    this.showToast(notice);
                  },
                  onEditUserMessage: (target: ChatMessage): void => {
                    this.editingUserMessage = target;
                    this.promptText = target.content;
                  },
                  onRegenerate: (target: ChatMessage): void => {
                    this.regenerateAssistantMessage(target);
                  },
                  onFeedback: (target: ChatMessage, fb: MessageFeedback): void => {
                    this.handleFeedback(target, fb);
                  },
                  onShareMessage: (target: ChatMessage): void => {
                    this.handleShareMessage(target);
                  },
                  onSwitchBranch: (pid: number | null, targetId: number): void => {
                    this.handleSwitchBranch(pid, targetId);
                  },
                  onOpenSourceUrl: (url: string, title: string): void => {
                    this.openWebPage(url, title, false);
                  },
                  onStreamingHeightChange: (): void => {
                    if (!this.userScrolledUp) {
                      this.scrollToBottomSoon(16);
                    }
                  }
                })
              }
            }, (msg: ChatMessage) => msg.renderKey)
          }
          .width('100%')
          .height('100%')
          .padding({ left: 14, right: 14, top: 14, bottom: 20 })
          .scrollBar(BarState.Auto)
          .onWillScroll((scrollOffset: number, _scrollState: ScrollState, scrollSource: ScrollSource) => {
            const fromUser =
              scrollSource === ScrollSource.DRAG ||
              scrollSource === ScrollSource.FLING ||
              scrollSource === ScrollSource.OTHER_USER_INPUT ||
              scrollSource === ScrollSource.SCROLL_BAR ||
              scrollSource === ScrollSource.SCROLL_BAR_FLING;
            this.lastScrollFromUser = fromUser;
            if (fromUser && scrollOffset < -1) {
              this.userScrolledUp = true;
              this.clearScrollTimer();
            }
          })
          .onDidScroll((scrollOffset: number, _scrollState: ScrollState) => {
            if (this.lastScrollFromUser) {
              try {
                if (this.listScroller.isAtEnd()) {
                  this.userScrolledUp = false;
                } else if (scrollOffset < -0.5) {
                  this.userScrolledUp = true;
                  this.clearScrollTimer();
                }
              } catch (err) {
                // 忽略。
              }
            }
          })
          .onReachEnd(() => {
            try {
              if (this.listScroller.isAtEnd()) {
                this.userScrolledUp = false;
              }
            } catch (err) {
              // 忽略。
            }
          })
          .onScrollStop(() => {
            if (this.lastScrollFromUser) {
              try {
                this.userScrolledUp = !this.listScroller.isAtEnd();
              } catch (err) {
                // 忽略。
              }
              this.lastScrollFromUser = false;
            }
          })

          if (this.userScrolledUp && this.displayMessages.length > 0) {
            Button('↓ 回到底部')
              .fontSize(12)
              .height(30)
              .padding({ left: 14, right: 14 })
              .backgroundColor($r('app.color.bg_elevated'))
              .fontColor($r('app.color.text_primary'))
              .border({ width: 1, color: $r('app.color.border_color') })
              .borderRadius(15)
              .margin({ bottom: 10 })
              .onClick(() => {
                this.userScrolledUp = false;
                this.lastScrollFromUser = false;
                this.clearScrollTimer();
                this.scrollToBottomSoon(16);
              })
          }
        }
        .layoutWeight(1)
        .width('100%')
      }

      // 底部输入栏
      ChatInputBar({
        promptText: $promptText,
        thinkingEnabled: $thinkingEnabled,
        searchEnabled: $searchEnabled,
        isStreaming: this.isStreaming,
        isEditing: this.editingUserMessage !== null,
        pendingAttachments: this.pendingAttachments,
        onSend: (): void => {
          this.sendMessage();
        },
        onStop: (): void => {
          this.stopActiveStream();
        },
        onCancelEdit: (): void => {
          this.editingUserMessage = null;
          this.promptText = '';
        },
        onFilesPicked: (files: PickedLocalFile[]): void => {
          this.handleFilesPicked(files);
        },
        onRemoveAttachment: (idx: number): void => {
          this.removeAttachmentAt(idx);
        },
        onRetryAttachment: (idx: number): void => {
          this.uploadSingleAttachment(idx);
        }
      })
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      if (this.isWideScreen) {
        Row() {
          Column() {
            SessionDrawer({
              sessions: this.sessions,
              currentSessionId: this.currentSessionId,
              hasMore: this.hasMoreSessions,
              loadingSessions: this.loadingSessions,
              loggedIn: this.loggedIn,
              userProfile: this.userProfile,
              onSelectSession: (session: ChatSession): void => {
                this.selectSession(session);
              },
              onNewChat: (): void => {
                this.resetCurrentChat();
              },
              onLoadMore: (): void => {
                this.loadMoreSessions();
              },
              onRefresh: (): void => {
                this.loadInitialSessions();
              },
              onRenameSession: (sid: string, title: string): void => {
                this.handleRenameSession(sid, title);
              },
              onDeleteSession: (sid: string): void => {
                this.handleDeleteSession(sid);
              },
              onOpenLogin: (): void => {
                this.openLogin();
              },
              onOpenSettings: (): void => {
                this.openSettings();
              }
            })
          }
          .width(280)
          .height('100%')

          Divider()
            .vertical(true)
            .color($r('app.color.border_color'))

          this.ChatWorkspaceBuilder();
        }
        .width('100%')
        .height('100%')
      } else {
        this.ChatWorkspaceBuilder();

        if (this.drawerOpen) {
          Row() {
            Column() {
              SessionDrawer({
                sessions: this.sessions,
                currentSessionId: this.currentSessionId,
                hasMore: this.hasMoreSessions,
                loadingSessions: this.loadingSessions,
                loggedIn: this.loggedIn,
                userProfile: this.userProfile,
                onSelectSession: (session: ChatSession): void => {
                  this.selectSession(session);
                },
                onNewChat: (): void => {
                  this.resetCurrentChat();
                },
                onLoadMore: (): void => {
                  this.loadMoreSessions();
                },
                onRefresh: (): void => {
                  this.loadInitialSessions();
                },
                onRenameSession: (sid: string, title: string): void => {
                  this.handleRenameSession(sid, title);
                },
                onDeleteSession: (sid: string): void => {
                  this.handleDeleteSession(sid);
                },
                onOpenLogin: (): void => {
                  this.openLogin();
                },
                onOpenSettings: (): void => {
                  this.openSettings();
                }
              })
            }
            .width('80%')
            .constraintSize({ maxWidth: 320 })
            .height('100%')

            Column()
              .layoutWeight(1)
              .height('100%')
              .backgroundColor('#66000000')
              .onClick(() => {
                this.drawerOpen = false;
              })
          }
          .width('100%')
          .height('100%')
        }
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_oldArea, newArea) => {
      const widthVp = Number(newArea.width);
      this.isWideScreen = !isNaN(widthVp) && widthVp >= 640;
    })
  }
}
