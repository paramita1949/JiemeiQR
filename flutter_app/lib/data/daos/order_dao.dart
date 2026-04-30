import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:qrscan_flutter/shared/utils/board_calculator.dart';

import '../app_database.dart';
import 'stock_dao.dart';

class OrderDao {
  OrderDao(this._database);

  final AppDatabase _database;

  Future<int> createOrder({
    required String waybillNo,
    required String merchantName,
    required DateTime orderDate,
    String? remark,
  }) async {
    await _ensureWaybillNoAvailable(waybillNo: waybillNo);
    final normalizedDate = DateTime(
      orderDate.year,
      orderDate.month,
      orderDate.day,
    );
    final id = await _database.into(_database.orders).insert(
          OrdersCompanion.insert(
            waybillNo: waybillNo,
            merchantName: merchantName,
            orderDate: normalizedDate,
            remark: Value.absentIfNull(remark),
          ),
        );
    return id;
  }

  Future<int> addOrderItem({
    required int orderId,
    required int productId,
    required int batchId,
    required int boxes,
    required int boxesPerBoard,
    required int piecesPerBox,
  }) {
    return _database.into(_database.orderItems).insert(
          OrderItemsCompanion.insert(
            orderId: orderId,
            productId: productId,
            batchId: batchId,
            boxes: boxes,
            boxesPerBoard: boxesPerBoard,
            piecesPerBox: piecesPerBox,
          ),
        );
  }

  Future<int> createPendingWaybill({
    required String waybillNo,
    required String merchantName,
    required DateTime orderDate,
    required PendingOrderItemInput item,
  }) async {
    if (item.boxes <= 0 || item.boxes > 1000000000) {
      throw InvalidStockQuantityException(item.boxes);
    }
    final availableBoxes = await _availableBoxesForBatch(item.batchId);
    if (item.boxes > availableBoxes) {
      throw InsufficientStockException(
        batchId: item.batchId,
        requestedBoxes: item.boxes,
        availableBoxes: availableBoxes,
      );
    }

    return _database.transaction(() async {
      final orderId = await createOrder(
        waybillNo: waybillNo,
        merchantName: merchantName,
        orderDate: orderDate,
      );
      await addOrderItem(
        orderId: orderId,
        productId: item.productId,
        batchId: item.batchId,
        boxes: item.boxes,
        boxesPerBoard: item.boxesPerBoard,
        piecesPerBox: item.piecesPerBox,
      );
      return orderId;
    });
  }

  Future<void> setStatus(int orderId, OrderStatus status) async {
    await (_database.update(_database.orders)
          ..where((table) => table.id.equals(orderId)))
        .write(
      OrdersCompanion(
        status: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> findOrCreateOpenOrder({
    required String waybillNo,
    required String merchantName,
    required DateTime orderDate,
  }) async {
    final normalizedDate = DateTime(
      orderDate.year,
      orderDate.month,
      orderDate.day,
    );
    final existing = await (_database.select(_database.orders)
          ..where((table) =>
              table.waybillNo.equals(waybillNo) &
              table.merchantName.equals(merchantName) &
              table.orderDate.equals(normalizedDate) &
              table.status.isNotValue(OrderStatus.done.index))
          ..orderBy([(table) => OrderingTerm.desc(table.createdAt)])
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) {
      return existing.id;
    }
    return createOrder(
      waybillNo: waybillNo,
      merchantName: merchantName,
      orderDate: normalizedDate,
    );
  }

  Future<int?> findOpenOrderId({
    required String waybillNo,
    required String merchantName,
    required DateTime orderDate,
  }) async {
    final normalizedDate = DateTime(
      orderDate.year,
      orderDate.month,
      orderDate.day,
    );
    final existing = await (_database.select(_database.orders)
          ..where((table) =>
              table.waybillNo.equals(waybillNo) &
              table.merchantName.equals(merchantName) &
              table.orderDate.equals(normalizedDate) &
              table.status.isNotValue(OrderStatus.done.index))
          ..orderBy([(table) => OrderingTerm.desc(table.createdAt)])
          ..limit(1))
        .getSingleOrNull();
    return existing?.id;
  }

  Future<void> _ensureWaybillNoAvailable({
    required String waybillNo,
    int? excludeOrderId,
  }) async {
    final query = _database.select(_database.orders)
      ..where((table) => table.waybillNo.equals(waybillNo));
    if (excludeOrderId != null) {
      query.where((table) => table.id.isNotValue(excludeOrderId));
    }
    final duplicate = await (query..limit(1)).getSingleOrNull();
    if (duplicate != null) {
      throw DuplicateWaybillNoException(
        waybillNo: waybillNo,
        existingOrderId: duplicate.id,
      );
    }
  }

  Future<int> appendPendingWaybillItem({
    required String waybillNo,
    required String merchantName,
    required DateTime orderDate,
    required PendingOrderItemInput item,
  }) async {
    if (item.boxes <= 0 || item.boxes > 1000000000) {
      throw InvalidStockQuantityException(item.boxes);
    }
    final availableBoxes = await _availableBoxesForBatch(item.batchId);
    if (item.boxes > availableBoxes) {
      throw InsufficientStockException(
        batchId: item.batchId,
        requestedBoxes: item.boxes,
        availableBoxes: availableBoxes,
      );
    }
    return _database.transaction(() async {
      final orderId = await findOrCreateOpenOrder(
        waybillNo: waybillNo,
        merchantName: merchantName,
        orderDate: orderDate,
      );
      final duplicateItem = await (_database.select(_database.orderItems)
            ..where((table) =>
                table.orderId.equals(orderId) &
                table.productId.equals(item.productId) &
                table.batchId.equals(item.batchId))
            ..limit(1))
          .getSingleOrNull();
      if (duplicateItem != null) {
        throw DuplicateOrderItemException(
          orderId: orderId,
          itemId: duplicateItem.id,
          currentBoxes: duplicateItem.boxes,
          productId: item.productId,
          batchId: item.batchId,
        );
      }
      await addOrderItem(
        orderId: orderId,
        productId: item.productId,
        batchId: item.batchId,
        boxes: item.boxes,
        boxesPerBoard: item.boxesPerBoard,
        piecesPerBox: item.piecesPerBox,
      );
      return orderId;
    });
  }

  Future<void> appendItemToOrder({
    required int orderId,
    required PendingOrderItemInput item,
  }) async {
    if (item.boxes <= 0 || item.boxes > 1000000000) {
      throw InvalidStockQuantityException(item.boxes);
    }
    final availableBoxes = await _availableBoxesForBatch(item.batchId);
    if (item.boxes > availableBoxes) {
      throw InsufficientStockException(
        batchId: item.batchId,
        requestedBoxes: item.boxes,
        availableBoxes: availableBoxes,
      );
    }
    await _database.transaction(() async {
      final order = await (_database.select(_database.orders)
            ..where((table) => table.id.equals(orderId))
            ..limit(1))
          .getSingleOrNull();
      if (order == null) {
        return;
      }
      if (order.status == OrderStatus.done) {
        throw const OrderItemUpdateNotAllowedException();
      }
      final duplicateItem = await (_database.select(_database.orderItems)
            ..where((table) =>
                table.orderId.equals(orderId) &
                table.productId.equals(item.productId) &
                table.batchId.equals(item.batchId))
            ..limit(1))
          .getSingleOrNull();
      if (duplicateItem != null) {
        throw DuplicateOrderItemException(
          orderId: orderId,
          itemId: duplicateItem.id,
          currentBoxes: duplicateItem.boxes,
          productId: item.productId,
          batchId: item.batchId,
        );
      }
      await addOrderItem(
        orderId: orderId,
        productId: item.productId,
        batchId: item.batchId,
        boxes: item.boxes,
        boxesPerBoard: item.boxesPerBoard,
        piecesPerBox: item.piecesPerBox,
      );
      await (_database.update(_database.orders)
            ..where((table) => table.id.equals(orderId)))
          .write(OrdersCompanion(updatedAt: Value(DateTime.now())));
    });
  }

  Future<int> _availableBoxesForBatch(int batchId) async {
    final stockDao = StockDao(_database);
    final currentBoxes = await stockDao.currentBoxesForBatch(batchId);
    final pendingRow = await _database.customSelect(
      '''
      SELECT COALESCE(SUM(oi.boxes), 0) AS reserved_boxes
      FROM order_items oi
      INNER JOIN orders o ON o.id = oi.order_id
      WHERE oi.batch_id = ? AND o.status != ?
      ''',
      variables: [
        Variable.withInt(batchId),
        Variable.withInt(OrderStatus.done.index),
      ],
      readsFrom: {_database.orderItems, _database.orders},
    ).getSingleOrNull();
    final reserved = (pendingRow?.data['reserved_boxes'] as int?) ?? 0;
    final available = currentBoxes - reserved;
    return available < 0 ? 0 : available;
  }

  Future<int> _availableBoxesForBatchExcludingItem({
    required int batchId,
    required int excludeItemId,
  }) async {
    final stockDao = StockDao(_database);
    final currentBoxes = await stockDao.currentBoxesForBatch(batchId);
    final pendingRow = await _database.customSelect(
      '''
      SELECT COALESCE(SUM(oi.boxes), 0) AS reserved_boxes
      FROM order_items oi
      INNER JOIN orders o ON o.id = oi.order_id
      WHERE oi.batch_id = ? AND o.status != ? AND oi.id != ?
      ''',
      variables: [
        Variable.withInt(batchId),
        Variable.withInt(OrderStatus.done.index),
        Variable.withInt(excludeItemId),
      ],
      readsFrom: {_database.orderItems, _database.orders},
    ).getSingleOrNull();
    final reserved = (pendingRow?.data['reserved_boxes'] as int?) ?? 0;
    final available = currentBoxes - reserved;
    return available < 0 ? 0 : available;
  }

  Future<int> mergeDuplicateOrderItem({
    required int itemId,
    required int appendBoxes,
  }) async {
    final item = await (_database.select(_database.orderItems)
          ..where((table) => table.id.equals(itemId))
          ..limit(1))
        .getSingle();
    await (_database.update(_database.orderItems)
          ..where((table) => table.id.equals(itemId)))
        .write(
      OrderItemsCompanion(
        boxes: Value(item.boxes + appendBoxes),
      ),
    );
    return item.orderId;
  }

  Future<void> updateOrderBasic({
    required int orderId,
    required String waybillNo,
    required String merchantName,
    required DateTime orderDate,
  }) async {
    final normalizedDate = DateTime(
      orderDate.year,
      orderDate.month,
      orderDate.day,
    );
    await _ensureWaybillNoAvailable(
      waybillNo: waybillNo,
      excludeOrderId: orderId,
    );
    await (_database.update(_database.orders)
          ..where((table) => table.id.equals(orderId)))
        .write(
      OrdersCompanion(
        waybillNo: Value(waybillNo),
        merchantName: Value(merchantName),
        orderDate: Value(normalizedDate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteOrder(int orderId) async {
    await _database.transaction(() async {
      await (_database.delete(_database.stockMovements)
            ..where((table) => table.orderId.equals(orderId)))
          .go();
      await (_database.delete(_database.orderItems)
            ..where((table) => table.orderId.equals(orderId)))
          .go();
      await (_database.delete(_database.orders)
            ..where((table) => table.id.equals(orderId)))
          .go();
    });
  }

  Future<void> deleteOrderItem({
    required int itemId,
  }) async {
    await _database.transaction(() async {
      final item = await (_database.select(_database.orderItems)
            ..where((table) => table.id.equals(itemId)))
          .getSingleOrNull();
      if (item == null) {
        return;
      }
      final order = await (_database.select(_database.orders)
            ..where((table) => table.id.equals(item.orderId)))
          .getSingleOrNull();
      if (order == null) {
        return;
      }
      if (order.status == OrderStatus.done) {
        throw const OrderItemDeleteNotAllowedException();
      }
      await (_database.delete(_database.orderItems)
            ..where((table) => table.id.equals(itemId)))
          .go();
      final hasRemaining = await (_database.select(_database.orderItems)
            ..where((table) => table.orderId.equals(order.id)))
          .getSingleOrNull();
      if (hasRemaining != null) {
        return;
      }
      await (_database.delete(_database.stockMovements)
            ..where((table) => table.orderId.equals(order.id)))
          .go();
      await (_database.delete(_database.orders)
            ..where((table) => table.id.equals(order.id)))
          .go();
    });
  }

  Future<void> updateOrderItem({
    required int itemId,
    required int batchId,
    required int boxes,
    required int boxesPerBoard,
    required int piecesPerBox,
  }) async {
    if (boxes <= 0 || boxes > 1000000000) {
      throw InvalidStockQuantityException(boxes);
    }
    await _database.transaction(() async {
      final item = await (_database.select(_database.orderItems)
            ..where((table) => table.id.equals(itemId))
            ..limit(1))
          .getSingleOrNull();
      if (item == null) {
        return;
      }
      final order = await (_database.select(_database.orders)
            ..where((table) => table.id.equals(item.orderId))
            ..limit(1))
          .getSingleOrNull();
      if (order == null) {
        return;
      }
      final canCorrectCompletedException =
          order.status == OrderStatus.done && item.isException;
      if (order.status == OrderStatus.done && !canCorrectCompletedException) {
        throw const OrderItemUpdateNotAllowedException();
      }
      final availableBoxes = canCorrectCompletedException
          ? await StockDao(_database).currentBoxesForBatch(batchId)
          : await _availableBoxesForBatchExcludingItem(
              batchId: batchId,
              excludeItemId: itemId,
            );
      if (boxes > availableBoxes) {
        throw InsufficientStockException(
          batchId: batchId,
          requestedBoxes: boxes,
          availableBoxes: availableBoxes,
        );
      }
      await (_database.update(_database.orderItems)
            ..where((table) => table.id.equals(itemId)))
          .write(
        OrderItemsCompanion(
          batchId: Value(batchId),
          boxes: Value(boxes),
          boxesPerBoard: Value(boxesPerBoard),
          piecesPerBox: Value(piecesPerBox),
          isException: const Value(false),
        ),
      );
      if (canCorrectCompletedException) {
        await (_database.update(_database.stockMovements)
              ..where((table) =>
                  table.orderId.equals(order.id) &
                  table.batchId.equals(item.batchId) &
                  table.type.equals(StockMovementType.orderOut.index)))
            .write(
          StockMovementsCompanion(
            batchId: Value(batchId),
            boxes: Value(boxes),
          ),
        );
      }
      await (_database.update(_database.orders)
            ..where((table) => table.id.equals(order.id)))
          .write(OrdersCompanion(updatedAt: Value(DateTime.now())));
    });
  }

  Future<List<String>> recentMerchantNames({int limit = 10}) async {
    final rows = await _database.customSelect(
      '''
      SELECT merchant_name, COUNT(*) AS freq, MAX(created_at) AS latest
      FROM orders
      GROUP BY merchant_name
      ORDER BY freq DESC, latest DESC
      LIMIT ?
      ''',
      variables: [Variable.withInt(limit)],
      readsFrom: {_database.orders},
    ).get();
    return rows
        .map((row) => row.data['merchant_name'] as String?)
        .whereType<String>()
        .toList();
  }

  Future<List<OrderSummary>> orderSummaries({
    OrderStatus? status,
    DateTimeRange? dateRange,
  }) async {
    final page = await orderSummariesPage(
      status: status,
      dateRange: dateRange,
      offset: 0,
      limit: 1000000,
    );
    return page.orders;
  }

  Future<OrderStatusCounts> orderStatusCounts({
    DateTimeRange? dateRange,
  }) async {
    final rows = await _ordersInRange(dateRange).get();
    var done = 0;
    var unfinished = 0;
    var picked = 0;
    for (final order in rows) {
      if (order.status == OrderStatus.done) {
        done += 1;
      } else {
        unfinished += 1;
      }
      if (order.status == OrderStatus.picked) {
        picked += 1;
      }
    }
    return OrderStatusCounts(
        done: done, unfinished: unfinished, picked: picked);
  }

  Future<List<OrderRestockAggregate>> orderRestockAggregates({
    OrderStatus? status,
    DateTimeRange? dateRange,
    bool unfinishedOnly = false,
  }) async {
    final where = <String>[];
    final vars = <Variable<Object>>[];
    if (unfinishedOnly) {
      where.add('o.status != ?');
      vars.add(Variable.withInt(OrderStatus.done.index));
    } else if (status != null) {
      where.add('o.status = ?');
      vars.add(Variable.withInt(status.index));
    }
    if (dateRange != null) {
      final start = DateTime(
        dateRange.start.year,
        dateRange.start.month,
        dateRange.start.day,
      );
      final end = DateTime(
        dateRange.end.year,
        dateRange.end.month,
        dateRange.end.day,
        23,
        59,
        59,
      );
      where.add('o.order_date BETWEEN ? AND ?');
      vars.add(Variable.withDateTime(start));
      vars.add(Variable.withDateTime(end));
    }
    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await _database
        .customSelect(
          '''
      SELECT
        p.code AS product_code,
        b.actual_batch AS actual_batch,
        b.date_batch AS date_batch,
        SUM(oi.boxes) AS total_boxes,
        MAX(oi.boxes_per_board) AS boxes_per_board
      FROM order_items oi
      INNER JOIN orders o ON o.id = oi.order_id
      INNER JOIN products p ON p.id = oi.product_id
      INNER JOIN batches b ON b.id = oi.batch_id
      $whereSql
      GROUP BY p.code, b.actual_batch, b.date_batch
      ORDER BY p.code ASC, b.date_batch ASC, b.actual_batch ASC
      ''',
          variables: vars,
          readsFrom: {
            _database.orderItems,
            _database.orders,
            _database.products,
            _database.batches,
          },
        )
        .get();
    final variants = await _batchCodesByProductDate();
    return rows
        .map((row) {
          final productCode = row.data['product_code'] as String? ?? '';
          final dateBatch = row.data['date_batch'] as String? ?? '';
          return OrderRestockAggregate(
            productCode: productCode,
            actualBatch: row.data['actual_batch'] as String? ?? '',
            dateBatch: dateBatch,
            totalBoxes: (row.data['total_boxes'] as int?) ?? 0,
            boxesPerBoard: (row.data['boxes_per_board'] as int?) ?? 1,
            batchCodeVariants:
                variants['$productCode|$dateBatch'] ?? const <String>[],
          );
        })
        .where((row) => row.productCode.isNotEmpty)
        .toList();
  }

  Future<Map<String, List<String>>> _batchCodesByProductDate() async {
    final rows = await _database.customSelect(
      '''
      SELECT
        p.code AS product_code,
        b.date_batch AS date_batch,
        b.actual_batch AS actual_batch
      FROM batches b
      INNER JOIN products p ON p.id = b.product_id
      ORDER BY p.code ASC, b.date_batch ASC, b.actual_batch ASC
      ''',
      readsFrom: {
        _database.products,
        _database.batches,
      },
    ).get();
    final result = <String, List<String>>{};
    for (final row in rows) {
      final productCode = row.data['product_code'] as String? ?? '';
      final dateBatch = row.data['date_batch'] as String? ?? '';
      final actualBatch = row.data['actual_batch'] as String? ?? '';
      if (productCode.isEmpty || dateBatch.isEmpty || actualBatch.isEmpty) {
        continue;
      }
      result
          .putIfAbsent('$productCode|$dateBatch', () => <String>[])
          .add(actualBatch);
    }
    return result;
  }

  Future<PagedOrderSummaries> orderSummariesPage({
    OrderStatus? status,
    DateTimeRange? dateRange,
    bool unfinishedOnly = false,
    bool exceptionOnly = false,
    required int offset,
    required int limit,
  }) async {
    final exceptionOrderIds = exceptionOnly
        ? await _exceptionOrderIdsPage(
            status: status,
            dateRange: dateRange,
            unfinishedOnly: unfinishedOnly,
            offset: offset,
            limit: limit,
          )
        : null;
    if (exceptionOnly && exceptionOrderIds!.ids.isEmpty) {
      return PagedOrderSummaries(
        orders: const <OrderSummary>[],
        total: exceptionOrderIds.total,
      );
    }
    final orderTable = _database.orders;
    final countExp = orderTable.id.count();
    final countQuery = _database.selectOnly(orderTable)..addColumns([countExp]);
    if (unfinishedOnly) {
      countQuery.where(orderTable.status.isNotValue(OrderStatus.done.index));
    } else if (status != null) {
      countQuery.where(orderTable.status.equals(status.index));
    }
    if (dateRange != null) {
      final start = DateTime(
        dateRange.start.year,
        dateRange.start.month,
        dateRange.start.day,
      );
      final end = DateTime(
        dateRange.end.year,
        dateRange.end.month,
        dateRange.end.day,
        23,
        59,
        59,
      );
      countQuery.where(orderTable.orderDate.isBetweenValues(start, end));
    }
    final total = exceptionOnly
        ? exceptionOrderIds!.total
        : (await countQuery.getSingle()).read(countExp) ?? 0;

    final query = _database.select(_database.orders);
    if (exceptionOnly) {
      query.where((table) => table.id.isIn(exceptionOrderIds!.ids));
    }
    if (unfinishedOnly) {
      query.where((table) => table.status.isNotValue(OrderStatus.done.index));
    } else if (status != null) {
      query.where((table) => table.status.equals(status.index));
    }
    if (dateRange != null) {
      final start = DateTime(
        dateRange.start.year,
        dateRange.start.month,
        dateRange.start.day,
      );
      final end = DateTime(
        dateRange.end.year,
        dateRange.end.month,
        dateRange.end.day,
        23,
        59,
        59,
      );
      query.where((table) => table.orderDate.isBetweenValues(start, end));
    }
    if (!exceptionOnly) {
      query.orderBy([
        (table) => OrderingTerm.desc(table.orderDate),
        (table) => OrderingTerm.desc(table.createdAt),
      ]);
      query.limit(limit, offset: offset);
    }

    final orders = await query.get();
    if (exceptionOnly) {
      orders.sort(
        (a, b) =>
            exceptionOrderIds!.ids.indexOf(a.id) -
            exceptionOrderIds.ids.indexOf(b.id),
      );
    }
    if (orders.isEmpty) {
      return PagedOrderSummaries(
        orders: const <OrderSummary>[],
        total: total,
      );
    }
    final orderIds = orders.map((order) => order.id).toList();
    final items = await (_database.select(_database.orderItems)
          ..where((table) => table.orderId.isIn(orderIds)))
        .get();
    final productIds = items.map((item) => item.productId).toSet().toList();
    final batchIds = items.map((item) => item.batchId).toSet().toList();
    final products = productIds.isEmpty
        ? const <Product>[]
        : await (_database.select(_database.products)
              ..where((table) => table.id.isIn(productIds)))
            .get();
    final productsById = {for (final product in products) product.id: product};
    final batches = batchIds.isEmpty
        ? const <BatchRecord>[]
        : await (_database.select(_database.batches)
              ..where((table) => table.id.isIn(batchIds)))
            .get();
    final batchById = {
      for (final batch in batches) batch.id: batch,
    };
    final statByOrderId = <int, _OrderItemStats>{};
    for (final item in items) {
      final batch = batchById[item.batchId];
      final tsRequired = batch?.tsRequired ?? false;
      final location = batch?.location;
      statByOrderId.update(
        item.orderId,
        (value) => value.add(
          item.boxes,
          tsRequired: tsRequired,
          isException: item.isException,
          location: location,
        ),
        ifAbsent: () => _OrderItemStats(
          item.boxes,
          tsRequired: tsRequired,
          isException: item.isException,
          location: location,
        ),
      );
    }
    final summaries = <OrderSummary>[];
    for (final order in orders) {
      final stats = statByOrderId[order.id];
      summaries.add(
        OrderSummary(
          id: order.id,
          waybillNo: order.waybillNo,
          merchantName: order.merchantName,
          orderDate: order.orderDate,
          status: order.status,
          itemCount: stats?.count ?? 0,
          totalBoxes: stats?.totalBoxes ?? 0,
          hasTsRequired: stats?.hasTsRequired ?? false,
          hasException: stats?.hasException ?? false,
          locationsText: stats?.locationsText ?? '',
          restockSummaryText: _restockSummaryText(
            orderItems:
                items.where((item) => item.orderId == order.id).toList(),
            productsById: productsById,
            batchesById: batchById,
          ),
        ),
      );
    }
    return PagedOrderSummaries(orders: summaries, total: total);
  }

  Future<_ExceptionOrderIdsPage> _exceptionOrderIdsPage({
    OrderStatus? status,
    DateTimeRange? dateRange,
    bool unfinishedOnly = false,
    required int offset,
    required int limit,
  }) async {
    final where = <String>['oi.is_exception = 1'];
    final vars = <Variable<Object>>[];
    if (unfinishedOnly) {
      where.add('o.status != ?');
      vars.add(Variable.withInt(OrderStatus.done.index));
    } else if (status != null) {
      where.add('o.status = ?');
      vars.add(Variable.withInt(status.index));
    }
    if (dateRange != null) {
      final start = DateTime(
        dateRange.start.year,
        dateRange.start.month,
        dateRange.start.day,
      );
      final end = DateTime(
        dateRange.end.year,
        dateRange.end.month,
        dateRange.end.day,
        23,
        59,
        59,
      );
      where.add('o.order_date BETWEEN ? AND ?');
      vars.add(Variable.withDateTime(start));
      vars.add(Variable.withDateTime(end));
    }
    final whereSql = where.join(' AND ');
    final totalRow = await _database
        .customSelect(
          '''
      SELECT COUNT(DISTINCT o.id) AS total
      FROM orders o
      INNER JOIN order_items oi ON oi.order_id = o.id
      WHERE $whereSql
      ''',
          variables: vars,
          readsFrom: {_database.orders, _database.orderItems},
        )
        .getSingle();
    final rows = await _database.customSelect(
      '''
      SELECT DISTINCT o.id AS order_id, o.order_date, o.created_at
      FROM orders o
      INNER JOIN order_items oi ON oi.order_id = o.id
      WHERE $whereSql
      ORDER BY o.order_date DESC, o.created_at DESC
      LIMIT ? OFFSET ?
      ''',
      variables: [
        ...vars,
        Variable.withInt(limit),
        Variable.withInt(offset),
      ],
      readsFrom: {_database.orders, _database.orderItems},
    ).get();
    return _ExceptionOrderIdsPage(
      ids: rows
          .map((row) => row.data['order_id'] as int?)
          .whereType<int>()
          .toList(growable: false),
      total: (totalRow.data['total'] as int?) ?? 0,
    );
  }

  Future<OrderDetail> orderDetail(int orderId) async {
    final order = await (_database.select(_database.orders)
          ..where((table) => table.id.equals(orderId)))
        .getSingle();
    final items = await (_database.select(_database.orderItems)
          ..where((table) => table.orderId.equals(orderId)))
        .get();
    if (items.isEmpty) {
      return OrderDetail(order: order, lines: const <OrderDetailLine>[]);
    }
    final productIds = items.map((item) => item.productId).toSet().toList();
    final batchIds = items.map((item) => item.batchId).toSet().toList();
    final products = await (_database.select(_database.products)
          ..where((table) => table.id.isIn(productIds)))
        .get();
    final batches = await (_database.select(_database.batches)
          ..where((table) => table.id.isIn(batchIds)))
        .get();
    final productsById = {for (final product in products) product.id: product};
    final batchesById = {for (final batch in batches) batch.id: batch};
    final lines = <OrderDetailLine>[];

    for (final item in items) {
      final product = productsById[item.productId];
      final batch = batchesById[item.batchId];
      if (product == null || batch == null) {
        continue;
      }
      lines.add(
        OrderDetailLine(
          item: item,
          product: product,
          batch: batch,
        ),
      );
    }

    return OrderDetail(order: order, lines: lines);
  }

  SimpleSelectStatement<$OrdersTable, Order> _ordersInRange(
    DateTimeRange? dateRange,
  ) {
    final query = _database.select(_database.orders);
    if (dateRange != null) {
      final start = DateTime(
        dateRange.start.year,
        dateRange.start.month,
        dateRange.start.day,
      );
      final end = DateTime(
        dateRange.end.year,
        dateRange.end.month,
        dateRange.end.day,
        23,
        59,
        59,
      );
      query.where((table) => table.orderDate.isBetweenValues(start, end));
    }
    return query;
  }

  String _restockSummaryText({
    required List<OrderItem> orderItems,
    required Map<int, Product> productsById,
    required Map<int, BatchRecord> batchesById,
  }) {
    final boxesByProductDate = <String, _RestockBoxesAccumulator>{};
    for (final item in orderItems) {
      final product = productsById[item.productId];
      final batch = batchesById[item.batchId];
      if (product == null || batch == null || item.boxesPerBoard <= 0) {
        continue;
      }
      final key = '${product.code}|${batch.dateBatch}';
      boxesByProductDate.update(
        key,
        (value) => value.add(boxes: item.boxes),
        ifAbsent: () => _RestockBoxesAccumulator(
          totalBoxes: item.boxes,
          boxesPerBoard: item.boxesPerBoard,
        ),
      );
    }
    if (boxesByProductDate.isEmpty) {
      return '';
    }
    final entries = boxesByProductDate.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((entry) {
      final parts = entry.key.split('|');
      final code = parts.first;
      final dateBatch = parts.length > 1 ? parts[1] : '';
      final text = BoardCalculator.format(
        boxes: entry.value.totalBoxes,
        boxesPerBoard: entry.value.boxesPerBoard,
      );
      return '$code $dateBatch 需$text';
    }).join(' / ');
  }
}

class PendingOrderItemInput {
  const PendingOrderItemInput({
    required this.productId,
    required this.batchId,
    required this.boxes,
    required this.boxesPerBoard,
    required this.piecesPerBox,
  });

  final int productId;
  final int batchId;
  final int boxes;
  final int boxesPerBoard;
  final int piecesPerBox;
}

class OrderItemDeleteNotAllowedException implements Exception {
  const OrderItemDeleteNotAllowedException();

  @override
  String toString() => 'OrderItemDeleteNotAllowedException';
}

class OrderItemUpdateNotAllowedException implements Exception {
  const OrderItemUpdateNotAllowedException();

  @override
  String toString() => 'OrderItemUpdateNotAllowedException';
}

class DuplicateOrderItemException implements Exception {
  const DuplicateOrderItemException({
    required this.orderId,
    required this.itemId,
    required this.currentBoxes,
    required this.productId,
    required this.batchId,
  });

  final int orderId;
  final int itemId;
  final int currentBoxes;
  final int productId;
  final int batchId;

  @override
  String toString() {
    return 'DuplicateOrderItemException(orderId: $orderId, itemId: $itemId, currentBoxes: $currentBoxes, productId: $productId, batchId: $batchId)';
  }
}

class DuplicateWaybillNoException implements Exception {
  const DuplicateWaybillNoException({
    required this.waybillNo,
    required this.existingOrderId,
  });

  final String waybillNo;
  final int existingOrderId;

  @override
  String toString() {
    return 'DuplicateWaybillNoException(waybillNo: $waybillNo, existingOrderId: $existingOrderId)';
  }
}

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.waybillNo,
    required this.merchantName,
    required this.orderDate,
    required this.status,
    required this.itemCount,
    required this.totalBoxes,
    required this.hasTsRequired,
    required this.hasException,
    required this.locationsText,
    required this.restockSummaryText,
  });

  final int id;
  final String waybillNo;
  final String merchantName;
  final DateTime orderDate;
  final OrderStatus status;
  final int itemCount;
  final int totalBoxes;
  final bool hasTsRequired;
  final bool hasException;
  final String locationsText;
  final String restockSummaryText;

  String get dateText =>
      '${orderDate.year}.${orderDate.month}.${orderDate.day}';
}

class PagedOrderSummaries {
  const PagedOrderSummaries({
    required this.orders,
    required this.total,
  });

  final List<OrderSummary> orders;
  final int total;
}

class OrderStatusCounts {
  const OrderStatusCounts({
    required this.done,
    required this.unfinished,
    required this.picked,
  });

  final int done;
  final int unfinished;
  final int picked;
}

class OrderRestockAggregate {
  const OrderRestockAggregate({
    required this.productCode,
    required this.actualBatch,
    required this.dateBatch,
    required this.totalBoxes,
    required this.boxesPerBoard,
    required this.batchCodeVariants,
  });

  final String productCode;
  final String actualBatch;
  final String dateBatch;
  final int totalBoxes;
  final int boxesPerBoard;
  final List<String> batchCodeVariants;
}

class _ExceptionOrderIdsPage {
  const _ExceptionOrderIdsPage({
    required this.ids,
    required this.total,
  });

  final List<int> ids;
  final int total;
}

class _RestockBoxesAccumulator {
  const _RestockBoxesAccumulator({
    required this.totalBoxes,
    required this.boxesPerBoard,
  });

  final int totalBoxes;
  final int boxesPerBoard;

  _RestockBoxesAccumulator add({required int boxes}) {
    return _RestockBoxesAccumulator(
      totalBoxes: totalBoxes + boxes,
      boxesPerBoard: boxesPerBoard,
    );
  }
}

class OrderDetail {
  const OrderDetail({
    required this.order,
    required this.lines,
  });

  final Order order;
  final List<OrderDetailLine> lines;
}

class OrderDetailLine {
  const OrderDetailLine({
    required this.item,
    required this.product,
    required this.batch,
  });

  final OrderItem item;
  final Product product;
  final BatchRecord batch;
}

class _OrderItemStats {
  _OrderItemStats(
    this.totalBoxes, {
    required bool tsRequired,
    required bool isException,
    String? location,
  })  : hasTsRequired = tsRequired,
        hasException = isException {
    if (location != null && location.isNotEmpty) {
      _locations.add(location);
    }
  }

  int count = 1;
  int totalBoxes;
  bool hasTsRequired;
  bool hasException;
  final Set<String> _locations = <String>{};

  String get locationsText {
    if (_locations.isEmpty) {
      return '';
    }
    final locations = _locations.toList()..sort();
    if (locations.length <= 2) {
      return locations.join(' / ');
    }
    return '${locations.take(2).join(' / ')} 等${locations.length}个库位';
  }

  _OrderItemStats add(
    int boxes, {
    required bool tsRequired,
    required bool isException,
    String? location,
  }) {
    count += 1;
    totalBoxes += boxes;
    hasTsRequired = hasTsRequired || tsRequired;
    hasException = hasException || isException;
    if (location != null && location.isNotEmpty) {
      _locations.add(location);
    }
    return this;
  }
}
