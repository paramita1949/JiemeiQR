import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/features/qr/qr_entry_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';

void main() {
  testWidgets('manual input shares the same parse and preview flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const QrEntryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('manualQrInputEntryButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('manualQrContentField')),
      '00720680088454517EL3FJEZ31',
    );
    await tester.tap(find.byKey(const Key('manualQrConfirmButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('EL3FJEZ'), findsWidgets);
  });
}
