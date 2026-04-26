import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';
import 'package:qrscan_flutter/features/orders/order_detail_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';

void main() {
  late AppDatabase database;
  late ProductDao productDao;
  late OrderDao orderDao;
  late StockDao stockDao;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    productDao = ProductDao(database);
    orderDao = OrderDao(database);
    stockDao = StockDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  Widget buildScreen(int orderId) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: OrderDetailScreen(database: database, orderId: orderId),
    );
  }

  Future<int> seedOrder() async {
    final productId = await productDao.createProduct(
      code: '72067',
      name: '六神花露水195ML',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    final batchId = await productDao.createBatch(
      productId: productId,
      actualBatch: 'FCHBLEZ',
      dateBatch: '2029.9.7',
      initialBoxes: 100,
      tsRequired: true,
    );
    return orderDao.createPendingWaybill(
      waybillNo: '168220019125',
      merchantName: '洁美A',
      orderDate: DateTime(2026, 4, 26),
      item: PendingOrderItemInput(
        productId: productId,
        batchId: batchId,
        boxes: 20,
        boxesPerBoard: 40,
        piecesPerBox: 30,
      ),
    );
  }

  testWidgets('shows order detail and marks picked', (tester) async {
    final orderId = await seedOrder();

    await tester.pumpWidget(buildScreen(orderId));
    await tester.pumpAndSettle();

    expect(find.text('168220019125'), findsOneWidget);
    expect(find.text('洁美A'), findsOneWidget);
    expect(find.text('未完成'), findsWidgets);
    expect(find.text('72067 · FCHBLEZ · 2029.9.7'), findsOneWidget);
    expect(find.text('20箱'), findsWidgets);
    expect(find.text('40箱/板 · 30件/箱'), findsOneWidget);
    expect(find.text('TS'), findsOneWidget);

    await tester.tap(find.text('已拣货'));
    await tester.pumpAndSettle();

    final order = await database.select(database.orders).getSingle();
    expect(order.status, OrderStatus.picked);
  });

  testWidgets('completion button confirms and deducts stock', (tester) async {
    final orderId = await seedOrder();
    final batch = await database.select(database.batches).getSingle();

    await tester.pumpWidget(buildScreen(orderId));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('completeOrderButton')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('completeOrderButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确认完成'));
    await tester.pumpAndSettle();

    final order = await database.select(database.orders).getSingle();
    expect(order.status, OrderStatus.done);
    expect(await stockDao.currentBoxesForBatch(batch.id), 80);
  });
}
