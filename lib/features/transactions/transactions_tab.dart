import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/global_ledger_entry.dart';
import '../../models/ledger_entry.dart';
import '../../providers/transaction_providers.dart';
import '../../providers/transfer_providers.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/money_text.dart';
import 'add_transaction_screen.dart';
import '../transfers/add_transfer_screen.dart';

/// Home tab: every transaction + transfer across all accounts for the
/// selected month, day-grouped, matching the reference app's Transaksi
/// screen. Per-currency income/expense/total summary (never blended across
/// currencies).
class TransactionsTab extends ConsumerStatefulWidget {
  const TransactionsTab({super.key});

  @override
  ConsumerState<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends ConsumerState<TransactionsTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(globalLedgerInMonthProvider(_month));

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: Column(
        children: [
          _MonthPager(
            month: _month,
            onChanged: (m) => setState(() => _month = m),
          ),
          const Divider(height: 1),
          Expanded(
            child: entriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (entries) {
                if (entries.isEmpty) {
                  return const Center(
                    child: Text(
                      'No transactions this month.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                final byCurrency = groupBy(
                  entries,
                  (GlobalLedgerEntry e) => e.currency.id,
                );
                final byDay = groupBy(
                  entries,
                  (GlobalLedgerEntry e) => DateTime(
                    e.entry.date.year,
                    e.entry.date.month,
                    e.entry.date.day,
                  ),
                );
                final days = byDay.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                return ListView(
                  children: [
                    for (final group in byCurrency.values)
                      _CurrencySummary(entries: group),
                    const SizedBox(height: 8),
                    for (final day in days)
                      _DaySection(day: day, entries: byDay[day]!),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthPager extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  const _MonthPager({required this.month, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
          ),
          Text(
            DateFormat('MMMM yyyy').format(month),
            style: const TextStyle(fontSize: 16),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
          ),
        ],
      ),
    );
  }
}

/// Income only counts plain 'in' transactions; transfers move money between
/// your own accounts so they're excluded from income/expense (they still
/// show up as line items below, just not summed into these totals).
class _CurrencySummary extends StatelessWidget {
  final List<GlobalLedgerEntry> entries;
  const _CurrencySummary({required this.entries});

  @override
  Widget build(BuildContext context) {
    final currency = entries.first.currency;
    final income = entries
        .where(
          (e) =>
              e.entry.kind == LedgerKind.transaction &&
              e.entry.signType == 'in',
        )
        .fold<int>(0, (sum, e) => sum + e.entry.amount);
    final expense = entries
        .where(
          (e) =>
              e.entry.kind == LedgerKind.transaction &&
              e.entry.signType == 'out',
        )
        .fold<int>(0, (sum, e) => sum + e.entry.amount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currency.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Income'),
              MoneyText(minorUnits: income, currency: currency, signType: 'in'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Expense'),
              MoneyText(
                minorUnits: expense,
                currency: currency,
                signType: 'out',
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
              MoneyText(
                minorUnits: income - expense,
                currency: currency,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DaySection extends ConsumerWidget {
  final DateTime day;
  final List<GlobalLedgerEntry> entries;
  const _DaySection({required this.day, required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyIds = entries.map((e) => e.currency.id).toSet();
    final singleCurrency = currencyIds.length == 1
        ? entries.first.currency
        : null;
    final net = singleCurrency == null
        ? null
        : entries
              .where((e) => e.entry.kind == LedgerKind.transaction)
              .fold<int>(
                0,
                (sum, e) =>
                    sum +
                    (e.entry.signType == 'in'
                        ? e.entry.amount
                        : -e.entry.amount),
              );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                DateFormat('d').format(day),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('EEEE').format(day)),
                    Text(
                      DateFormat('MMMM yyyy').format(day),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (net != null)
                MoneyText(minorUnits: net, currency: singleCurrency!),
            ],
          ),
        ),
        for (final global in entries)
          ListTile(
            leading: IconTile(
              iconKey: global.entry.iconKey,
              colorValue: global.entry.iconColor,
            ),
            title: Text(global.entry.title),
            subtitle: Text(
              global.entry.note?.isNotEmpty == true
                  ? '${global.account.name} · ${global.entry.note}'
                  : global.account.name,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MoneyText(
                  minorUnits: global.entry.amount,
                  currency: global.currency,
                  signType: global.entry.signType,
                ),
                Text(
                  DateFormat('HH:mm').format(global.entry.date),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            onTap: () => _openEntry(context, ref, global),
          ),
        const Divider(height: 24),
      ],
    );
  }

  Future<void> _openEntry(
    BuildContext context,
    WidgetRef ref,
    GlobalLedgerEntry global,
  ) async {
    if (global.entry.kind == LedgerKind.transaction) {
      final transaction = await ref.read(
        transactionByIdProvider(global.entry.id).future,
      );
      if (transaction != null && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddTransactionScreen(
              initialAccountId: global.account.id,
              transaction: transaction,
            ),
          ),
        );
      }
    } else {
      final transfer = await ref.read(
        transferByIdProvider(global.entry.id).future,
      );
      if (transfer != null && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddTransferScreen(
              initialFromAccountId: global.account.id,
              transfer: transfer,
            ),
          ),
        );
      }
    }
  }
}
