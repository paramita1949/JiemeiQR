import 'package:drift/drift.dart';

class GeofenceDailyStates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get accountKey => text().withDefault(const Constant('local'))();
  DateTimeColumn get day => dateTime()();
  BoolColumn get wasInside => boolean().withDefault(const Constant(false))();
  BoolColumn get triggered => boolean().withDefault(const Constant(false))();
  IntColumn get triggeredCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastTriggeredAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {accountKey, day},
      ];
}
