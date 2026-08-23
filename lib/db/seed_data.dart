import 'package:drift/drift.dart';

import '../widgets/icon_catalog.dart';
import 'database.dart';

/// Preset currencies seeded on first DB creation. IDR first as the home
/// currency for an Indonesia-based user; amounts are always stored as
/// integers in `decimalPlaces`-precision minor units (see currencies_table).
final List<CurrenciesCompanion> presetCurrencies = [
  _currency('IDR', 'Indonesian Rupiah', 'Rp', 0, null, true),
  _currency('USD', 'US Dollar', '\$', 2, 'cent', true),
  _currency('EUR', 'Euro', '€', 2, 'cent', true),
  _currency('SGD', 'Singapore Dollar', 'S\$', 2, 'cent', true),
  _currency('JPY', 'Japanese Yen', '¥', 0, null, true),
  _currency('MYR', 'Malaysian Ringgit', 'RM', 2, 'sen', true),
  _currency('AUD', 'Australian Dollar', 'A\$', 2, 'cent', true),
  _currency('GBP', 'British Pound', '£', 2, 'penny', true),
  _currency('CNY', 'Chinese Yuan', '¥', 2, 'fen', true),
  _currency('SAR', 'Saudi Riyal', 'ر.س', 2, 'halala', false),
  _currency('NOK', 'Norwegian Krone', 'kr', 2, 'øre', false),
  _currency('SEK', 'Swedish Krona', 'kr', 2, 'öre', false),
  _currency('DKK', 'Danish Krone', 'kr', 2, 'øre', false),
  _currency('XAUG', 'Gold', 'g', 3, null, false),
];

CurrenciesCompanion _currency(
  String code,
  String name,
  String symbol,
  int decimalPlaces,
  String? subunitName,
  bool symbolBeforeAmount,
) {
  return CurrenciesCompanion.insert(
    code: code,
    name: name,
    symbol: symbol,
    decimalPlaces: decimalPlaces,
    subunitName: Value(subunitName),
    symbolBeforeAmount: Value(symbolBeforeAmount),
    isPreset: const Value(true),
  );
}

/// Preset categories seeded on first DB creation, split by in/out type.
/// Tile color always follows the icon's default color (see icon_catalog.dart)
/// so there's one source of truth for the icon<->color mapping.
final List<CategoriesCompanion> presetCategories = [
  _category('Salary', CategoryType.in_, 'salary'),
  _category('Gift', CategoryType.in_, 'gift'),
  _category('Other Income', CategoryType.in_, 'other'),
  _category('Food', CategoryType.out, 'food'),
  _category('Groceries', CategoryType.out, 'groceries'),
  _category('Transport', CategoryType.out, 'car'),
  _category('Shopping', CategoryType.out, 'shopping'),
  _category('Bills', CategoryType.out, 'electricity'),
  _category('Health', CategoryType.out, 'health'),
  _category('Entertainment', CategoryType.out, 'movie'),
  _category('Other', CategoryType.out, 'other'),
];

CategoriesCompanion _category(String name, String type, String icon) {
  return CategoriesCompanion.insert(
    name: name,
    type: type,
    icon: Value(icon),
    color: Value(catalogEntryForKey(icon).defaultColor),
    isPreset: const Value(true),
  );
}
