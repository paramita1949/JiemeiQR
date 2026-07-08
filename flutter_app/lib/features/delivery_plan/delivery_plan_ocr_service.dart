import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
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

typedef DeliveryPlanOcrServiceFactory = DeliveryPlanPhotoOcrService Function(
  FileAiConfigStore configStore,
);

typedef PaddleDeliveryPlanSubmitJob = Future<String> Function({
  required File image,
  required String token,
  required String model,
  required Map<String, Object?> optionalPayload,
});

typedef PaddleDeliveryPlanGetJob = Future<Map<String, Object?>> Function({
  required String jobId,
  required String token,
});

typedef PaddleDeliveryPlanDownloadResult = Future<String> Function(Uri uri);

class ConfiguredDeliveryPlanOcrService implements DeliveryPlanPhotoOcrService {
  const ConfiguredDeliveryPlanOcrService({
    this.configStore = const FileAiConfigStore(),
    DeliveryPlanOcrServiceFactory? geminiServiceFactory,
    DeliveryPlanOcrServiceFactory? modelScopeServiceFactory,
    DeliveryPlanOcrServiceFactory? paddleOcrServiceFactory,
  })  : _geminiServiceFactory =
            geminiServiceFactory ?? _defaultGeminiServiceFactory,
        _modelScopeServiceFactory =
            modelScopeServiceFactory ?? _defaultModelScopeServiceFactory,
        _paddleOcrServiceFactory =
            paddleOcrServiceFactory ?? _defaultPaddleOcrServiceFactory;

  static DeliveryPlanPhotoOcrService _defaultGeminiServiceFactory(
    FileAiConfigStore configStore,
  ) {
    return GeminiDeliveryPlanOcrService(configStore: configStore);
  }

  static DeliveryPlanPhotoOcrService _defaultModelScopeServiceFactory(
    FileAiConfigStore configStore,
  ) {
    return ModelScopeDeliveryPlanOcrService(configStore: configStore);
  }

  static DeliveryPlanPhotoOcrService _defaultPaddleOcrServiceFactory(
    FileAiConfigStore configStore,
  ) {
    return PaddleDeliveryPlanOcrService(configStore: configStore);
  }

  final FileAiConfigStore configStore;
  final DeliveryPlanOcrServiceFactory _geminiServiceFactory;
  final DeliveryPlanOcrServiceFactory _modelScopeServiceFactory;
  final DeliveryPlanOcrServiceFactory _paddleOcrServiceFactory;

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
      return _paddleOcrServiceFactory(configStore)
          .recognize(image, onProgress: onProgress);
    }
    if (config.usesModelScopeOcr) {
      return _modelScopeServiceFactory(configStore)
          .recognize(image, onProgress: onProgress);
    }
    try {
      return await _geminiServiceFactory(configStore)
          .recognize(image, onProgress: onProgress);
    } on DeliveryPlanOcrException {
      if (!config.hasModelScopeCredential) {
        rethrow;
      }
      return _modelScopeServiceFactory(configStore)
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

class PaddleDeliveryPlanOcrService implements DeliveryPlanPhotoOcrService {
  PaddleDeliveryPlanOcrService({
    String? token,
    String? model,
    FileAiConfigStore? configStore,
    PaddleDeliveryPlanSubmitJob? submitJob,
    PaddleDeliveryPlanGetJob? getJob,
    PaddleDeliveryPlanDownloadResult? downloadResult,
    Duration pollInterval = const Duration(seconds: 5),
    int maxPollAttempts = 24,
  })  : token = token ?? const String.fromEnvironment('PADDLE_OCR_TOKEN'),
        model = model ?? const String.fromEnvironment('PADDLE_OCR_MODEL'),
        _configStore = configStore ?? const FileAiConfigStore(),
        _submitJob = submitJob ?? _defaultPaddleDeliveryPlanSubmitJob,
        _getJob = getJob ?? _defaultPaddleDeliveryPlanGetJob,
        _downloadResult =
            downloadResult ?? _defaultPaddleDeliveryPlanDownloadResult,
        _pollInterval = pollInterval,
        _maxPollAttempts = maxPollAttempts;

  final String token;
  final String model;
  final FileAiConfigStore _configStore;
  final PaddleDeliveryPlanSubmitJob _submitJob;
  final PaddleDeliveryPlanGetJob _getJob;
  final PaddleDeliveryPlanDownloadResult _downloadResult;
  final Duration _pollInterval;
  final int _maxPollAttempts;

  static const _jobUrl = 'https://paddleocr.aistudio-app.com/api/v2/ocr/jobs';
  static const _optionalPayload = {
    'useDocOrientationClassify': false,
    'useDocUnwarping': false,
    'useTextlineOrientation': false,
    'prompt': _deliveryPlanPrompt,
  };

  @override
  Future<DeliveryPlanOcrDraft> recognize(
    File image, {
    DeliveryPlanOcrProgressCallback? onProgress,
  }) async {
    final needsConfig = token.trim().isEmpty || model.trim().isEmpty;
    final config = needsConfig ? await _configStore.load() : null;
    final effectiveToken = token.trim().isNotEmpty
        ? token.trim()
        : config?.paddleOcrToken.trim() ?? '';
    final effectiveModel = model.trim().isNotEmpty
        ? model.trim()
        : config?.paddleOcrModel.trim().isNotEmpty == true
            ? config!.paddleOcrModel.trim()
            : AiOcrConfig.defaultPaddleOcrModel;
    if (effectiveToken.isEmpty) {
      throw const DeliveryPlanOcrException('缺少飞桨OCR Token');
    }

    final normalizedToken = _normalizeApiKey(effectiveToken);
    final imageBytes = await image.length();
    DebugEventLog.add(
      'DELIVERY_PLAN_OCR',
      'paddleocr_submit_start model=$effectiveModel image_bytes=$imageBytes',
    );
    onProgress?.call('正在上传交货计划截图到飞桨OCR...');
    final jobId = await _submitJob(
      image: image,
      token: normalizedToken,
      model: effectiveModel,
      optionalPayload: _optionalPayload,
    );
    DebugEventLog.add(
      'DELIVERY_PLAN_OCR',
      'paddleocr_job_submitted job=$jobId model=$effectiveModel',
    );
    onProgress?.call('飞桨OCR已提交交货计划识别任务...');
    final jsonlUrl = await _waitForResultUrl(
      jobId: jobId,
      token: normalizedToken,
      onProgress: onProgress,
    );
    onProgress?.call('飞桨OCR识别完成，正在整理交货计划...');
    final jsonl = await _downloadResult(Uri.parse(jsonlUrl));
    final extracted = _extractPaddleDeliveryPlanResult(jsonl);
    if (extracted.fullText.trim().isEmpty && extracted.rows.isEmpty) {
      throw const DeliveryPlanOcrException('飞桨OCR未返回识别文本');
    }
    final warnings = <String>[
      if (extracted.rows.isEmpty) '飞桨OCR未识别到交货计划表格明细，请检查截图清晰度',
    ];
    return DeliveryPlanOcrDraft(rows: extracted.rows, warnings: warnings);
  }

  Future<String> _waitForResultUrl({
    required String jobId,
    required String token,
    DeliveryPlanOcrProgressCallback? onProgress,
  }) async {
    var lastState = '';
    var lastProgress = '';
    for (var attempt = 0; attempt < _maxPollAttempts; attempt += 1) {
      final attemptNumber = attempt + 1;
      final response = await _getJob(jobId: jobId, token: token);
      final data = _mapValue(response, 'data');
      final state = data['state']?.toString() ?? '';
      final progress = _paddleExtractProgress(data);
      lastState = state;
      lastProgress = progress;
      if (state == 'done') {
        final resultUrl = _mapValue(data, 'resultUrl');
        final jsonUrl = resultUrl['jsonUrl']?.toString().trim() ?? '';
        if (jsonUrl.isEmpty) {
          throw const DeliveryPlanOcrException(
            '飞桨OCR任务完成但未返回结果地址',
          );
        }
        DebugEventLog.add(
          'DELIVERY_PLAN_OCR',
          'paddleocr_poll job=$jobId attempt=$attemptNumber/$_maxPollAttempts state=done',
        );
        return jsonUrl;
      }
      if (state == 'failed') {
        final message = data['errorMsg']?.toString().trim();
        DebugEventLog.add(
          'DELIVERY_PLAN_OCR',
          'paddleocr_poll job=$jobId attempt=$attemptNumber/$_maxPollAttempts state=failed error=${message ?? ''}',
        );
        throw DeliveryPlanOcrException(
          message == null || message.isEmpty ? '飞桨OCR任务失败' : message,
        );
      }
      if (state != 'pending' && state != 'running') {
        throw DeliveryPlanOcrException('飞桨OCR任务状态异常: $state');
      }
      final progressMessage = _paddlePollProgressMessage(
        state: state,
        attempt: attemptNumber,
        maxAttempts: _maxPollAttempts,
        progress: progress,
      );
      onProgress?.call(progressMessage);
      DebugEventLog.add(
        'DELIVERY_PLAN_OCR',
        'paddleocr_poll job=$jobId attempt=$attemptNumber/$_maxPollAttempts state=$state${progress.isEmpty ? '' : ' progress=$progress'}',
      );
      if (_pollInterval > Duration.zero) {
        await Future<void>.delayed(_pollInterval);
      }
    }
    throw DeliveryPlanOcrException(
      '飞桨OCR任务等待超时（最后状态: ${lastState.isEmpty ? '未知' : lastState}，'
      '查询 $_maxPollAttempts/$_maxPollAttempts 次'
      '${lastProgress.isEmpty ? '' : '，进度 $lastProgress'}）',
    );
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

class _PaddleDeliveryPlanExtractedResult {
  const _PaddleDeliveryPlanExtractedResult({
    required this.lines,
    required this.rows,
  });

  final List<String> lines;
  final List<DeliveryPlanOcrRow> rows;

  String get fullText => lines.join('\n');
}

_PaddleDeliveryPlanExtractedResult _extractPaddleDeliveryPlanResult(
  String jsonl,
) {
  final lines = <String>[];
  final rows = <DeliveryPlanOcrRow>[];
  for (final rawLine in jsonl.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }
    final decoded = jsonDecode(line);
    if (decoded is! Map) {
      continue;
    }
    final result = _mapValue(decoded, 'result');
    final ocrResults = result['ocrResults'];
    if (ocrResults is List) {
      for (final item in ocrResults) {
        if (item is! Map) {
          continue;
        }
        final prunedResult = _mapValue(item, 'prunedResult');
        final recTexts = prunedResult['rec_texts'];
        if (recTexts is List) {
          lines.addAll(
            recTexts
                .map((text) => text?.toString().trim() ?? '')
                .where((text) => text.isNotEmpty),
          );
        }
      }
    }

    final layoutResults = result['layoutParsingResults'];
    if (layoutResults is List) {
      for (final item in layoutResults) {
        if (item is! Map) {
          continue;
        }
        final markdown = item['markdown'];
        final tableText = markdown is Map
            ? markdown['text']?.toString().trim() ?? ''
            : markdown?.toString().trim() ?? '';
        if (tableText.isEmpty) {
          continue;
        }
        lines.add(tableText);
        rows.addAll(_parseDeliveryPlanRowsFromTables(tableText));
      }
    }
  }
  return _PaddleDeliveryPlanExtractedResult(lines: lines, rows: rows);
}

List<DeliveryPlanOcrRow> _parseDeliveryPlanRowsFromTables(String text) {
  return [
    ..._parseDeliveryPlanRowsFromMarkdownTable(text),
    ..._parseDeliveryPlanRowsFromHtmlTable(text),
  ];
}

List<DeliveryPlanOcrRow> _parseDeliveryPlanRowsFromMarkdownTable(String text) {
  final rows = <DeliveryPlanOcrRow>[];
  List<String>? headers;
  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (!line.contains('|')) {
      continue;
    }
    final cells = _splitMarkdownTableRow(line);
    if (cells.length < 2 || _isMarkdownSeparatorRow(cells)) {
      continue;
    }
    if (headers == null && cells.any(_isDeliveryPlanHeaderCell)) {
      headers = cells;
      continue;
    }
    if (headers == null) {
      continue;
    }
    final row = _deliveryPlanRowFromMappedCells(headers, cells);
    if (row != null) {
      rows.add(row);
    }
  }
  return rows;
}

List<DeliveryPlanOcrRow> _parseDeliveryPlanRowsFromHtmlTable(String text) {
  final rows = <DeliveryPlanOcrRow>[];
  final rowPattern = RegExp(
    r'<tr\b[^>]*>(.*?)</tr>',
    caseSensitive: false,
    dotAll: true,
  );
  final cellPattern = RegExp(
    r'<t[dh]\b[^>]*>(.*?)</t[dh]>',
    caseSensitive: false,
    dotAll: true,
  );
  List<String>? headers;
  for (final rowMatch in rowPattern.allMatches(text)) {
    final cells = cellPattern
        .allMatches(rowMatch.group(1) ?? '')
        .map((match) => _stripTableText(match.group(1) ?? ''))
        .where((cell) => cell.isNotEmpty)
        .toList();
    if (cells.isEmpty) {
      continue;
    }
    if (headers == null && cells.any(_isDeliveryPlanHeaderCell)) {
      headers = cells;
      continue;
    }
    if (headers == null) {
      continue;
    }
    final row = _deliveryPlanRowFromMappedCells(headers, cells);
    if (row != null) {
      rows.add(row);
    }
  }
  return rows;
}

List<String> _splitMarkdownTableRow(String line) {
  var value = line.trim();
  if (value.startsWith('|')) {
    value = value.substring(1);
  }
  if (value.endsWith('|')) {
    value = value.substring(0, value.length - 1);
  }
  return value.split('|').map(_cleanMarkdownCell).toList(growable: false);
}

String _cleanMarkdownCell(String value) {
  return _decodeHtmlEntities(
    value
        .replaceAll(RegExp(r'[*`_]'), '')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim(),
  );
}

bool _isMarkdownSeparatorRow(List<String> cells) {
  return cells.every(
    (cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell.replaceAll(' ', '')),
  );
}

bool _isDeliveryPlanHeaderCell(String value) {
  final header = _normalizeDeliveryPlanHeader(value);
  return header.contains('物料号') ||
      header.contains('物料名称') ||
      header.contains('批次') ||
      header.contains('货架寿命到期日') ||
      header.contains('减交货计划可用量箱数') ||
      header.contains('在库总箱数');
}

DeliveryPlanOcrRow? _deliveryPlanRowFromMappedCells(
  List<String> headers,
  List<String> cells,
) {
  String cellWhere(bool Function(String normalizedHeader) matches) {
    for (var i = 0; i < headers.length; i += 1) {
      final header = _normalizeDeliveryPlanHeader(headers[i]);
      if (!matches(header)) {
        continue;
      }
      if (i >= cells.length) {
        return '';
      }
      return cells[i].trim();
    }
    return '';
  }

  final productCode = _digitsOnly(
    cellWhere((header) => header.contains('物料号') || header.contains('产品码')),
  );
  final productName = cellWhere(
    (header) => header.contains('物料名称') || header.contains('产品名称'),
  );
  final actualBatch = _normalizeDeliveryPlanBatch(
    cellWhere(_isActualBatchHeader),
  );
  final dateBatch = _normalizeDeliveryPlanDate(
    cellWhere(
      (header) =>
          header.contains('货架寿命到期日') ||
          header.contains('截止日期') ||
          header.contains('日期批号'),
    ),
  );
  final stockTotalBoxes = _intFromDeliveryPlanCell(
    cellWhere((header) => header.contains('在库总箱数')),
  );
  final deliveryPlanAvailableBoxes = _intFromDeliveryPlanCell(
    cellWhere(
      (header) =>
          header.contains('减交货计划可用量箱数') ||
          (header.contains('交货计划可用量箱数') && !header.contains('零数')),
    ),
  );

  if (!_isDeliveryPlanProductCode(productCode) ||
      actualBatch.isEmpty ||
      (stockTotalBoxes <= 0 && deliveryPlanAvailableBoxes <= 0)) {
    return null;
  }
  return DeliveryPlanOcrRow(
    productCode: productCode,
    productName: productName,
    actualBatch: actualBatch,
    dateBatch: dateBatch,
    stockTotalBoxes: stockTotalBoxes,
    deliveryPlanAvailableBoxes: deliveryPlanAvailableBoxes,
  );
}

bool _isActualBatchHeader(String header) {
  return header == '批次' ||
      header == '批号' ||
      header == '实际批号' ||
      (header.contains('批次') && !header.contains('状态'));
}

String _normalizeDeliveryPlanHeader(String value) {
  return value
      .replaceAll(RegExp(r'[\s　]+'), '')
      .replaceAll('Σ', '')
      .replaceAll('∑', '')
      .replaceAll('：', ':')
      .trim();
}

String _digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

bool _isDeliveryPlanProductCode(String value) {
  return RegExp(r'^\d{4,9}$').hasMatch(value);
}

String _normalizeDeliveryPlanBatch(String value) {
  return value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
}

String _normalizeDeliveryPlanDate(String value) {
  final text = value.trim().replaceAll('年', '.').replaceAll('月', '.');
  final match =
      RegExp(r'(\d{4})[.\-/](\d{1,2})[.\-/](\d{1,2})日?').firstMatch(text);
  if (match == null) {
    return value.trim();
  }
  final month = match.group(2)!.padLeft(2, '0');
  final day = match.group(3)!.padLeft(2, '0');
  return '${match.group(1)}.$month.$day';
}

int _intFromDeliveryPlanCell(String value) {
  return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
}

String _stripTableText(String value) {
  return _decodeHtmlEntities(
    value
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim(),
  );
}

String _decodeHtmlEntities(String value) {
  return value
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
}

String _paddleExtractProgress(Map<String, Object?> data) {
  final progress = _mapValue(data, 'extractProgress');
  final totalPages = progress['totalPages'];
  final extractedPages = progress['extractedPages'];
  if (totalPages != null && extractedPages != null) {
    return '$extractedPages/$totalPages 页';
  }
  return '';
}

String _paddlePollProgressMessage({
  required String state,
  required int attempt,
  required int maxAttempts,
  required String progress,
}) {
  if (state == 'pending') {
    return '飞桨OCR排队中，第 $attempt/$maxAttempts 次查询';
  }
  final progressText = progress.isEmpty ? '' : '，进度 $progress';
  return '飞桨OCR识别交货计划中，第 $attempt/$maxAttempts 次查询$progressText';
}

const _paddleConnectTimeout = Duration(seconds: 15);
const _paddleSubmitTimeout = Duration(seconds: 45);
const _paddleQueryTimeout = Duration(seconds: 20);
const _paddleDownloadTimeout = Duration(seconds: 45);

Future<String> _defaultPaddleDeliveryPlanSubmitJob({
  required File image,
  required String token,
  required String model,
  required Map<String, Object?> optionalPayload,
}) async {
  final boundary =
      '----qrscan-delivery-plan-paddle-${DateTime.now().microsecondsSinceEpoch}';
  final client = HttpClient();
  client.connectionTimeout = _paddleConnectTimeout;
  try {
    final request = await client
        .postUrl(Uri.parse(PaddleDeliveryPlanOcrService._jobUrl))
        .timeout(
          _paddleConnectTimeout,
          onTimeout: () => throw const DeliveryPlanOcrException(
            '飞桨OCR提交连接超时，请检查网络后重试',
          ),
        );
    request.headers.set(HttpHeaders.authorizationHeader, 'bearer $token');
    request.headers.contentType = ContentType(
      'multipart',
      'form-data',
      parameters: {'boundary': boundary},
    );
    void writeText(String value) => request.add(utf8.encode(value));
    void writeField(String name, String value) {
      writeText('--$boundary\r\n');
      writeText('Content-Disposition: form-data; name="$name"\r\n\r\n');
      writeText('$value\r\n');
    }

    writeField('model', model);
    writeField('optionalPayload', jsonEncode(optionalPayload));
    writeText('--$boundary\r\n');
    writeText(
      'Content-Disposition: form-data; name="file"; filename="${p.basename(image.path)}"\r\n',
    );
    writeText('Content-Type: application/octet-stream\r\n\r\n');
    request.add(await image.readAsBytes());
    writeText('\r\n--$boundary--\r\n');

    final response = await request.close().timeout(
          _paddleSubmitTimeout,
          onTimeout: () => throw const DeliveryPlanOcrException(
            '飞桨OCR提交超时，请检查网络或稍后重试',
          ),
        );
    final responseText = await response.transform(utf8.decoder).join().timeout(
          _paddleSubmitTimeout,
          onTimeout: () => throw const DeliveryPlanOcrException(
            '飞桨OCR提交响应超时，请稍后重试',
          ),
        );
    if (response.statusCode != 200) {
      throw DeliveryPlanOcrException(
        '飞桨OCR提交失败: ${response.statusCode} ${responseText.trim()}',
      );
    }
    final decoded = jsonDecode(responseText);
    if (decoded is! Map) {
      throw const DeliveryPlanOcrException('飞桨OCR提交返回格式无效');
    }
    final data = _mapValue(decoded, 'data');
    final jobId = data['jobId']?.toString().trim() ?? '';
    if (jobId.isEmpty) {
      final message = decoded['msg']?.toString().trim();
      throw DeliveryPlanOcrException(
        message == null || message.isEmpty ? '飞桨OCR未返回任务ID' : message,
      );
    }
    return jobId;
  } on DeliveryPlanOcrException {
    rethrow;
  } on SocketException catch (error) {
    throw DeliveryPlanOcrException(
      '飞桨OCR提交网络异常: ${error.message}',
    );
  } on TimeoutException {
    throw const DeliveryPlanOcrException('飞桨OCR提交超时，请稍后重试');
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, Object?>> _defaultPaddleDeliveryPlanGetJob({
  required String jobId,
  required String token,
}) async {
  final client = HttpClient();
  client.connectionTimeout = _paddleConnectTimeout;
  try {
    final request = await client
        .getUrl(
          Uri.parse('${PaddleDeliveryPlanOcrService._jobUrl}/$jobId'),
        )
        .timeout(
          _paddleConnectTimeout,
          onTimeout: () => throw const DeliveryPlanOcrException(
            '飞桨OCR查询连接超时，请检查网络后重试',
          ),
        );
    request.headers.set(HttpHeaders.authorizationHeader, 'bearer $token');
    final response = await request.close().timeout(
          _paddleQueryTimeout,
          onTimeout: () => throw const DeliveryPlanOcrException(
            '飞桨OCR查询任务超时，请稍后重试',
          ),
        );
    final responseText = await response.transform(utf8.decoder).join().timeout(
          _paddleQueryTimeout,
          onTimeout: () => throw const DeliveryPlanOcrException(
            '飞桨OCR查询响应超时，请稍后重试',
          ),
        );
    if (response.statusCode != 200) {
      throw DeliveryPlanOcrException(
        '飞桨OCR查询任务失败: ${response.statusCode} ${responseText.trim()}',
      );
    }
    final decoded = jsonDecode(responseText);
    if (decoded is Map) {
      return decoded.cast<String, Object?>();
    }
    throw const DeliveryPlanOcrException('飞桨OCR查询返回格式无效');
  } on DeliveryPlanOcrException {
    rethrow;
  } on SocketException catch (error) {
    throw DeliveryPlanOcrException(
      '飞桨OCR查询网络异常: ${error.message}',
    );
  } on TimeoutException {
    throw const DeliveryPlanOcrException('飞桨OCR查询任务超时，请稍后重试');
  } finally {
    client.close(force: true);
  }
}

Future<String> _defaultPaddleDeliveryPlanDownloadResult(Uri uri) async {
  final client = HttpClient();
  client.connectionTimeout = _paddleConnectTimeout;
  try {
    final request = await client.getUrl(uri).timeout(
          _paddleConnectTimeout,
          onTimeout: () => throw const DeliveryPlanOcrException(
            '飞桨OCR下载连接超时，请稍后重试',
          ),
        );
    final response = await request.close().timeout(
          _paddleDownloadTimeout,
          onTimeout: () => throw const DeliveryPlanOcrException(
            '飞桨OCR下载结果超时，请稍后重试',
          ),
        );
    final responseText = await response.transform(utf8.decoder).join().timeout(
          _paddleDownloadTimeout,
          onTimeout: () => throw const DeliveryPlanOcrException(
            '飞桨OCR下载响应超时，请稍后重试',
          ),
        );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DeliveryPlanOcrException(
        '飞桨OCR下载结果失败: ${response.statusCode}',
      );
    }
    return responseText;
  } on DeliveryPlanOcrException {
    rethrow;
  } on SocketException catch (error) {
    throw DeliveryPlanOcrException(
      '飞桨OCR下载网络异常: ${error.message}',
    );
  } on TimeoutException {
    throw const DeliveryPlanOcrException('飞桨OCR下载结果超时，请稍后重试');
  } finally {
    client.close(force: true);
  }
}

Map<String, Object?> _mapValue(Map raw, String key) {
  final value = raw[key];
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  return const {};
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

先按下面两步处理表格，不要把所有物料都返回：
1. 先定位“交货计划”列（也可能显示为“Σ 交货计划”，表头前后可能有Σ、排序符号或空格）。
   只保留这一列有正数数量的明细行；如果该列为空、0、读不到或只是底部合计行，整行不要返回。
   不要用“交货计划件数”“交货计划可用用量”“减交货计划可用量箱数”替代这个筛选列。
2. 对第1步保留的行，再提取“减交货计划可用量箱数”，用于和本地库存明细比较。

返回字段：
- productCode: 物料号，只保留数字字符
- productName: 物料名称
- actualBatch: 批次/实际批号，优先读取英数串
- dateBatch: 货架寿命到期日/截止日期/日期批号
- stockTotalBoxes: 兼容旧字段，固定填0；不要从截图提取在库总库存、在库总箱数或非限制库存
- deliveryPlanAvailableBoxes: 第1步保留行中“减交货计划可用量箱数”列的整数；表头前有Σ、排序符号或空格也按这一列读取
- warnings: 读不清或列缺失时，用中文简短说明

只把“减交货计划可用量箱数”提取到 deliveryPlanAvailableBoxes。
不要把“交货计划”“Σ 交货计划”“交货计划件数”“交货计划可用用量”当作 deliveryPlanAvailableBoxes；它们只用于判断是否需要返回该行。
不要把库位描述、库位、包装规格、Σ在库总库存、Σ冻结库存、Σ非限制库存、Σ在库总箱数、批次状态、产品组描述、非限制箱数提取为业务字段。
不要根据件数、包装规格、金额、重量推算箱数。
本地程序会计算：可能备货箱数 = APP可用箱数 - 减交货计划可用量箱数；APP可用箱数来自本地库存明细，不由AI识别或推算。
本地程序会再从基础资料匹配仓储位置，不要提取或补全位置字段。
如果保留行的“减交货计划可用量箱数”读不到，deliveryPlanAvailableBoxes填0并在warnings说明；不要因此补返回未保留的行。
忽略底部合计行、黄色选中行样式和表格汇总数字。
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
