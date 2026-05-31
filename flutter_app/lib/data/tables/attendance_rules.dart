import 'package:drift/drift.dart';

class AttendanceRules extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get accountKey => text().withDefault(const Constant('local'))();
  TextColumn get workStartTime => text().withDefault(const Constant('08:00'))();
  TextColumn get workEndTime => text().withDefault(const Constant('17:00'))();
  IntColumn get lateGraceMinutes => integer().withDefault(const Constant(0))();
  TextColumn get weekendType => text().withDefault(const Constant('double'))();
  IntColumn get overtimeRoundingMinutes =>
      integer().withDefault(const Constant(30))();

  RealColumn get officeLat => real().nullable()();
  RealColumn get officeLng => real().nullable()();
  IntColumn get officeRadiusMeters =>
      integer().withDefault(const Constant(300))();

  BoolColumn get geofenceEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get checkinReminderEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get checkoutReminderEnabled =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
