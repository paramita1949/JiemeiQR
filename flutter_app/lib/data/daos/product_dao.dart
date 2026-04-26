import 'package:drift/drift.dart';

import '../app_database.dart';
import '../data_change_notifier.dart';

class ProductDao {
  ProductDao(this._database);

  final AppDatabase _database;

  Future<int> createProduct({
    required String code,
    required String name,
    required int boxesPerBoard,
    required int piecesPerBox,
  }) async {
    _validatePositive(boxesPerBoard, 'boxesPerBoard');
    _validatePositive(piecesPerBox, 'piecesPerBox');
    final existing = await (_database.select(_database.products)
          ..where((table) => table.code.equals(code)))
        .getSingleOrNull();
    if (existing != null) {
      await (_database.update(_database.products)
            ..where((table) => table.id.equals(existing.id)))
          .write(
        ProductsCompanion(
          name: Value(name),
          boxesPerBoard: Value(boxesPerBoard),
          piecesPerBox: Value(piecesPerBox),
          updatedAt: Value(DateTime.now()),
        ),
      );
      DataChangeNotifier.instance.emit(DataChangeKind.baseInfo);
      return existing.id;
    }
    final id = await _database.into(_database.products).insert(
          ProductsCompanion.insert(
            code: code,
            name: name,
            boxesPerBoard: boxesPerBoard,
            piecesPerBox: piecesPerBox,
          ),
        );
    DataChangeNotifier.instance.emit(DataChangeKind.baseInfo);
    return id;
  }

  Future<int> createBatch({
    required int productId,
    required String actualBatch,
    required String dateBatch,
    required int initialBoxes,
    int? boxesPerBoard,
    bool tsRequired = false,
    String? location,
    String? remark,
  }) async {
    _validatePositive(initialBoxes, 'initialBoxes');
    final product = await (_database.select(_database.products)
          ..where((table) => table.id.equals(productId)))
        .getSingle();
    final batchBoxesPerBoard = boxesPerBoard ?? product.boxesPerBoard;
    _validatePositive(batchBoxesPerBoard, 'boxesPerBoard');
    final batchId = await _database.into(_database.batches).insert(
          BatchesCompanion.insert(
            productId: productId,
            actualBatch: actualBatch,
            dateBatch: dateBatch,
            initialBoxes: initialBoxes,
            boxesPerBoard: batchBoxesPerBoard,
            tsRequired: Value(tsRequired),
            location: Value.absentIfNull(location),
            remark: Value.absentIfNull(remark),
          ),
        );
    if (tsRequired) {
      await _syncProductTsRequired(productId: productId, tsRequired: true);
    }
    DataChangeNotifier.instance.emit(DataChangeKind.baseInfo);
    return batchId;
  }

  Future<List<Product>> allProducts() {
    return (_database.select(_database.products)
          ..orderBy([
            (table) => OrderingTerm.asc(table.code),
          ]))
        .get();
  }

  Future<Product?> productByCode(String code) {
    return (_database.select(_database.products)
          ..where((table) => table.code.equals(code)))
        .getSingleOrNull();
  }

  Future<List<BatchRecord>> batchesForProduct(int productId) {
    return (_database.select(_database.batches)
          ..where((table) => table.productId.equals(productId))
          ..orderBy([
            (table) => OrderingTerm.desc(table.createdAt),
          ]))
        .get();
  }

  Future<List<AvailableBatch>> availableBatchesForProduct(int productId) async {
    final batches = await batchesForProduct(productId);
    if (batches.isEmpty) {
      return const <AvailableBatch>[];
    }
    final movements = await (_database.select(_database.stockMovements)
          ..where((table) => table.batchId.isIn(batches.map((e) => e.id).toList())))
        .get();
    final deltasByBatch = <int, int>{};
    for (final movement in movements) {
      deltasByBatch.update(
        movement.batchId,
        (value) => value + _movementDelta(movement),
        ifAbsent: () => _movementDelta(movement),
      );
    }
    final rows = <AvailableBatch>[];

    for (final batch in batches) {
      final currentBoxes = batch.initialBoxes + (deltasByBatch[batch.id] ?? 0);
      if (currentBoxes > 0) {
        rows.add(AvailableBatch(batch: batch, currentBoxes: currentBoxes));
      }
    }

    return rows;
  }

  Future<void> deleteBatch(int batchId) async {
    await (_database.delete(_database.batches)
          ..where((table) => table.id.equals(batchId)))
        .go();
    DataChangeNotifier.instance.emit(DataChangeKind.baseInfo);
  }

  Future<void> deleteProduct(int productId) async {
    await (_database.delete(_database.products)
          ..where((table) => table.id.equals(productId)))
        .go();
    DataChangeNotifier.instance.emit(DataChangeKind.baseInfo);
  }

  Future<void> updateBatchRemark(int batchId, String? remark) async {
    await (_database.update(_database.batches)
          ..where((table) => table.id.equals(batchId)))
        .write(
      BatchesCompanion(
        remark: Value(remark),
        updatedAt: Value(DateTime.now()),
      ),
    );
    DataChangeNotifier.instance.emit(DataChangeKind.baseInfo);
  }

  Future<bool> hasTsRequiredBatches(int productId) async {
    final row = await _database.customSelect(
      '''
      SELECT COUNT(*) AS c
      FROM batches
      WHERE product_id = ? AND ts_required = 1
      ''',
      variables: [Variable.withInt(productId)],
      readsFrom: {_database.batches},
    ).getSingleOrNull();
    return ((row?.data['c'] as int?) ?? 0) > 0;
  }

  Future<bool> hasDuplicateActualBatch({
    required String actualBatch,
    int? excludeBatchId,
  }) async {
    final query = _database.select(_database.batches)
      ..where(
        (table) => table.actualBatch.equals(actualBatch),
      );
    if (excludeBatchId != null) {
      query.where((table) => table.id.isNotValue(excludeBatchId));
    }
    final row = await query.getSingleOrNull();
    return row != null;
  }

  Future<BaseInfoEntry?> getBaseInfoEntry(int batchId) async {
    final batch = await (_database.select(_database.batches)
          ..where((table) => table.id.equals(batchId)))
        .getSingleOrNull();
    if (batch == null) {
      return null;
    }
    final product = await (_database.select(_database.products)
          ..where((table) => table.id.equals(batch.productId)))
        .getSingle();
    final movements = await (_database.select(_database.stockMovements)
          ..where((table) => table.batchId.equals(batch.id)))
        .get();
    final currentBoxes = movements.fold<int>(
      batch.initialBoxes,
      (stock, movement) => stock + _movementDelta(movement),
    );
    return BaseInfoEntry(
      product: product,
      batch: batch,
      currentBoxes: currentBoxes,
    );
  }

  Future<void> updateBaseInfoEntry({
    required int batchId,
    required String code,
    required String name,
    required String actualBatch,
    required String dateBatch,
    required int currentBoxes,
    required int boxesPerBoard,
    required int piecesPerBox,
    required bool tsRequired,
    String? location,
    String? remark,
  }) async {
    _validatePositive(currentBoxes, 'currentBoxes');
    _validatePositive(boxesPerBoard, 'boxesPerBoard');
    _validatePositive(piecesPerBox, 'piecesPerBox');

    await _database.transaction(() async {
      final entry = await getBaseInfoEntry(batchId);
      if (entry == null) {
        throw StateError('Batch $batchId does not exist.');
      }
      final duplicateCode = await (_database.select(_database.products)
            ..where((table) =>
                table.code.equals(code) & table.id.isNotValue(entry.product.id)))
          .getSingleOrNull();
      if (duplicateCode != null) {
        throw ProductCodeAlreadyExistsException(code);
      }
      final movements = await (_database.select(_database.stockMovements)
            ..where((table) => table.batchId.equals(batchId)))
          .get();
      final movementDelta = movements.fold<int>(
        0,
        (sum, movement) => sum + _movementDelta(movement),
      );
      final initialBoxes = currentBoxes - movementDelta;
      _validatePositive(initialBoxes, 'initialBoxes');

      await (_database.update(_database.products)
            ..where((table) => table.id.equals(entry.product.id)))
          .write(
        ProductsCompanion(
          code: Value(code),
          name: Value(name),
          boxesPerBoard: Value(boxesPerBoard),
          piecesPerBox: Value(piecesPerBox),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await (_database.update(_database.batches)
            ..where((table) => table.id.equals(batchId)))
          .write(
        BatchesCompanion(
          actualBatch: Value(actualBatch),
          dateBatch: Value(dateBatch),
          initialBoxes: Value(initialBoxes),
          boxesPerBoard: Value(boxesPerBoard),
          tsRequired: Value(tsRequired),
          location: Value(location),
          remark: Value(remark),
          updatedAt: Value(DateTime.now()),
          ),
        );
      if (tsRequired) {
        await _syncProductTsRequired(
          productId: entry.product.id,
          tsRequired: true,
        );
      }
    });
    DataChangeNotifier.instance.emit(DataChangeKind.baseInfo);
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

  void _validatePositive(int value, String fieldName) {
    if (value <= 0 || value > 1000000000) {
      throw InvalidProductQuantityException(fieldName: fieldName, value: value);
    }
  }

  Future<void> _syncProductTsRequired({
    required int productId,
    required bool tsRequired,
  }) async {
    await (_database.update(_database.batches)
          ..where((table) => table.productId.equals(productId)))
        .write(
      BatchesCompanion(
        tsRequired: Value(tsRequired),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

class AvailableBatch {
  const AvailableBatch({
    required this.batch,
    required this.currentBoxes,
  });

  final BatchRecord batch;
  final int currentBoxes;
}

class BaseInfoEntry {
  const BaseInfoEntry({
    required this.product,
    required this.batch,
    required this.currentBoxes,
  });

  final Product product;
  final BatchRecord batch;
  final int currentBoxes;
}

class InvalidProductQuantityException implements Exception {
  const InvalidProductQuantityException({
    required this.fieldName,
    required this.value,
  });

  final String fieldName;
  final int value;

  @override
  String toString() {
    return 'InvalidProductQuantityException(fieldName: $fieldName, value: $value)';
  }
}

class ProductCodeAlreadyExistsException implements Exception {
  const ProductCodeAlreadyExistsException(this.code);

  final String code;

  @override
  String toString() {
    return 'ProductCodeAlreadyExistsException(code: $code)';
  }
}
