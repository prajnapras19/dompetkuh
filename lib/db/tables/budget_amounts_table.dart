import 'package:drift/drift.dart';

import 'budgets_table.dart';

/// One "effective from" amount record for a Budget — the actual monthly
/// allocation for month M is whichever row has the latest `effectiveFrom`
/// that is `<= M`. Editing a budget's amount inserts a *new* row (effective
/// from the month you're editing in) rather than overwriting history, so
/// e.g. changing the amount in September 2026 doesn't alter what August
/// 2026 shows.
class BudgetAmounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get budgetId => integer().references(Budgets, #id)();

  /// Day=1 — the first month this amount applies to.
  DateTimeColumn get effectiveFrom => dateTime()();

  /// In the budget's currency's minor unit.
  IntColumn get amount => integer()();
}
