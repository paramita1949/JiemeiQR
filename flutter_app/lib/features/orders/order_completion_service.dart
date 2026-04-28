import 'package:drift/drift.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/order_dao.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';

class OrderCompletionService {
  OrderCompletionService(this._database);

  final AppDatabase _database;

  Future<void> updateStatus({
    required int orderId,
    required OrderStatus target,
  }) async {
    await _database.transaction(() async {
      final orderDao = OrderDao(_database);
      final order = await (_database.select(_database.orders)
            ..where((table) => table.id.equals(orderId)))
          .getSingle();
      final current = order.status;
      if (current == target) {
        return;
      }

      if (target == OrderStatus.done) {
        await _completeInTransaction(orderId: orderId, currentStatus: current);
        return;
      }

      if (current == OrderStatus.done) {
        await (_database.delete(_database.stockMovements)
              ..where((table) =>
                  table.orderId.equals(orderId) &
                  table.type.equals(StockMovementType.orderOut.index)))
            .go();
      }

      await orderDao.setStatus(orderId, target);
    });
  }

  Future<void> complete(int orderId) async {
    await _database.transaction(() async {
      final order = await (_database.select(_database.orders)
            ..where((table) => table.id.equals(orderId)))
          .getSingle();
      await _completeInTransaction(
        orderId: orderId,
        currentStatus: order.status,
      );
    });
  }

  Future<void> _completeInTransaction({
    required int orderId,
    required OrderStatus currentStatus,
  }) async {
    if (currentStatus == OrderStatus.done) {
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
  }
}
