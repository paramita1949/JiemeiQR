import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('database starts at schema version 5', () {
    expect(database.schemaVersion, 5);
  });

  test('creates product and batch records', () async {
    final productId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            code: '72067',
            name: '六神花露水195ML',
            boxesPerBoard: 40,
            piecesPerBox: 30,
          ),
        );

    final batchId = await database.into(database.batches).insert(
          BatchesCompanion.insert(
            productId: productId,
            actualBatch: 'FCHBLEZ',
            dateBatch: '2029.9.7',
            initialBoxes: 3477,
            boxesPerBoard: 40,
            location: const Value('4楼-后-右'),
            remark: const Value('首批录入'),
          ),
        );

    final product = await (database.select(database.products)
          ..where((table) => table.id.equals(productId)))
        .getSingle();
    final batch = await (database.select(database.batches)
          ..where((table) => table.id.equals(batchId)))
        .getSingle();

    expect(product.code, '72067');
    expect(batch.actualBatch, 'FCHBLEZ');
    expect(batch.hasShipped, isFalse);
  });

  test('creates order, item, and stock movement records', () async {
    final productId = await database.into(database.products).insert(
          ProductsCompanion.insert(
            code: '20380',
            name: '六神180ML止痒花露水喷雾',
            boxesPerBoard: 40,
            piecesPerBox: 30,
          ),
        );
    final batchId = await database.into(database.batches).insert(
          BatchesCompanion.insert(
            productId: productId,
            actualBatch: 'ELMAXEZ',
            dateBatch: '2029.6.14',
            initialBoxes: 3434,
            boxesPerBoard: 38,
          ),
        );
    final orderId = await database.into(database.orders).insert(
          OrdersCompanion.insert(
            waybillNo: '168220019125',
            merchantName: '洁美A',
            orderDate: DateTime(2026, 4, 26),
          ),
        );

    await database.into(database.orderItems).insert(
          OrderItemsCompanion.insert(
            orderId: orderId,
            productId: productId,
            batchId: batchId,
            boxes: 320,
            boxesPerBoard: 38,
            piecesPerBox: 30,
          ),
        );
    await database.into(database.stockMovements).insert(
          StockMovementsCompanion.insert(
            batchId: batchId,
            orderId: Value(orderId),
            movementDate: DateTime(2026, 4, 26),
            type: StockMovementType.orderOut,
            boxes: 320,
            remark: const Value('完成扣库存'),
          ),
        );

    final order = await database.select(database.orders).getSingle();
    final item = await database.select(database.orderItems).getSingle();
    final movement = await database.select(database.stockMovements).getSingle();

    expect(order.status, OrderStatus.pending);
    expect(item.boxes, 320);
    expect(movement.type, StockMovementType.orderOut);
  });

  test('enabling TS on one batch cascades to all batches of the product',
      () async {
    final productDao = ProductDao(database);
    final productId = await productDao.createProduct(
      code: '72067',
      name: '六神花露水195ML',
      boxesPerBoard: 40,
      piecesPerBox: 30,
    );

    final batchA = await productDao.createBatch(
      productId: productId,
      actualBatch: 'A-001',
      dateBatch: '2029.9.6',
      initialBoxes: 100,
      tsRequired: false,
    );
    final batchB = await productDao.createBatch(
      productId: productId,
      actualBatch: 'A-002',
      dateBatch: '2029.9.7',
      initialBoxes: 120,
      tsRequired: true,
    );

    final rows = await (database.select(database.batches)
          ..where((table) => table.id.isIn([batchA, batchB])))
        .get();
    expect(rows.length, 2);
    expect(rows.every((row) => row.tsRequired), isTrue);
    expect(await productDao.hasTsRequiredBatches(productId), isTrue);
  });

  test('migrates v1 database to v5 without data loss', () async {
    final oldWarnSetting = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = oldWarnSetting;
    });

    final tempDir = await Directory.systemTemp.createTemp('jiemei-migration-');
    final dbFile = File(p.join(tempDir.path, 'migration.sqlite'));

    final legacy = sqlite.sqlite3.open(dbFile.path);
    legacy.execute('''
      CREATE TABLE products (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        boxes_per_board INTEGER NOT NULL,
        pieces_per_box INTEGER NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        updated_at INTEGER
      );
      CREATE TABLE batches (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES products(id),
        actual_batch TEXT NOT NULL,
        date_batch TEXT NOT NULL,
        initial_boxes INTEGER NOT NULL,
        boxes_per_board INTEGER NOT NULL,
        location TEXT,
        has_shipped INTEGER NOT NULL DEFAULT 0,
        remark TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        updated_at INTEGER
      );
      CREATE TABLE orders (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        waybill_no TEXT NOT NULL UNIQUE,
        merchant_name TEXT NOT NULL,
        order_date INTEGER NOT NULL,
        status INTEGER NOT NULL DEFAULT 0,
        remark TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        updated_at INTEGER
      );
      CREATE TABLE order_items (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL REFERENCES orders(id),
        product_id INTEGER NOT NULL REFERENCES products(id),
        batch_id INTEGER NOT NULL REFERENCES batches(id),
        boxes INTEGER NOT NULL,
        boxes_per_board INTEGER NOT NULL,
        pieces_per_box INTEGER NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        updated_at INTEGER
      );
      CREATE TABLE stock_movements (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER NOT NULL REFERENCES batches(id),
        order_id INTEGER REFERENCES orders(id),
        movement_date INTEGER NOT NULL,
        type INTEGER NOT NULL,
        boxes INTEGER NOT NULL,
        remark TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        updated_at INTEGER
      );
      INSERT INTO products(code, name, boxes_per_board, pieces_per_box) VALUES
        ('72067', '六神花露水195ML', 40, 30);
      INSERT INTO batches(product_id, actual_batch, date_batch, initial_boxes, boxes_per_board, remark) VALUES
        (1, 'FCHBLEZ', '2029.9.7', 3477, 40, 'legacy');
      PRAGMA user_version = 1;
    ''');
    legacy.close();

    final migrated = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(() async {
      await migrated.close();
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final batch = await migrated.select(migrated.batches).getSingle();
    expect(batch.actualBatch, 'FCHBLEZ');
    expect(batch.remark, 'legacy');

    final stacking = await migrated.customSelect(
      'SELECT stacking_pattern FROM batches WHERE id = ?',
      variables: [Variable.withInt(batch.id)],
    ).getSingle();
    expect(stacking.data['stacking_pattern'], isNull);

    final versionRow =
        await migrated.customSelect('PRAGMA user_version;').getSingle();
    expect(versionRow.data['user_version'], 5);

    final tsRequired = await migrated.customSelect(
      'SELECT ts_required FROM batches WHERE id = ?',
      variables: [Variable.withInt(batch.id)],
    ).getSingle();
    expect(tsRequired.data['ts_required'], 0);

    final isException = await migrated
        .customSelect(
          'SELECT is_exception FROM order_items LIMIT 1',
        )
        .getSingleOrNull();
    expect(isException, isNull);

    final orderIndexRows = await migrated
        .customSelect(
          "PRAGMA index_list('orders');",
        )
        .get();
    expect(
      orderIndexRows.any(
        (row) => row.data['name'] == 'idx_orders_status_order_date',
      ),
      isTrue,
    );

    final movementIndexRows = await migrated
        .customSelect(
          "PRAGMA index_list('stock_movements');",
        )
        .get();
    expect(
      movementIndexRows.any(
        (row) => row.data['name'] == 'idx_movements_type_date_batch',
      ),
      isTrue,
    );
  });
}
