import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/database.dart';
import '../../models/account_summary.dart';
import '../../providers/account_providers.dart';
import '../../providers/budget_providers.dart';
import '../../providers/category_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../theme/colors.dart';
import '../../utils/formatters.dart';
import '../../utils/thousands_input_formatter.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/picker_form_field.dart';
import '../accounts/account_picker_screen.dart';
import '../budgets/budget_picker_screen.dart';
import '../categories/category_picker_screen.dart';

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
  int? _budgetId;
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
    _budgetId = t?.budgetId;
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
          final selectedAccount = accounts
              .where((a) => a.account.id == _accountId)
              .firstOrNull;

          if (_amountController.text.isEmpty &&
              widget.transaction != null &&
              selectedAccount != null) {
            _amountController.text = Money.formatEditable(
              widget.transaction!.amount,
              selectedAccount.currency,
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              // Extra bottom padding so the last button (DELETE, in edit
              // mode) isn't covered by the gesture-nav bar on devices
              // without a dedicated nav bar area.
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                _TypeToggle(
                  type: _type,
                  onChanged: (t) => setState(() {
                    _type = t;
                    _categoryId = null;
                    _budgetId = null;
                  }),
                ),
                const SizedBox(height: 20),
                const FormCaption('ACCOUNT'),
                PickerFormField<int>(
                  key: ValueKey(_accountId),
                  value: _accountId,
                  placeholder: 'Select account',
                  labelBuilder: (id) {
                    final a = accounts.where((a) => a.account.id == id).first;
                    return '${a.account.name} (${a.currency.code})';
                  },
                  leadingBuilder: (id) {
                    final a = accounts.where((a) => a.account.id == id).first;
                    return IconTile(
                      iconKey: a.account.icon,
                      colorValue: a.account.color,
                      size: 32,
                    );
                  },
                  onTap: (context) => Navigator.of(context).push<int>(
                    MaterialPageRoute(
                      builder: (_) => const AccountPickerScreen(),
                    ),
                  ),
                  onChanged: (v) => setState(() {
                    _accountId = v;
                    // A budget only applies within its own currency — clear
                    // it so the Budget dropdown never holds a value that's
                    // no longer in its (now re-filtered) item list.
                    _budgetId = null;
                  }),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                const FormCaption('CATEGORY'),
                categoriesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (categories) {
                    final valid = categories.any((c) => c.id == _categoryId);
                    if (!valid) _categoryId = null;
                    return PickerFormField<int>(
                      key: ValueKey(_categoryId),
                      value: _categoryId,
                      placeholder: 'Select category',
                      labelBuilder: (id) =>
                          categories.where((c) => c.id == id).first.name,
                      leadingBuilder: (id) {
                        final c = categories.where((c) => c.id == id).first;
                        return IconTile(
                          iconKey: c.icon,
                          colorValue: c.color,
                          size: 32,
                        );
                      },
                      onTap: (context) => Navigator.of(context).push<int>(
                        MaterialPageRoute(
                          builder: (_) => CategoryPickerScreen(type: _type),
                        ),
                      ),
                      onChanged: (v) => setState(() => _categoryId = v),
                      validator: (v) => v == null ? 'Required' : null,
                    );
                  },
                ),
                // Budgets are an expense-tracking concept (spent-vs-
                // allocated) — the field only makes sense for Expense, and
                // only once an account (and thus a currency) is chosen.
                if (_type == CategoryType.out && selectedAccount != null) ...[
                  const SizedBox(height: 16),
                  const FormCaption('BUDGET (OPTIONAL)'),
                  PickerFormField<int>(
                    key: ValueKey('${_accountId}_$_budgetId'),
                    value: _budgetId ?? noneBudgetId,
                    placeholder: 'None',
                    labelBuilder: (id) => id == noneBudgetId
                        ? 'None'
                        : ref
                              .read(activeBudgetsProvider)
                              .value!
                              .firstWhere((b) => b.id == id)
                              .name,
                    leadingBuilder: (id) {
                      if (id == noneBudgetId) return null;
                      final b = ref
                          .read(activeBudgetsProvider)
                          .value!
                          .firstWhere((b) => b.id == id);
                      return IconTile(
                        iconKey: b.icon,
                        colorValue: b.color,
                        size: 32,
                      );
                    },
                    onTap: (context) => Navigator.of(context).push<int>(
                      MaterialPageRoute(
                        builder: (_) => BudgetPickerScreen(
                          currencyId: selectedAccount.currency.id,
                        ),
                      ),
                    ),
                    onChanged: (v) => setState(
                      () => _budgetId = v == noneBudgetId ? null : v,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FormCaption('AMOUNT'),
                if (selectedAccount != null &&
                    selectedAccount.currency.decimalPlaces > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      amountDecimalHint(selectedAccount.currency),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [ThousandsInputFormatter()],
                  decoration: InputDecoration(
                    hintText: selectedAccount == null
                        ? '0'
                        : selectedAccount.currency.decimalPlaces == 0
                        ? '0'
                        : '0.${'0' * selectedAccount.currency.decimalPlaces}',
                    prefixText: selectedAccount == null
                        ? null
                        : '${selectedAccount.currency.symbol} ',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (selectedAccount == null) return null;
                    final parsed = Money.parse(v, selectedAccount.currency);
                    if (parsed == null) return 'Invalid amount';
                    if (parsed <= 0) return 'Must be greater than zero';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const FormCaption('NOTE (OPTIONAL)'),
                TextFormField(controller: _noteController),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DateField(
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
                      child: TimeField(
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
                  onPressed: _saving ? null : () => _save(accounts),
                  child: const Text('SAVE'),
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _saving ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: dompetkuhExpenseRed,
                      side: const BorderSide(color: dompetkuhExpenseRed),
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

  Future<void> _save(List<AccountSummary> accounts) async {
    if (!_formKey.currentState!.validate()) return;
    // The Account field's own validator guarantees _accountId is set by now.
    final currency = accounts
        .firstWhere((a) => a.account.id == _accountId)
        .currency;
    final amount = Money.parse(_amountController.text, currency)!;
    setState(() => _saving = true);
    final repo = ref.read(transactionRepositoryProvider);

    if (_isEditing) {
      await repo.update(
        widget.transaction!.copyWith(
          accountId: _accountId!,
          categoryId: _categoryId!,
          budgetId: Value(_budgetId),
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
          budgetId: Value(_budgetId),
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
