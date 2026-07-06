import 'package:drift/drift.dart';

@DataClassName('DeliveryPlanRecord')
class DeliveryPlanRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sourceImagePath => text().nullable()();
  IntColumn get lineCount => integer().withDefault(const Constant(0))();
  IntColumn get totalNeedBoxes => integer().withDefault(const Constant(0))();
  TextColumn get warningsJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}
