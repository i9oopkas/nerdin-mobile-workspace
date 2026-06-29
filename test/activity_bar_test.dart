import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/activity_bar.dart';

void main() {
  testWidgets('ActivityBar renders without crash when no tab is active',
      (tester) async {
    // Regression test: activeTabId defaults to '' (empty string),
    // sidePanelOpen defaults to false. _resolveIndex returns null,
    // which NavigationRail accepts. If it returned -1, the assertion
    // '0 <= selectedIndex && selectedIndex < destinations.length' would fail.
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ActivityBar(),
          ),
        ),
      ),
    );

    // Should render NavigationRail with 6 destinations without crash
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Agent'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Git'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
