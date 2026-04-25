import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/main.dart';

void main() {
  testWidgets('app renders home actions', (tester) async {
    await tester.pumpWidget(const QrScanApp());

    expect(find.text('箱贴二维码'), findsOneWidget);
    expect(find.text('开始扫描（相机）'), findsOneWidget);
    expect(find.text('本地图片识别'), findsOneWidget);
  });
}
