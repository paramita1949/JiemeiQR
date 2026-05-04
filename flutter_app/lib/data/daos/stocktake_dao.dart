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
              row.availableBoxes > 0 &&
              row.currentBoxes != row.batch.initialBoxes)
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

  String _monthKey(DateTime month) {
    final y = month.year.toString().padLeft(4, '0');
    final m = month.month.toString().padLeft(2, '0');
    return '$y-$m';
  }
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
