import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
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
        (rows) =>
            rows
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

/// SQL for how much one transfer leg contributes to a currency's report
/// totals, given `tr` (the transfer), `a` (the leg's own account) and `o`
/// (the other account). Cross-currency legs count in full: money really
/// entered/left this currency. A same-currency transfer just moves money
/// between your own accounts, so it counts only for what it lost or gained
/// along the way (sent minus received = a fee), and nothing when equal.
String _transferLegAmountSql({required bool incoming}) {
  final own = incoming ? 'tr.to_amount' : 'tr.from_amount';
  final other = incoming ? 'tr.from_amount' : 'tr.to_amount';
  return 'CASE WHEN o.currency_id = a.currency_id '
      'THEN MAX($own - $other, 0) ELSE $own END';
}

/// The synthetic "Transfer" slice of the same breakdown: cross-currency
/// transfer legs (and same-currency transfer fees — see
/// [_transferLegAmountSql]) count as income/expense but have no category,
/// so they're summed separately and merged into the list by the Reports
/// screen. Null when there are none.
final transferBreakdownProvider =
    StreamProvider.family<CategoryBreakdownEntry?, CategoryBreakdownArgs>((
      ref,
      args,
    ) {
      final db = ref.watch(databaseProvider);
      final isIn = args.type == CategoryType.in_;
      final accountCol = isIn ? 'to_account_id' : 'from_account_id';
      final otherCol = isIn ? 'from_account_id' : 'to_account_id';
      final leg = _transferLegAmountSql(incoming: isIn);

      final conditions = StringBuffer('WHERE a.currency_id = ?');
      final variables = <Variable>[Variable.withInt(args.currencyId)];
      if (args.start != null) {
        conditions.write(' AND tr.date >= ?');
        variables.add(Variable.withDateTime(args.start!));
      }
      if (args.end != null) {
        conditions.write(' AND tr.date < ?');
        variables.add(Variable.withDateTime(args.end!));
      }

      return db
          .customSelect(
            '''
            SELECT COALESCE(SUM($leg), 0) AS total,
              COALESCE(SUM(CASE WHEN $leg > 0 THEN 1 ELSE 0 END), 0) AS n
            FROM transfers tr
            INNER JOIN accounts a ON a.id = tr.$accountCol
            INNER JOIN accounts o ON o.id = tr.$otherCol
            $conditions
            ''',
            variables: variables,
            readsFrom: {db.transfers, db.accounts},
          )
          .map((row) {
            final total = row.read<int>('total');
            return total > 0
                ? CategoryBreakdownEntry(
                    category: null,
                    totalAmount: total,
                    transactionCount: row.read<int>('n'),
                  )
                : null;
          })
          .watchSingle();
    });

typedef CurrencyTotals = ({int income, int expense});

/// [start] inclusive, [end] exclusive; both null means all-time.
typedef CurrencyTotalsArgs = ({int currencyId, DateTime? start, DateTime? end});

/// Income vs expense totals for one currency's accounts within an optional
/// date range — the compact summary line above the Reports donut chart.
/// Transfers count the same way as in the breakdown (see
/// [_transferLegAmountSql]).
final currencyTotalsProvider =
    StreamProvider.family<CurrencyTotals, CurrencyTotalsArgs>((ref, args) {
      final db = ref.watch(databaseProvider);

      // Variables are positional, so each WHERE must be built in the same
      // order its subquery appears in the SQL below.
      final variables = <Variable>[];
      String where(String dateColumn) {
        final conditions = StringBuffer('WHERE a.currency_id = ?');
        variables.add(Variable.withInt(args.currencyId));
        if (args.start != null) {
          conditions.write(' AND $dateColumn >= ?');
          variables.add(Variable.withDateTime(args.start!));
        }
        if (args.end != null) {
          conditions.write(' AND $dateColumn < ?');
          variables.add(Variable.withDateTime(args.end!));
        }
        return conditions.toString();
      }

      final legIn = _transferLegAmountSql(incoming: true);
      final legOut = _transferLegAmountSql(incoming: false);
      final txIn = where('t.date');
      final transferIn = where('tr.date');
      final txOut = where('t.date');
      final transferOut = where('tr.date');

      final query = db
          .customSelect(
            '''
        SELECT
          COALESCE((SELECT SUM(t.amount) FROM transactions t
            INNER JOIN accounts a ON a.id = t.account_id
            $txIn AND t.type = 'in'), 0)
          + COALESCE((SELECT SUM($legIn) FROM transfers tr
            INNER JOIN accounts a ON a.id = tr.to_account_id
            INNER JOIN accounts o ON o.id = tr.from_account_id
            $transferIn), 0) AS income,
          COALESCE((SELECT SUM(t.amount) FROM transactions t
            INNER JOIN accounts a ON a.id = t.account_id
            $txOut AND t.type = 'out'), 0)
          + COALESCE((SELECT SUM($legOut) FROM transfers tr
            INNER JOIN accounts a ON a.id = tr.from_account_id
            INNER JOIN accounts o ON o.id = tr.to_account_id
            $transferOut), 0) AS expense
        ''',
            variables: variables,
            readsFrom: {db.transactions, db.transfers, db.accounts},
          )
          .map(
            (row) => (
              income: row.read<int>('income'),
              expense: row.read<int>('expense'),
            ),
          );
      return query.watchSingle();
    });
