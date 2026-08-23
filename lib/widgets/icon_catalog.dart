import 'package:flutter/material.dart';

/// Fixed icon set for the icon picker (categories/accounts), matching the
/// reference app's "Pilih Icon" grid: each icon has a fixed default tile
/// color, so picking an icon sets both icon+color together in one tap.
/// Keys/colors are what gets stored in the DB; the IconData lookup lives
/// only here so the visual mapping can change independently of stored data.
class IconCatalogEntry {
  final String key;
  final IconData icon;
  final String label;
  final int defaultColor;

  const IconCatalogEntry(this.key, this.icon, this.label, this.defaultColor);
}

const List<IconCatalogEntry> iconCatalog = [
  IconCatalogEntry('baby', Icons.child_friendly, 'Baby', 0xFFD81B60),
  IconCatalogEntry('bank', Icons.account_balance, 'Bank', 0xFF1E88E5),
  IconCatalogEntry('building', Icons.apartment, 'Building', 0xFF00897B),
  IconCatalogEntry('bus', Icons.directions_bus, 'Bus', 0xFFE53935),
  IconCatalogEntry('birthday', Icons.cake, 'Birthday', 0xFFE53935),
  IconCatalogEntry('car', Icons.directions_car, 'Car', 0xFF1E88E5),
  IconCatalogEntry('wallet', Icons.account_balance_wallet, 'Wallet', 0xFF43A047),
  IconCatalogEntry('coffee', Icons.local_cafe, 'Coffee', 0xFF6D4C41),
  IconCatalogEntry('drink', Icons.local_bar, 'Drink', 0xFF00ACC1),
  IconCatalogEntry('phone', Icons.smartphone, 'Phone', 0xFFFB8C00),
  IconCatalogEntry('education', Icons.school, 'Education', 0xFF757575),
  IconCatalogEntry('electricity', Icons.bolt, 'Electricity', 0xFFFDD835),
  IconCatalogEntry('lightbulb', Icons.lightbulb, 'Utilities', 0xFFFFB300),
  IconCatalogEntry('gym', Icons.fitness_center, 'Gym', 0xFF424242),
  IconCatalogEntry('flight', Icons.flight, 'Flight', 0xFF8E24AA),
  IconCatalogEntry('food', Icons.restaurant, 'Food', 0xFFE53935),
  IconCatalogEntry('fuel', Icons.local_gas_station, 'Fuel', 0xFFFB8C00),
  IconCatalogEntry('furniture', Icons.chair, 'Furniture', 0xFFE53935),
  IconCatalogEntry('electronics', Icons.devices, 'Electronics', 0xFF1E88E5),
  IconCatalogEntry('games', Icons.sports_esports, 'Games', 0xFF3949AB),
  IconCatalogEntry('investment', Icons.show_chart, 'Investment', 0xFF43A047),
  IconCatalogEntry('family', Icons.people, 'Family', 0xFF8E24AA),
  IconCatalogEntry('health', Icons.local_hospital, 'Health', 0xFF43A047),
  IconCatalogEntry('groceries', Icons.kitchen, 'Groceries', 0xFF7CB342),
  IconCatalogEntry('loan', Icons.person_pin, 'Loan', 0xFFFB8C00),
  IconCatalogEntry('gift', Icons.favorite, 'Gift', 0xFFD81B60),
  IconCatalogEntry('salary', Icons.attach_money, 'Salary', 0xFF43A047),
  IconCatalogEntry('motorbike', Icons.two_wheeler, 'Motorbike', 0xFF424242),
  IconCatalogEntry('movie', Icons.movie, 'Movie', 0xFF8E24AA),
  IconCatalogEntry('card', Icons.credit_card, 'Card', 0xFF1E88E5),
  IconCatalogEntry('pet', Icons.pets, 'Pet', 0xFF6D4C41),
  IconCatalogEntry('call', Icons.call, 'Call', 0xFFFB8C00),
  IconCatalogEntry('shopping', Icons.shopping_bag, 'Shopping', 0xFFFB8C00),
  IconCatalogEntry('train', Icons.train, 'Train', 0xFF00897B),
  IconCatalogEntry('transfer', Icons.swap_horiz, 'Transfer', 0xFF757575),
  IconCatalogEntry('gold', Icons.circle, 'Gold', 0xFFFFB300),
  IconCatalogEntry('other', Icons.category, 'Other', 0xFF757575),
];

IconCatalogEntry catalogEntryForKey(String? key) {
  return iconCatalog.firstWhere(
    (e) => e.key == key,
    orElse: () => iconCatalog.last,
  );
}

IconData iconForKey(String? key) {
  if (key == null) return Icons.category;
  return catalogEntryForKey(key).icon;
}
