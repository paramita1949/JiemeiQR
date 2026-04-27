# 订单与库存交互重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 一次性完成首页统计口径、库存筛选、订单默认日期与快捷筛选、运单详情可修改、新增运单文案和流程重构。

**Architecture:** 维持现有 Flutter + Drift 架构，在 `features` 层调整交互和默认筛选，在 `daos` 层补齐删除/更新接口，并用最小改动保持现有数据模型兼容。

**Tech Stack:** Flutter, Drift, SQLite, Dart

---

### Task 1: 首页统计口径调整

**Files:**
- Modify: `flutter_app/lib/features/home/home_screen.dart`

- [ ] 统计字段替换为今日订单/昨日订单/未完成订单
- [ ] 更新查询逻辑与显示文案
- [ ] 保留总库存显示不变

### Task 2: 库存明细筛选与库位透出

**Files:**
- Modify: `flutter_app/lib/features/inventory/inventory_detail_screen.dart`

- [ ] 增加产品编号快捷筛选 chips（来源于当前数据库）
- [ ] 库位信息显示在库存明细行

### Task 3: 订单列表默认今日与快捷筛选

**Files:**
- Modify: `flutter_app/lib/features/orders/order_list_screen.dart`
- Modify: `flutter_app/lib/data/daos/order_dao.dart`

- [ ] 默认日期范围改为今日
- [ ] 增加快捷筛选：今日/昨日/一周/一月/未完成
- [ ] 订单列表增加删除订单入口

### Task 4: 运单详情可编辑与库位展示

**Files:**
- Modify: `flutter_app/lib/features/orders/order_detail_screen.dart`
- Modify: `flutter_app/lib/data/daos/order_dao.dart`

- [ ] 增加编辑入口（日期、商家、运单号）
- [ ] 支持保存更新
- [ ] 产品行显示库位信息

### Task 5: 新增运单交互重命名与连续录入

**Files:**
- Modify: `flutter_app/lib/features/orders/order_edit_screen.dart`
- Modify: `flutter_app/lib/data/daos/order_dao.dart`

- [ ] “暂存”改为“继续添加”
- [ ] “完成”后清空并准备下一条输入
- [ ] 明确同运单多产品通过“继续添加”追加

### Task 6: 验证

**Files:**
- N/A

- [ ] 运行 `flutter analyze`
- [ ] 运行 `flutter test`
- [ ] 运行 `flutter build apk --debug`
