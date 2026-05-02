import 'dart:convert';
import 'dart:io';

import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_photo_ocr_service.dart';

typedef ModelScopeHttpPost = Future<String> Function(
  Uri uri,
  Map<String, Object?> body,
  String token,
);
class ModelScopeRateLimitInfo {
  const ModelScopeRateLimitInfo({
    required this.statusCode,
    required this.headers,
    this.retryAfter,
  });

  final int statusCode;
  final Map<String, String> headers;
  final String? retryAfter;

  String? get remaining {
    return headers['x-ratelimit-remaining'] ??
        headers['ratelimit-remaining'] ??
        headers['x-ratelimit-remaining-requests'];
  }

  String summaryText() {
    final parts = <String>[];
    if (remaining != null && remaining!.trim().isNotEmpty) {
      parts.add('剩余次数: ${remaining!.trim()}');
    }
    final retry = retryAfter?.trim() ?? '';
    if (retry.isNotEmpty) {
      parts.add('建议等待: ${retry}s');
    }
    if (parts.isEmpty) {
      return '魔搭限流信息未返回';
    }
    return '魔搭限流 ${parts.join('，')}';
  }
}

class ModelScopeWaybillOcrService implements WaybillPhotoOcrService {
  ModelScopeWaybillOcrService({
    String? apiKey,
    String? model,
    FileAiConfigStore? configStore,
    ModelScopeHttpPost? httpPost,
  })  : apiKey = apiKey ?? const String.fromEnvironment('MODELSCOPE_TOKEN'),
        model = model ?? const String.fromEnvironment('MODELSCOPE_MODEL'),
        _configStore = configStore ?? const FileAiConfigStore(),
        _httpPost = httpPost ?? _defaultHttpPost;

  final String apiKey;
  final String model;
  final FileAiConfigStore _configStore;
  final ModelScopeHttpPost _httpPost;
  static ModelScopeRateLimitInfo? _lastRateLimitInfo;
  static const _defaultCompletionUrl =
      'https://api-inference.modelscope.cn/v1/chat/completions';
  static const _qianfanOcrModel = 'baidu-qianfan/Qianfan-OCR';
  static const _qianfanOcrCompletionUrl =
      'https://ms-ens-9fc2bf8e-b006.api-inference.modelscope.cn/v1/chat/completions';

  static ModelScopeRateLimitInfo? get lastRateLimitInfo => _lastRateLimitInfo;

  @override
  Future<WaybillOcrDraft> recognize(File image) async {
    final config = await _configStore.load();
    final effectiveApiKey = apiKey.trim().isNotEmpty
        ? apiKey.trim()
        : config.modelscopeToken.trim();
    final normalizedApiKey = _normalizeApiKey(effectiveApiKey);
    final effectiveModel = model.trim().isNotEmpty
        ? model.trim()
        : config.modelscopeModel.trim().isNotEmpty
            ? config.modelscopeModel.trim()
            : AiOcrConfig.defaultModelScopeModel;
    final promptPreset = config.ocrPromptPreset;
    if (normalizedApiKey.isEmpty) {
      throw const ModelScopeWaybillOcrException('缺少魔搭 API KEY');
    }

    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);
    final uri = _completionUriForModel(effectiveModel);
    final body = {
      'model': effectiveModel,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': _promptByPreset(promptPreset),
            },
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
            },
          ],
        },
      ],
      'response_format': {'type': 'json_object'},
      'temperature': 0.0,
    };

    final responseText = await _httpPost(uri, body, normalizedApiKey);
    return _parseResponse(responseText);
  }

  Uri _completionUriForModel(String modelId) {
    if (modelId.trim() == _qianfanOcrModel) {
      return Uri.parse(_qianfanOcrCompletionUrl);
    }
    return Uri.parse(_defaultCompletionUrl);
  }

  WaybillOcrDraft _parseResponse(String responseText) {
    final decoded = jsonDecode(responseText);
    if (decoded is! Map<String, Object?>) {
      throw const ModelScopeWaybillOcrException('魔搭返回格式无效');
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const ModelScopeWaybillOcrException('魔搭未返回识别结果');
    }
    final first = choices.first;
    if (first is! Map) {
      throw const ModelScopeWaybillOcrException('魔搭返回内容无效');
    }
    final message = first['message'];
    if (message is! Map) {
      throw const ModelScopeWaybillOcrException('魔搭返回内容为空');
    }
    final content = message['content']?.toString().trim() ?? '';
    if (content.isEmpty) {
      throw const ModelScopeWaybillOcrException('魔搭返回文本为空');
    }

    final payload = jsonDecode(content);
    if (payload is! Map<String, Object?>) {
      throw const ModelScopeWaybillOcrException('OCR JSON 格式无效');
    }
    return WaybillOcrDraft.fromJson(payload);
  }
}

class ModelScopeWaybillOcrException implements Exception {
  const ModelScopeWaybillOcrException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<String> _defaultHttpPost(
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
    final headers = <String, String>{};
    response.headers.forEach((name, values) {
      if (values.isNotEmpty) {
        headers[name.toLowerCase()] = values.join(', ');
      }
    });
    ModelScopeWaybillOcrService._lastRateLimitInfo = ModelScopeRateLimitInfo(
      statusCode: response.statusCode,
      headers: headers,
      retryAfter: response.headers.value('retry-after'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ModelScopeWaybillOcrException(
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

String _promptByPreset(String preset) {
  if (preset == AiOcrConfig.ocrPromptPresetGeneral) {
    return _ocrPromptGeneral;
  }
  return _ocrPromptWaybillTemplateV2;
}

const _ocrPromptGeneral = '''
你只做OCR和模板字段抽取，不要推理，不要补全，不要判断业务含义。
请从这张发货单照片中读取看得见的文字和表格单元格，返回JSON。
如果图片方向旋转，请先按文字方向阅读。
只提取：
- waybillNo: 右上区域的运单号/通单号
- merchantName: 客户/收货方/经销商相关名称，读不到则空字符串
- orderDate: 单据日期，读不到则空字符串
- rows: 表格每一行的 productCode、productName、actualBatch、dateBatch、boxes
箱数只读取表格中的箱数/数量列，不要根据金额或重量换算。
不同实际批号必须作为不同原始行输出。
读不清的字段返回空字符串或0，并在warnings用中文写原因。
返回 JSON 对象，字段必须包含：
waybillNo, merchantName, orderDate, rows, warnings。
''';

const _ocrPromptWaybillTemplateV2 = '''
你只做OCR和模板字段抽取，不要推理，不要补全，不要判断业务含义。
请优先按“标准发货单模板”读取：右上运单号，页头客户信息区，主明细表格。
如果图片方向旋转，请先按文字方向阅读。
只提取并返回JSON字段：
- waybillNo: 右上区域“运单号”
- merchantName: 优先取“收货方”，没有则取“客户/经销商/售达方”
- orderDate: 优先取“起运日”，没有则取单据日期
- rows: 明细表每一行的 productCode、productName、actualBatch、dateBatch、boxes
列映射固定为：
- productCode <- 产品码
- productName <- 产品名称
- actualBatch <- 批号
- dateBatch <- 截止日期
- boxes <- 箱数（不要读零数、重量、体积、价税）
规则：
- productCode 仅保留数字字符；读不清则空字符串
- actualBatch 优先识别英数串，注意 O/0、I/1；不确定则空字符串
- 不同实际批号必须作为不同原始行输出，不要合并
- 读不清的字段返回空字符串或0，并在warnings用中文写原因
返回 JSON 对象，字段必须包含：
waybillNo, merchantName, orderDate, rows, warnings。
''';
