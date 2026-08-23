import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category_breakdown_entry.dart';
import 'database_provider.dart';

/// [start] inclusive, [end] exclusive; both null means all-time.
typedef CategoryBreakdownArgs = ({
  int currencyId,
  DateTime? start,
  DateTime? end,
  String type,
});

/// Category breakdown (total + transaction count per category) for one
/// currency's accounts, one transaction type (in/out), within an optional
/// date range — feeds the Reports screen's donut chart and list.
final categoryBreakdownProvider =
    StreamProvider.family<List<CategoryBreakdownEntry>, CategoryBreakdownArgs>((
      ref,
      args,
    ) {
      final db = ref.watch(databaseProvider);

      final amountSum = db.transactions.amount.sum();
      final txnCount = db.transactions.id.count();

      var predicate =
          db.accounts.currencyId.equals(args.currencyId) &
          db.transactions.type.equals(args.type);
      if (args.start != null) {
        predicate =
            predicate & db.transactions.date.isBiggerOrEqualValue(args.start!);
      }
      if (args.end != null) {
        predicate =
            predicate & db.transactions.date.isSmallerThanValue(args.end!);
      }

      final query =
          db.select(db.transactions).join([
              innerJoin(
                db.categories,
                db.categories.id.equalsExp(db.transactions.categoryId),
              ),
              innerJoin(
                db.accounts,
                db.accounts.id.equalsExp(db.transactions.accountId),
              ),
            ])
            ..where(predicate)
            ..addColumns([amountSum, txnCount])
            ..groupBy([db.transactions.categoryId]);

      return query.watch().map(
        (rows) => rows
            .map(
              (row) => CategoryBreakdownEntry(
                category: row.readTable(db.categories),
                totalAmount: row.read(amountSum) ?? 0,
                transactionCount: row.read(txnCount) ?? 0,
              ),
            )
            .where((e) => e.totalAmount > 0)
            .toList()
          ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount)),
      );
    });

typedef CurrencyTotals = ({int income, int expense});

/// [start] inclusive, [end] exclusive; both null means all-time.
typedef CurrencyTotalsArgs = ({int currencyId, DateTime? start, DateTime? end});

/// Income vs expense totals for one currency's accounts within an optional
/// date range — the compact summary line above the Reports donut chart.
final currencyTotalsProvider =
    StreamProvider.family<CurrencyTotals, CurrencyTotalsArgs>((ref, args) {
      final db = ref.watch(databaseProvider);

      final conditions = StringBuffer('WHERE a.currency_id = ?');
      final variables = <Variable>[Variable.withInt(args.currencyId)];
      if (args.start != null) {
        conditions.write(' AND t.date >= ?');
        variables.add(Variable.withDateTime(args.start!));
      }
      if (args.end != null) {
        conditions.write(' AND t.date < ?');
        variables.add(Variable.withDateTime(args.end!));
      }

      final query = db.customSelect(
        '''
        SELECT
          COALESCE(SUM(CASE WHEN t.type = 'in' THEN t.amount ELSE 0 END), 0) AS income,
          COALESCE(SUM(CASE WHEN t.type = 'out' THEN t.amount ELSE 0 END), 0) AS expense
        FROM transactions t
        INNER JOIN accounts a ON a.id = t.account_id
        $conditions
        ''',
        variables: variables,
        readsFrom: {db.transactions, db.accounts},
      ).map(
        (row) => (
          income: row.read<int>('income'),
          expense: row.read<int>('expense'),
        ),
      );
      return query.watchSingle();
    });
