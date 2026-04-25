# QRSCAN (Flutter)

纯 Flutter 单栈版本（不再包含 uni-app/HBuilderX/Python 旧实现）。

## 目录
- 应用代码：`flutter_app/`
- GitHub Actions：`.github/workflows/flutter-android-build.yml`
- 云编译说明：`docs/FLUTTER_GITHUB_BUILD.md`

## 核心功能
- 相机扫描二维码
- 本地图片识别二维码
- 扫描框含上下移动扫描线
- 解析格式：`prefix + serial(10) + batch(7) + suffix(2)`
- 必须扫码/图片识别生成（不再内置默认配置）
- 预览从扫码号开始，第一页固定 `1/N`
- 新增随机按钮：开启后仅最后三位随机，前七位保持不变
- 自定义每组生成数量（例如 10、100）
- 自动滑动时间可设置（例如 0.5s / 1s / 2s / 自定义）
- 一组浏览完后可继续生成下一组
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
