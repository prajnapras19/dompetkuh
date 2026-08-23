import 'package:drift/drift.dart';

import 'accounts_table.dart';
import 'budgets_table.dart';
import 'categories_table.dart';

/// In/out transactions only — transfers live in the separate Transfers table.
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId => integer().references(Categories, #id)();

  /// Optional budget tag — orthogonal to category, no limits/alerts attached.
  IntColumn get budgetId => integer().nullable().references(Budgets, #id)();

  /// 'in' or 'out'. Amount is always stored positive; sign is derived from this.
  TextColumn get type =>
      text().customConstraint("NOT NULL CHECK (type IN ('in', 'out'))")();

  /// Positive integer, in the account currency's minor unit.
  IntColumn get amount => integer()();

  TextColumn get note => text().nullable()();

  /// User-chosen transaction date/time (not necessarily "now").
  DateTimeColumn get date => dateTime()();

  DateTimeColumn get createdAt => dateTime()();
}
