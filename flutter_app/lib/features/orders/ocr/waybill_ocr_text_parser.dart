import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';

WaybillOcrDraft parseWaybillOcrText({
  Map<String, String> fields = const {},
  String fullText = '',
}) {
  return WaybillOcrDraft(
    waybillNo: _field(fields, const ['运单号', '通单号', '单号', '发货单号']),
    merchantName: _field(fields, const ['客户', '收货方', '经销商', '商家', '单位']),
    orderDateText: _field(fields, const ['日期', '单据日期', '发货日期']),
    rows: _parseRows(fields, fullText),
    warnings: const <String>[],
  );
}

String _field(Map<String, String> fields, List<String> names) {
  for (final name in names) {
    for (final entry in fields.entries) {
      if (entry.key.contains(name)) {
        return entry.value;
      }
    }
  }
  return '';
}

List<WaybillOcrRow> _parseRows(Map<String, String> fields, String fullText) {
  final rows = <WaybillOcrRow>[];
  final text = '${fields.values.join('\n\n')}\n\n$fullText';
  final linePattern = RegExp(
    r'(\d{4,6})\s+(.+?)\s+([A-Z0-9]{5,})\s+(\d{4}[.\-/年]\d{1,2}[.\-/月]\d{1,2}日?)\s+(\d+)\s*箱?',
    caseSensitive: false,
  );
  for (final match in linePattern.allMatches(text)) {
    rows.add(
      WaybillOcrRow(
        productCode: match.group(1) ?? '',
        productName: (match.group(2) ?? '').trim(),
        actualBatch: (match.group(3) ?? '').trim(),
        dateBatch: (match.group(4) ?? '').trim(),
        boxes: int.tryParse(match.group(5) ?? '') ?? 0,
      ),
    );
  }
  return rows;
}
