import { common } from '@kit.AbilityKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { fileUri, picker } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { PickedLocalFile } from '../model/ChatModels';

export async function pickImageFromCamera(context: common.Context): Promise<PickedLocalFile | null> {
  try {
    const profile: cameraPicker.PickerProfile = {
      cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK
    };
    const result = await cameraPicker.pick(
      context,
      [cameraPicker.PickerMediaType.PHOTO],
      profile
    );
    if (result && result.resultUri && result.resultUri.length > 0) {
      const uri = result.resultUri;
      const name = resolveFileName(uri, `camera_${Date.now()}.jpg`);
      return {
        localUri: uri,
        fileName: name,
        mimeType: guessMimeType(name, true),
        isImage: true
      };
    }
  } catch (err) {
    // 用户取消拍照或无相机设备。
  }
  return null;
}

export async function pickImagesFromGallery(
  _context: common.Context,
  maxCount: number = 5
): Promise<PickedLocalFile[]> {
  try {
    const photoPicker = new photoAccessHelper.PhotoViewPicker();
    const options = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = maxCount;
    const result = await photoPicker.select(options);
    const out: PickedLocalFile[] = [];
    if (result && result.photoUris) {
      for (const uri of result.photoUris) {
        const name = resolveFileName(uri, `image_${Date.now()}.jpg`);
        out.push({
          localUri: uri,
          fileName: name,
          mimeType: guessMimeType(name, true),
          isImage: true
        });
      }
    }
    return out;
  } catch (err) {
    return [];
  }
}

export async function pickLocalDocuments(
  context: common.Context,
  maxCount: number = 5
): Promise<PickedLocalFile[]> {
  try {
    const docPicker = new picker.DocumentViewPicker(context);
    const options = new picker.DocumentSelectOptions();
    options.maxSelectNumber = maxCount;
    const uris = await docPicker.select(options);
    const out: PickedLocalFile[] = [];
    if (uris) {
      for (const uri of uris) {
        const name = resolveFileName(uri, `document_${Date.now()}`);
        const isImg = isImageName(name);
        out.push({
          localUri: uri,
          fileName: name,
          mimeType: guessMimeType(name, isImg),
          isImage: isImg
        });
      }
    }
    return out;
  } catch (err) {
    return [];
  }
}

function resolveFileName(uri: string, fallback: string): string {
  try {
    const parsed = new fileUri.FileUri(uri);
    if (parsed.name && parsed.name.length > 0) {
      return parsed.name;
    }
  } catch (err) {
    // 回退到字符串切分。
  }
  const slashIdx = uri.lastIndexOf('/');
  if (slashIdx >= 0 && slashIdx + 1 < uri.length) {
    try {
      return decodeURIComponent(uri.substring(slashIdx + 1));
    } catch (e) {
      return uri.substring(slashIdx + 1);
    }
  }
  return fallback;
}

function isImageName(name: string): boolean {
  const lower = name.toLowerCase();
  return lower.endsWith('.jpg') ||
    lower.endsWith('.jpeg') ||
    lower.endsWith('.png') ||
    lower.endsWith('.webp') ||
    lower.endsWith('.gif');
}

function guessMimeType(fileName: string, isImage: boolean): string {
  const lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  if (lower.endsWith('.gif')) {
    return 'image/gif';
  }
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || isImage) {
    return 'image/jpeg';
  }
  if (lower.endsWith('.pdf')) {
    return 'application/pdf';
  }
  if (lower.endsWith('.txt') || lower.endsWith('.md') || lower.endsWith('.csv')) {
    return 'text/plain';
  }
  if (lower.endsWith('.json')) {
    return 'application/json';
  }
  if (lower.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (lower.endsWith('.doc')) {
    return 'application/msword';
  }
  return 'application/octet-stream';
}
