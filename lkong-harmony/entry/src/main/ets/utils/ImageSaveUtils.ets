import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { HttpClient } from '../network/HttpClient';

export function detectImageExtension(buffer: ArrayBuffer, url: string): string {
  const bytes = new Uint8Array(buffer);
  if (bytes.length >= 4 &&
    bytes[0] === 0x47 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x38) {
    return 'gif';
  }
  if (bytes.length >= 4 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4E &&
    bytes[3] === 0x47) {
    return 'png';
  }
  if (bytes.length >= 12 &&
    bytes[0] === 0x52 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x46 &&
    bytes[8] === 0x57 &&
    bytes[9] === 0x45 &&
    bytes[10] === 0x42 &&
    bytes[11] === 0x50) {
    return 'webp';
  }
  const lower = url.toLowerCase().split('?')[0];
  if (lower.endsWith('.gif')) {
    return 'gif';
  }
  if (lower.endsWith('.png')) {
    return 'png';
  }
  if (lower.endsWith('.webp')) {
    return 'webp';
  }
  return 'jpg';
}

/**
 * 配合系统 SaveButton 安全控件免存储写权限保存图片至系统相册。
 */
export async function saveImageUrlToGallery(context: common.Context, imageUrl: string): Promise<void> {
  const buffer = await HttpClient.getInstance().downloadImage(imageUrl);
  const ext = detectImageExtension(buffer, imageUrl);
  const helper = photoAccessHelper.getPhotoAccessHelper(context);
  const assetUri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, ext);
  let file: fileIo.File | null = null;
  try {
    file = fileIo.openSync(assetUri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
    fileIo.writeSync(file.fd, buffer);
  } finally {
    if (file !== null) {
      try {
        fileIo.closeSync(file);
      } catch (closeErr) {
        // 忽略关闭异常。
      }
    }
  }
}
