import 'package:drift/drift.dart';

import 'batches.dart';
import 'orders.dart';
import 'products.dart';

class OrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().references(Orders, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get batchId => integer().references(Batches, #id)();
  IntColumn get boxes => integer()();
  IntColumn get boxesPerBoard => integer()();
  IntColumn get piecesPerBox => integer()();
  BoolColumn get isException => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
