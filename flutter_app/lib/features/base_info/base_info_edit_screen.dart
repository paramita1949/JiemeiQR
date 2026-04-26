import 'package:flutter/material.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/features/qr/scanner_screen.dart';
import 'package:qrscan_flutter/services/qr_parser.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/widgets/page_title.dart';

class BaseInfoEditScreen extends StatefulWidget {
  const BaseInfoEditScreen({
    super.key,
    this.database,
    this.editingBatchId,
  });

  final AppDatabase? database;
  final int? editingBatchId;

  @override
  State<BaseInfoEditScreen> createState() => _BaseInfoEditScreenState();
}

class _BaseInfoEditScreenState extends State<BaseInfoEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productCodeController = TextEditingController();
  final _productNameController = TextEditingController();
  final _actualBatchController = TextEditingController();
  final _dateBatchController = TextEditingController();
  final _stockPiecesController = TextEditingController();
  final _boxesPerBoardController = TextEditingController();
  final _piecesPerBoxController = TextEditingController();
  final _locationController = TextEditingController();
  final _remarkController = TextEditingController();

  late final AppDatabase _database;
  late final ProductDao _productDao;
  late final bool _ownsDatabase;

  int? _savedProductId;
  int? _savedBatchId;
  bool _saving = false;
  bool _loadingEditData = false;
  bool _tsRequired = false;
  int _productLookupVersion = 0;

  bool get _isEditing => widget.editingBatchId != null;

  @override
  void initState() {
    super.initState();
    _ownsDatabase = widget.database == null;
    _database = widget.database ?? AppDatabase();
    _productDao = ProductDao(_database);
    if (_isEditing) {
      _loadingEditData = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadEditingData();
      });
    }
  }

  @override
  void dispose() {
    _productCodeController.dispose();
    _productNameController.dispose();
    _actualBatchController.dispose();
    _dateBatchController.dispose();
    _stockPiecesController.dispose();
    _boxesPerBoardController.dispose();
    _piecesPerBoxController.dispose();
    _locationController.dispose();
    _remarkController.dispose();
    if (_ownsDatabase) {
      _database.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingEditData) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final summary = _calculateSummary();
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 42),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: PageTitle(
                      icon: Icons.edit_document,
                      title: _isEditing ? '编辑基础资料' : '基础资料',
                    ),
                  ),
                  IconButton.filled(
                    tooltip: '扫码快速录入',
                    onPressed: _showQuickScanActions,
                    icon: const Icon(Icons.qr_code_scanner_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _TextField(
                            key: const Key('productCodeField'),
                            controller: _productCodeController,
                            label: '产品编号',
                            onChanged: _onProductCodeChanged,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _TextField(
                      key: const Key('productNameField'),
                      controller: _productNameController,
                      label: '产品名称',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _TextField(
                            key: const Key('actualBatchField'),
                            controller: _actualBatchController,
                            label: '批号',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TextField(
                            key: const Key('dateBatchField'),
                            controller: _dateBatchController,
                            label: '日期',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _TextField(
                      key: const Key('stockPiecesField'),
                      controller: _stockPiecesController,
                      label: '数量',
                      keyboardType: TextInputType.number,
                      validator: _validateStockPieces,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _TextField(
                            key: const Key('boxesPerBoardField'),
                            controller: _boxesPerBoardController,
                            label: '每板箱数',
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TextField(
                            key: const Key('piecesPerBoxField'),
                            controller: _piecesPerBoxController,
                            label: '每箱件数',
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _TextField(
                      key: const Key('locationField'),
                      controller: _locationController,
                      label: '库位',
                      requiredField: false,
                    ),
                    const SizedBox(height: 10),
                    _TextField(
                      key: const Key('remarkField'),
                      controller: _remarkController,
                      label: '备注',
                      maxLines: 2,
                      requiredField: false,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text(
                          'TS扫码',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('否')),
                            ButtonSegment(value: true, label: Text('是')),
                          ],
                          selected: {_tsRequired},
                          onSelectionChanged: (values) {
                            setState(() => _tsRequired = values.single);
                          },
                          showSelectedIcon: false,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (summary != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        '箱数',
                        style: TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${summary.totalBoxes}箱',
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        '板数',
                        style: TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${summary.fullBoards}板+${summary.remainingBoxes}箱',
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (_isEditing)
                FilledButton(
                  key: const Key('saveBaseInfoButton'),
                  onPressed:
                      _saving ? null : () => _save(continueSameProduct: false),
                  child: Text(_saving ? '保存中' : '保存修改'),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('saveSameProductButton'),
                        onPressed: _saving
                            ? null
                            : () => _save(continueSameProduct: true),
                        child: const Text('继续录入'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        key: const Key('saveBaseInfoButton'),
                        onPressed: _saving
                            ? null
                            : () => _save(continueSameProduct: false),
                        child: Text(_saving ? '保存中' : '保存'),
                      ),
                    ),
                  ],
                ),
              if (_savedBatchId != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const Key('deleteBaseInfoButton'),
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除资料'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade200),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _CalculatedSummary? _calculateSummary() {
    final stockPieces = int.tryParse(_stockPiecesController.text.trim());
    final piecesPerBox = int.tryParse(_piecesPerBoxController.text.trim());
    final boxesPerBoard = int.tryParse(_boxesPerBoardController.text.trim());
    if (stockPieces == null ||
        boxesPerBoard == null ||
        piecesPerBox == null ||
        stockPieces <= 0 ||
        boxesPerBoard <= 0 ||
        piecesPerBox <= 0) {
      return null;
    }
    if (stockPieces % piecesPerBox != 0) {
      return null;
    }
    final totalBoxes = stockPieces ~/ piecesPerBox;
    final fullBoards = totalBoxes ~/ boxesPerBoard;
    final remainingBoxes = totalBoxes % boxesPerBoard;
    return _CalculatedSummary(
      totalBoxes: totalBoxes,
      fullBoards: fullBoards,
      remainingBoxes: remainingBoxes,
    );
  }

  Future<void> _onProductCodeChanged(String value) async {
    final code = value.trim();
    if (code.isEmpty) {
      return;
    }
    final currentVersion = ++_productLookupVersion;
    final product = await _productDao.productByCode(code);
    if (!mounted ||
        currentVersion != _productLookupVersion ||
        product == null) {
      return;
    }
    if (_productNameController.text.trim().isEmpty) {
      _productNameController.text = product.name;
    }
    final hasTsRequired = await _productDao.hasTsRequiredBatches(product.id);
    if (!mounted || currentVersion != _productLookupVersion) {
      return;
    }
    if (hasTsRequired && !_tsRequired) {
      setState(() => _tsRequired = true);
    }
  }

  Future<void> _save({required bool continueSameProduct}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);
    try {
      final code = _productCodeController.text.trim();
      final actualBatch = _actualBatchController.text.trim();
      final dateBatch = _dateBatchController.text.trim();
      final piecesPerBox = int.parse(_piecesPerBoxController.text);
      final stockPieces = int.parse(_stockPiecesController.text);
      final initialBoxes = stockPieces ~/ piecesPerBox;
      final hasDuplicate = await _productDao.hasDuplicateActualBatch(
        actualBatch: actualBatch,
        excludeBatchId: widget.editingBatchId,
      );
      if (hasDuplicate) {
        final shouldContinue = await _confirmDuplicateBatch(
          actualBatch: actualBatch,
        );
        if (shouldContinue != true) {
          return;
        }
      }
      if (_isEditing) {
        await _productDao.updateBaseInfoEntry(
          batchId: widget.editingBatchId!,
          code: code,
          name: _productNameController.text.trim(),
          actualBatch: actualBatch,
          dateBatch: dateBatch,
          currentBoxes: initialBoxes,
          boxesPerBoard: int.parse(_boxesPerBoardController.text),
          piecesPerBox: piecesPerBox,
          tsRequired: _tsRequired,
          location: _emptyAsNull(_locationController.text),
          remark: _emptyAsNull(_remarkController.text),
        );
      } else {
        final productId = await _productDao.createProduct(
          code: code,
          name: _productNameController.text.trim(),
          boxesPerBoard: int.parse(_boxesPerBoardController.text),
          piecesPerBox: piecesPerBox,
        );
        await _productDao.createBatch(
          productId: productId,
          actualBatch: actualBatch,
          dateBatch: dateBatch,
          initialBoxes: initialBoxes,
          boxesPerBoard: int.parse(_boxesPerBoardController.text),
          tsRequired: _tsRequired,
          location: _emptyAsNull(_locationController.text),
          remark: _emptyAsNull(_remarkController.text),
        );
      }

      if (!mounted) {
        return;
      }
      if (_isEditing) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _clearForNextEntry(continueSameProduct: continueSameProduct);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存基础资料')),
        );
      }
    } on ProductCodeAlreadyExistsException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('产品编号已存在，不能修改为重复编号')),
      );
    } on InvalidProductQuantityException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('数量或规格不合法，请检查后重试')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<bool?> _confirmDuplicateBatch({
    required String actualBatch,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重复批号提醒'),
        content: Text(
          '批号已存在，是否继续？\n$actualBatch',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('继续保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadEditingData() async {
    final batchId = widget.editingBatchId;
    if (batchId == null) {
      return;
    }
    final entry = await _productDao.getBaseInfoEntry(batchId);
    if (!mounted) {
      return;
    }
    if (entry == null) {
      setState(() => _loadingEditData = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到可编辑的批号资料')),
      );
      Navigator.of(context).pop();
      return;
    }

    _productCodeController.text = entry.product.code;
    _productNameController.text = entry.product.name;
    _actualBatchController.text = entry.batch.actualBatch;
    _dateBatchController.text = entry.batch.dateBatch;
    _stockPiecesController.text =
        (entry.currentBoxes * entry.product.piecesPerBox).toString();
    _boxesPerBoardController.text = entry.batch.boxesPerBoard.toString();
    _piecesPerBoxController.text = entry.product.piecesPerBox.toString();
    _locationController.text = entry.batch.location ?? '';
    _remarkController.text = entry.batch.remark ?? '';
    _tsRequired = entry.batch.tsRequired;
    _savedProductId = entry.product.id;
    _savedBatchId = entry.batch.id;
    setState(() => _loadingEditData = false);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后会移除当前产品与批号资料。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || _savedBatchId == null || _savedProductId == null) {
      return;
    }

    await _productDao.deleteBatch(_savedBatchId!);
    await _productDao.deleteProduct(_savedProductId!);
    if (!mounted) {
      return;
    }
    if (_isEditing) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _savedBatchId = null;
      _savedProductId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已删除基础资料')),
    );
  }

  Future<void> _showQuickScanActions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('相机扫码'),
              onTap: () => Navigator.of(context).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('图片识别'),
              onTap: () => Navigator.of(context).pop('gallery'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case 'camera':
        await _scanActualBatch(startFromGallery: false);
        break;
      case 'gallery':
        await _scanActualBatch(startFromGallery: true);
        break;
    }
  }

  Future<void> _scanActualBatch({required bool startFromGallery}) async {
    final content = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ScannerScreen(startFromGallery: startFromGallery),
      ),
    );
    if (!mounted || content == null) {
      return;
    }
    _applyScannedContent(content);
  }

  void _applyScannedContent(String content) {
    final parsed = QrParser.parse(content.trim());
    if (parsed == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法解析QR箱码')),
      );
      return;
    }

    _actualBatchController.text = parsed.batch;
  }

  String? _emptyAsNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _clearForNextEntry({required bool continueSameProduct}) {
    if (!continueSameProduct) {
      _productCodeController.clear();
      _productNameController.clear();
      _piecesPerBoxController.clear();
    }
    _actualBatchController.clear();
    _dateBatchController.clear();
    _stockPiecesController.clear();
    _locationController.clear();
    _remarkController.clear();
    _boxesPerBoardController.clear();
    if (!continueSameProduct) {
      _tsRequired = false;
    }
    _savedBatchId = null;
    _savedProductId = null;
  }

  String? _validateStockPieces(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '必填';
    }
    final stockPieces = int.tryParse(text);
    if (stockPieces == null) {
      return '请输入数字';
    }
    if (stockPieces <= 0) {
      return '请输入大于0的数字';
    }
    final piecesPerBox = int.tryParse(_piecesPerBoxController.text.trim());
    if (piecesPerBox == null || piecesPerBox <= 0) {
      return null;
    }
    if (stockPieces % piecesPerBox != 0) {
      return '数量必须是整箱';
    }
    return null;
  }
}

class _CalculatedSummary {
  const _CalculatedSummary({
    required this.totalBoxes,
    required this.fullBoards,
    required this.remainingBoxes,
  });

  final int totalBoxes;
  final int fullBoards;
  final int remainingBoxes;
}

class _TextField extends StatelessWidget {
  const _TextField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
    this.requiredField = true,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool requiredField;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      validator: (value) {
        final customError = validator?.call(value);
        if (customError != null) {
          return customError;
        }
        final text = value?.trim() ?? '';
        if (requiredField && text.isEmpty) {
          return '必填';
        }
        if (keyboardType == TextInputType.number && text.isNotEmpty) {
          final number = int.tryParse(text);
          if (number == null) {
            return '请输入数字';
          }
          if (number <= 0) {
            return '请输入大于0的数字';
          }
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
