import { common } from '@kit.AbilityKit';

/**
 * 统一封装基于 UIContext 的提示与宿主 Context 获取，替代已废弃的全局 promptAction / getContext。
 */
export function showToast(uiContext: UIContext, message: string): void {
  try {
    uiContext.getPromptAction().showToast({ message: message });
  } catch (error) {
    // 忽略页面退出等场景下的弹窗异常。
  }
}

export function getHostContext(uiContext: UIContext): common.Context {
  return uiContext.getHostContext() as common.Context;
}
