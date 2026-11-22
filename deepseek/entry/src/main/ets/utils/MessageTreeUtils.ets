import { BranchInfo, ChatMessage } from '../model/ChatModels';

export function parentKey(parentId: number | null): string {
  return parentId === null || parentId === 0 ? 'root' : String(parentId);
}

/**
 * 将 DeepSeek 的消息树（messageId / parentId）展开为当前选中分支的线性消息列表。
 * 对每个分叉点：优先使用用户通过 "< 1 / 2 >" 选择的子节点，否则默认选择最新（messageId 最大）的子节点。
 */
export function buildActivePath(
  allMessages: ChatMessage[],
  branchSelection: Map<string, number>
): ChatMessage[] {
  if (allMessages.length === 0) {
    return [];
  }

  const childrenMap: Map<string, ChatMessage[]> = new Map<string, ChatMessage[]>();
  const idSet: Set<number> = new Set<number>();

  for (const msg of allMessages) {
    idSet.add(msg.messageId);
  }

  for (const msg of allMessages) {
    const hasParentInTree = msg.parentId !== null && msg.parentId !== 0 && idSet.has(msg.parentId);
    const key = hasParentInTree ? String(msg.parentId) : 'root';
    const list = childrenMap.get(key);
    if (list !== undefined) {
      list.push(msg);
    } else {
      childrenMap.set(key, [msg]);
    }
  }

  childrenMap.forEach((list: ChatMessage[]) => {
    list.sort((a: ChatMessage, b: ChatMessage) => a.messageId - b.messageId);
  });

  const activePath: ChatMessage[] = [];
  const visited: Set<number> = new Set<number>();
  let currentKey = 'root';

  while (true) {
    const candidates = childrenMap.get(currentKey);
    if (candidates === undefined || candidates.length === 0) {
      break;
    }

    let chosen: ChatMessage = candidates[candidates.length - 1];
    const selectedId = branchSelection.get(currentKey);
    if (selectedId !== undefined) {
      for (const candidate of candidates) {
        if (candidate.messageId === selectedId) {
          chosen = candidate;
          break;
        }
      }
    }

    if (visited.has(chosen.messageId)) {
      break;
    }
    visited.add(chosen.messageId);
    activePath.push(chosen);
    currentKey = String(chosen.messageId);
  }

  return activePath;
}

export function getBranchInfo(allMessages: ChatMessage[], target: ChatMessage): BranchInfo {
  const targetParent = parentKey(target.parentId);
  const siblings: ChatMessage[] = [];
  for (const msg of allMessages) {
    if (parentKey(msg.parentId) === targetParent && msg.role === target.role) {
      siblings.push(msg);
    }
  }
  siblings.sort((a: ChatMessage, b: ChatMessage) => a.messageId - b.messageId);

  const siblingIds: number[] = [];
  let currentIndex = 1;
  for (let i = 0; i < siblings.length; i++) {
    siblingIds.push(siblings[i].messageId);
    if (siblings[i].messageId === target.messageId) {
      currentIndex = i + 1;
    }
  }

  return {
    currentIndex: currentIndex,
    totalCount: siblingIds.length,
    siblingIds: siblingIds
  };
}
