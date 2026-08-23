import 'package:intl/intl.dart';

import '../db/database.dart';

/// Converts between a currency's minor-unit integer storage (see
/// currencies_table.dart) and the decimal string a user types/sees, using
/// that currency's own `decimalPlaces`. This is the one place amount
/// parsing/formatting happens, so every form and list stays consistent.
class Money {
  Money._();

  /// Parses user input (e.g. "12.50", "15.000" with grouping, "1,250") into
  /// the integer minor-unit value for [currency]. Returns null if the input
  /// isn't a valid non-negative number, or has more fractional digits than
  /// the currency supports.
  static int? parse(String input, Currency currency) {
    final cleaned = input.trim().replaceAll(RegExp(r'[,\s]'), '');
    if (cleaned.isEmpty) return null;

    final parts = cleaned.split('.');
    if (parts.length > 2) return null;

    final wholePart = parts[0].isEmpty ? '0' : parts[0];
    final fractionPart = parts.length == 2 ? parts[1] : '';

    if (!RegExp(r'^\d+$').hasMatch(wholePart)) return null;
    if (fractionPart.isNotEmpty && !RegExp(r'^\d+$').hasMatch(fractionPart)) {
      return null;
    }
    if (fractionPart.length > currency.decimalPlaces) return null;

    final whole = int.parse(wholePart);
    final scale = _scale(currency.decimalPlaces);
    final paddedFraction = fractionPart.padRight(currency.decimalPlaces, '0');
    final fraction = paddedFraction.isEmpty ? 0 : int.parse(paddedFraction);

    return whole * scale + fraction;
  }

  /// Formats a stored minor-unit integer back into a plain decimal string
  /// suitable for editing (e.g. 1250 -> "12.50" for a 2dp currency, or
  /// 15000 -> "15000" for a 0dp currency). No grouping/symbol — use
  /// [formatDisplay] for that.
  static String formatEditable(int minorUnits, Currency currency) {
    final scale = _scale(currency.decimalPlaces);
    final whole = minorUnits ~/ scale;
    if (currency.decimalPlaces == 0) return whole.toString();
    final fraction = (minorUnits % scale).abs();
    return '$whole.${fraction.toString().padLeft(currency.decimalPlaces, '0')}';
  }

  /// Formats a stored minor-unit integer for display with thousands
  /// grouping and the currency's symbol in the correct position, e.g.
  /// "Rp 15.000" or "12.50 kr" or "1.250 g". Kept as pure integer
  /// arithmetic (no float reconstruction) so large amounts stay exact.
  static String formatDisplay(int minorUnits, Currency currency) {
    final scale = _scale(currency.decimalPlaces);
    final whole = minorUnits ~/ scale;
    final fraction = (minorUnits % scale).abs();

    final groupedWhole = NumberFormat('#,##0').format(whole);
    final number = currency.decimalPlaces == 0
        ? groupedWhole
        : '$groupedWhole.${fraction.toString().padLeft(currency.decimalPlaces, '0')}';

    return currency.symbolBeforeAmount
        ? '${currency.symbol} $number'
        : '$number ${currency.symbol}';
  }

  static int _scale(int decimalPlaces) {
    var scale = 1;
    for (var i = 0; i < decimalPlaces; i++) {
      scale *= 10;
    }
    return scale;
  }
}
