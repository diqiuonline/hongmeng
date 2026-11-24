export const KEY_THREAD_REFRESH_SEQ: string = 'lkong_thread_refresh_seq';
export const KEY_THREAD_REFRESH_TID: string = 'lkong_thread_refresh_tid';
export const KEY_THREAD_REFRESH_PID: string = 'lkong_thread_refresh_pid';
export const KEY_THREAD_REFRESH_LOU: string = 'lkong_thread_refresh_lou';
export const KEY_FORUM_REFRESH_FID: string = 'lkong_forum_refresh_fid';
export const KEY_NOTICE_COUNT_DIRTY: string = 'lkong_notice_count_dirty';

export class AppConfig {
  static readonly APP_NAME: string = '龙空客户端';
  static readonly APP_VERSION: string = '1.3.0';
  static readonly API_URL: string = 'https://api.lkong.com/api';
  static readonly UPLOAD_URL: string = 'https://images.lkong.com/upload';
  static readonly DISCLAIMER: string =
    '本应用为非官方第三方客户端，仅用于个人学习与本地测试，不对外分发。';
  static readonly COOKIE_NOTICE: string =
    '登录态以 Cookie 形式仅保存在本机。请勿把 Cookie 分享给他人。';
}