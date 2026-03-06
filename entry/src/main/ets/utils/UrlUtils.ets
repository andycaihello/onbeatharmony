/**
 * URL 工具类
 */
import { Config } from '../common/Config';

export class UrlUtils {
  /**
   * 获取完整的资源 URL
   */
  static getFullUrl(path: string | undefined | null): string | null {
    if (!path) {
      return null;
    }

    // 如果已经是完整的 URL，直接返回
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    // 获取 API URL 并移除 /api 后缀
    const apiUrl = Config.BASE_URL;
    const baseUrl = apiUrl.replace('/api', '');

    // 拼接完整 URL
    return `${baseUrl}${path}`;
  }

  /**
   * 获取头像 URL，无头像时返回空字符串（由 AvatarImage 组件负责显示占位）
   */
  static getAvatarUrl(avatarUrl: string | undefined | null): string {
    const fullUrl = UrlUtils.getFullUrl(avatarUrl);
    return fullUrl || '';
  }

  /**
   * 获取封面图 URL
   */
  static getCoverUrl(coverUrl: string | undefined | null): string {
    const fullUrl = UrlUtils.getFullUrl(coverUrl);
    return fullUrl || '';
  }

  /**
   * 获取 WebSocket URL（Socket.IO EIO4 协议）
   */
  static getWebSocketUrl(): string {
    const baseUrl = Config.BASE_URL;
    const socketPath = '/socket.io/?EIO=4&transport=websocket';
    // 将 http:// 或 https:// 替换为 ws:// 或 wss://，并移除 /api 后缀
    if (baseUrl.startsWith('https://')) {
      return baseUrl.replace('/api', '').replace('https://', 'wss://') + socketPath;
    } else if (baseUrl.startsWith('http://')) {
      return baseUrl.replace('/api', '').replace('http://', 'ws://') + socketPath;
    }
    // 默认使用开发环境地址
    return 'ws://10.0.2.15:5001' + socketPath;
  }
}
