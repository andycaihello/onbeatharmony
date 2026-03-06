# Onbeat · 合拍

一款基于 HarmonyOS（ArkTS）开发的社交音乐应用，让你与好友分享音乐、发现新歌、实时交流。

## 功能特性

### 音乐
- 热门歌曲榜单、最新歌曲列表
- 歌手列表与展开歌手歌曲
- 歌曲详情页：封面、歌手、播放/点赞/评论/分享统计
- 在线播放（优先网易云音源，fallback 外链）
- 播放进度条、暂停/继续、关闭播放器

### 社交
- 用户注册 / 登录 / 退出
- 个人主页：头像上传、粉丝 & 关注数
- 关注 / 取关用户
- 好友动态：查看关注的人最近在听什么
- 搜索歌曲、歌手、用户

### 评论
- 多级评论（评论 + 回复）
- 折叠 / 展开回复列表
- 评论点赞

### 私信
- 会话列表 & 实时聊天（WebSocket）
- 歌曲分享：将歌曲以卡片形式发送到私信，支持直接点击播放

## 技术栈

| 层级 | 技术 |
|------|------|
| 语言 | ArkTS（严格模式） |
| UI 框架 | ArkUI（声明式） |
| 网络 | `@ohos.net.http` 自封装 HttpClient |
| 实时通信 | `@ohos.net.webSocket`（Socket.IO EIO4 协议） |
| 音频播放 | `@ohos.multimedia.media` AVPlayer |
| 状态管理 | `@State` + 静态 Store 类（AuthStore / MessageStore） |
| 路由 | `@ohos.router` |

## 项目结构

```
entry/src/main/ets/
├── api/
│   ├── ApiService.ets       # 所有 API 方法（Music / Social / Message 等）
│   └── HttpClient.ets       # HTTP 客户端封装（含 Token 自动注入）
├── common/
│   ├── Config.ets           # BASE_URL 等全局配置
│   └── Constants.ets        # 颜色、字体等 UI 常量
├── components/
│   └── AvatarImage.ets      # 通用头像组件（有图显示，无图显示占位）
├── models/
│   └── Models.ets           # 数据模型（User / Song / Comment / Message 等）
├── pages/
│   ├── Index.ets            # 启动页（鉴权跳转）
│   ├── LoginPage.ets        # 登录
│   ├── RegisterPage.ets     # 注册
│   ├── HomePage.ets         # 首页（推荐 / 歌手 / 动态 / 最新）
│   ├── SearchPage.ets       # 搜索
│   ├── SongDetailPage.ets   # 歌曲详情 + 播放器 + 评论
│   ├── MessagesPage.ets     # 会话列表
│   ├── ChatPage.ets         # 聊天页（支持歌曲卡片消息）
│   ├── ProfilePage.ets      # 个人主页
│   └── UserDetailPage.ets   # 其他用户主页
├── services/
│   └── WebSocketService.ets # WebSocket 单例服务
├── store/
│   └── AppStore.ets         # 全局状态（登录用户 / 未读消息数）
└── utils/
    └── UrlUtils.ets         # URL 拼接工具
```

## 后端

后端使用 Flask + Flask-SocketIO，部署于 `https://app.onbeat.com.cn`。

WebSocket 采用 Socket.IO EIO4 协议：
- 连接时携带 JWT Token 完成身份认证
- 实时推送新私信，客户端无需轮询

## 开发环境

- DevEco Studio 5.x
- HarmonyOS SDK API 12+
- 目标设备：手机（phone）

## 运行方式

1. 用 DevEco Studio 打开项目根目录
2. 连接真机或启动模拟器
3. 点击 Run 即可
