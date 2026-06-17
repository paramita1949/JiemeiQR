import 'dart:io';

import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';
import 'package:qrscan_flutter/features/orders/ocr/gemini_waybill_ocr_service.dart';
import 'package:qrscan_flutter/features/orders/ocr/modelscope_waybill_ocr_service.dart';
import 'package:qrscan_flutter/features/orders/ocr/paddle_ocr_waybill_ocr_service.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_photo_ocr_service.dart';
import 'package:qrscan_flutter/shared/utils/debug_event_log.dart';

typedef OcrServiceFactory = WaybillPhotoOcrService Function(
  FileAiConfigStore configStore,
  AiOcrConfig config,
);

class ConfiguredWaybillOcrService implements WaybillPhotoOcrService {
  const ConfiguredWaybillOcrService({
    this.configStore = const FileAiConfigStore(),
    OcrServiceFactory? geminiServiceFactory,
    OcrServiceFactory? modelScopeServiceFactory,
    OcrServiceFactory? paddleOcrServiceFactory,
  })  : _geminiServiceFactory =
            geminiServiceFactory ?? _defaultGeminiServiceFactory,
        _modelScopeServiceFactory =
            modelScopeServiceFactory ?? _defaultModelScopeServiceFactory,
        _paddleOcrServiceFactory =
            paddleOcrServiceFactory ?? _defaultPaddleOcrServiceFactory;

  static WaybillPhotoOcrService _defaultGeminiServiceFactory(
    FileAiConfigStore configStore,
    AiOcrConfig config,
  ) {
    return GeminiWaybillOcrService(configStore: configStore);
  }

  static WaybillPhotoOcrService _defaultModelScopeServiceFactory(
    FileAiConfigStore configStore,
    AiOcrConfig config,
  ) {
    return ModelScopeWaybillOcrService(configStore: configStore);
  }

  static WaybillPhotoOcrService _defaultPaddleOcrServiceFactory(
    FileAiConfigStore configStore,
    AiOcrConfig config,
  ) {
    return PaddleOcrWaybillOcrService(configStore: configStore);
  }

  final FileAiConfigStore configStore;
  final OcrServiceFactory _geminiServiceFactory;
  final OcrServiceFactory _modelScopeServiceFactory;
  final OcrServiceFactory _paddleOcrServiceFactory;

  @override
  Future<WaybillOcrDraft> recognize(
    File image, {
    Iterable<String> merchantHistoryNames = const [],
  }) async {
    final config = await configStore.load();
    final provider = config.usesPaddleOcr
        ? 'paddleocr'
        : config.usesModelScopeOcr
            ? 'modelscope'
            : 'gemini';
    final model = config.usesPaddleOcr
        ? config.paddleOcrModel
        : config.usesModelScopeOcr
            ? config.modelscopeModel
            : config.geminiModel;
    DebugEventLog.add(
      'AI_OCR',
      'route provider=$provider model=$model promptPreset=${config.ocrPromptPreset}',
    );
    if (config.usesPaddleOcr) {
      return _paddleOcrServiceFactory(configStore, config).recognize(
        image,
        merchantHistoryNames: merchantHistoryNames,
      );
    }
    if (config.usesModelScopeOcr) {
      return _modelScopeServiceFactory(configStore, config).recognize(
        image,
        merchantHistoryNames: merchantHistoryNames,
      );
    }
    try {
      return await _geminiServiceFactory(configStore, config).recognize(
        image,
        merchantHistoryNames: merchantHistoryNames,
      );
    } catch (error) {
      DebugEventLog.add(
        'AI_OCR',
        'fallback gemini_to_modelscope $error',
      );
      if (!config.hasModelScopeCredential) {
        rethrow;
      }
      return _modelScopeServiceFactory(configStore, config).recognize(
        image,
        merchantHistoryNames: merchantHistoryNames,
      );
    }
  }
}
