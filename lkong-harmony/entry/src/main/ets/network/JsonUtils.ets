/**
 * Next.js 页面数据是动态 JSON，ArkTS 静态类型无法预先覆盖所有可选字段。
 * 这些工具函数把 Object 安全地收敛为 Record<string, Object>，并提供容错取值。
 */

export function asRecord(value: Object | undefined): Record<string, Object> {
  if (value === undefined || value === null) {
    return {};
  }
  return value as Record<string, Object>;
}

export function asArray(value: Object | undefined): Object[] {
  if (value === undefined || value === null) {
    return [];
  }
  if (Array.isArray(value)) {
    return value as Object[];
  }
  return [];
}

export function pickString(record: Record<string, Object>, keys: string[]): string {
  for (const key of keys) {
    const value = record[key];
    if (value === undefined || value === null) {
      continue;
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
  }
  return '';
}

export function pickNumber(record: Record<string, Object>, keys: string[]): number {
  for (const key of keys) {
    const value = record[key];
    if (value === undefined || value === null) {
      continue;
    }
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      const parsed = Number(value);
      if (!isNaN(parsed)) {
        return parsed;
      }
    }
  }
  return 0;
}

export function pickBoolean(record: Record<string, Object>, keys: string[]): boolean {
  for (const key of keys) {
    const value = record[key];
    if (value === undefined || value === null) {
      continue;
    }
    if (typeof value === 'boolean') {
      return value;
    }
    if (typeof value === 'number') {
      return value !== 0;
    }
    if (typeof value === 'string') {
      const normalized = value.toLowerCase();
      return normalized === '1' || normalized === 'true' || normalized === 'yes';
    }
  }
  return false;
}

export function pickObject(record: Record<string, Object>, keys: string[]): Record<string, Object> {
  for (const key of keys) {
    const value = record[key];
    if (value !== undefined && value !== null && typeof value === 'object' && !Array.isArray(value)) {
      return value as Record<string, Object>;
    }
  }
  return {};
}

export function pickArray(record: Record<string, Object>, keys: string[]): Object[] {
  for (const key of keys) {
    const value = record[key];
    if (Array.isArray(value)) {
      return value as Object[];
    }
  }
  return [];
}