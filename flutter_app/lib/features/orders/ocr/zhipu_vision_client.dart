import 'dart:convert';
import 'dart:io';

import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';

typedef ZhipuHttpPost = Future<ZhipuHttpResponse> Function(
  Uri uri,
  Map<String, Object?> body,
  String apiKey,
);

class ZhipuHttpResponse {
  const ZhipuHttpResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

class ZhipuVisionResult {
  const ZhipuVisionResult({
    required this.model,
    required this.content,
  });

  final String model;
  final String content;
}

class ZhipuVisionException implements Exception {
  const ZhipuVisionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ZhipuVisionClient {
  ZhipuVisionClient({
    required String apiKey,
    required String model,
    ZhipuHttpPost? httpPost,
  })  : _apiKey = _normalizeApiKey(apiKey),
        _model =
            model.trim().isEmpty ? AiOcrConfig.defaultZhipuModel : model.trim(),
        _httpPost = httpPost ?? _defaultHttpPost;

  static final Uri _completionUri = Uri.parse(
    'https://open.bigmodel.cn/api/paas/v4/chat/completions',
  );

  final String _apiKey;
  final String _model;
  final ZhipuHttpPost _httpPost;

  Future<ZhipuVisionResult> recognize(
    File image, {
    required String prompt,
  }) async {
    if (_apiKey.isEmpty) {
      throw const ZhipuVisionException('缺少智谱 API Key');
    }

    final imageBytes = await image.readAsBytes();
    final dataUrl =
        'data:${_imageMimeType(imageBytes)};base64,${base64Encode(imageBytes)}';
    final errors = <String>[];

    for (final currentModel in _modelAttempts(_model)) {
      final body = <String, Object?>{
        'model': currentModel,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {'url': dataUrl},
              },
              {
                'type': 'text',
                'text': prompt,
              },
            ],
          },
        ],
        'thinking': {
          'type': _usesThinking(currentModel) ? 'enabled' : 'disabled',
        },
        'stream': false,
      };

      try {
        final response = await _httpPost(_completionUri, body, _apiKey);
        final content = _parseResponse(response);
        return ZhipuVisionResult(model: currentModel, content: content);
      } on _RetryableZhipuVisionException catch (error) {
        errors.add('$currentModel: ${error.message}');
      } on ZhipuVisionException {
        rethrow;
      } catch (error) {
        errors.add('$currentModel: 网络请求失败（${error.runtimeType}）');
      }
    }

    throw ZhipuVisionException(
      '智谱视觉识别失败：${errors.join('；')}',
    );
  }

  String _parseResponse(ZhipuHttpResponse response) {
    final statusCode = response.statusCode;
    if (statusCode == HttpStatus.unauthorized ||
        statusCode == HttpStatus.forbidden) {
      throw const ZhipuVisionException('智谱 API Key 无效或无调用权限');
    }
    if (statusCode == HttpStatus.tooManyRequests) {
      throw const _RetryableZhipuVisionException('HTTP 429（限流或模型繁忙）');
    }
    if (statusCode >= HttpStatus.internalServerError) {
      throw _RetryableZhipuVisionException('HTTP $statusCode（服务暂不可用）');
    }

    final Map<String, Object?> payload;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException();
      }
      payload = Map<String, Object?>.from(decoded);
    } on FormatException {
      if (statusCode < HttpStatus.ok ||
          statusCode >= HttpStatus.multipleChoices) {
        throw ZhipuVisionException('智谱请求失败（HTTP $statusCode）');
      }
      throw const _RetryableZhipuVisionException('响应 JSON 格式无效');
    }

    final apiError = _apiError(payload);
    if (apiError != null) {
      final reason = _safeReason(apiError.message);
      final summary = [
        if (apiError.code.isNotEmpty) apiError.code,
        if (reason.isNotEmpty) reason,
      ].join('：');
      if (apiError.code == '1305' || _isRetryableMessage(apiError.message)) {
        throw _RetryableZhipuVisionException(
          summary.isEmpty ? '模型暂不可用' : summary,
        );
      }
      throw ZhipuVisionException(
        summary.isEmpty ? '智谱请求失败' : '智谱请求失败：$summary',
      );
    }

    if (statusCode < HttpStatus.ok ||
        statusCode >= HttpStatus.multipleChoices) {
      throw ZhipuVisionException('智谱请求失败（HTTP $statusCode）');
    }

    final choices = payload['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const _RetryableZhipuVisionException('未返回 choices');
    }
    final first = choices.first;
    if (first is! Map) {
      throw const _RetryableZhipuVisionException('返回 choice 格式无效');
    }
    final message = first['message'];
    if (message is! Map) {
      throw const _RetryableZhipuVisionException('未返回 message');
    }
    final content = message['content']?.toString().trim() ?? '';
    if (content.isEmpty) {
      throw const _RetryableZhipuVisionException('返回内容为空');
    }
    return _stripOuterJsonFence(content);
  }

  String _safeReason(String raw) {
    var value = raw.trim();
    if (_apiKey.isNotEmpty) {
      value = value.replaceAll(_apiKey, '[已隐藏]');
    }
    value = value.replaceAll(
      RegExp(
        r'data:image\/[^;\s]+;base64,[A-Za-z0-9+/_=-]+',
        caseSensitive: false,
      ),
      '[图片数据已隐藏]',
    );
    if (value.length > 160) {
      value = '${value.substring(0, 160)}…';
    }
    return value;
  }
}

class _RetryableZhipuVisionException implements Exception {
  const _RetryableZhipuVisionException(this.message);

  final String message;
}

class _ZhipuApiError {
  const _ZhipuApiError({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;
}

_ZhipuApiError? _apiError(Map<String, Object?> payload) {
  final nested = payload['error'];
  if (nested is Map) {
    return _ZhipuApiError(
      code: nested['code']?.toString().trim() ?? '',
      message: nested['message']?.toString().trim() ?? '',
    );
  }

  final code = payload['code']?.toString().trim() ?? '';
  final message = payload['message']?.toString().trim() ??
      payload['msg']?.toString().trim() ??
      '';
  if (code.isEmpty && message.isEmpty) {
    return null;
  }
  return _ZhipuApiError(code: code, message: message);
}

bool _isRetryableMessage(String message) {
  final normalized = message.toLowerCase();
  return normalized.contains('过载') ||
      normalized.contains('繁忙') ||
      normalized.contains('暂不可用') ||
      normalized.contains('稍后再试') ||
      normalized.contains('overload') ||
      normalized.contains('unavailable') ||
      normalized.contains('busy') ||
      normalized.contains('rate limit');
}

List<String> _modelAttempts(String primary) {
  return <String>[
    primary,
    ...AiOcrConfig.defaultZhipuModelPresets,
  ]
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .take(2)
      .toList();
}

bool _usesThinking(String model) {
  return model.trim().toLowerCase() == AiOcrConfig.zhipuThinkingModel;
}

String _normalizeApiKey(String raw) {
  final value = raw.trim();
  if (value.toLowerCase().startsWith('bearer ')) {
    return value.substring(7).trim();
  }
  return value;
}

String _imageMimeType(List<int> bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a) {
    return 'image/png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'image/jpeg';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return 'image/jpeg';
}

String _stripOuterJsonFence(String value) {
  final trimmed = value.trim();
  final match = RegExp(
    r'^```(?:json)?\s*([\s\S]*?)\s*```$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  return match?.group(1)?.trim() ?? trimmed;
}

Future<ZhipuHttpResponse> _defaultHttpPost(
  Uri uri,
  Map<String, Object?> body,
  String apiKey,
) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $apiKey',
    );
    request.write(jsonEncode(body));
    final response = await request.close();
    return ZhipuHttpResponse(
      statusCode: response.statusCode,
      body: await response.transform(utf8.decoder).join(),
    );
  } finally {
    client.close(force: true);
  }
}
