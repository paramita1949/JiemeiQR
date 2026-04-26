import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/features/base_info/base_info_edit_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Widget buildScreen() {
    return MaterialApp(
      theme: AppTheme.light(),
      home: BaseInfoEditScreen(database: database),
    );
  }

  testWidgets('saves product and batch information', (tester) async {
    await tester.pumpWidget(buildScreen());

    await tester.enterText(find.byKey(const Key('productCodeField')), '72067');
    await tester.enterText(
      find.byKey(const Key('productNameField')),
      '六神花露水195ML',
    );
    await tester.enterText(
        find.byKey(const Key('actualBatchField')), 'FCHBLEZ');
    await tester.enterText(find.byKey(const Key('dateBatchField')), '2029.9.7');
    expect(find.text('库存件数'), findsOneWidget);
    expect(find.text('库存箱数'), findsNothing);
    await tester.enterText(find.byKey(const Key('stockPiecesField')), '104310');
    await tester.enterText(find.byKey(const Key('boxesPerBoardField')), '40');
    await tester.enterText(find.byKey(const Key('piecesPerBoxField')), '30');
    await tester.enterText(find.byKey(const Key('locationField')), '4楼-后-右');
    await tester.enterText(find.byKey(const Key('remarkField')), '首批录入');

    await tester.scrollUntilVisible(
      find.byKey(const Key('saveBaseInfoButton')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('saveBaseInfoButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveBaseInfoButton')));
    await tester.pumpAndSettle();

    final product = await database.select(database.products).getSingle();
    final batch = await database.select(database.batches).getSingle();

    expect(product.code, '72067');
    expect(batch.initialBoxes, 3477);
    expect(batch.boxesPerBoard, 40);
    expect(batch.dateBatch, '2029.9.7');
    expect(batch.remark, '首批录入');
    expect(find.text('已保存基础资料'), findsOneWidget);
    expect(find.byKey(const Key('deleteBaseInfoButton')), findsNothing);
    expect(_fieldText(tester, const Key('productCodeField')), isEmpty);
    expect(_fieldText(tester, const Key('actualBatchField')), isEmpty);
    expect(_fieldText(tester, const Key('stockPiecesField')), isEmpty);
    expect(_fieldText(tester, const Key('boxesPerBoardField')), isEmpty);
    expect(_fieldText(tester, const Key('piecesPerBoxField')), isEmpty);
  });

  testWidgets('scan icon parses QR content into actual batch', (tester) async {
    await tester.pumpWidget(buildScreen());

    await tester.tap(find.byTooltip('扫码快速录入'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('quickQrContentField')),
      'JM720670000000001FCHBLEZ01',
    );
    await tester.tap(find.text('填入'));
    await tester.pumpAndSettle();

    expect(find.text('FCHBLEZ'), findsWidgets);
  });

  testWidgets('rejects nonpositive inventory and spec numbers', (tester) async {
    await tester.pumpWidget(buildScreen());

    await tester.enterText(find.byKey(const Key('productCodeField')), '72067');
    await tester.enterText(find.byKey(const Key('productNameField')), '六神花露水');
    await tester.enterText(
        find.byKey(const Key('actualBatchField')), 'FCHBLEZ');
    await tester.enterText(find.byKey(const Key('dateBatchField')), '2030.1.1');
    await tester.enterText(find.byKey(const Key('stockPiecesField')), '-1');
    await tester.enterText(find.byKey(const Key('boxesPerBoardField')), '0');
    await tester.enterText(find.byKey(const Key('piecesPerBoxField')), '0');

    await tester.scrollUntilVisible(
      find.byKey(const Key('saveBaseInfoButton')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('saveBaseInfoButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveBaseInfoButton')));
    await tester.pumpAndSettle();

    expect(find.text('请输入大于0的数字'), findsNWidgets(3));
    expect(await database.select(database.products).get(), isEmpty);
    expect(await database.select(database.batches).get(), isEmpty);
  });

  testWidgets('rejects stock pieces that are not whole boxes', (tester) async {
    await tester.pumpWidget(buildScreen());

    await tester.enterText(find.byKey(const Key('productCodeField')), '72067');
    await tester.enterText(find.byKey(const Key('productNameField')), '六神花露水');
    await tester.enterText(
        find.byKey(const Key('actualBatchField')), 'FCHBLEZ');
    await tester.enterText(find.byKey(const Key('dateBatchField')), '2030.1.1');
    await tester.enterText(find.byKey(const Key('stockPiecesField')), '101');
    await tester.enterText(find.byKey(const Key('piecesPerBoxField')), '30');

    await tester.scrollUntilVisible(
      find.byKey(const Key('saveBaseInfoButton')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('saveBaseInfoButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveBaseInfoButton')));
    await tester.pumpAndSettle();

    expect(find.text('库存件数必须是整箱'), findsOneWidget);
    expect(await database.select(database.products).get(), isEmpty);
    expect(await database.select(database.batches).get(), isEmpty);
  });

  testWidgets('continues same product while clearing batch-specific fields',
      (tester) async {
    await tester.pumpWidget(buildScreen());

    await tester.enterText(find.byKey(const Key('productCodeField')), '72067');
    await tester.enterText(find.byKey(const Key('productNameField')), '六神花露水');
    await tester.enterText(find.byKey(const Key('piecesPerBoxField')), '30');
    await tester.enterText(
        find.byKey(const Key('actualBatchField')), 'BATCH-A');
    await tester.enterText(find.byKey(const Key('dateBatchField')), '2030.1.1');
    await tester.enterText(find.byKey(const Key('stockPiecesField')), '1200');
    await tester.enterText(find.byKey(const Key('boxesPerBoardField')), '40');

    await tester.scrollUntilVisible(
      find.byKey(const Key('saveSameProductButton')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('saveSameProductButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveSameProductButton')));
    await tester.pumpAndSettle();

    expect(_fieldText(tester, const Key('productCodeField')), '72067');
    expect(_fieldText(tester, const Key('productNameField')), '六神花露水');
    expect(_fieldText(tester, const Key('piecesPerBoxField')), '30');
    expect(_fieldText(tester, const Key('actualBatchField')), isEmpty);
    expect(_fieldText(tester, const Key('stockPiecesField')), isEmpty);
    expect(_fieldText(tester, const Key('boxesPerBoardField')), isEmpty);

    await tester.enterText(
        find.byKey(const Key('actualBatchField')), 'BATCH-B');
    await tester.enterText(find.byKey(const Key('dateBatchField')), '2029.9.8');
    await tester.enterText(find.byKey(const Key('stockPiecesField')), '1140');
    await tester.enterText(find.byKey(const Key('boxesPerBoardField')), '38');
    await tester.tap(find.byKey(const Key('saveBaseInfoButton')));
    await tester.pumpAndSettle();

    final batches = await database.select(database.batches).get();
    expect(batches, hasLength(2));
    expect(batches.map((batch) => batch.boxesPerBoard), containsAll([40, 38]));
  });

  testWidgets('edits existing base info without creating new rows',
      (tester) async {
    final productId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            code: '72067',
            name: '六神花露水',
            boxesPerBoard: 40,
            piecesPerBox: 30,
          ),
        );
    final batchId = await database.into(database.batches).insert(
          BatchesCompanion.insert(
            productId: productId,
            actualBatch: 'BATCH-A',
            dateBatch: '2029.9.7',
            initialBoxes: 100,
            boxesPerBoard: 40,
            remark: const Value('旧备注'),
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: BaseInfoEditScreen(
          database: database,
          editingBatchId: batchId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_fieldText(tester, const Key('productCodeField')), '72067');
    expect(_fieldText(tester, const Key('actualBatchField')), 'BATCH-A');
    expect(_fieldText(tester, const Key('stockPiecesField')), '3000');

    await tester.enterText(find.byKey(const Key('productNameField')), '六神花露水新版');
    await tester.enterText(find.byKey(const Key('actualBatchField')), 'BATCH-B');
    await tester.enterText(find.byKey(const Key('dateBatchField')), '2029.9.8');
    await tester.enterText(find.byKey(const Key('stockPiecesField')), '3600');
    await tester.enterText(find.byKey(const Key('boxesPerBoardField')), '36');
    await tester.enterText(find.byKey(const Key('piecesPerBoxField')), '24');
    await tester.enterText(find.byKey(const Key('locationField')), '新库位');
    await tester.enterText(find.byKey(const Key('remarkField')), '新备注');

    await tester.scrollUntilVisible(
      find.byKey(const Key('saveBaseInfoButton')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('saveBaseInfoButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveBaseInfoButton')));
    await tester.pumpAndSettle();

    final products = await database.select(database.products).get();
    final batches = await database.select(database.batches).get();

    expect(products, hasLength(1));
    expect(batches, hasLength(1));
    expect(products.single.name, '六神花露水新版');
    expect(products.single.piecesPerBox, 24);
    expect(batches.single.id, batchId);
    expect(batches.single.actualBatch, 'BATCH-B');
    expect(batches.single.dateBatch, '2029.9.8');
    expect(batches.single.initialBoxes, 150);
    expect(batches.single.boxesPerBoard, 36);
    expect(batches.single.location, '新库位');
    expect(batches.single.remark, '新备注');
  });

  testWidgets('shows duplicate reminder and can cancel save', (tester) async {
    final productId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            code: '72067',
            name: '六神花露水',
            boxesPerBoard: 40,
            piecesPerBox: 30,
          ),
        );
    await database.into(database.batches).insert(
          BatchesCompanion.insert(
            productId: productId,
            actualBatch: 'FCHBLEZ',
            dateBatch: '2029.9.7',
            initialBoxes: 100,
            boxesPerBoard: 40,
          ),
        );

    await tester.pumpWidget(buildScreen());
    await tester.enterText(find.byKey(const Key('productCodeField')), '72067');
    await tester.enterText(find.byKey(const Key('productNameField')), '六神花露水');
    await tester.enterText(find.byKey(const Key('actualBatchField')), 'FCHBLEZ');
    await tester.enterText(find.byKey(const Key('dateBatchField')), '2029.9.7');
    await tester.enterText(find.byKey(const Key('stockPiecesField')), '3000');
    await tester.enterText(find.byKey(const Key('boxesPerBoardField')), '40');
    await tester.enterText(find.byKey(const Key('piecesPerBoxField')), '30');
    await tester.scrollUntilVisible(
      find.byKey(const Key('saveBaseInfoButton')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('saveBaseInfoButton')));
    await tester.pumpAndSettle();

    expect(find.text('重复批号提醒'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    final batches = await database.select(database.batches).get();
    expect(batches, hasLength(1));
  });

  testWidgets('shows duplicate reminder and can continue save', (tester) async {
    final productId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            code: '72067',
            name: '六神花露水',
            boxesPerBoard: 40,
            piecesPerBox: 30,
          ),
        );
    await database.into(database.batches).insert(
          BatchesCompanion.insert(
            productId: productId,
            actualBatch: 'FCHBLEZ',
            dateBatch: '2029.9.7',
            initialBoxes: 100,
            boxesPerBoard: 40,
          ),
        );

    await tester.pumpWidget(buildScreen());
    await tester.enterText(find.byKey(const Key('productCodeField')), '72067');
    await tester.enterText(find.byKey(const Key('productNameField')), '六神花露水');
    await tester.enterText(find.byKey(const Key('actualBatchField')), 'FCHBLEZ');
    await tester.enterText(find.byKey(const Key('dateBatchField')), '2029.9.7');
    await tester.enterText(find.byKey(const Key('stockPiecesField')), '3000');
    await tester.enterText(find.byKey(const Key('boxesPerBoardField')), '40');
    await tester.enterText(find.byKey(const Key('piecesPerBoxField')), '30');
    await tester.scrollUntilVisible(
      find.byKey(const Key('saveBaseInfoButton')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('saveBaseInfoButton')));
    await tester.pumpAndSettle();

    expect(find.text('重复批号提醒'), findsOneWidget);
    await tester.tap(find.text('继续保存'));
    await tester.pumpAndSettle();

    final batches = await database.select(database.batches).get();
    expect(batches, hasLength(2));
  });
}

String _fieldText(WidgetTester tester, Key key) {
  final field = tester.widget<TextFormField>(
    find.descendant(
      of: find.byKey(key),
      matching: find.byType(TextFormField),
    ),
  );
  return field.controller?.text ?? '';
}
