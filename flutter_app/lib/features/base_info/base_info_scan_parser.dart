import 'package:qrscan_flutter/services/qr_parser.dart';

class BaseInfoScanResult {
  const BaseInfoScanResult({
    required this.batch,
    this.productCode,
  });

  final String batch;
  final String? productCode;
}

class BaseInfoScanParser {
  static final RegExp _directBatchPattern =
      RegExp(r'^[A-Z0-9]{7}$', caseSensitive: false);
  static final RegExp _gs1LotPattern =
      RegExp(r'(?:^|\()10\)?([A-Z0-9]{7})', caseSensitive: false);
  static final RegExp _gs1ProductPattern =
      RegExp(r'(?:^|\()01\)?([A-Z0-9]+?)(?=\(|$)', caseSensitive: false);

  static BaseInfoScanResult? extract(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final parsed = QrParser.parse(trimmed);
    if (parsed != null) {
      return BaseInfoScanResult(
        productCode: _normalizeProductCode(parsed.prefix),
        batch: parsed.batch.toUpperCase(),
      );
    }

    if (_directBatchPattern.hasMatch(trimmed)) {
      return BaseInfoScanResult(batch: trimmed.toUpperCase());
    }

    final gs1Match = _gs1LotPattern.firstMatch(trimmed);
    final gs1Batch = gs1Match?.group(1)?.toUpperCase();
    if (gs1Batch == null) {
      return null;
    }
    return BaseInfoScanResult(
      productCode: _gs1ProductPattern.firstMatch(trimmed)?.group(1),
      batch: gs1Batch,
    );
  }

  static String? extractBatch(String content) {
    return extract(content)?.batch;
  }

  static String _normalizeProductCode(String prefix) {
    final normalized = prefix.trim().toUpperCase();
    if (normalized.startsWith('00') && normalized.length > 2) {
      return normalized.substring(2);
    }
    return normalized;
  }
}
