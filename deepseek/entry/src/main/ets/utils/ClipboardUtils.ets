import { pasteboard } from '@kit.BasicServicesKit';

export async function copyTextToClipboard(text: string): Promise<boolean> {
  if (text.length === 0) {
    return false;
  }
  try {
    const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    const systemPasteboard = pasteboard.getSystemPasteboard();
    await systemPasteboard.setData(pasteData);
    return true;
  } catch (error) {
    return false;
  }
}
