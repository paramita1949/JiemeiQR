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
    final fullText = _extractTextLines(jsonl).join('\n');
    if (fullText.trim().isEmpty) {
      throw const PaddleOcrWaybillOcrException('飞桨OCR未返回识别文本');
    }
    return parseWaybillOcrText(fullText: fullText);
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

  List<String> _extractTextLines(String jsonl) {
    final lines = <String>[];
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
      if (ocrResults is! List) {
        continue;
      }
      for (final item in ocrResults) {
        if (item is! Map) {
          continue;
        }
        final prunedResult = _mapValue(item, 'prunedResult');
        final recTexts = prunedResult['rec_texts'];
        if (recTexts is! List) {
          continue;
        }
        for (final text in recTexts) {
          final value = text?.toString().trim() ?? '';
          if (value.isNotEmpty) {
            lines.add(value);
          }
        }
      }
    }
    return lines;
  }
}

class PaddleOcrWaybillOcrException implements Exception {
  const PaddleOcrWaybillOcrException(this.message);

  final String message;

  @override
  String toString() => message;
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
