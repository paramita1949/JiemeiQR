import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';
import 'package:qrscan_flutter/features/orders/ocr/gemini_waybill_ocr_service.dart';

void main() {
  test('sends waybill photo to Gemini with OCR-only schema prompt', () async {
    final image = await File('${Directory.systemTemp.path}/ocr-test.jpg')
        .writeAsBytes([1, 2, 3]);
    Uri? capturedUri;
    Map<String, Object?>? capturedBody;

    final service = GeminiWaybillOcrService(
      apiKey: 'test-key',
      httpPost: (uri, body) async {
        capturedUri = uri;
        capturedBody = body;
        return jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({
                      'waybillNo': '0001686469',
                      'merchantName': '上峰蒙悦',
                      'orderDate': '2026-04-10',
                      'rows': [
                        {
                          'productCode': '72067',
                          'productName': '大桶花露水195ml',
                          'actualBatch': 'FCHBLEZ',
                          'dateBatch': '2029.06.22',
                          'boxes': 15,
                        }
                      ],
                    }),
                  }
                ],
              },
            }
          ],
        });
      },
    );

    final result = await service.recognize(image);

    expect(capturedUri.toString(), contains('gemini-3-flash-preview'));
    final bodyText = jsonEncode(capturedBody);
    expect(bodyText, contains('只做OCR'));
    expect(bodyText, contains('不要推理'));
    expect(bodyText, contains('inlineData'));
    expect(result.waybillNo, '0001686469');
    expect(result.rows.single.actualBatch, 'FCHBLEZ');
    expect(result.rows.single.boxes, 15);
  });

  test('throws clear error when Gemini key is missing', () async {
    final image = await File('${Directory.systemTemp.path}/ocr-missing-key.jpg')
        .writeAsBytes([1, 2, 3]);
    final dir = await Directory.systemTemp.createTemp('ocr-empty-config-');
    final service = GeminiWaybillOcrService(
      apiKey: '',
      configStore: FileAiConfigStore(
        settingsFileProvider: () async => File('${dir.path}/ai_config.json'),
      ),
    );

    expect(
      () => service.recognize(image),
      throwsA(isA<GeminiWaybillOcrException>()),
    );
  });

  test('uses saved Gemini config when constructor key is empty', () async {
    final image = await File('${Directory.systemTemp.path}/ocr-config-key.jpg')
        .writeAsBytes([1, 2, 3]);
    final dir = await Directory.systemTemp.createTemp('ocr-config-');
    final store = FileAiConfigStore(
      settingsFileProvider: () async => File('${dir.path}/ai_config.json'),
    );
    await store.save(
      const AiOcrConfig(
        provider: AiOcrConfig.defaultProvider,
        geminiApiKey: 'saved-key',
        geminiModel: 'gemini-2.5-flash',
        tencentSecretId: '',
        tencentSecretKey: '',
        tencentRegion: AiOcrConfig.defaultTencentRegion,
        aliyunAccessKeyId: '',
        aliyunAccessKeySecret: '',
        aliyunEndpoint: AiOcrConfig.defaultAliyunEndpoint,
        baiduApiKey: '',
        baiduSecretKey: '',
      ),
    );
    Uri? capturedUri;

    final service = GeminiWaybillOcrService(
      apiKey: '',
      configStore: store,
      httpPost: (uri, body) async {
        capturedUri = uri;
        return jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({
                      'waybillNo': '',
                      'merchantName': '',
                      'orderDate': '',
                      'rows': [],
                      'warnings': [],
                    }),
                  }
                ],
              },
            }
          ],
        });
      },
    );

    await service.recognize(image);

    expect(capturedUri.toString(), contains('gemini-2.5-flash'));
    expect(capturedUri?.queryParameters['key'], 'saved-key');
  });
}
