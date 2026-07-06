import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/delivery_plan_dao.dart';
import 'package:qrscan_flutter/features/delivery_plan/delivery_plan_ocr_models.dart';
import 'package:qrscan_flutter/features/delivery_plan/delivery_plan_ocr_service.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/widgets/page_title.dart';

typedef DeliveryPlanImagePicker = Future<File?> Function(ImageSource source);

class DeliveryPlanScreen extends StatefulWidget {
  const DeliveryPlanScreen({
    super.key,
    this.database,
    this.ocrService,
    this.imagePicker,
  });

  final AppDatabase? database;
  final DeliveryPlanPhotoOcrService? ocrService;
  final DeliveryPlanImagePicker? imagePicker;

  @override
  State<DeliveryPlanScreen> createState() => _DeliveryPlanScreenState();
}

class _DeliveryPlanScreenState extends State<DeliveryPlanScreen> {
  late final AppDatabase _database;
  late final bool _ownsDatabase;
  late final DeliveryPlanDao _dao;
  late final DeliveryPlanPhotoOcrService _ocrService;
  late final DeliveryPlanImagePicker _imagePicker;
  late Future<List<DeliveryPlanRecordSummary>> _recordsFuture;
  bool _ocrInProgress = false;
  String? _ocrProgressText;

  @override
  void initState() {
    super.initState();
    _ownsDatabase = widget.database == null;
    _database = widget.database ?? AppDatabase();
    _dao = DeliveryPlanDao(_database);
    _ocrService = widget.ocrService ?? const ConfiguredDeliveryPlanOcrService();
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
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('相册识别'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('拍照识别'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) {
      return;
    }
    final image = await _imagePicker(source);
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
      if (draft.positiveRows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未识别到需要备货的交货计划行')),
        );
        return;
      }
      final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _DeliveryPlanReviewScreen(
            dao: _dao,
            draft: draft,
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
                          icon: Icons.assignment_outlined,
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
            Icons.assignment_outlined,
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
            for (final row in rows) ...[
              _DeliveryPlanOcrRowCard(row: row),
              const SizedBox(height: 8),
            ],
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

class _DeliveryPlanOcrRowCard extends StatelessWidget {
  const _DeliveryPlanOcrRowCard({required this.row});

  final DeliveryPlanOcrRow row;

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
          Text(
            '${row.productCode} · ${row.actualBatch} · ${row.dateBatch}',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '可能备货 ${_formatInt(row.needBoxes)}箱',
            style: const TextStyle(
              color: Color(0xFFDC2626),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '在库总箱数 ${_formatInt(row.stockTotalBoxes)} · 减交货计划可用量 ${_formatInt(row.deliveryPlanAvailableBoxes)}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
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
                  for (final item in detail.items) ...[
                    _DeliveryPlanItemCard(item: item),
                    const SizedBox(height: 8),
                  ],
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

class _DeliveryPlanItemCard extends StatelessWidget {
  const _DeliveryPlanItemCard({required this.item});

  final DeliveryPlanItem item;

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
          Text(
            '${item.productCode} · ${item.actualBatch} · ${item.dateBatch}',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '可能备货 ${_formatInt(item.needBoxes)}箱',
            style: const TextStyle(
              color: Color(0xFFDC2626),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '在库总箱数 ${_formatInt(item.stockTotalBoxes)} · 减交货计划可用量 ${_formatInt(item.deliveryPlanAvailableBoxes)}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatRecordTime(DateTime time) {
  final now = DateTime.now();
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  if (time.year == now.year && time.month == now.month && time.day == now.day) {
    return '今天 $hour:$minute';
  }
  return '${time.year}.${time.month}.${time.day} $hour:$minute';
}

String _formatInt(int value) {
  final text = value.toString();
  return text.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match.group(1)},',
  );
}
