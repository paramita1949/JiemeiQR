import 'package:flutter/material.dart';
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

class _WaybillOcrReviewScreenState extends State<WaybillOcrReviewScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final draft = widget.matched.source;
    final hasUnmatched = widget.matched.lines.any((line) => !line.isMatched);
    return Scaffold(
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _saving || hasUnmatched ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_outlined),
          label: Text(hasUnmatched ? '有未匹配明细' : '确认录入'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
          children: [
            const PageTitle(
              icon: Icons.document_scanner_outlined,
              title: '拍照识别结果',
              subtitle: '',
            ),
            const SizedBox(height: 8),
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
            if (draft.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoCard(
                children: draft.warnings
                    .map((warning) => Text(
                          warning,
                          style: const TextStyle(color: Color(0xFFB45309)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            ...widget.matched.lines.map(_LineCard.new),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final draft = widget.matched.source;
    final normalizedWaybillNo = _normalizeWaybillNo(draft.waybillNo);
    final orderDate = widget.matched.orderDate ?? DateTime.now();
    try {
      for (final line in widget.matched.lines.where((line) => line.isMatched)) {
        final product = line.product!;
        final batch = line.batch!;
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
  const _LineCard(this.line);

  final MatchedWaybillOcrLine line;

  @override
  Widget build(BuildContext context) {
    final product = line.product;
    final batch = line.batch;
    final title = product == null
        ? line.sourceRows.first.productCode
        : '${product.code} ${product.name}';
    final batchText = batch == null
        ? line.sourceRows.first.actualBatch
        : '${batch.actualBatch} ${batch.dateBatch}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                line.isMatched ? Colors.transparent : const Color(0xFFF59E0B),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.isEmpty ? '未识别产品' : title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              batchText.isEmpty ? '未识别批号' : batchText,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
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
              ],
            ),
          ],
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

String _dateText(DateTime? date, String fallback) {
  if (date == null) {
    return fallback;
  }
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
