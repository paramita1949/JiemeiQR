import 'package:drift/drift.dart';

import 'products.dart';
import 'batches.dart';
import 'stocktake_sessions.dart';

@DataClassName('StocktakeItemRecord')
class StocktakeItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(StocktakeSessions, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get batchId => integer().references(Batches, #id)();
  TextColumn get productCode => text()();
  TextColumn get batchCode => text()();
  TextColumn get dateBatch => text()();
  IntColumn get initialBoxes => integer()();
  IntColumn get currentBoxes => integer()();
  IntColumn get status => integer().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get checkedAt => dateTime().nullable()();
}
