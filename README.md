# QRSCAN (Flutter)

纯 Flutter 单栈版本（不再包含 uni-app/HBuilderX/Python 旧实现）。

## 目录
- 应用代码：`flutter_app/`
- GitHub Actions：`.github/workflows/flutter-android-build.yml`
- 云编译说明：`docs/FLUTTER_GITHUB_BUILD.md`

## 核心功能
- 扫描箱贴二维码
- 解析格式：`prefix + serial(10) + batch(7) + suffix(2)`
- 生成 20 条序列并定位扫描号
- 左右翻页预览二维码

## 无本地安卓环境的使用方式
1. 推送仓库到 GitHub
2. 打开 `Actions`
3. 运行 `Flutter Android Build`
4. 下载 artifact `qrscan-android-apk`

## 本地开发（可选）
```bash
cd flutter_app
flutter pub get
flutter run
```
