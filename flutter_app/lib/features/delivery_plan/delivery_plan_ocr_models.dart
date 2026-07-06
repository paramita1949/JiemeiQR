class DeliveryPlanOcrDraft {
  DeliveryPlanOcrDraft({
    required List<DeliveryPlanOcrRow> rows,
    this.warnings = const [],
  }) : rows = _aggregateRows(rows);

  final List<DeliveryPlanOcrRow> rows;
  final List<String> warnings;

  List<DeliveryPlanOcrRow> get positiveRows =>
      rows.where((row) => row.needBoxes > 0).toList(growable: false);

  int get totalNeedBoxes =>
      positiveRows.fold<int>(0, (sum, row) => sum + row.needBoxes);

  factory DeliveryPlanOcrDraft.fromJson(Map<String, Object?> json) {
    final rawRows = json['rows'];
    final rows = rawRows is List
        ? rawRows
            .whereType<Map>()
            .map((row) =>
                DeliveryPlanOcrRow.fromJson(row.cast<String, Object?>()))
            .where((row) => row.hasContent)
            .toList()
        : const <DeliveryPlanOcrRow>[];
    final rawWarnings = json['warnings'];
    final warnings = rawWarnings is List
        ? rawWarnings
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList()
        : const <String>[];
    return DeliveryPlanOcrDraft(rows: rows, warnings: warnings);
  }
}

class DeliveryPlanOcrRow {
  const DeliveryPlanOcrRow({
    required this.productCode,
    required this.productName,
    required this.actualBatch,
    required this.dateBatch,
    required this.stockTotalBoxes,
    required this.deliveryPlanAvailableBoxes,
  });

  final String productCode;
  final String productName;
  final String actualBatch;
  final String dateBatch;
  final int stockTotalBoxes;
  final int deliveryPlanAvailableBoxes;

  int get needBoxes {
    final value = stockTotalBoxes - deliveryPlanAvailableBoxes;
    return value > 0 ? value : 0;
  }

  bool get hasContent =>
      productCode.trim().isNotEmpty ||
      actualBatch.trim().isNotEmpty ||
      dateBatch.trim().isNotEmpty ||
      stockTotalBoxes > 0 ||
      deliveryPlanAvailableBoxes > 0;

  DeliveryPlanOcrRow merge(DeliveryPlanOcrRow other) {
    return DeliveryPlanOcrRow(
      productCode: productCode.isNotEmpty ? productCode : other.productCode,
      productName: productName.isNotEmpty ? productName : other.productName,
      actualBatch: actualBatch.isNotEmpty ? actualBatch : other.actualBatch,
      dateBatch: dateBatch.isNotEmpty ? dateBatch : other.dateBatch,
      stockTotalBoxes: stockTotalBoxes + other.stockTotalBoxes,
      deliveryPlanAvailableBoxes:
          deliveryPlanAvailableBoxes + other.deliveryPlanAvailableBoxes,
    );
  }

  factory DeliveryPlanOcrRow.fromJson(Map<String, Object?> json) {
    return DeliveryPlanOcrRow(
      productCode: _stringValue(
        json['productCode'] ?? json['materialCode'] ?? json['物料号'],
      ),
      productName: _stringValue(
        json['productName'] ?? json['materialName'] ?? json['物料名称'],
      ),
      actualBatch: _stringValue(
        json['actualBatch'] ?? json['batchCode'] ?? json['批次'],
      ),
      dateBatch: _stringValue(
        json['dateBatch'] ??
            json['expiryDate'] ??
            json['shelfLifeExpiryDate'] ??
            json['货架寿命到期日'],
      ),
      stockTotalBoxes: _intValue(
        json['stockTotalBoxes'] ??
            json['inventoryTotalBoxes'] ??
            json['inStockTotalBoxes'] ??
            json['在库总箱数'],
      ),
      deliveryPlanAvailableBoxes: _intValue(
        json['deliveryPlanAvailableBoxes'] ??
            json['planAvailableBoxes'] ??
            json['reducedDeliveryPlanAvailableBoxes'] ??
            json['减交货计划可用量箱数'],
      ),
    );
  }
}

List<DeliveryPlanOcrRow> _aggregateRows(List<DeliveryPlanOcrRow> rows) {
  final byKey = <String, DeliveryPlanOcrRow>{};
  for (final row in rows) {
    final key = [
      _keyPart(row.productCode),
      _keyPart(row.actualBatch),
      _dateKeyPart(row.dateBatch),
    ].join('|');
    if (key == '||') {
      byKey['row-${byKey.length}'] = row;
      continue;
    }
    final existing = byKey[key];
    byKey[key] = existing == null ? row : existing.merge(row);
  }
  return byKey.values.toList(growable: false);
}

String _stringValue(Object? value) => value?.toString().trim() ?? '';

String _keyPart(String value) =>
    value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

String _dateKeyPart(String value) {
  final normalized = _keyPart(value).replaceAll('。', '.');
  final match = RegExp(r'(\d{4})[.\-/年](\d{1,2})[.\-/月](\d{1,2})日?')
      .firstMatch(normalized);
  if (match == null) {
    return normalized;
  }
  return '${match.group(1)}.${int.parse(match.group(2)!)}.${int.parse(match.group(3)!)}';
}

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  final text = _stringValue(value).replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(text) ?? 0;
}
