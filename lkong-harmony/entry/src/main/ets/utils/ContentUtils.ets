import { BlockKind, InlineKind, PostBlock, PostInline } from '../model/Models';
import {
  asRecord,
  pickArray,
  pickBoolean,
  pickNumber,
  pickObject,
  pickString
} from '../network/JsonUtils';

const IMAGE_BASE_URL = 'https://images.lkong.com/images/';
const EMOTION_BASE_URL = 'https://image.lkong.com/bq/em';

/**
 * 帖子正文渲染。
 *
 * 龙空新帖的 content 不是 HTML，而是编辑器 JSON，例如：
 * [{"type":"paragraph","text":"..."}]
 * 或 ProseMirror/TipTap 结构：
 * {"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"..."}]}]}
 *
 * 这里把常见节点转成可读纯文本；旧帖如果仍是 HTML，则回退到 stripHtml。
 */

export function renderPostContent(raw: string): string {
  if (raw.length === 0) {
    return '（无内容）';
  }

  const trimmed = raw.trim();
  if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
    try {
      let parsed = JSON.parse(trimmed) as Object;
      // 有些接口会把 JSON 再包一层字符串。
      if (typeof parsed === 'string') {
        const inner = (parsed as string).trim();
        if (inner.startsWith('[') || inner.startsWith('{')) {
          parsed = JSON.parse(inner) as Object;
        }
      }

      let text = renderJson(parsed).trim();
      if (text.length === 0) {
        const values: string[] = [];
        collectTextValues(parsed, values);
        text = values.join('\n').trim();
      }
      if (text.length > 0) {
        return text.replace(/\n{3,}/g, '\n\n');
      }
    } catch (error) {
      // JSON 解析失败时按 HTML 处理。
    }
  }

  return stripHtml(raw);
}

function renderJson(value: Object): string {
  if (value === null || value === undefined) {
    return '';
  }
  if (Array.isArray(value)) {
    const list = value as Object[];
    const parts: string[] = [];
    for (const item of list) {
      parts.push(renderJson(item));
    }
    return parts.join('');
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number') {
    return String(value);
  }
  if (typeof value === 'boolean') {
    return value ? 'true' : 'false';
  }

  const node = value as Record<string, Object>;
  const type = pickString(node, ['type']);
  const text = pickString(node, ['text']);
  const attrs = asRecord(node['attrs']);
  const children = pickArray(node, ['content', 'children']);

  if (type === 'text') {
    return text;
  }
  if (type === 'hardBreak' || type === 'hard_break') {
    return '\n';
  }
  if (type === 'image') {
    const alt = pickString(attrs, ['alt', 'title']);
    return `${alt.length > 0 ? `[图片：${alt}]` : '[图片]'}\n`;
  }
  if (type === 'mention') {
    const label = pickString(attrs, ['label', 'name', 'id']);
    return label.length > 0 ? `@${label}` : '@某人';
  }
  if (type === 'emoji' || type === 'emotion') {
    const label = pickString(attrs, ['name', 'code', 'emoji']);
    return label.length > 0 ? label : '[表情]';
  }
  if (type === 'horizontalRule' || type === 'horizontal_rule') {
    return '\n---\n';
  }

  const content = children.length > 0 ? renderChildren(children) : text;

  if (type === 'paragraph' || type === 'heading' ||
    type === 'heading-one' || type === 'heading-two' || type === 'heading-three' ||
    type === 'codeBlock' || type === 'code_block') {
    return content + '\n';
  }
  if (type === 'blockquote' || type === 'block-quote') {
    const lines = content.trim().split('\n');
    const quoted: string[] = [];
    for (const line of lines) {
      quoted.push(`> ${line}`);
    }
    return quoted.join('\n') + '\n';
  }
  if (type === 'bulletList' || type === 'bullet_list') {
    const lines: string[] = [];
    for (const item of children) {
      lines.push(`• ${renderListItem(item)}`);
    }
    return lines.join('\n') + '\n';
  }
  if (type === 'orderedList' || type === 'ordered_list') {
    const lines: string[] = [];
    let index = 1;
    for (const item of children) {
      lines.push(`${index}. ${renderListItem(item)}`);
      index++;
    }
    return lines.join('\n') + '\n';
  }
  if (type === 'listItem' || type === 'list_item') {
    return renderListItem(value);
  }
  if (type === 'doc' || children.length > 0) {
    return content;
  }
  return text;
}

function renderChildren(children: Object[]): string {
  const parts: string[] = [];
  for (const child of children) {
    parts.push(renderJson(child));
  }
  return parts.join('');
}

function renderListItem(item: Object): string {
  const record = asRecord(item);
  const children = pickArray(record, ['content', 'children']);
  let text = renderChildren(children).trim();
  if (text.length === 0) {
    text = pickString(record, ['text']).trim();
  }
  return text.replace(/\n/g, '\n  ');
}

/**
 * 兜底：递归收集所有 text 字段，避免未知节点类型导致整段内容不可读。
 */
function collectTextValues(value: Object, output: string[]): void {
  if (value === null || value === undefined) {
    return;
  }
  if (Array.isArray(value)) {
    const list = value as Object[];
    for (const item of list) {
      collectTextValues(item, output);
    }
    return;
  }
  if (typeof value !== 'object') {
    return;
  }
  const record = value as Record<string, Object>;
  const text = pickString(record, ['text']);
  if (text.length > 0) {
    output.push(text);
  }
  const keys = Object.keys(record);
  for (const key of keys) {
    if (key === 'text') {
      continue;
    }
    const child = record[key];
    if (child !== undefined && child !== null && typeof child === 'object') {
      collectTextValues(child, output);
    }
  }
}

export function renderPostSummary(raw: string, maxLength: number = 140): string {
  const plain = renderPostContent(raw).replace(/\s+/g, ' ').trim();
  if (plain.length <= maxLength) {
    return plain;
  }
  return `${plain.slice(0, maxLength)}...`;
}

export function stripHtml(html: string): string {
  if (html.length === 0) {
    return '（无内容）';
  }

  let text = html;
  text = text.replace(/<br\s*\/?>/gi, '\n');
  text = text.replace(/<\/p>/gi, '\n');
  text = text.replace(/<[^>]+>/g, '');
  text = text.replace(/&nbsp;/g, ' ');
  text = text.replace(/&lt;/g, '<');
  text = text.replace(/&gt;/g, '>');
  text = text.replace(/&quot;/g, '"');
  text = text.replace(/&#39;/g, "'");
  text = text.replace(/&amp;/g, '&');
  text = text.replace(/\n{3,}/g, '\n\n');
  return text.trim();
}

export function blockHasEmotion(block: PostBlock): boolean {
  for (const inline of block.inlines) {
    if (inline.kind === InlineKind.EMOTION) {
      return true;
    }
  }
  return false;
}

interface InlineStyle {
  href: string;
  bold: boolean;
  italic: boolean;
  underline: boolean;
  strike: boolean;
  code: boolean;
}

function emptyStyle(): InlineStyle {
  const style: InlineStyle = {
    href: '',
    bold: false,
    italic: false,
    underline: false,
    strike: false,
    code: false
  };
  return style;
}

function sameStyle(item: PostInline, style: InlineStyle): boolean {
  return (
    item.href === style.href &&
    item.bold === style.bold &&
    item.italic === style.italic &&
    item.underline === style.underline &&
    item.strike === style.strike &&
    item.code === style.code
  );
}

function mergeNodeStyle(
  base: InlineStyle,
  node: Record<string, Object>,
  attrs: Record<string, Object>
): InlineStyle {
  let href = base.href;
  let bold = base.bold || pickBoolean(node, ['bold']);
  let italic = base.italic || pickBoolean(node, ['italic']);
  let underline = base.underline || pickBoolean(node, ['underline']);
  let strike = base.strike || pickBoolean(node, ['strikethrough', 'strike']);
  let code = base.code || pickBoolean(node, ['code']);

  const nodeType = pickString(node, ['type']);
  if (nodeType === 'link') {
    let rawLink = pickString(node, ['url', 'href']);
    if (rawLink.length === 0) {
      rawLink = pickString(attrs, ['url', 'href']);
    }
    const normalized = normalizeHttpUrl(rawLink);
    if (normalized.length > 0) {
      href = normalized;
    }
  }

  const marks = pickArray(node, ['marks']);
  for (const rawMark of marks) {
    const mark = asRecord(rawMark);
    const markType = pickString(mark, ['type']);
    if (markType === 'bold') {
      bold = true;
    } else if (markType === 'italic') {
      italic = true;
    } else if (markType === 'underline') {
      underline = true;
    } else if (markType === 'strike' || markType === 'strikethrough') {
      strike = true;
    } else if (markType === 'code') {
      code = true;
    } else if (markType === 'link') {
      const markAttrs = pickObject(mark, ['attrs']);
      const normalized = normalizeHttpUrl(pickString(markAttrs, ['href', 'url']));
      if (normalized.length > 0) {
        href = normalized;
      }
    }
  }

  const merged: InlineStyle = {
    href: href,
    bold: bold,
    italic: italic,
    underline: underline,
    strike: strike,
    code: code
  };
  return merged;
}

export function parsePostBlocks(raw: string): PostBlock[] {
  if (raw.length === 0) {
    return [createTextParagraph('（无内容）')];
  }

  const trimmed = raw.trim();
  if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
    try {
      let parsed = JSON.parse(trimmed) as Object;
      if (typeof parsed === 'string') {
        const inner = (parsed as string).trim();
        if (inner.startsWith('[') || inner.startsWith('{')) {
          parsed = JSON.parse(inner) as Object;
        }
      }

      const blocks: PostBlock[] = [];
      const pending: PostInline[] = [];
      collectJsonBlocks(parsed, blocks, pending, BlockKind.PARAGRAPH, emptyStyle());
      flushInlines(blocks, pending, BlockKind.PARAGRAPH);
      if (blocks.length > 0) {
        return blocks;
      }

      const values: string[] = [];
      collectTextValues(parsed, values);
      const fallback = values.join('\n').replace(/\n{3,}/g, '\n\n').trim();
      if (fallback.length > 0) {
        return [createTextParagraph(fallback)];
      }
      return [createTextParagraph('（无内容）')];
    } catch (error) {
      // JSON 解析失败时按 HTML 处理。
    }
  }

  return parseHtmlToBlocks(raw);
}

function createTextInline(text: string, style: InlineStyle): PostInline {
  const inline: PostInline = {
    kind: InlineKind.TEXT,
    text: text,
    url: '',
    href: style.href,
    bold: style.bold,
    italic: style.italic,
    underline: style.underline,
    strike: style.strike,
    code: style.code
  };
  return inline;
}

function createTextParagraph(text: string): PostBlock {
  const block: PostBlock = {
    kind: BlockKind.PARAGRAPH,
    inlines: [createTextInline(text, emptyStyle())],
    imageUrl: '',
    imageAlt: '',
    imageWidth: 0,
    imageHeight: 0
  };
  return block;
}

function appendTextInline(target: PostInline[], text: string, style: InlineStyle): void {
  if (text.length === 0) {
    return;
  }
  if (target.length > 0) {
    const last = target[target.length - 1];
    if (last.kind === InlineKind.TEXT && sameStyle(last, style)) {
      last.text = last.text + text;
      return;
    }
  }
  target.push(createTextInline(text, style));
}

function appendEmotionInline(target: PostInline[], url: string, fallbackText: string): void {
  if (url.length > 0) {
    target.push({
      kind: InlineKind.EMOTION,
      text: fallbackText,
      url: url,
      href: '',
      bold: false,
      italic: false,
      underline: false,
      strike: false,
      code: false
    });
  } else {
    appendTextInline(target, fallbackText, emptyStyle());
  }
}

function hasMeaningfulInlines(inlines: PostInline[]): boolean {
  for (const item of inlines) {
    if (item.kind === InlineKind.EMOTION) {
      return true;
    }
    if (item.text.trim().length > 0) {
      return true;
    }
  }
  return false;
}

function trimLeadingTrailingNewlines(inlines: PostInline[]): void {
  while (inlines.length > 0 && inlines[0].kind === InlineKind.TEXT) {
    const trimmedStart = inlines[0].text.replace(/^\n+/, '');
    if (trimmedStart.length === 0) {
      inlines.shift();
    } else {
      inlines[0].text = trimmedStart;
      break;
    }
  }
  while (inlines.length > 0 && inlines[inlines.length - 1].kind === InlineKind.TEXT) {
    const lastIdx = inlines.length - 1;
    const trimmedEnd = inlines[lastIdx].text.replace(/\n+$/, '');
    if (trimmedEnd.length === 0) {
      inlines.pop();
    } else {
      inlines[lastIdx].text = trimmedEnd;
      break;
    }
  }
}

function flushInlines(blocks: PostBlock[], pending: PostInline[], blockKind: string): void {
  if (pending.length === 0) {
    return;
  }
  const copied: PostInline[] = [];
  for (const item of pending) {
    copied.push({
      kind: item.kind,
      text: item.text,
      url: item.url,
      href: item.href,
      bold: item.bold,
      italic: item.italic,
      underline: item.underline,
      strike: item.strike,
      code: item.code
    });
  }
  pending.length = 0;
  trimLeadingTrailingNewlines(copied);
  if (!hasMeaningfulInlines(copied)) {
    return;
  }
  blocks.push({
    kind: blockKind,
    inlines: copied,
    imageUrl: '',
    imageAlt: '',
    imageWidth: 0,
    imageHeight: 0
  });
}

function normalizeHttpUrl(rawUrl: string): string {
  const trimmed = rawUrl.trim();
  if (trimmed.length === 0) {
    return '';
  }
  if (trimmed.startsWith('//')) {
    return `https:${trimmed}`;
  }
  if (trimmed.startsWith('https://') || trimmed.startsWith('http://')) {
    return trimmed;
  }
  return '';
}

function resolveImageUrl(node: Record<string, Object>, attrs: Record<string, Object>): string {
  let imageKey = pickString(node, ['imageKey']);
  if (imageKey.length === 0) {
    imageKey = pickString(attrs, ['imageKey']);
  }
  if (imageKey.length > 0) {
    return `${IMAGE_BASE_URL}${imageKey}.jpg`;
  }
  let url = pickString(node, ['url', 'src']);
  if (url.length === 0) {
    url = pickString(attrs, ['url', 'src']);
  }
  return normalizeHttpUrl(url);
}

function resolveEmotionUrl(node: Record<string, Object>, attrs: Record<string, Object>): string {
  let id = pickString(node, ['id']);
  if (id.length === 0) {
    id = pickString(attrs, ['id']);
  }
  if (id.length > 0) {
    return `${EMOTION_BASE_URL}${id}.gif`;
  }
  let url = pickString(node, ['url', 'src']);
  if (url.length === 0) {
    url = pickString(attrs, ['url', 'src']);
  }
  return normalizeHttpUrl(url);
}

function collectJsonBlocks(
  value: Object,
  blocks: PostBlock[],
  pending: PostInline[],
  blockKind: string,
  style: InlineStyle
): void {
  if (value === null || value === undefined) {
    return;
  }
  if (Array.isArray(value)) {
    const list = value as Object[];
    for (const item of list) {
      collectJsonBlocks(item, blocks, pending, blockKind, style);
    }
    return;
  }
  if (typeof value === 'string') {
    appendTextInline(pending, value, style);
    return;
  }
  if (typeof value === 'number') {
    appendTextInline(pending, String(value), style);
    return;
  }
  if (typeof value === 'boolean') {
    appendTextInline(pending, value ? 'true' : 'false', style);
    return;
  }

  const node = value as Record<string, Object>;
  const type = pickString(node, ['type']);
  const text = pickString(node, ['text']);
  const attrs = asRecord(node['attrs']);
  const children = pickArray(node, ['content', 'children']);
  const nextStyle = mergeNodeStyle(style, node, attrs);

  if (type === 'image') {
    flushInlines(blocks, pending, blockKind);
    const url = resolveImageUrl(node, attrs);
    let alt = pickString(node, ['alt', 'title']);
    if (alt.length === 0) {
      alt = pickString(attrs, ['alt', 'title']);
    }
    if (url.length > 0) {
      let width = pickNumber(node, ['width']);
      if (width <= 0) {
        width = pickNumber(attrs, ['width']);
      }
      let height = pickNumber(node, ['height']);
      if (height <= 0) {
        height = pickNumber(attrs, ['height']);
      }
      blocks.push({
        kind: BlockKind.IMAGE,
        inlines: [],
        imageUrl: url,
        imageAlt: alt,
        imageWidth: width,
        imageHeight: height
      });
    } else {
      appendTextInline(pending, alt.length > 0 ? `[图片：${alt}]` : '[图片]', emptyStyle());
      flushInlines(blocks, pending, blockKind);
    }
    return;
  }

  if (type === 'emotion' || type === 'emoji') {
    const url = resolveEmotionUrl(node, attrs);
    let label = pickString(node, ['name', 'code', 'emoji']);
    if (label.length === 0) {
      label = pickString(attrs, ['name', 'code', 'emoji']);
    }
    appendEmotionInline(pending, url, label.length > 0 ? label : '[表情]');
    return;
  }

  if (type === 'text' || (type.length === 0 && node['text'] !== undefined && children.length === 0)) {
    appendTextInline(pending, text, nextStyle);
    return;
  }

  if (type === 'hardBreak' || type === 'hard_break') {
    appendTextInline(pending, '\n', style);
    return;
  }

  if (type === 'mention') {
    let label = pickString(node, ['name', 'label', 'uid', 'id']);
    if (label.length === 0) {
      label = pickString(attrs, ['name', 'label', 'uid', 'id']);
    }
    appendTextInline(pending, label.length > 0 ? `@${label}` : '@某人', nextStyle);
    return;
  }

  if (type === 'link') {
    const beforeCount = pending.length;
    const beforeBlocks = blocks.length;
    if (children.length > 0) {
      for (const child of children) {
        collectJsonBlocks(child, blocks, pending, blockKind, nextStyle);
      }
    }
    if (pending.length === beforeCount && blocks.length === beforeBlocks) {
      let url = pickString(node, ['url', 'href']);
      if (url.length === 0) {
        url = pickString(attrs, ['url', 'href']);
      }
      if (url.length > 0) {
        appendTextInline(pending, url, nextStyle);
      }
    }
    return;
  }

  if (type === 'divider' || type === 'horizontalRule' || type === 'horizontal_rule') {
    flushInlines(blocks, pending, blockKind);
    blocks.push({
      kind: BlockKind.DIVIDER,
      inlines: [],
      imageUrl: '',
      imageAlt: '',
      imageWidth: 0,
      imageHeight: 0
    });
    return;
  }

  if (type === 'video') {
    appendTextInline(pending, '[视频]', style);
    return;
  }

  if (type === 'poll') {
    appendTextInline(pending, '[投票]', style);
    return;
  }

  if (type === 'blockquote' || type === 'block-quote') {
    flushInlines(blocks, pending, blockKind);
    if (children.length > 0) {
      for (const child of children) {
        collectJsonBlocks(child, blocks, pending, BlockKind.QUOTE, nextStyle);
      }
    } else if (text.length > 0) {
      appendTextInline(pending, text, nextStyle);
    }
    flushInlines(blocks, pending, BlockKind.QUOTE);
    return;
  }

  if (type === 'bulleted-list' || type === 'bulletList' || type === 'bullet_list' ||
    type === 'numbered-list' || type === 'orderedList' || type === 'ordered_list') {
    const ordered = type === 'numbered-list' || type === 'orderedList' || type === 'ordered_list';
    flushInlines(blocks, pending, blockKind);
    let index = 1;
    for (const item of children) {
      collectListItemBlocks(item, ordered ? `${index}. ` : '• ', blocks, blockKind);
      index++;
    }
    return;
  }

  if (type === 'list-item' || type === 'listItem' || type === 'list_item') {
    flushInlines(blocks, pending, blockKind);
    collectListItemBlocks(value, '• ', blocks, blockKind);
    return;
  }

  if (type === 'heading' || type === 'heading-one' || type === 'heading-two' || type === 'heading-three') {
    flushInlines(blocks, pending, blockKind);
    if (children.length > 0) {
      for (const child of children) {
        collectJsonBlocks(child, blocks, pending, BlockKind.HEADING, nextStyle);
      }
    } else if (text.length > 0) {
      appendTextInline(pending, text, nextStyle);
    }
    flushInlines(blocks, pending, BlockKind.HEADING);
    return;
  }

  if (type === 'code-block' || type === 'codeBlock' || type === 'code_block') {
    flushInlines(blocks, pending, blockKind);
    if (children.length > 0) {
      for (const child of children) {
        collectJsonBlocks(child, blocks, pending, BlockKind.CODE_BLOCK, nextStyle);
      }
    } else if (text.length > 0) {
      appendTextInline(pending, text, nextStyle);
    }
    flushInlines(blocks, pending, BlockKind.CODE_BLOCK);
    return;
  }

  if (type === 'paragraph') {
    const targetKind = blockKind === BlockKind.QUOTE ? BlockKind.QUOTE : BlockKind.PARAGRAPH;
    flushInlines(blocks, pending, blockKind);
    if (children.length > 0) {
      for (const child of children) {
        collectJsonBlocks(child, blocks, pending, targetKind, nextStyle);
      }
    } else if (text.length > 0) {
      appendTextInline(pending, text, nextStyle);
    }
    flushInlines(blocks, pending, targetKind);
    return;
  }

  if (children.length > 0) {
    for (const child of children) {
      collectJsonBlocks(child, blocks, pending, blockKind, nextStyle);
    }
    return;
  }

  if (text.length > 0) {
    appendTextInline(pending, text, nextStyle);
  }
}

function collectListItemBlocks(
  item: Object,
  prefix: string,
  blocks: PostBlock[],
  blockKind: string
): void {
  const itemPending: PostInline[] = [];
  const record = asRecord(item);
  const children = pickArray(record, ['content', 'children']);
  const directText = pickString(record, ['text']);
  if (children.length > 0) {
    const itemBlocks: PostBlock[] = [];
    for (const child of children) {
      collectJsonBlocks(child, itemBlocks, itemPending, blockKind, emptyStyle());
    }
    flushInlines(itemBlocks, itemPending, blockKind);
    if (itemBlocks.length > 0) {
      const first = itemBlocks[0];
      if (first.kind === BlockKind.PARAGRAPH || first.kind === BlockKind.QUOTE || first.kind === BlockKind.HEADING) {
        if (first.inlines.length > 0 && first.inlines[0].kind === InlineKind.TEXT && first.inlines[0].href.length === 0) {
          first.inlines[0].text = prefix + first.inlines[0].text;
        } else {
          first.inlines.unshift(createTextInline(prefix, emptyStyle()));
        }
      }
      for (const blk of itemBlocks) {
        blocks.push(blk);
      }
    }
  } else if (directText.length > 0) {
    appendTextInline(itemPending, prefix + directText, emptyStyle());
    flushInlines(blocks, itemPending, blockKind);
  }
}

function parseHtmlToBlocks(html: string): PostBlock[] {
  const blocks: PostBlock[] = [];
  const pending: PostInline[] = [];
  const tagRegex = /<img\b([^>]*)>|<a\b([^>]*)>([\s\S]*?)<\/a>/gi;
  let lastIndex = 0;
  let match: RegExpExecArray | null = tagRegex.exec(html);

  while (match !== null) {
    const before = html.slice(lastIndex, match.index);
    appendHtmlTextChunk(before, blocks, pending);

    if (match[1] !== undefined) {
      const attrsStr = match[1];
      const src = normalizeHttpUrl(extractHtmlAttr(attrsStr, 'src'));
      const alt = extractHtmlAttr(attrsStr, 'alt');
      const isEmotion = src.includes('/bq/em') ||
        attrsStr.toLowerCase().includes('emotion') ||
        attrsStr.toLowerCase().includes('emoji');

      if (src.length > 0 && isEmotion) {
        appendEmotionInline(pending, src, '[表情]');
      } else if (src.length > 0) {
        flushInlines(blocks, pending, BlockKind.PARAGRAPH);
        blocks.push({
          kind: BlockKind.IMAGE,
          inlines: [],
          imageUrl: src,
          imageAlt: alt,
          imageWidth: 0,
          imageHeight: 0
        });
      } else {
        appendTextInline(pending, alt.length > 0 ? `[图片：${alt}]` : '[图片]', emptyStyle());
      }
    } else {
      const linkAttrs = match[2] !== undefined ? match[2] : '';
      const linkInner = match[3] !== undefined ? match[3] : '';
      const href = normalizeHttpUrl(extractHtmlAttr(linkAttrs, 'href'));
      const label = stripHtmlPreserveWhitespace(linkInner).trim();
      const linkStyle: InlineStyle = {
        href: href,
        bold: false,
        italic: false,
        underline: false,
        strike: false,
        code: false
      };
      if (label.length > 0) {
        appendTextInline(pending, label, linkStyle);
      } else if (href.length > 0) {
        appendTextInline(pending, href, linkStyle);
      }
    }

    lastIndex = match.index + match[0].length;
    match = tagRegex.exec(html);
  }

  if (lastIndex < html.length) {
    appendHtmlTextChunk(html.slice(lastIndex), blocks, pending);
  }
  flushInlines(blocks, pending, BlockKind.PARAGRAPH);

  if (blocks.length === 0) {
    return [createTextParagraph('（无内容）')];
  }
  return blocks;
}

function appendHtmlTextChunk(chunk: string, blocks: PostBlock[], pending: PostInline[]): void {
  if (chunk.length === 0) {
    return;
  }
  const hasBlockBreak = /<\/(?:p|div|blockquote|li|h[1-6])>|<br\s*\/?>/i.test(chunk);
  const plain = stripHtmlPreserveWhitespace(chunk);
  if (plain.length === 0) {
    if (hasBlockBreak && pending.length > 0) {
      flushInlines(blocks, pending, BlockKind.PARAGRAPH);
    }
    return;
  }
  const baseStyle = emptyStyle();
  if (!plain.includes('\n')) {
    appendTextInline(pending, plain, baseStyle);
    return;
  }
  const parts = plain.split('\n');
  for (let i = 0; i < parts.length; i++) {
    const part = parts[i];
    if (part.trim().length > 0) {
      appendTextInline(pending, part, baseStyle);
    }
    if (i < parts.length - 1) {
      flushInlines(blocks, pending, BlockKind.PARAGRAPH);
    }
  }
}

function stripHtmlPreserveWhitespace(html: string): string {
  let text = html;
  text = text.replace(/<br\s*\/?>/gi, '\n');
  text = text.replace(/<\/(?:p|div|blockquote|li|h[1-6])>/gi, '\n');
  text = text.replace(/<[^>]+>/g, '');
  text = text.replace(/&nbsp;/g, ' ');
  text = text.replace(/&lt;/g, '<');
  text = text.replace(/&gt;/g, '>');
  text = text.replace(/&quot;/g, '"');
  text = text.replace(/&#39;/g, "'");
  text = text.replace(/&amp;/g, '&');
  return text.replace(/\n{3,}/g, '\n\n');
}

function extractHtmlAttr(attrs: string, name: string): string {
  const regex = new RegExp(`${name}\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s>]+))`, 'i');
  const match = regex.exec(attrs);
  if (match === null) {
    return '';
  }
  if (match[1] !== undefined) {
    return match[1];
  }
  if (match[2] !== undefined) {
    return match[2];
  }
  if (match[3] !== undefined) {
    return match[3];
  }
  return '';
}