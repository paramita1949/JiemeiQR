import 'package:flutter/material.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';
import 'package:qrscan_flutter/features/orders/order_completion_service.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/utils/board_calculator.dart';
import 'package:qrscan_flutter/shared/widgets/page_title.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.database,
  });

  final int orderId;
  final AppDatabase? database;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final AppDatabase _database;
  late final OrderDao _orderDao;
  late final OrderCompletionService _completionService;
  late final bool _ownsDatabase;
  late Future<OrderDetail> _detailFuture;

  @override
  void initState() {
    super.initState();
    _ownsDatabase = widget.database == null;
    _database = widget.database ?? AppDatabase();
    _orderDao = OrderDao(_database);
    _completionService = OrderCompletionService(_database);
    _detailFuture = _orderDao.orderDetail(widget.orderId);
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
        child: FutureBuilder<OrderDetail>(
          future: _detailFuture,
          builder: (context, snapshot) {
            final detail = snapshot.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 80),
              children: [
                const PageTitle(
                  icon: Icons.receipt_long_outlined,
                  title: '运单详情',
                  subtitle: '订单状态与产品明细',
                ),
                const SizedBox(height: 14),
                if (snapshot.connectionState != ConnectionState.done)
                  const Center(child: CircularProgressIndicator())
                else if (detail == null)
                  const Text('未找到运单')
                else ...[
                  _HeaderCard(detail: detail),
                  const SizedBox(height: 10),
                  _StatusControls(
                    status: detail.order.status,
                    onChanged: _setStatus,
                  ),
                  const SizedBox(height: 10),
                  ...detail.lines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LineCard(line: line),
                    ),
                  ),
                  if (detail.order.status != OrderStatus.done) ...[
                    const SizedBox(height: 4),
                    FilledButton(
                      key: const Key('completeOrderButton'),
                      onPressed: _confirmComplete,
                      child: const Text('完成'),
                    ),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _setStatus(OrderStatus status) async {
    await _orderDao.setStatus(widget.orderId, status);
    if (!mounted) {
      return;
    }
    setState(() {
      _detailFuture = _orderDao.orderDetail(widget.orderId);
    });
  }

  Future<void> _confirmComplete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认完成'),
        content: const Text('完成后将扣减对应批号库存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认完成'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await _completionService.complete(widget.orderId);
    } on InsufficientStockException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('库存不足，无法完成')),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _detailFuture = _orderDao.orderDetail(widget.orderId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('订单已完成')),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.detail});

  final OrderDetail detail;

  @override
  Widget build(BuildContext context) {
    final status = _statusMeta(detail.order.status);
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
                  detail.order.waybillNo,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusPill(label: status.label, color: status.color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail.order.merchantName,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatDate(detail.order.orderDate),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusControls extends StatelessWidget {
  const _StatusControls({
    required this.status,
    required this.onChanged,
  });

  final OrderStatus status;
  final ValueChanged<OrderStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatusButton(
            label: '未完成',
            color: const Color(0xFFF97316),
            selected: status == OrderStatus.pending,
            onTap: () => onChanged(OrderStatus.pending),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatusButton(
            label: '已拣货',
            color: const Color(0xFF2563EB),
            selected: status == OrderStatus.picked,
            onTap: () => onChanged(OrderStatus.picked),
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
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.line});

  final OrderDetailLine line;

  @override
  Widget build(BuildContext context) {
    final boardText = BoardCalculator.format(
      boxes: line.item.boxes,
      boxesPerBoard: line.item.boxesPerBoard,
    );
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
            '${line.product.code} · ${line.batch.actualBatch} · ${line.batch.dateBatch}',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(text: '${line.item.boxes}箱'),
              _MetricChip(text: boardText),
              _MetricChip(
                text:
                    '${line.item.boxesPerBoard}箱/板 · ${line.item.piecesPerBox}件/箱',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 12,
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
