import { preferences } from '@kit.ArkData';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { FontSizeLevel, ThemeMode } from '../model/ChatModels';

const PREF_NAME = 'deepseek_settings';
const KEY_THEME = 'theme_mode';
const KEY_FONT_SIZE = 'font_size_level';
const KEY_DEFAULT_THINKING = 'default_thinking';
const KEY_DEFAULT_SEARCH = 'default_search';
const KEY_AUTO_COLLAPSE_THINKING = 'auto_collapse_thinking';

export class SettingsStore {
  private static instance: SettingsStore = new SettingsStore();
  private prefs: preferences.Preferences | null = null;
  private themeMode: ThemeMode = 'system';
  private fontSizeLevel: FontSizeLevel = 'standard';
  private defaultThinking: boolean = true;
  private defaultSearch: boolean = false;
  private autoCollapseThinking: boolean = false;

  static getInstance(): SettingsStore {
    return SettingsStore.instance;
  }

  async ensureInit(context: common.Context): Promise<void> {
    if (this.prefs !== null) {
      return;
    }
    try {
      this.prefs = await preferences.getPreferences(context, { name: PREF_NAME });
      const themeRaw = String(await this.prefs.get(KEY_THEME, 'system'));
      if (themeRaw === 'light' || themeRaw === 'dark' || themeRaw === 'system') {
        this.themeMode = themeRaw;
      }
      const fontRaw = String(await this.prefs.get(KEY_FONT_SIZE, 'standard'));
      if (fontRaw === 'standard' || fontRaw === 'large' || fontRaw === 'xlarge') {
        this.fontSizeLevel = fontRaw;
      }
      this.defaultThinking = Boolean(await this.prefs.get(KEY_DEFAULT_THINKING, true));
      this.defaultSearch = Boolean(await this.prefs.get(KEY_DEFAULT_SEARCH, false));
      this.autoCollapseThinking = Boolean(await this.prefs.get(KEY_AUTO_COLLAPSE_THINKING, false));
    } catch (error) {
      this.prefs = null;
    }
  }

  getThemeMode(): ThemeMode {
    return this.themeMode;
  }

  getFontSizeLevel(): FontSizeLevel {
    return this.fontSizeLevel;
  }

  getDefaultThinking(): boolean {
    return this.defaultThinking;
  }

  getDefaultSearch(): boolean {
    return this.defaultSearch;
  }

  getAutoCollapseThinking(): boolean {
    return this.autoCollapseThinking;
  }

  getBodyFontSize(): number {
    if (this.fontSizeLevel === 'large') {
      return 17;
    }
    if (this.fontSizeLevel === 'xlarge') {
      return 19;
    }
    return 15;
  }

  async setThemeMode(mode: ThemeMode, context: common.Context): Promise<void> {
    this.themeMode = mode;
    this.applyColorMode(context);
    await this.saveString(KEY_THEME, mode);
  }

  async setFontSizeLevel(level: FontSizeLevel): Promise<void> {
    this.fontSizeLevel = level;
    await this.saveString(KEY_FONT_SIZE, level);
  }

  async setDefaultThinking(enabled: boolean): Promise<void> {
    this.defaultThinking = enabled;
    await this.saveBool(KEY_DEFAULT_THINKING, enabled);
  }

  async setDefaultSearch(enabled: boolean): Promise<void> {
    this.defaultSearch = enabled;
    await this.saveBool(KEY_DEFAULT_SEARCH, enabled);
  }

  async setAutoCollapseThinking(enabled: boolean): Promise<void> {
    this.autoCollapseThinking = enabled;
    await this.saveBool(KEY_AUTO_COLLAPSE_THINKING, enabled);
  }

  applyColorMode(context: common.Context): void {
    try {
      let targetMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
      if (this.themeMode === 'light') {
        targetMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
      } else if (this.themeMode === 'dark') {
        targetMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      }
      context.getApplicationContext().setColorMode(targetMode);
      if (this.themeMode === 'dark') {
        AppStorage.setOrCreate('isDarkMode', true);
      } else if (this.themeMode === 'light') {
        AppStorage.setOrCreate('isDarkMode', false);
      } else {
        const uiCtx = context as common.UIAbilityContext;
        if (uiCtx.config !== undefined && uiCtx.config.colorMode !== undefined) {
          AppStorage.setOrCreate(
            'isDarkMode',
            uiCtx.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
          );
        }
      }
    } catch (error) {
      // 忽略旧版本或预览器环境设置失败。
    }
  }

  private async saveString(key: string, value: string): Promise<void> {
    if (this.prefs === null) {
      return;
    }
    try {
      await this.prefs.put(key, value);
      await this.prefs.flush();
    } catch (error) {
      // 忽略存储异常。
    }
  }

  private async saveBool(key: string, value: boolean): Promise<void> {
    if (this.prefs === null) {
      return;
    }
    try {
      await this.prefs.put(key, value);
      await this.prefs.flush();
    } catch (error) {
      // 忽略存储异常。
    }
  }
}
