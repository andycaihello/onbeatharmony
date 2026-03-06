/**
 * 数据模型定义 - ArkTS 兼容版
 */

// 用户模型
export class UserModel {
  id: number = 0;
  username: string = '';
  email: string = '';
  nickname: string = '';
  phone: string = '';
  bio: string = '';
  avatar_url: string = '';
  followers_count: number = 0;
  following_count: number = 0;
  created_at: string = '';
}

// 歌手模型
export class ArtistModel {
  id: number = 0;
  name: string = '';
  genre: string = '';
  country: string = '';
  bio: string = '';
  avatar_url: string = '';
}

// 歌曲模型
export class SongModel {
  id: number = 0;
  title: string = '';
  artist: ArtistModel = new ArtistModel();
  duration: number = 0;
  cover_url: string = '';
  play_count: number = 0;
  like_count: number = 0;
  comment_count: number = 0;
  external_url: string = '';
  netease_id: number = 0;
}

// 评论模型
export class CommentModel {
  id: number = 0;
  content: string = '';
  user: UserModel = new UserModel();
  song_id: number = 0;
  parent_id: number = 0;
  like_count: number = 0;
  replies: CommentModel[] = [];
  created_at: string = '';
}

// 歌曲分享信息（私信中嵌入的歌曲卡片数据）
export class SongShareInfo {
  id: number = 0;
  title: string = '';
  artist_name: string = '';
  cover_url: string = '';
  netease_id: number = 0;
  external_url: string = '';
}

// 消息模型
export class MessageModel {
  id: number = 0;
  sender_id: number = 0;
  receiver_id: number = 0;
  sender: UserModel = new UserModel();
  content: string = '';
  is_read: boolean = false;
  created_at: string = '';
  // 客户端解析字段（不来自服务端）
  msg_type: string = 'text'; // 'text' | 'song_share'
  song_share: SongShareInfo = new SongShareInfo();
}

// 会话模型
export class ConversationModel {
  user: UserModel = new UserModel();
  last_message: MessageModel = new MessageModel();
  unread_count: number = 0;
}
