/// One row in an account's ledger — either an in/out Transaction or one leg
/// of a Transfer. Both are normalized into this shape so the Account Detail
/// screen can render/sort them as a single merged list without branching
/// everywhere on which table a row came from.
class LedgerEntry {
  final LedgerKind kind;
  final int id;
  final DateTime date;

  /// 'in' or 'out' — drives amount color/sign in the UI.
  final String signType;

  /// Always positive, in this account's currency's minor unit.
  final int amount;

  final String? iconKey;
  final int? iconColor;
  final String title;
  final String? note;

  const LedgerEntry({
    required this.kind,
    required this.id,
    required this.date,
    required this.signType,
    required this.amount,
    required this.iconKey,
    required this.iconColor,
    required this.title,
    required this.note,
  });
}

enum LedgerKind { transaction, transferOut, transferIn }
