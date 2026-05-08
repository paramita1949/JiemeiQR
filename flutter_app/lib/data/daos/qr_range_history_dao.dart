import 'package:drift/drift.dart';
import 'dart:convert';

import '../app_database.dart';

class QrRangeHistoryDao {
  QrRangeHistoryDao(this._db);

  final AppDatabase _db;

  Future<void> ensureTable() async {
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS qr_range_histories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_code TEXT NOT NULL,
        actual_batch TEXT NOT NULL,
        date_batch TEXT NOT NULL,
        start_serial TEXT NOT NULL,
        end_serial TEXT NOT NULL,
        generated_count INTEGER NOT NULL,
        ignored_count INTEGER NOT NULL DEFAULT 0,
        scanned_count INTEGER NOT NULL DEFAULT 0,
        raw_anchor_content TEXT NOT NULL DEFAULT '',
        scanned_codes_json TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
    ''');
    await _ensureColumn('qr_range_histories', 'raw_anchor_content', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn('qr_range_histories', 'scanned_codes_json', "TEXT NOT NULL DEFAULT '[]'");
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_qr_range_histories_batch_created ON qr_range_histories(actual_batch, created_at DESC);',
    );
  }

  Future<void> _ensureColumn(String table, String column, String type) async {
    final rows = await _db.customSelect('PRAGMA table_info($table);').get();
    final exists = rows.any((row) => row.data['name']?.toString() == column);
    if (!exists) {
      await _db.customStatement('ALTER TABLE $table ADD COLUMN $column $type;');
    }
  }

  Future<void> insert(QrRangeHistoryEntry entry) async {
    await ensureTable();
    await _db.customStatement(
      '''
      INSERT INTO qr_range_histories (
        product_code, actual_batch, date_batch, start_serial, end_serial,
        generated_count, ignored_count, scanned_count, raw_anchor_content, scanned_codes_json, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''',
      [
        entry.productCode,
        entry.actualBatch,
        entry.dateBatch,
        entry.startSerial,
        entry.endSerial,
        entry.generatedCount,
        entry.ignoredCount,
        entry.scannedCount,
        entry.rawAnchorContent,
        jsonEncode(entry.scannedCodes),
        entry.createdAt.toIso8601String(),
      ],
    );
  }

  Future<List<QrRangeHistoryEntry>> latest({int limit = 50}) async {
    await ensureTable();
    final rows = await _db.customSelect(
      '''
      SELECT id, product_code, actual_batch, date_batch, start_serial, end_serial,
             generated_count, ignored_count, scanned_count, raw_anchor_content, scanned_codes_json, created_at
      FROM qr_range_histories
      ORDER BY created_at DESC, id DESC
      LIMIT ?
      ''',
      variables: [Variable.withInt(limit)],
    ).get();
    return rows.map((row) {
      final createdAtRaw = row.read<String>('created_at');
      final createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
      return QrRangeHistoryEntry(
        id: row.read<int>('id'),
        productCode: row.read<String>('product_code'),
        actualBatch: row.read<String>('actual_batch'),
        dateBatch: row.read<String>('date_batch'),
        startSerial: row.read<String>('start_serial'),
        endSerial: row.read<String>('end_serial'),
        generatedCount: row.read<int>('generated_count'),
        ignoredCount: row.read<int>('ignored_count'),
        scannedCount: row.read<int>('scanned_count'),
        rawAnchorContent: row.read<String>('raw_anchor_content'),
        scannedCodes: _decodeCodes(row.read<String>('scanned_codes_json')),
        createdAt: createdAt,
      );
    }).toList();
  }

  List<String> _decodeCodes(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const <String>[];
    }
    final parsed = jsonDecode(raw);
    if (parsed is List) {
      return parsed.map((e) => '$e').toList();
    }
    return const <String>[];
  }

  Future<void> deleteById(int id) async {
    await ensureTable();
    await _db.customStatement(
      'DELETE FROM qr_range_histories WHERE id = ?;',
      [id],
    );
  }
}

class QrRangeHistoryEntry {
  const QrRangeHistoryEntry({
    this.id,
    required this.productCode,
    required this.actualBatch,
    required this.dateBatch,
    required this.startSerial,
    required this.endSerial,
    required this.generatedCount,
    required this.ignoredCount,
    required this.scannedCount,
    required this.rawAnchorContent,
    required this.scannedCodes,
    required this.createdAt,
  });

  final int? id;
  final String productCode;
  final String actualBatch;
  final String dateBatch;
  final String startSerial;
  final String endSerial;
  final int generatedCount;
  final int ignoredCount;
  final int scannedCount;
  final String rawAnchorContent;
  final List<String> scannedCodes;
  final DateTime createdAt;
}
