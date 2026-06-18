import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_text_parser.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_photo_ocr_service.dart';

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

    final jobId = await _submitJob(
      image: image,
      token: _normalizeBearerToken(effectiveToken),
      model: effectiveModel,
      optionalPayload: _optionalPayload,
    );
    final jsonlUrl = await _waitForResultUrl(
      jobId: jobId,
      token: _normalizeBearerToken(effectiveToken),
    );
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
    return WaybillOcrDraft(
      waybillNo: textDraft.waybillNo,
      merchantName: textDraft.merchantName,
      orderDateText: textDraft.orderDateText,
      rows: extracted.rows.isNotEmpty ? extracted.rows : textDraft.rows,
      warnings: textDraft.warnings,
    );
  }

  Future<String> _waitForResultUrl({
    required String jobId,
    required String token,
  }) async {
    for (var attempt = 0; attempt < _maxPollAttempts; attempt += 1) {
      final response = await _getJob(jobId: jobId, token: token);
      final data = _mapValue(response, 'data');
      final state = data['state']?.toString() ?? '';
      if (state == 'done') {
        final resultUrl = _mapValue(data, 'resultUrl');
        final jsonUrl = resultUrl['jsonUrl']?.toString().trim() ?? '';
        if (jsonUrl.isEmpty) {
          throw const PaddleOcrWaybillOcrException(
            '飞桨OCR任务完成但未返回结果地址',
          );
        }
        return jsonUrl;
      }
      if (state == 'failed') {
        final message = data['errorMsg']?.toString().trim();
        throw PaddleOcrWaybillOcrException(
          message == null || message.isEmpty ? '飞桨OCR任务失败' : message,
        );
      }
      if (state != 'pending' && state != 'running') {
        throw PaddleOcrWaybillOcrException('飞桨OCR任务状态异常: $state');
      }
      if (_pollInterval > Duration.zero) {
        await Future<void>.delayed(_pollInterval);
      }
    }
    throw const PaddleOcrWaybillOcrException('飞桨OCR任务等待超时');
  }

  _PaddleOcrExtractedResult _extractResult(String jsonl) {
    final lines = <String>[];
    final rows = <WaybillOcrRow>[];
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
            rows.addAll(_parseRowsFromCells(cellTexts));
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
          }
        }
      }
    }
    return _PaddleOcrExtractedResult(
      lines: lines,
      rows: _dedupeRows(rows),
    );
  }
}

class _PaddleOcrExtractedResult {
  const _PaddleOcrExtractedResult({
    required this.lines,
    required this.rows,
  });

  final List<String> lines;
  final List<WaybillOcrRow> rows;
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

List<WaybillOcrRow> _parseRowsFromCells(List<String> cells) {
  final rows = <WaybillOcrRow>[];
  for (var i = 0; i < cells.length - 3; i += 1) {
    final productCode = cells[i].trim();
    if (!_isProductCode(productCode)) {
      continue;
    }
    final productName = cells[i + 1].trim();
    final actualBatch = cells[i + 2].trim();
    final dateBatch = cells[i + 3].trim();
    if (productName.isEmpty ||
        !_isBatchCode(actualBatch) ||
        !_isDateText(dateBatch)) {
      continue;
    }
    final boxes = _boxesAfterDate(cells, i + 4);
    if (boxes <= 0) {
      continue;
    }
    rows.add(
      WaybillOcrRow(
        productCode: productCode,
        productName: productName,
        actualBatch: actualBatch,
        dateBatch: dateBatch,
        boxes: boxes,
      ),
    );
  }
  return rows;
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
  final actualBatch = cell('批号');
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

int _boxesAfterDate(List<String> cells, int start) {
  final end = (start + 8).clamp(0, cells.length);
  final window = cells.sublist(start, end);
  final locationIndex = window.indexWhere(_isWarehouseLocation);
  if (locationIndex >= 0) {
    final intsAfterLocation = window
        .skip(locationIndex + 1)
        .map(_integerCell)
        .whereType<int>()
        .toList();
    if (intsAfterLocation.length >= 2) {
      return intsAfterLocation[1];
    }
    if (intsAfterLocation.isNotEmpty) {
      return intsAfterLocation.first;
    }
  }
  final ints = window.map(_integerCell).whereType<int>().toList();
  if (ints.length >= 2) {
    return ints[1];
  }
  return ints.isEmpty ? 0 : ints.first;
}

int? _integerCell(String value) {
  final text = value.trim();
  if (!RegExp(r'^\d+$').hasMatch(text)) {
    return null;
  }
  return int.tryParse(text);
}

bool _isProductCode(String value) => RegExp(r'^\d{4,6}$').hasMatch(value);

bool _isBatchCode(String value) => RegExp(r'^[A-Z0-9]{5,}$').hasMatch(value);

bool _isDateText(String value) =>
    RegExp(r'^\d{4}[.\-/年]\d{1,2}[.\-/月]\d{1,2}日?$').hasMatch(value);

bool _isWarehouseLocation(String value) =>
    RegExp(r'^[A-Z]{1,4}\d{1,3}$', caseSensitive: false).hasMatch(value);

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

Future<String> _defaultSubmitJob({
  required File image,
  required String token,
  required String model,
  required Map<String, Object?> optionalPayload,
}) async {
  final boundary = '----qrscan-paddle-${DateTime.now().microsecondsSinceEpoch}';
  final client = HttpClient();
  try {
    final request =
        await client.postUrl(Uri.parse(PaddleOcrWaybillOcrService._jobUrl));
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

    final response = await request.close();
    final responseText = await response.transform(utf8.decoder).join();
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
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, Object?>> _defaultGetJob({
  required String jobId,
  required String token,
}) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse('${PaddleOcrWaybillOcrService._jobUrl}/$jobId'),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'bearer $token');
    final response = await request.close();
    final responseText = await response.transform(utf8.decoder).join();
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
  } finally {
    client.close(force: true);
  }
}

Future<String> _defaultDownloadResult(Uri uri) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    final responseText = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PaddleOcrWaybillOcrException(
        '飞桨OCR下载结果失败: ${response.statusCode}',
      );
    }
    return responseText;
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
