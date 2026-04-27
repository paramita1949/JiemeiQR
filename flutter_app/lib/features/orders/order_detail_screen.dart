import 'package:flutter/material.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';
import 'package:qrscan_flutter/features/orders/order_completion_service.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/utils/board_calculator.dart';
import 'package:qrscan_flutter/shared/widgets/delete_confirm_dialog.dart';
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: PageTitle(
                        icon: Icons.receipt_long_outlined,
                        title: '运单详情',
                        subtitle: '订单状态与产品明细',
                      ),
                    ),
                    if (detail != null) ...[
                      IconButton.filledTonal(
                        tooltip: '编辑订单',
                        onPressed: () => _editOrderBasic(detail),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        tooltip: '删除订单',
                        onPressed: _deleteOrder,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ],
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
                      child: _LineCard(
                        line: line,
                        onDeleteLine: detail.order.status == OrderStatus.done
                            ? null
                            : () => _deleteOrderLine(line),
                      ),
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

  Future<void> _editOrderBasic(OrderDetail detail) async {
    final waybillController =
        TextEditingController(text: detail.order.waybillNo);
    final merchantController = TextEditingController(
      text: detail.order.merchantName,
    );
    var selectedDate = DateTime(
      detail.order.orderDate.year,
      detail.order.orderDate.month,
      detail.order.orderDate.day,
    );

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('编辑订单信息'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: waybillController,
                decoration: const InputDecoration(labelText: '运单号'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: merchantController,
                decoration: const InputDecoration(labelText: '商家'),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('日期'),
                subtitle: Text(_formatDate(selectedDate)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    locale: const Locale('zh', 'CN'),
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(DateTime.now().year + 5),
                  );
                  if (picked == null) {
                    return;
                  }
                  setLocalState(() => selectedDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (shouldSave != true) {
      return;
    }
    final waybillNo = waybillController.text.trim();
    final merchantName = merchantController.text.trim();
    if (waybillNo.isEmpty || merchantName.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('运单号和商家不能为空')),
      );
      return;
    }
    await _orderDao.updateOrderBasic(
      orderId: widget.orderId,
      waybillNo: waybillNo,
      merchantName: merchantName,
      orderDate: selectedDate,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _detailFuture = _orderDao.orderDetail(widget.orderId);
    });
  }

  Future<void> _deleteOrder() async {
    final confirmed = await showDeleteConfirmDialog(
      context: context,
      title: '删除订单',
      message: '删除后不可恢复，确定删除该订单？',
      riskLevel: DeleteRiskLevel.high,
    );
    if (!confirmed) {
      return;
    }
    await _orderDao.deleteOrder(widget.orderId);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _deleteOrderLine(OrderDetailLine line) async {
    final confirmed = await showDeleteConfirmDialog(
      context: context,
      title: '删除产品明细',
      message: '确认删除 ${line.product.code} · ${line.batch.actualBatch} 这条明细？',
      riskLevel: DeleteRiskLevel.normal,
    );
    if (!confirmed) {
      return;
    }
    try {
      await _orderDao.deleteOrderItem(itemId: line.item.id);
      if (!mounted) {
        return;
      }
      try {
        await _orderDao.orderDetail(widget.orderId);
      } on StateError {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(true);
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _detailFuture = _orderDao.orderDetail(widget.orderId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除该产品明细')),
      );
    } on OrderItemDeleteNotAllowedException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已完成订单不允许删除单条明细')),
      );
    }
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
  const _LineCard({
    required this.line,
    this.onDeleteLine,
  });

  final OrderDetailLine line;
  final VoidCallback? onDeleteLine;

  @override
  Widget build(BuildContext context) {
    final boardText = BoardCalculator.format(
      boxes: line.item.boxes,
      boxesPerBoard: line.batch.boxesPerBoard,
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
          Row(
            children: [
              Expanded(
                child: Text(
                  '${line.product.code} · ${line.batch.actualBatch} · ${line.batch.dateBatch}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onDeleteLine != null)
                IconButton(
                  tooltip: '删除该产品',
                  onPressed: onDeleteLine,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
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
                    '${line.batch.boxesPerBoard}箱/板 · ${line.product.piecesPerBox}件/箱',
              ),
              _MetricChip(text: '库位 ${line.batch.location ?? '--'}'),
              if (line.batch.tsRequired)
                const _MetricChip(
                  text: 'TS',
                  textColor: Color(0xFFDC2626),
                  backgroundColor: Color(0xFFFEE2E2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.text,
    this.textColor = AppTheme.primary,
    this.backgroundColor = const Color(0xFFF3F6FB),
  });

  final String text;
  final Color textColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
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
