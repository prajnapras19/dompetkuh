import 'package:flutter/material.dart';

/// A read-only, tappable form field that pushes a full-page picker (via
/// [onTap]) and takes whatever it returns — matching the reference app's
/// Pilih Kategori/Rekening screens instead of a dropdown. Always construct
/// with `key: ValueKey(value)`: [FormField] does not re-read [initialValue]
/// after first build (same gotcha as `DropdownButtonFormField` elsewhere in
/// this codebase), so a value change from outside this field (e.g. an
/// account swap resetting the other side of a Transfer) needs a fresh key
/// to be picked up.
class PickerFormField<T> extends FormField<T> {
  PickerFormField({
    super.key,
    required T? value,
    required String placeholder,
    required String Function(T value) labelBuilder,
    Widget? Function(T value)? leadingBuilder,
    required Future<T?> Function(BuildContext context) onTap,
    required ValueChanged<T> onChanged,
    super.validator,
  }) : super(
         initialValue: value,
         builder: (state) {
           final current = state.value;
           final leading = current == null
               ? null
               : leadingBuilder?.call(current);
           return InkWell(
             borderRadius: BorderRadius.circular(8),
             onTap: () async {
               final result = await onTap(state.context);
               if (result != null) onChanged(result);
             },
             child: InputDecorator(
               decoration: InputDecoration(errorText: state.errorText),
               child: Row(
                 children: [
                   if (leading != null) ...[
                     leading,
                     const SizedBox(width: 12),
                   ],
                   Expanded(
                     child: Text(
                       current == null ? placeholder : labelBuilder(current),
                       style: TextStyle(
                         color: current == null
                             ? Theme.of(state.context).hintColor
                             : null,
                       ),
                     ),
                   ),
                   const Icon(Icons.chevron_right, color: Colors.grey),
                 ],
               ),
             ),
           );
         },
       );
}
