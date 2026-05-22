import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/broken_box_code_dao.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/services/qr_parser.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';

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
    final result = await showModalBottomSheet<_BrokenManualResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BrokenManualInputDialog(productDao: _productDao),
    );
    if (result == null || result.fullCode.isEmpty) return;
    await _saveCode(result.fullCode, autoPrefix00: result.autoPrefix00);
  }

  Future<void> _saveCode(String full, {bool autoPrefix00 = false}) async {
    final normalized =
        autoPrefix00 && !full.startsWith('00') ? '00$full' : full;
    final parsed = QrParser.parse(normalized);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('格式不匹配')),
      );
      return;
    }
    final day = DateTime.now();
    final dayKey =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final productCode = parsed.prefix.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
    await _dao.insert(
      day: dayKey,
      productCode: productCode,
      actualBatch: parsed.batch,
      fullCode: normalized,
    );
    await _load();
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
                Expanded(
                    child: FilledButton.icon(
                        onPressed: _scanAdd,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('扫码识别'))),
                const SizedBox(width: 8),
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: _manualAdd,
                        icon: const Icon(Icons.keyboard),
                        label: const Text('手动录入'))),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _rows.length,
                itemBuilder: (context, i) {
                  final item = _rows[i];
                  return Card(
                    child: ListTile(
                      title: Text(
                          '${item.day} | ${item.productCode} | ${item.actualBatch}'),
                      subtitle: Text(item.fullCode),
                      trailing: Wrap(
                        spacing: 2,
                        children: [
                          IconButton(
                            onPressed: () => Clipboard.setData(
                                ClipboardData(text: item.fullCode)),
                            icon: const Icon(Icons.copy_outlined),
                          ),
                          IconButton(
                            onPressed: () async {
                              await _dao.deleteById(item.id);
                              _load();
                            },
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
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
  State<_BrokenManualInputDialog> createState() =>
      _BrokenManualInputDialogState();
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
  int _modeIndex = 0;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await widget.productDao.tsRequiredProducts();
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
    final batches = await widget.productDao.availableBatchesForProduct(
      productId,
      includeZeroAvailable: true,
    );
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
    if (serial.length != QrParser.serialLength ||
        int.tryParse(serial) == null) {
      setState(() => _errorText = '流水号需为10位数字');
      return;
    }
    if (suffix.length != QrParser.suffixLength) {
      setState(() => _errorText = '后缀需为2位');
      return;
    }
    final raw = '${product.code}$serial${batch.actualBatch}$suffix';
    final fullCode = raw.startsWith('00') ? raw : '00$raw';
    Navigator.of(context).pop(
      _BrokenManualResult(fullCode: fullCode, autoPrefix00: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.88,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: _SheetHandle()),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '手动录入破损箱码',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ModeSwitch(
                    selectedIndex: _modeIndex,
                    labels: const ['完全手动输入', '按规则录入'],
                    onChanged: (index) => setState(() {
                      _modeIndex = index;
                      _errorText = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _modeIndex == 0
                        ? _buildFullManualPanel()
                        : _buildRuleManualPanel(),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 12),
                    _InlineError(text: _errorText!),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullManualPanel() {
    return Column(
      key: const ValueKey('brokenFullManual'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormSection(
          title: '完整码',
          subtitle: '可直接粘贴或输入，缺少开头 00 会自动补齐',
          child: TextField(
            key: const Key('brokenManualFullCodeField'),
            controller: _fullCodeController,
            decoration: const InputDecoration(
              labelText: '完整码',
              hintText: '00720680088454517EL3FJEZ31',
              prefixIcon: Icon(Icons.qr_code_2_outlined),
            ),
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            key: const Key('brokenManualFullConfirmButton'),
            onPressed: _confirmFullManual,
            child: const Text('保存完整码'),
          ),
        ),
      ],
    );
  }

  Widget _buildRuleManualPanel() {
    return Column(
      key: const ValueKey('brokenRuleManual'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormSection(
          title: '库存信息',
          subtitle: '产品和批号直接从库存明细选择',
          child: Column(
            children: [
              DropdownButtonFormField<int>(
                key: const Key('brokenManualProductField'),
                initialValue: _selectedProductId,
                decoration: const InputDecoration(
                  labelText: '产品',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
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
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: const Key('brokenManualBatchField'),
                initialValue: _selectedBatchId,
                decoration: const InputDecoration(
                  labelText: '批号',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
                items: _batches
                    .map((b) => DropdownMenuItem<int>(
                          value: b.batch.id,
                          child: Text(
                            '${b.batch.actualBatch} · ${b.batch.dateBatch} · 可用${b.availableBoxes}',
                          ),
                        ))
                    .toList(),
                onChanged: (value) => setState(() {
                  _selectedBatchId = value;
                  _errorText = null;
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _FormSection(
          title: '箱码参数',
          subtitle: '流水号输入 10 位数字，后缀默认 31',
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  key: const Key('brokenManualSerialField'),
                  controller: _serialController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(QrParser.serialLength),
                  ],
                  decoration: const InputDecoration(labelText: '流水号'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const Key('brokenManualSuffixField'),
                  controller: _suffixController,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(QrParser.suffixLength),
                  ],
                  decoration: const InputDecoration(labelText: '后缀'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.tonal(
            key: const Key('brokenManualRuleConfirmButton'),
            onPressed: _confirmRuleManual,
            child: const Text('生成并保存'),
          ),
        ),
      ],
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 5,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFCBD5E1),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.selectedIndex,
    required this.labels,
    required this.onChanged,
  });

  final int selectedIndex;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i += 1)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        selectedIndex == i ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: selectedIndex == i
                        ? const [
                            BoxShadow(
                              color: Color(0x1A0F172A),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: selectedIndex == i
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
