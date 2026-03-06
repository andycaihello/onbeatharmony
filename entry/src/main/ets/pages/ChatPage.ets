/**
 * 聊天页面 - 与特定用户聊天
 */
import router from '@ohos.router';
import { Constants } from '../common/Constants';
import { UserModel, MessageModel, SongShareInfo } from '../models/Models';
import { MessageAPI, ConversationMessagesResponse, UserAPI, UserResponse } from '../api/ApiService';
import { UrlUtils } from '../utils/UrlUtils';
import { AuthStore, MessageStore } from '../store/AppStore';
import { WebSocketService, MessageCallback } from '../services/WebSocketService';
import { AvatarImage } from '../components/AvatarImage';

interface RouterParams {
  userId: number;
}

@Entry
@Component
struct ChatPage {
  @State targetUser: UserModel | null = null;
  @State messages: MessageModel[] = [];
  @State messageContent: string = '';
  @State isLoading: boolean = true;
  @State isSending: boolean = false;
  @State currentUser: UserModel | null = null;

  private userId: number = 0;
  private scroller: Scroller = new Scroller();
  private wsCallback: MessageCallback = (_message: object) => {};

  aboutToAppear(): void {
    const params = router.getParams() as RouterParams;
    if (params && params.userId) {
      this.userId = params.userId;
      this.currentUser = AuthStore.getUser();
      this.fetchData();
    }

    // 注册 WebSocket 消息回调，实时接收新消息
    this.wsCallback = (message: object) => {
      const msg = message as Record<string, Object>;
      const senderId = msg['sender_id'] as number;
      const receiverId = msg['receiver_id'] as number;

      // 只处理当前会话的消息
      if (senderId === this.userId || receiverId === this.userId) {
        const newMsg = new MessageModel();
        newMsg.id = (msg['id'] || 0) as number;
        newMsg.sender_id = senderId;
        newMsg.receiver_id = receiverId;
        newMsg.content = (msg['content'] || '') as string;
        newMsg.is_read = (msg['is_read'] || false) as boolean;
        newMsg.created_at = (msg['created_at'] || '') as string;
        this.parseMessageContent(newMsg);

        this.messages = [...this.messages, newMsg];

        // 滚动到底部
        setTimeout(() => {
          this.scroller.scrollEdge(Edge.Bottom);
        }, 100);

        // 如果是对方发来的消息，标记为已读
        if (senderId === this.userId) {
          MessageAPI.markConversationAsRead(this.userId);
          MessageStore.decrementUnreadCount(1);
        }
      }
    };

    WebSocketService.getInstance().addMessageCallback(this.wsCallback);
    WebSocketService.getInstance().connect();
  }

  aboutToDisappear(): void {
    WebSocketService.getInstance().removeMessageCallback(this.wsCallback);
  }

  private parseMessageContent(msg: MessageModel): MessageModel {
    const content = msg.content;
    if (!content || !content.startsWith('{')) {
      return msg;
    }
    try {
      const obj = JSON.parse(content) as Record<string, Object>;
      if ((obj['type'] as string) === 'song_share' && obj['song']) {
        const songObj = obj['song'] as Record<string, Object>;
        msg.msg_type = 'song_share';
        const share = new SongShareInfo();
        share.id = (songObj['id'] as number) || 0;
        share.title = (songObj['title'] as string) || '';
        share.artist_name = (songObj['artist_name'] as string) || '';
        share.cover_url = (songObj['cover_url'] as string) || '';
        share.netease_id = (songObj['netease_id'] as number) || 0;
        share.external_url = (songObj['external_url'] as string) || '';
        msg.song_share = share;
      }
    } catch (_e) {
      // not JSON, treat as regular text
    }
    return msg;
  }

  async fetchData(): Promise<void> {
    this.isLoading = true;
    try {
      // 获取用户信息
      const userRes: UserResponse = await UserAPI.getProfile(this.userId);
      this.targetUser = userRes.user;

      // 获取消息
      const messagesRes: ConversationMessagesResponse = await MessageAPI.getConversation(this.userId);
      // 按时间正序排列（旧消息在前，新消息在后）
      const msgList = messagesRes.messages || [];
      // 使用冒泡排序
      for (let i = 0; i < msgList.length - 1; i++) {
        for (let j = 0; j < msgList.length - 1 - i; j++) {
          const timeA = new Date(msgList[j].created_at).getTime();
          const timeB = new Date(msgList[j + 1].created_at).getTime();
          if (timeA > timeB) {
            const temp = msgList[j];
            msgList[j] = msgList[j + 1];
            msgList[j + 1] = temp;
          }
        }
      }
      this.messages = msgList.map((m: MessageModel) => this.parseMessageContent(m));

      // 标记为已读
      const previousUnread = this.messages.filter((m: MessageModel) => !m.is_read && m.sender_id !== this.currentUser?.id).length;
      if (this.messages.length > 0) {
        await MessageAPI.markConversationAsRead(this.userId);
        // 更新未读消息数
        if (previousUnread > 0) {
          MessageStore.decrementUnreadCount(previousUnread);
        }
      }
    } catch (error) {
      console.error('Failed to fetch chat data: ' + (error as Error).message);
    } finally {
      this.isLoading = false;
    }
    // 滚动到底部
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 100);
  }

  async handleSendMessage(): Promise<void> {
    if (!this.messageContent.trim() || this.isSending) {
      return;
    }

    this.isSending = true;
    try {
      await MessageAPI.sendMessage(this.userId, this.messageContent.trim());
      this.messageContent = '';
      // 刷新消息
      const messagesRes: ConversationMessagesResponse = await MessageAPI.getConversation(this.userId);
      // 按时间正序排列
      const msgList = messagesRes.messages || [];
      for (let i = 0; i < msgList.length - 1; i++) {
        for (let j = 0; j < msgList.length - 1 - i; j++) {
          const timeA = new Date(msgList[j].created_at).getTime();
          const timeB = new Date(msgList[j + 1].created_at).getTime();
          if (timeA > timeB) {
            const temp = msgList[j];
            msgList[j] = msgList[j + 1];
            msgList[j + 1] = temp;
          }
        }
      }
      this.messages = msgList.map((m: MessageModel) => this.parseMessageContent(m));
      // 滚动到底部
      setTimeout(() => {
        this.scroller.scrollEdge(Edge.Bottom);
      }, 100);
    } catch (error) {
      console.error('Failed to send message: ' + (error as Error).message);
    } finally {
      this.isSending = false;
    }
  }

  private formatTime(dateString: string): string {
    const date = new Date(dateString);
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    return hours + ':' + minutes;
  }

  @Builder
  SongShareCard(message: MessageModel, isSelf: boolean) {
    Column() {
      Text('分享了一首歌曲')
        .fontSize(11)
        .fontColor(isSelf ? '#B0D8F5' : Constants.TEXT_SECONDARY)
        .width('100%')
        .padding({ left: 10, top: 8, bottom: 4 })

      Row() {
        Image(UrlUtils.getCoverUrl(message.song_share.cover_url) || $r('app.media.icon'))
          .width(44)
          .height(44)
          .borderRadius(6)
          .objectFit(ImageFit.Cover)

        Column() {
          Text(message.song_share.title)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(message.song_share.artist_name)
            .fontSize(12)
            .fontColor(Constants.TEXT_SECONDARY)
            .margin({ top: 3 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 10, right: 6 })

        Button() {
          Text('▶')
            .fontSize(16)
            .fontColor(Constants.WHITE_COLOR)
        }
        .width(36)
        .height(36)
        .backgroundColor(Constants.PRIMARY_COLOR)
        .borderRadius(18)
        .onClick(() => {
          router.pushUrl({
            url: 'pages/SongDetailPage',
            params: { songId: message.song_share.id, autoPlay: true }
          });
        })
      }
      .width('100%')
      .padding({ left: 10, right: 10, bottom: 10 })
    }
    .width(240)
    .backgroundColor(isSelf ? '#D1EBF8' : Constants.WHITE_COLOR)
    .borderRadius({
      topRight: isSelf ? 4 : 16,
      topLeft: isSelf ? 16 : 4,
      bottomRight: 16,
      bottomLeft: 16
    })
    .border({ width: 1, color: '#E0E0E0' })
    .onClick(() => {
      router.pushUrl({
        url: 'pages/SongDetailPage',
        params: { songId: message.song_share.id }
      });
    })
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Button() {
          Text('< 返回')
            .fontSize(16)
            .fontColor(Constants.TEXT_PRIMARY)
        }
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          router.back();
        })

        if (this.targetUser) {
          AvatarImage({ src: UrlUtils.getAvatarUrl(this.targetUser.avatar_url), diameter: 32 })
            .margin({ left: 12 })

          Text(this.targetUser.nickname || this.targetUser.username || '用户')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .margin({ left: 8 })
            .layoutWeight(1)
        } else {
          Text('聊天')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .margin({ left: 12 })
            .layoutWeight(1)
        }
      }
      .width('100%')
      .padding({ left: 8, right: 16 })
      .height(56)
      .backgroundColor(Constants.WHITE_COLOR)

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(50)
            .height(50)
            .color(Constants.PRIMARY_COLOR)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        // 消息列表
        List({ scroller: this.scroller }) {
          ForEach(this.messages, (message: MessageModel) => {
            ListItem() {
              Row() {
                if (message.sender_id === this.currentUser?.id) {
                  // 自己发送的消息 - 右侧
                  Blank()
                  Column() {
                    if (message.msg_type === 'song_share') {
                      this.SongShareCard(message, true)
                    } else {
                      Text(message.content)
                        .fontSize(15)
                        .fontColor(Constants.WHITE_COLOR)
                        .padding(12)
                        .backgroundColor(Constants.PRIMARY_COLOR)
                        .borderRadius({ topRight: 4, topLeft: 16, bottomRight: 16, bottomLeft: 16 })
                        .constraintSize({ maxWidth: '65%' })
                    }

                    Text(this.formatTime(message.created_at))
                      .fontSize(11)
                      .fontColor(Constants.TEXT_SECONDARY)
                      .margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.End)

                  AvatarImage({ src: UrlUtils.getAvatarUrl(this.currentUser?.avatar_url), diameter: 36 })
                    .margin({ left: 8 })
                    .alignSelf(ItemAlign.Start)
                } else {
                  // 对方发送的消息 - 左侧
                  AvatarImage({ src: UrlUtils.getAvatarUrl(this.targetUser?.avatar_url), diameter: 36 })
                    .alignSelf(ItemAlign.Start)

                  Column() {
                    if (message.msg_type === 'song_share') {
                      this.SongShareCard(message, false)
                    } else {
                      Text(message.content)
                        .fontSize(15)
                        .fontColor(Constants.TEXT_PRIMARY)
                        .padding(12)
                        .backgroundColor(Constants.WHITE_COLOR)
                        .borderRadius({ topRight: 16, topLeft: 4, bottomRight: 16, bottomLeft: 16 })
                        .constraintSize({ maxWidth: '65%' })
                    }

                    Text(this.formatTime(message.created_at))
                      .fontSize(11)
                      .fontColor(Constants.TEXT_SECONDARY)
                      .margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .margin({ left: 8 })
                  Blank()
                }
              }
              .width('100%')
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor(Constants.BACKGROUND_COLOR)
        .listDirection(Axis.Vertical)

        // 输入框
        Row() {
          TextInput({ placeholder: '输入消息...', text: this.messageContent })
            .layoutWeight(1)
            .height(40)
            .backgroundColor(Constants.WHITE_COLOR)
            .borderRadius(20)
            .padding({ left: 16, right: 16 })
            .onChange((value: string) => {
              this.messageContent = value;
            })

          Button() {
            Text('发送')
              .fontSize(14)
              .fontColor(Constants.WHITE_COLOR)
          }
          .width(60)
          .height(40)
          .backgroundColor(this.isSending || !this.messageContent.trim() ? '#CCCCCC' : Constants.PRIMARY_COLOR)
          .borderRadius(20)
          .margin({ left: 8 })
          .enabled(!this.isSending && this.messageContent.trim().length > 0)
          .onClick(() => {
            this.handleSendMessage();
          })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor(Constants.WHITE_COLOR)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.BACKGROUND_COLOR)
  }
}
