import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/features/orders/ocr/merchant_name_matcher.dart';

void main() {
  test('uses historical short merchant name when OCR sees full company name',
      () {
    final result = resolveMerchantNameFromHistory(
      recognizedName: '上海上峰蒙悦商贸有限公司',
      historyNames: const ['上峰蒙悦', '太仓'],
    );

    expect(result, '上峰蒙悦');
  });

  test('keeps OCR merchant name when no unique historical short name matches',
      () {
    final result = resolveMerchantNameFromHistory(
      recognizedName: '上海上峰蒙悦商贸有限公司',
      historyNames: const ['上峰A', '上峰B'],
    );

    expect(result, '上海上峰蒙悦商贸有限公司');
  });
}
