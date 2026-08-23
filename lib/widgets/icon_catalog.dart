import 'package:flutter/material.dart';

/// Fixed icon set for the icon picker (categories/accounts), matching the
/// reference app's "Pilih Icon" grid. Keys are stored in the DB; the
/// IconData/label lookup lives only here so it can change freely without
/// touching stored data.
class IconCatalogEntry {
  final String key;
  final IconData icon;
  final String label;

  const IconCatalogEntry(this.key, this.icon, this.label);
}

const List<IconCatalogEntry> iconCatalog = [
  IconCatalogEntry('baby', Icons.child_friendly, 'Baby'),
  IconCatalogEntry('bank', Icons.account_balance, 'Bank'),
  IconCatalogEntry('building', Icons.apartment, 'Building'),
  IconCatalogEntry('bus', Icons.directions_bus, 'Bus'),
  IconCatalogEntry('birthday', Icons.cake, 'Birthday'),
  IconCatalogEntry('car', Icons.directions_car, 'Car'),
  IconCatalogEntry('wallet', Icons.account_balance_wallet, 'Wallet'),
  IconCatalogEntry('coffee', Icons.local_cafe, 'Coffee'),
  IconCatalogEntry('drink', Icons.local_bar, 'Drink'),
  IconCatalogEntry('phone', Icons.smartphone, 'Phone'),
  IconCatalogEntry('education', Icons.school, 'Education'),
  IconCatalogEntry('electricity', Icons.bolt, 'Electricity'),
  IconCatalogEntry('lightbulb', Icons.lightbulb, 'Utilities'),
  IconCatalogEntry('gym', Icons.fitness_center, 'Gym'),
  IconCatalogEntry('flight', Icons.flight, 'Flight'),
  IconCatalogEntry('food', Icons.restaurant, 'Food'),
  IconCatalogEntry('fuel', Icons.local_gas_station, 'Fuel'),
  IconCatalogEntry('furniture', Icons.chair, 'Furniture'),
  IconCatalogEntry('electronics', Icons.devices, 'Electronics'),
  IconCatalogEntry('games', Icons.sports_esports, 'Games'),
  IconCatalogEntry('investment', Icons.show_chart, 'Investment'),
  IconCatalogEntry('family', Icons.people, 'Family'),
  IconCatalogEntry('health', Icons.local_hospital, 'Health'),
  IconCatalogEntry('groceries', Icons.kitchen, 'Groceries'),
  IconCatalogEntry('loan', Icons.person_pin, 'Loan'),
  IconCatalogEntry('gift', Icons.favorite, 'Gift'),
  IconCatalogEntry('salary', Icons.attach_money, 'Salary'),
  IconCatalogEntry('motorbike', Icons.two_wheeler, 'Motorbike'),
  IconCatalogEntry('movie', Icons.movie, 'Movie'),
  IconCatalogEntry('card', Icons.credit_card, 'Card'),
  IconCatalogEntry('pet', Icons.pets, 'Pet'),
  IconCatalogEntry('call', Icons.call, 'Call'),
  IconCatalogEntry('shopping', Icons.shopping_bag, 'Shopping'),
  IconCatalogEntry('train', Icons.train, 'Train'),
  IconCatalogEntry('transfer', Icons.swap_horiz, 'Transfer'),
  IconCatalogEntry('gold', Icons.circle, 'Gold'),
  IconCatalogEntry('other', Icons.category, 'Other'),
];

IconData iconForKey(String? key) {
  if (key == null) return Icons.category;
  return iconCatalog
      .firstWhere(
        (e) => e.key == key,
        orElse: () => const IconCatalogEntry('other', Icons.category, 'Other'),
      )
      .icon;
}

/// Curated tile-background palette matching the reference app's icon tiles.
const List<int> iconColorPalette = [
  0xFFE53935, // red
  0xFFFB8C00, // orange
  0xFFFFB300, // amber
  0xFFFDD835, // yellow
  0xFF43A047, // green
  0xFF00897B, // teal
  0xFF00ACC1, // cyan
  0xFF1E88E5, // blue
  0xFF3949AB, // indigo
  0xFF8E24AA, // purple
  0xFFD81B60, // pink
  0xFF6D4C41, // brown
  0xFF757575, // grey
];
