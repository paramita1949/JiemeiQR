# 洁美QR UI 设计稿索引

更新时间：2026-04-28（新增真机 UI 基准稿）

## Pencil 画布

当前设计稿写入：

```text
untitled.pen
```

## 真机 UI 基准稿（2026-04-28）

这组页面根据 `pencil/` 目录下 8 张真机截图重建为可编辑 Pencil 节点，用作后续 UI 设计的真实对照基准。

基准稿位于画布下方：

```text
y = 4930
```

| 页面 | Pencil 节点 ID | 位置 | 截图来源 |
| --- | --- | --- | --- |
| 首页总控 | `r00016` | x=-50, y=4930 | `pencil/Screenshot_20260428_060621.jpg` |
| 基础资料 | `r0002g` | x=370, y=4930 | `pencil/Screenshot_20260428_060626.jpg` |
| 局域网迁移 | `r0003n` | x=790, y=4930 | `pencil/Screenshot_20260428_060633.jpg` |
| 库存明细 | `r00058` | x=1210, y=4930 | `pencil/Screenshot_20260428_060638.jpg` |
| 出库日历 | `r00068` | x=1630, y=4930 | `pencil/Screenshot_20260428_060642.jpg` |
| 订单信息 | `r0007b` | x=2050, y=4930 | `pencil/Screenshot_20260428_060647.jpg` |
| 新增运单 | `r0008f` | x=2470, y=4930 | `pencil/Screenshot_20260428_060718.jpg` |
| QR箱码生成 | `r0009p` | x=2890, y=4930 | `pencil/Screenshot_20260428_060723.jpg` |

最终版位于画布下方：

```text
y = 2866
```

## 最终版页面

| 页面 | Pencil 节点 ID | 位置 | PNG 导出 |
| --- | --- | --- | --- |
| 首页 | `RSwmz` | x=-50, y=2866 | `docs/ui-export/RSwmz.png` |
| 基础库存 | `eNSgi` | x=370, y=2866 | `docs/ui-export/eNSgi.png` |
| 新增运单 | `OSGoU` | x=790, y=2866 | `docs/ui-export/OSGoU.png` |
| 出库日历 | `kgMq5` | x=1210, y=2866 | `docs/ui-export/kgMq5.png` |
| 数据迁移 | `uTflA` | x=1630, y=2866 | `docs/ui-export/uTflA.png` |
| 日库存详情 | `6B2Bs` | x=2050, y=2866 | `docs/ui-export/6B2Bs.png` |
| 运单详情 | `dO7DF` | x=2470, y=2866 | `docs/ui-export/dO7DF.png` |
| 批号选择 | `MbbDt` | x=2890, y=2866 | `docs/ui-export/MbbDt.png` |

## V3 页面（推荐）

V3 位于画布更下方：

```text
y = 3890
```

| 页面 | Pencil 节点 ID | 位置 | PNG 导出 |
| --- | --- | --- | --- |
| 首页总控 | `VnKxp` | x=-50, y=3890 | `docs/ui-export-v3/VnKxp.png` |
| QR箱码 | `afXiB` | x=370, y=3890 | `docs/ui-export-v3/afXiB.png` |
| 订单列表 | `KEOEr` | x=790, y=3890 | `docs/ui-export-v3/KEOEr.png` |
| 新增运单 | `FFIug` | x=1210, y=3890 | `docs/ui-export-v3/FFIug.png` |
| 基础库存 | `H3uvx` | x=1630, y=3890 | `docs/ui-export-v3/H3uvx.png` |
| 出库日历 | `tsiVY` | x=2050, y=3890 | `docs/ui-export-v3/tsiVY.png` |
| 数据迁移 | `pFw7w` | x=2470, y=3890 | `docs/ui-export-v3/pFw7w.png` |

## 入口逻辑

首页分为两组入口：

```text
业务
- QR箱码
- 订单信息
- 出库日历
- 库存明细

管理
- 基础资料
- 局域网数据迁移
```

## 视觉规则

```text
主色：#2563EB
危险色：#DC2626
未完成/占用：#E07B54
背景：#FFFFFF
浅蓝强调：#EFF6FF
浅红警示：#FFF1F2
```

V3 色板（更轻、更现代）：

```text
主色：#0B5FFF
辅助紫蓝：#EEF2FF / #3730A3
成功色：#16A34A
警示色：#B91C1C / #FFF7ED
页面背景：#F6F8FC
卡片背景：#FFFFFF
```

标题栏规则：

```text
页面图标不能单独占据顶部一行。
如页面需要图标，必须和页面标题放在同一行，位于标题左侧。
操作图标只放在按钮、筛选器或输入控件内部。
```

## 交互规则

```text
基础库存 -> 维护产品、批号、位置、初始库存
新增运单 -> 从基础库存选择有库存的批号
批号选择 -> 库存为 0 的批号不显示
日库存详情 -> 库存归零批号红色显示
运单详情 -> 标记完成后扣库存
数据迁移 -> 发送 / 接收完整备份
```

首页不保留独立的 `备份导入` 入口；备份/导入相关能力统一归入 `局域网数据迁移`。

不保留独立的 `每日订单` 页面。出库日历点击“查看订单信息”时，进入 `订单信息` 页面，并携带当前日期或范围筛选条件。
