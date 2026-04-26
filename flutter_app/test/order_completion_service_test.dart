import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';
import 'package:qrscan_flutter/features/orders/order_completion_service.dart';

void main() {
  late AppDatabase database;
  late ProductDao productDao;
  late OrderDao orderDao;
  late StockDao stockDao;
  late OrderCompletionService service;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    productDao = ProductDao(database);
    orderDao = OrderDao(database);
    stockDao = StockDao(database);
    service = OrderCompletionService(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> seedOrder(
      {required int stockBoxes, required int orderBoxes}) async {
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
      initialBoxes: stockBoxes,
    );
    return orderDao.createPendingWaybill(
      waybillNo: '168220019125',
      merchantName: '洁美A',
      orderDate: DateTime(2026, 4, 26),
      item: PendingOrderItemInput(
        productId: productId,
        batchId: batchId,
        boxes: orderBoxes,
        boxesPerBoard: 40,
        piecesPerBox: 30,
      ),
    );
  }

  test('completes order, deducts stock, and prevents duplicate deduction',
      () async {
    final orderId = await seedOrder(stockBoxes: 100, orderBoxes: 20);

    await service.complete(orderId);
    await service.complete(orderId);

    final order = await database.select(database.orders).getSingle();
    final movementCount = await database.select(database.stockMovements).get();
    final batch = await database.select(database.batches).getSingle();

    expect(order.status, OrderStatus.done);
    expect(movementCount, hasLength(1));
    expect(movementCount.single.type, StockMovementType.orderOut);
    expect(await stockDao.currentBoxesForBatch(batch.id), 80);
  });

  test('throws when stock is insufficient', () async {
    final orderId = await seedOrder(stockBoxes: 20, orderBoxes: 20);
    final batch = await database.select(database.batches).getSingle();
    await stockDao.addMovement(
      batchId: batch.id,
      movementDate: DateTime(2026, 4, 25),
      type: StockMovementType.lossOut,
      boxes: 10,
    );

    expect(
      () => service.complete(orderId),
      throwsA(isA<InsufficientStockException>()),
    );
    expect(await database.select(database.stockMovements).get(), hasLength(1));
  });
}
