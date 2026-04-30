import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_matcher.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';

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

  test('merges OCR rows only when product and actual batch are the same',
      () async {
    final productId = await productDao.createProduct(
      code: '72067',
      name: '大桶花露水195ml',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    await productDao.createBatch(
      productId: productId,
      actualBatch: 'FCHBLEZ',
      dateBatch: '2029.06.22',
      initialBoxes: 300,
    );

    final result = await WaybillOcrMatcher(productDao).match(
      const WaybillOcrDraft(
        waybillNo: '0001686469',
        merchantName: '上峰蒙悦',
        orderDateText: '2026-04-10',
        rows: [
          WaybillOcrRow(
            productCode: '72067',
            productName: '大桶花露水195ml',
            actualBatch: 'FCHBLEZ',
            dateBatch: '2029.06.22',
            boxes: 100,
          ),
          WaybillOcrRow(
            productCode: '72067',
            productName: '大桶花露水195ml',
            actualBatch: 'FCHBLEZ',
            dateBatch: '2029.06.22',
            boxes: 10,
          ),
        ],
      ),
    );

    expect(result.lines, hasLength(1));
    expect(result.lines.single.boxes, 110);
    expect(result.lines.single.sourceBoxes, [100, 10]);
    expect(result.lines.single.batch?.actualBatch, 'FCHBLEZ');
  });

  test(
      'keeps different actual batches separate even with same product and date',
      () async {
    final productId = await productDao.createProduct(
      code: '72067',
      name: '大桶花露水195ml',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    await productDao.createBatch(
      productId: productId,
      actualBatch: 'FCHBLEZ',
      dateBatch: '2029.06.22',
      initialBoxes: 300,
    );
    await productDao.createBatch(
      productId: productId,
      actualBatch: 'FCHBLEH',
      dateBatch: '2029.06.22',
      initialBoxes: 300,
    );

    final result = await WaybillOcrMatcher(productDao).match(
      const WaybillOcrDraft(
        waybillNo: '0001686469',
        merchantName: '上峰蒙悦',
        orderDateText: '2026-04-10',
        rows: [
          WaybillOcrRow(
            productCode: '72067',
            productName: '大桶花露水195ml',
            actualBatch: 'FCHBLEZ',
            dateBatch: '2029.06.22',
            boxes: 100,
          ),
          WaybillOcrRow(
            productCode: '72067',
            productName: '大桶花露水195ml',
            actualBatch: 'FCHBLEH',
            dateBatch: '2029.06.22',
            boxes: 10,
          ),
        ],
      ),
    );

    expect(result.lines, hasLength(2));
    expect(
      result.lines.map((line) => '${line.batch?.actualBatch}:${line.boxes}'),
      containsAll(['FCHBLEZ:100', 'FCHBLEH:10']),
    );
  });

  test('matches existing batch even when stock is fully reserved', () async {
    final productId = await productDao.createProduct(
      code: '20148',
      name: '六神喷雾花露水180ml',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    await productDao.createBatch(
      productId: productId,
      actualBatch: 'FBLAEEZ',
      dateBatch: '2029.06.22',
      initialBoxes: 50,
    );
    await orderDao.createPendingWaybill(
      waybillNo: 'RESERVED-1',
      merchantName: '占用库存',
      orderDate: DateTime(2026, 4, 29),
      item: PendingOrderItemInput(
        productId: productId,
        batchId: 1,
        boxes: 50,
        boxesPerBoard: 40,
        piecesPerBox: 30,
      ),
    );

    final result = await WaybillOcrMatcher(productDao).match(
      const WaybillOcrDraft(
        waybillNo: '0001691948',
        merchantName: '宁波嘉源日用品有限公司',
        orderDateText: '2026-04-29',
        rows: [
          WaybillOcrRow(
            productCode: '20148',
            productName: '六神喷雾花露水180ml',
            actualBatch: 'FBLAEEZ',
            dateBatch: '',
            boxes: 50,
          ),
        ],
      ),
    );

    expect(result.lines, hasLength(1));
    expect(result.lines.single.batch?.actualBatch, 'FBLAEEZ');
    expect(result.lines.single.messages, isNot(contains('未匹配批号')));
  });

  test('matches unique date batch when OCR date has leading zeroes', () async {
    final productId = await productDao.createProduct(
      code: '72067',
      name: '大桶花露水195ml',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    await productDao.createBatch(
      productId: productId,
      actualBatch: 'FCHBLEZ',
      dateBatch: '2029.8.11',
      initialBoxes: 300,
    );

    final result = await WaybillOcrMatcher(productDao).match(
      const WaybillOcrDraft(
        waybillNo: '0001686469',
        merchantName: '上峰蒙悦',
        orderDateText: '2026-04-10',
        rows: [
          WaybillOcrRow(
            productCode: '72067',
            productName: '大桶花露水195ml',
            actualBatch: '',
            dateBatch: '2029.08.11',
            boxes: 100,
          ),
        ],
      ),
    );

    expect(result.lines, hasLength(1));
    expect(result.lines.single.batch?.actualBatch, 'FCHBLEZ');
    expect(result.lines.single.messages, isNot(contains('未匹配批号')));
  });

  test('uses actual batch to disambiguate batches with same date', () async {
    final productId = await productDao.createProduct(
      code: '72067',
      name: '大桶花露水195ml',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    await productDao.createBatch(
      productId: productId,
      actualBatch: 'FCHBLEZ',
      dateBatch: '2029.8.11',
      initialBoxes: 300,
    );
    await productDao.createBatch(
      productId: productId,
      actualBatch: 'FCHBLEH',
      dateBatch: '2029.08.11',
      initialBoxes: 300,
    );

    final result = await WaybillOcrMatcher(productDao).match(
      const WaybillOcrDraft(
        waybillNo: '0001686469',
        merchantName: '上峰蒙悦',
        orderDateText: '2026-04-10',
        rows: [
          WaybillOcrRow(
            productCode: '72067',
            productName: '大桶花露水195ml',
            actualBatch: 'FCHBLEH',
            dateBatch: '2029.08.11',
            boxes: 10,
          ),
        ],
      ),
    );

    expect(result.lines, hasLength(1));
    expect(result.lines.single.batch?.actualBatch, 'FCHBLEH');
  });

  test(
      'does not guess when same date has multiple batches without actual batch',
      () async {
    final productId = await productDao.createProduct(
      code: '72067',
      name: '大桶花露水195ml',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    await productDao.createBatch(
      productId: productId,
      actualBatch: 'FCHBLEZ',
      dateBatch: '2029.8.11',
      initialBoxes: 300,
    );
    await productDao.createBatch(
      productId: productId,
      actualBatch: 'FCHBLEH',
      dateBatch: '2029.08.11',
      initialBoxes: 300,
    );

    final result = await WaybillOcrMatcher(productDao).match(
      const WaybillOcrDraft(
        waybillNo: '0001686469',
        merchantName: '上峰蒙悦',
        orderDateText: '2026-04-10',
        rows: [
          WaybillOcrRow(
            productCode: '72067',
            productName: '大桶花露水195ml',
            actualBatch: '',
            dateBatch: '2029.08.11',
            boxes: 10,
          ),
        ],
      ),
    );

    expect(result.lines, hasLength(1));
    expect(result.lines.single.batch, isNull);
    expect(result.lines.single.messages, contains('未匹配批号'));
  });
}
