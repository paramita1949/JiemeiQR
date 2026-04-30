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
      waybillNo: '0001686469',
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

    await tester.tap(find.text('确认录入'));
    await tester.pumpAndSettle();

    final items = await database.select(database.orderItems).get();
    expect(items, hasLength(1));
    expect(items.single.boxes, 35);
  });
}
