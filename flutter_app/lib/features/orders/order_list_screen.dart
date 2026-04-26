import 'package:flutter/material.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/features/orders/order_detail_screen.dart';
import 'package:qrscan_flutter/features/orders/order_edit_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
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
  OrderStatus _status = OrderStatus.pending;
  final List<OrderSummary> _orders = <OrderSummary>[];
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
                IconButton.filledTonal(
                  tooltip: '日期筛选',
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _StatusTabs(
              selected: _status,
              onChanged: (status) {
                setState(() => _status = status);
                _refreshOrders();
              },
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _openNewWaybill,
              icon: const Icon(Icons.add),
              label: const Text('新增运单'),
            ),
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
                    order: order,
                    onTap: () => _openOrderDetail(order),
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
      _orders.clear();
    });
    final page = await _orderDao.orderSummariesPage(
      status: _status,
      dateRange: _dateRange,
      offset: 0,
      limit: _pageSize,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _orders.addAll(page.orders);
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
    setState(() => _dateRange = picked);
    _refreshOrders();
  }

  Future<void> _openNewWaybill() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderEditScreen(database: _database),
      ),
    );
    if (!mounted) {
      return;
    }
    _refreshOrders();
  }

  Future<void> _openOrderDetail(OrderSummary order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          database: _database,
          orderId: order.id,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    _refreshOrders();
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
    required this.onChanged,
  });

  final OrderStatus selected;
  final ValueChanged<OrderStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatusButton(
            label: '未完成',
            color: const Color(0xFFF97316),
            selected: selected == OrderStatus.pending,
            onTap: () => onChanged(OrderStatus.pending),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatusButton(
            label: '已拣货',
            color: const Color(0xFF2563EB),
            selected: selected == OrderStatus.picked,
            onTap: () => onChanged(OrderStatus.picked),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatusButton(
            label: '完成',
            color: const Color(0xFF16A34A),
            selected: selected == OrderStatus.done,
            onTap: () => onChanged(OrderStatus.done),
          ),
        ),
      ],
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
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
                  child: Text(
                    order.waybillNo,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
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
            const SizedBox(height: 9),
            Text(
              order.merchantName,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
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
              ],
            ),
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
