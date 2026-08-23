import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/account_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/money_text.dart';
import '../transactions/add_transaction_screen.dart';
import 'account_form_screen.dart';

class AccountDetailScreen extends ConsumerWidget {
  final int accountId;

  const AccountDetailScreen({super.key, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(accountSummaryProvider(accountId));
    final entriesAsync = ref.watch(transactionsForAccountProvider(accountId));

    return Scaffold(
      appBar: AppBar(
        title: summaryAsync.maybeWhen(
          data: (s) => Text(s?.account.name ?? ''),
          orElse: () => const Text(''),
        ),
        actions: [
          summaryAsync.maybeWhen(
            data: (s) => s == null
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              AccountFormScreen(account: s.account),
                        ),
                      );
                    },
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: summaryAsync.maybeWhen(
        data: (s) => s == null
            ? null
            : FloatingActionButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          AddTransactionScreen(initialAccountId: accountId),
                    ),
                  );
                },
                child: const Icon(Icons.add),
              ),
        orElse: () => null,
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (summary) {
          if (summary == null) {
            return const Center(child: Text('Account not found'));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'BALANCE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    MoneyText(
                      minorUnits: summary.balance,
                      currency: summary.currency,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
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
                          'No transactions yet.\nTap + to add one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return ListTile(
                          leading: IconTile(
                            iconKey: entry.category.icon,
                            colorValue: entry.category.color,
                          ),
                          title: Text(entry.category.name),
                          subtitle: Text(
                            entry.transaction.note?.isNotEmpty == true
                                ? entry.transaction.note!
                                : DateFormat(
                                    'EEE, d MMM yyyy',
                                  ).format(entry.transaction.date),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              MoneyText(
                                minorUnits: entry.transaction.amount,
                                currency: summary.currency,
                                signType: entry.transaction.type,
                              ),
                              Text(
                                DateFormat(
                                  'HH:mm',
                                ).format(entry.transaction.date),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AddTransactionScreen(
                                  initialAccountId: accountId,
                                  transaction: entry.transaction,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
