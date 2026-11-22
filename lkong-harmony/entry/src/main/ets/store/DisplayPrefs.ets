import { preferences } from '@kit.ArkData';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import {
  FontSizePreset,
  KEY_FONT_SIZE,
  KEY_IS_DARK,
  KEY_THEME_MODE,
  ThemeMode
} from '../utils/Theme';

const PREF_NAME = 'lkong_display';
const KEY_STORED_THEME = 'theme_mode';
const KEY_STORED_FONT_SIZE = 'font_size';

/**
 * 显示与阅读偏好存储（主题模式、正文字号），通过 Preferences 持久化并同步到 AppStorage。
 */
export class DisplayPrefs {
  private static instance: DisplayPrefs = new DisplayPrefs();
  private prefs: preferences.Preferences | null = null;
  private initialized: boolean = false;
  private systemIsDark: boolean = false;
  private themeMode: string = ThemeMode.SYSTEM;
  private fontSize: number = FontSizePreset.STANDARD;

  private constructor() {
    this.syncAppStorage();
  }

  static getInstance(): DisplayPrefs {
    return DisplayPrefs.instance;
  }

  async ensureInit(context: common.Context, initialColorMode?: ConfigurationConstant.ColorMode): Promise<void> {
    if (initialColorMode !== undefined) {
      this.systemIsDark = initialColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }

    if (this.initialized) {
      this.syncAppStorage();
      return;
    }

    try {
      this.prefs = await preferences.getPreferences(context, { name: PREF_NAME });
      const storedTheme = String(await this.prefs.get(KEY_STORED_THEME, ThemeMode.SYSTEM));
      this.themeMode = normalizeThemeMode(storedTheme);
      const storedFont = Number(await this.prefs.get(KEY_STORED_FONT_SIZE, FontSizePreset.STANDARD));
      this.fontSize = normalizeFontSize(storedFont);
    } catch (error) {
      this.prefs = null;
    }

    this.initialized = true;
    this.applyColorMode(context);
    this.syncAppStorage();
  }

  async setThemeMode(context: common.Context, mode: string): Promise<void> {
    this.themeMode = normalizeThemeMode(mode);
    this.applyColorMode(context);
    this.syncAppStorage();

    if (this.prefs !== null) {
      try {
        await this.prefs.put(KEY_STORED_THEME, this.themeMode);
        await this.prefs.flush();
      } catch (error) {
        // 内存中已生效，持久化失败不阻塞切换。
      }
    }
  }

  async setFontSize(size: number): Promise<void> {
    this.fontSize = normalizeFontSize(size);
    this.syncAppStorage();

    if (this.prefs !== null) {
      try {
        await this.prefs.put(KEY_STORED_FONT_SIZE, this.fontSize);
        await this.prefs.flush();
      } catch (error) {
        // 内存中已生效，持久化失败不阻塞切换。
      }
    }
  }

  onSystemColorModeChanged(colorMode: ConfigurationConstant.ColorMode | undefined): void {
    if (colorMode === undefined) {
      return;
    }
    this.systemIsDark = colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    if (this.themeMode === ThemeMode.SYSTEM) {
      this.syncAppStorage();
    }
  }

  getThemeMode(): string {
    return this.themeMode;
  }

  getFontSize(): number {
    return this.fontSize;
  }

  isDarkEffective(): boolean {
    if (this.themeMode === ThemeMode.DARK) {
      return true;
    }
    if (this.themeMode === ThemeMode.LIGHT) {
      return false;
    }
    return this.systemIsDark;
  }

  private applyColorMode(context: common.Context): void {
    try {
      const appContext = context.getApplicationContext();
      if (this.themeMode === ThemeMode.DARK) {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else if (this.themeMode === ThemeMode.LIGHT) {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      } else {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    } catch (error) {
      // 忽略异常上下文下的颜色模式设置失败。
    }
  }

  private syncAppStorage(): void {
    AppStorage.setOrCreate(KEY_THEME_MODE, this.themeMode);
    AppStorage.setOrCreate(KEY_FONT_SIZE, this.fontSize);
    AppStorage.setOrCreate(KEY_IS_DARK, this.isDarkEffective());
  }
}

function normalizeThemeMode(value: string): string {
  if (value === ThemeMode.LIGHT || value === ThemeMode.DARK || value === ThemeMode.SYSTEM) {
    return value;
  }
  return ThemeMode.SYSTEM;
}

function normalizeFontSize(value: number): number {
  if (
    value === FontSizePreset.SMALL ||
    value === FontSizePreset.STANDARD ||
    value === FontSizePreset.LARGE ||
    value === FontSizePreset.XLARGE
  ) {
    return value;
  }
  return FontSizePreset.STANDARD;
}
