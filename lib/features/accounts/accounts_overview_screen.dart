import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/account_summary.dart';
import '../../providers/account_providers.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/money_text.dart';
import 'account_form_screen.dart';

/// No Transfer shortcut here — it's in the home tab's center speed-dial
/// menu now, so a second entry point in this app bar would be redundant.
/// Tapping an account opens Edit directly (no separate per-account
/// transaction log screen — the Transactions tab's account filter covers
/// that, without an extra screen to maintain).
class AccountsOverviewScreen extends ConsumerWidget {
  const AccountsOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(allAccountSummariesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AccountFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: summariesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (summaries) {
          if (summaries.isEmpty) {
            return const _EmptyState();
          }
          final grouped = groupBy(summaries, (s) => s.currency.id);
          final groups = grouped.values.toList()
            ..sort(
              (a, b) => a.first.currency.sortOrder.compareTo(
                b.first.currency.sortOrder,
              ),
            );

          return ListView(
            children: [
              for (final group in groups) _CurrencyGroup(summaries: group),
            ],
          );
        },
      ),
    );
  }
}

class _CurrencyGroup extends ConsumerWidget {
  final List<AccountSummary> summaries;
  const _CurrencyGroup({required this.summaries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = summaries.first.currency;
    final totalAsync = ref.watch(totalBalanceByCurrencyProvider(currency.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            currency.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ),
        ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.blueGrey,
            child: Icon(Icons.summarize, color: Colors.white),
          ),
          title: const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
          trailing: totalAsync.when(
            data: (total) => MoneyText(
              minorUnits: total,
              currency: currency,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const Text('—'),
          ),
        ),
        for (final summary in summaries)
          ListTile(
            leading: IconTile(
              iconKey: summary.account.icon,
              colorValue: summary.account.color,
            ),
            title: Text(
              summary.account.name,
              style: summary.account.archivedAt != null
                  ? const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                    )
                  : null,
            ),
            trailing: MoneyText(
              minorUnits: summary.balance,
              currency: summary.currency,
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AccountFormScreen(account: summary.account),
                ),
              );
            },
          ),
        const Divider(height: 24),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No accounts yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap + to add your first account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
