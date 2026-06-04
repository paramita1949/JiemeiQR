import 'package:flutter/material.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/utils/board_calculator.dart';
import 'package:qrscan_flutter/shared/widgets/page_title.dart';

class WaybillOcrReviewScreen extends StatefulWidget {
  const WaybillOcrReviewScreen({
    super.key,
    required this.orderDao,
    required this.matched,
    this.initialOrderDate,
    this.initialProgressText,
  });

  final OrderDao orderDao;
  final MatchedWaybillOcrDraft matched;
  final DateTime? initialOrderDate;
  final String? initialProgressText;

  @override
  State<WaybillOcrReviewScreen> createState() => _WaybillOcrReviewScreenState();
}

class _LineEntry {
  _LineEntry(this.line)
      : included = line.isMatched,
        selectedBatch = line.batch;

  final MatchedWaybillOcrLine line;
  bool included;
  BatchRecord? selectedBatch;

  bool get canCycleCandidates => line.candidateBatches.length > 1;

  int get selectedCandidateIndex {
    if (!canCycleCandidates) {
      return 0;
    }
    final currentId = selectedBatch?.id ?? line.candidateBatches.first.id;
    final index = line.candidateBatches.indexWhere((b) => b.id == currentId);
    return index == -1 ? 0 : index;
  }

  void cycleCandidateBatch() {
    if (!canCycleCandidates) {
      return;
    }
    final nextIndex =
        (selectedCandidateIndex + 1) % line.candidateBatches.length;
    selectedBatch = line.candidateBatches[nextIndex];
  }
}

class _InsufficientStockItem {
  const _InsufficientStockItem({
    required this.batchId,
    required this.requestedBoxes,
    required this.availableBoxes,
    required this.entries,
  });

  final int batchId;
  final int requestedBoxes;
  final int availableBoxes;
  final List<_LineEntry> entries;
}

class _WaybillOcrReviewScreenState extends State<WaybillOcrReviewScreen> {
  bool _saving = false;
  late final TextEditingController _merchantController =
      TextEditingController(text: widget.matched.source.merchantName);
  late final List<_LineEntry> _entries = [
    for (final line in widget.matched.lines) _LineEntry(line),
  ];
  late final Map<String, List<String>> _batchVariantsByProductDate =
      _buildBatchVariantsByProductDate(_entries);

  @override
  void dispose() {
    _merchantController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.matched.source;
    final selected = _entries.where((entry) => entry.included).toList();
    final selectedMatched = selected.where((entry) => entry.line.isMatched);
    final selectedCount = selectedMatched.length;
    final selectedBoxes = selectedMatched.fold<int>(
      0,
      (sum, entry) => sum + entry.line.boxes,
    );
    final totalBoxes =
        _entries.fold<int>(0, (sum, entry) => sum + entry.line.boxes);
    final reviewCount = _entries
        .where((entry) => entry.line.resolvedStatus == OcrLineStatus.needReview)
        .length;
    final unmatchedCount = _entries
        .where((entry) => entry.line.resolvedStatus == OcrLineStatus.unmatched)
        .length;
    final autoCount = _entries
        .where((entry) => entry.line.resolvedStatus == OcrLineStatus.autoFixed)
        .length;
    final canSave = selectedCount > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unmatchedCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '将自动忽略$unmatchedCount条未匹配明细',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            FilledButton.icon(
              onPressed: _saving || !canSave ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                canSave ? '确认录入（录入$selectedCount条）' : '无可录入明细',
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            const PageTitle(
              icon: Icons.document_scanner_outlined,
              title: 'AI识别结果',
              subtitle: '',
            ),
            if (widget.initialProgressText?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              _OcrReviewProgressCard(text: widget.initialProgressText!.trim()),
            ],
            const SizedBox(height: 10),
            _InfoCard(
              children: [
                _InfoRow(label: '运单号', value: draft.waybillNo),
                _EditableMerchantRow(controller: _merchantController),
                if (_merchantMatchText(draft).isNotEmpty)
                  _InfoRow(label: '商家匹配', value: _merchantMatchText(draft)),
                _InfoRow(
                  label: '订单日期',
                  value: _dateText(_effectiveOrderDate(), ''),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SummaryCard(
              total: _entries.length,
              autoCount: autoCount,
              reviewCount: reviewCount,
              unmatchedCount: unmatchedCount,
              totalBoxes: totalBoxes,
              selectedBoxes: selectedBoxes,
            ),
            if (_visibleWarnings(draft.warnings).isNotEmpty) ...[
              const SizedBox(height: 10),
              _InfoCard(
                children: _visibleWarnings(draft.warnings)
                    .map((warning) => Text(
                          warning,
                          style: const TextStyle(color: Color(0xFFB45309)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 10),
            ..._entries.map(
              (entry) => _LineCard(
                entry: entry,
                onChanged: (included) {
                  setState(() => entry.included = included);
                },
                onCycleCandidate: () {
                  setState(entry.cycleCandidateBatch);
                },
                batchVariantsByProductDate: _batchVariantsByProductDate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final draft = widget.matched.source;
    final normalizedWaybillNo = _normalizeWaybillNo(draft.waybillNo);
    final merchantName = _merchantController.text.trim().isEmpty
        ? draft.merchantName
        : _merchantController.text.trim();
    final orderDate = _effectiveOrderDate();
    final selected = _entries
        .where((entry) => entry.included && entry.line.isMatched)
        .toList(growable: false);
    final insufficientItems = await _insufficientItemsFor(selected);
    if (insufficientItems.isNotEmpty) {
      final insufficientEntries = {
        for (final item in insufficientItems) ...item.entries,
      };
      if (mounted) {
        setState(() {
          for (final entry in insufficientEntries) {
            entry.included = false;
          }
        });
      }
      final shouldContinue = await _showInsufficientConfirmDialog(
        insufficientItems,
      );
      if (shouldContinue != true) {
        if (mounted) {
          setState(() => _saving = false);
        }
        return;
      }
    }
    final selectedAfterExclusion = _entries
        .where((entry) => entry.included && entry.line.isMatched)
        .toList(growable: false);
    if (selectedAfterExclusion.isEmpty) {
      _showError('库存不足条目已移除，暂无可录入明细');
      return;
    }
    try {
      for (final entry in selectedAfterExclusion) {
        final line = entry.line;
        final product = line.product!;
        final batch = entry.selectedBatch ?? line.batch!;
        try {
          await widget.orderDao.appendPendingWaybillItem(
            waybillNo: normalizedWaybillNo,
            merchantName: merchantName,
            orderDate: orderDate,
            item: PendingOrderItemInput(
              productId: product.id,
              batchId: batch.id,
              boxes: line.boxes,
              boxesPerBoard: batch.boxesPerBoard,
              piecesPerBox: product.piecesPerBox,
            ),
          );
        } on DuplicateOrderItemException catch (duplicate) {
          await widget.orderDao.mergeDuplicateOrderItem(
            itemId: duplicate.itemId,
            appendBoxes: line.boxes,
          );
        }
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(merchantName);
    } on InsufficientStockException {
      _showError('库存不足，无法录入识别明细');
    } on InvalidStockQuantityException {
      _showError('箱数无效，无法录入识别明细');
    } on DuplicateWaybillNoException {
      _showError('运单号已存在');
    } catch (_) {
      _showError('录入失败，请检查识别结果');
    }
  }

  DateTime _normalizedOrderDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _effectiveOrderDate() {
    return _normalizedOrderDate(
      widget.initialOrderDate ?? widget.matched.orderDate ?? DateTime.now(),
    );
  }

  Future<List<_InsufficientStockItem>> _insufficientItemsFor(
    List<_LineEntry> selected,
  ) async {
    final byBatch = <int, List<_LineEntry>>{};
    for (final entry in selected) {
      final batch = entry.selectedBatch ?? entry.line.batch;
      if (batch == null) {
        continue;
      }
      byBatch.putIfAbsent(batch.id, () => <_LineEntry>[]).add(entry);
    }
    final result = <_InsufficientStockItem>[];
    for (final entry in byBatch.entries) {
      final requested = entry.value.fold<int>(
        0,
        (sum, lineEntry) => sum + lineEntry.line.boxes,
      );
      final available = await widget.orderDao.availableBoxesForBatch(entry.key);
      if (requested > available) {
        result.add(
          _InsufficientStockItem(
            batchId: entry.key,
            requestedBoxes: requested,
            availableBoxes: available,
            entries: entry.value,
          ),
        );
      }
    }
    return result;
  }

  Future<bool?> _showInsufficientConfirmDialog(
    List<_InsufficientStockItem> items,
  ) {
    if (!mounted) {
      return Future.value(false);
    }
    final lines = <String>[];
    for (final item in items) {
      final first = item.entries.first;
      final line = first.line;
      final productText = line.product == null
          ? line.sourceRows.first.productCode
          : '${line.product!.code} ${line.product!.name}';
      final batch = first.selectedBatch ?? line.batch;
      final batchText = batch == null ? '' : ' · ${batch.actualBatch}';
      lines.add(
        '$productText$batchText：需${item.requestedBoxes}箱，可用${item.availableBoxes}箱',
      );
    }
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('以下产品库存不足'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(line),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '已默认取消库存不足条目的录入，是否继续录入其余明细？',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('继续录入'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

List<String> _visibleWarnings(List<String> warnings) {
  return warnings.where((warning) {
    final normalized = warning.replaceAll(' ', '');
    return !normalized.contains('图片方向已旋转');
  }).toList();
}

String _normalizeWaybillNo(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  final stripped = trimmed.replaceFirst(RegExp(r'^0+'), '');
  return stripped.isEmpty ? '0' : stripped;
}

class _OcrReviewProgressCard extends StatelessWidget {
  const _OcrReviewProgressCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FFF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF15803D),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF15803D),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.autoCount,
    required this.reviewCount,
    required this.unmatchedCount,
    required this.totalBoxes,
    required this.selectedBoxes,
  });

  final int total;
  final int autoCount;
  final int reviewCount;
  final int unmatchedCount;
  final int totalBoxes;
  final int selectedBoxes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF4FF), Color(0xFFF8FBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '识别$total条 · 自动修正$autoCount条 · 待确认$reviewCount条 · 未匹配$unmatchedCount条',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '总箱数 $totalBoxes 箱（本次录入 $selectedBoxes 箱）',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableMerchantRow extends StatelessWidget {
  const _EditableMerchantRow({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 64,
            child: Text(
              '商家',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                isDense: true,
                hintText: '可直接修改收货方',
                border: UnderlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

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
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '未识别' : value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.entry,
    required this.onChanged,
    required this.onCycleCandidate,
    required this.batchVariantsByProductDate,
  });

  final _LineEntry entry;
  final ValueChanged<bool> onChanged;
  final VoidCallback onCycleCandidate;
  final Map<String, List<String>> batchVariantsByProductDate;

  @override
  Widget build(BuildContext context) {
    final line = entry.line;
    final product = line.product;
    final batch = entry.selectedBatch ?? line.batch;
    final title = product == null
        ? line.sourceRows.first.productCode
        : '${product.code} ${product.name}';
    final batchText =
        batch == null ? line.sourceRows.first.actualBatch : batch.dateBatch;
    final style = _statusStyle(line.resolvedStatus);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: style.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D0F172A),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.isEmpty ? '未识别产品' : title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (style.showBadge)
                  _StatusBadge(
                    text: style.label,
                    fg: style.fg,
                    bg: style.bg,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (batch == null)
              Text(
                batchText.isEmpty ? '未识别批号' : batchText,
                style: const TextStyle(color: AppTheme.textSecondary),
              )
            else
              Text.rich(
                TextSpan(
                  style: const TextStyle(color: AppTheme.textSecondary),
                  children: [
                    ..._batchCodeSpans(
                      batch.actualBatch,
                      variants: batchVariantsByProductDate[_productDateKey(
                            productCode: product?.code ?? '',
                            dateBatch: batch.dateBatch,
                          )] ??
                          const <String>[],
                      highlightDifferences: true,
                      normalColor: AppTheme.textSecondary,
                    ),
                    TextSpan(text: ' ${batch.dateBatch}'),
                  ],
                ),
              ),
            if (entry.canCycleCandidates) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onCycleCandidate,
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: Text(
                  '换一个（${entry.selectedCandidateIndex + 1}/${line.candidateBatches.length}）',
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChipText('${line.boxes}箱'),
                if (batch != null)
                  _ChipText(
                    BoardCalculator.format(
                      boxes: line.boxes,
                      boxesPerBoard: batch.boxesPerBoard,
                    ),
                  ),
                if (line.isMerged)
                  _ChipText('合并 ${line.sourceBoxes.join('+')}'),
                ...line.messages.map(_ChipText.new),
                ...line.reasons.map(_ReasonChip.new),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Switch(
                  value: entry.included,
                  onChanged: line.isMatched ? onChanged : null,
                ),
                Text(
                  line.isMatched ? '录入本条' : '未匹配，默认不录入',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.label,
    required this.fg,
    required this.bg,
    required this.border,
    required this.showBadge,
  });

  final String label;
  final Color fg;
  final Color bg;
  final Color border;
  final bool showBadge;
}

_StatusStyle _statusStyle(OcrLineStatus status) {
  switch (status) {
    case OcrLineStatus.matched:
      return const _StatusStyle(
        label: '',
        fg: AppTheme.textSecondary,
        bg: Colors.transparent,
        border: Color(0xFFE5E7EB),
        showBadge: false,
      );
    case OcrLineStatus.autoFixed:
      return const _StatusStyle(
        label: '已自动修正',
        fg: Color(0xFFB91C1C),
        bg: Color(0xFFFEE2E2),
        border: Color(0xFFFCA5A5),
        showBadge: true,
      );
    case OcrLineStatus.needReview:
      return const _StatusStyle(
        label: '已代选待确认',
        fg: Color(0xFF92400E),
        bg: Color(0xFFFEF3C7),
        border: Color(0xFFFCD34D),
        showBadge: true,
      );
    case OcrLineStatus.unmatched:
      return const _StatusStyle(
        label: '未匹配',
        fg: Color(0xFFB91C1C),
        bg: Color(0xFFFEE2E2),
        border: Color(0xFFFCA5A5),
        showBadge: true,
      );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.text,
    required this.fg,
    required this.bg,
  });

  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChipText extends StatelessWidget {
  const _ChipText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFB91C1C),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _dateText(DateTime? date, String fallback) {
  if (date == null) {
    return fallback;
  }
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _merchantMatchText(WaybillOcrDraft draft) {
  final matched = draft.matchedHistoryMerchant.trim();
  final raw = draft.rawMerchantName.trim();
  final confidence = draft.merchantConfidence.trim();
  final reason = draft.merchantMatchReason.trim();
  if (matched.isEmpty && raw.isEmpty && reason.isEmpty) {
    return '';
  }
  final parts = <String>[];
  if (matched.isNotEmpty) {
    parts.add('历史：$matched');
  }
  if (raw.isNotEmpty && raw != draft.merchantName.trim()) {
    parts.add('原文：$raw');
  }
  if (confidence.isNotEmpty) {
    parts.add('置信：$confidence');
  }
  if (reason.isNotEmpty) {
    parts.add(reason);
  }
  return parts.join(' / ');
}

String _productDateKey({
  required String productCode,
  required String dateBatch,
}) {
  return '$productCode|$dateBatch';
}

Map<String, List<String>> _buildBatchVariantsByProductDate(
  List<_LineEntry> entries,
) {
  final map = <String, Set<String>>{};
  for (final entry in entries) {
    final line = entry.line;
    final productCode = line.product?.code;
    if (productCode == null || productCode.isEmpty) {
      continue;
    }
    for (final candidate in line.candidateBatches) {
      final key = _productDateKey(
        productCode: productCode,
        dateBatch: candidate.dateBatch,
      );
      map.putIfAbsent(key, () => <String>{}).add(candidate.actualBatch);
    }
    final batch = line.batch;
    if (batch != null) {
      final key = _productDateKey(
        productCode: productCode,
        dateBatch: batch.dateBatch,
      );
      map.putIfAbsent(key, () => <String>{}).add(batch.actualBatch);
    }
  }
  return map.map(
    (key, value) => MapEntry(key, value.toList()..sort()),
  );
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
    0,
    (max, item) => item.length > max ? item.length : max,
  );
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
    spans.add(
      TextSpan(
        text: code[i],
        style: TextStyle(
          color: i < differsAt.length && differsAt[i]
              ? const Color(0xFFDC2626)
              : normalColor,
        ),
      ),
    );
  }
  return spans;
}
