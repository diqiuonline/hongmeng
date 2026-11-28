export class AppConfig {
  static readonly APP_NAME: string = 'AI 对话助手';
  static readonly APP_VERSION: string = '1.2.0';
  static readonly BASE_URL: string = 'https://chat.deepseek.com';
  static readonly SIGN_IN_URL: string = 'https://chat.deepseek.com/sign_in';
  static readonly CLIENT_PLATFORM: string = 'web';
  static readonly CLIENT_VERSION: string = '1.6.1';
  static readonly APP_HEADER_VERSION: string = '20241129.1';
  static readonly USER_AGENT: string =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
  static readonly DISCLAIMER: string =
    '本应用为非官方第三方 AI 对话客户端，直连第三方 AI 服务网页端接口，仅用于个人学习与本地测试，不对外分发。';
  static readonly SECURITY_NOTICE: string =
    '登录凭证（userToken 与 Cookie）仅保存在本机沙箱，不写入日志，不发送到任何第三方服务器。账号密码仅用于登录接口，不在本地保存。';
}