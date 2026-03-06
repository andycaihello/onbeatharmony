/**
 * 注册页面
 */
import router from '@ohos.router';
import { AuthAPI } from '../api/ApiService';
import { AuthStore } from '../store/AppStore';
import { Constants } from '../common/Constants';

@Entry
@Component
struct RegisterPage {
  @State username: string = '';
  @State email: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';
  @State isLoading: boolean = false;
  @State errorMessage: string = '';

  build() {
    Column() {
      Blank().layoutWeight(1)

      Column() {
        Text('注册')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.WHITE_COLOR)
          .margin({ bottom: 8 })

        Text('加入 Onbeat.合拍，开启音乐之旅')
          .fontSize(14)
          .fontColor('rgba(255,255,255,0.8)')
      }
      .margin({ bottom: 32 })

      Column() {
        Text('创建账号')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 24 })

        TextInput({ placeholder: '用户名', text: this.username })
          .width('100%')
          .height(50)
          .backgroundColor(Constants.BACKGROUND_COLOR)
          .borderRadius(8)
          .margin({ bottom: 12 })
          .onChange((value: string) => {
            this.username = value;
          })

        TextInput({ placeholder: '邮箱', text: this.email })
          .width('100%')
          .height(50)
          .backgroundColor(Constants.BACKGROUND_COLOR)
          .borderRadius(8)
          .margin({ bottom: 12 })
          .onChange((value: string) => {
            this.email = value;
          })

        TextInput({ placeholder: '密码', text: this.password })
          .width('100%')
          .height(50)
          .backgroundColor(Constants.BACKGROUND_COLOR)
          .borderRadius(8)
          .margin({ bottom: 12 })
          .type(InputType.Password)
          .onChange((value: string) => {
            this.password = value;
          })

        TextInput({ placeholder: '确认密码', text: this.confirmPassword })
          .width('100%')
          .height(50)
          .backgroundColor(Constants.BACKGROUND_COLOR)
          .borderRadius(8)
          .margin({ bottom: 12 })
          .type(InputType.Password)
          .onChange((value: string) => {
            this.confirmPassword = value;
          })

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor(Constants.ERROR_COLOR)
            .margin({ bottom: 12 })
        }

        Button(this.isLoading ? '注册中...' : '注册')
          .width('100%')
          .height(50)
          .fontSize(18)
          .fontColor(Constants.WHITE_COLOR)
          .backgroundColor(this.isLoading ? '#CCCCCC' : Constants.PRIMARY_COLOR)
          .borderRadius(25)
          .enabled(!this.isLoading)
          .margin({ bottom: 20 })
          .onClick(() => {
            this.handleRegister();
          })

        Row() {
          Text('已有账号? ')
            .fontSize(14)
            .fontColor(Constants.TEXT_SECONDARY)
          Text('立即登录')
            .fontSize(14)
            .fontColor(Constants.PRIMARY_COLOR)
            .onClick(() => {
              router.back();
            })
        }
      }
      .width('85%')
      .backgroundColor(Constants.WHITE_COLOR)
      .borderRadius(16)
      .padding(24)

      Blank().layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 135,
      colors: [[Constants.GRADIENT_START, 0], [Constants.GRADIENT_END, 1]]
    })
  }

  private handleRegister(): void {
    if (this.username.trim().length < 3) {
      this.errorMessage = '用户名至少3个字符';
      return;
    }
    if (this.email.trim().length === 0) {
      this.errorMessage = '请输入邮箱';
      return;
    }
    if (this.password.length < 6) {
      this.errorMessage = '密码至少6个字符';
      return;
    }
    if (this.password !== this.confirmPassword) {
      this.errorMessage = '两次密码不一致';
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';

    AuthAPI.register(this.username.trim(), this.email.trim(), this.password)
      .then((response) => {
        AuthStore.login(response.user, response.access_token, response.refresh_token);
        router.pushUrl({ url: 'pages/HomePage' });
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '注册失败';
      })
      .finally(() => {
        this.isLoading = false;
      });
  }
}
