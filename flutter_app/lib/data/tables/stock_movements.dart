import 'package:drift/drift.dart';

import '../database_enums.dart';
import 'batches.dart';
import 'orders.dart';

class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get batchId => integer().references(Batches, #id)();
  IntColumn get orderId => integer().nullable().references(Orders, #id)();
  DateTimeColumn get movementDate => dateTime()();
  IntColumn get type => intEnum<StockMovementType>()();
  IntColumn get boxes => integer()();
  TextColumn get remark => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
