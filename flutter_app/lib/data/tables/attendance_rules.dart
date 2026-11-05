import 'package:drift/drift.dart';

class AttendanceRules extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get accountKey => text().withDefault(const Constant('local'))();
  TextColumn get workStartTime => text().withDefault(const Constant('08:00'))();
  TextColumn get workEndTime => text().withDefault(const Constant('17:00'))();
  RealColumn get hourlyWage => real().withDefault(const Constant(28.85))();

  /// 午休开始时间；旧规则和旧备份默认使用11:30。
  TextColumn get restStartTime => text().withDefault(const Constant('11:30'))();

  /// 午休时段长度；0 表示不扣休息，保留旧规则的分钟数。
  IntColumn get restMinutes => integer().withDefault(const Constant(60))();
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
  TextColumn get autoCheckinPopupText => text().nullable()();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
