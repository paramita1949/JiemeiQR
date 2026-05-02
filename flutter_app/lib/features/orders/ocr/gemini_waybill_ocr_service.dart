import 'dart:convert';
import 'dart:io';

import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_photo_ocr_service.dart';

typedef GeminiHttpPost = Future<String> Function(
  Uri uri,
  Map<String, Object?> body,
);

class GeminiWaybillOcrService implements WaybillPhotoOcrService {
  GeminiWaybillOcrService({
    String? apiKey,
    String? model,
    FileAiConfigStore? configStore,
    GeminiHttpPost? httpPost,
  })  : apiKey = apiKey ?? const String.fromEnvironment('GEMINI_API_KEY'),
        model = model ?? const String.fromEnvironment('GEMINI_MODEL'),
        _configStore = configStore ?? const FileAiConfigStore(),
        _httpPost = httpPost ?? _defaultHttpPost;

  final String apiKey;
  final String model;
  final FileAiConfigStore _configStore;
  final GeminiHttpPost _httpPost;

  @override
  Future<WaybillOcrDraft> recognize(File image) async {
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
    final promptPreset =
        config?.ocrPromptPreset ?? AiOcrConfig.defaultOcrPromptPreset;
    if (effectiveApiKey.isEmpty) {
      throw const GeminiWaybillOcrException('缺少 GEMINI_API_KEY');
    }
    final bytes = await image.readAsBytes();
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$effectiveModel:generateContent',
    ).replace(queryParameters: {'key': effectiveApiKey});
    final responseText =
        await _httpPost(uri, _requestBody(bytes, promptPreset));
    return _parseResponse(responseText);
  }

  Map<String, Object?> _requestBody(List<int> imageBytes, String promptPreset) {
    final prompt = promptPreset == AiOcrConfig.ocrPromptPresetGeneral
        ? _ocrPromptGeneral
        : _ocrPromptWaybillTemplateV2;
    return {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text': prompt,
            },
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
        'responseSchema': _responseSchema,
      },
    };
  }

  WaybillOcrDraft _parseResponse(String responseText) {
    final decoded = jsonDecode(responseText);
    if (decoded is! Map<String, Object?>) {
      throw const GeminiWaybillOcrException('Gemini 返回格式无效');
    }
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const GeminiWaybillOcrException('Gemini 未返回识别结果');
    }
    final first = candidates.first;
    if (first is! Map) {
      throw const GeminiWaybillOcrException('Gemini 返回候选格式无效');
    }
    final content = first['content'];
    if (content is! Map) {
      throw const GeminiWaybillOcrException('Gemini 返回内容为空');
    }
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      throw const GeminiWaybillOcrException('Gemini 返回文本为空');
    }
    final text = parts
        .whereType<Map>()
        .map((part) => part['text'])
        .whereType<String>()
        .join()
        .trim();
    if (text.isEmpty) {
      throw const GeminiWaybillOcrException('Gemini 返回文本为空');
    }
    final payload = jsonDecode(text);
    if (payload is! Map<String, Object?>) {
      throw const GeminiWaybillOcrException('OCR JSON 格式无效');
    }
    return WaybillOcrDraft.fromJson(payload);
  }
}

class GeminiWaybillOcrException implements Exception {
  const GeminiWaybillOcrException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<String> _defaultHttpPost(Uri uri, Map<String, Object?> body) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close();
    final responseText = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GeminiWaybillOcrException('Gemini 请求失败：${response.statusCode}');
    }
    return responseText;
  } finally {
    client.close(force: true);
  }
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
''';

const _responseSchema = {
  'type': 'object',
  'properties': {
    'waybillNo': {'type': 'string'},
    'merchantName': {'type': 'string'},
    'orderDate': {'type': 'string'},
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
          'boxes': {'type': 'integer'},
        },
        'required': [
          'productCode',
          'productName',
          'actualBatch',
          'dateBatch',
          'boxes',
        ],
      },
    },
  },
  'required': [
    'waybillNo',
    'merchantName',
    'orderDate',
    'rows',
    'warnings',
  ],
};
