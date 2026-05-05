import 'package:drift/drift.dart';

import '../app_database.dart';
import 'stock_dao.dart';

class StocktakeDao {
  StocktakeDao(this._database);

  final AppDatabase _database;

  Future<StocktakeSessionBundle> createOrLoadSession({
    required DateTime month,
  }) async {
    final monthKey = _monthKey(month);
    final existing = await (_database.select(_database.stocktakeSessions)
          ..where((t) => t.monthKey.equals(monthKey))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
    if (existing != null && existing.status == StocktakeSessionStatus.draft.index) {
      return loadSession(existing.id);
    }

    return _database.transaction(() async {
      final sessionId = await _database.into(_database.stocktakeSessions).insert(
            StocktakeSessionsCompanion.insert(
              monthKey: monthKey,
              status: Value(StocktakeSessionStatus.draft.index),
            ),
          );

      final stockDao = StockDao(_database);
      final rows = await stockDao.inventoryDetailRows();
      final candidates = rows
          .where((row) =>
              row.batch.hasShipped &&
              row.currentBoxes > 0)
          .toList();

      for (final row in candidates) {
        await _database.into(_database.stocktakeItems).insert(
              StocktakeItemsCompanion.insert(
                sessionId: sessionId,
                productId: row.product.id,
                batchId: row.batch.id,
                productCode: row.product.code,
                batchCode: row.batch.actualBatch,
                dateBatch: row.batch.dateBatch,
                initialBoxes: Value(row.batch.initialBoxes),
                boxesPerBoard: Value(row.batch.boxesPerBoard),
                currentBoxes: row.currentBoxes,
                status: Value(StocktakeItemStatus.pending.index),
              ),
            );
      }
      return loadSession(sessionId);
    });
  }

  Future<StocktakeSessionBundle> loadSession(int sessionId) async {
    final session = await (_database.select(_database.stocktakeSessions)
          ..where((t) => t.id.equals(sessionId)))
        .getSingle();
    final items = await (_database.select(_database.stocktakeItems)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.productCode),
            (t) => OrderingTerm.asc(t.dateBatch),
            (t) => OrderingTerm.asc(t.batchCode),
          ]))
        .get();
    return StocktakeSessionBundle(session: session, items: items);
  }

  Future<List<StocktakeSessionRecord>> listRecentSessions({int limit = 6}) {
    return (_database.select(_database.stocktakeSessions)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<void> updateItem({
    required int itemId,
    required StocktakeItemStatus status,
    String? note,
  }) async {
    await (_database.update(_database.stocktakeItems)
          ..where((t) => t.id.equals(itemId)))
        .write(
      StocktakeItemsCompanion(
        status: Value(status.index),
        note: Value(note?.trim().isEmpty == true ? null : note?.trim()),
        checkedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> completeSession({
    required int sessionId,
    String? note,
  }) async {
    await (_database.update(_database.stocktakeSessions)
          ..where((t) => t.id.equals(sessionId)))
        .write(
      StocktakeSessionsCompanion(
        status: Value(StocktakeSessionStatus.completed.index),
        note: Value(note?.trim().isEmpty == true ? null : note?.trim()),
        completedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteSession(int sessionId) async {
    await _database.transaction(() async {
      await (_database.delete(_database.stocktakeItems)
            ..where((t) => t.sessionId.equals(sessionId)))
          .go();
      await (_database.delete(_database.stocktakeSessions)
            ..where((t) => t.id.equals(sessionId)))
          .go();
    });
  }

  Future<void> deleteItem(int itemId) async {
    await (_database.delete(_database.stocktakeItems)
          ..where((t) => t.id.equals(itemId)))
        .go();
  }

  Future<List<StocktakeCandidateBatch>> listCandidateBatches() async {
    final stockDao = StockDao(_database);
    final rows = await stockDao.inventoryDetailRows();
    final result = <StocktakeCandidateBatch>[];
    for (final row in rows) {
      if (row.currentBoxes <= 0) {
        continue;
      }
      result.add(
        StocktakeCandidateBatch(
          productId: row.product.id,
          batchId: row.batch.id,
          productCode: row.product.code,
          productName: row.product.name,
          batchCode: row.batch.actualBatch,
          dateBatch: row.batch.dateBatch,
          boxesPerBoard: row.batch.boxesPerBoard,
          initialBoxes: row.batch.initialBoxes,
          currentBoxes: row.currentBoxes,
        ),
      );
    }
    result.sort((a, b) {
      final byProduct = a.productCode.compareTo(b.productCode);
      if (byProduct != 0) return byProduct;
      final byDate = _compareDateBatch(a.dateBatch, b.dateBatch);
      if (byDate != 0) return byDate;
      return a.batchCode.compareTo(b.batchCode);
    });
    return result;
  }

  Future<bool> addItemToSession({
    required int sessionId,
    required int batchId,
  }) async {
    final existing = await (_database.select(_database.stocktakeItems)
          ..where((t) => t.sessionId.equals(sessionId) & t.batchId.equals(batchId))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) {
      return false;
    }

    final all = await listCandidateBatches();
    StocktakeCandidateBatch? candidate;
    for (final row in all) {
      if (row.batchId == batchId) {
        candidate = row;
        break;
      }
    }
    if (candidate == null) {
      throw StateError('未找到可加入的批号');
    }
    await _database.into(_database.stocktakeItems).insert(
          StocktakeItemsCompanion.insert(
            sessionId: sessionId,
            productId: candidate.productId,
            batchId: candidate.batchId,
            productCode: candidate.productCode,
            batchCode: candidate.batchCode,
            dateBatch: candidate.dateBatch,
            initialBoxes: Value(candidate.initialBoxes),
            boxesPerBoard: Value(candidate.boxesPerBoard),
            currentBoxes: candidate.currentBoxes,
            status: Value(StocktakeItemStatus.pending.index),
          ),
        );
    return true;
  }

  String _monthKey(DateTime month) {
    final y = month.year.toString().padLeft(4, '0');
    final m = month.month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  int _compareDateBatch(String left, String right) {
    final l = _parseDateBatch(left);
    final r = _parseDateBatch(right);
    if (l != null && r != null) {
      return l.compareTo(r);
    }
    if (l != null) return -1;
    if (r != null) return 1;
    return left.compareTo(right);
  }

  DateTime? _parseDateBatch(String value) {
    final parts = value.split('.');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }
}

class StocktakeCandidateBatch {
  const StocktakeCandidateBatch({
    required this.productId,
    required this.batchId,
    required this.productCode,
    required this.productName,
    required this.batchCode,
    required this.dateBatch,
    required this.boxesPerBoard,
    required this.initialBoxes,
    required this.currentBoxes,
  });

  final int productId;
  final int batchId;
  final String productCode;
  final String productName;
  final String batchCode;
  final String dateBatch;
  final int boxesPerBoard;
  final int initialBoxes;
  final int currentBoxes;
}

class StocktakeSessionBundle {
  const StocktakeSessionBundle({
    required this.session,
    required this.items,
  });

  final StocktakeSessionRecord session;
  final List<StocktakeItemRecord> items;
}

enum StocktakeSessionStatus { draft, completed }

enum StocktakeItemStatus { pending, checked, issue }
