import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';
import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';
import 'package:qrscan_flutter/features/orders/ocr/configured_waybill_ocr_service.dart';
import 'package:qrscan_flutter/features/orders/ocr/gemini_waybill_ocr_service.dart';
import 'package:qrscan_flutter/features/orders/ocr/modelscope_waybill_ocr_service.dart';
import 'package:qrscan_flutter/features/orders/ocr/paddle_ocr_waybill_ocr_service.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_matcher.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_photo_ocr_service.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_review_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/camera/ai_document_image_picker.dart';
import 'package:qrscan_flutter/shared/camera/ai_ocr_image_preparer.dart';
import 'package:qrscan_flutter/shared/utils/board_calculator.dart';
import 'package:qrscan_flutter/shared/utils/debug_event_log.dart';
import 'package:qrscan_flutter/shared/widgets/delete_confirm_dialog.dart';
import 'package:qrscan_flutter/shared/widgets/page_title.dart';

class OrderEditScreen extends StatefulWidget {
  const OrderEditScreen({
    super.key,
    this.database,
    this.ocrService,
    this.imagePicker,
    this.imagePreparer = const AiOcrImagePreparer(),
  });

  final AppDatabase? database;
  final WaybillPhotoOcrService? ocrService;
  final ImagePicker? imagePicker;
  final AiOcrImagePreparer imagePreparer;

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
  final FileAiConfigStore _aiConfigStore = const FileAiConfigStore();
  WaybillPhotoOcrService? _ocrService;
  ImagePicker? _imagePicker;
  late final AiOcrImagePreparer _imagePreparer;
  late final bool _ownsDatabase;
  late Future<_OrderEditState> _stateFuture;
  bool _ocrInProgress = false;
  String? _ocrProgressText;
  _OcrProgressState _ocrProgressState = _OcrProgressState.working;

  DateTime _orderDate = DateTime.now();
  Product? _selectedProduct;
  AvailableBatch? _selectedBatch;
  List<ProductInventoryOption> _productOptions = const [];
  List<Product> _products = const [];
  List<AvailableBatch> _availableBatches = const [];
  List<String> _merchantHistoryNames = const [];
  Map<String, List<String>> _batchCodesByProductDate = const {};
  AiOcrConfig _aiConfig = const AiOcrConfig(
    provider: AiOcrConfig.defaultProvider,
    geminiApiKey: '',
    geminiModel: AiOcrConfig.defaultModel,
    tencentSecretId: '',
    tencentSecretKey: '',
    tencentRegion: AiOcrConfig.defaultTencentRegion,
    aliyunAccessKeyId: '',
    aliyunAccessKeySecret: '',
    aliyunEndpoint: AiOcrConfig.defaultAliyunEndpoint,
    baiduApiKey: '',
    baiduSecretKey: '',
    modelscopeToken: '',
    modelscopeModel: AiOcrConfig.defaultModelScopeModel,
    paddleOcrToken: '',
    paddleOcrModel: AiOcrConfig.defaultPaddleOcrModel,
    openRouterApiKey: '',
    openRouterModel: AiOcrConfig.defaultOpenRouterModel,
    geminiModelPresets: AiOcrConfig.defaultGeminiModelPresets,
    modelScopeModelPresets: AiOcrConfig.defaultModelScopeModelPresets,
    paddleOcrModelPresets: AiOcrConfig.defaultPaddleOcrModelPresets,
    openRouterModelPresets: AiOcrConfig.defaultOpenRouterModelPresets,
    ocrPromptPreset: AiOcrConfig.defaultOcrPromptPreset,
  );
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
    _imagePreparer = widget.imagePreparer;
    _boxesController.addListener(() => setState(() {}));
    _waybillNoController.addListener(_onOrderHeaderChanged);
    _merchantController.addListener(_onOrderHeaderChanged);
    _stateFuture = _loadState();
    unawaited(_loadAiConfig());
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
                        onPressed:
                            _ocrInProgress ? null : _recognizeWaybillPhoto,
                        icon: const Icon(Icons.auto_awesome),
                      ),
                    ],
                  ),
                  if (_ocrProgressText != null) ...[
                    const SizedBox(height: 8),
                    _OcrProgressPanel(
                      inProgress: _ocrInProgress,
                      text: _ocrProgressText!,
                      state: _ocrProgressState,
                    ),
                  ],
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
                        decoration: _inputDecoration('输入商家').copyWith(
                          suffixIcon:
                              state != null && state.merchants.isNotEmpty
                                  ? _MerchantHistoryPicker(
                                      key: const Key('merchantHistoryDropdown'),
                                      names: state.merchants,
                                      onSelect: (name) =>
                                          _merchantController.text = name,
                                    )
                                  : null,
                        ),
                      ),
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
    final merchants = await _orderDao.recentMerchantNames(limit: 1000);
    _merchantHistoryNames = merchants;
    _batchCodesByProductDate = await _productDao.batchCodesByProductDate();
    _productOptions = await _productDao.productsForOrderEntry();
    _products = _productOptions.map((option) => option.product).toList();
    if (_selectedProduct == null && _products.isNotEmpty) {
      await _selectProduct(_products.first.id);
    }
    return _OrderEditState(merchants: merchants);
  }

  Future<void> _loadAiConfig() async {
    final config = await _aiConfigStore.load();
    if (!mounted) {
      return;
    }
    setState(() => _aiConfig = config);
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
    DebugEventLog.add('AI_OCR', 'open image source chooser');
    final plan = await showModalBottomSheet<_OcrCapturePlan>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        var provider = _aiConfig.provider;
        var geminiModel = _aiConfig.geminiModel;
        var modelscopeModel = _aiConfig.modelscopeModel;
        var paddleOcrModel = _aiConfig.paddleOcrModel;
        var promptPreset = _aiConfig.ocrPromptPreset;
        return StatefulBuilder(
          builder: (context, setModalState) {
            String shortModelName(String model) {
              final text = model.trim();
              if (text.isEmpty) {
                return '未选择模型';
              }
              final slashIndex = text.lastIndexOf('/');
              return slashIndex >= 0 ? text.substring(slashIndex + 1) : text;
            }

            List<String> activeModelPresets() {
              final current = provider == AiOcrConfig.modelscopeProvider
                  ? modelscopeModel
                  : provider == AiOcrConfig.paddleOcrProvider
                      ? paddleOcrModel
                      : geminiModel;
              final presets = provider == AiOcrConfig.modelscopeProvider
                  ? _aiConfig.modelScopeModelPresets
                  : provider == AiOcrConfig.paddleOcrProvider
                      ? _aiConfig.paddleOcrModelPresets
                      : _aiConfig.geminiModelPresets;
              return <String>{
                if (current.trim().isNotEmpty) current.trim(),
                ...presets.where((item) => item.trim().isNotEmpty),
              }.toList();
            }

            Widget compactChoice({
              required String label,
              required bool selected,
              required bool enabled,
              required VoidCallback onTap,
            }) {
              return InkWell(
                onTap: enabled ? onTap : null,
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFE9F1FF)
                        : const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF8FAEF5)
                          : const Color(0xFFE1E7F1),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: enabled
                          ? selected
                              ? const Color(0xFF2859CC)
                              : AppTheme.textSecondary
                          : const Color(0xFFB6BDCA),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        compactChoice(
                          label: '增强',
                          selected: promptPreset ==
                              AiOcrConfig.ocrPromptPresetWaybillTemplateV2,
                          enabled: true,
                          onTap: () => setModalState(
                            () => promptPreset =
                                AiOcrConfig.ocrPromptPresetWaybillTemplateV2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        compactChoice(
                          label: '通用',
                          selected: promptPreset ==
                              AiOcrConfig.ocrPromptPresetGeneral,
                          enabled: true,
                          onTap: () => setModalState(
                            () => promptPreset =
                                AiOcrConfig.ocrPromptPresetGeneral,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F7FC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFDCE4F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0F1E3A8A),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          compactChoice(
                            label: '谷歌',
                            selected: provider == AiOcrConfig.defaultProvider,
                            enabled: _aiConfig.hasGeminiKey,
                            onTap: () => setModalState(
                              () => provider = AiOcrConfig.defaultProvider,
                            ),
                          ),
                          const SizedBox(width: 6),
                          compactChoice(
                            label: '魔搭',
                            selected:
                                provider == AiOcrConfig.modelscopeProvider,
                            enabled: _aiConfig.hasModelScopeCredential,
                            onTap: () => setModalState(
                              () => provider = AiOcrConfig.modelscopeProvider,
                            ),
                          ),
                          const SizedBox(width: 6),
                          compactChoice(
                            label: '飞桨',
                            selected: provider == AiOcrConfig.paddleOcrProvider,
                            enabled: _aiConfig.hasPaddleOcrCredential,
                            onTap: () => setModalState(
                              () => provider = AiOcrConfig.paddleOcrProvider,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PopupMenuButton<String>(
                              tooltip: '切换具体模型',
                              onSelected: (value) => setModalState(() {
                                if (provider ==
                                    AiOcrConfig.modelscopeProvider) {
                                  modelscopeModel = value;
                                } else if (provider ==
                                    AiOcrConfig.paddleOcrProvider) {
                                  paddleOcrModel = value;
                                } else {
                                  geminiModel = value;
                                }
                              }),
                              itemBuilder: (context) => activeModelPresets()
                                  .map(
                                    (model) => PopupMenuItem<String>(
                                      value: model,
                                      child: Text(
                                        shortModelName(model),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              child: Container(
                                height: 33,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFFFF),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFDCE3EE),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        shortModelName(
                                          provider ==
                                                  AiOcrConfig.modelscopeProvider
                                              ? modelscopeModel
                                              : provider ==
                                                      AiOcrConfig
                                                          .paddleOcrProvider
                                                  ? paddleOcrModel
                                                  : geminiModel,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: Color(0xFF7A8598),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              backgroundColor: const Color(0xFFF8FAFD),
                              foregroundColor: const Color(0xFF2C5FD1),
                              side: const BorderSide(color: Color(0xFFD4DEEE)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(
                              _OcrCapturePlan(
                                source: ImageSource.gallery,
                                provider: provider,
                                geminiModel: geminiModel,
                                modelscopeModel: modelscopeModel,
                                paddleOcrModel: paddleOcrModel,
                                promptPreset: promptPreset,
                              ),
                            ),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('相册识别'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              elevation: 0,
                              backgroundColor: const Color(0xFF2860E5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(
                              _OcrCapturePlan(
                                source: ImageSource.camera,
                                provider: provider,
                                geminiModel: geminiModel,
                                modelscopeModel: modelscopeModel,
                                paddleOcrModel: paddleOcrModel,
                                promptPreset: promptPreset,
                              ),
                            ),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('拍照识别'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (plan == null) {
      DebugEventLog.add('AI_OCR', 'cancel image source chooser');
      return;
    }
    final nextConfig = _aiConfig.copyWith(
      provider: plan.provider,
      geminiModel: plan.geminiModel,
      modelscopeModel: plan.modelscopeModel,
      paddleOcrModel: plan.paddleOcrModel,
      ocrPromptPreset: plan.promptPreset,
    );
    await _aiConfigStore.save(nextConfig);
    if (!mounted) {
      return;
    }
    setState(() {
      _aiConfig = nextConfig;
    });
    _ocrService = const ConfiguredWaybillOcrService();
    final picked = await pickAiDocumentImage(
      plan.source,
      imagePicker: _effectiveImagePicker,
    );
    if (picked == null) {
      DebugEventLog.add('AI_OCR', 'image not selected');
      return;
    }
    if (!mounted) {
      return;
    }
    _setOcrProgress(
      '上传至${_ocrProviderLabel(nextConfig)}：${_ocrModelLabel(nextConfig)} · ${_ocrPromptPresetLabel(nextConfig)}策略',
    );
    await _runWaybillOcr(picked);
  }

  Future<void> _runWaybillOcr(File image) async {
    final totalStopwatch = Stopwatch()..start();
    DebugEventLog.add('AI_OCR',
        'start image=${image.path.split(Platform.pathSeparator).last}');
    _setOcrInProgress(true);
    try {
      _setOcrProgress('正在上传图片至${_ocrProviderLabel(_aiConfig)}，等待识别...');
      final prepared = await _imagePreparer.prepare(image);
      final recognizeStopwatch = Stopwatch()..start();
      final WaybillOcrDraft draft;
      try {
        draft = await _effectiveOcrService.recognize(
          prepared.file,
          merchantHistoryNames: _merchantHistoryNames,
          onProgress: (message) {
            DebugEventLog.add('AI_OCR', 'progress $message');
            _setOcrProgress(message);
          },
        );
      } finally {
        await prepared.dispose();
      }
      recognizeStopwatch.stop();
      DebugEventLog.add(
        'AI_OCR_TIMING',
        'recognize_ms=${recognizeStopwatch.elapsedMilliseconds}',
      );
      DebugEventLog.add(
        'AI_OCR_MERCHANT_FLOW',
        'raw=${_logValue(draft.rawMerchantName)} final=${_logValue(draft.merchantName)} warnings=${draft.warnings.length}',
      );
      _setOcrProgress(_ocrDraftSummary(draft));
      _setOcrProgress('正在匹配本地库存数据...');
      final matchStopwatch = Stopwatch()..start();
      final matched = await WaybillOcrMatcher(_productDao).match(draft);
      matchStopwatch.stop();
      DebugEventLog.add(
        'AI_OCR_TIMING',
        'match_ms=${matchStopwatch.elapsedMilliseconds}',
      );
      final successMessage = _ocrMatchSummary(matched);
      _setOcrProgress(successMessage, state: _OcrProgressState.success);
      DebugEventLog.add(
        'AI_OCR',
        'success waybill=${matched.source.waybillNo} merchant=${matched.source.merchantName} lines=${matched.lines.length} warnings=${matched.source.warnings.length}',
      );
      if (!mounted) {
        return;
      }
      _setOcrInProgress(false);
      final openReviewStopwatch = Stopwatch()..start();
      await _openOcrReview(matched, progressText: successMessage);
      openReviewStopwatch.stop();
      totalStopwatch.stop();
      DebugEventLog.add(
        'AI_OCR_TIMING',
        'open_review_ms=${openReviewStopwatch.elapsedMilliseconds} total_ms=${totalStopwatch.elapsedMilliseconds}',
      );
      if (mounted) {
        setState(() => _ocrProgressText = null);
      }
    } on AiOcrImagePreparationException catch (error) {
      DebugEventLog.add('AI_OCR', 'image_prepare_failed ${error.message}');
      if (!mounted) {
        return;
      }
      _setOcrProgress(error.message, state: _OcrProgressState.error);
      _setOcrInProgress(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on GeminiWaybillOcrException catch (error) {
      DebugEventLog.add('AI_OCR', 'gemini_failed ${error.message}');
      if (!mounted) {
        return;
      }
      _setOcrProgress('识别失败：${error.message}', state: _OcrProgressState.error);
      _setOcrInProgress(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on ModelScopeWaybillOcrException catch (error) {
      DebugEventLog.add('AI_OCR', 'modelscope_failed ${error.message}');
      if (!mounted) {
        return;
      }
      final rateLimitInfo = ModelScopeWaybillOcrService.lastRateLimitInfo;
      final rateLimitText = rateLimitInfo?.summaryText();
      final diagnosis = _diagnoseModelScopeFailure(error.message);
      _setOcrProgress('识别失败：$diagnosis', state: _OcrProgressState.error);
      _setOcrInProgress(false);
      _showOcrFeedback(
        [
          diagnosis,
          if (rateLimitText != null) rateLimitText,
        ].join('\n'),
        duration: const Duration(seconds: 4),
      );
    } on PaddleOcrWaybillOcrException catch (error) {
      DebugEventLog.add('AI_OCR', 'paddleocr_failed ${error.message}');
      if (!mounted) {
        return;
      }
      _setOcrProgress('识别失败：${error.message}', state: _OcrProgressState.error);
      _setOcrInProgress(false);
      _showOcrFeedback(error.message, duration: const Duration(seconds: 4));
    } catch (_) {
      DebugEventLog.add('AI_OCR', 'failed unknown_error');
      if (!mounted) {
        return;
      }
      _setOcrProgress('识别失败，请重试', state: _OcrProgressState.error);
      _setOcrInProgress(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('识别失败，请重试')),
      );
    }
  }

  Future<void> _refreshMerchantHistory() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _stateFuture = _loadState();
    });
  }

  WaybillPhotoOcrService get _effectiveOcrService {
    return _ocrService ??=
        widget.ocrService ?? const ConfiguredWaybillOcrService();
  }

  ImagePicker get _effectiveImagePicker {
    return _imagePicker ??= widget.imagePicker ?? ImagePicker();
  }

  void _setOcrInProgress(bool value) {
    if (!mounted || _ocrInProgress == value) {
      return;
    }
    setState(() => _ocrInProgress = value);
  }

  void _setOcrProgress(
    String text, {
    _OcrProgressState state = _OcrProgressState.working,
  }) {
    if (!mounted) {
      return;
    }
    setState(() {
      _ocrProgressText = text;
      _ocrProgressState = state;
    });
  }

  Future<void> _openOcrReview(
    MatchedWaybillOcrDraft matched, {
    String? progressText,
  }) async {
    final reviewResult = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => WaybillOcrReviewScreen(
          orderDao: _orderDao,
          matched: matched,
          merchantHistoryNames: _merchantHistoryNames,
          initialOrderDate: _orderDate,
          initialProgressText: progressText,
        ),
      ),
    );
    if (reviewResult == null || !mounted) {
      return;
    }
    final merchantName = reviewResult.trim().isEmpty
        ? matched.source.merchantName
        : reviewResult.trim();
    final normalizedWaybillNo = _normalizeWaybillNo(matched.source.waybillNo);
    final orderDate =
        DateTime(_orderDate.year, _orderDate.month, _orderDate.day);
    _waybillNoController.text = normalizedWaybillNo;
    _merchantController.text = merchantName;
    _orderDate = orderDate;
    final orderId = await _orderDao.findOpenOrderId(
      waybillNo: normalizedWaybillNo,
      merchantName: merchantName,
      orderDate: _orderDate,
    );
    if (orderId != null) {
      final headerKey = _orderHeaderKey(
        waybillNo: normalizedWaybillNo,
        merchantName: merchantName,
        orderDate: _orderDate,
      );
      _draftOrderKey = headerKey;
      await _reloadDraftLines(orderId: orderId, headerKey: headerKey);
    }
    if (!mounted) {
      return;
    }
    final rateLimitText =
        ModelScopeWaybillOcrService.lastRateLimitInfo?.summaryText();
    _showOcrFeedback(
      rateLimitText == null ? '识别明细已录入' : '识别明细已录入\n$rateLimitText',
      duration: const Duration(seconds: 3),
    );
  }

  void _showOcrFeedback(String message, {required Duration duration}) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
      ),
    );
  }

  String _diagnoseModelScopeFailure(String rawMessage) {
    final message = rawMessage.trim();
    if (message.contains('429') || message.contains('限流')) {
      return '$message\n定位建议：当前是接口限流，稍后重试或避开高峰。';
    }
    if (message.contains('未识别到任何内容') ||
        message.contains('返回空结果') ||
        message.contains('返回文本为空') ||
        message.contains('返回内容为空') ||
        message.contains('未返回识别结果')) {
      return '$message\n定位建议：优先检查照片是否模糊、反光、倾斜或裁切不完整。';
    }
    if (message.contains('400')) {
      return '$message\n定位建议：通常是图片尺寸/请求参数问题，请重新拍照后重试。';
    }
    if (message.contains('401') || message.contains('403')) {
      return '$message\n定位建议：请检查魔搭 Token 是否有效、是否有该模型权限。';
    }
    if (message.contains('500') ||
        message.contains('502') ||
        message.contains('503')) {
      return '$message\n定位建议：服务端波动，建议稍后重试。';
    }
    return '$message\n定位建议：请重试一次；若持续失败，换更清晰正拍照片。';
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
      await _refreshMerchantHistory();
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
        await _refreshMerchantHistory();
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

class _MerchantHistoryPicker extends StatelessWidget {
  const _MerchantHistoryPicker({
    super.key,
    required this.names,
    required this.onSelect,
  });

  final List<String> names;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '选择历史商家',
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      onPressed: () async {
        final selected = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _MerchantHistorySheet(names: names),
        );
        if (selected != null && selected.trim().isNotEmpty) {
          onSelect(selected);
        }
      },
    );
  }
}

class _MerchantHistorySheet extends StatefulWidget {
  const _MerchantHistorySheet({required this.names});

  final List<String> names;

  @override
  State<_MerchantHistorySheet> createState() => _MerchantHistorySheetState();
}

class _MerchantHistorySheetState extends State<_MerchantHistorySheet> {
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _keyword.trim();
    final filtered = keyword.isEmpty
        ? widget.names
        : widget.names
            .where((name) => name.toLowerCase().contains(keyword.toLowerCase()))
            .toList(growable: false);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('merchantHistorySearchField'),
            controller: _searchController,
            onChanged: (value) => setState(() => _keyword = value),
            decoration: const InputDecoration(
              hintText: '搜索历史商家',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      '未找到匹配商家',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final name = filtered[index];
                      return ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        title: Text(
                          name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(name),
                      );
                    },
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ),
          ),
        ],
      ),
    );
  }
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

class _OcrCapturePlan {
  const _OcrCapturePlan({
    required this.source,
    required this.provider,
    required this.geminiModel,
    required this.modelscopeModel,
    required this.paddleOcrModel,
    required this.promptPreset,
  });

  final ImageSource source;
  final String provider;
  final String geminiModel;
  final String modelscopeModel;
  final String paddleOcrModel;
  final String promptPreset;
}

enum _OcrProgressState {
  working,
  success,
  error,
}

class _OcrProgressPanel extends StatelessWidget {
  const _OcrProgressPanel({
    required this.inProgress,
    required this.text,
    required this.state,
  });

  final bool inProgress;
  final String text;
  final _OcrProgressState state;

  @override
  Widget build(BuildContext context) {
    final colors = switch (state) {
      _OcrProgressState.working => (
          background: const Color(0xFFEFF6FF),
          foreground: const Color(0xFF1D4ED8),
          border: const Color(0xFFBFDBFE),
        ),
      _OcrProgressState.success => (
          background: const Color(0xFFF0FFF4),
          foreground: const Color(0xFF15803D),
          border: const Color(0xFFBBF7D0),
        ),
      _OcrProgressState.error => (
          background: const Color(0xFFFFF1F2),
          foreground: const Color(0xFFB91C1C),
          border: const Color(0xFFFECACA),
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (inProgress)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(colors.foreground),
                backgroundColor: colors.border,
              ),
            )
          else
            Icon(
              state == _OcrProgressState.error
                  ? Icons.cancel_rounded
                  : Icons.check_circle_rounded,
              size: 17,
              color: colors.foreground,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.foreground,
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

String _ocrProviderLabel(AiOcrConfig config) {
  if (config.usesPaddleOcr) {
    return '飞桨OCR';
  }
  return config.usesModelScopeOcr ? '魔搭' : '谷歌';
}

String _ocrModelLabel(AiOcrConfig config) {
  final model = config.usesPaddleOcr
      ? config.paddleOcrModel
      : config.usesModelScopeOcr
          ? config.modelscopeModel
          : config.geminiModel;
  final text = model.trim();
  if (text.isEmpty) {
    return '未选择模型';
  }
  final slashIndex = text.lastIndexOf('/');
  return slashIndex >= 0 ? text.substring(slashIndex + 1) : text;
}

String _ocrPromptPresetLabel(AiOcrConfig config) {
  return config.ocrPromptPreset == AiOcrConfig.ocrPromptPresetGeneral
      ? '通用'
      : '增强';
}

String _ocrDraftSummary(WaybillOcrDraft draft) {
  final waybillNo =
      draft.waybillNo.trim().isEmpty ? '未识别' : draft.waybillNo.trim();
  final merchantName =
      draft.merchantName.trim().isEmpty ? '未识别' : draft.merchantName.trim();
  return '识别到运单号: $waybillNo, 商户: $merchantName, ${draft.rows.length} 条明细';
}

String _ocrMatchSummary(MatchedWaybillOcrDraft matched) {
  final matchedCount = matched.lines.where((line) => line.isMatched).length;
  return '识别完成：${matched.lines.length} 条明细，已匹配 $matchedCount 条';
}

String _logValue(String value) {
  final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= 80) {
    return compact;
  }
  return '${compact.substring(0, 80)}...';
}

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
