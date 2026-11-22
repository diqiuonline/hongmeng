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

export interface ChatMessage {
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
}

export interface BranchInfo {
  currentIndex: number;
  totalCount: number;
  siblingIds: number[];
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
