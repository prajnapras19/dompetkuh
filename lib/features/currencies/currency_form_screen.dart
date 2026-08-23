import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/database.dart';
import '../../providers/currency_providers.dart';

/// Create or edit a currency. [currency] null = create.
class CurrencyFormScreen extends ConsumerStatefulWidget {
  final Currency? currency;

  const CurrencyFormScreen({super.key, this.currency});

  @override
  ConsumerState<CurrencyFormScreen> createState() =>
      _CurrencyFormScreenState();
}

class _CurrencyFormScreenState extends ConsumerState<CurrencyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _symbolController;
  late final TextEditingController _subunitController;
  late int _decimalPlaces;
  late bool _symbolBeforeAmount;
  bool _saving = false;

  bool get _isEditing => widget.currency != null;

  @override
  void initState() {
    super.initState();
    final c = widget.currency;
    _codeController = TextEditingController(text: c?.code ?? '');
    _nameController = TextEditingController(text: c?.name ?? '');
    _symbolController = TextEditingController(text: c?.symbol ?? '');
    _subunitController = TextEditingController(text: c?.subunitName ?? '');
    _decimalPlaces = c?.decimalPlaces ?? 2;
    _symbolBeforeAmount = c?.symbolBeforeAmount ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _symbolController.dispose();
    _subunitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Currency' : 'Add Currency'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _Caption('CODE'),
            TextFormField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'e.g. USD'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            const _Caption('NAME'),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: 'e.g. US Dollar'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            const _Caption('SYMBOL'),
            TextFormField(
              controller: _symbolController,
              decoration: const InputDecoration(hintText: 'e.g. \$'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            const _Caption('DECIMAL PLACES'),
            DropdownButtonFormField<int>(
              initialValue: _decimalPlaces,
              items: const [
                DropdownMenuItem(value: 0, child: Text('0 (e.g. IDR, JPY)')),
                DropdownMenuItem(value: 2, child: Text('2 (e.g. USD, EUR)')),
                DropdownMenuItem(value: 3, child: Text('3 (e.g. Gold, grams)')),
              ],
              onChanged: (v) => setState(() => _decimalPlaces = v ?? 2),
            ),
            const SizedBox(height: 16),
            const _Caption('SUBUNIT NAME (OPTIONAL)'),
            TextFormField(
              controller: _subunitController,
              decoration: const InputDecoration(hintText: 'e.g. cent, sen, øre'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Symbol before amount'),
              subtitle: Text(
                _symbolBeforeAmount
                    ? '${_symbolController.text.isEmpty ? "\$" : _symbolController.text} 10'
                    : '10 ${_symbolController.text.isEmpty ? "kr" : _symbolController.text}',
              ),
              value: _symbolBeforeAmount,
              onChanged: (v) => setState(() => _symbolBeforeAmount = v),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(currencyRepositoryProvider);
    final subunit = _subunitController.text.trim();

    if (_isEditing) {
      await repo.update(
        widget.currency!.copyWith(
          code: _codeController.text.trim().toUpperCase(),
          name: _nameController.text.trim(),
          symbol: _symbolController.text.trim(),
          decimalPlaces: _decimalPlaces,
          subunitName: Value(subunit.isEmpty ? null : subunit),
          symbolBeforeAmount: _symbolBeforeAmount,
        ),
      );
    } else {
      await repo.create(
        CurrenciesCompanion.insert(
          code: _codeController.text.trim().toUpperCase(),
          name: _nameController.text.trim(),
          symbol: _symbolController.text.trim(),
          decimalPlaces: _decimalPlaces,
          subunitName: Value(subunit.isEmpty ? null : subunit),
          symbolBeforeAmount: Value(_symbolBeforeAmount),
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
