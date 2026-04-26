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
