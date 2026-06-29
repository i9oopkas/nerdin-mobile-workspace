import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A tab in the main area's tab bar.
///
/// Each tab has a unique [id], a display [title], an icon, and a builder
/// that creates the tab's content widget. [closable] controls whether the
/// user can close the tab (editor tabs are closable, chat/agent are not).
class WorkspaceTab {
  final String id;
  final String title;
  final IconData icon;
  final WidgetBuilder builder;
  final bool closable;

  const WorkspaceTab({
    required this.id,
    required this.title,
    required this.icon,
    required this.builder,
    this.closable = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkspaceTab && id == other.id);

  @override
  int get hashCode => id.hashCode;
}

/// Notifier that manages the list of open tabs.
class OpenTabsNotifier extends Notifier<List<WorkspaceTab>> {
  @override
  List<WorkspaceTab> build() => [];

  /// Open a tab (or switch to it if already open).
  void open(WorkspaceTab tab) {
    final existingIndex = state.indexWhere((t) => t.id == tab.id);
    if (existingIndex >= 0) {
      // Tab already open — just switch to it
      ref.read(activeTabIdProvider.notifier).state = tab.id;
      return;
    }
    state = [...state, tab];
    ref.read(activeTabIdProvider.notifier).state = tab.id;
  }

  /// Close a tab by [id].
  void close(String id) {
    final index = state.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final newTabs = [...state];
    newTabs.removeAt(index);
    state = newTabs;

    // If we closed the active tab, fall back to the last remaining tab
    final activeId = ref.read(activeTabIdProvider);
    if (activeId == id && newTabs.isNotEmpty) {
      final fallbackIndex = index.clamp(0, newTabs.length - 1);
      ref.read(activeTabIdProvider.notifier).state = newTabs[fallbackIndex].id;
    }
  }

  /// Replace all tabs with a single tab (e.g. on route change).
  void resetTo(WorkspaceTab tab) {
    state = [tab];
    ref.read(activeTabIdProvider.notifier).state = tab.id;
  }

  /// Close all tabs.
  void closeAll() => state = [];
}

/// All currently open tabs.
final openTabsProvider =
    NotifierProvider<OpenTabsNotifier, List<WorkspaceTab>>(
  OpenTabsNotifier.new,
);

/// ID of the currently active tab.
class ActiveTabIdNotifier extends Notifier<String> {
  @override
  String build() => '';
}

final activeTabIdProvider =
    NotifierProvider<ActiveTabIdNotifier, String>(
  ActiveTabIdNotifier.new,
);
