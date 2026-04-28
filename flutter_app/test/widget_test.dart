import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';
import 'package:qrscan_flutter/main.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  QrScanApp buildApp() => QrScanApp(database: database);

  Future<void> seedHomeData() async {
    final productDao = ProductDao(database);
    final orderDao = OrderDao(database);
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
      initialBoxes: 10,
    );
    await orderDao.createOrder(
      waybillNo: 'TODAY-1',
      merchantName: '今日商家',
      orderDate: DateTime.now(),
    );
    final pickedId = await orderDao.createOrder(
      waybillNo: 'OLD-1',
      merchantName: '旧商家',
      orderDate: DateTime(2026, 4, 25),
    );
    await orderDao.setStatus(pickedId, OrderStatus.picked);
  }

  testWidgets('app renders JIEMEI home shell with live stats', (tester) async {
    await seedHomeData();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('洁美'), findsOneWidget);
    expect(find.text('浙江仓订单与库存工作台'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('总库存'), findsOneWidget);
    expect(find.text('300 件'), findsOneWidget);
    expect(find.textContaining('今日订单'), findsOneWidget);
    expect(find.textContaining('昨日订单'), findsOneWidget);
    expect(find.textContaining('未完成 2 单'), findsOneWidget);

    expect(find.text('QR箱码'), findsOneWidget);
    expect(find.text('订单信息'), findsOneWidget);
    expect(find.text('出库日历'), findsOneWidget);
    expect(find.text('库存明细'), findsOneWidget);
    expect(find.text('数据备份'), findsOneWidget);
    expect(find.text('基础资料'), findsOneWidget);
    expect(find.text('备份导入'), findsNothing);
  });

  testWidgets('home stats update after stock changes without re-enter',
      (tester) async {
    await seedHomeData();
    final stockDao = StockDao(database);
    final batch = await database.select(database.batches).getSingle();

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.text('300 件'), findsOneWidget);

    await stockDao.addMovement(
      batchId: batch.id,
      movementDate: DateTime(2026, 4, 26),
      type: StockMovementType.inAdjust,
      boxes: 5,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(find.text('450 件'), findsOneWidget);
  });

  testWidgets('home action opens data backup page', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('数据备份'));
    await tester.pumpAndSettle();

    expect(find.text('数据备份'), findsWidgets);
    expect(find.text('发送'), findsOneWidget);
    expect(find.text('接收'), findsOneWidget);
    expect(find.textContaining('发送地址'), findsNothing);
  });

  testWidgets('QR home action opens QR entry screen', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('QR箱码'));
    await tester.pumpAndSettle();

    expect(find.text('QR箱码生成'), findsOneWidget);
    expect(find.text('开始扫码'), findsOneWidget);
    expect(find.text('导入图片'), findsOneWidget);
    expect(find.text('生成并预览'), findsOneWidget);
    expect(find.text('下一组继续'), findsOneWidget);
  });

  testWidgets('base info home action opens base info entry screen',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('基础资料'));
    await tester.pumpAndSettle();

    expect(find.text('基础资料'), findsWidgets);
    expect(find.text('产品信息'), findsNothing);
    expect(find.text('板数'), findsNothing);
    expect(find.byTooltip('扫码快速录入'), findsOneWidget);
  });

  testWidgets('inventory home action opens inventory detail screen',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('库存明细'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('库存明细'), findsWidgets);
    expect(find.text('总库存'), findsWidgets);
  });

  testWidgets('orders home action opens order list screen', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('订单信息'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('订单信息'), findsWidgets);
    expect(find.text('新增运单'), findsOneWidget);
    expect(find.byTooltip('日期筛选'), findsOneWidget);
  });

  testWidgets('calendar home action opens outbound calendar screen',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('出库日历'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('出库日历'), findsWidgets);
    expect(find.text('总库存'), findsWidgets);
    expect(find.text('查看订单信息'), findsOneWidget);
  });
}
