# Flutter GitHub 云编译

项目已重构为 Flutter（主流方案），不再依赖 HBuilderX/uni-app 打包链。

## 目录
- Flutter 应用根目录：`flutter_app/`
- 云编译工作流：`.github/workflows/flutter-android-build.yml`

## 使用
1. 推送代码到 GitHub。
2. 打开 `Actions`。
3. 运行 `Flutter Android Build`。
4. 普通开发流程：代码 push 到 `main` 后会自动构建并自动发布 Release，同时保留 artifact。
5. 手动触发 `workflow_dispatch` 也会发布 Release，可选择是否标记为预发布（`prerelease`）。

## 工作流做了什么
1. 安装 Java 17。
2. 安装 Flutter stable。
3. 在 `flutter_app/` 执行 `flutter pub get`。
4. 执行 `flutter analyze`。
5. 执行 `flutter test`。
6. 执行 `flutter build apk --release`。
7. 按版本重命名为 `洁美-v<version>.apk` 并上传 artifact。
8. 自动创建 Release 并上传 APK（无需手动创建 tag）。

## 发布策略（自动 Release，非手工 TAG）
- `push main`：自动构建 + 自动发布 Release + 上传 artifact。
- `workflow_dispatch`：手动触发也会发布 Release。
- Release 绑定的 tag 由工作流自动生成：`auto-v<version>-r<run_number>`。
- 不需要手工创建/维护任何 tag。

## 说明
- 当前仓库不要求本地安卓环境。
- 你可以完全依赖 GitHub Actions 得到 APK。
