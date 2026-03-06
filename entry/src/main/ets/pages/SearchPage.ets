/**
 * 搜索页面
 */
import router from '@ohos.router';
import { Constants } from '../common/Constants';
import { UserModel, SongModel, ArtistModel } from '../models/Models';
import { MusicAPI, SearchUserAPI, SocialAPI, SearchResponse, UserSearchResponse } from '../api/ApiService';
import { UrlUtils } from '../utils/UrlUtils';
import { AuthStore } from '../store/AppStore';
import { AvatarImage } from '../components/AvatarImage';

// 关注状态项
class FollowStatusItem {
  userId: number = 0;
  isFollowing: boolean = false;

  constructor(userId: number, isFollowing: boolean) {
    this.userId = userId;
    this.isFollowing = isFollowing;
  }
}

@Entry
@Component
struct SearchPage {
  @State searchQuery: string = '';
  @State currentTab: number = 0; // 0=全部 1=歌曲 2=歌手 3=用户
  @State songs: SongModel[] = [];
  @State artists: ArtistModel[] = [];
  @State users: UserModel[] = [];
  @State songsTotal: number = 0;
  @State artistsTotal: number = 0;
  @State usersTotal: number = 0;
  @State isLoading: boolean = false;
  @State hasSearched: boolean = false;
  @State currentUser: UserModel | null = null;

  // 当前 Tab 实际显示的数组（空数组 = 不渲染，彻底避免 ForEach 占位问题）
  @State displaySongs: SongModel[] = [];
  @State displayArtists: ArtistModel[] = [];
  @State displayUsers: UserModel[] = [];

  // 歌手展开状态
  @State expandedArtistId: number = -1;
  @State artistSongs: SongModel[] = [];
  @State loadingArtistSongs: boolean = false;

  // 用户关注状态
  @State followStatusList: FollowStatusItem[] = [];

  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.currentUser = AuthStore.getUser();
  }

  async performSearch(): Promise<void> {
    const q = this.searchQuery.trim();
    if (!q) return;

    this.isLoading = true;
    this.hasSearched = true;
    this.expandedArtistId = -1;
    this.artistSongs = [];
    this.followStatusList = [];

    try {
      const musicRes = await MusicAPI.search(q, 'all');
      this.songs = musicRes.songs || [];
      this.artists = musicRes.artists || [];
      this.songsTotal = musicRes.songs_total || 0;
      this.artistsTotal = musicRes.artists_total || 0;

      const userRes = await SearchUserAPI.searchUsers(q);
      this.users = userRes.users || [];
      this.usersTotal = userRes.total || 0;

      // 获取用户关注状态
      await this.fetchFollowStatus();
      this.updateDisplay();
    } catch (error) {
      console.error('Search failed: ' + (error as Error).message);
    } finally {
      this.isLoading = false;
      this.scroller.scrollEdge(Edge.Top);
    }
  }

  private updateDisplay(): void {
    this.displaySongs = (this.currentTab === 0 || this.currentTab === 1) ? this.songs : [];
    this.displayArtists = (this.currentTab === 0 || this.currentTab === 2) ? this.artists : [];
    this.displayUsers = (this.currentTab === 0 || this.currentTab === 3) ? this.users : [];
  }

  async fetchFollowStatus(): Promise<void> {
    if (!this.currentUser) return;
    for (const u of this.users) {
      if (u.id !== this.currentUser.id) {
        try {
          const res = await SocialAPI.isFollowing(u.id);
          this.followStatusList = [...this.followStatusList, new FollowStatusItem(u.id, res.is_following)];
        } catch (_e) {
          this.followStatusList = [...this.followStatusList, new FollowStatusItem(u.id, false)];
        }
      }
    }
  }

  private getFollowStatus(userId: number): boolean {
    for (const item of this.followStatusList) {
      if (item.userId === userId) return item.isFollowing;
    }
    return false;
  }

  private setFollowStatus(userId: number, isFollowing: boolean): void {
    const newList: FollowStatusItem[] = [];
    let found = false;
    for (const item of this.followStatusList) {
      if (item.userId === userId) {
        newList.push(new FollowStatusItem(userId, isFollowing));
        found = true;
      } else {
        newList.push(item);
      }
    }
    if (!found) newList.push(new FollowStatusItem(userId, isFollowing));
    this.followStatusList = newList;
  }

  async toggleArtistExpand(artist: ArtistModel): Promise<void> {
    if (this.expandedArtistId === artist.id) {
      this.expandedArtistId = -1;
      this.artistSongs = [];
    } else {
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

  async handleFollow(userId: number): Promise<void> {
    if (!this.currentUser) return;
    try {
      if (this.getFollowStatus(userId)) {
        await SocialAPI.unfollowUser(userId);
        this.setFollowStatus(userId, false);
      } else {
        await SocialAPI.followUser(userId);
        this.setFollowStatus(userId, true);
      }
    } catch (error) {
      console.error('Failed to toggle follow: ' + (error as Error).message);
    }
  }

  private getTotalCount(): number {
    return this.songsTotal + this.artistsTotal + this.usersTotal;
  }

  private formatNumber(num: number): string {
    if (num >= 10000) return (num / 10000).toFixed(1) + '万';
    return num.toString();
  }

  private formatDuration(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return mins.toString() + ':' + (secs < 10 ? '0' : '') + secs.toString();
  }

  build() {
    Column() {
      // 搜索栏
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

        TextInput({ placeholder: '搜索歌曲、歌手或用户', text: this.searchQuery })
          .layoutWeight(1)
          .height(40)
          .backgroundColor(Constants.BACKGROUND_COLOR)
          .borderRadius(20)
          .padding({ left: 16, right: 16 })
          .margin({ left: 8, right: 8 })
          .onChange((value: string) => {
            this.searchQuery = value;
          })
          .onSubmit((_enterKey: EnterKeyType) => {
            this.performSearch();
          })

        Button() {
          Text('搜索')
            .fontSize(14)
            .fontColor(Constants.WHITE_COLOR)
        }
        .width(60)
        .height(40)
        .backgroundColor(Constants.PRIMARY_COLOR)
        .borderRadius(20)
        .onClick(() => {
          this.performSearch();
        })
      }
      .width('100%')
      .padding({ left: 8, right: 16, top: 8, bottom: 8 })
      .backgroundColor(Constants.WHITE_COLOR)

      // Tab 栏（搜索后显示）
      if (this.hasSearched) {
        Row() {
          ForEach(
            [
              '全部(' + this.getTotalCount().toString() + ')',
              '歌曲(' + this.songsTotal.toString() + ')',
              '歌手(' + this.artistsTotal.toString() + ')',
              '用户(' + this.usersTotal.toString() + ')'
            ],
            (tab: string, index: number) => {
              Column() {
                Text(tab)
                  .fontSize(13)
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
              .padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .onClick(() => {
                this.currentTab = index;
                this.updateDisplay();
                this.scroller.scrollEdge(Edge.Top);
              })
            }
          )
        }
        .width('100%')
        .backgroundColor(Constants.WHITE_COLOR)
        .justifyContent(FlexAlign.SpaceEvenly)
      }

      // 内容区域
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(50)
            .height(50)
            .color(Constants.PRIMARY_COLOR)
          Text('搜索中...')
            .fontSize(14)
            .fontColor(Constants.TEXT_SECONDARY)
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (!this.hasSearched) {
        // 初始状态
        Column() {
          Text('🎵')
            .fontSize(48)
            .margin({ bottom: 16 })
          Text('搜索歌曲、歌手或用户')
            .fontSize(16)
            .fontColor(Constants.TEXT_SECONDARY)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.getTotalCount() === 0) {
        // 无结果
        Column() {
          Text('未找到相关结果')
            .fontSize(16)
            .fontColor(Constants.TEXT_SECONDARY)
          Text('试试其他关键词？')
            .fontSize(13)
            .fontColor(Constants.TEXT_SECONDARY)
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll(this.scroller) {
          Column() {
            // 歌曲 section header（仅全部 Tab 显示）
            if (this.currentTab === 0 && this.displaySongs.length > 0) {
              Text('歌曲')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(Constants.TEXT_PRIMARY)
                .width('100%')
                .padding({ left: 16, top: 16, bottom: 8 })
            }
            ForEach(this.displaySongs, (song: SongModel) => {
              this.SongCard(song)
            })

            // 歌手 section header（仅全部 Tab 显示）
            if (this.currentTab === 0 && this.displayArtists.length > 0) {
              Text('歌手')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(Constants.TEXT_PRIMARY)
                .width('100%')
                .padding({ left: 16, top: 16, bottom: 8 })
            }
            ForEach(this.displayArtists, (artist: ArtistModel) => {
              Column() {
                this.ArtistCard(artist)
                if (this.expandedArtistId === artist.id) {
                  this.ArtistSongsPanel()
                }
              }
              .width('100%')
            })

            // 用户 section header（仅全部 Tab 显示）
            if (this.currentTab === 0 && this.displayUsers.length > 0) {
              Text('用户')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(Constants.TEXT_PRIMARY)
                .width('100%')
                .padding({ left: 16, top: 16, bottom: 8 })
            }
            ForEach(this.displayUsers, (user: UserModel) => {
              this.UserCard(user)
            })
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .backgroundColor(Constants.BACKGROUND_COLOR)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.BACKGROUND_COLOR)
  }

  @Builder
  ArtistSongsPanel() {
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
        ForEach(this.artistSongs, (song: SongModel, idx: number) => {
          this.ArtistSongCard(song, idx + 1)
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

  @Builder
  SongCard(song: SongModel) {
    Row() {
      Image(UrlUtils.getCoverUrl(song.cover_url) || $r('app.media.icon'))
        .width(52)
        .height(52)
        .borderRadius(6)
        .objectFit(ImageFit.Cover)

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

  @Builder
  ArtistCard(artist: ArtistModel) {
    Row() {
      AvatarImage({ src: UrlUtils.getAvatarUrl(artist.avatar_url), diameter: 52 })

      Column() {
        Text(artist.name)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.TEXT_PRIMARY)

        Row() {
          if (artist.genre) {
            Text(artist.genre)
              .fontSize(12)
              .fontColor(Constants.WHITE_COLOR)
              .backgroundColor(Constants.PRIMARY_COLOR)
              .borderRadius(4)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          }
          if (artist.country) {
            Text(artist.country)
              .fontSize(12)
              .fontColor(Constants.TEXT_SECONDARY)
              .margin({ left: 8 })
          }
        }
        .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12 })

      Text(this.expandedArtistId === artist.id ? '∧' : '>')
        .fontSize(18)
        .fontColor(Constants.TEXT_SECONDARY)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.expandedArtistId === artist.id ? '#E6F7FF' : Constants.WHITE_COLOR)
    .margin({ bottom: 1 })
    .onClick(() => {
      this.toggleArtistExpand(artist);
    })
  }

  @Builder
  ArtistSongCard(song: SongModel, rank: number) {
    Row() {
      Text(rank.toString())
        .fontSize(15)
        .fontColor(Constants.TEXT_SECONDARY)
        .width(24)

      Image(UrlUtils.getCoverUrl(song.cover_url) || $r('app.media.icon'))
        .width(40)
        .height(40)
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
      .padding({ left: 10 })

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
  UserCard(user: UserModel) {
    Row() {
      AvatarImage({ src: UrlUtils.getAvatarUrl(user.avatar_url), diameter: 52 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/UserDetailPage', params: { userId: user.id } });
        })

      Column() {
        Text(user.nickname || user.username)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (user.bio) {
          Text(user.bio)
            .fontSize(12)
            .fontColor(Constants.TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/UserDetailPage', params: { userId: user.id } });
      })

      // 操作按钮（非本人）
      if (this.currentUser && user.id !== this.currentUser.id) {
        Column() {
          Button() {
            Text(this.getFollowStatus(user.id) ? '已关注' : '关注')
              .fontSize(12)
              .fontColor(this.getFollowStatus(user.id) ? Constants.TEXT_SECONDARY : Constants.WHITE_COLOR)
          }
          .width(64)
          .height(30)
          .backgroundColor(this.getFollowStatus(user.id) ? Constants.BACKGROUND_COLOR : Constants.PRIMARY_COLOR)
          .borderRadius(15)
          .onClick(() => {
            this.handleFollow(user.id);
          })

          Button() {
            Text('私信')
              .fontSize(12)
              .fontColor(Constants.PRIMARY_COLOR)
          }
          .width(64)
          .height(30)
          .backgroundColor('#E6F7FF')
          .borderRadius(15)
          .margin({ top: 6 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/ChatPage', params: { userId: user.id } });
          })
        }
        .alignItems(HorizontalAlign.End)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(Constants.WHITE_COLOR)
    .margin({ bottom: 1 })
  }
}
