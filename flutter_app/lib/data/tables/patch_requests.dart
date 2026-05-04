import 'package:drift/drift.dart';

class PatchRequests extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get day => dateTime()();
  TextColumn get patchType => text()(); // checkin / checkout / both
  DateTimeColumn get requestedCheckInAt => dateTime().nullable()();
  DateTimeColumn get requestedCheckOutAt => dateTime().nullable()();
  TextColumn get reason => text().withDefault(const Constant(''))();

  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get reviewedAt => dateTime().nullable()();
}
