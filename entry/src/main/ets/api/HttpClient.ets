/**
 * HTTP 客户端封装 - ArkTS 兼容版
 */
import http from '@ohos.net.http';
import util from '@ohos.util';
import { Config } from '../common/Config';

// Token 存储类
class TokenStorage {
  private accessToken: string = '';
  private refreshToken: string = '';

  setAccessToken(token: string): void {
    this.accessToken = token;
  }

  getAccessToken(): string {
    return this.accessToken;
  }

  setRefreshToken(token: string): void {
    this.refreshToken = token;
  }

  clear(): void {
    this.accessToken = '';
    this.refreshToken = '';
  }
}

// 空响应类
class EmptyResponseData {}

export class HttpClient {
  private static instance: HttpClient;
  private baseUrl: string = Config.BASE_URL;
  private timeout: number = Config.TIMEOUT;
  private tokenStorage: TokenStorage = new TokenStorage();

  private constructor() {}

  static getInstance(): HttpClient {
    if (!HttpClient.instance) {
      HttpClient.instance = new HttpClient();
    }
    return HttpClient.instance;
  }

  private getToken(): string {
    return this.tokenStorage.getAccessToken();
  }

  setTokens(accessToken: string, refreshToken: string): void {
    this.tokenStorage.setAccessToken(accessToken);
    this.tokenStorage.setRefreshToken(refreshToken);
  }

  clearTokens(): void {
    this.tokenStorage.clear();
  }

  isAuthenticated(): boolean {
    return this.getToken().length > 0;
  }

  getAccessToken(): string {
    return this.tokenStorage.getAccessToken();
  }

  private buildHeaders(): Record<string, string> {
    const headers: Record<string, string> = {};
    headers['Accept'] = 'application/json';
    headers['Content-Type'] = 'application/json';

    const token = this.getToken();
    if (token.length > 0) {
      headers['Authorization'] = 'Bearer ' + token;
    }
    return headers;
  }

  async get<T>(endpoint: string): Promise<T> {
    const url = this.baseUrl + endpoint;
    const httpRequest = http.createHttp();
    const headers = this.buildHeaders();

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: this.timeout,
        readTimeout: this.timeout
      });

      const code = response.responseCode;
      const result = response.result as string;

      if (code === 200 || code === 201) {
        const data: T = JSON.parse(result) as T;
        return data;
      } else if (code === 401) {
        this.clearTokens();
        throw new Error('登录已过期，请重新登录');
      } else {
        throw new Error('请求失败');
      }
    } finally {
      httpRequest.destroy();
    }
  }

  async post<T>(endpoint: string, jsonData: string): Promise<T> {
    const url = this.baseUrl + endpoint;
    const httpRequest = http.createHttp();
    const headers = this.buildHeaders();

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: jsonData,
        connectTimeout: this.timeout,
        readTimeout: this.timeout
      });

      const code = response.responseCode;
      const result = response.result as string;

      if (code === 200 || code === 201) {
        const data: T = JSON.parse(result) as T;
        return data;
      } else if (code === 401) {
        this.clearTokens();
        throw new Error('登录已过期，请重新登录');
      } else {
        throw new Error('请求失败');
      }
    } finally {
      httpRequest.destroy();
    }
  }

  async put<T>(endpoint: string): Promise<T> {
    const url = this.baseUrl + endpoint;
    const httpRequest = http.createHttp();
    const headers = this.buildHeaders();

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.PUT,
        header: headers,
        connectTimeout: this.timeout,
        readTimeout: this.timeout
      });

      const code = response.responseCode;
      const result = response.result as string;

      if (code === 200 || code === 201) {
        const data: T = JSON.parse(result) as T;
        return data;
      } else if (code === 401) {
        this.clearTokens();
        throw new Error('登录已过期，请重新登录');
      } else {
        throw new Error('请求失败');
      }
    } finally {
      httpRequest.destroy();
    }
  }

  async postMultipart<T>(
    endpoint: string,
    fieldName: string,
    fileName: string,
    fileData: ArrayBuffer,
    mimeType: string
  ): Promise<T> {
    const url = this.baseUrl + endpoint;
    const httpRequest = http.createHttp();
    const headers = this.buildHeaders();

    const boundary = 'boundary' + Date.now().toString();
    headers['Content-Type'] = 'multipart/form-data; boundary=' + boundary;

    const encoder = new util.TextEncoder();
    const preamble =
      '--' + boundary + '\r\n' +
      'Content-Disposition: form-data; name="' + fieldName + '"; filename="' + fileName + '"\r\n' +
      'Content-Type: ' + mimeType + '\r\n\r\n';
    const epilogue = '\r\n--' + boundary + '--\r\n';

    const preambleBytes = encoder.encode(preamble);
    const epilogueBytes = encoder.encode(epilogue);

    const totalLength = preambleBytes.byteLength + fileData.byteLength + epilogueBytes.byteLength;
    const body = new ArrayBuffer(totalLength);
    const view = new Uint8Array(body);
    view.set(preambleBytes, 0);
    view.set(new Uint8Array(fileData), preambleBytes.byteLength);
    view.set(epilogueBytes, preambleBytes.byteLength + fileData.byteLength);

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: body,
        connectTimeout: this.timeout,
        readTimeout: this.timeout
      });

      const code = response.responseCode;
      const result = response.result as string;

      if (code === 200 || code === 201) {
        const data: T = JSON.parse(result) as T;
        return data;
      } else if (code === 401) {
        this.clearTokens();
        throw new Error('登录已过期，请重新登录');
      } else {
        throw new Error('请求失败');
      }
    } finally {
      httpRequest.destroy();
    }
  }

  async delete<T>(endpoint: string): Promise<T> {
    const url = this.baseUrl + endpoint;
    const httpRequest = http.createHttp();
    const headers = this.buildHeaders();

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.DELETE,
        header: headers,
        connectTimeout: this.timeout,
        readTimeout: this.timeout
      });

      const code = response.responseCode;
      const result = response.result as string;

      if (code === 200 || code === 204) {
        if (result && result.length > 0) {
          const data: T = JSON.parse(result) as T;
          return data;
        }
        // 返回空响应类型的实例
        const empty = new EmptyResponseData();
        const data: T = empty as T;
        return data;
      } else if (code === 401) {
        this.clearTokens();
        throw new Error('登录已过期，请重新登录');
      } else {
        throw new Error('请求失败');
      }
    } finally {
      httpRequest.destroy();
    }
  }
}

export const httpClient = HttpClient.getInstance();
