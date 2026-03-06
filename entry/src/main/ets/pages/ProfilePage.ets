/**
 * 个人资料页面
 */
import router from '@ohos.router';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import fs from '@ohos.file.fs';
import promptAction from '@ohos.promptAction';
import { AuthStore } from '../store/AppStore';
import { Constants } from '../common/Constants';
import { UserModel } from '../models/Models';
import { UrlUtils } from '../utils/UrlUtils';
import { UserAPI, AuthAPI, SocialAPI, FollowersResponse, FollowingResponse } from '../api/ApiService';
import { AvatarImage } from '../components/AvatarImage';

@Entry
@Component
struct ProfilePage {
  @State currentUser: UserModel | null = null;
  @State followersCount: number = 0;
  @State followingCount: number = 0;
  @State isLoading: boolean = true;
  @State uploadLoading: boolean = false;

  aboutToAppear(): void {
    this.currentUser = AuthStore.getUser();
    this.fetchFollowStats();
  }

  async fetchFollowStats(): Promise<void> {
    if (!this.currentUser) return;
    try {
      const followersRes = await SocialAPI.getFollowers(this.currentUser.id);
      this.followersCount = followersRes.total;

      const followingRes = await SocialAPI.getFollowing(this.currentUser.id);
      this.followingCount = followingRes.total;
    } catch (error) {
      console.error('Failed to fetch follow stats: ' + (error as Error).message);
    } finally {
      this.isLoading = false;
    }
  }

  async pickAndUploadAvatar(): Promise<void> {
    try {
      const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result = await photoViewPicker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });
      if (!result.photoUris || result.photoUris.length === 0) {
        return;
      }

      this.uploadLoading = true;
      const srcUri = result.photoUris[0];

      // 读取图片文件数据
      const file = fs.openSync(srcUri, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      const fileBuffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, fileBuffer);
      fs.closeSync(file.fd);

      // 上传到服务器
      await UserAPI.uploadAvatar(fileBuffer);

      // 刷新用户信息
      const userRes = await AuthAPI.getCurrentUser();
      AuthStore.setUser(userRes.user);
      this.currentUser = userRes.user;

      promptAction.showToast({ message: '头像更新成功' });
    } catch (error) {
      promptAction.showToast({ message: '上传失败：' + (error as Error).message });
    } finally {
      this.uploadLoading = false;
    }
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

        Blank()

        Text('个人资料')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)

        Blank()

        Button() {
          Text('退出')
            .fontSize(16)
            .fontColor(Constants.ERROR_COLOR)
        }
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          AuthStore.logout();
          router.pushUrl({ url: 'pages/LoginPage' });
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .height(56)
      .backgroundColor(Constants.WHITE_COLOR)

      // 内容区域
      Scroll() {
        Column() {
          // 头像区域
          Column() {
            // 头像区域（可点击更换）
            Stack() {
              AvatarImage({ src: UrlUtils.getAvatarUrl(this.currentUser?.avatar_url), diameter: 100 })

              if (this.uploadLoading) {
                Column() {
                  LoadingProgress()
                    .width(36)
                    .height(36)
                    .color(Color.White)
                }
                .width(100)
                .height(100)
                .borderRadius(50)
                .backgroundColor('#80000000')
                .justifyContent(FlexAlign.Center)
              } else {
                Column() {
                  Image($r('app.media.ic_camera'))
                    .width(18)
                    .height(18)
                }
                .width(32)
                .height(32)
                .backgroundColor(Constants.PRIMARY_COLOR)
                .borderRadius(16)
                .border({ width: 2, color: Color.White })
                .justifyContent(FlexAlign.Center)
                .position({ x: 68, y: 68 })
              }
            }
            .width(100)
            .height(100)
            .margin({ bottom: 16 })
            .onClick(() => {
              if (!this.uploadLoading) {
                this.pickAndUploadAvatar();
              }
            })

            if (this.currentUser != null) {
              Text(this.currentUser.nickname || this.currentUser.username)
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor(Constants.TEXT_PRIMARY)
                .margin({ bottom: 8 })

              Text(this.currentUser.bio || '这个人很懒，什么都没写')
                .fontSize(14)
                .fontColor(Constants.TEXT_SECONDARY)
                .margin({ bottom: 16 })

              // 关注统计
              Row() {
                // 粉丝数
                Column() {
                  Text(this.followersCount.toString())
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Constants.PRIMARY_COLOR)
                  Text('粉丝')
                    .fontSize(14)
                    .fontColor(Constants.TEXT_SECONDARY)
                    .margin({ top: 4 })
                }
                .width(80)

                // 关注数
                Column() {
                  Text(this.followingCount.toString())
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Constants.PRIMARY_COLOR)
                  Text('关注')
                    .fontSize(14)
                    .fontColor(Constants.TEXT_SECONDARY)
                    .margin({ top: 4 })
                }
                .width(80)
              }
              .margin({ bottom: 24 })
            } else {
              Text('未登录')
                .fontSize(20)
                .fontColor(Constants.TEXT_SECONDARY)
            }
          }
          .width('100%')
          .padding(24)
          .justifyContent(FlexAlign.Center)

          // 详细信息卡片
          if (this.currentUser != null) {
            Column() {
              Text('详细信息')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(Constants.TEXT_PRIMARY)
                .width('100%')
                .margin({ bottom: 16 })

              this.InfoItem('用户名', this.currentUser.username)
              this.InfoItem('昵称', this.currentUser.nickname || '未设置')
              this.InfoItem('邮箱', this.currentUser.email)
              this.InfoItem('手机号', this.currentUser.phone || '未设置')
              this.InfoItem('个人简介', this.currentUser.bio || '未设置')
            }
            .width('100%')
            .padding(16)
            .backgroundColor(Constants.WHITE_COLOR)
            .borderRadius(12)
            .margin({ left: 16, right: 16 })
          }
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.BACKGROUND_COLOR)
  }

  @Builder
  InfoItem(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(Constants.TEXT_SECONDARY)
        .width(80)

      Text(value)
        .fontSize(14)
        .fontColor(Constants.TEXT_PRIMARY)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .border({ width: { bottom: 1 }, color: Constants.BACKGROUND_COLOR })
  }
}
