import 'package:drift/drift.dart';

import 'products.dart';

@DataClassName('BatchRecord')
class Batches extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get actualBatch => text()();
  TextColumn get dateBatch => text()();
  IntColumn get initialBoxes => integer()();
  IntColumn get boxesPerBoard => integer()();
  TextColumn get stackingPattern => text().nullable()();
  TextColumn get location => text().nullable()();
  BoolColumn get hasShipped => boolean().withDefault(const Constant(false))();
  TextColumn get remark => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}
