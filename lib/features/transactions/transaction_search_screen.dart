import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/global_ledger_entry.dart';
import '../../providers/transfer_providers.dart';
import 'transactions_tab.dart';

/// Search transactions/transfers by note, across all accounts and all
/// time — matching the reference app's "Cari berdasarkan catatan" box
/// (a separate pushed screen there too, reached from the Transactions tab's
/// search icon). Unlike the month view, there's no currency summary here
/// since results can span multiple months and currencies at once.
class TransactionSearchScreen extends ConsumerStatefulWidget {
  const TransactionSearchScreen({super.key});

  @override
  ConsumerState<TransactionSearchScreen> createState() =>
      _TransactionSearchScreenState();
}

class _TransactionSearchScreenState
    extends ConsumerState<TransactionSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(globalLedgerSearchProvider(_query));

    return Scaffold(
      appBar: AppBar(title: const Text('Search Transactions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by note',
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() {
                          _controller.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _query.trim().isEmpty
                ? const SizedBox.shrink()
                : resultsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (entries) {
                      if (entries.isEmpty) {
                        return const Center(
                          child: Text(
                            'No transactions match.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }
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
                          for (final day in days)
                            DaySection(day: day, entries: byDay[day]!),
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
