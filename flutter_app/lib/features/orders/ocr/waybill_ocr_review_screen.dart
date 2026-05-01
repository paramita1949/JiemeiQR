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
  });

  final OrderDao orderDao;
  final MatchedWaybillOcrDraft matched;

  @override
  State<WaybillOcrReviewScreen> createState() => _WaybillOcrReviewScreenState();
}

enum _LineFilter { all, reviewOnly }

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

class _WaybillOcrReviewScreenState extends State<WaybillOcrReviewScreen> {
  bool _saving = false;
  _LineFilter _filter = _LineFilter.all;
  late final List<_LineEntry> _entries = [
    for (final line in widget.matched.lines) _LineEntry(line),
  ];
  late final Map<String, List<String>> _batchVariantsByProductDate =
      _buildBatchVariantsByProductDate(_entries);

  @override
  Widget build(BuildContext context) {
    final draft = widget.matched.source;
    final selected = _entries.where((entry) => entry.included).toList();
    final selectedMatched = selected.where((entry) => entry.line.isMatched);
    final selectedCount = selectedMatched.length;
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
    final visibleEntries = _entries.where((entry) {
      if (_filter == _LineFilter.reviewOnly) {
        return entry.line.resolvedStatus == OcrLineStatus.needReview;
      }
      return true;
    }).toList();

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
            const SizedBox(height: 10),
            _InfoCard(
              children: [
                _InfoRow(label: '运单号', value: draft.waybillNo),
                _InfoRow(label: '商家', value: draft.merchantName),
                _InfoRow(
                  label: '日期',
                  value:
                      _dateText(widget.matched.orderDate, draft.orderDateText),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SummaryCard(
              total: _entries.length,
              autoCount: autoCount,
              reviewCount: reviewCount,
              unmatchedCount: unmatchedCount,
              onAcceptAuto: _acceptAutoFixed,
              onIgnoreUnmatched: _ignoreUnmatched,
              filter: _filter,
              onToggleFilter: _toggleReviewFilter,
            ),
            if (draft.warnings.isNotEmpty) ...[
              const SizedBox(height: 10),
              _InfoCard(
                children: draft.warnings
                    .map((warning) => Text(
                          warning,
                          style: const TextStyle(color: Color(0xFFB45309)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 10),
            ...visibleEntries.map(
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

  void _acceptAutoFixed() {
    setState(() {
      for (final entry in _entries) {
        if (entry.line.resolvedStatus == OcrLineStatus.autoFixed &&
            entry.line.isMatched) {
          entry.included = true;
        }
      }
    });
  }

  void _ignoreUnmatched() {
    setState(() {
      for (final entry in _entries) {
        if (entry.line.resolvedStatus == OcrLineStatus.unmatched) {
          entry.included = false;
        }
      }
    });
  }

  void _toggleReviewFilter() {
    setState(() {
      _filter =
          _filter == _LineFilter.all ? _LineFilter.reviewOnly : _LineFilter.all;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final draft = widget.matched.source;
    final normalizedWaybillNo = _normalizeWaybillNo(draft.waybillNo);
    final orderDate = widget.matched.orderDate ?? DateTime.now();
    final selected =
        _entries.where((entry) => entry.included && entry.line.isMatched);
    try {
      for (final entry in selected) {
        final line = entry.line;
        final product = line.product!;
        final batch = entry.selectedBatch ?? line.batch!;
        try {
          await widget.orderDao.appendPendingWaybillItem(
            waybillNo: normalizedWaybillNo,
            merchantName: draft.merchantName,
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
      Navigator.of(context).pop(true);
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

String _normalizeWaybillNo(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  final stripped = trimmed.replaceFirst(RegExp(r'^0+'), '');
  return stripped.isEmpty ? '0' : stripped;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.autoCount,
    required this.reviewCount,
    required this.unmatchedCount,
    required this.onAcceptAuto,
    required this.onIgnoreUnmatched,
    required this.filter,
    required this.onToggleFilter,
  });

  final int total;
  final int autoCount;
  final int reviewCount;
  final int unmatchedCount;
  final VoidCallback onAcceptAuto;
  final VoidCallback onIgnoreUnmatched;
  final _LineFilter filter;
  final VoidCallback onToggleFilter;

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
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onAcceptAuto,
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: const Text('一键接受高置信'),
              ),
              OutlinedButton.icon(
                onPressed: onIgnoreUnmatched,
                icon: const Icon(Icons.filter_alt_off, size: 18),
                label: const Text('忽略未匹配'),
              ),
              ChoiceChip(
                selected: filter == _LineFilter.reviewOnly,
                label: const Text('仅看待确认'),
                onSelected: (_) => onToggleFilter(),
              ),
            ],
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
  });

  final String label;
  final Color fg;
  final Color bg;
  final Color border;
}

_StatusStyle _statusStyle(OcrLineStatus status) {
  switch (status) {
    case OcrLineStatus.autoFixed:
      return const _StatusStyle(
        label: '已自动修正',
        fg: Color(0xFF166534),
        bg: Color(0xFFDCFCE7),
        border: Color(0xFF86EFAC),
      );
    case OcrLineStatus.needReview:
      return const _StatusStyle(
        label: '已代选待确认',
        fg: Color(0xFF92400E),
        bg: Color(0xFFFEF3C7),
        border: Color(0xFFFCD34D),
      );
    case OcrLineStatus.unmatched:
      return const _StatusStyle(
        label: '未匹配',
        fg: Color(0xFFB91C1C),
        bg: Color(0xFFFEE2E2),
        border: Color(0xFFFCA5A5),
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
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF1D4ED8),
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
