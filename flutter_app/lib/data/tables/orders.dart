import 'package:drift/drift.dart';

import '../database_enums.dart';

class Orders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get waybillNo => text()();
  TextColumn get merchantName => text()();
  DateTimeColumn get orderDate => dateTime()();
  IntColumn get status => intEnum<OrderStatus>().withDefault(
        Constant(OrderStatus.pending.index),
      )();
  TextColumn get remark => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}
