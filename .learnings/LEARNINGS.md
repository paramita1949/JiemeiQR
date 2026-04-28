## 2026-04-26 - Correction - Waybill Number Manual Entry and Stock Guardrails

**Context:** During implementation of the new waybill flow, I added a QR icon to fill the waybill number. The user clarified that this capability does not exist and waybill numbers must be manually entered. The user also asked to audit stock increase/decrease logic to prevent negative inventory and over-deduction.

**Learning:** Do not add waybill-number scan/fill behavior unless explicitly reintroduced. Inventory mutation must be guarded at the data/service layer, not only in UI validation: outbound movements and order completion must reject nonpositive quantities and overdrawn stock.

**Action:** Keep the new-waybill waybill field manual. Any future stock movement type must define its sign and validate quantity/current stock before persistence.

## 2026-04-26 - Correction - Inventory Batch Remark Source

**Context:** While adjusting the Pencil design for the QRSCAN/JIEMEI inventory batch detail page, the user clarified that the "备注" shown on the inventory batch detail page is the remark edited in the "基础信息录入" page.

**Learning:** Treat inventory batch remarks as persisted batch metadata maintained from the base-information entry/edit flow, not as a temporary note authored on the inventory page.

**Action:** Future design and implementation work should label this field as coming from "录入页备注" or "基础信息备注" when field provenance matters.

## 2026-04-26 - Correction - Homepage Overview Card Semantics

**Context:** While simplifying the JIEMEI home screen, I removed the top overview card after the user said "顶部的订单概览没有意义." The user clarified that the bottom order info was the unwanted element, while the top card is still needed and should show total inventory.

**Learning:** On the home screen, the top overview card should remain an inventory summary. Order status may appear elsewhere only if useful; do not replace or remove the inventory summary without explicit instruction.

## 2026-04-26 - Correction - Merchant History Selector UI

**Context:** On the new waybill screen, I represented frequent merchants as inline chips/cards inside the form. The user corrected that this interaction is wrong and visually poor.

**Learning:** Frequent merchants should be exposed through the merchant select control itself, likely as a dropdown or bottom sheet sorted by recent frequency. Do not expand merchant history as extra inline cards in the main form.

## 2026-04-26 - Correction - Total Inventory Unit

**Context:** The user clarified that total inventory must only use piece count, not box count. Box and board quantities belong to batch/product/order detail contexts.

**Learning:** Display total inventory as 件 only. Do not show total inventory as 件/箱 or as 总箱数 in overview, calendar, or dashboard cards.

## 2026-04-26 - Correction - Homepage Backup Entry

**Context:** The user clarified that the homepage should remove the standalone "备份导入" entry because it overlaps with "局域网迁移".

**Learning:** Do not expose "备份导入" as a separate homepage entry. Keep backup/import style capabilities under the "局域网迁移" flow when needed.

## 2026-04-26 - Product Decision - No Standalone Daily Orders Page

**Context:** The user agreed that the standalone "每日订单" design is redundant.

**Learning:** Do not create or keep a separate "每日订单" page. Route `出库日历 -> 查看订单信息` to the existing `订单信息` page with the selected date/range as filter state.

## 2026-04-26 - Correction - Page Header Icon Placement

**Context:** The user clarified that several page screenshots had standalone icons at the top in the wrong position. Icons should appear beside the title, not as an isolated line above it.

**Learning:** For app page headers, use a single title row: icon on the left, title text on the right. Do not place decorative or semantic page icons as separate top-level elements above the title.

## 2026-04-26 - Correction - JIEMEI App Icon Direction

**Context:** While branding the app icon, letter/Chinese-mark directions felt too abstract and too cluttered. The user clarified that 洁美 makes 花露水, so the icon should use a flower-water bottle concept and avoid Chinese text, `JM`, `JieM`, or `JIEMEI`.

**Learning:** For the app icon, use a minimal 花露水瓶 silhouette. Keep the launcher name as `洁美`, but avoid text inside the icon itself.

## 2026-04-26 - Correction - Use Real Liushen Product Image Direction

**Context:** I replaced the app icon with an original simplified bottle after the user asked for 六神花露水. The user corrected that this still does not look like the actual 六神花露水 product image.

**Learning:** When the user asks for a recognizable commercial product icon, first gather real product references and match the actual visual source closely. Do not substitute an abstract approximation unless the user explicitly asks for a stylized original.

**Action:** For this app icon, search real 六神经典玻璃瓶花露水整瓶 images and use a source-backed product-like image direction before rebuilding the APK.

## 2026-04-26 - Correction - Inventory Quantity Base Unit

**Context:** The user clarified that 件数 is the base inventory input and calculation unit. Boxes and boards are derived from piece count and product specs.

**Learning:** Treat stock entry as piece-based at the UI/business level. Convert derived boxes/boards from pieces using pieces-per-box and boxes-per-board. Do not ask the user to enter stock boxes in base information.

**Action:** Base info should collect 库存件数, validate whole-box conversion when needed, and clear fields after saving so the operator can enter the next product/batch.

## 2026-04-28 - User Preference - Lightweight Practical Development And UI Judgment

**Context:** The user instructed that for this project, agents should load required skills, retain self-memory, learn and summarize, improve UI design ability, keep code practical and lightweight, make interactions human-friendly, avoid over-optimization and over-engineering, avoid changing code merely for change, and challenge unnecessary modifications.

**Learning:** In QRSCAN, default to minimal, evidence-based changes. UI improvements should support real warehouse/order/inventory workflows rather than decorative redesign. If a requested or tempting change does not solve a concrete problem, question it instead of implementing churn.

**Action:** Before future edits, check whether the change is necessary, small, and aligned with existing learnings. Do not repeatedly optimize stable code without a clear user-facing benefit.

## 2026-04-28 - Project Tooling - UI Design Skills And Pencil Toolset

**Context:** The user asked whether UI design skills and Pencil-related skills exist, and requested adding them to project rules.

**Learning:** Confirmed local UI/design-related skills include `brainstorming`, `web-design-guidelines`, `figma`, `figma-implement-design`, `playwright`, `playwright-interactive`, and `agent-browser` for relevant UI tasks. No standalone local `pencil` SKILL.md was confirmed; Pencil should be treated as an available MCP design toolset (`mcp__pencil__`) for `.pen` inspection, editing, screenshots, and export.

**Action:** For future UI work, load design skills only when matched by the task. For Pencil work, use `mcp__pencil__` tools directly and avoid decorative design churn.

## 2026-04-28 - Project Tooling - Fixed Flutter SDK Path

**Context:** The user pointed out that the agent often reports `flutter` is missing from the current shell and repeatedly locates the SDK. The correct local SDK root is `C:\tools\flutter`.

**Learning:** In QRSCAN, do not rely on `flutter` or `dart` being on `PATH`. Use `C:\tools\flutter\bin\flutter.bat` and `C:\tools\flutter\bin\dart.bat` directly for commands and verification.

**Action:** Future Flutter verification should run from `flutter_app/` with commands such as `C:\tools\flutter\bin\flutter.bat test`. Only re-locate the SDK if that absolute path is missing or fails.

## 2026-04-29 - Correction - Database Reset Must Be SQL-Level Clear

**Context:** The user corrected that embedded seed data is only for first-install convenience. A reset must fully clear business data and must not preserve or re-import embedded stock. The user also challenged the file replacement approach for import/reset.

**Learning:** In QRSCAN, reset semantics are business-data clearing, not database-file deletion. Avoid replacing/deleting the live SQLite file for reset/import because it blurs business intent and can destabilize active app state. Prefer explicit SQL operations: clear tables, overwrite tables, or later add a separate merge mode with defined conflict rules.

**Action:** For future data backup work, keep strategies explicit in code and UI: `重置=清空`, `覆盖=清空后插入`, `增量合并=单独设计冲突规则`. Do not silently use file replacement when a database command can express the operation.
