import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/database.dart';
import '../../models/account_summary.dart';
import '../../providers/account_providers.dart';
import '../../providers/transfer_providers.dart';
import '../../theme/colors.dart';
import '../../utils/formatters.dart';
import '../../utils/thousands_input_formatter.dart';
import '../../widgets/form_helpers.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/picker_form_field.dart';
import '../accounts/account_picker_screen.dart';

/// Add or edit a transfer between two accounts. Same-currency transfers
/// auto-fill "amount received" to match "amount sent" (still editable, e.g.
/// for a fee); cross-currency transfers require both entered manually.
/// [initialFromAccountId] preselects the source account (e.g. launched from
/// Account Detail); [transfer] non-null means edit.
class AddTransferScreen extends ConsumerStatefulWidget {
  final int? initialFromAccountId;
  final Transfer? transfer;

  const AddTransferScreen({
    super.key,
    this.initialFromAccountId,
    this.transfer,
  });

  @override
  ConsumerState<AddTransferScreen> createState() => _AddTransferScreenState();
}

class _AddTransferScreenState extends ConsumerState<AddTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fromAmountController;
  late final TextEditingController _toAmountController;
  late final TextEditingController _noteController;

  int? _fromAccountId;
  int? _toAccountId;
  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _toAmountEditedManually = false;

  bool get _isEditing => widget.transfer != null;

  @override
  void initState() {
    super.initState();
    final t = widget.transfer;
    _fromAccountId = t?.fromAccountId ?? widget.initialFromAccountId;
    _toAccountId = t?.toAccountId;
    _date = t?.date ?? DateTime.now();
    _fromAmountController = TextEditingController();
    _toAmountController = TextEditingController();
    _noteController = TextEditingController(text: t?.note ?? '');
    if (_isEditing) _toAmountEditedManually = true;
  }

  @override
  void dispose() {
    _fromAmountController.dispose();
    _toAmountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountSummariesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Transfer' : 'Transfer')),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (accounts) {
          if (accounts.length < 2) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'You need at least two accounts to make a transfer.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final fromAccount = accounts
              .where((a) => a.account.id == _fromAccountId)
              .firstOrNull;
          final toAccount = accounts
              .where((a) => a.account.id == _toAccountId)
              .firstOrNull;
          final sameCurrency =
              fromAccount != null &&
              toAccount != null &&
              fromAccount.currency.id == toAccount.currency.id;

          if (_fromAmountController.text.isEmpty &&
              widget.transfer != null &&
              fromAccount != null &&
              toAccount != null) {
            _fromAmountController.text = Money.formatEditable(
              widget.transfer!.fromAmount,
              fromAccount.currency,
            );
            _toAmountController.text = Money.formatEditable(
              widget.transfer!.toAmount,
              toAccount.currency,
            );
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
                const FormCaption('FROM ACCOUNT'),
                PickerFormField<int>(
                  key: ValueKey('from_$_fromAccountId'),
                  value: _fromAccountId,
                  placeholder: 'Select account',
                  labelBuilder: (id) =>
                      accounts.where((a) => a.account.id == id).first.account.name,
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
                    _fromAccountId = v;
                    if (v == _toAccountId) _toAccountId = null;
                  }),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                const FormCaption('TO ACCOUNT'),
                PickerFormField<int>(
                  key: ValueKey('to_${_toAccountId}_$_fromAccountId'),
                  value: _toAccountId,
                  placeholder: 'Select account',
                  labelBuilder: (id) =>
                      accounts.where((a) => a.account.id == id).first.account.name,
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
                      builder: (_) =>
                          AccountPickerScreen(excludeId: _fromAccountId),
                    ),
                  ),
                  onChanged: (v) => setState(() => _toAccountId = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                FormCaption(
                  'AMOUNT SENT'
                  '${fromAccount == null ? '' : ' (${fromAccount.currency.code})'}',
                ),
                if (fromAccount != null && fromAccount.currency.decimalPlaces > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      amountDecimalHint(fromAccount.currency),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                TextFormField(
                  controller: _fromAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [ThousandsInputFormatter()],
                  decoration: InputDecoration(
                    hintText: fromAccount == null
                        ? '0'
                        : fromAccount.currency.decimalPlaces == 0
                        ? '0'
                        : '0.${'0' * fromAccount.currency.decimalPlaces}',
                    prefixText: fromAccount == null
                        ? null
                        : '${fromAccount.currency.symbol} ',
                  ),
                  onChanged: (v) {
                    if (sameCurrency && !_toAmountEditedManually) {
                      setState(() => _toAmountController.text = v);
                    }
                  },
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (fromAccount == null) return null;
                    final parsed = Money.parse(v, fromAccount.currency);
                    if (parsed == null) return 'Invalid amount';
                    if (parsed <= 0) return 'Must be greater than zero';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                FormCaption(
                  'AMOUNT RECEIVED'
                  '${toAccount == null ? '' : ' (${toAccount.currency.code})'}',
                ),
                if (toAccount != null && toAccount.currency.decimalPlaces > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      amountDecimalHint(toAccount.currency),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                TextFormField(
                  controller: _toAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [ThousandsInputFormatter()],
                  decoration: InputDecoration(
                    hintText: toAccount == null
                        ? '0'
                        : toAccount.currency.decimalPlaces == 0
                        ? '0'
                        : '0.${'0' * toAccount.currency.decimalPlaces}',
                    prefixText: toAccount == null
                        ? null
                        : '${toAccount.currency.symbol} ',
                  ),
                  onChanged: (_) =>
                      setState(() => _toAmountEditedManually = true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (toAccount == null) return null;
                    final parsed = Money.parse(v, toAccount.currency);
                    if (parsed == null) return 'Invalid amount';
                    if (parsed <= 0) return 'Must be greater than zero';
                    return null;
                  },
                ),
                if (!sameCurrency && fromAccount != null && toAccount != null)
                  _RateHint(
                    from: fromAccount,
                    to: toAccount,
                    fromText: _fromAmountController.text,
                    toText: _toAmountController.text,
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
    // The account fields' own validators guarantee both ids are set by now.
    final fromCurrency = accounts
        .firstWhere((a) => a.account.id == _fromAccountId)
        .currency;
    final toCurrency = accounts
        .firstWhere((a) => a.account.id == _toAccountId)
        .currency;
    final fromAmount = Money.parse(_fromAmountController.text, fromCurrency)!;
    final toAmount = Money.parse(_toAmountController.text, toCurrency)!;
    setState(() => _saving = true);
    final repo = ref.read(transferRepositoryProvider);
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();

    if (_isEditing) {
      await repo.update(
        widget.transfer!.copyWith(
          fromAccountId: _fromAccountId!,
          toAccountId: _toAccountId!,
          fromAmount: fromAmount,
          toAmount: toAmount,
          note: Value(note),
          date: _date,
        ),
      );
    } else {
      await repo.create(
        TransfersCompanion.insert(
          fromAccountId: _fromAccountId!,
          toAccountId: _toAccountId!,
          fromAmount: fromAmount,
          toAmount: toAmount,
          note: Value(note),
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
        title: const Text('Delete transfer?'),
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
    await ref.read(transferRepositoryProvider).delete(widget.transfer!.id);
    if (mounted) Navigator.of(context).pop();
  }
}

class _RateHint extends StatelessWidget {
  final AccountSummary from;
  final AccountSummary to;
  final String fromText;
  final String toText;

  const _RateHint({
    required this.from,
    required this.to,
    required this.fromText,
    required this.toText,
  });

  @override
  Widget build(BuildContext context) {
    final fromAmount = Money.parse(fromText, from.currency);
    final toAmount = Money.parse(toText, to.currency);
    if (fromAmount == null || toAmount == null || fromAmount == 0) {
      return const SizedBox.shrink();
    }
    final fromScale = _scale(from.currency.decimalPlaces);
    final toScale = _scale(to.currency.decimalPlaces);
    final rate = (toAmount / toScale) / (fromAmount / fromScale);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Rate: 1 ${from.currency.code} = ${rate.toStringAsFixed(4)} ${to.currency.code}',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }

  int _scale(int decimalPlaces) {
    var scale = 1;
    for (var i = 0; i < decimalPlaces; i++) {
      scale *= 10;
    }
    return scale;
  }
}
