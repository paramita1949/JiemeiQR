import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/features/orders/ocr/baidu_waybill_ocr_service.dart';

void main() {
  test('gets Baidu token then calls general_basic OCR', () async {
    final image = await File('${Directory.systemTemp.path}/baidu-ocr.jpg')
        .writeAsBytes([1, 2, 3]);
    Uri? tokenUri;
    Uri? ocrUri;
    Map<String, String>? ocrHeaders;
    String? ocrBody;
    final service = BaiduWaybillOcrService(
      apiKey: 'api',
      secretKey: 'secret',
      httpPost: (uri, headers, body) async {
        if (uri.path.endsWith('/oauth/2.0/token')) {
          tokenUri = uri;
          return jsonEncode({'access_token': 'token-1'});
        }
        ocrUri = uri;
        ocrHeaders = headers;
        ocrBody = body;
        return jsonEncode({
          'words_result': [
            {'words': '0001686469'},
            {'words': '上峰蒙悦'},
            {'words': '2026-04-10'},
            {'words': '72067 大桶花露水195ml FCHBLEZ 2029.06.22 15箱'},
          ],
        });
      },
    );

    final result = await service.recognize(image);

    expect(tokenUri?.queryParameters['grant_type'], 'client_credentials');
    expect(tokenUri?.queryParameters['client_id'], 'api');
    expect(tokenUri?.queryParameters['client_secret'], 'secret');
    expect(ocrUri.toString(), contains('/rest/2.0/ocr/v1/general_basic'));
    expect(ocrUri?.queryParameters['access_token'], 'token-1');
    expect(ocrHeaders?['Content-Type'], 'application/x-www-form-urlencoded');
    expect(ocrBody,
        contains('image=${Uri.encodeQueryComponent(base64Encode([1, 2, 3]))}'));
    expect(result.rows.single.productCode, '72067');
    expect(result.rows.single.boxes, 15);
  });
}
