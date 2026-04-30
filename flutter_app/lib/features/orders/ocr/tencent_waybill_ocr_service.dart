import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_photo_ocr_service.dart';

typedef TencentHttpPost = Future<String> Function(
  Uri uri,
  Map<String, String> headers,
  String body,
);

class TencentWaybillOcrService implements WaybillPhotoOcrService {
  TencentWaybillOcrService({
    String? secretId,
    String? secretKey,
    String? region,
    FileAiConfigStore? configStore,
    TencentHttpPost? httpPost,
    DateTime Function()? now,
  })  : secretId =
            secretId ?? const String.fromEnvironment('TENCENT_SECRET_ID'),
        secretKey =
            secretKey ?? const String.fromEnvironment('TENCENT_SECRET_KEY'),
        region = region ?? const String.fromEnvironment('TENCENT_REGION'),
        _configStore = configStore ?? const FileAiConfigStore(),
        _httpPost = httpPost ?? _defaultHttpPost,
        _now = now ?? DateTime.now;

  final String secretId;
  final String secretKey;
  final String region;
  final FileAiConfigStore _configStore;
  final TencentHttpPost _httpPost;
  final DateTime Function() _now;

  static const _host = 'ocr.tencentcloudapi.com';
  static const _service = 'ocr';
  static const _action = 'ExtractDocMulti';
  static const _version = '2018-11-19';
  static const _configId = 'SalesDeliveryNote';

  @override
  Future<WaybillOcrDraft> recognize(File image) async {
    final needsConfig =
        secretId.trim().isEmpty || secretKey.trim().isEmpty || region.isEmpty;
    final config = needsConfig ? await _configStore.load() : null;
    final effectiveSecretId = secretId.trim().isNotEmpty
        ? secretId.trim()
        : config?.tencentSecretId.trim() ?? '';
    final effectiveSecretKey = secretKey.trim().isNotEmpty
        ? secretKey.trim()
        : config?.tencentSecretKey.trim() ?? '';
    final effectiveRegion = region.trim().isNotEmpty
        ? region.trim()
        : config?.tencentRegion.trim().isNotEmpty == true
            ? config!.tencentRegion.trim()
            : AiOcrConfig.defaultTencentRegion;
    if (effectiveSecretId.isEmpty || effectiveSecretKey.isEmpty) {
      throw const TencentWaybillOcrException('缺少腾讯云 SecretId 或 SecretKey');
    }

    final body = jsonEncode({
      'ImageBase64': base64Encode(await image.readAsBytes()),
      'ConfigId': _configId,
      'ReturnFullText': true,
    });
    final now = _now().toUtc();
    final timestamp = now.millisecondsSinceEpoch ~/ 1000;
    final headers = _buildHeaders(
      body: body,
      secretId: effectiveSecretId,
      secretKey: effectiveSecretKey,
      region: effectiveRegion,
      timestamp: timestamp,
      date: _tc3Date(now),
    );
    final responseText = await _httpPost(
      Uri.parse('https://$_host'),
      headers,
      body,
    );
    return _parseResponse(responseText);
  }

  Map<String, String> _buildHeaders({
    required String body,
    required String secretId,
    required String secretKey,
    required String region,
    required int timestamp,
    required String date,
  }) {
    final payloadHash = sha256.convert(utf8.encode(body)).toString();
    final canonicalRequest = [
      'POST',
      '/',
      '',
      'content-type:application/json; charset=utf-8',
      'host:$_host',
      '',
      'content-type;host',
      payloadHash,
    ].join('\n');
    final credentialScope = '$date/$_service/tc3_request';
    final stringToSign = [
      'TC3-HMAC-SHA256',
      timestamp.toString(),
      credentialScope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');
    final secretDate = _hmac(utf8.encode('TC3$secretKey'), date);
    final secretService = _hmac(secretDate, _service);
    final secretSigning = _hmac(secretService, 'tc3_request');
    final signature = Hmac(sha256, secretSigning)
        .convert(utf8.encode(stringToSign))
        .toString();
    final authorization =
        'TC3-HMAC-SHA256 Credential=$secretId/$credentialScope, SignedHeaders=content-type;host, Signature=$signature';
    return {
      'Authorization': authorization,
      'Content-Type': 'application/json; charset=utf-8',
      'Host': _host,
      'X-TC-Action': _action,
      'X-TC-Version': _version,
      'X-TC-Timestamp': timestamp.toString(),
      'X-TC-Region': region,
    };
  }

  List<int> _hmac(List<int> key, String value) {
    return Hmac(sha256, key).convert(utf8.encode(value)).bytes;
  }

  String _tc3Date(DateTime utc) {
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    return '${utc.year}-$month-$day';
  }

  WaybillOcrDraft _parseResponse(String responseText) {
    final decoded = jsonDecode(responseText);
    if (decoded is! Map<String, Object?>) {
      throw const TencentWaybillOcrException('腾讯OCR返回格式无效');
    }
    final response = decoded['Response'];
    if (response is! Map<String, Object?>) {
      throw const TencentWaybillOcrException('腾讯OCR返回内容为空');
    }
    final error = response['Error'];
    if (error is Map) {
      final message = error['Message']?.toString() ?? '腾讯OCR请求失败';
      throw TencentWaybillOcrException(message);
    }
    final fields = <String, String>{};
    _collectKeyValues(response, fields);
    final fullText = _fullText(response);
    final rows = _parseRows(fields, fullText);
    return WaybillOcrDraft(
      waybillNo: _field(fields, const ['运单号', '通单号', '单号', '发货单号']),
      merchantName: _field(fields, const ['客户', '收货方', '经销商', '商家', '单位']),
      orderDateText: _field(fields, const ['日期', '单据日期', '发货日期']),
      rows: rows,
      warnings: const <String>[],
    );
  }

  void _collectKeyValues(Object? value, Map<String, String> fields) {
    if (value is Map) {
      final key = _firstText(value, const [
        'Name',
        'Key',
        'FieldName',
        'AutoName',
      ]);
      final text = _firstText(value, const [
        'Value',
        'Text',
        'FieldValue',
        'AutoContent',
      ]);
      if (key != null &&
          key.trim().isNotEmpty &&
          text != null &&
          text.trim().isNotEmpty) {
        fields[key.trim()] = text.trim();
      }
      for (final child in value.values) {
        _collectKeyValues(child, fields);
      }
    } else if (value is List) {
      for (final child in value) {
        _collectKeyValues(child, fields);
      }
    }
  }

  String? _firstText(Map value, List<String> keys) {
    for (final key in keys) {
      final child = value[key];
      final text = _textFrom(child, keys);
      if (text != null && text.trim().isNotEmpty) {
        return text.trim();
      }
    }
    return null;
  }

  String? _textFrom(Object? value, List<String> keys) {
    if (value == null) {
      return null;
    }
    if (value is String || value is num || value is bool) {
      return value.toString();
    }
    if (value is Map) {
      return _firstText(value, keys);
    }
    return null;
  }

  String _fullText(Map<String, Object?> response) {
    final direct = response['FullText']?.toString();
    if (direct != null && direct.trim().isNotEmpty) {
      return direct;
    }
    final lines = <String>[];
    void collect(Object? value) {
      if (value is Map) {
        final text = value['DetectedText']?.toString();
        if (text != null && text.trim().isNotEmpty) {
          lines.add(text.trim());
        }
        for (final child in value.values) {
          collect(child);
        }
      } else if (value is List) {
        for (final child in value) {
          collect(child);
        }
      }
    }

    collect(response);
    return lines.join('\n');
  }

  String _field(Map<String, String> fields, List<String> names) {
    for (final name in names) {
      for (final entry in fields.entries) {
        if (entry.key.contains(name)) {
          return entry.value;
        }
      }
    }
    return '';
  }

  List<WaybillOcrRow> _parseRows(Map<String, String> fields, String fullText) {
    final rows = <WaybillOcrRow>[];
    final text = '${fields.values.join('\n\n')}\n\n$fullText';
    final linePattern = RegExp(
      r'(\d{4,6})\s+(.+?)\s+([A-Z0-9]{5,})\s+(\d{4}[.\-/年]\d{1,2}[.\-/月]\d{1,2}日?)\s+(\d+)\s*箱?',
      caseSensitive: false,
    );
    for (final match in linePattern.allMatches(text)) {
      rows.add(
        WaybillOcrRow(
          productCode: match.group(1) ?? '',
          productName: (match.group(2) ?? '').trim(),
          actualBatch: (match.group(3) ?? '').trim(),
          dateBatch: (match.group(4) ?? '').trim(),
          boxes: int.tryParse(match.group(5) ?? '') ?? 0,
        ),
      );
    }
    return rows;
  }
}

class TencentWaybillOcrException implements Exception {
  const TencentWaybillOcrException(this.message);

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
      throw TencentWaybillOcrException('腾讯OCR请求失败：${response.statusCode}');
    }
    return responseText;
  } finally {
    client.close(force: true);
  }
}
