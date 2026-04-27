import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

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
    final stockDao = StockDao(_database);
    final availableBoxes = await stockDao.currentBoxesForBatch(item.batchId);
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

  Future<int> appendPendingWaybillItem({
    required String waybillNo,
    required String merchantName,
    required DateTime orderDate,
    required PendingOrderItemInput item,
  }) async {
    if (item.boxes <= 0 || item.boxes > 1000000000) {
      throw InvalidStockQuantityException(item.boxes);
    }
    final stockDao = StockDao(_database);
    final availableBoxes = await stockDao.currentBoxesForBatch(item.batchId);
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

  Future<PagedOrderSummaries> orderSummariesPage({
    OrderStatus? status,
    DateTimeRange? dateRange,
    required int offset,
    required int limit,
  }) async {
    final orderTable = _database.orders;
    final countExp = orderTable.id.count();
    final countQuery = _database.selectOnly(orderTable)..addColumns([countExp]);
    if (status != null) {
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
    final total = (await countQuery.getSingle()).read(countExp) ?? 0;

    final query = _database.select(_database.orders);
    if (status != null) {
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
    query.orderBy([
      (table) => OrderingTerm.desc(table.orderDate),
      (table) => OrderingTerm.desc(table.createdAt),
    ]);
    query.limit(limit, offset: offset);

    final orders = await query.get();
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
    final batchIds = items.map((item) => item.batchId).toSet().toList();
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
          location: location,
        ),
        ifAbsent: () => _OrderItemStats(
          item.boxes,
          tsRequired: tsRequired,
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
          locationsText: stats?.locationsText ?? '',
        ),
      );
    }
    return PagedOrderSummaries(orders: summaries, total: total);
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

class DuplicateOrderItemException implements Exception {
  const DuplicateOrderItemException({
    required this.orderId,
    required this.productId,
    required this.batchId,
  });

  final int orderId;
  final int productId;
  final int batchId;

  @override
  String toString() {
    return 'DuplicateOrderItemException(orderId: $orderId, productId: $productId, batchId: $batchId)';
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
    required this.locationsText,
  });

  final int id;
  final String waybillNo;
  final String merchantName;
  final DateTime orderDate;
  final OrderStatus status;
  final int itemCount;
  final int totalBoxes;
  final bool hasTsRequired;
  final String locationsText;

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
    String? location,
  }) : hasTsRequired = tsRequired {
    if (location != null && location.isNotEmpty) {
      _locations.add(location);
    }
  }

  int count = 1;
  int totalBoxes;
  bool hasTsRequired;
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
    String? location,
  }) {
    count += 1;
    totalBoxes += boxes;
    hasTsRequired = hasTsRequired || tsRequired;
    if (location != null && location.isNotEmpty) {
      _locations.add(location);
    }
    return this;
  }
}
