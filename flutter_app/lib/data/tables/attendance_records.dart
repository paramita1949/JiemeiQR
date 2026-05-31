import 'package:drift/drift.dart';

class AttendanceRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get accountKey => text().withDefault(const Constant('local'))();
  DateTimeColumn get day => dateTime()();
  DateTimeColumn get checkInAt => dateTime().nullable()();
  DateTimeColumn get checkOutAt => dateTime().nullable()();

  BoolColumn get isWorkday => boolean().withDefault(const Constant(true))();
  BoolColumn get isLate => boolean().withDefault(const Constant(false))();
  BoolColumn get isEarlyLeave => boolean().withDefault(const Constant(false))();
  BoolColumn get isAbsent => boolean().withDefault(const Constant(false))();
  BoolColumn get isLeave => boolean().withDefault(const Constant(false))();
  BoolColumn get isHoliday => boolean().withDefault(const Constant(false))();
  BoolColumn get isException => boolean().withDefault(const Constant(false))();
  BoolColumn get needsPatch => boolean().withDefault(const Constant(false))();
  BoolColumn get patched => boolean().withDefault(const Constant(false))();

  IntColumn get overtimeMinutesRaw =>
      integer().withDefault(const Constant(0))();
  IntColumn get leaveMinutes => integer().withDefault(const Constant(0))();
  RealColumn get overtimeHoursRounded =>
      real().withDefault(const Constant(0.0))();

  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
