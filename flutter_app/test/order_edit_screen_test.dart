import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';
import 'package:qrscan_flutter/features/orders/order_edit_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';

void main() {
  late AppDatabase database;
  late ProductDao productDao;
  late OrderDao orderDao;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    productDao = ProductDao(database);
    orderDao = OrderDao(database);
    await orderDao.createOrder(
      waybillNo: 'OLD-1',
      merchantName: '常用商家',
      orderDate: DateTime(2026, 4, 20),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Widget buildScreen() {
    return MaterialApp(
      theme: AppTheme.light(),
      home: OrderEditScreen(database: database),
    );
  }

  Future<void> seedProduct() async {
    final productId = await productDao.createProduct(
      code: '72067',
      name: '六神花露水195ML',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    await productDao.createBatch(
      productId: productId,
      actualBatch: 'FCHBLEZ',
      dateBatch: '2029.9.7',
      initialBoxes: 3477,
    );
  }

  testWidgets('shows merchant history and board calculation', (tester) async {
    await seedProduct();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('新增运单'), findsWidgets);
    expect(find.byKey(const Key('merchantHistoryDropdown')), findsOneWidget);
    expect(find.text('72067'), findsOneWidget);
    expect(find.text('FCHBLEZ 2029.9.7'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('boxesField')), '3477');
    await tester.pumpAndSettle();

    expect(find.text('可用 3477箱'), findsOneWidget);
    expect(find.text('需 86板+37箱'), findsOneWidget);
    final boardChipText = tester.widget<Text>(find.text('需 86板+37箱'));
    expect(boardChipText.style?.color, const Color(0xFFDC2626));
    expect(find.text('40箱/板 · 30件/箱'), findsOneWidget);
  });

  testWidgets('saves pending waybill from next button', (tester) async {
    await seedProduct();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('waybillNoField')), '168220019125');
    await tester.enterText(find.byKey(const Key('merchantNameField')), '常用商家');
    await tester.enterText(find.byKey(const Key('boxesField')), '320');
    await tester.scrollUntilVisible(
      find.byKey(const Key('nextWaybillButton')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nextWaybillButton')));
    await tester.pumpAndSettle();

    final order = await (database.select(database.orders)
          ..where((table) => table.waybillNo.equals('168220019125')))
        .getSingle();
    final item = await database.select(database.orderItems).getSingle();

    expect(order.waybillNo, '168220019125');
    expect(order.status, OrderStatus.pending);
    expect(item.boxes, 320);
    expect(find.text('已完成并清空，可录入下一单'), findsOneWidget);
  });

  testWidgets('waybill number must be filled manually without scan action',
      (tester) async {
    await seedProduct();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.byTooltip('扫描运单号'), findsNothing);
    expect(find.byKey(const Key('waybillQrContentField')), findsNothing);
  });

  testWidgets('does not show zero-box requirement before input',
      (tester) async {
    await seedProduct();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('需 0箱'), findsNothing);
    expect(find.text('需 --'), findsNothing);
  });

  testWidgets('sorts product selector by stock and marks TS products',
      (tester) async {
    final lowerStockProductId = await productDao.createProduct(
      code: '20584',
      name: '低库存产品',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    await productDao.createBatch(
      productId: lowerStockProductId,
      actualBatch: 'LOW',
      dateBatch: '2029.1.1',
      initialBoxes: 10,
    );
    final highStockProductId = await productDao.createProduct(
      code: '72067',
      name: '高库存扫码产品',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    await productDao.createBatch(
      productId: highStockProductId,
      actualBatch: 'HIGH-TS',
      dateBatch: '2029.1.2',
      initialBoxes: 100,
      tsRequired: true,
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('72067'), findsOneWidget);
    expect(find.text('可用 100箱'), findsOneWidget);
    expect(find.text('TS'), findsWidgets);
  });

  testWidgets('shows stock error when save becomes over-stock', (tester) async {
    await seedProduct();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('waybillNoField')), 'OVER-1');
    await tester.enterText(find.byKey(const Key('merchantNameField')), '常用商家');
    await tester.enterText(find.byKey(const Key('boxesField')), '3477');

    final stockDao = StockDao(database);
    final batch = await database.select(database.batches).getSingle();
    await stockDao.addMovement(
      batchId: batch.id,
      movementDate: DateTime.now(),
      type: StockMovementType.lossOut,
      boxes: 3477,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('nextWaybillButton')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('nextWaybillButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nextWaybillButton')));
    await tester.pumpAndSettle();

    expect(find.text('库存不足，无法保存运单'), findsOneWidget);
    expect(await database.select(database.orders).get(), hasLength(1));
  });

  testWidgets('duplicate product batch can be merged after confirmation',
      (tester) async {
    await seedProduct();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('waybillNoField')), 'DUP-1');
    await tester.enterText(find.byKey(const Key('merchantNameField')), '常用商家');
    await tester.enterText(find.byKey(const Key('boxesField')), '20');
    final continueButton = find.byKey(const Key('continueWaybillButton'));
    await tester.scrollUntilVisible(
      continueButton,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('boxesField')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('boxesField')), '20');
    await tester.ensureVisible(continueButton);
    await tester.pumpAndSettle();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('同一运单下该产品批号已添加，是否累加箱数？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '累加'));
    await tester.pumpAndSettle();

    expect(await database.select(database.orderItems).get(), hasLength(1));
    final mergedItem = await database.select(database.orderItems).getSingle();
    expect(mergedItem.boxes, 40);
  });

  testWidgets('shows appended lines and supports deleting single line',
      (tester) async {
    final productId = await productDao.createProduct(
      code: '72067',
      name: '六神花露水195ML',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    await productDao.createBatch(
      productId: productId,
      actualBatch: 'BATCH-LATE',
      dateBatch: '2029.9.7',
      initialBoxes: 100,
    );
    await productDao.createBatch(
      productId: productId,
      actualBatch: 'BATCH-EARLY',
      dateBatch: '2029.9.6',
      initialBoxes: 100,
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('waybillNoField')), 'WB-APPEND');
    await tester.enterText(find.byKey(const Key('merchantNameField')), '常用商家');
    await tester.enterText(find.byKey(const Key('boxesField')), '20');
    final continueButton = find.byKey(const Key('continueWaybillButton'));
    await tester.pumpAndSettle();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('已添加明细（1条 / 20箱）'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('已添加明细（1条 / 20箱）'), findsOneWidget);

    await tester.tap(find.byTooltip('删除该明细').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.textContaining('已添加明细'), findsNothing);
    final order = await (database.select(database.orders)
          ..where((table) => table.waybillNo.equals('WB-APPEND')))
        .getSingleOrNull();
    expect(order, isNull);
  });

  testWidgets('shows batch index reminder when same product date has two batches',
      (tester) async {
    final productId = await productDao.createProduct(
      code: 'FCHBMEZ',
      name: '测试产品',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    await productDao.createBatch(
      productId: productId,
      actualBatch: 'FCHBMEZ',
      dateBatch: '2029.9.7',
      initialBoxes: 100,
    );
    await productDao.createBatch(
      productId: productId,
      actualBatch: 'FCHBMEZ-ALT',
      dateBatch: '2029.9.7',
      initialBoxes: 80,
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('FCHBMEZ 2029.9.7 批号1'), findsOneWidget);
    await tester.tap(find.text('FCHBMEZ 2029.9.7 批号1'));
    await tester.pumpAndSettle();
    expect(find.text('FCHBMEZ-ALT 2029.9.7 批号2'), findsOneWidget);
  });

  testWidgets('does not show batch index when only one batch on date',
      (tester) async {
    await seedProduct();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('FCHBLEZ 2029.9.7'), findsOneWidget);
    expect(find.textContaining('批号1'), findsNothing);
  });

  testWidgets('end button saves current waybill and returns to home',
      (tester) async {
    await seedProduct();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OrderEditScreen(database: database),
                    ),
                  );
                },
                child: const Text('打开新增运单'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('打开新增运单'));
    await tester.pumpAndSettle();
    expect(find.text('新增运单'), findsWidgets);

    await tester.enterText(find.byKey(const Key('waybillNoField')), 'END-1');
    await tester.enterText(find.byKey(const Key('merchantNameField')), '常用商家');
    await tester.enterText(find.byKey(const Key('boxesField')), '20');

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('endWaybillButton')));
    await tester.pumpAndSettle();

    expect(find.text('打开新增运单'), findsOneWidget);
    final order = await (database.select(database.orders)
          ..where((table) => table.waybillNo.equals('END-1')))
        .getSingleOrNull();
    expect(order, isNotNull);
    expect(order!.status, OrderStatus.pending);
    final item = await (database.select(database.orderItems)
          ..where((table) => table.orderId.equals(order.id)))
        .getSingle();
    expect(item.boxes, 20);
  });
}
