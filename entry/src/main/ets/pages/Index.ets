/**
 * 应用入口页面
 * 检查登录状态，自动跳转到对应页面
 */
import router from '@ohos.router';
import { AuthStore } from '../store/AppStore';
import { httpClient } from '../api/HttpClient';
import { AuthAPI } from '../api/ApiService';
import { Constants } from '../common/Constants';

@Entry
@Component
struct Index {
  @State isLoading: boolean = true;

  aboutToAppear(): void {
    this.checkAuthStatus();
  }

  async checkAuthStatus(): Promise<void> {
    // 检查是否有保存的 token
    if (httpClient.isAuthenticated()) {
      try {
        // 尝试获取用户信息
        const res = await AuthAPI.getCurrentUser();
        AuthStore.setUser(res.user);
        // 跳转到首页
        router.pushUrl({ url: 'pages/HomePage' });
      } catch (error) {
        // Token 无效，清除并跳转到登录页
        AuthStore.logout();
        router.pushUrl({ url: 'pages/LoginPage' });
      }
    } else {
      // 未登录，跳转到登录页
      router.pushUrl({ url: 'pages/LoginPage' });
    }
    this.isLoading = false;
  }

  build() {
    Column() {
      // Logo
      Image($r('app.media.icon'))
        .width(100)
        .height(100)
        .margin({ bottom: 24 })

      Text('Onbeat.合拍')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(Constants.TEXT_PRIMARY)
        .margin({ bottom: 8 })

      Text('发现音乐，分享快乐')
        .fontSize(14)
        .fontColor(Constants.TEXT_SECONDARY)
        .margin({ bottom: 32 })

      if (this.isLoading) {
        LoadingProgress()
          .width(40)
          .height(40)
          .color(Constants.PRIMARY_COLOR)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Constants.WHITE_COLOR)
  }
}
