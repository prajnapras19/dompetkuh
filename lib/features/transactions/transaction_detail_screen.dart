import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../db/database.dart';
import '../../models/global_ledger_entry.dart';
import '../../providers/transaction_providers.dart';
import '../../theme/colors.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/money_text.dart';
import 'add_transaction_screen.dart';

/// Read-only summary of one transaction, matching the reference app's
/// Detail Transaksi screen — tapping a transaction opens this first rather
/// than jumping straight into the editable form, with Edit/Delete as
/// explicit app bar actions (Delete living here also sidesteps the
/// bottom-safe-area issue the edit form's own DELETE button had).
class TransactionDetailScreen extends ConsumerWidget {
  final GlobalLedgerEntry entry;
  final Transaction transaction;

  const TransactionDetailScreen({
    super.key,
    required this.entry,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddTransactionScreen(
                    initialAccountId: entry.account.id,
                    transaction: transaction,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconTile(
                        iconKey: entry.entry.iconKey,
                        colorValue: entry.entry.iconColor,
                        size: 48,
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: dompetkuhBlue,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          entry.entry.title,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _DetailRow(
                    'DATE',
                    DateFormat(
                      'EEEE, d MMMM yyyy HH:mm',
                    ).format(entry.entry.date),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow('ACCOUNT', entry.account.name),
                  if (entry.entry.note?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    _DetailRow('NOTE', entry.entry.note!),
                  ],
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'AMOUNT',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        MoneyText(
                          minorUnits: entry.entry.amount,
                          currency: entry.currency,
                          signType: entry.entry.signType,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(transactionRepositoryProvider).delete(transaction.id);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
