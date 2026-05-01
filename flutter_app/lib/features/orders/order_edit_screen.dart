import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';
import 'package:qrscan_flutter/features/orders/ocr/configured_waybill_ocr_service.dart';
import 'package:qrscan_flutter/features/orders/ocr/gemini_waybill_ocr_service.dart';
import 'package:qrscan_flutter/features/orders/ocr/merchant_name_matcher.dart';
import 'package:qrscan_flutter/features/orders/ocr/modelscope_waybill_ocr_service.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_matcher.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_photo_ocr_service.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_review_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/utils/board_calculator.dart';
import 'package:qrscan_flutter/shared/widgets/delete_confirm_dialog.dart';
import 'package:qrscan_flutter/shared/widgets/page_title.dart';

class OrderEditScreen extends StatefulWidget {
  const OrderEditScreen({
    super.key,
    this.database,
    this.ocrService,
    this.imagePicker,
  });

  final AppDatabase? database;
  final WaybillPhotoOcrService? ocrService;
  final ImagePicker? imagePicker;

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
  WaybillPhotoOcrService? _ocrService;
  ImagePicker? _imagePicker;
  late final bool _ownsDatabase;
  late Future<_OrderEditState> _stateFuture;

  DateTime _orderDate = DateTime.now();
  Product? _selectedProduct;
  AvailableBatch? _selectedBatch;
  List<ProductInventoryOption> _productOptions = const [];
  List<Product> _products = const [];
  List<AvailableBatch> _availableBatches = const [];
  Map<String, List<String>> _batchCodesByProductDate = const {};
  String? _draftOrderKey;
  List<OrderDetailLine> _draftLines = const [];

  @override
  void initState() {
    super.initState();
    _ownsDatabase = widget.database == null;
    _database = widget.database ?? AppDatabase();
    _productDao = ProductDao(_database);
    _orderDao = OrderDao(_database);
    _ocrService = widget.ocrService ?? const ConfiguredWaybillOcrService();
    _imagePicker = widget.imagePicker ?? ImagePicker();
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
      bottomNavigationBar: _OrderActionBar(
        onEnd: () => unawaited(_endToOrderList()),
        onContinue: () => _save(continueAdd: true),
        onNext: () => _save(continueAdd: false),
      ),
      body: SafeArea(
        child: FutureBuilder<_OrderEditState>(
          future: _stateFuture,
          builder: (context, snapshot) {
            final state = snapshot.data;
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: PageTitle(
                          icon: Icons.add_box_outlined,
                          title: '新增运单',
                          subtitle: '',
                        ),
                      ),
                      IconButton.filledTonal(
                        key: const Key('waybillOcrButton'),
                        tooltip: '拍照识别',
                        onPressed: _recognizeWaybillPhoto,
                        icon: const Icon(Icons.auto_awesome),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SectionCard(
                    title: '订单信息',
                    trailing: _DateField(
                      dateText: _formatDate(_orderDate),
                      onTap: _pickOrderDate,
                      compact: true,
                    ),
                    children: [
                      TextFormField(
                        key: const Key('waybillNoField'),
                        controller: _waybillNoController,
                        validator: _required,
                        decoration: _inputDecoration('运单号'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const Key('merchantNameField'),
                        controller: _merchantController,
                        validator: _required,
                        decoration: _inputDecoration('输入商家'),
                      ),
                      if (state != null && state.merchants.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          key: const Key('merchantHistoryDropdown'),
                          initialValue: null,
                          decoration: _inputDecoration('历史商家'),
                          items: state.merchants
                              .map(
                                (name) => DropdownMenuItem<String>(
                                  value: name,
                                  child: Text(name),
                                ),
                              )
                              .toList(),
                          onChanged: (name) {
                            if (name == null) {
                              return;
                            }
                            _merchantController.text = name;
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SectionCard(
                    title: '产品明细',
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: _selectedProduct?.id,
                        validator: (value) => value == null ? '必选' : null,
                        decoration: _inputDecoration('选择产品'),
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
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedBatch?.batch.id,
                        validator: (value) => value == null ? '必选' : null,
                        decoration: _inputDecoration('选择批号'),
                        items: _availableBatches
                            .map(
                              (row) => DropdownMenuItem(
                                value: row.batch.id,
                                child: Text.rich(
                                  TextSpan(
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    children: [
                                      ..._batchCodeSpans(
                                        row.batch.actualBatch,
                                        variants: _batchCodesByProductDate[
                                                '${_selectedProduct?.code ?? ''}|${row.batch.dateBatch}'] ??
                                            const <String>[],
                                        highlightDifferences: true,
                                        normalColor: AppTheme.textPrimary,
                                      ),
                                      TextSpan(
                                        text:
                                            ' ${row.batch.dateBatch}${_batchIndexSuffix(row.batch, _availableBatches.map((item) => item.batch).toList())}',
                                      ),
                                    ],
                                  ),
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
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const Key('boxesField'),
                        controller: _boxesController,
                        keyboardType: TextInputType.number,
                        validator: _validateBoxes,
                        decoration: _inputDecoration('输入箱数'),
                      ),
                      const SizedBox(height: 8),
                      _ProductMeta(
                        availableBoxes: _selectedBatch?.availableBoxes,
                        projectedUsedBoxes: _selectedBatch?.reservedBoxes,
                        boardText: _boardText(),
                        specText: _specText(),
                        tsRequired: _currentSelectionNeedsScan(),
                      ),
                    ],
                  ),
                  if (_draftLines.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _DraftLinesCard(
                      lines: _draftLines,
                      batchCodesByProductDate: _batchCodesByProductDate,
                      onDeleteLine: _deleteDraftLine,
                    ),
                  ],
                  const SizedBox(height: 8),
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
    _batchCodesByProductDate = await _productDao.batchCodesByProductDate();
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

  bool _currentSelectionNeedsScan() {
    final batchRequiresScan =
        _selectedBatch == null ? false : _batchNeedsScan(_selectedBatch!.batch);
    final productRequiresScan = _selectedProduct == null
        ? false
        : _productOptionFor(_selectedProduct!).tsRequired;
    return batchRequiresScan || productRequiresScan;
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
    final nextDate = DateTime(picked.year, picked.month, picked.day);
    if (_draftLines.isNotEmpty) {
      final waybillNo = _waybillNoController.text.trim();
      final merchantName = _merchantController.text.trim();
      final orderId = _draftLines.first.item.orderId;
      if (waybillNo.isNotEmpty && merchantName.isNotEmpty) {
        try {
          await _orderDao.updateOrderBasic(
            orderId: orderId,
            waybillNo: waybillNo,
            merchantName: merchantName,
            orderDate: nextDate,
          );
          final nextHeaderKey = _orderHeaderKey(
            waybillNo: waybillNo,
            merchantName: merchantName,
            orderDate: nextDate,
          );
          setState(() {
            _orderDate = nextDate;
            _draftOrderKey = nextHeaderKey;
          });
          await _reloadDraftLines(orderId: orderId, headerKey: nextHeaderKey);
          return;
        } on DuplicateWaybillNoException {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('运单号已存在，无法修改日期')),
          );
          return;
        } catch (_) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('修改日期失败，请重试')),
          );
          return;
        }
      }
    }
    setState(() => _orderDate = nextDate);
    _onOrderHeaderChanged();
  }

  Future<void> _recognizeWaybillPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照识别'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) {
      return;
    }
    final picked = await _effectiveImagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (!mounted || picked == null) {
      return;
    }
    await _runWaybillOcr(File(picked.path));
  }

  Future<void> _runWaybillOcr(File image) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      var draft = await _effectiveOcrService.recognize(image);
      draft = await _resolveOcrMerchantName(draft);
      final matched = await WaybillOcrMatcher(_productDao).match(draft);
      if (!mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      await _openOcrReview(matched);
    } on GeminiWaybillOcrException catch (error) {
      if (!mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on ModelScopeWaybillOcrException catch (error) {
      if (!mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('识别失败，请重试')),
      );
    }
  }

  Future<WaybillOcrDraft> _resolveOcrMerchantName(WaybillOcrDraft draft) async {
    final merchantName = draft.merchantName.trim();
    if (merchantName.isEmpty) {
      return draft;
    }
    final historyNames = await _orderDao.recentMerchantNames(limit: 200);
    final resolved = resolveMerchantNameFromHistory(
      recognizedName: merchantName,
      historyNames: historyNames,
    );
    if (resolved == merchantName) {
      return draft;
    }
    return WaybillOcrDraft(
      waybillNo: draft.waybillNo,
      merchantName: resolved,
      orderDateText: draft.orderDateText,
      rows: draft.rows,
      warnings: draft.warnings,
    );
  }

  WaybillPhotoOcrService get _effectiveOcrService {
    return _ocrService ??=
        widget.ocrService ?? const ConfiguredWaybillOcrService();
  }

  ImagePicker get _effectiveImagePicker {
    return _imagePicker ??= widget.imagePicker ?? ImagePicker();
  }

  Future<void> _openOcrReview(MatchedWaybillOcrDraft matched) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WaybillOcrReviewScreen(
          orderDao: _orderDao,
          matched: matched,
        ),
      ),
    );
    if (saved != true || !mounted) {
      return;
    }
    final normalizedWaybillNo = _normalizeWaybillNo(matched.source.waybillNo);
    final orderDate = matched.orderDate ?? DateTime.now();
    _waybillNoController.text = normalizedWaybillNo;
    _merchantController.text = matched.source.merchantName;
    _orderDate = DateTime(orderDate.year, orderDate.month, orderDate.day);
    final orderId = await _orderDao.findOpenOrderId(
      waybillNo: normalizedWaybillNo,
      merchantName: matched.source.merchantName,
      orderDate: _orderDate,
    );
    if (orderId != null) {
      final headerKey = _orderHeaderKey(
        waybillNo: normalizedWaybillNo,
        merchantName: matched.source.merchantName,
        orderDate: _orderDate,
      );
      _draftOrderKey = headerKey;
      await _reloadDraftLines(orderId: orderId, headerKey: headerKey);
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('识别明细已录入')),
    );
  }

  Future<void> _save({
    required bool continueAdd,
    bool exitAfterSave = false,
  }) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final product = _selectedProduct!;
    final batch = _selectedBatch!;
    final boxes = int.parse(_boxesController.text.trim());
    final waybillNo = _waybillNoController.text.trim();
    final merchantName = _merchantController.text.trim();
    final orderDate =
        DateTime(_orderDate.year, _orderDate.month, _orderDate.day);
    final currentKey = _orderHeaderKey(
      waybillNo: waybillNo,
      merchantName: merchantName,
      orderDate: orderDate,
    );

    try {
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
      if (exitAfterSave) {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(true);
        return;
      }
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
      if (shouldMerge == true) {
        final mergedOrderId = await _orderDao.mergeDuplicateOrderItem(
          itemId: duplicate.itemId,
          appendBoxes: boxes,
        );
        await _reloadDraftLines(orderId: mergedOrderId, headerKey: currentKey);
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已累加到原明细')),
        );
        if (continueAdd) {
          _boxesController.clear();
          return;
        }
        await _clearForNextWaybill();
      }
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
    } on DuplicateWaybillNoException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('运单号已存在')),
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

  Future<void> _endToOrderList() async {
    if (_draftLines.isNotEmpty) {
      Navigator.of(context).pop(true);
      return;
    }
    final hasCurrentInput = _waybillNoController.text.trim().isNotEmpty ||
        _merchantController.text.trim().isNotEmpty ||
        _boxesController.text.trim().isNotEmpty;
    if (!hasCurrentInput) {
      Navigator.of(context).pop();
      return;
    }
    await _save(continueAdd: false, exitAfterSave: true);
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

  String _normalizeWaybillNo(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final stripped = trimmed.replaceFirst(RegExp(r'^0+'), '');
    return stripped.isEmpty ? '0' : stripped;
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
    final available = _selectedBatch?.availableBoxes ?? 0;
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
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty || trailing != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (title.isNotEmpty)
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  )
                else
                  const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 8),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.dateText,
    required this.onTap,
    this.compact = false,
  });

  final String dateText;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: compact ? 34 : 42,
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(compact ? 10 : 12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              const Text(
                '日期',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              dateText,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: compact ? 12 : 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.calendar_month_outlined,
              size: compact ? 16 : 18,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
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
      ],
    );
  }
}

class _ProductMeta extends StatelessWidget {
  const _ProductMeta({
    required this.availableBoxes,
    required this.projectedUsedBoxes,
    required this.boardText,
    required this.specText,
    required this.tsRequired,
  });

  final int? availableBoxes;
  final int? projectedUsedBoxes;
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
        if ((projectedUsedBoxes ?? 0) > 0)
          _MetaChip(
            text: '预占 ${projectedUsedBoxes!}箱',
            textColor: const Color(0xFF92400E),
            backgroundColor: const Color(0xFFFFF7ED),
          ),
        if (boardText != null)
          _MetaChip(
            text: '需 $boardText',
            textColor: const Color(0xFFDC2626),
            backgroundColor: const Color(0xFFFEE2E2),
          ),
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
    required this.batchCodesByProductDate,
    required this.onDeleteLine,
  });

  final List<OrderDetailLine> lines;
  final Map<String, List<String>> batchCodesByProductDate;
  final ValueChanged<OrderDetailLine> onDeleteLine;

  @override
  Widget build(BuildContext context) {
    final totalBoxes = lines.fold<int>(0, (sum, line) => sum + line.item.boxes);
    final allBatches = lines.map((line) => line.batch).toList();
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
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        children: [
                          TextSpan(text: '${line.product.code} · '),
                          ..._batchCodeSpans(
                            line.batch.actualBatch,
                            variants: batchCodesByProductDate[
                                    '${line.product.code}|${line.batch.dateBatch}'] ??
                                const <String>[],
                            highlightDifferences: true,
                            normalColor: AppTheme.textPrimary,
                          ),
                          TextSpan(
                            text:
                                ' ${line.batch.dateBatch}${_batchIndexSuffix(line.batch, allBatches)}',
                          ),
                          TextSpan(text: ' · ${line.item.boxes}箱'),
                          if (_batchNeedsScan(line.batch))
                            const TextSpan(text: ' · TS'),
                        ],
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

class _OrderActionBar extends StatelessWidget {
  const _OrderActionBar({
    required this.onEnd,
    required this.onContinue,
    required this.onNext,
  });

  final VoidCallback onEnd;
  final VoidCallback onContinue;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('endWaybillButton'),
                onPressed: onEnd,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  foregroundColor: const Color(0xFF6B7280),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('结束'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonal(
                key: const Key('continueWaybillButton'),
                onPressed: onContinue,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  foregroundColor: const Color(0xFF1D4ED8),
                  backgroundColor: const Color(0xFFEAF1FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('继续'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                key: const Key('nextWaybillButton'),
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  elevation: 0,
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '下一单',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    hintText: label,
    hintStyle: const TextStyle(
      color: AppTheme.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    filled: true,
    fillColor: const Color(0xFFF7F9FC),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}

String _formatDate(DateTime date) => '${date.year}.${date.month}.${date.day}';

String _batchIndexSuffix(BatchRecord batch, List<BatchRecord> allBatches) {
  final sameDate =
      allBatches.where((item) => item.dateBatch == batch.dateBatch).toList()
        ..sort((a, b) {
          final byBatch = a.actualBatch.compareTo(b.actualBatch);
          if (byBatch != 0) {
            return byBatch;
          }
          return a.id.compareTo(b.id);
        });
  if (sameDate.length <= 1) {
    return '';
  }
  final index = sameDate.indexWhere((item) => item.id == batch.id);
  return index >= 0 ? ' 批号${index + 1}' : '';
}

List<InlineSpan> _batchCodeSpans(
  String code, {
  required List<String> variants,
  required bool highlightDifferences,
  required Color normalColor,
}) {
  if (!highlightDifferences || variants.toSet().length <= 1) {
    return <InlineSpan>[
      TextSpan(text: code, style: TextStyle(color: normalColor)),
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
    final isDiff = i < differsAt.length && differsAt[i];
    spans.add(
      TextSpan(
        text: code[i],
        style: TextStyle(
          color: isDiff ? const Color(0xFFDC2626) : normalColor,
        ),
      ),
    );
  }
  return spans;
}

bool _batchNeedsScan(BatchRecord batch) {
  return batch.tsRequired;
}
