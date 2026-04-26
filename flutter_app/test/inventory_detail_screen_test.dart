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
      shippedBoxes: 20,
      remark: '随时修改',
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('库存明细'), findsWidgets);
    expect(find.text('总库存'), findsOneWidget);
    expect(find.text('2,400 件'), findsOneWidget);
    expect(find.text('72067 · FCHBLEZ · 2029.9.7'), findsOneWidget);
    expect(find.text('80箱'), findsOneWidget);
    expect(find.text('2板'), findsOneWidget);
    expect(find.text('40箱/板 · 30件/箱'), findsOneWidget);
    expect(find.text('已发过'), findsOneWidget);
    expect(find.text('随时修改'), findsOneWidget);
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

    expect(find.text('20380 · ELMAXEZ · 2029.6.14'), findsOneWidget);
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

  testWidgets('opens base info edit from inventory row', (tester) async {
    await seedBatch(
      code: '72067',
      batch: 'FCHBLEZ',
      dateBatch: '2029.9.7',
      initialBoxes: 100,
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('编辑资料').first);
    await tester.pumpAndSettle();

    expect(find.text('编辑基础资料'), findsOneWidget);
    expect(find.text('72067'), findsWidgets);
    expect(find.text('FCHBLEZ'), findsWidgets);
  });

}
