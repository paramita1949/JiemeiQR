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
    expect(find.text('常用商家'), findsOneWidget);
    expect(find.text('72067'), findsOneWidget);
    expect(find.text('FCHBLEZ · 2029.9.7'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('boxesField')), '3477');
    await tester.pumpAndSettle();

    expect(find.text('可用 3477箱'), findsOneWidget);
    expect(find.text('需 86板+37箱'), findsOneWidget);
    expect(find.text('40箱/板 · 30件/箱'), findsOneWidget);
  });

  testWidgets('saves pending waybill from finish button', (tester) async {
    await seedProduct();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('waybillNoField')), '168220019125');
    await tester.enterText(find.byKey(const Key('merchantNameField')), '常用商家');
    await tester.enterText(find.byKey(const Key('boxesField')), '320');
    await tester.scrollUntilVisible(
      find.byKey(const Key('finishWaybillButton')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('finishWaybillButton')));
    await tester.pumpAndSettle();

    final order = await (database.select(database.orders)
          ..where((table) => table.waybillNo.equals('168220019125')))
        .getSingle();
    final item = await database.select(database.orderItems).getSingle();

    expect(order.waybillNo, '168220019125');
    expect(order.status, OrderStatus.pending);
    expect(item.boxes, 320);
    expect(find.text('已保存运单'), findsOneWidget);
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
      find.byKey(const Key('finishWaybillButton')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('finishWaybillButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('finishWaybillButton')));
    await tester.pumpAndSettle();

    expect(find.text('库存不足，无法保存运单'), findsOneWidget);
    expect(await database.select(database.orders).get(), hasLength(1));
  });
}
