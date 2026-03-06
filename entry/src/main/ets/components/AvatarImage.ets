/**
 * 头像组件：有 URL 时显示图片，无 URL 或加载失败时显示灰色圆形 + 白色人物占位
 */
@Component
export struct AvatarImage {
  @Watch('onSrcChange')
  @Prop src: string = ''
  @Prop diameter: number = 40
  @State loadFailed: boolean = false

  onSrcChange(): void {
    this.loadFailed = false
  }

  build() {
    Stack() {
      if (this.src.length > 0 && !this.loadFailed) {
        Image(this.src)
          .width(this.diameter)
          .height(this.diameter)
          .objectFit(ImageFit.Cover)
          .onError(() => {
            this.loadFailed = true
          })
      } else {
        Column() {
          // 头部
          Circle()
            .width(this.diameter * 0.34)
            .height(this.diameter * 0.34)
            .fill(Color.White)
            .margin({ bottom: this.diameter * 0.04 })
          // 肩膀
          Column()
            .width(this.diameter * 0.54)
            .height(this.diameter * 0.27)
            .backgroundColor(Color.White)
            .borderRadius({ topLeft: this.diameter * 0.27, topRight: this.diameter * 0.27 })
        }
        .width(this.diameter)
        .height(this.diameter)
        .backgroundColor('#BDBDBD')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding({ top: this.diameter * 0.1 })
      }
    }
    .width(this.diameter)
    .height(this.diameter)
    .borderRadius(this.diameter / 2)
    .clip(true)
  }
}
