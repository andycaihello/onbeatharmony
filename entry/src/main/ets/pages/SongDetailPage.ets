/**
 * 歌曲详情页面 - 含评论、回复、评论点赞、音乐播放
 */
import router from '@ohos.router';
import media from '@ohos.multimedia.media';
import { Constants } from '../common/Constants';
import { SongModel, CommentModel, UserModel, ConversationModel } from '../models/Models';
import {
  MusicAPI, InteractionAPI, NeteaseAPI, MessageAPI,
  SongDetailResponse, CommentsResponse, LikeStatusResponse
} from '../api/ApiService';
import { UrlUtils } from '../utils/UrlUtils';
import { AuthStore } from '../store/AppStore';
import { AvatarImage } from '../components/AvatarImage';

interface RouterParams {
  songId: number;
  autoPlay: boolean;
}

@Entry
@Component
struct SongDetailPage {
  // 歌曲
  @State song: SongModel | null = null;
  @State isLoading: boolean = true;
  @State isLiked: boolean = false;
  @State currentUser: UserModel | null = null;

  // 评论
  @State comments: CommentModel[] = [];
  @State commentContent: string = '';
  @State isSubmitting: boolean = false;

  // 回复状态
  @State replyToCommentId: number = -1;       // -1 表示不在回复模式
  @State replyToUsername: string = '';
  @State replyContent: string = '';

  // 评论点赞（客户端追踪）
  @State likedCommentIds: number[] = [];

  // 展开的回复列表
  @State expandedCommentIds: number[] = [];

  // 播放器
  @State isPlayerVisible: boolean = false;
  @State isPlaying: boolean = false;
  @State currentTime: number = 0;   // 秒
  @State totalDuration: number = 0; // 秒
  @State playLoading: boolean = false;
  private avPlayerInst: media.AVPlayer | null = null;
  private playRecorded: boolean = false;

  // 分享
  @State showSharePanel: boolean = false;
  @State conversations: ConversationModel[] = [];
  @State shareSending: boolean = false;

  private songId: number = 0;
  private autoPlay: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as RouterParams;
    if (params && params.songId) {
      this.songId = params.songId;
      this.autoPlay = params.autoPlay === true;
      this.currentUser = AuthStore.getUser();
      this.fetchData();
    }
  }

  aboutToDisappear(): void {
    this.releasePlayer();
  }

  // ─── 数据加载 ─────────────────────────────────────────

  async fetchData(): Promise<void> {
    this.isLoading = true;
    try {
      const songRes = await MusicAPI.getSongDetail(this.songId);
      this.song = songRes.song;

      const commentsRes = await InteractionAPI.getComments(this.songId);
      this.comments = commentsRes.comments;

      if (this.currentUser) {
        const likeRes = await InteractionAPI.getLikeStatus(this.songId);
        this.isLiked = likeRes.is_liked;
      }

      // 自动播放
      if (this.autoPlay) {
        this.autoPlay = false;
        this.handlePlay();
      }
    } catch (error) {
      console.error('fetchData error: ' + (error as Error).message);
    } finally {
      this.isLoading = false;
    }
  }

  async refreshComments(): Promise<void> {
    try {
      const res = await InteractionAPI.getComments(this.songId);
      this.comments = res.comments;
    } catch (error) {
      console.error('refreshComments error: ' + (error as Error).message);
    }
  }

  // ─── 点赞 ─────────────────────────────────────────────

  async handleLike(): Promise<void> {
    if (!this.currentUser) {
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    try {
      if (this.isLiked) {
        await InteractionAPI.unlikeSong(this.songId);
        this.isLiked = false;
        if (this.song) this.song.like_count = Math.max(0, this.song.like_count - 1);
      } else {
        await InteractionAPI.likeSong(this.songId);
        this.isLiked = true;
        if (this.song) this.song.like_count += 1;
      }
    } catch (error) {
      console.error('handleLike error: ' + (error as Error).message);
    }
  }

  // ─── 评论 ─────────────────────────────────────────────

  async handleSubmitComment(): Promise<void> {
    if (!this.currentUser) {
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    const text = this.commentContent.trim();
    if (!text) return;

    this.isSubmitting = true;
    try {
      await InteractionAPI.addComment(this.songId, text);
      this.commentContent = '';
      await this.refreshComments();
      if (this.song) this.song.comment_count += 1;
    } catch (error) {
      console.error('submitComment error: ' + (error as Error).message);
    } finally {
      this.isSubmitting = false;
    }
  }

  async handleSubmitReply(): Promise<void> {
    if (!this.currentUser || this.replyToCommentId < 0) return;
    const text = this.replyContent.trim();
    if (!text) return;

    const parentId = this.replyToCommentId; // 必须先保存，清空前

    this.isSubmitting = true;
    try {
      await InteractionAPI.addComment(this.songId, text, parentId);
      this.replyContent = '';
      this.replyToCommentId = -1;
      this.replyToUsername = '';
      await this.refreshComments();
      if (this.song) this.song.comment_count += 1;
      // 展开刚回复的评论的回复列表
      if (!this.isRepliesExpanded(parentId)) {
        this.expandedCommentIds = [...this.expandedCommentIds, parentId];
      }
    } catch (error) {
      console.error('submitReply error: ' + (error as Error).message);
    } finally {
      this.isSubmitting = false;
    }
  }

  async handleCommentLike(comment: CommentModel): Promise<void> {
    if (!this.currentUser) return;
    const liked = this.isCommentLiked(comment.id);
    try {
      if (liked) {
        await InteractionAPI.unlikeComment(comment.id);
        this.likedCommentIds = this.removeFromArr(this.likedCommentIds, comment.id);
        comment.like_count = Math.max(0, comment.like_count - 1);
      } else {
        await InteractionAPI.likeComment(comment.id);
        this.likedCommentIds = [...this.likedCommentIds, comment.id];
        comment.like_count += 1;
      }
      // 触发重渲染
      this.comments = [...this.comments];
    } catch (error) {
      console.error('commentLike error: ' + (error as Error).message);
    }
  }

  // ─── 评论辅助 ─────────────────────────────────────────

  private isCommentLiked(commentId: number): boolean {
    for (const id of this.likedCommentIds) {
      if (id === commentId) return true;
    }
    return false;
  }

  private isRepliesExpanded(commentId: number): boolean {
    for (const id of this.expandedCommentIds) {
      if (id === commentId) return true;
    }
    return false;
  }

  private toggleExpand(commentId: number): void {
    if (this.isRepliesExpanded(commentId)) {
      this.expandedCommentIds = this.removeFromArr(this.expandedCommentIds, commentId);
    } else {
      this.expandedCommentIds = [...this.expandedCommentIds, commentId];
    }
  }

  private removeFromArr(arr: number[], val: number): number[] {
    const result: number[] = [];
    for (const item of arr) {
      if (item !== val) result.push(item);
    }
    return result;
  }

  private startReply(commentId: number, username: string): void {
    this.replyToCommentId = commentId;
    this.replyToUsername = username;
    this.replyContent = '';
  }

  private cancelReply(): void {
    this.replyToCommentId = -1;
    this.replyToUsername = '';
    this.replyContent = '';
  }

  // ─── 播放器 ─────────────────────────────────────────

  async handlePlay(): Promise<void> {
    if (!this.song) return;
    if (this.isPlayerVisible) {
      // 已经在播放，切换播放/暂停
      this.handlePlayPause();
      return;
    }

    this.playLoading = true;
    try {
      let audioUrl = this.song.external_url || '';

      // 尝试获取网易云播放链接
      if (this.song.netease_id > 0) {
        try {
          const neteaseRes = await NeteaseAPI.getSongUrl(this.song.netease_id);
          if (neteaseRes.data && neteaseRes.data.length > 0 && neteaseRes.data[0].url) {
            audioUrl = neteaseRes.data[0].url;
          }
        } catch (_e) {
          console.warn('Netease URL failed, using external_url');
        }
      }

      if (!audioUrl) {
        console.error('No audio URL available');
        this.playLoading = false;
        return;
      }

      await this.initPlayer(audioUrl);
    } catch (error) {
      console.error('handlePlay error: ' + (error as Error).message);
      this.playLoading = false;
    }
  }

  private async initPlayer(audioUrl: string): Promise<void> {
    this.releasePlayer();
    this.playRecorded = false;
    this.currentTime = 0;
    this.totalDuration = this.song ? this.song.duration : 0;

    const player = await media.createAVPlayer();
    this.avPlayerInst = player;

    player.on('stateChange', (state: media.AVPlayerState) => {
      if (state === 'initialized') {
        player.prepare();
      } else if (state === 'prepared') {
        const dur = player.duration;
        if (dur > 0) this.totalDuration = Math.floor(dur / 1000);
        this.playLoading = false;
        this.isPlayerVisible = true;
        player.play();
        this.recordPlay();
      } else if (state === 'playing') {
        this.isPlaying = true;
        this.playLoading = false;
      } else if (state === 'paused') {
        this.isPlaying = false;
      } else if (state === 'completed') {
        this.isPlaying = false;
        this.currentTime = 0;
      } else if (state === 'error') {
        this.isPlaying = false;
        this.playLoading = false;
      }
    });

    player.on('timeUpdate', (time: number) => {
      this.currentTime = Math.floor(time / 1000);
    });

    player.url = audioUrl;
  }

  private handlePlayPause(): void {
    if (this.avPlayerInst === null) return;
    if (this.isPlaying) {
      this.avPlayerInst.pause();
    } else {
      this.avPlayerInst.play();
    }
  }

  private handleSeek(seconds: number): void {
    if (this.avPlayerInst !== null) {
      this.avPlayerInst.seek(Math.floor(seconds) * 1000);
      this.currentTime = Math.floor(seconds);
    }
  }

  private handleClosePlayer(): void {
    this.releasePlayer();
    this.isPlayerVisible = false;
    this.isPlaying = false;
    this.currentTime = 0;
  }

  private releasePlayer(): void {
    if (this.avPlayerInst !== null) {
      try {
        this.avPlayerInst.stop();
        this.avPlayerInst.release();
      } catch (_e) {
        // ignore
      }
      this.avPlayerInst = null;
    }
  }

  private async recordPlay(): Promise<void> {
    if (!this.playRecorded && this.song) {
      this.playRecorded = true;
      try {
        await InteractionAPI.playSong(this.songId);
        this.song.play_count += 1;
      } catch (_e) {
        // ignore
      }
    }
  }

  // ─── 分享 ──────────────────────────────────────────────

  async handleShare(): Promise<void> {
    if (!this.currentUser) {
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    try {
      const convs = await MessageAPI.getConversations();
      this.conversations = convs;
    } catch (_e) {
      this.conversations = [];
    }
    this.showSharePanel = true;
  }

  async handleSendShare(receiverId: number): Promise<void> {
    if (!this.song || this.shareSending) return;
    this.shareSending = true;
    try {
      await MessageAPI.sendSongShare(receiverId, this.song);
      this.showSharePanel = false;
    } catch (error) {
      console.error('sendSongShare error: ' + (error as Error).message);
    } finally {
      this.shareSending = false;
    }
  }

  // ─── 格式化 ───────────────────────────────────────────

  private formatDuration(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return mins.toString() + ':' + (secs < 10 ? '0' : '') + secs.toString();
  }

  private formatNumber(num: number): string {
    if (num >= 10000) return (num / 10000).toFixed(1) + '万';
    return num.toString();
  }

  private formatTime(dateString: string): string {
    const date = new Date(dateString);
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    if (days === 0) return '今天';
    if (days === 1) return '昨天';
    if (days < 7) return days.toString() + '天前';
    if (days < 30) return Math.floor(days / 7).toString() + '周前';
    if (days < 365) return Math.floor(days / 30).toString() + '个月前';
    return Math.floor(days / 365).toString() + '年前';
  }

  // ─── 构建 UI ──────────────────────────────────────────

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        // 顶部导航
        Row() {
          Button() {
            Text('< 返回')
              .fontSize(16)
              .fontColor(Constants.TEXT_PRIMARY)
          }
          .height(40)
          .backgroundColor(Color.Transparent)
          .onClick(() => router.back())

          Blank()

          Text('歌曲详情')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)

          Blank()
          Blank().width(60)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .height(56)
        .backgroundColor(Constants.WHITE_COLOR)

        // 内容
        if (this.isLoading) {
          Column() {
            LoadingProgress().width(50).height(50).color(Constants.PRIMARY_COLOR)
            Text('加载中...').fontSize(14).fontColor(Constants.TEXT_SECONDARY).margin({ top: 12 })
          }
          .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else if (!this.song) {
          Column() {
            Text('歌曲不存在').fontSize(16).fontColor(Constants.TEXT_SECONDARY)
          }
          .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column() {
              // 歌曲信息卡片
              Column() {
                // 封面
                Image(UrlUtils.getCoverUrl(this.song.cover_url) || $r('app.media.icon'))
                  .width(180)
                  .height(180)
                  .borderRadius(12)
                  .objectFit(ImageFit.Cover)
                  .margin({ top: 24, bottom: 16 })

                // 标题
                Text(this.song.title)
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Constants.TEXT_PRIMARY)
                  .textAlign(TextAlign.Center)
                  .width('100%')

                // 歌手
                Text(this.song.artist?.name || '未知歌手')
                  .fontSize(15)
                  .fontColor(Constants.TEXT_SECONDARY)
                  .margin({ top: 6, bottom: 20 })

                // 统计数字
                Row() {
                  Column() {
                    Text(this.formatNumber(this.song.play_count))
                      .fontSize(18).fontWeight(FontWeight.Bold).fontColor(Constants.PRIMARY_COLOR)
                    Text('播放').fontSize(12).fontColor(Constants.TEXT_SECONDARY).margin({ top: 4 })
                  }.width(72)

                  Column() {
                    Text(this.formatNumber(this.song.like_count))
                      .fontSize(18).fontWeight(FontWeight.Bold).fontColor(Constants.PRIMARY_COLOR)
                    Text('点赞').fontSize(12).fontColor(Constants.TEXT_SECONDARY).margin({ top: 4 })
                  }.width(72)

                  Column() {
                    Text(this.formatNumber(this.song.comment_count))
                      .fontSize(18).fontWeight(FontWeight.Bold).fontColor(Constants.PRIMARY_COLOR)
                    Text('评论').fontSize(12).fontColor(Constants.TEXT_SECONDARY).margin({ top: 4 })
                  }.width(72)

                  Column() {
                    Text(this.formatDuration(this.song.duration))
                      .fontSize(18).fontWeight(FontWeight.Bold).fontColor(Constants.PRIMARY_COLOR)
                    Text('时长').fontSize(12).fontColor(Constants.TEXT_SECONDARY).margin({ top: 4 })
                  }.width(72)
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceEvenly)
                .margin({ bottom: 24 })

                // 操作按钮
                Row() {
                  Button() {
                    Row() {
                      Text(this.playLoading ? '加载中' : (this.isPlayerVisible ? (this.isPlaying ? '⏸ 暂停' : '▶ 继续') : '▶ 播放'))
                        .fontSize(16).fontColor(Constants.WHITE_COLOR)
                    }
                  }
                  .width(100).height(44)
                  .backgroundColor(this.playLoading ? Constants.TEXT_SECONDARY : Constants.PRIMARY_COLOR)
                  .borderRadius(22)
                  .enabled(!this.playLoading)
                  .onClick(() => this.handlePlay())

                  Button() {
                    Text(this.isLiked ? '♥ 已点赞' : '♡ 点赞')
                      .fontSize(16)
                      .fontColor(this.isLiked ? Constants.PRIMARY_COLOR : Constants.TEXT_PRIMARY)
                  }
                  .width(100).height(44)
                  .backgroundColor(this.isLiked ? '#E6F7FF' : Constants.BACKGROUND_COLOR)
                  .borderRadius(22)
                  .margin({ left: 12 })
                  .onClick(() => this.handleLike())

                  Button() {
                    Text('↗ 分享')
                      .fontSize(16)
                      .fontColor(Constants.TEXT_PRIMARY)
                  }
                  .width(90).height(44)
                  .backgroundColor(Constants.BACKGROUND_COLOR)
                  .borderRadius(22)
                  .margin({ left: 12 })
                  .onClick(() => this.handleShare())
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .margin({ bottom: 24 })
              }
              .width('100%')
              .backgroundColor(Constants.WHITE_COLOR)
              .alignItems(HorizontalAlign.Center)

              // 评论区
              Column() {
                // 标题
                Text('评论 (' + this.song.comment_count.toString() + ')')
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Constants.TEXT_PRIMARY)
                  .width('100%')
                  .padding({ left: 16, top: 16, bottom: 12 })

                // 发表评论输入框
                Column() {
                  Row() {
                    TextInput({ placeholder: '写下你的评论...', text: this.commentContent })
                      .layoutWeight(1)
                      .height(40)
                      .backgroundColor(Constants.BACKGROUND_COLOR)
                      .borderRadius(20)
                      .padding({ left: 16, right: 16 })
                      .onChange((val: string) => { this.commentContent = val; })

                    Button() {
                      Text('发布').fontSize(14).fontColor(Constants.WHITE_COLOR)
                    }
                    .width(60).height(40)
                    .backgroundColor(Constants.PRIMARY_COLOR)
                    .borderRadius(20)
                    .margin({ left: 8 })
                    .enabled(!this.isSubmitting && this.commentContent.trim().length > 0)
                    .onClick(() => this.handleSubmitComment())
                  }
                  .width('100%')
                }
                .width('100%')
                .padding({ left: 16, right: 16, bottom: 12 })

                // 评论列表
                if (this.comments.length === 0) {
                  Text('暂无评论，快来抢沙发吧！')
                    .fontSize(14)
                    .fontColor(Constants.TEXT_SECONDARY)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .padding({ top: 24, bottom: 24 })
                } else {
                  ForEach(this.comments, (comment: CommentModel) => {
                    this.CommentItem(comment)
                  }, (comment: CommentModel) => comment.id.toString() + '_' + comment.replies.length.toString())
                }
              }
              .width('100%')
              .backgroundColor(Constants.WHITE_COLOR)
              .margin({ top: 8 })
            }
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .backgroundColor(Constants.BACKGROUND_COLOR)
        }

        // 播放器底部栏
        if (this.isPlayerVisible && this.song) {
          this.PlayerBar()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Constants.BACKGROUND_COLOR)

      // 分享面板覆层
      if (this.showSharePanel) {
        this.SharePanel()
      }
    }
    .width('100%')
    .height('100%')
  }

  // ─── 分享面板 ─────────────────────────────────────────

  @Builder
  SharePanel() {
    Column() {
      // 半透明遮罩（点击关闭）
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#66000000')
        .onClick(() => {
          this.showSharePanel = false;
        })

      // 底部卡片
      Column() {
        // 标题栏
        Row() {
          Text('分享给好友')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.TEXT_PRIMARY)

          Blank()

          Button() {
            Text('✕').fontSize(16).fontColor(Constants.TEXT_SECONDARY)
          }
          .width(36).height(36)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.showSharePanel = false;
          })
        }
        .width('100%')
        .padding({ left: 16, right: 8, top: 16, bottom: 8 })

        // 会话列表
        if (this.conversations.length === 0) {
          Text('暂无会话，先去和朋友聊聊吧')
            .fontSize(14)
            .fontColor(Constants.TEXT_SECONDARY)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 24, bottom: 32 })
        } else {
          Scroll() {
            Column() {
              ForEach(this.conversations, (conv: ConversationModel) => {
                Row() {
                  AvatarImage({ src: UrlUtils.getAvatarUrl(conv.user.avatar_url), diameter: 44 })

                  Column() {
                    Text(conv.user.nickname || conv.user.username)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Constants.TEXT_PRIMARY)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  .padding({ left: 12, right: 8 })

                  Button() {
                    Text(this.shareSending ? '发送中' : '发送')
                      .fontSize(13)
                      .fontColor(Constants.WHITE_COLOR)
                  }
                  .height(32)
                  .padding({ left: 14, right: 14 })
                  .backgroundColor(this.shareSending ? Constants.TEXT_SECONDARY : Constants.PRIMARY_COLOR)
                  .borderRadius(16)
                  .enabled(!this.shareSending)
                  .onClick(() => {
                    this.handleSendShare(conv.user.id);
                  })
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 10, bottom: 10 })
                .border({ width: { bottom: 1 }, color: Constants.BACKGROUND_COLOR })
              })
            }
            .width('100%')
          }
          .width('100%')
          .constraintSize({ maxHeight: 280 })
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .backgroundColor(Constants.WHITE_COLOR)
      .borderRadius({ topLeft: 16, topRight: 16 })
    }
    .width('100%')
    .height('100%')
  }

  // ─── 评论条目 ─────────────────────────────────────────

  @Builder
  CommentItem(comment: CommentModel) {
    Column() {
      Row() {
        // 头像
        AvatarImage({ src: UrlUtils.getAvatarUrl(comment.user?.avatar_url), diameter: 40 })
          .alignSelf(ItemAlign.Start)

        Column() {
          // 用户名 + 时间
          Row() {
            Text(comment.user?.nickname || comment.user?.username || '用户')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.TEXT_PRIMARY)

            Text(this.formatTime(comment.created_at))
              .fontSize(12)
              .fontColor(Constants.TEXT_SECONDARY)
              .margin({ left: 8 })

            Blank()

            if (this.currentUser && comment.user && comment.user.id !== this.currentUser.id) {
              Button() {
                Text('私信').fontSize(11).fontColor(Constants.PRIMARY_COLOR)
              }
              .height(24)
              .padding({ left: 8, right: 8 })
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: Constants.PRIMARY_COLOR })
              .borderRadius(12)
              .onClick(() => {
                router.pushUrl({ url: 'pages/ChatPage', params: { userId: comment.user.id } });
              })
            }
          }
          .width('100%')

          // 内容
          Text(comment.content)
            .fontSize(14)
            .fontColor(Constants.TEXT_PRIMARY)
            .margin({ top: 6, bottom: 8 })
            .width('100%')

          // 操作栏
          Row() {
            // 点赞
            Button() {
              Text((this.isCommentLiked(comment.id) ? '♥ ' : '♡ ') +
                (comment.like_count > 0 ? this.formatNumber(comment.like_count) : ''))
                .fontSize(13)
                .fontColor(this.isCommentLiked(comment.id) ? '#FF4D4F' : Constants.TEXT_SECONDARY)
            }
            .height(28)
            .padding({ left: 8, right: 8 })
            .backgroundColor(Color.Transparent)
            .onClick(() => this.handleCommentLike(comment))

            // 回复
            Button() {
              Text('回复').fontSize(13).fontColor(Constants.TEXT_SECONDARY)
            }
            .height(28)
            .padding({ left: 8, right: 8 })
            .backgroundColor(Color.Transparent)
            .margin({ left: 4 })
            .onClick(() => {
              if (this.replyToCommentId === comment.id) {
                this.cancelReply();
              } else {
                this.startReply(comment.id, comment.user?.nickname || comment.user?.username || '用户');
              }
            })

            // 展开/收起回复
            if (comment.replies && comment.replies.length > 0) {
              Button() {
                Text((this.isRepliesExpanded(comment.id) ? '∧ ' : '∨ ') +
                  comment.replies.length.toString() + '条回复')
                  .fontSize(13)
                  .fontColor(Constants.PRIMARY_COLOR)
              }
              .height(28)
              .padding({ left: 8, right: 8 })
              .backgroundColor(Color.Transparent)
              .margin({ left: 4 })
              .onClick(() => this.toggleExpand(comment.id))
            }
          }
          .width('100%')

          // 回复输入框
          if (this.replyToCommentId === comment.id) {
            Row() {
              TextInput({ placeholder: '回复 @' + this.replyToUsername, text: this.replyContent })
                .layoutWeight(1)
                .height(36)
                .backgroundColor(Constants.BACKGROUND_COLOR)
                .borderRadius(18)
                .padding({ left: 12, right: 12 })
                .onChange((val: string) => { this.replyContent = val; })

              Button() {
                Text('取消').fontSize(12).fontColor(Constants.TEXT_SECONDARY)
              }
              .height(32).padding({ left: 8, right: 8 })
              .backgroundColor(Color.Transparent)
              .onClick(() => this.cancelReply())

              Button() {
                Text('发送').fontSize(12).fontColor(Constants.WHITE_COLOR)
              }
              .height(32)
              .padding({ left: 12, right: 12 })
              .backgroundColor(Constants.PRIMARY_COLOR)
              .borderRadius(16)
              .margin({ left: 4 })
              .enabled(this.replyContent.trim().length > 0 && !this.isSubmitting)
              .onClick(() => this.handleSubmitReply())
            }
            .width('100%')
            .margin({ top: 8 })
          }

          // 回复列表
          if (comment.replies && comment.replies.length > 0 && this.isRepliesExpanded(comment.id)) {
            Column() {
              ForEach(comment.replies, (reply: CommentModel) => {
                this.ReplyItem(reply, comment.id)
              }, (reply: CommentModel) => reply.id.toString())
            }
            .width('100%')
            .margin({ top: 8 })
            .padding({ left: 12 })
            .border({ width: { left: 2 }, color: '#E8E8E8' })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 12 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .border({ width: { bottom: 1 }, color: Constants.BACKGROUND_COLOR })
  }

  // ─── 回复条目 ─────────────────────────────────────────

  @Builder
  ReplyItem(reply: CommentModel, parentCommentId: number) {
    Row() {
      AvatarImage({ src: UrlUtils.getAvatarUrl(reply.user?.avatar_url), diameter: 30 })
        .alignSelf(ItemAlign.Start)

      Column() {
        Row() {
          Text(reply.user?.nickname || reply.user?.username || '用户')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.TEXT_PRIMARY)

          Text(this.formatTime(reply.created_at))
            .fontSize(11)
            .fontColor(Constants.TEXT_SECONDARY)
            .margin({ left: 8 })
        }

        Text(reply.content)
          .fontSize(13)
          .fontColor(Constants.TEXT_PRIMARY)
          .margin({ top: 4, bottom: 4 })

        Button() {
          Text('回复').fontSize(12).fontColor(Constants.TEXT_SECONDARY)
        }
        .height(24).padding({ left: 0 })
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.startReply(parentCommentId, reply.user?.nickname || reply.user?.username || '用户');
        })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 8 })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Top)
  }

  // ─── 播放器底部栏 ─────────────────────────────────────

  @Builder
  PlayerBar() {
    Column() {
      // 进度条
      Slider({
        value: this.currentTime,
        min: 0,
        max: Math.max(this.totalDuration, 1),
        step: 1,
        style: SliderStyle.InSet
      })
      .width('100%')
      .height(20)
      .trackThickness(3)
      .blockSize({ width: 12, height: 12 })
      .selectedColor(Constants.PRIMARY_COLOR)
      .trackColor('#E0E0E0')
      .onChange((val: number) => this.handleSeek(val))

      // 控制栏
      Row() {
        // 封面
        Image(UrlUtils.getCoverUrl(this.song?.cover_url || '') || $r('app.media.icon'))
          .width(44)
          .height(44)
          .borderRadius(4)
          .objectFit(ImageFit.Cover)

        // 歌曲信息
        Column() {
          Text(this.song?.title || '')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Constants.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.song?.artist?.name || '')
            .fontSize(12)
            .fontColor(Constants.TEXT_SECONDARY)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 10, right: 10 })

        // 时间
        Text(this.formatDuration(this.currentTime) + ' / ' + this.formatDuration(this.totalDuration))
          .fontSize(12)
          .fontColor(Constants.TEXT_SECONDARY)
          .margin({ right: 8 })

        // 播放/暂停
        Button() {
          Text(this.isPlaying ? '⏸' : '▶')
            .fontSize(20)
            .fontColor(Constants.PRIMARY_COLOR)
        }
        .width(40).height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => this.handlePlayPause())

        // 关闭
        Button() {
          Text('✕')
            .fontSize(16)
            .fontColor(Constants.TEXT_SECONDARY)
        }
        .width(36).height(36)
        .backgroundColor(Color.Transparent)
        .onClick(() => this.handleClosePlayer())
      }
      .width('100%')
      .padding({ left: 12, right: 12, bottom: 8 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .backgroundColor(Constants.WHITE_COLOR)
    .border({ width: { top: 1 }, color: '#EEEEEE' })
  }
}
