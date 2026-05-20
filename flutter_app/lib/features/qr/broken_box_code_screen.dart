import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/broken_box_code_dao.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/services/qr_parser.dart';

import 'scanner_screen.dart';

class BrokenBoxCodeScreen extends StatefulWidget {
  const BrokenBoxCodeScreen({super.key, this.database});

  final AppDatabase? database;

  @override
  State<BrokenBoxCodeScreen> createState() => _BrokenBoxCodeScreenState();
}

class _BrokenBoxCodeScreenState extends State<BrokenBoxCodeScreen> {
  late final AppDatabase _db;
  late final bool _owns;
  late final BrokenBoxCodeDao _dao;
  late final ProductDao _productDao;
  final List<BrokenBoxCodeEntry> _rows = <BrokenBoxCodeEntry>[];

  @override
  void initState() {
    super.initState();
    _owns = widget.database == null;
    _db = widget.database ?? AppDatabase();
    _dao = BrokenBoxCodeDao(_db);
    _productDao = ProductDao(_db);
    _load();
  }

  @override
  void dispose() {
    if (_owns) {
      _db.close();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await _dao.latest();
    if (!mounted) return;
    setState(() {
      _rows
        ..clear()
        ..addAll(rows);
    });
  }

  Future<void> _scanAdd() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerScreen(title: '扫码识别破损箱码')),
    );
    if (code == null || code.trim().isEmpty) return;
    await _saveCode(code.trim());
  }

  Future<void> _manualAdd() async {
    final result = await showDialog<_BrokenManualResult>(
      context: context,
      builder: (context) => _BrokenManualInputDialog(productDao: _productDao),
    );
    if (result == null || result.fullCode.isEmpty) return;
    await _saveCode(result.fullCode, autoPrefix00: result.autoPrefix00);
  }

  Future<void> _saveCode(String full, {bool autoPrefix00 = false}) async {
    final normalized = autoPrefix00 && !full.startsWith('00') ? '00$full' : full;
    final parsed = QrParser.parse(normalized);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('格式不匹配')),
      );
      return;
    }
    final day = DateTime.now();
    final dayKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final productCode = parsed.prefix.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
    await _dao.insert(
      day: dayKey,
      productCode: productCode,
      actualBatch: parsed.batch,
      fullCode: normalized,
    );
    await _load();
  }

  Future<void> _generateByRule() async {
    final result = await showDialog<_BrokenRuleResult>(
      context: context,
      builder: (context) => _BrokenRuleDialog(productDao: _productDao),
    );
    if (result == null) return;
    for (var i = 0; i < result.count; i++) {
      final serial = (result.startSerial + i).toString().padLeft(10, '0');
      final full =
          '${result.productCode}$serial${result.actualBatch}${result.suffix}';
      await _saveCode(full);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('破损箱码')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: FilledButton.icon(onPressed: _scanAdd, icon: const Icon(Icons.qr_code_scanner), label: const Text('扫码识别'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: _manualAdd, icon: const Icon(Icons.keyboard), label: const Text('手动录入'))),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _generateByRule,
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: const Text('规则录入'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _rows.length,
                itemBuilder: (context, i) {
                  final item = _rows[i];
                  return Card(
                    child: ListTile(
                      title: Text('${item.day} | ${item.productCode} | ${item.actualBatch}'),
                      subtitle: Text(item.fullCode),
                      trailing: Wrap(
                        spacing: 2,
                        children: [
                          IconButton(
                            onPressed: () => Clipboard.setData(ClipboardData(text: item.fullCode)),
                            icon: const Icon(Icons.copy_outlined),
                          ),
                          IconButton(
                            onPressed: () async {
                              await _dao.deleteById(item.id);
                              _load();
                            },
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
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
      ),
    );
  }
}

class _BrokenManualResult {
  const _BrokenManualResult({
    required this.fullCode,
    required this.autoPrefix00,
  });

  final String fullCode;
  final bool autoPrefix00;
}

class _BrokenManualInputDialog extends StatefulWidget {
  const _BrokenManualInputDialog({required this.productDao});

  final ProductDao productDao;

  @override
  State<_BrokenManualInputDialog> createState() => _BrokenManualInputDialogState();
}

class _BrokenManualInputDialogState extends State<_BrokenManualInputDialog> {
  final TextEditingController _fullCodeController = TextEditingController();
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _suffixController =
      TextEditingController(text: '31');
  List<Product> _products = const <Product>[];
  List<AvailableBatch> _batches = const <AvailableBatch>[];
  int? _selectedProductId;
  int? _selectedBatchId;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await widget.productDao.allProducts();
    if (!mounted) return;
    final selectedProductId = products.isEmpty ? null : products.first.id;
    setState(() {
      _products = products;
      _selectedProductId = selectedProductId;
    });
    await _loadBatchesForProduct(selectedProductId);
  }

  Future<void> _loadBatchesForProduct(int? productId) async {
    if (productId == null) {
      setState(() {
        _batches = const <AvailableBatch>[];
        _selectedBatchId = null;
      });
      return;
    }
    final batches = await widget.productDao.availableBatchesForProduct(productId);
    if (!mounted) return;
    setState(() {
      _batches = batches;
      _selectedBatchId = batches.isEmpty ? null : batches.first.batch.id;
    });
  }

  Product? get _selectedProduct {
    for (final p in _products) {
      if (p.id == _selectedProductId) return p;
    }
    return null;
  }

  BatchRecord? get _selectedBatch {
    for (final b in _batches) {
      if (b.batch.id == _selectedBatchId) return b.batch;
    }
    return null;
  }

  void _confirmFullManual() {
    final fullCode = _fullCodeController.text.trim().toUpperCase();
    if (fullCode.isEmpty) {
      setState(() => _errorText = '请输入完整码');
      return;
    }
    Navigator.of(context).pop(
      _BrokenManualResult(fullCode: fullCode, autoPrefix00: true),
    );
  }

  void _confirmRuleManual() {
    final product = _selectedProduct;
    final batch = _selectedBatch;
    final serial = _serialController.text.trim();
    final suffix = _suffixController.text.trim().toUpperCase();
    if (product == null || batch == null) {
      setState(() => _errorText = '请先选择产品和批号');
      return;
    }
    if (serial.length != QrParser.serialLength || int.tryParse(serial) == null) {
      setState(() => _errorText = '流水号需为10位数字');
      return;
    }
    if (suffix.length != QrParser.suffixLength) {
      setState(() => _errorText = '后缀需为2位');
      return;
    }
    final fullCode = '${product.code}$serial${batch.actualBatch}$suffix';
    Navigator.of(context).pop(
      _BrokenManualResult(fullCode: fullCode, autoPrefix00: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('手动录入破损箱码'),
      content: SizedBox(
        width: 440,
        child: DefaultTabController(
          length: 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TabBar(
                tabs: [
                  Tab(text: '完全手动输入'),
                  Tab(text: '按规则录入'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 230,
                child: TabBarView(
                  children: [
                    Column(
                      children: [
                        TextField(
                          key: const Key('brokenManualFullCodeField'),
                          controller: _fullCodeController,
                          decoration: const InputDecoration(labelText: '完整码'),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            key: const Key('brokenManualFullConfirmButton'),
                            onPressed: _confirmFullManual,
                            child: const Text('保存'),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        DropdownButtonFormField<int>(
                          key: const Key('brokenManualProductField'),
                          initialValue: _selectedProductId,
                          decoration:
                              const InputDecoration(labelText: '产品（库存选择）'),
                          items: _products
                              .map((p) => DropdownMenuItem<int>(
                                    value: p.id,
                                    child: Text(p.code),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedProductId = value;
                              _selectedBatchId = null;
                              _errorText = null;
                            });
                            _loadBatchesForProduct(value);
                          },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          key: const Key('brokenManualBatchField'),
                          initialValue: _selectedBatchId,
                          decoration:
                              const InputDecoration(labelText: '批号（库存选择）'),
                          items: _batches
                              .map((b) => DropdownMenuItem<int>(
                                    value: b.batch.id,
                                    child: Text(
                                        '${b.batch.actualBatch} · 库存${b.availableBoxes}'),
                                  ))
                              .toList(),
                          onChanged: (value) => setState(() {
                            _selectedBatchId = value;
                            _errorText = null;
                          }),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key('brokenManualSerialField'),
                                controller: _serialController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(
                                    QrParser.serialLength,
                                  ),
                                ],
                                decoration:
                                    const InputDecoration(labelText: '流水号10位'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 96,
                              child: TextField(
                                key: const Key('brokenManualSuffixField'),
                                controller: _suffixController,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(
                                    QrParser.suffixLength,
                                  ),
                                ],
                                decoration: const InputDecoration(labelText: '后缀'),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonal(
                            key: const Key('brokenManualRuleConfirmButton'),
                            onPressed: _confirmRuleManual,
                            child: const Text('生成并保存'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

class _BrokenRuleResult {
  const _BrokenRuleResult({
    required this.productCode,
    required this.actualBatch,
    required this.startSerial,
    required this.suffix,
    required this.count,
  });

  final String productCode;
  final String actualBatch;
  final int startSerial;
  final String suffix;
  final int count;
}

class _BrokenRuleDialog extends StatefulWidget {
  const _BrokenRuleDialog({required this.productDao});

  final ProductDao productDao;

  @override
  State<_BrokenRuleDialog> createState() => _BrokenRuleDialogState();
}

class _BrokenRuleDialogState extends State<_BrokenRuleDialog> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _suffixController =
      TextEditingController(text: '31');
  final TextEditingController _countController = TextEditingController(text: '1');
  List<Product> _products = const <Product>[];
  List<AvailableBatch> _batches = const <AvailableBatch>[];
  int? _selectedProductId;
  int? _selectedBatchId;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await widget.productDao.allProducts();
    if (!mounted) return;
    final selectedProductId = products.isEmpty ? null : products.first.id;
    setState(() {
      _products = products;
      _selectedProductId = selectedProductId;
    });
    await _loadBatchesForProduct(selectedProductId);
  }

  Future<void> _loadBatchesForProduct(int? productId) async {
    if (productId == null) {
      setState(() {
        _batches = const <AvailableBatch>[];
        _selectedBatchId = null;
      });
      return;
    }
    final batches = await widget.productDao.availableBatchesForProduct(productId);
    if (!mounted) return;
    setState(() {
      _batches = batches;
      _selectedBatchId = batches.isEmpty ? null : batches.first.batch.id;
    });
  }

  Product? get _selectedProduct {
    for (final p in _products) {
      if (p.id == _selectedProductId) return p;
    }
    return null;
  }

  BatchRecord? get _selectedBatch {
    for (final b in _batches) {
      if (b.batch.id == _selectedBatchId) return b.batch;
    }
    return null;
  }

  void _confirm() {
    final product = _selectedProduct;
    final batch = _selectedBatch;
    final start = _startController.text.trim();
    final suffix = _suffixController.text.trim().toUpperCase();
    final count = _countController.text.trim();
    final startNum = int.tryParse(start);
    final countNum = int.tryParse(count);
    if (product == null || batch == null) {
      setState(() => _errorText = '请先选择产品和批号');
      return;
    }
    if (startNum == null || start.length != QrParser.serialLength) {
      setState(() => _errorText = '起始流水号需为10位数字');
      return;
    }
    if (suffix.length != QrParser.suffixLength) {
      setState(() => _errorText = '后缀需为2位');
      return;
    }
    if (countNum == null || countNum <= 0) {
      setState(() => _errorText = '数量需大于0');
      return;
    }
    Navigator.of(context).pop(
      _BrokenRuleResult(
        productCode: product.code,
        actualBatch: batch.actualBatch,
        startSerial: startNum,
        suffix: suffix,
        count: countNum,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('规则录入破损码'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              key: const Key('brokenRuleProductField'),
              initialValue: _selectedProductId,
              decoration: const InputDecoration(labelText: '产品（库存选择）'),
              items: _products
                  .map((p) => DropdownMenuItem<int>(value: p.id, child: Text(p.code)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProductId = value;
                  _selectedBatchId = null;
                  _errorText = null;
                });
                _loadBatchesForProduct(value);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              key: const Key('brokenRuleBatchField'),
              initialValue: _selectedBatchId,
              decoration: const InputDecoration(labelText: '批号（库存选择）'),
              items: _batches
                  .map((b) => DropdownMenuItem<int>(
                        value: b.batch.id,
                        child: Text('${b.batch.actualBatch} · 库存${b.availableBoxes}'),
                      ))
                  .toList(),
              onChanged: (value) => setState(() {
                _selectedBatchId = value;
                _errorText = null;
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('brokenRuleStartSerialField'),
              controller: _startController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(QrParser.serialLength),
              ],
              decoration: const InputDecoration(labelText: '起始流水号10位'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('brokenRuleSuffixField'),
                    controller: _suffixController,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(QrParser.suffixLength),
                    ],
                    decoration: const InputDecoration(labelText: '后缀'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('brokenRuleCountField'),
                    controller: _countController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: '数量'),
                  ),
                ),
              ],
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('生成保存'),
        ),
      ],
    );
  }
}
