import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
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
  late final OrderDao _orderDao;
  late final bool _ownsDatabase;
  late DateTimeRange _range;
  late Future<_CalendarState> _stateFuture;

  @override
  void initState() {
    super.initState();
    _ownsDatabase = widget.database == null;
    _database = widget.database ?? AppDatabase();
    _stockDao = StockDao(_database);
    _orderDao = OrderDao(_database);
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
                _TotalCard(totalPieces: state?.totalPieces),
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
                  _OrderSummaryCard(orderCount: state?.orderCount ?? 0),
                  const SizedBox(height: 10),
                  _OutboundDetailCard(rows: state?.rows ?? const []),
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
    final totalPieces = await _stockDao.totalInventoryPieces();
    final rows = await _outboundRows();
    final orders = await _orderDao.orderSummaries(dateRange: _range);
    return _CalendarState(
      totalPieces: totalPieces,
      rows: rows,
      orderCount: orders.length,
    );
  }

  Future<List<_OutboundRow>> _outboundRows() async {
    final start = _range.start;
    final end =
        DateTime(_range.end.year, _range.end.month, _range.end.day, 23, 59, 59);
    final movements = await (_database.select(_database.stockMovements)
          ..where((table) =>
              table.type.equals(StockMovementType.orderOut.index) &
              table.movementDate.isBetweenValues(start, end)))
        .get();
    if (movements.isEmpty) {
      return const <_OutboundRow>[];
    }
    final batchIds = movements.map((movement) => movement.batchId).toSet().toList();
    final batches = await (_database.select(_database.batches)
          ..where((table) => table.id.isIn(batchIds)))
        .get();
    final batchesById = {for (final batch in batches) batch.id: batch};
    final productIds = batches.map((batch) => batch.productId).toSet().toList();
    final products = await (_database.select(_database.products)
          ..where((table) => table.id.isIn(productIds)))
        .get();
    final productsById = {for (final product in products) product.id: product};
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
      final key = '${product.id}-${batch.id}';
      final current = rows[key];
      final nextBoxes = (current?.boxes ?? 0) + movement.boxes;
      rows[key] = _OutboundRow(
        productCode: product.code,
        actualBatch: batch.actualBatch,
        dateBatch: batch.dateBatch,
        boxesPerBoard: batch.boxesPerBoard,
        boxes: nextBoxes,
      );
    }

    return rows.values.toList()
      ..sort((a, b) => a.productCode.compareTo(b.productCode));
  }

  void _setRange(DateTimeRange range) {
    setState(() {
      _range = range;
      _stateFuture = _loadState();
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
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
    required this.rows,
    required this.orderCount,
  });

  final int totalPieces;
  final List<_OutboundRow> rows;
  final int orderCount;
}

class _OutboundRow {
  const _OutboundRow({
    required this.productCode,
    required this.actualBatch,
    required this.dateBatch,
    required this.boxesPerBoard,
    required this.boxes,
  });

  final String productCode;
  final String actualBatch;
  final String dateBatch;
  final int boxesPerBoard;
  final int boxes;
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.totalPieces});

  final int? totalPieces;

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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(
            label: const Text('今日'),
            onPressed: () =>
                onSelected(DateTimeRange(start: today, end: today))),
        ActionChip(
          label: const Text('昨日'),
          onPressed: () {
            final yesterday = today.subtract(const Duration(days: 1));
            onSelected(DateTimeRange(start: yesterday, end: yesterday));
          },
        ),
        ActionChip(
          label: const Text('一周'),
          onPressed: () => onSelected(DateTimeRange(
              start: today.subtract(const Duration(days: 6)), end: today)),
        ),
        ActionChip(
          label: const Text('一月'),
          onPressed: () => onSelected(DateTimeRange(
              start: DateTime(today.year, today.month, 1), end: today)),
        ),
        IconButton.filledTonal(
          tooltip: '自定义范围',
          onPressed: onCustom,
          icon: const Icon(Icons.date_range_outlined),
        ),
      ],
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.orderCount});

  final int orderCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '订单 $orderCount单',
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OutboundDetailCard extends StatelessWidget {
  const _OutboundDetailCard({required this.rows});

  final List<_OutboundRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '当日出库明细',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Text('暂无出库', style: TextStyle(color: AppTheme.textSecondary))
          else
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${row.productCode} · ${row.actualBatch} · ${row.dateBatch}',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '今日出货 ${row.boxes}箱',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      BoardCalculator.format(
                        boxes: row.boxes,
                        boxesPerBoard: row.boxesPerBoard,
                      ),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
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
