import 'package:drift/drift.dart';

import 'currencies_table.dart';

/// A lightweight, optional tag transactions can be attributed to (e.g.
/// "Food", "Bali Trip") — no over-limit alerts, just spent-vs-allocated
/// tracking. Scoped to one currency (like Accounts) so that sum is always
/// meaningful. The actual monthly allocation lives in BudgetAmounts
/// (effective-dated — see that table), not here.
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();
  TextColumn get icon => text().nullable()();
  IntColumn get color => integer().nullable()();

  /// Nullable only so the schema-3 migration doesn't need a default for
  /// pre-existing rows; the app always sets it when creating a budget.
  IntColumn get currencyId => integer().nullable().references(Currencies, #id)();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
}
