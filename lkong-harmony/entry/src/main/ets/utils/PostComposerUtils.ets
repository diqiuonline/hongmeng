import { NoticeCount, UploadedImage } from '../model/Models';
import { pickArray, pickBoolean, pickNumber, pickObject, pickString } from '../network/JsonUtils';
import { parsePostBlocks } from './ContentUtils';

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
    Math.max(0, count.fansCount) +
    Math.max(0, count.pmCount)
  );
}

export interface EditablePostContent {
  text: string;
  images: UploadedImage[];
}

function extractImageKeyFromUrl(rawUrl: string): string {
  const match = /\/images\/([^./?#]+)(?:\.[a-z0-9]+)?(?:[?#]|$)/i.exec(rawUrl);
  return match !== null ? match[1] : '';
}

function extractEmotionIdFromUrl(rawUrl: string): number {
  const match = /\/bq\/em(\d+)\.gif/i.exec(rawUrl);
  if (match === null) {
    return 0;
  }
  const id = Number(match[1]);
  return isNaN(id) ? 0 : id;
}

function extractEditableLine(node: Object): string {
  if (node === null || node === undefined) {
    return '';
  }
  if (typeof node === 'string') {
    return node;
  }
  if (Array.isArray(node)) {
    const parts: string[] = [];
    for (const item of node as Object[]) {
      parts.push(extractEditableLine(item));
    }
    return parts.join('');
  }
  const rec = node as Record<string, Object>;
  const type = pickString(rec, ['type']);
  const attrs = pickObject(rec, ['attrs']);
  if (type === 'emotion' || type === 'emoji') {
    let eid = pickNumber(rec, ['id']);
    if (eid <= 0) {
      eid = pickNumber(attrs, ['id']);
    }
    if (eid > 0) {
      return formatEmotionToken(eid);
    }
    const url = pickString(rec, ['url', 'src']);
    const urlId = extractEmotionIdFromUrl(url);
    return urlId > 0 ? formatEmotionToken(urlId) : '[表情]';
  }
  if (type === 'hardBreak' || type === 'hard_break') {
    return '\n';
  }
  const children = pickArray(rec, ['children', 'content']);
  if (children.length > 0) {
    const parts: string[] = [];
    for (const child of children) {
      parts.push(extractEditableLine(child));
    }
    return parts.join('');
  }
  return pickString(rec, ['text']);
}

/**
 * 将已发布帖子的 Slate JSON（或旧帖 HTML）还原为 ComposePage 可编辑的纯文本 + [em{id}] + 图片附件列表。
 */
export function parseEditablePostContent(raw: string): EditablePostContent {
  const images: UploadedImage[] = [];
  const trimmed = raw.trim();
  if (trimmed.length === 0) {
    return { text: '', images: images };
  }

  if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
    try {
      let parsed = JSON.parse(trimmed) as Object;
      if (typeof parsed === 'string') {
        const inner = (parsed as string).trim();
        if (inner.startsWith('[') || inner.startsWith('{')) {
          parsed = JSON.parse(inner) as Object;
        }
      }
      const rootNodes: Object[] = Array.isArray(parsed)
        ? (parsed as Object[])
        : pickArray(parsed as Record<string, Object>, ['content', 'children']);
      if (rootNodes.length > 0) {
        const lines: string[] = [];
        for (const item of rootNodes) {
          if (item === null || item === undefined || typeof item !== 'object') {
            continue;
          }
          const rec = item as Record<string, Object>;
          const type = pickString(rec, ['type']);
          const attrs = pickObject(rec, ['attrs']);
          if (type === 'image') {
            let key = pickString(rec, ['imageKey']);
            if (key.length === 0) {
              key = pickString(attrs, ['imageKey']);
            }
            if (key.length === 0) {
              const url = pickString(rec, ['url', 'src']);
              key = extractImageKeyFromUrl(url.length > 0 ? url : pickString(attrs, ['url', 'src']));
            }
            if (key.length > 0) {
              let width = pickNumber(rec, ['width']);
              if (width <= 0) {
                width = pickNumber(attrs, ['width']);
              }
              let height = pickNumber(rec, ['height']);
              if (height <= 0) {
                height = pickNumber(attrs, ['height']);
              }
              images.push({
                key: key,
                width: width,
                height: height
              });
            }
            continue;
          }
          lines.push(extractEditableLine(item));
        }
        return {
          text: lines.join('\n'),
          images: images
        };
      }
    } catch (error) {
      // JSON 解析失败时回退到块解析。
    }
  }

  const blocks = parsePostBlocks(raw);
  const fallbackLines: string[] = [];
  for (const blk of blocks) {
    if (blk.kind === 'image') {
      const key = extractImageKeyFromUrl(blk.imageUrl);
      if (key.length > 0) {
        images.push({
          key: key,
          width: blk.imageWidth,
          height: blk.imageHeight
        });
      }
      continue;
    }
    const lineParts: string[] = [];
    for (const inline of blk.inlines) {
      if (inline.kind === 'emotion') {
        const eid = extractEmotionIdFromUrl(inline.url);
        lineParts.push(eid > 0 ? formatEmotionToken(eid) : inline.text);
      } else {
        lineParts.push(inline.text);
      }
    }
    fallbackLines.push(lineParts.join(''));
  }
  return {
    text: fallbackLines.join('\n'),
    images: images
  };
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
