import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { ApiError, ErrorKind, UploadedImage } from '../model/Models';
import { LkongApi } from '../network/LkongApi';

const MAX_IMAGE_FILE_BYTES: number = 15 * 1024 * 1024;
const COMPRESS_THRESHOLD_BYTES: number = 2 * 1024 * 1024;
const MAX_IMAGE_DIMENSION: number = 1920;

interface ImageFileSpec {
  fileName: string;
  contentType: string;
  isGif: boolean;
}

export async function pickImageUris(maxCount: number): Promise<string[]> {
  const safeCount = Math.max(1, Math.min(9, maxCount));
  const options = new photoAccessHelper.PhotoSelectOptions();
  options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
  options.maxSelectNumber = safeCount;
  const picker = new photoAccessHelper.PhotoViewPicker();
  const result = await picker.select(options);
  if (result === undefined || result === null || result.photoUris === undefined) {
    return [];
  }
  const uris: string[] = [];
  for (const uri of result.photoUris) {
    if (uri.length > 0) {
      uris.push(uri);
    }
  }
  return uris;
}

function detectImageFileSpec(buffer: ArrayBuffer, uri: string): ImageFileSpec {
  const bytes = new Uint8Array(buffer);
  // GIF87a / GIF89a
  if (
    bytes.length >= 4 &&
    bytes[0] === 0x47 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x38
  ) {
    return {
      fileName: 'upload.gif',
      contentType: 'image/gif',
      isGif: true
    };
  }
  // PNG
  if (
    bytes.length >= 4 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4E &&
    bytes[3] === 0x47
  ) {
    return {
      fileName: 'upload.png',
      contentType: 'image/png',
      isGif: false
    };
  }
  // WEBP (RIFF....WEBP)
  if (
    bytes.length >= 12 &&
    bytes[0] === 0x52 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x46 &&
    bytes[8] === 0x57 &&
    bytes[9] === 0x45 &&
    bytes[10] === 0x42 &&
    bytes[11] === 0x50
  ) {
    return {
      fileName: 'upload.webp',
      contentType: 'image/webp',
      isGif: false
    };
  }
  if (uri.toLowerCase().endsWith('.gif')) {
    return {
      fileName: 'upload.gif',
      contentType: 'image/gif',
      isGif: true
    };
  }
  return {
    fileName: 'upload.jpg',
    contentType: 'image/jpeg',
    isGif: false
  };
}

export async function prepareAndUploadImage(uri: string): Promise<UploadedImage> {
  if (uri.length === 0) {
    throw new ApiError(ErrorKind.UNKNOWN, '图片路径无效。');
  }

  let file: fileIo.File | null = null;
  let imageSource: image.ImageSource | null = null;
  let pixelMap: image.PixelMap | null = null;
  let packer: image.ImagePacker | null = null;

  try {
    file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    const stat = fileIo.statSync(file.fd);
    if (stat.size <= 0) {
      throw new ApiError(ErrorKind.UNKNOWN, '图片文件为空。');
    }
    if (stat.size > MAX_IMAGE_FILE_BYTES) {
      throw new ApiError(ErrorKind.UNKNOWN, '图片大小不能超过 15MB。');
    }

    const rawBuffer = new ArrayBuffer(stat.size);
    const readLen = fileIo.readSync(file.fd, rawBuffer);
    const effectiveBuffer = readLen === stat.size ? rawBuffer : rawBuffer.slice(0, readLen);
    const spec = detectImageFileSpec(effectiveBuffer, uri);

    // GIF 保持原图直传，防止丢帧。
    if (spec.isGif) {
      return await LkongApi.getInstance().uploadImageBytes(effectiveBuffer, spec.fileName, spec.contentType);
    }

    imageSource = image.createImageSource(file.fd);
    const info = await imageSource.getImageInfo();
    const origW = info.size.width;
    const origH = info.size.height;
    const maxDim = Math.max(origW, origH);

    if (maxDim <= MAX_IMAGE_DIMENSION && effectiveBuffer.byteLength <= COMPRESS_THRESHOLD_BYTES) {
      return await LkongApi.getInstance().uploadImageBytes(effectiveBuffer, spec.fileName, spec.contentType);
    }

    let targetW = origW;
    let targetH = origH;
    if (maxDim > MAX_IMAGE_DIMENSION && origW > 0 && origH > 0) {
      const scale = MAX_IMAGE_DIMENSION / maxDim;
      targetW = Math.max(1, Math.round(origW * scale));
      targetH = Math.max(1, Math.round(origH * scale));
    }

    const decodeOpts: image.DecodingOptions = targetW > 0 && targetH > 0
      ? { desiredSize: { width: targetW, height: targetH } }
      : {};
    pixelMap = await imageSource.createPixelMap(decodeOpts);
    packer = image.createImagePacker();
    const packOpts: image.PackingOption = {
      format: 'image/jpeg',
      quality: 85
    };
    const packedBuffer = await packer.packToData(pixelMap, packOpts);
    return await LkongApi.getInstance().uploadImageBytes(packedBuffer, 'upload.jpg', 'image/jpeg');
  } catch (error) {
    if (error instanceof ApiError) {
      throw error;
    }
    throw new ApiError(ErrorKind.UNKNOWN, '图片处理或上传失败，请重试。');
  } finally {
    if (packer !== null) {
      try {
        await packer.release();
      } catch (e) {
      }
    }
    if (pixelMap !== null) {
      try {
        await pixelMap.release();
      } catch (e) {
      }
    }
    if (imageSource !== null) {
      try {
        await imageSource.release();
      } catch (e) {
      }
    }
    if (file !== null) {
      try {
        fileIo.closeSync(file);
      } catch (e) {
      }
    }
  }
}
