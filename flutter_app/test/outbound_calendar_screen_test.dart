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

  Widget buildScreen({DateTimeRange? initialRange}) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: OutboundCalendarScreen(
        key: UniqueKey(),
        database: database,
        initialRange: initialRange ??
            DateTimeRange(
              start: DateTime(2026, 4, 26),
              end: DateTime(2026, 4, 26),
            ),
      ),
    );
  }

  Finder richTextContaining(String pattern) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().contains(pattern),
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
    expect(find.text('库存变化 -20箱'), findsOneWidget);
    expect(find.text('订单 1单 · 20箱'), findsOneWidget);
    expect(find.text('168220019125'), findsOneWidget);
    expect(find.text('洁美A'), findsWidgets);
    expect(find.textContaining('+0箱'), findsNothing);
    expect(find.text('出库明细'), findsOneWidget);
    expect(find.text('按运单'), findsNothing);
    expect(find.text('运单 168220019125'), findsOneWidget);
    expect(find.text('合计 20箱'), findsOneWidget);
    expect(richTextContaining('72067'), findsOneWidget);
    expect(richTextContaining('2029.9.7'), findsOneWidget);
    expect(find.text('运单 168220019125 · 商家 洁美A'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText() == '洁美A' &&
            _hasRedMerchantSpan(widget.text, '洁美A'),
      ),
      findsOneWidget,
    );
    expect(find.text('20箱'), findsOneWidget);
  });

  testWidgets('selects one order to show only that outbound detail',
      (tester) async {
    await seedOutbound();
    final productId = await productDao.createProduct(
      code: '20584',
      name: '六神花露水',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    final batchId = await productDao.createBatch(
      productId: productId,
      actualBatch: 'OTHER',
      dateBatch: '2029.8.1',
      initialBoxes: 100,
    );
    final orderId = await orderDao.createPendingWaybill(
      waybillNo: '168220019126',
      merchantName: '洁美B',
      orderDate: DateTime(2026, 4, 26),
      item: PendingOrderItemInput(
        productId: productId,
        batchId: batchId,
        boxes: 5,
        boxesPerBoard: 40,
        piecesPerBox: 30,
      ),
    );
    await stockDao.addMovement(
      batchId: batchId,
      orderId: Value(orderId),
      movementDate: DateTime(2026, 4, 26),
      type: StockMovementType.orderOut,
      boxes: 5,
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(richTextContaining('20584'), findsOneWidget);
    expect(richTextContaining('2029.8.1'), findsOneWidget);
    await tester.tap(find.text('168220019126'));
    await tester.pumpAndSettle();

    expect(find.text('运单 168220019126 出库明细'), findsOneWidget);
    expect(find.text('合计 5箱'), findsOneWidget);
    expect(richTextContaining('20584'), findsOneWidget);
    expect(richTextContaining('2029.8.1'), findsOneWidget);
    expect(richTextContaining('72067'), findsNothing);
    expect(richTextContaining('2029.9.7'), findsNothing);
  });

  testWidgets('uses range-aware outbound detail titles', (tester) async {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final yesterday = todayOnly.subtract(const Duration(days: 1));

    await tester.pumpWidget(buildScreen(
      initialRange: DateTimeRange(start: todayOnly, end: todayOnly),
    ));
    await tester.pumpAndSettle();
    expect(find.text('今日出库明细'), findsOneWidget);

    await tester.pumpWidget(buildScreen(
      initialRange: DateTimeRange(start: yesterday, end: yesterday),
    ));
    await tester.pumpAndSettle();
    expect(find.text('昨日出库明细'), findsOneWidget);

    await tester.pumpWidget(buildScreen(
      initialRange: DateTimeRange(
        start: todayOnly.subtract(const Duration(days: 6)),
        end: todayOnly,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('近7天出库明细'), findsOneWidget);

    await tester.pumpWidget(buildScreen(
      initialRange: DateTimeRange(
        start: DateTime(todayOnly.year, todayOnly.month, 1),
        end: todayOnly,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('本月出库明细'), findsOneWidget);
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

    await tester.scrollUntilVisible(
      find.text('查看订单信息'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('查看订单信息'));
    await tester.pumpAndSettle();

    expect(find.text('订单信息'), findsWidgets);
    expect(find.textContaining('2026.4.26'), findsWidgets);
    expect(find.text('168220019125'), findsOneWidget);
  });

  testWidgets('does not show inventory change when outbound is zero',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.textContaining('库存变化'), findsNothing);
  });

  testWidgets('keeps custom range button on the same row as 一月 on narrow width',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await seedOutbound();

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final monthY = tester.getTopLeft(find.text('一月')).dy;
    final customY = tester.getTopLeft(find.byTooltip('自定义范围')).dy;
    expect((monthY - customY).abs(), lessThan(20));
  });

  testWidgets(
      'highlights differing batch letters for same product-date outbound rows',
      (tester) async {
    final productId = await productDao.createProduct(
      code: '72067',
      name: '六神花露水195ML',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    final batchA = await productDao.createBatch(
      productId: productId,
      actualBatch: 'FCHBLEZ',
      dateBatch: '2029.9.7',
      initialBoxes: 100,
    );
    final batchB = await productDao.createBatch(
      productId: productId,
      actualBatch: 'FCHBMHEZ',
      dateBatch: '2029.9.7',
      initialBoxes: 100,
    );
    final orderId = await orderDao.createPendingWaybill(
      waybillNo: 'HB-1',
      merchantName: '洁美A',
      orderDate: DateTime(2026, 4, 26),
      item: PendingOrderItemInput(
        productId: productId,
        batchId: batchA,
        boxes: 10,
        boxesPerBoard: 40,
        piecesPerBox: 30,
      ),
    );
    await orderDao.appendPendingWaybillItem(
      waybillNo: 'HB-1',
      merchantName: '洁美A',
      orderDate: DateTime(2026, 4, 26),
      item: PendingOrderItemInput(
        productId: productId,
        batchId: batchB,
        boxes: 12,
        boxesPerBoard: 40,
        piecesPerBox: 30,
      ),
    );
    await stockDao.addMovement(
      batchId: batchA,
      orderId: Value(orderId),
      movementDate: DateTime(2026, 4, 26),
      type: StockMovementType.orderOut,
      boxes: 10,
    );
    await stockDao.addMovement(
      batchId: batchB,
      orderId: Value(orderId),
      movementDate: DateTime(2026, 4, 26),
      type: StockMovementType.orderOut,
      boxes: 12,
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final richTexts =
        tester.widgetList<RichText>(find.byType(RichText)).where((widget) {
      final plain = widget.text.toPlainText();
      return plain.contains('FCHBLEZ') || plain.contains('FCHBMHEZ');
    }).toList();
    expect(richTexts, isNotEmpty);

    var hasRedA = false;
    var hasRedB = false;
    for (final richText in richTexts) {
      final root = richText.text;
      if (root is! TextSpan) {
        continue;
      }
      final spans = <TextSpan>[];
      void collect(TextSpan span) {
        spans.add(span);
        for (final child in span.children ?? const <InlineSpan>[]) {
          if (child is TextSpan) {
            collect(child);
          }
        }
      }

      collect(root);
      final hasRed =
          spans.any((span) => span.style?.color == const Color(0xFFDC2626));
      final plain = root.toPlainText();
      if (plain.contains('FCHBLEZ')) {
        hasRedA = hasRed;
      }
      if (plain.contains('FCHBMHEZ')) {
        hasRedB = hasRed;
      }
    }

    expect(hasRedA, isTrue);
    expect(hasRedB, isTrue);
  });
}

bool _hasRedMerchantSpan(InlineSpan span, String merchantName) {
  if (span is TextSpan) {
    if (span.text == merchantName &&
        span.style?.color == const Color(0xFFDC2626)) {
      return true;
    }
    return span.children?.any((child) {
          return _hasRedMerchantSpan(child, merchantName);
        }) ??
        false;
  }
  return false;
}
