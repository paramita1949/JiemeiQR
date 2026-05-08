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
        raw_content TEXT NOT NULL DEFAULT '',
        prefix TEXT NOT NULL DEFAULT '',
        suffix TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
    ''');
    await _ensureColumn('qr_preview_histories', 'raw_content', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn('qr_preview_histories', 'prefix', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn('qr_preview_histories', 'suffix', "TEXT NOT NULL DEFAULT ''");
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_qr_preview_histories_created ON qr_preview_histories(created_at DESC);',
    );
  }

  Future<void> _ensureColumn(String table, String column, String type) async {
    final rows = await _db.customSelect('PRAGMA table_info($table);').get();
    final exists = rows.any((row) => row.data['name']?.toString() == column);
    if (!exists) {
      await _db.customStatement('ALTER TABLE $table ADD COLUMN $column $type;');
    }
  }

  Future<void> insert(QrPreviewHistoryEntry entry) async {
    await ensureTable();
    await _db.customStatement(
      '''
      INSERT INTO qr_preview_histories (
        source, actual_batch, start_serial, end_serial, generated_count, raw_content, prefix, suffix, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''',
      [
        entry.source,
        entry.actualBatch,
        entry.startSerial,
        entry.endSerial,
        entry.generatedCount,
        entry.rawContent,
        entry.prefix,
        entry.suffix,
        entry.createdAt.toIso8601String(),
      ],
    );
  }

  Future<List<QrPreviewHistoryEntry>> latest({int limit = 80}) async {
    await ensureTable();
    final rows = await _db.customSelect(
      '''
      SELECT id, source, actual_batch, start_serial, end_serial, generated_count, raw_content, prefix, suffix, created_at
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
        rawContent: row.read<String>('raw_content'),
        prefix: row.read<String>('prefix'),
        suffix: row.read<String>('suffix'),
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
    required this.rawContent,
    required this.prefix,
    required this.suffix,
    required this.createdAt,
  });

  final int? id;
  final String source;
  final String actualBatch;
  final String startSerial;
  final String endSerial;
  final int generatedCount;
  final String rawContent;
  final String prefix;
  final String suffix;
  final DateTime createdAt;
}
