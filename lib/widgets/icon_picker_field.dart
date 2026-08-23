import 'package:flutter/material.dart';

import '../features/shared/icon_picker_screen.dart';
import 'icon_catalog.dart';
import 'icon_tile.dart';

/// Captioned field + icon-tile swatch button, matching the reference app's
/// KATEGORI/REKENING field style where an icon swatch sits beside the input.
/// Tapping the swatch opens the icon grid; picking one updates both fields.
class IconPickerField extends StatelessWidget {
  final String? iconKey;
  final int? colorValue;
  final ValueChanged<IconCatalogEntry> onChanged;

  const IconPickerField({
    super.key,
    required this.iconKey,
    required this.colorValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final entry = await Navigator.of(context).push<IconCatalogEntry>(
          MaterialPageRoute(builder: (_) => const IconPickerScreen()),
        );
        if (entry != null) onChanged(entry);
      },
      child: IconTile(iconKey: iconKey, colorValue: colorValue, size: 48),
    );
  }
}
