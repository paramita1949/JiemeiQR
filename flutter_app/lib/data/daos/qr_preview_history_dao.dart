import 'package:drift/drift.dart';

import '../app_database.dart';

class QrPreviewHistoryDao {
  QrPreviewHistoryDao(this._db);

  final AppDatabase _db;

  Future<void> ensureTable() async {
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS qr_preview_histories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL,
        actual_batch TEXT NOT NULL,
        start_serial TEXT NOT NULL,
        end_serial TEXT NOT NULL,
        generated_count INTEGER NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
    ''');
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_qr_preview_histories_created ON qr_preview_histories(created_at DESC);',
    );
  }

  Future<void> insert(QrPreviewHistoryEntry entry) async {
    await ensureTable();
    await _db.customStatement(
      '''
      INSERT INTO qr_preview_histories (
        source, actual_batch, start_serial, end_serial, generated_count, created_at
      ) VALUES (?, ?, ?, ?, ?, ?);
      ''',
      [
        entry.source,
        entry.actualBatch,
        entry.startSerial,
        entry.endSerial,
        entry.generatedCount,
        entry.createdAt.toIso8601String(),
      ],
    );
  }

  Future<List<QrPreviewHistoryEntry>> latest({int limit = 80}) async {
    await ensureTable();
    final rows = await _db.customSelect(
      '''
      SELECT id, source, actual_batch, start_serial, end_serial, generated_count, created_at
      FROM qr_preview_histories
      ORDER BY created_at DESC, id DESC
      LIMIT ?
      ''',
      variables: [Variable.withInt(limit)],
    ).get();
    return rows.map((row) {
      return QrPreviewHistoryEntry(
        id: row.read<int>('id'),
        source: row.read<String>('source'),
        actualBatch: row.read<String>('actual_batch'),
        startSerial: row.read<String>('start_serial'),
        endSerial: row.read<String>('end_serial'),
        generatedCount: row.read<int>('generated_count'),
        createdAt: DateTime.tryParse(row.read<String>('created_at')) ??
            DateTime.now(),
      );
    }).toList();
  }

  Future<void> deleteById(int id) async {
    await ensureTable();
    await _db.customStatement('DELETE FROM qr_preview_histories WHERE id = ?;', [
      id,
    ]);
  }

  Future<void> clearAll() async {
    await ensureTable();
    await _db.customStatement('DELETE FROM qr_preview_histories;');
  }
}

class QrPreviewHistoryEntry {
  const QrPreviewHistoryEntry({
    this.id,
    required this.source,
    required this.actualBatch,
    required this.startSerial,
    required this.endSerial,
    required this.generatedCount,
    required this.createdAt,
  });

  final int? id;
  final String source;
  final String actualBatch;
  final String startSerial;
  final String endSerial;
  final int generatedCount;
  final DateTime createdAt;
}
