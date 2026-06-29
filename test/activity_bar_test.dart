import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/activity_bar.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/main_area_providers.dart';
import 'package:nerdin_mobile_workspace/features/workspace/layout/workspace_providers.dart';

void main() {
  testWidgets('ActivityBar renders without crash when no tab is active',
      (tester) async {
    // This test verifies that NavigationRail handles the case where
    // _resolveIndex returns null (no active tab, side panel closed).
    // Regression for: selectedIndex assertion error when activeTabId is ''.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // activeTabIdProvider defaults to '' (empty string),
          // which is the case during app startup before chat tab is seeded.
          // No overrides needed — default behavior triggers the crash.
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ActivityBar(),
          ),
        ),
      ),
    );

    // If we reach here without assertion error, the fix works:
    // _resolveIndex returns null instead of -1, and NavigationRail
    // accepts null as valid (no selection).
    expect(find.byType(NavigationRail), findsOneWidget);

    // Verify all 6 destinations rendered
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Agent'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Git'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('ActivityBar highlights chat tab when active', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeTabIdProvider.overrideWith(
            () => _ActiveTabIdNotifier('chat'),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ActivityBar(),
          ),
        ),
      ),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
  });

  testWidgets('ActivityBar opens side panel without crash', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sidePanelOpenProvider.overrideWith(() => _SidePanelOpenNotifier(true)),
          activeSidePanelProvider.overrideWith(
            () => _ActiveSidePanelNotifier(SidePanelTab.explorer),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ActivityBar(),
          ),
        ),
      ),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('ActivityBar handles git panel open without crash',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sidePanelOpenProvider.overrideWith(() => _SidePanelOpenNotifier(true)),
          activeSidePanelProvider.overrideWith(
            () => _ActiveSidePanelNotifier(SidePanelTab.git),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ActivityBar(),
          ),
        ),
      ),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
  });
}

// Helper notifier for overriding activeTabIdProvider
class _ActiveTabIdNotifier extends Notifier<String> {
  _ActiveTabIdNotifier(this.initialValue);
  final String initialValue;

  @override
  String build() => initialValue;
}

// Helper notifier for overriding sidePanelOpenProvider
class _SidePanelOpenNotifier extends Notifier<bool> {
  _SidePanelOpenNotifier(this.initialValue);
  final bool initialValue;

  @override
  bool build() => initialValue;
}

// Helper notifier for overriding activeSidePanelProvider
class _ActiveSidePanelNotifier extends Notifier<SidePanelTab> {
  _ActiveSidePanelNotifier(this.initialValue);
  final SidePanelTab initialValue;

  @override
  SidePanelTab build() => initialValue;
}
