import 'package:drift/drift.dart';

import '../app_database.dart';

class StockDao {
  StockDao(this._database);

  final AppDatabase _database;

  Future<int> addMovement({
    required int batchId,
    required DateTime movementDate,
    required StockMovementType type,
    required int boxes,
    Value<int> orderId = const Value.absent(),
    String? remark,
  }) async {
    _validateBoxes(boxes);
    if (_isOutbound(type)) {
      final availableBoxes = await currentBoxesForBatch(batchId);
      if (boxes > availableBoxes) {
        throw InsufficientStockException(
          batchId: batchId,
          requestedBoxes: boxes,
          availableBoxes: availableBoxes,
        );
      }
    }

    final movementId = await _database.into(_database.stockMovements).insert(
          StockMovementsCompanion.insert(
            batchId: batchId,
            orderId: orderId,
            movementDate: movementDate,
            type: type,
            boxes: boxes,
            remark: Value.absentIfNull(remark),
          ),
        );
    if (type == StockMovementType.orderOut) {
      await (_database.update(_database.batches)
            ..where((table) => table.id.equals(batchId)))
          .write(
        BatchesCompanion(
          hasShipped: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
    return movementId;
  }

  Future<int> currentBoxesForBatch(int batchId) async {
    final batch = await (_database.select(_database.batches)
          ..where((table) => table.id.equals(batchId)))
        .getSingle();
    final movements = await (_database.select(_database.stockMovements)
          ..where((table) => table.batchId.equals(batchId)))
        .get();

    return movements.fold<int>(
      batch.initialBoxes,
      (stock, movement) => stock + _movementDelta(movement),
    );
  }

  Future<int> totalInventoryPieces() async {
    return totalInventoryPiecesAt(DateTime.now());
  }

  Future<int> totalInventoryPiecesAt(DateTime snapshotAt) async {
    final movementDeltaSql = '''
      COALESCE(SUM(CASE
        WHEN type IN (${StockMovementType.initial.index}, ${StockMovementType.inAdjust.index})
          THEN boxes
        ELSE -boxes
      END), 0)
    ''';
    final row = await _database.customSelect(
      '''
      SELECT COALESCE(SUM((b.initial_boxes + COALESCE(m.delta_boxes, 0)) * p.pieces_per_box), 0) AS total_pieces
      FROM batches b
      INNER JOIN products p ON p.id = b.product_id
      LEFT JOIN (
        SELECT batch_id, $movementDeltaSql AS delta_boxes
        FROM stock_movements
        WHERE movement_date <= ?
        GROUP BY batch_id
      ) m ON m.batch_id = b.id
      ''',
      variables: [Variable.withDateTime(snapshotAt)],
      readsFrom: {
        _database.batches,
        _database.products,
        _database.stockMovements,
      },
    ).getSingleOrNull();
    return (row?.data['total_pieces'] as int?) ?? 0;
  }

  Future<List<InventoryDetailRow>> inventoryDetailRows() async {
    final batches = await (_database.select(_database.batches)
          ..orderBy([
            (table) => OrderingTerm.desc(table.createdAt),
          ]))
        .get();
    if (batches.isEmpty) {
      return const <InventoryDetailRow>[];
    }
    final batchIds = batches.map((batch) => batch.id).toList();
    final productIds = batches.map((batch) => batch.productId).toSet().toList();
    final productsById = await _productsByIds(productIds);
    final deltas = await _movementDeltasByBatchIds(batchIds);
    final rows = <InventoryDetailRow>[];

    for (final batch in batches) {
      final product = productsById[batch.productId];
      if (product == null) {
        continue;
      }
      final currentBoxes = batch.initialBoxes + (deltas[batch.id] ?? 0);
      rows.add(
        InventoryDetailRow(
          product: product,
          batch: batch,
          currentBoxes: currentBoxes,
        ),
      );
    }

    rows.sort(_compareRowsByProductAndDate);
    return rows;
  }

  Future<PagedInventoryDetailRows> inventoryDetailRowsPage({
    required int offset,
    required int limit,
    String queryText = '',
    InventoryStockFilter stockFilter = InventoryStockFilter.all,
  }) async {
    final normalized = queryText.trim().toLowerCase();
    final whereParts = <String>[];
    final havingParts = <String>[];
    final vars = <Variable<Object>>[];
    final countVars = <Variable<Object>>[];

    if (normalized.isNotEmpty) {
      whereParts.add(
        '(LOWER(p.code) LIKE ? OR LOWER(b.actual_batch) LIKE ? OR LOWER(b.date_batch) LIKE ?)',
      );
      final pattern = '%$normalized%';
      for (var i = 0; i < 3; i += 1) {
        vars.add(Variable.withString(pattern));
        countVars.add(Variable.withString(pattern));
      }
    }

    final movementDeltaSql = '''
      COALESCE(SUM(CASE
        WHEN m.type IN (${StockMovementType.initial.index}, ${StockMovementType.inAdjust.index})
          THEN m.boxes
        ELSE -m.boxes
      END), 0)
    ''';
    final currentBoxesSql = '(b.initial_boxes + $movementDeltaSql)';
    const dateRestSql = "substr(b.date_batch, instr(b.date_batch, '.') + 1)";
    const dateYearSql = '''
      CASE
        WHEN instr(b.date_batch, '.') > 0
          THEN CAST(substr(b.date_batch, 1, instr(b.date_batch, '.') - 1) AS INTEGER)
        ELSE 0
      END
    ''';
    const dateMonthSql = '''
      CASE
        WHEN instr(b.date_batch, '.') > 0 AND instr($dateRestSql, '.') > 0
          THEN CAST(substr($dateRestSql, 1, instr($dateRestSql, '.') - 1) AS INTEGER)
        ELSE 0
      END
    ''';
    const dateDaySql = '''
      CASE
        WHEN instr(b.date_batch, '.') > 0 AND instr($dateRestSql, '.') > 0
          THEN CAST(substr($dateRestSql, instr($dateRestSql, '.') + 1) AS INTEGER)
        ELSE 0
      END
    ''';

    switch (stockFilter) {
      case InventoryStockFilter.all:
        break;
      case InventoryStockFilter.inStock:
        havingParts.add('$currentBoxesSql > 0');
        break;
      case InventoryStockFilter.zero:
        havingParts.add('$currentBoxesSql = 0');
        break;
    }

    final whereSql =
        whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}';
    final havingSql =
        havingParts.isEmpty ? '' : 'HAVING ${havingParts.join(' AND ')}';

    final countRows = await _database
        .customSelect(
          '''
      SELECT COUNT(*) AS c
      FROM (
        SELECT b.id
        FROM batches b
        INNER JOIN products p ON p.id = b.product_id
        LEFT JOIN stock_movements m ON m.batch_id = b.id
        $whereSql
        GROUP BY b.id, b.initial_boxes, b.created_at, p.code, b.date_batch
        $havingSql
      ) t
      ''',
          variables: countVars,
          readsFrom: {
            _database.batches,
            _database.products,
            _database.stockMovements,
          },
        )
        .getSingle();
    final total = (countRows.data['c'] as int?) ?? 0;
    if (total == 0) {
      return const PagedInventoryDetailRows(
          rows: <InventoryDetailRow>[], total: 0);
    }

    vars.add(Variable.withInt(limit));
    vars.add(Variable.withInt(offset));
    final pageRows = await _database
        .customSelect(
          '''
      SELECT
        b.id AS batch_id,
        $currentBoxesSql AS current_boxes
      FROM batches b
      INNER JOIN products p ON p.id = b.product_id
      LEFT JOIN stock_movements m ON m.batch_id = b.id
      $whereSql
      GROUP BY b.id, b.initial_boxes, b.created_at, p.code, b.date_batch
      $havingSql
      ORDER BY
        p.code ASC,
        $dateYearSql ASC,
        $dateMonthSql ASC,
        $dateDaySql ASC,
        b.created_at ASC
      LIMIT ? OFFSET ?
      ''',
          variables: vars,
          readsFrom: {
            _database.batches,
            _database.products,
            _database.stockMovements,
          },
        )
        .get();
    if (pageRows.isEmpty) {
      return PagedInventoryDetailRows(
          rows: const <InventoryDetailRow>[], total: total);
    }

    final orderedBatchIds = <int>[];
    final currentBoxesByBatchId = <int, int>{};
    for (final row in pageRows) {
      final batchId = row.data['batch_id'] as int?;
      final currentBoxes = row.data['current_boxes'] as int?;
      if (batchId == null || currentBoxes == null) {
        continue;
      }
      orderedBatchIds.add(batchId);
      currentBoxesByBatchId[batchId] = currentBoxes;
    }

    final batches = await (_database.select(_database.batches)
          ..where((table) => table.id.isIn(orderedBatchIds)))
        .get();
    final batchesById = {for (final batch in batches) batch.id: batch};
    final productIds = batches.map((batch) => batch.productId).toSet().toList();
    final productsById = await _productsByIds(productIds);

    final rows = <InventoryDetailRow>[];
    for (final batchId in orderedBatchIds) {
      final batch = batchesById[batchId];
      if (batch == null) {
        continue;
      }
      final product = productsById[batch.productId];
      if (product == null) {
        continue;
      }
      rows.add(
        InventoryDetailRow(
          product: product,
          batch: batch,
          currentBoxes: currentBoxesByBatchId[batchId] ?? 0,
        ),
      );
    }

    return PagedInventoryDetailRows(rows: rows, total: total);
  }

  Future<List<InventoryGroupSummary>> inventoryGroupSummaries({
    String queryText = '',
    InventoryStockFilter stockFilter = InventoryStockFilter.all,
  }) async {
    final normalized = queryText.trim().toLowerCase();
    final whereParts = <String>[];
    final havingParts = <String>[];
    final vars = <Variable<Object>>[];

    if (normalized.isNotEmpty) {
      whereParts.add(
        '(LOWER(p.code) LIKE ? OR LOWER(b.actual_batch) LIKE ? OR LOWER(b.date_batch) LIKE ?)',
      );
      final pattern = '%$normalized%';
      for (var i = 0; i < 3; i += 1) {
        vars.add(Variable.withString(pattern));
      }
    }

    final movementDeltaSql = '''
      COALESCE(SUM(CASE
        WHEN m.type IN (${StockMovementType.initial.index}, ${StockMovementType.inAdjust.index})
          THEN m.boxes
        ELSE -m.boxes
      END), 0)
    ''';
    final currentBoxesSql = '(b.initial_boxes + $movementDeltaSql)';

    switch (stockFilter) {
      case InventoryStockFilter.all:
        break;
      case InventoryStockFilter.inStock:
        havingParts.add('$currentBoxesSql > 0');
        break;
      case InventoryStockFilter.zero:
        havingParts.add('$currentBoxesSql = 0');
        break;
    }

    final whereSql =
        whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}';
    final havingSql =
        havingParts.isEmpty ? '' : 'HAVING ${havingParts.join(' AND ')}';

    final rows = await _database
        .customSelect(
          '''
      SELECT
        t.code AS product_code,
        SUM(t.current_boxes) AS total_boxes,
        SUM(t.current_boxes * t.pieces_per_box) AS total_pieces
      FROM (
        SELECT
          b.id AS batch_id,
          p.code AS code,
          p.pieces_per_box AS pieces_per_box,
          $currentBoxesSql AS current_boxes
        FROM batches b
        INNER JOIN products p ON p.id = b.product_id
        LEFT JOIN stock_movements m ON m.batch_id = b.id
        $whereSql
        GROUP BY b.id, b.initial_boxes, p.code, p.pieces_per_box
        $havingSql
      ) t
      GROUP BY t.code
      ORDER BY total_pieces DESC, total_boxes DESC, product_code ASC
      ''',
          variables: vars,
          readsFrom: {
            _database.batches,
            _database.products,
            _database.stockMovements,
          },
        )
        .get();

    return rows
        .map(
          (row) => InventoryGroupSummary(
            productCode: row.data['product_code'] as String? ?? '',
            totalBoxes: (row.data['total_boxes'] as int?) ?? 0,
            totalPieces: (row.data['total_pieces'] as int?) ?? 0,
          ),
        )
        .where((summary) => summary.productCode.isNotEmpty)
        .toList();
  }

  int _compareRowsByProductAndDate(InventoryDetailRow a, InventoryDetailRow b) {
    final codeCompare = a.product.code.compareTo(b.product.code);
    if (codeCompare != 0) {
      return codeCompare;
    }
    final aDate = _parseDateBatch(a.batch.dateBatch);
    final bDate = _parseDateBatch(b.batch.dateBatch);
    for (var i = 0; i < 3; i += 1) {
      final compare = aDate[i].compareTo(bDate[i]);
      if (compare != 0) {
        return compare;
      }
    }
    return a.batch.createdAt.compareTo(b.batch.createdAt);
  }

  List<int> _parseDateBatch(String dateBatch) {
    final parts = dateBatch.split('.');
    if (parts.length != 3) {
      return const [9999, 99, 99];
    }
    final year = int.tryParse(parts[0]) ?? 9999;
    final month = int.tryParse(parts[1]) ?? 99;
    final day = int.tryParse(parts[2]) ?? 99;
    return [year, month, day];
  }

  Future<Map<int, Product>> _productsByIds(List<int> productIds) async {
    final products = await (_database.select(_database.products)
          ..where((table) => table.id.isIn(productIds)))
        .get();
    return {for (final product in products) product.id: product};
  }

  Future<Map<int, int>> _movementDeltasByBatchIds(List<int> batchIds) async {
    final movements = await (_database.select(_database.stockMovements)
          ..where((table) => table.batchId.isIn(batchIds)))
        .get();
    final deltas = <int, int>{};
    for (final movement in movements) {
      deltas.update(
        movement.batchId,
        (value) => value + _movementDelta(movement),
        ifAbsent: () => _movementDelta(movement),
      );
    }
    return deltas;
  }

  int _movementDelta(StockMovement movement) {
    return switch (movement.type) {
      StockMovementType.initial || StockMovementType.inAdjust => movement.boxes,
      StockMovementType.orderOut ||
      StockMovementType.transferOut ||
      StockMovementType.lossOut =>
        -movement.boxes,
    };
  }

  bool _isOutbound(StockMovementType type) {
    return switch (type) {
      StockMovementType.orderOut ||
      StockMovementType.transferOut ||
      StockMovementType.lossOut =>
        true,
      StockMovementType.initial || StockMovementType.inAdjust => false,
    };
  }

  void _validateBoxes(int boxes) {
    if (boxes <= 0 || boxes > 1000000000) {
      throw InvalidStockQuantityException(boxes);
    }
  }
}

class InventoryDetailRow {
  const InventoryDetailRow({
    required this.product,
    required this.batch,
    required this.currentBoxes,
  });

  final Product product;
  final BatchRecord batch;
  final int currentBoxes;

  int get pieces => currentBoxes * product.piecesPerBox;
  bool get isZeroStock => currentBoxes == 0;
}

class PagedInventoryDetailRows {
  const PagedInventoryDetailRows({
    required this.rows,
    required this.total,
  });

  final List<InventoryDetailRow> rows;
  final int total;
}

class InventoryGroupSummary {
  const InventoryGroupSummary({
    required this.productCode,
    required this.totalBoxes,
    required this.totalPieces,
  });

  final String productCode;
  final int totalBoxes;
  final int totalPieces;
}

enum InventoryStockFilter { all, inStock, zero }

class InvalidStockQuantityException implements Exception {
  const InvalidStockQuantityException(this.boxes);

  final int boxes;

  @override
  String toString() => 'InvalidStockQuantityException(boxes: $boxes)';
}

class InsufficientStockException implements Exception {
  const InsufficientStockException({
    required this.batchId,
    required this.requestedBoxes,
    required this.availableBoxes,
  });

  final int batchId;
  final int requestedBoxes;
  final int availableBoxes;

  @override
  String toString() {
    return 'InsufficientStockException(batchId: $batchId, requested: $requestedBoxes, available: $availableBoxes)';
  }
}
