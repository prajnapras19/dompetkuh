import 'package:flutter/material.dart';

import '../db/database.dart';
import '../theme/colors.dart';
import '../utils/formatters.dart';

/// Right-aligned amount text, colored green/red for in/out, or plain for
/// account balances (no sign implied).
class MoneyText extends StatelessWidget {
  final int minorUnits;
  final Currency currency;

  /// 'in' -> green with a leading '+', 'out' -> red with a leading '-',
  /// null -> plain (account balances, totals).
  final String? signType;
  final TextStyle? style;

  const MoneyText({
    super.key,
    required this.minorUnits,
    required this.currency,
    this.signType,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = Money.formatDisplay(minorUnits, currency);
    final Color? color = switch (signType) {
      'in' => dompetkuhIncomeGreen,
      'out' => dompetkuhExpenseRed,
      _ => null,
    };
    final prefix = switch (signType) {
      'in' => '+',
      'out' => '-',
      _ => '',
    };
    return Text(
      '$prefix$formatted',
      style: (style ?? const TextStyle()).copyWith(color: color),
    );
  }
}
