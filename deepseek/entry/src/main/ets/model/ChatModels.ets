export type ThemeMode = 'system' | 'light' | 'dark';
export type FontSizeLevel = 'standard' | 'large' | 'xlarge';
export type MessageRole = 'USER' | 'ASSISTANT';
export type MessageStatus = 'WIP' | 'FINISHED' | 'INCOMPLETE' | 'ERROR';
export type MessageFeedback = 'none' | 'like' | 'dislike';
export type AttachmentStatus = 'uploading' | 'parsing' | 'ready' | 'error';

export interface UserProfile {
  id: string;
  email: string;
  mobileNumber: string;
  name: string;
  avatarUrl: string;
  hasToken: boolean;
}

export interface ChatSession {
  id: string;
  title: string;
  updatedAt: number;
  insertedAt: number;
  pinned: boolean;
}

export interface SessionPage {
  sessions: ChatSession[];
  hasMore: boolean;
  nextCursor: string;
}

export interface SessionGroup {
  label: string;
  sessions: ChatSession[];
}

export interface SearchSource {
  url: string;
  title: string;
  snippet: string;
  siteName: string;
  citeIndex: number;
  publishedAt: number;
}

export interface MessageFragment {
  type: string;
  content: string;
  elapsedSecs: number;
  queries: string[];
  results: SearchSource[];
  finished: boolean;
}

export interface UploadedAttachment {
  id: string;
  fileName: string;
  fileSize: number;
  mimeType: string;
  localUri: string;
  isImage: boolean;
  status: AttachmentStatus;
  errorMessage: string;
}

let nextMessageRenderKeySeq: number = 1;

export interface BranchInfo {
  currentIndex: number;
  totalCount: number;
  siblingIds: number[];
}

export interface ChatMessageInit {
  messageId: number;
  parentId: number | null;
  role: MessageRole;
  content: string;
  thinkingContent: string;
  thinkingElapsedSecs: number;
  searchQueries: string[];
  searchResults: SearchSource[];
  files: UploadedAttachment[];
  status: MessageStatus;
  insertedAt: number;
  feedback: MessageFeedback;
  accumulatedTokenUsage: number;
  isActiveStream?: boolean;
  branchInfo?: BranchInfo;
  stageText?: string;
  hasSearch?: boolean;
}

@Observed
export class ChatMessage {
  renderKey: string;
  messageId: number;
  parentId: number | null;
  role: MessageRole;
  content: string;
  thinkingContent: string;
  thinkingElapsedSecs: number;
  searchQueries: string[];
  searchResults: SearchSource[];
  files: UploadedAttachment[];
  status: MessageStatus;
  insertedAt: number;
  feedback: MessageFeedback;
  accumulatedTokenUsage: number;
  isActiveStream: boolean;
  branchInfo: BranchInfo;
  stageText: string;
  hasSearch: boolean;

  constructor(init: ChatMessageInit) {
    this.renderKey = `msg_${nextMessageRenderKeySeq++}`;
    this.messageId = init.messageId;
    this.parentId = init.parentId;
    this.role = init.role;
    this.content = init.content;
    this.thinkingContent = init.thinkingContent;
    this.thinkingElapsedSecs = init.thinkingElapsedSecs;
    this.searchQueries = init.searchQueries;
    this.searchResults = init.searchResults;
    this.files = init.files;
    this.status = init.status;
    this.insertedAt = init.insertedAt;
    this.feedback = init.feedback;
    this.accumulatedTokenUsage = init.accumulatedTokenUsage;
    this.isActiveStream = init.isActiveStream ?? false;
    this.branchInfo = init.branchInfo ?? { currentIndex: 1, totalCount: 1, siblingIds: [] };
    this.stageText = init.stageText ?? '';
    this.hasSearch = init.hasSearch ?? false;
  }
}

export interface PowChallenge {
  algorithm: string;
  challenge: string;
  salt: string;
  difficulty: number;
  expireAt: number;
  signature: string;
  targetPath: string;
}

export interface CompletionParams {
  sessionId: string;
  parentMessageId: number | null;
  prompt: string;
  refFileIds: string[];
  thinkingEnabled: boolean;
  searchEnabled: boolean;
}

export interface PickedLocalFile {
  localUri: string;
  fileName: string;
  mimeType: string;
  isImage: boolean;
}
