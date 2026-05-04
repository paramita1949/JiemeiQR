import 'package:drift/drift.dart';

@DataClassName('StocktakeSessionRecord')
class StocktakeSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get monthKey => text()();
  IntColumn get status => integer().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
}
