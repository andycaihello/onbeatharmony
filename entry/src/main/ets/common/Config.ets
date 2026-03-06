/**
 * 应用配置
 */
export class Config {
  // API 基础 URL
  static readonly BASE_URL: string = 'https://app.onbeat.com.cn/api';

  // 静态资源 URL（用于加载上传的图片）
  static readonly STATIC_URL: string = 'https://app.onbeat.com.cn';

  // 超时时间（毫秒）
  static readonly TIMEOUT: number = 30000;

  // Token 存储 Key
  static readonly ACCESS_TOKEN_KEY: string = 'access_token';
  static readonly REFRESH_TOKEN_KEY: string = 'refresh_token';
  static readonly USER_INFO_KEY: string = 'user_info';
}
