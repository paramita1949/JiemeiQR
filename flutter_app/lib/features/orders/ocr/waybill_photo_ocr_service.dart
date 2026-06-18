import 'dart:io';

import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';

typedef WaybillOcrProgressCallback = void Function(String message);

abstract class WaybillPhotoOcrService {
  Future<WaybillOcrDraft> recognize(
    File image, {
    Iterable<String> merchantHistoryNames = const [],
    WaybillOcrProgressCallback? onProgress,
  });
}
