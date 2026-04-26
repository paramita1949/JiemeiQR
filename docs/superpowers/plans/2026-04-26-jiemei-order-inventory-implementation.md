# JIEMEI Order Inventory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the confirmed 洁美 order/inventory workflow in Flutter as an offline local app.

**Architecture:** Use feature folders for UI flows and a shared SQLite/drift data layer for persistence. Keep inventory as derived state from batch initial stock plus stock movements, so order completion, calendar, and stock detail all read the same calculation service.

**Tech Stack:** Flutter, Dart, SQLite/drift, existing `mobile_scanner`, `image_picker`, `qr_flutter`.

---

## File Structure

Create or modify these areas:

```text
flutter_app/lib/main.dart
flutter_app/lib/shared/theme/app_theme.dart
flutter_app/lib/shared/widgets/page_title.dart
flutter_app/lib/shared/widgets/action_card.dart
flutter_app/lib/shared/utils/date_formatters.dart
flutter_app/lib/shared/utils/board_calculator.dart

flutter_app/lib/data/app_database.dart
flutter_app/lib/data/tables/products.dart
flutter_app/lib/data/tables/batches.dart
flutter_app/lib/data/tables/orders.dart
flutter_app/lib/data/tables/order_items.dart
flutter_app/lib/data/tables/stock_movements.dart
flutter_app/lib/data/daos/product_dao.dart
flutter_app/lib/data/daos/order_dao.dart
flutter_app/lib/data/daos/stock_dao.dart

flutter_app/lib/features/home/home_screen.dart
flutter_app/lib/features/qr/qr_entry_screen.dart
flutter_app/lib/features/qr/qr_scanner_screen.dart
flutter_app/lib/features/qr/qr_preview_screen.dart
flutter_app/lib/features/orders/order_list_screen.dart
flutter_app/lib/features/orders/order_edit_screen.dart
flutter_app/lib/features/orders/order_detail_screen.dart
flutter_app/lib/features/orders/widgets/merchant_picker.dart
flutter_app/lib/features/orders/widgets/product_batch_picker.dart
flutter_app/lib/features/inventory/inventory_detail_screen.dart
flutter_app/lib/features/base_info/base_info_edit_screen.dart
flutter_app/lib/features/calendar/outbound_calendar_screen.dart
flutter_app/lib/features/transfer/lan_transfer_screen.dart

flutter_app/test/board_calculator_test.dart
flutter_app/test/stock_snapshot_service_test.dart
flutter_app/test/order_completion_service_test.dart
```

Existing QR files can be moved gradually. Do not break current QR parser tests.

## Task 1: Establish Shared Visual Framework

**Files:**
- Create: `flutter_app/lib/shared/theme/app_theme.dart`
- Create: `flutter_app/lib/shared/widgets/page_title.dart`
- Create: `flutter_app/lib/shared/widgets/action_card.dart`
- Modify: `flutter_app/lib/main.dart`

- [x] Create `AppTheme` matching the Pencil V5/V3 style: light background, blue primary, compact cards.
- [x] Create `PageTitle` with icon on the left and title text on the right.
- [x] Create reusable `ActionCard` for homepage entries.
- [x] Change `main.dart` to use the new light theme and `HomeScreen`.
- [x] Run `flutter analyze`.

## Task 2: Build New Home Shell

**Files:**
- Create: `flutter_app/lib/features/home/home_screen.dart`
- Modify: `flutter_app/lib/main.dart`

- [x] Implement top brand row: icon + `洁美`.
- [x] Implement subtitle: `浙江仓订单与库存工作台`.
- [x] Implement total inventory card with pieces only.
- [x] Implement 6 home entries: QR箱码, 订单信息, 出库日历, 库存明细, 局域网迁移, 基础资料.
- [x] Wire each entry to placeholder pages first.
- [x] Run widget smoke test.

## Task 3: Preserve and Relocate QR Flow

**Files:**
- Move/adapt: current `scanner_screen.dart`, `preview_screen.dart`, `qr_parser.dart`
- Create: `flutter_app/lib/features/qr/qr_entry_screen.dart`

- [x] Keep existing QR parser behavior unchanged.
- [x] Recreate QR箱码页面 using the confirmed layout.
- [x] Buttons: `开始扫码`, `导入图片`, `生成并预览`, `下一组继续`.
- [x] Disable `生成并预览` and `下一组继续` until a QR code has been successfully parsed.
- [x] Do not apply inventory/batch filtering inside QR箱码 generation; zero-stock filtering only belongs to order batch selection.
- [x] Reuse existing QR scanner and preview behavior.
- [x] Run `flutter test test/qr_parser_test.dart`.

## Task 4: Add Board Calculation Core

**Files:**
- Create: `flutter_app/lib/shared/utils/board_calculator.dart`
- Create: `flutter_app/test/board_calculator_test.dart`

- [x] Write tests for exact board, board plus boxes, and boxes only.
- [x] Implement `BoardCalculator.format(boxes, boxesPerBoard)`.
- [x] Support output examples: `4板`, `86板+37箱`, `8箱`.
- [x] Run board calculator tests.

## Task 5: Introduce Local Database

**Files:**
- Modify: `flutter_app/pubspec.yaml`
- Create: data table and DAO files listed above

- [x] Add drift, sqlite, path provider, and build dependencies.
- [x] Create tables: products, batches, orders, order_items, stock_movements.
- [x] Define order status enum values: `pending`, `picked`, `done`.
- [x] Define movement types: `initial`, `orderOut`, `transferOut`, `lossOut`, `inAdjust`.
- [x] Generate drift files.
- [x] Add DAO methods needed by screens.
- [x] Run code generation, analyze, and tests.

## Task 6: Implement Base Info

**Files:**
- Create: `flutter_app/lib/features/base_info/base_info_edit_screen.dart`

- [x] Build fields for product code/name, actual batch, date batch, stock boxes, boxes per board, pieces per box, location, remark.
- [x] Add QR scan icon button and reuse QR parser for quick fill where possible.
- [x] Add save behavior to product/batch DAO.
- [x] Add delete with second confirmation.
- [x] Run manual smoke test from homepage.

## Task 7: Implement Inventory Detail

**Files:**
- Create: `flutter_app/lib/features/inventory/inventory_detail_screen.dart`
- Create: stock calculation service if not already in DAO

- [x] Show total inventory as pieces only.
- [x] Show batch rows with product code, actual batch, date batch, stock, board result, spec, has-shipped, remark.
- [x] Add product/batch/status filters.
- [x] Add inline remark edit that saves to batch.
- [x] Add `录入 / 编辑资料` button to base info.
- [x] Verify zero stock visual state.

## Task 8: Implement Order List and Date/Status Context

**Files:**
- Create: `flutter_app/lib/features/orders/order_list_screen.dart`

- [x] Support optional `dateRange` input.
- [x] Add status tabs: 未完成, 已拣货, 完成 with orange/blue/green styling.
- [x] Add calendar icon to open date/range filter.
- [x] Add order cards that open order detail.
- [x] Add button to create new waybill.
- [x] Confirm no standalone daily-orders page exists.

## Task 9: Implement New Waybill

**Files:**
- Create: `flutter_app/lib/features/orders/order_edit_screen.dart`
- Create: `flutter_app/lib/features/orders/widgets/merchant_picker.dart`
- Create: `flutter_app/lib/features/orders/widgets/product_batch_picker.dart`

- [x] Merchant selector shows historical Top10 by recent frequency.
- [x] Date chip opens order-date selector and defaults to today.
- [x] Waybill number is manual entry only; no scan/fill icon.
- [x] Product selector displays product code only.
- [x] Batch defaults to most recent available batch for the selected product.
- [x] Box input shows available stock, required board+box result, and spec.
- [x] `暂存` and `完成` both save the order/items with default status `pending`; the new-waybill `完成` means finish entry, not order completion.
- [x] Validate selected batch stock is greater than zero and box count does not exceed available stock.

## Task 10: Implement Waybill Detail and Completion

**Files:**
- Create: `flutter_app/lib/features/orders/order_detail_screen.dart`
- Create: `flutter_app/lib/features/orders/order_completion_service.dart`
- Create: `flutter_app/test/order_completion_service_test.dart`

- [x] Display waybill header, status, and enriched product lines.
- [x] Add status controls: 未完成, 已拣货.
- [x] Add bottom `完成` button.
- [x] Completion button opens confirmation dialog.
- [x] On confirm, validate stock, write order-out stock movements, and set status done.
- [x] Prevent duplicate stock deduction if already done.
- [x] Run service tests.

## Task 11: Implement Outbound Calendar

**Files:**
- Create: `flutter_app/lib/features/calendar/outbound_calendar_screen.dart`
- Create: `flutter_app/lib/features/calendar/date_range_filter.dart`
- Create: `flutter_app/test/stock_snapshot_service_test.dart`

- [x] Add range chips: 今日, 昨日, 一周, 一月, custom range icon.
- [x] Display selected dates without time.
- [x] Show realtime total inventory as pieces only.
- [x] Show outbound detail grouped by product code + batch.
- [x] Show order information summary.
- [x] `查看订单信息` navigates to order list with selected date/range.
- [x] `查看库存明细` navigates to inventory detail.

## Task 12: Implement LAN Transfer Placeholder and Backup Boundary

**Files:**
- Create: `flutter_app/lib/features/transfer/lan_transfer_screen.dart`
- Create: `flutter_app/lib/features/transfer/backup_service.dart`

- [x] Show send and receive database modes.
- [x] Keep backup/import under this page, not homepage.
- [x] First version may implement local backup/export placeholder if LAN service is deferred.
- [x] Document any deferred transfer behavior clearly in code comments and task plan: current version exposes the LAN migration entry and local backup boundary only; real LAN send/receive is deferred to a later networking task.

## Task 13: Regression and Release Checks

**Files:**
- Existing tests and new tests

- [x] Run `flutter pub get`.
- [x] Run code generation if drift is present.
- [x] Run `flutter test`.
- [x] Run `flutter analyze`.
- [ ] Manually open key screens on device/emulator.
- [ ] Confirm page header icon rule across all main screens.
