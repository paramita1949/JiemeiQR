import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';
import 'package:qrscan_flutter/features/calendar/outbound_calendar_screen.dart';
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

  Widget buildScreen() {
    return MaterialApp(
      theme: AppTheme.light(),
      home: OutboundCalendarScreen(
        database: database,
        initialRange: DateTimeRange(
          start: DateTime(2026, 4, 26),
          end: DateTime(2026, 4, 26),
        ),
      ),
    );
  }

  Future<void> seedOutbound({bool includeNextDayOutbound = false}) async {
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
    );
    final orderId = await orderDao.createPendingWaybill(
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
    await stockDao.addMovement(
      batchId: batchId,
      orderId: Value(orderId),
      movementDate: DateTime(2026, 4, 26),
      type: StockMovementType.orderOut,
      boxes: 20,
    );
    if (includeNextDayOutbound) {
      await stockDao.addMovement(
        batchId: batchId,
        orderId: Value(orderId),
        movementDate: DateTime(2026, 4, 27),
        type: StockMovementType.orderOut,
        boxes: 10,
      );
    }
  }

  testWidgets('shows outbound calendar inventory and grouped detail',
      (tester) async {
    await seedOutbound();

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('出库日历'), findsWidgets);
    expect(find.text('总库存'), findsOneWidget);
    expect(find.text('2,400 件'), findsOneWidget);
    expect(find.text('2026.4.26'), findsOneWidget);
    expect(find.text('今日'), findsOneWidget);
    expect(find.text('昨日'), findsOneWidget);
    expect(find.text('一周'), findsOneWidget);
    expect(find.text('一月'), findsOneWidget);
    expect(find.byTooltip('自定义范围'), findsOneWidget);
    expect(find.text('72067 · 2029.9.7'), findsOneWidget);
    expect(find.text('20箱'), findsOneWidget);
    expect(find.text('订单 1单'), findsOneWidget);
  });

  testWidgets('total inventory uses end-date snapshot instead of realtime',
      (tester) async {
    await seedOutbound(includeNextDayOutbound: true);

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('2,400 件'), findsOneWidget);
  });

  testWidgets('navigates to order list with selected range', (tester) async {
    await seedOutbound();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看订单信息'));
    await tester.pumpAndSettle();

    expect(find.text('订单信息'), findsWidgets);
    expect(find.textContaining('2026.4.26'), findsWidgets);
    expect(find.text('168220019125'), findsOneWidget);
  });
}
