import 'dart:convert';
import 'dart:io';

import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';
import 'package:qrscan_flutter/features/orders/ocr/merchant_name_matcher.dart';
import 'package:qrscan_flutter/features/orders/ocr/modelscope_waybill_ocr_service.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_diagnostics.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_photo_ocr_service.dart';
import 'package:qrscan_flutter/features/orders/ocr/zhipu_vision_client.dart';
import 'package:qrscan_flutter/shared/camera/ai_ocr_image_preparer.dart';
import 'package:qrscan_flutter/shared/utils/debug_event_log.dart';

class ZhipuWaybillOcrService implements WaybillPhotoOcrService {
  ZhipuWaybillOcrService({
    String? apiKey,
    String? model,
    FileAiConfigStore? configStore,
    ZhipuHttpPost? httpPost,
    AiOcrImagePreparer? imagePreparer,
  })  : apiKey = apiKey ?? const String.fromEnvironment('ZHIPU_API_KEY'),
        model = model ?? const String.fromEnvironment('ZHIPU_MODEL'),
        _configStore = configStore ?? const FileAiConfigStore(),
        _httpPost = httpPost,
        _imagePreparer = imagePreparer ??
            const AiOcrImagePreparer(
              maxLongEdge: 2048,
              targetLongEdges: [2048, 1792, 1536],
            );

  final String apiKey;
  final String model;
  final FileAiConfigStore _configStore;
  final ZhipuHttpPost? _httpPost;
  final AiOcrImagePreparer _imagePreparer;

  @override
  Future<WaybillOcrDraft> recognize(
    File image, {
    Iterable<String> merchantHistoryNames = const [],
    WaybillOcrProgressCallback? onProgress,
  }) async {
    final config = await _configStore.load();
    final effectiveApiKey =
        apiKey.trim().isNotEmpty ? apiKey.trim() : config.zhipuApiKey.trim();
    final effectiveModel = model.trim().isNotEmpty
        ? model.trim()
        : config.zhipuModel.trim().isNotEmpty
            ? config.zhipuModel.trim()
            : AiOcrConfig.defaultZhipuModel;
    if (effectiveApiKey.isEmpty) {
      throw const ZhipuWaybillOcrException('缺少智谱 API Key');
    }

    final prepared = await _imagePreparer.prepare(image);
    try {
      final result = await ZhipuVisionClient(
        apiKey: effectiveApiKey,
        model: effectiveModel,
        httpPost: _httpPost,
      ).recognize(
        prepared.file,
        prompt: waybillOcrPromptForPreset(config.ocrPromptPreset),
      );
      final draft = _parseDraft(
        result.content,
        merchantHistoryNames: merchantHistoryNames,
      );
      DebugEventLog.add(
        'AI_OCR',
        'success provider=zhipu model=${result.model}',
      );
      return draft;
    } on ZhipuWaybillOcrException {
      rethrow;
    } on ZhipuVisionException catch (error) {
      throw ZhipuWaybillOcrException(error.message);
    } finally {
      await prepared.dispose();
    }
  }

  WaybillOcrDraft _parseDraft(
    String content, {
    required Iterable<String> merchantHistoryNames,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      throw const ZhipuWaybillOcrException(
        '智谱返回的 OCR JSON 格式无效',
      );
    }
    if (decoded is! Map) {
      throw const ZhipuWaybillOcrException(
        '智谱返回的 OCR JSON 格式无效',
      );
    }

    final draft = applyMerchantHistoryMatch(
      WaybillOcrDraft.fromJson(Map<String, Object?>.from(decoded)),
      merchantHistoryNames,
    );
    if (_isRecognizedDraftEmpty(draft)) {
      throw const ZhipuWaybillOcrException('智谱未识别到有效运单内容');
    }
    logOcrMerchantDiagnosis(provider: 'zhipu', draft: draft);
    return draft;
  }
}

class ZhipuWaybillOcrException implements Exception {
  const ZhipuWaybillOcrException(this.message);

  final String message;

  @override
  String toString() => message;
}

bool _isRecognizedDraftEmpty(WaybillOcrDraft draft) {
  final hasHeader =
      draft.waybillNo.trim().isNotEmpty || draft.merchantName.trim().isNotEmpty;
  final hasRows = draft.rows.any((row) => row.hasContent && row.boxes > 0);
  return !hasHeader && !hasRows;
}
