import 'dart:io';

import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';
import 'package:qrscan_flutter/features/orders/ocr/gemini_waybill_ocr_service.dart';
import 'package:qrscan_flutter/features/orders/ocr/modelscope_waybill_ocr_service.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_photo_ocr_service.dart';

class ConfiguredWaybillOcrService implements WaybillPhotoOcrService {
  const ConfiguredWaybillOcrService({
    this.configStore = const FileAiConfigStore(),
  });

  final FileAiConfigStore configStore;

  @override
  Future<WaybillOcrDraft> recognize(File image) async {
    final config = await configStore.load();
    if (config.usesModelScopeOcr) {
      return ModelScopeWaybillOcrService(configStore: configStore).recognize(
        image,
      );
    }
    return GeminiWaybillOcrService(configStore: configStore).recognize(image);
  }
}
