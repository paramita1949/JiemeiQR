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

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with WidgetsBindingObserver {
  late final AppDatabase _database;
  late final OrderDao _orderDao;
  late final ProductDao _productDao;
  late final OrderCompletionService _completionService;
  late final bool _ownsDatabase;
  late final ScrollController _scrollController;
  late Future<_OrderDetailViewData> _detailFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsDatabase = widget.database == null;
    _scrollController = ScrollController();
    _database = widget.database ?? AppDatabase();
    _orderDao = OrderDao(_database);
    _productDao = ProductDao(_database);
    _completionService = OrderCompletionService(_database);
    _detailFuture = _loadDetail();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    if (_ownsDatabase) {
      _database.close();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshDetail();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_OrderDetailViewData>(
          future: _detailFuture,
          builder: (context, snapshot) {
            final viewData = snapshot.data;
            final detail = viewData?.detail;
            final batchCodesByProductDate = viewData?.batchCodesByProductDate ??
                const <String, List<String>>{};
            final duplicateBatchKeys = detail == null
                ? const <String>{}
                : _duplicateProductDateBatches(batchCodesByProductDate);
            return RefreshIndicator(
              onRefresh: _refreshDetail,
              child: ListView(
                controller: _scrollController,
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
                  if (detail == null &&
                      snapshot.connectionState != ConnectionState.done)
                    const Center(child: CircularProgressIndicator())
                  else if (detail == null)
                    const Text('未找到运单')
                  else ...[
                    _HeaderCard(
                      detail: detail,
                      onToggleUrgent: (next) => _setUrgent(next),
                      onSelectScannerGun: () =>
                          _openHeaderScannerGunSelector(detail),
                    ),
                    const SizedBox(height: 10),
                    _StatusControls(
                      status: detail.order.status,
                      onChanged: _setStatus,
                      onComplete: _confirmComplete,
                    ),
                    if (detail.order.status != OrderStatus.done) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          key: const Key('addOrderLineButton'),
                          onPressed: () => _openAddOrderLine(detail),
                          icon: const Icon(Icons.add),
                          label: const Text('新增产品'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    ...detail.lines.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _LineCard(
                          line: line,
                          highlightBatch: duplicateBatchKeys.contains(
                            _productDateKey(
                              productCode: line.product.code,
                              dateBatch: line.batch.dateBatch,
                            ),
                          ),
                          batchCodeVariants:
                              batchCodesByProductDate[_productDateKey(
                                    productCode: line.product.code,
                                    dateBatch: line.batch.dateBatch,
                                  )] ??
                                  const <String>[],
                          onEditLine: () => _editOrderLine(line),
                          onDeleteLine: () => _deleteOrderLine(line),
                          canTogglePicked:
                              detail.order.status != OrderStatus.done,
                          canModifyLine:
                              detail.order.status != OrderStatus.done,
                          onPickedChanged: (next) => _setOrderLinePicked(
                            line: line,
                            isPicked: next,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _refreshDetail() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _detailFuture = _loadDetail();
    });
    await _detailFuture;
  }

  Future<_OrderDetailViewData> _loadDetail() async {
    final detail = await _orderDao.orderDetail(widget.orderId);
    final batchCodesByProductDate = await _productDao.batchCodesByProductDate();
    return _OrderDetailViewData(
      detail: detail,
      batchCodesByProductDate: batchCodesByProductDate,
    );
  }

  Future<void> _reloadDetail({bool preserveScroll = false}) async {
    if (!mounted) {
      return;
    }
    final lastOffset = preserveScroll && _scrollController.hasClients
        ? _scrollController.offset
        : null;
    setState(() {
      _detailFuture = _loadDetail();
    });
    await _detailFuture;
    if (lastOffset == null || !mounted || !_scrollController.hasClients) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final maxOffset = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(lastOffset.clamp(0.0, maxOffset));
    });
  }

  Future<void> _setStatus(OrderStatus status) async {
    try {
      await _completionService.updateStatus(
        orderId: widget.orderId,
        target: status,
      );
      if (status == OrderStatus.picked) {
        await _orderDao.setOrderItemsPickedByOrder(
          orderId: widget.orderId,
          isPicked: true,
        );
      }
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
    await _reloadDetail(preserveScroll: true);
  }

  Future<void> _setUrgent(bool isUrgent) async {
    await _orderDao.setUrgent(widget.orderId, isUrgent);
    await _reloadDetail(preserveScroll: true);
  }

  Future<void> _openHeaderScannerGunSelector(OrderDetail detail) async {
    final options = await _orderDao.scannerGunOptions();
    if (!mounted) {
      return;
    }
    final selected = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (context) => _HeaderScannerGunSheet(
        options: options,
        selected: detail.order.scannerGun?.trim() ?? '',
      ),
    );
    if (selected == null) {
      return;
    }
    await _orderDao.updateOrderBasic(
      orderId: detail.order.id,
      waybillNo: detail.order.waybillNo,
      merchantName: detail.order.merchantName,
      orderDate: detail.order.orderDate,
      scannerGun: selected.isEmpty ? null : selected,
    );
    await _reloadDetail(preserveScroll: true);
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
    var selectedScannerGun = detail.order.scannerGun?.trim() ?? '';
    var scannerGunOptions = await _orderDao.scannerGunOptions();
    var deleteArmedScannerGun = '';
    if (!mounted) {
      return;
    }

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          scrollable: true,
          title: const Text('编辑订单信息'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: waybillController,
                decoration: _editDialogInputDecoration('运单号'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: merchantController,
                decoration: _editDialogInputDecoration('商家'),
              ),
              const SizedBox(height: 12),
              _EditDialogDatePicker(
                dateText: _formatDate(selectedDate),
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
              const SizedBox(height: 12),
              _ScannerGunSelector(
                options: scannerGunOptions,
                selected: selectedScannerGun,
                deleteArmed: deleteArmedScannerGun,
                onSelected: (option) {
                  setLocalState(() {
                    deleteArmedScannerGun = '';
                    selectedScannerGun =
                        selectedScannerGun == option ? '' : option;
                  });
                },
                onArmDelete: (option) {
                  setLocalState(() => deleteArmedScannerGun = option);
                },
                onDeleted: (option) async {
                  await _orderDao.deleteScannerGunOption(option);
                  final options = await _orderDao.scannerGunOptions();
                  setLocalState(() {
                    scannerGunOptions = options;
                    deleteArmedScannerGun = '';
                    if (selectedScannerGun == option) {
                      selectedScannerGun = '';
                    }
                  });
                },
                onAdd: () async {
                  final label = await _promptScannerGunLabel(context);
                  if (label == null || label.trim().isEmpty) {
                    return;
                  }
                  await _orderDao.addScannerGunOption(label);
                  final options = await _orderDao.scannerGunOptions();
                  setLocalState(() {
                    scannerGunOptions = options;
                    deleteArmedScannerGun = '';
                    selectedScannerGun = label.trim();
                  });
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
    try {
      await _orderDao.updateOrderBasic(
        orderId: widget.orderId,
        waybillNo: waybillNo,
        merchantName: merchantName,
        orderDate: selectedDate,
        scannerGun: selectedScannerGun.isEmpty ? null : selectedScannerGun,
      );
    } on DuplicateWaybillNoException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('运单号已存在')),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _detailFuture = _loadDetail();
    });
  }

  Future<String?> _promptScannerGunLabel(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增扫码枪'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '扫码枪名称',
            hintText: '例如 5号',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
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
        _detailFuture = _loadDetail();
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
          frozenBoxes: line.batch.frozenBoxes,
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
        _detailFuture = _loadDetail();
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

  Future<void> _setOrderLinePicked({
    required OrderDetailLine line,
    required bool isPicked,
  }) async {
    try {
      await _orderDao.updateOrderItemPicked(
        itemId: line.item.id,
        isPicked: isPicked,
      );
    } on OrderItemUpdateNotAllowedException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已完成订单不允许修改单条拣货状态')),
      );
      return;
    }
    final latest = await _orderDao.orderDetail(widget.orderId);
    if (!mounted) {
      return;
    }
    await _reloadDetail(preserveScroll: true);
    final shouldAutoSetPicked = isPicked &&
        latest.order.status == OrderStatus.pending &&
        latest.lines.isNotEmpty &&
        latest.lines.every((item) => item.item.isPicked);
    if (!shouldAutoSetPicked) {
      return;
    }
    await _setStatus(OrderStatus.picked);
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
    Navigator.of(context).pop(true);
  }

  Future<void> _openAddOrderLine(OrderDetail detail) async {
    final productOptions = await _productDao.productsForOrderEntry();
    if (!mounted) {
      return;
    }
    if (productOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可新增的产品库存')),
      );
      return;
    }
    final result = await showDialog<_AddOrderLineResult>(
      context: context,
      builder: (context) => _AddOrderLineDialog(
        productDao: _productDao,
        productOptions: productOptions,
        orderId: detail.order.id,
      ),
    );
    if (result == null) {
      return;
    }
    try {
      await _orderDao.appendItemToOrder(
        orderId: detail.order.id,
        item: PendingOrderItemInput(
          productId: result.product.id,
          batchId: result.batch.batch.id,
          boxes: result.boxes,
          boxesPerBoard: result.batch.batch.boxesPerBoard,
          piecesPerBox: result.product.piecesPerBox,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _detailFuture = _loadDetail();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已新增产品明细')),
      );
    } on DuplicateOrderItemException catch (duplicate) {
      if (!mounted) {
        return;
      }
      final shouldMerge = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('重复明细'),
          content: const Text('同一运单下该产品批号已添加，是否累加箱数？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('累加'),
            ),
          ],
        ),
      );
      if (shouldMerge != true) {
        return;
      }
      await _orderDao.mergeDuplicateOrderItem(
        itemId: duplicate.itemId,
        appendBoxes: result.boxes,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _detailFuture = _loadDetail();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已累加到原明细')),
      );
    } on OrderItemUpdateNotAllowedException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已完成订单不允许新增明细')),
      );
    } on InsufficientStockException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('库存不足，无法新增明细')),
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
}

class _OrderDetailViewData {
  const _OrderDetailViewData({
    required this.detail,
    required this.batchCodesByProductDate,
  });

  final OrderDetail detail;
  final Map<String, List<String>> batchCodesByProductDate;
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.detail,
    required this.onToggleUrgent,
    required this.onSelectScannerGun,
  });

  final OrderDetail detail;
  final ValueChanged<bool> onToggleUrgent;
  final VoidCallback onSelectScannerGun;

  @override
  Widget build(BuildContext context) {
    final status = _statusMeta(detail.order.status);
    final totalBoxes =
        detail.lines.fold<int>(0, (sum, line) => sum + line.item.boxes);
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _HeaderScannerGunSelector(
                scannerGun: detail.order.scannerGun?.trim() ?? '',
                onTap: onSelectScannerGun,
              ),
              const SizedBox(width: 8),
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
          Row(
            children: [
              Text(
                _formatDate(detail.order.orderDate),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => onToggleUrgent(!detail.order.isUrgent),
                    child: const Text(
                      '紧急',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _InlineToggleSwitch(
                    value: detail.order.isUrgent,
                    onTap: () => onToggleUrgent(!detail.order.isUrgent),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '总箱数 $totalBoxes箱',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
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
    required this.onComplete,
  });

  final OrderStatus status;
  final ValueChanged<OrderStatus> onChanged;
  final VoidCallback onComplete;

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
        const SizedBox(width: 8),
        Expanded(
          child: _StatusButton(
            label: '完成',
            color: const Color(0xFF16A34A),
            selected: status == OrderStatus.done,
            onTap: status == OrderStatus.done ? null : onComplete,
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
  final VoidCallback? onTap;

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
    required this.canTogglePicked,
    required this.canModifyLine,
    required this.onPickedChanged,
    required this.onEditLine,
    this.onDeleteLine,
  });

  final OrderDetailLine line;
  final bool highlightBatch;
  final List<String> batchCodeVariants;
  final bool canTogglePicked;
  final bool canModifyLine;
  final ValueChanged<bool> onPickedChanged;
  final VoidCallback onEditLine;
  final VoidCallback? onDeleteLine;

  @override
  Widget build(BuildContext context) {
    final boardText = BoardCalculator.format(
      boxes: line.item.boxes,
      boxesPerBoard: line.batch.boxesPerBoard,
    );
    final remainText = BoardCalculator.format(
      boxes: line.availableAfterReserveBoxes,
      boxesPerBoard: line.batch.boxesPerBoard,
    );
    final lowStockThresholdBoxes = line.batch.boxesPerBoard * 10;
    final isLowStock = line.availableAfterReserveBoxes < lowStockThresholdBoxes;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: line.item.isPicked ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              line.item.isPicked ? const Color(0xFF86EFAC) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                    children: [
                      TextSpan(text: line.product.code),
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
              const SizedBox(width: 8),
              _LineActionButton(
                tooltip: '编辑该产品',
                icon: Icons.edit_outlined,
                onPressed: canModifyLine ? onEditLine : null,
              ),
              _LineActionButton(
                tooltip: '删除该产品',
                icon: Icons.delete_outline,
                onPressed: canModifyLine ? onDeleteLine : null,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              _MetricChip(
                text: line.item.isPicked ? '已拣货' : '未拣货',
                textColor: line.item.isPicked
                    ? const Color(0xFF166534)
                    : const Color(0xFF9A3412),
                backgroundColor: line.item.isPicked
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFFEDD5),
              ),
              const Spacer(),
              Switch.adaptive(
                value: line.item.isPicked,
                onChanged: canTogglePicked ? onPickedChanged : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
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
              _MetricChip(
                text: '预占后余量 $remainText',
                textColor: isLowStock
                    ? const Color(0xFFC2410C)
                    : const Color(0xFF166534),
                backgroundColor: isLowStock
                    ? const Color(0xFFFFEDD5)
                    : const Color(0xFFDCFCE7),
              ),
              _MetricChip(text: '库位 ${line.batch.location ?? '--'}'),
              if (line.item.isException)
                const _MetricChip(
                  text: '异常',
                  textColor: Color(0xFFC2410C),
                  backgroundColor: Color(0xFFFFEDD5),
                ),
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

class _LineActionButton extends StatelessWidget {
  const _LineActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 22,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

InputDecoration _editDialogInputDecoration(String label) {
  const borderColor = Color(0xFFE3E0DA);
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xFFF8F7F4),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppTheme.primary, width: 1.4),
    ),
  );
}

class _EditDialogDatePicker extends StatelessWidget {
  const _EditDialogDatePicker({
    required this.dateText,
    required this.onTap,
  });

  final String dateText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8F7F4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE3E0DA)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '日期',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateText,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.calendar_month_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerGunSelector extends StatelessWidget {
  const _ScannerGunSelector({
    required this.options,
    required this.selected,
    required this.deleteArmed,
    required this.onSelected,
    required this.onArmDelete,
    required this.onDeleted,
    required this.onAdd,
  });

  final List<String> options;
  final String selected;
  final String deleteArmed;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onArmDelete;
  final ValueChanged<String> onDeleted;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final hasSelected = selected.trim().isNotEmpty;
    final optionRows = <List<String>>[];
    for (var index = 0; index < options.length; index += 3) {
      optionRows.add(options.skip(index).take(3).toList());
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E1D8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _ScannerGunTag.hermesOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 18,
                  color: _ScannerGunTag.hermesOrange,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '扫码枪',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: hasSelected
                      ? _ScannerGunTag.hermesOrange.withValues(alpha: 0.12)
                      : const Color(0xFFF1F0ED),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hasSelected ? '已选 $selected' : '未选择',
                  style: TextStyle(
                    color: hasSelected
                        ? _ScannerGunTag.hermesOrange
                        : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            key: const Key('scannerGunOptionGrid'),
            width: double.infinity,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F1EC),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE7E0D8)),
            ),
            child: Column(
              children: [
                for (var rowIndex = 0;
                    rowIndex < optionRows.length;
                    rowIndex++) ...[
                  if (rowIndex > 0) const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var columnIndex = 0; columnIndex < 3; columnIndex++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: columnIndex == 2 ? 0 : 8,
                            ),
                            child: columnIndex < optionRows[rowIndex].length
                                ? _ScannerGunTag(
                                    label: optionRows[rowIndex][columnIndex],
                                    selected: selected ==
                                        optionRows[rowIndex][columnIndex],
                                    showDelete: deleteArmed ==
                                        optionRows[rowIndex][columnIndex],
                                    onTap: () => onSelected(
                                      optionRows[rowIndex][columnIndex],
                                    ),
                                    onLongPress: () => onArmDelete(
                                      optionRows[rowIndex][columnIndex],
                                    ),
                                    onDeleted: () => onDeleted(
                                      optionRows[rowIndex][columnIndex],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '长按标签可删除',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _ScannerGunAddTag(
                key: const Key('scannerGunAddButton'),
                onTap: onAdd,
              ),
            ],
          ),
          if (deleteArmed.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              '点击红色叉叉删除，点其他标签退出删除状态',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScannerGunTag extends StatelessWidget {
  const _ScannerGunTag({
    required this.label,
    required this.selected,
    required this.showDelete,
    required this.onTap,
    required this.onLongPress,
    required this.onDeleted,
  });

  final String label;
  final bool selected;
  final bool showDelete;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDeleted;
  static const hermesOrange = Color(0xFFA8552A);
  static const unselectedBackground = Color(0xFFF7F7F5);
  static const unselectedBorder = Color(0xFFE3E0DA);
  static const unselectedText = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : unselectedText;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? hermesOrange : unselectedBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? hermesOrange : unselectedBorder,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: hermesOrange.withValues(alpha: 0.22),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: foreground,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        if (showDelete)
          Positioned(
            right: -7,
            top: -7,
            child: GestureDetector(
              onTap: onDeleted,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ScannerGunAddTag extends StatelessWidget {
  const _ScannerGunAddTag({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '新增扫码枪',
      child: Material(
        color: const Color(0xFFFFF7F1),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _ScannerGunTag.hermesOrange.withValues(alpha: 0.55),
                width: 1.4,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  semanticLabel: '新增扫码枪',
                  size: 21,
                  color: _ScannerGunTag.hermesOrange,
                ),
                SizedBox(width: 5),
                Text(
                  '新增',
                  style: TextStyle(
                    color: _ScannerGunTag.hermesOrange,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
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

class _InlineToggleSwitch extends StatelessWidget {
  const _InlineToggleSwitch({
    required this.value,
    required this.onTap,
  });

  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: value,
      label: '紧急开关',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 42,
          height: 24,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? const Color(0xFFDC2626) : const Color(0xFFE9E6F2),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: value ? const Color(0xFFDC2626) : const Color(0xFF7C7A86),
              width: 1.5,
            ),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: value ? Colors.white : const Color(0xFF7C7A86),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderScannerGunSelector extends StatelessWidget {
  const _HeaderScannerGunSelector({
    required this.scannerGun,
    required this.onTap,
  });

  final String scannerGun;
  final VoidCallback onTap;
  static const hermesOrange = Color(0xFFA8552A);

  @override
  Widget build(BuildContext context) {
    final hasValue = scannerGun.isNotEmpty;
    return Material(
      key: const Key('headerScannerGunSelector'),
      color: hasValue
          ? hermesOrange.withValues(alpha: 0.12)
          : const Color(0xFFFFF7F1),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: hermesOrange.withValues(alpha: hasValue ? 0.34 : 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasValue ? scannerGun : '扫码枪',
                style: const TextStyle(
                  color: hermesOrange,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: hermesOrange,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderScannerGunSheet extends StatelessWidget {
  const _HeaderScannerGunSheet({
    required this.options,
    required this.selected,
  });

  final List<String> options;
  final String selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择扫码枪',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final option in options)
                  _QuickScannerGunOption(
                    key: Key('quickScannerGunOption-$option'),
                    label: option,
                    selected: selected == option,
                    onTap: () => Navigator.of(context).pop(option),
                  ),
                _QuickScannerGunOption(
                  key: const Key('quickScannerGunOption-clear'),
                  label: '清空',
                  selected: selected.isEmpty,
                  muted: true,
                  onTap: () => Navigator.of(context).pop(''),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickScannerGunOption extends StatelessWidget {
  const _QuickScannerGunOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.muted = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool muted;
  static const hermesOrange = Color(0xFFA8552A);

  @override
  Widget build(BuildContext context) {
    final color = muted ? AppTheme.textSecondary : hermesOrange;
    return Material(
      color: selected ? color.withValues(alpha: 0.14) : const Color(0xFFF8F7F4),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minWidth: 70, minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? color : const Color(0xFFE3E0DA),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
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

Set<String> _duplicateProductDateBatches(Map<String, List<String>> variants) {
  return variants.entries
      .where((entry) => entry.value.length > 1)
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

class _AddOrderLineResult {
  const _AddOrderLineResult({
    required this.product,
    required this.batch,
    required this.boxes,
  });

  final Product product;
  final AvailableBatch batch;
  final int boxes;
}

class _AddOrderLineDialog extends StatefulWidget {
  const _AddOrderLineDialog({
    required this.productDao,
    required this.productOptions,
    required this.orderId,
  });

  final ProductDao productDao;
  final List<ProductInventoryOption> productOptions;
  final int orderId;

  @override
  State<_AddOrderLineDialog> createState() => _AddOrderLineDialogState();
}

class _AddOrderLineDialogState extends State<_AddOrderLineDialog> {
  late final TextEditingController _boxesController;
  late Product _selectedProduct;
  List<AvailableBatch> _availableBatches = const <AvailableBatch>[];
  AvailableBatch? _selectedBatch;
  bool _loadingBatches = true;

  @override
  void initState() {
    super.initState();
    _boxesController = TextEditingController();
    _selectedProduct = widget.productOptions.first.product;
    _loadBatches(_selectedProduct.id);
  }

  @override
  void dispose() {
    _boxesController.dispose();
    super.dispose();
  }

  Future<void> _loadBatches(int productId) async {
    setState(() => _loadingBatches = true);
    final batches = await widget.productDao.availableBatchesForProduct(
      productId,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _availableBatches = batches;
      _selectedBatch = batches.isEmpty ? null : batches.first;
      _loadingBatches = false;
    });
  }

  void _submit() {
    final selectedBatch = _selectedBatch;
    final boxes = int.tryParse(_boxesController.text.trim());
    if (selectedBatch == null || boxes == null || boxes <= 0) {
      return;
    }
    if (boxes > selectedBatch.availableBoxes) {
      return;
    }
    Navigator.of(context).pop(
      _AddOrderLineResult(
        product: _selectedProduct,
        batch: selectedBatch,
        boxes: boxes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedBatch = _selectedBatch;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
      contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: const Text('新增产品明细'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int>(
              key: const Key('addLineProductDropdown'),
              initialValue: _selectedProduct.id,
              decoration: const InputDecoration(labelText: '产品'),
              items: widget.productOptions
                  .map(
                    (option) => DropdownMenuItem<int>(
                      value: option.product.id,
                      child: Text(
                          '${option.product.code}（可用${option.currentBoxes}箱）'),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                if (id == null) {
                  return;
                }
                final next = widget.productOptions
                    .where((option) => option.product.id == id)
                    .map((option) => option.product)
                    .firstOrNull;
                if (next == null) {
                  return;
                }
                setState(() {
                  _selectedProduct = next;
                });
                _loadBatches(id);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('addLineBoxesField'),
              controller: _boxesController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '箱数',
                helperText: selectedBatch == null
                    ? '当前产品无可用批号'
                    : '当前批号可用 ${selectedBatch.availableBoxes} 箱',
              ),
            ),
            const SizedBox(height: 10),
            if (_loadingBatches)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_availableBatches.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('当前产品无可用批号'),
              )
            else
              ..._availableBatches.map(
                (row) {
                  final batchCodeVariants = _availableBatches
                      .where(
                          (item) => item.batch.dateBatch == row.batch.dateBatch)
                      .map((item) => item.batch.actualBatch)
                      .toList();
                  final selected = row.batch.id == _selectedBatch?.batch.id;
                  final sameDateDifferentBatch = selectedBatch != null &&
                      row.batch.id != selectedBatch.batch.id &&
                      row.batch.dateBatch == selectedBatch.batch.dateBatch;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _BatchChoiceTile(
                      row: row,
                      selected: selected,
                      sameDateDifferentBatch: sameDateDifferentBatch,
                      batchCodeVariants: batchCodeVariants,
                      onTap: () => setState(() => _selectedBatch = row),
                    ),
                  );
                },
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
          key: const Key('addLineConfirmButton'),
          onPressed: _submit,
          child: const Text('新增'),
        ),
      ],
    );
  }
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
    final selectedBatch = widget.editableBatches.firstWhere(
      (item) => item.batch.id == _selectedBatchId,
    );
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
      contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: const Text('编辑产品明细'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择批号',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _boxesController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '箱数',
                helperText: '当前批号可用 ${selectedBatch.availableBoxes} 箱',
              ),
            ),
            const SizedBox(height: 12),
            ...widget.editableBatches.map(
              (row) {
                final batchCodeVariants = widget.editableBatches
                    .where(
                        (item) => item.batch.dateBatch == row.batch.dateBatch)
                    .map((item) => item.batch.actualBatch)
                    .toList();
                final sameDateDifferentBatch =
                    row.batch.id != selectedBatch.batch.id &&
                        row.batch.dateBatch == selectedBatch.batch.dateBatch;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _BatchChoiceTile(
                    row: row,
                    selected: row.batch.id == _selectedBatchId,
                    sameDateDifferentBatch: sameDateDifferentBatch,
                    batchCodeVariants: batchCodeVariants,
                    onTap: () =>
                        setState(() => _selectedBatchId = row.batch.id),
                  ),
                );
              },
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

class _BatchChoiceTile extends StatelessWidget {
  const _BatchChoiceTile({
    required this.row,
    required this.selected,
    required this.sameDateDifferentBatch,
    required this.batchCodeVariants,
    required this.onTap,
  });

  final AvailableBatch row;
  final bool selected;
  final bool sameDateDifferentBatch;
  final List<String> batchCodeVariants;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppTheme.primary
        : sameDateDifferentBatch
            ? const Color(0xFFF59E0B)
            : const Color(0xFFE5E7EB);
    final tileColor = selected
        ? const Color(0xFFEFF6FF)
        : sameDateDifferentBatch
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFF8FAFC);
    return Material(
      color: tileColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          decoration: BoxDecoration(
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SelectionDot(selected: selected),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                        children: _batchCodeSpans(
                          row.batch.actualBatch,
                          variants: batchCodeVariants,
                          highlightDifferences:
                              batchCodeVariants.toSet().length > 1,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DialogInfoChip(text: row.batch.dateBatch),
                        _DialogInfoChip(text: '可用 ${row.availableBoxes} 箱'),
                        if (sameDateDifferentBatch)
                          const _DialogInfoChip(
                            text: '同日期',
                            textColor: Color(0xFFB45309),
                            backgroundColor: Color(0xFFFFF3C4),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppTheme.primary : const Color(0xFFCBD5E1),
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

class _DialogInfoChip extends StatelessWidget {
  const _DialogInfoChip({
    required this.text,
    this.textColor = AppTheme.primary,
    this.backgroundColor = Colors.white,
  });

  final String text;
  final Color textColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _productDateKey({
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
