import 'package:drift/drift.dart';
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

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    productDao = ProductDao(database);
    orderDao = OrderDao(database);
    stockDao = StockDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('exception order item can be corrected after completion', () async {
    final productId = await productDao.createProduct(
      code: '72067',
      name: '六神花露水195ML',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );
    final wrongBatchId = await productDao.createBatch(
      productId: productId,
      actualBatch: '123',
      dateBatch: '2029.1.1',
      initialBoxes: 100,
    );
    final rightBatchId = await productDao.createBatch(
      productId: productId,
      actualBatch: '124',
      dateBatch: '2029.1.1',
      initialBoxes: 100,
    );
    final orderId = await orderDao.createPendingWaybill(
      waybillNo: 'DONE-ERR',
      merchantName: '洁美A',
      orderDate: DateTime(2026, 4, 30),
      item: PendingOrderItemInput(
        productId: productId,
        batchId: wrongBatchId,
        boxes: 10,
        boxesPerBoard: 40,
        piecesPerBox: 30,
      ),
    );
    await OrderCompletionService(database).complete(orderId);
    await (database.update(database.orderItems)
          ..where((table) => table.orderId.equals(orderId)))
        .write(const OrderItemsCompanion(isException: Value(true)));

    final item = await database.select(database.orderItems).getSingle();
    await orderDao.updateOrderItem(
      itemId: item.id,
      batchId: rightBatchId,
      boxes: 10,
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );

    final updatedItem = await database.select(database.orderItems).getSingle();
    final movements = await database.select(database.stockMovements).get();
    expect(updatedItem.batchId, rightBatchId);
    expect(updatedItem.isException, isFalse);
    expect(movements.single.batchId, rightBatchId);
    expect(await stockDao.currentBoxesForBatch(wrongBatchId), 100);
    expect(await stockDao.currentBoxesForBatch(rightBatchId), 90);
  });
}
