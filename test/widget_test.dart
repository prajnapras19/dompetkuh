import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dompetkuh/app.dart';

void main() {
  testWidgets('App boots to the navigation shell without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DompetkuhApp()));
    // Bounded pumps rather than pumpAndSettle: the account list's loading
    // spinner animates indefinitely until the (platform-channel-backed)
    // Drift DB resolves, which pumpAndSettle would wait on forever here.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Bottom nav is icon-only (no text labels) — assert on the icons
    // themselves instead.
    expect(find.byIcon(Icons.list_alt), findsOneWidget);
    expect(find.byIcon(Icons.pie_chart_outline), findsOneWidget);
    expect(find.byIcon(Icons.savings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });
}
