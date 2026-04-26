import 'package:drift/drift.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';

class OrderCompletionService {
  OrderCompletionService(this._database);

  final AppDatabase _database;

  Future<void> complete(int orderId) async {
    await _database.transaction(() async {
      final order = await (_database.select(_database.orders)
            ..where((table) => table.id.equals(orderId)))
          .getSingle();
      if (order.status == OrderStatus.done) {
        return;
      }

      final items = await (_database.select(_database.orderItems)
            ..where((table) => table.orderId.equals(orderId)))
          .get();
      final stockDao = StockDao(_database);
      final orderDao = OrderDao(_database);

      for (final item in items) {
        final currentBoxes = await stockDao.currentBoxesForBatch(item.batchId);
        if (currentBoxes < item.boxes) {
          throw InsufficientStockException(
            batchId: item.batchId,
            requestedBoxes: item.boxes,
            availableBoxes: currentBoxes,
          );
        }
      }

      for (final item in items) {
        await stockDao.addMovement(
          batchId: item.batchId,
          orderId: Value(orderId),
          movementDate: DateTime.now(),
          type: StockMovementType.orderOut,
          boxes: item.boxes,
          remark: '订单完成出库',
        );
      }
      await orderDao.setStatus(orderId, OrderStatus.done);
    });
  }
}
