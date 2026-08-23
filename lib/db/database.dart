import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'seed_data.dart';
import 'tables/accounts_table.dart';
import 'tables/budgets_table.dart';
import 'tables/categories_table.dart';
import 'tables/currencies_table.dart';
import 'tables/transactions_table.dart';
import 'tables/transfers_table.dart';

export 'tables/categories_table.dart' show CategoryType;

part 'database.g.dart';

@DriftDatabase(
  tables: [Currencies, Accounts, Categories, Budgets, Transactions, Transfers],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For tests / alternate connections (e.g. restore-from-backup helpers
  /// that want an in-memory DB), not used by the app at runtime.
  AppDatabase.withExecutor(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await batch((batch) {
        batch.insertAll(currencies, presetCurrencies);
        batch.insertAll(categories, presetCategories);
      });
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // m.createTable uses the current table definition, so this already
        // includes the schema-3 currencyId/monthlyAmount columns below.
        await m.createTable(budgets);
        await m.addColumn(transactions, transactions.budgetId);
      } else if (from < 3) {
        await m.addColumn(budgets, budgets.currencyId);
        await m.addColumn(budgets, budgets.monthlyAmount);
      }
    },
  );
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'dompetkuh');
}
