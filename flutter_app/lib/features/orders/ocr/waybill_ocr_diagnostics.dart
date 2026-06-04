import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';
import 'package:qrscan_flutter/shared/utils/debug_event_log.dart';

void logOcrMerchantDiagnosis({
  required String provider,
  required WaybillOcrDraft draft,
}) {
  final raw = _compactLogValue(draft.rawMerchantName);
  final finalName = _compactLogValue(draft.merchantName);
  final relation = raw.isEmpty
      ? 'raw_empty'
      : raw == finalName
          ? 'same'
          : 'shortened_or_changed';
  DebugEventLog.add(
    'AI_OCR_MERCHANT',
    'provider=$provider raw=$raw final=$finalName relation=$relation',
  );
}

String _compactLogValue(String value) {
  final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= 80) {
    return compact;
  }
  return '${compact.substring(0, 80)}...';
}
