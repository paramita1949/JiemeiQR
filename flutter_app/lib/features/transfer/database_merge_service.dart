import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite;

class DatabaseMergeService {
  const DatabaseMergeService();

  Future<File> mergeDatabases({
    required String localDatabasePath,
    required String cloudDatabasePath,
    required String outputDatabasePath,
  }) async {
    final local = File(localDatabasePath);
    final cloud = File(cloudDatabasePath);
    final output = File(outputDatabasePath);
    if (!await local.exists()) {
      throw DatabaseMergeSourceMissingException(localDatabasePath);
    }
    if (!await cloud.exists()) {
      throw DatabaseMergeSourceMissingException(cloudDatabasePath);
    }
    await output.parent.create(recursive: true);
    if (await output.exists()) {
      await output.delete();
    }
    await local.copy(output.path);

    final db = sqlite.sqlite3.open(output.path);
    try {
      db.execute("ATTACH DATABASE '${_escape(cloud.path)}' AS cloud;");
      db.execute('PRAGMA foreign_keys = OFF;');
      db.execute('BEGIN IMMEDIATE;');
      try {
        _mergeScannerGuns(db);
        _mergeProducts(db);
        _mergeBatches(db);
        _mergeOrders(db);
        _mergeOrderItems(db);
        _mergeStockMovements(db);
        _refreshSequences(db);
        db.execute('COMMIT;');
      } on Object {
        db.execute('ROLLBACK;');
        rethrow;
      } finally {
        db.execute('PRAGMA foreign_keys = ON;');
        db.execute('DETACH DATABASE cloud;');
      }
      db.execute('PRAGMA wal_checkpoint(TRUNCATE);');
    } finally {
      db.close();
    }
    return output;
  }

  void _mergeScannerGuns(sqlite.Database db) {
    if (!_hasTable(db, schema: 'main', table: 'scanner_guns') ||
        !_hasTable(db, schema: 'cloud', table: 'scanner_guns')) {
      return;
    }
    db.execute('''
      INSERT INTO main.scanner_guns(label, created_at)
      SELECT c.label, c.created_at
      FROM cloud.scanner_guns c
      WHERE NOT EXISTS (
        SELECT 1 FROM main.scanner_guns m WHERE m.label = c.label
      );
    ''');
  }

  void _mergeProducts(sqlite.Database db) {
    db.execute('''
      INSERT INTO main.products(
        code, name, boxes_per_board, pieces_per_box, created_at, updated_at
      )
      SELECT
        c.code, c.name, c.boxes_per_board, c.pieces_per_box,
        c.created_at, c.updated_at
      FROM cloud.products c
      WHERE NOT EXISTS (
        SELECT 1 FROM main.products m WHERE m.code = c.code
      );
    ''');
  }

  void _mergeBatches(sqlite.Database db) {
    db.execute('''
      INSERT INTO main.batches(
        product_id, actual_batch, date_batch, initial_boxes, frozen_boxes,
        boxes_per_board, stacking_pattern, location, has_shipped, ts_required,
        remark, created_at, updated_at
      )
      SELECT
        mp.id, cb.actual_batch, cb.date_batch, cb.initial_boxes,
        cb.frozen_boxes, cb.boxes_per_board, cb.stacking_pattern, cb.location,
        cb.has_shipped, cb.ts_required, cb.remark, cb.created_at, cb.updated_at
      FROM cloud.batches cb
      INNER JOIN cloud.products cp ON cp.id = cb.product_id
      INNER JOIN main.products mp ON mp.code = cp.code
      WHERE NOT EXISTS (
        SELECT 1
        FROM main.batches mb
        INNER JOIN main.products mp2 ON mp2.id = mb.product_id
        WHERE mp2.code = cp.code
          AND mb.actual_batch = cb.actual_batch
          AND mb.date_batch = cb.date_batch
      );
    ''');
  }

  void _mergeOrders(sqlite.Database db) {
    db.execute('''
      INSERT INTO main.orders(
        waybill_no, merchant_name, order_date, status, is_urgent, scanner_gun,
        remark, created_at, updated_at
      )
      SELECT
        c.waybill_no, c.merchant_name, c.order_date, c.status, c.is_urgent,
        c.scanner_gun, c.remark, c.created_at, c.updated_at
      FROM cloud.orders c
      WHERE NOT EXISTS (
        SELECT 1 FROM main.orders m WHERE m.waybill_no = c.waybill_no
      );
    ''');
    db.execute('''
      UPDATE main.orders
      SET
        status = MAX(status, (
          SELECT c.status FROM cloud.orders c
          WHERE c.waybill_no = main.orders.waybill_no
        )),
        is_urgent = MAX(is_urgent, COALESCE((
          SELECT c.is_urgent FROM cloud.orders c
          WHERE c.waybill_no = main.orders.waybill_no
        ), 0)),
        updated_at = MAX(COALESCE(updated_at, 0), COALESCE((
          SELECT c.updated_at FROM cloud.orders c
          WHERE c.waybill_no = main.orders.waybill_no
        ), 0))
      WHERE EXISTS (
        SELECT 1 FROM cloud.orders c
        WHERE c.waybill_no = main.orders.waybill_no
      );
    ''');
  }

  void _mergeOrderItems(sqlite.Database db) {
    db.execute('''
      INSERT INTO main.order_items(
        order_id, product_id, batch_id, boxes, boxes_per_board, pieces_per_box,
        is_picked, is_exception, created_at
      )
      SELECT
        mo.id, mp.id, mb.id, ci.boxes, ci.boxes_per_board, ci.pieces_per_box,
        ci.is_picked, ci.is_exception, ci.created_at
      FROM cloud.order_items ci
      INNER JOIN cloud.orders co ON co.id = ci.order_id
      INNER JOIN cloud.products cp ON cp.id = ci.product_id
      INNER JOIN cloud.batches cb ON cb.id = ci.batch_id
      INNER JOIN main.orders mo ON mo.waybill_no = co.waybill_no
      INNER JOIN main.products mp ON mp.code = cp.code
      INNER JOIN main.batches mb ON mb.product_id = mp.id
        AND mb.actual_batch = cb.actual_batch
        AND mb.date_batch = cb.date_batch
      WHERE NOT EXISTS (
        SELECT 1
        FROM main.order_items mi
        INNER JOIN main.orders mo2 ON mo2.id = mi.order_id
        INNER JOIN main.products mp2 ON mp2.id = mi.product_id
        INNER JOIN main.batches mb2 ON mb2.id = mi.batch_id
        WHERE mo2.waybill_no = co.waybill_no
          AND mp2.code = cp.code
          AND mb2.actual_batch = cb.actual_batch
          AND mb2.date_batch = cb.date_batch
      );
    ''');
    db.execute('''
      UPDATE main.order_items
      SET
        is_picked = MAX(is_picked, COALESCE((
          SELECT ci.is_picked
          FROM cloud.order_items ci
          INNER JOIN cloud.orders co ON co.id = ci.order_id
          INNER JOIN cloud.products cp ON cp.id = ci.product_id
          INNER JOIN cloud.batches cb ON cb.id = ci.batch_id
          INNER JOIN main.orders mo ON mo.waybill_no = co.waybill_no
          INNER JOIN main.products mp ON mp.code = cp.code
          INNER JOIN main.batches mb ON mb.product_id = mp.id
            AND mb.actual_batch = cb.actual_batch
            AND mb.date_batch = cb.date_batch
          WHERE mo.id = main.order_items.order_id
            AND mp.id = main.order_items.product_id
            AND mb.id = main.order_items.batch_id
        ), 0)),
        is_exception = MAX(is_exception, COALESCE((
          SELECT ci.is_exception
          FROM cloud.order_items ci
          INNER JOIN cloud.orders co ON co.id = ci.order_id
          INNER JOIN cloud.products cp ON cp.id = ci.product_id
          INNER JOIN cloud.batches cb ON cb.id = ci.batch_id
          INNER JOIN main.orders mo ON mo.waybill_no = co.waybill_no
          INNER JOIN main.products mp ON mp.code = cp.code
          INNER JOIN main.batches mb ON mb.product_id = mp.id
            AND mb.actual_batch = cb.actual_batch
            AND mb.date_batch = cb.date_batch
          WHERE mo.id = main.order_items.order_id
            AND mp.id = main.order_items.product_id
            AND mb.id = main.order_items.batch_id
        ), 0))
      WHERE EXISTS (
        SELECT 1
        FROM cloud.order_items ci
        INNER JOIN cloud.orders co ON co.id = ci.order_id
        INNER JOIN cloud.products cp ON cp.id = ci.product_id
        INNER JOIN cloud.batches cb ON cb.id = ci.batch_id
        INNER JOIN main.orders mo ON mo.waybill_no = co.waybill_no
        INNER JOIN main.products mp ON mp.code = cp.code
        INNER JOIN main.batches mb ON mb.product_id = mp.id
          AND mb.actual_batch = cb.actual_batch
          AND mb.date_batch = cb.date_batch
        WHERE mo.id = main.order_items.order_id
          AND mp.id = main.order_items.product_id
          AND mb.id = main.order_items.batch_id
      );
    ''');
  }

  void _mergeStockMovements(sqlite.Database db) {
    db.execute('''
      INSERT INTO main.stock_movements(
        batch_id, order_id, movement_date, type, boxes, remark, created_at
      )
      SELECT
        mb.id, mo.id, cm.movement_date, cm.type, cm.boxes, cm.remark,
        cm.created_at
      FROM cloud.stock_movements cm
      INNER JOIN cloud.batches cb ON cb.id = cm.batch_id
      INNER JOIN cloud.products cp ON cp.id = cb.product_id
      INNER JOIN main.products mp ON mp.code = cp.code
      INNER JOIN main.batches mb ON mb.product_id = mp.id
        AND mb.actual_batch = cb.actual_batch
        AND mb.date_batch = cb.date_batch
      LEFT JOIN cloud.orders co ON co.id = cm.order_id
      LEFT JOIN main.orders mo ON co.waybill_no IS NOT NULL
        AND mo.waybill_no = co.waybill_no
      WHERE NOT EXISTS (
        SELECT 1
        FROM main.stock_movements mm
        WHERE mm.batch_id = mb.id
          AND COALESCE(mm.order_id, -1) = COALESCE(mo.id, -1)
          AND mm.movement_date = cm.movement_date
          AND mm.type = cm.type
          AND mm.boxes = cm.boxes
          AND COALESCE(mm.remark, '') = COALESCE(cm.remark, '')
      );
    ''');
  }

  void _refreshSequences(sqlite.Database db) {
    const tables = [
      'products',
      'batches',
      'orders',
      'order_items',
      'stock_movements',
      'scanner_guns',
    ];
    for (final table in tables) {
      if (!_hasTable(db, schema: 'main', table: table)) {
        continue;
      }
      db.execute(
        'INSERT OR REPLACE INTO main.sqlite_sequence(name, seq) '
        "SELECT '$table', COALESCE(MAX(id), 0) FROM main.$table;",
      );
    }
  }

  bool _hasTable(
    sqlite.Database db, {
    required String schema,
    required String table,
  }) {
    return db.select(
      "SELECT name FROM $schema.sqlite_master WHERE type = 'table' AND name = ?;",
      [table],
    ).isNotEmpty;
  }

  String _escape(String value) => value.replaceAll("'", "''");
}

class DatabaseMergeSourceMissingException implements Exception {
  const DatabaseMergeSourceMissingException(this.path);

  final String path;

  @override
  String toString() => 'DatabaseMergeSourceMissingException(path: $path)';
}
