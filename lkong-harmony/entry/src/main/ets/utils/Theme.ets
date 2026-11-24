/**
 * 集中式主题调色板与阅读偏好常量。
 * 页面和组件通过 @StorageProp(KEY_IS_DARK) / @StorageProp(KEY_FONT_SIZE) 响应系统深浅色与字号切换。
 */

export const KEY_THEME_MODE: string = 'lkong_theme_mode';
export const KEY_IS_DARK: string = 'lkong_is_dark';
export const KEY_FONT_SIZE: string = 'lkong_font_size';

export class ThemeMode {
  static readonly SYSTEM: string = 'system';
  static readonly LIGHT: string = 'light';
  static readonly DARK: string = 'dark';
}

export class FontSizePreset {
  static readonly SMALL: number = 13;
  static readonly STANDARD: number = 15;
  static readonly LARGE: number = 17;
  static readonly XLARGE: number = 19;
}

export interface ThemePalette {
  pageBg: string;
  cardBg: string;
  surfaceMuted: string;
  textPrimary: string;
  textSecondary: string;
  textMuted: string;
  accent: string;
  accentSolid: string;
  accentBg: string;
  divider: string;
  quoteBg: string;
  quoteBorder: string;
  codeBg: string;
  codeText: string;
  codeBlockBg: string;
  bannerBg: string;
  bannerText: string;
  bannerBtnBg: string;
  successBg: string;
  successText: string;
  dangerBg: string;
  dangerText: string;
  inputBg: string;
  disabledBtnBg: string;
  disabledBtnText: string;
  tabBarBg: string;
  highlightText: string;
  badgeBg: string;
}

const LIGHT_THEME: ThemePalette = {
  pageBg: '#F5F6F8',
  cardBg: '#FFFFFF',
  surfaceMuted: '#F2F4F7',
  textPrimary: '#222222',
  textSecondary: '#666666',
  textMuted: '#999999',
  accent: '#1A73E8',
  accentSolid: '#1A73E8',
  accentBg: '#E8F0FE',
  divider: '#E6E8EC',
  quoteBg: '#F8F9FA',
  quoteBorder: '#D0D7DE',
  codeBg: '#EFF1F5',
  codeText: '#C7254E',
  codeBlockBg: '#F6F8FA',
  bannerBg: '#FFF8E1',
  bannerText: '#8A6D3B',
  bannerBtnBg: '#FFF1C1',
  successBg: '#E8F5E9',
  successText: '#2E7D32',
  dangerBg: '#FDECEA',
  dangerText: '#C62828',
  inputBg: '#F5F6F8',
  disabledBtnBg: '#E5E8EE',
  disabledBtnText: '#9AA0A6',
  tabBarBg: '#FFFFFF',
  highlightText: '#D93025',
  badgeBg: '#D93025'
};

const DARK_THEME: ThemePalette = {
  pageBg: '#121212',
  cardBg: '#1E1F24',
  surfaceMuted: '#282A30',
  textPrimary: '#E8EAED',
  textSecondary: '#B0B5BD',
  textMuted: '#7E848E',
  accent: '#64A8FF',
  accentSolid: '#1A73E8',
  accentBg: '#1E3148',
  divider: '#2E3138',
  quoteBg: '#25272E',
  quoteBorder: '#434854',
  codeBg: '#2B2E36',
  codeText: '#FF8A80',
  codeBlockBg: '#23262D',
  bannerBg: '#332B14',
  bannerText: '#FFD56B',
  bannerBtnBg: '#4A3C18',
  successBg: '#1B3320',
  successText: '#81C784',
  dangerBg: '#3B1E1E',
  dangerText: '#EF9A9A',
  inputBg: '#262830',
  disabledBtnBg: '#2A2C33',
  disabledBtnText: '#6F7580',
  tabBarBg: '#1A1B20',
  highlightText: '#FF7B72',
  badgeBg: '#E53935'
};

export function getTheme(isDark: boolean): ThemePalette {
  return isDark ? DARK_THEME : LIGHT_THEME;
}

export function themeModeLabel(mode: string): string {
  if (mode === ThemeMode.LIGHT) {
    return '浅色';
  }
  if (mode === ThemeMode.DARK) {
    return '深色';
  }
  return '跟随系统';
}

export function fontSizeLabel(size: number): string {
  if (size <= FontSizePreset.SMALL) {
    return '小';
  }
  if (size === FontSizePreset.STANDARD) {
    return '标准';
  }
  if (size === FontSizePreset.LARGE) {
    return '大';
  }
  return '特大';
}
