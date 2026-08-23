import 'package:flutter/material.dart';

import 'icon_catalog.dart';

/// The colorful rounded-square icon tile used throughout the reference app
/// for categories and accounts (e.g. red "Food" fork/knife, blue "Bank").
class IconTile extends StatelessWidget {
  final String? iconKey;
  final int? colorValue;
  final double size;

  const IconTile({
    super.key,
    required this.iconKey,
    required this.colorValue,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorValue != null ? Color(colorValue!) : Colors.blueGrey;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Icon(iconForKey(iconKey), color: Colors.white, size: size * 0.55),
    );
  }
}
