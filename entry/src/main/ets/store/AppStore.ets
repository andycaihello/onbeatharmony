/**
 * 全局状态管理
 */
import { UserModel } from '../models/Models';
import { httpClient } from '../api/HttpClient';

// 认证状态管理
export class AuthStore {
  private static user: UserModel | null = null;
  private static isAuthenticatedFlag: boolean = false;

  // 获取当前用户
  static getUser(): UserModel | null {
    return AuthStore.user;
  }

  // 设置用户
  static setUser(user: UserModel): void {
    AuthStore.user = user;
    AuthStore.isAuthenticatedFlag = true;
  }

  // 清除用户
  static clearUser(): void {
    AuthStore.user = null;
    AuthStore.isAuthenticatedFlag = false;
    httpClient.clearTokens();
  }

  // 检查是否已登录
  static isAuthenticated(): boolean {
    return AuthStore.isAuthenticatedFlag;
  }

  // 登录
  static login(user: UserModel, accessToken: string, refreshToken: string): void {
    httpClient.setTokens(accessToken, refreshToken);
    AuthStore.setUser(user);
  }

  // 登出
  static logout(): void {
    AuthStore.clearUser();
  }
}

// 消息状态管理
export class MessageStore {
  private static unreadCount: number = 0;

  // 获取未读消息数
  static getUnreadCount(): number {
    return MessageStore.unreadCount;
  }

  // 设置未读消息数
  static setUnreadCount(count: number): void {
    MessageStore.unreadCount = count;
  }

  // 增加未读消息数
  static incrementUnreadCount(): void {
    MessageStore.unreadCount++;
  }

  // 减少未读消息数
  static decrementUnreadCount(count: number): void {
    MessageStore.unreadCount = Math.max(0, MessageStore.unreadCount - count);
  }

  // 清除未读消息数
  static clearUnreadCount(): void {
    MessageStore.unreadCount = 0;
  }
}

// 播放器状态管理
export class PlayerStore {
  private static currentSong: Object | null = null;
  private static isPlayingFlag: boolean = false;

  // 获取当前播放歌曲
  static getCurrentSong(): Object | null {
    return PlayerStore.currentSong;
  }

  // 设置当前播放歌曲
  static setCurrentSong(song: Object | null): void {
    PlayerStore.currentSong = song;
  }

  // 获取播放状态
  static isPlaying(): boolean {
    return PlayerStore.isPlayingFlag;
  }

  // 设置播放状态
  static setIsPlaying(playing: boolean): void {
    PlayerStore.isPlayingFlag = playing;
  }
}

// UI 状态管理
export class UIStore {
  private static loading: boolean = false;
  private static errorMessage: string | null = null;

  // 获取加载状态
  static isLoading(): boolean {
    return UIStore.loading;
  }

  // 设置加载状态
  static setLoading(loading: boolean): void {
    UIStore.loading = loading;
  }

  // 获取错误消息
  static getErrorMessage(): string | null {
    return UIStore.errorMessage;
  }

  // 设置错误消息
  static setErrorMessage(message: string | null): void {
    UIStore.errorMessage = message;
  }

  // 清除错误消息
  static clearErrorMessage(): void {
    UIStore.errorMessage = null;
  }
}
