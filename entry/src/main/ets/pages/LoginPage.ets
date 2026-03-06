/**
 * 登录页面
 */
import router from '@ohos.router';
import { AuthAPI } from '../api/ApiService';
import { AuthStore } from '../store/AppStore';
import { Constants } from '../common/Constants';

@Entry
@Component
struct LoginPage {
  @State identifier: string = '';
  @State password: string = '';
  @State isLoading: boolean = false;
  @State errorMessage: string = '';
  @State isPasswordVisible: boolean = false;

  build() {
    Column() {
      // 顶部空白
      Blank()
        .layoutWeight(1)

      // Logo 和标题
      Column() {
        Image($r('app.media.icon'))
          .width(80)
          .height(80)
          .margin({ bottom: 20 })

        Text('Onbeat.合拍')
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.WHITE_COLOR)
          .margin({ bottom: 8 })

        Text('发现音乐，分享快乐')
          .fontSize(16)
          .fontColor('rgba(255,255,255,0.8)')
      }
      .margin({ bottom: 40 })

      // 登录卡片
      Column() {
        Text('登录')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.TEXT_PRIMARY)
          .margin({ bottom: 32 })

        // 用户名输入框
        TextInput({ placeholder: '邮箱或用户名', text: this.identifier })
          .width('100%')
          .height(50)
          .backgroundColor(Constants.BACKGROUND_COLOR)
          .borderRadius(8)
          .padding({ left: 16, right: 16 })
          .fontSize(16)
          .onChange((value: string) => {
            this.identifier = value;
            this.errorMessage = '';
          })
          .margin({ bottom: 16 })

        // 密码输入框
        Row() {
          TextInput({ placeholder: '密码', text: this.password })
            .width('100%')
            .height(50)
            .backgroundColor(Constants.BACKGROUND_COLOR)
            .borderRadius(8)
            .padding({ left: 16, right: 60 })
            .fontSize(16)
            .type(this.isPasswordVisible ? InputType.Normal : InputType.Password)
            .onChange((value: string) => {
              this.password = value;
              this.errorMessage = '';
            })

          Button(this.isPasswordVisible ? '隐藏' : '显示')
            .width(50)
            .height(30)
            .fontSize(12)
            .fontColor(Constants.TEXT_SECONDARY)
            .backgroundColor(Color.Transparent)
            .position({ x: '100%', y: '50%' })
            .translate({ x: -60, y: '-50%' })
            .onClick(() => {
              this.isPasswordVisible = !this.isPasswordVisible;
            })
        }
        .width('100%')
        .margin({ bottom: 12 })

        // 错误消息
        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor(Constants.ERROR_COLOR)
            .width('100%')
            .margin({ bottom: 12 })
        }

        // 忘记密码
        Row() {
          Blank()
          Text('忘记密码?')
            .fontSize(14)
            .fontColor(Constants.PRIMARY_COLOR)
        }
        .width('100%')
        .margin({ bottom: 24 })

        // 登录按钮
        Button(this.isLoading ? '登录中...' : '登录')
          .width('100%')
          .height(50)
          .fontSize(18)
          .fontColor(Constants.WHITE_COLOR)
          .backgroundColor(this.isLoading ? '#CCCCCC' : Constants.PRIMARY_COLOR)
          .borderRadius(25)
          .enabled(!this.isLoading)
          .onClick(() => {
            this.handleLogin();
          })
          .margin({ bottom: 24 })

        // 注册链接
        Row() {
          Text('还没有账号? ')
            .fontSize(14)
            .fontColor(Constants.TEXT_SECONDARY)
          Text('立即注册')
            .fontSize(14)
            .fontColor(Constants.PRIMARY_COLOR)
            .onClick(() => {
              router.pushUrl({ url: 'pages/RegisterPage' });
            })
        }
      }
      .width('85%')
      .backgroundColor(Constants.WHITE_COLOR)
      .borderRadius(16)
      .padding(24)
      .shadow({
        radius: 20,
        color: 'rgba(0,0,0,0.15)',
        offsetX: 0,
        offsetY: 10
      })

      // 底部空白
      Blank()
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 135,
      colors: [[Constants.GRADIENT_START, 0], [Constants.GRADIENT_END, 1]]
    })
  }

  private handleLogin(): void {
    if (this.identifier.trim().length === 0) {
      this.errorMessage = '请输入邮箱或用户名';
      return;
    }
    if (this.password.trim().length === 0) {
      this.errorMessage = '请输入密码';
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';

    AuthAPI.login(this.identifier.trim(), this.password)
      .then((response) => {
        AuthStore.login(response.user, response.access_token, response.refresh_token);
        router.pushUrl({ url: 'pages/HomePage' });
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '登录失败，请检查用户名和密码';
      })
      .finally(() => {
        this.isLoading = false;
      });
  }
}
