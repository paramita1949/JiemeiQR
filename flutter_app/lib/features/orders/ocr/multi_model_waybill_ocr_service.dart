import 'dart:convert';
import 'dart:io';

import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';
import 'package:qrscan_flutter/features/orders/ocr/merchant_name_matcher.dart';
import 'package:qrscan_flutter/features/orders/ocr/modelscope_waybill_ocr_service.dart';
import 'package:qrscan_flutter/features/orders/ocr/multi_model_vision_client.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_diagnostics.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_photo_ocr_service.dart';
import 'package:qrscan_flutter/shared/camera/ai_ocr_image_preparer.dart';

class MultiModelWaybillOcrService implements WaybillPhotoOcrService {
  MultiModelWaybillOcrService({
    FileAiConfigStore? configStore,
    MultiModelVisionClient? client,
    AiOcrImagePreparer? imagePreparer,
  })  : _configStore = configStore ?? const FileAiConfigStore(),
        _client = client ?? MultiModelVisionClient(),
        _imagePreparer = imagePreparer ??
            const AiOcrImagePreparer(
              maxLongEdge: 2048,
              targetLongEdges: [2048, 1792, 1536],
            );

  final FileAiConfigStore _configStore;
  final MultiModelVisionClient _client;
  final AiOcrImagePreparer _imagePreparer;

  @override
  Future<WaybillOcrDraft> recognize(
    File image, {
    Iterable<String> merchantHistoryNames = const [],
    WaybillOcrProgressCallback? onProgress,
  }) async {
    final config = await _configStore.load();
    if (config.multiModelToken.trim().isEmpty) {
      throw const MultiModelWaybillOcrException('缺少模型中心 Token');
    }
    onProgress?.call('正在上传运单照片...');
    final prepared = await _imagePreparer.prepare(image);
    try {
      final content = await _client.completeVision(
        token: config.multiModelToken,
        model: config.multiModelModel,
        prompt: waybillOcrPromptForPreset(config.ocrPromptPreset),
        imageBytes: await prepared.file.readAsBytes(),
      );
      onProgress?.call('正在整理运单识别结果...');
      final decoded = jsonDecode(content);
      if (decoded is! Map) {
        throw const MultiModelWaybillOcrException('OCR JSON 格式无效');
      }
      final draft = applyMerchantHistoryMatch(
        WaybillOcrDraft.fromJson(decoded.cast<String, Object?>()),
        merchantHistoryNames,
      );
      final hasHeader = draft.waybillNo.trim().isNotEmpty ||
          draft.merchantName.trim().isNotEmpty;
      final hasRows = draft.rows.any((row) => row.hasContent && row.boxes > 0);
      if (!hasHeader && !hasRows) {
        throw const MultiModelWaybillOcrException('平台未识别到运单内容');
      }
      logOcrMerchantDiagnosis(provider: 'multi_model', draft: draft);
      return draft;
    } on MultiModelVisionException catch (error) {
      throw MultiModelWaybillOcrException(error.message);
    } on FormatException {
      throw const MultiModelWaybillOcrException('OCR JSON 格式无效');
    } finally {
      await prepared.dispose();
    }
  }
}

class MultiModelWaybillOcrException implements Exception {
  const MultiModelWaybillOcrException(this.message);

  final String message;

  @override
  String toString() => message;
}
