import 'dart:convert';
import 'dart:io';

import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';
import 'package:qrscan_flutter/features/orders/ocr/merchant_name_matcher.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_diagnostics.dart';
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
  Future<WaybillOcrDraft> recognize(
    File image, {
    Iterable<String> merchantHistoryNames = const [],
    WaybillOcrProgressCallback? onProgress,
  }) async {
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
    return _parseResponse(responseText, merchantHistoryNames);
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

  WaybillOcrDraft _parseResponse(
    String responseText,
    Iterable<String> merchantHistoryNames,
  ) {
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
    final draft = applyMerchantHistoryMatch(
      WaybillOcrDraft.fromJson(payload),
      merchantHistoryNames,
    );
    logOcrMerchantDiagnosis(provider: 'gemini', draft: draft);
    return draft;
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
      final compactBody = responseText.replaceAll(RegExp(r'\s+'), ' ').trim();
      final snippet = compactBody.length > 800
          ? '${compactBody.substring(0, 800)}...'
          : compactBody;
      throw GeminiWaybillOcrException(
        'Gemini 请求失败：${response.statusCode}，响应：$snippet',
      );
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
- rawMerchantName: 优先读取左上信息区“收货方：”后面的公司全称；可去掉括号内数字编码；不要简称；读不到则空字符串
- merchantName: 从rawMerchantName提取收货方业务短称；不要用承运方、售达方、托运方、发货方、发货仓、收货地址、收货方联系人、底部收货人推断商家；读不到则空字符串
- rows: 按“产品码+批号+截止日期”分组聚合后的 productCode、productName、actualBatch、dateBatch、boxes
- totalBoxes: 表格底部“页小计/总计”行中“箱数”列的整数；读不到则0
waybillNo 只保留数字字符；业务值一般是7位纯数字。请先逐字符读取右上区域“运单号/通单号”后的候选号码；如果有空格、横线、冒号等分隔符，去掉分隔符后返回数字。不要因为位数异常就直接清空：如果候选号码清晰可见但不是7位，仍然返回该候选号码，并在warnings写“运单号疑似识别异常，请复核”；如果候选中有看不清的字符，返回能确定的数字部分，并在warnings写“运单号有模糊字符，请复核”。只有当右上区域完全看不清、被裁切或找不到运单号字段时，waybillNo 才返回空字符串。不要从产品码、客户编码、电话号码、日期、金额、箱数中猜测运单号。
箱数只读取表格中的箱数/数量列，不要根据金额或重量换算。
同一产品码+批号+截止日期出现多行时，把箱数累加成一行；不同实际批号或不同截止日期必须分开输出。
返回前必须计算 rows 中 boxes 的合计，并与 totalBoxes 对比；如果 totalBoxes>0 且不一致，在warnings写“明细箱数合计X箱，与图片总计Y箱不一致”。
merchantName规则：行政区划前缀一律删除（省/市/县/区/镇/乡/街道等地区名称只作为前缀时不要放进merchantName）；括号内数字编码、从“二级”开始的后续门店说明不要放进merchantName；日用品/日用品商行可归一为日用。
商家简称示例：义乌市杜超日化有限公司 -> 杜超日化；湖州鑫唐贸易有限公司二级... -> 鑫唐贸易；金华市曦鑫商贸有限公司 -> 曦鑫商贸；浙江省义乌市名人贸易发展有限公司 -> 名人贸易；龙游华凯日用品商行（个体工商户） -> 华凯日用；宁波市宝敏瑞贸易有限公司 -> 宝敏瑞贸易。
读不清的字段返回空字符串或0，并在warnings用中文写原因。
''';

const _ocrPromptWaybillTemplateV2 = '''
你只做OCR和模板字段抽取，不要推理，不要补全，不要判断业务含义。
请优先按“标准发货单模板”读取：右上运单号，页头客户信息区，主明细表格。
如果图片方向旋转，请先按文字方向阅读。
只提取并返回JSON字段：
- waybillNo: 右上区域“运单号”
- rawMerchantName: 左上信息区“收货方：”后面的公司全称；可去掉括号内数字编码；不要简称；读不到则空字符串
- merchantName: 优先取“收货方”的业务短称，没有则取“客户/经销商/售达方”中的业务短称
- rows: 明细表按“产品码+批号+截止日期”分组聚合后的 productCode、productName、actualBatch、dateBatch、boxes
- totalBoxes: 明细表底部“页小计/总计”行中“箱数”列的整数；如果同时有页小计和总计，取“总计”；读不到则0
列映射固定为：
- productCode <- 产品码
- productName <- 产品名称
- actualBatch <- 批号
- dateBatch <- 截止日期
- boxes <- 箱数（不要读零数、重量、体积、价税）
规则：
- waybillNo 只保留数字字符；业务值一般是7位纯数字。请先逐字符读取右上区域“运单号”后的候选号码；如果有空格、横线、冒号等分隔符，去掉分隔符后返回数字。不要因为位数异常就直接清空：如果候选号码清晰可见但不是7位，仍然返回该候选号码，并在warnings写“运单号疑似识别异常，请复核”；如果候选中有看不清的字符，返回能确定的数字部分，并在warnings写“运单号有模糊字符，请复核”。只有当右上区域完全看不清、被裁切或找不到运单号字段时，waybillNo 才返回空字符串。不要从产品码、客户编码、电话号码、日期、金额、箱数中猜测运单号
- productCode 仅保留数字字符；读不清则空字符串
- actualBatch 优先识别英数串，注意 O/0、I/1；不确定则空字符串
- 同一产品码+批号+截止日期出现多行时，把箱数累加成一行；不同实际批号或不同截止日期必须分开输出，不要合并
- 返回前必须计算 rows 中 boxes 的合计，并与 totalBoxes 对比；如果 totalBoxes>0 且不一致，在warnings写“明细箱数合计X箱，与图片总计Y箱不一致”
- merchantName 提取规则（仅通过语义，不要机械截断）：
  - 对此类电子原图，商家在左上信息区，通常位于“发货地址：”下一行、“收货方联系人：”上一行；只以“收货方：”后面的公司名称为准
  - 不要把承运方、售达方、托运方、发货方、发货仓、收货地址、收货方联系人、底部收货人当作merchantName
  - 如果是公司全称，提取最稳定、最常用的业务短称；括号内数字编码、从“二级”开始的后续门店说明不要放进merchantName
  - 行政区划前缀一律删除：省/市/县/区/镇/乡/街道等地区名称只作为前缀时，不要放进 merchantName
  - 优先保留这些词：商贸、贸易、日用、化妆、供应链、百货、集团、经贸、物流、仓
  - “日用品/日用品商行”可归一为“日用”；“贸易发展有限公司”提取为“贸易”
  - 当命中上述关键词时，关键词前通常只保留2-3个核心字（例如“恒盛日化”“嘉源商贸”）
  - 当前模板商家简称示例：杜超日化、鑫唐贸易、曦鑫商贸、名人贸易、华凯日用、宝敏瑞贸易
  - 支持“十足”系列短称：十足、十足台州、十足诸暨（仅当这些词直接出现在收货方字段时）
  - 不要为了某个城市或地区写特殊规则，按“行政区划前缀删除 + 保留业务短称核心词”的通用规则处理
- 读不清的字段返回空字符串或0，并在warnings用中文写原因
''';

const _responseSchema = {
  'type': 'object',
  'properties': {
    'waybillNo': {'type': 'string'},
    'rawMerchantName': {'type': 'string'},
    'merchantName': {'type': 'string'},
    'totalBoxes': {'type': 'integer'},
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
    'rawMerchantName',
    'merchantName',
    'totalBoxes',
    'rows',
    'warnings',
  ],
};
