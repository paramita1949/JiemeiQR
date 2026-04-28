import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';
import 'package:qrscan_flutter/features/inventory/inventory_detail_screen.dart';
import 'package:qrscan_flutter/features/orders/order_list_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/utils/board_calculator.dart';
import 'package:qrscan_flutter/shared/widgets/page_title.dart';

class OutboundCalendarScreen extends StatefulWidget {
  const OutboundCalendarScreen({
    super.key,
    this.database,
    this.initialRange,
  });

  final AppDatabase? database;
  final DateTimeRange? initialRange;

  @override
  State<OutboundCalendarScreen> createState() => _OutboundCalendarScreenState();
}

class _OutboundCalendarScreenState extends State<OutboundCalendarScreen> {
  late final AppDatabase _database;
  late final StockDao _stockDao;
  late final bool _ownsDatabase;
  late DateTimeRange _range;
  late Future<_CalendarState> _stateFuture;
  int? _selectedOrderId;

  @override
  void initState() {
    super.initState();
    _ownsDatabase = widget.database == null;
    _database = widget.database ?? AppDatabase();
    _stockDao = StockDao(_database);
    final today = _dateOnly(DateTime.now());
    _range = widget.initialRange ?? DateTimeRange(start: today, end: today);
    _stateFuture = _loadState();
  }

  @override
  void dispose() {
    if (_ownsDatabase) {
      _database.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_CalendarState>(
          future: _stateFuture,
          builder: (context, snapshot) {
            final state = snapshot.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 42),
              children: [
                const PageTitle(
                  icon: Icons.calendar_month_outlined,
                  title: '出库日历',
                  subtitle: '按日期查看出库与订单',
                ),
                const SizedBox(height: 14),
                _TotalCard(
                  totalPieces: state?.totalPieces,
                  outboundBoxes: state?.outboundBoxes,
                ),
                const SizedBox(height: 10),
                _RangeBar(
                  selectedRange: _range,
                  onSelected: _setRange,
                  onCustom: _pickCustomRange,
                ),
                const SizedBox(height: 10),
                Text(
                  _rangeText(_range),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (snapshot.connectionState != ConnectionState.done)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  _OrderSummaryCard(
                    orders: state?.orders ?? const <_OutboundOrderSummary>[],
                    selectedOrderId: _selectedOrderId,
                    onSelected: _selectOrder,
                  ),
                  const SizedBox(height: 10),
                  _OutboundDetailCard(
                    title: _detailTitle(state),
                    rows: state?.rows ?? const [],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _openOrders,
                          child: const Text('查看订单信息'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _openInventory,
                          child: const Text('查看库存明细'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<_CalendarState> _loadState() async {
    final snapshotAt =
        DateTime(_range.end.year, _range.end.month, _range.end.day, 23, 59, 59);
    final totalPieces = await _stockDao.totalInventoryPiecesAt(snapshotAt);
    final allRows = await _outboundRows();
    final orders = await _orderSummariesFromRows(allRows);
    final selectedOrderStillVisible =
        orders.any((order) => order.id == _selectedOrderId);
    if (!selectedOrderStillVisible) {
      _selectedOrderId = null;
    }
    final rows = _selectedOrderId == null
        ? allRows
        : allRows.where((row) => row.orderId == _selectedOrderId).toList();
    return _CalendarState(
      totalPieces: totalPieces,
      outboundBoxes: allRows.fold<int>(0, (sum, row) => sum + row.boxes),
      orders: orders,
      rows: rows,
    );
  }

  Future<List<_OutboundRow>> _outboundRows() async {
    final start = _range.start;
    final end =
        DateTime(_range.end.year, _range.end.month, _range.end.day, 23, 59, 59);
    final movements = await (_database.select(_database.stockMovements)
          ..where((table) {
            final inRange =
                table.type.equals(StockMovementType.orderOut.index) &
                    table.movementDate.isBetweenValues(start, end);
            return inRange;
          }))
        .get();
    if (movements.isEmpty) {
      return const <_OutboundRow>[];
    }
    final batchIds =
        movements.map((movement) => movement.batchId).toSet().toList();
    final batches = await (_database.select(_database.batches)
          ..where((table) => table.id.isIn(batchIds)))
        .get();
    final batchesById = {for (final batch in batches) batch.id: batch};
    final productIds = batches.map((batch) => batch.productId).toSet().toList();
    final products = await (_database.select(_database.products)
          ..where((table) => table.id.isIn(productIds)))
        .get();
    final productsById = {for (final product in products) product.id: product};
    final orderIds = movements
        .map((movement) => movement.orderId)
        .whereType<int>()
        .toSet()
        .toList();
    final orders = orderIds.isEmpty
        ? const <Order>[]
        : await (_database.select(_database.orders)
              ..where((table) => table.id.isIn(orderIds)))
            .get();
    final ordersById = {for (final order in orders) order.id: order};
    final rows = <String, _OutboundRow>{};

    for (final movement in movements) {
      final batch = batchesById[movement.batchId];
      if (batch == null) {
        continue;
      }
      final product = productsById[batch.productId];
      if (product == null) {
        continue;
      }
      final order =
          movement.orderId == null ? null : ordersById[movement.orderId];
      final key = '${product.id}-${batch.id}-${movement.orderId ?? 0}';
      final current = rows[key];
      final nextBoxes = (current?.boxes ?? 0) + movement.boxes;
      rows[key] = _OutboundRow(
        productCode: product.code,
        dateBatch: batch.dateBatch,
        boxesPerBoard: batch.boxesPerBoard,
        boxes: nextBoxes,
        orderId: movement.orderId,
        waybillNo: order?.waybillNo,
        merchantName: order?.merchantName,
      );
    }

    return rows.values.toList()
      ..sort((a, b) {
        final waybillCmp = (a.waybillNo ?? '').compareTo(b.waybillNo ?? '');
        if (waybillCmp != 0) {
          return waybillCmp;
        }
        final productCmp = a.productCode.compareTo(b.productCode);
        if (productCmp != 0) {
          return productCmp;
        }
        return a.dateBatch.compareTo(b.dateBatch);
      });
  }

  Future<List<_OutboundOrderSummary>> _orderSummariesFromRows(
    List<_OutboundRow> rows,
  ) async {
    final boxesByOrderId = <int, int>{};
    for (final row in rows) {
      if (row.orderId == null) {
        continue;
      }
      boxesByOrderId.update(
        row.orderId!,
        (value) => value + row.boxes,
        ifAbsent: () => row.boxes,
      );
    }
    final orderIds = boxesByOrderId.keys.toList();
    if (orderIds.isEmpty) {
      return const <_OutboundOrderSummary>[];
    }
    final orders = await (_database.select(_database.orders)
          ..where((table) => table.id.isIn(orderIds)))
        .get();
    final summaries = orders
        .map(
          (order) => _OutboundOrderSummary(
            id: order.id,
            waybillNo: order.waybillNo,
            merchantName: order.merchantName,
            boxes: boxesByOrderId[order.id] ?? 0,
          ),
        )
        .toList();
    summaries.sort((a, b) => a.waybillNo.compareTo(b.waybillNo));
    return summaries;
  }

  void _setRange(DateTimeRange range) {
    setState(() {
      _range = range;
      _selectedOrderId = null;
      _stateFuture = _loadState();
    });
  }

  void _selectOrder(int orderId) {
    setState(() {
      _selectedOrderId = _selectedOrderId == orderId ? null : orderId;
      _stateFuture = _loadState();
    });
  }

  String _detailTitle(_CalendarState? state) {
    final selected = _selectedOrder(state);
    return selected == null
        ? _rangeDetailTitle(_range)
        : '运单 ${selected.waybillNo} 出库明细';
  }

  _OutboundOrderSummary? _selectedOrder(_CalendarState? state) {
    for (final order in state?.orders ?? const <_OutboundOrderSummary>[]) {
      if (order.id == _selectedOrderId) {
        return order;
      }
    }
    return null;
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      locale: const Locale('zh', 'CN'),
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5),
      initialDateRange: _range,
    );
    if (picked != null) {
      _setRange(DateTimeRange(
          start: _dateOnly(picked.start), end: _dateOnly(picked.end)));
    }
  }

  void _openOrders() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderListScreen(database: _database, dateRange: _range),
      ),
    );
  }

  void _openInventory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InventoryDetailScreen(database: _database),
      ),
    );
  }
}

class _CalendarState {
  const _CalendarState({
    required this.totalPieces,
    required this.outboundBoxes,
    required this.orders,
    required this.rows,
  });

  final int totalPieces;
  final int outboundBoxes;
  final List<_OutboundOrderSummary> orders;
  final List<_OutboundRow> rows;
}

class _OutboundRow {
  const _OutboundRow({
    required this.productCode,
    required this.dateBatch,
    required this.boxesPerBoard,
    required this.boxes,
    required this.orderId,
    required this.waybillNo,
    required this.merchantName,
  });

  final String productCode;
  final String dateBatch;
  final int boxesPerBoard;
  final int boxes;
  final int? orderId;
  final String? waybillNo;
  final String? merchantName;
}

class _OutboundOrderSummary {
  const _OutboundOrderSummary({
    required this.id,
    required this.waybillNo,
    required this.merchantName,
    required this.boxes,
  });

  final int id;
  final String waybillNo;
  final String merchantName;
  final int boxes;
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.totalPieces,
    required this.outboundBoxes,
  });

  final int? totalPieces;
  final int? outboundBoxes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '总库存',
            style: TextStyle(
              color: Color(0xFFDBEAFE),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            totalPieces == null ? '-- 件' : '${_formatNumber(totalPieces!)} 件',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 31,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (outboundBoxes != null && outboundBoxes! > 0)
            Text(
              '库存变化 -${outboundBoxes!}箱',
              style: const TextStyle(
                color: Color(0xFFBFDBFE),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _RangeBar extends StatelessWidget {
  const _RangeBar({
    required this.selectedRange,
    required this.onSelected,
    required this.onCustom,
  });

  final DateTimeRange selectedRange;
  final ValueChanged<DateTimeRange> onSelected;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ActionChip(
              label: const Text('今日'),
              onPressed: () =>
                  onSelected(DateTimeRange(start: today, end: today))),
          const SizedBox(width: 8),
          ActionChip(
            label: const Text('昨日'),
            onPressed: () {
              final yesterday = today.subtract(const Duration(days: 1));
              onSelected(DateTimeRange(start: yesterday, end: yesterday));
            },
          ),
          const SizedBox(width: 8),
          ActionChip(
            label: const Text('一周'),
            onPressed: () => onSelected(DateTimeRange(
                start: today.subtract(const Duration(days: 6)), end: today)),
          ),
          const SizedBox(width: 8),
          ActionChip(
            label: const Text('一月'),
            onPressed: () => onSelected(DateTimeRange(
                start: DateTime(today.year, today.month, 1), end: today)),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: '自定义范围',
            onPressed: onCustom,
            icon: const Icon(Icons.date_range_outlined),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.orders,
    required this.selectedOrderId,
    required this.onSelected,
  });

  final List<_OutboundOrderSummary> orders;
  final int? selectedOrderId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final totalBoxes = orders.fold<int>(0, (sum, order) => sum + order.boxes);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '订单 ${orders.length}单 · $totalBoxes箱',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (orders.isEmpty)
            const Text('暂无订单', style: TextStyle(color: AppTheme.textSecondary))
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 170),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final selected = order.id == selectedOrderId;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelected(order.id),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFEFF6FF)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primary
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.waybillNo,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  order.merchantName,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '出库 ${order.boxes}箱',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _OutboundDetailCard extends StatelessWidget {
  const _OutboundDetailCard({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<_OutboundRow> rows;

  @override
  Widget build(BuildContext context) {
    final groups = _OutboundGroup.fromRows(rows);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (groups.isNotEmpty)
                const Text(
                  '按运单',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (groups.isEmpty)
            const Text('暂无出库', style: TextStyle(color: AppTheme.textSecondary))
          else
            ...groups.map(_buildGroup),
        ],
      ),
    );
  }

  Widget _buildGroup(_OutboundGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.waybillTitle,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '合计 ${group.totalBoxes}箱',
                  style: const TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              if (group.merchantName != null &&
                  group.merchantName!.isNotEmpty) ...[
                Text.rich(
                  TextSpan(
                    text: group.merchantName!,
                    style: const TextStyle(color: Color(0xFFDC2626)),
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '${group.rows.length}个批号',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...group.rows.map(_buildProductRow),
        ],
      ),
    );
  }

  Widget _buildProductRow(_OutboundRow row) {
    final quantity = _quantityParts(row);
    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${row.productCode} · ${row.dateBatch}',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              quantity.boxesText,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(
            width: 88,
            child: quantity.boardText == null
                ? const SizedBox.shrink()
                : Row(
                    children: [
                      const Text(
                        '·',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          quantity.boardText!,
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  _QuantityParts _quantityParts(_OutboundRow row) {
    final boardText = BoardCalculator.format(
      boxes: row.boxes,
      boxesPerBoard: row.boxesPerBoard,
    );
    if (boardText == '${row.boxes}箱') {
      return _QuantityParts(
        boxesText: '${row.boxes}箱',
        boardText: null,
      );
    }
    return _QuantityParts(
      boxesText: '${row.boxes}箱',
      boardText: boardText,
    );
  }
}

class _QuantityParts {
  const _QuantityParts({
    required this.boxesText,
    required this.boardText,
  });

  final String boxesText;
  final String? boardText;
}

class _OutboundGroup {
  const _OutboundGroup({
    required this.waybillTitle,
    required this.merchantName,
    required this.totalBoxes,
    required this.rows,
  });

  final String waybillTitle;
  final String? merchantName;
  final int totalBoxes;
  final List<_OutboundRow> rows;

  static List<_OutboundGroup> fromRows(List<_OutboundRow> rows) {
    final grouped = <String, List<_OutboundRow>>{};
    for (final row in rows) {
      final key = row.orderId == null
          ? 'no-order-${row.productCode}-${row.dateBatch}'
          : 'order-${row.orderId}';
      grouped.putIfAbsent(key, () => <_OutboundRow>[]).add(row);
    }
    return grouped.values.map((groupRows) {
      final first = groupRows.first;
      final totalBoxes = groupRows.fold<int>(
        0,
        (sum, row) => sum + row.boxes,
      );
      return _OutboundGroup(
        waybillTitle: first.waybillNo == null || first.waybillNo!.isEmpty
            ? '未关联运单'
            : '运单 ${first.waybillNo}',
        merchantName: first.merchantName,
        totalBoxes: totalBoxes,
        rows: groupRows,
      );
    }).toList();
  }
}

String _rangeDetailTitle(DateTimeRange range) {
  final today = _dateOnly(DateTime.now());
  final yesterday = today.subtract(const Duration(days: 1));
  if (_sameDate(range.start, today) && _sameDate(range.end, today)) {
    return '今日出库明细';
  }
  if (_sameDate(range.start, yesterday) && _sameDate(range.end, yesterday)) {
    return '昨日出库明细';
  }
  if (_sameDate(range.start, today.subtract(const Duration(days: 6))) &&
      _sameDate(range.end, today)) {
    return '近7天出库明细';
  }
  if (_sameDate(range.start, DateTime(today.year, today.month, 1)) &&
      _sameDate(range.end, today)) {
    return '本月出库明细';
  }
  return '出库明细';
}

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _rangeText(DateTimeRange range) {
  final start = _formatDate(range.start);
  final end = _formatDate(range.end);
  return start == end ? start : '$start - $end';
}

String _formatDate(DateTime date) => '${date.year}.${date.month}.${date.day}';

String _formatNumber(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i += 1) {
    final reverseIndex = text.length - i;
    buffer.write(text[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}
