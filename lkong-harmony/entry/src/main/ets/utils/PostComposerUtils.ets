import { NoticeCount, UploadedImage } from '../model/Models';
import { pickBoolean, pickNumber, pickString } from '../network/JsonUtils';

const EMOTION_BASE_URL = 'https://image.lkong.com/bq/em';
const UPLOADED_IMAGE_BASE_URL = 'https://images.lkong.com/images/';
const HIGHLIGHT_COLORS: string[] = ['', '红', '橙', '黄', '绿', '青', '蓝', '紫', '粉'];

export interface EmotionGroup {
  name: string;
  title: string;
  ids: number[];
}

export const EMOTION_GROUPS: EmotionGroup[] = [
  {
    name: 'monkey',
    title: '悠嘻猴',
    ids: [
      50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66,
      67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83
    ]
  },
  {
    name: 'monkey2',
    title: '悠嘻猴2',
    ids: [
      84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99,
      100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115
    ]
  },
  {
    name: 'onion',
    title: '洋葱头',
    ids: [
      222, 238, 243, 244, 241, 240, 235, 234, 239, 246, 237, 242,
      223, 224, 225, 226, 227, 228, 229, 230, 231, 233, 232, 283,
      256, 274, 280, 275, 292, 260, 303, 285, 265, 307, 236
    ]
  },
  {
    name: 'onion2',
    title: '洋葱头2',
    ids: [
      245, 305, 253, 261, 254, 299, 295, 271, 306, 284, 272, 291,
      251, 298, 302, 267, 273, 278, 289, 252, 269, 290, 250, 270,
      310, 281, 258, 255, 257, 277, 268, 308, 266, 279, 276, 264,
      259, 297, 218, 219, 220, 296, 309, 300, 282, 301, 263, 294,
      262, 304, 286, 293, 221
    ]
  }
];

interface SlateTextLeaf {
  text: string;
}

interface SlateEmotionNode {
  type: string;
  id: number;
}

interface SlateParagraphNode {
  type: string;
  children: Object[];
}

interface SlateImageNode {
  type: string;
  imageKey: string;
  width: number;
  height: number;
}

export function emotionImageUrl(id: number): string {
  return `${EMOTION_BASE_URL}${id}.gif`;
}

export function uploadedImageUrl(key: string): string {
  return `${UPLOADED_IMAGE_BASE_URL}${key}.jpg`;
}

export function formatEmotionToken(id: number): string {
  return `[em${id}]`;
}

export function removeLastTokenOrChar(text: string): string {
  if (text.length === 0) {
    return '';
  }
  const tokenMatch = /\[em\d+\]$/.exec(text);
  if (tokenMatch !== null) {
    return text.slice(0, text.length - tokenMatch[0].length);
  }
  const chars = Array.from(text);
  chars.pop();
  return chars.join('');
}

export function hasPublishableContent(rawText: string, images: UploadedImage[]): boolean {
  if (rawText.trim().length > 0) {
    return true;
  }
  for (const img of images) {
    if (img.key.length > 0) {
      return true;
    }
  }
  return false;
}

export function buildPostContentJson(rawText: string, images: UploadedImage[]): string {
  const normalized = rawText.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  const lines = normalized.split('\n');
  while (lines.length > 0 && lines[lines.length - 1].trim().length === 0) {
    lines.pop();
  }

  const blocks: Object[] = [];
  for (const line of lines) {
    const children: Object[] = [];
    const tokenRegex = /\[em(\d+)\]/g;
    let lastIndex = 0;
    let match: RegExpExecArray | null = tokenRegex.exec(line);
    while (match !== null) {
      if (match.index > lastIndex) {
        const textPart: SlateTextLeaf = {
          text: line.slice(lastIndex, match.index)
        };
        children.push(textPart);
      }
      const emotionId = Number(match[1]);
      if (!isNaN(emotionId) && emotionId > 0) {
        const emotionNode: SlateEmotionNode = {
          type: 'emotion',
          id: emotionId
        };
        children.push(emotionNode);
      } else {
        const fallbackLeaf: SlateTextLeaf = {
          text: match[0]
        };
        children.push(fallbackLeaf);
      }
      lastIndex = match.index + match[0].length;
      match = tokenRegex.exec(line);
    }

    if (lastIndex < line.length) {
      const tailLeaf: SlateTextLeaf = {
        text: line.slice(lastIndex)
      };
      children.push(tailLeaf);
    }

    if (children.length === 0) {
      const emptyLeaf: SlateTextLeaf = {
        text: ''
      };
      children.push(emptyLeaf);
    }

    const paragraphNode: SlateParagraphNode = {
      type: 'paragraph',
      children: children
    };
    blocks.push(paragraphNode);
  }

  for (const img of images) {
    if (img.key.length === 0) {
      continue;
    }
    const imageNode: SlateImageNode = {
      type: 'image',
      imageKey: img.key,
      width: img.width > 0 ? img.width : 0,
      height: img.height > 0 ? img.height : 0
    };
    blocks.push(imageNode);
  }

  if (blocks.length === 0) {
    const emptyLeaf: SlateTextLeaf = {
      text: ''
    };
    const emptyParagraph: SlateParagraphNode = {
      type: 'paragraph',
      children: [emptyLeaf]
    };
    blocks.push(emptyParagraph);
  }

  return JSON.stringify(blocks);
}

export function formatNoticeUnreadBadge(count: number): string {
  if (count <= 0) {
    return '';
  }
  return count > 99 ? '99+' : `${count}`;
}

export function getVisibleUnreadTotal(count: NoticeCount | null): number {
  if (count === null) {
    return 0;
  }
  return (
    Math.max(0, count.noticeCount) +
    Math.max(0, count.atmeCount) +
    Math.max(0, count.rateCount) +
    Math.max(0, count.fansCount)
  );
}

/**
 * 映射龙空官网版务与系统通知的 19 种操作描述。
 */
export function formatModifyActionText(key: string, args: Record<string, Object>): string {
  const undo = pickBoolean(args, ['undo']);
  const deadline = pickNumber(args, ['deadline']);
  const highlight = pickNumber(args, ['highlight']);
  const isSuper = pickBoolean(args, ['isSuper']);
  const toForum = pickString(args, ['toforum']);
  const num = pickNumber(args, ['num']);

  if (key === 'modifyThreadDismiss') {
    return '移除版面';
  }
  if (key === 'modifyThreadHighLight') {
    if (highlight === 0) {
      return '取消高亮';
    }
    const colorName = highlight >= 0 && highlight < HIGHLIGHT_COLORS.length && HIGHLIGHT_COLORS[highlight].length > 0
      ? HIGHLIGHT_COLORS[highlight]
      : '色';
    const base = `高亮变${colorName}`;
    return deadline > 0 ? `${base}${deadline}天` : base;
  }
  if (key === 'modifyThreadAddTags') {
    return '修改标签';
  }
  if (key === 'modifyThreadFutie') {
    const base = isSuper ? '全站浮贴' : '浮贴';
    return deadline > 0 ? `${base}${deadline}天` : base;
  }
  if (key === 'modifyThreadUnFutie') {
    return '取消浮贴';
  }
  if (key === 'modifyThreadMove') {
    return toForum.length > 0 ? `移动到${toForum}` : '移动';
  }
  if (key === 'modifyThreadTop') {
    const base = isSuper ? '全站置顶' : '置顶';
    return deadline > 0 ? `${base}${deadline}天` : base;
  }
  if (key === 'modifyThreadUnTop') {
    return '解除置顶';
  }
  if (key === 'modifyThreadRecommend') {
    return undo ? '移出精选' : '加入精选';
  }
  if (key === 'modifyThreadUpdown') {
    return undo ? '下沉' : '提升';
  }
  if (key === 'modifyThreadAward') {
    return undo ? '取消龙粮奖励' : '龙粮奖励';
  }
  if (key === 'modifyThreadDelete') {
    return '删除主题';
  }
  if (key === 'modifyThreadLock') {
    return undo ? '打开' : '关闭';
  }
  if (key === 'modifyPostWarning') {
    return undo ? '取消黄牌' : '发放黄牌';
  }
  if (key === 'modifyPostIgnore') {
    return undo ? '解除屏蔽' : '屏蔽';
  }
  if (key === 'modifyPostLockEdit') {
    return undo ? '允许编辑' : '禁止编辑';
  }
  if (key === 'modifyPostDigest') {
    return undo ? '取消精华' : '添加精华';
  }
  if (key === 'modifyPostLongjing') {
    return num > 0 ? `奖励${num}龙晶` : `扣除${0 - num}龙晶`;
  }
  if (key === 'modifyPostCensor') {
    return '通过审核';
  }
  return '操作';
}
