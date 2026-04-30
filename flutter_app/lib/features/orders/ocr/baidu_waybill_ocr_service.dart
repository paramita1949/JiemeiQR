import 'dart:convert';
import 'dart:io';

import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_text_parser.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_photo_ocr_service.dart';

typedef BaiduHttpPost = Future<String> Function(
  Uri uri,
  Map<String, String> headers,
  String body,
);

class BaiduWaybillOcrService implements WaybillPhotoOcrService {
  BaiduWaybillOcrService({
    String? apiKey,
    String? secretKey,
    FileAiConfigStore? configStore,
    BaiduHttpPost? httpPost,
  })  : apiKey = apiKey ?? const String.fromEnvironment('BAIDU_API_KEY'),
        secretKey =
            secretKey ?? const String.fromEnvironment('BAIDU_SECRET_KEY'),
        _configStore = configStore ?? const FileAiConfigStore(),
        _httpPost = httpPost ?? _defaultHttpPost;

  final String apiKey;
  final String secretKey;
  final FileAiConfigStore _configStore;
  final BaiduHttpPost _httpPost;

  @override
  Future<WaybillOcrDraft> recognize(File image) async {
    final needsConfig = apiKey.trim().isEmpty || secretKey.trim().isEmpty;
    final config = needsConfig ? await _configStore.load() : null;
    final effectiveApiKey = apiKey.trim().isNotEmpty
        ? apiKey.trim()
        : config?.baiduApiKey.trim() ?? '';
    final effectiveSecretKey = secretKey.trim().isNotEmpty
        ? secretKey.trim()
        : config?.baiduSecretKey.trim() ?? '';
    if (effectiveApiKey.isEmpty || effectiveSecretKey.isEmpty) {
      throw const BaiduWaybillOcrException('缺少百度 OCR API Key 或 Secret Key');
    }

    final token = await _accessToken(effectiveApiKey, effectiveSecretKey);
    final body =
        'image=${Uri.encodeQueryComponent(base64Encode(await image.readAsBytes()))}';
    final responseText = await _httpPost(
      Uri.parse(
        'https://aip.baidubce.com/rest/2.0/ocr/v1/general_basic?access_token=$token',
      ),
      const {'Content-Type': 'application/x-www-form-urlencoded'},
      body,
    );
    return _parseResponse(responseText);
  }

  Future<String> _accessToken(String key, String secret) async {
    final uri = Uri.https('aip.baidubce.com', '/oauth/2.0/token', {
      'grant_type': 'client_credentials',
      'client_id': key,
      'client_secret': secret,
    });
    final responseText = await _httpPost(uri, const {}, '');
    final decoded = jsonDecode(responseText);
    if (decoded is Map<String, Object?>) {
      final token = decoded['access_token']?.toString();
      if (token != null && token.isNotEmpty) {
        return token;
      }
      final message = decoded['error_description']?.toString() ??
          decoded['error']?.toString() ??
          '百度OCR获取 access_token 失败';
      throw BaiduWaybillOcrException(message);
    }
    throw const BaiduWaybillOcrException('百度OCR授权返回格式无效');
  }

  WaybillOcrDraft _parseResponse(String responseText) {
    final decoded = jsonDecode(responseText);
    if (decoded is! Map<String, Object?>) {
      throw const BaiduWaybillOcrException('百度OCR返回格式无效');
    }
    final error = decoded['error_msg']?.toString();
    if (error != null && error.isNotEmpty) {
      throw BaiduWaybillOcrException(error);
    }
    final lines = <String>[];
    final words = decoded['words_result'];
    if (words is List) {
      for (final item in words) {
        if (item is Map) {
          final text = item['words']?.toString();
          if (text != null && text.trim().isNotEmpty) {
            lines.add(text.trim());
          }
        }
      }
    }
    return parseWaybillOcrText(fullText: lines.join('\n'));
  }
}

class BaiduWaybillOcrException implements Exception {
  const BaiduWaybillOcrException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<String> _defaultHttpPost(
  Uri uri,
  Map<String, String> headers,
  String body,
) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(uri);
    headers.forEach(request.headers.set);
    request.write(body);
    final response = await request.close();
    final responseText = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BaiduWaybillOcrException('百度OCR请求失败：${response.statusCode}');
    }
    return responseText;
  } finally {
    client.close(force: true);
  }
}
