import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';
import 'package:qrscan_flutter/features/inventory/inventory_detail_screen.dart';
import 'package:qrscan_flutter/features/orders/order_list_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/utils/navigation_refresh.dart';
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
  late final ProductDao _productDao;
  late final StockDao _stockDao;
  late final bool _ownsDatabase;
  late DateTimeRange _range;
  late Future<_CalendarState> _stateFuture;
  int? _selectedOrderId;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  _OutboundSearchType _searchType = _OutboundSearchType.waybill;
  _SearchRangePreset _searchRangePreset = _SearchRangePreset.week;
  DateTimeRange? _searchCustomRange;
  bool _searchLoading = false;
  int _searchVersion = 0;
  List<_OutboundSearchSuggestion> _searchSuggestions =
      const <_OutboundSearchSuggestion>[];
  List<_OutboundSearchRow> _searchRows = const <_OutboundSearchRow>[];

  @override
  void initState() {
    super.initState();
    _ownsDatabase = widget.database == null;
    _database = widget.database ?? AppDatabase();
    _productDao = ProductDao(_database);
    _stockDao = StockDao(_database);
    final today = _dateOnly(DateTime.now());
    _range = widget.initialRange ?? DateTimeRange(start: today, end: today);
    _stateFuture = _loadState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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
            final hasSearchQuery = _searchController.text.trim().isNotEmpty;
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
                _OutboundSearchPanel(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  searchType: _searchType,
                  rangePreset: _searchRangePreset,
                  customRange: _searchCustomRange,
                  suggestions: _searchSuggestions,
                  loading: _searchLoading,
                  onTypeChanged: _onSearchTypeChanged,
                  onRangePresetChanged: _onSearchRangePresetChanged,
                  onPickCustomRange: _pickSearchCustomRange,
                  onChanged: _onSearchChanged,
                  onSuggestionTap: _onSuggestionTap,
                  onClear: _clearSearch,
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
                  if (hasSearchQuery) ...[
                    _OutboundSearchResultCard(rows: _searchRows),
                  ] else ...[
                    _OrderSummaryCard(
                      orders: state?.orders ?? const <_OutboundOrderSummary>[],
                      selectedOrderId: _selectedOrderId,
                      onSelected: _selectOrder,
                    ),
                    const SizedBox(height: 10),
                    _OutboundDetailCard(
                      title: _detailTitle(state),
                      rows: _detailRows(state),
                      batchCodesByProductDate:
                          state?.batchCodesByProductDate ??
                              const <String, List<String>>{},
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          key: const Key('outboundViewOrdersButton'),
                          onPressed: _openOrders,
                          child: const Text('查看订单信息'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('outboundViewInventoryButton'),
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
    final batchCodesByProductDate = await _productDao.batchCodesByProductDate();
    final orders = await _orderSummariesFromRows(allRows);
    final selectedOrderStillVisible =
        orders.any((order) => order.id == _selectedOrderId);
    if (!selectedOrderStillVisible) {
      _selectedOrderId = null;
    }
    return _CalendarState(
      totalPieces: totalPieces,
      outboundBoxes: allRows.fold<int>(0, (sum, row) => sum + row.boxes),
      orders: orders,
      rows: allRows,
      batchCodesByProductDate: batchCodesByProductDate,
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
        actualBatch: batch.actualBatch,
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

  void _onSearchTypeChanged(_OutboundSearchType type) {
    setState(() {
      _searchType = type;
      if (type == _OutboundSearchType.waybill) {
        _searchRangePreset = _SearchRangePreset.all;
      } else if (_searchRangePreset == _SearchRangePreset.all) {
        _searchRangePreset = _SearchRangePreset.week;
      }
    });
    _refreshSearch();
  }

  void _onSearchRangePresetChanged(_SearchRangePreset preset) {
    if (_searchType == _OutboundSearchType.waybill) {
      return;
    }
    setState(() {
      _searchRangePreset = preset;
    });
    _refreshSearch();
  }

  void _onSearchChanged(String _) {
    _refreshSearch();
  }

  Future<void> _onSuggestionTap(_OutboundSearchSuggestion suggestion) async {
    _searchController.text = suggestion.value;
    _searchController.selection = TextSelection.collapsed(
      offset: _searchController.text.length,
    );
    await _refreshSearch();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchSuggestions = const <_OutboundSearchSuggestion>[];
      _searchRows = const <_OutboundSearchRow>[];
    });
  }

  Future<void> _pickSearchCustomRange() async {
    if (_searchType == _OutboundSearchType.waybill) {
      return;
    }
    final now = DateTime.now();
    final initial = _searchCustomRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 6),
          end: DateTime(now.year, now.month, now.day),
        );
    final picked = await showDateRangePicker(
      context: context,
      locale: const Locale('zh', 'CN'),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
      initialDateRange: initial,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _searchCustomRange = DateTimeRange(
        start: _dateOnly(picked.start),
        end: _dateOnly(picked.end),
      );
      _searchRangePreset = _SearchRangePreset.custom;
    });
    await _refreshSearch();
  }

  DateTimeRange? _effectiveSearchRange() {
    if (_searchType == _OutboundSearchType.waybill) {
      return null;
    }
    final today = _dateOnly(DateTime.now());
    switch (_searchRangePreset) {
      case _SearchRangePreset.all:
        return null;
      case _SearchRangePreset.today:
        return DateTimeRange(start: today, end: today);
      case _SearchRangePreset.yesterday:
        final yesterday = today.subtract(const Duration(days: 1));
        return DateTimeRange(start: yesterday, end: yesterday);
      case _SearchRangePreset.week:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );
      case _SearchRangePreset.month:
        return DateTimeRange(
          start: DateTime(today.year, today.month, 1),
          end: today,
        );
      case _SearchRangePreset.custom:
        return _searchCustomRange;
    }
  }

  Future<void> _refreshSearch() async {
    final keyword = _searchController.text.trim();
    final version = ++_searchVersion;
    if (keyword.isEmpty) {
      setState(() {
        _searchLoading = false;
        _searchSuggestions = const <_OutboundSearchSuggestion>[];
        _searchRows = const <_OutboundSearchRow>[];
      });
      return;
    }
    setState(() => _searchLoading = true);
    final range = _effectiveSearchRange();
    final suggestions = await _querySearchSuggestions(
      keyword: keyword,
      type: _searchType,
      range: range,
    );
    final rows = await _querySearchRows(
      keyword: keyword,
      type: _searchType,
      range: range,
    );
    if (!mounted || version != _searchVersion) {
      return;
    }
    setState(() {
      _searchLoading = false;
      _searchSuggestions = suggestions;
      _searchRows = rows;
    });
  }

  Future<List<_OutboundSearchSuggestion>> _querySearchSuggestions({
    required String keyword,
    required _OutboundSearchType type,
    required DateTimeRange? range,
  }) async {
    final where = <String>[
      'sm.type = ${StockMovementType.orderOut.index}',
    ];
    final vars = <Variable<Object>>[];
    final like = '%${keyword.toLowerCase()}%';
    switch (type) {
      case _OutboundSearchType.waybill:
        where.add('LOWER(o.waybill_no) LIKE ?');
        vars.add(Variable.withString(like));
        break;
      case _OutboundSearchType.merchant:
        where.add('LOWER(o.merchant_name) LIKE ?');
        vars.add(Variable.withString(like));
        break;
      case _OutboundSearchType.product:
        where.add('(LOWER(p.code) LIKE ? OR LOWER(p.name) LIKE ?)');
        vars.add(Variable.withString(like));
        vars.add(Variable.withString(like));
        break;
      case _OutboundSearchType.batch:
        where.add('(LOWER(b.actual_batch) LIKE ? OR LOWER(b.date_batch) LIKE ?)');
        vars.add(Variable.withString(like));
        vars.add(Variable.withString(like));
        break;
    }
    if (range != null) {
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
      where.add('sm.movement_date BETWEEN ? AND ?');
      vars.add(Variable.withDateTime(start));
      vars.add(Variable.withDateTime(end));
    }
    final selectSql = switch (type) {
      _OutboundSearchType.waybill =>
        'o.waybill_no AS value, o.merchant_name AS subtitle, MAX(sm.movement_date) AS sort_date',
      _OutboundSearchType.merchant =>
        'o.merchant_name AS value, MAX(o.waybill_no) AS subtitle, MAX(sm.movement_date) AS sort_date',
      _OutboundSearchType.product =>
        "p.code AS value, b.actual_batch || ' · ' || b.date_batch AS subtitle, MAX(sm.movement_date) AS sort_date",
      _OutboundSearchType.batch =>
        "b.actual_batch AS value, p.code || ' · ' || b.date_batch AS subtitle, MAX(sm.movement_date) AS sort_date",
    };
    final groupBySql = switch (type) {
      _OutboundSearchType.waybill => 'o.waybill_no, o.merchant_name',
      _OutboundSearchType.merchant => 'o.merchant_name',
      _OutboundSearchType.product => 'p.code, b.actual_batch, b.date_batch',
      _OutboundSearchType.batch => 'b.actual_batch, p.code, b.date_batch',
    };
    final rows = await _database.customSelect(
      '''
      SELECT $selectSql
      FROM stock_movements sm
      INNER JOIN orders o ON o.id = sm.order_id
      INNER JOIN batches b ON b.id = sm.batch_id
      INNER JOIN products p ON p.id = b.product_id
      WHERE ${where.join(' AND ')}
      GROUP BY $groupBySql
      ORDER BY sort_date DESC
      LIMIT 10
      ''',
      variables: vars,
      readsFrom: {
        _database.stockMovements,
        _database.orders,
        _database.batches,
        _database.products,
      },
    ).get();
    return rows
        .map(
          (row) => _OutboundSearchSuggestion(
            value: row.data['value']?.toString() ?? '',
            subtitle: row.data['subtitle']?.toString() ?? '',
          ),
        )
        .where((row) => row.value.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<_OutboundSearchRow>> _querySearchRows({
    required String keyword,
    required _OutboundSearchType type,
    required DateTimeRange? range,
  }) async {
    final where = <String>[
      'sm.type = ${StockMovementType.orderOut.index}',
    ];
    final vars = <Variable<Object>>[];
    final like = '%${keyword.toLowerCase()}%';
    switch (type) {
      case _OutboundSearchType.waybill:
        where.add('LOWER(o.waybill_no) LIKE ?');
        vars.add(Variable.withString(like));
        break;
      case _OutboundSearchType.merchant:
        where.add('LOWER(o.merchant_name) LIKE ?');
        vars.add(Variable.withString(like));
        break;
      case _OutboundSearchType.product:
        where.add('(LOWER(p.code) LIKE ? OR LOWER(p.name) LIKE ?)');
        vars.add(Variable.withString(like));
        vars.add(Variable.withString(like));
        break;
      case _OutboundSearchType.batch:
        where.add('(LOWER(b.actual_batch) LIKE ? OR LOWER(b.date_batch) LIKE ?)');
        vars.add(Variable.withString(like));
        vars.add(Variable.withString(like));
        break;
    }
    if (range != null) {
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
      where.add('sm.movement_date BETWEEN ? AND ?');
      vars.add(Variable.withDateTime(start));
      vars.add(Variable.withDateTime(end));
    }
    final rows = await _database.customSelect(
      '''
      SELECT
        o.id AS order_id,
        o.waybill_no,
        o.merchant_name,
        p.code AS product_code,
        b.actual_batch,
        b.date_batch,
        SUM(sm.boxes) AS total_boxes,
        MAX(sm.movement_date) AS movement_date
      FROM stock_movements sm
      INNER JOIN orders o ON o.id = sm.order_id
      INNER JOIN batches b ON b.id = sm.batch_id
      INNER JOIN products p ON p.id = b.product_id
      WHERE ${where.join(' AND ')}
      GROUP BY o.id, o.waybill_no, o.merchant_name, p.code, b.actual_batch, b.date_batch
      ORDER BY movement_date DESC, o.waybill_no ASC
      LIMIT 200
      ''',
      variables: vars,
      readsFrom: {
        _database.stockMovements,
        _database.orders,
        _database.batches,
        _database.products,
      },
    ).get();
    return rows
        .map((row) => _OutboundSearchRow(
              orderId: row.data['order_id'] as int? ?? 0,
              waybillNo: row.data['waybill_no']?.toString() ?? '',
              merchantName: row.data['merchant_name']?.toString() ?? '',
              productCode: row.data['product_code']?.toString() ?? '',
              actualBatch: row.data['actual_batch']?.toString() ?? '',
              dateBatch: row.data['date_batch']?.toString() ?? '',
              boxes: row.data['total_boxes'] as int? ?? 0,
              movementDate: _parseSqlDateTime(row.data['movement_date']),
            ))
        .where((row) => row.orderId > 0)
        .toList(growable: false);
  }

  DateTime _parseSqlDateTime(Object? value) {
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      if (value > 1000000000000000) {
        return DateTime.fromMicrosecondsSinceEpoch(value);
      }
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime(1970);
    }
    return DateTime(1970);
  }

  void _selectOrder(int orderId) {
    setState(() {
      _selectedOrderId = _selectedOrderId == orderId ? null : orderId;
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

  List<_OutboundRow> _detailRows(_CalendarState? state) {
    final rows = state?.rows ?? const <_OutboundRow>[];
    final selectedOrderId = _selectedOrderId;
    if (selectedOrderId == null) {
      return rows;
    }
    return rows.where((row) => row.orderId == selectedOrderId).toList();
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

  Future<void> _openOrders() async {
    await pushAndRefresh(
      context,
      route: MaterialPageRoute(
        builder: (_) => OrderListScreen(database: _database, dateRange: _range),
      ),
      onRefresh: () {
        setState(() {
          _stateFuture = _loadState();
        });
      },
    );
  }

  Future<void> _openInventory() async {
    await pushAndRefresh(
      context,
      route: MaterialPageRoute(
        builder: (_) => InventoryDetailScreen(database: _database),
      ),
      onRefresh: () {
        setState(() {
          _stateFuture = _loadState();
        });
      },
    );
  }
}

class _CalendarState {
  const _CalendarState({
    required this.totalPieces,
    required this.outboundBoxes,
    required this.orders,
    required this.rows,
    required this.batchCodesByProductDate,
  });

  final int totalPieces;
  final int outboundBoxes;
  final List<_OutboundOrderSummary> orders;
  final List<_OutboundRow> rows;
  final Map<String, List<String>> batchCodesByProductDate;
}

class _OutboundRow {
  const _OutboundRow({
    required this.productCode,
    required this.actualBatch,
    required this.dateBatch,
    required this.boxesPerBoard,
    required this.boxes,
    required this.orderId,
    required this.waybillNo,
    required this.merchantName,
  });

  final String productCode;
  final String actualBatch;
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

enum _OutboundSearchType { waybill, merchant, product, batch }

enum _SearchRangePreset { all, today, yesterday, week, month, custom }

class _OutboundSearchSuggestion {
  const _OutboundSearchSuggestion({
    required this.value,
    required this.subtitle,
  });

  final String value;
  final String subtitle;
}

class _OutboundSearchRow {
  const _OutboundSearchRow({
    required this.orderId,
    required this.waybillNo,
    required this.merchantName,
    required this.productCode,
    required this.actualBatch,
    required this.dateBatch,
    required this.boxes,
    required this.movementDate,
  });

  final int orderId;
  final String waybillNo;
  final String merchantName;
  final String productCode;
  final String actualBatch;
  final String dateBatch;
  final int boxes;
  final DateTime movementDate;
}

class _OutboundSearchPanel extends StatelessWidget {
  const _OutboundSearchPanel({
    required this.controller,
    required this.focusNode,
    required this.searchType,
    required this.rangePreset,
    required this.customRange,
    required this.suggestions,
    required this.loading,
    required this.onTypeChanged,
    required this.onRangePresetChanged,
    required this.onPickCustomRange,
    required this.onChanged,
    required this.onSuggestionTap,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final _OutboundSearchType searchType;
  final _SearchRangePreset rangePreset;
  final DateTimeRange? customRange;
  final List<_OutboundSearchSuggestion> suggestions;
  final bool loading;
  final ValueChanged<_OutboundSearchType> onTypeChanged;
  final ValueChanged<_SearchRangePreset> onRangePresetChanged;
  final VoidCallback onPickCustomRange;
  final ValueChanged<String> onChanged;
  final ValueChanged<_OutboundSearchSuggestion> onSuggestionTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final timeEnabled = searchType != _OutboundSearchType.waybill;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _typeChip(
                label: '运单号',
                type: _OutboundSearchType.waybill,
              ),
              _typeChip(
                label: '商家',
                type: _OutboundSearchType.merchant,
              ),
              _typeChip(
                label: '产品',
                type: _OutboundSearchType.product,
              ),
              _typeChip(
                label: '批号',
                type: _OutboundSearchType.batch,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: switch (searchType) {
                _OutboundSearchType.waybill => '输入运单号，如 169',
                _OutboundSearchType.merchant => '输入商家，如 鸿旺',
                _OutboundSearchType.product => '输入产品编号/名称，如 72067',
                _OutboundSearchType.batch => '输入实际批号或日期批号',
              },
              suffixIcon: controller.text.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: const Color(0xFFF7F9FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (!timeEnabled)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '运单号按全历史唯一匹配',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _rangeChip('今日', _SearchRangePreset.today),
                  const SizedBox(width: 6),
                  _rangeChip('昨日', _SearchRangePreset.yesterday),
                  const SizedBox(width: 6),
                  _rangeChip('一周', _SearchRangePreset.week),
                  const SizedBox(width: 6),
                  _rangeChip('一月', _SearchRangePreset.month),
                  const SizedBox(width: 6),
                  _rangeChip('全部', _SearchRangePreset.all),
                  const SizedBox(width: 6),
                  ActionChip(
                    label: Text(
                      customRange == null
                          ? '自定义'
                          : '${_formatDate(customRange!.start)}-${_formatDate(customRange!.end)}',
                    ),
                    onPressed: onPickCustomRange,
                  ),
                ],
              ),
            ),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (suggestions.isNotEmpty && focusNode.hasFocus) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = suggestions[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      item.value,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: item.subtitle.isEmpty
                        ? null
                        : Text(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    onTap: () => onSuggestionTap(item),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _typeChip({
    required String label,
    required _OutboundSearchType type,
  }) {
    final selected = searchType == type;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTypeChanged(type),
    );
  }

  Widget _rangeChip(String label, _SearchRangePreset preset) {
    return ChoiceChip(
      label: Text(label),
      selected: rangePreset == preset,
      onSelected: (_) => onRangePresetChanged(preset),
    );
  }
}

class _OutboundSearchResultCard extends StatelessWidget {
  const _OutboundSearchResultCard({
    required this.rows,
  });

  final List<_OutboundSearchRow> rows;

  @override
  Widget build(BuildContext context) {
    final waybills = rows.map((e) => e.orderId).toSet().length;
    final products = rows.map((e) => e.productCode).toSet().length;
    final batches =
        rows.map((e) => '${e.productCode}|${e.actualBatch}|${e.dateBatch}').toSet().length;
    final totalBoxes = rows.fold<int>(0, (sum, row) => sum + row.boxes);
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
            '反查结果 ${rows.length} 条',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '运单 $waybills 单 · 箱数 $totalBoxes 箱 · 产品 $products 个 · 批号 $batches 个',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const Text('当前条件无已出库记录', style: TextStyle(color: AppTheme.textSecondary))
          else
            ...rows.map((row) {
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '运单 ${row.waybillNo} · ${row.merchantName}',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${row.productCode} · ${row.actualBatch} · ${row.dateBatch} · ${row.boxes}箱',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '出库时间 ${_formatDate(row.movementDate)}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
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
    required this.batchCodesByProductDate,
  });

  final String title;
  final List<_OutboundRow> rows;
  final Map<String, List<String>> batchCodesByProductDate;

  @override
  Widget build(BuildContext context) {
    final groups = _OutboundGroup.fromRows(rows);
    final duplicateBatchKeys =
        _duplicateProductDateBatchKeys(batchCodesByProductDate);
    final batchCodesByKey = batchCodesByProductDate;
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
            ],
          ),
          const SizedBox(height: 8),
          if (groups.isEmpty)
            const Text('暂无出库', style: TextStyle(color: AppTheme.textSecondary))
          else
            ...groups.map(
              (group) => _buildGroup(
                group,
                duplicateBatchKeys: duplicateBatchKeys,
                batchCodesByKey: batchCodesByKey,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroup(
    _OutboundGroup group, {
    required Set<String> duplicateBatchKeys,
    required Map<String, List<String>> batchCodesByKey,
  }) {
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
          ...group.rows.map(
            (row) => _buildProductRow(
              row,
              duplicateBatchKeys: duplicateBatchKeys,
              batchCodesByKey: batchCodesByKey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow(
    _OutboundRow row, {
    required Set<String> duplicateBatchKeys,
    required Map<String, List<String>> batchCodesByKey,
  }) {
    final productDateKey = '${row.productCode}|${row.dateBatch}';
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
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                children: [
                  TextSpan(text: '${row.productCode} · '),
                  ..._batchCodeSpans(
                    row.actualBatch,
                    variants:
                        batchCodesByKey[productDateKey] ?? const <String>[],
                    highlightDifferences:
                        duplicateBatchKeys.contains(productDateKey),
                  ),
                  TextSpan(text: ' · ${row.dateBatch}'),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${row.boxes}箱',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

Set<String> _duplicateProductDateBatchKeys(Map<String, List<String>> variants) {
  return variants.entries
      .where((entry) => entry.value.toSet().length > 1)
      .map((entry) => entry.key)
      .toSet();
}

List<InlineSpan> _batchCodeSpans(
  String code, {
  required List<String> variants,
  required bool highlightDifferences,
}) {
  if (!highlightDifferences || variants.toSet().length <= 1) {
    return <InlineSpan>[
      TextSpan(
        text: code,
        style: const TextStyle(color: AppTheme.textPrimary),
      ),
    ];
  }
  final normalized = variants.toSet().toList()..sort();
  final maxLength = normalized.fold<int>(
      0, (max, item) => item.length > max ? item.length : max);
  final differsAt = List<bool>.filled(maxLength, false);
  for (var i = 0; i < maxLength; i += 1) {
    String? pivot;
    for (final value in normalized) {
      final char = i < value.length ? value[i] : '';
      pivot ??= char;
      if (char != pivot) {
        differsAt[i] = true;
        break;
      }
    }
  }
  final spans = <InlineSpan>[];
  for (var i = 0; i < code.length; i += 1) {
    final isDiff = i < differsAt.length && differsAt[i];
    spans.add(
      TextSpan(
        text: code[i],
        style: TextStyle(
          color: isDiff ? const Color(0xFFDC2626) : AppTheme.textPrimary,
        ),
      ),
    );
  }
  return spans;
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
