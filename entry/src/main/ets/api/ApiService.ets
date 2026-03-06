/**
 * API 服务层 - ArkTS 兼容版
 */
import { HttpClient } from './HttpClient';
import { UserModel, SongModel, ArtistModel, ConversationModel, CommentModel, MessageModel } from '../models/Models';

// 登录响应类
export class LoginResponse {
  user: UserModel = new UserModel();
  access_token: string = '';
  refresh_token: string = '';
}

// 用户响应类
export class UserResponse {
  user: UserModel = new UserModel();
}

// 歌曲列表响应类
export class SongsResponse {
  songs: SongModel[] = [];
}

// 歌手列表响应类
export class ArtistsResponse {
  artists: ArtistModel[] = [];
}

// 歌曲详情响应类
export class SongDetailResponse {
  song: SongModel = new SongModel();
}

// 空响应类
export class EmptyResponse {}

// 未读消息数响应类
export class UnreadCountResponse {
  count: number = 0;
}

// 认证 API
export class AuthAPI {
  static async login(identifier: string, password: string): Promise<LoginResponse> {
    const jsonData = '{"identifier":"' + identifier + '","password":"' + password + '"}';
    const client = HttpClient.getInstance();
    return await client.post<LoginResponse>('/auth/login', jsonData);
  }

  static async register(username: string, email: string, password: string): Promise<LoginResponse> {
    const jsonData = '{"username":"' + username + '","email":"' + email + '","password":"' + password + '"}';
    const client = HttpClient.getInstance();
    return await client.post<LoginResponse>('/auth/register', jsonData);
  }

  static async logout(): Promise<void> {
    const client = HttpClient.getInstance();
    await client.post<EmptyResponse>('/auth/logout', '{}');
  }

  static async getCurrentUser(): Promise<UserResponse> {
    const client = HttpClient.getInstance();
    return await client.get<UserResponse>('/auth/me');
  }
}

// 头像上传响应类
export class AvatarUploadResponse {
  avatar_url: string = '';
  message: string = '';
}

// 用户 API
export class UserAPI {
  static async getProfile(userId: number): Promise<UserResponse> {
    const client = HttpClient.getInstance();
    return await client.get<UserResponse>('/users/' + userId.toString());
  }

  static async uploadAvatar(fileBuffer: ArrayBuffer): Promise<AvatarUploadResponse> {
    const client = HttpClient.getInstance();
    return await client.postMultipart<AvatarUploadResponse>(
      '/users/me/avatar', 'avatar', 'avatar.jpg', fileBuffer, 'image/jpeg'
    );
  }
}

// 社交 API
export class SocialAPI {
  static async followUser(userId: number): Promise<void> {
    const client = HttpClient.getInstance();
    await client.post<EmptyResponse>('/social/follow/' + userId.toString(), '{}');
  }

  static async unfollowUser(userId: number): Promise<void> {
    const client = HttpClient.getInstance();
    await client.delete<EmptyResponse>('/social/follow/' + userId.toString());
  }

  static async getFollowers(userId: number): Promise<FollowersResponse> {
    const client = HttpClient.getInstance();
    return await client.get<FollowersResponse>('/social/followers/' + userId.toString());
  }

  static async getFollowing(userId: number): Promise<FollowingResponse> {
    const client = HttpClient.getInstance();
    return await client.get<FollowingResponse>('/social/following/' + userId.toString());
  }

  static async isFollowing(userId: number): Promise<FollowStatusResponse> {
    const client = HttpClient.getInstance();
    return await client.get<FollowStatusResponse>('/social/is-following/' + userId.toString());
  }
}

// 粉丝列表响应类
export class FollowersResponse {
  followers: UserModel[] = [];
  total: number = 0;
}

// 关注列表响应类
export class FollowingResponse {
  following: UserModel[] = [];
  total: number = 0;
}

// 关注状态响应类
export class FollowStatusResponse {
  is_following: boolean = false;
}

// 会话消息响应类
export class ConversationMessagesResponse {
  messages: MessageModel[] = [];
}

// 搜索响应类
export class SearchResponse {
  songs: SongModel[] = [];
  artists: ArtistModel[] = [];
  songs_total: number = 0;
  artists_total: number = 0;
  total: number = 0;
}

// 用户搜索响应类
export class UserSearchResponse {
  users: UserModel[] = [];
  total: number = 0;
}

// 音乐 API
export class MusicAPI {
  static async getTrendingSongs(): Promise<SongsResponse> {
    const client = HttpClient.getInstance();
    return await client.get<SongsResponse>('/songs/trending');
  }

  static async getLatestSongs(): Promise<SongsResponse> {
    const client = HttpClient.getInstance();
    return await client.get<SongsResponse>('/songs/latest');
  }

  static async getArtists(): Promise<ArtistsResponse> {
    const client = HttpClient.getInstance();
    return await client.get<ArtistsResponse>('/artists');
  }

  static async getArtistSongs(artistId: number): Promise<SongsResponse> {
    const client = HttpClient.getInstance();
    return await client.get<SongsResponse>('/artists/' + artistId.toString() + '/songs');
  }

  static async getSongDetail(songId: number): Promise<SongDetailResponse> {
    const client = HttpClient.getInstance();
    return await client.get<SongDetailResponse>('/songs/' + songId.toString());
  }

  static async search(query: string, type: string = 'all'): Promise<SearchResponse> {
    const client = HttpClient.getInstance();
    return await client.get<SearchResponse>('/search?q=' + encodeURIComponent(query) + '&type=' + type);
  }
}

// 用户搜索 API（扩展 UserAPI）
export class SearchUserAPI {
  static async searchUsers(query: string): Promise<UserSearchResponse> {
    const client = HttpClient.getInstance();
    return await client.get<UserSearchResponse>('/users/search?q=' + encodeURIComponent(query));
  }
}

// Feed API
export class FeedAPI {
  static async getFriendsActivity(): Promise<ActivitiesResponse> {
    const client = HttpClient.getInstance();
    return await client.get<ActivitiesResponse>('/feed/friends-activity');
  }
}

// 活动响应类
export class ActivitiesResponse {
  activities: ActivityModel[] = [];
}

// 活动模型
export class ActivityModel {
  id: number = 0;
  user: UserModel = new UserModel();
  song: SongModel = new SongModel();
  action_type: string = '';
  created_at: string = '';
}

// 点赞状态响应类
export class LikeStatusResponse {
  is_liked: boolean = false;
}

// 评论响应类
export class CommentsResponse {
  comments: CommentModel[] = [];
  total: number = 0;
}

// 网易云 URL 条目
export class NeteaseUrlItem {
  id: number = 0;
  url: string = '';
}

// 网易云 URL 响应
export class NeteaseUrlResponse {
  data: NeteaseUrlItem[] = [];
  code: number = 0;
}

// 互动 API
export class InteractionAPI {
  static async playSong(songId: number): Promise<void> {
    const client = HttpClient.getInstance();
    await client.post<EmptyResponse>('/songs/' + songId.toString() + '/play', '{}');
  }

  static async likeSong(songId: number): Promise<void> {
    const client = HttpClient.getInstance();
    await client.post<EmptyResponse>('/songs/' + songId.toString() + '/like', '{}');
  }

  static async unlikeSong(songId: number): Promise<void> {
    const client = HttpClient.getInstance();
    await client.delete<EmptyResponse>('/songs/' + songId.toString() + '/like');
  }

  static async getLikeStatus(songId: number): Promise<LikeStatusResponse> {
    const client = HttpClient.getInstance();
    return await client.get<LikeStatusResponse>('/songs/' + songId.toString() + '/like/status');
  }

  static async getComments(songId: number): Promise<CommentsResponse> {
    const client = HttpClient.getInstance();
    return await client.get<CommentsResponse>('/songs/' + songId.toString() + '/comments');
  }

  static async addComment(songId: number, content: string, parentId: number = 0): Promise<void> {
    const escaped = content.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
    let jsonData: string;
    if (parentId > 0) {
      jsonData = '{"content":"' + escaped + '","parent_id":' + parentId.toString() + '}';
    } else {
      jsonData = '{"content":"' + escaped + '"}';
    }
    const client = HttpClient.getInstance();
    await client.post<EmptyResponse>('/songs/' + songId.toString() + '/comments', jsonData);
  }

  static async likeComment(commentId: number): Promise<void> {
    const client = HttpClient.getInstance();
    await client.post<EmptyResponse>('/comments/' + commentId.toString() + '/like', '{}');
  }

  static async unlikeComment(commentId: number): Promise<void> {
    const client = HttpClient.getInstance();
    await client.delete<EmptyResponse>('/comments/' + commentId.toString() + '/like');
  }
}

// 网易云 API
export class NeteaseAPI {
  static async getSongUrl(neteaseId: number): Promise<NeteaseUrlResponse> {
    const client = HttpClient.getInstance();
    return await client.get<NeteaseUrlResponse>('/netease/song/' + neteaseId.toString() + '/url');
  }
}

// 消息 API
export class MessageAPI {
  static async sendMessage(receiverId: number, content: string): Promise<void> {
    const jsonData = '{"receiver_id":' + receiverId.toString() + ',"content":"' + content.replace(/"/g, '\\"') + '"}';
    const client = HttpClient.getInstance();
    await client.post<EmptyResponse>('/messages', jsonData);
  }

  static async sendSongShare(receiverId: number, song: SongModel): Promise<void> {
    // Escape field values for JSON string embedding (\ → \\, " → \")
    const title = song.title.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
    const artistName = (song.artist?.name || '').replace(/\\/g, '\\\\').replace(/"/g, '\\"');
    const coverUrl = (song.cover_url || '').replace(/\\/g, '\\\\').replace(/"/g, '\\"');
    const externalUrl = (song.external_url || '').replace(/\\/g, '\\\\').replace(/"/g, '\\"');
    // Build inner JSON (valid JSON)
    const innerJson = '{"type":"song_share","song":{"id":' + song.id.toString() +
      ',"title":"' + title + '","artist_name":"' + artistName +
      '","cover_url":"' + coverUrl + '","netease_id":' + (song.netease_id || 0).toString() +
      ',"external_url":"' + externalUrl + '"}}';
    // Double-escape for embedding as a JSON string value in outer JSON
    const escaped = innerJson.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
    const jsonData = '{"receiver_id":' + receiverId.toString() + ',"content":"' + escaped + '"}';
    const client = HttpClient.getInstance();
    await client.post<EmptyResponse>('/messages', jsonData);
  }

  static async getConversations(): Promise<ConversationModel[]> {
    const client = HttpClient.getInstance();
    return await client.get<ConversationModel[]>('/messages/conversations');
  }

  static async getConversation(userId: number): Promise<ConversationMessagesResponse> {
    const client = HttpClient.getInstance();
    return await client.get<ConversationMessagesResponse>('/messages/conversation/' + userId.toString());
  }

  static async markConversationAsRead(userId: number): Promise<void> {
    const client = HttpClient.getInstance();
    await client.put<EmptyResponse>('/messages/conversation/' + userId.toString() + '/read');
  }

  static async getUnreadCount(): Promise<UnreadCountResponse> {
    const client = HttpClient.getInstance();
    return await client.get<UnreadCountResponse>('/messages/unread-count');
  }
}
