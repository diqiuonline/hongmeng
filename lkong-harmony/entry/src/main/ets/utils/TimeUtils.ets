/**
 * 龙空页面里的时间可能是 Unix 秒、毫秒或普通字符串。
 * 这里做宽松处理，解析失败时保留原值，避免因为时间格式变化导致列表整体失败。
 */
export function formatTime(value: string): string {
  if (value.length === 0) {
    return '';
  }

  const numeric = Number(value);
  if (!isNaN(numeric) && numeric > 0) {
    const milliseconds = numeric > 1000000000000 ? numeric : numeric * 1000;
    return formatDate(new Date(milliseconds));
  }

  const date = new Date(value);
  if (!isNaN(date.getTime())) {
    return formatDate(date);
  }
  return value;
}

function formatDate(date: Date): string {
  const now = new Date();
  const diff = now.getTime() - date.getTime();

  if (diff >= 0 && diff < 60 * 1000) {
    return '刚刚';
  }
  if (diff >= 0 && diff < 60 * 60 * 1000) {
    return `${Math.floor(diff / 60000)} 分钟前`;
  }
  if (diff >= 0 && diff < 24 * 60 * 60 * 1000) {
    return `${Math.floor(diff / 3600000)} 小时前`;
  }

  const year = date.getFullYear();
  const month = `${date.getMonth() + 1}`.padStart(2, '0');
  const day = `${date.getDate()}`.padStart(2, '0');
  return `${year}-${month}-${day}`;
}