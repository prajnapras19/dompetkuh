import 'package:flutter/services.dart';

/// Live-inserts thousands-grouping commas into the integer part of an
/// amount field as the user types (e.g. typing "50000" shows "50,000"),
/// leaving any fractional part after "." untouched. Money.parse already
/// strips commas back out, so this is purely a typing aid.
class ThousandsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final parts = newValue.text.split('.');
    if (parts.length > 2) return oldValue;

    final rawDigits = parts[0].replaceAll(RegExp(r'[^\d]'), '');
    final grouped = _group(rawDigits);
    final newText = parts.length == 2 ? '$grouped.${parts[1]}' : grouped;

    if (newText == newValue.text) return newValue;

    // Keep the cursor the same distance from the end of the text — simple
    // and correct for the common case of typing/deleting at the end.
    final distanceFromEnd = newValue.text.length - newValue.selection.end;
    final newOffset = (newText.length - distanceFromEnd).clamp(
      0,
      newText.length,
    );

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  String _group(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
