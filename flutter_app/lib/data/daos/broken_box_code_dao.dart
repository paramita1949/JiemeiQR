import 'package:drift/drift.dart';

import '../app_database.dart';

class BrokenBoxCodeDao {
  BrokenBoxCodeDao(this._db);

  final AppDatabase _db;

  Future<void> ensureTable() async {
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS broken_box_codes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day TEXT NOT NULL,
        product_code TEXT NOT NULL,
        actual_batch TEXT NOT NULL,
        full_code TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
    ''');
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_broken_box_codes_group ON broken_box_codes(day, product_code, actual_batch, created_at DESC);',
    );
  }

  Future<void> insert({
    required String day,
    required String productCode,
    required String actualBatch,
    required String fullCode,
  }) async {
    await ensureTable();
    await _db.customStatement(
      '''
      INSERT INTO broken_box_codes(day, product_code, actual_batch, full_code, created_at)
      VALUES (?, ?, ?, ?, ?)
      ''',
      [day, productCode, actualBatch, fullCode, DateTime.now().toIso8601String()],
    );
  }

  Future<List<BrokenBoxCodeEntry>> latest({int limit = 300}) async {
    await ensureTable();
    final rows = await _db.customSelect(
      '''
      SELECT id, day, product_code, actual_batch, full_code, created_at
      FROM broken_box_codes
      ORDER BY created_at DESC, id DESC
      LIMIT ?
      ''',
      variables: [Variable.withInt(limit)],
    ).get();
    return rows.map((row) {
      return BrokenBoxCodeEntry(
        id: row.read<int>('id'),
        day: row.read<String>('day'),
        productCode: row.read<String>('product_code'),
        actualBatch: row.read<String>('actual_batch'),
        fullCode: row.read<String>('full_code'),
        createdAt: DateTime.tryParse(row.read<String>('created_at')) ??
            DateTime.now(),
      );
    }).toList();
  }

  Future<void> deleteById(int id) async {
    await ensureTable();
    await _db.customStatement('DELETE FROM broken_box_codes WHERE id = ?', [id]);
  }
}

class BrokenBoxCodeEntry {
  const BrokenBoxCodeEntry({
    required this.id,
    required this.day,
    required this.productCode,
    required this.actualBatch,
    required this.fullCode,
    required this.createdAt,
  });

  final int id;
  final String day;
  final String productCode;
  final String actualBatch;
  final String fullCode;
  final DateTime createdAt;
}
