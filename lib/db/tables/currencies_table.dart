import 'package:drift/drift.dart';

class Currencies extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get code => text().unique()();
  TextColumn get name => text()();
  TextColumn get symbol => text()();

  /// Number of decimal places this currency's minor unit uses.
  /// Amounts are always stored as integers in this minor unit
  /// (e.g. IDR=0 whole rupiah, USD=2 cents, Gold=3 milligrams).
  IntColumn get decimalPlaces => integer()();

  /// Display-only label for the minor unit (e.g. "cent", "sen", "øre").
  /// Null when the currency has no subunit (decimalPlaces == 0).
  TextColumn get subunitName => text().nullable()();

  BoolColumn get symbolBeforeAmount =>
      boolean().withDefault(const Constant(true))();

  BoolColumn get isPreset => boolean().withDefault(const Constant(false))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get archivedAt => dateTime().nullable()();
}
