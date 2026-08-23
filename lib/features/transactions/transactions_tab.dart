import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../db/database.dart';
import '../../models/global_transaction_entry.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/money_text.dart';
import 'add_transaction_screen.dart';

/// Home tab: all transactions across every account for the selected month,
/// day-grouped, matching the reference app's Transaksi screen. Per-currency
/// income/expense/total summary (never blended across currencies).
class TransactionsTab extends ConsumerStatefulWidget {
  const TransactionsTab({super.key});

  @override
  ConsumerState<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends ConsumerState<TransactionsTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(transactionsInMonthProvider(_month));

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
                  (GlobalTransactionEntry e) => e.currency.id,
                );
                final byDay = groupBy(
                  entries,
                  (GlobalTransactionEntry e) => DateTime(
                    e.transaction.date.year,
                    e.transaction.date.month,
                    e.transaction.date.day,
                  ),
                );
                final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

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
            onPressed: () =>
                onChanged(DateTime(month.year, month.month - 1)),
          ),
          Text(
            DateFormat('MMMM yyyy').format(month),
            style: const TextStyle(fontSize: 16),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () =>
                onChanged(DateTime(month.year, month.month + 1)),
          ),
        ],
      ),
    );
  }
}

class _CurrencySummary extends StatelessWidget {
  final List<GlobalTransactionEntry> entries;
  const _CurrencySummary({required this.entries});

  @override
  Widget build(BuildContext context) {
    final currency = entries.first.currency;
    final income = entries
        .where((e) => e.transaction.type == CategoryType.in_)
        .fold<int>(0, (sum, e) => sum + e.transaction.amount);
    final expense = entries
        .where((e) => e.transaction.type == CategoryType.out)
        .fold<int>(0, (sum, e) => sum + e.transaction.amount);

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

class _DaySection extends StatelessWidget {
  final DateTime day;
  final List<GlobalTransactionEntry> entries;
  const _DaySection({required this.day, required this.entries});

  @override
  Widget build(BuildContext context) {
    final currencyIds = entries.map((e) => e.currency.id).toSet();
    final singleCurrency = currencyIds.length == 1 ? entries.first.currency : null;
    final net = singleCurrency == null
        ? null
        : entries.fold<int>(
            0,
            (sum, e) => sum +
                (e.transaction.type == CategoryType.in_
                    ? e.transaction.amount
                    : -e.transaction.amount),
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
        for (final entry in entries)
          ListTile(
            leading: IconTile(
              iconKey: entry.category.icon,
              colorValue: entry.category.color,
            ),
            title: Text(entry.category.name),
            subtitle: Text(
              entry.transaction.note?.isNotEmpty == true
                  ? '${entry.account.name} · ${entry.transaction.note}'
                  : entry.account.name,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MoneyText(
                  minorUnits: entry.transaction.amount,
                  currency: entry.currency,
                  signType: entry.transaction.type,
                ),
                Text(
                  DateFormat('HH:mm').format(entry.transaction.date),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddTransactionScreen(
                    initialAccountId: entry.account.id,
                    transaction: entry.transaction,
                  ),
                ),
              );
            },
          ),
        const Divider(height: 24),
      ],
    );
  }
}
