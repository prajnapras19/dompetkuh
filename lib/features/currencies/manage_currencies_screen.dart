import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/database.dart';
import '../../providers/currency_providers.dart';
import 'currency_form_screen.dart';

class ManageCurrenciesScreen extends ConsumerWidget {
  const ManageCurrenciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currenciesAsync = ref.watch(allCurrenciesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Currencies')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CurrencyFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: currenciesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (currencies) {
          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Disabled currencies stay on any existing accounts, but '
                  "won't show up when creating new ones or in Reports.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              for (final currency in currencies)
                _CurrencyRow(currency: currency),
            ],
          );
        },
      ),
    );
  }
}

class _CurrencyRow extends ConsumerWidget {
  final Currency currency;
  const _CurrencyRow({required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = currency.archivedAt == null;
    final repo = ref.read(currencyRepositoryProvider);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: enabled ? Colors.blueGrey : Colors.grey.shade300,
        child: Text(
          currency.symbol.characters.first,
          style: TextStyle(color: enabled ? Colors.white : Colors.grey),
        ),
      ),
      title: Text(
        '${currency.code} — ${currency.name}',
        style: enabled ? null : const TextStyle(color: Colors.grey),
      ),
      subtitle: Text(
        currency.subunitName != null
            ? '${currency.decimalPlaces} dp · ${currency.subunitName}'
            : '${currency.decimalPlaces} dp',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: enabled,
            onChanged: (value) async {
              if (value) {
                await repo.unarchive(currency.id);
              } else {
                await repo.archive(currency.id);
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (action) => _handleAction(context, ref, action),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CurrencyFormScreen(currency: currency),
          ),
        );
      },
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final repo = ref.read(currencyRepositoryProvider);
    switch (action) {
      case 'edit':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CurrencyFormScreen(currency: currency),
          ),
        );
      case 'delete':
        final inUse = await repo.isInUse(currency.id);
        if (inUse) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'This currency is used by an account — disable it instead.',
                ),
              ),
            );
          }
          return;
        }
        await repo.delete(currency.id);
    }
  }
}
