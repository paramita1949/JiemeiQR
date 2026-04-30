import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';
import 'package:qrscan_flutter/features/orders/ocr/tencent_waybill_ocr_service.dart';

void main() {
  test('calls Tencent ExtractDocMulti with SalesDeliveryNote config', () async {
    final image = await File('${Directory.systemTemp.path}/tencent-ocr.jpg')
        .writeAsBytes([1, 2, 3]);
    Uri? capturedUri;
    Map<String, String>? capturedHeaders;
    String? capturedBody;
    final service = TencentWaybillOcrService(
      secretId: 'sid',
      secretKey: 'skey',
      region: 'ap-guangzhou',
      now: () => DateTime.utc(2026, 4, 30, 1, 2, 3),
      httpPost: (uri, headers, body) async {
        capturedUri = uri;
        capturedHeaders = headers;
        capturedBody = body;
        return jsonEncode({
          'Response': {
            'FullText':
                '0001686469\n上峰蒙悦\n2026-04-10\n72067 大桶花露水195ml FCHBLEZ 2029.06.22 15箱',
            'RequestId': 'request-1',
          },
        });
      },
    );

    final result = await service.recognize(image);

    expect(capturedUri.toString(), 'https://ocr.tencentcloudapi.com');
    expect(capturedHeaders?['X-TC-Action'], 'ExtractDocMulti');
    expect(capturedHeaders?['X-TC-Version'], '2018-11-19');
    expect(capturedHeaders?['X-TC-Region'], 'ap-guangzhou');
    expect(capturedHeaders?['Authorization'], contains('TC3-HMAC-SHA256'));
    final body = jsonDecode(capturedBody!) as Map<String, Object?>;
    expect(body['ConfigId'], 'SalesDeliveryNote');
    expect(body['ImageBase64'], base64Encode([1, 2, 3]));
    expect(result.rows.single.productCode, '72067');
    expect(result.rows.single.actualBatch, 'FCHBLEZ');
    expect(result.rows.single.boxes, 15);
  });

  test('uses saved Tencent credentials', () async {
    final dir = await Directory.systemTemp.createTemp('tencent-config-');
    final store = FileAiConfigStore(
      settingsFileProvider: () async => File('${dir.path}/ai_config.json'),
    );
    await store.save(
      const AiOcrConfig(
        provider: AiOcrConfig.tencentProvider,
        geminiApiKey: '',
        geminiModel: AiOcrConfig.defaultModel,
        tencentSecretId: 'saved-id',
        tencentSecretKey: 'saved-key',
        tencentRegion: 'ap-shanghai',
      ),
    );
    final image = await File('${Directory.systemTemp.path}/tencent-config.jpg')
        .writeAsBytes([1]);
    Map<String, String>? capturedHeaders;
    final service = TencentWaybillOcrService(
      secretId: '',
      secretKey: '',
      configStore: store,
      httpPost: (uri, headers, body) async {
        capturedHeaders = headers;
        return jsonEncode({
          'Response': {'RequestId': 'request-2'}
        });
      },
    );

    await service.recognize(image);

    expect(capturedHeaders?['X-TC-Region'], 'ap-shanghai');
    expect(
      capturedHeaders?['Authorization'],
      contains('Credential=saved-id/'),
    );
  });

  test('parses Tencent structural AutoName and AutoContent fields', () async {
    final image = await File('${Directory.systemTemp.path}/tencent-fields.jpg')
        .writeAsBytes([1]);
    final service = TencentWaybillOcrService(
      secretId: 'sid',
      secretKey: 'skey',
      region: 'ap-guangzhou',
      httpPost: (uri, headers, body) async {
        return jsonEncode({
          'Response': {
            'StructuralList': [
              {
                'Groups': [
                  {
                    'Lines': [
                      {
                        'Key': {'AutoName': '发货单号'},
                        'Value': {'AutoContent': '0001686469'},
                      },
                      {
                        'Key': {'AutoName': '经销商'},
                        'Value': {'AutoContent': '上峰蒙悦'},
                      },
                      {
                        'Key': {'AutoName': '发货日期'},
                        'Value': {'AutoContent': '2026-04-10'},
                      },
                    ],
                  },
                ],
              },
            ],
            'WordList': [
              {
                'DetectedText': '72067 大桶花露水195ml FCHBLEZ 2029.06.22 15箱',
              },
            ],
            'RequestId': 'request-3',
          },
        });
      },
    );

    final result = await service.recognize(image);

    expect(result.waybillNo, '0001686469');
    expect(result.merchantName, '上峰蒙悦');
    expect(result.orderDateText, '2026-04-10');
    expect(result.rows.single.productCode, '72067');
  });
}
