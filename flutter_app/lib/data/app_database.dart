import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database_enums.dart';
import 'tables/batches.dart';
import 'tables/order_items.dart';
import 'tables/orders.dart';
import 'tables/products.dart';
import 'tables/stock_movements.dart';

export 'database_enums.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Products,
    Batches,
    Orders,
    OrderItems,
    StockMovements,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createPerformanceIndexes(m);
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
        },
      );

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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'jiemei.sqlite'));
    return NativeDatabase(file);
  });
}
