import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../db/database.dart';
import '../../providers/account_providers.dart';
import '../../providers/category_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../theme/colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/icon_tile.dart';

/// Add or edit an in/out transaction. [initialAccountId] preselects the
/// account (e.g. when launched from Account Detail); [transaction] non-null
/// means edit.
class AddTransactionScreen extends ConsumerStatefulWidget {
  final int? initialAccountId;
  final Transaction? transaction;

  const AddTransactionScreen({
    super.key,
    this.initialAccountId,
    this.transaction,
  });

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  String _type = CategoryType.out;
  int? _accountId;
  int? _categoryId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _type = t?.type ?? CategoryType.out;
    _accountId = t?.accountId ?? widget.initialAccountId;
    _categoryId = t?.categoryId;
    _date = t?.date ?? DateTime.now();
    _amountController = TextEditingController();
    _noteController = TextEditingController(text: t?.note ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountSummariesProvider);
    final categoriesAsync = ref.watch(categoriesByTypeProvider(_type));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Add an account first before logging a transaction.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          _accountId ??= accounts.first.account.id;
          final selectedAccount = accounts.firstWhere(
            (a) => a.account.id == _accountId,
            orElse: () => accounts.first,
          );

          if (_amountController.text.isEmpty && widget.transaction != null) {
            _amountController.text = Money.formatEditable(
              widget.transaction!.amount,
              selectedAccount.currency,
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _TypeToggle(
                  type: _type,
                  onChanged: (t) => setState(() {
                    _type = t;
                    _categoryId = null;
                  }),
                ),
                const SizedBox(height: 20),
                const _Caption('ACCOUNT'),
                DropdownButtonFormField<int>(
                  initialValue: selectedAccount.account.id,
                  items: [
                    for (final a in accounts)
                      DropdownMenuItem(
                        value: a.account.id,
                        child: Text('${a.account.name} (${a.currency.code})'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _accountId = v),
                ),
                const SizedBox(height: 16),
                const _Caption('CATEGORY'),
                categoriesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (categories) {
                    if (_categoryId == null && categories.isNotEmpty) {
                      _categoryId = categories.first.id;
                    }
                    final valid = categories.any((c) => c.id == _categoryId);
                    return Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: valid ? _categoryId : null,
                            items: [
                              for (final c in categories)
                                DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                            ],
                            onChanged: (v) => setState(() => _categoryId = v),
                            validator: (v) => v == null ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconTile(
                          iconKey: categories
                              .where((c) => c.id == _categoryId)
                              .firstOrNull
                              ?.icon,
                          colorValue: categories
                              .where((c) => c.id == _categoryId)
                              .firstOrNull
                              ?.color,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _Caption(
                  'AMOUNT'
                  '${selectedAccount.currency.subunitName != null ? ' (${selectedAccount.currency.subunitName} = ${selectedAccount.currency.decimalPlaces}dp)' : ''}',
                ),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    hintText: selectedAccount.currency.decimalPlaces == 0
                        ? '0'
                        : '0.${'0' * selectedAccount.currency.decimalPlaces}',
                    prefixText: '${selectedAccount.currency.symbol} ',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final parsed = Money.parse(v, selectedAccount.currency);
                    if (parsed == null) return 'Invalid amount';
                    if (parsed <= 0) return 'Must be greater than zero';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const _Caption('NOTE (OPTIONAL)'),
                TextFormField(controller: _noteController),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        date: _date,
                        onChanged: (d) => setState(
                          () => _date = DateTime(
                            d.year,
                            d.month,
                            d.day,
                            _date.hour,
                            _date.minute,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimeField(
                        date: _date,
                        onChanged: (t) => setState(
                          () => _date = DateTime(
                            _date.year,
                            _date.month,
                            _date.day,
                            t.hour,
                            t.minute,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saving
                      ? null
                      : () => _save(selectedAccount.currency),
                  child: const Text('SAVE'),
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _saving ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: dompetkuhExpenseRed,
                      side: const BorderSide(color: dompetkuhExpenseRed),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('DELETE'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _save(Currency currency) async {
    if (!_formKey.currentState!.validate()) return;
    final amount = Money.parse(_amountController.text, currency)!;
    setState(() => _saving = true);
    final repo = ref.read(transactionRepositoryProvider);

    if (_isEditing) {
      await repo.update(
        widget.transaction!.copyWith(
          accountId: _accountId!,
          categoryId: _categoryId!,
          type: _type,
          amount: amount,
          note: Value(
            _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          ),
          date: _date,
        ),
      );
    } else {
      await repo.create(
        TransactionsCompanion.insert(
          accountId: _accountId!,
          categoryId: _categoryId!,
          type: _type,
          amount: amount,
          note: Value(
            _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          ),
          date: _date,
          createdAt: DateTime.now(),
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
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
    await ref
        .read(transactionRepositoryProvider)
        .delete(widget.transaction!.id);
    if (mounted) Navigator.of(context).pop();
  }
}

class _TypeToggle extends StatelessWidget {
  final String type;
  final ValueChanged<String> onChanged;
  const _TypeToggle({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToggleButton(
            label: 'INCOME',
            selected: type == CategoryType.in_,
            color: dompetkuhIncomeGreen,
            onTap: () => onChanged(CategoryType.in_),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ToggleButton(
            label: 'EXPENSE',
            selected: type == CategoryType.out,
            color: dompetkuhExpenseRed,
            onTap: () => onChanged(CategoryType.out),
          ),
        ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  const _DateField({required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(DateFormat('EEE, d MMM yyyy').format(date)),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final DateTime date;
  final ValueChanged<TimeOfDay> onChanged;
  const _TimeField({required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(date),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.access_time, size: 18),
        ),
        child: Text(DateFormat('HH:mm').format(date)),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  final String text;
  const _Caption(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
