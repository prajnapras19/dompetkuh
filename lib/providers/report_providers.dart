import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category_breakdown_entry.dart';
import 'database_provider.dart';

typedef ReportPeriod = ({int currencyId, DateTime month, String type});

/// Category breakdown (total + transaction count per category) for one
/// currency's accounts, one calendar month, one transaction type (in/out) —
/// feeds the Reports screen's donut chart and list. [period.month] should
/// have day=1.
final categoryBreakdownProvider =
    StreamProvider.family<List<CategoryBreakdownEntry>, ReportPeriod>((
      ref,
      period,
    ) {
      final db = ref.watch(databaseProvider);
      final start = DateTime(period.month.year, period.month.month);
      final end = DateTime(period.month.year, period.month.month + 1);

      final amountSum = db.transactions.amount.sum();
      final txnCount = db.transactions.id.count();

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
            ..where(
              db.accounts.currencyId.equals(period.currencyId) &
                  db.transactions.type.equals(period.type) &
                  db.transactions.date.isBiggerOrEqualValue(start) &
                  db.transactions.date.isSmallerThanValue(end),
            )
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

typedef CurrencyMonthTotals = ({int income, int expense});

/// Income vs expense totals for one currency's accounts, one calendar
/// month — the compact summary line above the Reports donut chart.
final currencyMonthTotalsProvider =
    StreamProvider.family<
      CurrencyMonthTotals,
      ({int currencyId, DateTime month})
    >((ref, args) {
      final db = ref.watch(databaseProvider);
      final start = DateTime(args.month.year, args.month.month);
      final end = DateTime(args.month.year, args.month.month + 1);

      final query = db.customSelect(
        '''
        SELECT
          COALESCE(SUM(CASE WHEN t.type = 'in' THEN t.amount ELSE 0 END), 0) AS income,
          COALESCE(SUM(CASE WHEN t.type = 'out' THEN t.amount ELSE 0 END), 0) AS expense
        FROM transactions t
        INNER JOIN accounts a ON a.id = t.account_id
        WHERE a.currency_id = ? AND t.date >= ? AND t.date < ?
        ''',
        variables: [
          Variable.withInt(args.currencyId),
          Variable.withDateTime(start),
          Variable.withDateTime(end),
        ],
        readsFrom: {db.transactions, db.accounts},
      ).map(
        (row) => (
          income: row.read<int>('income'),
          expense: row.read<int>('expense'),
        ),
      );
      return query.watchSingle();
    });
