import 'package:flutter/material.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/features/orders/order_detail_screen.dart';
import 'package:qrscan_flutter/features/orders/order_edit_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/utils/board_calculator.dart';
import 'package:qrscan_flutter/shared/utils/navigation_refresh.dart';
import 'package:qrscan_flutter/shared/widgets/delete_confirm_dialog.dart';
import 'package:qrscan_flutter/shared/widgets/page_title.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({
    super.key,
    this.database,
    this.dateRange,
  });

  final AppDatabase? database;
  final DateTimeRange? dateRange;

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  static const int _pageSize = 50;

  late final AppDatabase _database;
  late final OrderDao _orderDao;
  late final bool _ownsDatabase;
  late DateTimeRange? _dateRange;
  _OrderQuickFilter _quickFilter = _OrderQuickFilter.pendingOnly;
  OrderStatus? _status;
  final List<OrderSummary> _orders = <OrderSummary>[];
  List<OrderRestockAggregate> _restockAggregates = const [];
  int? _restockFloorFilter;
  bool _restockUrgentOnly = false;
  OrderStatusCounts? _counts;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _ownsDatabase = widget.database == null;
    _database = widget.database ?? AppDatabase();
    _orderDao = OrderDao(_database);
    _dateRange = widget.dateRange;
    _quickFilter = widget.dateRange == null
        ? _OrderQuickFilter.pendingOnly
        : _OrderQuickFilter.custom;
    _status = null;
    _refreshOrders();
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 42),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PageTitle(
                    icon: Icons.receipt_long_outlined,
                    title: '订单信息',
                    subtitle: _dateRangeText(),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filled(
                      key: const Key('newWaybillTopButton'),
                      tooltip: '新增运单',
                      onPressed: _openNewWaybill,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF7A8CA8),
                        foregroundColor: Colors.white,
                        hoverColor: const Color(0xFF6E809A),
                        highlightColor: const Color(0xFF64748E),
                      ),
                      icon: const Icon(Icons.playlist_add_rounded),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: '日期筛选',
                      onPressed: _pickDateRange,
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            _QuickFilterChips(
              selected: _quickFilter,
              onSelected: _applyQuickFilter,
            ),
            const SizedBox(height: 14),
            _StatusTabs(
              selected: _status,
              exceptionSelected: _quickFilter == _OrderQuickFilter.exception,
              onExceptionSelected: () =>
                  _applyQuickFilter(_OrderQuickFilter.exception),
              onChanged: (status) {
                setState(() {
                  _status = status;
                  if (_quickFilter == _OrderQuickFilter.pendingOnly &&
                      status == OrderStatus.done) {
                    _quickFilter = _OrderQuickFilter.today;
                    _dateRange = _singleDayRange(DateTime.now());
                  }
                });
                _refreshOrders();
              },
            ),
            if (_counts != null) ...[
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  children: [
                    TextSpan(
                      text: '完成 ${_counts!.done}单',
                      style: const TextStyle(color: Color(0xFF16A34A)),
                    ),
                    const TextSpan(text: ' · '),
                    TextSpan(
                      text: '未完成 ${_counts!.unfinished}单',
                      style: const TextStyle(color: Color(0xFFF97316)),
                    ),
                    const TextSpan(text: ' · '),
                    TextSpan(
                      text: '已拣货 ${_counts!.picked}单',
                      style: const TextStyle(color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
            ],
            if (_restockAggregates.isNotEmpty) ...[
              const SizedBox(height: 8),
              _RestockAggregateCard(
                rows: _restockAggregates,
                selectedFloor: _restockFloorFilter,
                urgentOnly: _restockUrgentOnly,
                onSelectFloor: (floor) {
                  setState(() => _restockFloorFilter = floor);
                },
                onToggleUrgent: () {
                  setState(() => _restockUrgentOnly = !_restockUrgentOnly);
                  _refreshOrders();
                },
                onTapRow: _showRestockWaybillLines,
              ),
            ],
            const SizedBox(height: 10),
            if (_loadingInitial)
              const Center(child: CircularProgressIndicator())
            else if (_orders.isEmpty)
              const _EmptyOrders()
            else
              ..._orders.map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OrderCard(
                    key: ValueKey<int>(order.id),
                    order: order,
                    onTap: () => _openOrderDetail(order),
                    onDelete: () => _deleteOrder(order.id),
                  ),
                ),
              ),
            if (!_loadingInitial && _hasMore)
              Center(
                child: TextButton(
                  key: const Key('orderLoadMoreButton'),
                  onPressed: _loadingMore ? null : _loadMoreOrders,
                  child: Text(
                    _loadingMore ? '加载中...' : '加载更多（${_orders.length}/$_total）',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshOrders() async {
    setState(() {
      _loadingInitial = true;
      _loadingMore = false;
      _hasMore = false;
      _total = 0;
      _counts = null;
      _restockAggregates = const [];
      _orders.clear();
    });
    final page = await _orderDao.orderSummariesPage(
      status: _status,
      dateRange: _dateRange,
      unfinishedOnly: _quickFilter == _OrderQuickFilter.pendingOnly,
      exceptionOnly: _quickFilter == _OrderQuickFilter.exception,
      offset: 0,
      limit: _pageSize,
    );
    final counts = await _orderDao.orderStatusCounts(dateRange: _dateRange);
    final hideRestock = _quickFilter == _OrderQuickFilter.exception ||
        _status == OrderStatus.picked ||
        _status == OrderStatus.done;
    final restockStatus = _status ?? OrderStatus.pending;
    final restockAggregates = hideRestock
        ? const <OrderRestockAggregate>[]
        : await _orderDao.orderRestockAggregates(
            status: restockStatus,
            dateRange: _dateRange,
            unfinishedOnly: false,
            urgentOnly: _restockUrgentOnly,
          );
    if (!mounted) {
      return;
    }
    final availableFloors = _extractAvailableFloors(restockAggregates);
    setState(() {
      _orders.addAll(page.orders);
      _counts = counts;
      _restockAggregates = restockAggregates;
      if (_restockFloorFilter != null &&
          !availableFloors.contains(_restockFloorFilter)) {
        _restockFloorFilter = null;
      }
      _total = page.total;
      _hasMore = _orders.length < _total;
      _loadingInitial = false;
    });
  }

  Future<void> _loadMoreOrders() async {
    if (_loadingMore || !_hasMore) {
      return;
    }
    setState(() => _loadingMore = true);
    final page = await _orderDao.orderSummariesPage(
      status: _status,
      dateRange: _dateRange,
      unfinishedOnly: _quickFilter == _OrderQuickFilter.pendingOnly,
      exceptionOnly: _quickFilter == _OrderQuickFilter.exception,
      offset: _orders.length,
      limit: _pageSize,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _orders.addAll(page.orders);
      _total = page.total;
      _hasMore = _orders.length < _total;
      _loadingMore = false;
    });
  }

  String _dateRangeText() {
    if (_quickFilter == _OrderQuickFilter.pendingOnly) {
      return '未完成';
    }
    if (_quickFilter == _OrderQuickFilter.exception) {
      return '异常订单';
    }
    final range = _dateRange;
    if (range == null) {
      return '全部日期';
    }
    final startDate =
        DateTime(range.start.year, range.start.month, range.start.day);
    final endDate = DateTime(range.end.year, range.end.month, range.end.day);
    final start = '${_formatDate(startDate)} ${_weekdayLabel(startDate)}';
    final end = '${_formatDate(endDate)} ${_weekdayLabel(endDate)}';
    return start == end ? start : '$start - $end';
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      locale: const Locale('zh', 'CN'),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _dateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: DateTime(now.year, now.month, now.day),
          ),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _dateRange = picked;
      _quickFilter = _OrderQuickFilter.custom;
    });
    _refreshOrders();
  }

  Future<void> _openNewWaybill() async {
    await pushAndRefresh(
      context,
      route: MaterialPageRoute(
        builder: (_) => OrderEditScreen(database: _database),
      ),
      onRefresh: _refreshOrders,
    );
  }

  Future<void> _openOrderDetail(OrderSummary order) async {
    await pushAndRefresh(
      context,
      route: MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          database: _database,
          orderId: order.id,
        ),
      ),
      onRefresh: _refreshOrders,
    );
  }

  void _applyQuickFilter(_OrderQuickFilter filter) {
    setState(() {
      _quickFilter = filter;
      switch (filter) {
        case _OrderQuickFilter.pendingOnly:
          _dateRange = null;
          _status = null;
        case _OrderQuickFilter.exception:
          _dateRange = null;
          _status = null;
        case _OrderQuickFilter.today:
          _dateRange = _singleDayRange(DateTime.now());
          _status = null;
        case _OrderQuickFilter.yesterday:
          _dateRange = _singleDayRange(
            DateTime.now().subtract(const Duration(days: 1)),
          );
          _status = null;
        case _OrderQuickFilter.week:
          final today = DateTime.now();
          final end = DateTime(today.year, today.month, today.day);
          final start = end.subtract(const Duration(days: 6));
          _dateRange = DateTimeRange(start: start, end: end);
          _status = null;
        case _OrderQuickFilter.month:
          final now = DateTime.now();
          _dateRange = DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: DateTime(now.year, now.month + 1, 0),
          );
          _status = null;
        case _OrderQuickFilter.custom:
          break;
      }
    });
    _refreshOrders();
  }

  Future<void> _deleteOrder(int orderId) async {
    final confirmed = await showDeleteConfirmDialog(
      context: context,
      title: '删除订单',
      message: '删除后不可恢复，确定删除该订单？',
      riskLevel: DeleteRiskLevel.high,
    );
    if (!confirmed) {
      return;
    }
    await _orderDao.deleteOrder(orderId);
    if (!mounted) {
      return;
    }
    await _refreshOrders();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('订单已删除')),
    );
  }

  Future<void> _showRestockWaybillLines(OrderRestockAggregate row) async {
    final lines = await _orderDao.orderRestockWaybillLines(
      productCode: row.productCode,
      actualBatch: row.actualBatch,
      dateBatch: row.dateBatch,
      status: _status,
      dateRange: _dateRange,
      unfinishedOnly: _quickFilter == _OrderQuickFilter.pendingOnly,
      urgentOnly: _restockUrgentOnly,
    );
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RestockWaybillSheet(
        aggregate: row,
        lines: lines,
        onOpenOrder: (orderId) {
          Navigator.of(context).pop();
          final order = _orders.where((item) => item.id == orderId).firstOrNull;
          if (order != null) {
            _openOrderDetail(order);
            return;
          }
          pushAndRefresh(
            this.context,
            route: MaterialPageRoute(
              builder: (_) => OrderDetailScreen(
                database: _database,
                orderId: orderId,
              ),
            ),
            onRefresh: _refreshOrders,
          );
        },
      ),
    );
  }
}

DateTimeRange _singleDayRange(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return DateTimeRange(start: day, end: day);
}

Set<int> _extractFloorsFromLocation(String? location) {
  if (location == null) {
    return const <int>{};
  }
  final text = location.trim();
  if (text.isEmpty) {
    return const <int>{};
  }
  final floors = <int>{};
  for (final match in RegExp(r'(\d+)\s*[楼层]').allMatches(text)) {
    final value = int.tryParse(match.group(1) ?? '');
    if (value != null) {
      floors.add(value);
    }
  }
  for (final match in RegExp(r'([一二三四五六七八九十]+)\s*[楼层]').allMatches(text)) {
    final value = _parseChineseFloor(match.group(1) ?? '');
    if (value != null) {
      floors.add(value);
    }
  }
  return floors;
}

int? _parseChineseFloor(String raw) {
  if (raw.isEmpty) {
    return null;
  }
  if (raw == '十') {
    return 10;
  }
  if (!raw.contains('十')) {
    return _chineseDigitMap[raw];
  }
  final parts = raw.split('十');
  final tensRaw = parts.first;
  final onesRaw = parts.length > 1 ? parts.last : '';
  final tens = tensRaw.isEmpty ? 1 : (_chineseDigitMap[tensRaw] ?? 0);
  final ones = onesRaw.isEmpty ? 0 : (_chineseDigitMap[onesRaw] ?? 0);
  if (tens == 0) {
    return null;
  }
  return tens * 10 + ones;
}

List<int> _extractAvailableFloors(List<OrderRestockAggregate> rows) {
  final floors = rows
      .expand((row) => _extractFloorsFromLocation(row.location))
      .toSet()
      .toList()
    ..sort();
  return floors;
}

const Map<String, int> _chineseDigitMap = <String, int>{
  '一': 1,
  '二': 2,
  '三': 3,
  '四': 4,
  '五': 5,
  '六': 6,
  '七': 7,
  '八': 8,
  '九': 9,
};

enum _OrderQuickFilter {
  today,
  yesterday,
  week,
  month,
  pendingOnly,
  exception,
  custom,
}

class _QuickFilterChips extends StatelessWidget {
  const _QuickFilterChips({
    required this.selected,
    required this.onSelected,
  });

  final _OrderQuickFilter selected;
  final ValueChanged<_OrderQuickFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickChip(
            label: '未完成',
            selected: selected == _OrderQuickFilter.pendingOnly,
            onTap: () => onSelected(_OrderQuickFilter.pendingOnly),
          ),
          const SizedBox(width: 8),
          _QuickChip(
            label: '今日',
            selected: selected == _OrderQuickFilter.today,
            onTap: () => onSelected(_OrderQuickFilter.today),
          ),
          const SizedBox(width: 8),
          _QuickChip(
            label: '昨日',
            selected: selected == _OrderQuickFilter.yesterday,
            onTap: () => onSelected(_OrderQuickFilter.yesterday),
          ),
          const SizedBox(width: 8),
          _QuickChip(
            label: '一周',
            selected: selected == _OrderQuickFilter.week,
            onTap: () => onSelected(_OrderQuickFilter.week),
          ),
          const SizedBox(width: 8),
          _QuickChip(
            label: '一月',
            selected: selected == _OrderQuickFilter.month,
            onTap: () => onSelected(_OrderQuickFilter.month),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE5EDFF) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF2563EB) : const Color(0xFFD5DDEB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF1D4ED8) : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

String _weekdayLabel(DateTime date) {
  const labels = <int, String>{
    DateTime.monday: '周一',
    DateTime.tuesday: '周二',
    DateTime.wednesday: '周三',
    DateTime.thursday: '周四',
    DateTime.friday: '周五',
    DateTime.saturday: '周六',
    DateTime.sunday: '周日',
  };
  return labels[date.weekday] ?? '';
}

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({
    required this.selected,
    required this.exceptionSelected,
    required this.onChanged,
    required this.onExceptionSelected,
  });

  final OrderStatus? selected;
  final bool exceptionSelected;
  final ValueChanged<OrderStatus?> onChanged;
  final VoidCallback onExceptionSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatusButton(
            label: '全部',
            color: AppTheme.primary,
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          const SizedBox(width: 8),
          _StatusButton(
            label: '未完成',
            color: const Color(0xFFF97316),
            selected: selected == OrderStatus.pending,
            onTap: () => onChanged(OrderStatus.pending),
          ),
          const SizedBox(width: 8),
          _StatusButton(
            label: '已拣货',
            color: const Color(0xFF2563EB),
            selected: selected == OrderStatus.picked,
            onTap: () => onChanged(OrderStatus.picked),
          ),
          const SizedBox(width: 8),
          _StatusButton(
            label: '完成',
            color: const Color(0xFF16A34A),
            selected: selected == OrderStatus.done,
            onTap: () => onChanged(OrderStatus.done),
          ),
          const SizedBox(width: 8),
          _StatusButton(
            label: '异常',
            color: const Color(0xFFDC2626),
            selected: exceptionSelected,
            onTap: onExceptionSelected,
          ),
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  const _OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    required this.onDelete,
  });

  final OrderSummary order;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  static const double _actionWidth = 88;
  double _offsetX = 0;

  void _openActions() => setState(() => _offsetX = -_actionWidth);
  void _closeActions() => setState(() => _offsetX = 0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final next = (_offsetX + details.delta.dx).clamp(-_actionWidth, 0.0);
        if (next != _offsetX) {
          setState(() => _offsetX = next);
        }
      },
      onHorizontalDragEnd: (details) {
        final shouldOpen = details.primaryVelocity == null
            ? _offsetX.abs() > _actionWidth * 0.5
            : details.primaryVelocity! < -150 || _offsetX.abs() > 44;
        if (shouldOpen) {
          _openActions();
        } else {
          _closeActions();
        }
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: _actionWidth,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TextButton(
                  onPressed: () {
                    _closeActions();
                    widget.onDelete();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    '删除',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_offsetX, 0, 0),
            child: _OrderCardContent(
              order: widget.order,
              onTap: () {
                if (_offsetX != 0) {
                  _closeActions();
                  return;
                }
                widget.onTap();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCardContent extends StatelessWidget {
  const _OrderCardContent({
    required this.order,
    required this.onTap,
  });

  final OrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _statusMeta(order.status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
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
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.waybillNo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          order.merchantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  alignment: Alignment.center,
                  width: 64,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: status.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${order.dateText} · ${order.itemCount}个产品 · ${order.totalBoxes}箱',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (order.hasTsRequired) const _TsPill(),
                if (order.hasException) const _ExceptionPill(),
                if (order.itemCount == 1 && order.locationsText.isNotEmpty)
                  Text(
                    '库位 ${order.locationsText}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _OrderPickProgress(order: order),
          ],
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(
          '暂无订单',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TsPill extends StatelessWidget {
  const _TsPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'TS',
        style: TextStyle(
          color: Color(0xFFDC2626),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusMeta {
  const _StatusMeta(this.label, this.color);

  final String label;
  final Color color;
}

_StatusMeta _statusMeta(OrderStatus status) {
  return switch (status) {
    OrderStatus.pending => const _StatusMeta('未完成', Color(0xFFF97316)),
    OrderStatus.picked => const _StatusMeta('已拣货', Color(0xFF2563EB)),
    OrderStatus.done => const _StatusMeta('完成', Color(0xFF16A34A)),
  };
}

String _formatDate(DateTime date) => '${date.year}.${date.month}.${date.day}';

class _RestockAggregateCard extends StatelessWidget {
  const _RestockAggregateCard({
    required this.rows,
    required this.selectedFloor,
    required this.urgentOnly,
    required this.onSelectFloor,
    required this.onToggleUrgent,
    required this.onTapRow,
  });

  final List<OrderRestockAggregate> rows;
  final int? selectedFloor;
  final bool urgentOnly;
  final ValueChanged<int?> onSelectFloor;
  final VoidCallback onToggleUrgent;
  final ValueChanged<OrderRestockAggregate> onTapRow;

  @override
  Widget build(BuildContext context) {
    final floors = _extractAvailableFloors(rows);
    final visibleRows = selectedFloor == null
        ? rows
        : rows
            .where(
              (row) => _extractFloorsFromLocation(row.location).contains(
                selectedFloor,
              ),
            )
            .toList();
    final duplicateKeys = _duplicateProductDateKeys(visibleRows);
    final totalBoxes =
        visibleRows.fold<int>(0, (sum, row) => sum + row.totalBoxes);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '备货汇总（按产品/批号/日期）',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '总箱数 $totalBoxes 箱',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (floors.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickChip(
                    label: '紧急',
                    selected: urgentOnly,
                    onTap: onToggleUrgent,
                  ),
                  const SizedBox(width: 8),
                  _QuickChip(
                    label: '全部楼层',
                    selected: selectedFloor == null,
                    onTap: () => onSelectFloor(null),
                  ),
                  for (final floor in floors) ...[
                    const SizedBox(width: 8),
                    _QuickChip(
                      label: '$floor楼',
                      selected: selectedFloor == floor,
                      onTap: () => onSelectFloor(floor),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: Scrollbar(
              thumbVisibility: visibleRows.length > 5,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: visibleRows.length,
                itemBuilder: (context, index) {
                  final row = visibleRows[index];
                  final key = _restockProductDateKey(
                    productCode: row.productCode,
                    dateBatch: row.dateBatch,
                  );
                  final restockColor = _restockQuantityColor(row);
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onTapRow(row),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 3,
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          children: [
                            TextSpan(
                              text: '${row.productCode} · ',
                            ),
                            ..._batchCodeSpans(
                              row.actualBatch,
                              variants: row.batchCodeVariants,
                              highlightDifferences: duplicateKeys.contains(key),
                            ),
                            const TextSpan(
                              text: ' · ',
                            ),
                            TextSpan(
                              text: row.dateBatch,
                              style: const TextStyle(
                                color: Color(0xFFDC2626),
                              ),
                            ),
                            TextSpan(
                              text: ' · ${row.totalBoxes}箱 · ',
                              style: TextStyle(color: restockColor),
                            ),
                            TextSpan(
                              text: BoardCalculator.format(
                                boxes: row.totalBoxes,
                                boxesPerBoard: row.boxesPerBoard,
                              ),
                              style: TextStyle(color: restockColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestockWaybillSheet extends StatelessWidget {
  const _RestockWaybillSheet({
    required this.aggregate,
    required this.lines,
    required this.onOpenOrder,
  });

  final OrderRestockAggregate aggregate;
  final List<OrderRestockWaybillLine> lines;
  final ValueChanged<int> onOpenOrder;

  @override
  Widget build(BuildContext context) {
    final sortedLines = [...lines]..sort((a, b) {
        final boxDiff = b.totalBoxes.compareTo(a.totalBoxes);
        if (boxDiff != 0) {
          return boxDiff;
        }
        return b.orderDate.compareTo(a.orderDate);
      });
    final totalBoxes = sortedLines.fold<int>(
      0,
      (sum, item) => sum + item.totalBoxes,
    );
    final location = aggregate.location?.trim();
    final summaryText =
        '合计 ${aggregate.totalBoxes}箱 · ${BoardCalculator.format(boxes: aggregate.totalBoxes, boxesPerBoard: aggregate.boxesPerBoard)}'
        '${location == null || location.isEmpty ? '' : ' · 库位 $location'}';
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF3F6FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${aggregate.productCode} · ${aggregate.actualBatch} · ${aggregate.dateBatch}',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            summaryText,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '运单 ${sortedLines.length} 单 · 箱数 $totalBoxes 箱（按箱数降序）',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _RestockRemainText(aggregate: aggregate),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: sortedLines.isEmpty
                ? const Center(
                    child: Text(
                      '当前筛选范围内没有运单明细',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: sortedLines.length,
                    itemBuilder: (context, index) {
                      final line = sortedLines[index];
                      final status = _restockLineStatusMeta(line);
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onOpenOrder(line.orderId),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.waybillNo,
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${line.merchantName} · ${_formatDate(line.orderDate)}',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${line.totalBoxes}箱 · ${BoardCalculator.format(boxes: line.totalBoxes, boxesPerBoard: line.boxesPerBoard)}',
                                      style: const TextStyle(
                                        color: Color(0xFF1D4ED8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: status.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  status.label,
                                  style: TextStyle(
                                    color: status.color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RestockRemainText extends StatelessWidget {
  const _RestockRemainText({required this.aggregate});

  final OrderRestockAggregate aggregate;

  @override
  Widget build(BuildContext context) {
    final remainText = BoardCalculator.format(
      boxes: aggregate.availableAfterReserveBoxes,
      boxesPerBoard: aggregate.boxesPerBoard,
    );
    final lowThresholdBoxes = aggregate.boxesPerBoard * 10;
    final isLow = aggregate.availableAfterReserveBoxes < lowThresholdBoxes;
    return Text(
      '余量 $remainText',
      style: TextStyle(
        color: isLow ? const Color(0xFFC2410C) : const Color(0xFF166534),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

_StatusMeta _restockLineStatusMeta(OrderRestockWaybillLine line) {
  if (line.status == OrderStatus.done) {
    return _statusMeta(OrderStatus.done);
  }
  if (line.isFullyPicked) {
    return const _StatusMeta('已拣货', Color(0xFF2563EB));
  }
  return _statusMeta(OrderStatus.pending);
}

class _OrderPickProgress extends StatelessWidget {
  const _OrderPickProgress({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final total = order.itemCount;
    final picked =
        (order.status == OrderStatus.done || order.status == OrderStatus.picked)
            ? total
            : order.pickedItemCount.clamp(0, total);
    final progress = total <= 0 ? 0.0 : picked / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '拣货进度 $picked/$total',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: progress,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 1 ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
            ),
          ),
        ),
      ],
    );
  }
}

Color _restockQuantityColor(OrderRestockAggregate row) {
  return row.totalBoxes >= row.boxesPerBoard
      ? const Color(0xFFDC2626)
      : const Color(0xFF2563EB);
}

Set<String> _duplicateProductDateKeys(List<OrderRestockAggregate> rows) {
  final keys = <String>{};
  for (final row in rows) {
    final key = _restockProductDateKey(
      productCode: row.productCode,
      dateBatch: row.dateBatch,
    );
    if (row.batchCodeVariants.toSet().length > 1) {
      keys.add(key);
    }
  }
  return keys;
}

class _ExceptionPill extends StatelessWidget {
  const _ExceptionPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF97316).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        '异常',
        style: TextStyle(
          color: Color(0xFFC2410C),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _restockProductDateKey({
  required String productCode,
  required String dateBatch,
}) {
  return '$productCode|$dateBatch';
}

List<InlineSpan> _batchCodeSpans(
  String code, {
  required List<String> variants,
  required bool highlightDifferences,
}) {
  if (!highlightDifferences || variants.length <= 1) {
    return <InlineSpan>[
      TextSpan(
        text: code,
        style: const TextStyle(color: AppTheme.textSecondary),
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
          color: isDiff ? const Color(0xFFDC2626) : AppTheme.textSecondary,
        ),
      ),
    );
  }
  return spans;
}
