import 'dart:io';

import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';

abstract class WaybillPhotoOcrService {
  Future<WaybillOcrDraft> recognize(File image);
}
