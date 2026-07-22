import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef MultiModelHttpPost = Future<MultiModelHttpResponse> Function(
  Uri uri,
  Map<String, Object?> body,
  String token,
);

class MultiModelHttpResponse {
  const MultiModelHttpResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

class MultiModelVisionClient {
  MultiModelVisionClient({MultiModelHttpPost? httpPost})
      : _httpPost = httpPost ?? _defaultHttpPost;

  static final endpoint =
      Uri.parse('https://router.huggingface.co/v1/chat/completions');

  final MultiModelHttpPost _httpPost;

  Future<String> completeVision({
    required String token,
    required String model,
    required String prompt,
    required List<int> imageBytes,
  }) async {
    final normalizedToken = _normalizeToken(token);
    if (normalizedToken.isEmpty) {
      throw const MultiModelVisionException('缺少抱抱脸 Token');
    }
    final normalizedModel = model.trim();
    if (normalizedModel.isEmpty) {
      throw const MultiModelVisionException('缺少模型标识');
    }
    final mimeType = _imageMimeType(imageBytes);
    final response = await _httpPost(
      endpoint,
      {
        'model': normalizedModel,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:$mimeType;base64,${base64Encode(imageBytes)}',
                },
              },
            ],
          },
        ],
        'temperature': 0.0,
        'max_tokens': 4096,
      },
      normalizedToken,
    );
    final decoded = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MultiModelVisionException(
        _httpErrorMessage(response.statusCode, decoded),
      );
    }
    final error = decoded['error'];
    if (error is Map) {
      throw MultiModelVisionException(_apiErrorText(error));
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw const MultiModelVisionException('平台未返回识别结果');
    }
    final message = (choices.first as Map)['message'];
    final content = message is Map ? message['content']?.toString() ?? '' : '';
    final cleaned = _stripJsonFence(content);
    if (cleaned.isEmpty) {
      throw const MultiModelVisionException('平台返回文本为空');
    }
    return cleaned;
  }
}

class MultiModelVisionException implements Exception {
  const MultiModelVisionException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<MultiModelHttpResponse> _defaultHttpPost(
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
    return MultiModelHttpResponse(
      statusCode: response.statusCode,
      body: responseText,
    );
  } on SocketException catch (error) {
    throw MultiModelVisionException('平台网络异常：${error.message}');
  } on TimeoutException {
    throw const MultiModelVisionException('平台请求超时，请稍后重试');
  } finally {
    client.close(force: true);
  }
}

Map<String, Object?> _decodeObject(String text) {
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map) {
      return decoded.cast<String, Object?>();
    }
  } catch (_) {}
  return {'raw': text};
}

String _httpErrorMessage(int statusCode, Map<String, Object?> body) {
  return switch (statusCode) {
    401 => '访问令牌无效或无调用权限',
    402 => '平台额度不足',
    429 => '平台请求过于频繁，请稍后重试',
    _ => '平台请求失败（$statusCode）：${_errorText(body)}',
  };
}

String _errorText(Map<String, Object?> body) {
  final error = body['error'];
  if (error is Map) {
    return _apiErrorText(error);
  }
  final raw = body['raw']?.toString().trim() ?? '';
  return raw.isEmpty ? '未知错误' : raw;
}

String _apiErrorText(Map error) {
  final message = error['message']?.toString().trim() ?? '';
  return message.isEmpty ? '平台接口返回错误' : message;
}

String _normalizeToken(String raw) {
  final value = raw.trim();
  return value.toLowerCase().startsWith('bearer ')
      ? value.substring(7).trim()
      : value;
}

String _stripJsonFence(String raw) {
  var value = raw.trim();
  if (value.startsWith('```')) {
    value = value.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
    value = value.replaceFirst(RegExp(r'\s*```$'), '');
  }
  return value.trim();
}

String _imageMimeType(List<int> bytes) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46) {
    return 'image/gif';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  return 'image/jpeg';
}
