import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/delivery_plan_dao.dart';
import 'package:qrscan_flutter/features/delivery_plan/delivery_plan_ocr_models.dart';
import 'package:qrscan_flutter/features/delivery_plan/delivery_plan_ocr_service.dart';
import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/utils/board_calculator.dart';
import 'package:qrscan_flutter/shared/widgets/page_title.dart';

typedef DeliveryPlanImagePicker = Future<File?> Function(ImageSource source);

class DeliveryPlanScreen extends StatefulWidget {
  const DeliveryPlanScreen({
    super.key,
    this.database,
    this.ocrService,
    this.imagePicker,
    this.aiConfigStore = const FileAiConfigStore(),
  });

  final AppDatabase? database;
  final DeliveryPlanPhotoOcrService? ocrService;
  final DeliveryPlanImagePicker? imagePicker;
  final FileAiConfigStore aiConfigStore;

  @override
  State<DeliveryPlanScreen> createState() => _DeliveryPlanScreenState();
}

class _DeliveryPlanScreenState extends State<DeliveryPlanScreen> {
  late final AppDatabase _database;
  late final bool _ownsDatabase;
  late final DeliveryPlanDao _dao;
  late final DeliveryPlanPhotoOcrService _ocrService;
  late final DeliveryPlanImagePicker _imagePicker;
  late final FileAiConfigStore _aiConfigStore;
  late Future<List<DeliveryPlanRecordSummary>> _recordsFuture;
  bool _ocrInProgress = false;
  String? _ocrProgressText;

  @override
  void initState() {
    super.initState();
    _ownsDatabase = widget.database == null;
    _database = widget.database ?? AppDatabase();
    _dao = DeliveryPlanDao(_database);
    _aiConfigStore = widget.aiConfigStore;
    _ocrService = widget.ocrService ??
        ConfiguredDeliveryPlanOcrService(configStore: _aiConfigStore);
    _imagePicker = widget.imagePicker ?? _pickImageWithSystemPicker;
    _recordsFuture = _dao.recordSummaries();
  }

  @override
  void dispose() {
    if (_ownsDatabase) {
      unawaited(_database.close());
    }
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _recordsFuture = _dao.recordSummaries();
    });
  }

  Future<void> _openRecord(DeliveryPlanRecordSummary summary) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _DeliveryPlanDetailScreen(
          dao: _dao,
          recordId: summary.id,
        ),
      ),
    );
    if (deleted == true && mounted) {
      _refresh();
    }
  }

  Future<void> _startAiScan() async {
    final currentConfig = await _aiConfigStore.load();
    if (!mounted) {
      return;
    }
    final plan = await showModalBottomSheet<_DeliveryPlanCapturePlan>(
      context: context,
      showDragHandle: true,
      builder: (context) =>
          _DeliveryPlanCaptureSheet(initialConfig: currentConfig),
    );
    if (plan == null) {
      return;
    }
    final nextConfig = currentConfig.copyWith(
      provider: plan.provider,
      geminiModel: plan.geminiModel,
      modelscopeModel: plan.modelscopeModel,
      paddleOcrModel: plan.paddleOcrModel,
    );
    await _aiConfigStore.save(nextConfig);
    if (!mounted) {
      return;
    }
    final image = await _imagePicker(plan.source);
    if (image == null) {
      return;
    }
    setState(() {
      _ocrInProgress = true;
      _ocrProgressText = '正在识别交货计划截图...';
    });
    try {
      final draft = await _ocrService.recognize(
        image,
        onProgress: (message) {
          if (mounted) {
            setState(() => _ocrProgressText = message);
          }
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _ocrInProgress = false;
        _ocrProgressText = null;
      });
      final enrichedDraft = await _dao.draftWithBaseLocations(draft);
      if (!mounted) {
        return;
      }
      if (enrichedDraft.positiveRows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未识别到需要备货的交货计划行')),
        );
        return;
      }
      final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _DeliveryPlanReviewScreen(
            dao: _dao,
            draft: enrichedDraft,
            sourceImagePath: image.path,
          ),
        ),
      );
      if (created == true && mounted) {
        _refresh();
      }
    } on DeliveryPlanOcrException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _ocrInProgress = false;
        _ocrProgressText = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _ocrInProgress = false;
        _ocrProgressText = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('交货计划识别失败，请重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<DeliveryPlanRecordSummary>>(
          future: _recordsFuture,
          builder: (context, snapshot) {
            final records =
                snapshot.data ?? const <DeliveryPlanRecordSummary>[];
            final loading =
                snapshot.connectionState == ConnectionState.waiting &&
                    snapshot.data == null;
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: PageTitle(
                          icon: Icons.event_note_outlined,
                          title: '交货计划',
                          subtitle: '截图识别后的临时记录',
                        ),
                      ),
                      FilledButton.icon(
                        key: const Key('deliveryPlanScanButton'),
                        onPressed: _ocrInProgress
                            ? null
                            : () => unawaited(_startAiScan()),
                        icon: const Icon(Icons.document_scanner_outlined),
                        label: const Text('AI扫描'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_ocrInProgress) ...[
                    LinearProgressIndicator(
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _ocrProgressText ?? '正在识别交货计划截图...',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (records.isEmpty)
                    const _DeliveryPlanEmptyState()
                  else
                    ...records.map(
                      (record) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DeliveryPlanRecordCard(
                          summary: record,
                          onTap: () => unawaited(_openRecord(record)),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

Future<File?> _pickImageWithSystemPicker(ImageSource source) async {
  final picked = await ImagePicker().pickImage(
    source: source,
    imageQuality: 85,
    maxWidth: 1800,
    maxHeight: 2400,
  );
  if (picked == null) {
    return null;
  }
  return File(picked.path);
}

class _DeliveryPlanCapturePlan {
  const _DeliveryPlanCapturePlan({
    required this.source,
    required this.provider,
    required this.geminiModel,
    required this.modelscopeModel,
    required this.paddleOcrModel,
  });

  final ImageSource source;
  final String provider;
  final String geminiModel;
  final String modelscopeModel;
  final String paddleOcrModel;
}

class _DeliveryPlanCaptureSheet extends StatefulWidget {
  const _DeliveryPlanCaptureSheet({required this.initialConfig});

  final AiOcrConfig initialConfig;

  @override
  State<_DeliveryPlanCaptureSheet> createState() =>
      _DeliveryPlanCaptureSheetState();
}

class _DeliveryPlanCaptureSheetState extends State<_DeliveryPlanCaptureSheet> {
  late String _provider;
  late String _geminiModel;
  late String _modelscopeModel;
  late String _paddleOcrModel;

  @override
  void initState() {
    super.initState();
    _provider = widget.initialConfig.provider;
    _geminiModel = widget.initialConfig.geminiModel;
    _modelscopeModel = widget.initialConfig.modelscopeModel;
    _paddleOcrModel = widget.initialConfig.paddleOcrModel;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Text(
                '交货计划专用提示词',
                style: TextStyle(
                  color: Color(0xFF1D4ED8),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
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
                  _compactChoice(
                    label: '谷歌',
                    selected: _provider == AiOcrConfig.defaultProvider,
                    enabled: widget.initialConfig.hasGeminiKey,
                    onTap: () => setState(
                      () => _provider = AiOcrConfig.defaultProvider,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _compactChoice(
                    label: '魔搭',
                    selected: _provider == AiOcrConfig.modelscopeProvider,
                    enabled: widget.initialConfig.hasModelScopeCredential,
                    onTap: () => setState(
                      () => _provider = AiOcrConfig.modelscopeProvider,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _compactChoice(
                    label: '飞桨',
                    selected: _provider == AiOcrConfig.paddleOcrProvider,
                    enabled: widget.initialConfig.hasPaddleOcrCredential,
                    onTap: () => setState(
                      () => _provider = AiOcrConfig.paddleOcrProvider,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PopupMenuButton<String>(
                      tooltip: '切换具体模型',
                      onSelected: (value) => setState(() {
                        if (_provider == AiOcrConfig.modelscopeProvider) {
                          _modelscopeModel = value;
                        } else if (_provider == AiOcrConfig.paddleOcrProvider) {
                          _paddleOcrModel = value;
                        } else {
                          _geminiModel = value;
                        }
                      }),
                      itemBuilder: (context) => _activeModelPresets()
                          .map(
                            (model) => PopupMenuItem<String>(
                              value: model,
                              child: Text(
                                _shortModelName(model),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      child: Container(
                        height: 33,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFDCE3EE)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _shortModelName(_activeModel()),
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
                    onPressed: () => _finish(ImageSource.gallery),
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
                    onPressed: () => _finish(ImageSource.camera),
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
  }

  Widget _compactChoice({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE9F1FF) : const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF8FAEF5) : const Color(0xFFE1E7F1),
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

  String _activeModel() {
    if (_provider == AiOcrConfig.modelscopeProvider) {
      return _modelscopeModel;
    }
    if (_provider == AiOcrConfig.paddleOcrProvider) {
      return _paddleOcrModel;
    }
    return _geminiModel;
  }

  List<String> _activeModelPresets() {
    final presets = _provider == AiOcrConfig.modelscopeProvider
        ? widget.initialConfig.modelScopeModelPresets
        : _provider == AiOcrConfig.paddleOcrProvider
            ? widget.initialConfig.paddleOcrModelPresets
            : widget.initialConfig.geminiModelPresets;
    return <String>{
      if (_activeModel().trim().isNotEmpty) _activeModel().trim(),
      ...presets.where((item) => item.trim().isNotEmpty),
    }.toList();
  }

  String _shortModelName(String model) {
    final text = model.trim();
    if (text.isEmpty) {
      return '未选择模型';
    }
    final slashIndex = text.lastIndexOf('/');
    return slashIndex >= 0 ? text.substring(slashIndex + 1) : text;
  }

  void _finish(ImageSource source) {
    Navigator.of(context).pop(
      _DeliveryPlanCapturePlan(
        source: source,
        provider: _provider,
        geminiModel: _geminiModel,
        modelscopeModel: _modelscopeModel,
        paddleOcrModel: _paddleOcrModel,
      ),
    );
  }
}

class _DeliveryPlanEmptyState extends StatelessWidget {
  const _DeliveryPlanEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_note_outlined,
            color: AppTheme.textSecondary,
            size: 34,
          ),
          SizedBox(height: 10),
          Text(
            '暂无交货计划记录',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '点 AI扫描 识别截图后生成记录',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DeliveryPlanRecordCard extends StatelessWidget {
  const _DeliveryPlanRecordCard({
    required this.summary,
    required this.onTap,
  });

  final DeliveryPlanRecordSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('deliveryPlanRecord-${summary.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.assignment_turned_in_outlined,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatRecordTime(summary.createdAt),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '识别 ${summary.lineCount} 个批号 · 可能备货 ${_formatInt(summary.totalNeedBoxes)} 箱',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryPlanDetailScreen extends StatefulWidget {
  const _DeliveryPlanDetailScreen({
    required this.dao,
    required this.recordId,
  });

  final DeliveryPlanDao dao;
  final int recordId;

  @override
  State<_DeliveryPlanDetailScreen> createState() =>
      _DeliveryPlanDetailScreenState();
}

class _DeliveryPlanReviewScreen extends StatelessWidget {
  const _DeliveryPlanReviewScreen({
    required this.dao,
    required this.draft,
    required this.sourceImagePath,
  });

  final DeliveryPlanDao dao;
  final DeliveryPlanOcrDraft draft;
  final String sourceImagePath;

  Future<void> _confirm(BuildContext context) async {
    await dao.createRecordFromDraft(
      draft,
      sourceImagePath: sourceImagePath,
    );
    if (context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = draft.positiveRows;
    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
          child: FilledButton.icon(
            key: const Key('confirmDeliveryPlanRecordButton'),
            onPressed: () => unawaited(_confirm(context)),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('确认生成记录'),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
          children: [
            const PageTitle(
              icon: Icons.task_alt_outlined,
              title: '识别复核',
              subtitle: '确认后生成一条交货计划记录',
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                '合计 ${_formatInt(draft.totalNeedBoxes)} 箱',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _DeliveryPlanLineList(
              lines: [
                for (final row in rows)
                  _DeliveryPlanDisplayLine(
                    productCode: row.productCode,
                    actualBatch: row.actualBatch,
                    dateBatch: row.dateBatch,
                    location: row.location,
                    needBoxes: row.needBoxes,
                    boxesPerBoard: row.boxesPerBoard,
                  ),
              ],
            ),
            if (draft.warnings.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '提醒：${draft.warnings.join('；')}',
                style: const TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeliveryPlanDisplayLine {
  const _DeliveryPlanDisplayLine({
    required this.productCode,
    required this.actualBatch,
    required this.dateBatch,
    required this.location,
    required this.needBoxes,
    required this.boxesPerBoard,
  });

  final String productCode;
  final String actualBatch;
  final String dateBatch;
  final String location;
  final int needBoxes;
  final int boxesPerBoard;
}

class _DeliveryPlanLineList extends StatelessWidget {
  const _DeliveryPlanLineList({required this.lines});

  final List<_DeliveryPlanDisplayLine> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < lines.length; index += 1) ...[
            _DeliveryPlanLineRow(line: lines[index]),
            if (index != lines.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _DeliveryPlanLineRow extends StatelessWidget {
  const _DeliveryPlanLineRow({required this.line});

  final _DeliveryPlanDisplayLine line;

  @override
  Widget build(BuildContext context) {
    const danger = Color(0xFFDC2626);
    final location = line.location.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              children: [
                TextSpan(text: _displayValue(line.productCode)),
                const TextSpan(text: ' · '),
                TextSpan(text: _displayValue(line.actualBatch)),
                const TextSpan(text: ' · '),
                TextSpan(
                  text: _displayValue(line.dateBatch),
                  style: const TextStyle(color: danger),
                ),
                TextSpan(
                  text: ' · ${_formatInt(line.needBoxes)}箱 · ',
                  style: const TextStyle(color: danger),
                ),
                TextSpan(
                  text: _boardText(
                    boxes: line.needBoxes,
                    boxesPerBoard: line.boxesPerBoard,
                  ),
                  style: const TextStyle(color: danger),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            location.isEmpty ? '库位 --' : '库位 $location',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryPlanDetailScreenState extends State<_DeliveryPlanDetailScreen> {
  late Future<DeliveryPlanRecordDetail?> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = widget.dao.recordDetail(widget.recordId);
  }

  Future<void> _deleteRecord() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除交货计划记录'),
        content: const Text('删除后仅移除这条识别记录，不影响订单和库存。'),
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
    if (confirm != true) {
      return;
    }
    await widget.dao.deleteRecord(widget.recordId);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<DeliveryPlanRecordDetail?>(
          future: _detailFuture,
          builder: (context, snapshot) {
            final detail = snapshot.data;
            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: PageTitle(
                        icon: Icons.fact_check_outlined,
                        title: '交货计划预览',
                        subtitle: '只用于查看，不影响订单库存',
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: '删除记录',
                      onPressed: _deleteRecord,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (detail == null)
                  const Text('记录不存在')
                else ...[
                  _DeliveryPlanTotalCard(detail: detail),
                  const SizedBox(height: 10),
                  _DeliveryPlanLineList(
                    lines: [
                      for (final item in detail.items)
                        _DeliveryPlanDisplayLine(
                          productCode: item.productCode,
                          actualBatch: item.actualBatch,
                          dateBatch: item.dateBatch,
                          location: item.location,
                          needBoxes: item.needBoxes,
                          boxesPerBoard: item.boxesPerBoard,
                        ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DeliveryPlanTotalCard extends StatelessWidget {
  const _DeliveryPlanTotalCard({required this.detail});

  final DeliveryPlanRecordDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '合计 ${_formatInt(detail.totalNeedBoxes)} 箱',
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _boardText({
  required int boxes,
  required int boxesPerBoard,
}) {
  if (boxesPerBoard <= 0) {
    return '--';
  }
  return BoardCalculator.format(
    boxes: boxes,
    boxesPerBoard: boxesPerBoard,
  );
}

String _displayValue(String value) {
  final text = value.trim();
  return text.isEmpty ? '--' : text;
}

String _formatRecordTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.month}.${time.day} $hour:$minute';
}

String _formatInt(int value) {
  final text = value.toString();
  return text.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match.group(1)},',
  );
}
