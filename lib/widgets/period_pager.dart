import 'package:flutter/material.dart';

import '../utils/report_period.dart';

/// Pages a [ReportPeriod] one unit at a time (Daily/Monthly/Yearly); for
/// All/Custom, which don't page, just centers the label. Shared by Reports
/// and the Transactions tab, which both browse by whatever period type is
/// currently selected in their filter.
class PeriodPager extends StatelessWidget {
  final ReportPeriod period;
  final ValueChanged<ReportPeriod> onChanged;
  const PeriodPager({super.key, required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (!period.canPage) {
      return Center(
        child: Text(period.label, style: const TextStyle(fontSize: 16)),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(period.previous()),
        ),
        Text(period.label, style: const TextStyle(fontSize: 16)),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(period.next()),
        ),
      ],
    );
  }
}
