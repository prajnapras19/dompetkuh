import 'package:intl/intl.dart';

enum ReportPeriodType { daily, monthly, yearly, all, custom }

/// A navigable reporting period — Daily/Monthly/Yearly page by one unit at
/// a time via [next]/[previous]; All has no date bounds; Custom is a fixed
/// range that doesn't page. Mirrors the reference app's Laporan period menu
/// (Harian/Bulanan/Tahunan/Semua/Sesuaikan).
class ReportPeriod {
  final ReportPeriodType type;
  final DateTime reference; // anchor day for daily/monthly/yearly
  final DateTime? customStart;
  final DateTime? customEnd; // inclusive

  const ReportPeriod._(
    this.type,
    this.reference, {
    this.customStart,
    this.customEnd,
  });

  factory ReportPeriod.daily([DateTime? day]) => ReportPeriod._(
    ReportPeriodType.daily,
    _dateOnly(day ?? DateTime.now()),
  );

  factory ReportPeriod.monthly([DateTime? month]) {
    final m = month ?? DateTime.now();
    return ReportPeriod._(ReportPeriodType.monthly, DateTime(m.year, m.month));
  }

  factory ReportPeriod.yearly([DateTime? year]) {
    final y = year ?? DateTime.now();
    return ReportPeriod._(ReportPeriodType.yearly, DateTime(y.year));
  }

  factory ReportPeriod.all() =>
      ReportPeriod._(ReportPeriodType.all, DateTime.now());

  factory ReportPeriod.custom(DateTime start, DateTime end) => ReportPeriod._(
    ReportPeriodType.custom,
    start,
    customStart: _dateOnly(start),
    customEnd: _dateOnly(end),
  );

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// [start] inclusive, [end] exclusive. Both null for All.
  (DateTime?, DateTime?) get range {
    switch (type) {
      case ReportPeriodType.daily:
        return (reference, reference.add(const Duration(days: 1)));
      case ReportPeriodType.monthly:
        return (reference, DateTime(reference.year, reference.month + 1));
      case ReportPeriodType.yearly:
        return (reference, DateTime(reference.year + 1));
      case ReportPeriodType.all:
        return (null, null);
      case ReportPeriodType.custom:
        return (customStart, customEnd!.add(const Duration(days: 1)));
    }
  }

  bool get canPage =>
      type == ReportPeriodType.daily ||
      type == ReportPeriodType.monthly ||
      type == ReportPeriodType.yearly;

  ReportPeriod next() {
    switch (type) {
      case ReportPeriodType.daily:
        return ReportPeriod.daily(reference.add(const Duration(days: 1)));
      case ReportPeriodType.monthly:
        return ReportPeriod.monthly(
          DateTime(reference.year, reference.month + 1),
        );
      case ReportPeriodType.yearly:
        return ReportPeriod.yearly(DateTime(reference.year + 1));
      case ReportPeriodType.all:
      case ReportPeriodType.custom:
        return this;
    }
  }

  ReportPeriod previous() {
    switch (type) {
      case ReportPeriodType.daily:
        return ReportPeriod.daily(reference.subtract(const Duration(days: 1)));
      case ReportPeriodType.monthly:
        return ReportPeriod.monthly(
          DateTime(reference.year, reference.month - 1),
        );
      case ReportPeriodType.yearly:
        return ReportPeriod.yearly(DateTime(reference.year - 1));
      case ReportPeriodType.all:
      case ReportPeriodType.custom:
        return this;
    }
  }

  String get label {
    switch (type) {
      case ReportPeriodType.daily:
        return DateFormat('EEE, d MMM yyyy').format(reference);
      case ReportPeriodType.monthly:
        return DateFormat('MMMM yyyy').format(reference);
      case ReportPeriodType.yearly:
        return DateFormat('yyyy').format(reference);
      case ReportPeriodType.all:
        return 'All time';
      case ReportPeriodType.custom:
        return '${DateFormat('d MMM yyyy').format(customStart!)} – '
            '${DateFormat('d MMM yyyy').format(customEnd!)}';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ReportPeriod &&
      other.type == type &&
      other.reference == reference &&
      other.customStart == customStart &&
      other.customEnd == customEnd;

  @override
  int get hashCode => Object.hash(type, reference, customStart, customEnd);
}
