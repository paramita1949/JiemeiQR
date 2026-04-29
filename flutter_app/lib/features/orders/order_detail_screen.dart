import 'package:flutter/material.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
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
  late final ProductDao _productDao;
  late final OrderCompletionService _completionService;
  late final bool _ownsDatabase;
  late Future<OrderDetail> _detailFuture;

  @override
  void initState() {
    super.initState();
    _ownsDatabase = widget.database == null;
    _database = widget.database ?? AppDatabase();
    _orderDao = OrderDao(_database);
    _productDao = ProductDao(_database);
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
            final duplicateBatchDates =
                detail == null ? const <String>{} : _duplicateDateBatches(detail.lines);
            final batchCodesByDate =
                detail == null ? const <String, List<String>>{} : _batchCodesByDate(detail.lines);
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
                        highlightBatch:
                            duplicateBatchDates.contains(line.batch.dateBatch),
                        batchCodeVariants:
                            batchCodesByDate[line.batch.dateBatch] ?? const <String>[],
                        onEditLine: () => _editOrderLine(line),
                        onDeleteLine: () => _deleteOrderLine(line),
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
    try {
      await _completionService.updateStatus(
        orderId: widget.orderId,
        target: status,
      );
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

  Future<void> _editOrderLine(OrderDetailLine line) async {
    final available = await _productDao.availableBatchesForProduct(
      line.product.id,
      excludeOrderId: line.item.orderId,
    );
    final editableBatches = [...available];
    if (!editableBatches.any((item) => item.batch.id == line.batch.id)) {
      editableBatches.insert(
        0,
        AvailableBatch(
          batch: line.batch,
          currentBoxes: line.item.boxes,
          reservedBoxes: 0,
        ),
      );
    }
    if (!mounted) {
      return;
    }
    final result = await showDialog<_EditOrderLineResult>(
      context: context,
      builder: (context) => _EditOrderLineDialog(
        initialBoxes: line.item.boxes,
        initialBatchId: line.batch.id,
        editableBatches: editableBatches,
      ),
    );
    if (result == null) {
      return;
    }
    final selectedBatch = editableBatches
        .where((item) => item.batch.id == result.batchId)
        .firstOrNull;
    if (selectedBatch == null) {
      return;
    }
    try {
      await _orderDao.updateOrderItem(
        itemId: line.item.id,
        batchId: selectedBatch.batch.id,
        boxes: result.boxes,
        boxesPerBoard: selectedBatch.batch.boxesPerBoard,
        piecesPerBox: line.product.piecesPerBox,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _detailFuture = _orderDao.orderDetail(widget.orderId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已更新产品明细')),
      );
    } on OrderItemUpdateNotAllowedException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已完成订单不允许编辑明细')),
      );
    } on InsufficientStockException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('库存不足，无法保存修改')),
      );
    } on InvalidStockQuantityException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('箱数无效')),
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
    required this.highlightBatch,
    required this.batchCodeVariants,
    required this.onEditLine,
    this.onDeleteLine,
  });

  final OrderDetailLine line;
  final bool highlightBatch;
  final List<String> batchCodeVariants;
  final VoidCallback onEditLine;
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
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    children: [
                      TextSpan(
                        text: line.product.code,
                        style: const TextStyle(color: Color(0xFFDC2626)),
                      ),
                      const TextSpan(
                        text: ' · ',
                        style: TextStyle(color: AppTheme.textPrimary),
                      ),
                      TextSpan(
                        children: _batchCodeSpans(
                          line.batch.actualBatch,
                          variants: batchCodeVariants,
                          highlightDifferences: highlightBatch,
                        ),
                      ),
                      const TextSpan(
                        text: ' · ',
                        style: TextStyle(color: AppTheme.textPrimary),
                      ),
                      TextSpan(
                        text: line.batch.dateBatch,
                        style: const TextStyle(color: Color(0xFFDC2626)),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: '编辑该产品',
                onPressed: onEditLine,
                icon: const Icon(Icons.edit_outlined),
              ),
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
              _MetricChip(
                text: boardText,
                textColor: const Color(0xFFDC2626),
                backgroundColor: const Color(0xFFFEE2E2),
              ),
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

Set<String> _duplicateDateBatches(List<OrderDetailLine> lines) {
  final dateCounts = <String, int>{};
  for (final line in lines) {
    final key = line.batch.dateBatch;
    dateCounts[key] = (dateCounts[key] ?? 0) + 1;
  }
  return dateCounts.entries
      .where((entry) => entry.value > 1)
      .map((entry) => entry.key)
      .toSet();
}

class _EditOrderLineResult {
  const _EditOrderLineResult({
    required this.batchId,
    required this.boxes,
  });

  final int batchId;
  final int boxes;
}

class _EditOrderLineDialog extends StatefulWidget {
  const _EditOrderLineDialog({
    required this.initialBoxes,
    required this.initialBatchId,
    required this.editableBatches,
  });

  final int initialBoxes;
  final int initialBatchId;
  final List<AvailableBatch> editableBatches;

  @override
  State<_EditOrderLineDialog> createState() => _EditOrderLineDialogState();
}

class _EditOrderLineDialogState extends State<_EditOrderLineDialog> {
  late final TextEditingController _boxesController;
  late int _selectedBatchId;

  @override
  void initState() {
    super.initState();
    _boxesController = TextEditingController(
      text: widget.initialBoxes.toString(),
    );
    _selectedBatchId = widget.initialBatchId;
  }

  @override
  void dispose() {
    _boxesController.dispose();
    super.dispose();
  }

  void _submit() {
    final boxes = int.tryParse(_boxesController.text.trim());
    if (boxes == null || boxes <= 0) {
      return;
    }
    Navigator.of(context).pop(
      _EditOrderLineResult(batchId: _selectedBatchId, boxes: boxes),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑产品明细'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _selectedBatchId,
              decoration: const InputDecoration(labelText: '批号'),
              items: widget.editableBatches
                  .map(
                    (row) => DropdownMenuItem(
                      value: row.batch.id,
                      child: Text(
                        '${row.batch.actualBatch} · ${row.batch.dateBatch} · 可用${row.availableBoxes}箱',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _selectedBatchId = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _boxesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '箱数'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }
}

Map<String, List<String>> _batchCodesByDate(List<OrderDetailLine> lines) {
  final map = <String, List<String>>{};
  for (final line in lines) {
    map.putIfAbsent(line.batch.dateBatch, () => <String>[])
        .add(line.batch.actualBatch);
  }
  return map;
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
        style: const TextStyle(color: AppTheme.textPrimary),
      ),
    ];
  }
  final normalized = variants.toSet().toList()..sort();
  final maxLength = normalized.fold<int>(0, (max, item) => item.length > max ? item.length : max);
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
    spans.add(
      TextSpan(
        text: code[i],
        style: TextStyle(
          color: i < differsAt.length && differsAt[i]
              ? const Color(0xFFDC2626)
              : AppTheme.textPrimary,
        ),
      ),
    );
  }
  return spans;
}
