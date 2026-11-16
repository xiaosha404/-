# PersonBox

一个完全在 iPhone 本地运行的 iOS 摄像头人体框选示例。

## 功能

- 使用 AVFoundation 获取后置摄像头画面
- 使用 Vision 检测人体矩形区域
- 使用绿色方框实时标出检测到的人
- 不上传摄像头画面

## GitHub Actions

工作流会在 macOS runner 上生成 Xcode 工程，编译未签名 App，并将 `PersonBox-unsigned.ipa` 上传为构建产物。

未签名 IPA 需要在安装前使用你的签名方式重新签名。

