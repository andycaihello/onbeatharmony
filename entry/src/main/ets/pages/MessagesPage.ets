/**
 * 消息列表页面
 */
import router from '@ohos.router';
import { Constants } from '../common/Constants';
import { ConversationModel, UserModel } from '../models/Models';
import { MessageAPI } from '../api/ApiService';
import { UrlUtils } from '../utils/UrlUtils';
import { AuthStore } from '../store/AppStore';
import { WebSocketService, MessageCallback } from '../services/WebSocketService';
import { AvatarImage } from '../components/AvatarImage';

@Entry
@Component
struct MessagesPage {
  @State conversations: ConversationModel[] = [];
  @State isLoading: boolean = true;
  @State currentUser: UserModel | null = null;

  private wsCallback: MessageCallback = (_message: object) => {};

  aboutToAppear(): void {
    this.currentUser = AuthStore.getUser();
    this.fetchConversations();

    // 注册 WebSocket 回调：收到新消息时刷新会话列表
    this.wsCallback = (_message: object) => {
      this.fetchConversations();
    };

    WebSocketService.getInstance().addMessageCallback(this.wsCallback);
    WebSocketService.getInstance().connect();
  }

  // 从 ChatPage 返回时触发，刷新会话列表以更新未读数
  onPageShow(): void {
    this.fetchConversations();
  }

  aboutToDisappear(): void {
    WebSocketService.getInstance().removeMessageCallback(this.wsCallback);
  }

  async fetchConversations(): Promise<void> {
    this.isLoading = true;
    try {
      this.conversations = await MessageAPI.getConversations();
    } catch (error) {
      console.error('Failed to fetch conversations: ' + (error as Error).message);
    } finally {
      this.isLoading = false;
    }
  }

  private formatTime(dateString: string): string {
    const date = new Date(dateString);
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));

    if (days === 0) {
      const hours = Math.floor(diff / (1000 * 60 * 60));
      if (hours === 0) {
        const minutes = Math.floor(diff / (1000 * 60));
        if (minutes < 1) return '刚刚';
        return minutes.toString() + '分钟前';
      }
      return hours.toString() + '小时前';
    }
    if (days === 1) return '昨天';
    if (days < 7) return days.toString() + '天前';
    return date.toLocaleDateString();
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

        Text('私信')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 12 })
          .layoutWeight(1)
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
      } else if (this.conversations.length > 0) {
        // 会话列表
        List() {
          ForEach(this.conversations, (conversation: ConversationModel) => {
            ListItem() {
              Row() {
                // 头像
                Stack() {
                  AvatarImage({ src: UrlUtils.getAvatarUrl(conversation.user?.avatar_url), diameter: 56 })

                  // 未读消息数角标
                  if (conversation.unread_count > 0) {
                    Text(conversation.unread_count > 99 ? '99+' : conversation.unread_count.toString())
                      .fontSize(11)
                      .fontColor(Constants.WHITE_COLOR)
                      .backgroundColor(Constants.ERROR_COLOR)
                      .borderRadius(10)
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .position({ x: 44, y: 0 })
                  }
                }
                .width(56)
                .height(56)

                // 用户信息和最后消息
                Column() {
                  Row() {
                    Text(conversation.user?.nickname || conversation.user?.username || '用户')
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Constants.TEXT_PRIMARY)
                      .layoutWeight(1)

                    Text(this.formatTime(conversation.last_message?.created_at || ''))
                      .fontSize(12)
                      .fontColor(Constants.TEXT_SECONDARY)
                  }
                  .width('100%')

                  Text(conversation.last_message?.content || '')
                    .fontSize(14)
                    .fontColor(Constants.TEXT_SECONDARY)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 4 })
                    .width('100%')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                .padding({ left: 12 })
                .justifyContent(FlexAlign.Center)
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .backgroundColor(Constants.WHITE_COLOR)
              .onClick(() => {
                if (conversation.user?.id) {
                  router.pushUrl({ url: 'pages/ChatPage', params: { userId: conversation.user.id } });
                }
              })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 1, color: Constants.BACKGROUND_COLOR })
      } else {
        // 空状态
        Column() {
          Image($r('app.media.icon'))
            .width(80)
            .height(80)
            .opacity(0.3)

          Text('暂无私信')
            .fontSize(16)
            .fontColor(Constants.TEXT_SECONDARY)
            .margin({ top: 16 })

          Text('关注其他用户后，可以在这里发送私信')
            .fontSize(14)
            .fontColor(Constants.TEXT_SECONDARY)
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.BACKGROUND_COLOR)
  }
}
