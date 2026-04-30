import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/features/orders/order_list_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';

void main() {
  late AppDatabase database;
  late OrderDao orderDao;
  late ProductDao productDao;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    orderDao = OrderDao(database);
    productDao = ProductDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  Widget buildScreen({DateTimeRange? dateRange}) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: OrderListScreen(database: database, dateRange: dateRange),
    );
  }

  Finder richTextContaining(String pattern) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().contains(pattern),
    );
  }

  testWidgets('defaults to unfinished quick filter and shows status stats',
      (tester) async {
    final today = DateTime.now();
    final pickedOrderId = await orderDao.createOrder(
      waybillNo: '168220019125',
      merchantName: '洁美A',
      orderDate: today,
    );
    await orderDao.setStatus(pickedOrderId, OrderStatus.picked);
    await orderDao.createOrder(
      waybillNo: '168220019126',
      merchantName: '洁美B',
      orderDate: today,
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('订单信息'), findsWidgets);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('未完成'), findsWidgets);
    expect(find.text('已拣货'), findsWidgets);
    expect(find.text('完成'), findsWidgets);
    expect(richTextContaining('完成 0单 · 未完成 2单 · 已拣货 1单'), findsOneWidget);
    expect(find.text('备货汇总（按产品/批号/日期）'), findsNothing);
    expect(find.text('新增运单'), findsOneWidget);
    expect(find.byTooltip('日期筛选'), findsOneWidget);
    expect(find.text('168220019125'), findsOneWidget);
    expect(find.text('168220019126'), findsOneWidget);
    expect(find.text('洁美B'), findsOneWidget);

    await tester.tap(find.text('全部').first);
    await tester.pumpAndSettle();
    expect(find.text('168220019125'), findsOneWidget);

    await tester.tap(find.text('已拣货').last);
    await tester.pumpAndSettle();

    expect(find.text('168220019125'), findsOneWidget);
    expect(find.text('洁美A'), findsOneWidget);
    expect(find.text('168220019126'), findsNothing);
  });

  testWidgets('uses date range context from calendar entry', (tester) async {
    await orderDao.createOrder(
      waybillNo: 'RANGE-1',
      merchantName: '范围内',
      orderDate: DateTime(2026, 4, 25),
    );
    await orderDao.createOrder(
      waybillNo: 'RANGE-2',
      merchantName: '范围外',
      orderDate: DateTime(2026, 4, 26),
    );

    await tester.pumpWidget(
      buildScreen(
        dateRange: DateTimeRange(
          start: DateTime(2026, 4, 25),
          end: DateTime(2026, 4, 25),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('2026.4.25'), findsWidgets);
    expect(find.text('RANGE-1'), findsOneWidget);
    expect(find.text('RANGE-2'), findsNothing);
  });

  testWidgets('exception filter sits after 完成 on the status row',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    final labels = find.text('未完成');
    expect(labels, findsWidgets);
    expect(find.text('异常'), findsOneWidget);
    expect(find.text('今日'), findsOneWidget);
    expect(find.text('昨日'), findsOneWidget);
    expect(find.text('一周'), findsOneWidget);
    expect(find.text('一月'), findsOneWidget);

    final donePosition = tester.getTopLeft(find.text('完成').first);
    final exceptionPosition = tester.getTopLeft(find.text('异常'));
    expect(exceptionPosition.dy, donePosition.dy);
    expect(exceptionPosition.dx, greaterThan(donePosition.dx));
  });

  testWidgets('exception quick filter shows orders triggered by batch edit',
      (tester) async {
    final productId = await productDao.createProduct(
      code: '72067',
      name: '六神花露水195ML',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    final batchA = await productDao.createBatch(
      productId: productId,
      actualBatch: '123',
      dateBatch: '2029.1.1',
      initialBoxes: 100,
    );
    final batchB = await productDao.createBatch(
      productId: productId,
      actualBatch: '124',
      dateBatch: '2029.01.01',
      initialBoxes: 100,
    );
    final batchC = await productDao.createBatch(
      productId: productId,
      actualBatch: '125',
      dateBatch: '2029.1.2',
      initialBoxes: 100,
    );
    await orderDao.createPendingWaybill(
      waybillNo: 'ERR-A',
      merchantName: '洁美A',
      orderDate: DateTime.now(),
      item: PendingOrderItemInput(
        productId: productId,
        batchId: batchA,
        boxes: 2,
        boxesPerBoard: 40,
        piecesPerBox: 30,
      ),
    );
    final doneOrderId = await orderDao.createPendingWaybill(
      waybillNo: 'ERR-B',
      merchantName: '洁美B',
      orderDate: DateTime.now(),
      item: PendingOrderItemInput(
        productId: productId,
        batchId: batchB,
        boxes: 2,
        boxesPerBoard: 40,
        piecesPerBox: 30,
      ),
    );
    await orderDao.setStatus(doneOrderId, OrderStatus.done);
    await orderDao.createPendingWaybill(
      waybillNo: 'OK-C',
      merchantName: '洁美C',
      orderDate: DateTime.now(),
      item: PendingOrderItemInput(
        productId: productId,
        batchId: batchC,
        boxes: 2,
        boxesPerBoard: 40,
        piecesPerBox: 30,
      ),
    );

    await productDao.updateBaseInfoEntry(
      batchId: batchA,
      code: '72067',
      name: '六神花露水195ML',
      actualBatch: '123A',
      dateBatch: '2029.1.1',
      currentBoxes: 100,
      boxesPerBoard: 40,
      piecesPerBox: 30,
      tsRequired: false,
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('异常').first);
    await tester.pumpAndSettle();

    expect(find.text('ERR-A'), findsOneWidget);
    expect(find.text('ERR-B'), findsOneWidget);
    expect(find.text('OK-C'), findsNothing);
  });

  testWidgets('new waybill button opens edit screen', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('新增运单'));
    await tester.pumpAndSettle();

    expect(find.text('新增运单'), findsWidgets);
    expect(find.byKey(const Key('waybillNoField')), findsOneWidget);
  });

  testWidgets('order card opens detail screen', (tester) async {
    final today = DateTime.now();
    await orderDao.createOrder(
      waybillNo: 'DETAIL-1',
      merchantName: '洁美A',
      orderDate: today,
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('DETAIL-1'));
    await tester.pumpAndSettle();

    expect(find.text('运单详情'), findsOneWidget);
    expect(find.text('DETAIL-1'), findsOneWidget);
  });

  testWidgets('shows TS badge only for TS-required orders', (tester) async {
    final today = DateTime.now();
    final productId = await productDao.createProduct(
      code: '72067',
      name: '六神花露水195ML',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    final tsBatchId = await productDao.createBatch(
      productId: productId,
      actualBatch: 'TS-A',
      dateBatch: '2029.9.7',
      initialBoxes: 10,
      tsRequired: true,
    );
    final normalBatchId = await productDao.createBatch(
      productId: productId,
      actualBatch: 'NO-TS',
      dateBatch: '2029.9.8',
      initialBoxes: 10,
      tsRequired: false,
    );
    await orderDao.createPendingWaybill(
      waybillNo: 'TS-ORDER',
      merchantName: '洁美TS',
      orderDate: today,
      item: PendingOrderItemInput(
        productId: productId,
        batchId: tsBatchId,
        boxes: 2,
        boxesPerBoard: 40,
        piecesPerBox: 30,
      ),
    );
    await orderDao.createPendingWaybill(
      waybillNo: 'NORMAL-ORDER',
      merchantName: '洁美普通',
      orderDate: today.subtract(const Duration(days: 1)),
      item: PendingOrderItemInput(
        productId: productId,
        batchId: normalBatchId,
        boxes: 2,
        boxesPerBoard: 40,
        piecesPerBox: 30,
      ),
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('TS'), findsOneWidget);
    expect(find.text('备货汇总（按产品/批号/日期）'), findsOneWidget);
    expect(richTextContaining('72067'), findsWidgets);
  });

  testWidgets('hides location summary for multi-product order', (tester) async {
    final productId = await productDao.createProduct(
      code: '72067',
      name: '六神花露水195ML',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    final batchA = await productDao.createBatch(
      productId: productId,
      actualBatch: 'LOC-A',
      dateBatch: '2029.9.6',
      initialBoxes: 10,
      location: '4楼-后',
    );
    final batchB = await productDao.createBatch(
      productId: productId,
      actualBatch: 'LOC-B',
      dateBatch: '2029.9.7',
      initialBoxes: 10,
      location: '5楼-前',
    );
    final today = DateTime.now();
    await orderDao.createPendingWaybill(
      waybillNo: 'MULTI-LOC',
      merchantName: '洁美A',
      orderDate: today,
      item: PendingOrderItemInput(
        productId: productId,
        batchId: batchA,
        boxes: 2,
        boxesPerBoard: 40,
        piecesPerBox: 30,
      ),
    );
    await orderDao.appendPendingWaybillItem(
      waybillNo: 'MULTI-LOC',
      merchantName: '洁美A',
      orderDate: today,
      item: PendingOrderItemInput(
        productId: productId,
        batchId: batchB,
        boxes: 2,
        boxesPerBoard: 40,
        piecesPerBox: 30,
      ),
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('MULTI-LOC'), findsWidgets);
    expect(find.textContaining('库位 '), findsNothing);
  });

  testWidgets('restock aggregate uses board+box format without decimal boards',
      (tester) async {
    final productId = await productDao.createProduct(
      code: '20148',
      name: '测试产品',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    final batchId = await productDao.createBatch(
      productId: productId,
      actualBatch: 'B-1',
      dateBatch: '2029.8.11',
      initialBoxes: 100,
      boxesPerBoard: 40,
    );
    await orderDao.createPendingWaybill(
      waybillNo: 'WB-BOARD-FMT',
      merchantName: '洁美A',
      orderDate: DateTime.now(),
      item: PendingOrderItemInput(
        productId: productId,
        batchId: batchId,
        boxes: 30,
        boxesPerBoard: 40,
        piecesPerBox: 30,
      ),
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(richTextContaining('30箱 · 30箱'), findsOneWidget);
    expect(find.textContaining('.5板'), findsNothing);
  });
}
