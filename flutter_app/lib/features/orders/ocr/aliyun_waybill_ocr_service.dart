import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_text_parser.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_photo_ocr_service.dart';

typedef AliyunHttpPost = Future<String> Function(
  Uri uri,
  Map<String, String> headers,
  List<int> body,
);

class AliyunWaybillOcrService implements WaybillPhotoOcrService {
  AliyunWaybillOcrService({
    String? accessKeyId,
    String? accessKeySecret,
    String? endpoint,
    FileAiConfigStore? configStore,
    AliyunHttpPost? httpPost,
    DateTime Function()? now,
    String Function()? nonce,
  })  : accessKeyId =
            accessKeyId ?? const String.fromEnvironment('ALIYUN_ACCESS_KEY_ID'),
        accessKeySecret = accessKeySecret ??
            const String.fromEnvironment('ALIYUN_ACCESS_KEY_SECRET'),
        endpoint = endpoint ??
            const String.fromEnvironment(
              'ALIYUN_ENDPOINT',
              defaultValue: AiOcrConfig.defaultAliyunEndpoint,
            ),
        _configStore = configStore ?? const FileAiConfigStore(),
        _httpPost = httpPost ?? _defaultHttpPost,
        _now = now ?? DateTime.now,
        _nonce = nonce ?? _defaultNonce;

  final String accessKeyId;
  final String accessKeySecret;
  final String endpoint;
  final FileAiConfigStore _configStore;
  final AliyunHttpPost _httpPost;
  final DateTime Function() _now;
  final String Function() _nonce;

  static const _action = 'RecognizeGeneral';
  static const _version = '2021-07-07';

  @override
  Future<WaybillOcrDraft> recognize(File image) async {
    final needsConfig = accessKeyId.trim().isEmpty ||
        accessKeySecret.trim().isEmpty ||
        endpoint.trim().isEmpty;
    final config = needsConfig ? await _configStore.load() : null;
    final effectiveAccessKeyId = accessKeyId.trim().isNotEmpty
        ? accessKeyId.trim()
        : config?.aliyunAccessKeyId.trim() ?? '';
    final effectiveAccessKeySecret = accessKeySecret.trim().isNotEmpty
        ? accessKeySecret.trim()
        : config?.aliyunAccessKeySecret.trim() ?? '';
    final effectiveEndpoint = endpoint.trim().isNotEmpty
        ? endpoint.trim()
        : config?.aliyunEndpoint.trim().isNotEmpty == true
            ? config!.aliyunEndpoint.trim()
            : AiOcrConfig.defaultAliyunEndpoint;
    if (effectiveAccessKeyId.isEmpty || effectiveAccessKeySecret.isEmpty) {
      throw const AliyunWaybillOcrException(
          '缺少阿里云 AccessKeyId 或 AccessKeySecret');
    }

    final bytes = await image.readAsBytes();
    final headers = _buildHeaders(
      body: bytes,
      accessKeyId: effectiveAccessKeyId,
      accessKeySecret: effectiveAccessKeySecret,
      endpoint: effectiveEndpoint,
      now: _now().toUtc(),
      nonce: _nonce(),
    );
    final responseText = await _httpPost(
      Uri.parse('https://$effectiveEndpoint'),
      headers,
      bytes,
    );
    return _parseResponse(responseText);
  }

  Map<String, String> _buildHeaders({
    required List<int> body,
    required String accessKeyId,
    required String accessKeySecret,
    required String endpoint,
    required DateTime now,
    required String nonce,
  }) {
    final contentHash = sha256.convert(body).toString();
    final signedHeaders = [
      'content-type',
      'host',
      'x-acs-action',
      'x-acs-content-sha256',
      'x-acs-date',
      'x-acs-signature-nonce',
      'x-acs-version',
    ];
    final headers = <String, String>{
      'content-type': 'application/octet-stream',
      'host': endpoint,
      'x-acs-action': _action,
      'x-acs-content-sha256': contentHash,
      'x-acs-date': _acsDate(now),
      'x-acs-signature-nonce': nonce,
      'x-acs-version': _version,
    };
    final canonicalHeaders =
        signedHeaders.map((name) => '$name:${headers[name]!.trim()}\n').join();
    final canonicalRequest = [
      'POST',
      '/',
      '',
      canonicalHeaders,
      signedHeaders.join(';'),
      contentHash,
    ].join('\n');
    final stringToSign =
        'ACS3-HMAC-SHA256\n${sha256.convert(utf8.encode(canonicalRequest))}';
    final signature = Hmac(sha256, utf8.encode(accessKeySecret))
        .convert(utf8.encode(stringToSign))
        .toString();
    headers['authorization'] =
        'ACS3-HMAC-SHA256 Credential=$accessKeyId,SignedHeaders=${signedHeaders.join(';')},Signature=$signature';
    return headers;
  }

  String _acsDate(DateTime utc) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${utc.year}-${two(utc.month)}-${two(utc.day)}T'
        '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}Z';
  }

  WaybillOcrDraft _parseResponse(String responseText) {
    final decoded = jsonDecode(responseText);
    if (decoded is! Map<String, Object?>) {
      throw const AliyunWaybillOcrException('阿里OCR返回格式无效');
    }
    final data = decoded['Data'];
    if (data == null) {
      final message = decoded['Message']?.toString() ?? '阿里OCR返回内容为空';
      throw AliyunWaybillOcrException(message);
    }
    final text = _extractText(data);
    return parseWaybillOcrText(fullText: text);
  }

  String _extractText(Object? data) {
    final lines = <String>[];
    void collect(Object? value) {
      if (value is String) {
        try {
          collect(jsonDecode(value));
        } catch (_) {
          lines.add(value);
        }
      } else if (value is Map) {
        const textKeys = ['content', 'text', 'word', 'words'];
        for (final key in textKeys) {
          final text = value[key]?.toString();
          if (text != null && text.trim().isNotEmpty) {
            lines.add(text.trim());
          }
        }
        for (final entry in value.entries) {
          if (!textKeys.contains(entry.key)) {
            collect(entry.value);
          }
        }
      } else if (value is List) {
        for (final child in value) {
          collect(child);
        }
      }
    }

    collect(data);
    return lines.join('\n');
  }
}

class AliyunWaybillOcrException implements Exception {
  const AliyunWaybillOcrException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<String> _defaultHttpPost(
  Uri uri,
  Map<String, String> headers,
  List<int> body,
) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(uri);
    headers.forEach(request.headers.set);
    request.add(body);
    final response = await request.close();
    final responseText = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AliyunWaybillOcrException('阿里OCR请求失败：${response.statusCode}');
    }
    return responseText;
  } finally {
    client.close(force: true);
  }
}

String _defaultNonce() => DateTime.now().microsecondsSinceEpoch.toString();
