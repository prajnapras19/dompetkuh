import 'package:drift/drift.dart';

import 'currencies_table.dart';

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  /// Icon key (see widgets/icon_catalog.dart) and ARGB color for the
  /// account's icon tile, matching the reference app's colorful account list.
  TextColumn get icon => text().nullable()();
  IntColumn get color => integer().nullable()();

  /// Immutable at the app layer once the account has >=1 transaction/transfer.
  IntColumn get currencyId => integer().references(Currencies, #id)();

  /// Opening balance, in the account currency's minor unit.
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
