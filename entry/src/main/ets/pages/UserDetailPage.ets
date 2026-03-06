/**
 * 用户详情页面
 */
import router from '@ohos.router';
import { Constants } from '../common/Constants';
import { AvatarImage } from '../components/AvatarImage';

@Entry
@Component
struct UserDetailPage {
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

        Text('用户详情')
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
      Column() {
        AvatarImage({ src: '', diameter: 100 })
          .margin({ bottom: 16 })

        Text('用户详情页面')
          .fontSize(20)
          .fontColor(Constants.TEXT_SECONDARY)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.BACKGROUND_COLOR)
  }
}
