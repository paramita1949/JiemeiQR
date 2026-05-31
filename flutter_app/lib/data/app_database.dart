import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database_enums.dart';
import 'tables/batches.dart';
import 'tables/attendance_records.dart';
import 'tables/attendance_rules.dart';
import 'tables/geofence_daily_states.dart';
import 'tables/order_items.dart';
import 'tables/orders.dart';
import 'tables/patch_requests.dart';
import 'tables/products.dart';
import 'tables/scanner_guns.dart';
import 'tables/stock_movements.dart';
import 'tables/stocktake_items.dart';
import 'tables/stocktake_sessions.dart';

export 'database_enums.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Products,
    Batches,
    Orders,
    OrderItems,
    StockMovements,
    AttendanceRules,
    AttendanceRecords,
    PatchRequests,
    GeofenceDailyStates,
    StocktakeSessions,
    StocktakeItems,
    ScannerGuns,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 20;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createPerformanceIndexes(m);
          await _createAttendanceIndexes(m);
          await _createStocktakeIndexes(m);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(batches, batches.stackingPattern);
          }
          if (from < 3) {
            await _createPerformanceIndexes(m);
          }
          if (from < 4) {
            await m.addColumn(batches, batches.tsRequired);
          }
          if (from < 5) {
            await m.addColumn(orderItems, orderItems.isException);
          }
          if (from < 6) {
            await m.createTable(attendanceRules);
            await m.createTable(attendanceRecords);
            await m.createTable(patchRequests);
            await _createAttendanceIndexes(m);
          }
          if (from < 7) {
            await m.createTable(geofenceDailyStates);
          }
          if (from < 8) {
            final exists =
                await _hasColumn('attendance_records', 'leave_minutes');
            if (!exists) {
              await m.addColumn(
                  attendanceRecords, attendanceRecords.leaveMinutes);
            }
          }
          if (from < 9) {
            await m.createTable(stocktakeSessions);
            await m.createTable(stocktakeItems);
            await _createStocktakeIndexes(m);
          }
          if (from < 10) {
            final exists =
                await _hasColumn('stocktake_items', 'boxes_per_board');
            if (!exists) {
              await m.database.customStatement(
                'ALTER TABLE stocktake_items ADD COLUMN boxes_per_board INTEGER NOT NULL DEFAULT 1;',
              );
            }
          }
          if (from < 11) {
            await m.database.customStatement(
              'UPDATE stocktake_items SET boxes_per_board = 1 WHERE boxes_per_board IS NULL OR boxes_per_board <= 0;',
            );
          }
          if (from < 12) {
            await m.database.customStatement('''
              UPDATE stocktake_items
              SET boxes_per_board = (
                SELECT b.boxes_per_board
                FROM batches b
                WHERE b.id = stocktake_items.batch_id
              )
              WHERE boxes_per_board <= 1;
            ''');
          }
          if (from < 13) {
            final hasInitialBoxes =
                await _hasColumn('stocktake_items', 'initial_boxes');
            if (!hasInitialBoxes) {
              await m.addColumn(stocktakeItems, stocktakeItems.initialBoxes);
            }
          }
          if (from < 14) {
            await _createStocktakeFloorStatsTable(m);
          }
          if (from < 15) {
            final exists = await _hasColumn('attendance_records', 'is_holiday');
            if (!exists) {
              await m.addColumn(attendanceRecords, attendanceRecords.isHoliday);
            }
          }
          if (from < 16) {
            final exists = await _hasColumn('order_items', 'is_picked');
            if (!exists) {
              await m.addColumn(orderItems, orderItems.isPicked);
            }
          }
          if (from < 17) {
            final exists = await _hasColumn('batches', 'frozen_boxes');
            if (!exists) {
              await m.addColumn(batches, batches.frozenBoxes);
            }
          }
          if (from < 18) {
            final exists = await _hasColumn('orders', 'is_urgent');
            if (!exists) {
              await m.addColumn(orders, orders.isUrgent);
            }
          }
          if (from < 19) {
            final hasScannerGun = await _hasColumn('orders', 'scanner_gun');
            if (!hasScannerGun) {
              await m.addColumn(orders, orders.scannerGun);
            }
            if (!await _hasTable('scanner_guns')) {
              await m.createTable(scannerGuns);
            }
          }
          if (from < 20) {
            await _migrateAttendanceAccountScope(m);
          }
        },
        beforeOpen: (details) async {
          await customStatement('''
            CREATE TABLE IF NOT EXISTS stocktake_item_floor_stats (
              item_id INTEGER PRIMARY KEY,
              stats_json TEXT NOT NULL,
              updated_at TEXT NOT NULL DEFAULT (datetime('now'))
            );
          ''');
        },
      );

  Future<bool> _hasColumn(String table, String column) async {
    final rows = await customSelect('PRAGMA table_info($table);').get();
    for (final row in rows) {
      final name = row.data['name']?.toString();
      if (name == column) return true;
    }
    return false;
  }

  Future<bool> _hasTable(String table) async {
    final rows = await customSelect(
      'SELECT name FROM sqlite_master WHERE type = ? AND name = ?;',
      variables: [
        Variable.withString('table'),
        Variable.withString(table),
      ],
    ).get();
    return rows.isNotEmpty;
  }

  Future<void> _createPerformanceIndexes(Migrator m) async {
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_orders_status_order_date ON orders(status, order_date);',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_items_batch_id ON order_items(batch_id);',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_batches_product_id ON batches(product_id);',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_batches_actual_batch ON batches(actual_batch);',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_movements_batch_id ON stock_movements(batch_id);',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_movements_type_date_batch ON stock_movements(type, movement_date, batch_id);',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_movements_order_id ON stock_movements(order_id);',
    );
  }

  Future<void> _createAttendanceIndexes(Migrator m) async {
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_attendance_account_day ON attendance_records(account_key, day);',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_attendance_account_status ON attendance_records(account_key, is_absent, is_late, needs_patch);',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_patch_account_day_status ON patch_requests(account_key, day, status);',
    );
  }

  Future<void> _migrateAttendanceAccountScope(Migrator m) async {
    if (await _hasTable('attendance_rules') &&
        !await _hasColumn('attendance_rules', 'account_key')) {
      await m.addColumn(attendanceRules, attendanceRules.accountKey);
    }
    if (await _hasTable('attendance_records') &&
        !await _hasColumn('attendance_records', 'account_key')) {
      await m.addColumn(attendanceRecords, attendanceRecords.accountKey);
    }
    if (await _hasTable('patch_requests') &&
        !await _hasColumn('patch_requests', 'account_key')) {
      await m.addColumn(patchRequests, patchRequests.accountKey);
    }
    await _rebuildGeofenceDailyStatesForAccountScope(m);
    await _createAttendanceIndexes(m);
  }

  Future<void> _rebuildGeofenceDailyStatesForAccountScope(Migrator m) async {
    if (!await _hasTable('geofence_daily_states')) {
      await m.createTable(geofenceDailyStates);
      return;
    }
    final hasAccountKey =
        await _hasColumn('geofence_daily_states', 'account_key');
    await m.database.customStatement(
        'ALTER TABLE geofence_daily_states RENAME TO geofence_daily_states_old;');
    await m.createTable(geofenceDailyStates);
    final accountKeyExpression =
        hasAccountKey ? "COALESCE(account_key, 'local')" : "'local'";
    await m.database.customStatement('''
      INSERT INTO geofence_daily_states (
        id,
        account_key,
        day,
        was_inside,
        triggered,
        triggered_count,
        last_triggered_at,
        updated_at
      )
      SELECT
        id,
        $accountKeyExpression,
        day,
        was_inside,
        triggered,
        triggered_count,
        last_triggered_at,
        updated_at
      FROM geofence_daily_states_old;
    ''');
    await m.database.customStatement('DROP TABLE geofence_daily_states_old;');
  }

  Future<void> _createStocktakeIndexes(Migrator m) async {
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_stocktake_sessions_month ON stocktake_sessions(month_key, created_at);',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_stocktake_items_session ON stocktake_items(session_id, status);',
    );
  }

  Future<void> _createStocktakeFloorStatsTable(Migrator m) async {
    await m.database.customStatement('''
      CREATE TABLE IF NOT EXISTS stocktake_item_floor_stats (
        item_id INTEGER PRIMARY KEY,
        stats_json TEXT NOT NULL,
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
    ''');
  }
}

LazyDatabase _openConnection() {
  if (Platform.isAndroid || Platform.isIOS) {
    return LazyDatabase(
      () async => SqfliteQueryExecutor.inDatabaseFolder(
        path: 'jiemei.sqlite',
        singleInstance: true,
      ),
    );
  }
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'jiemei.sqlite'));
    return NativeDatabase(file);
  });
}
