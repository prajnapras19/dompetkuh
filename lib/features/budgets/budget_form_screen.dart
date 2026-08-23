import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../db/database.dart';
import '../../providers/budget_providers.dart';
import '../../providers/currency_providers.dart';
import '../../utils/formatters.dart';
import '../../utils/thousands_input_formatter.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/icon_picker_field.dart';

/// Create or edit a budget tag. [budget] null = create.
///
/// The monthly amount is effective-dated (see BudgetAmounts): saving here
/// always sets the amount starting from the *current* month onward — it
/// never rewrites what earlier months show. Editing "September's amount"
/// specifically (rather than "from now on") isn't exposed in the UI; the
/// current month is the only one editable, matching the reference app's
/// lack of a past-editing concept.
class BudgetFormScreen extends ConsumerStatefulWidget {
  final Budget? budget;

  const BudgetFormScreen({super.key, this.budget});

  @override
  ConsumerState<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends ConsumerState<BudgetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  String? _iconKey;
  int? _colorValue;
  int? _currencyId;
  bool _saving = false;
  bool _amountPrefilled = false;

  static final _thisMonth = DateTime(DateTime.now().year, DateTime.now().month);

  bool get _isEditing => widget.budget != null;

  @override
  void initState() {
    super.initState();
    final b = widget.budget;
    _nameController = TextEditingController(text: b?.name ?? '');
    _amountController = TextEditingController();
    _iconKey = b?.icon ?? 'wallet';
    _colorValue = b?.color ?? 0xFF43A047;
    _currencyId = b?.currencyId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currenciesAsync = ref.watch(allCurrenciesProvider);
    final currentAmountAsync = _isEditing
        ? ref.watch(
            budgetAmountForMonthProvider((
              budgetId: widget.budget!.id,
              month: _thisMonth,
            )),
          )
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Budget' : 'Add Budget')),
      body: currenciesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allCurrencies) {
          final currencies = allCurrencies
              .where(
                (c) => c.archivedAt == null || c.id == widget.budget?.currencyId,
              )
              .toList();
          if (_currencyId == null && currencies.isNotEmpty) {
            _currencyId = currencies.first.id;
          }
          final currency = currencies.firstWhere(
            (c) => c.id == _currencyId,
            orElse: () => currencies.first,
          );

          if (!_amountPrefilled && currentAmountAsync != null) {
            currentAmountAsync.whenData((amount) {
              if (!_amountPrefilled) {
                _amountPrefilled = true;
                _amountController.text = Money.formatEditable(
                  amount ?? 0,
                  currency,
                );
              }
            });
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                Center(
                  child: IconPickerField(
                    iconKey: _iconKey,
                    colorValue: _colorValue,
                    onChanged: (entry) => setState(() {
                      _iconKey = entry.key;
                      _colorValue = entry.defaultColor;
                    }),
                  ),
                ),
                const SizedBox(height: 24),
                const FormCaption('NAME'),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(hintText: 'e.g. Food'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                const FormCaption('CURRENCY'),
                DropdownButtonFormField<int>(
                  initialValue: currency.id,
                  items: [
                    for (final c in currencies)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.code} — ${c.name}'),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _currencyId = v;
                    _amountController.clear();
                  }),
                ),
                const SizedBox(height: 16),
                FormCaption(
                  'MONTHLY AMOUNT (from ${DateFormat('MMMM yyyy').format(_thisMonth)})',
                ),
                if (currency.decimalPlaces > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      amountDecimalHint(currency),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                if (_isEditing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      "This changes the amount going forward — earlier "
                      "months keep showing whatever was set at the time.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [ThousandsInputFormatter()],
                  decoration: InputDecoration(
                    hintText: currency.decimalPlaces == 0
                        ? '0'
                        : '0.${'0' * currency.decimalPlaces}',
                    prefixText: '${currency.symbol} ',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final parsed = Money.parse(v, currency);
                    if (parsed == null) return 'Invalid amount';
                    if (parsed < 0) return 'Must be zero or more';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : () => _save(currency),
                  child: const Text('SAVE'),
                ),
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
    final repo = ref.read(budgetRepositoryProvider);

    int budgetId;
    if (_isEditing) {
      budgetId = widget.budget!.id;
      await repo.update(
        widget.budget!.copyWith(
          name: _nameController.text.trim(),
          icon: Value(_iconKey),
          color: Value(_colorValue),
          currencyId: Value(_currencyId),
        ),
      );
    } else {
      budgetId = await repo.create(
        BudgetsCompanion.insert(
          name: _nameController.text.trim(),
          icon: Value(_iconKey),
          color: Value(_colorValue),
          currencyId: Value(_currencyId),
        ),
      );
    }
    await repo.setAmountEffectiveFrom(budgetId, _thisMonth, amount);

    if (mounted) Navigator.of(context).pop();
  }
}
