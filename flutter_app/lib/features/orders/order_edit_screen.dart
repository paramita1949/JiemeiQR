import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/utils/board_calculator.dart';
import 'package:qrscan_flutter/shared/widgets/delete_confirm_dialog.dart';
import 'package:qrscan_flutter/shared/widgets/page_title.dart';

class OrderEditScreen extends StatefulWidget {
  const OrderEditScreen({
    super.key,
    this.database,
  });

  final AppDatabase? database;

  @override
  State<OrderEditScreen> createState() => _OrderEditScreenState();
}

class _OrderEditScreenState extends State<OrderEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _waybillNoController = TextEditingController();
  final _merchantController = TextEditingController();
  final _boxesController = TextEditingController();

  late final AppDatabase _database;
  late final ProductDao _productDao;
  late final OrderDao _orderDao;
  late final bool _ownsDatabase;
  late Future<_OrderEditState> _stateFuture;

  DateTime _orderDate = DateTime.now();
  Product? _selectedProduct;
  AvailableBatch? _selectedBatch;
  List<ProductInventoryOption> _productOptions = const [];
  List<Product> _products = const [];
  List<AvailableBatch> _availableBatches = const [];
  String? _draftOrderKey;
  List<OrderDetailLine> _draftLines = const [];

  @override
  void initState() {
    super.initState();
    _ownsDatabase = widget.database == null;
    _database = widget.database ?? AppDatabase();
    _productDao = ProductDao(_database);
    _orderDao = OrderDao(_database);
    _boxesController.addListener(() => setState(() {}));
    _waybillNoController.addListener(_onOrderHeaderChanged);
    _merchantController.addListener(_onOrderHeaderChanged);
    _stateFuture = _loadState();
  }

  @override
  void dispose() {
    _waybillNoController.dispose();
    _merchantController.dispose();
    _boxesController.dispose();
    if (_ownsDatabase) {
      _database.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_OrderEditState>(
          future: _stateFuture,
          builder: (context, snapshot) {
            final state = snapshot.data;
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 80),
                children: [
                  const PageTitle(
                    icon: Icons.add_box_outlined,
                    title: '新增运单',
                    subtitle: '商家、产品、批号、箱数录入',
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: '订单信息',
                    children: [
                      TextFormField(
                        key: const Key('waybillNoField'),
                        controller: _waybillNoController,
                        validator: _required,
                        decoration: _inputDecoration('运单号'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        key: const Key('merchantNameField'),
                        controller: _merchantController,
                        validator: _required,
                        decoration: _inputDecoration('商家'),
                      ),
                      if (state != null && state.merchants.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: state.merchants
                              .map(
                                (name) => ActionChip(
                                  label: Text(name),
                                  onPressed: () {
                                    _merchantController.text = name;
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 10),
                      ChoiceChip(
                        label: Text(_formatDate(_orderDate)),
                        selected: true,
                        avatar: const Icon(Icons.calendar_month_outlined),
                        onSelected: (_) => _pickOrderDate(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _SectionCard(
                    title: '产品明细',
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: _selectedProduct?.id,
                        validator: (value) => value == null ? '必选' : null,
                        decoration: _inputDecoration('产品'),
                        items: _products
                            .map(_productOptionFor)
                            .map(
                              (option) => DropdownMenuItem(
                                value: option.product.id,
                                child: _ProductOptionLabel(option: option),
                              ),
                            )
                            .toList(),
                        onChanged: (id) => _selectProduct(id),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedBatch?.batch.id,
                        validator: (value) => value == null ? '必选' : null,
                        decoration: _inputDecoration('批号'),
                        items: _availableBatches
                            .map(
                              (row) => DropdownMenuItem(
                                value: row.batch.id,
                                child: Text(
                                  '${row.batch.actualBatch} · ${row.batch.dateBatch}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (id) => setState(() {
                          _selectedBatch = _availableBatches
                              .where((row) => row.batch.id == id)
                              .firstOrNull;
                        }),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        key: const Key('boxesField'),
                        controller: _boxesController,
                        keyboardType: TextInputType.number,
                        validator: _validateBoxes,
                        decoration: _inputDecoration('箱数'),
                      ),
                      const SizedBox(height: 10),
                      _ProductMeta(
                        availableBoxes: _selectedBatch?.currentBoxes,
                        boardText: _boardText(),
                        specText: _specText(),
                        tsRequired: _selectedBatch?.batch.tsRequired ?? false,
                      ),
                    ],
                  ),
                  if (_draftLines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _DraftLinesCard(
                      lines: _draftLines,
                      onDeleteLine: _deleteDraftLine,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('continueWaybillButton'),
                          onPressed: () => _save(continueAdd: true),
                          child: const Text('继续添加'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          key: const Key('finishWaybillButton'),
                          onPressed: () => _save(continueAdd: false),
                          child: const Text('完成'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<_OrderEditState> _loadState() async {
    final merchants = await _orderDao.recentMerchantNames(limit: 10);
    _productOptions = await _productDao.productsForOrderEntry();
    _products = _productOptions.map((option) => option.product).toList();
    if (_selectedProduct == null && _products.isNotEmpty) {
      await _selectProduct(_products.first.id);
    }
    return _OrderEditState(merchants: merchants);
  }

  Future<void> _selectProduct(int? productId) async {
    if (productId == null) {
      return;
    }
    final product = _products.where((item) => item.id == productId).firstOrNull;
    if (product == null) {
      return;
    }
    final batches = await _productDao.availableBatchesForProduct(product.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedProduct = product;
      _availableBatches = batches;
      _selectedBatch = batches.isEmpty ? null : batches.first;
    });
  }

  ProductInventoryOption _productOptionFor(Product product) {
    return _productOptions.firstWhere(
      (option) => option.product.id == product.id,
      orElse: () => ProductInventoryOption(
        product: product,
        currentBoxes: 0,
        tsRequired: false,
      ),
    );
  }

  Future<void> _pickOrderDate() async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('zh', 'CN'),
      initialDate: _orderDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked == null) {
      return;
    }
    setState(() => _orderDate = picked);
    _onOrderHeaderChanged();
  }

  Future<void> _save({required bool continueAdd}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final product = _selectedProduct!;
    final batch = _selectedBatch!;
    final boxes = int.parse(_boxesController.text.trim());

    try {
      final waybillNo = _waybillNoController.text.trim();
      final merchantName = _merchantController.text.trim();
      final orderDate =
          DateTime(_orderDate.year, _orderDate.month, _orderDate.day);
      final currentKey = _orderHeaderKey(
        waybillNo: waybillNo,
        merchantName: merchantName,
        orderDate: orderDate,
      );
      if (_draftOrderKey != null && _draftOrderKey != currentKey) {
        _draftOrderKey = null;
      }
      final orderId = await _orderDao.appendPendingWaybillItem(
        waybillNo: waybillNo,
        merchantName: merchantName,
        orderDate: orderDate,
        item: PendingOrderItemInput(
          productId: product.id,
          batchId: batch.batch.id,
          boxes: boxes,
          boxesPerBoard: batch.batch.boxesPerBoard,
          piecesPerBox: product.piecesPerBox,
        ),
      );
      _draftOrderKey = currentKey;
      await _reloadDraftLines(orderId: orderId, headerKey: currentKey);
    } on DuplicateOrderItemException {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('该产品批号已添加，请勿重复添加')),
      );
      return;
    } on InsufficientStockException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('库存不足，无法保存运单')),
      );
      return;
    } on InvalidStockQuantityException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('箱数无效，无法保存运单')),
      );
      return;
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败，请重试')),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    if (continueAdd) {
      _boxesController.clear();
      if (_availableBatches.isNotEmpty) {
        setState(() {
          _selectedBatch = _availableBatches.first;
        });
      } else {
        setState(() {});
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已追加，继续录入同运单产品')),
      );
      return;
    }
    _clearForNextWaybill();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已完成并清空，可录入下一单')),
    );
  }

  void _onOrderHeaderChanged() {
    final currentKey = _orderHeaderKey(
      waybillNo: _waybillNoController.text.trim(),
      merchantName: _merchantController.text.trim(),
      orderDate: DateTime(_orderDate.year, _orderDate.month, _orderDate.day),
    );
    if (_draftOrderKey != null && _draftOrderKey != currentKey) {
      _draftOrderKey = null;
    }
    unawaited(_reloadDraftLinesByHeader());
  }

  String _orderHeaderKey({
    required String waybillNo,
    required String merchantName,
    required DateTime orderDate,
  }) {
    return '$waybillNo|$merchantName|${orderDate.year}-${orderDate.month}-${orderDate.day}';
  }

  Future<void> _clearForNextWaybill() async {
    _draftOrderKey = null;
    _draftLines = const [];
    _waybillNoController.clear();
    _merchantController.clear();
    _boxesController.clear();
    _orderDate = DateTime.now();
    if (_products.isNotEmpty) {
      await _selectProduct(_products.first.id);
    } else {
      setState(() {
        _selectedProduct = null;
        _selectedBatch = null;
        _availableBatches = const [];
      });
    }
  }

  String? _required(String? value) {
    return value?.trim().isEmpty == false ? null : '必填';
  }

  String? _validateBoxes(String? value) {
    final boxes = int.tryParse(value?.trim() ?? '');
    if (boxes == null || boxes <= 0) {
      return '请输入箱数';
    }
    final available = _selectedBatch?.currentBoxes ?? 0;
    if (available <= 0) {
      return '没有可用库存';
    }
    if (boxes > available) {
      return '超过可用库存';
    }
    return null;
  }

  String? _boardText() {
    final batch = _selectedBatch;
    final boxes = int.tryParse(_boxesController.text.trim());
    if (batch == null || boxes == null || boxes <= 0) {
      return null;
    }
    return BoardCalculator.format(
      boxes: boxes,
      boxesPerBoard: batch.batch.boxesPerBoard,
    );
  }

  String _specText() {
    final product = _selectedProduct;
    final batch = _selectedBatch;
    if (product == null || batch == null) {
      return '--';
    }
    return '${batch.batch.boxesPerBoard}箱/板 · ${product.piecesPerBox}件/箱';
  }

  Future<void> _reloadDraftLinesByHeader() async {
    final waybillNo = _waybillNoController.text.trim();
    final merchantName = _merchantController.text.trim();
    if (waybillNo.isEmpty || merchantName.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _draftLines = const [];
      });
      return;
    }
    final orderDate =
        DateTime(_orderDate.year, _orderDate.month, _orderDate.day);
    final headerKey = _orderHeaderKey(
      waybillNo: waybillNo,
      merchantName: merchantName,
      orderDate: orderDate,
    );
    final orderId = await _orderDao.findOpenOrderId(
      waybillNo: waybillNo,
      merchantName: merchantName,
      orderDate: orderDate,
    );
    if (orderId == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _draftLines = const [];
      });
      return;
    }
    await _reloadDraftLines(orderId: orderId, headerKey: headerKey);
  }

  Future<void> _reloadDraftLines({
    required int orderId,
    required String headerKey,
  }) async {
    final detail = await _orderDao.orderDetail(orderId);
    if (!mounted) {
      return;
    }
    final currentHeaderKey = _orderHeaderKey(
      waybillNo: _waybillNoController.text.trim(),
      merchantName: _merchantController.text.trim(),
      orderDate: DateTime(_orderDate.year, _orderDate.month, _orderDate.day),
    );
    if (currentHeaderKey != headerKey) {
      return;
    }
    setState(() {
      _draftOrderKey = headerKey;
      _draftLines = _sortDraftLines(detail.lines);
    });
  }

  List<OrderDetailLine> _sortDraftLines(List<OrderDetailLine> lines) {
    final sorted = [...lines];
    sorted.sort((a, b) {
      final dateA = _parseDate(a.batch.dateBatch);
      final dateB = _parseDate(b.batch.dateBatch);
      for (var i = 0; i < 3; i += 1) {
        final cmp = dateA[i].compareTo(dateB[i]);
        if (cmp != 0) {
          return cmp;
        }
      }
      final batchCmp = a.batch.actualBatch.compareTo(b.batch.actualBatch);
      if (batchCmp != 0) {
        return batchCmp;
      }
      return a.item.id.compareTo(b.item.id);
    });
    return sorted;
  }

  List<int> _parseDate(String dateText) {
    final parts = dateText.split('.');
    if (parts.length != 3) {
      return const [9999, 99, 99];
    }
    return [
      int.tryParse(parts[0]) ?? 9999,
      int.tryParse(parts[1]) ?? 99,
      int.tryParse(parts[2]) ?? 99,
    ];
  }

  Future<void> _deleteDraftLine(OrderDetailLine line) async {
    final confirmed = await showDeleteConfirmDialog(
      context: context,
      title: '删除已添加明细',
      message: '确认删除 ${line.product.code} · ${line.batch.actualBatch} 这条记录？',
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
      await _reloadDraftLinesByHeader();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除该明细')),
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
}

class _OrderEditState {
  const _OrderEditState({required this.merchants});

  final List<String> merchants;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

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
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _ProductOptionLabel extends StatelessWidget {
  const _ProductOptionLabel({required this.option});

  final ProductInventoryOption option;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(option.product.code),
        const SizedBox(width: 8),
        Text(
          '${option.currentBoxes}箱',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (option.tsRequired) ...[
          const SizedBox(width: 6),
          const _MetaChip(
            text: 'TS',
            textColor: Color(0xFFDC2626),
            backgroundColor: Color(0xFFFEE2E2),
          ),
        ],
      ],
    );
  }
}

class _ProductMeta extends StatelessWidget {
  const _ProductMeta({
    required this.availableBoxes,
    required this.boardText,
    required this.specText,
    required this.tsRequired,
  });

  final int? availableBoxes;
  final String? boardText;
  final String specText;
  final bool tsRequired;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetaChip(text: '可用 ${availableBoxes ?? 0}箱'),
        if (boardText != null) _MetaChip(text: '需 $boardText'),
        _MetaChip(text: specText),
        if (tsRequired)
          const _MetaChip(
            text: 'TS',
            textColor: Color(0xFFDC2626),
            backgroundColor: Color(0xFFFEE2E2),
          ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
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

class _DraftLinesCard extends StatelessWidget {
  const _DraftLinesCard({
    required this.lines,
    required this.onDeleteLine,
  });

  final List<OrderDetailLine> lines;
  final ValueChanged<OrderDetailLine> onDeleteLine;

  @override
  Widget build(BuildContext context) {
    final totalBoxes = lines.fold<int>(0, (sum, line) => sum + line.item.boxes);
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
            '已添加明细（${lines.length}条 / $totalBoxes箱）',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${line.product.code} · ${line.batch.dateBatch} · ${line.batch.actualBatch} · ${line.item.boxes}箱${line.batch.tsRequired ? ' · TS' : ''}',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '删除该明细',
                    onPressed: () => onDeleteLine(line),
                    icon: const Icon(Icons.delete_outline),
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

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xFFF7F9FC),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}

String _formatDate(DateTime date) => '${date.year}.${date.month}.${date.day}';
