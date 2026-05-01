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

  @override
  Future<WaybillOcrDraft> recognize(File image) async {
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
      throw const ModelScopeWaybillOcrException('缺少魔搭 API KEY');
    }

    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);
    final uri = Uri.parse('https://api-inference.modelscope.cn/v1/chat/completions');
    final body = {
      'model': effectiveModel,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': _ocrPrompt,
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

    final responseText = await _httpPost(uri, body, effectiveApiKey);
    return _parseResponse(responseText);
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
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ModelScopeWaybillOcrException('魔搭请求失败：${response.statusCode}');
    }
    return responseText;
  } finally {
    client.close(force: true);
  }
}

const _ocrPrompt = '''
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
