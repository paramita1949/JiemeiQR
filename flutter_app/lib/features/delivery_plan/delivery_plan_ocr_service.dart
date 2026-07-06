import 'dart:convert';
import 'dart:io';

import 'package:qrscan_flutter/features/delivery_plan/delivery_plan_ocr_models.dart';
import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';
import 'package:qrscan_flutter/shared/utils/debug_event_log.dart';

typedef DeliveryPlanOcrProgressCallback = void Function(String message);

abstract class DeliveryPlanPhotoOcrService {
  Future<DeliveryPlanOcrDraft> recognize(
    File image, {
    DeliveryPlanOcrProgressCallback? onProgress,
  });
}

typedef GeminiDeliveryPlanHttpPost = Future<String> Function(
  Uri uri,
  Map<String, Object?> body,
);

typedef ModelScopeDeliveryPlanHttpPost = Future<String> Function(
  Uri uri,
  Map<String, Object?> body,
  String token,
);

class ConfiguredDeliveryPlanOcrService implements DeliveryPlanPhotoOcrService {
  const ConfiguredDeliveryPlanOcrService({
    this.configStore = const FileAiConfigStore(),
  });

  final FileAiConfigStore configStore;

  @override
  Future<DeliveryPlanOcrDraft> recognize(
    File image, {
    DeliveryPlanOcrProgressCallback? onProgress,
  }) async {
    final config = await configStore.load();
    DebugEventLog.add(
      'DELIVERY_PLAN_OCR',
      'route provider=${config.provider}',
    );
    if (config.usesPaddleOcr) {
      throw const DeliveryPlanOcrException(
        '交货计划暂不支持飞桨OCR，请切换谷歌或魔搭后重试',
      );
    }
    if (config.usesModelScopeOcr) {
      return ModelScopeDeliveryPlanOcrService(configStore: configStore)
          .recognize(image, onProgress: onProgress);
    }
    try {
      return await GeminiDeliveryPlanOcrService(configStore: configStore)
          .recognize(image, onProgress: onProgress);
    } on DeliveryPlanOcrException {
      if (!config.hasModelScopeCredential) {
        rethrow;
      }
      return ModelScopeDeliveryPlanOcrService(configStore: configStore)
          .recognize(image, onProgress: onProgress);
    }
  }
}

class GeminiDeliveryPlanOcrService implements DeliveryPlanPhotoOcrService {
  GeminiDeliveryPlanOcrService({
    String? apiKey,
    String? model,
    FileAiConfigStore? configStore,
    GeminiDeliveryPlanHttpPost? httpPost,
  })  : apiKey = apiKey ?? const String.fromEnvironment('GEMINI_API_KEY'),
        model = model ?? const String.fromEnvironment('GEMINI_MODEL'),
        _configStore = configStore ?? const FileAiConfigStore(),
        _httpPost = httpPost ?? _defaultGeminiHttpPost;

  final String apiKey;
  final String model;
  final FileAiConfigStore _configStore;
  final GeminiDeliveryPlanHttpPost _httpPost;

  @override
  Future<DeliveryPlanOcrDraft> recognize(
    File image, {
    DeliveryPlanOcrProgressCallback? onProgress,
  }) async {
    onProgress?.call('正在上传交货计划截图...');
    final needsConfig = apiKey.trim().isEmpty;
    final config = needsConfig ? await _configStore.load() : null;
    final effectiveApiKey = apiKey.trim().isNotEmpty
        ? apiKey.trim()
        : config?.geminiApiKey.trim() ?? '';
    final effectiveModel = model.trim().isNotEmpty
        ? model.trim()
        : config?.geminiModel.trim().isNotEmpty == true
            ? config!.geminiModel.trim()
            : AiOcrConfig.defaultModel;
    if (effectiveApiKey.isEmpty) {
      throw const DeliveryPlanOcrException('缺少 GEMINI_API_KEY');
    }
    final bytes = await image.readAsBytes();
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$effectiveModel:generateContent',
    ).replace(queryParameters: {'key': effectiveApiKey});
    final responseText = await _httpPost(uri, _geminiRequestBody(bytes));
    onProgress?.call('正在整理交货计划识别结果...');
    return _parseGeminiResponse(responseText);
  }
}

class ModelScopeDeliveryPlanOcrService implements DeliveryPlanPhotoOcrService {
  ModelScopeDeliveryPlanOcrService({
    String? apiKey,
    String? model,
    FileAiConfigStore? configStore,
    ModelScopeDeliveryPlanHttpPost? httpPost,
  })  : apiKey = apiKey ?? const String.fromEnvironment('MODELSCOPE_TOKEN'),
        model = model ?? const String.fromEnvironment('MODELSCOPE_MODEL'),
        _configStore = configStore ?? const FileAiConfigStore(),
        _httpPost = httpPost ?? _defaultModelScopeHttpPost;

  static const _completionUrl =
      'https://api-inference.modelscope.cn/v1/chat/completions';

  final String apiKey;
  final String model;
  final FileAiConfigStore _configStore;
  final ModelScopeDeliveryPlanHttpPost _httpPost;

  @override
  Future<DeliveryPlanOcrDraft> recognize(
    File image, {
    DeliveryPlanOcrProgressCallback? onProgress,
  }) async {
    onProgress?.call('正在上传交货计划截图...');
    final config = await _configStore.load();
    final effectiveApiKey = apiKey.trim().isNotEmpty
        ? apiKey.trim()
        : config.modelscopeToken.trim();
    final effectiveModel = model.trim().isNotEmpty
        ? model.trim()
        : config.modelscopeModel.trim().isNotEmpty
            ? config.modelscopeModel.trim()
            : AiOcrConfig.defaultModelScopeModel;
    if (effectiveApiKey.isEmpty) {
      throw const DeliveryPlanOcrException('缺少魔搭 API KEY');
    }
    final bytes = await image.readAsBytes();
    final body = {
      'model': effectiveModel,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': _deliveryPlanPrompt,
            },
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,${base64Encode(bytes)}',
              },
            },
          ],
        },
      ],
      'response_format': {'type': 'json_object'},
      'temperature': 0.0,
    };
    final responseText = await _httpPost(
      Uri.parse(_completionUrl),
      body,
      _normalizeApiKey(effectiveApiKey),
    );
    onProgress?.call('正在整理交货计划识别结果...');
    return _parseModelScopeResponse(responseText);
  }
}

class DeliveryPlanOcrException implements Exception {
  const DeliveryPlanOcrException(this.message);

  final String message;

  @override
  String toString() => message;
}

Map<String, Object?> _geminiRequestBody(List<int> imageBytes) {
  return {
    'contents': [
      {
        'role': 'user',
        'parts': [
          {'text': _deliveryPlanPrompt},
          {
            'inlineData': {
              'mimeType': 'image/jpeg',
              'data': base64Encode(imageBytes),
            },
          },
        ],
      },
    ],
    'generationConfig': {
      'responseMimeType': 'application/json',
      'responseSchema': _deliveryPlanResponseSchema,
    },
  };
}

DeliveryPlanOcrDraft _parseGeminiResponse(String responseText) {
  final decoded = jsonDecode(responseText);
  if (decoded is! Map<String, Object?>) {
    throw const DeliveryPlanOcrException('Gemini 返回格式无效');
  }
  final candidates = decoded['candidates'];
  if (candidates is! List || candidates.isEmpty) {
    throw const DeliveryPlanOcrException('Gemini 未返回识别结果');
  }
  final first = candidates.first;
  if (first is! Map) {
    throw const DeliveryPlanOcrException('Gemini 返回候选格式无效');
  }
  final content = first['content'];
  if (content is! Map) {
    throw const DeliveryPlanOcrException('Gemini 返回内容为空');
  }
  final parts = content['parts'];
  if (parts is! List || parts.isEmpty) {
    throw const DeliveryPlanOcrException('Gemini 返回文本为空');
  }
  final text = parts
      .whereType<Map>()
      .map((part) => part['text'])
      .whereType<String>()
      .join()
      .trim();
  if (text.isEmpty) {
    throw const DeliveryPlanOcrException('Gemini 返回文本为空');
  }
  return _parseDraftPayload(text);
}

DeliveryPlanOcrDraft _parseModelScopeResponse(String responseText) {
  final decoded = jsonDecode(responseText);
  if (decoded is! Map<String, Object?>) {
    throw const DeliveryPlanOcrException('魔搭返回格式无效');
  }
  final choices = decoded['choices'];
  if (choices is! List || choices.isEmpty) {
    throw const DeliveryPlanOcrException('魔搭未返回识别结果');
  }
  final first = choices.first;
  if (first is! Map) {
    throw const DeliveryPlanOcrException('魔搭返回内容无效');
  }
  final message = first['message'];
  if (message is! Map) {
    throw const DeliveryPlanOcrException('魔搭返回内容为空');
  }
  final content = message['content']?.toString().trim() ?? '';
  if (content.isEmpty) {
    throw const DeliveryPlanOcrException('魔搭返回文本为空');
  }
  return _parseDraftPayload(content);
}

DeliveryPlanOcrDraft _parseDraftPayload(String text) {
  final payload = jsonDecode(text);
  if (payload is! Map<String, Object?>) {
    throw const DeliveryPlanOcrException('交货计划 OCR JSON 格式无效');
  }
  return DeliveryPlanOcrDraft.fromJson(payload);
}

Future<String> _defaultGeminiHttpPost(
  Uri uri,
  Map<String, Object?> body,
) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close();
    final responseText = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DeliveryPlanOcrException(
        'Gemini 请求失败：${response.statusCode} ${responseText.trim()}',
      );
    }
    return responseText;
  } finally {
    client.close(force: true);
  }
}

Future<String> _defaultModelScopeHttpPost(
  Uri uri,
  Map<String, Object?> body,
  String token,
) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.write(jsonEncode(body));
    final response = await request.close();
    final responseText = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DeliveryPlanOcrException(
        '魔搭请求失败：${response.statusCode} ${responseText.trim()}',
      );
    }
    return responseText;
  } finally {
    client.close(force: true);
  }
}

String _normalizeApiKey(String raw) {
  final value = raw.trim();
  if (value.toLowerCase().startsWith('bearer ')) {
    return value.substring(7).trim();
  }
  return value;
}

const _deliveryPlanPrompt = '''
你只做OCR和表格字段抽取，不要推理，不要补全，不要改写业务含义。
请识别这张“交货计划/库存计划”截图中的表格，返回JSON。
如果图片方向旋转，请先按文字方向阅读。

只提取表格明细行，返回字段：
- productCode: 物料号，只保留数字字符
- productName: 物料名称
- actualBatch: 批次/实际批号，优先读取英数串
- dateBatch: 货架寿命到期日/截止日期/日期批号
- stockTotalBoxes: “在库总箱数”列的整数
- deliveryPlanAvailableBoxes: “减交货计划可用量箱数”列的整数
- warnings: 读不清或列缺失时，用中文简短说明

不要把订单、交货计划件数、非限制库存件数当作 stockTotalBoxes。
不要根据件数、包装规格、金额、重量推算箱数。
本地程序会计算：可能备货箱数 = 在库总箱数 - 减交货计划可用量箱数。
如果某行这两个箱数字段读不到，填0并在warnings说明。
返回 JSON 对象，字段必须包含 rows 和 warnings。
''';

const _deliveryPlanResponseSchema = {
  'type': 'object',
  'properties': {
    'warnings': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'rows': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'productCode': {'type': 'string'},
          'productName': {'type': 'string'},
          'actualBatch': {'type': 'string'},
          'dateBatch': {'type': 'string'},
          'stockTotalBoxes': {'type': 'integer'},
          'deliveryPlanAvailableBoxes': {'type': 'integer'},
        },
        'required': [
          'productCode',
          'productName',
          'actualBatch',
          'dateBatch',
          'stockTotalBoxes',
          'deliveryPlanAvailableBoxes',
        ],
      },
    },
  },
  'required': ['rows', 'warnings'],
};
