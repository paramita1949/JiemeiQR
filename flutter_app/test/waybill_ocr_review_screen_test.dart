import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_review_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';

void main() {
  late AppDatabase database;
  late ProductDao productDao;
  late OrderDao orderDao;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    productDao = ProductDao(database);
    orderDao = OrderDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('confirming OCR result merges duplicate existing order item',
      (tester) async {
    final productId = await productDao.createProduct(
      code: '72067',
      name: '大桶花露水195ml',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    final batchId = await productDao.createBatch(
      productId: productId,
      actualBatch: 'FCHBLEZ',
      dateBatch: '2029.06.22',
      initialBoxes: 300,
    );
    final product = await (database.select(database.products)
          ..where((table) => table.id.equals(productId)))
        .getSingle();
    final batch = await (database.select(database.batches)
          ..where((table) => table.id.equals(batchId)))
        .getSingle();
    await orderDao.appendPendingWaybillItem(
      waybillNo: '1686469',
      merchantName: '上峰蒙悦',
      orderDate: DateTime(2026, 4, 10),
      item: PendingOrderItemInput(
        productId: product.id,
        batchId: batch.id,
        boxes: 20,
        boxesPerBoard: batch.boxesPerBoard,
        piecesPerBox: product.piecesPerBox,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: WaybillOcrReviewScreen(
          orderDao: orderDao,
          matched: MatchedWaybillOcrDraft(
            source: const WaybillOcrDraft(
              waybillNo: '0001686469',
              merchantName: '上峰蒙悦',
              orderDateText: '2026-04-10',
              rows: [],
            ),
            orderDate: DateTime(2026, 4, 10),
            lines: [
              MatchedWaybillOcrLine(
                product: product,
                batch: batch,
                boxes: 15,
                sourceRows: const [],
                sourceBoxes: const [15],
                messages: const [],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('确认录入（录入1条）'));
    await tester.pumpAndSettle();

    final items = await database.select(database.orderItems).get();
    expect(items, hasLength(1));
    expect(items.single.boxes, 35);
  });

  testWidgets('allows save when unmatched lines exist and ignores them',
      (tester) async {
    final productId = await productDao.createProduct(
      code: '20148',
      name: '六神喷雾花露水180ml',
      boxesPerBoard: 40,
      piecesPerBox: 12,
    );
    final batchId = await productDao.createBatch(
      productId: productId,
      actualBatch: 'FBLAFEX',
      dateBatch: '2029.8.11',
      initialBoxes: 500,
    );
    final product = await (database.select(database.products)
          ..where((table) => table.id.equals(productId)))
        .getSingle();
    final batch = await (database.select(database.batches)
          ..where((table) => table.id.equals(batchId)))
        .getSingle();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: WaybillOcrReviewScreen(
          orderDao: orderDao,
          matched: MatchedWaybillOcrDraft(
            source: const WaybillOcrDraft(
              waybillNo: '0001691948',
              merchantName: '宁波冀源日月用品有限公司',
              orderDateText: '2026-04-30',
              rows: [],
            ),
            orderDate: DateTime(2026, 4, 30),
            lines: [
              const MatchedWaybillOcrLine(
                product: null,
                batch: null,
                boxes: 50,
                sourceRows: [
                  WaybillOcrRow(
                    productCode: '20880',
                    productName: '',
                    actualBatch: 'ELOAYEZ',
                    dateBatch: '',
                    boxes: 50,
                  ),
                ],
                sourceBoxes: [50],
                messages: ['未匹配产品'],
              ),
              MatchedWaybillOcrLine(
                product: product,
                batch: batch,
                boxes: 50,
                sourceRows: const [],
                sourceBoxes: const [50],
                messages: const [],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.textContaining('识别2条 · 自动修正1条 · 待确认0条 · 未匹配1条'), findsOneWidget);
    expect(find.text('确认录入（录入1条）'), findsOneWidget);

    await tester.tap(find.text('确认录入（录入1条）'));
    await tester.pumpAndSettle();

    final orders = await database.select(database.orders).get();
    final items = await database.select(database.orderItems).get();
    expect(orders, hasLength(1));
    expect(items, hasLength(1));
    expect(items.single.productId, product.id);
    expect(items.single.batchId, batch.id);
    expect(items.single.boxes, 50);
  });

  testWidgets('can switch candidate batch for review line before save',
      (tester) async {
    final productId = await productDao.createProduct(
      code: '20148',
      name: '六神喷雾花露水180ml',
      boxesPerBoard: 40,
      piecesPerBox: 12,
    );
    final batchId1 = await productDao.createBatch(
      productId: productId,
      actualBatch: 'FBLAFEX',
      dateBatch: '2029.8.11',
      initialBoxes: 500,
    );
    final batchId2 = await productDao.createBatch(
      productId: productId,
      actualBatch: 'FBLAFEY',
      dateBatch: '2029.8.11',
      initialBoxes: 500,
    );
    final product = await (database.select(database.products)
          ..where((table) => table.id.equals(productId)))
        .getSingle();
    final batch1 = await (database.select(database.batches)
          ..where((table) => table.id.equals(batchId1)))
        .getSingle();
    final batch2 = await (database.select(database.batches)
          ..where((table) => table.id.equals(batchId2)))
        .getSingle();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: WaybillOcrReviewScreen(
          orderDao: orderDao,
          matched: MatchedWaybillOcrDraft(
            source: const WaybillOcrDraft(
              waybillNo: '0001691950',
              merchantName: '宁波冀源日月用品有限公司',
              orderDateText: '2026-04-30',
              rows: [],
            ),
            orderDate: DateTime(2026, 4, 30),
            lines: [
              MatchedWaybillOcrLine(
                product: product,
                batch: batch1,
                boxes: 30,
                sourceRows: const [],
                sourceBoxes: const [30],
                messages: const [],
                status: OcrLineStatus.needReview,
                reasons: const ['产品+日期对应多个批号，已默认代选批号1'],
                candidateBatches: [batch1, batch2],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('FBLAFEX 2029.8.11'), findsOneWidget);
    await tester.tap(find.text('换一个（1/2）'));
    await tester.pumpAndSettle();
    expect(find.textContaining('FBLAFEY 2029.8.11'), findsOneWidget);

    await tester.tap(find.text('确认录入（录入1条）'));
    await tester.pumpAndSettle();

    final items = await database.select(database.orderItems).get();
    expect(items, hasLength(1));
    expect(items.single.batchId, batch2.id);
  });
}
