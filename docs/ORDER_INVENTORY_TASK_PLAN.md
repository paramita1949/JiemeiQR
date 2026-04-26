# 洁美订单信息与库存功能 TASK 计划表

更新时间：2026-04-26

## 阶段总览

| 阶段 | 目标 | 状态 | 说明 |
| --- | --- | --- | --- |
| P0 | 需求定稿 | 进行中 | 已整理当前需求，功能调用关系已补流程图 |
| P1 | 数据模型与本地数据库 | 未开始 | SQLite + drift，建立产品、批号、订单、库存流水 |
| P2 | 产品基础资料 | 未开始 | 手动维护产品、批号、库存、位置 |
| P3 | 订单信息 | 未开始 | 按日期录入运单，支持未完成/已拣货/完成 |
| P4 | 库存扣减与流水 | 未开始 | 标记完成后扣库存，支持移库出库和损耗调整 |
| P5 | 出库日历与历史库存 | 未开始 | 按日期动态计算总库存和批号库存 |
| P6 | 备份、导入、局域网迁移 | 未开始 | 完整备份、恢复、发送/接收迁移 |
| P7 | 测试、打包、Release | 未开始 | 本地测试和 GitHub Actions Release |

## P0 需求定稿

| ID | 任务 | 产出 | 状态 |
| --- | --- | --- | --- |
| P0-1 | 确认板数合计规则 | 批号分别计算或同产品合并计算 | 待确认 |
| P0-2 | 确认已完成订单修改规则 | 是否允许撤回、修改、删除 | 待确认 |
| P0-3 | 确认位置层级 | 批号是否允许多个位置 | 待确认 |
| P0-4 | 确认第一版导出范围 | 订单、库存、流水、日历统计 | 待确认 |
| P0-5 | 固化需求文档 | `docs/ORDER_INVENTORY_REQUIREMENTS.md` | 已完成 |
| P0-6 | 固化功能调用关系 | `docs/FUNCTION_FLOW_AND_COMPONENT_LOGIC.md` | 已完成 |

## P1 数据模型与本地数据库

| ID | 任务 | 主要文件 | 验收标准 | 状态 |
| --- | --- | --- | --- | --- |
| P1-1 | 引入 drift / SQLite 依赖 | `flutter_app/pubspec.yaml` | `flutter pub get` 成功 | 未开始 |
| P1-2 | 建立数据库入口 | `lib/data/app_database.dart` | App 可打开本地数据库 | 未开始 |
| P1-3 | 建立产品表 | `lib/data/tables/products.dart` | 可增删改查产品 | 未开始 |
| P1-4 | 建立批号表 | `lib/data/tables/batches.dart` | 批号关联产品，包含日期批号、实际批号、位置、初始库存 | 未开始 |
| P1-5 | 建立订单表 | `lib/data/tables/orders.dart` | 支持日期、运单号、商家简称、状态 | 未开始 |
| P1-6 | 建立订单明细表 | `lib/data/tables/order_items.dart` | 支持产品、批号、箱数、规格 | 未开始 |
| P1-7 | 建立库存流水表 | `lib/data/tables/stock_movements.dart` | 支持订单出库、移库出库、损耗调整、入库调整 | 未开始 |
| P1-8 | 建立数据库迁移机制 | `lib/data/app_database.dart` | 后续加字段不会丢数据 | 未开始 |

## P2 产品基础资料

| ID | 任务 | 主要文件 | 验收标准 | 状态 |
| --- | --- | --- | --- | --- |
| P2-1 | 产品列表页面 | `lib/screens/products/product_list_screen.dart` | 显示产品代码、名称、规格、总库存 | 未开始 |
| P2-2 | 产品编辑页面 | `lib/screens/products/product_edit_screen.dart` | 可新增和修改产品 | 未开始 |
| P2-3 | 批号列表页面 | `lib/screens/products/batch_list_screen.dart` | 按产品显示批号、日期批号、实际批号、库存、位置 | 未开始 |
| P2-4 | 批号编辑页面 | `lib/screens/products/batch_edit_screen.dart` | 可维护初始库存、位置、备注 | 未开始 |
| P2-5 | 库存为 0 标红 | 批号列表 | 库存归零显示红色“已归零” | 未开始 |
| P2-6 | 产品搜索 | 产品选择组件 | 可按代码或名称搜索 | 未开始 |
| P2-7 | 批号搜索 | 批号选择组件 | 可按日期批号、实际批号、位置搜索 | 未开始 |

## P3 订单信息

| ID | 任务 | 主要文件 | 验收标准 | 状态 |
| --- | --- | --- | --- | --- |
| P3-1 | 订单信息 | `lib/features/orders/order_list_screen.dart` | 支持日期/范围和未完成/已拣货/完成筛选 | 未开始 |
| P3-2 | 日期切换 | 订单首页 | 可切换任意日期 | 未开始 |
| P3-3 | 新增运单 | `lib/screens/orders/order_edit_screen.dart` | 输入运单号、商家简称、日期 | 未开始 |
| P3-4 | 运单详情 | `lib/screens/orders/order_detail_screen.dart` | 显示明细、合计箱数、板数 | 未开始 |
| P3-5 | 添加明细 | `lib/screens/orders/order_item_edit_sheet.dart` | 选择产品、批号、位置、输入箱数 | 未开始 |
| P3-6 | 批号可选规则 | 批号选择组件 | 只显示订单日期库存大于 0 的批号 | 未开始 |
| P3-7 | 库存不足校验 | 订单明细保存 | 输入箱数超过可用库存时禁止保存 | 未开始 |
| P3-8 | 板数计算 | `lib/services/board_calculator.dart` | 正确输出 `X板+Y箱`、`X板`、`Y箱` | 未开始 |
| P3-9 | 状态切换 | 运单详情 | 可标记未完成/已拣货，点击完成后确认并扣库存 | 未开始 |

## P4 库存扣减与流水

| ID | 任务 | 主要文件 | 验收标准 | 状态 |
| --- | --- | --- | --- | --- |
| P4-1 | 完成订单生成流水 | `lib/services/order_completion_service.dart` | 标记完成后生成订单出库流水 | 未开始 |
| P4-2 | 防止重复扣减 | 完成订单服务 | 已完成订单再次点击不会重复扣库存 | 未开始 |
| P4-3 | 订单撤回规则 | 完成订单服务 | 如允许撤回，库存流水可反冲或删除 | 未开始 |
| P4-4 | 移库出库页面 | `lib/screens/stock/movement_edit_screen.dart` | 选择批号、输入数量、备注，扣减库存 | 未开始 |
| P4-5 | 损耗调整页面 | 库存调整页面 | 可记录损耗并扣减库存 | 未开始 |
| P4-6 | 入库调整页面 | 库存调整页面 | 可补录入库调整 | 未开始 |
| P4-7 | 流水列表 | `lib/screens/stock/movement_list_screen.dart` | 可按日期、类型查看流水 | 未开始 |

## P5 出库日历与历史库存

| ID | 任务 | 主要文件 | 验收标准 | 状态 |
| --- | --- | --- | --- | --- |
| P5-1 | 日历页面 | `lib/screens/calendar/stock_calendar_screen.dart` | 按月显示每日出库/移库摘要 | 未开始 |
| P5-2 | 日期详情页面 | `lib/screens/calendar/stock_day_detail_screen.dart` | 显示该日期总库存、出库、移库、损耗 | 未开始 |
| P5-3 | 历史库存计算服务 | `lib/services/stock_snapshot_service.dart` | 输入日期可算出每个批号当日库存 | 未开始 |
| P5-4 | 批号库存快照 | 日期详情页面 | 显示当日每个批号库存和板数 | 未开始 |
| P5-5 | 归零批号标红 | 日期详情页面 | 当日库存为 0 的批号标红 | 未开始 |
| P5-6 | 总库存计算 | 历史库存服务 | 显示当日总库存件数，不显示总箱数 | 未开始 |

## P6 备份、导入、局域网迁移

| ID | 任务 | 主要文件 | 验收标准 | 状态 |
| --- | --- | --- | --- | --- |
| P6-1 | 完整备份导出 | `lib/services/backup_service.dart` | 导出数据库和备份信息 | 未开始 |
| P6-2 | 完整备份导入 | 备份服务 | 导入前自动备份当前数据 | 未开始 |
| P6-3 | 备份校验 | 备份服务 | 校验 App 版本、数据库版本、文件完整性 | 未开始 |
| P6-4 | 表格导出 | `lib/services/export_service.dart` | 导出订单、库存、流水报表 | 未开始 |
| P6-5 | 局域网发送 | `lib/screens/transfer/send_screen.dart` | 生成临时备份包和配对二维码 | 未开始 |
| P6-6 | 局域网接收 | `lib/screens/transfer/receive_screen.dart` | 扫码下载并导入备份包 | 未开始 |
| P6-7 | 一次性验证码 | 迁移服务 | 传输完成或过期后失效 | 未开始 |

## P7 测试、打包、Release

| ID | 任务 | 命令/文件 | 验收标准 | 状态 |
| --- | --- | --- | --- | --- |
| P7-1 | 单元测试：板数计算 | `flutter test` | 覆盖整板、余箱、不足一板 | 未开始 |
| P7-2 | 单元测试：历史库存 | `flutter test` | 覆盖订单出库、移库出库、损耗、入库调整 | 未开始 |
| P7-3 | 单元测试：库存归零过滤 | `flutter test` | 归零批号不出现在订单选择 | 未开始 |
| P7-4 | 本地 analyze | `flutter analyze` | 无 error | 未开始 |
| P7-5 | 本地 Android 调试 | Android Studio / `flutter run` | 手机可运行主要流程 | 未开始 |
| P7-6 | GitHub Actions 打包 | `.github/workflows/flutter-android-build.yml` | APK 自动发布到 Releases | 未开始 |

## 第一版建议范围

第一版只做这些：

1. SQLite 本地数据库。
2. 产品、批号、库存、位置手动维护。
3. 订单按日期录入，支持未完成/已拣货/完成。
4. 标记完成扣库存。
5. 移库出库手动备注并扣库存。
6. 日历查看每天出库、移库和历史库存。
7. 完整备份导出/导入。

第二版再做：

1. 局域网配对迁移。
2. Excel/CSV 报表导出。
3. 更复杂的统计图表。
4. 商家简称基础库。
