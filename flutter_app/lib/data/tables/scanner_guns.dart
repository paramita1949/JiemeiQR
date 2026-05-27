import 'package:drift/drift.dart';

class ScannerGuns extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get label => text().unique()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
