import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';
import 'package:qrscan_flutter/features/inventory/inventory_detail_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';

void main() {
  late AppDatabase database;
  late ProductDao productDao;
  late StockDao stockDao;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    productDao = ProductDao(database);
    stockDao = StockDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  Widget buildScreen() {
    return MaterialApp(
      theme: AppTheme.light(),
      home: InventoryDetailScreen(database: database),
    );
  }

  Future<int> seedBatch({
    required String code,
    required String batch,
    required String dateBatch,
    required int initialBoxes,
    bool tsRequired = false,
    int shippedBoxes = 0,
    String? remark,
  }) async {
    final productId = await productDao.createProduct(
      code: code,
      name: '六神花露水',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    final batchId = await productDao.createBatch(
      productId: productId,
      actualBatch: batch,
      dateBatch: dateBatch,
      initialBoxes: initialBoxes,
      tsRequired: tsRequired,
      remark: remark,
    );
    if (shippedBoxes > 0) {
      await stockDao.addMovement(
        batchId: batchId,
        movementDate: DateTime(2026, 4, 26),
        type: StockMovementType.orderOut,
        boxes: shippedBoxes,
      );
    }
    return batchId;
  }

  testWidgets('shows inventory detail rows with pieces-only total',
      (tester) async {
    await seedBatch(
      code: '72067',
      batch: 'FCHBLEZ',
      dateBatch: '2029.9.7',
      initialBoxes: 100,
      tsRequired: true,
      shippedBoxes: 20,
      remark: '随时修改',
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inventory-group-72067')));
    await tester.pumpAndSettle();

    expect(find.text('库存明细'), findsWidgets);
    expect(find.text('总库存'), findsOneWidget);
    expect(find.text('2,400 件'), findsOneWidget);
    expect(find.text('72067 · FCHBLEZ'), findsOneWidget);
    expect(find.text('2029.9.7'), findsOneWidget);
    expect(find.text('80箱'), findsOneWidget);
    expect(find.text('2板'), findsOneWidget);
    expect(find.text('40箱/板 · 30件/箱'), findsOneWidget);
    expect(find.text('TS'), findsOneWidget);
    expect(find.text('已发过'), findsOneWidget);
    expect(find.text('随时修改'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('2029.9.7')).style?.color,
      const Color(0xFFB91C1C),
    );
    expect(
      tester.widget<Text>(find.text('已发过')).style?.color,
      const Color(0xFFB91C1C),
    );
  });

  testWidgets('filters zero stock rows and edits remark inline',
      (tester) async {
    final batchId = await seedBatch(
      code: '20380',
      batch: 'ELMAXEZ',
      dateBatch: '2029.6.14',
      initialBoxes: 50,
      shippedBoxes: 50,
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('零库存'));
    await tester.pumpAndSettle();

    final batchFinder = find.text('20380 · ELMAXEZ');
    for (var i = 0; i < 2; i += 1) {
      if (batchFinder.evaluate().isNotEmpty) {
        break;
      }
      await tester.tap(find.byKey(const Key('inventory-group-20380')));
      await tester.pumpAndSettle();
    }

    expect(find.text('20380 · ELMAXEZ'), findsOneWidget);
    expect(find.text('2029.6.14'), findsOneWidget);
    expect(find.text('已空'), findsOneWidget);

    await tester.tap(find.byTooltip('编辑备注').first);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('inventoryRemarkField')), '临时备注');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final batchRecord = await (database.select(database.batches)
          ..where((table) => table.id.equals(batchId)))
        .getSingle();
    expect(batchRecord.remark, '临时备注');
  });

  testWidgets('sorts same product by earlier date first', (tester) async {
    await seedBatch(
      code: '72067',
      batch: 'BATCH-LATE',
      dateBatch: '2029.9.7',
      initialBoxes: 10,
    );
    await seedBatch(
      code: '72067',
      batch: 'BATCH-EARLY',
      dateBatch: '2029.9.6',
      initialBoxes: 10,
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inventory-group-72067')));
    await tester.pumpAndSettle();

    final earlyY = tester.getTopLeft(find.text('2029.9.6')).dy;
    final lateY = tester.getTopLeft(find.text('2029.9.7')).dy;
    expect(earlyY, lessThan(lateY));
  });

  testWidgets('groups rows by product code', (tester) async {
    await seedBatch(
      code: '72067',
      batch: 'A-BATCH',
      dateBatch: '2029.9.6',
      initialBoxes: 10,
    );
    await seedBatch(
      code: '20380',
      batch: 'B-BATCH',
      dateBatch: '2029.9.7',
      initialBoxes: 10,
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('20380'), findsWidgets);
    expect(find.text('72067'), findsWidgets);
    final y20380 =
        tester.getTopLeft(find.byKey(const Key('inventory-group-20380'))).dy;
    final y72067 =
        tester.getTopLeft(find.byKey(const Key('inventory-group-72067'))).dy;
    expect(y20380, lessThan(y72067));
    expect(find.text('TS'), findsNothing);
  });

  testWidgets('group header shows aggregated pieces and boxes', (tester) async {
    await seedBatch(
      code: '72067',
      batch: 'BATCH-A',
      dateBatch: '2029.9.6',
      initialBoxes: 10,
    );
    await seedBatch(
      code: '72067',
      batch: 'BATCH-B',
      dateBatch: '2029.9.7',
      initialBoxes: 5,
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('450件 · 15箱'), findsOneWidget);
  });

  testWidgets('group header collapses and expands rows', (tester) async {
    await seedBatch(
      code: '72067',
      batch: 'BATCH-A',
      dateBatch: '2029.9.6',
      initialBoxes: 10,
    );
    await seedBatch(
      code: '72067',
      batch: 'BATCH-B',
      dateBatch: '2029.9.7',
      initialBoxes: 5,
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.textContaining('BATCH-A'), findsNothing);
    expect(find.textContaining('BATCH-B'), findsNothing);

    await tester.tap(find.byKey(const Key('inventory-group-72067')));
    await tester.pumpAndSettle();

    expect(find.textContaining('BATCH-A'), findsOneWidget);
    expect(find.textContaining('BATCH-B'), findsOneWidget);

    await tester.tap(find.byKey(const Key('inventory-group-72067')));
    await tester.pumpAndSettle();
    expect(find.textContaining('BATCH-A'), findsNothing);
    expect(find.textContaining('BATCH-B'), findsNothing);
  });

  testWidgets('opens base info edit from inventory row', (tester) async {
    await seedBatch(
      code: '72067',
      batch: 'FCHBLEZ',
      dateBatch: '2029.9.7',
      initialBoxes: 100,
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inventory-group-72067')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('编辑资料').first);
    await tester.pumpAndSettle();

    expect(find.text('编辑基础资料'), findsOneWidget);
    expect(find.text('72067'), findsWidgets);
    expect(find.text('FCHBLEZ'), findsWidgets);
  });

  testWidgets('deletes batch directly from inventory row', (tester) async {
    final batchId = await seedBatch(
      code: '72067',
      batch: 'DEL-BATCH',
      dateBatch: '2029.9.7',
      initialBoxes: 50,
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inventory-group-72067')));
    await tester.pumpAndSettle();

    expect(find.textContaining('DEL-BATCH'), findsOneWidget);
    await tester.tap(find.byTooltip('删除批号').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.textContaining('已删除当前批号'), findsOneWidget);
    final deleted = await (database.select(database.batches)
          ..where((table) => table.id.equals(batchId)))
        .getSingleOrNull();
    expect(deleted, isNull);
  });
}
