import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/ledger_entry.dart';
import '../../providers/account_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../providers/transfer_providers.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/money_text.dart';
import '../transactions/add_transaction_screen.dart';
import '../transfers/add_transfer_screen.dart';
import 'account_form_screen.dart';

/// No Add Transaction / Transfer shortcuts here — both live in the home
/// tab's center speed-dial menu now, so duplicating them per-screen was
/// just redundant. Editing an entry from the ledger below still opens
/// the right form with this account preselected.
class AccountDetailScreen extends ConsumerWidget {
  final int accountId;

  const AccountDetailScreen({super.key, required this.accountId});

  Future<void> _openEntry(
    BuildContext context,
    WidgetRef ref,
    LedgerEntry entry,
  ) async {
    if (entry.kind == LedgerKind.transaction) {
      final transaction = await ref.read(
        transactionByIdProvider(entry.id).future,
      );
      if (transaction != null && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddTransactionScreen(
              initialAccountId: accountId,
              transaction: transaction,
            ),
          ),
        );
      }
    } else {
      final transfer = await ref.read(transferByIdProvider(entry.id).future);
      if (transfer != null && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddTransferScreen(
              initialFromAccountId: accountId,
              transfer: transfer,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(accountSummaryProvider(accountId));
    final entriesAsync = ref.watch(accountLedgerProvider(accountId));

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
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (entries) {
                    if (entries.isEmpty) {
                      return const Center(
                        child: Text(
                          'No transactions yet.\nUse the pencil button on '
                          'the home tab to add one.',
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
                            iconKey: entry.iconKey,
                            colorValue: entry.iconColor,
                          ),
                          title: Text(entry.title),
                          subtitle: Text(
                            entry.note?.isNotEmpty == true
                                ? entry.note!
                                : DateFormat(
                                    'EEE, d MMM yyyy',
                                  ).format(entry.date),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              MoneyText(
                                minorUnits: entry.amount,
                                currency: summary.currency,
                                signType: entry.signType,
                              ),
                              Text(
                                DateFormat('HH:mm').format(entry.date),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _openEntry(context, ref, entry),
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
