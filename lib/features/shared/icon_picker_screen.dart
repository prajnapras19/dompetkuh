import 'package:flutter/material.dart';

import '../../widgets/icon_catalog.dart';

/// Grid of colorful icon tiles, matching the reference app's "Pilih Icon"
/// screen. Picking one returns its IconCatalogEntry (icon key + color) via
/// Navigator.pop.
class IconPickerScreen extends StatelessWidget {
  const IconPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Icon')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: iconCatalog.length,
        itemBuilder: (context, index) {
          final entry = iconCatalog[index];
          return InkWell(
            onTap: () => Navigator.of(context).pop(entry),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                color: Color(entry.defaultColor),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(entry.icon, color: Colors.white),
            ),
          );
        },
      ),
    );
  }
}
