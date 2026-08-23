import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'seed_data.dart';
import 'tables/accounts_table.dart';
import 'tables/budget_amounts_table.dart';
import 'tables/budgets_table.dart';
import 'tables/categories_table.dart';
import 'tables/currencies_table.dart';
import 'tables/transactions_table.dart';
import 'tables/transfers_table.dart';

export 'tables/categories_table.dart' show CategoryType;

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Currencies,
    Accounts,
    Categories,
    Budgets,
    BudgetAmounts,
    Transactions,
    Transfers,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For tests / alternate connections (e.g. restore-from-backup helpers
  /// that want an in-memory DB), not used by the app at runtime.
  AppDatabase.withExecutor(super.executor);

  @override
  int get schemaVersion => 4;

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
        // Uses the *current* Budgets definition (no monthlyAmount,
        // currencyId already present) — fine since anyone on from<2 has
        // no budgets yet at all.
        await m.createTable(budgets);
        await m.addColumn(transactions, transactions.budgetId);
      }
      if (from < 3 && from >= 2) {
        // Only DBs that already had a v2 Budgets table (i.e. didn't just
        // get the current definition via createTable above) need this.
        await m.addColumn(budgets, budgets.currencyId);
      }
      if (from < 4) {
        await m.createTable(budgetAmounts);
        if (from == 3) {
          // Only from==3 ever had a real on-disk monthly_amount column
          // (from<2 never had one; the from<2 createTable path above
          // never adds it since it's not in the current definition).
          // Move each budget's existing flat amount into an initial
          // effective-dated row (starting "now", the best available
          // approximation since the original had no history), then drop
          // the now-unused column.
          final rows = await customSelect(
            'SELECT id, monthly_amount FROM budgets',
          ).get();
          final effectiveFrom = DateTime(
            DateTime.now().year,
            DateTime.now().month,
          );
          for (final row in rows) {
            await into(budgetAmounts).insert(
              BudgetAmountsCompanion.insert(
                budgetId: row.read<int>('id'),
                effectiveFrom: effectiveFrom,
                amount: row.read<int>('monthly_amount'),
              ),
            );
          }
          await m.dropColumn(budgets, 'monthly_amount');
        }
      }
    },
  );
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'dompetkuh');
}
