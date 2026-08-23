import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import 'database_provider.dart';

/// Active budgets, for the picker in Add/Edit Transaction.
final activeBudgetsProvider = StreamProvider<List<Budget>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.budgets)
        ..where((b) => b.archivedAt.isNull())
        ..orderBy([(b) => OrderingTerm(expression: b.sortOrder)]))
      .watch();
});

/// All budgets including archived, for the Manage Budgets screen.
final allBudgetsProvider = StreamProvider<List<Budget>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.budgets)
        ..orderBy([(b) => OrderingTerm(expression: b.sortOrder)]))
      .watch();
});

final budgetByIdProvider = StreamProvider.family<Budget?, int>((ref, id) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.budgets,
  )..where((b) => b.id.equals(id))).watchSingleOrNull();
});

/// Total spent (out-transactions tagged with this budget) within one
/// calendar month — computed on read, never stored, so it can't drift out
/// of sync with the ledger. [month] should have day=1.
final budgetSpentInMonthProvider =
    StreamProvider.family<int, ({int budgetId, DateTime month})>((
      ref,
      args,
    ) {
      final db = ref.watch(databaseProvider);
      final start = DateTime(args.month.year, args.month.month);
      final end = DateTime(args.month.year, args.month.month + 1);

      final query = db.selectOnly(db.transactions)
        ..addColumns([db.transactions.amount.sum()])
        ..where(
          db.transactions.budgetId.equals(args.budgetId) &
              db.transactions.type.equals('out') &
              db.transactions.date.isBiggerOrEqualValue(start) &
              db.transactions.date.isSmallerThanValue(end),
        );
      return query
          .map((row) => row.read(db.transactions.amount.sum()) ?? 0)
          .watchSingle();
    });

/// The monthly allocation that actually applies to [month] — the amount
/// from the most recent BudgetAmounts row whose effectiveFrom is <= month.
/// Null if the budget had no amount set yet as of that month (e.g. paging
/// back to before the budget existed). [month] should have day=1.
final budgetAmountForMonthProvider =
    StreamProvider.family<int?, ({int budgetId, DateTime month})>((
      ref,
      args,
    ) {
      final db = ref.watch(databaseProvider);
      final month = DateTime(args.month.year, args.month.month);

      final query = db.select(db.budgetAmounts)
        ..where(
          (a) =>
              a.budgetId.equals(args.budgetId) &
              a.effectiveFrom.isSmallerOrEqualValue(month),
        )
        ..orderBy([(a) => OrderingTerm.desc(a.effectiveFrom)])
        ..limit(1);
      return query.watchSingleOrNull().map((row) => row?.amount);
    });

class BudgetRepository {
  BudgetRepository(this._db);
  final AppDatabase _db;

  Future<int> create(BudgetsCompanion entry) {
    return _db.into(_db.budgets).insert(entry);
  }

  Future<bool> update(Budget budget) {
    return _db.update(_db.budgets).replace(budget);
  }

  /// Sets the monthly amount effective from [month] onward — inserts a new
  /// BudgetAmounts row (or updates one already effective from that exact
  /// month, e.g. editing twice in the same month) rather than overwriting
  /// history, so earlier months keep whatever was in effect at the time.
  Future<void> setAmountEffectiveFrom(
    int budgetId,
    DateTime month,
    int amount,
  ) async {
    final normalized = DateTime(month.year, month.month);
    final existing =
        await (_db.select(_db.budgetAmounts)..where(
              (a) =>
                  a.budgetId.equals(budgetId) &
                  a.effectiveFrom.equals(normalized),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await (_db.update(
        _db.budgetAmounts,
      )..where((a) => a.id.equals(existing.id))).write(
        BudgetAmountsCompanion(amount: Value(amount)),
      );
    } else {
      await _db
          .into(_db.budgetAmounts)
          .insert(
            BudgetAmountsCompanion.insert(
              budgetId: budgetId,
              effectiveFrom: normalized,
              amount: amount,
            ),
          );
    }
  }

  Future<bool> isInUse(int budgetId) async {
    final count = await (_db.selectOnly(_db.transactions)
          ..addColumns([_db.transactions.id.count()])
          ..where(_db.transactions.budgetId.equals(budgetId)))
        .map((row) => row.read(_db.transactions.id.count()) ?? 0)
        .getSingle();
    return count > 0;
  }

  Future<void> archive(int budgetId) {
    return (_db.update(_db.budgets)..where((b) => b.id.equals(budgetId)))
        .write(BudgetsCompanion(archivedAt: Value(DateTime.now())));
  }

  Future<void> unarchive(int budgetId) {
    return (_db.update(_db.budgets)..where((b) => b.id.equals(budgetId)))
        .write(const BudgetsCompanion(archivedAt: Value(null)));
  }

  Future<void> delete(int budgetId) async {
    await (_db.delete(
      _db.budgetAmounts,
    )..where((a) => a.budgetId.equals(budgetId))).go();
    await (_db.delete(_db.budgets)..where((b) => b.id.equals(budgetId))).go();
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(databaseProvider));
});
