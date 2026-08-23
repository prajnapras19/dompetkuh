import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../db/database.dart';
import '../../models/category_breakdown_entry.dart';
import '../../providers/currency_providers.dart';
import '../../providers/report_providers.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/money_text.dart';

/// Per-currency reports: income/expense summary, and a category breakdown
/// donut + list for the selected in/out type, matching the reference app's
/// Laporan screen. Never blends totals across currencies.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int? _currencyId;
  String _type = CategoryType.out;

  @override
  Widget build(BuildContext context) {
    final currenciesAsync = ref.watch(activeCurrenciesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: currenciesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (currencies) {
          if (currencies.isEmpty) {
            return const Center(
              child: Text(
                'No currencies yet.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          _currencyId ??= currencies.first.id;
          final currency = currencies.firstWhere(
            (c) => c.id == _currencyId,
            orElse: () => currencies.first,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<int>(
                initialValue: currency.id,
                items: [
                  for (final c in currencies)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text('${c.code} — ${c.name}'),
                    ),
                ],
                onChanged: (v) => setState(() => _currencyId = v),
              ),
              const SizedBox(height: 8),
              _MonthPager(
                month: _month,
                onChanged: (m) => setState(() => _month = m),
              ),
              const SizedBox(height: 8),
              _TotalsLine(currencyId: currency.id, month: _month, currency: currency),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: CategoryType.in_, label: Text('Income')),
                  ButtonSegment(value: CategoryType.out, label: Text('Expense')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),
              _Breakdown(
                currencyId: currency.id,
                month: _month,
                type: _type,
                currency: currency,
              ),
            ],
          );
        },
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
        ),
        Text(DateFormat('MMMM yyyy').format(month)),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
        ),
      ],
    );
  }
}

class _TotalsLine extends ConsumerWidget {
  final int currencyId;
  final DateTime month;
  final Currency currency;
  const _TotalsLine({
    required this.currencyId,
    required this.month,
    required this.currency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalsAsync = ref.watch(
      currencyMonthTotalsProvider((currencyId: currencyId, month: month)),
    );
    return totalsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (totals) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              const Text('Income', style: TextStyle(color: Colors.grey)),
              MoneyText(
                minorUnits: totals.income,
                currency: currency,
                signType: 'in',
              ),
            ],
          ),
          Column(
            children: [
              const Text('Expense', style: TextStyle(color: Colors.grey)),
              MoneyText(
                minorUnits: totals.expense,
                currency: currency,
                signType: 'out',
              ),
            ],
          ),
          Column(
            children: [
              const Text('Net', style: TextStyle(color: Colors.grey)),
              MoneyText(
                minorUnits: totals.income - totals.expense,
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

const _donutPalette = [
  0xFFE53935,
  0xFFFB8C00,
  0xFFFFB300,
  0xFF43A047,
  0xFF00897B,
  0xFF1E88E5,
  0xFF3949AB,
  0xFF8E24AA,
  0xFFD81B60,
  0xFF6D4C41,
];

class _Breakdown extends ConsumerWidget {
  final int currencyId;
  final DateTime month;
  final String type;
  final Currency currency;

  const _Breakdown({
    required this.currencyId,
    required this.month,
    required this.type,
    required this.currency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakdownAsync = ref.watch(
      categoryBreakdownProvider((
        currencyId: currencyId,
        month: month,
        type: type,
      )),
    );

    return breakdownAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (entries) {
        if (entries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'No data for this period.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        final total = entries.fold<int>(0, (sum, e) => sum + e.totalAmount);

        return Column(
          children: [
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 48,
                  sectionsSpace: 2,
                  sections: [
                    for (final (index, e) in entries.indexed)
                      PieChartSectionData(
                        value: e.totalAmount.toDouble(),
                        color: Color(
                          _donutPalette[index % _donutPalette.length],
                        ),
                        radius: 56,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final (index, e) in entries.indexed)
              _CategoryRow(
                entry: e,
                currency: currency,
                percentage: total == 0 ? 0 : e.totalAmount / total * 100,
                color: _donutPalette[index % _donutPalette.length],
              ),
          ],
        );
      },
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategoryBreakdownEntry entry;
  final Currency currency;
  final double percentage;
  final int color;

  const _CategoryRow({
    required this.entry,
    required this.currency,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: IconTile(iconKey: entry.category.icon, colorValue: color),
      title: Text(entry.category.name),
      subtitle: Text('${percentage.toStringAsFixed(1)}%'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          MoneyText(minorUnits: entry.totalAmount, currency: currency),
          Text(
            '${entry.transactionCount} transaction${entry.transactionCount == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
