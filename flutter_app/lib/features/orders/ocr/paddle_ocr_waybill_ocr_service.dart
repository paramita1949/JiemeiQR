import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';
import 'package:qrscan_flutter/features/orders/ocr/merchant_name_matcher.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_diagnostics.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_text_parser.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_photo_ocr_service.dart';
import 'package:qrscan_flutter/shared/utils/debug_event_log.dart';

typedef PaddleOcrSubmitJob = Future<String> Function({
  required File image,
  required String token,
  required String model,
  required Map<String, Object?> optionalPayload,
});

typedef PaddleOcrGetJob = Future<Map<String, Object?>> Function({
  required String jobId,
  required String token,
});

typedef PaddleOcrDownloadResult = Future<String> Function(Uri uri);

class PaddleOcrWaybillOcrService implements WaybillPhotoOcrService {
  PaddleOcrWaybillOcrService({
    String? token,
    String? model,
    FileAiConfigStore? configStore,
    PaddleOcrSubmitJob? submitJob,
    PaddleOcrGetJob? getJob,
    PaddleOcrDownloadResult? downloadResult,
    Duration pollInterval = const Duration(seconds: 5),
    int maxPollAttempts = 24,
  })  : token = token ?? const String.fromEnvironment('PADDLE_OCR_TOKEN'),
        model = model ?? const String.fromEnvironment('PADDLE_OCR_MODEL'),
        _configStore = configStore ?? const FileAiConfigStore(),
        _submitJob = submitJob ?? _defaultSubmitJob,
        _getJob = getJob ?? _defaultGetJob,
        _downloadResult = downloadResult ?? _defaultDownloadResult,
        _pollInterval = pollInterval,
        _maxPollAttempts = maxPollAttempts;

  final String token;
  final String model;
  final FileAiConfigStore _configStore;
  final PaddleOcrSubmitJob _submitJob;
  final PaddleOcrGetJob _getJob;
  final PaddleOcrDownloadResult _downloadResult;
  final Duration _pollInterval;
  final int _maxPollAttempts;

  static const _jobUrl = 'https://paddleocr.aistudio-app.com/api/v2/ocr/jobs';
  static const _optionalPayload = {
    'useDocOrientationClassify': false,
    'useDocUnwarping': false,
    'useTextlineOrientation': false,
  };

  @override
  Future<WaybillOcrDraft> recognize(
    File image, {
    Iterable<String> merchantHistoryNames = const [],
    WaybillOcrProgressCallback? onProgress,
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
      throw const PaddleOcrWaybillOcrException('缺少飞桨OCR Token');
    }

    final normalizedToken = _normalizeBearerToken(effectiveToken);
    final imageBytes = await image.length();
    DebugEventLog.add(
      'AI_OCR',
      'paddleocr_submit_start model=$effectiveModel image_bytes=$imageBytes',
    );
    _reportPaddleProgress(onProgress, '正在上传图片到飞桨OCR...');
    final jobId = await _submitJob(
      image: image,
      token: normalizedToken,
      model: effectiveModel,
      optionalPayload: _optionalPayload,
    );
    DebugEventLog.add(
      'AI_OCR',
      'paddleocr_job_submitted job=$jobId model=$effectiveModel',
    );
    _reportPaddleProgress(onProgress, '飞桨OCR已提交任务，等待服务端识别...');
    final jsonlUrl = await _waitForResultUrl(
      jobId: jobId,
      token: normalizedToken,
      onProgress: onProgress,
    );
    _reportPaddleProgress(onProgress, '飞桨OCR识别完成，正在下载结果...');
    final jsonl = await _downloadResult(Uri.parse(jsonlUrl));
    final extracted = _extractResult(jsonl);
    final fullText = extracted.lines.join('\n');
    if (fullText.trim().isEmpty && extracted.rows.isEmpty) {
      throw const PaddleOcrWaybillOcrException('飞桨OCR未返回识别文本');
    }
    final textDraft = parseWaybillOcrText(
      fields: _extractHeaderFields(fullText),
      fullText: fullText,
    );
    final merchantResolution = _resolvePaddleMerchantName(
      rawMerchantName: textDraft.merchantName,
      historyNames: merchantHistoryNames,
    );
    final rows = extracted.rows.isNotEmpty ? extracted.rows : textDraft.rows;
    final totalBoxes =
        extracted.totalBoxes > 0 ? extracted.totalBoxes : textDraft.totalBoxes;
    final draft = WaybillOcrDraft(
      waybillNo: textDraft.waybillNo,
      merchantName: merchantResolution.name,
      rawMerchantName: merchantResolution.rawName,
      matchedHistoryMerchant: merchantResolution.matchedHistoryMerchant,
      merchantConfidence:
          merchantResolution.matchedHistoryMerchant.isEmpty ? '' : 'high',
      merchantMatchReason:
          merchantResolution.matchedHistoryMerchant.isEmpty ? '' : '历史商家简称匹配',
      orderDateText: textDraft.orderDateText,
      rows: rows,
      totalBoxes: totalBoxes,
      warnings: _warningsWithBoxTotalCheck(
        warnings: textDraft.warnings,
        rows: rows,
        totalBoxes: totalBoxes,
      ),
    );
    logOcrMerchantDiagnosis(provider: 'paddleocr', draft: draft);
    return draft;
  }

  Future<String> _waitForResultUrl({
    required String jobId,
    required String token,
    WaybillOcrProgressCallback? onProgress,
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
          throw const PaddleOcrWaybillOcrException(
            '飞桨OCR任务完成但未返回结果地址',
          );
        }
        DebugEventLog.add(
          'AI_OCR',
          'paddleocr_poll job=$jobId attempt=$attemptNumber/$_maxPollAttempts state=done',
        );
        return jsonUrl;
      }
      if (state == 'failed') {
        final message = data['errorMsg']?.toString().trim();
        DebugEventLog.add(
          'AI_OCR',
          'paddleocr_poll job=$jobId attempt=$attemptNumber/$_maxPollAttempts state=failed error=${message ?? ''}',
        );
        throw PaddleOcrWaybillOcrException(
          message == null || message.isEmpty ? '飞桨OCR任务失败' : message,
        );
      }
      if (state != 'pending' && state != 'running') {
        throw PaddleOcrWaybillOcrException('飞桨OCR任务状态异常: $state');
      }
      final progressMessage = _paddlePollProgressMessage(
        state: state,
        attempt: attemptNumber,
        maxAttempts: _maxPollAttempts,
        progress: progress,
      );
      _reportPaddleProgress(onProgress, progressMessage);
      DebugEventLog.add(
        'AI_OCR',
        'paddleocr_poll job=$jobId attempt=$attemptNumber/$_maxPollAttempts state=$state${progress.isEmpty ? '' : ' progress=$progress'}',
      );
      if (_pollInterval > Duration.zero) {
        await Future<void>.delayed(_pollInterval);
      }
    }
    throw PaddleOcrWaybillOcrException(
      '飞桨OCR任务等待超时（最后状态: ${lastState.isEmpty ? '未知' : lastState}，'
      '查询 $_maxPollAttempts/$_maxPollAttempts 次'
      '${lastProgress.isEmpty ? '' : '，进度 $lastProgress'}）',
    );
  }

  _PaddleOcrExtractedResult _extractResult(String jsonl) {
    final lines = <String>[];
    final rows = <WaybillOcrRow>[];
    var totalBoxes = 0;
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
            final cellTexts = recTexts
                .map((text) => text?.toString().trim() ?? '')
                .where((text) => text.isNotEmpty)
                .toList();
            lines.addAll(cellTexts);
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
          final markdownText = markdown is Map
              ? markdown['text']?.toString().trim() ?? ''
              : markdown?.toString().trim() ?? '';
          if (markdownText.isNotEmpty) {
            lines.add(markdownText);
            rows.addAll(_parseRowsFromHtmlTables(markdownText));
            final tableTotals = _parseTotalsFromHtmlTables(markdownText);
            if (tableTotals.grandTotalBoxes > 0) {
              totalBoxes = tableTotals.grandTotalBoxes;
            } else if (totalBoxes == 0 && tableTotals.pageTotalBoxes > 0) {
              totalBoxes = tableTotals.pageTotalBoxes;
            }
          }
        }
      }
    }
    return _PaddleOcrExtractedResult(
      lines: lines,
      rows: _dedupeRows(rows),
      totalBoxes: totalBoxes,
    );
  }
}

class _PaddleOcrExtractedResult {
  const _PaddleOcrExtractedResult({
    required this.lines,
    required this.rows,
    required this.totalBoxes,
  });

  final List<String> lines;
  final List<WaybillOcrRow> rows;
  final int totalBoxes;
}

void _reportPaddleProgress(
  WaybillOcrProgressCallback? onProgress,
  String message,
) {
  onProgress?.call(message);
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
  return '飞桨OCR识别中，第 $attempt/$maxAttempts 次查询$progressText';
}

class PaddleOcrWaybillOcrException implements Exception {
  const PaddleOcrWaybillOcrException(this.message);

  final String message;

  @override
  String toString() => message;
}

Map<String, String> _extractHeaderFields(String fullText) {
  final fields = <String, String>{};
  final plainText = _stripHtml(fullText);
  final waybillNo = RegExp(r'运单号\s*[:：]\s*([A-Za-z0-9]+)')
      .firstMatch(plainText)
      ?.group(1)
      ?.trim();
  if (waybillNo != null && waybillNo.isNotEmpty) {
    fields['运单号'] = waybillNo;
  }
  final merchantName = RegExp(r'收货方\s*[:：]\s*([^\n\r]+)')
      .firstMatch(plainText)
      ?.group(1)
      ?.trim();
  if (merchantName != null && merchantName.isNotEmpty) {
    fields['收货方'] = merchantName;
  }
  final orderDate =
      RegExp(r'起运日\s*[:：]?\s*(\d{4}[.\-/年]\d{1,2}[.\-/月]\d{1,2}日?)')
          .firstMatch(plainText)
          ?.group(1)
          ?.trim();
  if (orderDate != null && orderDate.isNotEmpty) {
    fields['日期'] = orderDate;
  }
  return fields;
}

List<WaybillOcrRow> _parseRowsFromHtmlTables(String text) {
  final rows = <WaybillOcrRow>[];
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
        .map((match) => _stripHtml(match.group(1) ?? ''))
        .toList();
    if (cells.isEmpty) {
      continue;
    }
    if (headers == null && cells.any((cell) => cell.contains('产品码'))) {
      headers = cells;
      continue;
    }
    if (headers == null) {
      continue;
    }
    final row = _rowFromMappedCells(headers, cells);
    if (row != null) {
      rows.add(row);
    }
  }
  return rows;
}

_HtmlTableTotals _parseTotalsFromHtmlTables(String text) {
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
  var pageTotalBoxes = 0;
  var grandTotalBoxes = 0;
  for (final rowMatch in rowPattern.allMatches(text)) {
    final cells = cellPattern
        .allMatches(rowMatch.group(1) ?? '')
        .map((match) => _stripHtml(match.group(1) ?? ''))
        .toList();
    if (cells.isEmpty) {
      continue;
    }
    if (headers == null && cells.any((cell) => cell.contains('产品码'))) {
      headers = cells;
      continue;
    }
    if (headers == null) {
      continue;
    }
    final rowText = cells.join(' ');
    if (!rowText.contains('页小计') && !rowText.contains('总计')) {
      continue;
    }
    final boxes = _totalBoxesFromMappedCells(headers, cells);
    if (boxes <= 0) {
      continue;
    }
    if (rowText.contains('总计')) {
      grandTotalBoxes = boxes;
    } else if (rowText.contains('页小计')) {
      pageTotalBoxes = boxes;
    }
  }
  return _HtmlTableTotals(
    pageTotalBoxes: pageTotalBoxes,
    grandTotalBoxes: grandTotalBoxes,
  );
}

WaybillOcrRow? _rowFromMappedCells(List<String> headers, List<String> cells) {
  String cell(String header) {
    final index = headers.indexWhere((item) => item.contains(header));
    if (index < 0 || index >= cells.length) {
      return '';
    }
    return cells[index].trim();
  }

  final productCode = cell('产品码');
  final productName = cell('产品名称');
  final actualBatch = _normalizedBatchCode(cell('批号'));
  final dateBatch = cell('截止日期');
  final boxes = int.tryParse(cell('箱数').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  if (!_isProductCode(productCode) ||
      productName.isEmpty ||
      !_isBatchCode(actualBatch) ||
      !_isDateText(dateBatch) ||
      boxes <= 0) {
    return null;
  }
  return WaybillOcrRow(
    productCode: productCode,
    productName: productName,
    actualBatch: actualBatch,
    dateBatch: dateBatch,
    boxes: boxes,
  );
}

int _totalBoxesFromMappedCells(List<String> headers, List<String> cells) {
  final boxesIndex = headers.indexWhere((item) => item.contains('箱数'));
  if (boxesIndex >= 0 && boxesIndex < cells.length) {
    final boxes = int.tryParse(
          cells[boxesIndex].replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
    if (boxes > 0) {
      return boxes;
    }
  }
  final labelIndex = cells.indexWhere(
    (cell) => cell.contains('页小计') || cell.contains('总计'),
  );
  final searchCells = labelIndex >= 0 ? cells.skip(labelIndex + 1) : cells;
  for (final cell in searchCells) {
    final value = int.tryParse(cell.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (value > 0) {
      return value;
    }
  }
  return 0;
}

List<String> _warningsWithBoxTotalCheck({
  required List<String> warnings,
  required List<WaybillOcrRow> rows,
  required int totalBoxes,
}) {
  final checked = warnings.toList();
  if (totalBoxes <= 0) {
    return checked;
  }
  final rowTotal = rows.fold<int>(0, (sum, row) => sum + row.boxes);
  if (rowTotal == totalBoxes) {
    return checked;
  }
  final warning = '明细箱数合计$rowTotal箱，与图片总计$totalBoxes箱不一致';
  if (!checked.contains(warning)) {
    checked.add(warning);
  }
  return checked;
}

bool _isProductCode(String value) => RegExp(r'^\d{4,6}$').hasMatch(value);

bool _isBatchCode(String value) =>
    RegExp(r'^[A-Z0-9]{5,}$').hasMatch(_normalizedBatchCode(value));

String _normalizedBatchCode(String value) =>
    value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

bool _isDateText(String value) =>
    RegExp(r'^\d{4}[.\-/年]\d{1,2}[.\-/月]\d{1,2}日?$').hasMatch(value);

_PaddleMerchantResolution _resolvePaddleMerchantName({
  required String rawMerchantName,
  required Iterable<String> historyNames,
}) {
  final rawName = rawMerchantName.trim();
  if (rawName.isEmpty) {
    return const _PaddleMerchantResolution(
      name: '',
      rawName: '',
      matchedHistoryMerchant: '',
    );
  }

  final historyFromRaw = resolveMerchantNameFromHistory(
    recognizedName: rawName,
    historyNames: historyNames,
  );
  if (historyFromRaw != rawName) {
    return _PaddleMerchantResolution(
      name: historyFromRaw,
      rawName: rawName,
      matchedHistoryMerchant: historyFromRaw,
    );
  }

  final shortened = _shortenPaddleMerchantName(rawName);
  final candidate = shortened.isEmpty ? rawName : shortened;
  final historyFromShortened = resolveMerchantNameFromHistory(
    recognizedName: candidate,
    historyNames: historyNames,
  );
  return _PaddleMerchantResolution(
    name: historyFromShortened,
    rawName: rawName,
    matchedHistoryMerchant:
        historyFromShortened == candidate ? '' : historyFromShortened,
  );
}

String _shortenPaddleMerchantName(String value) {
  var text = value
      .trim()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[（(][^）)]*[）)]'), '')
      .replaceFirst(RegExp(r'二级.*$'), '');
  text = _normalizePaddleMerchantSuffix(text);
  text = _stripPaddleMerchantAdministrativePrefix(text);
  text = _normalizePaddleMerchantSuffix(text);
  return text.length >= 2 ? text : value.trim();
}

String _normalizePaddleMerchantSuffix(String value) {
  var text = value.trim();
  var changed = true;
  while (changed) {
    changed = false;
    for (final replacement in _paddleMerchantSuffixReplacements.entries) {
      final suffix = replacement.key;
      if (!text.endsWith(suffix) || text.length <= suffix.length) {
        continue;
      }
      text = text.substring(0, text.length - suffix.length) + replacement.value;
      changed = true;
      break;
    }
  }
  return text;
}

String _stripPaddleMerchantAdministrativePrefix(String value) {
  var text = value.trim();
  var changed = true;
  while (changed) {
    changed = false;
    final markedPrefix =
        RegExp(r'^[\u4e00-\u9fa5]{2,8}(省|市|县|区|镇|乡|街道|街)').firstMatch(text);
    if (markedPrefix != null && text.length > markedPrefix.end + 1) {
      text = text.substring(markedPrefix.end);
      changed = true;
      continue;
    }
    for (final prefix in _paddleMerchantAdministrativePrefixes) {
      if (text.startsWith(prefix) && text.length > prefix.length + 1) {
        text = text.substring(prefix.length);
        changed = true;
        break;
      }
    }
  }
  return text;
}

const _paddleMerchantSuffixReplacements = {
  '贸易发展有限公司': '贸易',
  '日用品有限公司': '日用',
  '日用品商行': '日用',
  '日用品经营部': '日用',
  '日用品': '日用',
  '化妆品经营部': '',
  '有限责任公司': '',
  '股份有限公司': '',
  '有限公司': '',
  '商贸公司': '商贸',
  '贸易公司': '贸易',
  '经销商': '',
  '经营部': '',
  '商行': '',
  '公司': '',
  '客户': '',
};

const _paddleMerchantAdministrativePrefixes = [
  '黑龙江省',
  '内蒙古',
  '浙江省',
  '上海市',
  '北京市',
  '天津市',
  '重庆市',
  '杭州市',
  '宁波市',
  '温州市',
  '嘉兴市',
  '湖州市',
  '绍兴市',
  '金华市',
  '衢州市',
  '舟山市',
  '台州市',
  '丽水市',
  '义乌市',
  '永康市',
  '龙游县',
  '黑龙江',
  '浙江',
  '江苏',
  '安徽',
  '福建',
  '江西',
  '山东',
  '河南',
  '湖北',
  '湖南',
  '广东',
  '广西',
  '海南',
  '四川',
  '贵州',
  '云南',
  '陕西',
  '甘肃',
  '青海',
  '宁夏',
  '新疆',
  '西藏',
  '辽宁',
  '吉林',
  '河北',
  '山西',
  '北京',
  '上海',
  '天津',
  '重庆',
  '杭州',
  '宁波',
  '温州',
  '嘉兴',
  '湖州',
  '绍兴',
  '金华',
  '衢州',
  '舟山',
  '台州',
  '丽水',
  '义乌',
  '永康',
  '龙游',
];

class _PaddleMerchantResolution {
  const _PaddleMerchantResolution({
    required this.name,
    required this.rawName,
    required this.matchedHistoryMerchant,
  });

  final String name;
  final String rawName;
  final String matchedHistoryMerchant;
}

class _HtmlTableTotals {
  const _HtmlTableTotals({
    required this.pageTotalBoxes,
    required this.grandTotalBoxes,
  });

  final int pageTotalBoxes;
  final int grandTotalBoxes;
}

List<WaybillOcrRow> _dedupeRows(List<WaybillOcrRow> rows) {
  final seen = <String>{};
  final deduped = <WaybillOcrRow>[];
  for (final row in rows) {
    final key = [
      row.productCode,
      row.productName,
      row.actualBatch,
      row.dateBatch,
      row.boxes,
    ].join('|');
    if (seen.add(key)) {
      deduped.add(row);
    }
  }
  return deduped;
}

String _stripHtml(String value) {
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

const _paddleConnectTimeout = Duration(seconds: 15);
const _paddleSubmitTimeout = Duration(seconds: 45);
const _paddleQueryTimeout = Duration(seconds: 20);
const _paddleDownloadTimeout = Duration(seconds: 45);

Future<String> _defaultSubmitJob({
  required File image,
  required String token,
  required String model,
  required Map<String, Object?> optionalPayload,
}) async {
  final boundary = '----qrscan-paddle-${DateTime.now().microsecondsSinceEpoch}';
  final client = HttpClient();
  client.connectionTimeout = _paddleConnectTimeout;
  try {
    final request = await client
        .postUrl(Uri.parse(PaddleOcrWaybillOcrService._jobUrl))
        .timeout(
          _paddleConnectTimeout,
          onTimeout: () => throw const PaddleOcrWaybillOcrException(
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
          onTimeout: () => throw const PaddleOcrWaybillOcrException(
            '飞桨OCR提交超时，请检查网络或稍后重试',
          ),
        );
    final responseText = await response.transform(utf8.decoder).join().timeout(
          _paddleSubmitTimeout,
          onTimeout: () => throw const PaddleOcrWaybillOcrException(
            '飞桨OCR提交响应超时，请稍后重试',
          ),
        );
    if (response.statusCode != 200) {
      throw PaddleOcrWaybillOcrException(
        '飞桨OCR提交失败: ${response.statusCode} ${responseText.trim()}',
      );
    }
    final decoded = jsonDecode(responseText);
    if (decoded is! Map) {
      throw const PaddleOcrWaybillOcrException('飞桨OCR提交返回格式无效');
    }
    final data = _mapValue(decoded, 'data');
    final jobId = data['jobId']?.toString().trim() ?? '';
    if (jobId.isEmpty) {
      final message = decoded['msg']?.toString().trim();
      throw PaddleOcrWaybillOcrException(
        message == null || message.isEmpty ? '飞桨OCR未返回任务ID' : message,
      );
    }
    return jobId;
  } on PaddleOcrWaybillOcrException {
    rethrow;
  } on SocketException catch (error) {
    throw PaddleOcrWaybillOcrException(
      '飞桨OCR提交网络异常: ${error.message}',
    );
  } on TimeoutException {
    throw const PaddleOcrWaybillOcrException('飞桨OCR提交超时，请稍后重试');
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, Object?>> _defaultGetJob({
  required String jobId,
  required String token,
}) async {
  final client = HttpClient();
  client.connectionTimeout = _paddleConnectTimeout;
  try {
    final request = await client
        .getUrl(
          Uri.parse('${PaddleOcrWaybillOcrService._jobUrl}/$jobId'),
        )
        .timeout(
          _paddleConnectTimeout,
          onTimeout: () => throw const PaddleOcrWaybillOcrException(
            '飞桨OCR查询连接超时，请检查网络后重试',
          ),
        );
    request.headers.set(HttpHeaders.authorizationHeader, 'bearer $token');
    final response = await request.close().timeout(
          _paddleQueryTimeout,
          onTimeout: () => throw const PaddleOcrWaybillOcrException(
            '飞桨OCR查询任务超时，请稍后重试',
          ),
        );
    final responseText = await response.transform(utf8.decoder).join().timeout(
          _paddleQueryTimeout,
          onTimeout: () => throw const PaddleOcrWaybillOcrException(
            '飞桨OCR查询响应超时，请稍后重试',
          ),
        );
    if (response.statusCode != 200) {
      throw PaddleOcrWaybillOcrException(
        '飞桨OCR查询任务失败: ${response.statusCode} ${responseText.trim()}',
      );
    }
    final decoded = jsonDecode(responseText);
    if (decoded is Map) {
      return decoded.cast<String, Object?>();
    }
    throw const PaddleOcrWaybillOcrException('飞桨OCR查询返回格式无效');
  } on PaddleOcrWaybillOcrException {
    rethrow;
  } on SocketException catch (error) {
    throw PaddleOcrWaybillOcrException(
      '飞桨OCR查询网络异常: ${error.message}',
    );
  } on TimeoutException {
    throw const PaddleOcrWaybillOcrException('飞桨OCR查询任务超时，请稍后重试');
  } finally {
    client.close(force: true);
  }
}

Future<String> _defaultDownloadResult(Uri uri) async {
  final client = HttpClient();
  client.connectionTimeout = _paddleConnectTimeout;
  try {
    final request = await client.getUrl(uri).timeout(
          _paddleConnectTimeout,
          onTimeout: () => throw const PaddleOcrWaybillOcrException(
            '飞桨OCR下载连接超时，请稍后重试',
          ),
        );
    final response = await request.close().timeout(
          _paddleDownloadTimeout,
          onTimeout: () => throw const PaddleOcrWaybillOcrException(
            '飞桨OCR下载结果超时，请稍后重试',
          ),
        );
    final responseText = await response.transform(utf8.decoder).join().timeout(
          _paddleDownloadTimeout,
          onTimeout: () => throw const PaddleOcrWaybillOcrException(
            '飞桨OCR下载响应超时，请稍后重试',
          ),
        );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PaddleOcrWaybillOcrException(
        '飞桨OCR下载结果失败: ${response.statusCode}',
      );
    }
    return responseText;
  } on PaddleOcrWaybillOcrException {
    rethrow;
  } on SocketException catch (error) {
    throw PaddleOcrWaybillOcrException(
      '飞桨OCR下载网络异常: ${error.message}',
    );
  } on TimeoutException {
    throw const PaddleOcrWaybillOcrException('飞桨OCR下载结果超时，请稍后重试');
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

String _normalizeBearerToken(String raw) {
  final value = raw.trim();
  if (value.toLowerCase().startsWith('bearer ')) {
    return value.substring(7).trim();
  }
  return value;
}
