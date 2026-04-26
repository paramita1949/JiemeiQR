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
  }) {
    return _database.into(_database.orders).insert(
          OrdersCompanion.insert(
            waybillNo: waybillNo,
            merchantName: merchantName,
            orderDate: orderDate,
            remark: Value.absentIfNull(remark),
          ),
        );
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
    final statByOrderId = <int, _OrderItemStats>{};
    for (final item in items) {
      statByOrderId.update(
        item.orderId,
        (value) => value.add(item.boxes),
        ifAbsent: () => _OrderItemStats(item.boxes),
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

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.waybillNo,
    required this.merchantName,
    required this.orderDate,
    required this.status,
    required this.itemCount,
    required this.totalBoxes,
  });

  final int id;
  final String waybillNo;
  final String merchantName;
  final DateTime orderDate;
  final OrderStatus status;
  final int itemCount;
  final int totalBoxes;

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
  _OrderItemStats(this.totalBoxes);

  int count = 1;
  int totalBoxes;

  _OrderItemStats add(int boxes) {
    count += 1;
    totalBoxes += boxes;
    return this;
  }
}
