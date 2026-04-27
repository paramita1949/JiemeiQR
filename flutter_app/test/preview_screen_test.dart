import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrscan_flutter/features/qr/preview_screen.dart';
import 'package:qrscan_flutter/models/qr_record.dart';

class MemoryQrSizeStore implements QrSizeStore {
  MemoryQrSizeStore(this.value);

  double? value;

  @override
  Future<double?> loadQrSize() async => value;

  @override
  Future<void> saveQrSize(double size) async {
    value = size;
  }
}

void main() {
  QrGroup group() => const QrGroup(
        prefix: 'JM',
        batch: 'ABCDEFG',
        suffix: 'TS',
        sourceSerial: '0000000001',
        startSerial: 1,
        count: 1,
        randomTailEnabled: false,
        randomTailDigits: 3,
      );

  Widget buildScreen(MemoryQrSizeStore store) {
    return MaterialApp(
      home: PreviewScreen(
        records: const [
          QrRecord(content: 'JM0000000001ABCDEFGTS', serial: '0000000001')
        ],
        scanIndex: 0,
        group: group(),
        initialAutoSlideSeconds: 1,
        qrSizeStore: store,
      ),
    );
  }

  testWidgets('loads and persists QR size from slider', (tester) async {
    final store = MemoryQrSizeStore(220);

    await tester.pumpWidget(buildScreen(store));
    await tester.pumpAndSettle();

    expect(tester.widget<QrImageView>(find.byType(QrImageView)).size, 220);
    expect(find.text('二维码大小 220'), findsOneWidget);

    await tester.drag(
        find.byKey(const Key('qrSizeSlider')), const Offset(200, 0));
    await tester.pumpAndSettle();

    expect(store.value, isNotNull);
    expect(store.value!, greaterThan(220));
  });
}
