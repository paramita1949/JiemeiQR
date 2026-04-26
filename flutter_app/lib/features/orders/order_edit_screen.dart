import 'package:flutter/material.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/utils/board_calculator.dart';
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
  List<Product> _products = const [];
  List<AvailableBatch> _availableBatches = const [];

  @override
  void initState() {
    super.initState();
    _ownsDatabase = widget.database == null;
    _database = widget.database ?? AppDatabase();
    _productDao = ProductDao(_database);
    _orderDao = OrderDao(_database);
    _boxesController.addListener(() => setState(() {}));
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
                    subtitle: '商家、产品、批号、箱数',
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
                            .map(
                              (product) => DropdownMenuItem(
                                value: product.id,
                                child: Text(product.code),
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _save(popAfterSave: true),
                          child: const Text('暂存'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          key: const Key('finishWaybillButton'),
                          onPressed: () => _save(popAfterSave: false),
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
    _products = await _productDao.allProducts();
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

  Future<void> _pickOrderDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _orderDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked == null) {
      return;
    }
    setState(() => _orderDate = picked);
  }

  Future<void> _save({required bool popAfterSave}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final product = _selectedProduct!;
    final batch = _selectedBatch!;
    final boxes = int.parse(_boxesController.text.trim());

    try {
      await _orderDao.createPendingWaybill(
        waybillNo: _waybillNoController.text.trim(),
        merchantName: _merchantController.text.trim(),
        orderDate: _orderDate,
        item: PendingOrderItemInput(
          productId: product.id,
          batchId: batch.batch.id,
          boxes: boxes,
          boxesPerBoard: batch.batch.boxesPerBoard,
          piecesPerBox: product.piecesPerBox,
        ),
      );
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
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存运单')),
    );
    if (popAfterSave) {
      Navigator.of(context).pop(true);
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

class _ProductMeta extends StatelessWidget {
  const _ProductMeta({
    required this.availableBoxes,
    required this.boardText,
    required this.specText,
  });

  final int? availableBoxes;
  final String? boardText;
  final String specText;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetaChip(text: '可用 ${availableBoxes ?? 0}箱'),
        if (boardText != null) _MetaChip(text: '需 $boardText'),
        _MetaChip(text: specText),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.text});

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
