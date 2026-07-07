import 'package:drift/drift.dart';

import 'delivery_plan_records.dart';

@DataClassName('DeliveryPlanItem')
class DeliveryPlanItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get recordId => integer().references(DeliveryPlanRecords, #id)();
  IntColumn get rowIndex => integer().withDefault(const Constant(0))();
  TextColumn get productCode => text()();
  TextColumn get productName => text().withDefault(const Constant(''))();
  TextColumn get location => text().withDefault(const Constant(''))();
  TextColumn get actualBatch => text()();
  TextColumn get dateBatch => text()();
  IntColumn get stockTotalBoxes => integer().withDefault(const Constant(0))();
  IntColumn get deliveryPlanAvailableBoxes =>
      integer().withDefault(const Constant(0))();
  IntColumn get needBoxes => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
