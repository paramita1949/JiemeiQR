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

  Future<int> seedOrderWithBoxes(int boxes) async {
    final productId = await productDao.createProduct(
      code: '72068',
      name: '六神花露水195ML',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    final batchId = await productDao.createBatch(
      productId: productId,
      actualBatch: 'FCHBLEX',
      dateBatch: '2029.9.8',
      initialBoxes: 200,
    );
    return orderDao.createPendingWaybill(
      waybillNo: '168220019126',
      merchantName: '洁美B',
      orderDate: DateTime(2026, 4, 26),
      item: PendingOrderItemInput(
        productId: productId,
        batchId: batchId,
        boxes: boxes,
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
    expect(richTextContaining('72067'), findsOneWidget);
    expect(richTextContaining('FCHBLEZ'), findsOneWidget);
    expect(richTextContaining('2029.9.7'), findsOneWidget);
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

  testWidgets(
      'reverting done to pending restores stock and clears outbound movement',
      (tester) async {
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
    expect(await stockDao.currentBoxesForBatch(batch.id), 80);

    await tester.tap(find.text('未完成'));
    await tester.pumpAndSettle();

    final order = await (database.select(database.orders)
          ..where((table) => table.id.equals(orderId)))
        .getSingle();
    expect(order.status, OrderStatus.pending);
    expect(await stockDao.currentBoxesForBatch(batch.id), 100);

    final outboundMovements = await (database.select(database.stockMovements)
          ..where((table) => table.orderId.equals(orderId))
          ..where(
              (table) => table.type.equals(StockMovementType.orderOut.index)))
        .get();
    expect(outboundMovements, isEmpty);
  });

  testWidgets('deletes one order line without deleting whole order',
      (tester) async {
    final productId = await productDao.createProduct(
      code: '72067',
      name: '六神花露水195ML',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    final batchA = await productDao.createBatch(
      productId: productId,
      actualBatch: 'BATCH-A',
      dateBatch: '2029.9.6',
      initialBoxes: 100,
    );
    final batchB = await productDao.createBatch(
      productId: productId,
      actualBatch: 'BATCH-B',
      dateBatch: '2029.9.7',
      initialBoxes: 100,
    );
    final orderId = await orderDao.createPendingWaybill(
      waybillNo: 'LINE-DELETE-1',
      merchantName: '洁美A',
      orderDate: DateTime(2026, 4, 26),
      item: PendingOrderItemInput(
        productId: productId,
        batchId: batchA,
        boxes: 20,
        boxesPerBoard: 40,
        piecesPerBox: 30,
      ),
    );
    await orderDao.appendPendingWaybillItem(
      waybillNo: 'LINE-DELETE-1',
      merchantName: '洁美A',
      orderDate: DateTime(2026, 4, 26),
      item: PendingOrderItemInput(
        productId: productId,
        batchId: batchB,
        boxes: 10,
        boxesPerBoard: 40,
        piecesPerBox: 30,
      ),
    );

    await tester.pumpWidget(buildScreen(orderId));
    await tester.pumpAndSettle();

    expect(richTextContaining('BATCH-A'), findsOneWidget);
    expect(richTextContaining('BATCH-B'), findsOneWidget);

    await tester.tap(find.byTooltip('删除该产品').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.text('已删除该产品明细'), findsOneWidget);
    expect(richTextContaining('BATCH-A'), findsNothing);
    expect(richTextContaining('BATCH-B'), findsOneWidget);
    final remainOrder = await (database.select(database.orders)
          ..where((table) => table.id.equals(orderId)))
        .getSingleOrNull();
    expect(remainOrder, isNotNull);
    final items = await (database.select(database.orderItems)
          ..where((table) => table.orderId.equals(orderId)))
        .get();
    expect(items, hasLength(1));
  });

  testWidgets('edits one order line batch and boxes', (tester) async {
    final productId = await productDao.createProduct(
      code: '72067',
      name: '六神花露水195ML',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    final batchA = await productDao.createBatch(
      productId: productId,
      actualBatch: 'EDIT-A',
      dateBatch: '2029.9.6',
      initialBoxes: 100,
    );
    final batchB = await productDao.createBatch(
      productId: productId,
      actualBatch: 'EDIT-B',
      dateBatch: '2029.9.7',
      initialBoxes: 100,
    );
    final orderId = await orderDao.createPendingWaybill(
      waybillNo: 'LINE-EDIT-1',
      merchantName: '洁美A',
      orderDate: DateTime(2026, 4, 26),
      item: PendingOrderItemInput(
        productId: productId,
        batchId: batchA,
        boxes: 20,
        boxesPerBoard: 40,
        piecesPerBox: 30,
      ),
    );

    await tester.pumpWidget(buildScreen(orderId));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('编辑该产品').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('EDIT-A').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('EDIT-B').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '30');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    final item = await database.select(database.orderItems).getSingle();
    expect(item.batchId, batchB);
    expect(item.boxes, 30);
    expect(find.text('已更新产品明细'), findsOneWidget);
  });

  testWidgets('shows message when deleting line from done order', (tester) async {
    final orderId = await seedOrder();
    await orderDao.setStatus(orderId, OrderStatus.done);

    await tester.pumpWidget(buildScreen(orderId));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('删除该产品').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.text('已完成订单不允许删除单条明细'), findsOneWidget);
  });

  testWidgets('uses latest base-info conversion in line display',
      (tester) async {
    final orderId = await seedOrderWithBoxes(80);
    final detailBefore = await orderDao.orderDetail(orderId);
    final line = detailBefore.lines.single;

    await productDao.updateBaseInfoEntry(
      batchId: line.batch.id,
      code: line.product.code,
      name: line.product.name,
      actualBatch: line.batch.actualBatch,
      dateBatch: line.batch.dateBatch,
      currentBoxes: 200,
      boxesPerBoard: 36,
      piecesPerBox: 24,
      tsRequired: line.batch.tsRequired,
      location: line.batch.location,
      remark: line.batch.remark,
    );

    await tester.pumpWidget(buildScreen(orderId));
    await tester.pumpAndSettle();

    expect(find.text('2板+8箱'), findsOneWidget);
    expect(find.text('36箱/板 · 24件/箱'), findsOneWidget);
    expect(find.text('40箱/板 · 30件/箱'), findsNothing);
  });

  testWidgets('highlights only differing batch letters for same-date batches',
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
      waybillNo: 'LINE-HIGHLIGHT-1',
      merchantName: '洁美A',
      orderDate: DateTime(2026, 4, 26),
      item: PendingOrderItemInput(
        productId: productId,
        batchId: batchA,
        boxes: 20,
        boxesPerBoard: 40,
        piecesPerBox: 30,
      ),
    );
    await orderDao.appendPendingWaybillItem(
      waybillNo: 'LINE-HIGHLIGHT-1',
      merchantName: '洁美A',
      orderDate: DateTime(2026, 4, 26),
      item: PendingOrderItemInput(
        productId: productId,
        batchId: batchB,
        boxes: 10,
        boxesPerBoard: 40,
        piecesPerBox: 30,
      ),
    );

    await tester.pumpWidget(buildScreen(orderId));
    await tester.pumpAndSettle();

    final richTexts = tester
        .widgetList<RichText>(find.byType(RichText))
        .where((widget) =>
            widget.text.toPlainText().contains('FCHBLEZ') ||
            widget.text.toPlainText().contains('FCHBMHEZ'))
        .toList();
    expect(richTexts, isNotEmpty);

    bool hasRedDiffForBatchA = false;
    bool hasRedDiffForBatchB = false;
    bool hasNormalSharedForBatchA = false;
    bool hasNormalSharedForBatchB = false;
    for (final richText in richTexts) {
      final root = richText.text;
      if (root is! TextSpan) {
        continue;
      }
      final children = root.children ?? const <InlineSpan>[];
      final text = root.toPlainText();
      var hasRed = false;
      var hasNormal = false;
      for (final child in children) {
        if (child is! TextSpan) {
          continue;
        }
        if ((child.text ?? '').isEmpty) {
          continue;
        }
        if (child.style?.color == const Color(0xFFDC2626)) {
          hasRed = true;
        }
        if (child.style?.color == AppTheme.textPrimary) {
          hasNormal = true;
        }
      }
      if (text.contains('FCHBLEZ')) {
        hasRedDiffForBatchA = hasRed;
        hasNormalSharedForBatchA = hasNormal;
      }
      if (text.contains('FCHBMHEZ')) {
        hasRedDiffForBatchB = hasRed;
        hasNormalSharedForBatchB = hasNormal;
      }
    }
    expect(hasRedDiffForBatchA, isTrue);
    expect(hasRedDiffForBatchB, isTrue);
    expect(hasNormalSharedForBatchA, isTrue);
    expect(hasNormalSharedForBatchB, isTrue);
  });
}
  Finder richTextContaining(String text) {
    return find.byWidgetPredicate((widget) {
      if (widget is RichText) {
        return widget.text.toPlainText().contains(text);
      }
      return false;
    });
  }
