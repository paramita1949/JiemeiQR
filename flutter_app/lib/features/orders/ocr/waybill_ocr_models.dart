import 'package:qrscan_flutter/data/app_database.dart';

class WaybillOcrDraft {
  const WaybillOcrDraft({
    required this.waybillNo,
    required this.merchantName,
    required this.orderDateText,
    required this.rows,
    this.warnings = const [],
  });

  final String waybillNo;
  final String merchantName;
  final String orderDateText;
  final List<WaybillOcrRow> rows;
  final List<String> warnings;

  factory WaybillOcrDraft.fromJson(Map<String, Object?> json) {
    final rowValues = json['rows'] ?? json['items'];
    final rows = rowValues is List
        ? rowValues
            .whereType<Map>()
            .map((row) => WaybillOcrRow.fromJson(row.cast<String, Object?>()))
            .where((row) => row.hasContent)
            .toList()
        : const <WaybillOcrRow>[];
    final warningValues = json['warnings'];
    return WaybillOcrDraft(
      waybillNo: _stringValue(json['waybillNo']),
      merchantName: _stringValue(json['merchantName']),
      orderDateText: _stringValue(json['orderDate']),
      rows: rows,
      warnings: warningValues is List
          ? warningValues
              .map(_stringValue)
              .where((value) => value.isNotEmpty)
              .toList()
          : const <String>[],
    );
  }
}

class WaybillOcrRow {
  const WaybillOcrRow({
    required this.productCode,
    required this.productName,
    required this.actualBatch,
    required this.dateBatch,
    required this.boxes,
  });

  final String productCode;
  final String productName;
  final String actualBatch;
  final String dateBatch;
  final int boxes;

  bool get hasContent =>
      productCode.trim().isNotEmpty ||
      productName.trim().isNotEmpty ||
      actualBatch.trim().isNotEmpty ||
      boxes > 0;

  factory WaybillOcrRow.fromJson(Map<String, Object?> json) {
    return WaybillOcrRow(
      productCode: _stringValue(json['productCode']),
      productName: _stringValue(json['productName']),
      actualBatch: _stringValue(json['actualBatch'] ?? json['batchCode']),
      dateBatch: _stringValue(json['dateBatch']),
      boxes: _intValue(json['boxes'] ?? json['quantity']),
    );
  }
}

class MatchedWaybillOcrDraft {
  const MatchedWaybillOcrDraft({
    required this.source,
    required this.orderDate,
    required this.lines,
  });

  final WaybillOcrDraft source;
  final DateTime? orderDate;
  final List<MatchedWaybillOcrLine> lines;

  bool get hasSavableLines => lines.any((line) => line.isMatched);
  int get autoFixedCount =>
      lines.where((line) => line.status == OcrLineStatus.autoFixed).length;
  int get needReviewCount =>
      lines.where((line) => line.status == OcrLineStatus.needReview).length;
  int get unmatchedCount =>
      lines.where((line) => line.status == OcrLineStatus.unmatched).length;
}

enum OcrLineStatus {
  autoFixed,
  needReview,
  unmatched,
}

class MatchedWaybillOcrLine {
  const MatchedWaybillOcrLine({
    required this.product,
    required this.batch,
    required this.boxes,
    required this.sourceRows,
    required this.sourceBoxes,
    required this.messages,
    this.status,
    this.reasons = const [],
    this.candidateBatches = const [],
  });

  final Product? product;
  final BatchRecord? batch;
  final int boxes;
  final List<WaybillOcrRow> sourceRows;
  final List<int> sourceBoxes;
  final List<String> messages;
  final OcrLineStatus? status;
  final List<String> reasons;
  final List<BatchRecord> candidateBatches;

  bool get isMatched => product != null && batch != null && boxes > 0;
  bool get isMerged => sourceRows.length > 1;
  OcrLineStatus get resolvedStatus {
    if (status != null) {
      return status!;
    }
    return isMatched ? OcrLineStatus.autoFixed : OcrLineStatus.unmatched;
  }
}

String _stringValue(Object? value) => value?.toString().trim() ?? '';

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
