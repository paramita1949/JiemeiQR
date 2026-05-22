import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/data/daos/qr_preview_history_dao.dart';
import 'package:qrscan_flutter/features/qr/broken_box_code_screen.dart';
import 'package:qrscan_flutter/features/qr/preview_screen.dart';
import 'package:qrscan_flutter/features/qr/qr_range_screen.dart';
import 'package:qrscan_flutter/features/qr/scanner_screen.dart';
import 'package:qrscan_flutter/models/qr_record.dart';
import 'package:qrscan_flutter/services/qr_parser.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/widgets/page_title.dart';

class QrEntryScreen extends StatefulWidget {
  const QrEntryScreen({super.key, this.database});

  final AppDatabase? database;

  @override
  State<QrEntryScreen> createState() => _QrEntryScreenState();
}

class _QrEntryScreenState extends State<QrEntryScreen> {
  int _groupCount = 100;
  double _autoSlideSeconds = 1.0;
  bool _randomTailEnabled = true;
  int _randomTailDigits = 3;
  ParsedQr? _lastParsed;
  QrBuildResult? _lastBuildResult;
  late final AppDatabase _database;
  late final bool _ownsDatabase;
  late final QrPreviewHistoryDao _historyDao;
  late final ProductDao _productDao;
  String _lastSource = '扫码';
  String _lastRawContent = '';
  final List<QrPreviewHistoryEntry> _history = <QrPreviewHistoryEntry>[];

  @override
  void initState() {
    super.initState();
    _ownsDatabase = widget.database == null;
    _database = widget.database ?? AppDatabase();
    _historyDao = QrPreviewHistoryDao(_database);
    _productDao = ProductDao(_database);
    _loadHistory();
  }

  @override
  void dispose() {
    if (_ownsDatabase) {
      _database.close();
    }
    super.dispose();
  }

  Future<void> _startScan() => _openScannerAndPreview(startFromGallery: false);

  Future<void> _startFromGallery() =>
      _openScannerAndPreview(startFromGallery: true);

  Future<void> _openScannerAndPreview({required bool startFromGallery}) async {
    _lastSource = startFromGallery ? '导入图片' : '开始扫码';
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ScannerScreen(startFromGallery: startFromGallery),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    _parseAndPreview(result);
  }

  Future<void> _startManualInput() async {
    _lastSource = '手动输入';
    final result = await showModalBottomSheet<_ManualQrInputResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManualQrInputDialog(productDao: _productDao),
    );
    if (!mounted || result == null) {
      return;
    }
    final content = result.content.trim();
    if (content.isEmpty) {
      return;
    }
    _lastSource = result.source;
    _parseAndPreview(content);
  }

  void _parseAndPreview(String content) {
    final parsed = QrParser.parse(content);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('格式不匹配，请扫箱贴码')),
      );
      return;
    }
    _lastRawContent = content;
    setState(() => _lastParsed = parsed);
    _openPreview();
  }

  void _openPreview({int? startSerial}) {
    final parsed = _lastParsed;
    if (parsed == null) {
      return;
    }
    final buildResult = QrParser.buildRecords(
      prefix: parsed.prefix,
      serialSeed: parsed.serial,
      batch: parsed.batch,
      suffix: parsed.suffix,
      count: _groupCount,
      randomTailEnabled: _randomTailEnabled,
      randomTailDigits: _randomTailDigits,
      startSerial: startSerial,
    );
    setState(() => _lastBuildResult = buildResult);
    _saveHistory(buildResult);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          records: buildResult.records,
          scanIndex: buildResult.scanIndex,
          group: buildResult.group,
          initialAutoSlideSeconds: _autoSlideSeconds,
        ),
      ),
    );
  }

  Future<void> _loadHistory() async {
    final rows = await _historyDao.latest(limit: 50);
    if (!mounted) {
      return;
    }
    setState(() {
      _history
        ..clear()
        ..addAll(rows);
    });
  }

  Future<void> _saveHistory(QrBuildResult buildResult) async {
    await _historyDao.insert(
      QrPreviewHistoryEntry(
        source: _lastSource,
        actualBatch: buildResult.group.batch,
        startSerial: buildResult.records.first.serial,
        endSerial: buildResult.records.last.serial,
        generatedCount: buildResult.records.length,
        rawContent: _lastRawContent,
        prefix: buildResult.group.prefix,
        suffix: buildResult.group.suffix,
        createdAt: DateTime.now(),
      ),
    );
    await _loadHistory();
  }

  Future<void> _deleteHistory(int id) async {
    await _historyDao.deleteById(id);
    await _loadHistory();
  }

  Future<void> _clearHistory() async {
    await _historyDao.clearAll();
    await _loadHistory();
  }

  Future<void> _openHistoryPreview(QrPreviewHistoryEntry item) async {
    final raw = item.rawContent.trim();
    final parsed = QrParser.parse(raw);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('历史记录缺少有效原始码，无法进入预览')),
      );
      return;
    }
    final start = int.tryParse(item.startSerial);
    final end = int.tryParse(item.endSerial);
    if (start == null || end == null || end < start) {
      return;
    }
    final count = end - start + 1;
    final result = QrParser.buildRecords(
      prefix: parsed.prefix,
      serialSeed: parsed.serial,
      batch: parsed.batch,
      suffix: parsed.suffix,
      count: count,
      randomTailEnabled: false,
      startSerial: start,
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          records: result.records,
          scanIndex: result.scanIndex,
          group: result.group,
          initialAutoSlideSeconds: _autoSlideSeconds,
        ),
      ),
    );
  }

  void _openNextGroup() {
    final lastGroup = _lastBuildResult?.group;
    if (lastGroup == null) {
      return;
    }
    final startSerial =
        _randomTailEnabled ? null : lastGroup.startSerial + lastGroup.count;
    _openPreview(startSerial: startSerial);
  }

  Future<void> _setGroupCount() async {
    final controller = TextEditingController(text: _groupCount.toString());
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置生成数量'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '每组张数'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final count = int.tryParse(controller.text.trim());
              if (count == null || count <= 0) {
                return;
              }
              Navigator.of(context).pop(count);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (value == null) {
      return;
    }
    setState(() {
      _groupCount = value;
      _lastBuildResult = null;
    });
  }

  Future<void> _setAutoSlideSeconds() async {
    final controller =
        TextEditingController(text: _autoSlideSeconds.toString());
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置自动滑动间隔'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: '秒数'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final seconds = double.tryParse(controller.text.trim());
              if (seconds == null || seconds <= 0) {
                return;
              }
              Navigator.of(context).pop(seconds);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (value == null) {
      return;
    }
    setState(() => _autoSlideSeconds = value);
  }

  @override
  Widget build(BuildContext context) {
    final canGenerate = _lastParsed != null;
    final canContinue = _lastBuildResult != null;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageTitle(
                icon: Icons.qr_code_scanner_outlined,
                title: 'QR箱码生成',
                subtitle: '扫描后配置生成规则',
              ),
              const SizedBox(height: 12),
              _ScanCard(
                onScan: _startScan,
                onImportImage: _startFromGallery,
                onManualInput: _startManualInput,
                onOpenRange: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const QrRangeScreen()),
                  );
                },
                onOpenBroken: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BrokenBoxCodeScreen(database: _database),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _GenerateParamCard(
                groupCount: _groupCount,
                autoSlideSeconds: _autoSlideSeconds,
                randomTailEnabled: _randomTailEnabled,
                randomTailDigits: _randomTailDigits,
                onSetGroupCount: _setGroupCount,
                onSetAutoSlideSeconds: _setAutoSlideSeconds,
                onSetSequential: () => setState(() {
                  _randomTailEnabled = false;
                  _lastBuildResult = null;
                }),
                onSetRandom: () => setState(() {
                  _randomTailEnabled = true;
                  _lastBuildResult = null;
                }),
                onSetRandomDigits: (digits) => setState(() {
                  _randomTailEnabled = true;
                  _randomTailDigits = digits;
                  _lastBuildResult = null;
                }),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: canGenerate ? () => _openPreview() : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('生成并预览'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: canContinue ? _openNextGroup : null,
                      icon: const Icon(Icons.skip_next),
                      label: const Text('下一组继续'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _lastParsed == null ? '当前预览: 未扫描' : '当前预览: 1/$_groupCount',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '提示: 请先扫描箱贴码或导入图片，再生成预览',
                style: TextStyle(color: Color(0xFF9A3412), fontSize: 11),
              ),
              if (_history.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text(
                      '预览历史',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _clearHistory,
                      icon: const Icon(Icons.delete_sweep_outlined,
                          color: Colors.red),
                      label: const Text(
                        '全部清除',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ..._history.map((item) {
                  final time =
                      item.createdAt.toLocal().toString().split('.').first;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => _openHistoryPreview(item),
                      dense: true,
                      title: Text(
                        '${item.source} | 批号 ${item.actualBatch}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '$time\n${item.startSerial} ~ ${item.endSerial}（${item.generatedCount}张）',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 2,
                        children: [
                          IconButton(
                            tooltip: '复制原始码',
                            onPressed: item.rawContent.isEmpty
                                ? null
                                : () {
                                    Clipboard.setData(
                                      ClipboardData(text: item.rawContent),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('已复制原始完整码')),
                                    );
                                  },
                            icon: const Icon(Icons.copy_outlined),
                          ),
                          IconButton(
                            tooltip: '删除',
                            onPressed: item.id == null
                                ? null
                                : () => _deleteHistory(item.id!),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({
    required this.onScan,
    required this.onImportImage,
    required this.onManualInput,
    required this.onOpenRange,
    required this.onOpenBroken,
  });

  final VoidCallback onScan;
  final VoidCallback onImportImage;
  final VoidCallback onManualInput;
  final VoidCallback onOpenRange;
  final VoidCallback onOpenBroken;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      color: const Color(0xFFEAF7FF),
      children: [
        const _PanelTitle('扫码 / 本地图片识别'),
        const SizedBox(height: 4),
        const Text(
          '支持相机与本地图片导入',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('开始扫码'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onImportImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('导入图片'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            key: const Key('rangeEntryButton'),
            onPressed: onOpenRange,
            icon: const Icon(Icons.straighten_outlined),
            label: const Text('箱码范围'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            key: const Key('manualQrInputEntryButton'),
            onPressed: onManualInput,
            icon: const Icon(Icons.keyboard_outlined),
            label: const Text('手动输入'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: onOpenBroken,
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('破损箱码'),
          ),
        ),
      ],
    );
  }
}

class _ManualQrInputResult {
  const _ManualQrInputResult({
    required this.content,
    required this.source,
  });

  final String content;
  final String source;
}

class _ManualQrInputDialog extends StatefulWidget {
  const _ManualQrInputDialog({required this.productDao});

  final ProductDao productDao;

  @override
  State<_ManualQrInputDialog> createState() => _ManualQrInputDialogState();
}

class _ManualQrInputDialogState extends State<_ManualQrInputDialog> {
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

  @override
  void dispose() {
    _fullCodeController.dispose();
    _serialController.dispose();
    _suffixController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final products = await widget.productDao.tsRequiredProducts();
    if (!mounted) {
      return;
    }
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
    if (!mounted) {
      return;
    }
    setState(() {
      _batches = batches;
      _selectedBatchId = batches.isEmpty ? null : batches.first.batch.id;
    });
  }

  Product? get _selectedProduct {
    final id = _selectedProductId;
    if (id == null) {
      return null;
    }
    for (final product in _products) {
      if (product.id == id) {
        return product;
      }
    }
    return null;
  }

  BatchRecord? get _selectedBatch {
    final id = _selectedBatchId;
    if (id == null) {
      return null;
    }
    for (final batch in _batches) {
      if (batch.batch.id == id) {
        return batch.batch;
      }
    }
    return null;
  }

  void _confirmFullManual() {
    final raw = _fullCodeController.text.trim().toUpperCase();
    final content = raw.startsWith('00') ? raw : '00$raw';
    if (content.isEmpty) {
      setState(() => _errorText = '请输入箱码内容');
      return;
    }
    Navigator.of(context).pop(
      _ManualQrInputResult(content: content, source: '手动输入-完整码'),
    );
  }

  void _confirmRule() {
    final product = _selectedProduct;
    final batch = _selectedBatch;
    final serial = _serialController.text.trim();
    final suffix = _suffixController.text.trim().toUpperCase();
    if (product == null) {
      setState(() => _errorText = '请先选择产品');
      return;
    }
    if (batch == null) {
      setState(() => _errorText = '请先选择批号');
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
    final content = raw.startsWith('00') ? raw : '00$raw';
    Navigator.of(context).pop(
      _ManualQrInputResult(content: content, source: '手动输入-规则生成'),
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
                          '手动输入箱码',
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
                    labels: const ['完全手动输入', '按规则生成'],
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
                        : _buildRulePanel(),
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
      key: const ValueKey('fullManual'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormSection(
          title: '完整码',
          subtitle: '可直接粘贴或输入，缺少开头 00 会自动补齐',
          child: TextField(
            key: const Key('manualQrContentField'),
            controller: _fullCodeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: '箱码内容',
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
            key: const Key('manualQrConfirmButton'),
            onPressed: _confirmFullManual,
            child: const Text('确认完整码'),
          ),
        ),
      ],
    );
  }

  Widget _buildRulePanel() {
    final hasProducts = _products.isNotEmpty;
    final hasBatches = _batches.isNotEmpty;
    return Column(
      key: const ValueKey('ruleManual'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormSection(
          title: '库存信息',
          subtitle: '产品和批号直接从库存明细选择',
          child: Column(
            children: [
              DropdownButtonFormField<int>(
                key: const Key('manualRuleProductField'),
                initialValue: _selectedProductId,
                decoration: const InputDecoration(
                  labelText: '产品',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: _products
                    .map(
                      (product) => DropdownMenuItem<int>(
                        value: product.id,
                        child: Text(product.code),
                      ),
                    )
                    .toList(),
                onChanged: hasProducts
                    ? (value) {
                        setState(() {
                          _selectedProductId = value;
                          _selectedBatchId = null;
                          _errorText = null;
                        });
                        _loadBatchesForProduct(value);
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: const Key('manualRuleBatchField'),
                initialValue: _selectedBatchId,
                decoration: const InputDecoration(
                  labelText: '批号',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
                items: _batches
                    .map(
                      (row) => DropdownMenuItem<int>(
                        value: row.batch.id,
                        child: Text(
                          '${row.batch.actualBatch} · ${row.batch.dateBatch} · 可用${row.availableBoxes}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: hasBatches
                    ? (value) => setState(() {
                          _selectedBatchId = value;
                          _errorText = null;
                        })
                    : null,
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
                  key: const Key('manualRuleSerialField'),
                  controller: _serialController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '流水号'),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(QrParser.serialLength),
                  ],
                  onChanged: (_) {
                    if (_errorText != null) {
                      setState(() => _errorText = null);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const Key('manualRuleSuffixField'),
                  controller: _suffixController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: '后缀'),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(QrParser.suffixLength),
                  ],
                  onChanged: (_) {
                    if (_errorText != null) {
                      setState(() => _errorText = null);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (!hasProducts)
          const _InlineHint(text: '暂无库存产品，请先在库存明细录入基础信息。')
        else if (!hasBatches)
          const _InlineHint(text: '当前产品暂无可用批号（库存为0或未建批次）。'),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.tonal(
            key: const Key('manualRuleConfirmButton'),
            onPressed: _confirmRule,
            child: const Text('按规则生成并确认'),
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
    return _StatusPill(
      icon: Icons.error_outline,
      color: const Color(0xFFDC2626),
      background: const Color(0xFFFEE2E2),
      text: text,
    );
  }
}

class _InlineHint extends StatelessWidget {
  const _InlineHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _StatusPill(
      icon: Icons.info_outline,
      color: const Color(0xFFB45309),
      background: const Color(0xFFFFF7ED),
      text: text,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.color,
    required this.background,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
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

class _GenerateParamCard extends StatelessWidget {
  const _GenerateParamCard({
    required this.groupCount,
    required this.autoSlideSeconds,
    required this.randomTailEnabled,
    required this.randomTailDigits,
    required this.onSetGroupCount,
    required this.onSetAutoSlideSeconds,
    required this.onSetSequential,
    required this.onSetRandom,
    required this.onSetRandomDigits,
  });

  final int groupCount;
  final double autoSlideSeconds;
  final bool randomTailEnabled;
  final int randomTailDigits;
  final VoidCallback onSetGroupCount;
  final VoidCallback onSetAutoSlideSeconds;
  final VoidCallback onSetSequential;
  final VoidCallback onSetRandom;
  final ValueChanged<int> onSetRandomDigits;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      color: const Color(0xFFF3EEFF),
      children: [
        const _PanelTitle('生成参数'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onSetGroupCount,
                child: Text('数量: $groupCount'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: onSetAutoSlideSeconds,
                child: Text('自动滑动: ${autoSlideSeconds}s'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('顺序'),
              selected: !randomTailEnabled,
              onSelected: (_) => onSetSequential(),
            ),
            ChoiceChip(
              label: const Text('随机'),
              selected: randomTailEnabled,
              onSelected: (_) => onSetRandom(),
            ),
            ChoiceChip(
              label: const Text('末3位随机'),
              selected: randomTailEnabled && randomTailDigits == 3,
              onSelected: (_) => onSetRandomDigits(3),
            ),
            ChoiceChip(
              label: const Text('末4位随机'),
              selected: randomTailEnabled && randomTailDigits == 4,
              onSelected: (_) => onSetRandomDigits(4),
            ),
          ],
        ),
      ],
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.color, required this.children});

  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
