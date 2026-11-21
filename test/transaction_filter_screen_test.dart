import 'package:dompetkuh/db/database.dart';
import 'package:dompetkuh/features/transactions/transaction_filter_screen.dart';
import 'package:dompetkuh/providers/database_provider.dart';
import 'package:dompetkuh/utils/report_period.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Select all / Deselect all act on their own section only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(3000, 8000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    TransactionFilterResult? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context)
                    .push<TransactionFilterResult>(
                      MaterialPageRoute(
                        builder: (_) => TransactionFilterScreen(
                          period: ReportPeriod.monthly(),
                          excludedAccountIds: const {},
                          excludedCategoryIds: const {},
                          excludedBudgetIds: const {},
                          excludedCurrencyIds: const {},
                          includeTransfers: true,
                        ),
                      ),
                    );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // Drift streams need real async time to emit.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    final incomeIds = {
      for (final c in await db.select(db.categories).get())
        if (c.type == CategoryType.in_) c.id,
    };
    final expenseIds = {
      for (final c in await db.select(db.categories).get())
        if (c.type == CategoryType.out) c.id,
    };
    expect(incomeIds, isNotEmpty);
    expect(expenseIds, isNotEmpty);

    int checked() => tester
        .widgetList<Checkbox>(find.byType(Checkbox))
        .where((c) => c.value == true)
        .length;
    final total = tester.widgetList(find.byType(Checkbox)).length;
    expect(checked(), total);

    // Section header order: ACCOUNT, Income, Expense, CURRENCY, BUDGET.
    final deselect = find.text('Deselect all');
    final select = find.text('Select all');
    // Invoke the button callbacks directly: the test surface lays the header
    // rows out wider than the viewport, so pointer taps would miss.
    void press(Finder label) => tester
        .widget<TextButton>(
          find.ancestor(of: label, matching: find.byType(TextButton)),
        )
        .onPressed!();
    expect(deselect, findsNWidgets(5));
    press(deselect.at(1)); // Income
    await tester.pump();
    expect(checked(), total - incomeIds.length);
    press(deselect.at(2)); // Expense
    await tester.pump();
    expect(checked(), total - incomeIds.length - expenseIds.length);
    press(select.at(1)); // Income back on
    await tester.pump();
    expect(checked(), total - expenseIds.length);
    tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed!();
    // Bounded pumps rather than pumpAndSettle: loading spinners animate
    // indefinitely until the Drift streams resolve.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(result!.excludedCategoryIds, expenseIds);
    expect(result!.excludedAccountIds, isEmpty);
    expect(result!.excludedCurrencyIds, isEmpty);

    // Dispose the tree inside the test so Drift's stream-cancel timers are
    // flushed here, not left pending at teardown.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
