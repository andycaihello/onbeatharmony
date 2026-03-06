/**
 * 首页
 */
import router from '@ohos.router';
import { AuthStore, MessageStore } from '../store/AppStore';
import { Constants } from '../common/Constants';
import { UserModel, SongModel, ArtistModel } from '../models/Models';
import { MusicAPI, FeedAPI, ActivityModel, SongsResponse, MessageAPI } from '../api/ApiService';
import { UrlUtils } from '../utils/UrlUtils';
import { AvatarImage } from '../components/AvatarImage';

@Entry
@Component
struct HomePage {
  @State currentTab: number = 0;
  @State currentUser: UserModel | null = null;
  @State trendingSongs: SongModel[] = [];
  @State latestSongs: SongModel[] = [];
  @State artists: ArtistModel[] = [];
  @State isLoading: boolean = true;
  @State unreadCount: number = 0;
  // 歌手展开状态
  @State expandedArtistId: number = -1;
  @State artistSongs: SongModel[] = [];
  @State loadingArtistSongs: boolean = false;

  @State friendsActivity: ActivityModel[] = [];

  private pollInterval: number = -1;

  aboutToAppear(): void {
    this.currentUser = AuthStore.getUser();
    this.unreadCount = MessageStore.getUnreadCount();
    this.fetchData();
    this.fetchUnreadCount();
    // 启动轮询（每5秒检查一次新消息）
    this.startPolling();
  }

  aboutToDisappear(): void {
    // 停止轮询
    this.stopPolling();
  }

  onPageShow(): void {
    // 页面显示时刷新未读消息数
    this.unreadCount = MessageStore.getUnreadCount();
    this.fetchUnreadCount();
  }

  // 启动轮询
  private startPolling(): void {
    this.pollInterval = setInterval(() => {
      this.fetchUnreadCount();
    }, 5000); // 每5秒轮询一次
  }

  // 停止轮询
  private stopPolling(): void {
    if (this.pollInterval !== -1) {
      clearInterval(this.pollInterval);
      this.pollInterval = -1;
    }
  }

  async fetchUnreadCount(): Promise<void> {
    try {
      const res = await MessageAPI.getUnreadCount();
      this.unreadCount = res.count;
      MessageStore.setUnreadCount(res.count);
    } catch (error) {
      console.error('Failed to fetch unread count: ' + (error as Error).message);
    }
  }

  async fetchData(): Promise<void> {
    this.isLoading = true;
    try {
      const trendingRes = await MusicAPI.getTrendingSongs();
      this.trendingSongs = trendingRes.songs;

      const latestRes = await MusicAPI.getLatestSongs();
      this.latestSongs = latestRes.songs;

      const artistsRes = await MusicAPI.getArtists();
      this.artists = artistsRes.artists;

      const activityRes = await FeedAPI.getFriendsActivity();
      this.friendsActivity = activityRes.activities;
    } catch (error) {
      console.error('Failed to fetch data: ' + (error as Error).message);
    } finally {
      this.isLoading = false;
    }
  }

  async toggleArtistExpand(artist: ArtistModel): Promise<void> {
    if (this.expandedArtistId === artist.id) {
      // 收起
      this.expandedArtistId = -1;
      this.artistSongs = [];
    } else {
      // 展开
      this.expandedArtistId = artist.id;
      this.loadingArtistSongs = true;
      this.artistSongs = [];
      try {
        const res = await MusicAPI.getArtistSongs(artist.id);
        this.artistSongs = res.songs;
      } catch (error) {
        console.error('Failed to fetch artist songs: ' + (error as Error).message);
      } finally {
        this.loadingArtistSongs = false;
      }
    }
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Row() {
          Image($r('app.media.icon'))
            .width(32)
            .height(32)
            .margin({ right: 8 })

          Text('Onbeat.合拍')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.PRIMARY_COLOR)
        }

        Blank()

        // 搜索按钮
        Button() {
          Text('搜索')
            .fontSize(14)
            .fontColor(Constants.TEXT_SECONDARY)
        }
        .width(60)
        .height(36)
        .backgroundColor(Constants.BACKGROUND_COLOR)
        .borderRadius(18)
        .onClick(() => {
          router.pushUrl({ url: 'pages/SearchPage' });
        })

        // 消息按钮（带未读数角标）
        Stack() {
          Button() {
            Text('消息')
              .fontSize(14)
              .fontColor(Constants.TEXT_SECONDARY)
          }
          .width(60)
          .height(36)
          .backgroundColor(Constants.BACKGROUND_COLOR)
          .borderRadius(18)
          .onClick(() => {
            router.pushUrl({ url: 'pages/MessagesPage' });
          })

          // 未读消息角标
          if (this.unreadCount > 0) {
            Text(this.unreadCount > 99 ? '99+' : this.unreadCount.toString())
              .fontSize(10)
              .fontColor(Constants.WHITE_COLOR)
              .backgroundColor(Constants.ERROR_COLOR)
              .borderRadius(10)
              .padding({ left: 5, right: 5, top: 2, bottom: 2 })
              .constraintSize({ minWidth: 16 })
              .position({ x: 48, y: -6 })
          }
        }
        .width(60)
        .height(36)
        .margin({ left: 8 })

        // 用户头像
        AvatarImage({ src: UrlUtils.getAvatarUrl(this.currentUser?.avatar_url), diameter: 32 })
          .margin({ left: 8 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/ProfilePage' });
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Constants.WHITE_COLOR)

      // Tab 栏
      Row() {
        ForEach(['推荐', '歌手', '动态', '最新'], (tab: string, index: number) => {
          Column() {
            Text(tab)
              .fontSize(15)
              .fontColor(this.currentTab === index ? Constants.PRIMARY_COLOR : Constants.TEXT_SECONDARY)
              .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)

            if (this.currentTab === index) {
              Divider()
                .width(20)
                .height(3)
                .color(Constants.PRIMARY_COLOR)
                .margin({ top: 4 })
            }
          }
          .padding({ left: 20, right: 20, top: 12, bottom: 12 })
          .onClick(() => {
            this.currentTab = index;
          })
        })
      }
      .width('100%')
      .backgroundColor(Constants.WHITE_COLOR)
      .justifyContent(FlexAlign.SpaceEvenly)

      // 内容区域
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(50)
            .height(50)
            .color(Constants.PRIMARY_COLOR)

          Text('加载中...')
            .fontSize(14)
            .fontColor(Constants.TEXT_SECONDARY)
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            if (this.currentTab === 0) {
              // 推荐页 - 热门歌曲
              Column() {
                Text('热门歌曲')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Constants.TEXT_PRIMARY)
                  .width('100%')
                  .padding({ left: 16, top: 16, bottom: 12 })
              }
              .width('100%')

              ForEach(this.trendingSongs, (song: SongModel, index: number) => {
                this.SongCard(song, index + 1)
              })
            } else if (this.currentTab === 1) {
              // 歌手页
              Column() {
                Text('歌手列表')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Constants.TEXT_PRIMARY)
                  .width('100%')
                  .padding({ left: 16, top: 16, bottom: 12 })
              }
              .width('100%')

              ForEach(this.artists, (artist: ArtistModel) => {
                Column() {
                  // 歌手卡片
                  this.ArtistCard(artist)

                  // 展开的歌曲列表
                  if (this.expandedArtistId === artist.id) {
                    Column() {
                      if (this.loadingArtistSongs) {
                        Row() {
                          LoadingProgress()
                            .width(24)
                            .height(24)
                            .color(Constants.PRIMARY_COLOR)
                          Text('加载中...')
                            .fontSize(14)
                            .fontColor(Constants.TEXT_SECONDARY)
                            .margin({ left: 8 })
                        }
                        .width('100%')
                        .justifyContent(FlexAlign.Center)
                        .padding(16)
                      } else if (this.artistSongs.length > 0) {
                        ForEach(this.artistSongs, (song: SongModel, index: number) => {
                          this.SongCardCompact(song, index + 1)
                        })
                      } else {
                        Text('暂无歌曲')
                          .fontSize(14)
                          .fontColor(Constants.TEXT_SECONDARY)
                          .width('100%')
                          .textAlign(TextAlign.Center)
                          .padding(16)
                      }
                    }
                    .width('100%')
                    .backgroundColor('#FAFAFA')
                    .padding({ left: 16, right: 16 })
                  }
                }
                .width('100%')
              })
            } else if (this.currentTab === 2) {
              // 好友动态
              if (this.friendsActivity.length === 0) {
                Column() {
                  Text('暂无好友动态')
                    .fontSize(14)
                    .fontColor(Constants.TEXT_SECONDARY)
                  Text('关注好友后，可以在这里看到他们最近在听什么歌曲')
                    .fontSize(12)
                    .fontColor(Constants.TEXT_SECONDARY)
                    .textAlign(TextAlign.Center)
                    .margin({ top: 8 })
                }
                .width('100%')
                .height(200)
                .justifyContent(FlexAlign.Center)
                .padding({ left: 32, right: 32 })
              } else {
                ForEach(this.friendsActivity, (activity: ActivityModel) => {
                  this.ActivityCard(activity)
                })
              }
            } else {
              // 最新歌曲
              Column() {
                Text('最新歌曲')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Constants.TEXT_PRIMARY)
                  .width('100%')
                  .padding({ left: 16, top: 16, bottom: 12 })
              }
              .width('100%')

              ForEach(this.latestSongs, (song: SongModel) => {
                this.SongCard(song)
              })
            }
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.BACKGROUND_COLOR)
  }

  @Builder
  ActivityCard(activity: ActivityModel) {
    Row() {
      // 用户头像
      AvatarImage({ src: UrlUtils.getAvatarUrl(activity.user.avatar_url), diameter: 44 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/UserDetailPage', params: { userId: activity.user.id } });
        })

      // 中间内容
      Column() {
        Row() {
          Text(activity.user.nickname || activity.user.username)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.TEXT_PRIMARY)
            .onClick(() => {
              router.pushUrl({ url: 'pages/UserDetailPage', params: { userId: activity.user.id } });
            })

          Text(activity.action_type === 'like' ? ' 喜欢了' : ' 播放了')
            .fontSize(14)
            .fontColor(Constants.TEXT_SECONDARY)

          if (this.currentUser != null && this.currentUser.id !== activity.user.id) {
            Button() {
              Text('私信')
                .fontSize(11)
                .fontColor(Constants.PRIMARY_COLOR)
            }
            .height(24)
            .padding({ left: 8, right: 8 })
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: Constants.PRIMARY_COLOR })
            .borderRadius(12)
            .margin({ left: 8 })
            .onClick(() => {
              router.pushUrl({ url: 'pages/ChatPage', params: { userId: activity.user.id } });
            })
          }
        }

        Text(activity.song.title + ' - ' + activity.song.artist.name)
          .fontSize(13)
          .fontColor(Constants.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })

        Text(this.formatActivityTime(activity.created_at))
          .fontSize(11)
          .fontColor(Constants.TEXT_SECONDARY)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12, right: 8 })

      // 歌曲封面
      Image(UrlUtils.getCoverUrl(activity.song.cover_url) || $r('app.media.icon'))
        .width(48)
        .height(48)
        .borderRadius(4)
        .objectFit(ImageFit.Cover)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Constants.WHITE_COLOR)
    .margin({ bottom: 1 })
    .onClick(() => {
      router.pushUrl({ url: 'pages/SongDetailPage', params: { songId: activity.song.id } });
    })
  }

  @Builder
  SongCard(song: SongModel, rank?: number) {
    Row() {
      // 排名
      if (rank !== undefined) {
        Text(rank.toString())
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(rank <= 3 ? Constants.ERROR_COLOR : Constants.TEXT_SECONDARY)
          .width(40)
          .textAlign(TextAlign.Center)
      }

      // 封面
      Image(UrlUtils.getCoverUrl(song.cover_url) || $r('app.media.icon'))
        .width(56)
        .height(56)
        .borderRadius(6)
        .objectFit(ImageFit.Cover)
        .margin({ left: rank !== undefined ? 8 : 0 })

      // 歌曲信息
      Column() {
        Text(song.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(song.artist?.name || '未知歌手')
          .fontSize(13)
          .fontColor(Constants.TEXT_SECONDARY)
          .margin({ top: 4 })

        Row() {
          Text(this.formatNumber(song.like_count) + ' 喜欢')
            .fontSize(12)
            .fontColor(Constants.TEXT_SECONDARY)

          Text(this.formatNumber(song.comment_count) + ' 评论')
            .fontSize(12)
            .fontColor(Constants.TEXT_SECONDARY)
            .margin({ left: 12 })

          Text(this.formatDuration(song.duration))
            .fontSize(12)
            .fontColor(Constants.TEXT_SECONDARY)
            .margin({ left: 12 })
        }
        .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12, right: 12 })

      // 播放按钮
      Button() {
        Text('播放')
          .fontSize(13)
          .fontColor(Constants.WHITE_COLOR)
      }
      .width(56)
      .height(32)
      .backgroundColor(Constants.PRIMARY_COLOR)
      .borderRadius(16)
      .onClick(() => {
        router.pushUrl({ url: 'pages/SongDetailPage', params: { songId: song.id, autoPlay: true } });
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(Constants.WHITE_COLOR)
    .margin({ bottom: 1 })
    .onClick(() => {
      router.pushUrl({ url: 'pages/SongDetailPage', params: { songId: song.id } });
    })
  }

  // 紧凑型歌曲卡片（用于歌手展开列表）
  @Builder
  SongCardCompact(song: SongModel, rank: number) {
    Row() {
      Text(rank.toString())
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(Constants.TEXT_SECONDARY)
        .width(24)

      Image(UrlUtils.getCoverUrl(song.cover_url) || $r('app.media.icon'))
        .width(44)
        .height(44)
        .borderRadius(4)
        .objectFit(ImageFit.Cover)
        .margin({ left: 8 })

      Column() {
        Text(song.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.formatDuration(song.duration))
          .fontSize(12)
          .fontColor(Constants.TEXT_SECONDARY)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12 })

      Button() {
        Text('播放')
          .fontSize(12)
          .fontColor(Constants.WHITE_COLOR)
      }
      .width(48)
      .height(28)
      .backgroundColor(Constants.PRIMARY_COLOR)
      .borderRadius(14)
      .onClick(() => {
        router.pushUrl({ url: 'pages/SongDetailPage', params: { songId: song.id, autoPlay: true } });
      })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .onClick(() => {
      router.pushUrl({ url: 'pages/SongDetailPage', params: { songId: song.id } });
    })
  }

  @Builder
  ArtistCard(artist: ArtistModel) {
    Row() {
      // 歌手头像
      AvatarImage({ src: UrlUtils.getAvatarUrl(artist.avatar_url), diameter: 56 })

      Column() {
        Text(artist.name)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.TEXT_PRIMARY)

        Row() {
          if (artist.genre) {
            Text(artist.genre)
              .fontSize(12)
              .fontColor(Constants.WHITE_COLOR)
              .backgroundColor(Constants.PRIMARY_COLOR)
              .borderRadius(4)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          }

          if (artist.country) {
            Text(artist.country)
              .fontSize(12)
              .fontColor(Constants.TEXT_SECONDARY)
              .margin({ left: 8 })
          }
        }
        .margin({ top: 4 })

        if (artist.bio) {
          Text(artist.bio)
            .fontSize(12)
            .fontColor(Constants.TEXT_SECONDARY)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12 })

      // 展开/收起箭头
      Text(this.expandedArtistId === artist.id ? '∧' : '>')
        .fontSize(20)
        .fontColor(Constants.TEXT_SECONDARY)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.expandedArtistId === artist.id ? '#E6F7FF' : Constants.WHITE_COLOR)
    .margin({ bottom: 1 })
    .onClick(() => {
      this.toggleArtistExpand(artist);
    })
  }

  private formatActivityTime(created_at: string): string {
    try {
      const tIdx = created_at.indexOf('T');
      if (tIdx < 0) return created_at;
      const datePart = created_at.substring(0, tIdx);
      const timePart = created_at.substring(tIdx + 1, tIdx + 6);
      const dateParts = datePart.split('-');
      if (dateParts.length < 3) return created_at;
      return dateParts[1] + '月' + dateParts[2] + '日 ' + timePart;
    } catch (e) {
      return created_at;
    }
  }

  private formatNumber(num: number): string {
    if (num >= 10000) {
      return (num / 10000).toFixed(1) + '万';
    }
    return num.toString();
  }

  private formatDuration(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return mins.toString() + ':' + (secs < 10 ? '0' : '') + secs.toString();
  }
}
