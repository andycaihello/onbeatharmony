/**
 * WebSocket 服务 - 实时消息监听（Socket.IO EIO4 协议）
 */
import webSocket from '@ohos.net.webSocket';
import { AuthStore, MessageStore } from '../store/AppStore';
import { UrlUtils } from '../utils/UrlUtils';
import { MessageAPI, UnreadCountResponse } from '../api/ApiService';
import { httpClient } from '../api/HttpClient';

export type MessageCallback = (message: object) => void;
export type UnreadCountCallback = (count: number) => void;

export class WebSocketService {
  private static instance: WebSocketService | null = null;
  private socket: webSocket.WebSocket | null = null;
  private isConnected: boolean = false;
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = 5;
  private reconnectDelay: number = 1000;
  private messageCallbacks: MessageCallback[] = [];
  private unreadCountCallbacks: UnreadCountCallback[] = [];
  private reconnectTimer: number = -1;

  private constructor() {}

  static getInstance(): WebSocketService {
    if (!WebSocketService.instance) {
      WebSocketService.instance = new WebSocketService();
    }
    return WebSocketService.instance;
  }

  // 添加消息回调
  addMessageCallback(callback: MessageCallback): void {
    this.messageCallbacks.push(callback);
  }

  // 移除消息回调
  removeMessageCallback(callback: MessageCallback): void {
    const index = this.messageCallbacks.indexOf(callback);
    if (index > -1) {
      this.messageCallbacks.splice(index, 1);
    }
  }

  // 添加未读数回调
  addUnreadCountCallback(callback: UnreadCountCallback): void {
    this.unreadCountCallbacks.push(callback);
  }

  // 移除未读数回调
  removeUnreadCountCallback(callback: UnreadCountCallback): void {
    const index = this.unreadCountCallbacks.indexOf(callback);
    if (index > -1) {
      this.unreadCountCallbacks.splice(index, 1);
    }
  }

  // 连接WebSocket
  async connect(): Promise<void> {
    if (this.isConnected || !AuthStore.isAuthenticated()) {
      return;
    }

    // 如果已有 socket 在尝试连接，先清理
    if (this.socket) {
      try {
        this.socket.close();
      } catch (_e) {}
      this.socket = null;
    }

    try {
      const wsUrl = UrlUtils.getWebSocketUrl();
      console.info('[WebSocket] Connecting to: ' + wsUrl);

      this.socket = webSocket.createWebSocket();

      // 监听连接打开事件
      this.socket.on('open', (_err, _value) => {
        console.info('[WebSocket] TCP connection opened, waiting for EIO handshake');
        // 不在此处设置 isConnected，等待 Socket.IO 握手完成
      });

      // 监听消息事件
      this.socket.on('message', (err, value) => {
        if (err) {
          console.error('[WebSocket] Message error');
          return;
        }
        this.handleMessage(value as string);
      });

      // 监听关闭事件
      this.socket.on('close', (_err, _value) => {
        console.info('[WebSocket] Connection closed');
        this.isConnected = false;
        this.handleReconnect();
      });

      // 监听错误事件
      this.socket.on('error', (_err) => {
        console.error('[WebSocket] Error occurred');
        this.isConnected = false;
        this.handleReconnect();
      });

      // 连接到服务器
      await this.socket.connect(wsUrl, {
        header: {}
      });

    } catch (error) {
      console.error('[WebSocket] Connect error: ' + (error as Error).message);
      this.handleReconnect();
    }
  }

  // 处理收到的消息（Socket.IO EIO4 协议）
  private handleMessage(data: string): void {
    if (!data || data.length === 0) {
      return;
    }

    console.info('[WebSocket] Received: ' + data);

    // Engine.IO OPEN 包：格式 0{...} - 连接建立，发送 Socket.IO CONNECT 认证
    if (data.charAt(0) === '0') {
      const token = httpClient.getAccessToken();
      this.sendRaw('40{"token":"' + token + '"}');
      return;
    }

    // Engine.IO PING 包：格式 2 - 响应 PONG
    if (data === '2') {
      this.sendRaw('3');
      return;
    }

    // Socket.IO CONNECT ACK：格式 40 或 40{...}
    if (data.startsWith('40')) {
      console.info('[WebSocket] Socket.IO namespace connected');
      this.isConnected = true;
      this.reconnectAttempts = 0;
      return;
    }

    // Socket.IO CONNECT ERROR：格式 44{...}
    if (data.startsWith('44')) {
      console.error('[WebSocket] Socket.IO connect error: ' + data.substring(2));
      return;
    }

    // Socket.IO EVENT：格式 42["event_name", {...data}]
    if (data.startsWith('42')) {
      this.parseSocketIOEvent(data);
      return;
    }
  }

  // 解析 Socket.IO 事件包
  private parseSocketIOEvent(data: string): void {
    // 去掉 "42" 前缀，剩余格式为 ["event_name", {...}]
    const payload = data.substring(2);

    // 提取事件名（第一个引号对之间的内容）
    const firstQuote = payload.indexOf('"');
    const secondQuote = payload.indexOf('"', firstQuote + 1);
    if (firstQuote < 0 || secondQuote <= firstQuote) {
      return;
    }
    const eventName = payload.substring(firstQuote + 1, secondQuote);

    if (eventName === 'new_message') {
      // 提取数据部分（事件名后面的逗号到最后一个 ] 之间）
      const commaIdx = payload.indexOf(',', secondQuote);
      const dataEnd = payload.lastIndexOf(']');
      if (commaIdx < 0 || dataEnd <= commaIdx) {
        return;
      }
      const dataStr = payload.substring(commaIdx + 1, dataEnd).trim();
      try {
        const msgData: Record<string, Object> = JSON.parse(dataStr) as Record<string, Object>;
        console.info('[WebSocket] New message received');
        // 通知所有回调
        for (const callback of this.messageCallbacks) {
          callback(msgData);
        }
        // 更新未读数
        this.refreshUnreadCount();
      } catch (error) {
        console.error('[WebSocket] Parse event data error: ' + (error as Error).message);
      }
    } else if (eventName === 'connected') {
      console.info('[WebSocket] Authenticated by server');
    }
  }

  // 发送原始字符串（用于 Socket.IO 协议握手）
  private sendRaw(data: string): void {
    if (!this.socket) {
      return;
    }
    try {
      this.socket.send(data);
    } catch (error) {
      console.error('[WebSocket] Send raw error: ' + (error as Error).message);
    }
  }

  // 刷新未读消息数
  private async refreshUnreadCount(): Promise<void> {
    try {
      const res: UnreadCountResponse = await MessageAPI.getUnreadCount();
      MessageStore.setUnreadCount(res.count);
      for (const callback of this.unreadCountCallbacks) {
        callback(res.count);
      }
    } catch (error) {
      console.error('[WebSocket] Refresh unread error: ' + (error as Error).message);
    }
  }

  // 处理重连
  private handleReconnect(): void {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('[WebSocket] Max reconnect attempts reached');
      return;
    }

    if (this.reconnectTimer !== -1) {
      return;
    }

    this.reconnectAttempts++;
    console.info('[WebSocket] Reconnecting (attempt ' + this.reconnectAttempts + ')...');

    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = -1;
      this.connect();
    }, this.reconnectDelay * this.reconnectAttempts);
  }

  // 断开连接
  disconnect(): void {
    if (this.reconnectTimer !== -1) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = -1;
    }
    if (this.socket) {
      try {
        this.socket.close();
      } catch (_e) {}
      this.socket = null;
    }
    this.isConnected = false;
    this.reconnectAttempts = 0;
    console.info('[WebSocket] Disconnected');
  }

  // 检查是否已连接
  isActive(): boolean {
    return this.isConnected;
  }

  // 发送应用层消息
  send(data: object): boolean {
    if (!this.isConnected || !this.socket) {
      return false;
    }
    try {
      this.socket.send(JSON.stringify(data));
      return true;
    } catch (error) {
      console.error('[WebSocket] Send error: ' + (error as Error).message);
      return false;
    }
  }
}
