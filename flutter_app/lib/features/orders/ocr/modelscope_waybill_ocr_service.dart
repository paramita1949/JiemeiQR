import 'dart:convert';
import 'dart:io';

import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';
import 'package:qrscan_flutter/features/orders/ocr/merchant_name_matcher.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_diagnostics.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_photo_ocr_service.dart';
import 'package:qrscan_flutter/shared/camera/ai_ocr_image_preparer.dart';
import 'package:qrscan_flutter/shared/utils/debug_event_log.dart';

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

  String? summaryText() {
    final parts = <String>[];
    if (remaining != null && remaining!.trim().isNotEmpty) {
      parts.add('剩余次数: ${remaining!.trim()}');
    }
    final retry = retryAfter?.trim() ?? '';
    if (retry.isNotEmpty) {
      parts.add('建议等待: ${retry}s');
    }
    if (parts.isEmpty) {
      return null;
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
    AiOcrImagePreparer? imagePreparer,
  })  : apiKey = apiKey ?? const String.fromEnvironment('MODELSCOPE_TOKEN'),
        model = model ?? const String.fromEnvironment('MODELSCOPE_MODEL'),
        _configStore = configStore ?? const FileAiConfigStore(),
        _httpPost = httpPost ?? _defaultHttpPost,
        _imagePreparer = imagePreparer ??
            const AiOcrImagePreparer(
              maxLongEdge: 2048,
              targetLongEdges: [2048, 1792, 1536],
            );

  final String apiKey;
  final String model;
  final FileAiConfigStore _configStore;
  final ModelScopeHttpPost _httpPost;
  final AiOcrImagePreparer _imagePreparer;
  static ModelScopeRateLimitInfo? _lastRateLimitInfo;
  static const _completionUrl =
      'https://api-inference.modelscope.cn/v1/chat/completions';

  static ModelScopeRateLimitInfo? get lastRateLimitInfo => _lastRateLimitInfo;

  @override
  Future<WaybillOcrDraft> recognize(
    File image, {
    Iterable<String> merchantHistoryNames = const [],
    WaybillOcrProgressCallback? onProgress,
  }) async {
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
    final modelAttempts = _modelAttempts(
      effectiveModel,
      config.modelScopeModelPresets,
    );
    final promptPreset = config.ocrPromptPreset;
    if (normalizedApiKey.isEmpty) {
      throw const ModelScopeWaybillOcrException('缺少魔搭 API KEY');
    }

    final prepared = await _imagePreparer.prepare(image);
    try {
      return await _recognizePrepared(
        prepared.file,
        normalizedApiKey: normalizedApiKey,
        modelAttempts: modelAttempts,
        promptPreset: promptPreset,
        merchantHistoryNames: merchantHistoryNames,
      );
    } finally {
      await prepared.dispose();
    }
  }

  Future<WaybillOcrDraft> _recognizePrepared(
    File image, {
    required String normalizedApiKey,
    required List<String> modelAttempts,
    required String promptPreset,
    required Iterable<String> merchantHistoryNames,
  }) async {
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);
    final uri = Uri.parse(_completionUrl);
    final primaryPrompt = _promptByPreset(promptPreset);
    const fallbackPrompt = _ocrPromptGeneral;
    final promptAttempts = <String>[
      primaryPrompt,
      primaryPrompt,
      fallbackPrompt,
    ];
    ModelScopeWaybillOcrException? lastError;
    for (var modelIndex = 0; modelIndex < modelAttempts.length; modelIndex++) {
      final currentModel = modelAttempts[modelIndex];
      final attemptsForModel =
          modelIndex == 0 ? promptAttempts : <String>[primaryPrompt];
      for (var i = 0; i < attemptsForModel.length; i += 1) {
        final body = _buildBody(
          model: currentModel,
          prompt: attemptsForModel[i],
          base64Image: base64Image,
        );
        try {
          final responseText = await _httpPost(uri, body, normalizedApiKey);
          final draft = _parseResponse(responseText, merchantHistoryNames);
          if (_isRecognizedDraftEmpty(draft)) {
            lastError = ModelScopeWaybillOcrException(
              '魔搭返回空结果（第${i + 1}次）',
            );
            continue;
          }
          return draft;
        } on ModelScopeWaybillOcrException catch (error) {
          lastError = error;
          if (_isRateLimitError(error.message) &&
              modelIndex < modelAttempts.length - 1) {
            DebugEventLog.add(
              'AI_OCR',
              'fallback modelscope_429 model=$currentModel next=${modelAttempts[modelIndex + 1]}',
            );
            break;
          }
          if (_isRetryableEmptyError(error.message) &&
              i < attemptsForModel.length - 1) {
            continue;
          }
          rethrow;
        }
      }
    }
    throw ModelScopeWaybillOcrException(
      '未识别到任何内容。可能原因：图片模糊/反光/倾斜、文字过小，或模型当次返回为空。'
      '建议：重拍更清晰正面照片后重试。'
      '${lastError == null ? '' : '（最后一次：${lastError.message}）'}',
    );
  }

  Map<String, Object?> _buildBody({
    required String model,
    required String prompt,
    required String base64Image,
  }) {
    return {
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': prompt,
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
  }

  WaybillOcrDraft _parseResponse(
    String responseText,
    Iterable<String> merchantHistoryNames,
  ) {
    final decoded = jsonDecode(responseText);
    if (decoded is! Map<String, Object?>) {
      throw const ModelScopeWaybillOcrException('魔搭返回格式无效');
    }
    final responseError = _responseErrorMessage(decoded);
    if (responseError != null) {
      throw ModelScopeWaybillOcrException(responseError);
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
    final draft = applyMerchantHistoryMatch(
      WaybillOcrDraft.fromJson(payload),
      merchantHistoryNames,
    );
    logOcrMerchantDiagnosis(provider: 'modelscope', draft: draft);
    return draft;
  }
}

String? _responseErrorMessage(Map<String, Object?> decoded) {
  final error = decoded['error'];
  if (error is! Map) {
    return null;
  }
  final code = error['http_code']?.toString().trim() ??
      error['code']?.toString().trim() ??
      '';
  final message = error['message']?.toString().trim() ?? '';
  final type = error['type']?.toString().trim() ?? '';
  final requestId = decoded['request_id']?.toString().trim() ?? '';
  final isInsufficientBalance = code == '402' ||
      type.contains('insufficient_balance') ||
      message.contains('insufficient balance');
  final title = isInsufficientBalance
      ? '魔搭余额不足或额度不足（402）'
      : code.isEmpty
          ? '魔搭请求失败'
          : '魔搭请求失败（$code）';
  final details = <String>[
    if (message.isNotEmpty) message,
    if (type.isNotEmpty) type,
    if (requestId.isNotEmpty) 'request_id=$requestId',
  ];
  return details.isEmpty ? title : '$title：${details.join('；')}';
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
      final retryAfter = response.headers.value('retry-after');
      if (response.statusCode == 429) {
        final waitHint = retryAfter == null || retryAfter.trim().isEmpty
            ? '请稍后再试'
            : '建议等待 ${retryAfter.trim()} 秒后重试';
        throw ModelScopeWaybillOcrException(
          '魔搭触发限流（429）：常见原因是免费额度/并发限制。$waitHint',
        );
      }
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

bool _isRecognizedDraftEmpty(WaybillOcrDraft draft) {
  final hasHeader =
      draft.waybillNo.trim().isNotEmpty || draft.merchantName.trim().isNotEmpty;
  final hasRows = draft.rows.any((row) => row.hasContent && row.boxes > 0);
  return !hasHeader && !hasRows;
}

bool _isRetryableEmptyError(String message) {
  return message.contains('未返回识别结果') ||
      message.contains('返回内容为空') ||
      message.contains('返回文本为空') ||
      message.contains('返回空结果');
}

bool _isRateLimitError(String message) {
  return message.contains('429') || message.contains('限流');
}

List<String> _modelAttempts(String primary, List<String> presets) {
  final values = <String>[
    primary.trim(),
    ...presets.map((item) => item.trim()),
  ].where((item) => item.isNotEmpty).toSet().toList();
  if (values.isEmpty) {
    return [AiOcrConfig.defaultModelScopeModel];
  }
  return values.take(2).toList();
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
返回 JSON 对象，字段必须包含：
waybillNo, rawMerchantName, merchantName, totalBoxes, rows, warnings。
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
返回 JSON 对象，字段必须包含：
waybillNo, rawMerchantName, merchantName, totalBoxes, rows, warnings。
''';
