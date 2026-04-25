# Flutter GitHub 云编译

项目已重构为 Flutter（主流方案），不再依赖 HBuilderX/uni-app 打包链。

## 目录
- Flutter 应用根目录：`flutter_app/`
- 云编译工作流：`.github/workflows/flutter-android-build.yml`

## 使用
1. 推送代码到 GitHub。
2. 打开 `Actions`。
3. 运行 `Flutter Android Build`。
4. 构建结束后下载 artifact：`qrscan-android-apk`。

## 工作流做了什么
1. 安装 Java 17。
2. 安装 Flutter stable。
3. 在 `flutter_app/` 执行 `flutter create` 生成 Android scaffold。
4. 执行 `flutter pub get`。
5. 执行 `flutter analyze`。
6. 执行 `flutter test`。
7. 执行 `flutter build apk --release`。
8. 上传 `app-release.apk`。

## 说明
- 当前仓库不要求本地安卓环境。
- 你可以完全依赖 GitHub Actions 得到 APK。
