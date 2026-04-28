# QRSCAN

面向仓库出入库与箱码管理的 Flutter 应用。

## 项目状态
- 技术栈：Flutter（单栈）
- 当前版本：`3.0.9`
- 变更记录：[CHANGELOG.md](C:/Users/Administrator/Desktop/QRSCAN/CHANGELOG.md)

## 核心能力
- QR 箱码扫描与图片识别
- QR 批量生成与预览（支持随机尾号、自动翻页、尺寸调节）
- 基础资料管理（产品、批号、TS 标识、库位、备注）
- 库存明细与分组查看（快捷筛选、批号级维护）
- 新增运单、订单状态管理、重复明细拦截
- 出库日历与出库明细追溯（按范围标题、按运单分组、商家标红、紧凑合计）
- 数据备份与局域网互传（二维码/配对码连接、自动发现、自动备份导入）

## 版本规则
- 使用三段式版本：`x.y.z`
- 默认补丁号递增：`2.0.1 -> 2.0.2`
- 需要功能升级时手动使用 `minor`/`major`
- 升版脚本：`./scripts/bump_version.ps1`
- Android `versionCode` 自动由 `x.y.z` 计算（`major*10000 + minor*100 + patch`），确保覆盖安装可升级
- 示例：
  - `./scripts/bump_version.ps1`（patch）
  - `./scripts/bump_version.ps1 -Part minor`
  - `./scripts/bump_version.ps1 -Part major`

## 目录说明
- 应用代码：`flutter_app/`
- 版本脚本：`scripts/bump_version.ps1`
- CI 构建：`.github/workflows/flutter-android-build.yml`
- 云编译说明：`docs/FLUTTER_GITHUB_BUILD.md`
- Android 固定签名说明：`docs/ANDROID_RELEASE_SIGNING.md`

## 本地开发
```bash
cd flutter_app
flutter pub get
flutter run
```

## 质量校验
```bash
cd flutter_app
flutter test
flutter analyze
```

## 无本地安卓环境发布
1. 推送到 GitHub 仓库。
2. 打开 `Actions`。
3. 运行 `Flutter Android Build`。
4. 下载产物 `qrscan-android-apk`。

## 维护约定
- 不做无必要工程化和过度优化。
- 需求变更优先保持交互直观、修改轻量、可回归验证。
