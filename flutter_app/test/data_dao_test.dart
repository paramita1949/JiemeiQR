import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';

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

  test('product dao saves product and batch for base info entry', () async {
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
      initialBoxes: 3477,
      location: '4楼-后-右',
      remark: '可随时修改',
    );

    final batches = await productDao.batchesForProduct(productId);

    expect(batchId, isPositive);
    expect(batches.single.remark, '可随时修改');
  });

  test('same product can have batches with different board stacking', () async {
    final firstProductId = await productDao.createProduct(
      code: '72067',
      name: '六神花露水195ML',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    await productDao.createBatch(
      productId: firstProductId,
      actualBatch: 'A',
      dateBatch: '2029.9.7',
      initialBoxes: 40,
      boxesPerBoard: 40,
    );

    final secondProductId = await productDao.createProduct(
      code: '72067',
      name: '六神花露水195ML',
      boxesPerBoard: 38,
      piecesPerBox: 30,
    );
    await productDao.createBatch(
      productId: secondProductId,
      actualBatch: 'B',
      dateBatch: '2029.9.8',
      initialBoxes: 38,
      boxesPerBoard: 38,
    );

    final products = await database.select(database.products).get();
    final batches = await productDao.batchesForProduct(firstProductId);

    expect(secondProductId, firstProductId);
    expect(products, hasLength(1));
    expect(batches.map((batch) => batch.boxesPerBoard), containsAll([40, 38]));
  });

  test('product dao rejects invalid product specs and initial stock', () async {
    expect(
      () => productDao.createProduct(
        code: 'BAD-BOARD',
        name: '坏规格',
        boxesPerBoard: 0,
        piecesPerBox: 30,
      ),
      throwsA(isA<InvalidProductQuantityException>()),
    );
    expect(
      () => productDao.createProduct(
        code: 'BAD-PIECES',
        name: '坏规格',
        boxesPerBoard: 40,
        piecesPerBox: 0,
      ),
      throwsA(isA<InvalidProductQuantityException>()),
    );

    final productId = await productDao.createProduct(
      code: 'SAFE',
      name: '安全规格',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    expect(
      () => productDao.createBatch(
        productId: productId,
        actualBatch: 'BAD',
        dateBatch: '2029.1.1',
        initialBoxes: -1,
      ),
      throwsA(isA<InvalidProductQuantityException>()),
    );
  });

  test('order dao returns merchants by recent frequency', () async {
    for (final name in ['A商家', 'B商家', 'A商家']) {
      await orderDao.createOrder(
        waybillNo: 'NO-$name-${DateTime.now().microsecondsSinceEpoch}',
        merchantName: name,
        orderDate: DateTime(2026, 4, 26),
      );
    }

    final merchants = await orderDao.recentMerchantNames(limit: 10);

    expect(merchants.first, 'A商家');
    expect(merchants, contains('B商家'));
  });

  test('order dao filters order summaries by status and date range', () async {
    final firstOrderId = await orderDao.createOrder(
      waybillNo: 'NO-1',
      merchantName: 'A商家',
      orderDate: DateTime(2026, 4, 25),
    );
    await orderDao.createOrder(
      waybillNo: 'NO-2',
      merchantName: 'B商家',
      orderDate: DateTime(2026, 4, 26),
    );
    await orderDao.setStatus(firstOrderId, OrderStatus.picked);

    final summaries = await orderDao.orderSummaries(
      status: OrderStatus.picked,
      dateRange: DateTimeRange(
        start: DateTime(2026, 4, 25),
        end: DateTime(2026, 4, 25),
      ),
    );

    expect(summaries, hasLength(1));
    expect(summaries.single.waybillNo, 'NO-1');
    expect(summaries.single.status, OrderStatus.picked);
    expect(summaries.single.dateText, '2026.4.25');
  });

  test('product dao returns available batches with current stock', () async {
    final productId = await productDao.createProduct(
      code: '72067',
      name: '六神花露水195ML',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    final emptyBatchId = await productDao.createBatch(
      productId: productId,
      actualBatch: 'OLD',
      dateBatch: '2029.1.1',
      initialBoxes: 10,
    );
    await productDao.createBatch(
      productId: productId,
      actualBatch: 'FCHBLEZ',
      dateBatch: '2029.9.7',
      initialBoxes: 100,
    );
    await stockDao.addMovement(
      batchId: emptyBatchId,
      movementDate: DateTime(2026, 4, 26),
      type: StockMovementType.orderOut,
      boxes: 10,
    );

    final batches = await productDao.availableBatchesForProduct(productId);

    expect(batches, hasLength(1));
    expect(batches.single.batch.actualBatch, 'FCHBLEZ');
    expect(batches.single.currentBoxes, 100);
  });

  test('order dao saves a pending waybill with items', () async {
    final productId = await productDao.createProduct(
      code: '20380',
      name: '六神180ML止痒花露水喷雾',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    final batchId = await productDao.createBatch(
      productId: productId,
      actualBatch: 'ELMAXEZ',
      dateBatch: '2029.6.14',
      initialBoxes: 3434,
    );

    final orderId = await orderDao.createPendingWaybill(
      waybillNo: '168220019125',
      merchantName: '洁美A',
      orderDate: DateTime(2026, 4, 26),
      item: PendingOrderItemInput(
        productId: productId,
        batchId: batchId,
        boxes: 320,
        boxesPerBoard: 40,
        piecesPerBox: 30,
      ),
    );

    final order = await database.select(database.orders).getSingle();
    final item = await database.select(database.orderItems).getSingle();

    expect(order.id, orderId);
    expect(order.status, OrderStatus.pending);
    expect(item.boxes, 320);
  });

  test('order dao rejects nonpositive and over-stock pending waybill items',
      () async {
    final productId = await productDao.createProduct(
      code: '20381',
      name: '六神花露水',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    final batchId = await productDao.createBatch(
      productId: productId,
      actualBatch: 'FCHBLEZ',
      dateBatch: '2029.9.7',
      initialBoxes: 10,
    );

    Future<void> createWithBoxes(int boxes) {
      return orderDao.createPendingWaybill(
        waybillNo: 'BAD-$boxes',
        merchantName: '洁美A',
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

    expect(() => createWithBoxes(0),
        throwsA(isA<InvalidStockQuantityException>()));
    expect(
        () => createWithBoxes(11), throwsA(isA<InsufficientStockException>()));
    expect(await database.select(database.orders).get(), isEmpty);
  });

  test('order dao rejects duplicate product batch in same open waybill',
      () async {
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
    final item = PendingOrderItemInput(
      productId: productId,
      batchId: batchId,
      boxes: 20,
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );

    await orderDao.appendPendingWaybillItem(
      waybillNo: 'DUP-DAO',
      merchantName: '洁美A',
      orderDate: DateTime(2026, 4, 26),
      item: item,
    );

    expect(
      () => orderDao.appendPendingWaybillItem(
        waybillNo: 'DUP-DAO',
        merchantName: '洁美A',
        orderDate: DateTime(2026, 4, 26),
        item: item,
      ),
      throwsA(isA<DuplicateOrderItemException>()),
    );
    expect(await database.select(database.orderItems).get(), hasLength(1));
  });

  test('stock dao derives current stock and total pieces from movements',
      () async {
    final productId = await productDao.createProduct(
      code: '20380',
      name: '六神180ML止痒花露水喷雾',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    final batchId = await productDao.createBatch(
      productId: productId,
      actualBatch: 'ELMAXEZ',
      dateBatch: '2029.6.14',
      initialBoxes: 100,
    );
    final orderId = await orderDao.createOrder(
      waybillNo: '168220019125',
      merchantName: '洁美A',
      orderDate: DateTime(2026, 4, 26),
    );
    await orderDao.addOrderItem(
      orderId: orderId,
      productId: productId,
      batchId: batchId,
      boxes: 20,
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    await stockDao.addMovement(
      batchId: batchId,
      orderId: Value(orderId),
      movementDate: DateTime(2026, 4, 26),
      type: StockMovementType.orderOut,
      boxes: 20,
    );

    expect(await stockDao.currentBoxesForBatch(batchId), 80);
    expect(await stockDao.totalInventoryPieces(), 2400);
  });

  test('stock dao supports total pieces snapshot by date', () async {
    final productId = await productDao.createProduct(
      code: '20382',
      name: '六神花露水快照测试',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    final batchId = await productDao.createBatch(
      productId: productId,
      actualBatch: 'SNAP-1',
      dateBatch: '2029.6.15',
      initialBoxes: 100,
    );

    await stockDao.addMovement(
      batchId: batchId,
      movementDate: DateTime(2026, 4, 26, 10),
      type: StockMovementType.orderOut,
      boxes: 20,
    );
    await stockDao.addMovement(
      batchId: batchId,
      movementDate: DateTime(2026, 4, 27, 10),
      type: StockMovementType.orderOut,
      boxes: 10,
    );

    expect(
      await stockDao.totalInventoryPiecesAt(
        DateTime(2026, 4, 26, 23, 59, 59),
      ),
      2400,
    );
    expect(
      await stockDao.totalInventoryPiecesAt(
        DateTime(2026, 4, 27, 23, 59, 59),
      ),
      2100,
    );
  });

  test('stock dao rejects invalid or overdrawn movements', () async {
    final productId = await productDao.createProduct(
      code: '99001',
      name: '测试产品',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    final batchId = await productDao.createBatch(
      productId: productId,
      actualBatch: 'SAFE',
      dateBatch: '2029.1.1',
      initialBoxes: 10,
    );

    expect(
      () => stockDao.addMovement(
        batchId: batchId,
        movementDate: DateTime(2026, 4, 26),
        type: StockMovementType.orderOut,
        boxes: 0,
      ),
      throwsA(isA<InvalidStockQuantityException>()),
    );
    expect(
      () => stockDao.addMovement(
        batchId: batchId,
        movementDate: DateTime(2026, 4, 26),
        type: StockMovementType.orderOut,
        boxes: 11,
      ),
      throwsA(isA<InsufficientStockException>()),
    );
    expect(await stockDao.currentBoxesForBatch(batchId), 10);
  });
}
