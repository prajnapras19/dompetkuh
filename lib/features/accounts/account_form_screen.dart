import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/database.dart';
import '../../providers/account_providers.dart';
import '../../providers/currency_providers.dart';
import '../../utils/formatters.dart';
import '../../widgets/icon_picker_field.dart';

/// Create or edit an account. [account] null = create.
class AccountFormScreen extends ConsumerStatefulWidget {
  final Account? account;

  const AccountFormScreen({super.key, this.account});

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;

  String? _iconKey;
  int? _colorValue;
  int? _currencyId;
  bool _locked = false;
  bool _saving = false;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _nameController = TextEditingController(text: account?.name ?? '');
    _balanceController = TextEditingController();
    _iconKey = account?.icon ?? 'wallet';
    _colorValue = account?.color ?? 0xFF43A047;
    _currencyId = account?.currencyId;

    if (_isEditing) {
      ref.read(accountRepositoryProvider).hasEntries(account!.id).then((
        hasEntries,
      ) {
        if (mounted) setState(() => _locked = hasEntries);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // All (not just active) currencies, so editing an account whose currency
    // was since archived still shows a valid dropdown selection.
    final currenciesAsync = ref.watch(allCurrenciesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Account' : 'Add Account')),
      body: currenciesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allCurrencies) {
          final currencies = allCurrencies
              .where(
                (c) =>
                    c.archivedAt == null || c.id == widget.account?.currencyId,
              )
              .toList();
          if (_currencyId == null && currencies.isNotEmpty) {
            _currencyId = currencies.first.id;
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
                const _Caption('NAME'),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(hintText: 'e.g. BCA Savings'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                const _Caption('CURRENCY'),
                DropdownButtonFormField<int>(
                  initialValue: _currencyId,
                  items: [
                    for (final c in currencies)
                      DropdownMenuItem(value: c.id, child: Text('${c.code} — ${c.name}')),
                  ],
                  onChanged: _locked
                      ? null
                      : (v) => setState(() => _currencyId = v),
                ),
                if (_locked)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Currency is locked because this account already has transactions.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                if (!_isEditing) ...[
                  const SizedBox(height: 16),
                  const _Caption('INITIAL BALANCE'),
                  TextFormField(
                    controller: _balanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(hintText: '0'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final currency = currencies.firstWhere(
                        (c) => c.id == _currencyId,
                      );
                      return Money.parse(v, currency) == null
                          ? 'Invalid amount'
                          : null;
                    },
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saving ? null : () => _save(currencies),
                  child: const Text('SAVE'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _save(List<Currency> currencies) async {
    if (!_formKey.currentState!.validate()) return;
    if (_currencyId == null) return;

    setState(() => _saving = true);
    final repo = ref.read(accountRepositoryProvider);
    final currency = currencies.firstWhere((c) => c.id == _currencyId);
    final initialBalance = _balanceController.text.trim().isEmpty
        ? 0
        : Money.parse(_balanceController.text, currency) ?? 0;

    if (_isEditing) {
      await repo.update(
        widget.account!.copyWith(
          name: _nameController.text.trim(),
          icon: Value(_iconKey),
          color: Value(_colorValue),
          currencyId: _locked ? widget.account!.currencyId : _currencyId!,
        ),
      );
    } else {
      await repo.create(
        AccountsCompanion.insert(
          name: _nameController.text.trim(),
          icon: Value(_iconKey),
          color: Value(_colorValue),
          currencyId: _currencyId!,
          initialBalance: Value(initialBalance),
          createdAt: DateTime.now(),
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
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
