import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/features/orders/ocr/aliyun_waybill_ocr_service.dart';

void main() {
  test('calls Aliyun RecognizeGeneral with ACS3 signature', () async {
    final image = await File('${Directory.systemTemp.path}/aliyun-ocr.jpg')
        .writeAsBytes([1, 2, 3]);
    Uri? capturedUri;
    Map<String, String>? capturedHeaders;
    List<int>? capturedBody;
    final service = AliyunWaybillOcrService(
      accessKeyId: 'ak',
      accessKeySecret: 'secret',
      now: () => DateTime.utc(2026, 4, 30, 1, 2, 3),
      nonce: () => 'nonce-1',
      httpPost: (uri, headers, body) async {
        capturedUri = uri;
        capturedHeaders = headers;
        capturedBody = body;
        return jsonEncode({
          'Data': jsonEncode({
            'content':
                '0001686469\n上峰蒙悦\n2026-04-10\n72067 大桶花露水195ml FCHBLEZ 2029.06.22 15箱',
          }),
          'RequestId': 'request-1',
        });
      },
    );

    final result = await service.recognize(image);

    expect(capturedUri.toString(), 'https://ocr-api.cn-hangzhou.aliyuncs.com');
    expect(capturedHeaders?['x-acs-action'], 'RecognizeGeneral');
    expect(capturedHeaders?['x-acs-version'], '2021-07-07');
    expect(capturedHeaders?['authorization'], contains('ACS3-HMAC-SHA256'));
    expect(capturedHeaders?['content-type'], 'application/octet-stream');
    expect(capturedBody, [1, 2, 3]);
    expect(result.rows.single.productCode, '72067');
    expect(result.rows.single.actualBatch, 'FCHBLEZ');
    expect(result.rows.single.boxes, 15);
  });
}
