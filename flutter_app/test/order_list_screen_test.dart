import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/features/orders/order_list_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';

void main() {
  late AppDatabase database;
  late OrderDao orderDao;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    orderDao = OrderDao(database);
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

  testWidgets('shows status tabs and centered order cards', (tester) async {
    final pickedOrderId = await orderDao.createOrder(
      waybillNo: '168220019125',
      merchantName: '洁美A',
      orderDate: DateTime(2026, 4, 26),
    );
    await orderDao.setStatus(pickedOrderId, OrderStatus.picked);
    await orderDao.createOrder(
      waybillNo: '168220019126',
      merchantName: '洁美B',
      orderDate: DateTime(2026, 4, 26),
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('订单信息'), findsWidgets);
    expect(find.text('未完成'), findsWidgets);
    expect(find.text('已拣货'), findsWidgets);
    expect(find.text('完成'), findsWidgets);
    expect(find.text('新增运单'), findsOneWidget);
    expect(find.byTooltip('日期筛选'), findsOneWidget);
    expect(find.text('168220019126'), findsOneWidget);
    expect(find.text('洁美B'), findsOneWidget);

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

    expect(find.text('2026.4.25'), findsOneWidget);
    expect(find.text('RANGE-1'), findsOneWidget);
    expect(find.text('RANGE-2'), findsNothing);
  });

  testWidgets('new waybill button opens edit screen', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('新增运单'));
    await tester.pumpAndSettle();

    expect(find.text('新增运单'), findsWidgets);
    expect(find.text('产品明细'), findsOneWidget);
  });

  testWidgets('order card opens detail screen', (tester) async {
    await orderDao.createOrder(
      waybillNo: 'DETAIL-1',
      merchantName: '洁美A',
      orderDate: DateTime(2026, 4, 26),
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('DETAIL-1'));
    await tester.pumpAndSettle();

    expect(find.text('运单详情'), findsOneWidget);
    expect(find.text('DETAIL-1'), findsOneWidget);
  });

}
